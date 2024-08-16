function edit-user-password {
    try {
        $user = select-user -lineBefore

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
        $password = read-input -prompt "Enter password or leave blank:" -IsSecure $true

        if ($password.Length -eq 0) { $message = "Password removed" } 
        else { $message = "Password changed" }

        Get-LocalUser -Name $username | Set-LocalUser -Password $password

        write-text -Type "success" -text $message -lineBefore -lineAfter

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
