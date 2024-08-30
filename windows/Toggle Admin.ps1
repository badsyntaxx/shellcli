function toggle-admin {
    try {
        $choice = readOption -options $([ordered]@{
                "Enable admin"  = "Enable the built-in administrator account."
                "Disable admin" = "Disable the built-in administrator account."
                "Cancel"        = "Do nothing and exit this function."
            }) -prompt "Select a user account type:"

        Write-Host ": "  -ForegroundColor "DarkCyan" -NoNewline
        Write-Host "Running command:" -NoNewline -ForegroundColor "DarkGray"
        Write-Host " $command" -ForegroundColor "Gray"
        Write-Host

        switch ($choice) {
            0 { enable-admin }
            1 { disable-admin }
            2 { readCommand }
        }
    } catch {
        writeText -type "error" -text "toggle-admin-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function enable-admin {
    try { 
        $admin = Get-LocalUser -Name "Administrator"
        
        if ($admin.Enabled) { 
            writeText -text "Administrator account is currently enabled"
        } else { 
            Get-LocalUser -Name "Administrator" | Enable-LocalUser 
        }

        $admin = Get-LocalUser -Name "Administrator"

        if ($admin.Enabled) { 
            writeText -type "success" -text "Administrator account enabled"
        } else { 
            writeText -type "error" -text "Could not enable administrator account"
        }
    } catch {
        writeText -type "error" -text "enable-admin-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function disable-admin {
    try { 
        $admin = Get-LocalUser -Name "Administrator"
        
        if ($admin.Enabled) { 
            Get-LocalUser -Name "Administrator" | Disable-LocalUser 
        } else { 
            writeText -text "Administrator account is already disabled"
        }

        $admin = Get-LocalUser -Name "Administrator"

        if ($admin.Enabled) { 
            writeText -type "error" -text "Could not disable administrator account"
        } else { 
            writeText -type "success" -text "Administrator account disabled"
        }
    } catch {
        writeText -type "error" -text "disable-admin-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}