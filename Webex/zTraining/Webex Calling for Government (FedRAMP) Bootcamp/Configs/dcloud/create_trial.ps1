#script used to create Webex trial for labs and demos
#last update: 5 October 2023

$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
Start-Transcript -path C:\dcloud\create_trial_log.txt -append
$StartTime = $(get-date)
write-output "Script started at $StartTime"
#########-START COPYING HERE TO RUN COMMANDS MANUALLY-###########
filter timestamp {"$(Get-Date -Format G): $_"}
$full_lab = Test-Path "C:\dcloud\full_lab"
$v5 = Test-Path "C:\dcloud\v5"
$v6 = Test-Path "C:\dcloud\v6"
$v7 = Test-Path "C:\dcloud\v7"
$t1 = Test-Path "C:\dcloud\t1"
$wxcc = Test-Path "C:\dcloud\wxcc"
$webex_tsw = Test-Path "C:\dcloud\webex_tsw"
$twc_demo = Test-Path "C:\dcloud\twc"
$cloudlock = Test-Path "C:\dcloud\cloudlock"
$pstn = Test-Path "C:\dcloud\pstn"
$sec_lab = Test-Path "C:\dcloud\security_lab"
$call_lab = Test-Path "C:\dcloud\call_lab"
$general = Test-Path "C:\dcloud\general" #use for labs/demos that just need a webex org (Message/Call/Meet) with 8 users.
$call_lab2 = Test-Path "C:\dcloud\call_lab2"
$intro_lab = Test-Path "C:\dcloud\intro_lab" #does not get webex calling configured but configures meeting site
$latc = Test-Path "C:\dcloud\latc" #for Learning @ Cisco
$gdoat = Test-Path "C:\dcloud\gdoat"
$srw = Test-Path "C:\dcloud\srw" #for secure remote worker demo
$sase = Test-Path "C:\dcloud\sase" #for SASE demo
$code = 'None'
$msg = 'None'
$sess_name = 'None' 
$sess_status = 'None'
$cbnum = '4175551234' #fake number so calling gets configured
$alt_pat_order = $False

[XML]$xml = Get-Content "c:/dcloud/session.xml"
$vpod = $xml.session.vpod
$owner = $xml.session.owner
$acpassword = $xml.session.anycpwd
$acusername = "v" + $vpod + "user1"
$id = $xml.session.id
$dc = $xml.session.datacenter
$domain = $xml.SelectNodes("//mailsrv") | select -exp domain

$webserver = "198.19.254.140"
$last4 = $id.substring($id.length - 4, 4)
$webex_password = 'dCloud'+$last4+'!'

if($srw){
    $exc_ip = "198.18.6.2"
}else{
    $exc_ip = "198.18.133.2"
}

function api($url, $method, $data= @{default="no data"}){
    $json = $data | ConvertTo-Json    
    if($method -eq 'POST'){
        $r = Invoke-RestMethod -Uri $url -Method $method -Body $json -ContentType "application/json" -TimeoutSec 900
    }else{
        $r = Invoke-RestMethod -Uri $url -Method $method -TimeoutSec 900
    }
    return $r
}

if($v6){
    $cubenatip = $xml.SelectNodes("//translation[inside='198.18.1.231']") | select -exp outside
}

if (!$intro_lab -and !$latc -and !$gdoat -and !$srw -and !$general){
    $xmlDevices = $xml.SelectNodes("/session/devices/device")

    Foreach ($xmlDevice in $xmlDevices) {
        $device = ($xmlDevice | Where-Object {$_.Name -Match "^830.*" })
        if ($device.name -like "830*") {$cbnum = $device.name}  
    }
}

if ($latc){
    $xmlDevices = $xml.SelectNodes("/session/devices/device")

    Foreach ($xmlDevice in $xmlDevices) {
        $device = ($xmlDevice | Where-Object {$_.Name -Match "^198.*" })
        if ($device.name -like "198*") {$devip = $device.name}  
    }
}

Write-Host "Getting session details"
$resp = api "http://$webserver/api/v1/dcloud/session-details" POST @{sessId="$id";dc="$dc"}
$resp | ConvertTo-Json | timestamp
$sess_name = $resp.name 
$sess_status = $resp.status

if ($sess_status -eq 5 -or $sess_status -eq 7){
    Write-Host "Session shutting down. Ending Script"
    exit
}

$domain = $xml.SelectNodes("//mailsrv") | select -exp domain

if($domain -eq $Null){
    $msg = "'Webex session id ["+$id+"](https://dcloud2-"+$dc+".cisco.com/session/"+$id+"?returnPathTitleKey=view-session) in " +$dc+ " could not run setup script due to domain being empty. Setup script halted. Owner: "+$owner+", Session Name: "+$sess_name+".'"
    api "http://$webserver/api/v1/message" POST @{message="$msg"}
    Send-MailMessage -To cholland@dcloud.cisco.com -From cholland@dcloud.cisco.com -Subject "WEBEX TRIAL COULD NOT START" -Body "The Webex trial could not be started. The dCloud support team has been notified. Unfortunately you will need to re-schedule another lab. We appologize for the inconvenience.  -dCloud Collab Team" -SmtpServer mail1.dcloud.cisco.com
    exit 
}

