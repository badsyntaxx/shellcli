function edit-user-name {
    try {
        write-welcome -Title "Edit User Name" -Description "Edit an existing users name." -Command "edit user name"

        $user = select-user

        if ($user["Source"] -eq "Local") { Edit-LocalUserName -User $user } else { Edit-ADUserName }
    } catch {
        # Display error message and end the script
        exit-script -Type "error" -Text "edit-user-name-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -LineAfter
    }
}

function Edit-LocalUserName {
    param (
        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$User
    )

    try {
        write-text -Type "header" -Text "Enter username" -LineAfter
        $newName = get-input -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,64})$" -CheckExistingUser

        write-text -Type "header" -Text "YOU'RE ABOUT TO CHANGE THIS USERS NAME." -LineBefore -LineAfter
        get-closing -Script "edit-user-name"
    
        Rename-LocalUser -Name $User["Name"] -NewName $newName

        $newUser = Get-LocalUser -Name $newName

        if ($null -ne $newUser) { 
            $newData = get-userdata -Username $newUser
            write-text -Type "compare" -OldData $User -NewData $newData -LineAfter
            exit-script -Type "success" -Text "The name for this account has been changed." -LineAfter
        } else {
            exit-script -Type "error" -Text "There was an unknown error when trying to rename this user." -LineAfter
        }
    } catch {
        # Display error message and end the script
        exit-script -Type "error" -Text "Edit-LocalUserName-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -LineAfter -LineAfter
    }
}

function Edit-ADUserName {
    write-text -Type "fail" -Text "Editing domain users doesn't work yet."
    write-text
}