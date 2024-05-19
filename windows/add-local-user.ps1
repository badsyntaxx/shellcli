function add-local-user {
    # Begin try/catch block for error handling
    try {
        # Display a welcome message with title, description, and command
        write-welcome -Title "Add Local User" -Description "Add a new local user to the system." -Command "add local user"

        # Prompt for user name with validation, and check for existing users
        write-text -Type "header" -Text "Enter name" -LineBefore -LineAfter
        $name = get-input -Validate "^([a-zA-Z0-9 _\-]{1,64})$" -CheckExistingUser

        # Prompt for password securely
        write-text -Type "header" -Text "Enter password" -LineBefore -LineAfter
        $password = get-input -IsSecure

        # Prompt for group membership with options and return key
        write-text -Type "header" -Text "Set group membership" -LineBefore -LineAfter
        $group = get-option -Options $([ordered]@{
                "Administrators" = "Set this user's group membership to administrators."
                "Users"          = "Set this user's group membership to standard users."
            }) -ReturnKey -LineAfter

        # Confirmation prompt with options
        write-text -Type "header" -Text "YOU'RE ABOUT TO CREATE A NEW LOCAL USER!" -LineAfter
        
        get-closing -script "Add-LocalUser"

        # Create the new local user and add to the specified group
        New-LocalUser $name -Password $password -Description "Local User" -AccountNeverExpires -PasswordNeverExpires -ErrorAction Stop | Out-Null
        Add-LocalGroupMember -Group $group -Member $name -ErrorAction Stop | Out-Null

        # Retrieve user information and display it in a list
        $username = Get-LocalUser -Name $name -ErrorAction Stop | Select-Object -ExpandProperty Name
        $data = get-userdata $username
        write-text -Type "list" -List $data -LineAfter

        # Confirm success or throw an error if applicable
        if ($null -ne $username) {
            exit-script -Type "success" -Text "The user account was created." -LineAfter
        } else {
            throw "There was an unknown error while creating the user account."
        }
    } catch {
        # Display error message and end the script
        exit-script -Type "error" -Text "add-local-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -LineAfter
    }
}


