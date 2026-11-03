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
    <# The physical Wi-Fi adapters, enabled or not: interface type 71 (IEEE 802.11), or a media type that says so. #>
    try {
        $adapters = @(Get-NetAdapter -Physical -ErrorAction Stop)
    } catch {
        # Do not turn "could not ask" into "there is no Wi-Fi adapter".
        throw "Could not list the network adapters: $($_.Exception.Message)"
    }

    return @($adapters | Where-Object { $_.InterfaceType -eq 71 -or "$($_.PhysicalMediaType)" -match '802\.11|Wireless LAN' })
}
function invokeNetshWlan {
    <#
        Runs "netsh wlan ..." directly (not through cmd.exe, so no shell characters in a
        name can do anything). The password is never an argument: it goes in a file.
        Returns ExitCode, Output and LocationBlocked (Windows 11 24H2 refuses to show Wi-Fi
        details to command-line tools unless Location services are on).
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$arguments
    )

    # netsh writes in the console's output encoding. Use UTF-8 so a network name with accents
    # or other non-ASCII characters comes back as it was typed, not through an OEM code page.
    $previous = $null
    try {
        $previous = [Console]::OutputEncoding
        [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
    } catch {
        $previous = $null
    }

    try {
        $output = & netsh.exe wlan @arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        if ($null -ne $previous) {
            try { [Console]::OutputEncoding = $previous } catch { }
        }
    }

    $text = (($output | ForEach-Object { "$_" }) -join "`n")

    return [pscustomobject]@{
        ExitCode        = $exitCode
        Output          = $text
        LocationBlocked = ($text -match '(?i)location (permission|services)')
    }
}
function getWifiInterfaceSsid {
    <#
        What "netsh wlan show interfaces" says about this adapter: Readable (netsh answered and
        listed the adapter) and Ssid (the network it is connected to, or $null). Matched on the
        adapter's GUID and the SSID line, labels that are not translated on other display
        languages (State, Name and so on are).
    #>
    param (
        [Parameter(Mandatory = $true)]
        $adapter
    )

    $result = invokeNetshWlan -arguments @("show", "interfaces")
    $guid = "$($adapter.InterfaceGuid)".Trim("{", "}")
    $listed = $false
    $ssid = $null

    if ($result.ExitCode -eq 0) {
        $current = $null

        foreach ($line in ($result.Output -split "`r?`n")) {
            if ($line -match '^\s*GUID\s*:\s*\{?([0-9a-fA-F-]{36})\}?\s*$') {
                $current = $Matches[1]
                if ($current -ieq $guid) { $listed = $true }
                continue
            }
            if ($current -and $current -ieq $guid -and $line -match '^\s*SSID\s*:\s?(.*)$') {
                if ($Matches[1].Length -gt 0) { $ssid = $Matches[1] }
                break
            }
        }
    }

    return [pscustomobject]@{ Readable = $listed; Ssid = $ssid; Blocked = [bool]$result.LocationBlocked }
}
function getVisibleWifiNetworks {
    <# The networks this adapter can see ("SSID 1 : name" lines): Readable (netsh answered) and Names. #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$interfaceName
    )

    $result = invokeNetshWlan -arguments @("show", "networks", "interface=$interfaceName")
    $names = @()

    if ($result.ExitCode -eq 0) {
        foreach ($line in ($result.Output -split "`r?`n")) {
            if ($line -match '^\s*SSID\s+\d+\s*:\s?(.*)$') { $names += $Matches[1] }
        }
    }

    return [pscustomobject]@{ Readable = ($result.ExitCode -eq 0); Names = $names }
}
function getWifiConnection {
    <#
        The network this adapter is on, as Known / Ssid / Source. netsh answers first. If
        Windows will not let it (no Location services), the name of the adapter's Windows
        network profile is used instead. That name is only a hint: it is the SSID, with a
        number added when the name was already taken, but it is the domain name on a domain
        network, "Unidentified network" on one without an address, and it can appear late.
        Known is false when neither can say.
    #>
    param (
        [Parameter(Mandatory = $true)]
        $adapter
    )

    $netsh = getWifiInterfaceSsid -adapter $adapter
    if ($netsh.Readable) {
        return [pscustomobject]@{ Known = $true; Ssid = $netsh.Ssid; Source = "netsh"; Blocked = $false }
    }

    $profile = Get-NetConnectionProfile -InterfaceIndex $adapter.InterfaceIndex -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($profile) {
        return [pscustomobject]@{ Known = $true; Ssid = "$($profile.Name)"; Source = "windows"; Blocked = $netsh.Blocked }
    }

    # No network profile: not connected, or still being set up. (Status can be a combination
    # such as "Disconnected + LowPower", so it is matched on its start.)
    $status = "$((Get-NetAdapter -InterfaceIndex $adapter.InterfaceIndex -ErrorAction SilentlyContinue).Status)"
    if ($status -match '^(Disconnected|Not Present)') {
        return [pscustomobject]@{ Known = $true; Ssid = $null; Source = "windows"; Blocked = $netsh.Blocked }
    }

    return [pscustomobject]@{ Known = $false; Ssid = $null; Source = "none"; Blocked = $netsh.Blocked }
}
function testWifiConnectionIs {
    <#
        Is the connection reported by getWifiConnection to this exact network? Windows names
        its network profile after the SSID and adds a number when the name is taken, so for a
        name that came from Windows (not netsh) "Home 2" also counts as "Home", unless
        -exactOnly is given: that is for a yes that must not be a guess.
    #>
    param (
        [Parameter(Mandatory = $true)]
        $connection,
        [Parameter(Mandatory = $true)]
        [string]$ssid,
        [Parameter(Mandatory = $false)]
        [switch]$exactOnly
    )

    if (-not $connection.Known -or $null -eq $connection.Ssid) { return $false }
    if ($connection.Ssid -ceq $ssid) { return $true }

    if (-not $exactOnly -and $connection.Source -eq "windows" -and $connection.Ssid -cmatch ('^' + [regex]::Escape($ssid) + ' \d+$')) { return $true }

    return $false
}
function getWifiHiddenCharacters {
    <#
        A regular expression class for characters that cannot be shown safely: control characters
        (they move the cursor), and bidirectional, zero-width and line-separator characters (they
        can make text read differently from what it is). Built from character codes so that this
        file stays plain ASCII, which Windows PowerShell 5.1 needs.
    #>
    return "[\x00-\x1F\x7F-\x9F$([char]0x200B)-$([char]0x200F)$([char]0x2028)-$([char]0x202E)$([char]0x2066)-$([char]0x2069)]"
}
function getWifiInvalidXmlCharacters {
    <# A regular expression for characters that cannot be written in an XML profile: U+FFFE, U+FFFF and a surrogate on its own. #>
    $high = "$([char]0xD800)-$([char]0xDBFF)"
    $low = "$([char]0xDC00)-$([char]0xDFFF)"

    return "[$([char]0xFFFE)$([char]0xFFFF)]|[$high](?![$low])|(?<![$high])[$low]"
}
function showWifiName {
    <#
        A network name that came from Windows, safe to print: control characters would move the
        cursor, and bidirectional and line-separator characters can make text read differently
        from what it is.
    #>
    param (
        [Parameter(Mandatory = $false)]
        [string]$name
    )

    return ($name -replace (getWifiHiddenCharacters), '?')
}
function getWifiProfileSecurity {
    <#
        $null if no saved profile has this name. Otherwise how it signs in: Authentication
        (open, WPA2PSK, WPA3SAE, WPA2 for enterprise ...) and UseOneX. Read from an export
        made without the key, in a private folder that is removed again. Throws if that folder
        cannot be made (a different problem from not being able to read the profile).
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$name,
        [Parameter(Mandatory = $true)]
        [string]$interfaceName
    )

    $found = invokeNetshWlan -arguments @("show", "profile", "name=$name", "interface=$interfaceName")
    if ($found.ExitCode -ne 0) { return $null }

    $unknown = [pscustomobject]@{ Authentication = "Unknown"; UseOneX = $true }
    $folder = newPrivateWifiFolder -parent (getConfigPath -name temp)

    try {
        $export = invokeNetshWlan -arguments @("export", "profile", "name=$name", "folder=$folder", "interface=$interfaceName")
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
    if ($ssid -match (getWifiHiddenCharacters)) { return "The network name contains a control or invisible formatting character." }
    # Characters that cannot be written in the XML profile (a lone surrogate, U+FFFE, U+FFFF).
    if ($ssid -match (getWifiInvalidXmlCharacters)) { return "The network name contains a character that cannot be used in a Wi-Fi profile." }
    # These would change what netsh is asked to do.
    if ($ssid.Contains('"')) { return "ShellCLI cannot connect to a network whose name contains a double quote." }
    # PowerShell 5.1 puts quotes around an argument that has a space in it, and a backslash just
    # before the closing quote then swallows it and runs the arguments together.
    if ($ssid.EndsWith("\", [System.StringComparison]::Ordinal) -and $ssid -match '\s') { return "ShellCLI cannot connect to a network whose name has a space in it and ends with a backslash." }
    # netsh treats * as "every profile" in a profile name.
    if ($ssid.Contains("*") -or $ssid.Contains("?")) { return "ShellCLI cannot connect to a network whose name contains * or ?." }

    return $null
}
function testWifiPassword {
    <# Returns what is wrong with this Wi-Fi password, or $null if it is usable. #>
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$password
    )

    # A raw key is exactly 64 hexadecimal digits. (-cmatch: a case-insensitive match lets
    # characters such as the Kelvin sign through as if they were plain letters.)
    if ($password -cmatch '^[0-9a-fA-F]{64}$') { return $null }

    # A passphrase is 8 to 63 plain keyboard characters.
    if ($password -cmatch '[^\x20-\x7E]') { return "A Wi-Fi password can only use plain keyboard characters (letters, digits, symbols and spaces). Accented and other non-English characters are not accepted." }
    if ($password.Length -lt 8 -or $password.Length -gt 63) { return "A Wi-Fi password is 8 to 63 characters (or exactly 64 hexadecimal digits)." }

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
        if ($password -cmatch '^[0-9a-fA-F]{64}$') { $keyType = "networkKey" }
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
    <#
        $true once the adapter is up and on exactly this network. $false only on a definite no:
        netsh could be read at the end and the adapter is not on this network, or the adapter
        is not joined to anything. $null when it cannot be told: all Windows has is a network
        name, and a name that does not match proves nothing (see getWifiConnection).
    #>
    param (
        [Parameter(Mandatory = $true)]
        $adapter,
        [Parameter(Mandatory = $true)]
        [string]$ssid,
        [Parameter(Mandatory = $false)]
        [int]$seconds = 15
    )

    $connection = $null

    for ($i = 0; $i -lt $seconds; $i++) {
        Start-Sleep -Seconds 1

        $connection = getWifiConnection -adapter $adapter

        if (testWifiConnectionIs -connection $connection -ssid $ssid) {
            $status = "$((Get-NetAdapter -InterfaceIndex $adapter.InterfaceIndex -ErrorAction SilentlyContinue).Status)"
            if ($status -match '^Up') { return $true }
        }
    }

    if ($null -ne $connection -and $connection.Known -and ($connection.Source -eq "netsh" -or $null -eq $connection.Ssid)) { return $false }

    return $null
}
function waitForWifiAddress {
    <#
        The adapter's IPv4 address once it has one. On a network that only gives IPv6, the
        global IPv6 address after the whole wait. $null if there is neither.
    #>
    param (
        [Parameter(Mandatory = $true)]
        $adapter,
        [Parameter(Mandatory = $false)]
        [int]$seconds = 10
    )

    $v6 = $null

    for ($i = 0; $i -lt $seconds; $i++) {
        $v4 = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1
        if ($v4) { return $v4.IPAddress }

        if (-not $v6) {
            $found = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv6 -ErrorAction SilentlyContinue |
                Where-Object { $_.IPAddress -notlike "fe80*" -and $_.IPAddress -ne "::1" } | Select-Object -First 1
            if ($found) { $v6 = $found.IPAddress }
        }

        Start-Sleep -Seconds 1
    }

    return $v6
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
    <#
        The profile file holds the password in clear text: overwrite it, then delete it.
        Returns $true if the file is gone.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$path
    )

    if (-not (Test-Path -LiteralPath $path)) { return $true }

    try {
        $length = (Get-Item -LiteralPath $path -ErrorAction Stop).Length
        [System.IO.File]::WriteAllBytes($path, (New-Object byte[] $length))
    } catch { }

    Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue

    return (-not (Test-Path -LiteralPath $path))
}
function newPrivateWifiFolder {
    <#
        A new, empty folder that only SYSTEM and Administrators can use, for the profile file
        that holds the password. It is created with that access list already on it (not made
        and locked down afterwards, which leaves a gap), and it does not depend on where it is:
        the ShellCLI folders are only protected when ShellCLI was started in the usual way.
        Throws if it cannot be made that way.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$parent,
        [Parameter(Mandatory = $false)]
        [string[]]$allowedSids = @("S-1-5-18", "S-1-5-32-544")
    )

    $folder = Join-Path $parent "wifi-$([guid]::NewGuid().ToString('N'))"

    try {
        $security = New-Object System.Security.AccessControl.DirectorySecurity
        $security.SetAccessRuleProtection($true, $false)

        foreach ($sid in $allowedSids) {
            $account = New-Object System.Security.Principal.SecurityIdentifier($sid)
            $security.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($account, "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")))
        }

        [void][System.IO.Directory]::CreateDirectory($folder, $security)
    } catch {
        Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
        throw "Could not make a private folder for the Wi-Fi profile ($($_.Exception.Message)), so nothing was written."
    }

    return $folder
}
function clearStaleWifiFolders {
    <#
        A run that was killed (window closed, power lost) can leave its private folder behind,
        and the profile file with the password in it. Wipe any that earlier runs left. Only
        the folder's own files are touched, and a link that has taken the place of a folder
        is removed as a link, never followed.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$parent,
        [Parameter(Mandatory = $false)]
        [int]$minutes = 10
    )

    $limit = (Get-Date).AddMinutes(-$minutes)

    foreach ($stale in @(Get-ChildItem -LiteralPath $parent -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^wifi-[0-9a-f]{32}$' -and $_.LastWriteTime -lt $limit })) {
        $isLink = (($stale.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)

        if (-not $isLink) {
            foreach ($file in @(Get-ChildItem -LiteralPath $stale.FullName -File -Force -ErrorAction SilentlyContinue)) {
                if (($file.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) { [void](removeWifiProfileFile -path $file.FullName) }
            }
        }

        try { [System.IO.Directory]::Delete($stale.FullName, (-not $isLink)) } catch { }
    }
}
function testLocalFolder {
    <# True if the folder is on a disk in this computer: not a network share or a mapped network drive. #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$path
    )

    if ($path.StartsWith("\\")) { return $false }

    try {
        $root = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($path))
        if ($root -and (New-Object System.IO.DriveInfo($root)).DriveType -eq [System.IO.DriveType]::Network) { return $false }
    } catch { }

    return $true
}
function restoreWifiConnection {
    <#
        After a failed switch, go back to the network the computer was on, if its saved profile
        is still there. $true / $false / $null as for waitForWifiConnection.
    #>
    param (
        [Parameter(Mandatory = $true)]
        $adapter,
        [Parameter(Mandatory = $true)]
        [string]$ssid
    )

    $saved = invokeNetshWlan -arguments @("show", "profile", "name=$ssid", "interface=$($adapter.Name)")
    if ($saved.ExitCode -ne 0) { return $false }

    $request = invokeNetshWlan -arguments @("connect", "name=$ssid", "ssid=$ssid", "interface=$($adapter.Name)")
    if ($request.ExitCode -ne 0) { return $false }

    return (waitForWifiConnection -adapter $adapter -ssid $ssid -seconds 10)
}
function connectWifi {
    $password = $null
    $secure = $null
    $folder = $null
    $adapter = $null
    $ssid = $null
    $existing = $null
    $previous = $null
    $createdProfile = $false
    $profileWritten = $false
    $connectRequested = $false
    $connected = $false
    $unconfirmed = $false
    $afterNotes = @()

    $hiddenHint = "Windows would not report Wi-Fi details to ShellCLI (on Windows 11 that usually means Location services are off: Settings > Privacy & security > Location)."

    try {
        # An earlier run that was killed may have left a profile file with a password in it.
        $tempRoot = getConfigPath -name temp
        clearStaleWifiFolders -parent $tempRoot

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

        if ("$($adapter.Status)" -match '^Disabled') {
            writeText -type "error" -text "The Wi-Fi adapter ($($adapter.Name)) is disabled. Enable it with 'edit network' first."
            return
        }

        # The profile file holds the password in clear text: never over the network.
        if (-not (testLocalFolder -path $tempRoot)) {
            writeText -type "error" -text "ShellCLI's temp folder ($tempRoot) is on a network location, and the Wi-Fi password would be written over the network. Point tempDirectory in config.json at a local folder."
            return
        }

        # --- What to connect to ---

        writeText -type "prompt" -text "Enter the Wi-Fi network details."

        $ssid = readInput -prompt "SSID:"
        if ($null -eq $ssid) { return }

        $problem = testWifiSsid -ssid $ssid
        if ($problem) {
            writeText -type "error" -text $problem
            return
        }

        # A saved network that cannot be replaced is refused before the password is asked for.
        $existing = getWifiProfileSecurity -name $ssid -interfaceName $adapter.Name
        if ($null -ne $existing) {
            $kind = $existing.Authentication
            $blocked = $true

            if ($kind -eq "Unknown") {
                writeText -type "error" -text "A saved profile named '$ssid' exists, but ShellCLI could not read how it signs in, so it will not replace it."
            } elseif ($existing.UseOneX -or @("WPA", "WPA2", "WPA3ENT", "WPA3ENT192") -contains $kind) {
                writeText -type "error" -text "A saved profile named '$ssid' signs in with a work or school account or a certificate (802.1X), not with a password. ShellCLI will not replace it."
            } elseif (@("open", "WPAPSK", "WPA2PSK", "WPA3SAE") -notcontains $kind) {
                writeText -type "error" -text "A saved profile named '$ssid' uses '$kind' security, which ShellCLI does not set up, so it will not replace it."
            } else {
                $blocked = $false
            }

            if ($blocked) {
                writeText -type "plain" -text "Forget it first (Settings > Network & internet > Wi-Fi > Manage known networks), then run this again."
                return
            }
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

        # --- What the computer is doing now (looked at after the typing, which takes a while) ---

        $connection = getWifiConnection -adapter $adapter

        if (testWifiConnectionIs -connection $connection -ssid $ssid -exactOnly) {
            writeText -type "notice" -text "This computer is already connected to '$ssid' on $($adapter.Name)."
            return
        }

        # Is the network in range? A typo in the name shows up here. A network that is not
        # broadcasting its name needs the profile to say so, and a profile that says so also
        # works for one that is visible, so when the scan cannot say, assume hidden.
        $scan = getVisibleWifiNetworks -interfaceName $adapter.Name
        $listed = @($scan.Names | Where-Object { $_ })
        $scanKnown = ($scan.Readable -and $listed.Count -gt 0)
        $hidden = $true
        if ($scanKnown) { $hidden = ($listed -cnotcontains $ssid) }

        # --- Things the user should agree to ---

        $warnings = @()

        if ($scanKnown -and $hidden) {
            $warnings += "'$ssid' was not found in range. Check the name; it will be tried as a hidden network."
        }
        if ($null -ne $existing) {
            $warnings += "The saved profile for '$ssid' will be replaced. If the connection fails, the old settings are not restored."
        }
        if (-not $connection.Known) {
            $warnings += "ShellCLI cannot tell which network this computer is on, so it cannot say whether connecting disconnects it. $hiddenHint"
        } elseif ($connection.Ssid) {
            $warnings += "This computer is connected to '$(showWifiName $connection.Ssid)' on $($adapter.Name). Connecting to '$ssid' disconnects it."
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

            # The answer can take a while too.
            $connection = getWifiConnection -adapter $adapter
            if (testWifiConnectionIs -connection $connection -ssid $ssid -exactOnly) {
                writeText -type "notice" -text "This computer is already connected to '$ssid' on $($adapter.Name)."
                return
            }
        }

        if (-not $scan.Readable) {
            writeText -type "plain" -text "Windows would not list the networks in range, so '$ssid' is tried as a hidden network."
        }

        # What the computer is on right now: where to go back to if this fails.
        $previous = $connection

        # --- Connect: WPA2 first, then WPA3 ---

        if ($open) {
            $attempts = @("open")
        } elseif ($password -cmatch '^[0-9a-fA-F]{64}$') {
            $attempts = @("WPA2PSK")
        } else {
            $attempts = @("WPA2PSK", "WPA3SAE")
        }
        $labels = @{ "open" = "open network"; "WPA2PSK" = "WPA2-Personal"; "WPA3SAE" = "WPA3-Personal" }

        log -msg "Connecting to Wi-Fi network '$ssid' on $($adapter.Name)."

        $usedAuthentication = $null
        $failures = @()

        # The profile file holds the password in clear text, so it lives only in this private
        # folder, only for as long as netsh needs it.
        $folder = newPrivateWifiFolder -parent $tempRoot

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
                    if (-not (removeWifiProfileFile -path $file)) {
                        writeText -type "error" -text "Could not delete the temporary profile file $file. It may contain the password: delete it yourself."
                    }
                }

                if ($add.ExitCode -ne 0) {
                    $failures += "$($labels[$authentication]): Windows would not accept the profile: $(hideWifiPassword -text $add.Output -password $password)"
                    continue
                }

                $profileWritten = $true
                if ($null -eq $existing) { $createdProfile = $true }

                $connectRequested = $true
                $request = invokeNetshWlan -arguments @("connect", "name=$ssid", "ssid=$ssid", "interface=$($adapter.Name)")
                if ($request.ExitCode -ne 0) {
                    $failures += "$($labels[$authentication]): the connection request failed: $(hideWifiPassword -text $request.Output -password $password)"
                    continue
                }

                $state = waitForWifiConnection -adapter $adapter -ssid $ssid

                # Slow to join is not the same as failed: while the adapter is still up, give it a
                # little longer before a second profile is put on top of this one.
                if ($state -eq $false -and "$((Get-NetAdapter -InterfaceIndex $adapter.InterfaceIndex -ErrorAction SilentlyContinue).Status)" -match '^Up') {
                    $state = waitForWifiConnection -adapter $adapter -ssid $ssid -seconds 5
                }

                if ($state -eq $true) {
                    $connected = $true
                    $usedAuthentication = $authentication
                    break
                }
                if ($null -eq $state) {
                    # Nothing definite can be read, so do not try again with a different profile
                    # on top of a connection that may be coming up.
                    $unconfirmed = $true
                    $usedAuthentication = $authentication
                    break
                }

                $failures += "$($labels[$authentication]): did not connect"
            }
        } finally {
            Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path -LiteralPath $folder) {
                $afterNotes += @{ Type = "error"; Text = "Could not remove the temporary folder $folder. Check that it is empty, and delete it." }
            }

            # Do not leave behind a profile that does not work (also if this is interrupted),
            # unless it replaced one that was already there.
            if ($createdProfile -and -not $connected -and -not $unconfirmed) {
                $deleted = invokeNetshWlan -arguments @("delete", "profile", "name=$ssid", "interface=$($adapter.Name)")
                if ($deleted.ExitCode -ne 0) {
                    $afterNotes += @{ Type = "error"; Text = "The profile for '$ssid' that was just created could not be removed. Forget it in Settings > Network & internet > Wi-Fi > Manage known networks." }
                }
            }

            # If the computer was moved off its network and this did not work, put it back (also
            # if this is interrupted), so a remote session survives.
            if ($connectRequested -and -not $connected -and -not $unconfirmed -and $previous -and $previous.Known -and $previous.Ssid) {
                try {
                    $now = getWifiConnection -adapter $adapter
                    if (-not (testWifiConnectionIs -connection $now -ssid $previous.Ssid -exactOnly)) {
                        if (testWifiSsid -ssid $previous.Ssid) {
                            $afterNotes += @{ Type = "notice"; Text = "This computer was on '$(showWifiName $previous.Ssid)' and has to be put back on it by hand." }
                        } else {
                            $back = restoreWifiConnection -adapter $adapter -ssid $previous.Ssid
                            if ($back -eq $true) {
                                $afterNotes += @{ Type = "plain"; Text = "Reconnected to '$(showWifiName $previous.Ssid)'." }
                            } elseif ($null -eq $back) {
                                $afterNotes += @{ Type = "notice"; Text = "Asked to go back to '$(showWifiName $previous.Ssid)', but ShellCLI cannot confirm it did. Check with 'network'." }
                            } else {
                                $afterNotes += @{ Type = "notice"; Text = "This computer was on '$(showWifiName $previous.Ssid)' and could not be put back on it automatically." }
                            }
                        }
                    }
                } catch {
                    $afterNotes += @{ Type = "notice"; Text = "This computer was on '$(showWifiName $previous.Ssid)'. Check that it is still connected." }
                }
            }
        }

        # --- The result ---

        if ($connected) {
            $address = waitForWifiAddress -adapter $adapter

            if ($address) {
                writeText -type "success" -text "Connected to '$ssid' ($($labels[$usedAuthentication])) on $($adapter.Name). Address: $address"
            } else {
                writeText -type "notice" -text "Connected to '$ssid' ($($labels[$usedAuthentication])) on $($adapter.Name), but no address has been given yet. Check again in a moment with 'network'."
            }
            writeText -type "plain" -text "The network is saved and will connect automatically when it is in range."
            if ($hidden -and -not $scanKnown) {
                writeText -type "plain" -text "Because the networks in range could not be listed, the saved profile is marked as a hidden network. It connects normally either way."
            }
            return
        }

        if ($unconfirmed) {
            writeText -type "notice" -text "The connection request for '$ssid' ($($labels[$usedAuthentication])) was accepted, but ShellCLI cannot confirm it connected. $hiddenHint Check with 'network'. If it did not connect, forget the network in Settings > Network & internet > Wi-Fi > Manage known networks."
            writeText -type "plain" -text "The network is saved and will connect automatically when it is in range."
            return
        }

        writeText -type "error" -text "Could not connect to '$ssid'. The most likely causes are a wrong password, the network being out of range, or a security type ShellCLI does not set up (for example an enterprise sign-in)."
        foreach ($failure in $failures) { writeText -type "plain" -text "  $failure" }

        if (-not $createdProfile -and $profileWritten) {
            writeText -type "plain" -text "The saved profile for '$ssid' now has the settings you just entered."
        }
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    } finally {
        foreach ($note in $afterNotes) { writeText -type $note.Type -text $note.Text }

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
