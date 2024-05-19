function isr-add-bookmarks {
    try {
        $user = select-user

        $profiles = [ordered]@{}
        $chromeUserDataPath = "C:\Users\$($user["Name"])\AppData\Local\Google\Chrome\User Data"
        $profileFolders = Get-ChildItem -Path $chromeUserDataPath -Directory
        if ($null -eq $profileFolders) { throw "Cannot find profiles for this Chrome installation." }
        foreach ($profileFolder in $profileFolders) {
            $preferencesFile = Join-Path -Path $profileFolder.FullName -ChildPath "Preferences"
            if (Test-Path -Path $preferencesFile) {
                $preferencesContent = Get-Content -Path $preferencesFile -Raw | ConvertFrom-Json
                $profileName = $preferencesContent.account_info.full_name
                $profiles["$profileName"] = $profileFolder.FullName
            }
        }

        $choice = get-option -Options $profiles -LineAfter -ReturnKey
        $account = $profiles["$choice"]
        $boomarksUrl = "https://drive.google.com/uc?export=download&id=1WmvSnxtDSLOt0rgys947sOWW-v9rzj9U"

        $download = get-download -Url $boomarksUrl -Target "$env:TEMP\Bookmarks"
        if (!$download) { throw "Unable to acquire bookmarks." }

        ROBOCOPY $env:TEMP $account "Bookmarks" /NFL /NDL /NC /NS /NP | Out-Null

        Remove-Item -Path "$env:TEMP\Bookmarks" -Force

        $preferencesFilePath = Join-Path -Path $profiles["$choice"] -ChildPath "Preferences"
        if (Test-Path -Path $preferencesFilePath) {
            $preferences = Get-Content -Path $preferencesFilePath -Raw | ConvertFrom-Json
            if (-not $preferences.PSObject.Properties.Match('bookmark_bar').Count) {
                $preferences | Add-Member -Type NoteProperty -Name 'bookmark_bar' -Value @{}
            }

            if (-not $preferences.bookmark_bar.PSObject.Properties.Match('show_on_all_tabs').Count) {
                $preferences.bookmark_bar | Add-Member -Type NoteProperty -Name 'show_on_all_tabs' -Value $true
            } else {
                $preferences.bookmark_bar.show_on_all_tabs = $true
            }

            $preferences | ConvertTo-Json -Depth 100 | Set-Content -Path $preferencesFilePath
        } else {
            throw "Preferences file not found."
        }

        if (Test-Path -Path $account) {
            Write-Host
            exit-script -Type "success" -Text "The bookmarks have been added." -LineAfter
        }
    } catch {
        # Display error message and end the script
        exit-script -Type "error" -Text "Add isr error: $($_.Exception.Message)"
        exit-script -Type "error" -Text "Error | Add-Bookmarks-$($_.InvocationInfo.ScriptLineNumber)"
    }
}

