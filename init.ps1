function initializeShellCLI {
    try {
        # Elevation
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]$identity

        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            try {
                Start-Process -FilePath 'powershell.exe' -Verb RunAs -ErrorAction Stop `
                    -WorkingDirectory $env:SystemRoot -ArgumentList @(
                    '-NoProfile'
                    '-ExecutionPolicy', 'Bypass'
                    '-Command', 'irm https://raw.githubusercontent.com/badsyntaxx/shellcli/main/init.ps1 | iex'
                )
            } catch {
                # Thrown when the user cancels the UAC prompt (error 1223) or
                # when a policy blocks elevation entirely.
                Write-Host "  ShellCLI requires administrator privileges." -ForegroundColor "Yellow"
            }

            return
        }

        # A dev checkout loaded earlier in this window must not leak into this run.
        $global:shellcliDevRoot = $null

        # Download everything up front, in memory: the config has to be known
        # before anything is written to disk. Nothing is ever written and then
        # executed, so execution policy never applies and there is no window in
        # which a file could be swapped between being written and being run.
        $framework = getRemoteFile -file 'framework.ps1'
        if ($null -eq $framework) {
            throw "Could not download framework.ps1"
        }

        $core = getRemoteFile -directory 'main' -file 'core.ps1'
        if ($null -eq $core) {
            throw "Could not download main/core.ps1"
        }

        # Optional: without it ShellCLI uses its default folders and only the
        # built-in commands.
        $configText = getRemoteFile -file 'config.json' -optional

        # Cheap sanity check: a successful download is never this small
        if (($framework.Length + $core.Length) -lt 256) {
            throw "Downloaded scripts look truncated ($($framework.Length + $core.Length) chars)"
        }

        # Define the framework and core functions in this scope. The shell
        # itself is started below, once the folders are set up.
        . ([scriptblock]::Create($framework + "`n" + $core))

        # The framework just reset the module cache. core is already defined,
        # so seed the cache with it and the first core command (help) does not
        # download it a second time.
        $global:moduleCache = @{ 'main/core' = $core }

        loadShellcliConfig -json $configText
        if ($null -eq $configText) {
            addConfigWarning "Could not download config.json. Using the default folders and only the built-in commands."
        }

        # The root folder comes first: create it and lock it down before
        # anything else is put in it. A configured folder that cannot be used
        # falls back to its default, with a warning, instead of stopping startup.
        $rootExisted = Test-Path -LiteralPath (getConfigPath -name root) -PathType Container
        ensureConfigFolder -key rootDirectory
        $shellCliRoot = getConfigPath -name root

        if (testShellcliRootIsOurs -path $shellCliRoot -existedBefore $rootExisted) {
            protectShellCLIDirectory -path $shellCliRoot
        } else {
            addConfigWarning "rootDirectory '$shellCliRoot' already holds other files, so its permissions were left alone. ShellCLI runs cached modules and installers from it: use a folder only ShellCLI uses."
        }

        ensureConfigFolder -key logDirectory
        ensureConfigFolder -key downloadDirectory

        foreach ($warning in $global:shellcliConfigWarnings) {
            log -msg $warning -lvl "WARNING"
        }

        log -msg "Initializing ShellCLI"
        log -msg "Downloaded framework.ps1 ($($framework.Length) chars), core.ps1 ($($core.Length) chars), config.json ($("$configText".Length) chars)" -lvl "DEBUG"
        log -msg "Folders: root=$shellCliRoot log=$(getConfigPath -name log) download=$(getConfigPath -name download)" -lvl "DEBUG"
        log -msg "Commands: $($global:commandMap.Count)" -lvl "DEBUG"

        # Domain check
        $domain = getJoinedDomain
        if ($domain) {
            Write-Host "  This computer is joined to the domain '$domain'." -ForegroundColor "Yellow"
            Write-Host "  Much of ShellCLI will not work on domain-joined computers." -ForegroundColor "Yellow"
            Read-Host "  Press any key to continue..."
            log -msg "Domain-joined computer detected ($domain)" -lvl "WARNING"
        }

        log -msg "Running main script"
        invokeScript -script "startShell" -initialize $true
    } catch {
        Write-Host "  $($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -ForegroundColor "Red"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}

function getRemoteFile {
    <#
        Downloads one file from the repo and returns its text.
        Reports the error and returns $null if it cannot be obtained. With
        -optional the failure is only logged, because the caller has a fallback.
    #>
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $false)][string]$directory,
        [Parameter(Mandatory)][string]$file,   # with its extension, e.g. framework.ps1
        [Parameter(Mandatory = $false)][switch]$optional
    )

    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    try {
        $base = 'https://raw.githubusercontent.com/badsyntaxx/shellcli/main'
        $url = if ($directory) { "$base/$directory/$file" } else { "$base/$file" }

        # Older hosts may still default to TLS 1.0, which GitHub rejects.
        [Net.ServicePointManager]::SecurityProtocol = `
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

        # Windows PowerShell 5.1 does not ask for compression by itself. With
        # the header GitHub sends gzip (~75% smaller) and the body still comes
        # back decoded.
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop `
            -Headers @{ 'Accept-Encoding' = 'gzip' }

        # Decode UTF-8 explicitly rather than trusting the response header.
        $src = [System.Text.Encoding]::UTF8.GetString($response.RawContentStream.ToArray()).TrimStart([char]0xFEFF)

        if ([string]::IsNullOrWhiteSpace($src)) {
            throw "Downloaded an empty response from $url"
        }

        return $src
    } catch {
        # Nothing is logged on success or for an optional file: the log folder
        # is not known until the config has been read, and logging earlier
        # would create the default folder even when another one is configured.
        if (-not $optional) {
            Write-Host "  $($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -ForegroundColor "Red"
            log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
        }
        return $null
    } finally {
        $ProgressPreference = $oldProgress
    }
}

