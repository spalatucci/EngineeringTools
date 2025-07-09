#############################
# Constants & Configuration #
#############################

# We stop on Errors unless overridden in the procedure call
Import-Module PackageManagement
$ErrorActionPreference = "Stop"

# Toggle Debugging message on & off
$DebugPreference = "Continue"

# In case we're compiled, we need this
$SysAppInfo = [System.AppDomain]::CurrentDomain

# Required Environment Information
If ($SysAppInfo.FriendlyName -like "*.exe") { $MyName = ($SysAppInfo.FriendlyName).Replace(".exe", "") }
Else { $MyName = ($MyInvocation.MyCommand.Name).Replace(".ps1", "") }

# Paths & Files
$MyPath = Get-Location
$MyLog = "$MyPath\$MyName.log"

# Default Data Path
$RRPath = Join-Path $Env:ProgramData "RedRiver"
$MyAppID = "Cisco"

# Configuration for Downloads
$BaseURL = "https://s3.amazonaws.com/cmsagent.redriver.com/"
$FileSection = "software/cisco"


##################
# Core Functions #
##################

# Format anything
Function Get-FormattedString () {
    [CmdletBinding()]
    Param ($rawValue, [string]$Format = "{0}")
    Return ($Format -f $rawValue)
}


# Convert etype Code to String
# eTypes are:
#           1 = Error and Exit
#           2 = Warning
#           3 = Warning and Exit
#           4 = Information
#           8 = Success Audit
#          16 = Failure Audit
#           0 = Information with no Prefix
#
function ConvertTo-StringType () {
    [CmdletBinding()]
    param([int]$Code, [string]$Format = "{0}")

    $thisValue = ""
    switch ($Code) {
        1 { $thisValue = "ERROR"; break }
        2 { $thisValue = "WARNING"; break }
        3 { $thisValue = "WARNING"; break }
        4 { $thisValue = "Information"; break }
        8 { $thisValue = "Success Audit"; break }
        16 { $thisValue = "Failure Audit"; break }
        default { $thisValue = "" }
    }
    return (Get-FormattedString $thisValue -Format $Format)
}

# Write to Event Log
function Write-AppEventLog () {
    [Cmdletbinding()]
    param($text, [int]$etype = 0)

    New-EventLog -Source "$MyName" -LogName "Application" -ErrorAction SilentlyContinue
    switch ($etype) {
        1 { Write-EventLog -LogName "Application" -Source "$MyName" -EventID $etype -EntryType Error -Message $text -Category 0 -ErrorAction SilentlyContinue; break }
        2 { Write-EventLog -LogName "Application" -Source "$MyName" -EventID $etype -EntryType Warning -Message $text -Category 0 -ErrorAction SilentlyContinue; break }
        3 { Write-EventLog -LogName "Application" -Source "$MyName" -EventID $etype -EntryType Warning -Message $text -Category 0 -ErrorAction SilentlyContinue; break }
        4 { Write-EventLog -LogName "Application" -Source "$MyName" -EventID $etype -EntryType Information -Message $text -Category 0 -ErrorAction SilentlyContinue; break }
        8 { Write-EventLog -LogName "Application" -Source "$MyName" -EventID $etype -EntryType SuccessAudit -Message $text -Category 0 -ErrorAction SilentlyContinue; break }
        16 { Write-EventLog -LogName "Application" -Source "$MyName" -EventID $etype -EntryType FailureAudit -Message $text -Category 0 -ErrorAction SilentlyContinue; break }
        default { Write-EventLog -LogName "Application" -Source "$MyName" -EventID 0 -EntryType Information -Message $text -Category 0 -ErrorAction SilentlyContinue }
    }
}

# Write to the Log File & Possibly the Event Log
function Write-MyLog () {
    [Cmdletbinding()]
    param($text, [int]$etype = 0, [switch]$EventLog)

    $myType = ConvertTo-StringType $etype -Format "{0}: "

    try {
        if ($text.count -gt 1) { Write-Output ($text) >> $MyLog }
        else { Write-Output ("{0} - {1}{2}" -f (Get-Date -Format 'yyyyMMddTHHmmss'), $myType, $text) >> $MyLog }
    }
    catch { Write-AppEventLog -text ("Failed to write to log file {0}" -f $MyLog) -etype 1 }

    if ($EventLog) { Write-AppEventLog -text $text -etype $etype }
}

#--------------------------------
# Write to the Log(s) and Output
# eTypes are:
#           1 = Error and Exit
#           2 = Warning
#           3 = Warning and Exit
#           4 = Information
#           8 = Success Audit
#          16 = Failure Audit
#           0 = Information with no Prefix
#
function Write-LogAndOut () {
    [Cmdletbinding()]
    param($text, [int]$etype = 0, [switch]$EventLog)

    $myType = ConvertTo-StringType $etype -Format "{0}: "

    # Write to Log(s)
    if ($EventLog) { Write-MyLog -text $text -etype $etype -EventLog }
    else { Write-MyLog -text $text -etype $etype }

    if ($myType -ne "") { $message = ("{0}{1}" -f $myType, $text) }
    else { $message = $text }

    switch ($etype) {
        1 { Write-Error $text; exit 1 }
        2 { Write-Warning $text; break }
        3 { Write-Warning $text; exit 2 }
        default { Write-Output $message }
    }
}

