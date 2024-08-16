function toggle-context-menu {
    try {         
        $choice = read-option -options $([ordered]@{
                "Enable"  = "Enable the stupid pointless menu that nobody wants or asked for."
                "Disable" = "Disable the stupid pointless menu that nobody wants or asked for."
            }) -prompt "Would you like to enable or disable the W11 context menu?"

        if ($choice -eq 0) { 
            reg delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f | Out-Null
        } 

        if ($choice -eq 1) { 
            reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve | Out-Null
        }

        Stop-Process -Name explorer -force
        Start-Process explorer

        read-command
    } catch {
        # Display error message and exit this script
        write-text -type "error" -text "enable-admin-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
        read-command
    }
}
