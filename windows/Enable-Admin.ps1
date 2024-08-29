function Enable-Admin {
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
                "Cancel"  = "Do nothing and exit this function."
            }) -prompt "Turn the account on or off?"

        switch ($choice) {
            0 { Get-LocalUser -Name "Administrator" | Enable-LocalUser }
            1 { Get-LocalUser -Name "Administrator" | Disable-LocalUser }
            Default { read-command }
        }

        $admin = Get-LocalUser -Name "Administrator"
        if ($admin.Enabled) { 
            write-text -type "success" -text "Account enabled"
        } else { 
            write-text -type "success" -text "Account disabled"
        }
    } catch {
        write-text -type "error" -text "Enable-Admin-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}