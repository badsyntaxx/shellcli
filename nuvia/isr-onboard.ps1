function isr-onboard {
    try {
        # Display a welcome message with title, description, and command
        write-welcome -Title "ISR Onboard" -Description "Onboarding an ISR computer." -Command "isr onboard"

        write-text -Type "notice" -Text "Editing hostname" -LineBefore

        $currentHostname = $env:COMPUTERNAME
        $currentDescription = (Get-WmiObject -Class Win32_OperatingSystem).Description

        write-text -Type "header" -Text "Enter hostname" -LineBefore -LineAfter
        $hostname = get-input -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,15})$" -Value $currentHostname

        write-text -Type "header" -Text "Enter description" -LineBefore -LineAfter
        $description = get-input -Validate "^(\s*|[a-zA-Z0-9 |_\-]{1,64})$" -Value $currentDescription

        if ($hostname -eq "") { $hostname = $currentHostname } 
        if ($description -eq "") { $description = $currentDescription } 

        if ($hostname -ne "") {
            Remove-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "Hostname" 
            Remove-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "NV Hostname" 
            Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\Computername\Computername" -name "Computername" -value $hostname
            Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\Computername\ActiveComputername" -name "Computername" -value $hostname
            Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "Hostname" -value $hostname
            Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "NV Hostname" -value  $hostname
            Set-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -name "AltDefaultDomainName" -value $hostname
            Set-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -name "DefaultDomainName" -value $hostname
        } 

        if ($description -ne "") {
            Set-CimInstance -Query 'Select * From Win32_OperatingSystem' -Property @{Description = $description }
        } 

        write-text -Type "success" -Text "The PC name changes have been applied. No restart required!"
         
        # END EDIT HOSTNAME ----------------------------------------------------------------------------------------------------

        write-text -Type "header" -Text "Installing NinjaOne for Nuvia ISR Center" -LineBefore -LineAfter

        $url = "https://app.ninjarmm.com/agent/installer/0274c0c3-3ec8-44fc-93cb-79e96f191e07/nuviaisrcenteroremut-5.8.9154-windows-installer.msi"
        $service = Get-Service -Name "NinjaRMMAgent" -ErrorAction SilentlyContinue

        if ($null -ne $service -and $service.Status -eq "Running") {
            write-text -Type "done" -Text "NinjaRMMAgent is already installed and running."
        } else {
            $download = get-download -Url $Url -Target "$env:TEMP\NinjaOne.msi"
            if (!$download) { throw "Unable to acquire intaller." }
          
            Start-Process -FilePath "msiexec" -ArgumentList "/i `"$env:TEMP\NinjaOne.msi`" /qn" -Wait

            $service = Get-Service -Name "NinjaRMMAgent" -ErrorAction SilentlyContinue
            if ($null -eq $service -or $service.Status -ne "Running") { throw "NinjaOne did not successfully install." }

            Get-Item -ErrorAction SilentlyContinue "$env:TEMP\NinjaOne.msi" | Remove-Item -ErrorAction SilentlyContinue

            write-text -Type "success" -Text "NinjaOne successfully installed." -LineAfter
        }
        
        # END INSTALL NINJA ------------------------------------------------------------------------------------------------------
        
        $script:user = select-user -CustomHeader "Select user to install apps for"
        
        install-chrome
        install-cliq
        install-zoom
        install-ringcentral
        install-revouninstaller
        install-acrobatreader
        install-balto
        install-explorerpatcher 
        add-epregedits
        initialize-cleanup

        write-text -Type "success" -Text "The ISR app installs have completed."
        
        # END INSTALL APPS -----------------------------------------------------------------------------------------------------

        write-text -Type "header" -Text "Adding InTech Admin" -LineBefore -LineAfter

        $accountName = "InTechAdmin"
        $downloads = [ordered]@{
            "$env:TEMP\KEY.txt"    = "https://drive.google.com/uc?export=download&id=1EGASU9cvnl5E055krXXcXUcgbr4ED4ry"
            "$env:TEMP\PHRASE.txt" = "https://drive.google.com/uc?export=download&id=1jbppZfGusqAUM2aU7V4IeK0uHG2OYgoY"
        }

        foreach ($d in $downloads.Keys) { $download = get-download -Url $downloads[$d] -Target $d } 
        if (!$download) { throw "Unable to acquire credentials." }

        $password = Get-Content -Path "$env:TEMP\PHRASE.txt" | ConvertTo-SecureString -Key (Get-Content -Path "$env:TEMP\KEY.txt")

        write-text -Type "done" -Text "Credentials acquired."

        $account = Get-LocalUser -Name $accountName -ErrorAction SilentlyContinue

        if ($null -eq $account) {
            write-text -Type "header" -Text "Creating account" -LineBefore -LineAfter
            New-LocalUser -Name $accountName -Password $password -FullName "" -Description "InTech Administrator" -AccountNeverExpires -PasswordNeverExpires -ErrorAction stop | Out-Null
            write-text -Type "done" -Text "Account created."
            $finalMessage = "Success! The InTechAdmin account has been created."
        } else {
            write-text -Type "header" -Text "InTechAdmin account already exists!" -LineBefore -LineAfter
            write-text -Text "Updating password..."
            $account | Set-LocalUser -Password $password

            $finalMessage = "Success! The password was updated and the groups were applied."
        }

        write-text -Text "Updating group membership..."
        Add-LocalGroupMember -Group "Administrators" -Member $accountName -ErrorAction SilentlyContinue
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $accountName -ErrorAction SilentlyContinue
        Add-LocalGroupMember -Group "Users" -Member $accountName -ErrorAction SilentlyContinue

        Remove-Item -Path "$env:TEMP\PHRASE.txt"
        Remove-Item -Path "$env:TEMP\KEY.txt"

        write-text -Type "success" -Text $finalMessage        

        # END ADD INTECHADMIN --------------------------------------------------------------------------------------------------------

        write-text -Type "header" -Text "Install BgInfo for Nuvia" -LineBefore
        
        # Check if the current PowerShell session is running as the system account
        if ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -eq 'NT AUTHORITY\SYSTEM') {
            write-text -Type "notice" -Text "RUNNING AS SYSTEM: Changes wont apply until reboot. Run as logged user for instant results." -LineBefore
        }

        $choice = get-option -Options $([ordered]@{
                "Default" = "Generic install with no background and customizations by Chase."
                "Nuvia"   = "Customized BGInfo with Nuvia flavor profile."
            }) -LineBefore -LineAfter

        if ($choice -eq 0) { 
            $url = "https://drive.google.com/uc?export=download&id=1wBYV4MFbC68YhIUFcFeul8iuMsy1Qo_N" 
            $target = "Default" 
        }
        if ($choice -eq 1) { 
            $url = "https://drive.google.com/uc?export=download&id=18gFWHawWknKufHXjcmMUB0SwGoSlbBEk" 
            $target = "Nuvia" 
        }

        $download = get-download -Url $url -Target "$env:systemroot\Temp\$target`_BGInfo.zip"
        if (!$download) { throw "Couldn't download Bginfo." }

        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallPaper -Value ""
        Set-ItemProperty -Path "HKCU:Control Panel\Colors" -Name Background -Value "0 0 0"

        Expand-Archive -LiteralPath "$env:systemroot\Temp\$target`_BGInfo.zip" -DestinationPath "$env:systemroot\Temp\"

        Remove-Item -Path "$env:systemroot\Temp\$target`_BGInfo.zip" -Recurse

        ROBOCOPY "$env:systemroot\Temp\BGInfo" "C:\Program Files\BGInfo" /E /NFL /NDL /NJH /NJS /nc /ns | Out-Null
        ROBOCOPY "$env:systemroot\Temp\BGInfo" "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" "Start BGInfo.bat" /NFL /NDL /NJH /NJS /nc /ns | Out-Null

        Remove-Item -Path "$env:systemroot\Temp\BGInfo" -Recurse 

        Start-Process -FilePath "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\Start BGInfo.bat" -WindowStyle Hidden

        write-text -Type "success" -Text "BGInfo installed and applied." -LineBefore -LineAfter

        write-text -Type "notice" -Text "Disabling Windows 11 nonsense" -LineAfter
        
        $tweaks = @(    
            ### Privacy Settings ###
            "DisableTelemetry",
            "DisableWiFiSense",
            "DisableWebSearch",
            "DisableAppSuggestions",
            "DisableLockScreenSpotlight",
            "DisableMapUpdates",
            "DisableFeedback",
            "DisableAdvertisingID",
            "DisableCortana",      
            "EnableErrorReporting",
            "DisableAutoLogger",
            "DisableDiagTrack",
            "DisableWAPPush",
            
            ### Service Tweaks ###
            "SetUACLow",
            # "DisableAdminShares",         # "EnableAdminShares",
            "DisableSMB1",
            "SetCurrentNetworkPrivate",
            "DisableUpdateRestart",
            "DisableRemoteAssistance", # "EnableRemoteAssistance",
            "EnableRemoteDesktop", # "DisableRemoteDesktop",
            "DisableAutoplay",
            "DisableAutorun",
            "DisableHibernation",
            "DisableFastStartup",
            
            ### UI Tweaks ###
            "ShowShutdownOnLockScreen",
            "DisableStickyKeys",
            "ShowFileOperationsDetails",
            "HideTaskbarSearchBox",
            "HideTaskView",
            "HideTaskbarPeopleIcon",
            "ShowTrayIcons",                
            "SetExplorerThisPC",
            "ShowThisPCOnDesktop",          
            "ShowDesktopInThisPC",
            "ShowDesktopInExplorer",
            "ShowDocumentsInThisPC",
            "ShowDocumentsInExplorer",
            "ShowDownloadsInThisPC",
            "ShowDownloadsInExplorer",
            "ShowMusicInThisPC",
            "ShowMusicInExplorer",
            "ShowPicturesInThisPC",
            "ShowPicturesInExplorer",
            "ShowVideosInThisPC",
            "ShowVideosInExplorer",
            
            ### Application Tweaks ###
            # "DisableOneDrive",
            # "EnableOneDrive",
            # "UninstallOneDrive", 
            # "InstallOneDrive",
            "UninstallMsftBloat",
            "UninstallThirdPartyBloat",
            "DisableXboxFeatures",
            #"InstallLinuxSubsystem",      # "UninstallLinuxSubsystem",
            "SetPhotoViewerAssociation", # "UnsetPhotoViewerAssociation",
            "AddPhotoViewerOpenWith", # "RemovePhotoViewerOpenWith",
            "DisableSearchAppInStore" # "EnableSearchAppInStore",
            #"EnableF8BootMenu",             # "DisableF8BootMenu",
            
            ### Server Specific Tweaks ###
            # "HideServerManagerOnLogin",   # "ShowServerManagerOnLogin",
            # "DisableShutdownTracker",     # "EnableShutdownTracker",
            # "DisablePasswordPolicy",      # "EnablePasswordPolicy",
            # "DisableCtrlAltDelLogin",     # "EnableCtrlAltDelLogin",
        )
        
        $tweaks | ForEach-Object { Invoke-Expression $_ }

        write-text -Type "success" -Text "Windows 11 has been made semi-normal again."

        # END RECLAIM ----------------------------------------------------------------------------------------------------

        get-cscommand
    } catch {
        # Error handling: display an error message and prompt for a new command
        Write-Host "    Unknown command: $($_.Exception.Message)" -ForegroundColor Red
        get-cscommand
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

function install-explorerpatcher {
    $paths = @("C:\Program Files\ExplorerPatcher\ep_gui.dll")
    $url = "https://github.com/valinet/ExplorerPatcher/releases/download/22621.2861.62.2_9b68cc0/ep_setup.exe"
    $appName = "ExplorerPatcher"
    $installed = Find-ExistingInstall -Paths $paths -App $appName
    if (!$installed) { Install-Program $url $appName "exe" "/silent" }
}

function initialize-cleanup {
    Remove-Item "$env:TEMP\Revo Uninstaller.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\Users\Public\Desktop\Revo Uninstaller.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\Adobe Acrobat.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\Users\Public\Desktop\Adobe Acrobat.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\Microsoft Edge.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\Users\Public\Desktop\Microsoft Edge.lnk" -Force -ErrorAction SilentlyContinue
}

function add-epregedits {
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "ImportOK" -Value 1 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "OldTaskbar" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "Virtualized_{D17F1E1A-5919-4427-8F89-A1A8503CA3EB}_AutoHideTaskbar" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "SkinMenus" -Value 1 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "CenterMenus" -Value 1 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "FlyoutMenus" -Value 1 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\TabletTip\1.7" -Name "TipbandDesiredVisibility" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "HideControlCenterButton" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarSD" -Value 1 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "Virtualized_{D17F1E1A-5919-4427-8F89-A1A8503CA3EB}_RegisterAsShellExtension" -Value 1 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Name "(Default)" -Value "" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "LegacyFileTransferDialog" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "UseClassicDriveGrouping" -Value 1 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "Virtualized_{D17F1E1A-5919-4427-8F89-A1A8503CA3EB}_FileExplorerCommandUI" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "DisableImmersiveContextMenu" -Value 0 -ErrorAction SilentlyContinue
    # Remove registry key
    Remove-Item -Path "HKCU:\Software\Classes\CLSID\{056440FD-8568-48e7-A632-72157243B55B}\InprocServer32" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "Virtualized_{D17F1E1A-5919-4427-8F89-A1A8503CA3EB}_DisableModernSearchBar" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "ShrinkExplorerAddressBar" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "HideExplorerSearchBar" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "MicaEffectOnTitlebar" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_ShowClassicMode" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "Virtualized_{D17F1E1A-5919-4427-8F89-A1A8503CA3EB}_Start_MaximumFrequentApps" -Value 10 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartPage" -Name "MonitorOverride" -Value 1 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "Virtualized_{D17F1E1A-5919-4427-8F89-A1A8503CA3EB}_StartDocked_DisableRecommendedSection" -Value 1 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartPage" -Name "MakeAllAppsDefault" -Value 1 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "AltTabSettings" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "SpotlightDisableIcon" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "SpotlightDesktopMenuMask" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "SpotlightUpdateSchedule" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "LastSectionInProperties" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "ClockFlyoutOnWinC" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "ToolbarSeparators" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "PropertiesInWinX" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "NoMenuAccelerator" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "DisableOfficeHotkeys" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "DisableWinFHotkey" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "Virtualized_{D17F1E1A-5919-4427-8F89-A1A8503CA3EB}_DisableRoundedCorners" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "DisableAeroSnapQuadrants" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_PowerButtonAction" -Value 2 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "DoNotRedirectSystemToSettingsApp" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "DoNotRedirectProgramsAndFeaturesToSettingsApp" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "DoNotRedirectDateAndTimeToSettingsApp" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "DoNotRedirectNotificationIconsToSettingsApp" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "UpdatePolicy" -Value 1 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "UpdatePreferStaging" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "UpdateAllowDowngrades" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "UpdateURL" -Value "" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "UpdateURLStaging" -Value "" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "AllocConsole" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "Memcheck" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "TaskbarAutohideOnDoubleClick" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "PaintDesktopVersion" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "ClassicThemeMitigations" -Value 0 -ErrorAction SilentlyContinue
    # Remove registry key
    Remove-Item -Path "HKCU:\Software\Classes\CLSID\{1eeb5b5a-06fb-4732-96b3-975c0194eb39}\InprocServer32" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "NoPropertiesInContextMenu" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "EnableSymbolDownload" -Value 1 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "ExplorerReadyDelay" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ExplorerPatcher" -Name "XamlSounds" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\ExplorerPatcher" -Name "Language" -Value 0 -ErrorAction SilentlyContinue

    write-text "Explorer configured" -Type "done"
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
            
            write-text -Type "success" -Text "$AppName successfully installed." -LineAfter
        } else {
            write-text -Type "error" -Text "Download failed. Skipping." -LineAfter
        }
    } catch {
        write-text -Type "error" "Installation error: $($_.Exception.Message)"
        write-text "Skipping $AppName installation."
    }
}

