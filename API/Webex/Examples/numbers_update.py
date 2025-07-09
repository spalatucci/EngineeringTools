import csv
from wxc_common import *

def configure_numbers(orgId, httpHeaders):
    print("Choose the feature to configure:")
    print("1. Add numbers")
    print("9. Back to main menu")
    print("Q. Exit")
    
    choice = input("Enter the number of your choice: ").lower()
    
    if choice == '1':
        csv_files = list_files('csv')
        print("Please select the CSV file:")
        selected_csv = choice_prompt(csv_files)
        file_reader = open_file(selected_csv)
        csv_headers = ["Location Name", "Number"]
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
                    "phoneNumber": format_phone_number(row["Number"])
                }
                numbers_data.append(record)
        file_reader.close()

        apiUrl = 'https://webexapis.com/v1/telephony/config/locations?orgId=' + orgId
        locations_list = api_get(apiUrl, httpHeaders)
        numbers_data = dataset_compare(numbers_data, locations_list, 'name', 'id', False)
        apiUrl = 'https://webexapis.com/v1/telephony/config/numbers?orgId=' + orgId
        numbers_list = api_get(apiUrl, httpHeaders)
        numbers_data = dataset_compare(numbers_data, numbers_list, 'phoneNumber', 'name', True)
        if numbers_data  == None:
            return None
        n = len(numbers_data)
        with alive_bar(n) as bar:
            for j in range(n):
                location_id = search_value2_by_key1_target(locations_list, "name", "id", numbers_data[j]['name'])
                apiUrl = 'https://webexapis.com/v1/telephony/config/locations/' + location_id + '/numbers?orgId=' + orgId
                body = {
                    "phoneNumbers": [numbers_data[j]['phoneNumber']]
                }
                if api_action("POST", apiUrl, body, httpHeaders):
                    print(numbers_data[j]['phoneNumber'])
                    continue
                bar()
    elif choice == '9':
        return
    elif choice == 'q':
        print("Exiting")
        exit()
    else:
        print("Invalid choice")
        return None