if ($latc -or $v5 -or $v6 -or $v7 -or $t1 -or $srw -or $gdoat -or $wxcc){
        $Password = "dCloud123!"
        $exc_pass = "dCloud123!"
    }elseif ($twc_demo) {
        $Password = "dCloud12345!"
        $exc_pass = "dCloud12345!"
    }else{
        $Password = "C1sco12345"
        $exc_pass = "C1sco12345"
    }
# $GLOBAL:cpassfail = $False
#run base setup if owner is listed
$base_setup = $false
if ($call_lab -or $call_lab2 -or $webex_tsw -or $v5 -or $v6 -or $t1 -or $srw -or $gdoat -or $sec_lab -or $twc_demo -or $full_lab -or $wxcc -or $general){$base_setup = $true}

function webex_api($access_token, $url, $method, $data= @{default="no data"}){
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
    $json = $data | ConvertTo-Json
    $header = @{"Authorization" = "Bearer "+$access_token}     
    if($method -eq 'POST'){
        $r = Invoke-RestMethod -Uri $url -Method $method -Header $header -Body $json -ContentType "application/json"
    }else{
        $r = Invoke-RestMethod -Uri $url -Method $method -Header $header -ContentType "application/json"
    }
    return $r
}

function delete_trial(){
    write-output "Sending trial delete." | timestamp
    api "http://$webserver/api/v1/trials/trial-tasks" POST @{domain="$domain";sessId="$id";dc="$dc";task="delete_trial"} 
}

#########-STOP COPYING HERE TO RUN COMMANDS MANUALLY-###########


if ($gdoat -or $sase){
    write-output "Creating customer trial without Webex meetings, please wait. Trial creation will take a bit to complete." | timestamp
    write-output " "
    $resp = api "http://$webserver/api/v1/trials" POST @{domain="$domain";sessId="$id";dc="$dc";meet="false"}
}elseif ($wxcc){
    write-output "Creating customer trial with  WxCC name and Webex meetings, please wait. Trial creation will take a bit to complete." | timestamp
    write-output " "
    $resp = api "http://$webserver/api/v1/trials" POST @{domain="$domain";sessId="$id";dc="$dc";meet="true";wxcc="true"}
}else{
    write-output "Creating customer trial with Webex meetings, please wait. Trial creation will take a bit to complete." | timestamp
    write-output " "
    $resp = api "http://$webserver/api/v1/trials" POST @{domain="$domain";sessId="$id";dc="$dc";meet="true"}
}
$resp | ConvertTo-Json | timestamp
if ($resp.result -ne 'success'){
    write-output "Could not create Webex trial. Going to try to delete and create on more time." | timestamp
    Start-Sleep 10
    delete_trial
    write-output "Pausing for a minute after delete" | timestamp
    Start-sleep 60
    $inbox.Empty([Microsoft.Exchange.WebServices.Data.DeleteMode]::SoftDelete,$True)
    write-output "Trying to create trial one more time" | timestamp
    if ($gdoat -or $sase){
        $resp = api "http://$webserver/api/v1/trials" POST @{domain="$domain";sessId="$id";dc="$dc";meet="false"}
    }elseif ($wxcc){
        write-output "Creating customer trial with  WxCC name and Webex meetings, please wait. Trial creation will take a bit to complete." | timestamp
        write-output " "
        $resp = api "http://$webserver/api/v1/trials" POST @{domain="$domain";sessId="$id";dc="$dc";meet="true";wxcc="true"}
    }else{
        $resp = api "http://$webserver/api/v1/trials" POST @{domain="$domain";sessId="$id";dc="$dc";meet="true"}
    }
    $resp | ConvertTo-Json | timestamp
    if ($resp.result -ne 'success'){
        write-output "Failed to create trial on the last attempt. Setup cannot continue." | timestamp
        write-output "Attempting to delete org if exists." | timestamp
        delete_trial
        $resp = api "http://$webserver/api/v1/dcloud/session-reset" POST @{sessId="$id";dc="$dc"}
        $resp | ConvertTo-Json | timestamp
        $status = $resp.success
        while ($status -ne $True){
            write-output "dCloud session could not be reset"
            Start-Sleep 20
            $resp = api "http://$webserver/api/v1/dcloud/session-reset" POST @{sessId="$id";dc="$dc"}
            $resp | ConvertTo-Json | timestamp
            $status = $resp.success
        }
        $msg = "'Webex lab session id ["+$id+"](https://dcloud2-"+$dc+".cisco.com/session/"+$id+"?returnPathTitleKey=view-session) in " +$dc+ " with domain " + $domain + " could not create trial. Setup script halted. dCloud session reset: "+$status+". Owner: "+$owner+", Session Name: "+$sess_name+".'"
        api "http://$webserver/api/v1/message" POST @{message="$msg"}
        exit 
    }
}else{
    write-output "Customer trial created successfully." | timestamp
    Start-Sleep 5
}
if ($cloudlock){
    $resp = api "http://$webserver/api/v1/trials/trial-tasks" POST @{domain="$domain";sessId="$id";dc="$dc";task="enable_cloudlock"}
    $resp | ConvertTo-Json | timestamp
}
$webex_url = $resp.webexUrl
write-output "Pausing for 3 minutes to wait for trial to be setup" | timestamp
Start-Sleep 180
$calling_configured = 'None'
if ($full_lab -or $v5 -or $v6 -or $v7 -or $t1 -or $webex_tsw -or $call_lab -or $call_lab2 -or $wxcc -or $general){
    write-output "Configuring Webex Calling." | timestamp
    write-output " "
    $resp = api "http://$webserver/api/v1/calling" POST @{domain="$domain";sessId="$id";dc="$dc"}
    $resp | ConvertTo-Json | timestamp
    if ($resp.result -ne 'success'){
        write-output "Webex Calling did not get setup correctly.  Going to pause 1 min and try again." | timestamp
        Start-Sleep 60
        write-output "Configuring Webex Calling." | timestamp
        $resp = api "http://$webserver/api/v1/calling" POST @{domain="$domain";sessId="$id";dc="$dc"}
        $resp | ConvertTo-Json | timestamp
        if ($resp.result -ne 'success'){
            write-output "Webex Calling did not get setup correctly for a second time.  Script will continue and try again a few more times at the end of the script." | timestamp
            $calling_configured = $False
        }     
    }
}

