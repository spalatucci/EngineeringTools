"""
Person numbers API
"""
from typing import Optional, Literal

from pydantic import Field

from .common import PersonSettingsApiChild
from ..base import ApiModel
from ..common import RingPattern, PatternAction

__all__ = ['PersonPhoneNumber', 'PersonNumbers', 'UpdatePersonPhoneNumber', 'UpdatePersonNumbers', 'NumbersApi']


class PersonPhoneNumber(ApiModel):
    """
    Information about a phone number
    """
    #: Flag to indicate primary number or not.
    primary: bool
    #: Phone Number.
    direct_number: Optional[str] = None
    #: Extension
    extension: Optional[str] = None
    #: Routing prefix of location.
    routing_prefix: Optional[str] = None
    #: Routing prefix + extension of a person or workspace.
    esn: Optional[str] = None
    #: Optional ring pattern and this is applicable only for alternate numbers.
    ring_pattern: Optional[RingPattern] = None


class PersonNumbers(ApiModel):
    """
    Information about person's phone numbers
    """
    #: To enable/disable distinctive ring pattern that identifies calls coming from a specific phone number.
    distinctive_ring_enabled: bool
    #: Information about the number.
    phone_numbers: list[PersonPhoneNumber]


class UpdatePersonPhoneNumber(ApiModel):
    """
    Information about a phone number
    """
    #: Flag to indicate primary number or not.
    primary: Literal[False] = Field(default=False)
    #: This is either 'ADD' to add phone numbers or 'DELETE' to remove phone numbers.
    action: PatternAction
    #: Phone numbers that are assigned.
    external: str
    #: Extension that is being assigned.
    extension: Optional[str] = None
    #: Ring Pattern of this number.
    ring_pattern: Optional[RingPattern] = None


class UpdatePersonNumbers(ApiModel):
    """
    Information about person's phone numbers
    """
    #: This enable distinctive ring pattern for the person.
    enable_distinctive_ring_pattern: Optional[bool] = None
    #: Information about the number.
    phone_numbers: list[UpdatePersonPhoneNumber]


class NumbersApi(PersonSettingsApiChild):
    """
    API for person's numbers
    """

    feature = 'numbers'

    def read(self, person_id: str, prefer_e164_format: bool = None, org_id: str = None) -> PersonNumbers:
        """
        Get a person's phone numbers including alternate numbers.

        A person can have one or more phone numbers and/or extensions via which they can be called.

        This API requires a full or user administrator auth token with
        the spark-admin:people_read scope.

        :param person_id: Unique identifier for the person.
        :type person_id: str
        :param prefer_e164_format: Return phone numbers in E.164 format.
        :type prefer_e164_format: bool
        :param org_id: Person is in this organization. Only admin users of another organization (such as partners) may
            use this parameter as the default is the same organization as the token used to access API.
        :type org_id: str
        :return: Alternate numbers of the user
        :rtype: :class:`PersonNumbers`
        """
        params = {}
        if org_id is not None:
            params['orgId'] = org_id
        if prefer_e164_format is not None:
            params['preferE164Format'] = str(prefer_e164_format).lower()
        ep = self.f_ep(person_id=person_id)
        return PersonNumbers.model_validate(self.get(ep, params=params))

    def update(self, person_id: str, update: UpdatePersonNumbers, org_id: str = None):
        """
        Assign or unassign alternate phone numbers to a person.

        Each location has a set of phone numbers that can be assigned to people, workspaces, or features. Phone
        numbers must follow E.164 format for all countries, except for the United States, which can also follow the
        National format. Active phone numbers are in service.

        Assigning or Unassigning an alternate phone number to a person requires a full administrator auth token with
        a scope of spark-admin:telephony_config_write.

        :param person_id: Unique identifier of the person.
        :type person_id: str
        :param update: Update to apply
        :type update: :class:`UpdatePersonNumbers`
        :param org_id: organization to work on
        :type org_id: str
        """
        url = self.session.ep(f'telephony/config/people/{person_id}/numbers')
        params = org_id and {'orgId': org_id} or None
        body = update.model_dump_json()
        self.put(url=url, params=params, data=body)