# Disable Telemetry
function DisableTelemetry {
    write-text "Disabling Telemetry..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 0
    # Disable-ScheduledTask -TaskName "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" | Out-Null
    # Disable-ScheduledTask -TaskName "Microsoft\Windows\Application Experience\ProgramDataUpdater" | Out-Null
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Autochk\Proxy" | Out-Null
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Customer Experience Improvement Program\Consolidator" | Out-Null
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" | Out-Null
    Disable-ScheduledTask -TaskName "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" | Out-Null
}

# Disable Wi-Fi Sense
function DisableWiFiSense {
    write-text "Disabling Wi-Fi Sense..."
    if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting" -Name "Value" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots" -Name "Value" -Type DWord -Value 0
    if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" -Name "AutoConnectAllowedOEM" -Type Dword -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" -Name "WiFISenseAllowed" -Type Dword -Value 0
}

# Disable Web Search in Start Menu
function DisableWebSearch {
    write-text "Disabling Bing Search in Start Menu..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Type DWord -Value 0
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "DisableWebSearch" -Type DWord -Value 1
}

# Disable Application suggestions and automatic installation
function DisableAppSuggestions {
    write-text "Disabling Application suggestions..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "ContentDeliveryAllowed" -Type DWord -Value 0
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "OemPreInstalledAppsEnabled" -Type DWord -Value 0
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "PreInstalledAppsEnabled" -Type DWord -Value 0
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "PreInstalledAppsEverEnabled" -Type DWord -Value 0
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Type DWord -Value 0
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Type DWord -Value 0
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Type DWord -Value 0
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Type DWord -Value 0
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Type DWord -Value 1
}

