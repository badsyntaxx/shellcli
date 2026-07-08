function plugins {
    readMenu
}
function readMenu {
    try {
        # Create a menu with options and descriptions using an ordered hashtable
        $choice = readOption -options $([ordered]@{
                "massgravel"   = "https://github.com/massgravel/Microsoft-Activation-Scripts"
                "reclaimw11"   = "Credit needed"
                "win11debloat" = "https://github.com/Raphire/Win11Debloat"
                "Cancel"       = "Select nothing and exit this menu."
            }) -prompt "Select a plugin:" -returnKey

        if ($choice -eq "Cancel") {
            readCommand
        }

        readCommand -command "plugins $choice"
    } catch {
        writeText -type "error" -text "readMenu-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function writeHelp {   
    writeText -type "plain" -text "GET STARTED:"
    writeText -type "plain" -text "commands                   - Display a full list of commands."
    writeText -type "plain" -text "plugins menu               - Display a menu with some available functions."
    writeText -type "plain" -text "plugins ? or plugins help  - Display this help text."
    writeText -type "plain" -text "FULL DOCUMENTATION:" -lineBefore
    writeText -type "plain" -text "https://wkey.pro/dev/shellcli"
}