#-------------------------------------
# Checks if being run by CMS & Assures
# that Working folders are present &
# Configured
#-------------------------------------
Function Confirm-WorkingPath () {
    $workPath = ""

    # Check if we're in CMS folder structure
    if ($MyPath -contains ":\CMS") {
        if ($MyPath -contains $MyAppID) { $workPath = $MyPath }
        else { $workPath = Join-Path $MyPath $MyAppID }
    }
    else { $workPath = Join-Path $RRPath $MyAppID }

    # Always make sure the RR Path is there
    if (!(Test-Path -path $RRPath )) {
        try { New-Item $RRPath -ItemType Directory -ErrorAction SilentlyContinue }
        catch { Write-LogAndOut "Unable to create Red River Default Data Path ($RRPath)" -etype 1 -EventLog }
    }

    # Now Validate our working path
    if (!(Test-Path -path $workPath )) {
        try { New-Item $workPath -ItemType Directory -ErrorAction SilentlyContinue }
        catch { Write-LogAndOut "Unable to create the Working Path $workPath" -etype 1 -EventLog }
    }
    return $workPath
}

# Retrieve Files from the Web & verify good
Function Get-FileFromWeb () {
    [CmdletBinding()]
    Param ([string]$section, [string]$fetchFile, [string]$savePath, [string]$saveFile)

    $result = ""

    $thisURL = ($BaseURL + $section + "/" + $fetchFile)
    $thisTarget = Join-Path $savePath $saveFile

    Write-Debug "The URL is: $thisURL"
    Write-Debug "The Target is: $thisTarget"

    Try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($thisURL, $thisTarget)
    }
    Catch { Write-LogAndOut "Failed trying to download $fetchFile" -etype 1 -EventLog }

    # If we are here file downloaded so we'll verify it
    If (Test-Path -path $thisTarget) {
        Write-Debug "Have the file, checking size"
        If (((Get-Item $thisTarget).Length / 1KB) -gt 300) { $result = $thisTarget }
        Else { Write-LogAndOut "The file $thisTarget is less than 300KB in size." -etype 1 -EventLog }
    }
    Else { Write-LogAndOut "Could not find $thisTarget" -etype 1 -EventLog }

    #We only get here on fill success
    return $result
}

# ----------------------------------------------------
# This handy little function will return the Service
# Control Object of any Service that exists otherwise
# it returns an empty Service Control Object.
# ----------------------------------------------------
Function Get-ServiceObject() {
	[CmdletBinding()]
	Param ([string]$Name,[string]$DisplayName)
	
	# default return value is a blank service control object
	# kick start it just to be sure it works
	$blank = Get-Service "WinRM" -ErrorAction SilentlyContinue
	$blank = New-Object -TypeName "System.ServiceProcess.ServiceController" -ErrorAction SilentlyContinue
	$return = $blank 
	
	# If we have either parameter we can do the test
	If ($Name -or $DisplayName) {
		If ($Name) {
			Try { $return = ( Get-Service -Name $Name -ErrorAction SilentlyContinue ) }
			Catch { Write-LogAndOut "Failed to find Service Named: $Name" -etype 2 -EventLog; $return = $blank }
		}
		If ($DisplayeName -and ($return -eq $blank)) {
			Try { $return = (Get-Service -DisplayName $DisplayName -ErrorAction SilentlyContinue) }
			Catch { Write-LogAndOut "Failed to find Service with DisplayName: $DisplayName" -etype 2 -EventLog; $return = $blank }
		}
	}
	
	# Return our findings
	return $return
}

####################
# Custom Functions #
####################

Function Confirm-Profile () {
    [CmdletBinding()]
    param ([string]$where)

    $part1 = Join-Path $where "Profiles"
    $result = ""

    if (!(Test-Path -path $part1 )) {
        try { New-Item $part1 -ItemType Directory -ErrorAction SilentlyContinue }
        catch { Write-LogAndOut "Unable to create the path ($part1)" -etype 1 -EventLog }
    }

    $part2 = Join-Path $part1 "Umbrella"
    # Now Validate the next level
    if (!(Test-Path -path $part2 )) {
        try { New-Item $part2 -ItemType Directory -ErrorAction SilentlyContinue }
        catch { Write-LogAndOut "Unable to create the path ($part2)" -etype 1 -EventLog }
    }

    #Write The Profile
    $thisProfile = Join-Path $part2 "orginfo.json"
    Try { [ordered]@{organizationId = "$OrgID"; fingerprint = "$FingerPrint"; userId = "$UserID" } | ConvertTo-json | Out-File -FilePath $thisProfile }
    catch { Write-LogAndOut "Unable to write the profile ($thisProfile)" -etype 1 -EventLog }

    if (Test-Path -path $thisProfile) { $result = $thisProfile}
    return $result
}

#####################
# Logic Starts Here #
#####################

