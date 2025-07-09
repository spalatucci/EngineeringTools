"""
REST session for Webex API requests
"""
import asyncio
import json as json_mod
import logging
import urllib.parse
import uuid
from asyncio import Semaphore
from collections.abc import AsyncGenerator
from functools import wraps
from io import TextIOBase, StringIO
from json import JSONDecodeError
from time import perf_counter_ns
from typing import Tuple, Type, Optional, Any

from aiohttp import ClientSession, ClientResponse, ClientResponseError, RequestInfo
from aiohttp.typedefs import LooseHeaders
from pydantic import ValidationError

from .base import ApiModel, RETRY_429_MAX_WAIT
from .base import StrOrDict
from .tokens import Tokens

__all__ = ['AsErrorMessage', 'AsSingleError', 'AsErrorDetail', 'AsRestError', 'as_dump_response', 'AsRestSession']

log = logging.getLogger(__name__)


class AsErrorMessage(ApiModel):
    description: str
    code: Optional[int] = None
    error_code: Optional[int] = None


class AsSingleError(ApiModel):
    """
    Representation of single error in the body of an HTTP error response from Webex
    """
    key: Optional[str] = None
    message: list[AsErrorMessage]

    @property
    def code(self) -> Optional[int]:
        """
        Error code or None

        :return: error code
        """
        return self.message[0].code

    @property
    def description(self) -> Optional[int]:
        """
        Description or None

        :return: description
        """
        return self.message[0].description


class AsErrorDetail(ApiModel):
    """
    Representation of error details in the body of an HTTP error response from Webex. There are several variants of
    error responses. This model tries to generalize them
    """
    error: Optional[list[AsSingleError]] = None
    error_code: Optional[int] = None
    tracking_id: Optional[str] = None
    #
    message: Optional[str] = None
    errors: Optional[list[AsErrorMessage]] = None

    @property
    def description(self) -> str:
        """
        error description

        """
        return self.error and self.error[0].description or (self.errors and self.errors[0].description)

    @property
    def code(self) -> Optional[int]:
        """
        error code

        """
        return self.error and self.error[0].code or None


class AsRestError(ClientResponseError):
    """
    A REST error
    """

    def __init__(self, request_info: RequestInfo, history: Tuple[ClientResponse, ...], *, code: Optional[int] = None,
                 status: Optional[int] = None, message: str = "", headers: Optional[LooseHeaders] = None,
                 detail: Any = None) -> None:
        super().__init__(request_info, history, code=code, status=status, message=message, headers=headers)
        try:
            self.detail = AsErrorDetail.model_validate(detail)
        except ValidationError:
            self.detail = detail
        # TODO: implement equivalent to __init__ in sync implementation


def as_dump_response(*, response: ClientResponse, response_data=None, data=None,
                     json=None, file: TextIOBase = None, dump_log: logging.Logger = None,
                     diff_ns: int = None):
    """
    Dump response object to log file

    :param response: HTTP request response
    :param response_data:
    :param data:
    :param json:
    :param file: stream to dump to
    :type file: TextIOBase
    :param dump_log: logger to dump to
    :type dump_log: logging.Logger
    :param diff_ns: time the request took (in ns)
    :type diff_ns: int
    """
    if not log.isEnabledFor(logging.DEBUG):
        return
    dump_log = dump_log or log
    output = file or StringIO()

    # dump response objects in redirect history
    for h in response.history:
        as_dump_response(response=h, file=output)

    if diff_ns is None:
        time_str = ''
    else:
        time_str = f'({diff_ns / 1000000.0:.3f} ms)'

    print(f'Request {response.status}[{response.reason}]{time_str}: '
          f'{response.request_info.method} {response.request_info.url}', file=output)

    # request headers
    for k, v in response.request_info.headers.items():
        if k.lower() == 'authorization':
            v = 'Bearer ***'
        print(f'  {k}: {v}', file=output)

    # request body
    body_str = ''
    if isinstance(data, dict):
        body_str = str(urllib.parse.quote_plus(urllib.parse.urlencode(data)))
    elif isinstance(data, str):
        body_str = data
    elif json:
        body_str = json_mod.dumps(json)

    if body_str:
        print('  --- body ---', file=output)
        print(f'  {body_str}', file=output)

    print(' Response', file=output)
    # response headers
    for k in response.headers:
        print(f'  {k}: {response.headers[k]}', file=output)
    # dump response body
    if response_data:
        print('  --- response body ---', file=output)
        body = response_data
        if isinstance(body, dict):
            # mask access and refresh tokens
            if 'access_token' in body:
                # mask access token
                body['access_token'] = '***'
            if 'refresh_token' in body:
                body['refresh_token'] = '***'
        body = json_mod.dumps(body, indent=2)
        for line in body.splitlines():
            print(f'  {line}', file=output)
    print(' --- end ---', file=output)
    if file is None:
        dump_log.debug(output.getvalue())


