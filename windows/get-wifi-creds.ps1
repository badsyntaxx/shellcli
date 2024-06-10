function get-wifi-creds {
    $wifiProfiles = netsh wlan show profiles
    if ($wifiProfiles -match "There is no wireless interface on the system.") {
        exit-script -type "error" -text "There is no wireless interface on the system." -lineBefore -lineAfter
    }

    if ((Get-Service wlansvc).Status -ne "Running") {
        exit-script -type "notice" -text "The wlansvc service is not running or the wireless adapter is disabled." -lineBefore -lineAfter
    }

    if ($wifiProfiles.Count -gt 0) {
        $wifiList = ($wifiProfiles | Select-String -Pattern "\w*All User Profile.*: (.*)" -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value }
    } else {
        exit-script -type "error" -text "No WiFi profiles found." -lineBefore -lineAfter
    }

    write-text -type 'label' -text "Found $($wifiList.Count) Wi-Fi Connection settings stored on the system:" -lineBefore -lineAfter

    foreach ($ssid in $wifiList) {
        try {
            $password = (netsh wlan show profile name="$ssid" key=clear | Select-String -Pattern ".*Key Content.*: (.*)" -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value }
        } catch {
            $password = "N/A"
        }

        Write-Host "    ${ssid}: " -NoNewLine  -ForegroundColor DarkGray
        Write-Host "$password"
    }
   
    Write-Host
    read-command
}
