# Run the netsh command to retrieve SSIDs
$networks = netsh wlan show networks

# Extract SSIDs using regex (assuming the output format remains consistent)
$ssids = $networks | Select-String -Pattern 'SSID\s+:\s+(.+)'

# Create an ordered dictionary
$ssidDictionary = [ordered]@{}

# Populate the dictionary with SSIDs and empty strings
foreach ($ssid in $ssids) {
    $ssidName = $ssid.Matches.Groups[1].Value
    $ssidDictionary[$ssidName] = ''
}

# Display the ordered dictionary
$ssidDictionary


netsh wlan show profile name="Nuvia ISR" key=clear