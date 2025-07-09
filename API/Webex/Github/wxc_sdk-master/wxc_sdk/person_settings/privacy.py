"""
user privacy API
"""
from typing import Optional, Union

from .common import PersonSettingsApiChild
from ..base import ApiModel
from ..common import PersonPlaceAgent

__all__ = ['PrivacyApi', 'Privacy']


class Privacy(ApiModel):
    """
    Person privacy settings
    """
    #: When true auto attendant extension dialing will be enabled.
    aa_extension_dialing_enabled: Optional[bool] = None
    #: When true auto attendant dialing by first or last name will be enabled.
    aa_naming_dialing_enabled: Optional[bool] = None
    #: When true phone status directory privacy will be enabled.
    enable_phone_status_directory_privacy: Optional[bool] = None
    #: When `true` privacy is enforced for call pickup and barge-in. Only people specified by `monitoringAgents` can
    #: pick up the call or barge in by dialing the extension.
    enable_phone_status_pickup_barge_in_privacy: Optional[bool] = None
    #: List of people that are being monitored.
    #: for updates IDs can be used directly instead of :class:`wxc_sdk.common.PersonPlaceAgent` objects
    monitoring_agents: Optional[list[Union[str, PersonPlaceAgent]]] = None


class PrivacyApi(PersonSettingsApiChild):
    """
    API for privacy settings for users, vírtual lines and workspaces
    """

    feature = 'privacy'

    def read(self, entity_id: str, org_id: str = None) -> Privacy:
        """
        Get Privacy Settings for an entity

        Get privacy settings for the specified entity id.

        The privacy feature enables the entity's line to be monitored by others and determine if they can be reached
        by Auto Attendant services.

        This API requires a full, user, or read-only administrator auth token with a scope of spark-admin:people_read.

        :param entity_id: Unique identifier for the entity.
        :type entity_id: str
        :param org_id: Entity is in this organization. Only admin users of another organization (such as partners)
            may use this parameter as the default is the same organization as the token used to access API.
        :type org_id: str
        :return: privacy settings
        :rtype: :class:`Privacy`
        """
        ep = self.f_ep(person_id=entity_id)
        params = org_id and {'orgId': org_id} or None
        data = self.get(ep, params=params)
        return Privacy.model_validate(data)

    def configure(self, entity_id: str, settings: Privacy, org_id: str = None):
        """
        Configure an entity's Privacy Settings

        Configure an entity's privacy settings for the specified entity ID.

        The privacy feature enables the entity's line to be monitored by others and determine if they can be reached by
        Auto Attendant services.

        This API requires a full or user administrator or location administrator auth token with
        the spark-admin:people_write scope.

        :param entity_id: Unique identifier for the entity.
        :type entity_id: str
        :param settings: settings for update
        :type settings: :class:`Monitoring`
        :param org_id: Entity is in this organization. Only admin users of another organization (such as partners)
            may use this parameter as the default is the same organization as the token used to access API.
        :type org_id: str
        """
        ep = self.f_ep(person_id=entity_id)
        params = org_id and {'orgId': org_id} or None
        data = settings.model_dump(mode='json', by_alias=True, exclude_none=True)
        if settings.monitoring_agents is not None:
            id_list = []
            for ma in settings.monitoring_agents:
                if isinstance(ma, str):
                    id_list.append(ma)
                else:
                    id_list.append(ma.agent_id)
            data['monitoringAgents'] = id_list
        self.put(ep, params=params, json=data)
