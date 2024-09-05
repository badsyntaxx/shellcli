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
                & "cmd.exe" "sfc /scannow"
                & "cmd.exe" "DISM /Online /Cleanup-Image /RestoreHealth"
                restartUpdateService
            }
            1 { & "cmd.exe" "sfc /scannow" }
            2 { & "cmd.exe" "DISM /Online /Cleanup-Image /RestoreHealth" }
            3 { restartUpdateService } 
        }
    } catch {
        writeText -type "error" -text "repairWindows-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}

function restartUpdateService {
    & "cmd.exe" "net stop wuauserv"
    & "cmd.exe" "net start appidsvc"
}