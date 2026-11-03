function repairWindows {
    try {
        $choice = readOption -options $([ordered]@{
                "Repair System"  = "System Check and DISM and SFC tools."
                "Repair Network" = "Network fixes like resetting TCP/IP stack and flush DNS."
                "Cancel"         = "Do nothing and exit this function."
            }) -prompt "Select a repair tool." -lineAfter

        switch ($choice) {
            0 { repairSystem } 
            1 { repairNetwork } 
        }
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function repairSystem {
    try {
        $choice = readOption -options $([ordered]@{
                "System file check"             = "Scans for and repairs corrupted system files."
                "Cleanup & restore"             = "Scans for and repairs the Windows image."
                "Restart update service"        = "Restart the Windows update service."
                "Clear temporary files"         = "Removes Windows temporary and cache files."
                "Reregister all Windows apps"   = "Reregisters all Windows apps.(Requires reboot)"
                "Run Windows Memory Diagnostic" = "Tests RAM for errors.(Requires reboot)"
                "Cancel"                        = "Do nothing and exit this function."
            }) -prompt "Select a repair tool."

        switch ($choice) {
            0 { & "C:\Windows\System32\cmd.exe" /c sfc /scannow } 
            1 { & "C:\Windows\System32\cmd.exe" /c DISM /Online /Cleanup-Image /RestoreHealth } 
            2 {
                & "C:\Windows\System32\cmd.exe" /c net stop wuauserv 
                & "C:\Windows\System32\cmd.exe" /c net start appidsvc  
            }
            3 {
                clearTempFiles
            }
            4 { reregisterWindowsApps }
            5 { & "C:\Windows\System32\cmd.exe" /c mdsched.exe }
        }

        repairWindows
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function reregisterWindowsApps {
    <#
        Registers every installed Windows app again from its own manifest. Get-AppxPackage
        also lists packages whose files are gone (the old Microsoft Edge, apps removed from
        disk): they have no manifest to register, and asking for one is an error that would
        otherwise end the whole run. Those are skipped, and one app that cannot be registered
        (an app that is running, for instance) does not stop the others.
    #>
    try {
        writeText -type "plain" -text "Reading the installed Windows apps..."

        $packages = @(Get-AppxPackage -AllUsers -ErrorAction Stop | Sort-Object -Property PackageFullName -Unique)

        $registered = 0
        $skipped = @()
        $failed = @()

        writeText -type "plain" -text "Registering $($packages.Count) apps again. This can take a few minutes..."

        # Add-AppxPackage draws its own progress bar for every app.
        $previousProgress = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"

        try {
            foreach ($package in $packages) {
                $manifest = $null
                if ($package.InstallLocation) { $manifest = Join-Path $package.InstallLocation "AppXManifest.xml" }

                if (-not $manifest -or -not (Test-Path -LiteralPath $manifest)) {
                    $skipped += $package.Name
                    continue
                }

                try {
                    Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction Stop
                    $registered++
                } catch {
                    $reason = (($_.Exception.Message -split "\r?\n") | Where-Object { $_.Trim() } | Select-Object -First 1)
                    $failed += [pscustomobject]@{ Name = $package.Name; Reason = "$reason".Trim() }
                    log -msg "reregisterWindowsApps:$($package.Name):$($_.Exception.Message)" -lvl "WARNING"
                }
            }
        } finally {
            $ProgressPreference = $previousProgress
        }

        if ($skipped.Count -gt 0) {
            log -msg "reregisterWindowsApps: skipped, files not on disk: $($skipped -join ', ')" -lvl "INFO"
            writeText -type "plain" -text "Skipped $($skipped.Count) apps whose files are no longer on this computer (such as the old Microsoft Edge): $((($skipped | Select-Object -First 10) -join ', '))$(if ($skipped.Count -gt 10) { ', ...' })"
        }

        if ($failed.Count -gt 0) {
            writeText -type "notice" -text "Registered $registered apps again. $($failed.Count) could not be registered:"
            foreach ($item in ($failed | Select-Object -First 15)) {
                writeText -type "plain" -text "  $($item.Name): $($item.Reason)"
            }
            if ($failed.Count -gt 15) { writeText -type "plain" -text "  ... and $($failed.Count - 15) more (see the log)." }
            writeText -type "plain" -text "An app that is running cannot be registered again; a restart and another run tries those once more."
        } else {
            writeText -type "success" -text "Registered $registered apps again."
        }

        writeText -type "plain" -text "A restart may be needed."
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function cleanTempFiles {
    try {
        $paths = @()

        # ---- System-wide ----
        $systemPaths = @(
            "$env:SystemRoot\Temp",
            "$env:SystemDrive\Temp",
            "$env:SystemRoot\Logs\CBS",
            "$env:SystemRoot\Minidump",
            "$env:ProgramData\Microsoft\Windows\WER\ReportQueue",
            "$env:ProgramData\Microsoft\Windows\WER\ReportArchive",
            "$env:ProgramData\Microsoft\Windows\RetailDemo",
            "$env:ProgramData\Package Cache\.unverified"
        )
        foreach ($p in $systemPaths) {
            if (Test-Path -LiteralPath $p) { $paths += @{ Path = $p; Label = $p } }
        }

        # ---- Per-user, relative to each profile root ----
        $userRelativePaths = @(
            "AppData\Local\Temp",
            "AppData\Local\CrashDumps",
            "AppData\Local\Microsoft\Windows\INetCache",
            "AppData\Local\Microsoft\Windows\WebCache",
            "AppData\Local\Microsoft\Windows\Explorer",          # thumbnail/icon cache
            "AppData\Local\Microsoft\Windows\WER",
            "AppData\Local\Microsoft\Terminal Server Client\Cache",
            "AppData\Local\D3DSCache",
            "AppData\Local\Downloaded Installations"
        )

        # wildcard patterns, matched with -like
        $excludedProfiles = @(
            "Public", "Default", "Default User", "All Users",
            "defaultuser0", "WDAGUtilityAccount", 'MSSQL$*'
        )

        $userProfiles = Get-ChildItem -LiteralPath "$env:SystemDrive\Users" -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $name = $_.Name
            -not ($excludedProfiles | Where-Object { $name -like $_ })
        }

        foreach ($userProfile in $userProfiles) {
            foreach ($rel in $userRelativePaths) {
                $full = Join-Path $userProfile.FullName $rel
                if (Test-Path -LiteralPath $full) {
                    $paths += @{ Path = $full; Label = "$($userProfile.Name)\$rel" }
                }
            }
        }

        # ---- Recycle bin for every user, on every fixed drive ----
        try {
            $fixedDrives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop |
            Select-Object -ExpandProperty DeviceID
            foreach ($drive in $fixedDrives) {
                $binRoot = Join-Path $drive '$Recycle.Bin'
                writeText -type "plain" -text "Emptying recycle bing at $binRoot"
                if (-not (Test-Path -LiteralPath $binRoot)) { continue }
                $sidFolders = Get-ChildItem -LiteralPath $binRoot -Directory -Force -ErrorAction SilentlyContinue
                foreach ($sid in $sidFolders) {
                    $paths += @{ Path = $sid.FullName; Label = "$drive Recycle Bin ($($sid.Name))" }
                }
            }
        } catch {
            writeText -type "warning" -text "Could not enumerate recycle bins; skipping."
            log -msg "cleanTempFiles:recycleBin:$($_.Exception.Message)" -lvl "WARNING"
        }

        # ---- Clean each target independently ----
        $totalFreed = 0
        foreach ($item in $paths) {
            try {
                $beforeSize = getFolderSize -Path $item.Path
                if ($beforeSize -eq 0) { continue }

                writeText -type "plain" -text "$(formatSize $beforeSize) found at $($item.Label)."

                Get-ChildItem -LiteralPath $item.Path -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

                $afterSize = getFolderSize -Path $item.Path
                $freed = $beforeSize - $afterSize
                $totalFreed += $freed

                writeText -type "plain" -text "$(formatSize $freed) removed. Current size: $(formatSize $afterSize)" -lineAfter
            } catch {
                writeText -type "warning" -text "Could not fully clean $($item.Label)."
                log -msg "cleanTempFiles:$($item.Label):$($_.Exception.Message)" -lvl "WARNING"
            }
        }

        # ---- Delivery Optimization cache (needs dosvc RUNNING) ----
        try {
            Delete-DeliveryOptimizationCache -Force -ErrorAction Stop
            writeText -type "plain" -text "Delivery Optimization cache cleared." -lineAfter
        } catch {
            writeText -type "warning" -text "Delivery Optimization cache not cleared."
            log -msg "cleanTempFiles:doCache:$($_.Exception.Message)" -lvl "WARNING"
        }

        # ---- Windows Update cache (service-dependent) ----
        $services = @("wuauserv", "bits", "dosvc")
        $serviceStates = @{}
        foreach ($svc in $services) {
            $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($s) { $serviceStates[$svc] = $s.Status }
        }

        try {
            foreach ($svc in $serviceStates.Keys) {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            }
            foreach ($svc in $serviceStates.Keys) {
                $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
                if ($s) {
                    try { $s.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(20)) } catch { }
                }
            }

            $pendingReboot =
            (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or
            (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')

            $updatePaths = @(
                "$env:SystemRoot\ServiceProfiles\NetworkService\AppData\Local\Temp",
                "$env:SystemRoot\ServiceProfiles\LocalService\AppData\Local\Temp"
            )
            if ($pendingReboot) {
                writeText -type "warning" -text "Reboot pending; skipping SoftwareDistribution\Download."
            } else {
                $updatePaths += "$env:SystemRoot\SoftwareDistribution\Download"
            }

            foreach ($p in $updatePaths) {
                if (-not (Test-Path -LiteralPath $p)) { continue }
                $before = getFolderSize -Path $p
                if ($before -eq 0) { continue }
                writeText -type "plain" -text "$(formatSize $before) found at $p."
                Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                $after = getFolderSize -Path $p
                $totalFreed += ($before - $after)
                writeText -type "plain" -text "$(formatSize ($before - $after)) removed." -lineAfter
            }
        } catch {
            writeText -type "warning" -text "Update cache cleanup incomplete."
            log -msg "cleanTempFiles:updateCache:$($_.Exception.Message)" -lvl "WARNING"
        } finally {
            foreach ($svc in $serviceStates.Keys) {
                if ($serviceStates[$svc] -eq 'Running') {
                    Start-Service -Name $svc -ErrorAction SilentlyContinue
                }
            }
        }

        writeText -type "success" -text "Temporary files cleaned. Total freed: $(formatSize $totalFreed)"
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function repairNetwork {
    try {
        $choice = readOption -options $([ordered]@{
                "Reset Winsock"          = "Resets the Winsock catalog to its default state.(Requires reboot to take effect.)"
                "Reset IP configuration" = "Resets the IP configuration.(Requires reboot to take effect.)"
                "Release and Renew IP"   = "Releases and renews the IP configuration."
                "Flush DNS"              = "Clears the DNS client cache."
                "Reset network stack"    = "Do all the above."
                "Cancel"                 = "Do nothing and exit this function."
            }) -prompt "Select a repair tool."

        switch ($choice) {
            1 { & "C:\Windows\System32\cmd.exe" /c netsh winsock reset }  
            2 { & "C:\Windows\System32\cmd.exe" /c netsh int ip reset } 
            3 { & "C:\Windows\System32\cmd.exe" /c "ipconfig /release && ipconfig /renew" } 
            4 { & "C:\Windows\System32\cmd.exe" /c "ipconfig /flushdns" } 
            5 { 
                & "C:\Windows\System32\cmd.exe" /c netsh winsock reset
                & "C:\Windows\System32\cmd.exe" /c netsh int ip reset
                & "C:\Windows\System32\cmd.exe" /c "ipconfig /release && ipconfig /renew"
                & "C:\Windows\System32\cmd.exe" /c "ipconfig /flushdns"
            }
        }

        return
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function updateWindows {
    try { 
        writeText -type "plain" -text "Loading update module..."

        Import-Module PowerShellGet
        Install-Module -Name PSWindowsUpdate -Force
        Import-Module PSWindowsUpdate -Force

        writeText -type "plain" -text "Getting updates..."

        $updates = Get-WindowsUpdate

        # Create an empty ordered dictionary
        $orderedUpdateData = [ordered]@{}

        # Loop through each update and add its properties to the dictionary
        for ($i = 0; $i -lt $updates.Count; $i++) {
            $update = $updates[$i]
            # Key: "KB1234567" or "Update #1" - Value: "Title of the update"
            $orderedUpdateData["KB$($update.KB)"] = "$($update.Title) ($([math]::Round($update.Size/1MB, 2)) MB)"
        }

        writeText -type "table" -Table $orderedUpdateData

        $orderedUpdateData += [ordered]@{
            "All"       = "Install all updates."
            "Important" = "Install only important updates."
            "Cancel"    = "Do nothing and exit this function."
        }

        $choice = readOption -options $orderedUpdateData -prompt "Select which updates to install:" -lineBefore -returnKey

        if ($choice -eq 'All') {
            Get-WindowsUpdate -Install -AcceptAll | Out-Null
        }
        if ($choice -eq 'Important') {
            Get-WindowsUpdate -Severity "Important" -Install | Out-Null
        }
        if ($choice -eq 'Cancel') {
            readCommand
        }
        if ($choice -ne 'All' -and $choice -ne 'Important' -and $choice -ne 'Cancel') {
            Get-WindowsUpdate -KBArticleID $choice -Install | Out-Null
        }

        writeText -type "success" -text "Updates complete."
    } catch {
        writeText -type "error" -text "updateWindows-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function fixIcons {
    try {
        Stop-Process -Name explorer -Force; Remove-Item "$env:USERPROFILE\AppData\Local\Microsoft\Windows\Explorer\iconcache*" -Force; Start-Process explorer
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}