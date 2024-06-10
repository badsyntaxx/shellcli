Get-NetAdapter -InterfaceAlias "*" | ForEach-Object {
    $adapter = $_
  
    $ipv4Address = (Get-NetIPAddress -InterfaceIndex $adapter.ifindex).IPv4Address
    $subnetMask = (Get-NetIPAddress -InterfaceIndex $adapter.ifindex).SubnetMask
  
    $defaultGateway = Get-NetRoute | Where-Object { $_.NextHop -eq $adapter.IPAddress } | Select-Object -ExpandProperty NextHop
  
    $dnsServers = Get-DnsClientServerAddress -InterfaceAlias $adapter.Name | Select-Object IPAddress
  
    # Display information in a formatted table
    New-Object PSObject -Property @{
        Name              = $adapter.Name
        MACAddress        = $adapter.MacAddress
        "IPv4 Address"    = $ipv4Address
        SubnetMask        = $subnetMask
        "Default Gateway" = $defaultGateway
        "DNS Servers"     = $dnsServers
    } | Format-Table -AutoSize
}