function add-local-user {
    try {
        $name = read-input -prompt "What name would you like for the account?" -Validate "^([a-zA-Z0-9 _\-]{1,64})$" -CheckExistingUser -lineBefore
        $password = read-input -prompt "Enter password or leave blank." -IsSecure -lineBefore

        # Create the new local user and add to the specified group
        New-LocalUser $name -Password $password -description "Local User" -AccountNeverExpires -PasswordNeverExpires -ErrorAction Stop | Out-Null
        $newUser = Get-LocalUser -Name $name
        if ($null -eq $newUser) {
            # User creation failed, exit with error
            exit-script -type 'error' -text "Failed to create user $name. Please check the logs for details."
        }
        write-text -type 'success' -text "User $name created successfully." -lineBefore

        $group = read-option -options $([ordered]@{
                "Administrators" = "Set this user's group membership to administrators."
                "Users"          = "Set this user's group membership to standard users."
            }) -prompt "What group should this account be in?" -returnKey -lineBefore
          
        Add-LocalGroupMember -Group $group -Member $name -ErrorAction Stop | Out-Null

        # There is a powershell bug with Get-LocalGroupMember So we can't do a manual check.
        <# if ((Get-LocalGroupMember -Group $group -Name $name).Count -gt 0) {
            write-text -type "success" -text "$name has been assigned to the $group group." -lineAfter
        } else {
            exit-script -type 'error' -text  "$($_.Exception.Message)" -lineAfter
        } #>

        # Because of the bug listed above we just assume success if the script is still executing at this point.
        write-text -type "success" -text "$name has been assigned to the $group group." -lineAfter -lineBefore

        # Retrieve user information and display it in a list
        $username = Get-LocalUser -Name $name -ErrorAction Stop | Select-Object -ExpandProperty Name
        $data = get-userdata $username
        write-text -type "list" -List $data

        exit-script 
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "add-local-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}
