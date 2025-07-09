cd \

[XML]$xml = Get-Content "c:/dcloud/session.xml"
$vpod = $xml.session.vpod
$owner = $xml.session.owner
$acpassword = $xml.session.anycpwd
$acusername = "v" + $vpod + "user1"
$id = $xml.session.id
$dc = $xml.session.datacenter

$domain = $xml.SelectNodes("//mailsrv") | select -exp domain

$v6 = Test-Path "C:\dcloud\v6"
$webserver = "198.19.254.140"

if($v6){
    $password = "dCloud123!"
}else{
    $password = "C1sco12345"
}

function api($url, $method, $data= @{default="no data"}){
    $json = $data | ConvertTo-Json    
    if($method -eq 'POST'){
        $r = Invoke-RestMethod -Uri $url -Method $method -Body $json -ContentType "application/json" -TimeoutSec 600
    }else{
        $r = Invoke-RestMethod -Uri $url -Method $method -TimeoutSec 600
    }
    return $r
}

write-host "Ready to configure the Calendar Connector for Cisco Webex" -ForegroundColor DarkGreen
write-host " "
write-host "To run script successfully, do not press any key until told to do so" -ForegroundColor Yellow
write-host " "
write-host "You may drag the command window to the side to view the configuration in IE" -ForegroundColor Yellow
write-host " "


write-host " "
write-host "Getting Webex URL" -ForegroundColor DarkGreen
write-host " "


$resp = api "http://$webserver/api/v1/trials/trial-tasks" POST @{domain="$domain";sessId="$id";dc="$dc";task="get_webex_url"}
$webex_url = $resp.url
$webex_url

write-host " "
write-host "Configuring Exchange Server for Calendar Connector" -ForegroundColor DarkGreen
write-host " "

$ie = new-object -com "InternetExplorer.Application"
$ie.visible = $true

$ie.navigate("https://exp-cc.dcloud.cisco.com/exchangeservers")

while ($ie.Busy -eq $true) {Start-Sleep -Milliseconds 1000}
[System.Threading.Thread]::Sleep(2000)

$ie.document.IHTMLDocument3_GetElementByID("username").value = "admin"
$ie.document.IHTMLDocument3_GetElementByID("password").value = "dCloud123!"
$ie.document.IHTMLDocument3_GetElementByID("save_button").click()

while ($ie.Busy -eq $true) {Start-Sleep -Milliseconds 1000}
[System.Threading.Thread]::Sleep(2000)

$new = $ie.document.IHTMLDocument3_GetElementByID("new").click()

while ($ie.Busy -eq $true) {Start-Sleep -Milliseconds 1000}
[System.Threading.Thread]::Sleep(2000)

$ie.document.IHTMLDocument3_GetElementByID("username").value = "dcloud\hcalendar"
$ie.document.IHTMLDocument3_GetElementByID("password").value = "$password"
$ie.document.IHTMLDocument3_GetElementByID("display_name").value = "mail16"
#$ie.document.IHTMLDocument3_GetElementByID("basic_check").Checked = $false
$ie.document.IHTMLDocument3_GetElementByID("tls_verify").value = "false"
#$ie.document.IHTMLDocument3_GetElementByID("auto_discover").value = "false"
#$ie.document.IHTMLDocument3_GetElementByID("address").value = "198.18.133.2"
$ie.document.IHTMLDocument3_GetElementByID("query_mode").value = "ldap"
$ie.document.IHTMLDocument3_GetElementByID("ldap_tls_verify").value = "false"
$ie.document.IHTMLDocument3_GetElementByID("domain").value = "dcloud.cisco.com"
$ie.document.IHTMLDocument3_GetElementByID("emailAddress").value = "cholland@$domain"

$ie.document.IHTMLDocument3_GetElementByID("save_button").click()

write-host " "
write-host "Script will click Add again due to display name error" -ForegroundColor Yellow
write-host " "

while ($ie.Busy -eq $true) {Start-Sleep -Milliseconds 1000}
[System.Threading.Thread]::Sleep(2000)

Start-Sleep 5

$ie.document.IHTMLDocument3_GetElementByID("save_button").click()

Start-Sleep 30

while ($ie.Busy -eq $true) {Start-Sleep -Milliseconds 1000}
[System.Threading.Thread]::Sleep(2000)

write-host " "
write-host "Configuring CMR for Calendar Connector" -ForegroundColor DarkGreen
write-host " "

$ie.navigate("https://exp-cc.dcloud.cisco.com/cmrconfig")

while ($ie.Busy -eq $true) {Start-Sleep -Milliseconds 1000}
[System.Threading.Thread]::Sleep(2000)

$new = $ie.document.IHTMLDocument3_GetElementByID("new").click()

while ($ie.Busy -eq $true) {Start-Sleep -Milliseconds 1000}
[System.Threading.Thread]::Sleep(2000)

$fqdn = $ie.document.IHTMLDocument3_GetElementByID("cmr_fqdn").value = $webex_url

$add = $ie.document.IHTMLDocument3_GetElementByID("save_button").click()

while ($ie.Busy -eq $true) {Start-Sleep -Milliseconds 1000}
[System.Threading.Thread]::Sleep(2000) 

write-host " "
write-host "Enabling the Calendar Connector" -ForegroundColor DarkGreen
write-host " "

$ie.navigate("https://exp-cc.dcloud.cisco.com/fusionregistration?uuid=c_cal")

while ($ie.Busy -eq $true) {Start-Sleep -Milliseconds 1000}
[System.Threading.Thread]::Sleep(2000)  

$enable = $ie.document.IHTMLDocument3_GetElementByID("enable_service").value = "true"

$save = $ie.document.IHTMLDocument3_GetElementByID("save_button").click()

while ($ie.Busy -eq $true) {Start-Sleep -Milliseconds 1000}
[System.Threading.Thread]::Sleep(2000) 

write-host " "
write-host "This Completes the Calendar Connector Configuration. Internet Explorer will now close" -ForegroundColor DarkGreen
write-host " "    

Start-Sleep 5

$ie.quit()