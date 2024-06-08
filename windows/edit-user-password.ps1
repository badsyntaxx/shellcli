function edit-user-password {
    try {
        write-welcome -Title "Edit User Password" -Description "Edit an existing users Password." -Command "edit user password"

        $user = select-user

        if ($user["Source"] -eq "Local") { Edit-LocalUserPassword -Username $user["Name"] } else { Edit-ADUserPassword }
    } catch {
        # Display error message and end the script
        exit-script -type "error" -text "edit-user-password-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

function Edit-LocalUserPassword {
    param (
        [Parameter(Mandatory)]
        [string]$Username
    )

    try {
        write-text -type "label" -text "Enter password or leave blank" -lineAfter
        $password = get-input -Prompt "" -IsSecure $true

        if ($password.Length -eq 0) { $alert = "YOU'RE ABOUT TO REMOVE THIS USERS PASSWORD!" } 
        else { $alert = "YOU'RE ABOUT TO CHANGE THIS USERS PASSWORD" }

        write-text -type "label" -text $alert  -lineAfter
        get-closing -Script "edit-user-password"

        Get-LocalUser -Name $Username | Set-LocalUser -Password $password

        exit-script -type "success" -Text "The password for this account has been changed." -lineAfter
    } catch {
        # Display error message and end the script
        exit-script -type "error" -text "Edit-LocalUserPassword-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

function Edit-ADUserPassword {
    exit-script -type "fail" -Text "Editing domain users doesn't work yet."
}

