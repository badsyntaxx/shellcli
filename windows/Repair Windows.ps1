function repairWindows {
    try {
        $choice = readOption -options $([ordered]@{
                "System file check"      = "Scans for and repairs corrupted system files."
                "Cleanup & restore"      = "Scans for and repairs the Windows image."
                "Restart update service" = "Restart the Windows update service."
                "Cancel"                 = "Do nothing and exit this function."
            }) -prompt "Select a repair tool."

        switch ($choice) {
            0 { & "C:\Windows\System32\cmd.exe" /c sfc /scannow } 
            1 { & "C:\Windows\System32\cmd.exe" /c DISM /Online /Cleanup-Image /RestoreHealth } 
            2 { restartUpdateService } 
        }
    } catch {
        writeText -type "error" -text "repairWindows-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}

function restartUpdateService {
    & "C:\Windows\System32\cmd.exe" /c net stop wuauserv 
    & "C:\Windows\System32\cmd.exe" /c net start appidsvc 
}