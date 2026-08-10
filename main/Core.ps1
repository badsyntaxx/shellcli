function shellCLI {
    Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
    Write-Host " $([char]0x2502)" -NoNewline -ForegroundColor "Gray"
    Write-Host " Try" -NoNewline
    Write-Host " help" -ForegroundColor "Cyan" -NoNewline
    Write-Host " or" -NoNewline
    Write-Host " menu" -NoNewline -ForegroundColor "Cyan"
    Write-Host " if you get stuck."
    Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
}
function readMenu {
    try {
        # Create a menu with options and descriptions using an ordered hashtable
        $choice = readOption -options $([ordered]@{
                "user menu"           = "View the user management menu."
                "edit hostname"       = "Edit this computers name and description."
                "edit net adapter"    = "(BETA) Edit a network adapter."
                "get wifi creds"      = "View all saved WiFi credentials on the system."
                "toggle context menu" = "Enable or Disable the Windows 11 context menu."
                "repair windows"      = "Repair Windows."
                "update windows"      = "(BETA) Install Windows updates silently."
                "clear temp files"    = "Removes Windows temporary and cache files."
                "get software"        = "Get a list of installed software that can be installed."
                "schedule task "      = "(ALPHA) Schedule a new task."
                "Cancel"              = "Select nothing and exit this menu."
            }) -prompt "Select a function." -returnKey -lineAfter

        if ($choice -eq "Cancel") {
            readCommand
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
        $logDirectory = "C:\Temp\ShellCLI"
        
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
            writeText -type "header" -text "Reading: $($logFiles[0].Name)"
            writeText -type "plain" -text "----------------------------------------"
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