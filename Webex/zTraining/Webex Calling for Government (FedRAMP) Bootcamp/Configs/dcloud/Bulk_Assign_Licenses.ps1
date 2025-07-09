$webserver = "198.19.254.140"

[XML]$xml = Get-Content "c:/dcloud/session.xml"
$vpod = $xml.session.vpod
$owner = $xml.session.owner
$acpassword = $xml.session.anycpwd
$acusername = "v" + $vpod + "user1"
$id = $xml.session.id
$dc = $xml.session.datacenter
$domain = $xml.SelectNodes("//mailsrv") | select -exp domain
$last4ofid = $id.Substring($id.Length - 4)
$wbxpwd = "dCloud"+$last4ofid+"!"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

function api($url, $method, $data= @{default="no data"}){
    $json = $data | ConvertTo-Json    
    if($method -eq 'POST'){
        $r = Invoke-RestMethod -Uri $url -Method $method -Body $json -ContentType "application/json" -TimeoutSec 900
    }else{
        $r = Invoke-RestMethod -Uri $url -Method $method -TimeoutSec 900
    }
    return $r
}


#Getting the Access token for Charles
$resp = api "http://$webserver/api/v1/users/access-token" POST @{email="cholland@$domain";userType="admin";password="$wbxpwd"}
$resp | ConvertTo-Json
$resp.access_token

$file_path = 'C:\Users\cholland\Desktop\Webex_API_Details.txt'
"Access_Token: "+"Bearer "+$resp.access_token | Out-File $file_path

#Creating Header
 $headers = @{
       Authorization = "Bearer "+$resp.access_token
                }

#Getting OrgId
$uri = "https://webexapis.com/v1/organizations"
$rsp = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ContentType "application/json"
$orgId = $rsp.items.id



#getting the location ID
$uri = "https://webexapis.com/v1/locations"
$rsp = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ContentType "application/json"
$locid = $rsp.items.id



#getting the Calling License ID
$uri = "https://webexapis.com/v1/licenses?orgId=$orgId"
$rsp = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ContentType "application/json"
foreach ($item in $rsp.items) {if ($item.name -eq "Webex Calling - Professional") {$wbx_calling_lic = $item.id}}



#Assigning Licenses to Users
$AddUser = "esteele", "rbarretta","rfilice","smauk"
$extn = "6099", "6088", "6083", "6072"

for($i=0 ; $i -lt 4; $i++){
$upn = $AddUser[$i]+"@"+$domain
$user_extn = $extn[$i]
$uri = "https://webexapis.com/v1/licenses/users"
$body = @"
  {
  "email": "$upn",
  "orgId": "$orgId",
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
