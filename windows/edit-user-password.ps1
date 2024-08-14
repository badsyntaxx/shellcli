function edit-user-password {
    try {
        $user = select-user

        if ($user["Source"] -eq "Local") { Edit-LocalUserPassword -username $user["Name"] } else { Edit-ADUserPassword }
    } catch {
        # Display error message and exit this script
        write-text -type "error" -text "edit-user-password-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
        read-command
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

        read-closing -script "edit-user-password" -customText $alert

        Get-LocalUser -Name $username | Set-LocalUser -Password $password

        write-text -Type "success" -text "Password settings for $username successfully updated." -lineAfter
        read-command
    } catch {
        # Display error message and exit this script
        write-text -type "error" -text "Edit-LocalUserPassword-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
        read-command
    }
}

function Edit-ADUserPassword {
    write-text -Type "fail" -text "Editing domain users doesn't work yet."
    read-command
}