#--------------------
# Validation Section
#--------------------

# If we don't have the required arguments warn the caller and exit *
if ($args.count -ne 3) {
    $message = "Requires 3 parameters formatted as <Item>=<value>"
    $message += "`nFor Example:  OrgID=3F75542AF7BBC03"
    $message += "`nValid Items Are:`n`tOrgID`n`tFingerprint`n`tUserID"
    Write-LogAndOut $message 3
}

# Parse the arguments
for ($i = 0; $i -lt $args.count; $i++) {
    $thisItem = $args[$i].split("=")
    switch ($thisItem[0].ToUpper()) {
        "ORGID" { $OrgID = $thisItem[1]; break }
        "FINGERPRINT" { $FingerPrint = $thisItem[1]; break }
        "USERID" { $UserID = $thisItem[1] }
        default {
            Write-LogAndOut "Invalid Item Identifier in Parameter $($i+1)" 1 -EventLog
        }
    }
}

# Validate the arguments
if (!$OrgID -or !$FingerPrint -or !$UserID) {
    Write-LogAndOut "One or more of the Item Identifiers was not provided as required." 1 -EventLog
}

#----------------
# Process Section
#----------------
# Get our Working Path
$WorkingPath = Confirm-WorkingPath

# Validate the profile
$MyProfile = Confirm-Profile $WorkingPath

# Define Application Paths
$AppPath = "$Env:ProgramData\Cisco\Cisco AnyConnect Secure Mobility Client\Umbrella\"
$DataPath = "$AppPath\data"

# Define the Installer Files
$File1 = "anyconnect-install.msi"
$File2 = "anyconnect-umbrella-install.msi"

#Service Name
$SvcName = "acumbrellaagent"

# This is Version Dependent Code
If ($PSVersionTable.PSVersion.Major -le 5) {
	# Make sure we have the NuGet provider
	Install-PackageProvider -Name "NuGet" -MinimumVersion 2.8.5.208 -Force -ErrorAction SilentlyContinue
	# Use Package Management (Fast!)
	$allApps = (Get-Package -ProviderName Programs -IncludeWindowsInstaller -Name "*")
}
Else { $allApps = (Get-WmiObject -Class Win32_Product) }

# Get the App Package if it's installed, otherwise it's null'
$App = ($allApps | Where-Object {$_.Name -like '*umbrella*roaming*'})

#Fetch the Installers
$Installer1 = Get-FileFromWeb -section $FileSection -fetchFile $File1 -savePath $WorkingPath -saveFile $File1
$Installer2 = Get-FileFromWeb -section $FileSection -fetchFile $File2 -savePath $WorkingPath -saveFile $File2

# If we are here then we have what we need to proceed

# If the application is installed then we need to 
# stop the service if it's running and remove the app
# Simple enough to tell now, if this is an object it's installed
If ($App) {
	Write-LogAndOut "The count of matching applications is: $($App.Count). Each will be removed." -etype 4
	
	# See if we have a service running
	$appSvc = Get-ServiceObject -Name $SvcName
	If ($appSvc.Status -eq 'Running') {
		Write-LogAndOut "The service is running. We're stopping it now." -etype 4
		Try { Stop-Service -Name $appSvc.Name -ErrorAction SilentlyContinue }
		Catch { Write-LogAndOut "We failed to stop the ($($AppSvc.DisplayName)) service. Unable to continue" -etype 1 -EventLog }
	}
	
	#Un-Install the Application(s)
	ForEach ($a In $app) {
		Write-LogAndOut "Removing the $($a.Name) version $($a.Version) application" -etype 4
		Try {
			$nukeMe = Get-WmiObject -Class Win32_Product -Filter "Name = '$($a.Name)'"
			$nukeMe.UnInstall()
		}
		Catch { Write-LogAndOut "We failed to remove $($a.Name) version $($a.Version). Unable to Continue" -etype 1 -EventLog }		
	}
	
}

# If we are here without any errors then all 
# services have been stopped and all applications 
# have been removed.  We have a clean slate
Write-LogAndOut "Starting the Installation of $Installer1." -etype 4
Try { Start-Process "msiexec" -ArgumentList "/i $Installer1 /qn /l*vx+ $MyLog" -PassThru -Wait }
Catch { Write-LogAndOut "Installation failed check the $MyLog file for details." -etype 1 -EventLog  }

Write-LogAndOut "Starting the Installation of $Installer2." -etype 4
Try { Start-Process "msiexec" -ArgumentList "/i $Installer2 /qn /l*vx+ $MyLog" -PassThru -Wait }
Catch { Write-LogAndOut "Installation failed check the $MyLog file for details." -etype 1 -EventLog }

# Last, but not least, start the VPN so they connect & update if needed.
Write-LogAndOut "Starting the Application" -etype 4
Try { Start-Process "C:\Program Files (x86)\Cisco\Cisco AnyConnect Secure Mobility Client\vpnui.exe" -PassThru }
Catch { Write-LogAndOut "Failed to start the application." -etype 1 -EventLog }

$LASTEXITCODE
exit 0
