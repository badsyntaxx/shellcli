function updateWindows {
    try { 
        writeText -type "plain" -text "Loading update module..."

        Import-Module PowerShellGet
        Install-Module -Name PSWindowsUpdate -Force
        Import-Module PSWindowsUpdate -Force

        writeText -type "plain" -text "Getting updates..."

        $updates = Get-WindowsUpdate

        # Create an empty ordered dictionary
        $orderedUpdateData = [ordered]@{}

        # Loop through each update and add its properties to the dictionary
        for ($i = 0; $i -lt $updates.Count; $i++) {
            $update = $updates[$i]
            # Key: "KB1234567" or "Update #1" - Value: "Title of the update"
            $orderedUpdateData["KB$($update.KB)"] = "$($update.Title) ($([math]::Round($update.Size/1MB, 2)) MB)"
        }

        writeText -type "table" -Table $orderedUpdateData

        $orderedUpdateData += [ordered]@{
            "All"       = "Install all updates."
            "Important" = "Install only important updates."
            "Cancel"    = "Do nothing and exit this function."
        }

        $choice = readOption -options $orderedUpdateData -prompt "Select which updates to install:" -lineBefore -returnKey

        if ($choice -eq 'All') {
            Get-WindowsUpdate -Install -AcceptAll | Out-Null
        }
        if ($choice -eq 'Important') {
            Get-WindowsUpdate -Severity "Important" -Install | Out-Null
        }
        if ($choice -eq 'Cancel') {
            readCommand
        }
        if ($choice -ne 'All' -and $choice -ne 'Important' -and $choice -ne 'Cancel') {
            Get-WindowsUpdate -KBArticleID $choice -Install | Out-Null
        }

        writeText -type "success" -text "Updates complete."
    } catch {
        writeText -type "error" -text "updateWindows-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
