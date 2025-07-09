#script used to complete lab base config: configure users and set passwords
#last update: 10 May 2023
#updated to support more users for security lab
#########-START COPYING HERE TO RUN COMMANDS MANUALLY-###########
filter timestamp {"$(Get-Date -Format G): $_"}
[XML]$xml = Get-Content "c:/dcloud/session.xml"
#$vpod = $xml.session.vpod
#$owner = $xml.session.owner
#$acpassword = $xml.session.anycpwd
#$acusername = "v" + $vpod + "user1"
$id = $xml.session.id
$dc = $xml.session.datacenter

$domain = $xml.SelectNodes("//mailsrv") | select -exp domain
$code = 'None'
$v5 = Test-Path "C:\dcloud\v5"
$v6 = Test-Path "C:\dcloud\v6"
$t1 = Test-Path "C:\dcloud\t1"
$srw = Test-Path "C:\dcloud\srw"
$sec_lab = Test-Path "C:\dcloud\security_lab"

$webserver = "198.19.254.140"

function api($url, $method, $data= @{default="no data"}){
    $json = $data | ConvertTo-Json    
    if($method -eq 'POST'){
        $r = Invoke-RestMethod -Uri $url -Method $method -Body $json -ContentType "application/json" -TimeoutSec 600
    }else{
        $r = Invoke-RestMethod -Uri $url -Method $method -TimeoutSec 600
    }
    return $r
}

# function init_emails($Username){
#     #api "http://$webserver/api/v1/users/user-tasks" POST @{email="$Username@$domain";task="init_passwd_reset"}
#     api "http://$webserver/api/v1/users/user-tasks" POST @{email="$Username@$domain";task="init_user_activation"}
#     #api "http://$webserver/api/v1/users/user-tasks" POST @{email="$Username@$domain";task="init_user_verify"}
# }

#########-STOP COPYING HERE TO RUN COMMANDS MANUALLY-###########
# write-output "Creating two users for conversion." | timestamp
# init_emails "jill_user"
# init_emails "bill_user"

#Creating and setting up lab users
write-output "Creating and configuring lab users." | timestamp
write-output "This will take a few minutes or so to complete." | timestamp
write-output " "

if($sec_lab){
    $resp = api "http://$webserver/api/v1/users" POST @{domain="$domain";sessId="$id";dc="$dc";userGroup="security_lab"}
}else{
    $resp = api "http://$webserver/api/v1/users" POST @{domain="$domain";sessId="$id";dc="$dc"}
}

$resp | ConvertTo-Json | timestamp
$avatar_set = $resp.avatarSet
write-output "Total users created: "$resp.totalUsers  | timestamp
write-output "Users created: "$resp.usersConfigured   | timestamp
write-output "Avatars configured: "$avatar_set   | timestamp

if([int]$resp.totalUsers -gt 7){
     write-output "Org has more than 7 users. Continuing on."  | timestamp
}else{
    write-output "Org has less than 8 users. Pausing for 1 min and going to try and create users once more."  | timestamp
    Start-sleep 180
    if($sec_lab){
        $resp = api "http://$webserver/api/v1/users" POST @{domain="$domain";sessId="$id";dc="$dc";userGroup="security_lab"}
    }else{
        $resp = api "http://$webserver/api/v1/users" POST @{domain="$domain";sessId="$id";dc="$dc"}
    }
    $resp | ConvertTo-Json | timestamp
    $avatar_set = $resp.avatarSet
    write-output "Total users created: "$resp.totalUsers   | timestamp
    write-output "Users created: "$resp.usersConfigured   | timestamp
    write-output "Avatars configured: "$avatar_set   | timestamp
    if([int]$resp.totalUsers -gt 7){
        write-output "Org has more than 7 users. Continuing on."  | timestamp
    }else{
        write-output "Org has less than 8 users. Possible issue."  | timestamp
        $msg = "'Lab session id ["+$id+"](https://dcloud2-"+$dc+".cisco.com/session/"+$id+"?returnPathTitleKey=view-session) in " +$dc+ " with domain " + $domain + " has less than 8 users created. Users created: " + $resp.usersConfigured + ". Owner: "+$owner+", Session Name: "+$sess_name+".'"
        api "http://$webserver/api/v1/message" POST @{message="$msg"}
    }
}

$usersConfigured = $resp.usersConfigured
write-output "Setting up users complete."  | timestamp
write-output " "
write-output "Base Configuration Complete."  | timestamp
write-output " "

Start-Sleep 5
