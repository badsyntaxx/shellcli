function toggle-admin {
    try { 
        $admin = Get-LocalUser -Name "Administrator"
        Write-Host
        Write-Host "    Administrator account is currently: " -NoNewLine
        if ($admin.Enabled) { Write-Host "enabled" -ForegroundColor Magenta } 
        else { Write-Host "disabled" -ForegroundColor Magenta }
        
        $choice = read-option -options $([ordered]@{
                "Enable"  = "Enable the Windows built in administrator account."
                "Disable" = "Disable the built in administrator account."
            }) -lineAfter 

        if ($choice -ne 0 -and $choice -ne 1) { enable-admin }

        if ($choice -eq 0) { 
            Get-LocalUser -Name "Administrator" | Enable-LocalUser 
        } 

        if ($choice -eq 1) { 
            Get-LocalUser -Name "Administrator" | Disable-LocalUser 
        }

        $admin = Get-LocalUser -Name "Administrator"
        Write-Host "    Administrator account is now: " -NoNewLine
        if ($admin.Enabled) { Write-Host "enabled" -ForegroundColor Magenta } 
        else { Write-Host "disabled" -ForegroundColor Magenta }

        exit-script
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "enable-admin-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

