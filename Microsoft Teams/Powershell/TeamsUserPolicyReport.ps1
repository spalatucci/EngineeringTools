$TeamsUsers = Get-CsOnlineUser | Select-Object DisplayName,ObjectId,UserPrincipalName, `
    SipAddress,Enabled,WindowsEmailAddress,LineURI,HostedVoiceMail,OnPremEnterpriseVoiceEnabled,OnPremLineURI,SipProxyAddress, `
    OnlineDialinConferencingPolicy,TeamsUpgradeEffectiveMode,TeamsUpgradePolicy,HostingProvider

$TeamsReport = @()

Foreach ($User in $TeamsUsers) {
    $Info = "" | Select "DisplayName","ObjectId","UserPrincipalName","SipAddress","Enabled","LineURI", `
    "WindowsEmailAddress","HostedVoiceMail","OnPremEnterpriseVoiceEnabled","OnPremLineURI","SipProxyAddress", `
    "OnlineDialinConferencingPolicy","TeamsUpgradeEffectiveMode","TeamsUpgradePolicy","HostingProvider", `
    "VoicePolicy","MeetingPolicy","TeamsMeetingPolicy","TeamsMessagingPolicy","TeamsAppSetupPolicy", `
    "TeamsCallingPolicy","VoicePolicySource","MeetingPolicySource","TeamsMeetingPolicySource", `
    "TeamsMessagingPolicySource","TeamsAppSetupPolicySource","TeamsCallingPolicySource"

    Write-Host "Querying policy information for" $User.DisplayName -ForegroundColor Green

    $UserPolicies = Get-CsUserPolicyAssignment -Identity $User.ObjectId

    $Info.DisplayName = $User.DisplayName
	$Info.ObjectId = $User.ObjectId
	$Info.UserPrincipalName = $User.UserPrincipalName
	$Info.SipAddress = $User.SipAddress
	$Info.Enabled = $User.Enabled
	$Info.LineURI = $User.LineURI
	$Info.WindowsEmailAddress = $User.WindowsEmailAddress
	$Info.HostedVoiceMail = $User.HostedVoiceMail
	$Info.OnPremEnterpriseVoiceEnabled = $User.OnPremEnterpriseVoiceEnabled
	$Info.OnPremLineURI = $User.OnPremLineURI
	$Info.SipProxyAddress = $User.SipProxyAddress
	$Info.OnlineDialinConferencingPolicy = $User.OnlineDialinConferencingPolicy
	$Info.TeamsUpgradeEffectiveMode = $User.TeamsUpgradeEffectiveMode
	$Info.TeamsUpgradePolicy = $User.TeamsUpgradePolicy
	$Info.HostingProvider = $User.HostingProvider
    $Info.VoicePolicy = ($UserPolicies | Where-Object {$_.PolicyType -eq "VoicePolicy"}).PolicyName
    $Info.VoicePolicy = (($UserPolicies | Where-Object {$_.PolicyType -eq "VoicePolicy"}).PolicySource).AssignmentType
    $Info.MeetingPolicy = ($UserPolicies | Where-Object {$_.PolicyType -eq "MeetingPolicy"}).PolicyName
    $Info.MeetingPolicySource = (($UserPolicies | Where-Object {$_.PolicyType -eq "MeetingPolicy"}).PolicySource).AssignmentType
    $Info.TeamsMeetingPolicy = ($UserPolicies | Where-Object {$_.PolicyType -eq "TeamsMeetingPolicy"}).PolicyName
    $Info.TeamsMeetingPolicySource = (($UserPolicies | Where-Object {$_.PolicyType -eq "TeamsMeetingPolicy"}).PolicySource).AssignmentType
    $Info.TeamsMessagingPolicy = ($UserPolicies | Where-Object {$_.PolicyType -eq "TeamsMessagingPolicy"}).PolicyName
    $Info.TeamsMessagingPolicySource = (($UserPolicies | Where-Object {$_.PolicyType -eq "TeamsMessagingPolicy"}).PolicySource).AssignmentType
    $Info.TeamsAppSetupPolicy = ($UserPolicies | Where-Object {$_.PolicyType -eq "TeamsAppSetupPolicy"}).PolicyName
    $Info.TeamsAppSetupPolicySource = (($UserPolicies | Where-Object {$_.PolicyType -eq "TeamsAppSetupPolicy"}).PolicySource).AssignmentType
    $Info.TeamsCallingPolicy = ($UserPolicies | Where-Object {$_.PolicyType -eq "TeamsCallingPolicy"}).PolicyName
    $Info.TeamsCallingPolicySource = (($UserPolicies | Where-Object {$_.PolicyType -eq "TeamsCallingPolicy"}).PolicySource).AssignmentType

    $TeamsReport += $Info
    $Info = $null
    }

$TeamsReport | Export-Csv .\TeamsReport.csv -NoTypeInformation