# Disable Lock screen Spotlight - New backgrounds, tips, advertisements etc.
function DisableLockScreenSpotlight {
    write-text "Disabling Lock screen spotlight..."
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "RotatingLockScreenEnabled" -Type DWord -Value 0
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "RotatingLockScreenOverlayEnabled" -Type DWord -Value 0
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338387Enabled" -Type DWord -Value 0
}

# Disable automatic Maps updates
function DisableMapUpdates {
    write-text "Disabling automatic Maps updates..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\Maps" -Name "AutoUpdateEnabled" -Type DWord -Value 0
}

# Disable Feedback
function DisableFeedback {
    write-text "Disabling Feedback..."
    if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules")) {
        New-Item -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Type DWord -Value 0
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Feedback\Siuf\DmClient" -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload" -ErrorAction SilentlyContinue | Out-Null
}

# Disable Advertising ID
function DisableAdvertisingID {
    write-text "Disabling Advertising ID..."
    if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo")) {
        New-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Type DWord -Value 0
    if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy")) {
        New-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Type DWord -Value 0
}

# Disable Cortana
function DisableCortana {
    write-text "Disabling Cortana..."
    if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\Personalization\Settings")) {
        New-Item -Path "HKCU:\SOFTWARE\Microsoft\Personalization\Settings" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Personalization\Settings" -Name "AcceptedPrivacyPolicy" -Type DWord -Value 0
    if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization")) {
        New-Item -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictImplicitTextCollection" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictImplicitInkCollection" -Type DWord -Value 1
    if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore")) {
        New-Item -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" -Name "HarvestContacts" -Type DWord -Value 0
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Type DWord -Value 0
}

