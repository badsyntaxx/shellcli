function add-task {
    # Begin try/catch block for error handling
    try {
        # Display a welcome message with title, description, and command
        write-welcome -Title "New Scheduled Task" -Description "Add a new local user to the system." -Command "new task"

        # Prompt for group membership with options and return key
        write-text -Type "header" -Text "Pick a time" -LineBefore -LineAfter
        $time = get-input -Validate "^(0[0-9]|1[0-2]):[0-5][0-9]\s?(?i)(am|pm)$"

        $trigger = New-ScheduledTaskTrigger -At $time -Daily
        $User = "NT AUTHORITY\SYSTEM"
        $action = New-ScheduledTaskAction -Execute "shutdown.exe" -Argument "-f -r -t 0"

        Register-ScheduledTask -TaskName "RebootTask" -Trigger $trigger -User $User -Action $action -RunLevel Highest -Force
    } catch {
        # Display error message and end the script
        exit-script -Type "error" -Text "add-task-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -LineAfter
    }
}