#script used to download and install Cisco Webex Teams and Directory Connector
$general = Test-Path "C:\dcloud\general"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$webserver = "198.19.254.140"

$webex_url = "http://$webserver/collab/webex/v2/ref_files/webex_url.txt"
$webex_txt = "C:\dcloud\installs\webex_url.txt"

$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile($webex_url, $webex_txt)

$url = Get-Content $webex_txt
$install_file = "C:\dcloud\installs\Webex.msi"


Write-host "Downloading Webex.msi"
Write-host " "

$WebClient.DownloadFile($url, $install_file)

Write-host "Installing Cisco Webex"
Write-host " "

Start-Sleep 2

Start-Process $install_file -ArgumentList "/qnia","INSTALLWV2=1" -Wait

Write-host "Cisco Webex Install Complete"

Start-Sleep 3

if (!$general){
    $dc_url = "http://198.19.254.140/collab/webex/v2/ref_files/dc_url.txt"
    $dc_txt = "C:\dcloud\installs\dc_url.txt"

    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile($dc_url, $dc_txt)

    $url = Get-Content $dc_txt
    $zip_file = "C:\dcloud\installs\DirectoryConnector.zip"

    Write-host " "
    Write-host "Downloading DirectoryConnector.zip"
    Write-host " "

    $WebClient.DownloadFile($url, $zip_file)

    Write-host "Unzipping Directory Connector"
    Write-host " "


    & 'C:\Program Files\7-Zip\7z.exe' e $zip_file -oc:\dcloud\installs\DirectoryConnector

    Write-host " "
    Write-host "Installing Directory Connector"
    Write-host " "

    Start-Sleep 2

    $dc_install_file = "c:\dcloud\installs\DirectoryConnector\CiscoDirectoryConnector.msi"

    Start-Process $dc_install_file -ArgumentList /qn -Wait

    Write-host "Directory Connector Install Complete"
}

Start-Sleep 3

#fix time sync in SJ DC

if ($dc -eq "SJC") {

cd "C:\Program Files\VMware\VMware Tools"
.\VMwareToolboxCmd.exe timesync enable

}