# Enable Error reporting
function EnableErrorReporting {
    write-text "Enabling Error reporting..."
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -ErrorAction SilentlyContinue
    Enable-ScheduledTask -TaskName "Microsoft\Windows\Windows Error Reporting\QueueReporting" | Out-Null
}

# Remove AutoLogger file and restrict directory
function DisableAutoLogger {
    write-text "Removing AutoLogger file and restricting directory..."
    $autoLoggerDir = "$env:PROGRAMDATA\Microsoft\Diagnosis\ETLLogs\AutoLogger"
    if (Test-Path "$autoLoggerDir\AutoLogger-Diagtrack-Listener.etl") {
        Remove-Item -Path "$autoLoggerDir\AutoLogger-Diagtrack-Listener.etl"
    }
    icacls $autoLoggerDir /deny SYSTEM:`(OI`)`(CI`)F | Out-Null
}

# Stop and disable Diagnostics Tracking Service
function DisableDiagTrack {
    write-text "Stopping and disabling Diagnostics Tracking Service..."
    Stop-Service "DiagTrack" -WarningAction SilentlyContinue
    Set-Service "DiagTrack" -StartupType Disabled
}

# Stop and disable WAP Push Service
function DisableWAPPush {
    write-text "Stopping and disabling WAP Push Service..."
    Stop-Service "dmwappushservice" -WarningAction SilentlyContinue
    Set-Service "dmwappushservice" -StartupType Disabled
}



##########
# Service Tweaks
##########

# Lower UAC level (disabling it completely would break apps)
function SetUACLow {
    write-text "Lowering UAC level..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "PromptOnSecureDesktop" -Type DWord -Value 0
}

# Disable implicit administrative shares
function DisableAdminShares {
    write-text "Disabling implicit administrative shares..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "AutoShareWks" -Type DWord -Value 0
}

# Enable implicit administrative shares
function EnableAdminShares {
    write-text "Enabling implicit administrative shares..."
    Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "AutoShareWks" -ErrorAction SilentlyContinue
}

# Disable obsolete SMB 1.0 protocol - Disabled by default since 1709
function DisableSMB1 {
    write-text "Disabling SMB 1.0 protocol..."
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
}

# Set current network profile to private (allow file sharing, device discovery, etc.)
function SetCurrentNetworkPrivate {
    write-text "Setting current network profile to private..."
    Set-NetConnectionProfile -NetworkCategory Private
}

# Disable Windows Update automatic restart
function DisableUpdateRestart {
    write-text "Disabling Windows Update automatic restart..."
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -Type DWord -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUPowerManagement" -Type DWord -Value 0
}

# Disable Remote Assistance - Not applicable to Server (unless Remote Assistance is explicitly installed)
function DisableRemoteAssistance {
    write-text "Disabling Remote Assistance..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Type DWord -Value 0
}

# Enable Remote Assistance - Not applicable to Server (unless Remote Assistance is explicitly installed)
function EnableRemoteAssistance {
    write-text "Enabling Remote Assistance..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Type DWord -Value 1
}

# Enable Remote Desktop w/o Network Level Authentication
function EnableRemoteDesktop {
    write-text "Enabling Remote Desktop w/o Network Level Authentication..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -Type DWord -Value 0
}

# Disable Remote Desktop
function DisableRemoteDesktop {
    write-text "Disabling Remote Desktop..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Type DWord -Value 1
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -Type DWord -Value 1
}

# Disable Autoplay
function DisableAutoplay {
    write-text "Disabling Autoplay..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" -Name "DisableAutoplay" -Type DWord -Value 1
}

# Disable Autorun for all drives
function DisableAutorun {
    write-text "Disabling Autorun for all drives..."
    if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -Type DWord -Value 255
}

