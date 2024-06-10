function edit-user-password {
    try {
        $user = select-user

        if ($user["Source"] -eq "Local") { Edit-LocalUserPassword -username $user["Name"] } else { Edit-ADUserPassword }
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "edit-user-password-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

function Edit-LocalUserPassword {
    param (
        [Parameter(Mandatory)]
        [string]$username
    )

    try {
        $password = read-input -prompt "Enter password or leave blank:" -IsSecure $true -lineBefore

        if ($password.Length -eq 0) { $alert = "Removing password. Are you sure?" } 
        else { $alert = "Changing password. Are you sure?" }

        get-closing -script "edit-user-password" -customText $alert

        Get-LocalUser -Name $username | Set-LocalUser -Password $password

        exit-script -Type "success" -text "Password settings for $username successfully updated." -lineAfter
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "Edit-LocalUserPassword-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

function Edit-ADUserPassword {
    exit-script -Type "fail" -text "Editing domain users doesn't work yet."
}
