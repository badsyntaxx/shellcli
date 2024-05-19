function menu {
    try {
        clear-host
        write-welcome -Title "Chaste s Menu" -Description "Select an action to take." -Command "menu"

        $url = "https://raw.githubusercontent.com/badsyntaxx/chaste-scripts-intech/main"
        $subPath = "framework"

        write-text -Type "header" -Text "Select a sub menu" -LineAfter -LineBefore
        $choice = get-option -Options $([ordered]@{
                "Windows" = "General Windows functions."
                "Nuvia"   = "Nuvia specific functions."
            }) -LineAfter

        if ($choice -eq 0) { $command = "windows menu" }
        if ($choice -eq 1) { $command = "nuvia menu" }

        get-cscommand -command $command
    } catch {
        exit-script -Type "error" -Text "Menu error: $($_.Exception.Message) $url/$subPath/$dependency.ps1" 
    }
}

