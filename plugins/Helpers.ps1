function plugins {
    Write-Host
    Write-Host "  Try" -NoNewline
    Write-Host " plugins help" -ForegroundColor "Cyan" -NoNewline
    Write-Host " or" -NoNewline
    Write-Host " plugins menu" -NoNewline -ForegroundColor "Cyan"
    Write-Host " if you don't know what to do."
}
function readMenu {
    try {
        # Create a menu with options and descriptions using an ordered hashtable
        $choice = readOption -options $([ordered]@{
                "massgravel"   = "https://github.com/massgravel/Microsoft-Activation-Scripts"
                "reclaimw11"   = "Credit needed"
                "win11debloat" = "https://github.com/Raphire/Win11Debloat"
                "Cancel"       = "Select nothing and exit this menu."
            }) -prompt "Select a plugin:" -returnKey

        if ($choice -eq "Cancel") {
            readCommand
        }

        readCommand -command "plugins $choice"
    } catch {
        writeText -type "error" -text "readMenu-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function writeHelp {
    writeText -type "header" -text "COMMANDS:" -lineBefore
    writeText -type "plain" -text "plugins massgravel    - https://github.com/massgravel/Microsoft-Activation-Scripts" -Color "DarkGray"
    writeText -type "plain" -text "plugins reclaimw11    - Credit needed" -Color "DarkGray"
    writeText -type "plain" -text "plugins win11debloat  - https://github.com/Raphire/Win11Debloat" -Color "DarkGray"
}