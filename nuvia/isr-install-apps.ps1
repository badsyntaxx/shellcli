function isr-install-apps {
    try {
        write-welcome -Title "Install ISR Applications" -Description "Install ISR apps and add bookmarks to Chrome." -Command "isr install apps"

        write-text -Type "header" -Text "Select app to install." -LineBefore -LineAfter

        $installChoice = get-option -Options $([ordered]@{
                "All"              = "Install all the apps that an ISR will need."
                "Chrome"           = "Install Google Chrome."
                "Cliq"             = "Install Zoho Cliq."
                "Zoom"             = "Install Microsoft Zoom."
                "RingCentral"      = "Install RingCentral."
                "Revo Uninstaller" = "Install RevoUninstaller."
                "Acrobat"          = "Install Adobe Acrobat reader."
                "Balto"            = "Install Balto AI"
                "HWInfo"           = "Install HWInfo"
            })

        $script:user = select-user -CustomHeader "Select user to install apps for"

        if ($installChoice -eq 1 -or $installChoice -eq 0) { install-chrome }
        if ($installChoice -eq 2 -or $installChoice -eq 0) { install-cliq }
        if ($installChoice -eq 3 -or $installChoice -eq 0) { install-zoom }
        if ($installChoice -eq 4 -or $installChoice -eq 0) { install-ringcentral }
        if ($installChoice -eq 5 -or $installChoice -eq 0) { install-revouninstaller }
        if ($installChoice -eq 6 -or $installChoice -eq 0) { install-acrobatreader }
        if ($installChoice -eq 7 -or $installChoice -eq 0) { install-balto }
        if ($installChoice -eq 8 -or $installChoice -eq 0) { install-hwinfo }

        Initialize-Cleanup
        exit-script
    } catch {
        # Display error message and end the script
        exit-script -Type "error" -Text "Error | install-apps-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}

function install-chrome {
    $paths = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles (x86)\Google\Chrome\Application\chrome.exe",
        "C:\Users\$($user["Name"])\AppData\Google\Chrome\Application\chrome.exe"
    )

    $url = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"
    $appName = "Google Chrome"
    $installed = Find-ExistingInstall -Paths $paths -App $appName
    if (!$installed) { Install-Program $url $appName "msi" "/qn" }
}

function Add-ChromeBookmarks {
    write-text -Type "header" -Text "Which profile "
    $profiles = [ordered]@{}
    $chromeUserDataPath = "C:\Users\$($user["name"])\AppData\Local\Google\Chrome\User Data"
    $profileFolders = Get-ChildItem -Path $chromeUserDataPath -Directory -ErrorAction SilentlyContinue
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
        exit-script -Type "success" -Text "The bookmarks have been added." -LineBefore
    }
}

function Install-Slack {
    $paths = @(
        "C:\Program Files\Slack\slack.exe",
        "C:\Users\$($user["Name"])\AppData\slack\slack.exe"
    )
    $url = "https://downloads.slack-edge.com/releases/windows/4.36.138/prod/x64/slack-standalone-4.36.138.0.msi"
    $appName = "Slack"
    $installed = Find-ExistingInstall -Paths $paths -App $appName
    if (!$installed) { Install-Program $url $appName "msi" "/qn" }
}

function install-cliq {
    $paths = @("C:\Users\$($user["Name"])\AppData\Local\cliq\app-1.7.1")
    $url = "https://downloads.zohocdn.com/chat-desktop/windows/Cliq_1.7.1_x64.exe"
    $appName = "Cliq"
    $installed = Find-ExistingInstall -Paths $paths -App $appName
    if (!$installed) { Install-Program $url $appName "exe" "/silent" }
}

function install-zoom {
    $paths = @(
        "C:\Program Files\Zoom\Zoom.exe",
        "C:\Program Files\Zoom\bin\Zoom.exe",
        "C:\Users\$($user["Name"])\AppData\Zoom\Zoom.exe"
    )
    $url = "https://zoom.us/client/latest/ZoomInstallerFull.msi?archType=x64"
    $appName = "Zoom"
    $installed = Find-ExistingInstall -Paths $paths -App $appName
    if (!$installed) { Install-Program $url $appName "msi" "/qn" }
}

function install-ringcentral {
    $paths = @(
        "C:\Program Files\RingCentral\RingCentral.exe",
        "C:\Users\$env:username\AppData\Local\Programs\RingCentral"
    )
    $url = "https://app.ringcentral.com/download/RingCentral-x64.msi"
    $appName = "Ring Central"
    $installed = Find-ExistingInstall -Paths $paths -App $appName
    if (!$installed) { Install-Program $url $appName "msi" "/qn" }
}

