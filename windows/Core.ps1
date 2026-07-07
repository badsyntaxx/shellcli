function shellCLI {
    Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
    Write-Host " $([char]0x2502)" -NoNewline -ForegroundColor "Gray"
    Write-Host " Try" -NoNewline
    Write-Host " help" -ForegroundColor "Cyan" -NoNewline
    Write-Host " or" -NoNewline
    Write-Host " menu" -NoNewline -ForegroundColor "Cyan"
    Write-Host " if you get stuck."
    Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
}
function readMenu {
    try {
        # Create a menu with options and descriptions using an ordered hashtable
        $choice = readOption -options $([ordered]@{
                "user menu"           = "View the user management menu."
                "edit hostname"       = "Edit this computers name and description."
                "edit net adapter"    = "(BETA) Edit a network adapter."
                "get wifi creds"      = "View all saved WiFi credentials on the system."
                "toggle context menu" = "Enable or Disable the Windows 11 context menu."
                "repair windows"      = "Repair Windows."
                "update windows"      = "(BETA) Install Windows updates silently."
                "clear temp files"    = "Removes Windows temporary and cache files."
                "get software"        = "Get a list of installed software that can be installed."
                "schedule task "      = "(ALPHA) Schedule a new task."
                "Cancel"              = "Select nothing and exit this menu."
            }) -prompt "Select a function." -returnKey -lineAfter

        if ($choice -eq "Cancel") {
            readCommand
        }

        readCommand -command $choice
    } catch {
        writeText -type "error" -text "readMenu-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function writeHelp {   
    writeText -type "plain" -text "STARTER COMMANDS:"
    writeText -type "plain" -text "commands    - Display a full list of commands."
    writeText -type "plain" -text "menu        - Display a menu with some available functions."
    writeText -type "plain" -text "? or help   - Display this help text."
    writeText -type "plain" -text "FULL DOCUMENTATION:" -lineBefore
    writeText -type "plain" -text "https://wkey.pro/dev/shellcli"
}
function toggleContextMenu {
    try {         
        $choice = readOption -options $([ordered]@{
                "Enable"  = "Enable the stupid pointless menu that nobody wants or asked for."
                "Disable" = "Disable the stupid pointless menu that nobody wants or asked for."
                "Cancel"  = "Do nothing and exit this function."
            }) -prompt "Would you like to enable or disable the W11 context menu?"

        switch ($choice) {
            0 { enableContextMenu }
            1 { disableContextMenu }
            2 { readCommand }
        }
    } catch {
        writeText -type "error" -text "toggleContextMenu-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function enableContextMenu {
    try {
        # Remove from HKLM (system-wide)
        & "C:\Windows\System32\reg.exe" delete "HKLM\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f 2>$null | Out-Null
        
        # Remove from HKCU using PowerShell registry provider
        $regPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
        if (Test-Path $regPath) {
            Remove-Item -Path $regPath -Recurse -Force
        }
        
        # Also try using reg.exe with HKCU
        & "C:\Windows\System32\reg.exe" delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f 2>$null | Out-Null
        
        Stop-Process -Name explorer -force
        Start-Process explorer
        writeText -type "success" -text "Context menu enabled"
    } catch {
        writeText -type "error" -text "enableContextMenu-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function disableContextMenu {
    try {
        # Try HKLM (system-wide) - but only if we have permission
        $hkmlPath = "HKLM\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        try {
            & "C:\Windows\System32\reg.exe" add $hkmlPath /f /ve 2>$null | Out-Null
            writeText -type "info" -text "HKLM registry entry added (system-wide)"
        } catch {
            # Silently skip HKLM if access denied - we'll still apply HKCU
            writeText -type "info" -text "HKLM not accessible, applying to current user only"
        }
        
        # Target current user's HKCU directly (this always works)
        $regPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        New-Item -Path $regPath -Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty -Path $regPath -Name "(Default)" -Value "" -Force
        
        # Also try using reg.exe with the current user (this works even when elevated)
        & "C:\Windows\System32\reg.exe" add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve 2>$null | Out-Null
        
        Stop-Process -Name explorer -force
        Start-Process explorer
        writeText -type "success" -text "Context menu disabled"
    } catch {
        writeText -type "error" -text "disableContextMenu-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function editHostname {
    try {
        writeText -type "prompt" -text "Enter a new hostname for the target PC."

        $currentHostname = $env:COMPUTERNAME
        $hostname = readInput -prompt "Hostname:" -Validate "^(\s*|[a-zA-Z0-9 _\-?]{1,15})$" -Value $currentHostname
        
        if ($hostname -eq "") { 
            $hostname = $currentHostname 
        } 

        if ($hostname -ne "") {
            Remove-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "Hostname" 
            Remove-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "NV Hostname" 
            Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\Computername\Computername" -name "Computername" -value $hostname
            Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\Computername\ActiveComputername" -name "Computername" -value $hostname
            Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "Hostname" -value $hostname
            Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "NV Hostname" -value  $hostname
            Set-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -name "AltDefaultDomainName" -value $hostname
            Set-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -name "DefaultDomainName" -value $hostname
            $env:COMPUTERNAME = $hostname
        } 

        $hostnameChanged = $currentHostname -ne $env:COMPUTERNAME

        if ($hostnameChanged) {
            writeText -type "success" -text "Hostname changed."
        } else {
            writeText -type "success" -text "Hostname unchanged."
        }

        $choice = readOption -options $([ordered]@{
                "Yes" = "Change the description of the PC."
                "No"  = "Do not change the description of the PC."
            }) -prompt "Do you also want to change the description for the target PC?" -lineAfter

        switch ($choice) {
            0 { editDescription }
            1 { readCommand }
        }
    } catch {
        writeText -type "error" -text "editHostname-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function editDescription {
    try {
        writeText -type "prompt" -text "Enter a new description for the target PC."

        $currentDescription = (Get-WmiObject -Class Win32_OperatingSystem).Description
        $description = readInput -prompt "Description:" -Validate "^(\s*|[a-zA-Z0-9[\] |_\-?']{1,64})$" -Value $currentDescription

        if ($description -ne "") {
            Set-CimInstance -Query 'Select * From Win32_OperatingSystem' -Property @{Description = $description }
        } 

        writeText -type "success" -text "Description changed."
    } catch {
        writeText -type "error" -text "editDescription-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function getWifiCreds {
    try {
        $wifiProfiles = netsh wlan show profiles
        if ($wifiProfiles -match "There is no wireless interface on the system.") {
            writeText -type "error" -text "There is no wireless interface on the system." -lineBefore -lineAfter
            readCommand
        }

        if ((Get-Service wlansvc).Status -ne "Running") {
            writeText -type "notice" -text "The wlansvc service is not running or the wireless adapter is disabled." -lineBefore -lineAfter
            readCommand
        }

        if ($wifiProfiles.Count -gt 0) {
            $wifiList = ($wifiProfiles | Select-String -Pattern "\w*All User Profile.*: (.*)" -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value }
        } else {
            writeText -type "error" -text "No WiFi profiles found." -lineBefore -lineAfter
            readCommand
        }

        writeText -type "prompt" -text "Found $($wifiList.Count) Wi-Fi Connection settings stored on the system"

        foreach ($ssid in $wifiList) {
            try {
                $password = (netsh wlan show profile name="$ssid" key=clear | Select-String -Pattern ".*Key Content.*: (.*)" -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value }
            } catch {
                $password = "N/A"
            }

            Write-Host " $([char]0x2502)" -NoNewline -ForegroundColor "Gray"
            Write-Host "  ${ssid}: " -NoNewLine  -ForegroundColor DarkGray
            Write-Host "$password"
        }
    } catch {
        writeText -type "error" -text "getWifiCreds-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function disableHypernateFile {
    try {
        # Get current file size before removal (for feedback)
        $fileSize = if (Test-Path "C:\hiberfil.sys") {
            [math]::Round((Get-Item "C:\hiberfil.sys").Length / 1GB, 2)
        } else {
            0
        }
        
        # Disable hibernation
        Write-Host "⏳ Disabling hibernation..." -ForegroundColor Yellow
        $result = powercfg /hibernate off 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Failed to disable hibernation: $result" -ForegroundColor Red
            return $false
        }
        
        # Wait for system to release the file
        Start-Sleep -Seconds 2
        
        # Force remove if still present
        if (Test-Path "C:\hiberfil.sys") {
            try {
                # Clear read-only attribute if set
                attrib -r "C:\hiberfil.sys" 2>$null
                
                Remove-Item "C:\hiberfil.sys" -Force -ErrorAction Stop
                Write-Host "✅ Successfully removed hiberfil.sys (freed ~${fileSize}GB)" -ForegroundColor Green
            } catch {
                Write-Host "⚠️ Hibernation disabled but file removal failed: $_" -ForegroundColor Yellow
                Write-Host "   The file will be removed automatically on next reboot." -ForegroundColor Yellow
                return $true # Still consider it a success since hibernation is disabled
            }
        } else {
            if ($fileSize -eq 0) {
                Write-Host "ℹ️ Hibernation was already disabled. No space to free." -ForegroundColor Cyan
            } else {
                Write-Host "✅ Hibernation disabled. File automatically removed." -ForegroundColor Green
            }
        }
        
        # Show freed space summary
        $currentFree = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
        Write-Host "📊 Current free space on C: ~${currentFree}GB" -ForegroundColor Cyan
        
        return $true
    } catch {
        Write-Host "❌ Unexpected error: $_" -ForegroundColor Red
        return $false
    }
}