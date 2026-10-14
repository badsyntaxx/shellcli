# The one address ShellCLI cannot take from config.json, because config.json is
# itself downloaded from here, along with framework.ps1 and main/core.ps1. The
# elevated relaunch fetches this script from here too. The command modules
# come from the repository named in config.json, never from this address.
# A fork changes this line (and the repository in config.json).
$global:shellcliBootstrapBase = 'https://raw.githubusercontent.com/badsyntaxx/shellcli/main'.TrimEnd('/')

function initializeShellCLI {
    try {
        # Everything downloaded from this address runs as administrator, so it
        # must be https. (config.json's repository has to be https as well, and
        # has to name the same repository, so nothing else could ever start.)
        if ($global:shellcliBootstrapBase -notmatch '^https://') {
            throw "`$global:shellcliBootstrapBase in init.ps1 must be an https address, but it is '$($global:shellcliBootstrapBase)'."
        }

        # Elevation
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]$identity

        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            try {
                Start-Process -FilePath 'powershell.exe' -Verb RunAs -ErrorAction Stop `
                    -WorkingDirectory $env:SystemRoot -ArgumentList @(
                    '-NoProfile'
                    '-ExecutionPolicy', 'Bypass'
                    # The flag keeps this window open after a failed start, so the error can be read.
                    '-Command', "`$global:shellcliPauseOnError = `$true; irm '$($global:shellcliBootstrapBase)/init.ps1' | iex"
                )
            } catch {
                # Thrown when the user cancels the UAC prompt (error 1223) or
                # when a policy blocks elevation entirely.
                Write-Host "  ShellCLI requires administrator privileges." -ForegroundColor "Yellow"
            }

            return
        }

        # A dev checkout or a config loaded earlier in this window must not leak into this run.
        $global:shellcliDevRoot = $null
        $global:shellcliConfig = $null

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

        # config.json is required. There are no defaults to fall back on.
        $configText = getRemoteFile -file 'config.json'
        if ($null -eq $configText) {
            throw "Could not download config.json"
        }

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

        # Throws, listing every problem, if config.json is not usable.
        loadShellcliConfig -json $configText

        # config.json and this script must name the same repository. A fork that
        # changes only one of them would otherwise run another repository's
        # modules as administrator. This stops startup before anything is
        # written to disk. (The Get-Command guard only matters in the few
        # minutes after a push when this script and framework.ps1 are from
        # different versions.)
        if (Get-Command getRepositoryMismatch -ErrorAction SilentlyContinue) {
            $mismatch = getRepositoryMismatch -configuredBase $global:shellcliConfig['repositoryBase'] -bootstrapBase $global:shellcliBootstrapBase
            if ($mismatch) {
                # Forget the config, so the error handler has no log folder to create.
                $global:shellcliConfig = $null
                throw $mismatch
            }
        }

        # The root folder comes first: create it and lock it down before
        # anything else is put in it. Folders are created exactly as config.json
        # has them, and one that cannot be created stops startup with an error.
        ensureConfigFolder -key rootDirectory
        $shellCliRoot = getConfigPath -name root

        protectShellCLIDirectory -path $shellCliRoot

        # The other folders are created only now, after the root is locked down:
        # a folder inside it then inherits the restricted permissions from the
        # start. One created earlier would begin with the permissions of its
        # parent, and a file planted in it before the lock-down would stay.
        ensureConfigFolder -key logDirectory
        ensureConfigFolder -key downloadDirectory
        ensureConfigFolder -key cacheDirectory

        foreach ($warning in $global:shellcliConfigWarnings) {
            log -msg $warning -lvl "WARNING"
        }

        log -msg "Initializing ShellCLI"
        log -msg "Downloaded framework.ps1 ($($framework.Length) chars), core.ps1 ($($core.Length) chars), config.json ($("$configText".Length) chars)" -lvl "DEBUG"
        log -msg "Folders: root=$shellCliRoot log=$(getConfigPath -name log) download=$(getConfigPath -name download) cache=$(getConfigPath -name cache)" -lvl "DEBUG"
        log -msg "Commands: $($global:commandMap.Count)" -lvl "DEBUG"
        if (Get-Command getModuleBase -ErrorAction SilentlyContinue) {
            log -msg "Modules are downloaded from $(getModuleBase)" -lvl "DEBUG"
        }

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
        $detail = "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"

        Write-Host
        Write-Host "  ShellCLI could not start:" -ForegroundColor "Red"
        foreach ($line in ($_.Exception.Message -split "`r?`n")) {
            Write-Host "  $line" -ForegroundColor "Red"
        }

        # Only written if config.json was loaded, and never allowed to add noise of its own.
        log -msg $detail -lvl "ERROR" 2>$null

        # In the window opened by the elevated relaunch, wait so the error stays readable.
        if ($global:shellcliPauseOnError) {
            Write-Host
            [void](Read-Host "  Press Enter to close")
        }
    }
}

function getRemoteFile {
    <#
        Downloads one file from the bootstrap address and returns its text.
        Reports the error and returns $null if it cannot be obtained.
    #>
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $false)][string]$directory,
        [Parameter(Mandatory)][string]$file   # with its extension, e.g. framework.ps1
    )

    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    try {
        $base = $global:shellcliBootstrapBase
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
        # Nothing is logged here: the log folder comes from config.json, which
        # is one of the things this downloads. initializeShellCLI reports the failure.
        Write-Host "  $($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -ForegroundColor "Red"
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
        $acl = Get-Acl -LiteralPath $path -ErrorAction Stop
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
