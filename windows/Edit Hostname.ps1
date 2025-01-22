function editHostname {
    try {
        $currentHostname = $env:COMPUTERNAME
        $hostname = readInput -prompt "Enter the desired hostname:" -Validate "^(\s*|[a-zA-Z0-9 _\-?]{1,15})$" -Value $currentHostname
        
        if ($hostname -eq "") { 
            $hostname = $currentHostname 
        } 

        if ($hostname -ne "") {
            Remove-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "Hostname" 
            Remove-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "NV Hostname" 
            Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\Computername\Computername" -name "Computername" -value $hostname
            Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\Computername\ActiveComputername" -name "Computername" -value $hostname
            Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "Hostname" -value $hostname
            Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "NV Hostname" -value  $hostname
            Set-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -name "AltDefaultDomainName" -value $hostname
            Set-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -name "DefaultDomainName" -value $hostname
            $env:COMPUTERNAME = $hostname
        } 


        $hostnameChanged = $currentHostname -ne $env:COMPUTERNAME

        if ($hostnameChanged) {
            writeText -type "success" -text "Hostname changed."
        } else {
            writeText -type "error" -text "Hostname unchanged."
        }

        $choice = readOption -options $([ordered]@{
                "Yes" = "Change the description of the PC."
                "No"  = "Do not change the description of the PC."
            }) -prompt "Do you also want to change the computer description?"

        switch ($choice) {
            0 { editDescription }
            1 { readCommand }
        }
    } catch {
        writeText -type "error" -text "editHostname-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}

function editDescription {
    try {
        $currentDescription = (Get-WmiObject -Class Win32_OperatingSystem).Description
        $description = readInput -prompt "Enter a desired description:" -Validate "^(\s*|[a-zA-Z0-9[\] |_\-?]{1,64})$" -Value $currentDescription
        
        if ($description -eq "") { 
            $description = $currentDescription 
        } 

        if ($description -ne "") {
            Set-CimInstance -Query 'Select * From Win32_OperatingSystem' -Property @{Description = $description }
        } 

        $descriptionChanged = $currentDescription -ne (Get-WmiObject -Class Win32_OperatingSystem).Description

        if ($descriptionChanged) {
            writeText -type "success" -text "Description changed."
        } else {
            writeText -type "success" -text "Description unchanged."
        }
    } catch {
        writeText -type "error" -text "editDescription-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}