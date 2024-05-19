function menu {
    try {
        clear-host
        write-welcome -Title "Windows Menu" -Description "Select an action to take." -Command "windows menu"

        write-text -Type "header" -Text "Selection" -LineAfter -LineBefore
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
        exit-script -Type "error" -Text "windows-menu-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -LineAfter
    }
}