write-output "Setting org features." | timestamp
$resp = api "http://$webserver/api/v1/trials/trial-tasks" POST @{domain="$domain";sessId="$id";dc="$dc";task="set_org_feat"}
$resp | ConvertTo-Json | timestamp


if (!$intro_lab -and !$gdoat -and !$srw -and !$sec_lab -and !$wxcc -and !$sase -and  !$general){
    write-output "Configure DID to DN text document" | timestamp

    function did($num){
        $did = $xml.SelectNodes("//dids/did[name='DID$num']") | select -exp number
        $did = $did -replace '\s',''
        $did = $did -replace '-',''
        
        if ($dc -eq "SJC"  -Or $dc -eq "RTP" ) {
            $country = "+1"
            $did = $country+$did
        }
        $did
    }
    $did1 = did "1"
    $did2 = did "2"
    $did3 = did "3"
    $did4 = did "4"
    $did5 = did "5"
    $did6 = did "6"
    $did7 = did "7"
    $did8 = did "8"
    $did9 = did "9"
    $did10 = did "10"

    $file_path = 'C:\Users\cholland\Desktop\DN_to_DID.txt'
    if($v6){
        $file_path = 'C:\Users\cholland\Desktop\Lab_info.txt'
    } 
    'DN to DID Mappings' | Out-File $file_path
    '' | Out-File $file_path -Append

    if ($call_lab -eq $True -or $call_lab2 -eq $True){

        '6016 - ' + $did7 | Out-File $file_path -Append
        '6017 - ' + $did8 + ' - Anita Perez' | Out-File $file_path -Append
        '6018 - ' + $did9 + ' - Charles Holland' | Out-File $file_path -Append
        '6019 - ' + $did10 | Out-File $file_path -Append
        '6020 - ' + $did5 | Out-File $file_path -Append
        '6021 - ' + $did2 + ' - Taylor Bard'| Out-File $file_path -Append
        '6022 - ' + $did3 + ' - Rebekah Barretta'| Out-File $file_path -Append
        '6023 - ' + $did4 + ' - Kellie Melby'| Out-File $file_path -Append
        '7019 - ' + $did6 | Out-File $file_path -Append
        '7800 - ' + $did1 | Out-File $file_path -Append

        write-output "Moving LGW Config to Desktop" | timestamp
        
        if ($call_lab){
            Move-Item -Path 'C:\dcloud\LGW_Config_wco.txt' -Destination 'C:\Users\cholland\Desktop\LGW_Config.txt'
        }else{
            Move-Item -Path 'C:\dcloud\LGW_Config_wco2.txt' -Destination 'C:\Users\cholland\Desktop\LGW_Config.txt'
        }
    }elseif($general){
        write-output "Skipping text doc creation." | timestamp
    }else{

        'Hybrid Calling:' | Out-File $file_path -Append
        'Charles Holland - x6018 - ' + $did9 | Out-File $file_path -Append
        'Anita Perez - x6017 - ' + $did8 | Out-File $file_path -Append
        'Hybrid Device - x7800 - ' + $did1 | Out-File $file_path -Append
        '' | Out-File $file_path -Append

        'Webex Calling:' | Out-File $file_path -Append
        'Auto Attendant - 86020 - ' + $did5 | Out-File $file_path -Append
        'Taylor Bard - 86021 - ' + $did2 | Out-File $file_path -Append
        'Rebekah Barretta - 86022 - ' + $did3 | Out-File $file_path -Append
        'External Caller - 86023 - ' + $did4 | Out-File $file_path -Append

        if($v6){
            '' | Out-File $file_path -Append
            'Cube Public IP - ' + $cubenatip | Out-File $file_path -Append
            'Webex Meeting Site Name - ' + $webex_url | Out-File $file_path -Append
            'Expressway-E Password - ' + $acpassword | Out-File $file_path -Append
            'Domain - ' + $domain | Out-File $file_path -Append
            'Webex password - ' + $webex_password | Out-File $file_path -Append
            Move-Item -Path 'C:\dcloud\EA_CUBE_Config.txt' -Destination 'C:\Users\cholland\Desktop\EA_CUBE_Config.txt'
            (Get-Content 'C:\Users\cholland\Desktop\EA_CUBE_Config.txt').replace('<public-ip>', $cubenatip) | Set-Content 'C:\Users\cholland\Desktop\EA_CUBE_Config.txt' 
            
            $pubkey1 = Get-Content 'C:\Users\cholland\Desktop\certs\pubkey1.pem'
            $privkey1 = Get-Content 'C:\Users\cholland\Desktop\certs\privkey1-rsa.pem'
            $lecacert = Get-Content 'C:\Users\cholland\Desktop\certs\chain.pem'
            $cubecert = Get-Content 'C:\Users\cholland\Desktop\certs\cert.pem'

            $file_path = 'C:\Users\cholland\Desktop\CUBE_CERTs.txt'
            'CUBE CERTIFICATE OPERATIONS' | Out-File $file_path
            '' | Out-File $file_path -Append
            'crypto key import rsa CUBE_PEM exportable pem encryption terminal dCloud123!' | Out-File $file_path -Append
            '' | Out-File $file_path -Append
            'PUBLIC:' | Out-File $file_path -Append
            $pubkey1  | Out-File $file_path  -Append
            '' | Out-File $file_path -Append
            'PRIVATE:' | Out-File $file_path -Append
            $privkey1  | Out-File $file_path  -Append
            '' | Out-File $file_path -Append
            '' | Out-File $file_path -Append
            'crypto pki import CUBE_CA_CERT pem terminal password dCloud123!' | Out-File $file_path -Append
            '' | Out-File $file_path -Append
            'LETS ENCRYPT CERT:' | Out-File $file_path -Append
            $lecacert  | Out-File $file_path  -Append
            '' | Out-File $file_path -Append
            'PRIVATE:' | Out-File $file_path -Append
            $privkey1  | Out-File $file_path  -Append
            'quit' | Out-File $file_path -Append
            '' | Out-File $file_path -Append
            'CUBE SIGNED CERT:' | Out-File $file_path -Append
            $cubecert  | Out-File $file_path  -Append
            '' | Out-File $file_path -Append
            '' | Out-File $file_path -Append
            'ip http secure-server' | Out-File $file_path -Append
            'ip http secure-trustpoint CUBE_CA_CERT' | Out-File $file_path -Append

        }
        
        write-output "Moving LGW Config to Desktop" | timestamp
        
        if($t1){
            Move-Item -Path 'C:\dcloud\LGW_Config_tra1.txt' -Destination 'C:\Users\cholland\Desktop\LGW_Config.txt'
        }elseif($v6){
            Move-Item -Path 'C:\dcloud\LGW_Config_v6.txt' -Destination 'C:\Users\cholland\Desktop\LGW_Config.txt'
        }else{
            Move-Item -Path 'C:\dcloud\LGW_Config.txt' -Destination 'C:\Users\cholland\Desktop\LGW_Config.txt'
        }
    }
}

