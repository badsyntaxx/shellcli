function edit-user-group {
    try {
        $user = select-user

        if ($user["Source"] -eq "Local") { 
            Edit-LocalUserGroup -User $user 
        } else { 
            Edit-ADUserGroup 
        }
    } catch {
        write-text -type "error" -text "edit-user-group-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
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
                "Cancel" = "Choose neither and exit this function."
            }) -prompt "Do you want to add or remove this user from groups?" -returnKey

        if ($addOrRemove -eq "Cancel") {
            read-command
        }

        if ($addOrRemove -eq "Add") {
            add-groups -username $user["Name"]
        } else {
            remove-groups -username $user["Name"]
        }

        write-text -type "success" -text "Group membership updated."
    } catch {
        write-text -type "error" -text "Edit-LocalUserGroup-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function add-groups {
    param(
        [Parameter(Mandatory = $true)]
        [string]$username
    )
    
    $default = Get-LocalGroup | ForEach-Object {
        $description = $_.Description
        @{ $_.Name = $description }
    } | Sort-Object -Property Name

    $groups = [ordered]@{}
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

    $groups["Cancel"] = "Select nothing and exit this function."
    $selectedGroups = @()
    $selectedGroups += read-option -options $groups -prompt "Select a group:" -returnKey

    if ($selectedGroups -eq "Cancel") {
        read-command
    }

    $groupsList = [ordered]@{}
    $groupsList["Done"] = "Stop selecting groups and move to the next step."
    $groupsList += $groups

    while ($selectedGroups -notcontains 'Done') {
        $availableGroups = [ordered]@{}
        foreach ($key in $groupsList.Keys) {
            if ($selectedGroups -notcontains $key) {
                $availableGroups[$key] = $groupsList[$key]
            }
        }

        $selectedGroups += read-option -options $availableGroups -prompt "Select another group or 'Done':" -ReturnKey
        if ($selectedGroups -eq "Cancel") {
            read-command
        }
    }

    foreach ($group in $selectedGroups) {
        if ($addOrRemove -eq "Add" -and $group -ne "Done") {
            Add-LocalGroupMember -Group $group -Member $username -ErrorAction SilentlyContinue | Out-Null 
        }
    }
}
function remove-groups {
    param(
        [Parameter(Mandatory = $true)]
        [string]$username
    )

    $groups = [ordered]@{}

    $allGroups = Get-LocalGroup

    # Check each group for the user's membership
    foreach ($group in $allGroups) {
        try {
            $members = Get-LocalGroupMember -Group $group.Name -ErrorAction Stop
            $isMember = $members | Where-Object {
                $_.Name -eq $Username -or 
                $_.SID.Value -eq $Username -or 
                $_ -eq $Username -or 
                $_ -like "*\$Username"
            }
            
            if ($isMember) {
                $description = $group.Description
                if ($description.Length -gt 72) { 
                    $description = $description.Substring(0, 72) + "..." 
                }
                $groups[$group.Name] = $description
            }
        } catch {
            # If there's an error (e.g., access denied), we skip this group
            Write-Verbose "Couldn't check membership for group $($group.Name): $_"
        }
    }

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

    if ($groups.Count -eq 0) {
        Write-Host "The user $Username is not a member of any local groups, or we don't have permission to check."

    }

    # Add a "Cancel" option
    $groups["Cancel"] = "Select nothing and exit this function."

    $selectedGroups = @()
    $selectedGroups += read-option -options $groups -prompt "Select a group:" -returnKey

    if ($selectedGroups -eq "Cancel") {
        read-command
    }

    $groupsList = [ordered]@{}
    $groupsList["Done"] = "Stop selecting groups and move to the next step."
    $groupsList += $groups

    while ($selectedGroups -notcontains 'Done') {
        $availableGroups = [ordered]@{}

        foreach ($key in $groupsList.Keys) {
            if ($selectedGroups -notcontains $key) {
                $availableGroups[$key] = $groupsList[$key]
            }
        }

        $selectedGroups += read-option -options $availableGroups -prompt "Select another group or 'Done':" -ReturnKey

        if ($selectedGroups -eq "Cancel") {
            read-command
        }
    }

    foreach ($group in $selectedGroups) {
        if ($group -ne "Done") {
            Remove-LocalGroupMember -Group $group -Member $username -ErrorAction SilentlyContinue
        }
    }
}
function Edit-ADUserGroup {
    write-text -type "plain" -text "Editing domain users doesn't work yet."
}