function editNetAdapter {
    try {
        selectTask
    } catch {
        writeText -type "error" -text "editNetAdapter-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function selectTask {
    $task = readOption -options $([ordered]@{
            "Enable / Disable"  = "Enable or disable a network adapter."
            "Rename"            = "Rename a network adapter."
            "Edit IP settings"  = "Set the IP schema to dynamic or static."
            "Edit DNS settings" = "Set the DNS to dynamic or static."
        }) -prompt "Select a task:"

    switch ($task) {
        0 { toggleAdapter }
        1 { renameAdapter }
        2 { changeIPSettings }
        3 { changeDNSSettings }
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
        $adapterIndex = $netAdapter.InterfaceIndex
        $script:ipv4Regex = "^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){0,4}$"

        $adapter = [ordered]@{}
        $adapter["name"] = $choice
        $adapter["self"] = Get-NetAdapter -Name $choice
        $adapter["index"] = $netAdapter.InterfaceIndex
        $adapter["status"] = $netAdapter.Status
        $interface = Get-NetIPInterface -InterfaceIndex $adapterIndex
        $ipData = Get-NetIPAddress -InterfaceIndex $adapterIndex -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -ne "WellKnown" -and $_.SuffixOrigin -ne "Link" -and ($_.AddressState -eq "Preferred" -or $_.AddressState -eq "Tentative") } | Select-Object -First 1
        $adapter["ip"] = $ipData.IPAddress
        $adapter["gateway"] = Get-NetRoute -InterfaceAlias $choice -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty "NextHop"
        $adapter["subnet"] = convertCIDRtoMask -CIDR $ipData.PrefixLength
        $adapter["dns"] = Get-DnsClientServerAddress -InterfaceIndex $adapterIndex | Select-Object -ExpandProperty ServerAddresses
        if ($interface.Dhcp -eq "Enabled") { 
            $adapter["IPDHCP"] = $true 
        } else { 
            $adapter["IPDHCP"] = $false 
        }

        getAdapterInfo -adapterName $adapter["name"]

        return $adapter
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
function getOriginalAdapterSettings {
    try {
        $adapter = selectAdapter

        # This block of code is just to get the original adapter array.
        $memoryStream = New-Object System.IO.MemoryStream
        $binaryFormatter = New-Object System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
        $binaryFormatter.Serialize($memoryStream, $adapter)
        $memoryStream.Position = 0
        $original = $binaryFormatter.Deserialize($memoryStream)
        $memoryStream.Close()

        return $original
    } catch {
        writeText -type "error" -text "getOriginalAdapterSettings-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function changeIPSettings {
    try {   
        $originalAdapter = getOriginalAdapterSettings

        $choice = readOption -options $([ordered]@{
                "Static"  = "Set this adapter to static and enter IP data manually."
                "Dynamic" = "Set this adapter to DHCP."
                "Back"    = "Go back to network adapter selection."
            }) -prompt "Set the IP scheme to static or dynamic?"

        if (2 -eq $choice) { 
            selectTask
        }

        $desiredSettings = $originalAdapter
        Get-NetAdapter -Name $originalAdapter["name"] | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute -InterfaceAlias $originalAdapter["name"] -DestinationPrefix "0.0.0.0/0" -Confirm:$false -ErrorAction SilentlyContinue

        if ($choice -eq 0) { 
            $ip = readInput -prompt "IPv4:" -Validate $ipv4Regex -Value $originalAdapter["ip"]
            $subnet = readInput -prompt "Subnet mask:" -Validate $ipv4Regex -Value $originalAdapter["subnet"]  
            $gateway = readInput -prompt "Gateway:" -Validate $ipv4Regex -Value $originalAdapter["gateway"] -lineAfter
        
            if ($ip -eq "") { 
                $ip = $originalAdapter["ip"] 
            }
            if ($subnet -eq "") { 
                $subnet = $originalAdapter["subnet"] 
            }
            if ($gateway -eq "") { 
                $gateway = $originalAdapter["gateway"] 
            }

            $desiredSettings["ip"] = $ip
            $desiredSettings["subnet"] = $subnet
            $desiredSettings["gateway"] = $gateway

            & "C:\Windows\System32\cmd.exe" /c netsh interface ipv4 set address name = "$($originalAdapter["name"])" static $desiredSettings["ip"] $desiredSettings["subnet"] $desiredSettings["gateway"] | Out-Null
            writeText -type 'success' -text "The network adapters IP, subnet, and gateway were set to static and your addresses were applied."
        }
        
        if (1 -eq $choice) { 
            Set-NetIPInterface -InterfaceIndex $originalAdapter["index"] -Dhcp Enabled  | Out-Null
            & "C:\Windows\System32\cmd.exe" /c netsh interface ipv4 set address name = "$($originalAdapter["name"])" source = dhcp | Out-Null
            writeText -type 'success' -text "The network adapters IP settings were set to dynamic"
        }

        Disable-NetAdapter -Name $originalAdapter["name"] -Confirm:$false
        Start-Sleep 1
        Enable-NetAdapter -Name $originalAdapter["name"] -Confirm:$false
    } catch {
        writeText -type "error" -text "changeIPSettings-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function changeDNSSettings {
    try {
        $originalAdapter = getOriginalAdapterSettings

        $choice = readOption -options $([ordered]@{
                "Static"  = "Set this adapters DNS to static."
                "Dynamic" = "Set this adapters DNS to DHCP."
                "Back"    = "Go back to task selection."
            }) -prompt "Set DNS to static or dynamic?"

        if (2 -eq $choice) { 
            selectTask 
        }

        Get-NetAdapter -Name $originalAdapter["name"] | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute -InterfaceAlias $originalAdapter["name"] -DestinationPrefix "0.0.0.0/0" -Confirm:$false -ErrorAction SilentlyContinue

        $dns = @()

        if ($choice -eq 0) { 
            $prompt = readInput -prompt "Enter a DNS:" -Validate $ipv4Regex
            $dns += $prompt
            while ($prompt.Length -gt 0) {
                $prompt = readInput -prompt "Enter another DNS (Leave blank to finish):" -Validate $ipv4Regex
                if ($prompt -ne "") { $dns += $prompt }
            }
            $originalAdapter["dns"] = $dns

            $dnsString = ""
            $dns = $originalAdapter['dns']

            if ($dns.Count -gt 0) { 
                $dnsString = $dns -join "," 
            } else { 
                $dnsString = $dns[0] 
            }

            Set-DnsClientServerAddress -InterfaceAlias $originalAdapter["name"] -ServerAddresses $dnsString
            writeText -type 'success' -text "The network adapters DNS was set to static and your addresses were applied."
        }

        if (1 -eq $choice) { 
            Set-DnsClientServerAddress -InterfaceAlias $originalAdapter["name"] -ResetServerAddresses | Out-Null
            writeText -type 'success' -text "The network adapters DNS settings were set to dynamic"
        }

        Disable-NetAdapter -Name $originalAdapter["name"] -Confirm:$false
        Start-Sleep 1
        Enable-NetAdapter -Name $originalAdapter["name"] -Confirm:$false
    } catch {
        writeText -type "error" -text "changeDNSSettings-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function getAdapterInfo {
    param (
        [parameter(Mandatory = $false)]
        [string]$adapterName
    )
    
    try {
        Write-Host
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
            $subnet = convertCIDRtoMask -CIDR $ipData.PrefixLength
            $dnsServers = Get-DnsClientServerAddress -InterfaceIndex $index | Select-Object -ExpandProperty ServerAddresses

            if ($status -eq "Up") {
                Write-Host "  $([char]0x2022)" -ForegroundColor "Green" -NoNewline
                Write-Host " $name | $dhcp" -ForegroundColor "Gray" 
            } else {
                Write-Host "  $([char]0x25BC)" -ForegroundColor "Red" -NoNewline
                Write-Host " $name | $dhcp" -ForegroundColor "Gray"
            }

            writeText -type "plain" -text "  MAC Address . . . : $macAddress" -Color "Gray"
            writeText -type "plain" -text "  IPv4 Address. . . : $ipAddress" -Color "Gray"
            writeText -type "plain" -text "  Subnet Mask . . . : $subnet" -Color "Gray"
            writeText -type "plain" -text "  Default Gateway . : $gateway" -Color "Gray"

            for ($i = 0; $i -lt $dnsServers.Count; $i++) {
                if ($i -eq 0) {
                    writeText -type "plain" -text "  DNS Servers . . . : $($dnsServers[$i])" -Color "Gray"
                } else {
                    writeText -type "plain" -text "                      $($dnsServers[$i])" -Color "Gray"
                }
            }
        }
        Write-Host
    } catch {
        writeText -type "error" -text "getAdapterInfo-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function convertCIDRtoMask {
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
function showAdapters {
    try {
        $adapters = @()
        foreach ($n in (Get-NetAdapter | Select-Object -ExpandProperty Name)) { $adapters += $n }
        foreach ($a in $adapters) { getAdapterInfo -adapterName $a }

        selectAdapter
    } catch {
        writeText -type "error" -text "showAdapters-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}