#adding dCloud password to all users desktop
$file_path = 'C:\Users\Public\Desktop\WEBEX_PASSWORD.txt'
'Password for all Webex users:' | Out-File $file_path
'' | Out-File $file_path -Append
$webex_password | Out-File $file_path -Append

if ($v5 -or $v6 -or $t1 -or $sec_lab -or $wxcc) {
    #Sending email to Charles to use for trial creations
    $trialemail = Get-Content \\$exc_ip\c$\TRIAL_EMAIL.txt -Raw
    $trialemail = $trialemail.Trim()
    Send-MailMessage -To cholland@dcloud.cisco.com -From cholland@dcloud.cisco.com -Subject "CLOUD TRIALS EMAIL ADDRESS: $trialemail" -Body "Use the following email address when signing up for cloud trials: $trialemail" -BodyAsHtml -SmtpServer mail1.dcloud.cisco.com
}

if ($full_lab -or $intro_lab -or $webex_tsw -or $twc_demo){

write-output "Ready to sync Unified CM with Active Directory" | timestamp
[System.Net.ServicePointManager]::Expect100Continue = $false

$os = Get-WmiObject win32_operatingsystem

$body = @'
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns="http://www.cisco.com/AXL/API/12.0">
   <soapenv:Header/>
   <soapenv:Body>
      <ns:doLdapSync sequence="1">
         <name>ad1</name>
         <sync>true</sync>
      </ns:doLdapSync>
   </soapenv:Body>
</soapenv:Envelope>
'@

$pwd = ConvertTo-SecureString "dCloud123!" -AsPlainText -Force
$cred = New-Object Management.Automation.PSCredential ('Administrator', $pwd)

Invoke-RestMethod -Method Post `
-ContentType "text/xml" -Body $body `
-Credential $cred `
-Uri https://cucm1.dcloud.cisco.com:8443/axl/    

write-output "Sync Complete" | timestamp
Start-Sleep 5

}

if ($full_lab -or $intro_lab -or $webex_tsw -or $twc_demo -or $sec_lab){

    $lic_url = "http://$webserver/collab/esxi6_lic.txt"
    $lic_txt = "C:\dcloud\lic.txt"
    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile($lic_url, $lic_txt)
    $lic = Get-Content $lic_txt
    Remove-Item $lic_txt

    $node1 = "198.18.134.47"
    write-output  "Updating ESXi license of $node1." | timestamp

    connect-viserver $node1 -user root -password dCloud123! -Force

    $lm = Get-View -Id "LicenseManager-ha-license-manager"
    $lm.UpdateLicense($lic, $null)
    write-output  "Completed the license update of node: $node1." | timestamp
    disconnect-viserver $node1 -confirm:$false

}

if ($webex_tsw){

    api "http://$webserver/api/v1/trials/trial-tasks" POST @{domain="$domain";sessId="$id";dc="$dc";task="get_webex_url"}

    write-output "Configure Lab Info text document" | timestamp
    $file_path = 'C:\Users\cholland\Desktop\Lab_Info.txt'
    'Lab Session Information' | Out-File $file_path
    '' | Out-File $file_path -Append

    'Session Domain: ' +$domain | Out-File $file_path -Append
    '' | Out-File $file_path -Append

    'Scenario 1 Webex Control Hub:' | Out-File $file_path -Append
    'Charles Holland Webex Login: cholland@' +$domain+ ' / dCloud123!' | Out-File $file_path -Append
    
    '' | Out-File $file_path -Append
    'Scenario 2 Webex Edge (Audio):' | Out-File $file_path -Append
    'Webex Meeting Site URL: ' +$webex_url | Out-File $file_path -Append
    
    '' | Out-File $file_path -Append
    'Expressway-C Traversal Client Zone: vcse.' +$domain | Out-File $file_path -Append

    '' | Out-File $file_path -Append
    'Expressway-E Call Routing Pattern String: (.*)@mtls.' +$domain+ ';.*x-cisco-webex-service=audio' | Out-File $file_path -Append

    '' | Out-File $file_path -Append
    'Expressway-E Call Routing Replace String: \1@' +$domain | Out-File $file_path -Append

    '' | Out-File $file_path -Append
    'Edge Audio CallBack DNS SRV: mtls.' +$domain | Out-File $file_path -Append

    '' | Out-File $file_path -Append
    'Scenario 3 Hybrid Calendar Service (Exchange):' | Out-File $file_path -Append
    'Expressway-C Connector Host: exp-cc.dcloud.cisco.com' | Out-File $file_path -Append

    '' | Out-File $file_path -Append
    'Room Device Mail Box: webexrd@' +$domain | Out-File $file_path -Append

    '' | Out-File $file_path -Append
    'Scenario 4 Webex Hybrid Calling for Devices:' | Out-File $file_path -Append
    'Expressway-C Traversal Client Zone: vcse.' +$domain | Out-File $file_path -Append

}

if($wxcc){   
    write-output "Adding WxCC trial." | timestamp 
    $resp = api "http://$webserver/api/v1/wxcc" POST @{domain="$domain";sessId="$id";dc="$dc"}
    Copy-Item -Path 'C:\dcloud\sync_wxcc.ps1' -Destination 'C:\Users\cholland\Desktop\sync_wxcc.ps1'
}
# if($pstn){   
#     write-output "Adding PSTN location to trial." | timestamp 
#     $resp = api "http://$webserver/api/v1/calling" POST @{domain="$domain";sessId="$id";dc="$dc";feature="pstn"}
# }

if ($base_setup){   
    write-output "Starting Complete Base Config Script" | timestamp 
    Invoke-Expression c:\dcloud\complete_base_config.ps1
}


if ($latc){
    #Create Webex Full Admin, set password, and create lab info doc on Student WS desktop
    write-output "Creating Student admin for DEVWBX." | timestamp
    $resp = api "http://$webserver/api/v1/users" POST @{domain="$domain";sessId="$id";dc="$dc";userName="student";firstName="Student";lastName="Admin";privType="compliance"}
    $resp | ConvertTo-Json | timestamp
    $resp = api "http://$webserver/api/v1/trials/trial-tasks" POST @{domain="$domain";sessId="$id";dc="$dc";task="set_org_feat";userName="student";password="C0ll@B123"}
    $resp | ConvertTo-Json | timestamp   
    $resp = api "http://$webserver/api/v1/users/access-token" POST @{email="student@$domain";userType="dev";password="C0ll@B123"}
    $access_token = $resp.access_token
    Write-Host "Webex Access Token: "$access_token
    $resp = webex_api $access_token "https://webexapis.com/v1/rooms" POST @{title="MyRoom2"}
    $resp | ConvertTo-Json | timestamp  
    $resp = webex_api $access_token "https://webexapis.com/v1/rooms" POST @{title="MyRoom1"}
    $resp | ConvertTo-Json | timestamp
    
    write-output "Email received for Student. Password was set." | timestamp
    write-output "Configure Lab Info text document" | timestamp
    
    $ws_userName = "student-vm-1\student"
    $ws_password = "C0ll@B123"
    $secPassword = ConvertTo-SecureString $ws_password -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($ws_userName, $secPassword)

    New-PSDrive -Name studentws -PSProvider FileSystem -Credential $cred -Root \\198.18.133.37\Desktop

    'Lab Pod Information' | Out-File studentws:\Lab_Pod_Info.txt
    '' | Out-File studentws:\Lab_Pod_Info.txt -Append

    'Webex Email: student@'+$domain | Out-File studentws:\Lab_Pod_Info.txt -Append
    'Webex Password: C0ll@B123' | Out-File studentws:\Lab_Pod_Info.txt -Append
    'Device IP: '+$devip | Out-File studentws:\Lab_Pod_Info.txt -Append
    'Webex Meeting Site Name: '+$webex_url | Out-File studentws:\Lab_Pod_Info.txt -Append
    'Test Account Username/Password: cholland@'+$domain+'/dCloud123!' | Out-File studentws:\Lab_Pod_Info.txt -Append
    '' | Out-File studentws:\Lab_Pod_Info.txt -Append
    $dev4oct = $devip.split('.')[3]
    write-output "Getting activation code for endpoint with ip $devip." | timestamp
    $resp = api "http://$webserver/api/v1/devices/place" POST @{domain="$domain";sessId="$id";dc="$dc";deviceName="Pod Video Endpoint $dev4oct"}
    $resp | ConvertTo-Json | timestamp
    if ($resp.result -ne 'success'){
        write-output "Failed to get activation code. Trying once more." | timestamp
        $resp = api "http://$webserver/api/v1/devices/place" POST @{domain="$domain";sessId="$id";dc="$dc";deviceName="Pod Video Endpoint $dev4oct"}
        $resp | ConvertTo-Json | timestamp
        if ($resp.result -ne 'success'){
            write-output "Failed to get activation code again." | timestamp
            $msg = "'DEVWBX lab session id ["+$id+"](https://dcloud2-"+$dc+".cisco.com/session/"+$id+"?returnPathTitleKey=view-session) in " +$dc+ " with domain " + $domain + " and endpoint IP " + $dev4oct + " could not get activation code after two tries. Please check session. Owner: "+$owner+".'"
            api "http://$webserver/api/v1/message" POST @{message="$msg"}
        }
    }
    if ($resp.result -eq 'success'){
        $acode = $resp.activationCode
        write-output "Configuring video endpoint with ip $devip and registering to Webex with activation code $acode." | timestamp
        $resp = api "http://$webserver/api/v1/devices/latcep" POST @{domain="$domain";sessId="$id";dc="$dc";ip="$devip";code="$acode"}
        $resp | ConvertTo-Json | timestamp
        if ($resp.result -ne 'success'){
            write-output "Failed to register endpoint. Trying once more." | timestamp
            $resp = api "http://$webserver/api/v1/devices/latcep" POST @{domain="$domain";sessId="$id";dc="$dc";ip="$devip";code="$acode"}
            $resp | ConvertTo-Json | timestamp
            if ($resp.result -ne 'success'){
                write-output "Failed to register endpoint again." | timestamp
                $msg = "'DEVWBX lab session id ["+$id+"](https://dcloud2-"+$dc+".cisco.com/session/"+$id+"?returnPathTitleKey=view-session) in " +$dc+ " with domain " + $domain + " and endpoint IP " + $dev4oct + " could not register video endpoint after two tries. Please check session. Owner: "+$owner+".'"
                api "http://$webserver/api/v1/message" POST @{message="$msg"}
            }
        }
    }else{
        write-output "Could not configure endpoint $devip due to not being able to get activation code in previous step." | timestamp
    }
}
if ($calling_configured -eq $False){
    $counter = 0 
    while ($calling_configured -eq $False){       
        if ($counter -eq 3){
            write-output "Could not configure Webex Calling after serveral tries. Script will not try again. Will need to be tried again later with script if possible." | timestamp
            Start-Sleep 1
            Move-Item -Path 'C:\dcloud\config_calling.ps1' -Destination 'C:\Users\cholland\Desktop\config_calling.ps1'
            Send-MailMessage -To cholland@dcloud.cisco.com -From cholland@dcloud.cisco.com -Subject "WEBEX LAB WARNING" -Body "Webex Calling could not be setup. The dCloud support team has been notified. Please see the text document (ERROR_WEBEX_CALLING.txt) on the desktop to find next steps. We appologize for the inconvenience.  -dCloud Collab Team" -SmtpServer mail1.dcloud.cisco.com
            $file_path = 'C:\Users\cholland\Desktop\ERROR_WEBEX_CALLING.txt'
            'Unfortunately Webex Calling was not setup properly. It maybe possible to try the setup again by following the steps below.' | Out-File $file_path
            '' | Out-File $file_path -Append
            'Before starting check https://status.broadsoft.com to see if there are any reported ongoing maintenaces or system issues.' | Out-File $file_path -Append
            'If there are, then this is why Webex Calling was not setup.  You will need to wait till those are resolved before continuing.' | Out-File $file_path -Append
            'If there are no ongoing maintenaces or system issues then you can try the next steps.' | Out-File $file_path -Append
            '' | Out-File $file_path -Append
            '1. Find the file named config_calling.ps1 on the Desktop' | Out-File $file_path -Append
            '2. Right click on the file and choose "Run with Powershell" from the menu.' | Out-File $file_path -Append
            '3. Wait.' | Out-File $file_path -Append
            '' | Out-File $file_path -Append
            'If you see the message "Webex Calling Setup Completed Successfully" then setup should have finished successfully and you can try to use Webex Calling again.' | Out-File $file_path -Append
            '' | Out-File $file_path -Append
            'If you see the message "Webex Calling Setup Failed" then setup failed again. There could be system issues preventing configuraiton to be completed.' | Out-File $file_path -Append
            'Unfortunately those issues are out of our control. You will need to check the status of Broadcloud at status.broadsoft.com' | Out-File $file_path -Append
            ' to see if there are any on going maintenaces or system issues.  If there are you will need to wait and try again.' | Out-File $file_path -Append
            $msg = "'Webex lab session id ["+$id+"](https://dcloud2-"+$dc+".cisco.com/session/"+$id+"?returnPathTitleKey=view-session) in " +$dc+ " with domain " + $domain + " could not configure Webex Calling after several tries. Owner: "+$owner+", Session Name: "+$sess_name+".'"
            api "http://$webserver/api/v1/message" POST @{message="$msg"}
            break
        }
        write-output "Configuring Webex Calling again." | timestamp
        $resp = api "http://$webserver/api/v1/calling" POST @{domain="$domain";sessId="$id";dc="$dc"}
        $resp | ConvertTo-Json | timestamp
        if ($resp.result -eq 'success'){
            write-output "Configured Webex Calling succesfully." | timestamp
            $calling_configured -eq $True
            break
        }else{
            write-output "Configuring Webex Calling failed again. Pausing for 3 minutes" | timestamp
            Start-Sleep 180
        }
        $counter ++
    }
}

if ($twc_demo){
    if ($twc_demo){
        $extra_users = @("mcheng", "amckenzie")
        $person = "Venky"
    }
    foreach ($Username in $extra_users){
        if ($Username -eq "mcheng"){
            $firstname = "Monica"
            $lastname = "Cheng"
        }elseif ($Username -eq "amckenzie") {
            $firstname = "Adam"
            $lastname = "McKenzie"
        }
        write-output "Creating $firstname $lastname for $person because he insists on having extra users :)." | timestamp
        $resp = api "http://$webserver/api/v1/users" POST @{domain="$domain";sessId="$id";dc="$dc";userName="$Username";firstName=$firstname;lastName=$lastname;privType="user"}
        $resp | ConvertTo-Json | timestamp
    } 
    #Venky Changes for TWC 14.0 demo
    $wbxpwd = $webex_password
    #Getting the Access token for Charles
    $resp = api "http://$webserver/api/v1/users/access-token" POST @{email="cholland@$domain";userType="admin";password="$wbxpwd"}
    $resp | ConvertTo-Json
    $resp.access_token

    #Creating Header
    $headers = @{
    Authorization = "Bearer "+$resp.access_token
                }
    #Sending GET request to get Org ID
    $cust = api "http://$webserver/api/v1/trials/$domain" GET 
    $orgid = $cust.organizations.customerOrgId

    #generating random UUIDs
    $guid1 = New-Guid
    $guid2 = New-Guid
    $guid3 = New-Guid

    #Body for the custom shortcuts
    $body = "{`"key`":`"custom_shortcuts`",`"orgId`":`"$orgid`",`"value`":[{`"id`":`"$guid1`",`"url`":`"https://imagicle.dcloud.cisco.com:443/jabber/stonefax`",`"appId`":`"ciscospark://us/APPLICATION/4e7e5328-cb08-44c6-9146-d7230bd89e3a`",`"title`":`"Imagicle StoneFax`",`"favicon`":{`"icon`":`"browser_20`",`"color`":`"violet`"},`"assignment`":`"ORG`"},{`"id`":`"$guid2`",`"url`":`"https://imagicle.dcloud.cisco.com:443/jabber/BudgetControl`",`"appId`":`"ciscospark://us/APPLICATION/4e7e5328-cb08-44c6-9146-d7230bd89e3a`",`"title`":`"Imagicle Budget Control`",`"favicon`":{`"icon`":`"pie-chart_16`",`"color`":`"pink`"},`"assignment`":`"ORG`"},{`"id`":`"$guid3`",`"appId`":`"ciscospark://us/APPLICATION/4e7e5328-cb08-44c6-9146-d7230bd89e3a`",`"title`":`"Imaglice Call Recording`",`"url`":`"https://imagicle.dcloud.cisco.com:443/jabber/CallRecording`",`"assignment`":`"ORG`",`"favicon`":{`"icon`":`"link_24`",`"color`":`"orange`"}}]}"

    #Creating the custom shortcuts
    $url = "https://settings-service-r.wbx2.com/settings-service/api/v1/orgsettings/orgs/$orgid/"
    $response = Invoke-RestMethod -uri $url -Method 'POST' -Headers $headers -Body $body -ContentType "application/json"
    $response | ConvertTo-Json

    #Body for the custom short cuts list
    $body = "{`"key`":`"custom_shortcuts_org_preference`",`"entityId`":`"$orgid`",`"entityType`":`"ORG`",`"value`":[`"$guid1`",`"$guid2`",`"$guid3`"]}"

    #Updating the list
    $url = "https://settings-service-r.wbx2.com/settings-service/api/v1/orgsettings/valueOp/$orgid/UPDATE"
    $response = Invoke-RestMethod -uri $url -Method 'PUT' -Headers $headers -Body $body -ContentType "application/json"
    $response | ConvertTo-Json

    #Body for setting the Calling Behavior
    $body = "{`n    `"callingBehavior`": `"NATIVE_SIP_CALL_TO_UCM`",`n    `"callingBehaviorTemplate`": `"`"`n}"

    #Setting the Calling Behavior to Calling in Webex (Unified CM) - Org Level
    $url = "https://atlas-a.wbx2.com/admin/api/v1//organizations/$orgid/settings/callingBehavior"
    $response = Invoke-RestMethod -uri $url -Method 'PUT' -Headers $headers -Body $body -ContentType "application/json"
    $response | ConvertTo-Json 
}
if ($sase){
    if ($sase){
        $extra_users = @("karen", "bob", "gary")
    }
    foreach ($Username in $extra_users){
        if ($Username -eq "karen"){
            $firstname = "Karen"
            $lastname = "Johnson"
        }elseif ($Username -eq "bob") {
            $firstname = "Bob"
            $lastname = "Sinclar"
        }elseif ($Username -eq "gary") {
            $firstname = "Gary"
            $lastname = "Smith"
        }
        write-output "Creating $firstname $lastname for SASE lab." | timestamp
        $resp = api "http://$webserver/api/v1/users" POST @{domain="$domain";sessId="$id";dc="$dc";userName="$Username";password="C1sco12345!";firstName=$firstname;lastName=$lastname;privType="admin"}
        $resp | ConvertTo-Json | timestamp
    } 
}

