function edit-user-name {
    try {
        $user = select-user

        if ($user["Source"] -eq "Local") { Edit-LocalUserName -User $user } else { Edit-ADUserName }
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "edit-user-name-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

function Edit-LocalUserName {
    param (
        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$user
    )

    try {
        $newName = read-input -prompt "Enter username:" -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,64})$" -CheckExistingUser -lineBefore

        get-closing -Script "edit-user-name"
    
        Rename-LocalUser -Name $user["Name"] -NewName $newName

        $newUser = Get-LocalUser -Name $newName

        if ($null -ne $newUser) { 
            # $newData = get-userdata -Username $newUser
            write-compare -oldData "$($user['name'])" -newData $newUser
            exit-script -type "success" -text "Account name successfully changed." -lineBefore -lineAfter
        } else {
            exit-script -type "error" -text "There was an unknown error when trying to rename this user." -lineBefore -lineAfter
        }
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "Edit-LocalUserName-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

function Edit-ADUserName {
    write-text -type "fail" -text "Editing domain users doesn't work yet."
    write-text
}
