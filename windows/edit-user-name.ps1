function edit-user-name {
    try {
        $user = select-user

        if ($user["Source"] -eq "Local") { Edit-LocalUserName -User $user } else { Edit-ADUserName }
    } catch {
        # Display error message and end the script
        exit-script -type "error" -text "edit-user-name-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

function Edit-LocalUserName {
    param (
        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$User
    )

    try {

        $newName = get-input -prompt "Enter username:" -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,64})$" -CheckExistingUser

        write-text -type "label" -text "Are you sure?"  -lineAfter
        get-closing -Script "edit-user-name"
    
        Rename-LocalUser -Name $User["Name"] -NewName $newName

        $newUser = Get-LocalUser -Name $newName

        if ($null -ne $newUser) { 
            $newData = get-userdata -Username $newUser
            write-text -Type "compare" -OldData $User -NewData $newData -lineAfter
            exit-script -Type "success" -Text "Account name changed." -lineAfter
        } else {
            exit-script -type "error" -text "There was an unknown error when trying to rename this user." -lineAfter
        }
    } catch {
        # Display error message and end the script
        exit-script -type "error" -text "Edit-LocalUserName-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter -lineAfter
    }
}

function Edit-ADUserName {
    write-text -Type "fail" -Text "Editing domain users doesn't work yet."
    write-text
}