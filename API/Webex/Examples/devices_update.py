from wxc_common import *

def configure_devices(orgId, httpHeaders):
    device_data = identity_choice(orgId, httpHeaders, "devices")
    if device_data is None:
        return
    n = len(device_data)

    print("Choose the feature to configure:")
    print("1. Apply changes")
    print("2. Reboot devices")
    print("9. Back to main menu")
    print("Q. Exit")

    choice = input("Enter the number of your choice: ").lower()
    
    if choice == '1':
        with alive_bar(n) as bar:
            for j in range(n):
                apiUrl = 'https://webexapis.com/v1/telephony/config/devices/' + device_data[j]["id"] + '/actions/applyChanges/invoke/?orgId=' + orgId
                body = {
                }
                if api_action("POST", apiUrl, body, httpHeaders):
                    continue
                bar()
        return None
    elif choice == '2':
        with alive_bar(n) as bar:
            for j in range(n):
                apiUrl = 'https://webexapis.com/v1/xapi/command/SystemUnit.Boot'
                body = {
                    "deviceId":device_data[j]["id"],
                    "arguments":{
                        "Action": "Restart",
                        "Force": "False"
                    }
                }
                if api_action("POST", apiUrl, body, httpHeaders):
                    continue
                bar()
        return None
    elif choice == '9':
        return None
    elif choice == 'q':
        print("Exiting")
        exit()
    else:
        print("Invalid choice")
        return None