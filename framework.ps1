$global:moduleCache = @{}
$global:commandMap = [ordered]@{}

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
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
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

    # Config problems found during init are shown here, after the banner,
    # because init's own output is wiped by the screen clear.
    foreach ($warning in $global:shellcliConfigWarnings) {
        writeText -type "notice" -text $warning
    }
    $global:shellcliConfigWarnings = @()

    while ($true) {
        try {
            $command = if ($pending) { $pending } else { promptForCommand }
            $pending = $null

            if ([string]::IsNullOrWhiteSpace($command)) { continue }

            $command = normalizeCommandName -text $command

            if ($command -in @('exit', 'quit')) {
                log -msg "Session ended by user." -lvl "INFO"
                break
            }

            runCommand -command $command
        } catch {
            # A failing command must not take the shell down with it.
            writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
            log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
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

    runCommand -command (normalizeCommandName -text $command)
}
function normalizeCommandName {
    <#
        The form commands are looked up by: lower case in the invariant
        culture (so a Turkish language setting cannot turn I into a dotless
        i), runs of whitespace collapsed to one space, and trimmed. Typed
        input and the names in config.json both go through this.
    #>
    param (
        [Parameter(Mandatory = $false)][string]$text
    )

    return (($text -replace '\s+', ' ').Trim().ToLowerInvariant())
}
function filterCommands {
    param (
        [Parameter(Mandatory = $false)][string]$command
    )

    try {
        $normalized = normalizeCommandName -text $command

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
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
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
function expandConfigPath {
    <#
        Turns a configured folder into a plain path: %rootDirectory% (any
        case) becomes $root, environment variables are expanded, and forward
        slashes are accepted so nobody has to double every backslash in JSON.
    #>
    param (
        [Parameter(Mandatory = $false)][string]$value,
        [Parameter(Mandatory = $false)][string]$root
    )

    $token = '%rootDirectory%'
    $at = $value.IndexOf($token, [System.StringComparison]::OrdinalIgnoreCase)
    while ($root -and $at -ge 0) {
        $value = $value.Substring(0, $at) + $root + $value.Substring($at + $token.Length)
        $at = $value.IndexOf($token, $at + $root.Length, [System.StringComparison]::OrdinalIgnoreCase)
    }

    return [Environment]::ExpandEnvironmentVariables($value.Trim()).Replace('/', '\')
}
function addConfigWarning {
    param (
        [Parameter(Mandatory)][string]$text
    )

    $global:shellcliConfigWarnings = @(@($global:shellcliConfigWarnings) | Where-Object { $_ }) + $text
}
function testConfigPath {
    <#
        Returns a short reason a configured folder can't be used, or $null if
        it is fine. $path has already been through expandConfigPath.
    #>
    param (
        [Parameter(Mandatory)][string]$key,
        [Parameter(Mandatory)][string]$path
    )

    if ($path -match '%') { return "contains an environment variable that is not defined" }
    if ($path -notmatch '^([A-Za-z]:\\|\\\\[^\\]+\\[^\\]+)') { return "is not a full path (use something like D:\ShellCLI)" }
    if ($path -match '[\[\]]') { return "contains [ or ], which are not supported in folder names" }

    foreach ($segment in $path.Split('\')) {
        if ($segment -and $segment -notin '.', '..' -and $segment -match '[ .]$') {
            return "has a folder name ending in a space or dot"
        }
        # CON, NUL, COM1 ... are devices, not folders (also with an extension: NUL.txt)
        if ($segment -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$') {
            return "has a folder name that Windows reserves for a device ($segment)"
        }
    }

    try {
        $full = [System.IO.Path]::GetFullPath($path).TrimEnd('\')
    } catch {
        return "is not a valid path"
    }

    if ($full -match '^[A-Za-z]:$') { return "is a drive root, not a folder" }

    # A drive letter this computer does not have (D: on a machine without one)
    if ($full -match '^[A-Za-z]:' -and -not (Test-Path -LiteralPath $full.Substring(0, 3))) {
        return "is on a drive that is not available"
    }

    # Expand 8.3 short names (C:\PROGRA~1) so they cannot get past the system
    # folder checks below. GetFullPath only does this for a path that exists,
    # so expand the part that does and keep the rest as written.
    if ($full -match '^[A-Za-z]:') {
        $existing = $full
        $rest = ''
        while ($existing -and -not (Test-Path -LiteralPath $existing)) {
            $rest = '\' + (Split-Path -Path $existing -Leaf) + $rest
            $existing = Split-Path -Path $existing -Parent
        }
        if ($existing) { $full = [System.IO.Path]::GetFullPath($existing).TrimEnd('\') + $rest }
    }

    if ($key -eq 'rootDirectory') {
        if ($full.StartsWith('\\')) { return "must be on a local drive, not a network share" }

        # ShellCLI rewrites the permissions of this folder, so refuse anything
        # inside a system location, and any system location or parent of one.
        $trees = @(
            $env:SystemRoot, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramW6432,
            (Join-Path -Path $env:SystemDrive -ChildPath 'Users')
        ) | Where-Object { $_ }
        $folders = @($env:ProgramData, $env:USERPROFILE, $env:PUBLIC) | Where-Object { $_ }

        foreach ($location in @($trees) + @($folders)) {
            $location = $location.TrimEnd('\')
            if ($location -ieq $full -or $location.StartsWith("$full\", [System.StringComparison]::OrdinalIgnoreCase)) {
                return "would change the permissions of '$location'"
            }
        }
        foreach ($location in $trees) {
            if ($full.StartsWith($location.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
                return "is inside the system folder '$location' (use a folder such as %ProgramData%\YourName or C:\YourName instead)"
            }
        }
    }

    return $null
}
function getConfiguredCommands {
    <#
        The commands of the "commands" section of config.json ($section, as
        parsed), as an ordered map of name -> directory, file, function and
        description. An entry looks like
        "add user": { "directory": "main", "file": "user", "function": "addUser", "description": "..." }
        Every entry is checked, because the function name ends up in
        Invoke-Expression and the directory and file names end up in a
        download URL. Each problem is added to $problems.
    #>
    param (
        [Parameter(Mandatory)]$section,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$problems
    )

    $map = [ordered]@{}

    # Names that would shadow the dictionary's own properties (a command called
    # "keys" would break the `commands` listing).
    $reserved = 'keys', 'values', 'count', 'item', 'isreadonly', 'isfixedsize', 'issynchronized', 'syncroot'

    # Plain, short text for use in a message, whatever the file contained.
    $show = { param($text) $t = ([string]$text) -replace '[^\x20-\x7e]', '?'; if ($t.Length -gt 40) { $t.Substring(0, 40) + '...' } else { $t } }

    $reported = 0
    foreach ($entry in $section.PSObject.Properties) {
        $name = normalizeCommandName -text ([string]$entry.Name)
        $item = $entry.Value
        $problem = $null

        # -cmatch with \A and \z: -match is case-insensitive (the Kelvin sign
        # would pass [a-z]) and '$' also matches before a trailing newline.
        if ($name.Length -eq 0 -or $name.Length -gt 60 -or $name -cnotmatch '\A[\x20-\x7e]+\z') {
            $problem = "has no usable name (1 to 60 plain ASCII characters)"
        } elseif ($name -in $reserved) {
            $problem = "uses a reserved name"
        } elseif ($map.Contains($name)) {
            $problem = "is listed twice"
        } elseif ($item -isnot [System.Management.Automation.PSCustomObject]) {
            $problem = "must be an object with directory, file, function and description"
        } else {
            $directory = [string]$item.directory
            $file = [string]$item.file
            $functionName = [string]$item.function
            $description = ([string]$item.description) -replace '[\x00-\x1f]', ' '
            if ($description.Length -gt 200) { $description = $description.Substring(0, 200) }

            if ($functionName -cnotmatch '\A[A-Za-z_][A-Za-z0-9_-]{0,127}\z') {
                $problem = "has an invalid function name '$(& $show $functionName)'"
            } elseif (($directory -or $file) -and ($directory -cnotmatch '\A[A-Za-z0-9_-]{1,64}\z' -or $file -cnotmatch '\A[A-Za-z0-9_-]{1,64}\z')) {
                $problem = "needs a directory and a file made only of letters, digits, - and _ (up to 64 characters)"
            }
        }

        if ($problem) {
            $reported++
            if ($reported -le 10) { $problems.Add("command '$(& $show $name)' $problem") }
            continue
        }

        $map[$name] = @($directory, $file, $functionName, $description)
    }

    if ($reported -gt 10) { $problems.Add("$($reported - 10) more commands have problems") }
    return $map
}
function loadShellcliConfig {
    <#
        Builds $global:shellcliConfig (full paths and the module download
        address) and $global:commandMap from the text of config.json.

        There are no defaults and no fallbacks. A config.json that is empty,
        could not be downloaded, is not valid JSON, lacks a setting or has a
        wrong one makes this throw one error that lists every problem found.
        Does not touch the disk: see ensureConfigFolder for that.
    #>
    param (
        [Parameter(Mandatory = $false)][string]$json
    )

    $global:shellcliConfig = $null

    if ([string]::IsNullOrWhiteSpace($json)) {
        throw "config.json is empty or could not be read."
    }

    try {
        # A BOM (Notepad adds one) would make ConvertFrom-Json fail.
        $parsed = $json.TrimStart([char]0xFEFF) | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "config.json is not valid JSON ($($_.Exception.Message))."
    }

    if ($null -eq $parsed -or $parsed -isnot [System.Management.Automation.PSCustomObject]) {
        throw "config.json must contain a JSON object."
    }

    $problems = [System.Collections.Generic.List[string]]::new()
    $resolved = [ordered]@{}

    $known = 'repository', 'branch', 'rootDirectory', 'logDirectory', 'downloadDirectory', 'commands'
    foreach ($name in $parsed.PSObject.Properties.Name) {
        if ($name -notin $known) { $problems.Add("unknown setting '$name'") }
    }

    # Folders. The root comes first because the others may refer to it.
    $root = $null
    foreach ($key in 'rootDirectory', 'logDirectory', 'downloadDirectory') {
        $property = $parsed.PSObject.Properties[$key]
        $value = if ($property) { $property.Value } else { $null }

        if ($null -eq $value -or ($value -is [string] -and [string]::IsNullOrWhiteSpace($value))) {
            $problems.Add("$key is missing")
        } elseif ($value -isnot [string]) {
            $problems.Add("$key must be text")
        } elseif ($key -ne 'rootDirectory' -and -not $root -and $value -match '(?i)%rootDirectory%') {
            # Refers to a root folder that is itself unusable, which is already reported.
        } else {
            $candidate = expandConfigPath -value $value -root $root
            $problem = testConfigPath -key $key -path $candidate
            if ($problem) {
                $problems.Add("$key '$value' $problem")
            } else {
                $resolved[$key] = $candidate.TrimEnd('\')
                if ($key -eq 'rootDirectory') { $root = $resolved[$key] }
            }
        }
    }

    # The module cache always lives under the root folder.
    if ($root) { $resolved['cacheDirectory'] = "$root\cache" }

    # Repository: where the modules are downloaded from
    $property = $parsed.PSObject.Properties['repository']
    $repository = if ($property) { $property.Value } else { $null }
    $property = $parsed.PSObject.Properties['branch']
    $branch = if ($property) { $property.Value } else { $null }

    if ($null -eq $repository -or ($repository -is [string] -and [string]::IsNullOrWhiteSpace($repository))) {
        $problems.Add("repository is missing")
    } elseif ($repository -isnot [string]) {
        $problems.Add("repository must be text")
    } elseif ($null -ne $branch -and $branch -isnot [string]) {
        $problems.Add("branch must be text")
    } else {
        $result = resolveRepositoryBase -repository $repository -branch ([string]$branch)
        if ($result.problem) {
            $problems.Add("repository '$repository' $($result.problem)")
        } else {
            $resolved['repositoryBase'] = $result.base
        }
    }

    # Commands
    $commands = $null
    $property = $parsed.PSObject.Properties['commands']
    if (-not $property -or $null -eq $property.Value) {
        $problems.Add("commands is missing")
    } elseif ($property.Value -isnot [System.Management.Automation.PSCustomObject]) {
        $problems.Add("commands must be an object with one entry per command")
    } elseif (@($property.Value.PSObject.Properties).Count -eq 0) {
        $problems.Add("commands is empty")
    } else {
        $commands = getConfiguredCommands -section $property.Value -problems $problems
    }

    if ($problems.Count -gt 0) {
        throw ("config.json cannot be used:`n" + (($problems | ForEach-Object { "  - $_" }) -join "`n"))
    }

    $global:shellcliConfig = $resolved
    $global:shellcliConfigWarnings = @()
    $global:commandMap = $commands
    $global:shellcliLogFailed = $false
}
function getConfigPath {
    <#
        Returns one of the configured folders as a full path:
        root, log, cache or download. Throws when config.json has not been
        loaded: there is no default.
    #>
    param (
        [Parameter(Mandatory)][ValidateSet('root', 'log', 'cache', 'download')][string]$name
    )

    if (-not $global:shellcliConfig) { throw "ShellCLI's config.json has not been loaded." }

    return $global:shellcliConfig["${name}Directory"]
}
function testConfigFolder {
    <#
        Creates the folder if needed and proves it can be written to.
        Returns $null when it is usable, otherwise a short reason.
    #>
    param (
        [Parameter(Mandatory)][string]$path
    )

    try {
        if (-not (Test-Path -LiteralPath $path -PathType Container)) {
            $null = New-Item -Path $path -ItemType Directory -Force -ErrorAction Stop
        }

        # New-Item reports success without creating anything when a parent is a file.
        if (-not (Test-Path -LiteralPath $path -PathType Container)) { return "could not be created" }

        $probe = Join-Path -Path $path -ChildPath ('.write-test-' + [guid]::NewGuid().ToString('N'))
        [System.IO.File]::WriteAllText($probe, 'x')

        # A folder that lets files be created but not deleted is still usable.
        try { [System.IO.File]::Delete($probe) } catch { }
        return $null
    } catch {
        return "cannot be used ($($_.Exception.Message))"
    }
}
function ensureConfigFolder {
    <#
        Makes sure a configured folder exists and can be written to. Throws
        when it cannot: the setting is not replaced by anything else.
    #>
    param (
        [Parameter(Mandatory)][ValidateSet('rootDirectory', 'logDirectory', 'downloadDirectory')][string]$key
    )

    if (-not $global:shellcliConfig) { throw "ShellCLI's config.json has not been loaded." }

    $path = $global:shellcliConfig[$key]
    $problem = testConfigFolder -path $path
    if ($problem) { throw "config.json: $key '$path' $problem." }
}
function resolveRepositoryBase {
    <#
        Turns the repository and branch settings of config.json into the
        address the repo's files are downloaded from. Returns an object with
        a base (or $null) and a problem (or $null).

        A GitHub link such as https://github.com/owner/repo needs a branch
        (a branch, tag or commit) and becomes
        https://raw.githubusercontent.com/owner/repo/<branch>. Any other https
        address is used as it is and must not come with a branch: files are
        expected at <address>/framework.ps1, <address>/main/user.ps1 and so
        on. Plain http is refused because what is downloaded runs as
        administrator.
    #>
    param (
        [Parameter(Mandatory)][string]$repository,
        [Parameter(Mandatory = $false)][string]$branch
    )

    $repository = $repository.Trim().TrimEnd('/')
    $branch = $branch.Trim()

    if ($repository -notmatch '^https://[^\s/@?#]+(/[^\s?#]*)?$') {
        return [pscustomobject]@{ base = $null; problem = "must be an https address such as https://github.com/owner/repo" }
    }

    if ($repository -match '^https://(www\.)?github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+?)(\.git)?$') {
        $owner = $Matches[2]
        $name = $Matches[3]

        if ($owner -match '^\.+$' -or $name -match '^\.+$') {
            return [pscustomobject]@{ base = $null; problem = "is not a valid repository link" }
        }
        if (-not $branch) {
            return [pscustomobject]@{ base = $null; problem = "needs a branch, tag or commit: add a branch setting such as ""branch"": ""main""" }
        }
        if ($branch -notmatch '^[A-Za-z0-9._][A-Za-z0-9._/-]*$' -or $branch -match '\.\.|//|/$|/\./|\.$') {
            return [pscustomobject]@{ base = $null; problem = "has a branch ('$branch') that is not a valid branch, tag or commit name" }
        }

        return [pscustomobject]@{ base = "https://raw.githubusercontent.com/$owner/$name/$branch"; problem = $null }
    }

    if ($repository -match '^https://(www\.)?github\.com(/|$)') {
        return [pscustomobject]@{ base = $null; problem = "must be the plain repository link, https://github.com/owner/repo" }
    }

    # Any other address is used as written, so keep it simple and unambiguous:
    # no dot segments, percent-encoding or backslashes to disguise another path.
    if ($repository -match '\.\.|%|\\') {
        return [pscustomobject]@{ base = $null; problem = "must not contain '..', '%' or '\'" }
    }
    if ($branch) {
        return [pscustomobject]@{ base = $null; problem = "comes with a branch, but a branch only applies to GitHub links: put it in the address instead" }
    }

    return [pscustomobject]@{ base = $repository; problem = $null }
}
function getRepositoryIdentity {
    <#
        A short, comparable name for a repository address, so a GitHub link,
        the raw address of the same repository and other branches of it all
        count as the same repository.
    #>
    param (
        [Parameter(Mandatory)][string]$url
    )

    $address = $url.Trim().TrimEnd('/').ToLowerInvariant()
    if ($address -match '^https://raw\.githubusercontent\.com/([^/]+)/([^/]+)') {
        return "github:$($Matches[1])/$($Matches[2])"
    }

    return $address
}
function getModuleBase {
    <#
        The address module files are downloaded from: the repository in
        config.json. $null when config.json has not been loaded.
    #>
    if (-not $global:shellcliConfig) { return $null }

    return $global:shellcliConfig['repositoryBase']
}
function getModuleCachePath {
    param (
        [Parameter(Mandatory)][string]$key,
        [Parameter(Mandatory = $false)][string]$base
    )

    # Cached modules are kept per repository, so two ShellCLI variants that
    # share a root folder (say a personal one and a work one) can never hand
    # each other's code to the offline fallback.
    if (-not $base) { $base = getModuleBase }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("$base".ToLowerInvariant()))
    } finally {
        $sha.Dispose()
    }
    $repoFolder = -join ($bytes[0..3] | ForEach-Object { $_.ToString('x2') })

    $cacheDir = Join-Path -Path (getConfigPath -name cache) -ChildPath $repoFolder
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

    if ($global:shellcliDevRoot) {
        $rel = if ($directory) { "$directory\$file.ps1" } else { "$file.ps1" }
        $path = Join-Path $global:shellcliDevRoot $rel
        if (-not (Test-Path -LiteralPath $path)) {
            writeText -type "error" -text "DEV: $rel not found at $path"
            return $null
        }
        # No memory or disk cache in dev, so edits take effect on the next command.
        return [System.IO.File]::ReadAllText($path)
    }

    if ($global:moduleCache.ContainsKey($key)) {
        log -msg "Module '$key' served from memory." -lvl "DEBUG"
        return $global:moduleCache[$key]
    }

    $base = getModuleBase
    if (-not $base) {
        log -msg "Module '$key' cannot be downloaded: config.json has not been loaded, so there is no repository address." -lvl "ERROR"
        writeText -type "error" -text "config.json has not been loaded, so '$key' cannot be downloaded."
        return $null
    }

    $url = if ($directory) { "$base/$directory/$file.ps1" } else { "$base/$file.ps1" }
    $cachePath = getModuleCachePath -key $key -base $base

    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    try {
        [Net.ServicePointManager]::SecurityProtocol = `
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

        # Windows PowerShell 5.1 does not ask for compression by itself. With
        # the header GitHub sends gzip (~75% smaller) and the body still comes
        # back decoded, so RawContentStream below is plain UTF-8 text.
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop `
            -Headers @{ 'Accept-Encoding' = 'gzip' }

        # Decode UTF-8 explicitly rather than trusting the response header.
        $src = [System.Text.Encoding]::UTF8.GetString($resp.RawContentStream.ToArray()).TrimStart([char]0xFEFF)

        # Reject anything that is not a module before it reaches Invoke-Expression
        # or overwrites the last good copy on disk.
        $problem = testModuleSource -src $src
        if ($problem) { throw "Module '$key' $problem" }

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
        $status = $null
        try { $status = [int]$_.Exception.Response.StatusCode } catch { }

        log -msg "Download of '$key' failed: $($_.Exception.Message)" -lvl "WARNING"

        if ($status -eq 404) {
            # The server answered, so the module is simply not there: cached code
            # from an earlier version must not stand in for it.
            log -msg "Module '$key' was not found (404) at $url." -lvl "ERROR"
            writeText -type "error" -text "'$key' was not found at $url. Check directory, file and repository in config.json."
            return $null
        }
    } finally {
        $ProgressPreference = $oldProgress
    }

    if (Test-Path -LiteralPath $cachePath) {
        try {
            $src = [System.IO.File]::ReadAllText($cachePath).TrimStart([char]0xFEFF)

            # A half-written or damaged cache file must not reach Invoke-Expression.
            $problem = testModuleSource -src $src
            if ($problem) {
                log -msg "Disk cache for '$key' was ignored: it $problem" -lvl "WARNING"
            } else {
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
    writeText -type "error" -text "Could not download '$key'. Check your connection."
    return $null
}
function testModuleSource {
    <#
        Returns $null when $src looks like a ShellCLI module, otherwise a short
        reason it does not. A module must parse and define at least one
        function: an HTML or plain-text error page can parse as a script.
    #>
    param (
        [Parameter(Mandatory = $false)][string]$src
    )

    if ([string]::IsNullOrWhiteSpace($src)) { return "is empty" }

    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($src, [ref]$null, [ref]$parseErrors)
    if ($parseErrors -and $parseErrors.Count -gt 0) { return "does not parse ($($parseErrors[0].Message))" }

    $functions = @($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false))
    if ($functions.Count -eq 0) { return "defines no functions (an error page?)" }

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
        if (-not (testCommandFunction -name $commandFunction -where "the framework")) { return }
        invokeScript -script $commandFunction
        return
    }

    # The framework itself is already loaded, so only the module is fetched.
    $src = getModuleSource -directory $commandDirectory -file $commandFile

    if ($null -eq $src) {
        writeText -type "error" -text "Could not load '$commandDirectory/$commandFile'."
        return
    }

    # Defines the module's functions in this scope. invokeScript is called
    # from here, so its scope chain reaches them.
    Invoke-Expression $src

    if (-not (testCommandFunction -name $commandFunction -where "$commandDirectory/$commandFile")) { return }

    invokeScript -script $commandFunction
}
function testCommandFunction {
    <#
        True when $name is a function that is defined right now. Commands may
        only run functions: a config.json entry naming a cmdlet, alias or
        program would otherwise be handed to Invoke-Expression, and a typo or a
        deleted function gets a clear message instead of a PowerShell error.
    #>
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)][string]$name,
        [Parameter(Mandatory)][string]$where
    )

    if (Get-Command -Name $name -CommandType Function -ErrorAction SilentlyContinue) { return $true }

    writeText -type "error" -text "There is no function '$name' in $where. Check this command's entry in config.json."
    log -msg "Command function '$name' is not defined in $where." -lvl "ERROR"
    return $false
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
        # One failure switches logging off for the rest of the session, so an
        # unusable log folder gives one error instead of one per line of output.
        if ($global:shellcliLogFailed) { return }

        # Before config.json is loaded there is no log folder, and none is invented.
        if (-not $global:shellcliConfig) { return }

        # Define log directory
        $logDirectory = getConfigPath -name log

        # Create log directory if it doesn't exist
        if (-not (Test-Path -LiteralPath $logDirectory)) {
            try {
                New-Item -Path $logDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
            } catch {
                $global:shellcliLogFailed = $true
                Write-Error "Failed to create log directory (logging is off for this session): $_"
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

        # Write to log file. Once more after a moment if that fails: a virus
        # scan or a reader can hold the file for a split second.
        try {
            Add-Content -LiteralPath $logFilePath -Value $logEntry -ErrorAction Stop
        } catch {
            Start-Sleep -Milliseconds 150
            Add-Content -LiteralPath $logFilePath -Value $logEntry -ErrorAction Stop
        }
    } catch {
        $global:shellcliLogFailed = $true
        Write-Error "Failed to write log entry (logging is off for this session): $_"
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
            if (-not $List -or $List.Count -eq 0) {
                Write-Host "None" -ForegroundColor $Color
                log -msg "No errors recorded." -lvl "INFO"
            } else {
                $orderedKeys = @($List.Keys)
                $longestKeyLength = ($orderedKeys | Measure-Object -Property Length -Maximum).Maximum

                foreach ($key in $orderedKeys) {
                    $padding = " " * ($longestKeyLength - $key.Length)
                    $value = $List[$key]
                    if ($ListValue -and $value -is [System.Collections.IDictionary]) {
                        $value = $value[$ListValue]
                    }
                    Write-Host "$($key): $padding $value" -ForegroundColor $Color
                    log -msg "$($key): $padding $value" -lvl "INFO"
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
                return
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
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
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
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
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
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
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
            return
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
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function getDownload {
    param (
        [parameter(Mandatory)]
        [string]$url,
        # A full file path, or a folder (existing, or ending in '\' or '/') to keep the
        # remote filename. Omit to save into the configured download folder
        # (downloadDirectory in config.json) with the remote filename.
        [parameter(Mandatory = $false)]
        [string]$target = "",
        # Return the saved file's full path on success instead of $true
        [parameter(Mandatory = $false)]
        [switch]$passThru = $false,
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
        function getRemoteFileName {
            param (
                [parameter(Mandatory)]
                [System.Net.WebResponse]$response
            )

            $name = $null

            # 1. Content-Disposition header (prefer RFC 5987 filename*= over filename=)
            $disposition = $response.Headers['Content-Disposition']
            if ($disposition) {
                if ($disposition -match "filename\*\s*=\s*(?:[\w-]+'[\w-]*')?`"?([^`";]+)`"?") {
                    $name = [Uri]::UnescapeDataString($Matches[1].Trim())
                } elseif ($disposition -match 'filename\s*=\s*"?([^";]+)"?') {
                    $name = $Matches[1].Trim()
                }
            }

            # 2. Last segment of the final URL (ResponseUri reflects redirects)
            if (-not $name) {
                $name = [Uri]::UnescapeDataString([System.IO.Path]::GetFileName($response.ResponseUri.AbsolutePath))
            }

            # Never trust a server-supplied name: strip any directory parts (blocks
            # "..\..\evil.exe") and characters Windows doesn't allow in filenames
            if ($name) {
                $name = [System.IO.Path]::GetFileName(($name -replace '/', '\'))
                $invalid = [regex]::Escape( -join [System.IO.Path]::GetInvalidFileNameChars())
                $name = ($name -replace "[$invalid]", '_').Trim(' ', '.')
            }

            if (-not $name) { $name = 'download' }
            return $name
        }

        function showProgress {
            param (
                [parameter(Mandatory)]
                [Single]$totalValue,
                [parameter(Mandatory)]
                [Single]$currentValue,
                [parameter(Mandatory = $false)]
                [switch]$complete = $false
            )

            $barSize = 30
            $percent = if ($totalValue -gt 0) { $currentValue / $totalValue } else { 0 }
            # Clamp in case the server's Content-Length is wrong
            $percent = [Math]::Max(0, [Math]::Min(1, $percent))
            $percentComplete = $percent * 100

            $curBarSize = [int][Math]::Floor($barSize * $percent)
            $progbar = "".PadRight($curBarSize, [char]9608).PadRight($barSize, [char]9617)

            if ($complete) {
                # Trailing spaces overwrite the " 100.00%" left over from the previous draw
                Write-Host -NoNewLine "`r$progbar        " -ForegroundColor "Gray"
            } else {
                Write-Host -NoNewLine "`r$progbar $($percentComplete.ToString("##0.00").PadLeft(6))%" -ForegroundColor "Gray"
            }
        }
    }
    Process {
        # No target given: the configured download folder, remote filename kept
        if ($target -eq "") { $target = "$(getConfigPath -name download)\" }

        # $null = ... keeps helper output from polluting the function's return value
        $null = log -msg "Downloading file from $url to $target"

        # Resolve the target once, against PowerShell's current location (not the .NET
        # process directory). Handles "file.zip", ".\file.zip", "sub\file.zip", "..\file.zip".
        # A folder target means "keep the remote filename"; the name is picked per attempt
        # once the response headers are available.
        $outFile = $null
        try {
            $targetIsFolder = $target -match '[\\/]$'
            $target = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($target)
            if (Test-Path -LiteralPath $target -PathType Container) { $targetIsFolder = $true }

            $fileDirectory = if ($targetIsFolder) { $target } else { [System.IO.Path]::GetDirectoryName($target) }
            if ($fileDirectory -and -not (Test-Path -LiteralPath $fileDirectory)) {
                [System.IO.Directory]::CreateDirectory($fileDirectory) | Out-Null
            }
        } catch {
            $null = writeText -type "error" -text $failText
            $null = log -msg "$($MyInvocation.MyCommand.Name): invalid target '$target': $($_.Exception.Message)" -lvl "ERROR"
            return $false
        }

        # Must be set before the request is created
        [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

        $maxAttempts = 2

        for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
            # Initialize in this scope so 'finally' never touches a caller's variables
            $reader = $null
            $writer = $null
            $response = $null
            $success = $false
            $retryable = $true
            $progressDrawn = $false
            $errorMessage = $null
            $errorLine = $null

            $storeEAP = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Stop'

                $request = [System.Net.HttpWebRequest]::Create($url)
                $request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) NuviaOnboarding/1.0"
                $request.Timeout = 60000
                $request.ReadWriteTimeout = 300000

                # Throws WebException for any non-2xx status (handled below)
                $response = $request.GetResponse()

                [long]$fullSize = $response.ContentLength   # -1 if the server didn't send it
                $fullSizeMB = $fullSize / 1024 / 1024

                [byte[]]$buffer = New-Object byte[] 1048576
                [long]$total = 0
                [int]$count = 0

                $outFile = if ($targetIsFolder) {
                    Join-Path $target (getRemoteFileName -response $response)
                } else {
                    $target
                }

                $reader = $response.GetResponseStream()
                $writer = [System.IO.FileStream]::new($outFile, [System.IO.FileMode]::Create)

                # Only print the header on the first attempt
                if ($attempt -eq 1) {
                    if ($lineBefore) { Write-Host }
                    if (-not $hide -and $label -ne "") {
                        Write-Host " $label" -ForegroundColor "Yellow"
                    }
                }

                do {
                    $count = $reader.Read($buffer, 0, $buffer.Length)
                    if ($count -gt 0) {
                        $writer.Write($buffer, 0, $count)
                        $total += $count

                        if (-not $hide -and $fullSize -gt 0) {
                            showProgress -totalValue $fullSizeMB -currentValue ($total / 1024 / 1024)
                            $progressDrawn = $true
                        }
                    }
                } while ($count -gt 0)

                # A dropped connection often just ends the stream early; don't call that success
                if ($fullSize -gt 0 -and $total -ne $fullSize) {
                    throw "Incomplete download: received $total of $fullSize bytes."
                }

                if (-not $hide -and $fullSize -gt 0) {
                    showProgress -totalValue $fullSizeMB -currentValue $fullSizeMB -complete
                    $progressDrawn = $true
                }

                $success = $true
            } catch [System.Net.WebException] {
                $errorMessage = $_.Exception.Message
                $errorLine = $_.InvocationInfo.ScriptLineNumber

                $webResponse = $_.Exception.Response
                if ($webResponse) {
                    $statusCode = [int]$webResponse.StatusCode
                    if ($statusCode -in 401, 403, 404) {
                        # Permanent errors: retrying won't help
                        $retryable = $false
                        $errorMessage = "Remote file either doesn't exist, is unauthorized, or is forbidden (HTTP $statusCode) for '$url'."
                    }
                    $webResponse.Close()
                }
            } catch {
                $errorMessage = $_.Exception.Message
                $errorLine = $_.InvocationInfo.ScriptLineNumber
            } finally {
                if ($reader) { $reader.Close() }
                if ($writer) { $writer.Flush(); $writer.Close() }
                if ($response) { $response.Close() }
                $ErrorActionPreference = $storeEAP
            }

            # End the progress-bar line so following output starts on a fresh line
            if ($progressDrawn) { Write-Host }

            if ($success) {
                if ($lineAfter) { Write-Host }
                $null = log -msg "Download complete: $outFile ($total bytes)"
                if ($passThru) { return $outFile }
                return $true
            }

            if ($attempt -lt $maxAttempts -and $retryable) {
                $null = log -msg "$($MyInvocation.MyCommand.Name)-$($errorLine): attempt $attempt failed: $errorMessage" -lvl "WARNING"
                $null = writeText -type "plain" -text "Retrying..."
                Start-Sleep -Seconds 1
                continue
            }

            $null = writeText -type "error" -text "$failText ($($MyInvocation.MyCommand.Name)-$errorLine)"
            $null = log -msg "$($MyInvocation.MyCommand.Name)-$($errorLine): $errorMessage" -lvl "ERROR"
            break
        }

        # Don't leave a partial/corrupt file behind for later checks to mistake as valid
        if ($outFile -and (Test-Path -LiteralPath $outFile -PathType Leaf)) {
            Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue
        }

        return $false
    }
}
function waitForProcess {
    param (
        [parameter(Mandatory)][System.Diagnostics.Process]$process,
        [string]$label = "Installing"
    )

    $frames = '|', '/', '-', '\'
    $i = 0
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $lastLength = 0

    # WaitForExit(250) returns $false while the process is still running
    while (-not $process.WaitForExit(250)) {
        $line = " $($frames[$i % $frames.Count]) $label... $($timer.Elapsed.ToString('mm\:ss'))"
        Write-Host -NoNewline "`r$line" -ForegroundColor "Gray"
        $lastLength = $line.Length
        $i++
    }

    # Call again with no timeout so the process state is fully settled
    $process.WaitForExit()

    # Erase the spinner line so the next message starts cleanly
    if ($lastLength -gt 0) {
        Write-Host -NoNewline ("`r" + (' ' * $lastLength) + "`r")
    }
}
function installEXE {
    param (
        [string]$Path, # Path to the .exe file
        [string]$exeArguments, # Arguments for the installer
        [bool]$Wait = $true, # Whether to wait for the process to complete
        [string]$label = "Installing" # Text shown next to the spinner
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
            waitForProcess -process $process -label $label
            return $process.ExitCode
        } else {
            $null = writeText -type "plain" -text "Installation of '$Path' started in the background."
            return 0
        }
    } catch {
        $null = writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
        return -1
    }
}
function installMSI {
    param (
        [string]$Path, # Path to the .msi file
        [string]$msiArguments, # Additional arguments for the MSI installer
        [string]$label = "Installing" # Text shown next to the spinner
    )

    try {
        # No -Wait: waitForProcess does the waiting so it can draw the spinner
        $process = Start-Process "msiexec.exe" -ArgumentList "/i `"$Path`" $msiArguments" -PassThru

        # Known quirk: without touching Handle right away, ExitCode can come back
        # empty for processes started with Start-Process -PassThru
        $null = $process.Handle

        waitForProcess -process $process -label $label
        return $process.ExitCode
    } catch {
        $null = writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
        return -1
    }
}
function installApp {
    param (
        [parameter(Mandatory = $true)][string]$url,
        [parameter(Mandatory = $true)][string]$appName,
        [parameter(Mandatory = $false)][string]$fileName,
        [parameter(Mandatory = $false)][string]$params = "",
        # Where the installer is downloaded; defaults to downloadDirectory in config.json
        [parameter(Mandatory = $false)][string]$outputPath = ""
    )

    if ([string]::IsNullOrWhiteSpace($outputPath)) { $outputPath = getConfigPath -name download }

    # Every run downloads into a folder of its own and deletes only that folder
    # afterwards. The installer's name comes from the server, so downloading
    # straight into a shared folder could overwrite, then delete, someone's file.
    $scratch = Join-Path -Path $outputPath -ChildPath ('install-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $outputPath = $scratch

    # Exit codes that mean the install worked: 0 = success,
    # 1641 = success and a reboot was initiated, 3010 = success, reboot required
    $successCodes = @(0, 1641, 3010)
    $rebootCodes = @(1641, 3010)

    $installerPath = $null

    try {
        # $null = ... everywhere keeps helper output out of this function's output
        $null = writeText -Type "plain" -Text "Installing $appName..." -lineBefore

        # Select-Object -Last 1 guards against helpers that write extra output to the pipeline
        if ((appInstalled -appName $appName | Select-Object -Last 1) -eq $true) {
            $null = writeText -Type "plain" -Text "$appName is already installed."
            return
        }

        # Download: use the given name, or let the server's filename decide
        if ($fileName) {
            $installerPath = Join-Path -Path $outputPath -ChildPath $fileName
            if (-not (getDownload -url $url -target $installerPath)) {
                throw "Download failed from $url."
            }
        } else {
            $installerPath = getDownload -url $url -target "$outputPath\" -passThru | Select-Object -Last 1
            if ($installerPath -isnot [string]) {
                $installerPath = $null
                throw "Download failed from $url."
            }
        }

        # Detect the real type from the file signature. EXE = 'MZ';
        # MSI = OLE compound document D0 CF 11 E0 A1 B1 1A E1.
        $header = [byte[]]::new(8)
        $stream = [System.IO.File]::OpenRead($installerPath)
        try { $bytesRead = $stream.Read($header, 0, $header.Length) } finally { $stream.Close() }

        $detected = if ($bytesRead -ge 2 -and $header[0] -eq 0x4D -and $header[1] -eq 0x5A) { ".exe" }
        elseif ($bytesRead -ge 8 -and ( -join ($header | ForEach-Object { $_.ToString('X2') })) -eq 'D0CF11E0A1B11AE1') { ".msi" }

        if (-not $detected) {
            $sizeKB = [math]::Round((Get-Item -LiteralPath $installerPath).Length / 1KB)
            throw "$appName download ($sizeKB KB) is not a valid .exe or .msi file - likely an error page."
        }

        $fileExtension = [System.IO.Path]::GetExtension($installerPath).ToLower()
        if ($fileExtension -and $fileExtension -ne $detected) {
            if ($fileName) { throw "'$fileName' is actually a $detected file." }
        }

        # Make sure the extension matches the content (msiexec/CreateProcess are happier)
        if ($fileExtension -ne $detected) {
            $newPath = "$installerPath$detected"
            Move-Item -LiteralPath $installerPath -Destination $newPath -Force
            $installerPath = $newPath
        }
        $fileExtension = $detected

        # Messages are written before the switch so they can't end up in $exitCode
        $null = writeText -type "plain" -text "Running $($fileExtension.TrimStart('.')) installer ($installerPath)."

        $exitCode = switch ($fileExtension) {
            ".exe" { installEXE -Path $installerPath -exeArguments $params -Wait $true | Select-Object -Last 1 }
            ".msi" { installMSI -Path $installerPath -msiArguments $params | Select-Object -Last 1 }
        }

        if ($null -eq $exitCode -or $exitCode -isnot [int]) {
            throw "Installer for $appName returned no usable exit code ('$exitCode')."
        }

        if ($exitCode -notin $successCodes) {
            throw "Installation of $appName failed with exit code $exitCode."
        }

        $note = if ($exitCode -in $rebootCodes) { " (reboot pending)" } else { "" }
        $null = writeText -type "success" -text "Installation of $appName completed successfully$note." -lineAfter
    } catch {
        $null = writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    } finally {
        # Runs on success AND failure, so failed installers don't pile up
        if (Test-Path -LiteralPath $scratch) {
            $deadline = (Get-Date).AddSeconds(10)
            do {
                try {
                    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction Stop
                    break
                } catch {
                    Start-Sleep -Seconds 1
                }
            } while ((Get-Date) -lt $deadline)

            if (Test-Path -LiteralPath $scratch) {
                $null = writeText -type "notice" -text "Could not remove the installer folder $scratch. This is harmless."
            }
        }
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
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
        return $false
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
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
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
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
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
        log -msg "registerWingetForCurrentUser: $($_.Exception.Message)" -lvl "WARNING"
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
        $work = Join-Path (getConfigPath -name download) "wingetProvision"
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
            log -msg "installWingetForAllUsers: provisioned but not resolvable in current session." -lvl "WARNING"
        }

        # --- 10. Clean up ----------------------------------------------------------
        Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $work) {
            writeText -type "error" -text "Some temp files were not deleted. This is harmless."
        }
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
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
