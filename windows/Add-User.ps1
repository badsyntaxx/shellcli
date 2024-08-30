function add-user {
    try {
        $choice = read-option -options $([ordered]@{
                "Add local user"  = "Add a local user to the system."
                "Add domain user" = "Add a domain user to the system."
                "Cancel"          = "Do nothing and exit this function."
            }) -prompt "Select a user account type:"

        Write-Host ": "  -ForegroundColor "DarkCyan" -NoNewline
        Write-Host "Running command:" -NoNewline -ForegroundColor "DarkGray"
        Write-Host " $command" -ForegroundColor "Gray"

        switch ($choice) {
            0 { add-localUser }
            1 { add-adUser }
            2 { read-command }
        }
    } catch {
        write-text -type "error" -text "add-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function add-localUser {
    try {
        $name = read-input -prompt "Enter a user name:" -Validate "^([a-zA-Z0-9 ._\-]{1,64})$" -CheckExistingUser
        $password = read-input -prompt "Enter a password or leave blank:" -IsSecure

        # Create the new local user and add to the specified group
        New-LocalUser $name -Password $password -description "Local User" -AccountNeverExpires -PasswordNeverExpires -ErrorAction Stop | Out-Null

        $group = read-option -options $([ordered]@{
                "Administrators" = "Set this user's group membership to administrators."
                "Users"          = "Set this user's group membership to standard users."
            }) -prompt "Select a user group:" -returnKey
          
        Add-LocalGroupMember -Group $group -Member $name -ErrorAction Stop | Out-Null

        
        $newUser = Get-LocalUser -Name $name
        if ($null -eq $newUser) {
            # User creation failed, exit with error
            write-text -type 'error' -text "Failed to create user $name. Please check the logs for details."
        }

        # There is a powershell bug with Get-LocalGroupMember So we can't do a manual check.
        <# if ((Get-LocalGroupMember -Group $group -Name $name).Count -gt 0) {
            write-text -type "success" -text "$name has been assigned to the $group group." -lineAfter
        } else {
            write-text -type 'error' -text  "$($_.Exception.Message)"
        } #>

        # Because of the bug listed above we just assume success if the script is still executing at this point.
        write-text -type "success" -text "Local user added."
    } catch {
        write-text -type "error" -text "add-localUser-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function add-adUser {
    try {
        write-text -type "plain" -text "Editing domain users doesn't work yet."
        read-command

        Get-Item -ErrorAction SilentlyContinue "$path\add-ad-user.ps1" | Remove-Item -ErrorAction SilentlyContinue
        Write-Host " Chaste Scripts: Add Domain User v0321240710"
        Write-Host "$des" -ForegroundColor DarkGray

        write-text -type "label" -text "Enter name"  -lineAfter
        $name = read-input -prompt "" -Validate "^([a-zA-Z0-9 _\-]{1,64})$"  -CheckExistingUser

        write-text -type "label" -text "Enter sam name"  -lineAfter
        $samAccountName = read-input -prompt "" -Validate "^([a-zA-Z0-9 _\-]{1,20})$"  -CheckExistingUser

        write-text -type "label" -text "Enter password"  -lineAfter
        $password = read-input -prompt "" -IsSecure
        
        write-text -type "label" -text "Set group membership"  -lineAfter
        $choice = read-option -options @("Administrator", "Standard user")
        
        if ($choice -eq 0) { $group = 'Administrators' } else { $group = "Users" }
        if ($group -eq 'Administrators') { $groupDisplay = 'Administrator' } else { $groupDisplay = 'Standard user' }

        write-text -type "label" -text "YOU'RE ABOUT TO CREATE A NEW AD USER!"  -lineAfter

        $choice = read-option -options @(
            "Submit  - Confirm and apply." 
            "Reset   - Start over at the beginning."
            "Exit    - Run a different command."
        ) -lineAfter

        if ($choice -ne 0 -and $choice -ne 2) { invoke-script -script "add-ad-user" }
        if ($choice -eq 2) { throw "This function is under construction." }

        New-ADUser -Name $name 
        -SamAccountName $samAccountName 
        -GivenName $GivenName 
        -Surname $Surname 
        -UserPrincipalName "$UserPrincipalName@$domainName.com" 
        -AccountPassword $password 
        -Enabled $true

        Add-LocalGroupMember -Group $group -Member $name -ErrorAction Stop

        $data = get-userData -Username $name

        write-text -type "list" -List $data -lineAfter

        write-text -type "success" -text "The user account was created."
    } catch {
        write-text -type "error" -text "add-adUser-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}

