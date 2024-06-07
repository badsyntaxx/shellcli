function get-wifi-creds {
    $wifiProfiles = netsh wlan show profiles
    if ($wifiProfiles -match "There is no wireless interface on the system.") {
        get-cscommand
    }

    $wifiList = ($wifiProfiles | Select-String -Pattern "\w*All User Profile.*: (.*)" -AllMatches).Matches |
    ForEach-Object { $_.Groups[1].Value }

    write-text -type 'header' -text "Found $($wifiList.Count) Wi-Fi Connection settings stored on the system:"  -lineAfter

    foreach ($ssid in $wifiList) {
        try {
            $password = (netsh wlan show profile name="$ssid" key=clear | Select-String -Pattern ".*Key Content.*: (.*)" -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value }
        } catch {
            $password = "N/A"
        }

        Write-Host "    ${ssid}: " -NoNewLine  -ForegroundColor DarkGray
        Write-Host "$password"
    }
   
    get-cscommand
}