# Disable Hibernation
function DisableHibernation {
    write-text "Disabling Hibernation..."
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Session Manager\Power" -Name "HibernteEnabled" -Type Dword -Value 0
    if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" -Name "ShowHibernateOption" -Type Dword -Value 0
}

# Disable Sleep start menu and keyboard button
function DisableSleepButton {
    write-text "Disabling Sleep start menu and keyboard button..."
    if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" -Name "ShowSleepOption" -Type Dword -Value 0
    powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_BUTTONS SBUTTONACTION 0
    powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_BUTTONS SBUTTONACTION 0
}

# Enable Sleep start menu and keyboard button
function EnableSleepButton {
    write-text "Enabling Sleep start menu and keyboard button..."
    if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" -Name "ShowSleepOption" -Type Dword -Value 1
    powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_BUTTONS SBUTTONACTION 1
    powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_BUTTONS SBUTTONACTION 1
}

# Disable display and sleep mode timeouts
function DisableSleepTimeout {
    write-text "Disabling display and sleep mode timeouts..."
    powercfg /X monitor-timeout-ac 0
    powercfg /X monitor-timeout-dc 0
    powercfg /X standby-timeout-ac 0
    powercfg /X standby-timeout-dc 0
}

# Enable display and sleep mode timeouts
function EnableSleepTimeout {
    write-text "Enabling display and sleep mode timeouts..."
    powercfg /X monitor-timeout-ac 10
    powercfg /X monitor-timeout-dc 5
    powercfg /X standby-timeout-ac 30
    powercfg /X standby-timeout-dc 15
}

# Disable Fast Startup
function DisableFastStartup {
    write-text "Disabling Fast Startup..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Type DWord -Value 0
}



##########
# UI Tweaks
##########

# Show shutdown options on lock screen
function ShowShutdownOnLockScreen {
    write-text "Showing shutdown options on Lock Screen..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ShutdownWithoutLogon" -Type DWord -Value 1
}

# Disable Sticky keys prompt
function DisableStickyKeys {
    write-text "Disabling Sticky keys prompt..."
    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Type String -Value "506"
}

# Show file operations details
function ShowFileOperationsDetails {
    write-text "Showing file operations details..."
    if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager")) {
        New-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager" | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager" -Name "EnthusiastMode" -Type DWord -Value 1
}

# Hide Taskbar Search button / box
function HideTaskbarSearchBox {
    write-text "Hiding Taskbar Search box / button..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Type DWord -Value 0
}

# Hide Task View button
function HideTaskView {
    write-text "Hiding Task View button..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Type DWord -Value 0
}

# Hide Taskbar People icon
function HideTaskbarPeopleIcon {
    write-text "Hiding People icon..."
    if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People")) {
        New-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" -Name "PeopleBand" -Type DWord -Value 0
}

# Show all tray icons
function ShowTrayIcons {
    write-text "Showing all tray icons..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -Type DWord -Value 0
}

# Hide tray icons as needed
function HideTrayIcons {
    write-text "Hiding tray icons..."
    Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -ErrorAction SilentlyContinue
}

# Change default Explorer view to This PC
function SetExplorerThisPC {
    write-text "Changing default Explorer view to This PC..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Type DWord -Value 1
}

# Show This PC shortcut on desktop
function ShowThisPCOnDesktop {
    write-text "Showing This PC shortcut on desktop..."
    if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu")) {
        New-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu" -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Type DWord -Value 0
    if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel")) {
        New-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Type DWord -Value 0
}

# Show Desktop icon in This PC
function ShowDesktopInThisPC {
    write-text "Showing Desktop icon in This PC..."
    if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}" | Out-Null
    }
}

# Show Desktop icon in Explorer namespace
function ShowDesktopInExplorer {
    write-text "Showing Desktop icon in Explorer namespace..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}\PropertyBag" -Name "ThisPCPolicy" -Type String -Value "Show"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}\PropertyBag" -Name "ThisPCPolicy" -Type String -Value "Show"
}

# Show Documents icon in This PC
function ShowDocumentsInThisPC {
    write-text "Showing Documents icon in This PC..."
    if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{d3162b92-9365-467a-956b-92703aca08af}")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{d3162b92-9365-467a-956b-92703aca08af}" | Out-Null
    }
    if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}" | Out-Null
    }
}

# Show Documents icon in Explorer namespace
function ShowDocumentsInExplorer {
    write-text "Showing Documents icon in Explorer namespace..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{f42ee2d3-909f-4907-8871-4c22fc0bf756}\PropertyBag" -Name "ThisPCPolicy" -Type String -Value "Show"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{f42ee2d3-909f-4907-8871-4c22fc0bf756}\PropertyBag" -Name "ThisPCPolicy" -Type String -Value "Show"
}

# Show Downloads icon in This PC
function ShowDownloadsInThisPC {
    write-text "Showing Downloads icon in This PC..."
    if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{088e3905-0323-4b02-9826-5d99428e115f}")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{088e3905-0323-4b02-9826-5d99428e115f}" | Out-Null
    }
    if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{374DE290-123F-4565-9164-39C4925E467B}")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{374DE290-123F-4565-9164-39C4925E467B}" | Out-Null
    }
}

# Show Downloads icon in Explorer namespace
function ShowDownloadsInExplorer {
    write-text "Showing Downloads icon in Explorer namespace..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{7d83ee9b-2244-4e70-b1f5-5393042af1e4}\PropertyBag" -Name "ThisPCPolicy" -Type String -Value "Show"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{7d83ee9b-2244-4e70-b1f5-5393042af1e4}\PropertyBag" -Name "ThisPCPolicy" -Type String -Value "Show"
}

# Show Music icon in This PC
function ShowMusicInThisPC {
    write-text "Showing Music icon in This PC..."
    if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}" | Out-Null
    }
    if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{1CF1260C-4DD0-4ebb-811F-33C572699FDE}")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{1CF1260C-4DD0-4ebb-811F-33C572699FDE}" | Out-Null
    }
}

