function edit-user-name {
    try {
        $user = select-user -lineBefore

        if ($user["Source"] -eq "Local") { Edit-LocalUserName -User $user } else { Edit-ADUserName }
    } catch {
        # Display error message and exit this script
        write-text -type "error" -text "edit-user-name-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
        read-command
    }
}

function Edit-LocalUserName {
    param (
        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$user
    )

    try {
        $newName = read-input -prompt "Enter username:" -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,64})$" -CheckExistingUser
    
        Rename-LocalUser -Name $user["Name"] -NewName $newName

        $newUser = Get-LocalUser -Name $newName

        if ($null -ne $newUser) { 
            write-text -type "success" -text "Account name changed"
        } else {
            write-text -type "error" -text "Unknown error"
        }

        read-command
    } catch {
        # Display error message and exit this script
        write-text -type "error" -text "Edit-LocalUserName-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
        read-command
    }
}

function Edit-ADUserName {
    write-text -type "plain" -text "Editing domain users doesn't work yet."
}