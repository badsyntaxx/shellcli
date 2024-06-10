function edit-hostname {
    try {
        $currentHostname = $env:COMPUTERNAME
        $currentDescription = (Get-WmiObject -Class Win32_OperatingSystem).Description

        $hostname = read-input -prompt "Enter hostname:" -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,15})$" -Value $currentHostname -lineBefore
        if ($hostname -eq "") { 
            $hostname = $currentHostname 
        } 

        $description = read-input -prompt "Enter description:" -Validate "^(\s*|[a-zA-Z0-9 |_\-]{1,64})$" -Value $currentDescription
        if ($description -eq "") { 
            $description = $currentDescription 
        } 
        
        get-closing -Script "edit-hostname"

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

        if ($env:COMPUTERNAME -eq $hostname) {
            if ($hostname -eq $currentHostname) {
                write-text -type "success" -text "The hostname will remain $hostname"
            } else {
                write-text -type "success" -text "The hostname has been changed to $hostname"
            }
        }

        if ($description -ne "") {
            Set-CimInstance -Query 'Select * From Win32_OperatingSystem' -Property @{Description = $description }
        } 

        if ((Get-WmiObject -Class Win32_OperatingSystem).Description -eq $description) {
            if ($description -eq $currentDescription) {
                write-text -type "success" -text "The description will remain $description" -lineAfter
            } else {
                write-text -type "success" -text "The description has been changed to $description" -lineAfter
            }
        }

        read-command
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "edit-hostname-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

