Import-Module MSOnline
Import-Module AzureAD

Start-Transcript -Path C:\dcloud\O365_Lic.txt

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12


#Reading Session.xml file for doamin and user
[XML]$xml = Get-Content "c:/dcloud/session.xml"
$vpod = $xml.session.vpod
$owner = $xml.session.owner
$acpassword = $xml.session.anycpwd
$acusername = "v" + $vpod + "user1"
$wbxpwd="dCloud123!"

$vcseurl = $xml.SelectNodes("//translation[inside='198.18.1.5']") | select -exp name
if ($sevtdemo -eq $True -Or $twcdemo -eq $True -Or $cmslab -eq $True) {$vcseurl = $vcseurl -replace "join.","vcse."}
$vcsedomain = $vcseurl -replace "vcse.",""
#write-host $vcsedomain

#Getting the Trial email
$trialemail = Get-Content \\198.18.133.2\c$\TRIAL_EMAIL.txt -Raw
$trialemail = $trialemail.Trim()
#write-host $trialemail


$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")

$body = "{
`n  `"culture`": `"en-US`",
`n  `"EmailAddress`": `"$trialemail`",
`n  `"skipVerificationEmail`": true,
`n  `"skuId`": `"c7df2760-2c81-4ef7-b578-5b5392b571df`"
`n}"


$response0 = Invoke-RestMethod 'https://signup.microsoft.com/api/signupservice/usersignup?api-version=1&culture=en-US' -Method 'POST' -Headers $headers -Body $body
$response0 | ConvertTo-Json


#Entering User details for creating O365 trial 
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")

$body = "{
`n  `"Address`": {
`n    `"FirstName`": `"Charles`",
`n    `"MiddleName`": null,
`n    `"LastName`": `"Holland`",
`n    `"CountryCode`": `"US`",
`n    `"PhoneNumber`": `"9725556018`"
`n  },
`n  `"IncludeDomainRegistrarAddressValidation`": true,
`n  `"EmailAddress`": `"$trialemail`",
`n  `"PartialAddressValidation`": true
`n}"

$response1 = Invoke-RestMethod 'https://signup.microsoft.com/api/signupservice/ValidateAddress?api-version=1&culture=en-US' -Method 'POST' -Headers $headers -Body $body
$response1 | ConvertTo-Json

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")

#Gettting User Mobile Phone number
$cc = Read-Host "Enter Your Country Code"

#Gettting User Mobile Phone number
$phonenumber = Read-Host "Enter Your 10 Digit Phone number"

#Sending Mobile Number to recieve the code
$body = "{
`n  `"phoneNumber`": `"$phonenumber`",
`n  `"phoneCountryCode`": `"$cc`",
`n  `"useVoice`": false,
`n  `"emailAddress`": `"$trialemail`"
`n}
`n"

$response2 = Invoke-RestMethod 'https://signup.microsoft.com/api/signupservice/hipchallenge?api-version=1&culture=en-US' -Method 'POST' -Headers $headers -Body $body
$response2 | ConvertTo-Json

#Getting Challenge ID from response and saving it to a variable
#Write-Host $response2.challengeId
$challenge = $response2.challengeId



#Getting the code from user Mobile
$code = Read-Host "Enter the code you recived on Mobile"

#Sending ChallengeId and code to O365
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")

$body = "{
`n  `"HipChallengeResponse`": {
`n    `"challengeId`": `"$challenge`",
`n    `"challengeAnswer`": `"$code`"
`n  },
`n  `"ContextData`": {
`n    `"regionCode`": `"US`",
`n    `"firstName`": `"Charles`",
`n    `"middleName`": null,
`n    `"lastName`": `"Holland`",
`n    `"emailAddress`": `"$trialemail`",
`n    `"phoneNumber`": `"9725556018`",
`n    `"organizationName`": `"Cisco`",
`n    `"domainName`": `"`"
`n  }
`n}"

#write-host $body

$response3 = Invoke-RestMethod 'https://signup.microsoft.com/api/signupservice/verifyhipchallenge?api-version=1&culture=en-US' -Method 'POST' -Headers $headers -Body $body
$response3 | ConvertTo-Json


#Defining the trial domain
$trialdomain=“trial" + (get-date -format "ddHHmmss") 
#write-host $trialdomain




$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")

$body = "{
`n  `"OfferIds`": [
`n    `"101bde18-5ffb-4d79-a47b-f5b2c62525b3`"
`n  ],
`n  `"Region`": `"US`"
`n}"

$response = Invoke-RestMethod 'https://signup.microsoft.com/api/signupservice/domainoptions?api-version=1&culture=en-US' -Method 'POST' -Headers $headers -Body $body
$response | ConvertTo-Json



