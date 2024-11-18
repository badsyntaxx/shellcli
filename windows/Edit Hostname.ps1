function editHostname {
    try {
        $currentHostname = $env:COMPUTERNAME
        $currentDescription = (Get-WmiObject -Class Win32_OperatingSystem).Description
        $hostname = readInput -prompt "Enter the desired hostname:" -Validate "^(\s*|[a-zA-Z0-9 _\-?]{1,15})$" -Value $currentHostname
        $description = readInput -prompt "Enter a desired description:" -Validate "^(\s*|[a-zA-Z0-9[\] |_\-?]{1,64})$" -Value $currentDescription
        
        if ($hostname -eq "") { 
            $hostname = $currentHostname 
        } 
        if ($description -eq "") { 
            $description = $currentDescription 
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

        if ($description -ne "") {
            Set-CimInstance -Query 'Select * From Win32_OperatingSystem' -Property @{Description = $description }
        } 

        $hostnameChanged = $currentHostname -ne $env:COMPUTERNAME
        $descriptionChanged = $currentDescription -ne (Get-WmiObject -Class Win32_OperatingSystem).Description

        $response = ""

        if ($hostnameChanged -and $descriptionChanged) {
            $response = "Hostname and description updated."
        } elseif ($hostnameChanged) {
            $response = "Hostname updated."
        } elseif ($descriptionChanged) {
            $response = "Description updated."
        } else {
            $response = "Hostname and description unchanged."
        }

        writeText -type "success" -text $response
    } catch {
        writeText -type "error" -text "editHostname-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
