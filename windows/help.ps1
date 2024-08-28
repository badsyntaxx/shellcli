function help {
    write-text -type "plain" -text "COMMANDS:"
    write-text -type "plain" -text "toggle admin                     - Toggle the Windows built-in administrator account." -Color "DarkGray"
    write-text -type "plain" -text "add [local,domain] user          - Add a local or domain user to the system." -Color "DarkGray"
    write-text -type "plain" -text "edit user [name,password,group]  - Edit user account settings." -Color "DarkGray"
    write-text -type "plain" -text "edit net adapter                 - Edit network adapter settings like IP and DNS." -Color "DarkGray"
    write-text -type "plain" -text "get wifi creds                   - View WiFi credentials saved on the system." -Color "DarkGray"
    write-text -type "plain" -text "plugins [plugin name]  - Useful scripts made by others. Try the 'plugins help' command." -Color "DarkGray"
    write-text -type "plain" -text "FULL DOCUMENTATION:" -lineBefore
    write-text -type "plain" -text "https://guided.chaste.pro/dev/chaste-scripts" -Color "DarkGray"

    $choice = read-option -options $([ordered]@{
            "Yes" = "Open the menu."
            "No"  = "Manually enter commands."
        }) -prompt "Open the menu now?" -lineBefore

    if ($choice -eq 0) {
        read-command -command "menu"
    }
}