function install-revouninstaller {
    $paths = @("C:\Program Files\VS Revo Group\Revo Uninstaller\RevoUnin.exe")
    $url = "https://download.revouninstaller.com/download/revosetup.exe"
    $appName = "Revo Uninstaller"
    $installed = Find-ExistingInstall -Paths $paths -App $appName
    if (!$installed) { Install-Program $url $appName "exe" "/verysilent" }
}

function install-acrobatreader {
    $paths = @(
        "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
        "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
    )
    $url = "https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/2300820555/AcroRdrDC2300820555_en_US.exe"
    $appName = "Adobe Acrobat Reader"
    $installed = Find-ExistingInstall -Paths $paths -App $appName
    if (!$installed) { Install-Program $url $appName "exe" "/sAll /rs /msi EULA_ACCEPT=YES" }
}

function install-balto {
    $paths = @("C:\Users\$($user["Name"])\AppData\Local\Programs\Balto\Balto.exe")
    $url = "https://download.baltocloud.com/Balto+Setup+6.1.1.exe"
    $appName = "Balto"
    $installed = Find-ExistingInstall -Paths $paths -App $appName
    if (!$installed) { Install-Program $url $appName "exe" "/silent" }
}

function install-hwinfo {
    # $paths = @("C:\Users\$($user["Name"])\AppData\Local\Programs\Balto\Balto.exe")
    $url = "https://downloads.sourceforge.net/project/hwinfo/Windows_Installer/hwi64_802.exe?ts=gAAAAABmR85Z5GCzlgHfKsClnbCZQHdJ5v9kwy9AZ9--D0SM16SGVlguNTOzHXDAr2t8QQvM8pW7vswscBT7ModKXdXvDGtO0w%3D%3D&r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fhwinfo%2Ffiles%2FWindows_Installer%2Fhwi64_802.exe%2Fdownload"
    $appName = "HWInfo"
    $installed = Find-ExistingInstall -Paths $paths -App $appName
    if (!$installed) { Install-Program $url $appName "exe" "/silent" }
}

function Initialize-Cleanup {
    Remove-Item "$env:TEMP\Revo Uninstaller.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\Users\Public\Desktop\Revo Uninstaller.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\Adobe Acrobat.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\Users\Public\Desktop\Adobe Acrobat.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\Microsoft Edge.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\Users\Public\Desktop\Microsoft Edge.lnk" -Force -ErrorAction SilentlyContinue
}

function Find-ExistingInstall {
    param (
        [parameter(Mandatory = $true)]
        [array]$Paths,
        [parameter(Mandatory = $true)]
        [string]$App
    )

    write-text -Type "header" -Text "Installing $App" -LineAfter

    $installationFound = $false

    foreach ($path in $paths) {
        if (Test-Path $path) {
            $installationFound = $true
            break
        }
    }

    if ($installationFound) { write-text -Type "success" -Text "$App already installed." -LineAfter }

    return $installationFound
}

function Install-Program {
    param (
        [parameter(Mandatory = $true)]
        [string]$Url,
        [parameter(Mandatory = $true)]
        [string]$AppName,
        [parameter(Mandatory = $true)]
        [string]$Extenstion,
        [parameter(Mandatory = $true)]
        [string]$Args
    )

    try {
        if ($Extenstion -eq "msi") { $output = "$AppName.msi" } else { $output = "$AppName.exe" }
        
        $download = get-download -Url $Url -Target "$env:TEMP\$output"

        if ($download) {
            if ($Extenstion -eq "msi") {
                $process = Start-Process -FilePath "msiexec" -ArgumentList "/i `"$env:TEMP\$output`" $Args" -PassThru
            } else {
                $process = Start-Process -FilePath "$env:TEMP\$output" -ArgumentList "$Args" -PassThru
            }

            $dots = ""
            $counter = 0
            while (!$process.HasExited) {
                $dots += "."
                Write-Host -NoNewLine "`r    Installing$dots    "
                Start-Sleep -Milliseconds 500
                $counter++
                if ($counter -eq 5) { 
                    $dots = "" 
                    $counter = 0
                }
            }

            Get-Item -ErrorAction SilentlyContinue "$env:TEMP\$output" | Remove-Item -ErrorAction SilentlyContinue
            
            write-text -Type "success" -Text "$AppName successfully installed." -LineBefore -LineAfter
        } else {
            write-text -Type "error" -Text "Download failed. Skipping." -LineAfter
        }
    } catch {
        write-text -Type "error" -Text "Installation error: $($_.Exception.Message)"
        write-text "Skipping $AppName installation."
    }
}

