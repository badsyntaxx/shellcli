function getSoftware {
    try {
        $installChoice = readOption -options $([ordered]@{
                "Browsers"      = "Install all the apps that an ISR will need."
                "Diagnostic"    = "Install Google Chrome"
                "Productivity"  = "Install Google Chrome"
                "Customization" = "Install Google Chrome"
                "Exit"          = "Exit this script and go back to main command line."
            }) -prompt "Select which apps to install:"

        if ($installChoice -ne 2) { 
            $script:user = selectUser -prompt "Select user to install apps for:"
        }
        if ($installChoice -eq 0) { 
            getBrowserSoftware
        }
        if ($installChoice -eq 1) { 
            getDiagnosticSoftware
        }
        if ($installChoice -eq 2) { 
            getProductivitySoftware
        }
        if ($installChoice -eq 3) { 
            getCustomizationSoftware
        }
        if ($installChoice -eq 4) { 
            readCommand
        }

        Initialize-Cleanup
    } catch {
        # Display error message and end the script
        writeText -type "error" -text "isrInstallApps-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}
function getBrowserSoftware {
    $installChoice = readOption -options $([ordered]@{
            "Vivaldi" = "Install all the apps that an ISR will need."
            "Brave"   = "Install Google Chrome"
            "Firefox" = "Install Google Chrome"
            "Chrome"  = "Install Google Chrome"
            "Exit"    = "Exit this script and go back to main command line."
        }) -prompt "Select which apps to install:"

    if ($installChoice -ne 2) { 
        $script:user = selectUser -prompt "Select user to install apps for:"
    }
    if ($installChoice -eq 0) { 
        $url = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"
        $appName = "Vivaldi"
        $paths = @(
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "$env:ProgramFiles (x86)\Google\Chrome\Application\chrome.exe",
            "C:\Users\$($user["Name"])\AppData\Google\Chrome\Application\chrome.exe"
        )
    }
    if ($installChoice -eq 1) { 
        $url = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"
        $appName = "Brave"
        $paths = @(
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "$env:ProgramFiles (x86)\Google\Chrome\Application\chrome.exe",
            "C:\Users\$($user["Name"])\AppData\Google\Chrome\Application\chrome.exe"
        )
    }
    if ($installChoice -eq 2) { 
        $url = "https://download.mozilla.org/?product=firefox-stub&os=win&lang=en-US&attribution_code=c291cmNlPXd3dy5nb29nbGUuY29tJm1lZGl1bT1yZWZlcnJhbCZjYW1wYWlnbj0obm90IHNldCkmY29udGVudD0obm90IHNldCkmZXhwZXJpbWVudD0obm90IHNldCkmdmFyaWF0aW9uPShub3Qgc2V0KSZ1YT1jaHJvbWUmY2xpZW50X2lkX2dhND0obm90IHNldCkmc2Vzc2lvbl9pZD0obm90IHNldCkmZGxzb3VyY2U9bW96b3Jn&attribution_sig=c629f49b91d2fa3e54e7b9ae8d92a74866b3980356bf1a5b70c0bca69812620b"
        $appName = "Firefox"
        $paths = @(
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "$env:ProgramFiles (x86)\Google\Chrome\Application\chrome.exe",
            "C:\Users\$($user["Name"])\AppData\Google\Chrome\Application\chrome.exe"
        )
        $installed = Find-ExistingInstall -Paths $paths -App $appName
        if (!$installed) { 
            Install-Program $url $appName "exe" "/silent" 
        }
    }
    if ($installChoice -eq 3) { 
        $url = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"
        $appName = "Google Chrome"
        $paths = @(
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "$env:ProgramFiles (x86)\Google\Chrome\Application\chrome.exe",
            "C:\Users\$($user["Name"])\AppData\Google\Chrome\Application\chrome.exe"
        )
    }
}
function getDiagnosticSoftware {
    $paths = @(
        "C:\Program Files (x86)\Cliq Deployment\cliqDeploymentTool.exe"
    )
    $url = "https://downloads.zohocdn.com/chat-desktop/windows/Cliq-1.7.3-x64.msi"
    $appName = "Cliq"
    $installed = Find-ExistingInstall -Paths $paths -App $appName
    if (!$installed) { 
        Install-Program $url $appName "msi" "/qn" 
    }
}
function Find-ExistingInstall {
    param (
        [parameter(Mandatory = $true)]
        [array]$Paths,
        [parameter(Mandatory = $true)]
        [string]$App
    )

    writeText -type "notice" -text "Installing $App" -lineBefore

    $installationFound = $false

    foreach ($path in $paths) {
        if (Test-Path $path) {
            $installationFound = $true
            break
        }
    }

    if ($installationFound) { 
        writeText -type "success" -text "$App already installed."
    }

    return $installationFound
}
function Install-Program {
    param (
        [parameter(Mandatory = $true)]
        [string]$url,
        [parameter(Mandatory = $true)]
        [string]$AppName,
        [parameter(Mandatory = $true)]
        [string]$Extension,
        [parameter(Mandatory = $true)]
        [string]$Args
    )

    try {
        if ($Extension -eq "msi") {
            $output = "$AppName.msi"
        } else {
            $output = "$AppName.exe"
        }

        $download = getDownload -url $url -target "$env:SystemRoot\Temp\$output" 

        if ($download) {
            if ($Extension -eq "msi") {
                $process = Start-Process -FilePath "msiexec" -ArgumentList "/i `"$env:SystemRoot\Temp\$output`" $Args" -PassThru
            } else {
                $process = Start-Process -FilePath "$env:SystemRoot\Temp\$output" -ArgumentList "$Args" -PassThru
            }

            $curPos = $host.UI.RawUI.CursorPosition

            while (!$process.HasExited) {
                Write-Host -NoNewLine "`r  Installing |"
                Start-Sleep -Milliseconds 150
                Write-Host -NoNewLine "`r  Installing /"
                Start-Sleep -Milliseconds 150
                Write-Host -NoNewLine "`r  Installing $([char]0x2015)"
                Start-Sleep -Milliseconds 150
                Write-Host -NoNewLine "`r  Installing \"
                Start-Sleep -Milliseconds 150
            }

            # Restore the cursor position after the installation is complete
            [Console]::SetCursorPosition($curPos.X, $curPos.Y)

            $nextPos = $host.UI.RawUI.CursorPosition

            Write-Host "                                                     `r"

            [Console]::SetCursorPosition($nextPos.X, $nextPos.Y)

            Get-Item -ErrorAction SilentlyContinue "$env:SystemRoot\Temp\$output" | Remove-Item -ErrorAction SilentlyContinue

            writeText -type "success" -text "$AppName successfully installed."
        }        
    } catch {
        writeText -type "error" -text "Installation error: $($_.Exception.Message)"
        writeText "Skipping $AppName installation."
    }
}