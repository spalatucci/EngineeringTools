#script used to configure Webex Calling if it failed on initial startup
#last update: 21 July 2020 

$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
Start-Transcript -path C:\dcloud\config_calling_log.txt -append

[XML]$xml = Get-Content "c:/dcloud/session.xml"
$vpod = $xml.session.vpod
$owner = $xml.session.owner
$acpassword = $xml.session.anycpwd
$acusername = "v" + $vpod + "user1"
$id = $xml.session.id
$dc = $xml.session.datacenter
$domain = $xml.SelectNodes("//mailsrv") | select -exp domain

$full_lab = Test-Path "C:\dcloud\full_lab"
$call_lab = Test-Path "C:\dcloud\call_lab"
$gdoat = Test-Path "C:\dcloud\gdoat"
$code = 'None'
$msg = 'None'
$webserver = "198.19.254.140"

if (!$gdoat){
    $xmlDevices = $xml.SelectNodes("/session/devices/device")
    Foreach ($xmlDevice in $xmlDevices) {
        $device = ($xmlDevice | Where-Object {$_.Name -Match "^830.*" })
        if ($device.name -like "830*") {$cbnum = $device.name}  
    }
}else{
    $cbnum = '4175551234' #fake number so calling gets configured for gdoat
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

Write-Host "Configuring Webex Calling." -ForegroundColor DarkGreen
Write-Host " "

$resp = api "http://$webserver/api/v1/calling" POST @{domain="$domain";sessId="$id";dc="$dc";baseNumber="$cbnum"}
$resp | ConvertTo-Json
if ($resp.result -eq 'failed'){
    write-host "Webex Calling Setup Failed." -ForegroundColor Red
    Start-Sleep 20
}else{
    write-host "Webex Calling Setup Completed Successfully." -ForegroundColor DarkGreen
    Start-Sleep 20
}

