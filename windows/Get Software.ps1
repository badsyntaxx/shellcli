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
        log -msg "Installing Vivaldi web browser."
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
        log -msg "Installing Brave web browser."
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
        log -msg "Installing Firefox web browser."
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
        log -msg "Installing Google Chrome web browser."
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
            "BGInfo"           = "Install BGInfo."
            "HWiNFO"           = "Install HWiNFO."
            "Exit"             = "Exit this script and go back to main command line."
        }) -prompt "Select which diagnostic tool to install:" -lineAfter

    switch ($installChoice) {
        0 { getRevoUninstaller }
        1 { getWinDirStat }
        2 { getBGInfo }
        3 { getHWInfo }
        4 { readCommand }
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
    } catch {
        writeText -type "error" -text "getWinDirStat-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

function getHWInfo {
    $url = "https://www.hwinfo.com/files/hwi64_848.exe"
    $appName = "HWiNFO"
    $paths = @(
        "$env:ProgramFiles\HWiNFO64\HWiNFO64.exe"
    )
    $installed = findExisting -Paths $paths -App $appName
    if (!$installed) { 
        installProgram -url $url -AppName $appName -Args "/VERYSILENT /NORESTART" 
    }
}

function getProductivitySoftware {
    $installChoice = readOption -options $([ordered]@{
            "Windows PowerToys" = "Install Windows PowerToys."
            "Exit"              = "Exit this script and go back to main command line."
        }) -prompt "Select which diagnostic tool to install:" -lineAfter

    switch ($installChoice) {
        0 { getRevoUninstaller }
        1 { getWinDirStat }
        2 { getBGInfo }
        3 { readCommand }
    }
}

function getWindowsPowerToys {
    $url = "https://release-assets.githubusercontent.com/github-production-release-asset/184456251/58b30170-c4ae-4a90-8abd-a955c5f58e07?sp=r&sv=2018-11-09&sr=b&spr=https&se=2026-06-30T13%3A10%3A52Z&rscd=attachment%3B+filename%3DPowerToysUserSetup-0.100.1-x64.exe&rsct=application%2Foctet-stream&skoid=96c2d410-5711-43a1-aedd-ab1947aa7ab0&sktid=398a6654-997b-47e9-b12b-9515b896b4de&skt=2026-06-30T12%3A10%3A52Z&ske=2026-06-30T13%3A10%3A52Z&sks=b&skv=2018-11-09&sig=%2BYe3kIqAD8DFp3%2FY4GNAe4%2BK%2BVg%2FClwvyJr0IGmims0%3D&jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmVsZWFzZS1hc3NldHMuZ2l0aHVidXNlcmNvbnRlbnQuY29tIiwia2V5Ijoia2V5MSIsImV4cCI6MTc4MjgyNTM1NSwibmJmIjoxNzgyODIxNzU1LCJwYXRoIjoicmVsZWFzZWFzc2V0cHJvZHVjdGlvbi5ibG9iLmNvcmUud2luZG93cy5uZXQifQ.WxR7zlAsBDXUl-oF75i1HCwklmM43HzqKZ3mLFYSlj0&response-content-disposition=attachment%3B%20filename%3DPowerToysUserSetup-0.100.1-x64.exe&response-content-type=application%2Foctet-stream"
    $appName = "Google Chrome"
    $paths = @(
        "$env:ProgramFiles\PowerToys.exe"
    )
    $installed = findExisting -Paths $paths -App $appName
    if (!$installed) { 
        installProgram -url $url -AppName $appName -Args "" 
    }
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

function getBGInfo {
    try {
        $url = "https://drive.google.com/uc?export=download&id=1gBFuz6WqrgPvIqYjrcRCYZeC_x9XsUbC"

        $download = getDownload -url $url -target "$env:SystemRoot\Temp\BGInfo.zip" -lineBefore

        if ($download -eq $true) { 
            Expand-Archive -LiteralPath "$env:SystemRoot\Temp\BGInfo.zip" -DestinationPath "$env:SystemRoot\Temp\"

            # Test if the extracted folder exists
            if (Test-Path "$env:SystemRoot\Temp\BGInfo") {
                writeText -type "plain" -text "BGInfo unpacked."
            } else {
                writeText -type "error" -text "Failed to unpack BGInfo."
            }

            ROBOCOPY "$env:SystemRoot\Temp\BGInfo" "C:\Program Files\BGInfo" /E /NFL /NDL /NJH /NJS /nc /ns | Out-Null
            ROBOCOPY "$env:SystemRoot\Temp\BGInfo" "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" "Start BGInfo.bat" /NFL /NDL /NJH /NJS /nc /ns | Out-Null

            if (Test-Path "C:\Program Files\BGInfo") {
                writeText -type "plain" -text "BGInfo installed."
            } else {
                writeText -type "error" -text "Failed to install BGInfo."
            }

            Remove-Item -Path "$env:SystemRoot\Temp\BGInfo.zip" -Recurse
            Remove-Item -Path "$env:SystemRoot\Temp\BGInfo" -Recurse 

            $filesDeleted = $true
            if (Test-Path "$env:SystemRoot\Temp\BGInfo.zip") { 
                $filesDeleted = $false 
            }
            if (Test-Path "$env:SystemRoot\Temp\BGInfo") { 
                $filesDeleted = $false 
            } 
            if (!$filesDeleted) {
                writeText -type "error" -text "Some temp files were not deleted. This is harmless."
            }

            Start-Process -FilePath "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\Start BGInfo.bat" -WindowStyle Hidden

            writeText -type "success" -text "BGInfo installed and applied."
        }
    } catch {
        writeText -type "error" -text "installBGInfo-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
