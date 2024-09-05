function repairWindows {
    try {
        $choice = readOption -options $([ordered]@{
                "Run all"                = "Send it!"
                "System file check"      = "Scans for and repairs corrupted system files."
                "Cleanup & restore"      = "Scans for and repairs the Windows image."
                "Restart update service" = "Restart the Windows update service."
                "Cancel"                 = "Do nothing and exit this function."
            }) -prompt "Select a user account type:"

        switch ($choice) {
            0 { 
                cmd /c sfc /scannow
                cmd /c DISM /Online /Cleanup-Image /RestoreHealth
                restartUpdateService
            }
            1 { cmd /c sfc /scannow } 
            2 { cmd /c DISM /Online /Cleanup-Image /RestoreHealth } 
            3 { restartUpdateService } 
        }
    } catch {
        writeText -type "error" -text "repairWindows-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}

function restartUpdateService {
    cmd /c net stop wuauserv 
    cmd /c net start appidsvc 
}