if($avatar_set -eq "false"){
    write-output "Trying to set avatars once more" | timestamp
    $resp = api "http://$webserver/api/v1/users" POST @{domain="$domain";sessId="$id";dc="$dc";userName="fixpics"}
    $resp | ConvertTo-Json | timestamp
}

if($v6){
    Write-Host "Powering on the Edge Audio Cube"
    $resp = api "http://$webserver/api/v1/dcloud/server" POST @{sessId="$id";dc="$dc";vmName="cube_ea";action="on"}
    $resp | ConvertTo-Json | timestamp
}

if($v7){
    Write-Host "Moving O365 Powershell script to desktop"
    Move-Item -Path 'C:\dcloud\O365_Lic.ps1' -Destination 'C:\Users\cholland\Desktop\O365_Lic.ps1'
}

if($t1){
    Write-Host "Moving Add Trunk Powershell script and LGW Config to desktop"
    Copy-Item "C:\dcloud\Add_Trunk.ps1" -Destination "C:\Users\cholland\Desktop\Add_Trunk.ps1" -Force
    Copy-Item "C:\dcloud\LGW_Config_t1.txt" -Destination "C:\Users\cholland\Desktop\LGW_Config.txt" -Force
    Copy-Item 'C:\dcloud\LGW_Config_HC.txt' -Destination 'C:\Users\cholland\Desktop\LGW_Config_HC.txt' -Force
    Copy-Item 'C:\dcloud\Randon_Num.ps1' -Destination 'C:\Users\cholland\Desktop\Randon_Num.ps1' -Force
    Copy-Item 'C:\dcloud\get_at_orgid.ps1' -Destination 'C:\Users\cholland\Desktop\get_at_orgid.ps1' -Force
    Copy-Item 'C:\dcloud\Bulk_Assign_Licenses.ps1' -Destination 'C:\Users\cholland\Desktop\Bulk_Assign_Licenses.ps1' -Force
}

