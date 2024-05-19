function menu {
    try {
        clear-host
        write-welcome -Title "Chaste s Menu" -Description "Select an action to take." -Command "menu"

        $url = "https://raw.githubusercontent.com/badsyntaxx/chaste-scripts-intech/main"
        $subPath = "framework"

        write-text -Type "header" -Text "Selection" -LineAfter -LineBefore
        $choice = get-option -Options $([ordered]@{
                "Install TScan"     = "Install TScan software."
                "ISR Onboard"       = "Collection of functions to onboard and ISR computer."
                "ISR Install Apps"  = "Install all the apps an ISR needs to work."
                "ISR Install Ninja" = "Install Ninja for ISR computers."
                "ISR Add Bookmarks" = "Add ISR bookmarks to Chrome."
            }) -LineAfter

        if ($choice -eq 0) { $command = "install tscan" }
        if ($choice -eq 1) { $command = "isr onboard" }
        if ($choice -eq 2) { $command = "isr install apps" }
        if ($choice -eq 3) { $command = "isr install ninja" }
        if ($choice -eq 4) { $command = "isr add bookmarks" }

        get-cscommand -command $command
    } catch {
        exit-script -Type "error" -Text "Menu error: $($_.Exception.Message) $url/$subPath/$dependency.ps1" 
    }
}

