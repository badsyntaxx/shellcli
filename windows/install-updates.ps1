function install-updates {
    try { 
        write-text -type "plain" -text "Loading update module..."

        Import-Module PowerShellGet
        Install-Module -Name PSWindowsUpdate -Force
        Import-Module PSWindowsUpdate -Force

        write-text -type "plain" -text "Getting updates..."

        Get-WindowsUpdate

        $choice = read-option -options $([ordered]@{
                "All"    = "Install all updates."
                "Severe" = "Install only severe updates."
                "Cancel" = "Do nothing and exit this function."
            }) -prompt "Select which updates to install:" -lineBefore

        switch ($choice) {
            0 { Get-WindowsUpdate -Install -AcceptAll | Out-Null }
            1 { Get-WindowsUpdate -Severity "Important" -Install | Out-Null }
            2 { read-command }
        }

        write-text -type "success" -text "Updates complete."
    } catch {
        write-text -type "error" -text "install-updates-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}