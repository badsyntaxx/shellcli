function initializeShellCLI {
    try {
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Start-Process powershell.exe -Verb RunAs -WorkingDirectory $PSScriptRoot -ArgumentList @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit', '-File', "`"$PSCommandPath`"")
            return
        }

        $global:shellcliDevRoot = $PSScriptRoot
        $global:moduleCache = @{}

        foreach ($f in 'framework.ps1', 'main\core.ps1') {
            . ([scriptblock]::Create([System.IO.File]::ReadAllText((Join-Path $PSScriptRoot $f))))
        }

        # The local config.json, so folder and command changes can be tried
        # without pushing.
        $configPath = Join-Path $PSScriptRoot 'config.json'
        $configText = $null
        if (Test-Path -LiteralPath $configPath) { $configText = [System.IO.File]::ReadAllText($configPath) }

        loadShellcliConfig -json $configText
        if ($null -eq $configText) {
            addConfigWarning "DEV: no config.json in $PSScriptRoot. Using the default folders and only the built-in commands."
        }

        # Same folder checks as init.ps1 (without locking the root down), so a
        # bad folder in the local config falls back instead of breaking logging.
        foreach ($key in 'rootDirectory', 'logDirectory', 'downloadDirectory') {
            ensureConfigFolder -key $key
        }

        writeText -type "notice" -text "DEV MODE - loading modules from $PSScriptRoot"
        invokeScript -script "startShell" -initialize $true
    } catch {
        Write-Host "  $($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor "Red"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)"
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
        # Define log directory: the configured one once the config is loaded,
        # the default before that (this copy runs before the framework exists)
        $logDirectory = if ($global:shellcliConfig) { $global:shellcliConfig.logDirectory } else { Join-Path -Path $env:ProgramData -ChildPath 'shellcli' }

        # Create log directory if it doesn't exist
        if (-not (Test-Path -LiteralPath $logDirectory)) {
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
        Add-Content -LiteralPath $logFilePath -Value $logEntry -ErrorAction Stop
    } catch {
        Write-Error "Failed to write log entry: $_"
    }
}

initializeShellCLI