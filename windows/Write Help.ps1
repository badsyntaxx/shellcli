function writeHelp {
    writeText -type "plain" -text "COMMAND STRUCTURE:" -lineBefore
    writeText -type "plain" -text "add [local,ad] user              - Add a local or domain user to the system." -Color "DarkGray"
    writeText -type "plain" -text "edit user [name,password,group]  - Edit user account settings." -Color "DarkGray"
    writeText -type "plain" -text "edit net adapter                 - Edit network adapter settings like IP and DNS." -Color "DarkGray"
    writeText -type "plain" -text "FULL DOCUMENTATION:"
    writeText -type "plain" -text "https://guided.chaste.pro/dev/chaste-scripts" -Color "DarkGray"
}