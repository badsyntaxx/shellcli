function chasteScripts {
    Write-Host
    Write-Host "  Try" -NoNewline
    Write-Host " help" -ForegroundColor "Cyan" -NoNewline
    Write-Host " or" -NoNewline
    Write-Host " menu" -NoNewline -ForegroundColor "Cyan"
    Write-Host " if you don't know what to do."
}

function readMenu {
    try {
        # Create a menu with options and descriptions using an ordered hashtable
        $choice = readOption -options $([ordered]@{
                "toggle admin"        = "Toggle the Windows built in administrator account."
                "add user"            = "Add a user to the system."
                "remove user"         = "Remove a user from the system."
                "edit user"           = "Edit a users."
                "edit hostname"       = "Edit this computers name and description."
                "edit net adapter"    = "(BETA) Edit a network adapter."
                "get wifi creds"      = "View all saved WiFi credentials on the system."
                "toggle context menu" = "Enable or Disable the Windows 11 context menu."
                "repair windows"      = "Repair Windows."
                "update window"       = "(BETA) Install Windows updates silently."
                "get software"        = "Get a list of installed software that can be installed."
                "schedule task "      = "(ALPHA) Schedule a new task."
                "Cancel"              = "Select nothing and exit this menu."
            }) -prompt "Select a Chaste Scripts function:" -returnKey

        if ($choice -eq "Cancel") {
            readCommand
        }

        readCommand -command $choice
    } catch {
        writeText -type "error" -text "readMenu-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function writeHelp {
    writeText -type "plain" -text "USER COMMANDS:" -lineBefore
    writeText -type "plain" -text "add [local,ad] user              - Add a local or domain user to the system." -Color "DarkGray"
    writeText -type "plain" -text "remove user                      - Add a local or domain user to the system." -Color "DarkGray"
    writeText -type "plain" -text "edit user [name,password,group]  - Edit user account settings." -Color "DarkGray"
    writeText -type "plain" -text "SYSTEM COMMANDS:" -lineBefore
    writeText -type "plain" -text "edit hostname        - Edit the computers hostname and description." -Color "DarkGray"
    writeText -type "plain" -text "repair windows       - Repair Windows." -Color "DarkGray"
    writeText -type "plain" -text "update windows      - Install Windows updates. All or just severe." -Color "DarkGray"
    writeText -type "plain" -text "schedule task        - Create a task in the task scheduler." -Color "DarkGray"
    writeText -type "plain" -text "toggle context menu  - Disable the Windows 11 context menu." -Color "DarkGray"
    writeText -type "plain" -text "NETWORK COMMANDS:" -lineBefore
    writeText -type "plain" -text "edit net adapter  - Edit network adapters." -Color "DarkGray"
    writeText -type "plain" -text "get wifi creds    - View WiFi credentials for the currently active WiFi adapter." -Color "DarkGray"
    writeText -type "plain" -text "FULL DOCUMENTATION:" -lineBefore
    writeText -type "plain" -text "https://guided.chaste.pro/dev/chaste-scripts" -Color "DarkGray"
}