function readMenu {
    try {
        # Create a menu with options and descriptions using an ordered hashtable
        $choice = readOption -options $([ordered]@{
                "Toggle administrator"         = "Toggle the Windows built in administrator account."
                "Add user"                     = "Add a user to the system."
                "Remove user"                  = "Remove a user from the system."
                "Edit user"                    = "Edit a users."
                "Edit hostname"                = "Edit this computers name and description."
                "Edit network adapter (Alpha)" = "Edit a network adapter.(BETA)"
                "Get WiFi credentials"         = "View all saved WiFi credentials on the system."
                "Toggle W11 Context Menu"      = "Enable or Disable the Windows 11 context menu."
                "Install updates (Alpha)"      = "Install Windows updates silently."
                "Schedule task (Alpha)"        = "Schedule a new task."
                "Cancel"                       = "Select nothing and exit this menu."
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
            8 { $command = "install updates" }
            9 { $command = "add task" }
            10 { readCommand }
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
