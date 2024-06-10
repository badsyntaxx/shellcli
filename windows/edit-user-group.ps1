function edit-user-group {
    try {
        $user = select-user

        if ($user["Source"] -eq "Local") { Edit-LocalUserGroup -User $user } else { Edit-ADUserGroup }
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "edit-user-group-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
} 

function Edit-LocalUserGroup {
    param (
        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$user
    )

    try {
        $addOrRemove = read-option -options $([ordered]@{
                "Add"    = "Add this user to more groups"
                "Remove" = "Remove this user from certain groups"
            }) -returnKey

        $default = Get-LocalGroup | ForEach-Object {
            $description = $_.Description
            # if ($description.Length -gt 72) { $description = $description.Substring(0, 72) + "..." }
            @{ $_.Name = $description }
        } | Sort-Object -Property Name
    
        $groups = [ordered]@{}

        # Shorten group descriptions by manually creating shorter ones.
        foreach ($group in $default) { 
            # $groups += $group
            switch ($group.Keys) {
                "Performance Monitor Users" { $groups["$($group.Keys)"] = "Access local performance counter data." }
                "Power Users" { $groups["$($group.Keys)"] = "Limited administrative privileges." }
                "Network Configuration Operators" { $groups["$($group.Keys)"] = "Privileges for managing network configuration." }
                "Performance Log Users" { $groups["$($group.Keys)"] = "Schedule performance counter logging." }
                "Remote Desktop Users" { $groups["$($group.Keys)"] = "Log on remotely." }
                "System Managed Accounts Group" { $groups["$($group.Keys)"] = "Managed by the system." }
                "Users" { $groups["$($group.Keys)"] = "Prevented from making system-wide changes." }
                "Remote Management Users" { $groups["$($group.Keys)"] = "Access WMI resources over management protocols." }
                "Replicator" { $groups["$($group.Keys)"] = "Supports file replication in a domain." }
                "IIS_IUSRS" { $groups["$($group.Keys)"] = "Used by Internet Information Services (IIS)." }
                "Backup Operators" { $groups["$($group.Keys)"] = "Override security restrictions for backup purposes." }
                "Cryptographic Operators" { $groups["$($group.Keys)"] = "Perform cryptographic operations." }
                "Access Control Assistance Operators" { $groups["$($group.Keys)"] = "Remotely query authorization attributes and permissions." }
                "Administrators" { $groups["$($group.Keys)"] = "Complete, unrestricted access to the computer/domain." }
                "Device Owners" { $groups["$($group.Keys)"] = "Can change system-wide settings." }
                "Guests" { $groups["$($group.Keys)"] = "Similar access to members of the Users group by default." }
                "Hyper-V Administrators" { $groups["$($group.Keys)"] = "Complete and unrestricted access to all Hyper-V features." }
                "Distributed COM Users" { $groups["$($group.Keys)"] = "Authorized for Distributed Component Object Model (DCOM) operations." }
            }
        }
    
        $selectedGroups = @()
        $selectedGroups += read-option -options $groups -returnKey

        $groupsList = [ordered]@{}
        $groupsList["Done"] = "Stop selecting groups and move to the next step."
        $groupsList += $groups

        while ($selectedGroups -notcontains 'Done') {
            $availableGroups = [ordered]@{}

            write-text -text "    Selected groups:" -lineBefore
            foreach ($selectedGroup in $selectedGroups) {
                Write-Host "            $selectedGroup" -ForegroundColor "DarkGray"
            }

            # Iterate through the keys in the hashtable
            foreach ($key in $groupsList.Keys) {
                if ($selectedGroups -notcontains $key) {
                    # Add the key-value pair to the filtered groups
                    $availableGroups[$key] = $groupsList[$key]
                }
            }

            # $availableGroups
            $selectedGroups += read-option -options $availableGroups -ReturnKey
        }

        get-closing -Script "Edit-LocalUserGroup"

        foreach ($group in $selectedGroups) {
            if ($addOrRemove -eq "Add" -and $group -ne "Done") {
                Add-LocalGroupMember -Group $group -Member $user["Name"] -ErrorAction SilentlyContinue | Out-Null 
            } else {
                Remove-LocalGroupMember -Group $group -Member $user["Name"] -ErrorAction SilentlyContinue
            }
        }

        $updatedUser = get-userdata -username $user["Name"]
        write-text -type "list" -list $updatedUser -lineAfter
        exit-script -type "success" -text "The group membership for $($user["Name"]) has been changed to $group." -lineAfter
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "Edit-LocalUserGroup-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

function Edit-ADUserGroup {
    write-text -type "fail" -text "Editing domain users doesn't work yet."
}
