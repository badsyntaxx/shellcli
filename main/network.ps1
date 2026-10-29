function editNetAdapter {
    try {
        selectTask
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function selectTask {
    $task = readOption -options $([ordered]@{
            "Enable / Disable"  = "Enable or disable a network adapter."
            "Rename"            = "Rename a network adapter."
            "Edit IP settings"  = "Set the IP schema to dynamic or static."
            "Edit DNS settings" = "Set the DNS to dynamic or static."
            "Exit"              = "Exit back to command line."
        }) -prompt "Select a task:" -lineAfter

    switch ($task) {
        0 { toggleAdapter }
        1 { renameAdapter }
        2 { changeIPSettings }
        3 { changeDNSSettings }
        4 { readCommand }
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
            $choice = readOption -options $adapterList -prompt "Select a network adapter:" -returnKey -lineAfter
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
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
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
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
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
            
            $updatedAdapter = selectAdapter -adapterName $originalAdapter["name"]

            if ($originalAdapter["ip"] -eq $updatedAdapter["ip"]) {
                writeText -type "plain" -text "IP updated."
            } else {
                writeText -type "plain" -text "IP not updated."
            }

            if ($originalAdapter["subnet"] -eq $updatedAdapter["subnet"]) {
                writeText -type "plain" -text "Subnet updated."
            } else {
                writeText -type "plain" -text "Subnet not updated."
            }

            if ($originalAdapter["gateway"] -eq $updatedAdapter["gateway"]) {
                writeText -type "plain" -text "Gateway updated."
            } else {
                writeText -type "plain" -text "Gateway not updated."
            }

            if ($originalAdapter["ip"] -eq $updatedAdapter["ip"] -and $originalAdapter["subnet"] -eq $updatedAdapter["subnet"] -and $originalAdapter["gateway"] -eq $updatedAdapter["gateway"]) {
                writeText -type 'success' -text "The network adapters IP, subnet, and gateway were set to static and your addresses were applied."
            } else {
                writeText -type "error" -text "Something went wrong and not all values were updated."
            }
        }
        
        if (1 -eq $choice) { 
            Set-NetIPInterface -InterfaceIndex $originalAdapter["index"] -Dhcp Enabled  | Out-Null
            & "C:\Windows\System32\cmd.exe" /c netsh interface ipv4 set address name = "$($originalAdapter["name"])" source = dhcp | Out-Null

            # Verify DHCP settings
            $verifyDHCP = Get-NetIPInterface -InterfaceAlias $originalAdapter["name"] -AddressFamily IPv4
            if ($verifyDHCP.Dhcp -eq "Enabled") {
                writeText -type 'success' -text "The network adapter's IP settings were successfully set to dynamic (DHCP)."
            } else {
                writeText -type 'error' -text "Failed to set DHCP. Please check the configuration manually."

            }

            # writeText -type 'success' -text "The network adapters IP settings were set to dynamic"
        }

        Disable-NetAdapter -Name $originalAdapter["name"] -Confirm:$false
        Start-Sleep 1
        Enable-NetAdapter -Name $originalAdapter["name"] -Confirm:$false
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
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
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
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
            $subnet = convertCIDRtoMask -CIDR $ipData.PrefixLength
            $dnsServers = Get-DnsClientServerAddress -InterfaceIndex $index | Select-Object -ExpandProperty ServerAddresses

            if ($status -eq "Up") {
                Write-Host
                Write-Host "$([char]0x2022)" -ForegroundColor "Green" -NoNewline
                Write-Host " $name | $dhcp" -ForegroundColor "Gray" 
            } else {
                Write-Host
                Write-Host "$([char]0x25BC)" -ForegroundColor "Red" -NoNewline
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
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
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
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function getWifiCreds {
    try {
        $wifiProfiles = netsh wlan show profiles
        if ($wifiProfiles -match "There is no wireless interface on the system.") {
            writeText -type "error" -text "There is no wireless interface on the system." -lineBefore -lineAfter
            return
        }

        if ((Get-Service wlansvc).Status -ne "Running") {
            writeText -type "notice" -text "The wlansvc service is not running or the wireless adapter is disabled." -lineBefore -lineAfter
            return
        }

        if ($wifiProfiles.Count -gt 0) {
            $wifiList = ($wifiProfiles | Select-String -Pattern "\w*All User Profile.*: (.*)" -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value }
        } else {
            writeText -type "error" -text "No WiFi profiles found." -lineBefore -lineAfter
            return
        }

        writeText -type "prompt" -text "Found $($wifiList.Count) Wi-Fi Connection settings stored on the system"

        foreach ($ssid in $wifiList) {
            try {
                $password = (netsh wlan show profile name="$ssid" key=clear | Select-String -Pattern ".*Key Content.*: (.*)" -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value }
            } catch {
                $password = "N/A"
            }

            Write-Host
            Write-Host "  ${ssid}: " -NoNewLine  -ForegroundColor Cyan
            Write-Host "$password"
        }
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function getWifiAdapters {
    <# The physical Wi-Fi (802.11) adapters, enabled or not. #>
    return @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { "$($_.PhysicalMediaType)" -match '802\.11' })
}
function invokeNetshWlan {
    <#
        Runs "netsh wlan ..." directly (not through cmd.exe, so no shell characters in a
        name can do anything). The password is never an argument: it goes in a file.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$arguments
    )

    $output = & netsh.exe wlan @arguments 2>&1
    $exitCode = $LASTEXITCODE

    return [pscustomobject]@{ ExitCode = $exitCode; Output = (($output | ForEach-Object { "$_" }) -join "`n") }
}
function getWifiInterfaceSsid {
    <#
        The network this adapter is connected to, or $null. Read from "netsh wlan show
        interfaces" by matching the adapter's GUID and the SSID line: those two labels
        are not translated on other display languages (State, Name and so on are).
    #>
    param (
        [Parameter(Mandatory = $true)]
        $adapter
    )

    $result = invokeNetshWlan -arguments @("show", "interfaces")
    $guid = "$($adapter.InterfaceGuid)".Trim("{", "}")
    $current = $null

    foreach ($line in ($result.Output -split "`r?`n")) {
        if ($line -match '^\s*GUID\s*:\s*\{?([0-9a-fA-F-]{36})\}?\s*$') {
            $current = $Matches[1]
            continue
        }
        if ($current -and $current -ieq $guid -and $line -match '^\s*SSID\s*:\s?(.*)$') {
            return $Matches[1]
        }
    }

    return $null
}
function getVisibleWifiNetworks {
    <# Names of the networks this adapter can see ("SSID 1 : name" lines). #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$interfaceName
    )

    $result = invokeNetshWlan -arguments @("show", "networks", "interface=$interfaceName")
    $names = @()

    foreach ($line in ($result.Output -split "`r?`n")) {
        if ($line -match '^\s*SSID\s+\d+\s*:\s?(.*)$') { $names += $Matches[1] }
    }

    return $names
}
function getWifiProfileSecurity {
    <#
        $null if no saved profile has this name. Otherwise how it signs in: Authentication
        (open, WPA2PSK, WPA3SAE, WPA2 for enterprise ...) and UseOneX. Read from an export
        made without the key, in a private folder that is removed again.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$name
    )

    $found = invokeNetshWlan -arguments @("show", "profile", "name=$name")
    if ($found.ExitCode -ne 0) { return $null }

    $folder = Join-Path (getConfigPath -name temp) "wifi-$([guid]::NewGuid().ToString('N'))"
    $unknown = [pscustomobject]@{ Authentication = "Unknown"; UseOneX = $true }

    try {
        [void][System.IO.Directory]::CreateDirectory($folder)
        $export = invokeNetshWlan -arguments @("export", "profile", "name=$name", "folder=$folder")
        $file = @(Get-ChildItem -LiteralPath $folder -Filter "*.xml" -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($export.ExitCode -ne 0 -or $file.Count -eq 0) { return $unknown }

        $xml = [xml](Get-Content -LiteralPath $file[0].FullName -Raw -ErrorAction Stop)
        $security = $xml.WLANProfile.MSM.security
        if ($null -eq $security -or $null -eq $security.authEncryption) { return $unknown }

        return [pscustomobject]@{
            Authentication = "$($security.authEncryption.authentication)"
            UseOneX        = ("$($security.authEncryption.useOneX)" -eq "true") -or ($null -ne $security.OneX)
        }
    } catch {
        return $unknown
    } finally {
        Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
    }
}
function testWifiSsid {
    <# Returns what is wrong with this network name, or $null if it is usable. #>
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$ssid
    )

    if ($ssid.Trim().Length -eq 0) { return "The network name cannot be blank." }
    if ([System.Text.Encoding]::UTF8.GetByteCount($ssid) -gt 32) { return "A network name can be at most 32 bytes long." }
    if ($ssid -match '[\x00-\x1F\x7F]') { return "The network name contains a control character." }
    # These would change what netsh is asked to do.
    if ($ssid.Contains('"')) { return "ShellCLI cannot connect to a network whose name contains a double quote." }
    if ($ssid.EndsWith("\")) { return "ShellCLI cannot connect to a network whose name ends with a backslash." }

    return $null
}
function testWifiPassword {
    <# Returns what is wrong with this Wi-Fi password, or $null if it is usable. #>
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$password
    )

    if ($password -match '[\x00-\x1F\x7F]') { return "The password contains a control character." }

    # A passphrase is 8 to 63 characters; a raw key is exactly 64 hexadecimal digits.
    $bytes = [System.Text.Encoding]::UTF8.GetByteCount($password)
    if (($bytes -lt 8 -or $bytes -gt 63) -and $password -notmatch '^[0-9a-fA-F]{64}$') {
        return "A Wi-Fi password is 8 to 63 characters (or exactly 64 hexadecimal digits)."
    }

    return $null
}
function newWifiProfileXml {
    <#
        The Windows Wi-Fi profile for this network. open, WPA2PSK (WPA2-Personal) or
        WPA3SAE (WPA3-Personal). A 64 digit hexadecimal password is a raw key rather than a
        passphrase. Everything typed is XML-escaped.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$ssid,
        [Parameter(Mandatory = $false)]
        [string]$password = "",
        [Parameter(Mandatory = $true)]
        [ValidateSet("open", "WPA2PSK", "WPA3SAE")]
        [string]$authentication,
        [Parameter(Mandatory = $false)]
        [bool]$hidden = $false
    )

    $name = [System.Security.SecurityElement]::Escape($ssid)
    $nonBroadcast = "$hidden".ToLowerInvariant()

    if ($authentication -eq "open") {
        $security = "<authEncryption><authentication>open</authentication><encryption>none</encryption><useOneX>false</useOneX></authEncryption>"
    } else {
        $keyType = "passPhrase"
        if ($password -match '^[0-9a-fA-F]{64}$') { $keyType = "networkKey" }
        $key = [System.Security.SecurityElement]::Escape($password)
        $security = "<authEncryption><authentication>$authentication</authentication><encryption>AES</encryption><useOneX>false</useOneX></authEncryption>" +
        "<sharedKey><keyType>$keyType</keyType><protected>false</protected><keyMaterial>$key</keyMaterial></sharedKey>"
    }

    return "<?xml version=`"1.0`"?>" +
    "<WLANProfile xmlns=`"http://www.microsoft.com/networking/WLAN/profile/v1`">" +
    "<name>$name</name>" +
    "<SSIDConfig><SSID><name>$name</name></SSID><nonBroadcast>$nonBroadcast</nonBroadcast></SSIDConfig>" +
    "<connectionType>ESS</connectionType><connectionMode>auto</connectionMode>" +
    "<MSM><security>$security</security></MSM>" +
    "</WLANProfile>"
}
function waitForWifiConnection {
    <# True once the adapter is up and connected to exactly this network. #>
    param (
        [Parameter(Mandatory = $true)]
        $adapter,
        [Parameter(Mandatory = $true)]
        [string]$ssid,
        [Parameter(Mandatory = $false)]
        [int]$seconds = 15
    )

    for ($i = 0; $i -lt $seconds; $i++) {
        Start-Sleep -Seconds 1

        $current = getWifiInterfaceSsid -adapter $adapter
        if ($null -ne $current -and $current -ceq $ssid) {
            $status = "$((Get-NetAdapter -Name $adapter.Name -ErrorAction SilentlyContinue).Status)"
            if ($status -eq "Up") { return $true }
        }
    }

    return $false
}
function waitForWifiAddress {
    <# The adapter's IPv4 address once DHCP has given one, or $null. #>
    param (
        [Parameter(Mandatory = $true)]
        $adapter,
        [Parameter(Mandatory = $false)]
        [int]$seconds = 10
    )

    for ($i = 0; $i -lt $seconds; $i++) {
        $address = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1
        if ($address) { return $address.IPAddress }

        Start-Sleep -Seconds 1
    }

    return $null
}
function hideWifiPassword {
    <# Text that is about to be shown, with the password blanked out if netsh echoed it. #>
    param (
        [Parameter(Mandatory = $false)]
        [string]$text,
        [Parameter(Mandatory = $false)]
        [string]$password
    )

    if ([string]::IsNullOrEmpty($text) -or [string]::IsNullOrEmpty($password)) { return $text }

    return $text.Replace($password, "********")
}
function removeWifiProfileFile {
    <# The profile file holds the password in clear text: overwrite it, then delete it. #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$path
    )

    try {
        $length = (Get-Item -LiteralPath $path -ErrorAction Stop).Length
        [System.IO.File]::WriteAllBytes($path, (New-Object byte[] $length))
    } catch { }

    Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
}
function connectWifi {
    $password = $null
    $secure = $null

    try {
        # --- The adapter ---

        $adapters = @(getWifiAdapters)
        if ($adapters.Count -eq 0) {
            writeText -type "error" -text "There is no Wi-Fi adapter on this computer."
            return
        }

        $service = Get-Service -Name "wlansvc" -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            writeText -type "error" -text "The WLAN AutoConfig service (wlansvc) is not installed, so this computer cannot use Wi-Fi."
            return
        }
        if ("$($service.Status)" -ne "Running") {
            writeText -type "notice" -text "The WLAN AutoConfig service (wlansvc) is not running. Start it with 'start service' and try again."
            return
        }

        if ($adapters.Count -eq 1) {
            $adapter = $adapters[0]
        } else {
            $options = [ordered]@{}
            foreach ($candidate in $adapters) { $options[$candidate.Name] = "$($candidate.Status)" }
            $options["Cancel"] = "Do nothing and exit this function."

            $choice = readOption -options $options -prompt "Select a Wi-Fi adapter:" -returnKey -lineAfter
            $adapter = $adapters | Where-Object { $_.Name -ceq $choice } | Select-Object -First 1
            if (-not $adapter) { return }
        }

        if ("$($adapter.Status)" -eq "Disabled") {
            writeText -type "error" -text "The Wi-Fi adapter ($($adapter.Name)) is disabled. Enable it with 'edit network' first."
            return
        }

        $currentSsid = getWifiInterfaceSsid -adapter $adapter

        # --- What to connect to ---

        writeText -type "prompt" -text "Enter the Wi-Fi network details."

        $ssid = readInput -prompt "SSID:"
        if ($null -eq $ssid) { return }

        $problem = testWifiSsid -ssid $ssid
        if ($problem) {
            writeText -type "error" -text $problem
            return
        }

        if ($null -ne $currentSsid -and $currentSsid -ceq $ssid) {
            writeText -type "notice" -text "This computer is already connected to '$ssid' on $($adapter.Name)."
            return
        }

        $secure = readInput -prompt "Password (leave blank for an open network):" -isSecure -allowBlank
        if ($null -eq $secure) { return }

        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try { $password = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        $open = ($password.Length -eq 0)

        if (-not $open) {
            $problem = testWifiPassword -password $password
            if ($problem) {
                writeText -type "error" -text $problem
                return
            }
        }

        # --- Things the user should agree to ---

        $warnings = @()

        $existing = getWifiProfileSecurity -name $ssid
        if ($null -ne $existing) {
            if ($existing.UseOneX -or @("open", "WPAPSK", "WPA2PSK", "WPA3SAE") -notcontains $existing.Authentication) {
                writeText -type "error" -text "A saved profile named '$ssid' signs in with $($existing.Authentication), not with a password. ShellCLI will not replace it."
                writeText -type "plain" -text "Remove it yourself first if you really want to: netsh wlan delete profile name=""$ssid"""
                return
            }
            $warnings += "The saved profile for '$ssid' will be replaced."
        }
        if ($null -ne $currentSsid -and $currentSsid -ne "") {
            $warnings += "This computer is connected to '$currentSsid' on $($adapter.Name). Connecting to '$ssid' disconnects it."
        }
        if ($open) {
            $warnings += "No password was entered, so '$ssid' is joined as an open network: anyone nearby can read what is sent over it."
        }

        if ($warnings.Count -gt 0) {
            foreach ($warning in $warnings) { writeText -type "notice" -text $warning }

            $answer = readOption -options $([ordered]@{
                    "Cancel"   = "Do not connect."
                    "Continue" = "Connect to '$ssid'."
                }) -prompt "Do you want to continue?" -returnKey
            if ($answer -ne "Continue") { return }
        }

        # --- Connect: WPA2 first, then WPA3 ---

        $visible = @(getVisibleWifiNetworks -interfaceName $adapter.Name)
        $hidden = ($visible -cnotcontains $ssid)
        if ($hidden) {
            writeText -type "plain" -text "'$ssid' was not found in range, so it is tried as a hidden network."
        }

        if ($open) {
            $attempts = @("open")
        } elseif ($password -match '^[0-9a-fA-F]{64}$') {
            $attempts = @("WPA2PSK")
        } else {
            $attempts = @("WPA2PSK", "WPA3SAE")
        }
        $labels = @{ "open" = "open network"; "WPA2PSK" = "WPA2-Personal"; "WPA3SAE" = "WPA3-Personal" }

        log -msg "Connecting to Wi-Fi network '$ssid' on $($adapter.Name)."

        $connected = $false
        $usedAuthentication = $null
        $failure = $null

        # The profile file holds the password in clear text, so it lives only in this
        # administrator-only folder, only for as long as netsh needs it.
        $folder = Join-Path (getConfigPath -name temp) "wifi-$([guid]::NewGuid().ToString('N'))"
        [void][System.IO.Directory]::CreateDirectory($folder)

        try {
            foreach ($authentication in $attempts) {
                writeText -type "plain" -text "Connecting to '$ssid' ($($labels[$authentication]))..."

                $file = Join-Path $folder "profile.xml"
                $xml = newWifiProfileXml -ssid $ssid -password $password -authentication $authentication -hidden $hidden
                [System.IO.File]::WriteAllText($file, $xml, (New-Object System.Text.UTF8Encoding $false))
                $xml = $null

                try {
                    $add = invokeNetshWlan -arguments @("add", "profile", "filename=$file", "interface=$($adapter.Name)")
                } finally {
                    removeWifiProfileFile -path $file
                }

                if ($add.ExitCode -ne 0) {
                    $failure = "Windows would not accept the profile: $(hideWifiPassword -text $add.Output -password $password)"
                    break
                }

                $request = invokeNetshWlan -arguments @("connect", "name=$ssid", "ssid=$ssid", "interface=$($adapter.Name)")
                if ($request.ExitCode -ne 0) {
                    $failure = "The connection request failed: $(hideWifiPassword -text $request.Output -password $password)"
                    break
                }

                if (waitForWifiConnection -adapter $adapter -ssid $ssid) {
                    $connected = $true
                    $usedAuthentication = $authentication
                    break
                }
            }
        } finally {
            Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
        }

        # --- The result ---

        if ($connected) {
            $address = waitForWifiAddress -adapter $adapter

            if ($address) {
                writeText -type "success" -text "Connected to '$ssid' ($($labels[$usedAuthentication])) on $($adapter.Name). IP address: $address"
            } else {
                writeText -type "notice" -text "Connected to '$ssid' ($($labels[$usedAuthentication])) on $($adapter.Name), but no IP address has been given yet. Check again in a moment with 'network'."
            }
            writeText -type "plain" -text "The network is saved and will connect automatically when it is in range."
            return
        }

        if ($failure) {
            writeText -type "error" -text $failure
        } else {
            writeText -type "error" -text "Could not connect to '$ssid'. The most likely causes are a wrong password, the network being out of range, or the network using a security type ShellCLI does not set up (for example an enterprise sign-in)."
        }

        # Do not leave a profile that does not work behind, unless it was one that was already there.
        if ($null -eq $existing) {
            [void](invokeNetshWlan -arguments @("delete", "profile", "name=$ssid", "interface=$($adapter.Name)"))
        } else {
            writeText -type "plain" -text "The saved profile for '$ssid' now has the settings you just entered."
        }
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    } finally {
        $password = $null
        $secure = $null
    }
}
function network {
    try {
        $adapters = @()
        foreach ($n in (Get-NetAdapter | Select-Object -ExpandProperty Name)) { $adapters += $n }
        foreach ($a in $adapters) { getAdapterInfo -adapterName $a }
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
