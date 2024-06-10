function edit-user {
    try {
        $choice = read-option -options $([ordered]@{
                "Edit user name"     = "Edit an existing users name."
                "Edit user password" = "Edit an existing users password."
                "Edit user group"    = "Edit an existing users group membership."
            })

        switch ($choice) {
            0 { $command = "edit user name" }
            1 { $command = "edit user password" }
            2 { $command = "edit user group" }
        }

        write-welcome -command $command

        read-command -command $command
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "edit-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

