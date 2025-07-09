import csv
from wxc_common import *

def call_routing(orgId, httpHeaders):
    print("Choose the connection type:")
    print("1. Route group")
    print("2. Trunk")
    print("9. Back to main menu")
    print("Q. Exit")

    choice = input("Enter the number of your choice: ").lower()
    
    if choice == '1':
        connectionType = 'ROUTE_GROUP'
    elif choice == '2':
        connectionType = 'TRUNK'
    elif choice == '9':
        return None, None
    elif choice == 'q':
        print("Exiting")
        exit()
    else:
        print("Invalid choice")
        return None, None
    print("Choose the connection name:")
    apiUrl = 'https://webexapis.com/v1/telephony/config/routeChoices?orgId=' + orgId
    routing_choices = api_get(apiUrl, httpHeaders)
    if not routing_choices:
        return
    connection_names = [name["name"] for name in routing_choices if name["type"] == connectionType]
    connection_name = choice_prompt(connection_names)
    connectionId = search_value2_by_key1_target(routing_choices, 'name', 'id',connection_name)
    return connectionType, connectionId

def configure_locations(orgId, httpHeaders):
    print("Choose the feature to configure:")
    print("1. Create locations")
    print("2. Enable location(s) For calling")
    print("3. Call routing")
    print("4. Main line for locations")
    print("5. Outside access digit")
    print("6. Voice portal extension")
    print("7. Unknown extension routing")
    print("9. Back to main menu")
    print("Q. Exit")
    
    choice = input("Enter the number of your choice: ").lower()
    
    if choice == '1':
        csv_files = list_files('csv')
        print("Please select the CSV file:")
        selected_csv = choice_prompt(csv_files)
        file_reader = open_file(selected_csv)
        csv_headers = ["Location Name", "Address line 1", "Address line 2", "City / Town", "State / Province", "ZIP / Postal Code", "Country", "Preferred Language"]
        csv_reader = csv.DictReader(file_reader)
        csv_missing = [header for header in csv_headers if header not in csv_reader.fieldnames]
        if csv_missing:
            for header in csv_missing:
                print(f"CSV not formatted properly. Missing {header} header")
                return None
        else:
            locations_list = []
            for row in csv_reader:
                address = {
                    "address1": row["Address line 1"],
                    "city": row["City / Town"],
                    "state": row["State / Province"],
                    "postalCode": row["ZIP / Postal Code"],
                    "country": row["Country"]
                }
                if row["Address line 2"]:
                    address["address2"] = row["Address line 2"]
                record = {
                    "name": row["Location Name"],
                    "timeZone": row["Timezone"],
                    "preferredLanguage": row["Preferred Language"],
                    "announcementLanguage": row["Preferred Language"],
                    "address": address
                }
                locations_list.append(record)
        file_reader.close()

        n = len(locations_list)
        with alive_bar(n) as bar:
            for j in range(n):
                apiUrl = 'https://webexapis.com/v1/locations?orgId=' + orgId
                body = locations_list[j]
                if api_action('POST',apiUrl, body, httpHeaders):
                    continue
                bar()
        return None
    if choice == '2':
        location_data = identity_choice(orgId, httpHeaders, "locations")
        if location_data is None:
            return None
        apiUrl = 'https://webexapis.com/v1/telephony/config/locations?orgId=' + orgId
        locations_list = api_get(apiUrl, httpHeaders)
        print("Check if locations already enabled...")
        location_data = dataset_compare(location_data, locations_list, 'name', 'id', True)
        if location_data == None:
            return None
        n = len(location_data)
        with alive_bar(n) as bar:
            for j in range(n):
                apiUrl = 'https://webexapis.com/v1/locations/' + location_data[j]["id"] + '?orgId=' + orgId
                print(location_data[j]["name"])
                location_calling = api_get(apiUrl, httpHeaders)
                apiUrl = 'https://webexapis.com/v1/telephony/config/locations?orgId=' + orgId
                address = {
                    "address1": location_calling[0]["address"]["address1"],
                    "city": location_calling[0]["address"]["city"],
                    "state": location_calling[0]["address"]["state"],
                    "postalCode": location_calling[0]["address"]["postalCode"],
                    "country": location_calling[0]["address"]["country"]
                }
                if 'address2' in location_calling[0]['address']:
                    if location_calling[0]["address"]["address2"]:
                        address["address2"] = location_calling[0]["address"]["address2"]
                body = {
                    "id": location_calling[0]["id"],
                    "name": location_calling[0]["name"],
                    "timeZone": location_calling[0]["timeZone"],
                    "preferredLanguage": location_calling[0]["preferredLanguage"].lower(),
                    "announcementLanguage": location_calling[0]["preferredLanguage"].lower(),
                    "address": address
                }
                if api_action("POST", apiUrl, body, httpHeaders):
                    continue
                bar()
        return None
    elif choice == '3':
        location_data = identity_choice(orgId, httpHeaders, "locations")
        if location_data is None:
            return None
        apiUrl = 'https://webexapis.com/v1/telephony/config/locations?orgId=' + orgId
        locations_list = api_get(apiUrl, httpHeaders)
        location_data = dataset_compare(location_data, locations_list, 'name', 'id', False)
        if location_data == None:
            return None
        n = len(location_data)
        connectionType, connectionId = call_routing(orgId, httpHeaders)
        if connectionId == None:
            return None
        with alive_bar(n) as bar:
            for j in range(n):
                apiUrl = 'https://webexapis.com/v1/telephony/config/locations/' + location_data[j]["id"] + '?orgId=' + orgId
                body = {
                    "connection": {
                        "type": connectionType,
                        "id": connectionId
                    },
                }
                if api_action("PUT", apiUrl, body, httpHeaders):
                    continue
                bar()
        return None
    elif choice == '4':
        csv_files = list_files('csv')
        print("Please select the CSV file:")
        selected_csv = choice_prompt(csv_files)
        file_reader = open_file(selected_csv)
        csv_headers = ["Location Name", "Main Number"]
        csv_reader = csv.DictReader(file_reader)
        csv_missing = [header for header in csv_headers if header not in csv_reader.fieldnames]
        if csv_missing:
            for header in csv_missing:
                print(f"CSV not formatted properly. Missing {header} header")
                return None
        else:
            numbers_data = []
            for row in csv_reader:
                record = {
                    "name": row["Location Name"],
                    "phoneNumber": format_phone_number(row["Main Number"])
                }
                numbers_data.append(record)
        file_reader.close()

        apiUrl = 'https://webexapis.com/v1/telephony/config/locations?orgId=' + orgId
        locations_list = api_get(apiUrl, httpHeaders)
        numbers_data = dataset_compare(numbers_data, locations_list, 'name', 'id', False)
        if numbers_data  == None:
            return None
        apiUrl = 'https://webexapis.com/v1/telephony/config/numbers?orgId=' + orgId
        numbers_list = api_get(apiUrl, httpHeaders)
        numbers_data = dataset_compare(numbers_data, numbers_list, 'phoneNumber', 'name', False)
        if numbers_data  == None:
            return None
        n = len(numbers_data)
        with alive_bar(n) as bar:
            for j in range(n):
                location_id = search_value2_by_key1_target(locations_list, "name", "id", numbers_data[j]['name'])
                apiUrl = 'https://webexapis.com/v1/telephony/config/locations/' + location_id + '?orgId=' + orgId
                body = {
                    "callingLineId": {
                        "phoneNumber": numbers_data[j]['phoneNumber']
                    }
                }
                if api_action("PUT", apiUrl, body, httpHeaders):
                    print(numbers_data[j]['phoneNumber'])
                    continue
                bar()
        return None
    elif choice == '5':
        location_data = identity_choice(orgId, httpHeaders, "locations")
        if location_data is None:
            return None
        apiUrl = 'https://webexapis.com/v1/telephony/config/locations?orgId=' + orgId
        locations_list = api_get(apiUrl, httpHeaders)
        location_data = dataset_compare(location_data, locations_list, 'name', 'id', False)
        if location_data == None:
            return None
        n = len(location_data)
        outsideDigit = input("Enter the outside access digit: ")
        with alive_bar(n) as bar:
            for j in range(n):
                apiUrl = 'https://webexapis.com/v1/telephony/config/locations/' + location_data[j]["id"] + '?orgId=' + orgId
                body = {
                    "outsideDialDigit": outsideDigit,
                    "externalCallerIdName": location_data[j]["name"],
                    "enforceOutsideDialDigit": "false"
                }
                if api_action("PUT", apiUrl, body, httpHeaders):
                    continue
                bar()
        return None
    elif choice == '6':
        location_data = identity_choice(orgId, httpHeaders, "locations")
        if location_data is None:
            return None
        apiUrl = 'https://webexapis.com/v1/telephony/config/locations?orgId=' + orgId
        locations_list = api_get(apiUrl, httpHeaders)
        location_data = dataset_compare(location_data, locations_list, 'name', 'id', False)
        if location_data == None:
            return None
        n = len(location_data)
        extensionStart = input("Enter the voice portal extension: ")
        with alive_bar(n) as bar:
            for j in range(n):
                print(location_data[j]["name"])
                apiUrl = 'https://webexapis.com/v1/telephony/config/locations/' + location_data[j]["id"] + '/voicePortal?orgId=' + orgId
                body = {
                    "languageCode" : location_data[j]["preferredLanguage"].lower(),
                    "extension" : extensionStart
                }
                if api_action("PUT", apiUrl, body, httpHeaders):
                    continue
                bar()
        return None
    elif choice == '7':
        location_data = identity_choice(orgId, httpHeaders, "locations")
        if location_data is None:
            return None
        apiUrl = 'https://webexapis.com/v1/telephony/config/locations?orgId=' + orgId
        locations_list = api_get(apiUrl, httpHeaders)
        location_data = dataset_compare(location_data, locations_list, 'name', 'id', False)
        if location_data == None:
            return None
        n = len(location_data)
        connectionType, connectionId = call_routing(orgId, httpHeaders)
        with alive_bar(n) as bar:
            for j in range(n):
                apiUrl = 'https://webexapis.com/v1/telephony/config/locations/' + location_data[j]["id"] + '/internalDialing?orgId=' + orgId
                body = {
                    "enableUnknownExtensionRoutePolicy": True,
                    "unknownExtensionRouteIdentity": {
                        "id": connectionId,
                        "type": connectionType
                    }
                }
                if api_action("PUT", apiUrl, body, httpHeaders):
                    continue
                bar()
        return None
    elif choice == '9':
        return
    elif choice == 'q':
        print("Exiting")
        exit()
    else:
        print("Invalid choice")
        return None