if ($sec_lab) {
    
    write-output "Setting org features for Anita." | timestamp
    $resp = api "http://$webserver/api/v1/trials/trial-tasks" POST @{domain="$domain";sessId="$id";dc="$dc";task="set_org_feat";userName="aperez"}
    $resp | ConvertTo-Json | timestamp

    write-output "Downloading HDS OVA" | timestamp
    #download HDS ova
    $hds_url = "http://$webserver/collab/webex/v2/ref_files/hds_url.txt"
    $hds_txt = "C:\dcloud\hds_url.txt"

    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile($hds_url, $hds_txt)

    $url = Get-Content $hds_txt
    $ova_file = "C:\Users\cholland\Desktop\hds.ova"

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-host "Downloading hds.ova"
    Write-host " "

    $WebClient.DownloadFile($url, $ova_file)
}

if ($twc_demo) {
    write-output "Demo Setup Complete." | timestamp
    Send-MailMessage -To amckenzie@dcloud.cisco.com -From amckenzie@dcloud.cisco.com -Subject "THE WEBEX DEMO SETUP IS COMPLETE" -Body "$owner, <br><br>The Webex organization, users, and all cloud services have been configured. <br><br>-dCloud Collab Team" -BodyAsHtml -SmtpServer mail2.dcloud.cisco.com
    Send-MailMessage -To aperez@dcloud.cisco.com -From amckenzie@dcloud.cisco.com -Subject "THE WEBEX DEMO SETUP IS COMPLETE" -Body "$owner, <br><br>The Webex organization, users, and all cloud services have been configured. <br><br>-dCloud Collab Team" -BodyAsHtml -SmtpServer mail2.dcloud.cisco.com
    Send-MailMessage -To mcheng@dcloud.cisco.com -From amckenzie@dcloud.cisco.com -Subject "THE WEBEX DEMO SETUP IS COMPLETE" -Body "$owner, <br><br>The Webex organization, users, and all cloud services have been configured. <br><br>-dCloud Collab Team" -BodyAsHtml -SmtpServer mail2.dcloud.cisco.com
} elseif ($general) {
    write-output "Demo Setup Complete." | timestamp
} else {
    write-output "Demo Setup Complete." | timestamp
    Send-MailMessage -To cholland@dcloud.cisco.com -From cholland@dcloud.cisco.com -Subject "THE WEBEX LAB SETUP IS COMPLETE" -Body "$owner, <br><br>The Webex organization, users, and passwords have been configured. <br><br>-dCloud Collab Team" -BodyAsHtml -SmtpServer mail1.dcloud.cisco.com   
}
$elapsedTime = $(get-date) - $StartTime
$totalTime = "{0:HH:mm:ss}" -f ([datetime]$elapsedTime.Ticks)
write-output "Total script run time HH:mm:ss: $totalTime" 
Stop-Transcript
