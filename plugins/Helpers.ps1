function plugins {
    Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
    Write-Host " $([char]0x2502)" -NoNewline -ForegroundColor "Gray"
    Write-Host "  Try" -NoNewline
    Write-Host " plugins help" -ForegroundColor "Cyan" -NoNewline
    Write-Host " or" -NoNewline
    Write-Host " plugins menu" -NoNewline -ForegroundColor "Cyan"
    Write-Host " if you don't know what to do."
}
function readMenu {
    try {
        # Create a menu with options and descriptions using an ordered hashtable
        $choice = readOption -options $([ordered]@{
                "massgravel"   = "https://github.com/massgravel/Microsoft-Activation-Scripts"
                "reclaimw11"   = "Credit needed"
                "win11debloat" = "https://github.com/Raphire/Win11Debloat"
                "Cancel"       = "Select nothing and exit this menu."
            }) -prompt "Select a plugin:" -returnKey

        if ($choice -eq "Cancel") {
            readCommand
        }

        readCommand -command "plugins $choice"
    } catch {
        writeText -type "error" -text "readMenu-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function writeHelp {
    writeText -type "header" -text "Here are all plugin commands:"
    writeText -type "plain" -text "plugins massgravel    - https://github.com/massgravel/Microsoft-Activation-Scripts" -Color "DarkGray"
    writeText -type "plain" -text "plugins reclaimw11    - Credit needed" -Color "DarkGray"
    writeText -type "plain" -text "plugins win11debloat  - https://github.com/Raphire/Win11Debloat" -Color "DarkGray"

    # Add dynamic command listing
    if ($null -eq $script:commandMap) {
        loadCommandMap | Out-Null
    }
    
    Write-Host " $([char]0x2502) Available Commands:" -ForegroundColor "Gray"
    Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
    
    # Group commands by category
    $categories = @{}
    foreach ($cmd in $script:commandMap.Keys | Where-Object { $_ -ne "" }) {
        $def = $script:commandMap[$cmd]
        $category = $def[0]
        if (-not $categories.ContainsKey($category)) {
            $categories[$category] = @()
        }
        $categories[$category] += $cmd
    }
    
    foreach ($category in $categories.Keys | Sort-Object) {
        Write-Host " $([char]0x2502)  $($category):" -ForegroundColor "Cyan"
        $commands = $categories[$category] | Sort-Object
        $grouped = @()
        $line = ""
        foreach ($cmd in $commands) {
            if ($line.Length + $cmd.Length + 2 -gt 60) {
                Write-Host " $([char]0x2502)    $line" -ForegroundColor "White"
                $line = ""
            }
            if ($line -ne "") { $line += ", " }
            $line += $cmd
        }
        if ($line -ne "") {
            Write-Host " $([char]0x2502)    $line" -ForegroundColor "White"
        }
        Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
    }
}