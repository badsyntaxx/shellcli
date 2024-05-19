function edit-user {
    try {
        write-welcome -Title "Edit User" -Description "Edit an existing users data." -Command "edit user"

        write-text -Type "header" -Text "Local or domain user?" -LineAfter -LineBefore
        $choice = get-option -Options $([ordered]@{
                "Edit user name"     = "Edit an existing users name."
                "Edit user password" = "Edit an existing users password."
                "Edit user group"    = "Edit an existing users group membership."
            }) -LineAfter

        if ($choice -eq 0) { $command = "edit user name" }
        if ($choice -eq 1) { $command = "edit user password" }
        if ($choice -eq 2) { $command = "edit user group" }

        get-cscommand -command $command
    } catch {
        # Display error message and end the script
        exit-script -Type "error" -Text "edit-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -LineAfter
    }
}

