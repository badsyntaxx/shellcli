$global:moduleCache = @{}
$global:commandMap = [ordered]@{
    "?"                              = @("main", "core", "writeHelp", "List some help info.")
    "help"                           = @("main", "core", "writeHelp", "List some help info.")
    "menu"                           = @("main", "core", "readMenu", "Display the main menu.")
    "commands"                       = @("main", "core", "listAllCommands", "List all available commands.")
    "logs"                           = @("main", "core", "readLog", "Output the last 50 lines of the log file.")
    #-- CUSTOMIZATION COMMANDS --#
    "toggle context menu"            = @("main", "common", "toggleContextMenu", "Toggle the context menu.")
    "enable context menu"            = @("main", "common", "enableContextMenu", "Enable the context menu.")
    "disable context menu"           = @("main", "common", "disableContextMenu", "Disable the context menu.")
    "edit hostname"                  = @("main", "common", "editHostname", "Edit the hostname.")
    "edit description"               = @("main", "common", "editDescription", "Edit the host description.")
    #-- USER COMMANDS --#
    "toggle admin"                   = @("main", "user", "toggleAdmin", "Toggle admin privileges.")
    "enable admin"                   = @("main", "user", "enableAdmin", "Enable admin privileges.")
    "disable admin"                  = @("main", "user", "disableAdmin", "Disable admin privileges.")
    "users"                          = @("main", "user", "listUsers", "List all users.")
    "user menu"                      = @("main", "user", "userMenu", "Display the user menu.")
    "add user"                       = @("main", "user", "addUser", "Add a new user.")
    "add local user"                 = @("main", "user", "addLocalUser", "Add a new local user.")
    "add ad user"                    = @("main", "user", "addADUser", "Add a new Active Directory user.")
    "remove user"                    = @("main", "user", "removeUser", "Remove a user.")
    "edit user"                      = @("main", "user", "editUser", "Edit a user.")
    "edit user name"                 = @("main", "user", "editUserName", "Edit a user's name.")
    "edit user password"             = @("main", "user", "editUserPassword", "Edit a user's password.")
    "edit user group"                = @("main", "user", "editUserGroup", "Edit a user's group.")
    "unlock user"                    = @("main", "user", "unlockUser", "Unlock a user.")
    #-- NETWORK COMMANDS --#
    "network"                        = @("main", "network", "network", "Get net adapter info.")
    "edit network"                   = @("main", "network", "editNetAdapter", "Edit the network adapter. ()ETA")
    "wifi"                           = @("main", "network", "getWifiCreds", "Get WiFi credentials.")
    #-- APPS COMMANDS --#
    "get apps"                       = @("main", "apps", "getApps", "Display a menu of available apps.")
    "get app"                        = @("main", "apps", "getApp", "Get an app by providing install details.")
    "get browser apps"               = @("main", "apps", "getBrowserApps", "Display a menu of web browsers.")
    "get diagnostic apps"            = @("main", "apps", "getDiagnosticApps", "Display a menu of PC diagnostic software.")
    "get productivity apps"          = @("main", "apps", "getProductivityApps", "Display a menu of productivity apps.")
    "get customization apps"         = @("main", "apps", "getCustomizationApps", "Display a menu of customization apps.")
    #-- SYSTEM COMMANDS --#
    "techmode 1"                     = @("main", "common", "techMode", "Enable tech mode.")
    "techmode 0"                     = @("main", "common", "userMode", "Enable user mode.")
    "fix icons"                      = @("main", "fix", "fixIcons", "Fix desktop icons.")
    "disable hibernate file"         = @("main", "common", "disableHibernateFile", "Disable the hibernate file.")
    "services"                       = @("main", "services", "listServices", "Display the services.")
    "stop service"                   = @("main", "services", "stopService", "Stop a service.")
    "start service"                  = @("main", "services", "startService", "Start a service.")
    "restart service"                = @("main", "services", "restartService", "Restart a service.")
    "service status"                 = @("main", "services", "getServiceStatus", "Check the status of a service.")
    "service menu"                   = @("main", "services", "serviceMenu", "Display the service controller menu.")
    "schedule task"                  = @("main", "task", "scheduleTask", "Schedule a task.(BETA)")
    "update windows"                 = @("main", "fix", "updateWindows", "Update Windows.")
    "clean temp files"               = @("main", "fix", "cleanTempFiles", "Clear temporary files.")
    "repair windows"                 = @("main", "fix", "repairWindows", "Repair Windows.")
    "install host gpu drivers on vm" = @("main", "gpu", "installHostGPUDriversOnVM", "Install host GPU drivers on VM.")
    "partition gpu"                  = @("main", "gpu", "partitionGPU", "Partition the GPU.")
    "generate encrypted password"    = @("main", "common", "generateEncryptedPassword", "Generate an encrypted password.")
    "unlock local user"              = @("main", "user", "unlockLocalUser", "Unlock a locked local account.")
    "find dc"                        = @("main", "common", "findDC", "Find the domain controller.")
    "storage"                        = @("main", "common", "getStorage", "Display storage information.")
    "stored creds"                   = @("main", "common", "showStoredCredentials", "Show Windows stored credentials.")
    #-- PLUGIN COMMANDS --#
    "plugins"                        = @("plugins", "core", "plugins", "List available plugins.")
    "plugins menu"                   = @("plugins", "core", "readMenu", "Display the plugin menu.")
    "plugins help"                   = @("plugins", "core", "writeHelp", "Display help information for plugins.")
    "plugins ?"                      = @("plugins", "core", "writeHelp", "Display help information for plugins.")
    "plugins massgravel"             = @("plugins", "massgravel", "massgravel", "Windows activation scripts.")
    "plugins reclaim"                = @("plugins", "reclaim", "reclaim", "Disable telemetry and bloatware in Windows 11.")
}

