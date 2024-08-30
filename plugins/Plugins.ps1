function read-menu {
    try {
        # Create a menu with options and descriptions using an ordered hashtable
        $choice = read-option -options $([ordered]@{
                "massgravel"   = "https://github.com/massgravel/Microsoft-Activation-Scripts"
                "reclaimw11"   = "https://gist.github.com/DanielLarsenNZ/edc6dd611418581ef90b02ad8e23b363#file-reclaim-windows-11-ps1"
                "win11debloat" = "https://github.com/Raphire/Win11Debloat"
                "Cancel"       = "Select nothing and exit this menu."
            }) -prompt "Select a plugin:" -returnKey

        Write-Host
        Write-Host ": "  -ForegroundColor "DarkCyan" -NoNewline
        Write-Host "Running command:" -NoNewline -ForegroundColor "DarkGray"
        Write-Host " $choice" -ForegroundColor "Gray"

        if ($choice -eq "Cancel") {
            read-command
        }

        read-command -command $choice
    } catch {
        write-text -type "error" -text "read-menu-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
