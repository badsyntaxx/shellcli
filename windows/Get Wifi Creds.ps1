function getWifiCreds {
    try {
        $wifiProfiles = netsh wlan show profiles
        if ($wifiProfiles -match "There is no wireless interface on the system.") {
            writeText -type "error" -text "There is no wireless interface on the system." -lineBefore -lineAfter
            readCommand
        }

        if ((Get-Service wlansvc).Status -ne "Running") {
            writeText -type "notice" -text "The wlansvc service is not running or the wireless adapter is disabled." -lineBefore -lineAfter
            readCommand
        }

        if ($wifiProfiles.Count -gt 0) {
            $wifiList = ($wifiProfiles | Select-String -Pattern "\w*All User Profile.*: (.*)" -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value }
        } else {
            writeText -type "error" -text "No WiFi profiles found." -lineBefore -lineAfter
            readCommand
        }

        Write-Host " $([char]0x251C)" -NoNewline -ForegroundColor "Gray"
        Write-Host " Found $($wifiList.Count) Wi-Fi Connection settings stored on the system:" -lineAfter

        foreach ($ssid in $wifiList) {
            try {
                $password = (netsh wlan show profile name="$ssid" key=clear | Select-String -Pattern ".*Key Content.*: (.*)" -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value }
            } catch {
                $password = "N/A"
            }

            Write-Host " $([char]0x2502)" -NoNewline -ForegroundColor "Gray"
            Write-Host "  ${ssid}: " -NoNewLine  -ForegroundColor DarkGray
            Write-Host "$password"
        }
   
        Write-Host
    } catch {
        writeText -type "error" -text "getWifiCreds-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
