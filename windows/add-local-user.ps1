function add-local-user {
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
            write-text -type 'error' -text  "$($_.Exception.Message)" -lineAfter
        } #>

        # Because of the bug listed above we just assume success if the script is still executing at this point.
        write-text -type "success" -text "Local user added"

        read-command
    } catch {
        # Display error message and exit this script
        write-text -type "error" -text "add-local-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
        read-command
    }
}