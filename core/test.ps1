function writeHelp {
    writeText -type "plain" -text "COMMANDS:"
    writeText -type "plain" -text "toggle admin                     - Toggle the Windows built-in administrator account." -Color "DarkGray"
    writeText -type "plain" -text "add [local,domain] user          - Add a local or domain user to the system." -Color "DarkGray"
    writeText -type "plain" -text "edit user [name,password,group]  - Edit user account settings." -Color "DarkGray"
    writeText -type "plain" -text "edit net adapter                 - Edit network adapter settings like IP and DNS." -Color "DarkGray"
    writeText -type "plain" -text "get wifi creds                   - View WiFi credentials saved on the system." -Color "DarkGray"
    writeText -type "plain" -text "plugins [plugin name]  - Useful scripts made by others. Try the 'plugins help' command." -Color "DarkGray"
    writeText -type "plain" -text "FULL DOCUMENTATION:" -lineBefore
    writeText -type "plain" -text "https://guided.chaste.pro/dev/chaste-scripts" -Color "DarkGray"
}
function invokeScript {
    param (
        [parameter(Mandatory = $true)]
        [string]$script,
        [parameter(Mandatory = $false)]
        [boolean]$initialize = $false
    ) 

    try {
        if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
            Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
            Exit
        } 

        # Customize console appearance
        $console = $host.UI.RawUI
        $console.BackgroundColor = "Black"
        $console.ForegroundColor = "Gray"
        $console.WindowTitle = "Chaste Scripts"

        if ($initialize) {
            Clear-Host
            readCommand -command "help"
        }

        Invoke-Expression $script
    } catch {
        writeText -type "error" -text "invokeScript-$($_.InvocationInfo.ScriptLineNumber) | $script"
    }
}
function readCommand {
    param (
        [Parameter(Mandatory = $false)]
        [string]$command = ""
    )

    try {
        Write-Host
        if ($command -eq "") { 
            Write-Host "$([char]0x203A) " -NoNewline
            $command = Read-Host 
        }

        $command = $command.ToLower()
        $command = $command.Trim()

        if ($command -ne "help") {
            if (Get-command $command -ErrorAction SilentlyContinue) {
                Invoke-Expression $command
            }
        }

        $filteredCommand = filterCommands -command $command
        $commandDirectory = $filteredCommand[0]
        $commandFile = $filteredCommand[1]
        $commandFunction = $filteredCommand[2]

        New-Item -Path "$env:SystemRoot\Temp\CHASTE-Script.ps1" -ItemType File -Force | Out-Null
        addScript -directory $commandDirectory -file $commandFile
        addScript -directory "core" -file "Framework"
        Add-Content -Path "$env:SystemRoot\Temp\CHASTE-Script.ps1" -Value "invokeScript '$commandFunction'"
        Add-Content -Path "$env:SystemRoot\Temp\CHASTE-Script.ps1" -Value "readCommand"

        $chasteScript = Get-Content -Path "$env:SystemRoot\Temp\CHASTE-Script.ps1" -Raw
        Invoke-Expression $chasteScript
    } catch {
        writeText -type "error" -text "readCommand-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}

function filterCommands {
    param (
        [Parameter(Mandatory)]
        [string]$command
    )

    try {
        $commandArray = $()

        switch ($command) {
            "help" { $commandArray = $("windows", "writeHelp", "writeHelp") }
            "menu" { $commandArray = $("windows", "Menu", "readMenu") }
            "enable admin" { $commandArray = $("windows", "enableAdmin", "enableAdmin") }
            "disable admin" { $commandArray = $("windows", "enableAdmin", "disableAdmin") }
            "add user" { $commandArray = $("windows", "addUser", "addUser") }
            "add local user" { $commandArray = $("windows", "addUser", "addLocalUser") }
            "add ad user" { $commandArray = $("windows", "addUser", "addUser") }
            "remove user" { $commandArray = $("windows", "removeUser", "removeUser") }
            "edit hostname" { $commandArray = $("windows", "editHostname", "editHostname") }
            "edit user" { $commandArray = $("windows", "editUser", "editUser") }
            "edit user name" { $commandArray = $("windows", "editUser", "editUserName") }
            "edit user password" { $commandArray = $("windows", "editUser", "editUserPassword") }
            "edit user group" { $commandArray = $("windows", "editUser", "editUserGroup") }
            "add drive letter" { $commandArray = $("windows", "addDriveLetter", "addDriveLetter") }
            "schedule task" { $commandArray = $("windows", "scheduleTask", "scheduleTask") }
            "plugins" { $commandArray = $("plugins", "Plugins", "readMenu") }
            "plugins help" { $commandArray = $("plugins", "writeHelp", "writeHelp") }
            "plugins reclaim" { $commandArray = $("plugins", "ReclaimW11", "reclaim") }
            "plugins massgravel" { $commandArray = $("plugins", "massgravel", "massgravel") }
            "plugins win11debloat" { $commandArray = $("plugins", "win11Debloat", "win11debloat") }
            default { readCommand }
        }

        return $commandArray
    } catch {
        writeText -type "error" -text "filterCommands-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function addScript {
    param (
        [Parameter(Mandatory)]
        [string]$directory,
        [Parameter(Mandatory)]
        [string]$file
    )

    try {
        $url = "https://raw.githubusercontent.com/badsyntaxx/chaste-scripts/main"

        getDownload -Url "$url/$directory/$file.ps1" -Target "$env:SystemRoot\Temp\$file.ps1"

        $rawScript = Get-Content -Path "$env:SystemRoot\Temp\$file.ps1" -Raw -ErrorAction SilentlyContinue
        Add-Content -Path "$env:SystemRoot\Temp\CHASTE-Script.ps1" -Value $rawScript

        Get-Item -ErrorAction SilentlyContinue "$env:SystemRoot\Temp\$file.ps1" | Remove-Item -ErrorAction SilentlyContinue
    } catch {
        writeText -type "error" -text "addScript-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function writeText {
    param (
        [parameter(Mandatory = $false)]
        [string]$label = "",
        [parameter(Mandatory = $false)]
        [string]$text = "",
        [parameter(Mandatory = $false)]
        [string]$type = "plain",
        [parameter(Mandatory = $false)]
        [string]$Color = "Gray",
        [parameter(Mandatory = $false)]
        [switch]$lineBefore = $false, # Add a new line before output if specified
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false, # Add a new line after output if specified
        [parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary]$List,
        [parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary]$oldData,
        [parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary]$newData
    )

    try {
        # Add a new line before output if specified
        if ($lineBefore) { Write-Host }

        # Format output based on the specified Type
        if ($type -eq "header") {
            Write-Host "# " -ForegroundColor "Cyan" -NoNewline
            Write-Host "$text" -ForegroundColor "White" 
        }
        
        if ($type -eq 'success') { 
            Write-Host "$([char]0x2713) $text"  -ForegroundColor "Green" 
        }
        if ($type -eq 'error') { 
            Write-Host "X $text" -ForegroundColor "Red" 
        }
        if ($type -eq 'notice') { 
            Write-Host "! $text" -ForegroundColor "Yellow" 
        }
        if ($type -eq 'plain') {
            if ($label -ne "") { 
                if ($Color -eq "Gray") {
                    $Color = 'DarkCyan'
                }
                Write-Host "  $label`: " -NoNewline -ForegroundColor "Gray"
                Write-Host "$text" -ForegroundColor $Color 
            } else {
                Write-Host "  $text" -ForegroundColor $Color 
            }
        }
        if ($type -eq 'list') { 
            # Get a list of keys from the options dictionary
            $orderedKeys = $List.Keys | ForEach-Object { $_ }

            # Find the length of the longest key for padding
            $longestKeyLength = ($orderedKeys | Measure-Object -Property Length -Maximum).Maximum

            # Display single option if only one exists
            if ($orderedKeys.Count -eq 1) {
                Write-Host " $($orderedKeys) $(" " * ($longestKeyLength - $orderedKeys.Length)) - $($List[$orderedKeys])"
            } else {
                # Loop through each option and display with padding and color
                for ($i = 0; $i -lt $orderedKeys.Count; $i++) {
                    $key = $orderedKeys[$i]
                    $padding = " " * ($longestKeyLength - $key.Length)
                    Write-Host "    $($key): $padding $($List[$key])" -ForegroundColor $Color
                }
            }
        }

        # Add a new line after output if specified
        if ($lineAfter) { Write-Host }
    } catch {
        writeText -type "error" -text "writeText-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function readInput {
    param (
        [parameter(Mandatory = $false)]
        [string]$Value = "", # A pre-fill value so the user can hit enter without typing command and get the current value if there is one
        [parameter(Mandatory = $false)]
        [string]$prompt, # Provide a specific prompt in necessary
        [parameter(Mandatory = $false)]
        [regex]$Validate = $null,
        [parameter(Mandatory = $false)]
        [string]$ErrorMessage = "", # Provide an optional error message
        [parameter(Mandatory = $false)]
        [switch]$IsSecure = $false, # If prompting for a password
        [parameter(Mandatory = $false)]
        [switch]$CheckExistingUser = $false,
        [parameter(Mandatory = $false)]
        [switch]$lineBefore = $false, # Add a new line before prompt if specified
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false # Add a new line after prompt if specified
    )

    try {
        # Add a new line before prompt if specified
        if ($lineBefore) { Write-Host }

        # Get current cursor position
        $currPos = $host.UI.RawUI.CursorPosition

        Write-Host "? " -NoNewline -ForegroundColor "Cyan"
        Write-Host "$prompt " -NoNewline

        if ($IsSecure) { $userInput = Read-Host -AsSecureString } 
        else { $userInput = Read-Host }

        # Check for existing user if requested
        if ($CheckExistingUser) {
            $account = Get-LocalUser -Name $userInput -ErrorAction SilentlyContinue
            if ($null -ne $account) { $ErrorMessage = "An account with that name already exists." }
        }

        # Validate user input against provided regular expression
        if ($userInput -notmatch $Validate) { $ErrorMessage = "Invalid input. Please try again." } 

        # Display error message if encountered
        if ($ErrorMessage -ne "") {
            writeText -type "error" -text $ErrorMessage
            # Recursively call readInput if user exists
            if ($CheckExistingUser) { return readInput -prompt $prompt -Validate $Validate -CheckExistingUser } 

            # Otherwise, simply call again without CheckExistingUser
            else { return readInput -prompt $prompt -Validate $Validate }
        }

        # Use provided default value if user enters nothing for a non-secure input
        if ($userInput.Length -eq 0 -and $Value -ne "" -and !$IsSecure) { $userInput = $Value }

        # Reset cursor position
        [Console]::SetCursorPosition($currPos.X, $currPos.Y)
        
        Write-Host "? " -ForegroundColor "Cyan" -NoNewline
        if ($IsSecure -and ($userInput.Length -eq 0)) { 
            Write-Host "$prompt                                                "
        } else { 
            Write-Host "$prompt " -NoNewline
            Write-Host "$userInput                                             " -ForegroundColor "DarkCyan"
        }

        # Add a new line after prompt if specified
        if ($lineAfter) { Write-Host }
    
        # Return the validated user input
        return $userInput
    } catch {
        writeText -type "error" -text "readInput-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function readOption {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$options,
        [parameter(Mandatory = $false)]
        [string]$prompt, # Provide a specific prompt in necessary
        [parameter(Mandatory = $false)]
        [switch]$returnKey = $false,
        [parameter(Mandatory = $false)]
        [switch]$returnValue = $false,
        [parameter(Mandatory = $false)]
        [switch]$lineBefore = $false,
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false
    )

    try {
        # Add a line break before the menu if lineBefore is specified
        if ($lineBefore) { Write-Host }

        # Get current cursor position
        $promptPos = $host.UI.RawUI.CursorPosition

        Write-Host "? " -NoNewline -ForegroundColor "Cyan"
        Write-Host "$prompt "

        # Initialize variables for user input handling
        $vkeycode = 0
        $pos = 0
        $oldPos = 0

        # Get a list of keys from the options dictionary
        $orderedKeys = $options.Keys | ForEach-Object { $_ }

        # Get an array of all values
        $values = $options.Values

        # Find the length of the longest key for padding
        $longestKeyLength = ($orderedKeys | Measure-Object -Property Length -Maximum).Maximum

        # Find the length of the longest value
        $longestValueLength = ($values | Measure-Object -Property Length -Maximum).Maximum

        # Display single option if only one exists
        if ($orderedKeys.Count -eq 1) {
            Write-Host "$([char]0x2192)" -ForegroundColor "DarkCyan" -NoNewline
            Write-Host "  $($orderedKeys) $(" " * ($longestKeyLength - $orderedKeys.Length)) - $($options[$orderedKeys])" -ForegroundColor "DarkCyan"
        } else {
            # Loop through each option and display with padding and color
            for ($i = 0; $i -lt $orderedKeys.Count; $i++) {
                $key = $orderedKeys[$i]
                $padding = " " * ($longestKeyLength - $key.Length)
                if ($i -eq $pos) { 
                    Write-Host "$([char]0x2192)" -ForegroundColor "DarkCyan" -NoNewline  
                    Write-Host " $key $padding - $($options[$key])" -ForegroundColor "DarkCyan"
                } else { 
                    Write-Host "  $key $padding - $($options[$key])" -ForegroundColor "Gray" 
                }
            }
        }

        # Get the current cursor position
        $currPos = $host.UI.RawUI.CursorPosition

        # Loop for user input to select an option
        While ($vkeycode -ne 13) {
            $press = $host.ui.rawui.readkey("NoEcho, IncludeKeyDown")
            $vkeycode = $press.virtualkeycode
            Write-host "$($press.character)" -NoNewLine
            if ($orderedKeys.Count -ne 1) { 
                $oldPos = $pos;
                if ($vkeycode -eq 38) { $pos-- }
                if ($vkeycode -eq 40) { $pos++ }
                if ($pos -lt 0) { $pos = 0 }
                if ($pos -ge $orderedKeys.Count) { $pos = $orderedKeys.Count - 1 }

                # Calculate positions for redrawing menu items
                $menuLen = $orderedKeys.Count
                $menuOldPos = New-Object System.Management.Automation.Host.Coordinates(0, ($currPos.Y - ($menuLen - $oldPos)))
                $menuNewPos = New-Object System.Management.Automation.Host.Coordinates(0, ($currPos.Y - ($menuLen - $pos)))
                $oldKey = $orderedKeys[$oldPos]
                $newKey = $orderedKeys[$pos]
            
                # Re-draw the previously selected and newly selected options
                $host.UI.RawUI.CursorPosition = $menuOldPos
                Write-Host "  $($orderedKeys[$oldPos]) $(" " * ($longestKeyLength - $oldKey.Length)) - $($options[$orderedKeys[$oldPos]])" -ForegroundColor "Gray"
                $host.UI.RawUI.CursorPosition = $menuNewPos
                Write-Host "$([char]0x2192)" -ForegroundColor "DarkCyan" -NoNewline
                Write-Host " $($orderedKeys[$pos]) $(" " * ($longestKeyLength - $newKey.Length)) - $($options[$orderedKeys[$pos]])" -ForegroundColor "DarkCyan"
                $host.UI.RawUI.CursorPosition = $currPos
            }
        }

        [Console]::SetCursorPosition($promptPos.X, $promptPos.Y)

        if ($orderedKeys.Count -ne 1) {
            Write-Host "? " -ForegroundColor "Cyan" -NoNewline
            Write-Host $prompt -NoNewline
            Write-Host " $($orderedKeys[$pos])" -ForegroundColor "DarkCyan"
        } else {
            Write-Host "? " -ForegroundColor "Cyan" -NoNewline
            Write-Host $prompt -NoNewline
            Write-Host " $($orderedKeys) $(" " * ($longestKeyLength - $orderedKeys.Length))" -ForegroundColor "DarkCyan"
        }

        for ($i = 0; $i -lt $options.Count; $i++) {
            Write-Host "       $(" " * ($longestKeyLength + $longestValueLength))"
        }
        
        [Console]::SetCursorPosition($promptPos.X, $promptPos.Y)
        Write-Host

        # Add a line break after the menu if lineAfter is specified
        if ($lineAfter) { Write-Host }

        # Handle function return values (key, value, menu position) based on parameters
        if ($returnKey) { 
            if ($orderedKeys.Count -eq 1) { 
                return $orderedKeys 
            } else { 
                return $orderedKeys[$pos] 
            } 
        } 
        if ($returnValue) { 
            if ($orderedKeys.Count -eq 1) { 
                return $options[$pos] 
            } else { 
                return $options[$orderedKeys[$pos]] 
            } 
        } else { 
            return $pos 
        }
    } catch {
        writeText -type "error" -text "readOption-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function getDownload {
    param (
        [Parameter(Mandatory)]
        [string]$Url,
        [Parameter(Mandatory)]
        [string]$Target,
        [Parameter(Mandatory = $false)]
        [string]$label = 'Loading',
        [Parameter(Mandatory = $false)]
        [string]$failText = 'Connection failed...',
        [parameter(Mandatory = $false)]
        [int]$MaxRetries = 2,
        [parameter(Mandatory = $false)]
        [int]$Interval = 1,
        [parameter(Mandatory = $false)]
        [switch]$visible = $false
    )
    Begin {
        function showProgress {
            param (
                [Parameter(Mandatory)]
                [Single]$TotalValue,
                [Parameter(Mandatory)]
                [Single]$CurrentValue,
                [Parameter(Mandatory)]
                [string]$label,
                [Parameter()]
                [string]$ValueSuffix,
                [Parameter()]
                [int]$BarSize = 40,
                [Parameter()]
                [switch]$Complete
            )
            
            # calc %
            $percent = $CurrentValue / $TotalValue
            $percentComplete = $percent * 100
            if ($ValueSuffix) {
                $ValueSuffix = " $ValueSuffix" # add space in front
            }
  
            # build progressbar with string function
            $curBarSize = $BarSize * $percent
            $progbar = ""
            $progbar = $progbar.PadRight($curBarSize, [char]9608)
            $progbar = $progbar.PadRight($BarSize, [char]9617)

            if (!$Complete.IsPresent) {
                Write-Host -NoNewLine "`r  $label $progbar $($percentComplete.ToString("##0.00").PadLeft(6))%"
            } else {
                Write-Host -NoNewLine "`r  $label $progbar $($percentComplete.ToString("##0.00").PadLeft(6))%"                    
            }              
        }
    }
    Process {
        for ($retryCount = 1; $retryCount -le $MaxRetries; $retryCount++) {
            try {
                $storeEAP = $ErrorActionPreference
                $ErrorActionPreference = 'Stop'
        
                # invoke request
                $request = [System.Net.HttpWebRequest]::Create($Url)
                $response = $request.GetResponse()
  
                if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403 -or $response.StatusCode -eq 404) {
                    throw "Remote file either doesn't exist, is unauthorized, or is forbidden for '$Url'."
                }
  
                if ($Target -match '^\.\\') {
                    $Target = Join-Path (Get-Location -PSProvider "FileSystem") ($Target -Split '^\.')[1]
                }
            
                if ($Target -and !(Split-Path $Target)) {
                    $Target = Join-Path (Get-Location -PSProvider "FileSystem") $Target
                }

                if ($Target) {
                    $fileDirectory = $([System.IO.Path]::GetDirectoryName($Target))
                    if (!(Test-Path($fileDirectory))) {
                        [System.IO.Directory]::CreateDirectory($fileDirectory) | Out-Null
                    }
                }

                [long]$fullSize = $response.ContentLength
                $fullSizeMB = $fullSize / 1024 / 1024
  
                # define buffer
                [byte[]]$buffer = new-object byte[] 1048576
                [long]$total = [long]$count = 0
  
                # create reader / writer
                $reader = $response.GetResponseStream()
                $writer = new-object System.IO.FileStream $Target, "Create"
  
                # start download
                $finalBarCount = 0 #show final bar only one time
                do {
                    $count = $reader.Read($buffer, 0, $buffer.Length)
          
                    $writer.Write($buffer, 0, $count)
              
                    $total += $count
                    $totalMB = $total / 1024 / 1024
          
                    if ($visible) {
                        if ($fullSize -gt 0) {
                            showProgress -TotalValue $fullSizeMB -CurrentValue $totalMB -label $label -ValueSuffix "MB"
                        }

                        if ($total -eq $fullSize -and $count -eq 0 -and $finalBarCount -eq 0) {
                            showProgress -TotalValue $fullSizeMB -CurrentValue $totalMB -label $label -ValueSuffix "MB" -Complete
                            $finalBarCount++
                        }
                    }
                } while ($count -gt 0)

                # Prevent the following output from appearing on the same line as the progress bar
                if ($visible) {
                    Write-Host 
                }
            } catch {
                # writeText -type "plain" -text "$($_.Exception.Message)"
                writeText -type "plain" -text $failText
            
                if ($retryCount -lt $MaxRetries) {
                    writeText "Retrying..."
                    Start-Sleep -Seconds $Interval
                } else {
                    writeText -type "error" -text "Load failed. Exiting function." 
                }
            } finally {
                # cleanup
                if ($reader) { 
                    $reader.Close() 
                }
                if ($writer) { 
                    $writer.Flush(); $writer.Close() 
                }
        
                $ErrorActionPreference = $storeEAP
                [GC]::Collect()
            } 
        }   
    }
}
function getUserData {
    param (
        [parameter(Mandatory = $true)]
        [string]$username
    )

    try {
        $user = Get-LocalUser -Name $username
        $groups = Get-LocalGroup | Where-Object { $user.SID -in ($_ | Get-LocalGroupMember | Select-Object -ExpandProperty "SID") } | Select-Object -ExpandProperty "Name"
        $userProfile = Get-CimInstance Win32_UserProfile -Filter "SID = '$($user.SID)'"
        $dir = $userProfile.LocalPath
        if ($null -ne $userProfile) { $dir = $userProfile.LocalPath } else { $dir = "Awaiting first sign in." }

        $source = Get-LocalUser -Name $username | Select-Object -ExpandProperty PrincipalSource

        $data = [ordered]@{
            "Name"   = "$username"
            "Groups" = "$($groups -join ';')"
            "Path"   = "$dir"
            "Source" = "$source"
        }

        return $data
    } catch {
        writeText -type "error" -text "getUserData-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
function selectUser {
    param (
        [parameter(Mandatory = $false)]
        [string]$prompt = "Select a user account:",
        [parameter(Mandatory = $false)]
        [switch]$lineBefore = $false,
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false,
        [parameter(Mandatory = $false)]
        [switch]$writeResult = $false
    )

    try {
        # Add a line break before the menu if lineBefore is specified
        if ($lineBefore) { Write-Host }
         
        # Initialize empty array to store user names
        $userNames = @()

        # Get all local users on the system
        $localUsers = Get-LocalUser

        # Define a list of accounts to exclude from selection
        $excludedAccounts = @("DefaultAccount", "WDAGUtilityAccount", "Guest", "defaultuser0")

        # Check if the "Administrator" account is disabled and add it to excluded list if so
        $adminEnabled = Get-LocalUser -Name "Administrator" | Select-Object -ExpandProperty Enabled
        if (!$adminEnabled) { $excludedAccounts += "Administrator" }

        # Filter local users to exclude predefined accounts
        foreach ($user in $localUsers) {
            if ($user.Name -notin $excludedAccounts) { $userNames += $user.Name }
        }

        # Create an ordered dictionary to store username and group information
        $accounts = [ordered]@{}
        foreach ($name in $userNames) {
            # Get details for the current username
            $username = Get-LocalUser -Name $name
            
            # Find groups the user belongs to
            $groups = Get-LocalGroup | Where-Object { $username.SID -in ($_ | Get-LocalGroupMember | Select-Object -ExpandProperty "SID") } | Select-Object -ExpandProperty "Name"
            # Convert groups to a semicolon-separated string
            $groupString = $groups -join ';'

            # Get the users source
            $source = Get-LocalUser -Name $username | Select-Object -ExpandProperty PrincipalSource

            # Add username and group string to the dictionary
            $accounts["$username"] = "$source | $groupString"
        }

        $accounts["Cancel"] = "Do not select a user and exit this function."

        # Prompt user to select a user from the list and return the key (username)
        $choice = readOption -options $accounts -prompt $prompt -returnKey

        if ($choice -eq "Cancel") {
            readCommand
        }

        # Get user data using the selected username
        $data = getUserData -Username $choice

        if ($writeResult) {
            Write-Host
            # Display user data as a list
            writeText -type "list" -List $data -Color "Green"
        }

        # Add a line break after the menu if lineAfter is specified
        if ($lineAfter) { Write-Host }

        # Return the user data dictionary
        return $data
    } catch {
        writeText -type "error" -text "selectUser-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
invokeScript 'writeHelp'
readCommand