function invokeScript {
    param (
        [parameter(Mandatory = $true)]
        [string]$script,
        [parameter(Mandatory = $false)]
        [boolean]$initialize = $false
    ) 

    try {
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "invokeScript called without elevation"
        }

        # Customize console appearance
        $console = $host.UI.RawUI
        $console.BackgroundColor = "Black"
        $console.ForegroundColor = "White"
        $console.WindowTitle = "Shell CLI"

        if ($initialize) {
            Clear-Host
            Write-Host
            Write-Host "Shell CLI" -ForegroundColor "Cyan"
        }

        Invoke-Expression $script
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function startShell {
    <#
        The command loop. This is the only place that ever prompts.
        Replaces the old recursive readCommand, which grew the call stack by
        two frames per command and eventually died with an uncatchable
        StackOverflowException.
    #>
    param (
        [Parameter(Mandatory = $false)][string]$firstCommand = "help"
    )

    $pending = $firstCommand

    while ($true) {
        try {
            $command = if ($pending) { $pending } else { promptForCommand }
            $pending = $null

            if ([string]::IsNullOrWhiteSpace($command)) { continue }

            $command = $command.ToLower().Trim()

            if ($command -in @('exit', 'quit')) {
                log -msg "Session ended by user." -lvl "INFO"
                break
            }

            runCommand -command $command
        } catch {
            # A failing command must not take the shell down with it.
            writeText -type "error" -text "$($_.Exception.Message)"
            log -msg "startShell-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
        }
    }
}
function promptForCommand {
    <#
        Draws the prompt and returns a non-empty command string.
        Contains no dispatch logic and never recurses.
    #>
    while ($true) {
        Write-Host
        Write-Host "$([char]0x203A) " -NoNewline -ForegroundColor "Gray"

        $esc = [char]27
        Write-Host "$esc[1 q" -NoNewline

        $entry = Read-Host

        if (-not [string]::IsNullOrWhiteSpace($entry)) {
            Write-Host
            return $entry
        }

        # Blank entry: wipe the line and redraw the prompt in place.
        try {
            $cursorPos = [System.Console]::CursorTop - 1
            [System.Console]::SetCursorPosition(0, $cursorPos)
            Write-Host (" " * [System.Console]::WindowWidth) -NoNewline
            [System.Console]::SetCursorPosition(0, $cursorPos)
        } catch {
            # Redirected or non-interactive host: cursor control is
            # unavailable, so fall through and prompt again on a new line.
        }
    }
}
function runCommand {
    <#
        Resolves a command and runs it. Always returns.
    #>
    param (
        [Parameter(Mandatory)][string]$command
    )

    log -msg "Running command: $command"

    $filteredCommand = filterCommands -command $command

    if ($filteredCommand -and $filteredCommand.Count -eq 4) {
        dispatchCommand -filteredCommand $filteredCommand
    }
}
function readCommand {
    <#
        COMPATIBILITY SHIM.

        43 call sites across the modules call `readCommand` with no arguments
        to mean "abandon this and go back to the prompt". Returning here
        unwinds to startShell's loop instead of recursing, which is what stops
        the stack growing.

        This does NOT fix fall-through: code placed after such a call still
        executes. Those sites want `return` instead. Migrate them per file,
        then delete this shim and rename the remaining chaining calls to
        runCommand.
    #>
    param (
        [Parameter(Mandatory = $false)][string]$command = ""
    )

    if ([string]::IsNullOrWhiteSpace($command)) { return }

    runCommand -command $command.ToLower().Trim()
}
function filterCommands {
    param (
        [Parameter(Mandatory = $false)][string]$command
    )

    try {
        $normalized = $command.ToLower().Trim()

        if ([string]::IsNullOrWhiteSpace($normalized)) { return $null }

        # 1. Known shellcli command
        if ($global:commandMap.Contains($normalized)) {
            return $global:commandMap[$normalized]
        }

        # 2. Passthrough to PowerShell
        if (tryInvokePassthrough -command $command) { return $null }

        # 3. Nothing matched. Single exit point, no fall-through.
        writeText -type "plain" -text "Unknown command '$command' | Try 'help' or 'menu'."
        return $null
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
        return $null
    }
}
function tryInvokePassthrough {
    <#
        Runs the input as PowerShell when it looks like PowerShell.
        Returns $true if handled, $false to treat it as an unknown command.
    #>
    param (
        [Parameter(Mandatory)][string]$command
    )

    $trimmed = $command.Trim()

    # Expression-shaped: (...), $var, [type], @(...), &
    $looksLikeExpression = $trimmed -match '^[\(\$\[@&]'

    # Command-shaped: first token resolves as a cmdlet, alias, function or exe
    $firstToken = ($trimmed -split '\s+')[0]
    $resolvesAsCommand = $firstToken -and
    (Get-Command -Name $firstToken -ErrorAction SilentlyContinue)

    if (-not ($looksLikeExpression -or $resolvesAsCommand)) { return $false }

    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput(
        $trimmed, [ref]$null, [ref]$parseErrors)

    if ($parseErrors -and $parseErrors.Count -gt 0) {
        writeText -type "error" -text "Parse error: $($parseErrors[0].Message)"
        return $true
    }

    try {
        $output = Invoke-Expression -Command $trimmed
        if ($null -ne $output) {
            $output | Format-Table -AutoSize | Out-String | Write-Host
        }
    } catch {
        writeText -type "error" -text "Error executing command: $($_.Exception.Message)"
    }

    return $true
}
function getModuleCachePath {
    param (
        [Parameter(Mandatory)][string]$key
    )

    $cacheDir = Join-Path -Path $env:ProgramData -ChildPath 'shellcli\cache'
    if (-not (Test-Path -LiteralPath $cacheDir)) {
        New-Item -Path $cacheDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }

    $safeName = $key -replace '[\\/:*?"<>|]', '_'
    return (Join-Path -Path $cacheDir -ChildPath "$safeName.ps1")
}
function getModuleSource {
    <#
        Returns a command module's source text, or $null if unobtainable.
        Order: memory cache, then network, then disk cache (offline fallback).
    #>
    param (
        [Parameter(Mandatory = $false)][string]$directory,
        [Parameter(Mandatory)][string]$file
    )

    $key = if ($directory) { "$directory/$file" } else { $file }

    if ($global:moduleCache.ContainsKey($key)) {
        log -msg "Module '$key' served from memory." -lvl "DEBUG"
        return $global:moduleCache[$key]
    }

    $base = 'https://raw.githubusercontent.com/badsyntaxx/shellcli/main'
    $url = if ($directory) { "$base/$directory/$file.ps1" } else { "$base/$file.ps1" }
    $cachePath = getModuleCachePath -key $key

    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    try {
        [Net.ServicePointManager]::SecurityProtocol = `
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop

        # Decode UTF-8 explicitly rather than trusting the response header.
        $src = [System.Text.Encoding]::UTF8.GetString($resp.RawContentStream.ToArray())

        if ([string]::IsNullOrWhiteSpace($src)) { throw "Empty response body from $url" }

        # Reject unparseable content before it reaches Invoke-Expression.
        $parseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseInput(
            $src, [ref]$null, [ref]$parseErrors)

        if ($parseErrors -and $parseErrors.Count -gt 0) {
            throw "Module '$key' failed to parse: $($parseErrors[0].Message)"
        }

        $global:moduleCache[$key] = $src

        try {
            $utf8Bom = New-Object System.Text.UTF8Encoding($true)
            [System.IO.File]::WriteAllText($cachePath, $src, $utf8Bom)
        } catch {
            log -msg "Disk cache write failed for '$key': $($_.Exception.Message)" -lvl "WARNING"
        }

        log -msg "Module '$key' downloaded ($($src.Length) chars)." -lvl "DEBUG"
        return $src
    } catch {
        log -msg "Download of '$key' failed: $($_.Exception.Message)" -lvl "WARNING"
    } finally {
        $ProgressPreference = $oldProgress
    }

    if (Test-Path -LiteralPath $cachePath) {
        try {
            $src = [System.IO.File]::ReadAllText($cachePath)
            if (-not [string]::IsNullOrWhiteSpace($src)) {
                $global:moduleCache[$key] = $src
                $age = (Get-Date) - (Get-Item -LiteralPath $cachePath).LastWriteTime
                writeText -type "notice" -text "Offline - using cached '$key' from $([int]$age.TotalDays) day(s) ago."
                return $src
            }
        } catch {
            log -msg "Disk cache read failed for '$key': $($_.Exception.Message)" -lvl "ERROR"
        }
    }

    log -msg "Module '$key' unavailable from network and cache." -lvl "ERROR"
    return $null
}
function dispatchCommand {
    param (
        [Parameter(Mandatory)][array]$filteredCommand
    )

    $commandDirectory = $filteredCommand[0]
    $commandFile = $filteredCommand[1]
    $commandFunction = $filteredCommand[2]

    # Framework-resident command (empty directory/file): already defined.
    if ([string]::IsNullOrEmpty($commandFile)) {
        invokeScript -script $commandFunction
        return
    }

    # The framework itself is already loaded, so only the module is fetched.
    $src = getModuleSource -directory $commandDirectory -file $commandFile

    if ($null -eq $src) {
        writeText -type "error" -text "Could not load '$commandDirectory/$commandFile'. Check your connection."
        return
    }

    # Defines the module's functions in this scope. invokeScript is called
    # from here, so its scope chain reaches them.
    Invoke-Expression $src

    invokeScript -script $commandFunction
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
function writeText {
    param (
        [parameter(Mandatory = $false)]
        [string]$label = "",
        [parameter(Mandatory = $false)]
        [string]$text = "",
        [parameter(Mandatory = $false)]
        [string]$type = "plain",
        [parameter(Mandatory = $false)]
        [string]$Color = "Gray",
        [parameter(Mandatory = $false)]
        [switch]$lineBefore = $false, # Add a new line before output if specified
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false, # Add a new line after output if specified
        [parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary]$Table,
        [parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary]$List,
        [parameter(Mandatory = $false)]
        [string]$ListValue,
        [parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary]$oldData,
        [parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary]$newData
    )

    try {
        # Add a new line before output if specified
        if ($lineBefore) { Write-Host "" }

        # Format output based on the specified Type
        if ($type -eq "header") {
            Write-Host "#" -NoNewline -ForegroundColor "Cyan"
            Write-Host " $text " -ForegroundColor "Cyan"
            log -msg $text -lvl "INFO"
        }

        if ($type -eq "prompt") {
            Write-Host "?" -NoNewline -ForegroundColor "Yellow"
            Write-Host " $text" -ForegroundColor "Gray"
            log -msg "ShellCLI prompted: $text"
        }

        if ($type -eq 'success') { 
            Write-Host "$([char]0x2713) $text"  -ForegroundColor "Green"
            Write-Host "" -ForegroundColor "Cyan"
            log -msg $text -lvl "SUCCESS"
        }

        if ($type -eq 'error') { 
            Write-Host "X $text" -ForegroundColor "Red"
            Write-Host "" -ForegroundColor "Cyan"
            log -msg $text -lvl "ERROR"
        }

        if ($type -eq 'notice') { 
            Write-Host "! $text" -ForegroundColor "Yellow" 
            Write-Host "" -ForegroundColor "Cyan"
            log -msg $text -lvl "INFO"
        }

        if ($type -eq 'plain') {
            if ($label -ne "") { 
                if ($Color -eq "Cyan") {
                    $Color = 'Cyan'
                }
                Write-Host "$label`: " -NoNewline -ForegroundColor "Cyan"
                Write-Host "$text" -ForegroundColor $Color 
                if ($text -ne "") {
                    log -msg $text -lvl "INFO"
                }
            } else {
                Write-Host "$text" -ForegroundColor $Color 
                if ($text -ne "") {
                    log -msg $text -lvl "INFO"
                }
            }
        }

        if ($type -eq 'table') { 
            # Get a list of keys from the options dictionary
            $orderedKeys = $Table.Keys | ForEach-Object { $_ }

            # Find the length of the longest key for padding
            $longestKeyLength = ($orderedKeys | Measure-Object -Property Length -Maximum).Maximum

            # Display single option if only one exists
            if ($orderedKeys.Count -eq 1) {
                Write-Host "$($orderedKeys) $(" " * ($longestKeyLength - $orderedKeys.Length)) - $($Table[$orderedKeys])"
                log -msg "$($orderedKeys) - $($Table[$orderedKeys])" -lvl "INFO"
            } else {
                # Loop through each option and display with padding and color
                for ($i = 0; $i -lt $orderedKeys.Count; $i++) {
                    $key = $orderedKeys[$i]
                    $padding = " " * ($longestKeyLength - $key.Length)
                    Write-Host "$($key): $padding $($Table[$key])" -ForegroundColor $Color
                    log -msg "$($key): $padding $($Table[$key])" -lvl "INFO"
                }
            }
        }

        if ($type -eq 'list') { 
            # Get a list of keys from the options dictionary
            $orderedKeys = $List.Keys | ForEach-Object { $_ }
            # Find the length of the longest key for padding
            $longestKeyLength = ($orderedKeys | Measure-Object -Property Length -Maximum).Maximum

            # Display single option if only one exists
            if ($orderedKeys.Count -eq 1) {
                Write-Host " $($orderedKeys) $(" " * ($longestKeyLength - $orderedKeys.Length)) - $($List[$key][$ListValue])"
                log -msg "$($orderedKeys) - $($List[$key][$ListValue])" -lvl "INFO"
            } else {
                # Loop through each option and display with padding and color
                for ($i = 0; $i -lt $orderedKeys.Count; $i++) {
                    $key = $orderedKeys[$i]
                    $padding = " " * ($longestKeyLength - $key.Length)
                    Write-Host "$($key): $padding $($List[$key][$ListValue])" -ForegroundColor $Color
                    log -msg "$($key): $padding $($List[$key][$ListValue])" -lvl "INFO"
                }
            }
        }

        # Add a new line after output if specified
        if ($lineAfter) { Write-Host }
    } catch {
        Write-Host "  $($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -ForegroundColor "Red"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function readInput {
    param (
        [parameter(Mandatory = $false)]
        [string]$Value = "", # A pre-fill value so the user can hit enter without typing command and get the current value if there is one
        [parameter(Mandatory = $false)]
        [string]$prompt, # Provide a specific prompt in necessary
        [parameter(Mandatory = $false)]
        [regex]$Validate = $null,
        [parameter(Mandatory = $false)]
        [string[]]$validSet = $null, # Array of acceptable values; input must match one of these
        [parameter(Mandatory = $false)]
        [string]$ErrorMessage = "", # Provide an optional error message
        [parameter(Mandatory = $false)]
        [switch]$IsSecure = $false, # If prompting for a password
        [parameter(Mandatory = $false)]
        [switch]$CheckExistingUser = $false,
        [parameter(Mandatory = $false)]
        [switch]$lineBefore = $false, # Add a new line before prompt if specified
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false, # Add a new line after prompt if specified
        [parameter(Mandatory = $false)]
        [switch]$allowBlank = $false # Allow blank input
    )

    try {
        log -msg "Prompting host to input. ($prompt)"

        # Add a new line before prompt if specified
        if ($lineBefore) { Write-Host }

        # Get current cursor position
        $currPos = $host.UI.RawUI.CursorPosition

        # Write-Host " ? " -NoNewline -ForegroundColor "Cyan"
        Write-Host "  $prompt " -NoNewline

        if ($IsSecure) { 
            $userInput = Read-Host -AsSecureString 
        } else { 
            $userInput = Read-Host 
        }

        # Check for existing user if requested
        if ($CheckExistingUser) {
            $account = Get-LocalUser -Name $userInput -ErrorAction SilentlyContinue
            if ($null -ne $account) { $ErrorMessage = "An account with that name already exists." }
        }

        if ($allowBlank -eq $false) {
            if ($userInput -eq "" -or $userInput.Length -eq 0) { 
                writeText -type "notice" -text "Input was blank, exiting." 
                readCommand
            } 
        }

        # Validate user input against provided regular expression
        if ($userInput -notmatch $Validate) { 
            $ErrorMessage = "Invalid input. Please try again." 
        } 

        # Validate user input against provided array of acceptable values
        if ($null -ne $validSet -and $validSet.Count -gt 0) {
            $isMatch = $validSet -icontains $userInput
            if (-not $isMatch) {
                $ErrorMessage = "Invalid input. Please enter one of the following: $($validSet -join ', ')."
            }
        }

        # Display error message if encountered
        if ($ErrorMessage -ne "") {
            writeText -type "error" -text $ErrorMessage
            # Recursively call readInput if user exists
            if ($CheckExistingUser) { return readInput -prompt $prompt -Validate $Validate -CheckExistingUser } 

            # Otherwise, simply call again without CheckExistingUser
            else { return readInput -prompt $prompt -Validate $Validate }
        }

        # Use provided default value if user enters nothing for a non-secure input
        if ($userInput.Length -eq 0 -and $Value -ne "" -and !$IsSecure) { $userInput = $Value }

        # Reset cursor position
        [Console]::SetCursorPosition($currPos.X, $currPos.Y)
        
        # Write-Host " ? " -ForegroundColor "Cyan" -NoNewline
        if ($IsSecure -and ($userInput.Length -eq 0)) { 
            Write-Host "  $prompt                                                "
        } else { 
            Write-Host "  $prompt " -NoNewline
            Write-Host "$userInput                                             " -ForegroundColor "DarkGray"
        }

        # Add a new line after prompt if specified
        if ($lineAfter) { Write-Host "" }

        log -msg "Input accepted ($userInput)"
    
        # Return the validated user input
        return $userInput
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function readOption {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$options,
        [parameter(Mandatory = $false)]
        [string]$prompt, # Provide a specific prompt if necessary
        [parameter(Mandatory = $false)]
        [switch]$returnKey = $false,
        [parameter(Mandatory = $false)]
        [switch]$returnValue = $false,
        [parameter(Mandatory = $false)]
        [switch]$lineBefore = $false,
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false,
        [parameter(Mandatory = $false)]
        [int]$maxDescriptionLength = 100 # New parameter for max description length
    )

    try {
        log -msg "Prompting host to choose. ($prompt)"
        # Add a line break before the menu if lineBefore is specified
        if ($lineBefore) { Write-Host }

        Write-Host "?" -NoNewline -ForegroundColor "Yellow"
        Write-Host " $prompt " -ForegroundColor "Gray"

        # Initialize variables for user input handling
        $vkeycode = 0
        $pos = 0
        $oldPos = 0

        # Get a list of keys from the options dictionary
        $orderedKeys = $options.Keys | ForEach-Object { $_ }

        # Find the length of the longest key for padding
        $longestKeyLength = ($orderedKeys | ForEach-Object { "$_".Length } | Measure-Object -Maximum).Maximum

        # Helper function to truncate description with ellipsis
        function truncateDescription {
            param([string]$description)
            if ($description.Length -gt $maxDescriptionLength) {
                return $description.Substring(0, $maxDescriptionLength - 3) + "..."
            }
            return $description
        }

        # Display single option if only one exists
        if ($orderedKeys.Count -eq 1) {
            $truncatedDesc = truncateDescription -description $options[$orderedKeys]
            Write-Host "$([char]0x2192)" -ForegroundColor "Cyan" -NoNewline
            Write-Host " $($orderedKeys) $(" " * ($longestKeyLength - $orderedKeys.Length)) - $truncatedDesc" -ForegroundColor "White"
        } else {
            # Loop through each option and display with padding and color
            for ($i = 0; $i -lt $orderedKeys.Count; $i++) {
                $key = $orderedKeys[$i]
                $padding = " " * ($longestKeyLength - $key.Length)
                $truncatedDesc = truncateDescription -description $options[$key]
                if ($i -eq $pos) { 
                    Write-Host "$([char]0x2192)" -ForegroundColor "Cyan" -NoNewline  
                    Write-Host " $key $padding - $truncatedDesc" -ForegroundColor "White"
                } else { 
                    Write-Host "  $key $padding - $truncatedDesc" -ForegroundColor "Gray"
                }
            }
        }

        # Get the current cursor position
        $currPos = $host.UI.RawUI.CursorPosition

        # Loop for user input to select an option
        While ($vkeycode -ne 13) {
            $press = $host.ui.rawui.readkey("NoEcho, IncludeKeyDown")
            $vkeycode = $press.virtualkeycode
            if ($orderedKeys.Count -ne 1) { 
                $oldPos = $pos;
                if ($vkeycode -eq 38) { $pos-- }
                if ($vkeycode -eq 40) { $pos++ }
                if ($pos -lt 0) { $pos = 0 }
                if ($pos -ge $orderedKeys.Count) { $pos = $orderedKeys.Count - 1 }

                # Calculate positions for redrawing menu items
                $menuLen = $orderedKeys.Count
                $menuOldPos = New-Object System.Management.Automation.Host.Coordinates($currPos.X, ($currPos.Y - ($menuLen - $oldPos)))
                $menuNewPos = New-Object System.Management.Automation.Host.Coordinates($currPos.X, ($currPos.Y - ($menuLen - $pos)))
                $oldKey = $orderedKeys[$oldPos]
                $newKey = $orderedKeys[$pos]
            
                # Re-draw the previously selected and newly selected options
                $oldTruncatedDesc = truncateDescription -description $options[$orderedKeys[$oldPos]]
                $newTruncatedDesc = truncateDescription -description $options[$orderedKeys[$pos]]
                
                $host.UI.RawUI.CursorPosition = $menuOldPos
                Write-Host "  $($orderedKeys[$oldPos]) $(" " * ($longestKeyLength - $oldKey.Length)) - $oldTruncatedDesc" -ForegroundColor "Gray"
                $host.UI.RawUI.CursorPosition = $menuNewPos
                Write-Host "$([char]0x2192)" -ForegroundColor "Cyan" -NoNewline
                Write-Host " $($orderedKeys[$pos]) $(" " * ($longestKeyLength - $newKey.Length)) - $newTruncatedDesc" -ForegroundColor "White"
                $host.UI.RawUI.CursorPosition = $currPos
            }
        }

        # Add a line break after the menu if lineAfter is specified
        if ($lineAfter) { Write-Host }

        # Handle function return values (key, value, menu position) based on parameters
        if ($returnKey) { 
            if ($orderedKeys.Count -eq 1) { 
                log -msg "Returning the key of ($pos $orderedKeys[$($options[$orderedKeys[$pos]])])"
                return $orderedKeys 
            } else { 
                log -msg "Returning the key of ($pos $($orderedKeys[$pos])[$($options[$orderedKeys[$pos]])])"
                return $orderedKeys[$pos] 
            } 
        } 
        if ($returnValue) { 
            if ($orderedKeys.Count -eq 1) { 
                log -msg "Returning the value of ($pos $orderedKeys[$($options[$orderedKeys[$pos]])])"
                return $options[$pos] 
            } else { 
                log -msg "Returning the value of ($pos $($orderedKeys[$pos])[$($options[$orderedKeys[$pos]])])"
                return $options[$orderedKeys[$pos]] 
            } 
        } else { 
            log -msg "Returning the index of ($pos $($orderedKeys[$pos])[$($options[$orderedKeys[$pos]])])"
            return $pos 
        }
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function getDownload {
    param (
        [parameter(Mandatory)]
        [string]$url,
        [parameter(Mandatory)]
        [string]$target,
        [parameter(Mandatory = $false)]
        [string]$label = "",
        [parameter(Mandatory = $false)]
        [string]$failText = 'Download failed...',
        [parameter(Mandatory = $false)]
        [switch]$lineBefore = $false,
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false,
        [parameter(Mandatory = $false)]
        [switch]$hide = $false
    )
    Begin {       
        function showProgress {
            param (
                [parameter(Mandatory)]
                [Single]$totalValue,
                [parameter(Mandatory)]
                [Single]$currentValue,
                [parameter(Mandatory = $false)]
                [switch]$complete = $false
            )
            
            # calc %
            $barSize = 30
            $percent = $currentValue / $totalValue
            $percentComplete = $percent * 100
  
            # build progressbar with string function
            $curBarSize = $barSize * $percent
            $progbar = ""
            $progbar = $progbar.PadRight($curBarSize, [char]9608)
            $progbar = $progbar.PadRight($barSize, [char]9617)

            if ($complete) {
                Write-Host -NoNewLine "`r$progbar" -ForegroundColor "Gray"
            } else {
                Write-Host -NoNewLine "`r$progbar $($percentComplete.ToString("##0.00").PadLeft(6))%" -ForegroundColor "Gray"
            }         
        }
    }
    Process {        
        log -msg "Downloading file from $url to $target"

        $downloadComplete = $true 
        for ($retryCount = 1; $retryCount -le 2; $retryCount++) {
            try {
                $storeEAP = $ErrorActionPreference
                $ErrorActionPreference = 'Stop'
        
                # invoke request
                $request = [System.Net.HttpWebRequest]::Create($url)
                $response = $request.GetResponse()
  
                if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403 -or $response.StatusCode -eq 404) {
                    throw "Remote file either doesn't exist, is unauthorized, or is forbidden for '$url'."
                }
  
                if ($target -match '^\.\\') {
                    $target = Join-Path (Get-Location -PSProvider "FileSystem") ($target -Split '^\.')[1]
                }
            
                if ($target -and !(Split-Path $target)) {
                    $target = Join-Path (Get-Location -PSProvider "FileSystem") $target
                }

                if ($target) {
                    $fileDirectory = $([System.IO.Path]::GetDirectoryName($target))
                    if (!(Test-Path($fileDirectory))) {
                        [System.IO.Directory]::CreateDirectory($fileDirectory) | Out-Null
                    }
                }

                [long]$fullSize = $response.ContentLength
                $fullSizeMB = $fullSize / 1024 / 1024
  
                # define buffer
                [byte[]]$buffer = new-object byte[] 1048576
                [long]$total = [long]$count = 0
  
                # create reader / writer
                $reader = $response.GetResponseStream()
                $writer = new-object System.IO.FileStream $target, "Create"
                
                if ($lineBefore) { Write-Host }

                if (-not $hide -and $label -ne "") {
                    Write-Host " $text" -ForegroundColor "Yellow"
                }
                # start download
                $finalBarCount = 0 #Show final bar only one time
                do {
                    $count = $reader.Read($buffer, 0, $buffer.Length)
          
                    $writer.Write($buffer, 0, $count)
              
                    $total += $count
                    $totalMB = $total / 1024 / 1024
                    if (-not $hide) {
                        if ($fullSize -gt 0) {
                            showProgress -totalValue $fullSizeMB -currentValue $totalMB
                        }

                        if ($total -eq $fullSize -and $count -eq 0 -and $finalBarCount -eq 0) {
                            showProgress -totalValue $fullSizeMB -currentValue $totalMB -complete
                            $finalBarCount++
                        }
                    }
                } while ($count -gt 0)

                if (-not $hide) {
                    Write-Host
                }

                # Prevent the following output from appearing on the same line as the progress bar
                if ($lineAfter) { 
                    Write-Host
                }
                
                if ($downloadComplete) { 
                    return $true 
                } else { 
                    return $false 
                }
            } catch {
                $downloadComplete = $false
            
                if ($retryCount -lt 2) {
                    writeText -type "plain" -text "Retrying..."
                    Start-Sleep -Seconds 1
                } else {
                    writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
                    log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
                }
            } finally {
                # cleanup
                if ($reader) { $reader.Close() }
                if ($writer) { $writer.Flush(); $writer.Close() }
        
                $ErrorActionPreference = $storeEAP
                [GC]::Collect()
            } 
        }   
    }
}
function getUserData {
    param (
        [parameter(Mandatory = $true)]
        [string]$username
    )

    try {
        $user = Get-LocalUser -Name $username
        $groups = Get-LocalGroup | Where-Object { $user.SID -in ($_ | Get-LocalGroupMember | Select-Object -ExpandProperty "SID") } | Select-Object -ExpandProperty "Name"
        $userProfile = Get-CimInstance Win32_UserProfile -Filter "SID = '$($user.SID)'"
        $dir = $userProfile.LocalPath
        if ($null -ne $userProfile) { $dir = $userProfile.LocalPath } else { $dir = "Awaiting first sign in." }

        $source = Get-LocalUser -Name $username | Select-Object -ExpandProperty PrincipalSource

        $data = [ordered]@{
            "Name"   = "$username"
            "Groups" = "$($groups -join ';')"
            "Path"   = "$dir"
            "Source" = "$source"
        }

        return $data
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function selectUser {
    param (
        [parameter(Mandatory = $false)]
        [string]$prompt = "Select a user account:",
        [parameter(Mandatory = $false)]
        [switch]$lineBefore = $false,
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false,
        [parameter(Mandatory = $false)]
        [switch]$writeResult = $false
    )

    try {
        # Add a line break before the menu if lineBefore is specified
        if ($lineBefore) { Write-Host "" }
         
        # Initialize empty array to store user names
        $userNames = @()

        # Get all local users on the system
        $localUsers = Get-LocalUser

        # Define a list of accounts to exclude from selection
        $excludedAccounts = @("DefaultAccount", "WDAGUtilityAccount", "Guest", "defaultuser0")

        # Check if the "Administrator" account is disabled and add it to excluded list if so
        $adminEnabled = Get-LocalUser -Name "Administrator" | Select-Object -ExpandProperty Enabled
        if (!$adminEnabled) { $excludedAccounts += "Administrator" }

        # Filter local users to exclude predefined accounts
        foreach ($user in $localUsers) {
            if ($user.Name -notin $excludedAccounts) { $userNames += $user.Name }
        }

        # Create an ordered dictionary to store username and group information
        $accounts = [ordered]@{}
        
        # Get all local groups once (more efficient)
        $allGroups = Get-LocalGroup
        
        foreach ($name in $userNames) {
            # Get details for the current username
            $username = Get-LocalUser -Name $name
            
            $groupNames = @()
            
            # Check each group for membership with improved error handling
            foreach ($group in $allGroups) {
                try {
                    # Use SilentlyContinue to handle groups with domain members
                    $members = Get-LocalGroupMember -Group $group.Name -ErrorAction SilentlyContinue 2>$null
                    
                    # Only check membership if we got results
                    if ($members) {
                        # Check if the user's SID is in the group members
                        if ($username.SID -in ($members | Select-Object -ExpandProperty SID)) {
                            $groupNames += $group.Name
                        }
                    }
                } catch [System.ComponentModel.Win32Exception] {
                    # Handle error 1789 specifically (Domain unavailable)
                    if ($_.Exception.ErrorCode -eq 1789) {
                        # Domain is unavailable, skip this group
                        Write-Verbose "Domain unavailable, skipping group: $($group.Name)"
                        continue
                    }
                    # Handle other Win32 exceptions
                    log -msg "Win32 error checking group $($group.Name): $($_.Exception.Message)" -lvl "WARNING"
                    continue
                } catch {
                    # Handle any other errors
                    log -msg "Could not enumerate members for group: $($group.Name) - $($_.Exception.Message)" -lvl "WARNING"
                    continue
                }
            }
            
            # Convert groups to a semicolon-separated string
            $groupString = $groupNames -join ';'

            # Get the users source
            $source = Get-LocalUser -Name $username | Select-Object -ExpandProperty PrincipalSource

            # Add username and group string to the dictionary
            $accounts["$username"] = "$source | $groupString"
        }

        $accounts["Cancel"] = "Do not select a user and exit this function."

        # Prompt user to select a user from the list and return the key (username)
        $choice = readOption -options $accounts -prompt $prompt -returnKey

        if ($choice -eq "Cancel") {
            readCommand
        }

        # Get user data using the selected username
        $data = getUserData -Username $choice

        if ($writeResult) {
            Write-Host
            # Display user data as a list
            writeText -type "table" -Table $data -Color "Green"
        }

        # Add a line break after the menu if lineAfter is specified
        if ($lineAfter) { Write-Host "" }

        # Return the user data dictionary
        return $data
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function installEXE {
    param (
        [string]$Path, # Path to the .exe file
        [string]$exeArguments, # Arguments for the installer
        [bool]$Wait = $true # Whether to wait for the process to complete
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Path
    $startInfo.Arguments = $exeArguments
    $startInfo.UseShellExecute = $false  # Important for capturing exit codes
    $startInfo.CreateNoWindow = $true    # Run the installer in the background

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo

    try {
        $process.Start() | Out-Null
        if ($Wait) {
            $process.WaitForExit()
            return $process.ExitCode  # Return the exit code
        } else {
            writeText -type "plain" -text "Installation of '$Path' started in the background."
            return 0  # Return 0 if not waiting
        }
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
        return -1  # Return -1 to indicate a failure to start the process
    }
}
function installMSI {
    param (
        [string]$Path, # Path to the .msi file
        [string]$msiArguments # Additional arguments for the MSI installer
    )

    try {
        $process = Start-Process "msiexec.exe" -ArgumentList "/i `"$Path`" $msiArguments" -Wait -PassThru
        return $process.ExitCode  # Return the exit code
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
        return -1  # Return -1 to indicate a failure to start the process
    }
}
function installViaWinget {
    param(
        [string]$appName,
        [string]$wingetId
    )

    try {
        WriteText -Type "plain" -Text "Installing $appName via winget (ID: $wingetId)..."

        $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $wingetPath) {
            WriteText -Type "plain" -Text "winget not found. Installing winget..."
            
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction Stop | Out-Null
            Install-Script -Name winget-install -Force -ErrorAction Stop | Out-Null
                
            winget-install 2>&1 | Out-Null
                
            $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
            if (-not $wingetPath) {
                writeText -Type "error" -text "winget installation failed. Please install winget manually from https://github.com/microsoft/winget-cli"
            }
                
            WriteText -Type "success" -Text "winget installed successfully."
                
            # Need to refresh environment variables to see the new winget path
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")   
        }

        if (appInstalled -appName $appName) {
            WriteText -Type "plain" -Text "$appName is already installed."
        } else {
            # Update sources
            $null = Start-Process -FilePath "winget" -ArgumentList "source update" -Wait -WindowStyle Hidden

            $params = @(
                'install', "--id $wingetId",  # Fixed: $wingetId not $PackageId
                '--exact', '--silent',
                '--accept-package-agreements',
                '--accept-source-agreements',
                '--disable-interactivity'
            )
    
            $process = Start-Process -FilePath 'winget' -ArgumentList $params -Wait -PassThru -WindowStyle Hidden
    
            $success = $process.ExitCode -in @(0, -1978335189)
            WriteText -Type "plain" -Text "Winget exit code: $($process.ExitCode)"
    
            if ($success) {
                WriteText -Type "success" -Text "$appName installed successfully via winget."
            } else {
                WriteText -Type "error" -Text "Failed to install $appName via winget. Exit code: $($process.ExitCode)"
            }
        }
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }    
}
function resolveWinget {
    try {
        $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }

        $candidate = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" `
            -Filter "winget.exe" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.DirectoryName -like "*Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe*" } |
        Select-Object -Last 1

        if ($candidate) { return $candidate.FullName }
        return $null
    } catch {
        return $null
    }
}
function registerWingetForCurrentUser {
    <#
        Provisioning stages the package into the image, but the account running
        the script right now may not have it registered. This binds it without
        re-downloading anything.
    #>
    try {
        Add-AppxPackage -RegisterByFamilyName `
            -MainPackage "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe" `
            -ErrorAction Stop
    } catch {
        # Expected under SYSTEM, where there is no meaningful user context.
        log -msg "registerWingetForCurrentUser: $($_.Exception.Message)" -lvl "WARN"
    }
}
function installWingetForAllUsers {
    [CmdletBinding()]
    param(
        # Re-provision even if App Installer is already present.
        [switch]$Force
    )

    try {
        # Already there? ---------------------------------------------
        if (-not $Force) {
            $existing = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq 'Microsoft.DesktopAppInstaller' }

            if ($existing) {
                writeText -type "plain" -text "App Installer already provisioned (v$($existing.Version))." -lineAfter
                if (-not (resolveWinget)) { registerWingetForCurrentUser }
                return
            }
        }

        # Scratch space -------------------------------------------------
        $work = Join-Path $env:ProgramData "shellcli\wingetProvision"
        if (Test-Path $work) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Path $work -Force | Out-Null

        # Work out what to download --------------------------------------
        writeText -type "plain" -text "Querying latest winget-cli release..."

        $apiJson = Join-Path $work "release.json"
        if (-not (getDownload -url "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -target $apiJson)) {
            writeText -type "error" -text "Failed to query the winget-cli release feed."
            log -msg "installWingetForAllUsers: release feed download failed." -lvl "ERROR"
            return
        }

        try {
            $release = Get-Content -LiteralPath $apiJson -Raw | ConvertFrom-Json
        } catch {
            # Almost always a 403 from GitHub because no User-Agent header was sent.
            writeText -type "error" -text "Release feed did not return valid JSON. If getDownload uses WebClient or BITS, add a User-Agent header."
            log -msg "installWingetForAllUsers: release feed parse failed - $($_.Exception.Message)" -lvl "ERROR"
            return
        }

        if (-not $release.assets) {
            writeText -type "error" -text "Release feed contained no assets."
            return
        }

        $bundleAsset = $release.assets | Where-Object { $_.name -like "*.msixbundle" }   | Select-Object -First 1
        $licenseAsset = $release.assets | Where-Object { $_.name -like "*_License1.xml" } | Select-Object -First 1
        $depsAsset = $release.assets | Where-Object { $_.name -eq "DesktopAppInstaller_Dependencies.zip" } | Select-Object -First 1

        if (-not $bundleAsset -or -not $licenseAsset -or -not $depsAsset) {
            writeText -type "error" -text "Could not locate all required assets in release $($release.tag_name)."
            log -msg "installWingetForAllUsers: missing release assets in $($release.tag_name)." -lvl "ERROR"
            return
        }

        writeText -type "plain" -text "Found $($release.tag_name)."

        # --- 5. Download via getDownload ----------------------------------------
        $bundlePath = Join-Path $work $bundleAsset.name
        $licensePath = Join-Path $work $licenseAsset.name
        $depsZipPath = Join-Path $work $depsAsset.name

        $downloads = @(
            @{ Url = $bundleAsset.browser_download_url; Target = $bundlePath; Label = "App Installer bundle" },
            @{ Url = $licenseAsset.browser_download_url; Target = $licensePath; Label = "license file" },
            @{ Url = $depsAsset.browser_download_url; Target = $depsZipPath; Label = "dependency package" }
        )

        foreach ($item in $downloads) {
            if (-not (getDownload -url $item.Url -target $item.Target)) {
                writeText -type "error" -text "Failed to download the $($item.Label)."
                log -msg "installWingetForAllUsers: download failed - $($item.Url)" -lvl "ERROR"
                return
            }
            if (-not (Test-Path $item.Target)) {
                writeText -type "error" -text "getDownload reported success but $($item.Target) is missing."
                return
            }
        }

        # --- 6. Unpack the dependencies -------------------------------------------
        $depsDir = Join-Path $work "deps"
        Expand-Archive -LiteralPath $depsZipPath -DestinationPath $depsDir -Force

        # Zip layout is <arch>\<package>.appx - we only need the host arch.
        $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
        $dependencies = @(
            Get-ChildItem -Path (Join-Path $depsDir $arch) -Filter "*.appx" -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName
        )

        if ($dependencies.Count -eq 0) {
            writeText -type "notice" -text "No $arch dependency packages found; attempting provision without them."
        } else {
            writeText -type "plain" -text "Staging $($dependencies.Count) dependency package(s)."
        }

        # --- 7. Provision -------------------------------------------------------
        writeText -type "plain" -text "Provisioning App Installer for all users..."

        $provisionArgs = @{
            Online      = $true
            PackagePath = $bundlePath
            LicensePath = $licensePath
        }
        if ($dependencies.Count -gt 0) {
            $provisionArgs['DependencyPackagePath'] = $dependencies
        }

        Add-AppxProvisionedPackage @provisionArgs -ErrorAction Stop | Out-Null

        # --- 8. Register for the current account so winget works right now ------
        registerWingetForCurrentUser

        # --- 9. Verify -----------------------------------------------------------
        $exe = resolveWinget
        if ($exe) {
            $version = (& $exe --version) 2>$null
            writeText -type "success" -text "winget $version provisioned and available."
            log -msg "installWingetForAllUsers: provisioned $($release.tag_name)." -lvl "INFO"
        } else {
            writeText -type "notice" -text "Provisioning succeeded but winget is not resolvable in this session. It will be available to users at next sign-in."
            log -msg "installWingetForAllUsers: provisioned but not resolvable in current session." -lvl "WARN"
        }

        # --- 10. Clean up ----------------------------------------------------------
        Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $work) {
            writeText -type "error" -text "Some temp files were not deleted. This is harmless."
        }
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function installApp {
    param (
        [parameter(Mandatory = $true)]
        [string]$url,
        [parameter(Mandatory = $true)]
        [string]$appName,
        [parameter(Mandatory = $true)]
        [string]$params
    )

    try {
        writeText -Type "plain" -Text "Installing $appName..." -lineBefore
        if (appInstalled -appName $appName) {
            WriteText -Type "plain" -Text "$appName is already installed."
        } else {
            $fileName = Split-Path -Path $url -Leaf
            $outputPath = Join-Path -Path "$env:ProgramData\shellcli" -ChildPath $fileName

            if (getDownload -url $url -target $outputPath) {
                $fileExtension = [System.IO.Path]::GetExtension($outputPath).ToLower()
                switch ($fileExtension) {
                    ".exe" {
                        writeText -type "plain" -text "Running exe installer ($outputPath)."
                        $exitCode = installEXE -Path $outputPath -exeArguments $params -Wait $true
                        if ($exitCode -eq 0) {
                            writeText -type "success" -text "Installation of $appName completed successfully." -lineAfter
                        } else {
                            writeText -type "error" -text "Installation of $appName failed with exit code $exitCode."
                        }
                    }
                    ".msi" {
                        writeText -type "plain" -text "Running msi installer ($outputPath)."
                        $exitCode = installMSI -Path $outputPath -msiArguments $params
                        if ($exitCode -eq 0) {
                            writeText -type "success" -text "Installation of $appName completed successfully." -lineAfter
                        } else {
                            writeText -type "error" -text "Installation of $appName failed with exit code $exitCode."
                        }
                    }
                    default {
                        writeText -type "notice" -text "Unsupported file type: $fileExtension"
                    }
                }

                # Clean up the downloaded installer
                $timeout = 10  # Timeout in seconds
                $startTime = Get-Date

                while ((Test-Path $outputPath) -and ((Get-Date) - $startTime).TotalSeconds -lt $timeout) {
                    try {
                        Remove-Item -Path $outputPath -Force -ErrorAction Stop
                        break
                    } catch {
                        Start-Sleep -Seconds 1
                    }
                }

                if (Test-Path $outputPath) {
                    writeText -type "error" -text "Failed to remove installer."
                }
            }   
        }     
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function uninstallWin32App {
    param(
        [string]$AppName
    )

    try {
        writeText -type "plain" -text "Searching for $AppName"

        $found = $false
        $regPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )

        foreach ($regPath in $regPaths) {
            $apps = Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*$AppName*" }
            foreach ($app in $apps) {
                $found = $true
                writeText -type "plain" -text "Uninstalling $($app.DisplayName) v$($app.DisplayVersion)..."

                $cmd = if ($app.QuietUninstallString) { 
                    $app.QuietUninstallString 
                } elseif ($app.UninstallString) { 
                    $app.UninstallString 
                } else { 
                    $null 
                }

                if ($cmd) {
                    if ($cmd -match "msiexec") {
                        $cmd = $cmd -replace "/I", "/X"
                        if ($cmd -notmatch "/quiet|/qn|/qb") { $cmd += " /quiet /norestart" }
                    } elseif ($cmd -match "OfficeClickToRun|C2RClient|officec2rclient") {
                        if ($cmd -notmatch "DisplayLevel") { $cmd = $cmd.TrimEnd() + " DisplayLevel=False" }
                    }
                    try {
                        Start-Process -FilePath "cmd.exe" -ArgumentList "/c $cmd" -Wait -WindowStyle Hidden
                        writeText -type "success" -text "$($app.DisplayName) v$($app.DisplayVersion) uninstalled"
                    } catch {
                        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
                        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
                    }
                } else {
                    writeText -type "notice" -text "Uninstall failed. No uninstall string found."
                }
            }
        }
        if (-not $found) {
            writeText -type "plain" -text "$AppName not found"
        }
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function uninstallAppXApp {
    param(
        [string]$PackageName, 
        [string]$FriendlyName = $PackageName
    )

    writeText -type "plain" -text "Searching for AppX: $FriendlyName"
    $found = $false
    $installed = Get-AppxPackage -AllUsers -Name "*$PackageName*" -ErrorAction SilentlyContinue

    foreach ($app in $installed) {
        $found = $true
        writeText -type "plain" -text "Uninstalling $($app.Name)..."
        try {
            Remove-AppxPackage -Package $app.PackageFullName -AllUsers -ErrorAction Stop
            writeText -type "success" -text "$FriendlyName uninstalled successfully"
        } catch {
            writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
            log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
        }
    }

    $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$PackageName*" }
    
    foreach ($app in $provisioned) {
        $found = $true
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $app.PackageName -ErrorAction Stop
            writeText "$FriendlyName (Provisioned) removed successfully"
        } catch {
            writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
            log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
        }
    }
    if (-not $found) {
        writeText -type "plain" -text "$FriendlyName not found"
    }
}
function appInstalled {
    param([string]$appName)

    try {
        $pattern = [regex]::Escape($appName)

        $regPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )

        foreach ($path in $regPaths) {
            $apps = Get-ItemProperty $path -ErrorAction SilentlyContinue
            foreach ($app in $apps) {
                if ($app.DisplayName -and $app.DisplayName -match $pattern) {
                    return $true
                }
            }
        }

        # Windows Store apps must be actually registered to a user, not just have leftover metadata. Thanks Claude.
        $pkgs = Get-AppxPackage -Name "*$appName*" -ErrorAction SilentlyContinue
        foreach ($pkg in $pkgs) {
            if ($pkg.PackageUserInformation -and $pkg.PackageUserInformation.Count -gt 0) {
                return $true
            }
        }

        return $false
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
        return $false
    }
}
function formatSize {
    param([long]$Bytes)
    switch ($Bytes) {
        { $_ -ge 1TB } { "{0:N2} TB" -f ($_ / 1TB); break }
        { $_ -ge 1GB } { "{0:N2} GB" -f ($_ / 1GB); break }
        { $_ -ge 1MB } { "{0:N2} MB" -f ($_ / 1MB); break }
        { $_ -ge 1KB } { "{0:N2} KB" -f ($_ / 1KB); break }
        default { "{0} B" -f $_ }
    }
}
function getFolderSize {
    param([string]$Path)
    $size = (Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $size) { 
        $size = 0 
    }
    return $size
}
