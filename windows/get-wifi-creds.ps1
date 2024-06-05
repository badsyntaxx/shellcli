function get-wifi-password {
    write-welcome -Title "Get WiFi Password" -Description "View the currently used WiFi password." -Command "get wifi password"

    $ssid = (Get-NetConnectionProfile).Name
    write-text -Type "header" -Text "Viewing the WiFi Password for $ssid" -LineBefore -LineAfter

    $profileInfo = netsh wlan show profile name=$ssid key=clear
    $password = $profileInfo | Select-String -Pattern "Key Content" | ForEach-Object { $_.ToString().Split(":")[1].Trim() }

    # netsh wlan show profile name="$ssid" key=clear

    exit-script -Type "success" -Text $password -LineAfter
}
