function get-wifi-creds {
    try {
        $wifiProfiles = netsh wlan show profiles
        if ($wifiProfiles -match "There is no wireless interface on the system.") {
            write-text -type "error" -text "There is no wireless interface on the system." -lineBefore -lineAfter
            read-command
        }

        if ((Get-Service wlansvc).Status -ne "Running") {
            write-text -type "notice" -text "The wlansvc service is not running or the wireless adapter is disabled." -lineBefore -lineAfter
            read-command
        }

        if ($wifiProfiles.Count -gt 0) {
            $wifiList = ($wifiProfiles | Select-String -Pattern "\w*All User Profile.*: (.*)" -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value }
        } else {
            write-text -type "error" -text "No WiFi profiles found." -lineBefore -lineAfter
            read-command
        }

        write-text -type 'label' -text "Found $($wifiList.Count) Wi-Fi Connection settings stored on the system:" -lineBefore -lineAfter

        foreach ($ssid in $wifiList) {
            try {
                $password = (netsh wlan show profile name="$ssid" key=clear | Select-String -Pattern ".*Key Content.*: (.*)" -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value }
            } catch {
                $password = "N/A"
            }

            Write-Host "  ${ssid}: " -NoNewLine  -ForegroundColor DarkGray
            Write-Host "$password"
        }
   
        Write-Host
    } catch {
        write-text -type "error" -text "get-wifi-creds-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
    
}
