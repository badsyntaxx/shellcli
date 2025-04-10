function toggleAdmin {
    try {
        $choice = readOption -options $([ordered]@{
                "enable admin"  = "Enable the built-in administrator account."
                "disable admin" = "Disable the built-in administrator account."
                "Cancel"        = "Do nothing and exit this function."
            }) -prompt "Select a user account type." -lineAfter

        switch ($choice) {
            0 { enableAdmin }
            1 { disableAdmin }
            2 { readCommand }
        }
    } catch {
        writeText -type "error" -text "toggleAdmin-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function enableAdmin {
    try { 
        $admin = Get-LocalUser -Name "Administrator"
        
        if ($admin.Enabled) { 
            writeText -text "Administrator account is already enabled."
        } else { 
            Get-LocalUser -Name "Administrator" | Enable-LocalUser 

            $admin = Get-LocalUser -Name "Administrator"

            if ($admin.Enabled) { 
                writeText -type "success" -text "Administrator account enabled."
            } else { 
                writeText -type "error" -text "Could not enable administrator account."
            }
        }
    } catch {
        writeText -type "error" -text "enableAdmin-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function disableAdmin {
    try { 
        $admin = Get-LocalUser -Name "Administrator"
        
        if ($admin.Enabled) { 
            Get-LocalUser -Name "Administrator" | Disable-LocalUser 

            $admin = Get-LocalUser -Name "Administrator"

            if ($admin.Enabled) { 
                writeText -type "error" -text "Could not disable administrator account."
            } else { 
                writeText -type "success" -text "Administrator account disabled."
            }
        } else { 
            writeText -text "Administrator account is already disabled."
        }
    } catch {
        writeText -type "error" -text "disableAdmin-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}