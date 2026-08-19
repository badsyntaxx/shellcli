function repairWindows {
    try {
        $choice = readOption -options $([ordered]@{
                "Repair System"  = "System Check and DISM and SFC tools."
                "Repair Network" = "Network fixes like resetting TCP/IP stack and flush DNS."
                "Cancel"         = "Do nothing and exit this function."
            }) -prompt "Select a repair tool."

        switch ($choice) {
            0 { repairSystem } 
            1 { repairNetwork } 
        }
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function repairSystem {
    try {
        $choice = readOption -options $([ordered]@{
                "System file check"             = "Scans for and repairs corrupted system files."
                "Cleanup & restore"             = "Scans for and repairs the Windows image."
                "Restart update service"        = "Restart the Windows update service."
                "Clear temporary files"         = "Removes Windows temporary and cache files."
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
            4 { & "C:\Windows\System32\cmd.exe" /c mdsched.exe }
        }

        repairWindows
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
    }
}
function cleanTempFiles {
    try {
        $paths = @(
            @{ Path = "C:\Windows\Temp"; Label = "C:\Windows\Temp" },
            @{ Path = "C:\Windows\Prefetch"; Label = "C:\Windows\Prefetch" },
            @{ Path = "C:\Users\$env:USERNAME\AppData\Local\Temp"; Label = "C:\Users\$env:USERNAME\AppData\Local\Temp" }
        )

        foreach ($item in $paths) {
            $beforeSize = getFolderSize -Path $item.Path
            writeText -type "plain" -text "Clearing temporary files at $($item.Label) - Before: $(formatSize $beforeSize)"

            Remove-Item -Path "$($item.Path)\*" -Recurse -Force -ErrorAction SilentlyContinue

            $afterSize = getFolderSize -Path $item.Path
            $freedSize = $beforeSize - $afterSize
            writeText -type "plain" -text "$($item.Label) - After: $(formatSize $afterSize) (Freed: $(formatSize $freedSize))"
        }

        writeText -type "plain" -text "Emtying Recycle Bin"
        Clear-RecycleBin -Force
        writeText -type "success" -text "Temporary files cleaned."
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
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

        repairWindows
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber)"
        log -msg "$($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber):$($_.Exception.Message)" -lvl "ERROR"
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
