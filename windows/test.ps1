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

function invoke-script {
    param (
        [parameter(Mandatory = $true)]
        [string]$script,
        [parameter(Mandatory = $false)]
        [boolean]$initialize = $false
    ) 

    try {
        # Check if user has administrator privileges
        if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
            # If not, elevate privileges and restart function with current arguments
            Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
            Exit
        } 

        # Customize console appearance
        $console = $host.UI.RawUI
        $console.BackgroundColor = "Black"
        $console.ForegroundColor = "Gray"
        $console.WindowTitle = "Chased Scripts"

        if ($initialize) {
            # Display a stylized menu prompt
            Clear-Host
            Write-Host
            Write-Host "  Welcome to Chased Scripts" -ForegroundColor DarkCyan
            Write-Host "  Enter" -ForegroundColor DarkGray -NoNewLine
            Write-Host " menu" -ForegroundColor Gray -NoNewLine
            Write-Host " or" -ForegroundColor DarkGray -NoNewLine
            Write-Host " help" -ForegroundColor Gray -NoNewLine
            Write-Host " if you don't know commands." -ForegroundColor DarkGray
            Write-Host
        }

        # Call the script specified by the parameter
        Invoke-Expression $script
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "invoke-script-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

function read-command {
    param (
        [Parameter(Mandatory = $false)]
        [string]$command = ""
    )

    try {
        # Get the command from the user
        if ($command -eq "") { 
            # Right carrot icon, this is a prompt for a command in CHASED Scripts
            Write-Host "  $([char]0x203A) " -NoNewline 
            $command = Read-Host 
        }

        # Convert the command to lowercase
        $command = $command.ToLower()

        # Trim leading and trailing spaces
        $command = $command.Trim()

        # Extract the first word
        if ($command -ne "" -and $command -match "^(?-i)(\w+(-\w+)*)") { $firstWord = $matches[1] }

        if (Get-command $firstWord -ErrorAction SilentlyContinue) {
            Invoke-Expression $command
            read-command
        }

        # Adjust command and paths
        $subCommands = @("windows", "plugins");
        $subPath = "windows"
        foreach ($sub in $subCommands) {
            if ($firstWord -eq $sub -and $firstWord -ne 'menu') { 
                $command = $command -replace "^$firstWord \s*", "" 
                $subPath = $sub
            } elseif ($firstWord -eq 'menu') {
                $subPath = "core"
            }
        }

        # Convert command to title case and replace the first spaces with a dash and the second space with no space
        $lowercaseCommand = $command.ToLower()
        $fileFunc = $lowercaseCommand -replace ' ', '-'

        # Create the main script file
        New-Item -Path "$env:TEMP\CHASED-Script.ps1" -ItemType File -Force | Out-Null

        add-script -subPath $subPath -script $fileFunc
        add-script -subpath "core" -script "framework"

        # Add a final line that will invoke the desired function
        Add-Content -Path "$env:TEMP\CHASED-Script.ps1" -Value "invoke-script '$fileFunc'"

        # Execute the combined script
        $chasedScript = Get-Content -Path "$env:TEMP\CHASED-Script.ps1" -Raw
        Invoke-Expression $chasedScript
    } catch {
        # Error handling: display an error message and prompt for a new command
        Write-Host "    $($_.Exception.Message) | init-$($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
        read-command
    }
}

function add-script {
    param (
        [Parameter(Mandatory)]
        [string]$subPath,
        [Parameter(Mandatory)]
        [string]$script,
        [Parameter(Mandatory = $false)]
        [string]$progressText
    )

    $url = "https://raw.githubusercontent.com/badsyntaxx/chased-scripts/main"

    # Download the script
    $download = get-download -Url "$url/$subPath/$script.ps1" -Target "$env:TEMP\$script.ps1" -failText "Could not acquire components..."
    if (!$download) { read-command }

    # Append the script to the main script
    $rawScript = Get-Content -Path "$env:TEMP\$script.ps1" -Raw -ErrorAction SilentlyContinue
    Add-Content -Path "$env:TEMP\CHASED-Script.ps1" -Value $rawScript

    # Remove the script file
    Get-Item -ErrorAction SilentlyContinue "$env:TEMP\$script.ps1" | Remove-Item -ErrorAction SilentlyContinue
}

function get-help() {
    write-text -type "plain" -text "## CHASED SCRIPTS:" -Color "DarkGray" -lineBefore
    write-text -type "plain" -text "    Chased scripts aims to simplify tedious powershell commands and make common IT tasks" -Color "DarkGray"
    write-text -type "plain" -text "    simpler by keeping commands logical, intuitive and short." -Color "DarkGray" -lineAfter
    write-text -type "plain" -text "## DOCS:" -Color "DarkGray" -lineBefore 
    write-text -type "plain" -text "    https://chased.dev/chased-scripts" -Color "DarkGray" -lineAfter
    write-text -type "plain" -text "## COMMANDS:" -Color "DarkGray" -lineBefore
    write-text -type "plain" -text "    enable admin                     - Toggle the Windows built-in administrator account." -Color "DarkGray"
    write-text -type "plain" -text "    add [ local, domain ] user          - Add a local or domain user to the system." -Color "DarkGray"
    write-text -type "plain" -text "    edit user [ name, password, group ]  - Edit user account settings." -Color "DarkGray"
    write-text -type "plain" -text "    edit net adapter                 - Edit network adapter settings like IP and DNS." -Color "DarkGray"
    write-text -type "plain" -text "    get wifi creds                   - View WiFi credentials saved on the system." -Color "DarkGray" -lineAfter
    read-command # Recursively call itself to prompt for a new command
}

function write-text {
    param (
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
        if ($type -eq "label") { Write-Host "    $text" -ForegroundColor "Yellow" }
        if ($type -eq 'success') { Write-Host "    $text"  -ForegroundColor "Green" }
        if ($type -eq 'error') { Write-Host "    $text" -ForegroundColor "Red" }
        if ($type -eq 'notice') { Write-Host "    $text" -ForegroundColor "Yellow" }
        if ($type -eq 'plain') { Write-Host "    $text" -ForegroundColor $Color }
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
                    Write-Host "    $($key): $padding $($List[$key])" -ForegroundColor "DarkGray"
                }
            }
        }

        if ($type -eq 'fail') { 
            Write-Host "  X " -ForegroundColor "Red" -NoNewline
            Write-Host "$text" 
        }

        # Format output for data comparison
        if ($type -eq 'compare') { 
            foreach ($data in $oldData.Keys) {
                if ($oldData["$data"] -ne $newData["$data"]) {
                    write-compare -oldData $oldData["$data"] -newData $newData["$data"]
                } else {
                    Write-Host "    $($oldData["$data"])"
                }
            }
        }

        # Add a new line after output if specified
        if ($lineAfter) { Write-Host }
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "write-text-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

