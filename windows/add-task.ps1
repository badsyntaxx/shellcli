function add-task {
    try {
        # Prompt the user for task settings
        $taskName = Read-Host "Enter a name for your scheduled task"
        $action = Read-Host "Enter the action (e.g., path to a script or executable)"
        $arguments = Read-Host "Enter any arguments for the action (if applicable)"
        $runType = Read-Host "Select the task frequency (one-time/daily/weekly/monthly):"

        # Initialize trigger objects
        $triggerObj = $null

        # Common action for all trigger types
        $actionObj = New-ScheduledTaskAction -Execute $action -Argument $arguments

        # Process user's choice
        switch ($runType.ToLower()) {
            "one-time" {
                $startTime = Read-Host "Enter the date and time for the one-time task (e.g., '2024-08-15 14:30'):"
                $triggerObj = New-ScheduledTaskTrigger -Once -At $startTime
            }
            "daily" {
                $dailyInterval = Read-Host "Enter the interval in minutes for the daily task (e.g., 60 for every hour):"
                $triggerObj = New-ScheduledTaskTrigger -Daily -RepetitionInterval ([TimeSpan]::FromMinutes($dailyInterval))
            }
            "weekly" {
                $triggerDays = Read-Host "Enter the days of the week (comma-separated) when the task should run (e.g., Monday,Wednesday,Friday)"
                $daysOfWeek = $triggerDays -split ',' | ForEach-Object { $_.Trim() }
                $triggerObj = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $daysOfWeek
            }
            "monthly" {
                $dayOfMonth = Read-Host "Enter the day of the month for the monthly task (1-31):"
                $monthlyTime = Read-Host "Enter the time for the monthly task (in HH:mm format):"
                $triggerObj = New-ScheduledTaskTrigger -Monthly -DaysOfMonth $dayOfMonth -At $monthlyTime
            }
            default {
                Write-Host "Invalid choice. Please select one-time, daily, weekly, or monthly."
                exit
            }
        }

        # Register the task
        Register-ScheduledTask -Action $actionObj -Trigger $triggerObj -TaskName $taskName -User 'NT AUTHORITY\SYSTEM' -RunLevel Highest

        Write-Host "Task '$taskName' has been scheduled successfully!"

        read-command
    } catch {
        # Display error message and exit this script
        write-text -type "error" -text "schedule-task-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
        read-command
    }
}