#Sending the domain and creating O365 tenant
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")

$body = "{
`n  `"HipChallengeResponse`": {
`n    `"challengeId`": `"$challenge`",
`n    `"challengeAnswer`": `"$code`"
`n  },
`n  `"AdminAccountInfo`": {
`n    `"userId`": `"cholland`",
`n    `"domainName`": `"$trialdomain`",
`n    `"password`": `"dCloud123!`",
`n    `"domainPurchaseOption`": 0
`n  },
`n  `"AdminContactPreferences`": {
`n    `"emailContactPreference`": true,
`n    `"phoneContactPreference`": true,
`n    `"partnerContactPreference`": false
`n  },
`n  `"OfferIds`": [
`n    `"101bde18-5ffb-4d79-a47b-f5b2c62525b3`"
`n  ],
`n  `"SkipAuxiliaryPostSignupActions`": true,
`n  `"AdminUserInfo`": {
`n    `"regionCode`": `"US`",
`n    `"firstName`": `"Charles`",
`n    `"middleName`": null,
`n    `"lastName`": `"Holland`",
`n    `"emailAddress`": `"$trialemail`",
`n    `"phoneNumber`": `"9725556018`",
`n    `"organizationName`": `"Cisco`",
`n    `"organizationSize`": `"1000+`"
`n  },
`n  `"EnableInstantOn`": true
`n}"

$response4 = Invoke-RestMethod 'https://signup.microsoft.com/api/signupservice/adminsignup?api-version=1&culture=en-US' -Method 'POST' -Headers $headers -Body $body
$response4 | ConvertTo-Json
$orgid = $response4.tenantId

#write-host $response4.upn


write-host "Waiting for 60s for the trial to be active"



Start-Sleep 60


#Connecting to O365
$O365pwd = ConvertTo-SecureString "dCloud123!" -AsPlainText -Force
$O365user = $response4.upn
$uid,$O365domain = $O365user.split("@")
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $O365user, $O365pwd
Connect-MsolService -Credential $cred


#Adding Additional Users to O365
$AddUser = "amckenzie","aperez","mcheng", "jli", "mkumar","tadams","kmelby","tbard","nfox"
$Display = "Adam McKenzie", "Anita Perez", "Monica Cheng","Jim Li","Mukul Kumar","Tanya Adams","Kellie, Melby","Taylor Bard","Nancy Fox"

$NoOfUsers=Read-Host "How many users do you need in O365 Trial, Enter up to 10"

for($i=0 ; $i -lt $NoOfUsers-1 ; $i++)
    {$UserPN = $AddUser[$i]+"@"+$O365domain
     $FN,$SN=$Display[$i].split(" ")
     New-MsolUser -UserPrincipalName $UserPN -DisplayName $Display[$i] -FirstName $FN -LastName $SN -Password dcloud123!}


#Getting skuid (license)
$sku= Get-MsolAccountSku
$skuId = $sku.AccountSkuId
#write-host $skuId

#Get-MsolUser -All -UnlicensedUsersOnly
$Users = Get-MsolUser -All -UnlicensedUsersOnly



#Assigning Licenses 
$UnLicensedUsers = $Users.Count
#write-host $UnLicensedUsers
#write-host $Users.UserPrincipalName
#$Users.UserPrincipalName.GetType().FullName
$a= Out-String -InputObject $Users.UserPrincipalName -Stream
#write-host $a
#$a.GetType().FullName
Foreach($user in $a)
{ #write-host $user
  Set-MsolUser -UserPrincipalName $user -UsageLocation US
  Set-MsolUserLicense -UserPrincipalName $user -AddLicenses $skuId 
  }

Write-host "All Your O365 Users are licensed"



write-host "Your O365 Trial Tenant is Successfully Created!!!" -ForegroundColor DarkMagenta -BackgroundColor White
write-host  "`n"
write-host "Your O365 Trial Domain is:        " $response4.upn -ForegroundColor DarkGreen -BackgroundColor White
write-host "Your O365  Trial Password is:        " $wbxpwd -ForegroundColor DarkMagenta -BackgroundColor White
write-host  "`n"
write-host "Your O365 Trial Tenant ID is:      "$response4.tenantId -ForegroundColor DarkGreen -BackgroundColor White 

$file_path = 'C:\Users\cholland\Desktop\TRIAL_EMAIL.txt'
write-output "Your O365 Trial Tenant is Successfully Created!!!" >> $file_path
write-output  "`n" >>  $file_path
write-output "Your O365 Trial Domain is:        " $response4.upn >> $file_path
write-output "Your O365  Trial Password is:        " $wbxpwd >> $file_path
write-output  "`n" >> $file_path
write-host "Your O365 Trial Tenant ID is:      "$response4.tenantId >> $file_path