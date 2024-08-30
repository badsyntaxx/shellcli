function edit-user {
    try {
        $choice = read-option -options $([ordered]@{
                "Edit user name"     = "Edit an existing users name."
                "Edit user password" = "Edit an existing users password."
                "Edit user group"    = "Edit an existing users group membership."
                "Cancel"             = "Do nothing and exit this function."
            }) -prompt "What would you like to edit?"

        Write-Host ": "  -ForegroundColor "DarkCyan" -NoNewline
        Write-Host "Running command:" -NoNewline -ForegroundColor "DarkGray"
        Write-Host " $command" -ForegroundColor "Gray"

        switch ($choice) {
            0 { edit-userName }
            1 { edit-userPassword }
            2 { $command = "edit user group" }
            3 { read-command }
        }
    } catch {
        write-text -type "error" -text "edit-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function edit-userName {
    try {
        $user = select-user

        if ($user["Source"] -eq "MicrosoftAccount") { 
            write-text -type "notice" -text "Cannot edit Microsoft accounts."
        }

        if ($user["Source"] -eq "Local") { 
            $newName = read-input -prompt "Enter username:" -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,64})$" -CheckExistingUser
    
            Rename-LocalUser -Name $user["Name"] -NewName $newName

            $newUser = Get-LocalUser -Name $newName

            if ($null -ne $newUser) { 
                write-text -type "success" -text "Account name changed"
            } else {
                write-text -type "error" -text "Unknown error"
            }
        } else { 
            write-text -type "notice" -text "Editing domain users doesn't work yet."
        }
    } catch {
        write-text -type "error" -text "edit-user-name-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}

function edit-userPassword {
    try {
        $user = select-user

        if ($user["Source"] -eq "Local") { 
            $password = read-input -prompt "Enter password or leave blank:" -IsSecure $true

            if ($password.Length -eq 0) { 
                $message = "Password removed" 
            } else { 
                $message = "Password changed" 
            }

            Get-LocalUser -Name $username | Set-LocalUser -Password $password

            write-text -Type "success" -text $message
        } else { 
            write-text -type "plain" -text "Editing domain users doesn't work yet."
        }
    } catch {
        write-text -type "error" -text "edit-user-password-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
