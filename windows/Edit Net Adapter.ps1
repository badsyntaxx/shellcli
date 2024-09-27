function editNetAdapter {
    try {
        selectTask
    } catch {
        writeText -type "error" -text "editNetAdapter-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function selectTask {
    $task = readOption -options $([ordered]@{
            "Enable / Disable"         = "Enable or disable a network adapter."
            "Rename"                   = "Rename a network adapter."
            "Set IP static / dynamic"  = "Set a network adapter to static or dynamic IP."
            "Set DNS static / dynamic" = "Set a network adapter to static or dynamic IP."
        }) -prompt "Select a task:"

    switch ($task) {
        0 { toggleAdapter }
        1 { renameAdapter }
        2 { getDesiredSettings -setting "ip" }
    }
}
function getDesiredSettings {
    param (
        [parameter(Mandatory = $true)]
        [string]$setting
    )

    try {
        $adapter = selectAdapter

        # This block of code is just to get the original adapter array.
        $memoryStream = New-Object System.IO.MemoryStream
        $binaryFormatter = New-Object System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
        $binaryFormatter.Serialize($memoryStream, $adapter)
        $memoryStream.Position = 0
        $original = $binaryFormatter.Deserialize($memoryStream)
        $memoryStream.Close()

        if ($setting -eq "ip") {
            $adapter = changeIPSettings -adapter $adapter
        } else {
            $adapter = changeDNSSettings -adapter $adapter
        }

        confirmChanges -adapter $adapter -original $original
    } catch {
        writeText -type "error" -text "getDesiredSettings-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function selectAdapter {
    param (
        [parameter(Mandatory = $false)]
        [string]$adapterName = ""
    )

    try {
        $adapters = [ordered]@{}

        Get-NetAdapter | ForEach-Object { 
            $adapters[$_.Name] = $_.MediaConnectionState 
        }

        $adapterList = [ordered]@{}

        foreach ($al in $adapters) { 
            $adapterList = $al 
        }

        if ($adapterName -ne "") {
            $choice = $adapterName
        } else {
            $choice = readOption -options $adapterList -prompt "Select a network adapter:" -returnKey
        }
        
        $netAdapter = Get-NetAdapter -Name $choice
        $netAdapter
        $adapterIndex = $netAdapter.InterfaceIndex

        $script:ipv4Regex = "^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){0,4}$"

        $ipData = Get-NetIPAddress -InterfaceIndex $adapterIndex -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -ne "WellKnown" -and $_.SuffixOrigin -ne "Link" -and ($_.AddressState -eq "Preferred" -or $_.AddressState -eq "Tentative") } | Select-Object -First 1
        $interface = Get-NetIPInterface -InterfaceIndex $adapterIndex
        $adapter = [ordered]@{}
        $adapter["name"] = $choice
        $adapter["self"] = Get-NetAdapter -Name $choice
        $adapter["index"] = $netAdapter.InterfaceIndex
        $adapter["status"] = $netAdapter.Status

        if ($netAdapter.Status -eq "Up") {
            $adapter["ip"] = $ipData.IPAddress
            $adapter["gateway"] = Get-NetRoute -InterfaceAlias $choice -DestinationPrefix "0.0.0.0/0" | Select-Object -ExpandProperty "NextHop"
            $adapter["subnet"] = convert-cidr-to-mask -CIDR $ipData.PrefixLength
            $adapter["dns"] = Get-DnsClientServerAddress -InterfaceIndex $adapterIndex | Select-Object -ExpandProperty ServerAddresses
            if ($interface.Dhcp -eq "Enabled") { 
                $adapter["IPDHCP"] = $true 
            } else { 
                $adapter["IPDHCP"] = $false 
            }
        } 
    
        getAdapterInfo -adapterName $adapter["name"]

        return $adapter

        getDesiredSettings -adapter $adapter
    } catch {
        writeText -type "error" -text "selectAdapter-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function toggleAdapter {
    $adapter = selectAdapter

    $choices = $([ordered]@{})

    if ($adapter["status"] -eq "Disabled") {
        $choices["Enable"] = "Enable this network adapter."
    } else {
        $choices["Disable"] = "Disable this network adapter."
    }

    $choices["Back" ] = "Go back to task selection."
    
    $choice = readOption -options $choices -prompt "Select an action:" -returnKey

    if ($choice -eq "Enable" -and $adapter["status"] -eq "Disabled") { 
        Get-NetAdapter | Where-Object { $_.Name -eq $adapter["name"] } | Enable-NetAdapter
    }
    if ($choice -eq "Disable" -and $adapter["status"] -ne "Disabled") { 
        Get-NetAdapter | Where-Object { $_.Name -eq $adapter["name"] } | Disable-NetAdapter
    }
    if ($choice -eq "Back") {
        selectTask
    }

    $updatedAdapter = selectAdapter -adapterName $adapter["name"]

    if ($choice -eq "Enable" -and $updatedAdapter["status"] -eq "Enabled") { 
        writeText -type "success" -text "Success the adapter was Enabled."
    }
    if ($choice -eq "Disable" -and $updatedAdapter["status"] -eq "Disabled") { 
        writeText -type "success" -text "Success the adapter was Disabled."
    }
}
function changeIPSettings {
    try {   
        $choice = readOption -options $([ordered]@{
                "Set static"  = "Set this adapter to static and enter IP data manually."
                "Set dynamic" = "Set this adapter to DHCP."
                "Back"        = "Go back to network adapter selection."
            }) -prompt "Select an action:"

        $desiredSettings = $adapter

        if ($choice -eq 0) { 
            $ip = readInput -prompt "IPv4:" -Validate $ipv4Regex -Value $adapter["ip"]
            $subnet = readInput -prompt "Subnet mask:" -Validate $ipv4Regex -Value $adapter["subnet"]  
            $gateway = readInput -prompt "Gateway:" -Validate $ipv4Regex -Value $adapter["gateway"] -lineAfter
        
            if ($ip -eq "") { $ip = $adapter["ip"] }
            if ($subnet -eq "") { $subnet = $adapter["subnet"] }
            if ($gateway -eq "") { $gateway = $adapter["gateway"] }

            $desiredSettings["ip"] = $ip
            $desiredSettings["subnet"] = $subnet
            $desiredSettings["gateway"] = $gateway
            $desiredSettings["IPDHCP"] = $false
        }

        if (1 -eq $choice) { 
            $desiredSettings["IPDHCP"] = $true
        }
        if (2 -eq $choice) { 
            selectTask
        }

        return $desiredSettings 
    } catch {
        writeText -type "error" -text "changeIPSettings-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function changeDNSSettings {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$adapter
    )

    try {
        $choice = readOption -options $([ordered]@{
                "Set DNS to static"  = "Set this adapter to static and enter DNS data manually."
                "Set DNS to dynamic" = "Set this adapter to DHCP."
                "Back"               = "Go back to network adapter selection."
            })

        $dns = @()

        if ($choice -eq 0) { 
            $prompt = readInput -prompt "Enter a DNS (Leave blank to skip)" -Validate $ipv4Regex
            $dns += $prompt
            while ($prompt.Length -gt 0) {
                $prompt = readInput -prompt "Enter another DNS (Leave blank to skip)" -Validate $ipv4Regex
                if ($prompt -ne "") { $dns += $prompt }
            }
            $adapter["dns"] = $dns
        }
        if (1 -eq $choice) { $adapter["DNSDHCP"] = $true }
        if (2 -eq $choice) { changeIPSettings }

        return $adapter
    } catch {
        writeText -type "error" -text "changeDNSSettings-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function confirmChanges {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$adapter,
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$original
    )

    try {
        $status = Get-NetAdapter -Name $adapter["name"] | Select-Object -ExpandProperty Status
        if ($status -eq "Up") {
            Write-Host "  $([char]0x2022)" -ForegroundColor "Green" -NoNewline
            Write-Host " $($original["name"])" -ForegroundColor "Gray"
        } else {
            Write-Host "  $([char]0x25BC)" -ForegroundColor "Red" -NoNewline
            Write-Host " $($original["name"])" -ForegroundColor "Gray"
        }

        if ($adapter["IPDHCP"]) {
            write-compare -oldData "IPv4 Address. . . : $($original["ip"])" -newData "Dynamic"
            write-compare -oldData "Subnet Mask . . . : $($original["subnet"])" -newData "Dynamic"
            write-compare -oldData "Default Gateway . : $($original["gateway"])" -newData "Dynamic"
        } else {
            write-compare -oldData "IPv4 Address. . . : $($original["ip"])" -newData $($adapter['ip'])
            write-compare -oldData "Subnet Mask . . . : $($original["subnet"])" -newData $($adapter['subnet'])
            write-compare -oldData "Default Gateway . : $($original["gateway"])" -newData $($adapter['gateway'])
        }

        $originalDNS = $original["dns"]
        $newDNS = $adapter["dns"]
        $count = 0
        if ($originalDNS.Count -gt $newDNS.Count) {
            $count = $originalDNS.Count
        } else {
            $count = $newDNS.Count
        }
    
        if ($adapter["DNSDHCP"]) {
            for ($i = 0; $i -lt $count; $i++) {
                if ($i -eq 0) {
                    write-compare -oldData "DNS Servers . . . : $($originalDNS[$i])" -newData "Dynamic"
                } else {
                    write-compare -oldData "                    $($originalDNS[$i])" -newData "Dynamic"
                }
            }
        } else {
            for ($i = 0; $i -lt $count; $i++) {
                if ($i -eq 0) {
                    write-compare -oldData "DNS Servers . . . : $($originalDNS[$i])" -newData $($newDNS[$i])
                } else {
                    write-compare -oldData "                    $($originalDNS[$i])" -newData $($newDNS[$i])
                }
            }
        }


        $dnsString = ""
    
        $dns = $adapter['dns']

        if ($dns.Count -gt 0) { $dnsString = $dns -join ", " } 
        else { $dnsString = $dns[0] }

        Get-NetAdapter -Name $adapter["name"] | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute -InterfaceAlias $adapter["name"] -DestinationPrefix 0.0.0.0 / 0 -Confirm:$false -ErrorAction SilentlyContinue

        if ($adapter["IPDHCP"]) {
            Set-NetIPInterface -InterfaceIndex $adapterIndex -Dhcp Enabled  | Out-Null
            netsh interface ipv4 set address name = "$($adapter["name"])" source = dhcp | Out-Null
            writeText -type 'success' -text "The network adapters IP settings were set to dynamic"
        } else {
            writeText "Disabling DHCP and applying static addresses." 
            netsh interface ipv4 set address name = "$($adapter["name"])" static $adapter["ip"] $adapter["subnet"] $adapter["gateway"] | Out-Null
            writeText -type 'success' -text "The network adapters IP, subnet, and gateway were set to static and your addresses were applied."
        }

        if ($adapter["DNSDHCP"]) {
            Set-DnsClientServerAddress -InterfaceAlias $adapter["name"] -ResetServerAddresses | Out-Null
            writeText -type 'success' -text "The network adapters DNS settings were set to dynamic"
        } else {
            writeText "Disabling DHCP and applying static addresses."
            Set-DnsClientServerAddress -InterfaceAlias $adapter["name"] -ServerAddresses $dnsString
            writeText -type 'success' -text "The network adapters DNS was set to static and your addresses were applied."
        }

        Disable-NetAdapter -Name $adapter["name"] -Confirm:$false
        Start-Sleep 1
        Enable-NetAdapter -Name $adapter["name"] -Confirm:$false

        readCommand
    } catch {
        writeText -type "error" -text "confirmChanges-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function getAdapterInfo {
    param (
        [parameter(Mandatory = $false)]
        [string]$adapterName
    )
    
    try {
        $status = Get-NetAdapter -Name $adapterName | Select-Object -ExpandProperty Status
        if ($status -ne "Disabled") {
            $macAddress = Get-NetAdapter -Name $adapterName | Select-Object -ExpandProperty MacAddress
            $name = Get-NetAdapter -Name $adapterName | Select-Object -ExpandProperty Name
            $status = Get-NetAdapter -Name $adapterName | Select-Object -ExpandProperty Status
            $index = Get-NetAdapter -Name $adapterName | Select-Object -ExpandProperty InterfaceIndex
            $gateway = Get-NetIPConfiguration -InterfaceAlias $adapterName | ForEach-Object { $_.IPv4DefaultGateway.NextHop }
            # $gateway = Get-NetRoute -InterfaceAlias $adapterName -DestinationPrefix "0.0.0.0/0" | Select-Object -ExpandProperty "NextHop"
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

            writeText "  MAC Address . . . : $macAddress" -Color "Gray"
            writeText "  IPv4 Address. . . : $ipAddress" -Color "Gray"
            writeText "  Subnet Mask . . . : $subnet" -Color "Gray"
            writeText "  Default Gateway . : $gateway" -Color "Gray"

            for ($i = 0; $i -lt $dnsServers.Count; $i++) {
                if ($i -eq 0) {
                    writeText "  DNS Servers . . . : $($dnsServers[$i])" -Color "Gray"
                } else {
                    writeText "                    $($dnsServers[$i])" -Color "Gray"
                }
            }
        }
    } catch {
        writeText -type "error" -text "getAdapterInfo-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
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
        foreach ($a in $adapters) { getAdapterInfo -adapterName $a }

        selectAdapter
    } catch {
        writeText -type "error" -text "show-adapters-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}