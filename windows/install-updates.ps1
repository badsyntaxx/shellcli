function install-updates {
    try { 
        write-text -type "plain" -text "Loading update module."

        Install-Module -Name PSWindowsUpdate -Force
        Import-Module PSWindowsUpdate -Force

        write-text -type "plain" -text "Update module loaded."

        Get-WindowsUpdate

        $choice = read-option -options $([ordered]@{
                "All"    = "Install all updates."
                "Severe" = "Install only severe updates."
            })

        switch ($choice) {
            0 { 
                Get-WindowsUpdate -Install -Verbose 
            }
            1 {
                Get-WindowsUpdate -Severity Important -Install -Verbose
            }
        }

        write-text -type "success" -text "Updates complete."

        read-command
    } catch {
        # Display error message and exit this script
        write-text -type "error" -text "install-updates-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
        read-command
    }
}