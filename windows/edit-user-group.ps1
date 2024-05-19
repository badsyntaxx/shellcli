function edit-user-group {
    try {
        write-welcome -Title "Edit User Group" -Description "Edit an existing users group membership." -Command "edit user group"

        $user = select-user

        if ($user["Source"] -eq "Local") { Edit-LocalUserGroup -User $user } else { Edit-ADUserGroup }
    } catch {
        # Display error message and end the script
        exit-script -Type "error" -Text "Error | edit-user-group-$($_.InvocationInfo.ScriptLineNumber)"
    }
} 

function Edit-LocalUserGroup {
    param (
        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$User
    )

    try {
        write-text -Type "header" -Text "Add or Remove user from groups" -LineAfter
        $addOrRemove = get-option -Options $([ordered]@{
                "Add"    = "Add this user to more groups"
                "Remove" = "Remove this user from certain groups"
            }) -ReturnKey

        write-text -Type "header" -Text "Select user group" -LineBefore -LineAfter
        $groups = Get-LocalGroup | ForEach-Object {
            $description = $_.Description
            if ($description.Length -gt 72) { $description = $description.Substring(0, 72) + "..." }
            @{ $_.Name = $description }
        } | Sort-Object -Property Name
    
        $moreGroups = [ordered]@{}

        foreach ($group in $groups) { 
            $moreGroups += $group
            switch ($group.Keys) {
                "Performance Monitor Users" { $moreGroups["$($group.Keys)"] = "Access local performance counter data." }
                "Power Users" { $moreGroups["$($group.Keys)"] = "Limited administrative privileges." }
                "Network Configuration Operators" { $moreGroups["$($group.Keys)"] = "Privileges for managing network configuration." }
                "Performance Log Users" { $moreGroups["$($group.Keys)"] = "Schedule performance counter logging." }
                "Remote Desktop Users" { $moreGroups["$($group.Keys)"] = "Log on remotely." }
                "System Managed Accounts Group" { $moreGroups["$($group.Keys)"] = "Managed by the system." }
                "Users" { $moreGroups["$($group.Keys)"] = "Prevented from making system-wide changes." }
                "Remote Management Users" { $moreGroups["$($group.Keys)"] = "Access WMI resources over management protocols." }
                "Replicator" { $moreGroups["$($group.Keys)"] = "Supports file replication in a domain." }
                "IIS_IUSRS" { $moreGroups["$($group.Keys)"] = "Used by Internet Information Services (IIS)." }
                "Backup Operators" { $moreGroups["$($group.Keys)"] = "Override security restrictions for backup purposes." }
                "Cryptographic Operators" { $moreGroups["$($group.Keys)"] = "Perform cryptographic operations." }
                "Access Control Assistance Operators" { $moreGroups["$($group.Keys)"] = "Remotely query authorization attributes and permissions." }
                "Administrators" { $moreGroups["$($group.Keys)"] = "Complete, unrestricted access to the computer/domain." }
                "Device Owners" { $moreGroups["$($group.Keys)"] = "Can change system-wide settings." }
                "Guests" { $moreGroups["$($group.Keys)"] = "Similar access to members of the Users group by default." }
                "Hyper-V Administrators" { $moreGroups["$($group.Keys)"] = "Complete and unrestricted access to all Hyper-V features." }
                "Distributed COM Users" { $moreGroups["$($group.Keys)"] = "Authorized for Distributed Component Object Model (DCOM) operations." }
            }
        }
    
        $selectedGroups = @()
        $selectedGroups += get-option -Options $moreGroups -ReturnKey

        $moreGroupsDone = [ordered]@{}
        $moreGroupsDone["Done"] = "Stop selecting groups and move to the next step."
        $moreGroupsDone += $moreGroups
        $previewString = ""

        while ($selectedGroups -notcontains 'Done') {
            $previewString = $selectedGroups -join ","
            write-text -Type "header" -Text "$previewString" -LineBefore -LineAfter
            $selectedGroups += get-option -Options $moreGroupsDone -ReturnKey 
        }

        write-text -Type "header" -Text "YOU'RE ABOUT TO CHANGE THIS USERS GROUP MEMBERSHIP." -LineBefore -LineAfter
        get-closing -Script "Edit-LocalUserGroup"

        foreach ($group in $selectedGroups) {
            if ($addOrRemove -eq "Add") {
                Add-LocalGroupMember -Group $group -Member $User["Name"] -ErrorAction SilentlyContinue | Out-Null 
            } else {
                Remove-LocalGroupMember -Group $group -Member $User["Name"] -ErrorAction SilentlyContinue
            }
        }

        write-text -Type "list" -List $User -LineAfter
        exit-script -Type "success" -Text "The group membership for $($User["Name"]) has been changed to $group." -LineAfter
    } catch {
        # Display error message and end the script
        exit-script -Type "error" -Text "edit-user-group-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -LineAfter
    }
}

function Edit-ADUserGroup {
    write-text -Type "fail" -Text "Editing domain users doesn't work yet."
}

