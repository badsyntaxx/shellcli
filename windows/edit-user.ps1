function edit-user {
    try {
        $choice = read-option -options $([ordered]@{
                "Edit user name"     = "Edit an existing users name."
                "Edit user password" = "Edit an existing users password."
                "Edit user group"    = "Edit an existing users group membership."
            }) -prompt "What would you like to edit?"

        switch ($choice) {
            0 { $command = "edit user name" }
            1 { $command = "edit user password" }
            2 { $command = "edit user group" }
        }

        Write-Host ": "  -ForegroundColor "DarkCyan" -NoNewline
        Write-Host "Running command:" -NoNewline -ForegroundColor "DarkGray"
        Write-Host " $command" -ForegroundColor "Gray"

        read-command -command $command
    } catch {
        write-text -type "error" -text "edit-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}

