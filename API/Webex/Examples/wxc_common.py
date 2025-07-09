import requests
import json
import os
import re
import csv
from ratelimit import limits, sleep_and_retry
from alive_progress import alive_bar
from InquirerPy import prompt
from fuzzywuzzy import process

ONE_MINUTE = 60
MAX_CALLS_PER_MINUTE = 300

def extract_dicts(data):
    if isinstance(data, dict):
        for key, value in data.items():
            if isinstance(value, list) and all(isinstance(item, dict) for item in value):
                return value
        return [data]
    elif isinstance(data, list) and all(isinstance(item, dict) for item in data):
        return data
    return None

def get_nested_value(data, key):
    if isinstance(data, dict):
        if key in data:
            return data[key]
        for k, v in data.items():
            if isinstance(v, (dict, list)):
                result = get_nested_value(v, key)
                if result is not None:
                    return result
    elif isinstance(data, list):
        for item in data:
            result = get_nested_value(item, key)
            if result is not None:
                return result
    return None

#Recursively search for a key1 and return the value its key2
def search_value2_by_key1(data, key1, key2):
    if isinstance(data, dict):
        if key1 in data:
            return data.get(key2)
        for key, value in data.items():
            if isinstance(value, (dict, list)):
                result = search_value2_by_key1(value, key1, key2)
                if result is not None:
                    return result
    elif isinstance(data, list):
        for item in data:
            if isinstance(item, (dict, list)):
                result = search_value2_by_key1(item, key1, key2)
                if result is not None:
                    return result
    return None

#Recursively search through multiple entries of key1 by the target name and return its value of key2
def search_value2_by_key1_target(data, key1, key2, target_name):
    if isinstance(data, dict):
        if key1 in data and data[key1].lower() == target_name.lower():
            return get_nested_value(data, key2)
        for key, value in data.items():
            if isinstance(value, (dict, list)):
                result = search_value2_by_key1_target(value, key1, key2, target_name)
                if result is not None:
                    return result
    elif isinstance(data, list):
        for item in data:
            if isinstance(item, (dict, list)):
                result = search_value2_by_key1_target(item, key1, key2, target_name)
                if result is not None:
                    return result
    return None

def get_value2_from_key1_query(query_value, lists, key1, key2):
    # Extract the list names from the lists
    query_values = [value[key1] for value in lists]
    
    # Perform fuzzy matching to find the best match
    matches = process.extractBests(query_value, query_values, limit=5, score_cutoff=70)
    
    if not matches:
        print("No matches found.")
        return None

    # If there's an exact match or only one good match, return it
    if len(matches) == 1 or matches[0][1] == 100:
        selected_value = next(value for value in lists if value[key1] == matches[0][0])
        return selected_value[key2]

    # If there are multiple good matches, prompt the user to select one
    print("Multiple matches found. Please select one:")
    for i, match in enumerate(matches):
        print(f"{i + 1}. {match[0]}")
    
    choice = int(input("Enter the number of your choice: ")) - 1
    
    if 0 <= choice < len(matches):
        selected_value = next(value for value in lists if value[key1] == matches[choice][0])
        return selected_value[key2]
    else:
        print("Invalid choice. Exiting.")
        return None

def get_dict2_from_key1_query(query_value, lists, key1, key2):
    key2_value = get_value2_from_key1_query(query_value, lists, key1, key2)
    if key2_value:
        return next(value for value in lists if value[key2] == key2_value)
    return None

def error_message(message, error_key1, error_key2):
    if isinstance(message, dict):
        if error_key1 in message:
            return message[error_key1]
        if error_key2 in message:
            return message[error_key2]
        for key, value in message.items():
            result = error_message(value, error_key1, error_key2)
            if result is not None:
                return result
    elif isinstance(message, list):
        for item in message:
            result = error_message(item, error_key1, error_key2)
            if result is not None:
                return result
    return None

def choice_prompt(choice_list):
    for index, file in enumerate(choice_list):
        print(f"{index + 1}. {file}")
    choice = int(input("Enter the number of your choice: ")) - 1
    if 0 <= choice < len(choice_list):
        return choice_list[choice]
    else:
        print("Invalid choice. Exiting.")
        return None

def list_files(extension, directory='.'):
    return [file for file in os.listdir(directory) if file.endswith('.' + extension)]

def open_file(selected_file):
    file_reader = open(selected_file, mode='r')
    return file_reader