def retry_request(func):
    """
    Decorator for the request method in the AsRestSession class. Used to implement backoff on 429 responses

    :param func:
    :return:
    """

    async def giveup_429(e: ClientResponseError, retry_429: bool) -> bool:
        """
        callback for backoff on REST requests

        :param e: latest exception
        :param retry_429: retry on 429?
        :return: True -> break the backoff loop
        """
        if e.status != 429 or not retry_429:
            # Don't retry on anything other than 429
            return True

        # determine how long we have to wait
        retry_after = int(e.headers.get('Retry-After', 5))

        # never wait more than the defined maximum of 20 s
        retry_after = min(retry_after, RETRY_429_MAX_WAIT)
        log.warning(f'429 retry after {retry_after} on {e.request_info.method} {e.request_info.url}')
        await asyncio.sleep(retry_after)
        return False

    @wraps(func)
    async def wrapper(session: 'AsRestSession', *args, **kwargs):
        async with session._sem:
            while True:
                try:
                    result = await func(session, *args, **kwargs)
                except ClientResponseError as e:
                    if await giveup_429(e, session.retry_429):
                        raise
                else:
                    break
        return result

    return wrapper


class AsRestSession(ClientSession):
    """
    REST session used for API requests:
            * includes an Authorization header in reach request
            * implements retries on 429
            * loads deserializes JSON data if needed
    """
    #: base URL for all Webex API requests
    BASE = 'https://webexapis.com/v1'

    def __init__(self, *, tokens: Tokens, concurrent_requests: int, retry_429: bool = True):
        super().__init__()
        self._tokens = tokens
        self._sem = Semaphore(concurrent_requests)
        self.retry_429 = retry_429

    def ep(self, path: str = None):
        """
        get an API endpoint

        :param path:
        :return: full endpoint
        :meta private:
        """
        path = path and f'/{path}' or ''
        return f'{self.BASE}{path}'

    @property
    def access_token(self) -> str:
        """
        access token used for all requests

        :return: access token
        :rtype: str
        """
        return self._tokens.access_token

    @retry_request
    async def _request_w_response(self, method: str, url: str, headers=None, content_type: str = None,
                                  data=None, json=None, **kwargs) -> Tuple[ClientResponse, StrOrDict]:
        """
        low level API REST request with support for 429 rate limiting

        :param method: HTTP method
        :type method: str
        :param url: URL
        :type url: str
        :param headers: prepared headers for request
        :type headers: Optional[dict]
        :param content_type:
        :type content_type: str
        :param kwargs: additional keyward args
        :type kwargs: dict
        :return: Tuple of response object and body. Body can be text or dict (parsed from JSON body)
        :rtype:
        """
        request_headers = {'authorization': f'Bearer {self._tokens.access_token}',
                           'content-type': 'application/json;charset=utf-8',
                           'TrackingID': f'SIMPLE_{uuid.uuid4()}'}
        if headers:
            request_headers.update((k.lower(), v) for k, v in headers.items())
        if content_type:
            request_headers['content-type'] = content_type
        # the event is cleared if any task hit a 429
        start = perf_counter_ns()
        async with self.request(method, url=url, headers=request_headers,
                                data=data, json=json, **kwargs) as response:
            # get response body as text or dict (parsed JSON)
            ct = response.headers.get('Content-Type')
            if not ct:
                response_data = ''
            elif ct.startswith('application/json'):
                try:
                    response_data = await response.json()
                except JSONDecodeError:
                    response_data = await response.text()
            else:
                response_data = await response.text()
            diff_ns = perf_counter_ns() - start
            as_dump_response(response=response, data=data, json=json, response_data=response_data, diff_ns=diff_ns)
            try:
                response.raise_for_status()
            except ClientResponseError as error:
                # create a RestError based on HTTP error
                error = AsRestError(request_info=error.request_info,
                                    history=error.history, status=error.status,
                                    message=error.message, headers=error.headers,
                                    detail=response_data)
                raise error

        return response, response_data

    async def _rest_request(self, method: str, url: str, **kwargs) -> StrOrDict:
        """
        low level API request only returning the body

        :param method: HTTP method
        :type method: str
        :param url: URL
        :type url: str
        :param headers: prepared headers for request
        :type headers: Optional[dict]
        :param kwargs: additional keyward args
        :type kwargs: dict
        :return: body. Body can be text or dict (parsed from JSON body)
        :rtype: Unon
        """
        _, data = await self._request_w_response(method, url=url, **kwargs)
        return data

    async def rest_get(self, *args, **kwargs) -> StrOrDict:
        """
        GET request

        :param args:
        :param kwargs:
        :return: deserialized JSON content or body text
        """
        return await self._rest_request('GET', *args, **kwargs)

    async def rest_post(self, *args, **kwargs) -> StrOrDict:
        """
        POST request

        :param args:
        :param kwargs:
        :return: deserialized JSON content or body text
        """
        return await self._rest_request('POST', *args, **kwargs)

    async def rest_put(self, *args, **kwargs) -> StrOrDict:
        """
        PUT request

        :param args:
        :param kwargs:
        :return: deserialized JSON content or body text
        """
        return await self._rest_request('PUT', *args, **kwargs)

    async def rest_delete(self, *args, **kwargs) -> StrOrDict:
        """
        DELETE request

        :param args:
        :param kwargs:
        """
        return await self._rest_request('DELETE', *args, **kwargs)

    async def rest_patch(self, *args, **kwargs) -> StrOrDict:
        """
        PATCH request

        :param args:
        :param kwargs:
        """
        return await self._rest_request('PATCH', *args, **kwargs)

    async def follow_pagination(self, url: str, model: Type[ApiModel] = None,
                                params: dict = None,
                                item_key: str = None, **kwargs) -> AsyncGenerator[ApiModel, None, None]:
        """
        Handling RFC5988 pagination of list requests. Generator of parsed objects

        :param url: start url for 1st GET
        :type url: str
        :param model: data type to return
        :type model: ApiModel
        :param params: URL parameters, optional
        :type params: Optional[dict]
        :param item_key: key to list of values
        :type item_key: str
        :return: yields parsed objects
        """

        def noop(x):
            return x

        if model is None or not issubclass(model, ApiModel):
            model = noop
        else:
            model = model.model_validate

        while url:
            log.debug(f'{self}.pagination: getting {url}')
            response, data = await self._request_w_response('GET', url=url, params=params, **kwargs)
            # params only in first request. In subsequent requests we rely on the completeness of the 'next' URL
            params = None
            # try to get the next page (if present)
            try:
                url = str(response.links['next']['url'])
            except KeyError:
                url = None
            else:
                # not needed any more, WXCAPIBULK-27 has been fixed
                # if len((pagination_fix := url.split('https,https:/'))) > 1:
                #     url = f'https://{pagination_fix[1]}'
                pass
            if not data:
                continue
            # return all items
            if item_key is None:
                if 'items' in data:
                    item_key = 'items'
                else:
                    # we go w/ the first return value that is a list
                    item_key = next((k for k, v in data.items()
                                     if isinstance(v, list)))
            items = data.get(item_key, [])
            for item in items:
                yield model(item)
