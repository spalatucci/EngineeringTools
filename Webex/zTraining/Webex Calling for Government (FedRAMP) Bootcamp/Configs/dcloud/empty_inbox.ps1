$v5 = Test-Path "C:\dcloud\v5" 
$latc = Test-Path "C:\dcloud\latc" 


$users = @("cholland","aperez","kmelby","tbard","esteele","rbarretta","smauk","rfilice")

if ($v5 -or $v6){
        $Password = "dCloud123!"
    }
    elseif($latc){
        $users = @("student")
        $Password = "C0ll@B123"
    }
    else{
        $Password = "C1sco12345"
    }

$User_Domain = "dcloud"
Add-Type -Path "C:\Program Files\Microsoft\Exchange\Web Services\2.2\Microsoft.Exchange.WebServices.dll"
$EWS = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService -ArgumentList "Exchange2013"

foreach ($Username in $users){

    write-host "Emptying $Username inbox"
    $EWS.Credentials = New-Object System.Net.NetworkCredential -ArgumentList $Username, $Password, $User_Domain
    $EWS.Url = "https://mail16.dcloud.cisco.com/EWS/Exchange.asmx"
    if ($v6) {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
        $EWS.Url = "https://mail19.dcloud.cisco.com/EWS/Exchange.asmx"
    }
    $inbox = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($EWS,[Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Inbox)
    $inbox.Empty([Microsoft.Exchange.WebServices.Data.DeleteMode]::SoftDelete,$True)
} 

