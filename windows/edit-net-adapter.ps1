function edit-net-adapter {
    try {
        select-adapter
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "edit-net-adapter-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
    
}

function select-adapter {
    try {
        $adapters = [ordered]@{}
        Get-NetAdapter | ForEach-Object { $adapters[$_.Name] = $_.MediaConnectionState }
        $adapterList = [ordered]@{}
        foreach ($al in $adapters) { $adapterList = $al }
        $choice = read-option -options $adapterList -lineAfter -returnKey
        $netAdapter = Get-NetAdapter -Name $choice
        $adapterIndex = $netAdapter.InterfaceIndex
        $ipData = Get-NetIPAddress -InterfaceIndex $adapterIndex -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -ne "WellKnown" -and $_.SuffixOrigin -ne "Link" -and ($_.AddressState -eq "Preferred" -or $_.AddressState -eq "Tentative") } | Select-Object -First 1
        $interface = Get-NetIPInterface -InterfaceIndex $adapterIndex

        $script:ipv4Regex = "^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){0,4}$"

        $adapter = [ordered]@{
            "name"    = $choice
            "self"    = Get-NetAdapter -Name $choice
            "index"   = $netAdapter.InterfaceIndex
            "ip"      = $ipData.IPAddress
            "gateway" = Get-NetRoute -InterfaceAlias $choice -DestinationPrefix "0.0.0.0/0" | Select-Object -ExpandProperty "NextHop"
            "subnet"  = convert-cidr-to-mask -CIDR $ipData.PrefixLength
            "dns"     = Get-DnsClientServerAddress -InterfaceIndex $adapterIndex | Select-Object -ExpandProperty ServerAddresses
            "IPDHCP"  = if ($interface.Dhcp -eq "Enabled") { $true } else { $false }
        }

        get-desiredsettings -Adapter $adapter
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "select-adapter-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

function get-desiredsettings {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Adapter
    )

    try {
        get-adapter-info -AdapterName $Adapter["name"]

        # This block of code is just to get the original adapter array.
        $memoryStream = New-Object System.IO.MemoryStream
        $binaryFormatter = New-Object System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
        $binaryFormatter.Serialize($memoryStream, $Adapter)
        $memoryStream.Position = 0
        $Original = $binaryFormatter.Deserialize($memoryStream)
        $memoryStream.Close()

        $Adapter = read-ipsettings -Adapter $Adapter
        $Adapter = read-dnssettings -Adapter $Adapter

        confirm-edits -Adapter $Adapter -Original $Original
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "get-desired-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

function read-ipsettings {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Adapter
    )

    try {
        $choice = read-option -options $([ordered]@{
                "Set IP to static" = "Set this adapter to static and enter IP data manually."
                "Set IP to DHCP"   = "Set this adapter to DHCP."
                "Back"             = "Go back to network adapter selection."
            }) -lineAfter

        $desiredSettings = $Adapter

        if ($choice -eq 0) { 
            $ip = read-input -prompt "IPv4:" -Validate $ipv4Regex -Value $Adapter["ip"]
            $subnet = read-input -prompt "Subnet mask:" -Validate $ipv4Regex -Value $Adapter["subnet"]  
            $gateway = read-input -prompt "Gateway:" -Validate $ipv4Regex -Value $Adapter["gateway"] -lineAfter
        
            if ($ip -eq "") { $ip = $Adapter["ip"] }
            if ($subnet -eq "") { $subnet = $Adapter["subnet"] }
            if ($gateway -eq "") { $gateway = $Adapter["gateway"] }

            $desiredSettings["ip"] = $ip
            $desiredSettings["subnet"] = $subnet
            $desiredSettings["gateway"] = $gateway
            $desiredSettings["IPDHCP"] = $false
        }

        if (1 -eq $choice) { $desiredSettings["IPDHCP"] = $true }
        if (2 -eq $choice) { select-adapter }

        return $desiredSettings 
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "read-ipsettings-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

function read-dnssettings {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Adapter
    )

    try {
        $choice = read-option -options $([ordered]@{
                "Set DNS to static"  = "Set this adapter to static and enter DNS data manually."
                "Set DNS to dynamic" = "Set this adapter to DHCP."
                "Back"               = "Go back to network adapter selection."
            }) -lineAfter

        $dns = @()

        if ($choice -eq 0) { 
            $prompt = read-input -prompt "Enter a DNS (Leave blank to skip)" -Validate $ipv4Regex
            $dns += $prompt
            while ($prompt.Length -gt 0) {
                $prompt = read-input -prompt "Enter another DNS (Leave blank to skip)" -Validate $ipv4Regex
                if ($prompt -ne "") { $dns += $prompt }
            }
            $Adapter["dns"] = $dns
        }
        if (1 -eq $choice) { $Adapter["DNSDHCP"] = $true }
        if (2 -eq $choice) { read-ipsettings }

        return $Adapter
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "read-dnssettings-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

function confirm-edits {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Adapter,
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Original
    )

    try {
        write-text -type "label" -text "Confirm your changes"  -lineAfter

        $status = Get-NetAdapter -Name $Adapter["name"] | Select-Object -ExpandProperty Status
        if ($status -eq "Up") {
            Write-Host "  $([char]0x2022)" -ForegroundColor "Green" -NoNewline
            Write-Host " $($Original["name"])" -ForegroundColor "Gray"
        } else {
            Write-Host "  $([char]0x25BC)" -ForegroundColor "Red" -NoNewline
            Write-Host " $($Original["name"])" -ForegroundColor "Gray"
        }

        if ($Adapter["IPDHCP"]) {
            write-text -type "compare" -oldData "IPv4 Address. . . : $($Original["ip"])" -newData "Dynamic"
            write-text -type "compare" -oldData "Subnet Mask . . . : $($Original["subnet"])" -newData "Dynamic"
            write-text -type "compare" -oldData "Default Gateway . : $($Original["gateway"])" -newData "Dynamic"
        } else {
            write-text -type "compare" -oldData "IPv4 Address. . . : $($Original["ip"])" -newData $($Adapter['ip'])
            write-text -type "compare" -oldData "Subnet Mask . . . : $($Original["subnet"])" -newData $($Adapter['subnet'])
            write-text -type "compare" -oldData "Default Gateway . : $($Original["gateway"])" -newData $($Adapter['gateway'])
        }

        $originalDNS = $Original["dns"]
        $newDNS = $Adapter["dns"]
        $count = 0
        if ($originalDNS.Count -gt $newDNS.Count) {
            $count = $originalDNS.Count
        } else {
            $count = $newDNS.Count
        }
    
        if ($Adapter["DNSDHCP"]) {
            for ($i = 0; $i -lt $count; $i++) {
                if ($i -eq 0) {
                    write-text -type "compare" -oldData "DNS Servers . . . : $($originalDNS[$i])" -newData "Dynamic"
                } else {
                    write-text -type "compare" -oldData "                    $($originalDNS[$i])" -newData "Dynamic"
                }
            }
        } else {
            for ($i = 0; $i -lt $count; $i++) {
                if ($i -eq 0) {
                    write-text -type "compare" -oldData "DNS Servers . . . : $($originalDNS[$i])" -newData $($newDNS[$i])
                } else {
                    write-text -type "compare" -oldData "                    $($originalDNS[$i])" -newData $($newDNS[$i])
                }
            }
        }

        $choice = read-option -options $([ordered]@{
                "Submit & apply" = "Submit your changes and apply them to the system." 
                "Start over"     = "Start this function over at the beginning."
                "Other options"  = "Discard changes and do something else."
            })  -lineAfter

        if ($choice -ne 0 -and $choice -ne 2) { invoke-script -script "Edit-NetAdapter" }
        if ($choice -eq 2) { write-text }

        $dnsString = ""
    
        $dns = $Adapter['dns']

        if ($dns.Count -gt 0) { $dnsString = $dns -join ", " } 
        else { $dnsString = $dns[0] }

        Get-NetAdapter -Name $adapter["name"] | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute -InterfaceAlias $adapter["name"] -DestinationPrefix 0.0.0.0 / 0 -Confirm:$false -ErrorAction SilentlyContinue

        if ($Adapter["IPDHCP"]) {
            write-text "Enabling DHCP for IPv4." 
            Set-NetIPInterface -InterfaceIndex $adapterIndex -Dhcp Enabled  | Out-Null
            netsh interface ipv4 set address name = "$($adapter["name"])" source = dhcp | Out-Null
            write-text -type 'success' -text "The network adapters IP settings were set to dynamic"
        } else {
            write-text "Disabling DHCP and applying static addresses." 
            netsh interface ipv4 set address name = "$($adapter["name"])" static $Adapter["ip"] $Adapter["subnet"] $Adapter["gateway"] | Out-Null
            write-text -type 'success' -text "The network adapters IP, subnet, and gateway were set to static and your addresses were applied."
        }

        if ($Adapter["DNSDHCP"]) {
            write-text "Enabling DHCP for DNS."
            Set-DnsClientServerAddress -InterfaceAlias $Adapter["name"] -ResetServerAddresses | Out-Null
            write-text -type 'success' -text "The network adapters DNS settings were set to dynamic"
        } else {
            write-text "Disabling DHCP and applying static addresses."
            Set-DnsClientServerAddress -InterfaceAlias $Adapter["name"] -ServerAddresses $dnsString
            write-text -type 'success' -text "The network adapters DNS was set to static and your addresses were applied."
        }

        Disable-NetAdapter -Name $Adapter["name"] -Confirm:$false
        Start-Sleep 1
        Enable-NetAdapter -Name $Adapter["name"] -Confirm:$false

        exit-script -type "success" -text "Your settings have been applied."
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "confirm-edits-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

function get-adapter-info {
    param (
        [parameter(Mandatory = $false)]
        [string]$AdapterName
    )
    
    try {
        $status = Get-NetAdapter -Name $AdapterName | Select-Object -ExpandProperty Status
        if ($status -ne "Disabled") {
            $macAddress = Get-NetAdapter -Name $AdapterName | Select-Object -ExpandProperty MacAddress
            $name = Get-NetAdapter -Name $AdapterName | Select-Object -ExpandProperty Name
            $status = Get-NetAdapter -Name $AdapterName | Select-Object -ExpandProperty Status
            $index = Get-NetAdapter -Name $AdapterName | Select-Object -ExpandProperty InterfaceIndex
            $gateway = Get-NetIPConfiguration -InterfaceAlias $adapterName | ForEach-Object { $_.IPv4DefaultGateway.NextHop }
            # $gateway = Get-NetRoute -InterfaceAlias $AdapterName -DestinationPrefix "0.0.0.0/0" | Select-Object -ExpandProperty "NextHop"
            $interface = Get-NetIPInterface -InterfaceIndex $index 
            $dhcp = $(if ($interface.Dhcp -eq "Enabled") { "DHCP" } else { "Static" })
            $ipData = Get-NetIPAddress -InterfaceIndex $index -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -ne "WellKnown" -and $_.SuffixOrigin -ne "Link" -and ($_.AddressState -eq "Preferred" -or $_.AddressState -eq "Tentative") } | Select-Object -First 1
            $ipAddress = $ipData.IPAddress
            $subnet = convert-cidr-to-mask -CIDR $ipData.PrefixLength
            $dnsServers = Get-DnsClientServerAddress -InterfaceIndex $index | Select-Object -ExpandProperty ServerAddresses

            if ($status -eq "Up") {
                Write-Host "  $([char]0x2022)" -ForegroundColor "Green" -NoNewline
                Write-Host " $name | $dhcp" -ForegroundColor "Gray" 
            } else {
                Write-Host "  $([char]0x25BC)" -ForegroundColor "Red" -NoNewline
                Write-Host " $name | $dhcp" -ForegroundColor "Gray"
            }

            write-text "MAC Address . . . : $macAddress" -Color "Gray"
            write-text "IPv4 Address. . . : $ipAddress" -Color "Gray"
            write-text "Subnet Mask . . . : $subnet" -Color "Gray"
            write-text "Default Gateway . : $gateway" -Color "Gray"

            for ($i = 0; $i -lt $dnsServers.Count; $i++) {
                if ($i -eq 0) {
                    write-text "DNS Servers . . . : $($dnsServers[$i])" -Color "Gray"
                } else {
                    write-text "                    $($dnsServers[$i])" -Color "Gray"
                }
            }
        }
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "get-adapter-info-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

function convert-cidr-to-mask {
    param (
        [parameter(Mandatory = $false)]
        [int]$CIDR
    )

    switch ($CIDR) {
        8 { $mask = "255.0.0.0" }
        9 { $mask = "255.128.0.0" }
        10 { $mask = "255.192.0.0" }
        11 { $mask = "255.224.0.0" }
        12 { $mask = "255.240.0.0" }
        13 { $mask = "255.248.0.0" }
        14 { $mask = "255.252.0.0" }
        15 { $mask = "255.254.0.0" }
        16 { $mask = "255.255.0.0" }
        17 { $mask = "255.255.128.0" }
        18 { $mask = "255.255.192.0" }
        19 { $mask = "255.255.224.0" }
        20 { $mask = "255.255.240.0" }
        21 { $mask = "255.255.248.0" }
        22 { $mask = "255.255.252.0" }
        23 { $mask = "255.255.254.0" }
        24 { $mask = "255.255.255.0" }
        25 { $mask = "255.255.255.128" }
        26 { $mask = "255.255.255.192" }
        27 { $mask = "255.255.255.224" }
        28 { $mask = "255.255.255.240" }
        29 { $mask = "255.255.255.248" }
        30 { $mask = "255.255.255.252" }
        31 { $mask = "255.255.255.254" }
        32 { $mask = "255.255.255.255" }
    }

    return $mask
}

function show-adapters {
    try {
        $adapters = @()
        foreach ($n in (Get-NetAdapter | Select-Object -ExpandProperty Name)) { $adapters += $n }
        foreach ($a in $adapters) { get-adapter-info -AdapterName $a }

        select-adapter
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "show-adapters-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
    
}
