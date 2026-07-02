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
        & "C:\Windows\System32\reg.exe" delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f | Out-Null
        Stop-Process -Name explorer -force
        Start-Process explorer
        writeText -type "success" -text "Context menu enabled"
    } catch {
        writeText -type "error" -text "enableContextMenu-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function disableContextMenu {
    try {
        # Target HKLM (system-wide)
        & "C:\Windows\System32\reg.exe" add "HKLM\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve | Out-Null
        
        # Target current user's HKCU directly
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
