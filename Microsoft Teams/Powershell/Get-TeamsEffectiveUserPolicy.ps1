function Get-TeamsEffectiveUserPolicy {

    param (
        [Parameter(mandatory = $true)]
        $UserID,
        [Parameter(mandatory = $true)]
        [ValidateSet("TeamsAppPermissionPolicy", "TeamsAppSetupPolicy", "TeamsAudioConferencingPolicy", "TeamsCallParkPolicy", "TeamsCallingPolicy", "TenantDialPlan", "TeamsEmergencyCallRoutingPolicy", "TeamsEmergencyCallingPolicy", "TeamsEnhancedEncryptionPolicy", "TeamsMeetingPolicy", "TeamsMessagingPolicy", "TeamsUpdatePolicy", "TeamsVoiceRoutingPolicy", "TeamsVoicemailPolicy")]
        [string]$Policy,
        [switch]$ShowAll
    )
    $result = @()
    $UserPolicies = $null
    $Assigned = $null
    $direct = $null
    $userGPA = $null
    $ListAllPolicies = $false

    if ($null -eq (Get-CsOnlineUser $userid)) {
        $result = "User not found"
    }
    else {

        if ($ShowAll.ispresent) { $ListAllPolicies = $true }

        $UserPolicies = @(get-csuserpolicyassignment -identity $userID -PolicyType $Policy)
        $Assigned = @(get-csuserpolicyassignment -identity $userID -PolicyType $Policy | Select-Object -ExpandProperty PolicySource)
        if ([string]::IsNullOrEmpty($UserPolicies)) {
            $result = [pscustomobject]@{Assignment = "[3] Global"; PolicyName = "<not set>"; Rank = "" }
        }
        else {
            if ($assigned.Assignmenttype -contains 'Group') {
                #No direct assignment
                #Get Group Policy assignments and check order
                $userGPA = @(Get-CSGroupPolicyAssignment | Where-Object { $_.groupID -in $assigned.reference -and $_.PolicyType -like $policy })
                $userGPA = $userGPA | Sort-Object Priority
                $policyCount = $userGPA.count
                if (!($ListAllPolicies)) {
                    $userGPA = @($userGPA | Select-Object -First 1)
                }
                $i = 0
                foreach ($entry in $userGPA) {
                    $i++
                    $output = [pscustomobject]@{
                        Assignment = "[2] Group [$($i)/$($policyCount)]"
                        PolicyName = "$($entry.PolicyName)"
                        Rank       = "$($entry.priority)"
                    }
                    $result += $output
                }
            }
        }
        if ($assigned.Assignmenttype -contains 'Direct') {
            #Direct assignment to user
            $direct = $assigned | where-object { $_.AssignmentType -like 'Direct' }
            $output = [pscustomobject]@{Assignment = "[1] Direct (Applied)"; PolicyName = "$($direct.PolicyName)"; Rank = "1" }
            if ($ListAllPolicies) {
                $result += $output
            }
            else {
                $result = $output
            }
        }
        $result = $result | Sort-Object Assignment
    }
    Return $result
}