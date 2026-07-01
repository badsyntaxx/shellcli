function shellCLI {
    Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
    Write-Host " $([char]0x2502)" -NoNewline -ForegroundColor "Gray"
    Write-Host " Try" -NoNewline
    Write-Host " help" -ForegroundColor "Cyan" -NoNewline
    Write-Host " or" -NoNewline
    Write-Host " menu" -NoNewline -ForegroundColor "Cyan"
    Write-Host " if you get stuck."
    Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
}

function readMenu {
    try {
        # Create a menu with options and descriptions using an ordered hashtable
        $choice = readOption -options $([ordered]@{
                "user menu"           = "View the user management menu."
                "edit hostname"       = "Edit this computers name and description."
                "edit net adapter"    = "(BETA) Edit a network adapter."
                "get wifi creds"      = "View all saved WiFi credentials on the system."
                "toggle context menu" = "Enable or Disable the Windows 11 context menu."
                "repair windows"      = "Repair Windows."
                "update windows"      = "(BETA) Install Windows updates silently."
                "clear temp files"    = "Removes Windows temporary and cache files."
                "get software"        = "Get a list of installed software that can be installed."
                "schedule task "      = "(ALPHA) Schedule a new task."
                "Cancel"              = "Select nothing and exit this menu."
            }) -prompt "Select a function." -returnKey

        if ($choice -eq "Cancel") {
            readCommand
        }

        readCommand -command $choice
    } catch {
        writeText -type "error" -text "readMenu-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}

function writeHelp {   
    writeText -type "header" -text "Here are some commands to get you started:" -lineAfter
    Write-Host " $([char]0x2502)" -ForegroundColor "Gray" -NoNewline
    Write-Host "  Type" -NoNewline
    Write-Host " commands" -ForegroundColor "Cyan" -NoNewline
    Write-Host " for a full list of commands."
    Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
    writeText -type "plain" -text "EXAMPLE COMMANDS:"
    writeText -type "plain" -text "menu                 - Display a menu with some available functions." -Color "DarkGray"
    writeText -type "plain" -text "edit hostname        - Edit the computers hostname and description." -Color "DarkGray"
    writeText -type "plain" -text "repair windows       - Repair Windows." -Color "DarkGray"
    writeText -type "plain" -text "FULL DOCUMENTATION:" -lineBefore
    writeText -type "plain" -text "https://wkey.pro/dev/shellcli" -Color "DarkGray"
}