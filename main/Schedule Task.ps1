function scheduleTask {
    try {
        # Prompt the user for task settings
        $taskName = readInput -prompt "Enter a name for your scheduled task"
        $action = readInput -prompt "Enter the action (e.g., path to a script or executable)"
        $arguments = readInput -prompt "Enter any arguments for the action (if applicable)"
        $runType = readInput -prompt "Select the task frequency (one-time/daily/weekly/monthly)"

        # Initialize trigger objects
        $triggerObj = $null

        # Common action for all trigger types
        $actionObj = New-ScheduledTaskAction -Execute $action -Argument $arguments

        # Process user's choice
        switch ($runType.ToLower()) {
            "one-time" {
                $startTime = readInput -prompt "Enter the date and time for the one-time task (e.g., '2024-08-15 14:30'):"
                $triggerObj = New-ScheduledTaskTrigger -Once -At $startTime
            }
            "daily" {
                $dailyInterval = readInput -prompt "Enter the interval in minutes for the daily task (e.g., 60 for every hour):"
                $triggerObj = New-ScheduledTaskTrigger -Daily -RepetitionInterval ([TimeSpan]::FromMinutes($dailyInterval))
            }
            "weekly" {
                $triggerDays = readInput -prompt "Enter the days of the week (comma-separated) when the task should run (e.g., Monday,Wednesday,Friday)"
                $daysOfWeek = $triggerDays -split ',' | ForEach-Object { $_.Trim() }
                $triggerObj = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $daysOfWeek
            }
            "monthly" {
                $dayOfMonth = readInput -prompt "Enter the day of the month for the monthly task (1-31):"
                $monthlyTime = readInput -prompt "Enter the time for the monthly task (in HH:mm format):"
                $triggerObj = New-ScheduledTaskTrigger -Monthly -DaysOfMonth $dayOfMonth -At $monthlyTime
            }
            default {
                Write-Host "Invalid choice. Please select one-time, daily, weekly, or monthly."
                exit
            }
        }

        Register-ScheduledTask -Action $actionObj -Trigger $triggerObj -TaskName $taskName -User 'NT AUTHORITY\SYSTEM' -RunLevel Highest

        Write-Host "Task '$taskName' has been scheduled successfully!"
    } catch {
        writeText -type "error" -text "scheduleTask-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
