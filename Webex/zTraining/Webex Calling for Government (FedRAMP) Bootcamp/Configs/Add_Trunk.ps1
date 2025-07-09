Start-Transcript -Path C:\dcloud\AddingTrunk_log.txt

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

#Reading Session.xml file for doamin and user
[XML]$xml = Get-Content "c:/dcloud/session.xml"
$vpod = $xml.session.vpod
$owner = $xml.session.owner
$acpassword = $xml.session.anycpwd
$acusername = "v" + $vpod + "user1"

$vcseurl = $xml.SelectNodes("//mailsrv") | select -exp domain
if ($sevtdemo -eq $True -Or $twcdemo -eq $True -Or $cmslab -eq $True) {$vcseurl = $vcsssseurl -replace "join.","vcse."}
$vcsedomain = $vcseurl -replace "vcse.",""
write-host $vcsedomain
$id = $xml.session.id
$dc = $xml.session.datacenter
$domain = $xml.SelectNodes("//mailsrv") | select -exp domain
$last4ofid = $id.Substring($id.Length - 4)
$wbxpwd = "dCloud"+$last4ofid+"!"
$webserver = "198.19.254.140"

#Generate random DID numbers 
for($i=1;$i -le 40;$i++)
{$num=Get-Random -Minimum 4112223333 -Maximum 9999999999
 $num = "$num"+","
 if ($i -eq 40) {$num = $num.Substring(0, $num.Length-1)}
 Add-Content -Path C:\Users\cholland\Desktop\DID_numbers.txt "$num"
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
$resp = api "http://$webserver/api/v1/users/access-token" POST @{email="cholland@$vcsedomain";userType="dev";password="$wbxpwd"}
$resp | ConvertTo-Json
$resp.access_token


#Creating Header
$headers = @{
   Authorization = "Bearer "+$resp.access_token
            }

#Get orgid & locationid
$uri = "https://webexapis.com/v1/locations"
$rsp = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ContentType "application/json"
$locid = $rsp.items.id
$orgid = $rsp.items.orgId


#Add randon numbers to location
$uri = "https://webexapis.com/v1/telephony/config/locations/$locid/numbers"
$did = Import-Csv -Path C:\Users\cholland\Desktop\DID_numbers.txt | ForEach-Object {foreach ($line in $_.PSObject.Properties) {$did_num = $line.Value ;$loc_body = @"
    {
    `"phoneNumbers`": [
        `"$did_num`"
                      ],
     `"state`": `"ACTIVE`"
    }
"@ | ConvertTo-Json ; $rsp = Invoke-WebRequest -Uri $uri -Method Post -Headers $headers -Body $loc_body -ContentType "application/json" }}


#Get one of the numbers from the location DIDs
$uri = "https://webexapis.com/v1/telephony/config/numbers"
$info = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ContentType "application/json"
$main_num = $info.phoneNumbers[0].phoneNumber

#Assign Main number to location
$uri = "https://webexapis.com/v1/telephony/config/locations/$locid"
$main_loc_body =  @"
    {


    `"callingLineId`": {
        `"phoneNumber`": `"$main_num`"
    }
    }
"@ | ConvertTo-Json
$rsp = Invoke-WebRequest -Uri $uri -Method Put -Headers $headers -Body $main_loc_body -ContentType "application/json"
$rsp.StatusCode.GetType()

#Assigning Licenses to Users - hardcode values
$AddUser = "cholland", "aperez","esteele", "rbarretta","rfilice","smauk", "tbard", "kmelby"
$extn = "6018", "6017", "6099", "6088", "6083", "6072", "6026", "6050"

for($i=0 ; $i -lt 8; $i++){
$upn = $AddUser[$i]+"@"+$domain
$user_extn = $extn[$i]
$uri = "https://webexapis.com/v1/licenses/users"
$body = @"
  {
  "email": "$upn",
  "orgId": "$orgid",
  "licenses": [
    {
      "id": "$wbx_calling_lic",
      "operation": "add",
      "properties": {
        "locationId": "$locid",
        "extension": "$user_extn"
                    }
    }
             ]
  } 
"@
$rsp = Invoke-WebRequest -Uri $uri -Method PATCH -Headers $headers -Body $body -ContentType "application/json"
if ($rsp.StatusCode -eq 200){ write-host "`n"; write-host "License Assigned to $upn"}
}



#Local Gateway Configuration
$name = "dCloud-GW"

#Add Trunk to the Control Hub, registration based
$uri = "https://webexapis.com/v1/telephony/config/locations/$locid/actions/generatePassword/invoke?orgId=$orgid"
$rsp = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ContentType "application/json"
Write-Output $rsp.exampleSipPassword

$body1 = @{"locationId" = $locid
           "name" = $name
           "password" = $rsp.exampleSipPassword
           "trunkType" = "REGISTERING"
         } | ConvertTo-Json


$uri = "https://webexapis.com/v1/telephony/config/premisePstn/trunks?orgId=$orgid"
$info = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body1 -ContentType "application/json"
$trunk_id = $info.id


#Get All trunk details
$uri = "https://webexapis.com/v1/telephony/config/premisePstn/trunks/$trunk_id"
$info = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ContentType "application/json"
Write-Output $info

$cred,$regdns = $info.linePort.split("@")
$prxy = $info.outboundProxy.outboundProxy
$trunk_otg = $info.otgDtgId
$dtg = $info.otgDtgId.Replace("_",".")
$uname = $info.sipAuthenticationUserName
$passwd = $rsp.exampleSipPassword

(Get-Content C:\Users\cholland\Desktop\LGW_Config.txt).Replace("v_cred", "$cred").Replace("v_regdns","$regdns").Replace("v_proxy", "$prxy").Replace("v_trunk_otg","$trunk_otg").Replace("v_uname","$uname").Replace("v_passwd","$passwd").Replace("v_dtg","$dtg") | Set-Content C:\Users\cholland\Desktop\LGW_Config.txt
(Get-Content C:\Users\cholland\Desktop\LGW_Config_HC.txt).Replace("v_cred", "$cred").Replace("v_regdns","$regdns").Replace("v_proxy", "$prxy").Replace("v_trunk_otg","$trunk_otg").Replace("v_uname","$uname").Replace("v_passwd","$passwd").Replace("v_dtg","$dtg") | Set-Content C:\Users\cholland\Desktop\LGW_Config_HC.txt


#Assign the trunk to the location
$uri = "https://webexapis.com/v1/telephony/config/locations/$locid" 
$con_body = @" 
          {


    `"connection`": {
        `"type`": `"TRUNK`",
        `"id`": `"$trunk_id`"
    }
    }
"@ | ConvertTo-Json


$info = Invoke-WebRequest -Uri $uri -Method Put -Headers $headers -Body $con_body -ContentType "application/json"
write-host $info.StatusCode


Stop-Transcript