# Show Music icon in Explorer namespace
function ShowMusicInExplorer {
    write-text "Showing Music icon in Explorer namespace..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{a0c69a99-21c8-4671-8703-7934162fcf1d}\PropertyBag" -Name "ThisPCPolicy" -Type String -Value "Show"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{a0c69a99-21c8-4671-8703-7934162fcf1d}\PropertyBag" -Name "ThisPCPolicy" -Type String -Value "Show"
}

# Show Pictures icon in This PC
function ShowPicturesInThisPC {
    write-text "Showing Pictures icon in This PC..."
    if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}" | Out-Null
    }
    if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}" | Out-Null
    }
}

# Show Pictures icon in Explorer namespace
function ShowPicturesInExplorer {
    write-text "Showing Pictures icon in Explorer namespace..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{0ddd015d-b06c-45d5-8c4c-f59713854639}\PropertyBag" -Name "ThisPCPolicy" -Type String -Value "Show"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{0ddd015d-b06c-45d5-8c4c-f59713854639}\PropertyBag" -Name "ThisPCPolicy" -Type String -Value "Show"
}

# Show Videos icon in This PC
function ShowVideosInThisPC {
    write-text "Showing Videos icon in This PC..."
    if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}" | Out-Null
    }
    if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A0953C92-50DC-43bf-BE83-3742FED03C9C}")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A0953C92-50DC-43bf-BE83-3742FED03C9C}" | Out-Null
    }
}

# Show Videos icon in Explorer namespace
function ShowVideosInExplorer {
    write-text "Showing Videos icon in Explorer namespace..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{35286a68-3c57-41a1-bbb1-0eae73d76c95}\PropertyBag" -Name "ThisPCPolicy" -Type String -Value "Show"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{35286a68-3c57-41a1-bbb1-0eae73d76c95}\PropertyBag" -Name "ThisPCPolicy" -Type String -Value "Show"
}

# Set Control Panel view to icons (Classic) - Note: May trigger antimalware
function SetControlPanelViewIcons {
    write-text "Setting Control Panel view to icons..."
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "ForceClassicControlPanel" -Type DWord -Value 1
}

# Set Control Panel view to categories
function SetControlPanelViewCategories {
    write-text "Setting Control Panel view to categories..."
    Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "ForceClassicControlPanel" -ErrorAction SilentlyContinue
}

# Disable OneDrive
function DisableOneDrive {
    write-text "Disabling OneDrive..."
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -Type DWord -Value 1
}

# Enable OneDrive
Function EnableOneDrive {
    write-text "Enabling OneDrive..."
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -ErrorAction SilentlyContinue
}

# Uninstall OneDrive - Not applicable to Server
function UninstallOneDrive {
    write-text "Uninstalling OneDrive..."
    Stop-Process -Name OneDrive -ErrorAction SilentlyContinue
    Start-Sleep -s 3
    $onedrive = "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe"
    if (!(Test-Path $onedrive)) {
        $onedrive = "$env:SYSTEMROOT\System32\OneDriveSetup.exe"
    }
    Start-Process $onedrive "/uninstall" -NoNewWindow -Wait
    Start-Sleep -s 3
    Stop-Process -Name explorer -ErrorAction SilentlyContinue
    Start-Sleep -s 3
    Remove-Item -Path "$env:USERPROFILE\OneDrive" -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\OneDrive" -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:PROGRAMDATA\Microsoft OneDrive" -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:SYSTEMDRIVE\OneDriveTemp" -Force -Recurse -ErrorAction SilentlyContinue
    if (!(Test-Path "HKCR:")) {
        New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
    }
    Remove-Item -Path "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Recurse -ErrorAction SilentlyContinue
}

# Install OneDrive - Not applicable to Server
Function InstallOneDrive {
    write-text "Installing OneDrive..."
    $onedrive = "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe"
    If (!(Test-Path $onedrive)) {
        $onedrive = "$env:SYSTEMROOT\System32\OneDriveSetup.exe"
    }
    Start-Process $onedrive -NoNewWindow
}

# Uninstall default Microsoft applications
function UninstallMsftBloat {
    write-text "Uninstalling default Microsoft applications..."
    Get-AppxPackage "Microsoft.3DBuilder" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.BingFinance" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.BingNews" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.BingSports" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.BingWeather" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.Getstarted" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.MicrosoftOfficeHub" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.MicrosoftSolitaireCollection" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.Office.OneNote" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.People" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.SkypeApp" | Remove-AppxPackage
    #	Get-AppxPackage "Microsoft.Windows.Photos" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.WindowsAlarms" | Remove-AppxPackage
    #	Get-AppxPackage "Microsoft.WindowsCamera" | Remove-AppxPackage
    #Get-AppxPackage "microsoft.windowscommunicationsapps" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.WindowsMaps" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.WindowsPhone" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.WindowsSoundRecorder" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.ZuneMusic" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.ZuneVideo" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.AppConnector" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.ConnectivityStore" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.Office.Sway" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.Messaging" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.CommsPhone" | Remove-AppxPackage
    # Get-AppxPackage "Microsoft.MicrosoftStickyNotes" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.OneConnect" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.WindowsFeedbackHub" | Remove-AppxPackage
    #Get-AppxPackage "Microsoft.MinecraftUWP" | Remove-AppxPackage
    #	Get-AppxPackage "Microsoft.MicrosoftPowerBIForWindows" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.NetworkSpeedTest" | Remove-AppxPackage
    #	Get-AppxPackage "Microsoft.MSPaint" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.Microsoft3DViewer" | Remove-AppxPackage
    #	Get-AppxPackage "Microsoft.RemoteDesktop" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.Print3D" | Remove-AppxPackage
    Get-AppxPackage -name "Microsoft.Music.Preview" | Remove-AppxPackage	
    Get-AppxPackage -name "Microsoft.BingTravel" | Remove-AppxPackage
    Get-AppxPackage -name "Microsoft.BingHealthAndFitness" | Remove-AppxPackage
    Get-AppxPackage -name "Microsoft.BingFoodAndDrink" | Remove-AppxPackage

}

