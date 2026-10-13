<#
    Checks config.json before it is pushed. Run it from the repo root:

        .\test-config.ps1

    Every endpoint downloads config.json each time ShellCLI starts, and
    ShellCLI refuses to start when it is wrong, so one bad edit stops all of
    them. This loads the file the same way ShellCLI does and reports every
    problem ShellCLI would stop for, then checks that each
    command's function really exists in its module file (with the same upper
    and lower case, because GitHub file names are case sensitive).

    It needs no administrator rights and changes nothing on disk. It does
    define ShellCLI's functions and variables in the current PowerShell
    session, so run it in a window you are not using for ShellCLI.
    Exit code 1 when anything is wrong.
#>

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$problems = [System.Collections.Generic.List[string]]::new()

$json = [System.IO.File]::ReadAllText((Join-Path $root 'config.json'))
. ([scriptblock]::Create([System.IO.File]::ReadAllText((Join-Path $root 'framework.ps1'))))

# Two commands with the same name (ignoring case) are almost always a mistake.
# Windows PowerShell 5.1 refuses the WHOLE file when only the case differs, so
# this also explains what the loader would report.
$seen = @{}
foreach ($match in [regex]::Matches($json, '(?m)^\s*"([^"\\]+)"\s*:\s*\{\s*"directory"')) {
    $name = normalizeCommandName -text $match.Groups[1].Value
    if ($seen.ContainsKey($name)) { $problems.Add("The command '$name' is listed twice.") }
    $seen[$name] = $true
}

# Everything ShellCLI itself would refuse. It throws one error that lists every problem.
$loaded = $true
try {
    loadShellcliConfig -json $json
} catch {
    $loaded = $false
    foreach ($line in ($_.Exception.Message -split "`r?`n")) {
        $line = $line.Trim().TrimStart('-').Trim()
        if ($line -and $line -ne 'config.json cannot be used:') { $problems.Add($line) }
    }
}

# Each command's function must exist in the module it names
# (only possible when the file could be loaded at all)
$functionsByFile = @{}
foreach ($name in $(if ($loaded) { @($global:commandMap.PSBase.Keys) } else { @() })) {
    $entry = $global:commandMap[$name]
    $directory = $entry[0]
    $file = $entry[1]
    $function = $entry[2]

    $relative = if ($file) { "$directory/$file.ps1" } else { 'framework.ps1' }

    if (-not $functionsByFile.ContainsKey($relative)) {
        $path = Join-Path $root ($relative -replace '/', '\')
        $folder = Split-Path $path -Parent
        $leaf = Split-Path $path -Leaf
        $onDisk = if (Test-Path -LiteralPath $folder) { Get-ChildItem -LiteralPath $folder -File | Where-Object { $_.Name -ceq $leaf } } else { $null }

        if (-not $onDisk) {
            $functionsByFile[$relative] = $null
        } else {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$null)
            $defined = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) | ForEach-Object { $_.Name }
            $functionsByFile[$relative] = @($defined)
        }
    }

    $defined = $functionsByFile[$relative]
    if ($null -eq $defined) {
        $problems.Add("Command '$name': the file $relative does not exist (the case of its name must match exactly).")
    } elseif ($function -cnotin $defined) {
        $problems.Add("Command '$name': $relative does not define a function called '$function'.")
    }
}

Write-Host
if ($problems.Count -eq 0) {
    Write-Host "config.json is fine: $($global:commandMap.Count) commands, modules from $(getModuleBase)." -ForegroundColor Green
    exit 0
}

Write-Host "config.json has $($problems.Count) problem(s):" -ForegroundColor Red
foreach ($problem in $problems) { Write-Host "  - $problem" -ForegroundColor Yellow }
Write-Host
exit 1
