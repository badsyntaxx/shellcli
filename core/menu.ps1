function menu {
    try {
        clear-host
        write-welcome -Title "CHASED|Scripts Menu" -Description "Select an action to take." -Command "menu"

        $url = "https://raw.githubusercontent.com/badsyntaxx/chased-scripts/main"
        $subPath = "framework"

        write-text -Type "header" -Text "Select a sub menu" -LineAfter -LineBefore
        $choice = get-option -Options $([ordered]@{
                "Enable administrator" = "Toggle the Windows built in administrator account."
                "Add user"             = "Add a user to the system."
                "Remove user"          = "Remove a user from the system."
                "Edit user"            = "Edit a users."
                "Edit hostname"        = "Edit this computers name and description."
                "Edit network adapter" = "Edit a network adapter.(BETA)"
            }) -LineAfter

        if ($choice -eq 0) { $command = "enable admin" }
        if ($choice -eq 1) { $command = "add user" }
        if ($choice -eq 2) { $command = "remove user" }
        if ($choice -eq 3) { $command = "edit user" }
        if ($choice -eq 4) { $command = "edit hostname" }
        if ($choice -eq 5) { $command = "edit net adapter" }

        get-cscommand -command $command
    } catch {
        exit-script -Type "error" -Text "Menu error: $($_.Exception.Message) $url/$subPath/$dependency.ps1" 
    }
}

