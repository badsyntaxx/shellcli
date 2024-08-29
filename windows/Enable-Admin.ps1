function enable-admin {
    try { 
        $admin = Get-LocalUser -Name "Administrator"
        
        if ($admin.Enabled) { 
            write-text -text "Administrator account is currently enabled"
        } else { 
            Get-LocalUser -Name "Administrator" | Enable-LocalUser 
        }

        $admin = Get-LocalUser -Name "Administrator"

        if ($admin.Enabled) { 
            write-text -type "success" -text "Administrator account enabled"
        } else { 
            write-text -type "error" -text "Could not enable administrator account"
        }
    } catch {
        write-text -type "error" -text "enable-admin-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function disable-admin {
    try { 
        $admin = Get-LocalUser -Name "Administrator"
        
        if ($admin.Enabled) { 
            Get-LocalUser -Name "Administrator" | Disable-LocalUser 
        } else { 
            write-text -text "Administrator account is already disabled"
        }

        $admin = Get-LocalUser -Name "Administrator"

        if ($admin.Enabled) { 
            write-text -type "error" -text "Could not disable administrator account"
        } else { 
            write-text -type "success" -text "Administrator account disabled"
        }
    } catch {
        write-text -type "error" -text "disable-admin-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}