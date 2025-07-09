from wxc_common import *
import locations_update
import numbers_update
import users_update
import devices_update

def select_org(httpHeaders):
    apiUrl = 'https://webexapis.com/v1/organizations'
    organizations = api_get(apiUrl, httpHeaders)
    if not organizations:
        return

    org_name = input("Enter organization name: ")
    orgId = get_value2_from_key1_query(org_name, organizations,"displayName","id")
    if orgId is None:
        return
    return orgId

def main():
    access_token = input("Enter your personal access token: ")
    httpHeaders = {'Content-type': 'application/json', 'Authorization': 'Bearer ' + access_token}

    orgId = select_org(httpHeaders)

    while True:
        print("Choose the script to run:")
        print("1. Configure Locations")
        print("2. Configure Numbers")
        print("3. Configure Users")
        print("4. Configure Devices")
        print("9. Select another organization")
        print("Q. Exit")
        
        choice = input("Enter the number of your choice: ").lower()
        
        if choice == '1':
            locations_update.configure_locations(orgId, httpHeaders)
        elif choice == '2':
            numbers_update.configure_numbers(orgId, httpHeaders)
        elif choice == '3':
            users_update.configure_users(orgId, httpHeaders)
        elif choice == '4':
            devices_update.configure_devices(orgId, httpHeaders)
        elif choice == '9':
            orgId = select_org(httpHeaders)
        elif choice == 'q':
            print("Exiting")
            break
        else:
            print("Invalid choice. Exiting.")

if __name__ == "__main__":
    main()