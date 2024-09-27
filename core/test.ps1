function editNetAdapter {
    try {
        selectAdapter
    } catch {
        writeText -type "error" -text "editNetAdapter-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function getDesiredSettings {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Adapter
    )

    try {
        getAdapterInfo -AdapterName $Adapter["name"]

        # This block of code is just to get the original adapter array.
        $memoryStream = New-Object System.IO.MemoryStream
        $binaryFormatter = New-Object System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
        $binaryFormatter.Serialize($memoryStream, $Adapter)
        $memoryStream.Position = 0
        $Original = $binaryFormatter.Deserialize($memoryStream)
        $memoryStream.Close()

        $Adapter = readIPSettings -Adapter $Adapter
        $Adapter = read-dnssettings -Adapter $Adapter

        confirm-edits -Adapter $Adapter -Original $Original
    } catch {
        writeText -type "error" -text "get-desired-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function selectAdapter {
    try {
        $adapters = [ordered]@{}

        Get-NetAdapter | ForEach-Object { 
            $adapters[$_.Name] = $_.MediaConnectionState 
        }

        $adapterList = [ordered]@{}

        foreach ($al in $adapters) { 
            $adapterList = $al 
        }

        $choice = readOption -options $adapterList -prompt "Select an network adapter:" -returnKey
        
        $netAdapter = Get-NetAdapter -Name $choice
        $netAdapter
        $adapterIndex = $netAdapter.InterfaceIndex

        $script:ipv4Regex = "^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){0,4}$"

        if ($netAdapter.Status -eq "Up") {
            $ipData = Get-NetIPAddress -InterfaceIndex $adapterIndex -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -ne "WellKnown" -and $_.SuffixOrigin -ne "Link" -and ($_.AddressState -eq "Preferred" -or $_.AddressState -eq "Tentative") } | Select-Object -First 1
            $interface = Get-NetIPInterface -InterfaceIndex $adapterIndex
            $adapter = [ordered]@{
                "name"    = $choice
                "self"    = Get-NetAdapter -Name $choice
                "index"   = $netAdapter.InterfaceIndex
                "ip"      = $ipData.IPAddress
                "gateway" = Get-NetRoute -InterfaceAlias $choice -DestinationPrefix "0.0.0.0/0" | Select-Object -ExpandProperty "NextHop"
                "subnet"  = convert-cidr-to-mask -CIDR $ipData.PrefixLength
                "dns"     = Get-DnsClientServerAddress -InterfaceIndex $adapterIndex | Select-Object -ExpandProperty ServerAddresses
                "IPDHCP"  = if ($interface.Dhcp -eq "Enabled") { 
                    $true 
                } else { 
                    $false 
                }
                "status"  = $netAdapter.Status
            }
        } else {
            $adapter = [ordered]@{
                "name"   = $choice
                "self"   = Get-NetAdapter -Name $choice
                "index"  = $netAdapter.InterfaceIndex
                "status" = $netAdapter.Status
            }
        }

        getDesiredSettings -Adapter $adapter
    } catch {
        writeText -type "error" -text "selectAdapter-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function readIPSettings {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Adapter
    )

    try {
        $choices = $([ordered]@{})

        $Adapter["ip"]
        if ($Adapter["status"] -eq "Disabled") {
            $choices["Enable adapter"] = "Enable this network adapter"
        } else {
            $choices["Disabled adapter"] = "Enable this network adapter"
        }

        $choices["Set static"] = "Set this adapter to static and enter IP data manually."
        $choices["Set dynamic"] = "Set this adapter to DHCP."
        $choices["Back" ] = "Go back to network adapter selection."
    
        $choice = readOption -options $choices -prompt "Select an action:"

        $desiredSettings = $Adapter

        if ($choice -eq 0 -and $Adapter["status"] -eq "Disabled") { 
            Get-NetAdapter | Where-Object { $_.Name -eq $Adapter["name"] } | Enable-NetAdapter
        }
        if ($choice -eq 0 -and $Adapter["status"] -ne "Disabled") { 
            Get-NetAdapter | Where-Object { $_.Name -eq $Adapter["name"] } | Disable-NetAdapter
        }
        if ($choice -eq 1) { 
            $ip = readInput -prompt "IPv4:" -Validate $ipv4Regex -Value $Adapter["ip"]
            $subnet = readInput -prompt "Subnet mask:" -Validate $ipv4Regex -Value $Adapter["subnet"]  
            $gateway = readInput -prompt "Gateway:" -Validate $ipv4Regex -Value $Adapter["gateway"] -lineAfter
        
            if ($ip -eq "") { $ip = $Adapter["ip"] }
            if ($subnet -eq "") { $subnet = $Adapter["subnet"] }
            if ($gateway -eq "") { $gateway = $Adapter["gateway"] }

            $desiredSettings["ip"] = $ip
            $desiredSettings["subnet"] = $subnet
            $desiredSettings["gateway"] = $gateway
            $desiredSettings["IPDHCP"] = $false
        }

        if (2 -eq $choice) { 
            $desiredSettings["IPDHCP"] = $true 
        }
        if (3 -eq $choice) { 
            selectAdapter 
        }

        return $desiredSettings 
    } catch {
        writeText -type "error" -text "readIPSettings-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function read-dnssettings {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Adapter
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
            $Adapter["dns"] = $dns
        }
        if (1 -eq $choice) { $Adapter["DNSDHCP"] = $true }
        if (2 -eq $choice) { readIPSettings }

        return $Adapter
    } catch {
        writeText -type "error" -text "read-dnssettings-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
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
        $status = Get-NetAdapter -Name $Adapter["name"] | Select-Object -ExpandProperty Status
        if ($status -eq "Up") {
            Write-Host "  $([char]0x2022)" -ForegroundColor "Green" -NoNewline
            Write-Host " $($Original["name"])" -ForegroundColor "Gray"
        } else {
            Write-Host "  $([char]0x25BC)" -ForegroundColor "Red" -NoNewline
            Write-Host " $($Original["name"])" -ForegroundColor "Gray"
        }

        if ($Adapter["IPDHCP"]) {
            write-compare -oldData "IPv4 Address. . . : $($Original["ip"])" -newData "Dynamic"
            write-compare -oldData "Subnet Mask . . . : $($Original["subnet"])" -newData "Dynamic"
            write-compare -oldData "Default Gateway . : $($Original["gateway"])" -newData "Dynamic"
        } else {
            write-compare -oldData "IPv4 Address. . . : $($Original["ip"])" -newData $($Adapter['ip'])
            write-compare -oldData "Subnet Mask . . . : $($Original["subnet"])" -newData $($Adapter['subnet'])
            write-compare -oldData "Default Gateway . : $($Original["gateway"])" -newData $($Adapter['gateway'])
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
    
        $dns = $Adapter['dns']

        if ($dns.Count -gt 0) { $dnsString = $dns -join ", " } 
        else { $dnsString = $dns[0] }

        Get-NetAdapter -Name $adapter["name"] | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute -InterfaceAlias $adapter["name"] -DestinationPrefix 0.0.0.0 / 0 -Confirm:$false -ErrorAction SilentlyContinue

        if ($Adapter["IPDHCP"]) {
            Set-NetIPInterface -InterfaceIndex $adapterIndex -Dhcp Enabled  | Out-Null
            netsh interface ipv4 set address name = "$($adapter["name"])" source = dhcp | Out-Null
            writeText -type 'success' -text "The network adapters IP settings were set to dynamic"
        } else {
            writeText "Disabling DHCP and applying static addresses." 
            netsh interface ipv4 set address name = "$($adapter["name"])" static $Adapter["ip"] $Adapter["subnet"] $Adapter["gateway"] | Out-Null
            writeText -type 'success' -text "The network adapters IP, subnet, and gateway were set to static and your addresses were applied."
        }

        if ($Adapter["DNSDHCP"]) {
            Set-DnsClientServerAddress -InterfaceAlias $Adapter["name"] -ResetServerAddresses | Out-Null
            writeText -type 'success' -text "The network adapters DNS settings were set to dynamic"
        } else {
            writeText "Disabling DHCP and applying static addresses."
            Set-DnsClientServerAddress -InterfaceAlias $Adapter["name"] -ServerAddresses $dnsString
            writeText -type 'success' -text "The network adapters DNS was set to static and your addresses were applied."
        }

        Disable-NetAdapter -Name $Adapter["name"] -Confirm:$false
        Start-Sleep 1
        Enable-NetAdapter -Name $Adapter["name"] -Confirm:$false

        readCommand
    } catch {
        writeText -type "error" -text "confirm-edits-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function getAdapterInfo {
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

            writeText "MAC Address . . . : $macAddress" -Color "Gray"
            writeText "IPv4 Address. . . : $ipAddress" -Color "Gray"
            writeText "Subnet Mask . . . : $subnet" -Color "Gray"
            writeText "Default Gateway . : $gateway" -Color "Gray"

            for ($i = 0; $i -lt $dnsServers.Count; $i++) {
                if ($i -eq 0) {
                    writeText "DNS Servers . . . : $($dnsServers[$i])" -Color "Gray"
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
        foreach ($a in $adapters) { getAdapterInfo -AdapterName $a }

        selectAdapter
    } catch {
        writeText -type "error" -text "show-adapters-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function invokeScript {
    param (
        [parameter(Mandatory = $true)]
        [string]$script,
        [parameter(Mandatory = $false)]
        [boolean]$initialize = $false
    ) 

    try {
        if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
            Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
            Exit
        } 

        # Customize console appearance
        $console = $host.UI.RawUI
        $console.BackgroundColor = "Black"
        $console.ForegroundColor = "Gray"
        $console.WindowTitle = "Chaste Scripts"

        if ($initialize) {
            Clear-Host
            Write-Host
            Write-Host "  Try" -NoNewline
            Write-Host " help" -ForegroundColor "Cyan" -NoNewline
            Write-Host " or" -NoNewline
            Write-Host " menu" -NoNewline -ForegroundColor "Cyan"
            Write-Host " if you don't know what to do."
        }

        Invoke-Expression $script
    } catch {
        writeText -type "error" -text "invokeScript-$($_.InvocationInfo.ScriptLineNumber) | $script"
    }
}
function readCommand {
    param (
        [Parameter(Mandatory = $false)]
        [string]$command = ""
    )

    try {
        Write-Host
        if ($command -eq "") { 
            Write-Host "$([char]0x203A) " -NoNewline
            $command = Read-Host 
        }

        $command = $command.ToLower()
        $command = $command.Trim()

        if ($command -ne "help" -and $command -ne "" -and $command -match "^(?-i)(\w+(-\w+)*)") {
            if (Get-command $matches[1] -ErrorAction SilentlyContinue) {
                Invoke-Expression $command
                readCommand
            }
        }

        $filteredCommand = filterCommands -command $command
        $commandDirectory = $filteredCommand[0]
        $commandFile = $filteredCommand[1]
        $commandFunction = $filteredCommand[2]

        New-Item -Path "$env:SystemRoot\Temp\CHASTE-Script.ps1" -ItemType File -Force | Out-Null
        addScript -directory $commandDirectory -file $commandFile
        addScript -directory "core" -file "Framework"
        Add-Content -Path "$env:SystemRoot\Temp\CHASTE-Script.ps1" -Value "invokeScript '$commandFunction'"
        Add-Content -Path "$env:SystemRoot\Temp\CHASTE-Script.ps1" -Value "readCommand"

        $chasteScript = Get-Content -Path "$env:SystemRoot\Temp\CHASTE-Script.ps1" -Raw
        Invoke-Expression $chasteScript
    } catch {
        writeText -type "error" -text "readCommand-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function filterCommands {
    param (
        [Parameter(Mandatory)]
        [string]$command
    )

    try {
        $commandArray = $()

        switch ($command) {
            "" { $commandArray = $("windows", "Helpers", "chasteScripts") }
            "help" { $commandArray = $("windows", "Helpers", "writeHelp") }
            "menu" { $commandArray = $("windows", "Helpers", "readMenu") }
            "toggle context menu" { $commandArray = $("windows", "Toggle Context Menu", "toggleContextMenu") }
            "enable context menu" { $commandArray = $("windows", "Toggle Context Menu", "enableContextMenu") }
            "disable context menu" { $commandArray = $("windows", "Toggle Context Menu", "disableContextMenu") }
            "toggle admin" { $commandArray = $("windows", "Toggle Admin", "toggleAdmin") }
            "enable admin" { $commandArray = $("windows", "Toggle Admin", "enableAdmin") }
            "disable admin" { $commandArray = $("windows", "Toggle Admin", "disableAdmin") }
            "add user" { $commandArray = $("windows", "Add User", "addUser") }
            "add local user" { $commandArray = $("windows", "Add User", "addLocalUser") }
            "add ad user" { $commandArray = $("windows", "Add User", "addADUser") }
            "add drive letter" { $commandArray = $("windows", "Add Drive Letter", "addDriveLetter") }
            "remove user" { $commandArray = $("windows", "Remove User", "removeUser") }
            "edit hostname" { $commandArray = $("windows", "Edit Hostname", "editHostname") }
            "edit user" { $commandArray = $("windows", "Edit User", "editUser") }
            "edit user name" { $commandArray = $("windows", "Edit User", "editUserName") }
            "edit user password" { $commandArray = $("windows", "Edit User", "editUserPassword") }
            "edit user group" { $commandArray = $("windows", "Edit User", "editUserGroup") }
            "edit net adapter" { $commandArray = $("windows", "Edit Net Adapter", "editNetAdapter") }
            "get wifi creds" { $commandArray = $("windows", "Get Wifi Creds", "getWifiCreds") }
            "schedule task" { $commandArray = $("windows", "Schedule Task", "scheduleTask") }
            "update windows" { $commandArray = $("windows", "Update Windows", "updateWindows") }
            "repair windows" { $commandArray = $("windows", "Repair Windows", "repairWindows") }
            "plugins" { $commandArray = $("plugins", "Helpers", "plugins") }
            "plugins menu" { $commandArray = $("plugins", "Helpers", "readMenu") }
            "plugins help" { $commandArray = $("plugins", "Helpers", "writeHelp") }
            "plugins reclaim" { $commandArray = $("plugins", "ReclaimW11", "reclaim") }
            "plugins massgravel" { $commandArray = $("plugins", "massgravel", "massgravel") }
            "plugins win11debloat" { $commandArray = $("plugins", "win11Debloat", "win11Debloat") }
            default { 
                Write-Host "  Unrecognized command `"$command`". Try" -NoNewline
                Write-Host " help" -ForegroundColor "Cyan" -NoNewline
                Write-Host " or" -NoNewline
                Write-Host " menu" -NoNewline -ForegroundColor "Cyan"
                Write-Host " to learn more."
                readCommand 
            }
        }

        return $commandArray
    } catch {
        writeText -type "error" -text "filterCommands-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function addScript {
    param (
        [Parameter(Mandatory)]
        [string]$directory,
        [Parameter(Mandatory)]
        [string]$file
    )

    try {
        $url = "https://raw.githubusercontent.com/badsyntaxx/chaste-scripts/main"

        $download = getDownload -url "$url/$directory/$file.ps1" -target "$env:SystemRoot\Temp\$file.ps1" -hide

        if ($download -eq $true) {
            $rawScript = Get-Content -Path "$env:SystemRoot\Temp\$file.ps1" -Raw -ErrorAction SilentlyContinue
            Add-Content -Path "$env:SystemRoot\Temp\CHASTE-Script.ps1" -Value $rawScript

            Get-Item -ErrorAction SilentlyContinue "$env:SystemRoot\Temp\$file.ps1" | Remove-Item -ErrorAction SilentlyContinue
        }
    } catch {
        writeText -type "error" -text "addScript-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function writeText {
    param (
        [parameter(Mandatory = $false)]
        [string]$label = "",
        [parameter(Mandatory = $false)]
        [string]$text = "",
        [parameter(Mandatory = $false)]
        [string]$type = "plain",
        [parameter(Mandatory = $false)]
        [string]$Color = "Gray",
        [parameter(Mandatory = $false)]
        [switch]$lineBefore = $false, # Add a new line before output if specified
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false, # Add a new line after output if specified
        [parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary]$List,
        [parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary]$oldData,
        [parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary]$newData
    )

    try {
        # Add a new line before output if specified
        if ($lineBefore) { Write-Host }

        # Format output based on the specified Type
        if ($type -eq "header") {
            $l = $([char]0x2500)
            Write-Host "# " -ForegroundColor "Cyan" -NoNewline
            Write-Host "$text" -ForegroundColor "White" 
            Write-host "$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l$l" -ForegroundColor "Cyan"
        }

        if ($type -eq 'success') { 
            Write-Host
            Write-Host
            Write-Host "    $([char]0x2713) $text"  -ForegroundColor "Green"
            Write-Host
        }

        if ($type -eq 'error') { 
            Write-Host
            Write-Host
            Write-Host "    X $text" -ForegroundColor "Red"
            Write-Host 
        }

        if ($type -eq 'notice') { 
            Write-Host "! $text" -ForegroundColor "Yellow" 
        }

        if ($type -eq 'plain') {
            if ($label -ne "") { 
                if ($Color -eq "Gray") {
                    $Color = 'DarkCyan'
                }
                Write-Host "  $label`: " -NoNewline -ForegroundColor "Gray"
                Write-Host "$text" -ForegroundColor $Color 
            } else {
                Write-Host "  $text" -ForegroundColor $Color 
            }
        }

        if ($type -eq 'list') { 
            # Get a list of keys from the options dictionary
            $orderedKeys = $List.Keys | ForEach-Object { $_ }

            # Find the length of the longest key for padding
            $longestKeyLength = ($orderedKeys | Measure-Object -Property Length -Maximum).Maximum

            # Display single option if only one exists
            if ($orderedKeys.Count -eq 1) {
                Write-Host " $($orderedKeys) $(" " * ($longestKeyLength - $orderedKeys.Length)) - $($List[$orderedKeys])"
            } else {
                # Loop through each option and display with padding and color
                for ($i = 0; $i -lt $orderedKeys.Count; $i++) {
                    $key = $orderedKeys[$i]
                    $padding = " " * ($longestKeyLength - $key.Length)
                    Write-Host "    $($key): $padding $($List[$key])" -ForegroundColor $Color
                }
            }
        }

        # Add a new line after output if specified
        if ($lineAfter) { Write-Host }
    } catch {
        writeText -type "error" -text "writeText-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function readInput {
    param (
        [parameter(Mandatory = $false)]
        [string]$Value = "", # A pre-fill value so the user can hit enter without typing command and get the current value if there is one
        [parameter(Mandatory = $false)]
        [string]$prompt, # Provide a specific prompt in necessary
        [parameter(Mandatory = $false)]
        [regex]$Validate = $null,
        [parameter(Mandatory = $false)]
        [string]$ErrorMessage = "", # Provide an optional error message
        [parameter(Mandatory = $false)]
        [switch]$IsSecure = $false, # If prompting for a password
        [parameter(Mandatory = $false)]
        [switch]$CheckExistingUser = $false,
        [parameter(Mandatory = $false)]
        [switch]$lineBefore = $false, # Add a new line before prompt if specified
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false # Add a new line after prompt if specified
    )

    try {
        # Add a new line before prompt if specified
        if ($lineBefore) { Write-Host }

        # Get current cursor position
        $currPos = $host.UI.RawUI.CursorPosition

        Write-Host "? " -NoNewline -ForegroundColor "Green"
        Write-Host "$prompt " -NoNewline

        if ($IsSecure) { $userInput = Read-Host -AsSecureString } 
        else { $userInput = Read-Host }

        # Check for existing user if requested
        if ($CheckExistingUser) {
            $account = Get-LocalUser -Name $userInput -ErrorAction SilentlyContinue
            if ($null -ne $account) { $ErrorMessage = "An account with that name already exists." }
        }

        # Validate user input against provided regular expression
        if ($userInput -notmatch $Validate) { $ErrorMessage = "Invalid input. Please try again." } 

        # Display error message if encountered
        if ($ErrorMessage -ne "") {
            writeText -type "error" -text $ErrorMessage
            # Recursively call readInput if user exists
            if ($CheckExistingUser) { return readInput -prompt $prompt -Validate $Validate -CheckExistingUser } 

            # Otherwise, simply call again without CheckExistingUser
            else { return readInput -prompt $prompt -Validate $Validate }
        }

        # Use provided default value if user enters nothing for a non-secure input
        if ($userInput.Length -eq 0 -and $Value -ne "" -and !$IsSecure) { $userInput = $Value }

        # Reset cursor position
        [Console]::SetCursorPosition($currPos.X, $currPos.Y)
        
        Write-Host "? " -ForegroundColor "Green" -NoNewline
        if ($IsSecure -and ($userInput.Length -eq 0)) { 
            Write-Host "$prompt                                                "
        } else { 
            Write-Host "$prompt " -NoNewline
            Write-Host "$userInput                                             " -ForegroundColor "DarkCyan"
        }

        # Add a new line after prompt if specified
        if ($lineAfter) { Write-Host }
    
        # Return the validated user input
        return $userInput
    } catch {
        writeText -type "error" -text "readInput-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function readOption {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$options,
        [parameter(Mandatory = $false)]
        [string]$prompt, # Provide a specific prompt in necessary
        [parameter(Mandatory = $false)]
        [switch]$returnKey = $false,
        [parameter(Mandatory = $false)]
        [switch]$returnValue = $false,
        [parameter(Mandatory = $false)]
        [switch]$lineBefore = $false,
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false
    )

    try {
        # Add a line break before the menu if lineBefore is specified
        if ($lineBefore) { Write-Host }

        # Get current cursor position
        $promptPos = $host.UI.RawUI.CursorPosition

        Write-Host "? " -NoNewline -ForegroundColor "Green"
        Write-Host "$prompt "

        # Initialize variables for user input handling
        $vkeycode = 0
        $pos = 0
        $oldPos = 0

        # Get a list of keys from the options dictionary
        $orderedKeys = $options.Keys | ForEach-Object { $_ }

        # Get an array of all values
        $values = $options.Values

        # Find the length of the longest key for padding
        $longestKeyLength = ($orderedKeys | ForEach-Object { "$_".Length } | Measure-Object -Maximum).Maximum

        # Find the length of the longest value
        $longestValueLength = ($values | ForEach-Object { "$_".Length } | Measure-Object -Maximum).Maximum

        # Display single option if only one exists
        if ($orderedKeys.Count -eq 1) {
            Write-Host "$([char]0x2192)" -ForegroundColor "DarkCyan" -NoNewline
            Write-Host "  $($orderedKeys) $(" " * ($longestKeyLength - $orderedKeys.Length)) - $($options[$orderedKeys])" -ForegroundColor "DarkCyan"
        } else {
            # Loop through each option and display with padding and color
            for ($i = 0; $i -lt $orderedKeys.Count; $i++) {
                $key = $orderedKeys[$i]
                $padding = " " * ($longestKeyLength - $key.Length)
                if ($i -eq $pos) { 
                    Write-Host "$([char]0x2192)" -ForegroundColor "DarkCyan" -NoNewline  
                    Write-Host " $key $padding - $($options[$key])" -ForegroundColor "DarkCyan"
                } else { 
                    Write-Host "  $key $padding - $($options[$key])" -ForegroundColor "Gray" 
                }
            }
        }

        # Get the current cursor position
        $currPos = $host.UI.RawUI.CursorPosition

        # Loop for user input to select an option
        While ($vkeycode -ne 13) {
            $press = $host.ui.rawui.readkey("NoEcho, IncludeKeyDown")
            $vkeycode = $press.virtualkeycode
            Write-host "$($press.character)" -NoNewLine
            if ($orderedKeys.Count -ne 1) { 
                $oldPos = $pos;
                if ($vkeycode -eq 38) { $pos-- }
                if ($vkeycode -eq 40) { $pos++ }
                if ($pos -lt 0) { $pos = 0 }
                if ($pos -ge $orderedKeys.Count) { $pos = $orderedKeys.Count - 1 }

                # Calculate positions for redrawing menu items
                $menuLen = $orderedKeys.Count
                $menuOldPos = New-Object System.Management.Automation.Host.Coordinates(0, ($currPos.Y - ($menuLen - $oldPos)))
                $menuNewPos = New-Object System.Management.Automation.Host.Coordinates(0, ($currPos.Y - ($menuLen - $pos)))
                $oldKey = $orderedKeys[$oldPos]
                $newKey = $orderedKeys[$pos]
            
                # Re-draw the previously selected and newly selected options
                $host.UI.RawUI.CursorPosition = $menuOldPos
                Write-Host "  $($orderedKeys[$oldPos]) $(" " * ($longestKeyLength - $oldKey.Length)) - $($options[$orderedKeys[$oldPos]])" -ForegroundColor "Gray"
                $host.UI.RawUI.CursorPosition = $menuNewPos
                Write-Host "$([char]0x2192)" -ForegroundColor "DarkCyan" -NoNewline
                Write-Host " $($orderedKeys[$pos]) $(" " * ($longestKeyLength - $newKey.Length)) - $($options[$orderedKeys[$pos]])" -ForegroundColor "DarkCyan"
                $host.UI.RawUI.CursorPosition = $currPos
            }
        }

        [Console]::SetCursorPosition($promptPos.X, $promptPos.Y)

        if ($orderedKeys.Count -ne 1) {
            Write-Host "? " -ForegroundColor "Green" -NoNewline
            Write-Host $prompt -NoNewline
            Write-Host " $($orderedKeys[$pos])" -ForegroundColor "DarkCyan"
        } else {
            Write-Host "? " -ForegroundColor "Green" -NoNewline
            Write-Host $prompt -NoNewline
            Write-Host " $($orderedKeys) $(" " * ($longestKeyLength - $orderedKeys.Length))" -ForegroundColor "DarkCyan"
        }

        for ($i = 0; $i -lt $options.Count; $i++) {
            Write-Host "       $(" " * ($longestKeyLength + $longestValueLength))"
        }
        
        [Console]::SetCursorPosition($promptPos.X, $promptPos.Y)
        Write-Host

        # Add a line break after the menu if lineAfter is specified
        if ($lineAfter) { Write-Host }

        # Handle function return values (key, value, menu position) based on parameters
        if ($returnKey) { 
            if ($orderedKeys.Count -eq 1) { 
                return $orderedKeys 
            } else { 
                return $orderedKeys[$pos] 
            } 
        } 
        if ($returnValue) { 
            if ($orderedKeys.Count -eq 1) { 
                return $options[$pos] 
            } else { 
                return $options[$orderedKeys[$pos]] 
            } 
        } else { 
            return $pos 
        }
    } catch {
        writeText -type "error" -text "readOption-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function getDownload {
    param (
        [parameter(Mandatory)]
        [string]$url,
        [parameter(Mandatory)]
        [string]$target,
        [parameter(Mandatory = $false)]
        [string]$label = "",
        [parameter(Mandatory = $false)]
        [string]$failText = 'Download failed...',
        [parameter(Mandatory = $false)]
        [switch]$lineBefore = $false,
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false,
        [parameter(Mandatory = $false)]
        [switch]$hide = $false
    )
    Begin {
        function Show-Progress {
            param (
                [parameter(Mandatory)]
                [Single]$totalValue,
                [parameter(Mandatory)]
                [Single]$currentValue,
                [parameter(Mandatory = $false)]
                [switch]$complete = $false
            )
            
            # calc %
            $barSize = 30
            $percent = $currentValue / $totalValue
            $percentComplete = $percent * 100
  
            # build progressbar with string function
            $curBarSize = $barSize * $percent
            $progbar = ""
            $progbar = $progbar.PadRight($curBarSize, [char]9608)
            $progbar = $progbar.PadRight($barSize, [char]9617)

            if ($complete) {
                Write-Host -NoNewLine "`r  $progbar Complete"
            } else {
                Write-Host -NoNewLine "`r  $progbar $($percentComplete.ToString("##0.00").PadLeft(6))%"
            }          
        }
    }
    Process {
        $downloadComplete = $true 
        for ($retryCount = 1; $retryCount -le 2; $retryCount++) {
            try {
                $storeEAP = $ErrorActionPreference
                $ErrorActionPreference = 'Stop'
        
                # invoke request
                $request = [System.Net.HttpWebRequest]::Create($url)
                $response = $request.GetResponse()
  
                if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403 -or $response.StatusCode -eq 404) {
                    throw "Remote file either doesn't exist, is unauthorized, or is forbidden for '$url'."
                }
  
                if ($target -match '^\.\\') {
                    $target = Join-Path (Get-Location -PSProvider "FileSystem") ($target -Split '^\.')[1]
                }
            
                if ($target -and !(Split-Path $target)) {
                    $target = Join-Path (Get-Location -PSProvider "FileSystem") $target
                }

                if ($target) {
                    $fileDirectory = $([System.IO.Path]::GetDirectoryName($target))
                    if (!(Test-Path($fileDirectory))) {
                        [System.IO.Directory]::CreateDirectory($fileDirectory) | Out-Null
                    }
                }

                [long]$fullSize = $response.ContentLength
                $fullSizeMB = $fullSize / 1024 / 1024
  
                # define buffer
                [byte[]]$buffer = new-object byte[] 1048576
                [long]$total = [long]$count = 0
  
                # create reader / writer
                $reader = $response.GetResponseStream()
                $writer = new-object System.IO.FileStream $target, "Create"
                
                if ($lineBefore) { Write-Host }

                if (-not $hide -and $label -ne "") {
                    Write-Host  "  $label" -ForegroundColor "Yellow"
                }
                # start download
                $finalBarCount = 0 #Show final bar only one time
                do {
                    $count = $reader.Read($buffer, 0, $buffer.Length)
          
                    $writer.Write($buffer, 0, $count)
              
                    $total += $count
                    $totalMB = $total / 1024 / 1024
                    if (-not $hide) {
                        if ($fullSize -gt 0) {
                            Show-Progress -totalValue $fullSizeMB -currentValue $totalMB
                        }

                        if ($total -eq $fullSize -and $count -eq 0 -and $finalBarCount -eq 0) {
                            Show-Progress -totalValue $fullSizeMB -currentValue $totalMB -complete
                            $finalBarCount++
                        }
                    }
                } while ($count -gt 0)

                if (-not $hide) {
                    Write-Host
                }

                # Prevent the following output from appearing on the same line as the progress bar
                if ($lineAfter) { 
                    Write-Host
                }
                
                if ($downloadComplete) { 
                    return $true 
                } else { 
                    return $false 
                }
            } catch {
                $downloadComplete = $false
            
                if ($retryCount -lt 2) {
                    writeText -type "plain" -text "Retrying..."
                    Start-Sleep -Seconds 1
                } else {
                    writeText -type "error" -text "getDownload-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
                }
            } finally {
                # cleanup
                if ($reader) { $reader.Close() }
                if ($writer) { $writer.Flush(); $writer.Close() }
        
                $ErrorActionPreference = $storeEAP
                [GC]::Collect()
            } 
        }   
    }
}
function getUserData {
    param (
        [parameter(Mandatory = $true)]
        [string]$username
    )

    try {
        $user = Get-LocalUser -Name $username
        $groups = Get-LocalGroup | Where-Object { $user.SID -in ($_ | Get-LocalGroupMember | Select-Object -ExpandProperty "SID") } | Select-Object -ExpandProperty "Name"
        $userProfile = Get-CimInstance Win32_UserProfile -Filter "SID = '$($user.SID)'"
        $dir = $userProfile.LocalPath
        if ($null -ne $userProfile) { $dir = $userProfile.LocalPath } else { $dir = "Awaiting first sign in." }

        $source = Get-LocalUser -Name $username | Select-Object -ExpandProperty PrincipalSource

        $data = [ordered]@{
            "Name"   = "$username"
            "Groups" = "$($groups -join ';')"
            "Path"   = "$dir"
            "Source" = "$source"
        }

        return $data
    } catch {
        writeText -type "error" -text "getUserData-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function selectUser {
    param (
        [parameter(Mandatory = $false)]
        [string]$prompt = "Select a user account:",
        [parameter(Mandatory = $false)]
        [switch]$lineBefore = $false,
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false,
        [parameter(Mandatory = $false)]
        [switch]$writeResult = $false
    )

    try {
        # Add a line break before the menu if lineBefore is specified
        if ($lineBefore) { Write-Host }
         
        # Initialize empty array to store user names
        $userNames = @()

        # Get all local users on the system
        $localUsers = Get-LocalUser

        # Define a list of accounts to exclude from selection
        $excludedAccounts = @("DefaultAccount", "WDAGUtilityAccount", "Guest", "defaultuser0")

        # Check if the "Administrator" account is disabled and add it to excluded list if so
        $adminEnabled = Get-LocalUser -Name "Administrator" | Select-Object -ExpandProperty Enabled
        if (!$adminEnabled) { $excludedAccounts += "Administrator" }

        # Filter local users to exclude predefined accounts
        foreach ($user in $localUsers) {
            if ($user.Name -notin $excludedAccounts) { $userNames += $user.Name }
        }

        # Create an ordered dictionary to store username and group information
        $accounts = [ordered]@{}
        foreach ($name in $userNames) {
            # Get details for the current username
            $username = Get-LocalUser -Name $name
            
            # Find groups the user belongs to
            $groups = Get-LocalGroup | Where-Object { $username.SID -in ($_ | Get-LocalGroupMember | Select-Object -ExpandProperty "SID") } | Select-Object -ExpandProperty "Name"
            # Convert groups to a semicolon-separated string
            $groupString = $groups -join ';'

            # Get the users source
            $source = Get-LocalUser -Name $username | Select-Object -ExpandProperty PrincipalSource

            # Add username and group string to the dictionary
            $accounts["$username"] = "$source | $groupString"
        }

        $accounts["Cancel"] = "Do not select a user and exit this function."

        # Prompt user to select a user from the list and return the key (username)
        $choice = readOption -options $accounts -prompt $prompt -returnKey

        if ($choice -eq "Cancel") {
            readCommand
        }

        # Get user data using the selected username
        $data = getUserData -Username $choice

        if ($writeResult) {
            Write-Host
            # Display user data as a list
            writeText -type "list" -List $data -Color "Green"
        }

        # Add a line break after the menu if lineAfter is specified
        if ($lineAfter) { Write-Host }

        # Return the user data dictionary
        return $data
    } catch {
        writeText -type "error" -text "selectUser-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}


invokeScript 'editNetAdapter'
readCommand