# Uninstall default third party applications
function UninstallThirdPartyBloat {
    write-text "Uninstalling default third party applications..."
    Get-AppxPackage "9E2F88E3.Twitter" | Remove-AppxPackage
    Get-AppxPackage "king.com.CandyCrushSodaSaga" | Remove-AppxPackage
    Get-AppxPackage "4DF9E0F8.Netflix" | Remove-AppxPackage
    Get-AppxPackage "Drawboard.DrawboardPDF" | Remove-AppxPackage
    Get-AppxPackage "D52A8D61.FarmVille2CountryEscape" | Remove-AppxPackage
    Get-AppxPackage "GAMELOFTSA.Asphalt8Airborne" | Remove-AppxPackage
    Get-AppxPackage "flaregamesGmbH.RoyalRevolt2" | Remove-AppxPackage
    Get-AppxPackage "AdobeSystemsIncorporated.AdobePhotoshopExpress" | Remove-AppxPackage
    Get-AppxPackage "ActiproSoftwareLLC.562882FEEB491" | Remove-AppxPackage
    Get-AppxPackage "D5EA27B7.Duolingo-LearnLanguagesforFree" | Remove-AppxPackage
    Get-AppxPackage "Facebook.Facebook" | Remove-AppxPackage
    Get-AppxPackage "46928bounde.EclipseManager" | Remove-AppxPackage
    Get-AppxPackage "A278AB0D.MarchofEmpires" | Remove-AppxPackage
    Get-AppxPackage "KeeperSecurityInc.Keeper" | Remove-AppxPackage
    Get-AppxPackage "king.com.BubbleWitch3Saga" | Remove-AppxPackage
    Get-AppxPackage "89006A2E.AutodeskSketchBook" | Remove-AppxPackage
    Get-AppxPackage "CAF9E577.Plex" | Remove-AppxPackage
    Get-AppxPackage "A278AB0D.DisneyMagicKingdoms" | Remove-AppxPackage
    Get-AppxPackage "828B5831.HiddenCityMysteryofShadows" | Remove-AppxPackage
    Get-AppxPackage "WinZipComputing.WinZipUniversal" | Remove-AppxPackage
    Get-AppxPackage "SpotifyAB.SpotifyMusic" | Remove-AppxPackage
    Get-AppxPackage "PandoraMediaInc.29680B314EFC2" | Remove-AppxPackage
    Get-AppxPackage "2414FC7A.Viber" | Remove-AppxPackage
    Get-AppxPackage "64885BlueEdge.OneCalendar" | Remove-AppxPackage
    Get-AppxPackage "41038Axilesoft.ACGMediaPlayer" | Remove-AppxPackage
}

# Disable Xbox features
function DisableXboxFeatures {
    write-text "Disabling Xbox features..."
    Get-AppxPackage "Microsoft.XboxApp" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.XboxIdentityProvider" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.XboxSpeechToTextOverlay" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.XboxGameOverlay" | Remove-AppxPackage
    Get-AppxPackage "Microsoft.Xbox.TCUI" | Remove-AppxPackage
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Type DWord -Value 0
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Type DWord -Value 0
}


# Install Linux Subsystem - Applicable to 1607 or newer, not applicable to Server yet
function InstallLinuxSubsystem {
    write-text "Installing Linux Subsystem..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -Type DWord -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowAllTrustedApps" -Type DWord -Value 1
    Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -NoRestart -WarningAction SilentlyContinue | Out-Null
}

# Uninstall Linux Subsystem - Applicable to 1607 or newer, not applicable to Server yet
function UninstallLinuxSubsystem {
    write-text "Uninstalling Linux Subsystem..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowAllTrustedApps" -Type DWord -Value 0
    Disable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -NoRestart -WarningAction SilentlyContinue | Out-Null
}