function write-compare() {
    param (
        [parameter(Mandatory)]
        [string]$oldData,
        [parameter(Mandatory)]
        [string]$newData
    )

    Write-Host "    $oldData" -ForegroundColor "DarkGray" -NoNewline
    Write-Host " $([char]0x2192) " -ForegroundColor "Magenta" -NoNewline
    Write-Host $newData -ForegroundColor "Gray"
}

function write-box {
    param (
        [parameter(Mandatory = $false)]
        [array]$Text
    )

    $horizontalLine = [string][char]0x2500
    $verticalLine = [string][char]0x2502
    $topLeft = [string][char]0x250C
    $topRight = [string][char]0x2510
    $bottomLeft = [string][char]0x2514
    $bottomRight = [string][char]0x2518
    $longestString = $Text | Sort-Object Length -Descending | Select-Object -First 1
    $count = $longestString.Length

    Write-Host " $topLeft$($horizontalLine * ($count + 2))$topRight" -ForegroundColor Cyan

    foreach ($line in $Text) {
        Write-Host " $verticalLine" -ForegroundColor Cyan -NoNewline
        
        Write-Host " $($line.PadRight($count))" -ForegroundColor White -NoNewline
        
        Write-Host " $verticalLine" -ForegroundColor Cyan
    }

    Write-Host " $bottomLeft$($horizontalLine * ($count + 2))$bottomRight" -ForegroundColor Cyan
}

