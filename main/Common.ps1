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
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
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
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function disableContextMenu {
    try {
        # Try HKLM (system-wide) - but only if we have permission
        $hkmlPath = "HKLM\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        try {
            & "C:\Windows\System32\reg.exe" add $hkmlPath /f /ve 2>$null | Out-Null
            writeText -type "notice" -text "HKLM registry entry added (system-wide)"
        } catch {
            # Silently skip HKLM if access denied - we'll still apply HKCU
            writeText -type "notice" -text "HKLM not accessible, applying to current user only"
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
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
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
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
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
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function disableHybernateFile {
    try {
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            writeText -type "error" -text "This function must be run as Administrator to modify hiberfil.sys."
            return
        }

        function Get-FreeSpaceGB {
            [math]::Round(([System.IO.DriveInfo]::new('C')).AvailableFreeSpace / 1GB, 2)
        }

        $currentFree = Get-FreeSpaceGB
        writeText -type "plain" -text "Current free space on C: ~${currentFree}GB"

        $hiberEnabled = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled" -ErrorAction SilentlyContinue).HibernateEnabled -eq 1

        $fileExists = Test-Path "C:\hiberfil.sys"
        $fileSize = if ($fileExists) {
            [math]::Round((Get-Item "C:\hiberfil.sys" -Force).Length / 1GB, 2)
        } else { 0 }

        if (-not $hiberEnabled -and $fileExists) {
            writeText -type "notice" -text "Hibernation is already disabled, but hiberfil.sys still exists. Removing it..."
            try {
                attrib -r -s -h "C:\hiberfil.sys"
                takeown /F "C:\hiberfil.sys" | Out-Null
                icacls "C:\hiberfil.sys" /grant administrators:F | Out-Null
                Remove-Item "C:\hiberfil.sys" -Force -ErrorAction Stop
                writeText -type "success" -text "Successfully removed hiberfil.sys (freed ~${fileSize}GB)"
            } catch {
                writeText -type "error" -text "Failed to remove hiberfil.sys: $_"
                writeText -type "notice" -text "The file will be removed automatically on next reboot."
            }
            $newFree = Get-FreeSpaceGB
            writeText -type "plain" -text "Current free space on C: ~${newFree}GB (freed ~$([math]::Round($newFree - $currentFree,2))GB)"
            return
        }

        if (-not $fileExists -and -not $hiberEnabled) {
            writeText -type "notice" -text "Hibernation was already disabled and no hiberfil.sys found. No action needed."
            return
        }

        writeText -type "plain" -text "Disabling hibernation..."
        $global:LASTEXITCODE = $null
        $result = powercfg /hibernate off 2>&1

        if ($LASTEXITCODE -ne 0) {
            writeText -type "error" -text "Failed to disable hibernation: $result"
            return
        }

        Start-Sleep -Seconds 3

        if (-not (Test-Path "C:\hiberfil.sys")) {
            writeText -type "success" -text "Hibernation disabled. File automatically removed (freed ~${fileSize}GB)"
        } else {
            try {
                attrib -r -s -h "C:\hiberfil.sys"
                takeown /F "C:\hiberfil.sys" | Out-Null
                icacls "C:\hiberfil.sys" /grant administrators:F | Out-Null
                Remove-Item "C:\hiberfil.sys" -Force -ErrorAction Stop
                writeText -type "success" -text "Successfully removed hiberfil.sys (freed ~${fileSize}GB)"
            } catch {
                writeText -type "error" -text "Hibernation disabled but file removal failed: $_"
                writeText -type "notice" -text "The file will be removed automatically on next reboot."
            }
        }

        $newFree = Get-FreeSpaceGB
        writeText -type "plain" -text "Current free space on C: ~${newFree}GB (freed ~$([math]::Round($newFree - $currentFree,2))GB)"

    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function fixIcons {
    try {
        Stop-Process -Name explorer -Force; Remove-Item "$env:USERPROFILE\AppData\Local\Microsoft\Windows\Explorer\iconcache*" -Force; Start-Process explorer
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function techMode {
    # Check for interactive user session
    if (-not $env:USERNAME -or $env:USERNAME -eq "SYSTEM" -or -not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        writeText "This is not a logged in user terminal. Adding the GodMode folder wont work."
    }
    
    writeText -type "plain" -text "Enabling TechMode"
    writeText -type "plain" -text "Showing file extensions"
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
    writeText -type "plain" -text "Showing hidden folders and files"
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
    writeText -type "plain" -text "Showing full paths title bar"
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" -Name "FullPath" -Value 1
    writeText -type "plain" -text "Showing all try icons"
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -Value 0
    writeText -type "plain" -text "Adding GodMode folder to desktop"
    $godmode = New-Item -Path "$env:USERPROFILE\Desktop\GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}" -ItemType Directory -ErrorAction SilentlyContinue
    Stop-Process -ProcessName explorer
    Start-Process explorer
    writeText -type "success" -text "TechMode enabled"
}
function userMode {
    # Check for interactive user session
    if (-not $env:USERNAME -or $env:USERNAME -eq "SYSTEM" -or -not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        writeText "This is not a logged in user terminal. Removing the GodMode folder wont work."
    }

    writeText "Disabling TechMode"
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 1
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 0
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" -Name "FullPath" -Value 0
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -Value 1
    Remove-Item -Path "$env:USERPROFILE\Desktop\GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}"
    Stop-Process -ProcessName explorer
    Start-Process explorer
    writeText -type "success" -text "TechMode disabled"
}
function findDC {
    try {
        nltest /dsgetdc:
        dsregcmd /status
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function getStorage {
    $disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
    $total = [math]::Round($disk.Size / 1GB, 2)
    $free = [math]::Round($disk.FreeSpace / 1GB, 2)
    $used = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 2)
    $percent = [math]::Round(($used / $total) * 100, 2)

    $data = [ordered]@{
        "Disk"    = "C:"
        "Total"   = "$total GB"
        "Free"    = "$free GB"
        "Used"    = "$used GB"
        "Percent" = "$percent%"
    }

    writeText -type "table" -Table $data
}
