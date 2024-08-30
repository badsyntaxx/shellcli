function writeHelp {
    writeText -type "plain" -text "COMMANDS:"
    writeText -type "plain" -text "toggle admin                     - Toggle the Windows built-in administrator account." -Color "DarkGray"
    writeText -type "plain" -text "add [local,domain] user          - Add a local or domain user to the system." -Color "DarkGray"
    writeText -type "plain" -text "edit user [name,password,group]  - Edit user account settings." -Color "DarkGray"
    writeText -type "plain" -text "edit net adapter                 - Edit network adapter settings like IP and DNS." -Color "DarkGray"
    writeText -type "plain" -text "get wifi creds                   - View WiFi credentials saved on the system." -Color "DarkGray"
    writeText -type "plain" -text "plugins [plugin name]            - Useful scripts made by others. Try the 'plugins help' command." -Color "DarkGray"
    writeText -type "plain" -text "FULL DOCUMENTATION:" -lineBefore
    writeText -type "plain" -text "https://guided.chaste.pro/dev/chaste-scripts" -Color "DarkGray"
}