#script used to delete webex trial
#last update: 15 July 2020 

$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
Start-Transcript -path C:\dcloud\delete_trial_log.txt -append

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

write-host "Deleting trial" 
write-host " " 

$resp = api "http://$webserver/api/v1/trials/$dc/$id/$domain" DELETE 

$resp | ConvertTo-Json

Start-Sleep 10

Stop-Transcript