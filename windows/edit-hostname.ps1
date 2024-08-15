function edit-hostname {
    try {
        $currentHostname = $env:COMPUTERNAME
        $currentDescription = (Get-WmiObject -Class Win32_OperatingSystem).Description
        $hostname = read-input -prompt "Enter the desired hostname." -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,15})$" -Value $currentHostname -lineBefore
        $description = read-input -prompt "Enter a desired description. (Optional)" -Validate "^(\s*|[a-zA-Z0-9 |_\-]{1,64})$" -Value $currentDescription
        
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

        if ($env:COMPUTERNAME -eq $hostname -and (Get-WmiObject -Class Win32_OperatingSystem).Description -eq $description) {
            write-text -type "success" -text "Hostname & description changed" -lineBefore
        }
        
        write-text -label "Hostname" -text $env:COMPUTERNAME -lineBefore
        write-text -label "Description" -text (Get-WmiObject -Class Win32_OperatingSystem).Description -lineAfter

        read-command
    } catch {
        # Display error message and exit this script
        write-text -type "error" -text "edit-hostname-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
        read-command
    }
}
