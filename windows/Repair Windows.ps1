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
                Invoke-Command -CommandType ScriptBlock -ScriptBlock { cmd.exe sfc /scannow }
                Invoke-Command -CommandType ScriptBlock -ScriptBlock { cmd.exe DISM /Online /Cleanup-Image /RestoreHealth }
                restartUpdateService
            }
            1 { Invoke-Command -CommandType ScriptBlock -ScriptBlock { cmd.exe sfc /scannow } }
            2 { Invoke-Command -CommandType ScriptBlock -ScriptBlock { cmd.exe DISM /Online /Cleanup-Image /RestoreHealth } }
            3 { restartUpdateService } 
        }
    } catch {
        writeText -type "error" -text "repairWindows-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}

function restartUpdateService {
    Invoke-Command -CommandType ScriptBlock -ScriptBlock { cmd.exe net stop wuauserv }
    Invoke-Command -CommandType ScriptBlock -ScriptBlock { cmd.exe net start appidsvc }
}