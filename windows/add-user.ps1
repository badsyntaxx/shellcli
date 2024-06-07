function add-user {
    # Begin try/catch block for error handling
    try {
        # Prompt user to choose between local or domain user
        write-text -type "label" -text "Local or domain user?" -LineBefore -LineAfter
        $choice = get-option -Options $([ordered]@{
                "Add local user"  = "Add a local user to the system."
                "Add domain user" = "Add a domain user to the system."
            })

        # Determine function name based on user choice
        if ($choice -eq 0) { $command = "add local user" }
        if ($choice -eq 1) { $command = "add ad user" }

        get-cscommand -command $command
    } catch {
        # Display error message and end the script
        exit-script -Type "error" -Text "add-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -LineAfter
    }
}

