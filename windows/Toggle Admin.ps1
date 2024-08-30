function toggleAdmin {
    try {
        $choice = readOption -options $([ordered]@{
                "Enable admin"  = "Enable the built-in administrator account."
                "Disable admin" = "Disable the built-in administrator account."
                "Cancel"        = "Do nothing and exit this function."
            }) -prompt "Select a user account type:"

        switch ($choice) {
            0 { 
                enableAdmin 
                $command = "enable admin"
            }
            1 { 
                disableAdmin 
                $command = "disable admin"
            }
            2 { 
                readCommand 
            }
        }

        Write-Host ": "  -ForegroundColor "DarkCyan" -NoNewline
        Write-Host "Running command:" -NoNewline -ForegroundColor "DarkGray"
        Write-Host " $command" -ForegroundColor "Gray"
        Write-Host
    } catch {
        writeText -type "error" -text "toggleAdmin-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function enableAdmin {
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
        writeText -type "error" -text "enableAdmin-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function disableAdmin {
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
        writeText -type "error" -text "disableAdmin-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}