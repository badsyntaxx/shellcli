function add-local-user {
    try {
        # Prompt for user name with validation, and check for existing users
        $name = read-input -prompt "Enter name:" -Validate "^([a-zA-Z0-9 _\-]{1,64})$" -CheckExistingUser -lineBefore
        # Prompt for password securely
        $password = read-input -prompt "Enter password:" -IsSecure

        $group = read-option -options $([ordered]@{
                "Administrators" = "Set this user's group membership to administrators."
                "Users"          = "Set this user's group membership to standard users."
            }) -returnKey
        
        get-closing -script "add-local-user"

        # Create the new local user and add to the specified group
        New-LocalUser $name -Password $password -description "Local User" -AccountNeverExpires -PasswordNeverExpires -ErrorAction Stop | Out-Null
        $newUser = Get-LocalUser -Name $name
        if ($null -eq $newUser) {
            # User creation failed, exit with error
            exit-script -type 'error' -text "Failed to create user $name. Please check the logs for details."
        }

        write-text -type 'success' -text "User $name created successfully."
          
        Add-LocalGroupMember -Group $group -Member $name -ErrorAction Stop | Out-Null
        if ((Get-LocalGroupMember -Group $group -Member $name).Count -gt 0) {
            write-text -type "success" -text "$name has been assigned to the $group group." -lineAfter
        } else {
            exit-script -type 'error' -text  "$($_.Exception.Message)" -lineAfter
        }

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


