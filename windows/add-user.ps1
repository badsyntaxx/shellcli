function add-user {
    try {
        $choice = read-option -options $([ordered]@{
                "Add local user"  = "Add a local user to the system."
                "Add domain user" = "Add a domain user to the system."
            }) -prompt "Select a user account type:" -lineBefore

        if ($choice -eq 0) { $command = "add local user" }
        if ($choice -eq 1) { $command = "add ad user" }

        Write-Host
        Write-Host " ::"  -ForegroundColor "DarkCyan" -NoNewline
        Write-Host " Running command:" -NoNewline -ForegroundColor "DarkGray"
        Write-Host " $command" -ForegroundColor "Gray"

        read-command -command $command
    } catch {
        # Display error message and exit this script
        write-text -type "error" -text "add-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
        read-command
    }
}

