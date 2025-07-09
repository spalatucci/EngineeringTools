#script used to sync Control Hub and WXCC in a Webex org  
#last update: 5 October 2023

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

write-host "Syncing Control Hub and WXCC" -ForegroundColor DarkGreen
write-host " "

$resp = api "http://$webserver/api/v1/trials/trial-tasks" POST @{domain="$domain";sessId="$id";dc="$dc";task="sync_wxcc"}
$resp | ConvertTo-Json


Start-Sleep 10