def identity_choice(orgId, httpHeaders, identity):
    if identity == "locations":
        apiUrl = 'https://webexapis.com/v1/locations?orgId=' + orgId + '&max=1000'
        identityName = "Location"
        identitySearch1 = "name"
        identitySearch2 = identitySearch1
        csv_header = "Location Name"
        identities_list = api_get(apiUrl,httpHeaders)
        identities_filter = identities_list
    elif identity == "users":
        apiUrl = 'https://webexapis.com/v1/people?orgId=' + orgId + '&callingData=True&max=1000'
        identityName = "User"
        identitySearch1 = "emails"
        identitySearch2 = identitySearch1
        csv_header = "User ID/Email"
        identities_list = api_get(apiUrl,httpHeaders)
        identities_filter = [item for item in identities_list if "locationId" in item and item["locationId"] is not None]
    elif identity == "devices":
        apiUrl = 'https://webexapis.com/v1/devices?orgId=' + orgId + '&max=1000'
        identityName = "Device"
        identitySearch1 = "displayName"
        identitySearch2 = "mac"
        csv_header = "Mac Address"
        identities_list = api_get(apiUrl,httpHeaders)
        identities_filter = [item for item in identities_list if item.get("type") == "phone"]
    else:
        print("Invalid choice. Exiting.")
        return None
    print("What " + identityName.lower() + "(s) would you like to modify?")
    print("1. All")
    print("2. One " + identityName)
    print("3. Multiple " + identityName + "s")
    print("9. Back to main menu")
    print("Q. Exit")

    choice = input("Enter the number of your choice: ").lower()
    
    if choice == '1':
        return identities_filter
    elif choice == '2':
        identity_name = input("Enter " + identityName.lower() + " " + identitySearch1 + ": ")
        identity_id = get_value2_from_key1_query(identity_name, identities_filter,identitySearch1,"id")
        if identity_id is None:
            return None
        identity_selected = [get_dict2_from_key1_query(identity_id, identities_filter,"id",identitySearch1)]
        return identity_selected
    elif choice == '3':
        if len(identities_filter) > 50:
            print("There are over 50 " + identityName.lower() + "s. Please use a spreadsheet to select " + identityName.lower() + "s")
            csv_files = list_files('csv')
            print("Please select the CSV file:")
            selected_csv = choice_prompt(csv_files)
            file_reader = open_file(selected_csv)
            csv_reader = csv.DictReader(file_reader)
            if csv_header not in csv_reader.fieldnames:
                print(f"CSV not formatted properly. Missing {csv_header} header")
                return None
            else:
                identities_data = []
                for row in csv_reader:
                    record = row[csv_header].lower()
                    identities_data.append(record)
            file_reader.close()
            identities_selected = []
            for identities in identities_data:
                found = False
                for identity in identities_filter:
                    if isinstance(identity[identitySearch2], list):
                        identities_lower = [entry.lower() for entry in identity[identitySearch2]]
                        if identities in identities_lower:
                            identities_selected.append(identity)
                            found = True
                            break
                    else:
                        if identities in identity[identitySearch2].lower():
                            identities_selected.append(identity)
                            found = True
                            break
                if not found:
                    print(f"{identities} doesn't exist")
            return identities_selected
        else:
            identities_options = [identity[identitySearch1] for identity in identities_filter]
            questions = [
                {
                    "type": "checkbox",
                    "message": "Select multiple " + identityName.lower() + "s:",
                    "name": "selected_identities",
                    "choices": identities_options
                }
            ]
            identity_answers = prompt(questions)
            identities_selected = [identities for identities in identities_filter if identities[identitySearch1] in identity_answers["selected_identities"]]
            if len(identities_selected) == 0:
                print("You must select atleast one option")
                return None
            return identities_selected
    elif choice == '9':
        return None
    elif choice == 'q':
        print("Exiting")
        exit()
    else:
        print("Invalid choice")
        return None
    
def format_phone_number(number):
    digits = re.sub(r'\D', '', number)
    if len(digits) == 11 and digits.startswith('1'):
        return f"+{digits}"
    elif len(digits) == 10:
        return f"+1{digits}"
    else:
        return None

def dataset_compare(data1, data2, key1, key2, inverse):
    new_data1 = []
    printed_names = set()
    if inverse:
        for entry in data1:
            data_id = search_value2_by_key1_target(data2, key1, key2, entry[key1])
            if data_id is None:
                if entry[key1] not in printed_names:
                    new_data1.append(entry)
            else:
                print(f"{entry[key1]} does exist")
                printed_names.add(entry[key1])
    else:
        for entry in data1:
            data_id = search_value2_by_key1_target(data2, key1, key2, entry[key1])
            if data_id is None:
                if entry[key1] not in printed_names:
                    print(f"{entry[key1]} doesn't exist")
                    printed_names.add(entry[key1])
            else:
                new_data1.append(entry)
    if len(new_data1) == 0:
        print("No entries remaining")
        return None
    return new_data1

@sleep_and_retry
@limits(calls=MAX_CALLS_PER_MINUTE, period=ONE_MINUTE)
def api_get(apiUrl, httpHeaders):
    data_all = []
    while apiUrl:
        httpResponse = requests.get(apiUrl, headers=httpHeaders)
        if httpResponse.status_code == 200:
            try:
                data = extract_dicts(httpResponse.json())
            except ValueError:
                raise ValueError("Response content is not valid JSON")
            data_all.extend(data)
            link_header = httpResponse.headers.get('Link')
            apiUrl = None
            if link_header:
                if 'rel="next"' in link_header:
                    apiUrl = link_header[link_header.find("<")+1:link_header.find(">")]
        else:
            if 400 <= httpResponse.status_code < 500:
                if httpResponse.headers.get('Content-Type') == 'application/json':
                    try:
                        httpResponse = httpResponse.json()
                        print(error_message(httpResponse, 'errorMessage', 'description'))
                    except ValueError:
                        print("Response content is not valid JSON")
                else:
                    print("Response does not contain JSON data")
            break
    return data_all

@sleep_and_retry
@limits(calls=MAX_CALLS_PER_MINUTE, period=ONE_MINUTE)
def api_action(request_type, apiUrl, body, httpHeaders):
    if request_type.upper() == 'POST':
        httpResponse = requests.post(url = apiUrl, json = body, headers = httpHeaders)
    elif request_type.upper() == 'PUT':
        httpResponse = requests.put(url = apiUrl, json = body, headers = httpHeaders)
    print(httpResponse)
    if 400 <= httpResponse.status_code < 500:
        if httpResponse.headers.get('Content-Type') == 'application/json':
            try:
                httpResponse = httpResponse.json()
                print(error_message(httpResponse, 'errorMessage', 'description'))
            except ValueError:
                print("Response content is not valid JSON")
        else:
            print("Response does not contain JSON data")
        return True
    if httpResponse.headers.get('Content-Type') == 'application/json':
        try:
            httpResponse = httpResponse.json()
            print(json.dumps(httpResponse, indent=2))
        except ValueError:
            print("Response content is not valid JSON")
    else:
        print("Response does not contain JSON data")
    return False
