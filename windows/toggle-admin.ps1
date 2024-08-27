function toggle-admin {
    try { 
        $admin = Get-LocalUser -Name "Administrator"
        
        if ($admin.Enabled) { 
            write-text -label "Administrator account is currently" -text "enabled"
        } else { 
            write-text -label "Administrator account is currently" -text "disabled"
        }
        
        $choice = read-option -options $([ordered]@{
                "Enable"  = "Enable the Windows built in administrator account."
                "Disable" = "Disable the built in administrator account."
            }) -prompt "Turn the account on or off?"

        if ($choice -ne 0 -and $choice -ne 1) { 
            enable-admin 
        }

        if ($choice -eq 0) { 
            Get-LocalUser -Name "Administrator" | Enable-LocalUser 
        } 

        if ($choice -eq 1) { 
            Get-LocalUser -Name "Administrator" | Disable-LocalUser 
        }

        $admin = Get-LocalUser -Name "Administrator"
        if ($admin.Enabled) { 
            write-text -type "success" -text "Account enabled"
        } else { 
            write-text -type "success" -text "Account disabled"
        }
    } catch {
        write-text -type "error" -text "enable-admin-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}