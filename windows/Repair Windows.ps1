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
        writeText -type "error" -text "repairWindows-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}

function repairSystem {
    try {
        $choice = readOption -options $([ordered]@{
                "System file check"             = "Scans for and repairs corrupted system files."
                "Cleanup & restore"             = "Scans for and repairs the Windows image."
                "Restart update service"        = "Restart the Windows update service."
                "Check disk"                    = "Scans and repairs disk errors and bad sectors.(Requires reboot)"
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
            3 { & "C:\Windows\System32\cmd.exe" /c chkdsk /f /r }
            4 {
                clearTempFiles
            }
            5 { & "C:\Windows\System32\cmd.exe" /c mdsched.exe }
        }

        repairWindows
    } catch {
        writeText -type "error" -text "repairWindows-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}

function clearTempFiles {
    try {
        & "C:\Windows\System32\cmd.exe" /c cleanmgr /sagerun:1
        Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "C:\Windows\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        writeText -type "error" -text "clearTempFiles-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
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
        writeText -type "error" -text "repairWindows-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}