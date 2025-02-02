function getSoftware {
    try {
        $installChoice = readOption -options $([ordered]@{
                "Browsers"      = "Get a list of internet browser software."
                "Diagnostic"    = "Get a list of diagnostic software."
                "Productivity"  = "Get a list of productivity software."
                "Customization" = "Get a list of customization software."
                "Exit"          = "Exit this script and go back to main command line."
            }) -prompt "Select which apps to install:"

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

    writeText -type "plain" -text "Running installer."

    try {
        $process.Start() | Out-Null
        if ($Wait) {
            $process.WaitForExit()
            if ($process.ExitCode -eq 0) {
                writeText -type "plain" -text "Installer ran successfully."
            } else {
                writeText -type "plain" -text "Installer failed with exit code $($process.ExitCode)."
            }
            return $process.ExitCode  # Return the exit code
        } else {
            writeText -type "plain" -text "Installation of '$Path' started in the background."
            return 0  # Return 0 if not waiting
        }
    } catch {
        writeText -type "plain" -text "Failed to start the installation process. Error: $_"
        return -1  # Return -1 to indicate a failure to start the process
    }
}
function installMSI {
    param (
        [string]$Path, # Path to the .msi file
        [string]$msiArguments # Additional arguments for the MSI installer
    )

    writeText -type "plain" -text "Running installer."

    try {
        $process = Start-Process "msiexec.exe" -ArgumentList "/i `"$Path`" $msiArguments" -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            writeText -type "plain" -text "Installer ran successfully."
        } else {
            writeText -type "plain" -text "Installer failed with exit code $($process.ExitCode)."
        }
        return $process.ExitCode  # Return the exit code
    } catch {
        writeText -type "plain" -text "Failed to start the installation process. Error: $_"
        return -1  # Return -1 to indicate a failure to start the process
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

    if ($installChoice -ne 2) { 
        $script:user = selectUser -prompt "Select user to install apps for:"
    }
    if ($installChoice -eq 0) { 
        $url = "https://downloads.vivaldi.com/stable/Vivaldi.7.0.3495.27.x64.exe"
        $appName = "Vivaldi"
        $paths = @(
            "C:\Users\Badsyntax\AppData\Local\Vivaldi\Application"
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
    WriteText -type "notice" -text "Diagnostic software not yet implemented." -lineBefore
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
function installProgram {
    param (
        [parameter(Mandatory = $true)]
        [string]$url,
        [parameter(Mandatory = $true)]
        [string]$AppName,
        [parameter(Mandatory = $true)]
        [string]$Args
    )

    try {
        $fileName = Split-Path -Path $url -Leaf
        $outputPath = Join-Path -Path "$env:SystemRoot\Temp" -ChildPath $fileName

        if (getDownload -url $url -target $outputPath) {
            $fileExtension = [System.IO.Path]::GetExtension($outputPath).ToLower()
            switch ($fileExtension) {
                ".exe" {
                    $exitCode = installEXE -Path $outputPath -exeArguments $Args -Wait $true
                    if ($exitCode -eq 0) {
                        writeText -type "success" -text "Installation of $AppName completed successfully." -lineAfter
                    } else {
                        writeText -type "error" -text "Installation of $AppName failed with exit code $exitCode."
                    }
                }
                ".msi" {
                    $exitCode = installMSI -Path $outputPath -msiArguments $Args
                    if ($exitCode -eq 0) {
                        writeText -type "success" -text "Installation of $AppName completed successfully." -lineAfter
                    } else {
                        writeText -type "error" -text "Installation of $AppName failed with exit code $exitCode."
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
                    writeText -type "plain" -text "Removed installer."
                    break
                } catch {
                    Start-Sleep -Seconds 1
                }
            }

            if (Test-Path $outputPath) {
                writeText -type "error" -text "Failed to remove installer."
            }
        }        
    } catch {
        writeText -type "error" -text "Installation error: $($_.Exception.Message)"
        writeText "Skipping $AppName installation."
    }
}