function write-welcome {
    param (
        [parameter(Mandatory = $false)]
        [string]$command,
        [switch]$lineBefore = $false, # Add a new line before output if specified
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false # Add a new line after output if specified
    )

    # Add a new line before output if specified
    if ($lineBefore) { Write-Host }

    Write-Host
    Write-Host " ::"  -ForegroundColor "DarkCyan" -NoNewline
    Write-Host " Running command:" -NoNewline -ForegroundColor "DarkGray"
    Write-Host " $command" -ForegroundColor "Gray"

    # Add a new line after output if specified
    if ($lineAfter) { Write-Host }
}

function exit-script {
    param (
        [parameter(Mandatory = $false)]
        [string]$text = "",
        [parameter(Mandatory = $false)]
        [string]$type = "plain",
        [parameter(Mandatory = $false)]
        [switch]$lineBefore = $false, # Add a new line before output if specified
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false # Add a new line after output if specified
    )

    # Add a new line before output if specified
    if ($lineBefore) { Write-Host }
    write-text -type $Type -text $Text
    # Add a new line after output if specified
    if ($lineAfter) { Write-Host }
    read-command 
}

function get-download {
    param (
        [Parameter(Mandatory)]
        [string]$Url,
        [Parameter(Mandatory)]
        [string]$Target,
        [Parameter(Mandatory = $false)]
        [string]$ProgressText = 'Loading',
        [Parameter(Mandatory = $false)]
        [string]$failText = 'Download failed...',
        [parameter(Mandatory = $false)]
        [int]$MaxRetries = 2,
        [parameter(Mandatory = $false)]
        [int]$Interval = 1,
        [parameter(Mandatory = $false)]
        [switch]$visible = $false
    )
    Begin {
        function Show-Progress {
            param (
                [Parameter(Mandatory)]
                [Single]$TotalValue,
                [Parameter(Mandatory)]
                [Single]$CurrentValue,
                [Parameter(Mandatory)]
                [string]$ProgressText,
                [Parameter()]
                [string]$ValueSuffix,
                [Parameter()]
                [int]$BarSize = 40,
                [Parameter()]
                [switch]$Complete
            )
            
            # calc %
            $percent = $CurrentValue / $TotalValue
            $percentComplete = $percent * 100
            if ($ValueSuffix) {
                $ValueSuffix = " $ValueSuffix" # add space in front
            }
  
            # build progressbar with string function
            $curBarSize = $BarSize * $percent
            $progbar = ""
            $progbar = $progbar.PadRight($curBarSize, [char]9608)
            $progbar = $progbar.PadRight($BarSize, [char]9617)

            if (!$Complete.IsPresent) {
                Write-Host -NoNewLine "`r    $ProgressText $progbar $($percentComplete.ToString("##0.00").PadLeft(6))%"
            } else {
                Write-Host -NoNewLine "`r    $ProgressText $progbar $($percentComplete.ToString("##0.00").PadLeft(6))%"                    
            }              
             
        }
    }
    Process {
        $downloadComplete = $true 
        for ($retryCount = 1; $retryCount -le $MaxRetries; $retryCount++) {
            try {
                $storeEAP = $ErrorActionPreference
                $ErrorActionPreference = 'Stop'
        
                # invoke request
                $request = [System.Net.HttpWebRequest]::Create($Url)
                $response = $request.GetResponse()
  
                if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403 -or $response.StatusCode -eq 404) {
                    throw "Remote file either doesn't exist, is unauthorized, or is forbidden for '$Url'."
                }
  
                if ($Target -match '^\.\\') {
                    $Target = Join-Path (Get-Location -PSProvider "FileSystem") ($Target -Split '^\.')[1]
                }
            
                if ($Target -and !(Split-Path $Target)) {
                    $Target = Join-Path (Get-Location -PSProvider "FileSystem") $Target
                }

                if ($Target) {
                    $fileDirectory = $([System.IO.Path]::GetDirectoryName($Target))
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
                $writer = new-object System.IO.FileStream $Target, "Create"
  
                # start download
                $finalBarCount = 0 #show final bar only one time
                do {
                    $count = $reader.Read($buffer, 0, $buffer.Length)
          
                    $writer.Write($buffer, 0, $count)
              
                    $total += $count
                    $totalMB = $total / 1024 / 1024
          
                    if ($visible) {
                        if ($fullSize -gt 0) {
                            Show-Progress -TotalValue $fullSizeMB -CurrentValue $totalMB -ProgressText $ProgressText -ValueSuffix "MB"
                        }

                        if ($total -eq $fullSize -and $count -eq 0 -and $finalBarCount -eq 0) {
                            Show-Progress -TotalValue $fullSizeMB -CurrentValue $totalMB -ProgressText $ProgressText -ValueSuffix "MB" -Complete
                            $finalBarCount++
                        }
                    }
                } while ($count -gt 0)

                # Prevent the following output from appearing on the same line as the progress bar
                if ($visible) {
                    Write-Host 
                }
                
                if ($downloadComplete) { return $true } else { return $false }
            } catch {
                # write-text -type "fail" -text "$($_.Exception.Message)"
                write-text -type "fail" -text $failText
                
                $downloadComplete = $false
            
                if ($retryCount -lt $MaxRetries) {
                    write-text "Retrying..."
                    Start-Sleep -Seconds $Interval
                } else {
                    write-text -type "error" -text "Maximum retries reached." 
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

function read-input {
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

        # Display prompt with a diamond symbol (optional secure input for passwords)
        Write-Host "  $([char]0x203A) $prompt" -NoNewline 
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
            write-text -type "error" -text $ErrorMessage
            # Recursively call read-input if user exists
            if ($CheckExistingUser) { return read-input -prompt $prompt -Validate $Validate -CheckExistingUser } 

            # Otherwise, simply call again without CheckExistingUser
            else { return read-input -prompt $prompt -Validate $Validate }
        }

        # Use provided default value if user enters nothing for a non-secure input
        if ($userInput.Length -eq 0 -and $Value -ne "" -and !$IsSecure) { $userInput = $Value }

        # Reset cursor position
        [Console]::SetCursorPosition($currPos.X, $currPos.Y)
        
        # Display checkmark symbol and user input (masked for secure input)
        Write-Host "  $([char]0x2713) " -ForegroundColor "Green" -NoNewline
        if ($IsSecure -and ($userInput.Length -eq 0)) { Write-Host "$prompt                                                       " } 
        else { Write-Host "$Prompt$userInput                                             " }

        # Add a new line after prompt if specified
        if ($lineAfter) { Write-Host }
    
        # Return the validated user input
        return $userInput
    } catch {
        # Handle errors during input
        write-text -type "error" -text "Input Error: $($_.Exception.Message)"
    }
}

function read-option {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$options,
        [parameter(Mandatory = $false)]
        [switch]$returnKey = $false,
        [parameter(Mandatory = $false)]
        [switch]$ReturnValue = $false,
        [parameter(Mandatory = $false)]
        [boolean]$lineBefore = $true,
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false
    )

    try {
        # Add a line break before the menu if lineBefore is specified
        if ($lineBefore) { Write-Host }

        # Initialize variables for user input handling
        $vkeycode = 0
        $pos = 0
        $oldPos = 0

        # Get a list of keys from the options dictionary
        $orderedKeys = $options.Keys | ForEach-Object { $_ }

        # Find the length of the longest key for padding
        $longestKeyLength = ($orderedKeys | Measure-Object -Property Length -Maximum).Maximum

        # Display single option if only one exists
        if ($orderedKeys.Count -eq 1) {
            Write-Host "  $([char]0x203A)" -ForegroundColor "Gray" -NoNewline
            Write-Host " $($orderedKeys) $(" " * ($longestKeyLength - $orderedKeys.Length)) - $($options[$orderedKeys])" -ForegroundColor "Cyan"
        } else {
            # Loop through each option and display with padding and color
            for ($i = 0; $i -lt $orderedKeys.Count; $i++) {
                $key = $orderedKeys[$i]
                $padding = " " * ($longestKeyLength - $key.Length)
                if ($i -eq $pos) { 
                    Write-Host "  $([char]0x203A)" -ForegroundColor "Gray" -NoNewline  
                    Write-Host " $key $padding - $($options[$key])" -ForegroundColor "Cyan"
                } else { Write-Host "    $key $padding - $($options[$key])" -ForegroundColor "Gray" }
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
                Write-Host "    $($orderedKeys[$oldPos]) $(" " * ($longestKeyLength - $oldKey.Length)) - $($options[$orderedKeys[$oldPos]])" -ForegroundColor "Gray"
                $host.UI.RawUI.CursorPosition = $menuNewPos
                Write-Host "  $([char]0x203A)" -ForegroundColor "Gray" -NoNewline
                Write-Host " $($orderedKeys[$pos]) $(" " * ($longestKeyLength - $newKey.Length)) - $($options[$orderedKeys[$pos]])" -ForegroundColor "Cyan"
                $host.UI.RawUI.CursorPosition = $currPos
            }
        }

        if ($orderedKeys.Count -ne 1) {
            $host.UI.RawUI.CursorPosition = $menuNewPos
        } else {
            $host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates(0, ($currPos.Y - ($menuLen + 1)))
        }

        if ($orderedKeys.Count -ne 1) {
            Write-Host "  $([char]0x2713)" -ForegroundColor "Green" -NoNewline
            Write-Host " $($orderedKeys[$pos]) $(" " * ($longestKeyLength - $newKey.Length)) - $($options[$orderedKeys[$pos]])" -ForegroundColor "Cyan"
        } else {
            Write-Host "  $([char]0x2713)" -ForegroundColor "Green" -NoNewline
            Write-Host " $($orderedKeys[$pos])" -ForegroundColor "Cyan"
        }
        
        $host.UI.RawUI.CursorPosition = $currPos

        # Add a line break after the menu if lineAfter is specified
        if ($lineAfter) { Write-Host }

        # Handle function return values (key, value, menu position) based on parameters
        if ($returnKey) { if ($orderedKeys.Count -eq 1) { return $orderedKeys } else { return $orderedKeys[$pos] } } 
        if ($ReturnValue) { if ($orderedKeys.Count -eq 1) { return $options[$pos] } else { return $options[$orderedKeys[$pos]] } }
        else { return $pos }
    } catch {
        # Display error message and exit this script
        write-text -type "error" -text "Error | read-option-$($_.InvocationInfo.ScriptLineNumber)"
    }
}

function get-closing {
    param (
        [parameter(Mandatory = $false)]
        [string]$script = "",
        [parameter(Mandatory = $false)]
        [string]$customText = "Are you sure?"
    ) 

    write-text -type "label" -text $customText -lineBefore

    $choice = read-option -options $([ordered]@{
            "Submit" = "Submit and apply your changes." 
            "Rest"   = "Discard changes and start this task over at the beginning."
            "Exit"   = "Exit this task but remain in the CHASED Scripts CLI." 
        }) -lineAfter

    if ($choice -eq 1) { 
        if ($script -ne "") { invoke-script $script } 
        else { read-command }
    }
    if ($choice -eq 2) { read-command }
}

function get-userdata {
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
        write-text -type "error" -text "Error getting account info: $($_.Exception.Message)"
    }
}

function select-user {
    try {
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

        # Prompt user to select a user from the list and return the key (username)
        $choice = read-option -options $accounts -returnKey -lineAfter

        # Get user data using the selected username
        $data = get-userdata -Username $choice

        # Display user data as a list
        write-text -type "list" -List $data

        # Return the user data dictionary
        return $data
    } catch {
        # Handle errors during user selection
        write-text -type "error" -text "Select user error: $($_.Exception.Message)"
    }
}
invoke-script 'edit-net-adapter'
