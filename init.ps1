function initializeShellCLI {
    try {
        log -msg "Initializing ShellCLI..."
        # Check if user has administrator privileges
        if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
            log -msg "Terminal is not admin. Self elevating."
            # If not, elevate privileges and restart function with current arguments
            Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
            Exit
        }
        
        # Create the main script file
        log -msg "Building main script..."
        New-Item -Path "$env:ProgramData\shellcli\SHELLCLI.ps1" -ItemType File -Force | Out-Null

        appendToMainScript -file "framework"
        appendToMainScript -directory "main" -file "core" -functionName "writeHelp"

        # Add a final line that will invoke the desired function
        Add-Content -Path "$env:ProgramData\shellcli\SHELLCLI.ps1" -Value 'invokeScript -script "readCommand -command `"help`"" -initialize $true'

        log -msg "Running main script..."
        # Execute the combined script
        . "$env:ProgramData\shellcli\SHELLCLI.ps1"
    } catch {
        Write-Host "  $($MyInvocation.MyCommand.Name): $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor "Red"
        log -msg "$($MyInvocation.MyCommand.Name): $($_.InvocationInfo.ScriptLineNumber)-$($_.Exception.Message)"
    }
}
function appendToMainScript {
    param (
        [Parameter(Mandatory = $false)][string]$directory,
        [Parameter(Mandatory)][string]$file,
        [Parameter(Mandatory = $false)][string]$functionName
    )

    try {
        $url = "https://raw.githubusercontent.com/badsyntaxx/shellcli/main/$file.ps1"
        if ($directory) {
            $url = "https://raw.githubusercontent.com/badsyntaxx/shellcli/main/$directory/$file.ps1"
        }

        $src = (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($src, [ref]$null, [ref]$null)

        if (-not $functionName) {
            # If no function name is provided, append the entire script
            Add-Content -Path "$env:ProgramData\shellcli\SHELLCLI.ps1" -Value $src
            return
        }

        $fn = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq $functionName
            }, $true) | Select-Object -First 1

        if ($fn) {
            Add-Content -Path "$env:ProgramData\shellcli\SHELLCLI.ps1" -Value $fn.Extent.Text
        } else {
            throw "Function '$functionName' not found."
        }
    } catch {
        Write-Host "  $($MyInvocation.MyCommand.Name): $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor "Red"
        log -msg "$($MyInvocation.MyCommand.Name): $($_.InvocationInfo.ScriptLineNumber)-$($_.Exception.Message)"
    }

    
}
function log {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$msg,
        [Parameter(Position = 1)]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'DEBUG', 'SUCCESS')]
        [string]$lvl = 'INFO'
    )

    try {      
        # Define log directory
        $logDirectory = "$env:ProgramData\shellcli"
        
        # Create log directory if it doesn't exist
        if (-not (Test-Path -Path $logDirectory)) {
            try {
                New-Item -Path $logDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
            } catch {
                Write-Error "Failed to create log directory: $_"
                return
            }
        }
        
        # Define log file path
        $dateStamp = Get-Date -Format "yyyy-MM-dd"
        $logFileName = "${dateStamp}.log"
        $logFilePath = Join-Path -Path $logDirectory -ChildPath $logFileName

        # Format log entry
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$lvl] $msg"
            
        # Write to log file
        Add-Content -Path $logFilePath -Value $logEntry -ErrorAction Stop
    } catch {
        Write-Error "Failed to write log entry: $_"
    }
}

# Invoke the root of Shell CLI
initializeShellCLI
