function editUser {
    try {
        $choice = readOption -options $([ordered]@{
                "Edit user name"     = "Edit an existing users name."
                "Edit user password" = "Edit an existing users password."
                "Edit user group"    = "Edit an existing users group membership."
                "Cancel"             = "Do nothing and exit this function."
            }) -prompt "What would you like to edit?"

        switch ($choice) {
            0 { editUserName }
            1 { editUserPassword }
            2 { editUserGroup }
            3 { readCommand }
        }
    } catch {
        writeText -type "error" -text "editUser-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function editUserName {
    try {
        $user = selectUser

        if ($user["Source"] -eq "MicrosoftAccount") { 
            writeText -type "notice" -text "Cannot edit Microsoft accounts."
        }

        if ($user["Source"] -eq "Local") { 
            $newName = readInput -prompt "Enter username:" -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,64})$" -CheckExistingUser
    
            Rename-LocalUser -Name $user["Name"] -NewName $newName

            $newUser = Get-LocalUser -Name $newName

            if ($null -ne $newUser) { 
                writeText -type "success" -text "Account name changed"
            } else {
                writeText -type "error" -text "Unknown error"
            }
        } else { 
            writeText -type "notice" -text "Editing domain users doesn't work yet."
        }
    } catch {
        writeText -type "error" -text "editUser-name-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function editUserPassword {
    try {
        $user = selectUser

        if ($user["Source"] -eq "MicrosoftAccount") { 
            writeText -type "notice" -text "Cannot edit Microsoft accounts."
        }

        if ($user["Source"] -eq "Local") { 
            $password = readInput -prompt "Enter password or leave blank:" -IsSecure $true

            if ($password.Length -eq 0) { 
                $message = "Password removed" 
            } else { 
                $message = "Password changed" 
            }

            Get-LocalUser -Name $user["Name"] | Set-LocalUser -Password $password

            writeText -Type "success" -text $message
        } else { 
            writeText -type "plain" -text "Editing domain users doesn't work yet."
        }
    } catch {
        writeText -type "error" -text "editUserPassword-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function editUserGroup {
    try {
        $user = selectUser

        if ($user["Source"] -eq "MicrosoftAccount") { 
            writeText -type "notice" -text "Cannot edit Microsoft accounts."
        }

        if ($user["Source"] -eq "Local") { 
            $choice = readOption -options $([ordered]@{
                    "Add"    = "Add this user to more groups"
                    "Remove" = "Remove this user from certain groups"
                    "Cancel" = "Do nothing and exit this function."
                }) -prompt "Do you want to add or remove this user from groups?"

            switch ($choice) {
                0 { addGroups -username $user["Name"] }
                1 { removeGroups -username $user["Name"] }
                2 { readCommand }
            }

            writeText -type "success" -text "Group membership updated."
        } else { 
            writeText -type "plain" -text "Editing domain users doesn't work yet."
        }
    } catch {
        writeText -type "error" -text "editUserGroup-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
} 
function addGroups {
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
    $selectedGroups += readOption -options $groups -prompt "Select a group:" -returnKey

    if ($selectedGroups -eq "Cancel") {
        readCommand
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

        $selectedGroups += readOption -options $availableGroups -prompt "Select another group or 'Done':" -ReturnKey
        if ($selectedGroups -eq "Cancel") {
            readCommand
        }
    }

    foreach ($group in $selectedGroups) {
        if ($group -ne "Done") {
            Add-LocalGroupMember -Group $group -Member $username -ErrorAction SilentlyContinue | Out-Null 
        }
    }
}
function removeGroups {
    param(
        [Parameter(Mandatory = $true)]
        [string]$username
    )

    try {
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

        $groups

        foreach ($group in $groups) { 
            switch ($group.Name) {
                "Performance Monitor Users" { $groups["$($group.Name)"] = "Access local performance counter data." }
                "Power Users" { $groups["$($group.Name)"] = "Limited administrative privileges." }
                "Network Configuration Operators" { $groups["$($group.Name)"] = "Privileges for managing network configuration." }
                "Performance Log Users" { $groups["$($group.Name)"] = "Schedule performance counter logging." }
                "Remote Desktop Users" { $groups["$($group.Name)"] = "Log on remotely." }
                "System Managed Accounts Group" { $groups["$($group.Name)"] = "Managed by the system." }
                "Users" { $groups["$($group.Name)"] = "Prevented from making system-wide changes." }
                "Remote Management Users" { $groups["$($group.Name)"] = "Access WMI resources over management protocols." }
                "Replicator" { $groups["$($group.Name)"] = "Supports file replication in a domain." }
                "IIS_IUSRS" { $groups["$($group.Name)"] = "Used by Internet Information Services (IIS)." }
                "Backup Operators" { $groups["$($group.Name)"] = "Override security restrictions for backup purposes." }
                "Cryptographic Operators" { $groups["$($group.Name)"] = "Perform cryptographic operations." }
                "Access Control Assistance Operators" { $groups["$($group.Name)"] = "Remotely query authorization attributes and permissions." }
                "Administrators" { $groups["$($group.Name)"] = "Complete, unrestricted access to the computer/domain." }
                "Device Owners" { $groups["$($group.Name)"] = "Can change system-wide settings." }
                "Guests" { $groups["$($group.Name)"] = "Similar access to members of the Users group by default." }
                "Hyper-V Administrators" { $groups["$($group.Name)"] = "Complete and unrestricted access to all Hyper-V features." }
                "Distributed COM Users" { $groups["$($group.Name)"] = "Authorized for Distributed Component Object Model (DCOM) operations." }
            }
        }

        if ($groups.Count -eq 0) {
            Write-Host "The user $Username is not a member of any local groups, or we don't have permission to check."
        }

        # Add a "Cancel" option
        $groups["Cancel"] = "Select nothing and exit this function."

        $selectedGroups = @()
        $selectedGroups += readOption -options $groups -prompt "Select a group:" -returnKey

        if ($selectedGroups -eq "Cancel") {
            readCommand
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

            $selectedGroups += readOption -options $availableGroups -prompt "Select another group or 'Done':" -ReturnKey

            if ($selectedGroups -eq "Cancel") {
                readCommand
            }
        }

        foreach ($group in $selectedGroups) {
            if ($group -ne "Done") {
                Remove-LocalGroupMember -Group $group -Member $username -ErrorAction SilentlyContinue
            }
        }
    } catch {
        writeText -type "error" -text "remove-group-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}