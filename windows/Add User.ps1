function addUser {
    try {
        $choice = readOption -options $([ordered]@{
                "Add local user"  = "Add a local user to the system."
                "Add domain user" = "Add a domain user to the system."
                "Cancel"          = "Do nothing and exit this function."
            }) -prompt "Select a user account type:"

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
        $name = readInput -prompt "Enter a user name:" -Validate "^([a-zA-Z0-9 ._\-]{1,64})$" -CheckExistingUser
        $password = readInput -prompt "Enter a password or leave blank:" -IsSecure

        # Create the new local user and add to the specified group
        New-LocalUser $name -Password $password -description "Local User" -AccountNeverExpires -PasswordNeverExpires -ErrorAction Stop | Out-Null

        $group = readOption -options $([ordered]@{
                "Administrators" = "Set this user's group membership to administrators."
                "Users"          = "Set this user's group membership to standard users."
            }) -prompt "Select a user group:" -returnKey
          
        Add-LocalGroupMember -Group $group -Member $name -ErrorAction Stop | Out-Null
        
        $newUser = Get-LocalUser -Name $name
        if ($null -eq $newUser) {
            # User creation failed, exit with error
            writeText -type 'error' -text "Failed to create user $name. Please check the logs for details."
        }

        # There is a powershell bug with Get-LocalGroupMember So we can't do a manual check.
        <# if ((Get-LocalGroupMember -Group $group -Name $name).Count -gt 0) {
            writeText -type "success" -text "$name has been assigned to the $group group." -lineAfter
        } else {
            writeText -type 'error' -text  "$($_.Exception.Message)"
        } #>

        # Because of the bug listed above we just assume success if the script is still executing at this point.
        writeText -type "success" -text "Local user added."
    } catch {
        writeText -type "error" -text "addLocalUser-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function addADUser {
    try {
        writeText -type "plain" -text "Editing domain users doesn't work yet."
        readCommand

        Get-Item -ErrorAction SilentlyContinue "$path\add-ad-user.ps1" | Remove-Item -ErrorAction SilentlyContinue
        Write-Host " Chaste Scripts: Add Domain User v0321240710"
        Write-Host "$des" -ForegroundColor DarkGray

        writeText -type "label" -text "Enter name"  -lineAfter
        $name = readInput -prompt "" -Validate "^([a-zA-Z0-9 _\-]{1,64})$"  -CheckExistingUser

        writeText -type "label" -text "Enter sam name"  -lineAfter
        $samAccountName = readInput -prompt "" -Validate "^([a-zA-Z0-9 _\-]{1,20})$"  -CheckExistingUser

        writeText -type "label" -text "Enter password"  -lineAfter
        $password = readInput -prompt "" -IsSecure
        
        writeText -type "label" -text "Set group membership"  -lineAfter
        $choice = readOption -options @("Administrator", "Standard user")
        
        if ($choice -eq 0) { $group = 'Administrators' } else { $group = "Users" }
        if ($group -eq 'Administrators') { $groupDisplay = 'Administrator' } else { $groupDisplay = 'Standard user' }

        writeText -type "label" -text "YOU'RE ABOUT TO CREATE A NEW AD USER!"  -lineAfter

        $choice = readOption -options @(
            "Submit  - Confirm and apply." 
            "Reset   - Start over at the beginning."
            "Exit    - Run a different command."
        ) -lineAfter

        if ($choice -ne 0 -and $choice -ne 2) { invokeScript -script "add-ad-user" }
        if ($choice -eq 2) { throw "This function is under construction." }

        New-ADUser -Name $name 
        -SamAccountName $samAccountName 
        -GivenName $GivenName 
        -Surname $Surname 
        -UserPrincipalName "$UserPrincipalName@$domainName.com" 
        -AccountPassword $password 
        -Enabled $true

        Add-LocalGroupMember -Group $group -Member $name -ErrorAction Stop

        $data = getUserData -Username $name

        writeText -type "list" -List $data -lineAfter

        writeText -type "success" -text "The user account was created."
    } catch {
        writeText -type "error" -text "addADUser-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}

