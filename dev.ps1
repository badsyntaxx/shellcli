function initializeShellCLI {
    try {
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Start-Process powershell.exe -Verb RunAs -WorkingDirectory $PSScriptRoot -ArgumentList @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit', '-File', "`"$PSCommandPath`"")
            return
        }

        $global:shellcliConfig = $null
        $global:shellcliDevRoot = $PSScriptRoot
        $global:moduleCache = @{}

        foreach ($f in 'framework.ps1', 'main\core.ps1') {
            . ([scriptblock]::Create([System.IO.File]::ReadAllText((Join-Path $PSScriptRoot $f))))
        }

        # The local config.json, so folder and command changes can be tried
        # without pushing. It is required, as it is everywhere else.
        $configPath = Join-Path $PSScriptRoot 'config.json'
        if (-not (Test-Path -LiteralPath $configPath)) {
            throw "There is no config.json in $PSScriptRoot."
        }

        # Throws, listing every problem, if config.json is not usable.
        loadShellcliConfig -json ([System.IO.File]::ReadAllText($configPath))

        # Same folder checks as init.ps1 (without locking the root down).
        foreach ($key in 'rootDirectory', 'logDirectory', 'downloadDirectory') {
            ensureConfigFolder -key $key
        }

        writeText -type "notice" -text "DEV MODE - loading modules from $PSScriptRoot"
        invokeScript -script "startShell" -initialize $true
    } catch {
        $detail = "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"

        Write-Host
        Write-Host "  ShellCLI could not start:" -ForegroundColor "Red"
        foreach ($line in ($_.Exception.Message -split "`r?`n")) {
            Write-Host "  $line" -ForegroundColor "Red"
        }

        # Only written if config.json was loaded, and never allowed to add noise of its own.
        log -msg $detail -lvl "ERROR" 2>$null
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
        # The log folder comes from config.json. Until that is loaded there is no
        # log folder, and none is invented. (This copy runs before the framework exists.)
        if (-not $global:shellcliConfig) { return }
        $logDirectory = $global:shellcliConfig.logDirectory

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