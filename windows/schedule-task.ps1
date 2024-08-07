# Prompt the user for task settings
$taskName = Read-Host "Enter a name for your scheduled task"
$action = Read-Host "Enter the action (e.g., path to a script or executable)"
$arguments = Read-Host "Enter any arguments for the action (if applicable)"
$triggerDays = Read-Host "Enter the days of the week (comma-separated) when the task should run (e.g., Monday,Wednesday,Friday)"
$triggerTime = Read-Host "Enter the time (in HH:mm format) when the task should run (e.g., 10:00)"

# Convert trigger days to an array
$daysOfWeek = $triggerDays -split ',' | ForEach-Object { $_.Trim() }

# Create the action
$actionObj = New-ScheduledTaskAction -Execute $action -Argument $arguments

# Create the trigger
$triggerObj = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $daysOfWeek -At $triggerTime

# Register the task
Register-ScheduledTask -Action $actionObj -Trigger $triggerObj -TaskName $taskName -User 'NT AUTHORITY\SYSTEM' -RunLevel Highest

Write-Host "Task '$taskName' has been scheduled successfully!"