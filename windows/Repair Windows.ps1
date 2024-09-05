function repairWindows {
    try {
        $choice = readOption -options $([ordered]@{
                "System file check"      = "Scans for and repairs corrupted system files."
                "Cleanup & restore"      = "Scans for and repairs the Windows image."
                "Restart update service" = "Restart the Windows update service."
                "Cancel"                 = "Do nothing and exit this function."
            }) -prompt "Select a user account type:"

        switch ($choice) {
            0 { 
                Invoke-Expression "sfc /scannow"
                Invoke-Expression "DISM /Online /Cleanup-Image /RestoreHealth"
                restartUpdateService
            }
            1 { Invoke-Expression "sfc /scannow" }
            2 { Invoke-Expression "DISM /Online /Cleanup-Image /RestoreHealth" }
            3 { restartUpdateService } 
        }
    } catch {
        writeText -type "error" -text "repairWindows-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}

function restartUpdateService {
    Invoke-Expression "net stop wuauserv"
    Invoke-Expression "net start appidsvc"
}