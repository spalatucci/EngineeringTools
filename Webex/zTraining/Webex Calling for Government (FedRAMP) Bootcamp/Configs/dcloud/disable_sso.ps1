#script used to disable SSO in a Webex Teams org  
#last update: 15 July 2020

[XML]$xml = Get-Content "c:/dcloud/session.xml"
$vpod = $xml.session.vpod
$owner = $xml.session.owner
$acpassword = $xml.session.anycpwd
$acusername = "v" + $vpod + "user1"
$id = $xml.session.id
$dc = $xml.session.datacenter

$domain = $xml.SelectNodes("//mailsrv") | select -exp domain
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

write-host "Disabling SSO" -ForegroundColor DarkGreen
write-host " "

$resp = api "http://$webserver/api/v1/trials/trial-tasks" POST @{domain="$domain";sessId="$id";dc="$dc";task="disable_sso"}
$resp | ConvertTo-Json

write-host "Note that it could take a few minutes before the SSO status is reflected in the control hub." -ForegroundColor DarkGreen


Start-Sleep 10