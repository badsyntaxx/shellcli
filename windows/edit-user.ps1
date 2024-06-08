function edit-user {
    try {
        $choice = get-option -Options $([ordered]@{
                "Edit user name"     = "Edit an existing users name."
                "Edit user password" = "Edit an existing users password."
                "Edit user group"    = "Edit an existing users group membership."
            }) -lineAfter

        switch ($choice) {
            0 { $command = "edit user name" }
            1 { $command = "edit user password" }
            2 { $command = "edit user group" }
        }

        get-cscommand -command $command
    } catch {
        # Display error message and end the script
        exit-script -type "error" -text "edit-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

