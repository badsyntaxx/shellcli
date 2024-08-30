function write-help {
    writeText -type "header" -text "COMMANDS:" -lineBefore
    writeText -type "plain" -text "plugins massgravel    - https://github.com/massgravel/Microsoft-Activation-Scripts" -Color "DarkGray"
    writeText -type "plain" -text "plugins reclaimw11    - https://gist.github.com/DanielLarsenNZ/edc6dd611418581ef90b02ad8e23b363#file-reclaim-windows-11-ps1" -Color "DarkGray"
    writeText -type "plain" -text "plugins win11debloat  - https://github.com/Raphire/Win11Debloat" -Color "DarkGray"

    $choice = readOption -options $([ordered]@{
            "Yes" = "Open the plugins menu."
            "No"  = "Manually enter commands."
        }) -prompt "Open the menu now?" -lineBefore

    if ($choice -eq 0) {
        readCommand -command "plugins"
    }
}