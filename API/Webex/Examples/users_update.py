from wxc_common import *

def configure_users(orgId, httpHeaders):
    user_data = identity_choice(orgId, httpHeaders, "users")
    if user_data is None:
        return
    n = len(user_data)
    
    print("Choose the feature to configure:")
    print("1. Configure the voicemail passcode")
    print("9. Back to main menu")
    print("Q. Exit")

    choice = input("Enter the number of your choice: ").lower()
    
    if choice == '1':
        vmPasscode = input("Enter the voicemail passcode: ")
        with alive_bar(n) as bar:
            for j in range(n):
                apiUrl = 'https://webexapis.com/v1/telephony/config/people/' + user_data[j]["id"] + '/voicemail/passcode/?orgId=' + orgId
                body = {
                    "passcode": vmPasscode
                }
                if api_action("PUT", apiUrl, body, httpHeaders):
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