# Set Photo Viewer association for bmp, gif, jpg, png and tif
function SetPhotoViewerAssociation {
    write-text "Setting Photo Viewer association for bmp, gif, jpg, png and tif..."
    if (!(Test-Path "HKCR:")) {
        New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
    }
    ForEach ($type in @("Paint.Picture", "giffile", "jpegfile", "pngfile")) {
        New-Item -Path $("HKCR:\$type\shell\open") -Force | Out-Null
        New-Item -Path $("HKCR:\$type\shell\open\command") | Out-Null
        Set-ItemProperty -Path $("HKCR:\$type\shell\open") -Name "MuiVerb" -Type ExpandString -Value "@%ProgramFiles%\Windows Photo Viewer\photoviewer.dll,-3043"
        Set-ItemProperty -Path $("HKCR:\$type\shell\open\command") -Name "(Default)" -Type ExpandString -Value "%SystemRoot%\System32\rundll32.exe `"%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll`", ImageView_Fullscreen %1"
    }
}

# Unset Photo Viewer association for bmp, gif, jpg, png and tif
function UnsetPhotoViewerAssociation {
    write-text "Unsetting Photo Viewer association for bmp, gif, jpg, png and tif..."
    if (!(Test-Path "HKCR:")) {
        New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
    }
    Remove-Item -Path "HKCR:\Paint.Picture\shell\open" -Recurse -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKCR:\giffile\shell\open" -Name "MuiVerb" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCR:\giffile\shell\open" -Name "CommandId" -Type String -Value "IE.File"
    Set-ItemProperty -Path "HKCR:\giffile\shell\open\command" -Name "(Default)" -Type String -Value "`"$env:SystemDrive\Program Files\Internet Explorer\iexplore.exe`" %1"
    Set-ItemProperty -Path "HKCR:\giffile\shell\open\command" -Name "DelegateExecute" -Type String -Value "{17FE9752-0B5A-4665-84CD-569794602F5C}"
    Remove-Item -Path "HKCR:\jpegfile\shell\open" -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path "HKCR:\pngfile\shell\open" -Recurse -ErrorAction SilentlyContinue
}

# Add Photo Viewer to "Open with..."
function AddPhotoViewerOpenWith {
    write-text "Adding Photo Viewer to `"Open with...`""
    if (!(Test-Path "HKCR:")) {
        New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
    }
    New-Item -Path "HKCR:\Applications\photoviewer.dll\shell\open\command" -Force | Out-Null
    New-Item -Path "HKCR:\Applications\photoviewer.dll\shell\open\DropTarget" -Force | Out-Null
    Set-ItemProperty -Path "HKCR:\Applications\photoviewer.dll\shell\open" -Name "MuiVerb" -Type String -Value "@photoviewer.dll,-3043"
    Set-ItemProperty -Path "HKCR:\Applications\photoviewer.dll\shell\open\command" -Name "(Default)" -Type ExpandString -Value "%SystemRoot%\System32\rundll32.exe `"%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll`", ImageView_Fullscreen %1"
    Set-ItemProperty -Path "HKCR:\Applications\photoviewer.dll\shell\open\DropTarget" -Name "Clsid" -Type String -Value "{FFE2A43C-56B9-4bf5-9A79-CC6D4285608A}"
}

# Remove Photo Viewer from "Open with..."
function RemovePhotoViewerOpenWith {
    write-text "Removing Photo Viewer from `"Open with...`""
    if (!(Test-Path "HKCR:")) {
        New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
    }
    Remove-Item -Path "HKCR:\Applications\photoviewer.dll\shell\open" -Recurse -ErrorAction SilentlyContinue
}

# Disable search for app in store for unknown extensions
function DisableSearchAppInStore {
    write-text "Disabling search for app in store for unknown extensions..."
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "NoUseStoreOpenWith" -Type DWord -Value 1
}

# Enable search for app in store for unknown extensions
function EnableSearchAppInStore {
    write-text "Enabling search for app in store for unknown extensions..."
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "NoUseStoreOpenWith" -ErrorAction SilentlyContinue
}

# Enable F8 boot menu options
function EnableF8BootMenu {
    write-text "Enabling F8 boot menu options..."
    bcdedit /set `{current`} bootmenupolicy Legacy | Out-Null
}

# Disable F8 boot menu options
function DisableF8BootMenu {
    write-text "Disabling F8 boot menu options..."
    bcdedit /set `{current`} bootmenupolicy Standard | Out-Null
}

# Set Data Execution Prevention (DEP) policy to OptOut
function SetDEPOptOut {
    write-text "Setting Data Execution Prevention (DEP) policy to OptOut..."
    bcdedit /set `{current`} nx OptOut | Out-Null
}

# Set Data Execution Prevention (DEP) policy to OptIn
function SetDEPOptIn {
    write-text "Setting Data Execution Prevention (DEP) policy to OptIn..."
    bcdedit /set `{current`} nx OptIn | Out-Null
}


##########
# Server specific Tweaks
##########

# Hide Server Manager after login
function HideServerManagerOnLogin {
    write-text "Hiding Server Manager after login..."
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Server\ServerManager")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Server\ServerManager" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Server\ServerManager" -Name "DoNotOpenAtLogon" -Type DWord -Value 1
}

# Hide Server Manager after login
function ShowServerManagerOnLogin {
    write-text "Showing Server Manager after login..."
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Server\ServerManager" -Name "DoNotOpenAtLogon" -ErrorAction SilentlyContinue
}

# Disable Shutdown Event Tracker
function DisableShutdownTracker {
    write-text "Disabling Shutdown Event Tracker..."
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Reliability")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Reliability" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Reliability" -Name "ShutdownReasonOn" -Type DWord -Value 0
}

# Enable Shutdown Event Tracker
function EnableShutdownTracker {
    write-text "Enabling Shutdown Event Tracker..."
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Reliability" -Name "ShutdownReasonOn" -ErrorAction SilentlyContinue
}

# Disable password complexity and maximum age requirements
function DisablePasswordPolicy {
    write-text "Disabling password complexity and maximum age requirements..."
    $tmpfile = New-TemporaryFile
    secedit /export /cfg $tmpfile /quiet
    (Get-Content $tmpfile).Replace("PasswordComplexity = 1", "PasswordComplexity = 0").Replace("MaximumPasswordAge = 42", "MaximumPasswordAge = -1") | Out-File $tmpfile
    secedit /configure /db "$env:SYSTEMROOT\security\database\local.sdb" /cfg $tmpfile /areas SECURITYPOLICY | Out-Null
    Remove-Item -Path $tmpfile
}

# Enable password complexity and maximum age requirements
function EnablePasswordPolicy {
    write-text "Enabling password complexity and maximum age requirements..."
    $tmpfile = New-TemporaryFile
    secedit /export /cfg $tmpfile /quiet
    (Get-Content $tmpfile).Replace("PasswordComplexity = 0", "PasswordComplexity = 1").Replace("MaximumPasswordAge = -1", "MaximumPasswordAge = 42") | Out-File $tmpfile
    secedit /configure /db "$env:SYSTEMROOT\security\database\local.sdb" /cfg $tmpfile /areas SECURITYPOLICY | Out-Null
    Remove-Item -Path $tmpfile
}

# Disable Ctrl+Alt+Del requirement before login
function DisableCtrlAltDelLogin {
    write-text "Disabling Ctrl+Alt+Del requirement before login..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableCAD" -Type DWord -Value 1
}

# Enable Ctrl+Alt+Del requirement before login
function EnableCtrlAltDelLogin {
    write-text "Enabling Ctrl+Alt+Del requirement before login..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableCAD" -Type DWord -Value 0
}  
