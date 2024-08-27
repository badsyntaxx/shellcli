function plugins {
    try {
        # Create a menu with options and descriptions using an ordered hashtable
        $choice = read-option -options $([ordered]@{
                "massgravel"   = "https://github.com/massgravel/Microsoft-Activation-Scripts"
                "reclaimw11"   = "https://gist.github.com/DanielLarsenNZ/edc6dd611418581ef90b02ad8e23b363#file-reclaim-windows-11-ps1"
                "win11debloat" = "https://github.com/Raphire/Win11Debloat"
                "Cancel"       = "Select nothing and exit this menu."
            }) -prompt "Select a plugin:" -returnKey

        if ($choice -eq "Cancel") {
            read-command
        }

        Write-Host
        Write-Host ": "  -ForegroundColor "DarkCyan" -NoNewline
        Write-Host "Running command:" -NoNewline -ForegroundColor "DarkGray"
        Write-Host " $choice" -ForegroundColor "Gray"

        read-command -command $choice
    } catch {
        write-text -type "error" -text "menu-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}