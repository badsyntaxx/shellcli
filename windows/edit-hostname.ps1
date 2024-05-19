function edit-hostname {
    try {
        write-welcome -Title "Edit Hostname" -Description "Edit the hostname and description of this computer." -Command "edit hostname"

        $currentHostname = $env:COMPUTERNAME
        $currentDescription = (Get-WmiObject -Class Win32_OperatingSystem).Description

        write-text -Type "header" -Text "Enter hostname" -LineBefore -LineAfter
        $hostname = get-input -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,15})$" -Value $currentHostname

        write-text -Type "header" -Text "Enter description" -LineBefore -LineAfter
        $description = get-input -Validate "^(\s*|[a-zA-Z0-9 |_\-]{1,64})$" -Value $currentDescription

        if ($hostname -eq "") { $hostname = $currentHostname } 
        if ($description -eq "") { $description = $currentDescription } 

        write-text -Type "header" -Text "YOU'RE ABOUT TO CHANGE THE COMPUTER NAME AND DESCRIPTION" -LineBefore -LineAfter
        
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

        if ($description -ne "") {
            Set-CimInstance -Query 'Select * From Win32_OperatingSystem' -Property @{Description = $description }
        } 

        exit-script -Type "success" -Text "The PC name changes have been applied. No restart required!" -LineAfter
    } catch {
        # Display error message and end the script
        exit-script -Type "error" -Text "edit-hostname-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -LineAfter
    }
}

