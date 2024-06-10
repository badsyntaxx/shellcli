function add-user {
    try {
        $choice = read-option -options $([ordered]@{
                "Add local user"  = "Add a local user to the system."
                "Add domain user" = "Add a domain user to the system."
            })

        if ($choice -eq 0) { $command = "add local user" }
        if ($choice -eq 1) { $command = "add ad user" }

        write-welcome -command $command

        read-command -command $command
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "add-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

