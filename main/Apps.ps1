function getApps {
    try {
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

        $installChoice = readOption -options $([ordered]@{
                "Browsers"      = "Get a list of internet browser software."
                "Diagnostic"    = "Get a list of diagnostic software."
                "Productivity"  = "Get a list of productivity software."
                "Customization" = "Get a list of customization software."
                "Exit"          = "Exit this script and go back to main command line."
            }) -prompt "Select which apps to install." -lineAfter

        if ($installChoice -eq 0) { 
            getBrowserApps
        }
        if ($installChoice -eq 1) { 
            getDiagnosticApps
        }
        if ($installChoice -eq 2) { 
            getProductivityApps
        }
        if ($installChoice -eq 3) { 
            getCustomizationApps
        }
        if ($installChoice -eq 4) { 
            readCommand
        }
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function getApp {
    $url = readInput -prompt "URL:"
    $appName = readInput -prompt "App name:"
    $params = readInput -prompt "Args:"
    

    installApp -url $url -appName $appName -params $params 
}
function getBrowserApps {
    try {
        $installChoice = readOption -options $([ordered]@{
                "Vivaldi" = "Install Vivaldi."
                "Brave"   = "Install Brave."
                "Firefox" = "Install Firefox."
                "Chrome"  = "Install Google Chrome."
                "Exit"    = "Exit this script and go back to main command line."
            }) -prompt "Select which browser to install:" -lineAfter

        switch ($installChoice) {
            0 { 
                $url = (winget show --id Vivaldi.Vivaldi | Select-String "Installer Url:").Line.Split(" ")[-1]
                installApp -url $url -appName "Vivaldi" -params "vivaldi-silent --do-not-launch-chrome --system-level" 
            }    
            1 { 
                $url = (winget show --id Brave.Brave | Select-String "Installer Url:").Line.Split(" ")[-1]
                installApp -url $url -appName "Brave" -params "--install --silent --system-level"
            }
            2 {
                $url = (winget show --id Mozilla.Firefox | Select-String "Installer Url:").Line.Split(" ")[-1]
                installApp -url $url -appName "Mozilla Firefox" -params "/S"
            }    
            3 { 
                $url = (winget show --id Google.Chrome | Select-String "Installer Url:").Line.Split(" ")[-1]
                installApp -url $url -appName "Google Chrome" -params "/qn /norestart" 
            }
            4 { readCommand }
        }
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function getDiagnosticApps {
    try {
        $installChoice = readOption -options $([ordered]@{
                "Bulk Crap Uninstaller" = "Install Bulk Crap Uninstaller."
                "Revo Uninstaller"      = "Install Revo Uninstaller."
                "WinDirStat"            = "Install WinDirStat."
                "BGInfo"                = "Install BGInfo."
                "HWiNFO"                = "Install HWiNFO."
                "AIPS"                  = "Install Advanced IP Scanner."
                "Exit"                  = "Exit this script and go back to main command line."
            }) -prompt "Select which diagnostic tool to install:" -lineAfter

        switch ($installChoice) {
            0 { getBulkCrapUninstaller }
            1 { getRevoUninstaller }
            2 { getWinDirStat }
            3 { getBGInfo }
            4 { getHWInfo }
            5 { getAIPS }
            6 { readCommand }
        } 
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function getBulkCrapUninstaller {
    try {
        $url = (winget show --id Klocman.BulkCrapUninstaller --accept-source-agreements --accept-package-agreements | Select-String "Installer Url:").Line.Split(" ")[-1]
        installApp -url $url -appName "BulkCrapUninstaller" -params "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART"
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function getRevoUninstaller {
    try {
        $url = "https://revouninstaller.b-cdn.net/ruf270/revosetup.exe"
        $appName = "Revo Uninstaller"
        installApp -url $url -appName $appName -params "/VERYSILENT /NORESTART"
    
        # Remove from PUBLIC Desktop (where it actually is)
        $publicDesktopLink = "C:\Users\Public\Desktop\Revo Uninstaller.lnk"
        if (Test-Path $publicDesktopLink) {
            Remove-Item -Path $publicDesktopLink -Force
        } 
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
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
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function getBGInfo {
    try {
        $url = "https://drive.google.com/uc?export=download&id=1gBFuz6WqrgPvIqYjrcRCYZeC_x9XsUbC"

        $download = getDownload -url $url -target "$env:SystemRoot\Temp\BGInfo.zip"

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
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function getHWInfo {
    try {
        $url = (winget show --id  REALiX.HWiNFO --accept-source-agreements --accept-package-agreements | Select-String "Installer Url:").Line.Split(" ")[-1]
        installApp -url $url -appName "HWiNFO" -params "--install --silent --system-level"
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function getAIPS {
    try {
        $url = "https://download.advanced-ip-scanner.com/download/files/Advanced_IP_Scanner_2.5.4594.1.exe"
        $appName = "Advanced IP Scanner"
        installApp -url $url -appName $appName -params "/VERYSILENT /NORESTART" 
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    } 
}
function getProductivityApps {
    try {
        $installChoice = readOption -options $([ordered]@{
                "Windows PowerToys"    = "Install Windows PowerToys."
                "Adobe Acrobat Reader" = "Install Adober Acrobat Reader"
                "Winget"               = "Install Winget package manager."
                "Exit"                 = "Exit this script and go back to main command line."
            }) -prompt "Select which productivity app to install:" -lineAfter

        switch ($installChoice) {
            0 { getWindowsPowerToys }
            1 { getAdobeAcrobatReader }
            2 { getWinget }
            3 { readCommand }
        } 
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function getWindowsPowerToys {
    try {
        $url = "https://release-assets.githubusercontent.com/github-production-release-asset/184456251/58b30170-c4ae-4a90-8abd-a955c5f58e07?sp=r&sv=2018-11-09&sr=b&spr=https&se=2026-06-30T13%3A10%3A52Z&rscd=attachment%3B+filename%3DPowerToysUserSetup-0.100.1-x64.exe&rsct=application%2Foctet-stream&skoid=96c2d410-5711-43a1-aedd-ab1947aa7ab0&sktid=398a6654-997b-47e9-b12b-9515b896b4de&skt=2026-06-30T12%3A10%3A52Z&ske=2026-06-30T13%3A10%3A52Z&sks=b&skv=2018-11-09&sig=%2BYe3kIqAD8DFp3%2FY4GNAe4%2BK%2BVg%2FClwvyJr0IGmims0%3D&jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmVsZWFzZS1hc3NldHMuZ2l0aHVidXNlcmNvbnRlbnQuY29tIiwia2V5Ijoia2V5MSIsImV4cCI6MTc4MjgyNTM1NSwibmJmIjoxNzgyODIxNzU1LCJwYXRoIjoicmVsZWFzZWFzc2V0cHJvZHVjdGlvbi5ibG9iLmNvcmUud2luZG93cy5uZXQifQ.WxR7zlAsBDXUl-oF75i1HCwklmM43HzqKZ3mLFYSlj0&response-content-disposition=attachment%3B%20filename%3DPowerToysUserSetup-0.100.1-x64.exe&response-content-type=application%2Foctet-stream"
        $appName = "Windows PowerToys"
        installApp -url $url -appName $appName -params "" 
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function getAdobeAcrobatReader {
    try {
        $url = "https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/2300820555/AcroRdrDC2300820555_en_US.exe"
        $appName = "Adobe Acrobat Reader"
        installApp -url $url -appName $appName -params "/sAll /rs /msi EULA_ACCEPT=YES" 
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function getCustomizationApps {
    WriteText -type "notice" -text "Customization software not yet implemented." -lineBefore
}
