function add-user {
    try {
        $choice = get-option -Options $([ordered]@{
                "Add local user"  = "Add a local user to the system."
                "Add domain user" = "Add a domain user to the system."
            }) -LineBefore

        if ($choice -eq 0) { $command = "add local user" }
        if ($choice -eq 1) { $command = "add ad user" }

        get-cscommand -command $command
    } catch {
        exit-script -Type "error" -Text "add-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -LineAfter
    }
}

