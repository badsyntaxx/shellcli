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
                "Toggle administrator"        = "Toggle the Windows built in administrator account."
                "Add user"                    = "Add a user to the system."
                "Remove user"                 = "Remove a user from the system."
                "Edit user"                   = "Edit a users."
                "Edit hostname"               = "Edit this computers name and description."
                "Edit network adapter (BETA)" = "Edit a network adapter."
                "Get WiFi credentials"        = "View all saved WiFi credentials on the system."
                "Toggle W11 Context Menu"     = "Enable or Disable the Windows 11 context menu."
                "Repair Windows (BETA)"       = "Repair Windows."
                "Install updates (BETA)"      = "Install Windows updates silently."
                "Schedule task (ALPHA)"       = "Schedule a new task."
                "Cancel"                      = "Select nothing and exit this menu."
            }) -prompt "Select a Chaste Scripts function:"

        switch ($choice) {
            0 { $command = "toggle admin" }
            1 { $command = "add user" }
            2 { $command = "remove user" }
            3 { $command = "edit user" }
            4 { $command = "edit hostname" }
            5 { $command = "edit net adapter" }
            6 { $command = "get wifi creds" }
            7 { $command = "toggle context menu" }
            8 { $command = "repair windows" }
            9 { $command = "install updates" }
            10 { $command = "add task" }
            11 { readCommand }
        }

        Write-Host
        Write-Host ": "  -ForegroundColor "DarkCyan" -NoNewline
        Write-Host "Running command:" -NoNewline -ForegroundColor "DarkGray"
        Write-Host " $command" -ForegroundColor "Gray"

        readCommand -command $command
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
    writeText -type "plain" -text "install updates      - Install Windows updates. All or just severe." -Color "DarkGray"
    writeText -type "plain" -text "schedule task        - Create a task in the task scheduler." -Color "DarkGray"
    writeText -type "plain" -text "toggle context menu  - Disable the Windows 11 context menu." -Color "DarkGray"
    writeText -type "plain" -text "NETWORK COMMANDS:" -lineBefore
    writeText -type "plain" -text "edit net adapter  - Edit network adapters." -Color "DarkGray"
    writeText -type "plain" -text "get wifi creds    - View WiFi credentials for the currently active WiFi adapter." -Color "DarkGray"
    writeText -type "plain" -text "FULL DOCUMENTATION:" -lineBefore
    writeText -type "plain" -text "https://guided.chaste.pro/dev/chaste-scripts" -Color "DarkGray"
}