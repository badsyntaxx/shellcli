function userMenu {
    $choice = readOption -options $([ordered]@{
            "users"        = "List all users on the system."
            "toggle admin" = "Toggle the Windows built in administrator account."
            "add user"     = "Add a user to the system."
            "remove user"  = "Remove a user from the system."
            "edit user"    = "Edit a user."
            "unlock user"  = "Unlock a user account."
            "Cancel"       = "Select nothing and exit this menu."
        }) -prompt "Select a function:"

    switch ($choice) {
        0 { listUsers }
        1 { toggleAdmin }
        2 { addUser }
        3 { removeUser }
        4 { editUser }
        5 { unlockUser }
        6 { return }
    }
}
function addUser {
    try {
        $choice = readOption -options $([ordered]@{
                "Add local user"  = "Add a local user to the system."
                "Add domain user" = "Add a domain user to the system."
                "Cancel"          = "Do nothing and exit this function."
            }) -prompt "Select a user account type:" -lineAfter

        switch ($choice) {
            0 { addLocalUser }
            1 { addADUser }
            2 { return }
        }
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function getLocalUserNamePattern {
    # 1 to 20 characters (the limit for a local account name) that start and end with a
    # letter, digit, underscore or hyphen, so blank, dot-only and space-only names are refused.
    return '^[a-zA-Z0-9_\-]([a-zA-Z0-9 ._\-]{0,18}[a-zA-Z0-9_\-])?$'
}
function reportPasswordRejected {
    <#
        Windows gives no reason when it rejects a password (the exception has no
        message), so say which rules the local password policy has.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$name
    )

    writeText -type "error" -text "Windows rejected the password for $name. It does not meet this computer's password policy."
    foreach ($requirement in (getPasswordPolicyRequirements)) {
        writeText -type "plain" -text "  - $requirement"
    }
}
function addLocalUser {
    try {
        writeText -type "prompt" -text "Enter user credentials."

        $name = readInput -prompt "Username:" -Validate (getLocalUserNamePattern) -CheckExistingUser
        if ($null -eq $name) { return }

        $password = readInput -prompt "Password:" -isSecure -lineAfter
        if ($null -eq $password) { return }

        $group = readOption -options $([ordered]@{
                "Administrators" = "Set this user's group membership to administrators."
                "Users"          = "Set this user's group membership to standard users."
                "Cancel"         = "Do not create the user and exit this function."
            }) -prompt "Select a user group:" -returnKey

        # Built-in groups are addressed by SID so this works on any display language.
        # Cancel, or a menu that returned nothing, is not a key here and ends the function.
        $groupSids = @{ "Administrators" = "S-1-5-32-544"; "Users" = "S-1-5-32-545" }
        if ([string]::IsNullOrEmpty("$group") -or -not $groupSids.ContainsKey("$group")) { return }

        try {
            New-LocalUser $name -Password $password -description "Local User" -AccountNeverExpires -PasswordNeverExpires -ErrorAction Stop | Out-Null
        } catch {
            if ($_.Exception.GetType().Name -ne 'InvalidPasswordException') { throw }

            reportPasswordRejected -name $name
            $password = $null
            return
        }

        $password = $null

        $newUser = Get-LocalUser -Name $name -ErrorAction SilentlyContinue
        if ($null -eq $newUser) {
            writeText -type 'error' -text "Failed to create user $name. Please check the logs for details."
            return
        }

        try {
            Add-LocalGroupMember -SID $groupSids[$group] -Member $name -ErrorAction Stop
        } catch {
            writeText -type "error" -text "The user ($name) was created, but adding it to the ($group) group failed: $($_.Exception.Message)"
            writeText -type "plain" -text "The account is not in any group yet. Use 'edit user group' to add it."
            return
        }

        writeText -type "success" -text "Local user ($name) was created and added to the ($group) group."
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function addADUser {
    try {
        $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        if ($computer.DomainRole -ne 4 -and $computer.DomainRole -ne 5) {
            writeText -type 'notice' -text "This machine is NOT a Domain Controller."
            return
        }

        $name = readInput -prompt "Enter a user name:" -Validate "^([a-zA-Z0-9 _\-]{1,64})$"
        if ($null -eq $name) { return }

        $name = $name.Trim()
        if ($name.Length -eq 0) {
            writeText -type "notice" -text "The name cannot be blank."
            return
        }

        $samAccountName = readInput -prompt "Enter a sam name:" -Validate "^([a-zA-Z0-9_\-]{1,20})$"
        if ($null -eq $samAccountName) { return }

        # The local-account check readInput offers does not apply to domain accounts.
        if (Get-ADUser -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction SilentlyContinue) {
            writeText -type "error" -text "An account with the sam name $samAccountName already exists."
            return
        }

        $password = readInput -prompt "Enter a password:" -isSecure
        if ($null -eq $password) { return }

        $choice = readOption -options $([ordered]@{
                "Administrator" = "Create admin user (member of the Administrators group)"
                "Standard user" = "Create standard user (member of the Users group)"
                "Cancel"        = "Do not create the user and exit this function."
            }) -prompt "Set group membership"

        if ($choice -eq 0) {
            $group = "Administrators"
            $groupSid = "S-1-5-32-544"
        } elseif ($choice -eq 1) {
            $group = "Users"
            $groupSid = "S-1-5-32-545"
        } else {
            return
        }

        # Parameters are splatted: a command broken over several lines without
        # continuation characters runs as separate statements.
        $nameParts = @($name -split '\s+')
        $params = @{
            Name              = $name
            SamAccountName    = $samAccountName
            UserPrincipalName = "$samAccountName@$($computer.Domain)"
            AccountPassword   = $password
            Enabled           = $true
        }
        if ($nameParts.Count -gt 1) {
            $params["GivenName"] = $nameParts[0]
            $params["Surname"] = $nameParts[-1]
        } else {
            $params["GivenName"] = $name
        }

        New-ADUser @params -ErrorAction Stop
        $password = $null

        try {
            Add-ADGroupMember -Identity $groupSid -Members $samAccountName -ErrorAction Stop
        } catch {
            writeText -type "error" -text "The account ($name) was created, but adding it to the ($group) group failed: $($_.Exception.Message)"
            return
        }

        writeText -type "table" -Table ([ordered]@{
                "Name"      = $name
                "Sam name"  = $samAccountName
                "Logon"     = $params["UserPrincipalName"]
                "Group"     = $group
            }) -lineAfter

        writeText -type "success" -text "The user account was created."
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function editUser {
    try {
        $user = selectUser -lineAfter
        if (-not $user) { return }

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
            3 { return }
        }
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function editUserName {
    param (
        [parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary]$user
    )

    try {
        if (-not $user) {
            $user = selectUser -prompt "Which name would you like to edit?" -lineAfter
        }
        if (-not $user) { return }

        if ($user["Source"] -eq "MicrosoftAccount") {
            writeText -type "notice" -text "Cannot edit Microsoft accounts."
            return
        }

        if ($user["Source"] -ne "Local") {
            writeText -type "notice" -text "Editing domain users doesn't work yet."
            return
        }

        writeText -type "prompt" -text "Enter a new username."

        $newName = readInput -prompt "Username:" -Validate (getLocalUserNamePattern) -CheckExistingUser
        if ($null -eq $newName) { return }

        # Rename-LocalUser reports failures as non-terminating errors, so stop on them here.
        Rename-LocalUser -Name $user["Name"] -NewName $newName -ErrorAction Stop

        $newUser = Get-LocalUser -Name $newName -ErrorAction SilentlyContinue

        if ($null -ne $newUser) {
            writeText -type "success" -text "Account name $($user['Name']) changed to $newName."
        } else {
            writeText -type "error" -text "The account was not renamed. Please check the logs for details."
        }
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function editUserPassword {
    param (
        [parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary]$user
    )

    try {
        log -msg "Editing a local users password on this PC."

        if (-not $user) {
            $user = selectUser -prompt "Select a user to edit the password for." -lineAfter
        }
        if (-not $user) { return }

        if ($user["Source"] -eq "MicrosoftAccount") {
            writeText -type "notice" -text "Cannot edit Microsoft accounts."
            return
        }

        if ($user["Source"] -ne "Local") {
            writeText -type "plain" -text "Editing domain users doesn't work yet."
            return
        }

        writeText -type "prompt" -text "Enter a new password."

        $password = readInput -prompt "Password:" -isSecure:$true -allowBlank:$true
        if ($null -eq $password) { return }

        # Set-LocalUser reports failures as non-terminating errors, so without
        # -ErrorAction Stop the catch below never runs and "changed" is printed anyway.
        try {
            Get-LocalUser -Name $user["Name"] -ErrorAction Stop | Set-LocalUser -Password $password -PasswordNeverExpires $true -ErrorAction Stop
        } catch {
            if ($_.Exception.GetType().Name -ne 'InvalidPasswordException') { throw }

            reportPasswordRejected -name $user["Name"]
            $password = $null
            return
        }

        if ($password.Length -eq 0) {
            $message = "Password for user $($user['Name']) was removed."
        } else {
            $message = "Password for user $($user['Name']) changed."
        }

        $password = $null

        writeText -Type "success" -text $message
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function getPasswordPolicyRequirements {
    <#
        Returns the local password rules as sentences. The exception for a
        rejected password carries no reason, so the policy is read from the
        security database (secedit) to tell the user what to change.
    #>
    $file = Join-Path (getConfigPath -name temp) "secpol-$([guid]::NewGuid().ToString('N')).inf"
    $policy = @{}

    try {
        $output = & secedit.exe /export /cfg $file /areas SECURITYPOLICY 2>&1
        if (($null -ne $LASTEXITCODE) -and ($LASTEXITCODE -ne 0)) {
            throw "secedit exited with code $LASTEXITCODE ($((($output | Out-String).Trim()) -replace '\s+', ' '))"
        }

        foreach ($line in (Get-Content -LiteralPath $file -ErrorAction Stop)) {
            if ($line -match '^\s*(MinimumPasswordLength|PasswordComplexity|PasswordHistorySize)\s*=\s*(\d+)\s*$') {
                $policy[$Matches[1]] = [int]$Matches[2]
            }
        }
    } catch {
        log -msg "Could not read the password policy: $($_.Exception.Message)" -lvl "WARNING"
    } finally {
        Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
    }

    $requirements = @()
    if ($policy['MinimumPasswordLength'] -gt 0) { $requirements += "At least $($policy['MinimumPasswordLength']) characters long." }
    if ($policy['PasswordComplexity'] -eq 1) { $requirements += "Must meet complexity rules: at least 6 characters, 3 of upper case, lower case, digits and symbols, and no part of the user name." }
    if ($policy['PasswordHistorySize'] -gt 0) { $requirements += "Cannot repeat any of the last $($policy['PasswordHistorySize']) passwords." }

    if ($policy.Count -eq 0) {
        $requirements += "The policy could not be read. Check minimum length, complexity and password history in Local Security Policy."
    } elseif ($requirements.Count -eq 0) {
        $requirements += "The policy has no length, complexity or history rule, so another setting blocked it (for example blank passwords are not allowed). Try a longer password."
    }

    return $requirements
}
function editUserGroup {
    param (
        [parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary]$user
    )

    try {
        if (-not $user) {
            $user = selectUser -prompt "Select a user to edit the groups for." -lineAfter
        }
        if (-not $user) { return }

        if ($user["Source"] -eq "MicrosoftAccount") {
            writeText -type "notice" -text "Cannot edit Microsoft accounts."
            return
        }

        if ($user["Source"] -ne "Local") {
            writeText -type "plain" -text "Editing domain users doesn't work yet."
            return
        }

        $choice = readOption -options $([ordered]@{
                "Add"    = "Add this user to more groups"
                "Remove" = "Remove this user from certain groups"
                "Cancel" = "Do nothing and exit this function."
            }) -prompt "Do you want to add or remove this user from groups?" -lineAfter

        if ($choice -eq 0) {
            $verb = "added to"
            $result = addGroups -username $user["Name"]
        } elseif ($choice -eq 1) {
            $verb = "removed from"
            $result = removeGroups -username $user["Name"]
        } else {
            return
        }

        # Nothing to report when the user cancelled.
        if ($null -eq $result) { return }

        if ($result.Changed.Count -gt 0) {
            writeText -type "success" -text "$($user['Name']) was $verb $($result.Changed -join ', ')."
        }
        foreach ($group in $result.Unchanged) {
            writeText -type "notice" -text "$($user['Name']) is already a member of $group."
        }
        foreach ($failure in $result.Failed) {
            writeText -type "error" -text $failure
        }
        if (($result.Changed.Count + $result.Unchanged.Count + $result.Failed.Count) -eq 0) {
            writeText -type "notice" -text "No changes were made."
        }
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function getGroupMenuOptions {
    <#
        Every local group (name -> description) for a menu. The well-known
        groups get a friendlier description; any other group, including ones
        created later, is listed with its own.
    #>
    $friendly = @{
        "Performance Monitor Users"           = "Access local performance counter data."
        "Power Users"                         = "Limited administrative privileges."
        "Network Configuration Operators"     = "Privileges for managing network configuration."
        "Performance Log Users"               = "Schedule performance counter logging."
        "Remote Desktop Users"                = "Log on remotely."
        "System Managed Accounts Group"       = "Managed by the system."
        "Users"                               = "Prevented from making system-wide changes."
        "Remote Management Users"             = "Access WMI resources over management protocols."
        "Replicator"                          = "Supports file replication in a domain."
        "IIS_IUSRS"                           = "Used by Internet Information Services (IIS)."
        "Backup Operators"                    = "Override security restrictions for backup purposes."
        "Cryptographic Operators"             = "Perform cryptographic operations."
        "Access Control Assistance Operators" = "Remotely query authorization attributes and permissions."
        "Administrators"                      = "Complete, unrestricted access to the computer/domain."
        "Device Owners"                       = "Can change system-wide settings."
        "Guests"                              = "Similar access to members of the Users group by default."
        "Hyper-V Administrators"              = "Complete and unrestricted access to all Hyper-V features."
        "Distributed COM Users"               = "Authorized for Distributed Component Object Model (DCOM) operations."
    }

    $options = [ordered]@{}
    foreach ($group in (Get-LocalGroup | Sort-Object -Property Name)) {
        $description = $friendly[$group.Name]
        if (-not $description) { $description = "$($group.Description)" }
        $options[$group.Name] = $description
    }

    return $options
}
function selectGroups {
    <#
        Lets the user pick any number of groups from $groups. Returns an object
        with Cancelled (true when the user backed out or the menu failed) and
        Groups (the names picked, in the order picked).
    #>
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$groups,
        [Parameter(Mandatory = $true)]
        [string]$verb
    )

    $selected = @()

    # Always ends with Done (or Cancel), even when every group has been picked, so
    # nothing is applied until the user has said so.
    while ($true) {
        $available = [ordered]@{}

        if ($selected.Count -gt 0) {
            $available["Done"] = "Stop selecting groups and $verb the groups chosen."
        }
        foreach ($key in $groups.Keys) {
            if ($selected -notcontains $key) { $available[$key] = $groups[$key] }
        }
        $available["Cancel"] = "Select nothing and exit this function."

        if ($selected.Count -eq 0) { $prompt = "Select a group:" } else { $prompt = "Select another group or 'Done':" }

        $choice = readOption -options $available -prompt $prompt -returnKey

        # A menu that returned nothing counts as a cancel, so the loop always ends.
        if (-not $choice -or $choice -eq "Cancel") {
            return [pscustomobject]@{ Cancelled = $true; Groups = @() }
        }
        if ($choice -eq "Done") { break }

        $selected += $choice
    }

    return [pscustomobject]@{ Cancelled = $false; Groups = $selected }
}
function addGroups {
    param (
        [Parameter(Mandatory = $true)]
        [string]$username
    )

    $selection = selectGroups -groups (getGroupMenuOptions) -verb "add the user to"
    if ($selection.Cancelled) { return $null }

    $result = [pscustomobject]@{ Changed = @(); Unchanged = @(); Failed = @() }

    foreach ($group in $selection.Groups) {
        try {
            Add-LocalGroupMember -Group $group -Member $username -ErrorAction Stop
            log -msg "The user ($username) has been added to the group $group."
            $result.Changed += $group
        } catch {
            if ($_.Exception.GetType().Name -eq 'MemberExistsException') {
                $result.Unchanged += $group
            } else {
                log -msg "The user ($username) could not be added to the group ${group}: $($_.Exception.Message)" -lvl "ERROR"
                $result.Failed += "Could not add $username to ${group}: $($_.Exception.Message)"
            }
        }
    }

    return $result
}
function removeGroups {
    param (
        [Parameter(Mandatory = $true)]
        [string]$username
    )

    $account = Get-LocalUser -Name $username -ErrorAction Stop
    $descriptions = getGroupMenuOptions

    # Match on SID: a name match also hits same-named accounts from other machines or domains.
    $memberOf = [ordered]@{}
    $unreadable = @()
    foreach ($group in (Get-LocalGroup | Sort-Object -Property Name)) {
        try {
            $members = @(Get-LocalGroupMember -SID $group.SID -ErrorAction Stop)
            if ($members | Where-Object { $_.SID.Value -eq $account.SID.Value }) {
                $memberOf[$group.Name] = $descriptions[$group.Name]
            }
        } catch {
            $unreadable += $group.Name
        }
    }

    if ($unreadable.Count -gt 0) {
        writeText -type "notice" -text "Could not read the members of $($unreadable.Count) group(s), so they are not listed: $($unreadable -join ', ')"
    }

    if ($memberOf.Count -eq 0) {
        writeText -type "notice" -text "The user $username is not a member of any local group that could be read."
        return $null
    }

    $selection = selectGroups -groups $memberOf -verb "remove the user from"
    if ($selection.Cancelled) { return $null }

    $result = [pscustomobject]@{ Changed = @(); Unchanged = @(); Failed = @() }

    foreach ($group in $selection.Groups) {
        try {
            $groupObject = Get-LocalGroup -Name $group -ErrorAction Stop

            # Do not let the last way into the computer, or the account running ShellCLI, be removed.
            if ($groupObject.SID.Value -eq "S-1-5-32-544") {
                if ($account.SID.Value -eq (getCurrentUserSid).Value) {
                    $result.Failed += "Did not remove $username from ${group}: it is the account you are signed in as."
                    continue
                }

                $admins = getAdministratorSummary -sid $account.SID
                if ($null -eq $admins) {
                    writeText -type "notice" -text "Could not check whether another administrator exists."
                } elseif ($account.Enabled -and $admins.OtherEnabled -eq 0) {
                    $result.Failed += "Did not remove $username from ${group}: it is the only enabled administrator on this computer."
                    continue
                }
            }

            Remove-LocalGroupMember -Group $group -Member $username -ErrorAction Stop
            log -msg "The user ($username) has been removed from the group $group."
            $result.Changed += $group
        } catch {
            log -msg "The user ($username) could not be removed from the group ${group}: $($_.Exception.Message)" -lvl "ERROR"
            $result.Failed += "Could not remove $username from ${group}: $($_.Exception.Message)"
        }
    }

    return $result
}
function getCurrentUserSid {
    return [System.Security.Principal.WindowsIdentity]::GetCurrent().User
}
function getBuiltInAdministrator {
    <#
        The built-in Administrator account is the one whose SID ends in -500.
        Its name can be changed (or translated), so it is never looked up by name.
    #>
    return Get-LocalUser | Where-Object { $_.SID.Value -match '-500$' } | Select-Object -First 1
}
function getAdministratorSummary {
    <#
        Looks at the local Administrators group for the account with $sid.
        Returns IsMember (is that account in the group) and OtherEnabled (how
        many other accounts could still administer this computer), or $null if
        the group cannot be read. Domain and Azure AD members and groups cannot be
        checked from here, so they count as available. Only direct members are
        looked at, not the members of a group inside the group.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [System.Security.Principal.SecurityIdentifier]$sid
    )

    try {
        $members = @(Get-LocalGroupMember -SID "S-1-5-32-544" -ErrorAction Stop)
    } catch {
        log -msg "Could not read the Administrators group: $($_.Exception.Message)" -lvl "WARNING"
        return $null
    }

    $isMember = $false
    $others = 0

    foreach ($member in $members) {
        if ($member.SID.Value -eq $sid.Value) {
            $isMember = $true
            continue
        }

        $source = "$($member.PrincipalSource)"
        $class = "$($member.ObjectClass)"

        # Well-known principals report Unknown. SYSTEM and NT SERVICE accounts cannot sign in,
        # but Everyone, Authenticated Users and INTERACTIVE let anybody who can.
        if ($source -eq "Unknown") {
            if ($member.SID.Value -in @("S-1-1-0", "S-1-5-11", "S-1-5-4")) { $others++ }
            continue
        }

        # A deleted local account leaves a bare SID behind (no name, not a user or group). It cannot sign in.
        if ($source -eq "Local" -and $class -eq "Other") { continue }

        if ($class -eq "User") {
            # Local accounts (including ones linked to a Microsoft account) can be checked.
            # If this computer has no such account it is a domain or Azure AD user.
            $account = Get-LocalUser -SID $member.SID -ErrorAction SilentlyContinue
            if ($account) {
                $expired = $account.AccountExpires -and ($account.AccountExpires -lt (Get-Date))
                if ($account.Enabled -and -not $expired) { $others++ }
            } else {
                $others++
            }
        } else {
            $others++
        }
    }

    return [pscustomobject]@{ IsMember = $isMember; OtherEnabled = $others }
}
function removeUser {
    try {
        $user = selectUser -prompt "Select an account to remove." -lineAfter
        if (-not $user) { return }

        $name = $user["Name"]
        $account = Get-LocalUser -Name $name -ErrorAction Stop
        $sid = $account.SID

        # --- Guards: refuse before asking anything else ---

        if ($sid.Value -eq (getCurrentUserSid).Value) {
            writeText -type "error" -text "$name is the account you are signed in as. ShellCLI will not remove it."
            return
        }

        if ($sid.Value -match '-(\d+)$' -and [int]$Matches[1] -lt 1000) {
            writeText -type "error" -text "$name is a built-in account and cannot be removed."
            if ($sid.Value -match '-500$') { writeText -type "plain" -text "To turn the built-in Administrator account off, use 'disable admin'." }
            return
        }

        $admins = getAdministratorSummary -sid $sid
        if ($null -eq $admins) {
            writeText -type "notice" -text "Could not check whether another administrator exists, so make sure one does."
        } elseif ($admins.IsMember -and $account.Enabled -and $admins.OtherEnabled -eq 0) {
            writeText -type "error" -text "$name is the only enabled administrator on this computer. Removing it would leave nobody able to administer it."
            writeText -type "plain" -text "Make another account an administrator (and enabled) first."
            return
        }

        $profileFilter = "SID = '$($sid.Value)'"
        $userProfile = Get-CimInstance Win32_UserProfile -Filter $profileFilter -ErrorAction Stop | Select-Object -First 1
        $dir = $null
        if ($userProfile) { $dir = $userProfile.LocalPath }

        # --- Ask what to do. The first option is the one selected by default, so it is the harmless one. ---

        $options = [ordered]@{}
        if ($userProfile) {
            $options["Keep"] = "Remove the account but keep the user's data."
            if ($userProfile.Loaded) {
                writeText -type "notice" -text "$name is signed in or something is using their profile, so their data cannot be deleted right now."
            } else {
                $options["Delete"] = "Remove the account and permanently delete the user's data."
            }
        } else {
            $options["Remove"] = "Remove the account (it has no profile yet, so there is no data)."
        }
        $options["Cancel"] = "Do not remove anything and exit this function."

        $choice = readOption -options $options -prompt "How do you want to remove ${name}?" -returnKey

        # Anything other than a real answer, including no answer, does nothing.
        if ($choice -notin @("Keep", "Delete", "Remove")) { return }

        # --- Confirm by typing the name ---

        if ($choice -eq "Delete") {
            writeText -type "notice" -text "This permanently removes the account $name and deletes everything in $dir."
        } else {
            writeText -type "notice" -text "This permanently removes the account $name."
        }
        $typed = readInput -prompt "Type the account name to confirm:" -allowBlank
        if ($typed -ne $name) {
            writeText -type "notice" -text "That is not the account name. Nothing was removed."
            return
        }

        # --- Remove ---

        # Remove-LocalUser reports failures as non-terminating errors; stop so a failed
        # removal never goes on to delete the user's data or report success.
        Remove-LocalUser -SID $sid -ErrorAction Stop | Out-Null

        $removed = "The user ($name) has been removed"
        $dataFailure = $null

        if ($choice -eq "Delete") {
            try {
                # Deleting the profile this way removes the folder and its registry entry,
                # and Windows takes care of ownership and permissions.
                $userProfile | Remove-CimInstance -ErrorAction Stop

                $leftover = Get-CimInstance Win32_UserProfile -Filter $profileFilter -ErrorAction SilentlyContinue
                if ($leftover -or (Test-Path -LiteralPath $dir)) {
                    $dataFailure = "some of it is still there"
                }
            } catch {
                $dataFailure = $_.Exception.Message
            }
        }

        if ($dataFailure) {
            writeText -type "error" -text "$removed, but their data could not be deleted: $dataFailure"
            writeText -type "plain" -text "Their folder is still at $dir."
        } elseif ($choice -eq "Delete") {
            writeText -type "success" -text "$removed, along with their data."
        } elseif ($choice -eq "Keep") {
            writeText -type "success" -text "$removed. Their data was kept in $dir."
        } else {
            writeText -type "success" -text "$removed."
        }
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
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

        # Exclude the built-in Administrator account while it is disabled (found by SID: it may be renamed)
        $builtInAdmin = getBuiltInAdministrator
        if ($builtInAdmin -and -not $builtInAdmin.Enabled) {
            $excludedAccounts += $builtInAdmin.Name
        }

        # Filter local users to exclude predefined accounts
        foreach ($user in $localUsers) {
            if ($user.Name -notin $excludedAccounts) {
                $userNames += $user.Name
            }
        }

        # Create an ordered dictionary to store username and group information
        $accounts = [ordered]@{}

        # Get all local groups once (more efficient)
        $allGroups = Get-LocalGroup

        foreach ($name in $userNames) {
            # Get details for the current username
            $username = Get-LocalUser -Name $name

            $groupNames = @()

            # Check each group for membership
            foreach ($group in $allGroups) {
                try {
                    # Use -ErrorAction Stop to catch errors from Get-LocalGroupMember
                    $members = Get-LocalGroupMember -Group $group.Name -ErrorAction Stop

                    # Check if the user's SID is in the group members
                    if ($username.SID -in ($members | Select-Object -ExpandProperty SID)) {
                        $groupNames += $group.Name
                    }
                } catch {
                    # Skip groups that cause errors (like built-in groups with permission issues)
                    log -msg "Could not enumerate members for group: $($group.Name)" -lvl "ERROR"
                    continue
                }
            }

            # Convert groups to a semicolon-separated string
            $groupString = $groupNames -join ';'

            # Get the users source
            $source = Get-LocalUser -Name $username | Select-Object -ExpandProperty PrincipalSource

            # Add username and group string to the dictionary
            $accounts["$username"] = "$source | $groupString"
        }

        # Display user data as a list
        writeText -type "table" -Table $accounts
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function toggleAdmin {
    try {
        $choice = readOption -options $([ordered]@{
                "Enable"  = "Enable the built-in administrator account."
                "Disable" = "Disable the built-in administrator account."
                "Cancel"  = "Do nothing and exit this function."
            }) -prompt "Choose an option:" -lineAfter

        switch ($choice) {
            0 { enableAdmin }
            1 { disableAdmin }
            2 { return }
        }
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function enableAdmin {
    try {
        # The built-in Administrator is found by SID (-500), since it may have been renamed.
        $admin = getBuiltInAdministrator
        if (-not $admin) {
            writeText -type "error" -text "The built-in Administrator account was not found."
            return
        }

        if ($admin.Enabled) {
            writeText -text "The built-in Administrator account ($($admin.Name)) is already enabled."
        } else {
            $admin | Enable-LocalUser -ErrorAction Stop

            $admin = getBuiltInAdministrator

            if ($admin.Enabled) {
                writeText -type "success" -text "The built-in Administrator account ($($admin.Name)) is enabled."
            } else {
                writeText -type "error" -text "Could not enable the built-in Administrator account."
            }
        }
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function disableAdmin {
    try {
        $admin = getBuiltInAdministrator
        if (-not $admin) {
            writeText -type "error" -text "The built-in Administrator account was not found."
            return
        }

        if ($admin.Enabled) {
            # Same protection as removing an administrator: do not leave nobody able to sign in as one.
            $admins = getAdministratorSummary -sid $admin.SID
            if ($admins -and $admins.IsMember -and $admins.OtherEnabled -eq 0) {
                writeText -type "error" -text "The built-in Administrator account ($($admin.Name)) is the only enabled administrator on this computer. Disabling it would leave nobody able to administer it."
                writeText -type "plain" -text "Make another account an administrator (and enabled) first."
                return
            }

            $admin | Disable-LocalUser -ErrorAction Stop

            $admin = getBuiltInAdministrator

            if ($admin.Enabled) {
                writeText -type "error" -text "Could not disable the built-in Administrator account."
            } else {
                writeText -type "success" -text "The built-in Administrator account ($($admin.Name)) is disabled."
            }
        } else {
            writeText -text "The built-in Administrator account ($($admin.Name)) is already disabled."
        }
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function unlockUser {
    try {
        # Create a menu with options and descriptions using an ordered hashtable
        $choice = readOption -options $([ordered]@{
                "Unlock local user" = "Clear the lockout on a local account."
                "Unlock AD user"    = "Clear the lockout on a domain account."
                "Cancel"            = "Select nothing and exit this menu."
            }) -prompt "Select a function." -lineAfter

        switch ($choice) {
            0 { unlockLocalUser }
            1 { unlockADUser }
            2 { return }
        }
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function getLocalAccountLockout {
    <#
        Returns $true or $false for whether a local account is locked out.
        Get-LocalUser has no lockout property, so this asks WMI.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$name
    )

    # In a WQL string a single quote is escaped with a backslash.
    $escaped = $name -replace "'", "\'"
    $account = Get-CimInstance -ClassName Win32_UserAccount -Filter "LocalAccount=True AND Name='$escaped'" -ErrorAction Stop

    if (-not $account) { throw "Could not find the local account $name." }

    return [bool]$account.Lockout
}
function unlockLocalUser {
    try {
        $user = selectUser -lineAfter
        if (-not $user) { return }

        $name = $user["Name"]

        if (-not (getLocalAccountLockout -name $name)) {
            writeText -type "plain" -text "User $name is not locked."
            return
        }

        writeText -type "plain" -text "User $name is currently locked. Unlocking..."

        # There is no Unlock-LocalUser cmdlet. The WinNT provider can clear the
        # lockout without touching anything else about the account.
        $entry = [ADSI]"WinNT://$env:COMPUTERNAME/$name,user"
        $entry.psbase.InvokeSet("IsAccountLocked", $false)
        $entry.SetInfo()

        # Verify unlock was successful, from the same source the lockout was read from
        if (-not (getLocalAccountLockout -name $name)) {
            writeText -type "success" -text "User $name successfully unlocked!"
        } else {
            writeText -type "error" -text "Failed to unlock user $name"
        }
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function unlockADUser {
    try {
        $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        if ($computer.DomainRole -ne 4 -and $computer.DomainRole -ne 5) {
            writeText -type 'notice' -text "This machine is NOT a Domain Controller."
            return
        }

        writeText -type "notice" -text "This function is not yet implemented."
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function getUsers {
    Write-Host "Getting user profiles..."

    $profiles = Get-CimInstance -ClassName Win32_UserProfile

    foreach ($p in $profiles) {
        try {
            $sid = New-Object System.Security.Principal.SecurityIdentifier($p.SID)
            $account = $sid.Translate([System.Security.Principal.NTAccount])

            $user = [PSCustomObject]@{
                UserName  = $account.Value          # DOMAIN\user or COMPUTER\user
                SID       = $p.SID
                Loaded    = $p.Loaded
                LocalPath = $p.LocalPath
            }

            Write-Host "User: $($user.UserName), SID: $($user.SID), Loaded: $($user.Loaded), LocalPath: $($user.LocalPath)"
        } catch {
            Write-Host "Could not resolve SID $($p.SID): $($_.Exception.Message)"
        }
    }
}
