function Enable-Admin {
    try { 
        $admin = Get-LocalUser -Name "Administrator"
        
        if ($admin.Enabled) { 
            write-text -label "Administrator account is currently" -text "enabled"
        } else { 
            Get-LocalUser -Name "Administrator" | Enable-LocalUser 
        }

        if ($admin.Enabled) { 
            write-text -type "success" -text "Administrator account enabled"
        } else { 
            write-text -type "success" -text "Could not enable administrator account"
        }
    } catch {
        write-text -type "error" -text "Enable-Admin-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function Disable-Admin {
    try { 
        $admin = Get-LocalUser -Name "Administrator"
        
        if ($admin.Enabled) { 
            Get-LocalUser -Name "Administrator" | Disable-LocalUser 
        } else { 
            write-text -label "Administrator account is already" -text "disabled"
        }

        if ($admin.Enabled) { 
            write-text -type "success" -text "Could not disable administrator account"
        } else { 
            write-text -type "success" -text "Administrator account disabled"
        }
    } catch {
        write-text -type "error" -text "Disable-Admin-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}