function protectShellCLIDirectory {
    <#
        Restricts the ShellCLI root folder (rootDirectory in config.json) to
        SYSTEM and Administrators.

        Subfolders under ProgramData inherit ACEs that let standard users create
        files there. Installers and cached modules are written here and then
        run (or read back and evaluated) with admin rights, so an unprivileged
        user could otherwise swap their contents in between.
    #>
    param (
        [Parameter(Mandatory)][string]$path
    )

    try {
        $acl = Get-Acl -LiteralPath $path
        $acl.SetAccessRuleProtection($true, $false)   # disable inheritance, drop inherited ACEs

        foreach ($sid in @('S-1-5-18', 'S-1-5-32-544')) {
            # SYSTEM, BUILTIN\Administrators
            $account = (New-Object Security.Principal.SecurityIdentifier($sid))
            $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule(
                        $account,
                        'FullControl',
                        'ContainerInherit, ObjectInherit',
                        'None',
                        'Allow'
                    )))
        }

        Set-Acl -LiteralPath $path -AclObject $acl -ErrorAction Stop
        log -msg "Secured $path" -lvl "DEBUG"
    } catch {
        # Non-fatal: tell the user and continue rather than blocking startup.
        addConfigWarning "Could not restrict access to ${path} ($($_.Exception.Message)). Cached modules and installers are run from it."
    }
}
function testShellcliRootIsOurs {
    <#
        True when ShellCLI may take over the permissions of the root folder:
        it is the default root, it did not exist before this run, or it holds
        only things ShellCLI puts there. Anything else is somebody else's
        folder, and removing its inherited permissions could lock people out.
    #>
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)][string]$path,
        [Parameter(Mandatory)][bool]$existedBefore
    )

    if (-not $existedBefore) { return $true }
    if ($path -ieq (getDefaultFolder -key rootDirectory)) { return $true }

    foreach ($item in @(Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue)) {
        if ($item.Name -notmatch '^(cache|downloads|logs|\.write-test-.*)$' -and $item.Name -notmatch '\.log$') {
            return $false
        }
    }

    return $true
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

function getJoinedDomain {
    <#
        Returns the AD domain name if this machine is domain joined, otherwise $null.
        Failure to query is treated as "not joined" so startup is never blocked.
    #>
    [OutputType([string])]
    param ()

    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        if ($cs.PartOfDomain) { return $cs.Domain }
        return $null
    } catch {
        log -msg "Could not determine domain membership: $($_.Exception.Message)" -lvl "WARNING"
        return $null
    }
}

# Invoke the root of Shell CLI
initializeShellCLI
