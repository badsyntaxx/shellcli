function add-task {
    # Begin try/catch block for error handling
    try {
        # Prompt for group membership with options and return key
        write-text -type "label" -text "Pick a time"  -lineAfter
        $time = read-input -Validate "^(0[0-9]|1[0-2]):[0-5][0-9]\s?(?i)(am|pm)$"

        $trigger = New-ScheduledTaskTrigger -At $time -Daily
        $User = "NT AUTHORITY\SYSTEM"
        $action = New-ScheduledTaskAction -Execute "shutdown.exe" -Argument "-f -r -t 0"

        Register-ScheduledTask -TaskName "RebootTask" -Trigger $trigger -User $User -Action $action -RunLevel Highest -Force
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "add-task-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}