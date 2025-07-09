# ----------------------
# Configuration Section
# ----------------------
# Constants
$username = $ENV:UserProfile
$InstallerFolder = "RedRiver"
$InstallerFilename = "CMSsetup.exe"
$InstallerPath = Join-Path $Env:ProgramData $InstallerFolder

#Define which CMS is being used
# CMS0 = cmstest.redriver.com
# CMS1 = cms.redriver.com
# CMS2 = cms2.redriver.com
$CMSID = "CMS2"

# These URLs are only valid for 30 days at a time and they will change when re-created.
$DownloadURL = ("https://s3.amazonaws.com/cmsagent.redriver.com/Agents/"+$CMSID+"Setup.exe")

# OrgID
# Every Organization has an ID
#
# GroupID
# You can specify the entire group ID for example: "no-patch.svr" or "geneva.office"
# The end result should read like "no-patch.svr.MyOrg" or "hq.MyOrg"
# Every Org has an 'hq' group as it's default.
#
$OrgID = "MyOrg"
$GroupID = "hq"

# CMS Installer Arguments
# Silent Install and define the Group & Org
$InstallerArgs = "/s /g=$GroupID.$OrgID"

# ------------------
# Logic Starts Here
# ------------------
# Installer Path = C:\ProgramData\RedRiver (from Configuration Section)
# Test Folder path to find out if it exists if not, create it
if(!(Test-Path -Path $InstallerPath )){
    New-Item $InstallerPath -ItemType Directory -ErrorAction SilentlyContinue
}

# Append the CMS ID to the Installer Path C:\ProgramData\RedRiver\CMS0
$InstallerPath = Join-Path $InstallerPath $CMSID

# Test Folder path to find out if it exists if not, create it
if(!(Test-Path -Path $InstallerPath )){
    New-Item $InstallerPath -ItemType Directory -ErrorAction SilentlyContinue
}

# Name of installer exe file path information C:\ProgramData\RedRiver\CMS0\CMSsetup.exe
$Installer = Join-Path $InstallerPath $InstallerFilename

# Download the Installer
$webClient = New-Object System.Net.WebClient
$webClient.DownloadFile($DownloadURL, $Installer)

# Start Process = "Command to Execute install"
Start-Process "$Installer" -ArgumentList $InstallerArgs -Wait -NoNewWindow -PassThru