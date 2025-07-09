#script used to enable Webex org features 
#last update: 15 July 2020 

[XML]$xml = Get-Content "c:/dcloud/session.xml"
$vpod = $xml.session.vpod
$owner = $xml.session.owner
$acpassword = $xml.session.anycpwd
$acusername = "v" + $vpod + "user1"
$id = $xml.session.id
$dc = $xml.session.datacenter
$xmlDevices = $xml.SelectNodes("/session/devices/device")

$domain = $xml.SelectNodes("//mailsrv") | select -exp domain

$v3path = "C:\dcloud\webexv3"
$code = 'None'
$msg = 'None'
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

write-host "Configuring Org Features" 
write-host " " 

api "http://$webserver/api/v1/trials/trial-tasks" POST @{domain="$domain";sessId="$id";dc="$dc";task="set_org_feat"}

Start-Sleep 10