function writeHelp {
    writeText -type "plain" -text "USER COMMANDS:" -lineBefore
    writeText -type "plain" -text "add [local,ad] user              - Add a local or domain user to the system." -Color "DarkGray"
    writeText -type "plain" -text "remove user                      - Add a local or domain user to the system." -Color "DarkGray"
    writeText -type "plain" -text "edit user [name,password,group]  - Edit user account settings." -Color "DarkGray"
    writeText -type "plain" -text "SYSTEM COMMANDS:" -lineBefore
    writeText -type "plain" -text "edit hostname        - Edit the computers hostname and description." -Color "DarkGray"
    writeText -type "plain" -text "install updates      - Install Windows updates. All or just severe." -Color "DarkGray"
    writeText -type "plain" -text "schedule task        - Create a task in the task scheduler." -Color "DarkGray"
    writeText -type "plain" -text "toggle context menu  - Disable the Windows 11 context menu." -Color "DarkGray"
    writeText -type "plain" -text "NETWORK COMMANDS:" -lineBefore
    writeText -type "plain" -text "edit net adapter  - Edit network adapters." -Color "DarkGray"
    writeText -type "plain" -text "get wifi creds    - View WiFi credentials for the currently active WiFi adapter." -Color "DarkGray"
    writeText -type "plain" -text "FULL DOCUMENTATION:" -lineBefore
    writeText -type "plain" -text "https://guided.chaste.pro/dev/chaste-scripts" -Color "DarkGray"
}