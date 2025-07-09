"""
Reports API
"""
import csv
import io
import zipfile
from collections.abc import Generator, Iterable
from dataclasses import dataclass
from datetime import datetime, date
from typing import Optional

from pydantic import Field, TypeAdapter

from ..api_child import ApiChild
from ..base import ApiModel, to_camel
from ..cdr import CDR

__all__ = ['ValidationRules', 'ReportTemplate', 'Report', 'ReportsApi', 'CallingCDR']


class ValidationRules(ApiModel):
    #: Field on which validation rule is applied
    field: Optional[str] = None
    #: Whether the above field is required
    required: Optional[str] = None


class ReportTemplate(ApiModel):
    #: Unique identifier representing a report.
    id: Optional[int] = Field(alias='Id', default=None)
    #: Name of the template.
    title: Optional[str] = None
    #: The service to which the report belongs.
    service: Optional[str] = None
    #: Maximum date range for reports belonging to this template.
    max_days: Optional[int] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    #: Generated reports belong to which field.
    identifier: Optional[str] = None
    #: an array of validation rules
    validations: Optional[list[ValidationRules]] = None


class Report(ApiModel):
    #: Unique identifier for the report.
    id: Optional[str] = Field(alias='Id', default=None)
    #: Name of the template to which this report belongs.
    title: Optional[str] = None
    #: The service to which the report belongs.
    service: Optional[str] = None
    #: The data in this report belongs to dates greater than or equal to this.
    start_date: Optional[date] = None
    #: The data in this report belongs to dates smaller than or equal to this.
    end_date: Optional[date] = None
    #: The site to which this report belongs to. This only exists if the report belongs to service Webex.
    site_list: Optional[str] = None
    #: Time of creation for this report.
    created: Optional[datetime] = None
    #: The person who created the report.
    created_by: Optional[str] = None
    #: Whether this report was scheduled from API or Control Hub.
    schedule_from: Optional[str] = None
    #: Completion status of this report.
    status: Optional[str] = None
    download_domain: Optional[str] = None
    #: The link from which the report can be downloaded.
    download_url: Optional[str] = Field(alias='downloadURL', default=None)


class CallingCDR(CDR):
    """
    Records in a Calling Detailed Call History report
    """

    @classmethod
    def from_dicts(cls, dicts: Iterable[dict]) -> Generator['CallingCDR', None, None]:
        """
        Yield :class:`CallingCDR` instances from dicts

        :param dicts: iterable with the dicts to yield CDRs from
        :return: yields :class:`CallingCDR` instances

        Example:

            .. code-block:: python

                # download call history report from Webex
                cdrs = list(CallingCDR.from_dicts(api.reports.download(url=url)))

        """
        for record in dicts:
            yield cls.model_validate(record)


