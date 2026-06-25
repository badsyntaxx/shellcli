function getSoftware {
    try {
        $installChoice = readOption -options $([ordered]@{
                "Browsers"      = "Get a list of internet browser software."
                "Diagnostic"    = "Get a list of diagnostic software."
                "Productivity"  = "Get a list of productivity software."
                "Customization" = "Get a list of customization software."
                "Exit"          = "Exit this script and go back to main command line."
            }) -prompt "Select which apps to install." -lineAfter

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
    } catch {
        # Display error message and end the script
        writeText -type "error" -text "isrInstallApps-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}
function getBrowserSoftware {
    $installChoice = readOption -options $([ordered]@{
            "Vivaldi" = "Install Vivaldi."
            "Brave"   = "Install Brave."
            "Firefox" = "Install Firefox."
            "Chrome"  = "Install Google Chrome."
            "Exit"    = "Exit this script and go back to main command line."
        }) -prompt "Select which browser to install:"

    if ($installChoice -ne 4) { 
        $script:user = selectUser -prompt "Select user to install apps for:"
    }
    if ($installChoice -eq 0) { 
        $url = "https://downloads.vivaldi.com/stable/Vivaldi.7.0.3495.27.x64.exe"
        $appName = "Vivaldi"
        $paths = @(
            "C:\Users\$($user["Name"])\AppData\Local\Vivaldi\Application"
        )
        $installed = findExisting -Paths $paths -App $appName
        if (!$installed) { 
            installProgram -url $url -AppName $appName -Args "/silent" 
        }
    }
    if ($installChoice -eq 1) { 
        $url = "https://github.com/brave/browser-laptop/releases/download/v0.25.2dev/BraveSetup-x64.exe"
        $appName = "Brave"
        $paths = @(
            "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe"
        )
        $installed = findExisting -Paths $paths -App $appName
        if (!$installed) { 
            installProgram -url $url -AppName $appName -Args "/silent" 
        }
    }
    if ($installChoice -eq 2) { 
        $url = "https://archive.mozilla.org/pub/firefox/releases/134.0.2/win64/en-US/Firefox Setup 134.0.2.msi"
        $appName = "Firefox"
        $paths = @(
            "$env:ProgramFiles\Mozilla Firefox\firefox.exe"
        )
        $installed = findExisting -Paths $paths -App $appName
        if (!$installed) { 
            installProgram -url $url -AppName $appName -Args "/qn" 
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
        $installed = findExisting -Paths $paths -App $appName
        if (!$installed) { 
            installProgram -url $url -AppName $appName -Args "/qn" 
        }
    }
}
function getDiagnosticSoftware {
    $installChoice = readOption -options $([ordered]@{
            "Revo Uninstaller" = "Install Revo Uninstaller."
            "WinDirStat"       = "Install WinDirStat."
            "Exit"             = "Exit this script and go back to main command line."
        }) -prompt "Select which diagnostic tool to install:" -lineAfter

    switch ($installChoice) {
        0 { getRevoUninstaller }
        1 { getWinDirStat }
        2 { readCommand }
    }
}

function getRevoUninstaller {
    $url = "https://revouninstaller.b-cdn.net/ruf270/revosetup.exe"
    $appName = "Revo Uninstaller"
    $paths = @(
        "C:\Program Files\VS Revo Group\Revo Uninstaller\RevoUnin.exe"
    )
    $installed = findExisting -Paths $paths -App $appName
    if (!$installed) { 
        installProgram -url $url -AppName $appName -Args "/VERYSILENT /NORESTART"
    }
    
    # Remove from PUBLIC Desktop (where it actually is)
    $publicDesktopLink = "C:\Users\Public\Desktop\Revo Uninstaller.lnk"
    if (Test-Path $publicDesktopLink) {
        Remove-Item -Path $publicDesktopLink -Force
    }
    getDiagnosticSoftware
}

function getWinDirStat {
    try {
        $url = "https://github.com/windirstat/windirstat/releases/latest/download/WinDirStat.zip"

        # Define paths
        $tempDir = "C:\Temp"
        $zipPath = Join-Path -Path $tempDir -ChildPath "WinDirStat.zip"  # FULL path with filename
        $exePath = Join-Path -Path $tempDir -ChildPath "WinDirStat.exe"

        # Create directory if it doesn't exist
        if (!(Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            writeText -type "notice" -text "Created directory: $tempDir"
        }          

        # Check if WinDirStat.exe already exists
        if (!(Test-Path $exePath)) {
            # Download the zip file - pass the FULL file path
            if (getDownload -url $url -target $zipPath) {
                # Verify the zip file was downloaded
                if (Test-Path $zipPath) {
                    # Extract the zip file
                    Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
                        
                    # Move WinDirStat.exe from x64 subfolder to root
                    $extractedExe = Join-Path -Path $tempDir -ChildPath "x64\WinDirStat.exe"
                    if (Test-Path $extractedExe) {
                        Move-Item -Path $extractedExe -Destination $exePath -Force
                        # Clean up the x64 folder
                        Remove-Item -Path (Join-Path -Path $tempDir -ChildPath "x64") -Recurse -Force -ErrorAction SilentlyContinue
                        Remove-Item -Path (Join-Path -Path $tempDir -ChildPath "x86") -Recurse -Force -ErrorAction SilentlyContinue
                        Remove-Item -Path (Join-Path -Path $tempDir -ChildPath "Arm64") -Recurse -Force -ErrorAction SilentlyContinue
                    } else {
                        writeText -type "notice" -text "WinDirStat.exe not found in the expected x64 subfolder"
                    }
                        
                    # Clean up the zip file
                    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
                        
                    writeText -type "success" -text "WinDirStat.exe has been placed in: $tempDir"
                } else {
                    writeText -type "error" -text "Download failed or zip file not found at: $zipPath"
                }
            } else {
                writeText -type "error" -text "Failed to download WinDirStat.zip"
            }
        } else {
            writeText -type "notice" -text "WinDirStat.exe already exists in: $tempDir. Skipping download and extraction."
        }
        getDiagnosticSoftware
    } catch {
        writeText -type "error" -text "getWinDirStat-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

function getProductivitySoftware {
    WriteText -type "notice" -text "Productivity software not yet implemented." -lineBefore
}

function getCustomizationSoftware {
    WriteText -type "notice" -text "Customization software not yet implemented." -lineBefore
}

function findExisting {
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