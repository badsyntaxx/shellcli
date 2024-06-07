function add-local-user {
    try {
        # Prompt for user name with validation, and check for existing users
        $name = get-input -prompt "Enter name:" -Validate "^([a-zA-Z0-9 _\-]{1,64})$" -CheckExistingUser
        # Prompt for password securely
        $password = get-input -prompt "Enter password:" -IsSecure -lineAfter

        $group = get-option -Options $([ordered]@{
                "Administrators" = "Set this user's group membership to administrators."
                "Users"          = "Set this user's group membership to standard users."
            }) -ReturnKey

        # Confirmation prompt with options
        write-text -Type "notice" -Text "Are you sure?" -lineBefore -lineAfter
        
        get-closing -script "add-local-user"

        # Create the new local user and add to the specified group
        New-LocalUser $name -Password $password -Description "Local User" -AccountNeverExpires -PasswordNeverExpires -ErrorAction Stop | Out-Null
        Add-LocalGroupMember -Group $group -Member $name -ErrorAction Stop | Out-Null

        # Retrieve user information and display it in a list
        $username = Get-LocalUser -Name $name -ErrorAction Stop | Select-Object -ExpandProperty Name
        $data = get-userdata $username
        write-text -Type "list" -List $data -lineAfter -lineBefore

        # Confirm success or throw an error if applicable
        if ($null -ne $username) {
            exit-script 
        } else {
            throw "There was an unknown error while creating the user account."
        }
    } catch {
        # Display error message and end the script
        exit-script -Type "error" -Text "add-local-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}