@dataclass(init=False)
class ReportsApi(ApiChild, base='devices'):
    """
    Reports

    To access these endpoints, you must use an administrator token with the `analytics:read_all` `scope
    <https://developer.webex.com/docs/integrations#scopes>`_. The
    authenticated user must be a read-only or full administrator of the organization to which the report belongs.

    To use this endpoint the org needs to be licensed for the Pro Pack.

    Reports available via `Webex Control Hub
    <https://admin.webex.com>`_ may be generated and downloaded via the Reports API. To access this API,
    the authenticated user must be a read-only or full administrator of the organization to which the report belongs.

    For more information about Reports, see the `Admin API
    <https://developer.webex.com/docs/admin#reports-api>`_ guide.

    """

    def list_templates(self) -> list[ReportTemplate]:
        """
        List all the available report templates that can be generated.

        CSV (comma separated value) reports for Webex services are only supported for organizations based in the
        North American region. Organizations based in other regions will return blank CSV files for any Webex reports.

        :return: list of report templates
        :rtype: list[ReportTemplate]
        """
        # TODO: https://developer.webex.com/docs/api/v1/report-templates/list-report-templates, documentation bug
        #   "Template Attributes" is actually "items"
        # TODO: https://developer.webex.com/docs/api/v1/report-templates/list-report-templates, documentation bug
        #   "validations"/"validations" is actually "validations"
        # TODO: https://developer.webex.com/docs/api/v1/report-templates/list-report-templates, documentation bug
        #   "id" is actually "Id"
        # TODO: https://developer.webex.com/docs/api/v1/report-templates/list-report-templates, documentation bug
        #   "startDate", "endDate" not documented
        url = self.session.ep('report/templates')
        data = self.get(url=url)
        result = TypeAdapter(list[ReportTemplate]).validate_python(data['items'])
        return result

    def list(self, report_id: str = None, service: str = None, template_id: str = None, from_date: date = None,
             to_date: date = None) -> Generator[Report, None, None]:
        """
        Lists all reports. Use query parameters to filter the response. The parameters are optional. However, `from`
        and `to` parameters should be provided together.

        CSV reports for Teams services are only supported for organizations based in the North American region.
        Organizations based in a different region will return blank CSV files for any Teams reports.

        Reports are usually provided in zip format. A Content-header `application/zip` or `application/octet-stream`
        does indicate the zip format. There is usually no .zip file extension.

        :param report_id: List reports by ID.
        :param service: List reports which use this service.
        :param template_id: List reports with this report template ID.
        :param from_date: List reports that were created on or after this date.
        :param to_date: List reports that were created before this date.
        :return: yields :class:`Report` instances
        """
        # TODO: https://developer.webex.com/docs/api/v1/report-templates/list-report-templates, documentation bug
        #   "Report Attributes" is actually "items"
        # TODO: https://developer.webex.com/docs/api/v1/report-templates/list-report-templates, documentation bug
        #   missing attribute: downloadDomain
        # TODO: https://developer.webex.com/docs/api/v1/report-templates/list-report-templates, documentation bug
        #   "id" is actually "Id"
        # TODO: https://developer.webex.com/docs/api/v1/report-templates/list-report-templates, documentation bug
        #   "scheduledFrom" is actually "scheduleFrom"

        params = {to_camel(k.split('_')[0] if k.endswith('date') else k): v for k, v in locals().items()
                  if k not in {'self', 'from_date', 'to_date'} and v is not None}
        if from_date:
            params['from'] = from_date.strftime('%Y-%m-%d')
        if to_date:
            params['to'] = to_date.strftime('%Y-%m-%d')

        url = self.session.ep('reports')
        return self.session.follow_pagination(url=url, params=params, model=Report, item_key='items')

    def create(self, template_id: int, start_date: date = None, end_date: date = None, site_list: str = None) -> str:
        """
        Create a new report. For each templateId, there are a set of validation rules that need to be followed. For
        example, for templates belonging to Webex, the user needs to provide siteUrl. These validation rules can be
        retrieved via the Report Templates API.

        CSV reports for Teams services are only supported for organizations based in the North American region.
        Organizations based in a different region will return blank CSV files for any Teams reports.

        :param template_id: Unique ID representing valid report templates.
        :type template_id: int
        :param start_date: Data in the report will be from this date onwards.
        :type start_date: date
        :param end_date: Data in the report will be until this date.
        :type end_date: date
        :param site_list: Sites belonging to user's organization. This attribute is needed for site-based templates.
        :type site_list: str
        :return: The unique identifier for the report.
        :rtype: str
        """
        # TODO: https://developer.webex.com/docs/api/v1/reports/create-a-report, documentation bug
        #   result actually is something like: {'items': {'Id': 'Y2...lMg'}}
        body = {'templateId': template_id}
        if start_date:
            body['startDate'] = start_date.strftime('%Y-%m-%d')
        if end_date:
            body['endDate'] = end_date.strftime('%Y-%m-%d')
        if site_list:
            body['siteList'] = site_list
        url = self.session.ep('reports')
        data = self.post(url=url, json=body)
        result = data['items']['Id']
        return result

    def details(self, report_id: str) -> Report:
        """
        Shows details for a report, by report ID.

        Specify the report ID in the reportId parameter in the URI.

        CSV reports for Teams services are only supported for organizations based in the North American region.
        Organizations based in a different region will return blank CSV files for any Teams reports.

        :param report_id: The unique identifier for the report.
        :type report_id: str
        :return: report details
        :rtype: Report
        """
        # TODO: https://developer.webex.com/docs/api/v1/reports/create-a-report, documentation bug
        #   result actually is something like: {'items': [{'title': 'Engagement Report', 'service': 'Webex Calling',
        #   'startDate': '2021-12-14', 'endDate': '2022-01-13', 'siteList': '', 'created': '2022-01-14 11:16:59',
        #   'createdBy': 'Y2lz..GM', 'scheduleFrom': 'api', 'status': 'done', 'downloadDomain':
        #   'https://reportdownload-a.webex.com/',  'downloadURL':
        #   'https://reportdownload-a.webex.com/api?reportId=Y2lz3ZA',  'Id': 'Y23ZA'}], 'numberOfReports': 1}
        url = self.session.ep(f'reports/{report_id}')
        data = self.get(url=url)
        result = Report.model_validate(data['items'][0])
        return result

    def delete(self, report_id: str):
        """
        Remove a report from the system.

        Specify the report ID in the reportId parameter in the URI

        CSV reports for Teams services are only supported for organizations based in the North American region.
        Organizations based in a different region will return blank CSV files for any Teams reports.

        :param report_id: The unique identifier for the report.
        :type report_id: str
        """
        url = self.session.ep(f'reports/{report_id}')
        super().delete(url=url)

    def download(self, url: str) -> Generator[dict, None, None]:
        """
        Download a report from the given URL and yield the rows as dicts

        :param url: download URL
        :type url: str
        :return: yields dicts
        """
        '''async
    async def download(self, url: str) -> List[dict]:
        """
        Download a report from the given URL and yield the rows as dicts

        :param url: download URL
        :type url: str
        :return: list of dicts (one per row)
        :rtype: list[dict]
        """
        raise NotImplementedError('async download not implemented; use sync call instead')
        '''
        headers = {'Authorization': f'Bearer {self.session.access_token}'}
        with self.session.get(url=url, stream=True, headers=headers) as r:
            r.raise_for_status()
            # content is a ZIP file
            zip_file_bytes = io.BytesIO(r.content)
            with zipfile.ZipFile(zip_file_bytes, 'r') as zip_file:
                # open 1st file
                first_info = zip_file.infolist()[0]
                with zip_file.open(first_info) as f:
                    # read over UTF BOM
                    f.read(3)
                    text = io.TextIOWrapper(f, encoding='utf-8')
                    lines = (line for line in text)
                    reader = csv.DictReader(lines)
                    yield from reader
        return
