function addUser {
    try {
        $choice = readOption -options $([ordered]@{
                "Add local user"  = "Add a local user to the system."
                "Add domain user" = "Add a domain user to the system."
                "Cancel"          = "Do nothing and exit this function."
            }) -prompt "Select a user account type." -lineAfter

        switch ($choice) {
            0 { addLocalUser }
            1 { addADUser }
            2 { readCommand }
        }
    } catch {
        writeText -type "error" -text "addUser-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function addLocalUser {
    try {
        writeText -type "prompt" -text "Enter user credentials."

        $name = readInput -prompt "Username:" -Validate "^([a-zA-Z0-9 ._\-]{1,64})$" -CheckExistingUser
        $password = readInput -prompt "Password:" -IsSecure -lineAfter
        $group = readOption -options $([ordered]@{
                "Administrators" = "Set this user's group membership to administrators."
                "Users"          = "Set this user's group membership to standard users."
            }) -prompt "Select a user group" -returnKey -lineAfter

        # Create the new local user and add to the specified group
        New-LocalUser $name -Password $password -description "Local User" -AccountNeverExpires -PasswordNeverExpires -ErrorAction Stop | Out-Null

        $newUser = Get-LocalUser -Name $name
        if ($null -eq $newUser) {
            # User creation failed, exit with error
            writeText -type 'error' -text "Failed to create user $name. Please check the logs for details."
        }

        Add-LocalGroupMember -Group $group -Member $name -ErrorAction Stop | Out-Null

        # There is a powershell bug with Get-LocalGroupMember So we can't do a manual check.
        <# if ((Get-LocalGroupMember -Group $group -Name $name).Count -gt 0) {
            writeText -type "success" -text "$name has been assigned to the $group group." -lineAfter
        } else {
            writeText -type 'error' -text  "$($_.Exception.Message)"
        } #>

        $password = $null

        # Because of the bug listed above we just assume success if the script is still executing at this point.
        writeText -type "success" -text "Local user added."
    } catch {
        writeText -type "error" -text "addLocalUser-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function addADUser {
    try {
        $name = readInput -prompt "Enter a user name:" -Validate "^([a-zA-Z0-9 _\-]{1,64})$"  -CheckExistingUser
        $nameParts = $name -split ' '
        $GivenName = $nameParts[0]
        $Surname = $nameParts[-1]
        $samAccountName = readInput -prompt "Enter a sam name:" -Validate "^([a-zA-Z0-9 _\-]{1,20})$"  -CheckExistingUser
        $password = readInput -prompt "Enter a password:" -IsSecure
        $choice = readOption -options $([ordered]@{
                "Administrator" = "Create admin user"
                "Standard user" = "Create standard user"
            }) -prompt "Set group membership"
        $domainName = $env:USERDNSDOMAIN
        
        if ($choice -eq 0) { 
            $group = 'Administrators' 
        } else { 
            $group = "Users" 
        }

        New-ADUser -Name $name 
        -SamAccountName $samAccountName 
        -GivenName $GivenName
        -Surname $Surname
        -UserPrincipalName "$samAccountName@$domainName.com" 
        -AccountPassword $password 
        -Enabled $true

        Add-LocalGroupMember -Group $group -Member $name -ErrorAction Stop

        $data = getUserData -Username $name

        $password = $null

        writeText -type "list" -List $data -lineAfter

        writeText -type "success" -text "The user account was created."
    } catch {
        writeText -type "error" -text "addADUser-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function editUser {
    try {
        $user = selectUser -lineAfter

        $choice = readOption -options $([ordered]@{
                "Edit user name"     = "Edit an existing users name."
                "Edit user password" = "Edit an existing users password."
                "Edit user group"    = "Edit an existing users group membership."
                "Cancel"             = "Do nothing and exit this function."
            }) -prompt "What would you like to edit?" -lineAfter

        switch ($choice) {
            0 { editUserName -user $user }
            1 { editUserPassword -user $user }
            2 { editUserGroup -user $user }
            3 { readCommand }
        }
    } catch {
        writeText -type "error" -text "editUser-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function editUserName {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$user
    )
        
    try {
        writeText -type "prompt" -text "Enter a new username."

        if ($user["Source"] -eq "MicrosoftAccount") { 
            writeText -type "notice" -text "Cannot edit Microsoft accounts."
        }

        if ($user["Source"] -eq "Local") { 
            $newName = readInput -prompt "Username:" -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,64})$" -CheckExistingUser
    
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
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$user
    )

    try {
        writeText -type "prompt" -text "Enter a new password."

        if ($user["Source"] -eq "MicrosoftAccount") { 
            writeText -type "notice" -text "Cannot edit Microsoft accounts."
        }

        if ($user["Source"] -eq "Local") { 
            $password = readInput -prompt "Password:" -IsSecure $true

            if ($password.Length -eq 0) { 
                $message = "Password removed" 
            } else { 
                $message = "Password changed" 
            }

            Get-LocalUser -Name $user["Name"] | Set-LocalUser -Password $password

            $password = $null

            writeText -Type "success" -text $message
        } else { 
            writeText -type "plain" -text "Editing domain users doesn't work yet."
        }
    } catch {
        writeText -type "error" -text "editUserPassword-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function editUserGroup {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$user
    )

    try {
        if ($user["Source"] -eq "MicrosoftAccount") { 
            writeText -type "notice" -text "Cannot edit Microsoft accounts."
        }

        if ($user["Source"] -eq "Local") { 
            $choice = readOption -options $([ordered]@{
                    "Add"    = "Add this user to more groups"
                    "Remove" = "Remove this user from certain groups"
                    "Cancel" = "Do nothing and exit this function."
                }) -prompt "Do you want to add or remove this user from groups?" -lineAfter

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
function removeUser {
    try {
        $user = selectUser -prompt "Select an account to remove." -lineAfter
        $userSid = (Get-LocalUser $user["Name"]).Sid
        $userProfile = Get-CimInstance Win32_UserProfile -Filter "SID = '$userSid'"
        $dir = $userProfile.LocalPath

        $choice = readOption -options $([ordered]@{
                "Delete" = "Also delete the users data."
                "Keep"   = "Do not delete the users data."
                "Cancel" = "Do not delete anything and exit this function."
            }) -prompt "Do you also want to delete the users data?" -lineAfter

        if ($choice -eq 2) {
            return
        }

        Remove-LocalUser -Name $user["Name"] | Out-Null

        $response = "The user has been removed."
        if ($choice -eq 0 -and $dir) { 
            try {
                # Attempt to take ownership and grant full control
                $acl = Get-Acl $dir
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    [System.Security.Principal.WindowsIdentity]::GetCurrent().User, 
                    "FullControl", 
                    "ContainerInherit,ObjectInherit", 
                    "None", 
                    "Allow"
                )
                $acl.SetAccessRule($rule)
                Set-Acl $dir $acl

                # Remove files with full permissions
                Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
                
                # Verify profile folder deletion
                $profileStillExists = Get-CimInstance Win32_UserProfile -Filter "SID = '$userSid'" -ErrorAction SilentlyContinue

                if ($null -eq $profileStillExists) {
                    $response += " as well as their data."
                } else {
                    writeText -type 'error' -text "Unable to delete user data for unknown reasons."
                    $response += " but their data could not be fully deleted."
                }
            } catch {
                writeText -type 'error' -text "Failed to delete user profile folder: $($_.Exception.Message)"
                $response += " but their data could not be deleted."
            }
        } elseif ($choice -eq 1) {
            $response += " but not their data."
        }

        writeText -type 'success' -text $response

        removeUser
    } catch {
        writeText -type "error" -text "removeUser-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function listUsers {
    try {
        # Initialize empty array to store user names
        $userNames = @()

        # Get all local users on the system
        $localUsers = Get-LocalUser

        # Define a list of accounts to exclude from selection
        $excludedAccounts = @("DefaultAccount", "WDAGUtilityAccount", "Guest", "defaultuser0")

        # Check if the "Administrator" account is disabled and add it to excluded list if so
        $adminEnabled = Get-LocalUser -Name "Administrator" | Select-Object -ExpandProperty Enabled
        if (!$adminEnabled) { 
            $excludedAccounts += "Administrator" 
        }

        # Filter local users to exclude predefined accounts
        foreach ($user in $localUsers) {
            if ($user.Name -notin $excludedAccounts) { 
                $userNames += $user.Name 
            }
        }

        # Create an ordered dictionary to store username and group information
        $accounts = [ordered]@{}
        foreach ($name in $userNames) {
            # Get details for the current username
            $username = Get-LocalUser -Name $name
            
            # Find groups the user belongs to
            $groups = Get-LocalGroup | Where-Object { $username.SID -in ($_ | Get-LocalGroupMember | Select-Object -ExpandProperty "SID") } | Select-Object -ExpandProperty "Name"
            # Convert groups to a semicolon-separated string
            $groupString = $groups -join ';'

            # Get the users source
            $source = Get-LocalUser -Name $username | Select-Object -ExpandProperty PrincipalSource

            # Add username and group string to the dictionary
            $accounts["$username"] = "$source | $groupString"
        }

        # Display user data as a list
        writeText -type "list" -List $accounts
        
    } catch {
        writeText -type "error" -text "listUsers-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}