function readMenu {
    try {
        # Create a menu with options and descriptions using an ordered hashtable
        $choice = readOption -options $([ordered]@{
                "User menu"            = "View the user management menu."
                "Edit hostname"        = "Edit this computers name and description."
                "Edit net adapter"     = "(BETA) Edit a network adapter."
                "Get wifi credentials" = "View all saved WiFi credentials on the system."
                "Toggle context menu"  = "Enable or Disable the Windows 11 context menu."
                "Repair windows"       = "Repair Windows."
                "Update windows"       = "(BETA) Install Windows updates silently."
                "Clear temp files"     = "Removes Windows temporary and cache files."
                "Get software"         = "Get a list of installed software that can be installed."
                "Schedule task "       = "(ALPHA) Schedule a new task."
                "Cancel"               = "Select nothing and exit this menu."
            }) -prompt "Select a function." -returnKey -lineAfter

        if ($choice -eq "Cancel") {
            readCommand
        }
        
        switch ($choice) {
            "User menu" { $choice = "user menu" }
            "Edit hostname" { $choice = "edit hostname" }
            "Edit net adapter" { $choice = "edit net adapter" }
            "Get wifi credentials" { $choice = "wifi" }
            "Toggle context menu" { $choice = "toggle context menu" }
            "Repair windows" { $choice = "repair windows" }
            "Update windows" { $choice = "update windows" }
            "Clear temp files" { $choice = "clear temp files" }
            "Get software" { $choice = "get apps" }
            "Schedule task" { $choice = "schedule task" }
        }

        readCommand -command $choice
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function writeHelp {   
    writeText -type "plain" -text "GET STARTED:"
    writeText -type "plain" -text "commands    - Display a full list of commands."
    writeText -type "plain" -text "menu        - Display a menu with some available functions."
    writeText -type "plain" -text "? or help   - Display this help text."
    writeText -type "plain" -text "FULL DOCUMENTATION:" -lineBefore
    writeText -type "plain" -text "https://wkey.pro/dev/shellcli"
}
function listAllCommands {
    try {
        writeText -type "List" -List $global:commandMap -ListValue 3
        
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function readLog {
    param (
        [Parameter(Mandatory = $false)]
        [int]$lines = 50,  # Show last 50 lines by default
        [Parameter(Mandatory = $false)]
        [switch]$tail   # Follow mode (like Linux tail -f)
    )

    try {
        $logDirectory = "$env:ProgramData\shellcli"
        
        if ($date) {
            $logFileName = "${date}.log"
            $logFilePath = Join-Path -Path $logDirectory -ChildPath $logFileName
            if (-not (Test-Path -Path $logFilePath)) {
                writeText -type "plain" -text "No log file found for date: $date"
                readCommand
            }
        } else {
            $logFiles = Get-ChildItem -Path $logDirectory -Filter "*.log" | 
            Sort-Object -Property LastWriteTime -Descending
            if ($logFiles.Count -eq 0) {
                writeText -type "plain" -text "No log files found in $logDirectory"
                readCommand
            }
            $logFilePath = $logFiles[0].FullName
            writeText -type "header" -text "Reading Log: $($logFiles[0].Name)"
        }
        
        # Read last N lines (most useful for logs)
        Get-Content -Path $logFilePath -Tail $lines
        
        # If tail switch is used, follow the log
        if ($tail) {
            writeText -type "plain" -text "`nFollowing log (Ctrl+C to stop)..."
            Get-Content -Path $logFilePath -Wait
        }
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
