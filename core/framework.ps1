function invoke-script {
    param (
        [parameter(Mandatory = $true)]
        [string]$script,
        [parameter(Mandatory = $false)]
        [boolean]$initialize = $false
    ) 

    try {
        # Check if user has administrator privileges
        if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
            # If not, elevate privileges and restart function with current arguments
            Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
            Exit
        } 

        # Customize console appearance
        $console = $host.UI.RawUI
        $console.BackgroundColor = "Black"
        $console.ForegroundColor = "Gray"
        $console.WindowTitle = "Chased Scripts"

        if ($initialize) {
            # Display a stylized menu prompt
            Clear-Host
            Write-Host
            Write-Host "  Welcome to Chased Scripts"
            Write-Host "  Enter" -ForegroundColor DarkGray -NoNewLine
            Write-Host " menu" -ForegroundColor DarkCyan -NoNewLine
            Write-Host " or" -ForegroundColor DarkGray -NoNewLine
            Write-Host " help" -ForegroundColor DarkCyan -NoNewLine
            Write-Host " if you don't know commands." -ForegroundColor DarkGray
            Write-Host
        }

        # Call the script specified by the parameter
        Invoke-Expression $script
    } catch {
        # Error handling: display error message and give an opportunity to run another command
        exit-script -Type "error" -Text "Initialization Error: $($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
        get-cscommand
    }
}

function get-cscommand {
    param (
        [Parameter(Mandatory = $false)]
        [string]$command = ""
    )

    try {
        # Get the command from the user
        if ($command -eq "") { 
            # Right carrot icon, this is a prompt for a command in CHASED Scripts
            Write-Host "  $([char]0x203A) " -NoNewline 
            $command = Read-Host 
        }
        $command = $command.ToLower()

        # Extract the first word
        if ($command -ne "" -and $command -match "^(?-i)(\w+(-\w+)*)") { $firstWord = $matches[1] }

        if (Get-Command $firstWord -ErrorAction SilentlyContinue) {
            Write-Host
            Invoke-Expression $command
            Write-Host
            get-cscommand
        }

        # Adjust command and paths
        $subCommands = @("windows", "plugins", "nuvia");
        $subPath = "windows"
        foreach ($sub in $subCommands) {
            if ($firstWord -eq $sub -and $firstWord -ne 'menu') { 
                $command = $command -replace "^$firstWord \s*", "" 
                $subPath = $sub
            } elseif ($firstWord -eq 'menu') {
                $subPath = "core"
            }
        }

        # Convert command to title case and replace the first spaces with a dash and the second space with no space
        $lowercaseCommand = $command.ToLower()
        $fileFunc = $lowercaseCommand -replace ' ', '-'

        # Create the main script file
        New-Item -Path "$env:TEMP\CHASED-Script.ps1" -ItemType File -Force | Out-Null

        add-script -subPath $subPath -script $fileFunc
        add-script -subpath "core" -script "framework"

        # Add a final line that will invoke the desired function
        Add-Content -Path "$env:TEMP\CHASED-Script.ps1" -Value "invoke-script '$fileFunc'"

        # Execute the combined script
        $chasedScript = Get-Content -Path "$env:TEMP\CHASED-Script.ps1" -Raw
        Invoke-Expression $chasedScript
    } catch {
        # Error handling: display an error message and prompt for a new command
        Write-Host "    $($_.Exception.Message) | init-$($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
        get-cscommand
    }
}

function add-script {
    param (
        [Parameter(Mandatory)]
        [string]$subPath,
        [Parameter(Mandatory)]
        [string]$script,
        [Parameter(Mandatory = $false)]
        [string]$progressText
    )

    $url = "https://raw.githubusercontent.com/badsyntaxx/chased-scripts/main"

    # Download the script
    $download = get-download -Url "$url/$subPath/$script.ps1" -Target "$env:TEMP\$script.ps1" -failText "Could not acquire components..."
    if (!$download) { throw "Could not acquire dependency." }

    # Append the script to the main script
    $rawScript = Get-Content -Path "$env:TEMP\$script.ps1" -Raw -ErrorAction SilentlyContinue
    Add-Content -Path "$env:TEMP\CHASED-Script.ps1" -Value $rawScript

    # Remove the script file
    Get-Item -ErrorAction SilentlyContinue "$env:TEMP\$script.ps1" | Remove-Item -ErrorAction SilentlyContinue
}

function get-help() {
    write-text -Type 'header' -text 'Commands'
    Write-Host "    enable admin        - Toggle the built-in administrator account."
    Write-Host "    add user            - Add a user to the system."
    Write-Host "    add local user      - Add a local user to the system."
    Write-Host "    add ad user         - Add a domain user to the system."
    Write-Host "    edit user           - Add a domain user to the system."
    Write-Host "    edit user name      - Add a domain user to the system."
    Write-Host "    edit user password  - Add a domain user to the system."
    Write-Host "    edit user group     - Add a domain user to the system."
    Write-Host "    edit net adapter    - Add a domain user to the system."
    Write-Host
    get-cscommand # Recursively call itself to prompt for a new command
}

function write-text {
    param (
        [parameter(Mandatory = $false)]
        [string]$text = "",
        [parameter(Mandatory = $false)]
        [string]$type = "plain",
        [parameter(Mandatory = $false)]
        [string]$Color = "Gray",
        [parameter(Mandatory = $false)]
        [switch]$LineBefore = $false, # Add a new line before output if specified
        [parameter(Mandatory = $false)]
        [switch]$LineAfter = $false, # Add a new line after output if specified
        [parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary]$List,
        [parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary]$OldData,
        [parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary]$NewData
    )

    try {
        # Add a new line before output if specified
        if ($LineBefore) { Write-Host }

        # Format output based on the specified Type
        if ($type -eq "label") { Write-Host "    $text" -ForegroundColor "Yellow" }
        if ($type -eq 'success') { Write-Host "    $text"  -ForegroundColor "Green" }
        if ($type -eq 'error') { Write-Host "    $text" -ForegroundColor "Red" }
        if ($type -eq 'notice') { Write-Host "    $text" -ForegroundColor "Yellow" }
        if ($type -eq 'plain') { Write-Host "    $text" -ForegroundColor $Color }
        if ($type -eq 'list') { 
            # Get a list of keys from the Options dictionary
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
                    Write-Host "    $($key): $padding $($List[$key])" -ForegroundColor "DarkGray"
                }
            }
        }

        if ($type -eq 'fail') { 
            Write-Host "  X " -ForegroundColor "Red" -NoNewline
            Write-Host "$text" 
        }

        # Format output for data comparison
        if ($type -eq 'compare') { 
            foreach ($data in $OldData.Keys) {
                if ($OldData["$data"] -ne $NewData["$data"]) {
                    Write-Host "    $($OldData["$data"])" -ForegroundColor "Gray" -NoNewline
                    Write-Host " $([char]0x2192) " -ForegroundColor "Magenta" -NoNewline
                    Write-Host "$($NewData["$data"])" -ForegroundColor "White"
                } else {
                    Write-Host "    $($OldData["$data"])"
                }
            }
        }

        # Add a new line after output if specified
        if ($LineAfter) { Write-Host }
    } catch {
        # Display error message and end the script
        exit-script -Type "error" -Text "write-text-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

function write-box {
    param (
        [parameter(Mandatory = $false)]
        [array]$Text
    )

    $horizontalLine = [string][char]0x2500
    $verticalLine = [string][char]0x2502
    $topLeft = [string][char]0x250C
    $topRight = [string][char]0x2510
    $bottomLeft = [string][char]0x2514
    $bottomRight = [string][char]0x2518
    $longestString = $Text | Sort-Object Length -Descending | Select-Object -First 1
    $count = $longestString.Length

    Write-Host " $topLeft$($horizontalLine * ($count + 2))$topRight" -ForegroundColor Cyan

    foreach ($line in $Text) {
        Write-Host " $verticalLine" -ForegroundColor Cyan -NoNewline
        
        Write-Host " $($line.PadRight($count))" -ForegroundColor White -NoNewline
        
        Write-Host " $verticalLine" -ForegroundColor Cyan
    }

    Write-Host " $bottomLeft$($horizontalLine * ($count + 2))$bottomRight" -ForegroundColor Cyan
}

function write-welcome {
    param (
        [parameter(Mandatory = $true)]
        [string]$Title,
        [parameter(Mandatory = $true)]
        [string]$Description,
        [parameter(Mandatory = $false)]
        [string]$Command
    )

    # Get-Item -ErrorAction SilentlyContinue "$env:TEMP\CHASED-Script.ps1" | Remove-Item -ErrorAction SilentlyContinue
    Write-Host
    Write-Host " ::"  -ForegroundColor Magenta -NoNewline
    Write-Host " Executing command:" -NoNewline
    Write-Host " $Command" -ForegroundColor Cyan -NoNewline
    Write-Host " | $Description" -ForegroundColor Gray
}

function exit-script {
    param (
        [parameter(Mandatory = $false)]
        [string]$text = "",
        [parameter(Mandatory = $false)]
        [string]$type = "plain",
        [parameter(Mandatory = $false)]
        [switch]$lineBefore = $false, # Add a new line before output if specified
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false # Add a new line after output if specified
    )

    # Add a new line before output if specified
    if ($lineBefore) { Write-Host }
    write-text -Type $Type -Text $Text
    # Add a new line after output if specified
    if ($lineAfter) { Write-Host }
    get-cscommand 
}

function get-download {
    param (
        [Parameter(Mandatory)]
        [string]$Url,
        [Parameter(Mandatory)]
        [string]$Target,
        [Parameter(Mandatory = $false)]
        [string]$ProgressText = 'Loading',
        [Parameter(Mandatory = $false)]
        [string]$failText = 'Download failed...',
        [parameter(Mandatory = $false)]
        [int]$MaxRetries = 2,
        [parameter(Mandatory = $false)]
        [int]$Interval = 1,
        [parameter(Mandatory = $false)]
        [switch]$visible = $false
    )
    Begin {
        function Show-Progress {
            param (
                [Parameter(Mandatory)]
                [Single]$TotalValue,
                [Parameter(Mandatory)]
                [Single]$CurrentValue,
                [Parameter(Mandatory)]
                [string]$ProgressText,
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
                Write-Host -NoNewLine "`r    $ProgressText $progbar $($percentComplete.ToString("##0.00").PadLeft(6))%"
            } else {
                Write-Host -NoNewLine "`r    $ProgressText $progbar $($percentComplete.ToString("##0.00").PadLeft(6))%"                    
            }              
             
        }
    }
    Process {
        $downloadComplete = $true 
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
                            Show-Progress -TotalValue $fullSizeMB -CurrentValue $totalMB -ProgressText $ProgressText -ValueSuffix "MB"
                        }

                        if ($total -eq $fullSize -and $count -eq 0 -and $finalBarCount -eq 0) {
                            Show-Progress -TotalValue $fullSizeMB -CurrentValue $totalMB -ProgressText $ProgressText -ValueSuffix "MB" -Complete
                            $finalBarCount++
                        }
                    }
                } while ($count -gt 0)

                # Prevent the following output from appearing on the same line as the progress bar
                if ($visible) {
                    Write-Host 
                }
                
                if ($downloadComplete) { return $true } else { return $false }
            } catch {
                # write-text -Type "fail" -Text "$($_.Exception.Message)"
                write-text -Type "fail" -Text $failText
                
                $downloadComplete = $false
            
                if ($retryCount -lt $MaxRetries) {
                    write-text "Retrying..."
                    Start-Sleep -Seconds $Interval
                } else {
                    write-text -Type "error" -Text "Maximum retries reached." 
                }
            } finally {
                # cleanup
                if ($reader) { $reader.Close() }
                if ($writer) { $writer.Flush(); $writer.Close() }
        
                $ErrorActionPreference = $storeEAP
                [GC]::Collect()
            } 
        }   
    }
}

function get-input {
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

        # Display prompt with a diamond symbol (optional secure input for passwords)
        Write-Host "  $([char]0x203A) $prompt" -NoNewline 
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
            write-text -Type "error" -Text $ErrorMessage
            # Recursively call get-input if user exists
            if ($CheckExistingUser) { return get-input -Prompt $prompt -Validate $Validate -CheckExistingUser } 

            # Otherwise, simply call again without CheckExistingUser
            else { return get-input -Prompt $prompt -Validate $Validate }
        }

        # Use provided default value if user enters nothing for a non-secure input
        if ($userInput.Length -eq 0 -and $Value -ne "" -and !$IsSecure) { $userInput = $Value }

        # Reset cursor position
        [Console]::SetCursorPosition($currPos.X, $currPos.Y)
        
        # Display checkmark symbol and user input (masked for secure input)
        Write-Host "  $([char]0x2713) " -ForegroundColor "Green" -NoNewline
        if ($IsSecure -and ($userInput.Length -eq 0)) { Write-Host "$prompt                                                       " } 
        else { Write-Host "$Prompt$userInput                                             " }

        # Add a new line after prompt if specified
        if ($lineAfter) { Write-Host }
    
        # Return the validated user input
        return $userInput
    } catch {
        # Handle errors during input
        write-text -Type "error" -Text "Input Error: $($_.Exception.Message)"
    }
}

function get-option {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Options,
        [parameter(Mandatory = $false)]
        [switch]$ReturnKey = $false,
        [parameter(Mandatory = $false)]
        [switch]$ReturnValue = $false,
        [parameter(Mandatory = $false)]
        [boolean]$lineBefore = $true,
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false
    )

    try {
        # Add a line break before the menu if lineBefore is specified
        if ($lineBefore) { Write-Host }

        # Initialize variables for user input handling
        $vkeycode = 0
        $pos = 0
        $oldPos = 0

        # Get a list of keys from the Options dictionary
        $orderedKeys = $Options.Keys | ForEach-Object { $_ }

        # Find the length of the longest key for padding
        $longestKeyLength = ($orderedKeys | Measure-Object -Property Length -Maximum).Maximum

        # Display single option if only one exists
        if ($orderedKeys.Count -eq 1) {
            Write-Host "  $([char]0x203A)" -ForegroundColor "Gray" -NoNewline
            Write-Host " $($orderedKeys) $(" " * ($longestKeyLength - $orderedKeys.Length)) - $($Options[$orderedKeys])" -ForegroundColor "White"
        } else {
            # Loop through each option and display with padding and color
            for ($i = 0; $i -lt $orderedKeys.Count; $i++) {
                $key = $orderedKeys[$i]
                $padding = " " * ($longestKeyLength - $key.Length)
                if ($i -eq $pos) { 
                    Write-Host "  $([char]0x203A)" -ForegroundColor "Gray" -NoNewline  
                    Write-Host " $key $padding - $($Options[$key])" -ForegroundColor "Cyan"
                } else { Write-Host "    $key $padding - $($Options[$key])" -ForegroundColor "Gray" }
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
                Write-Host "    $($orderedKeys[$oldPos]) $(" " * ($longestKeyLength - $oldKey.Length)) - $($Options[$orderedKeys[$oldPos]])" -ForegroundColor "Gray"
                $host.UI.RawUI.CursorPosition = $menuNewPos
                Write-Host "  $([char]0x203A)" -ForegroundColor "Gray" -NoNewline
                Write-Host " $($orderedKeys[$pos]) $(" " * ($longestKeyLength - $newKey.Length)) - $($Options[$orderedKeys[$pos]])" -ForegroundColor "Cyan"
                $host.UI.RawUI.CursorPosition = $currPos
            }
        }

        $host.UI.RawUI.CursorPosition = $menuNewPos
        Write-Host "  $([char]0x2713)" -ForegroundColor "Green" -NoNewline
        Write-Host " $($orderedKeys[$pos]) $(" " * ($longestKeyLength - $newKey.Length)) - $($Options[$orderedKeys[$pos]])" -ForegroundColor "Cyan"
        $host.UI.RawUI.CursorPosition = $currPos

        # Add a line break after the menu if lineAfter is specified
        if ($lineAfter) { Write-Host }

        # Handle function return values (key, value, menu position) based on parameters
        if ($ReturnKey) { if ($orderedKeys.Count -eq 1) { return $orderedKeys } else { return $orderedKeys[$pos] } } 
        if ($ReturnValue) { if ($orderedKeys.Count -eq 1) { return $Options[$pos] } else { return $Options[$orderedKeys[$pos]] } }
        else { return $pos }
    } catch {
        # Display error message and end the script
        write-text -Type "error" -Text "Error | get-option-$($_.InvocationInfo.ScriptLineNumber)"
    }
}

function get-closing {
    param (
        [parameter(Mandatory = $false)]
        [string]$script = ""
    ) 

    $choice = get-option -Options $([ordered]@{
            "Submit" = "Submit and apply your changes." 
            "Rest"   = "Discard changes and start this task over at the beginning."
            "Exit"   = "Exit this task but remain in the CHASED Scripts CLI." 
        }) -lineAfter

    if ($choice -eq 1) { 
        if ($script -ne "") { invoke-script $script } 
        else { get-cscommand }
    }
    if ($choice -eq 2) { exit-script }
}

function get-userdata {
    param (
        [parameter(Mandatory = $true)]
        [string]$Username
    )

    try {
        $user = Get-LocalUser -Name $Username
        $groups = Get-LocalGroup | Where-Object { $user.SID -in ($_ | Get-LocalGroupMember | Select-Object -ExpandProperty "SID") } | Select-Object -ExpandProperty "Name"
        $userProfile = Get-CimInstance Win32_UserProfile -Filter "SID = '$($user.SID)'"
        $dir = $userProfile.LocalPath
        if ($null -ne $userProfile) { $dir = $userProfile.LocalPath } else { $dir = "Awaiting first sign in." }

        $source = Get-LocalUser -Name $Username | Select-Object -ExpandProperty PrincipalSource

        $data = [ordered]@{
            "Name"   = "$Username"
            "Groups" = "$($groups -join ';')"
            "Path"   = "$dir"
            "Source" = "$source"
        }

        return $data
    } catch {
        write-text -Type "error" -Text "Error getting account info: $($_.Exception.Message)"
    }
}

function select-user {
    param (
        [parameter(Mandatory = $false)]
        [string]$CustomHeader = "Select a user"
    )

    try {
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

        # Prompt user to select a user from the list and return the key (username)
        $choice = get-option -Options $accounts -ReturnKey -lineAfter

        # Get user data using the selected username
        $data = get-userdata -Username $choice

        # Display user data as a list
        write-text -Type "list" -List $data

        # Return the user data dictionary
        return $data
    } catch {
        # Handle errors during user selection
        write-text -Type "error" -Text "Select user error: $($_.Exception.Message)"
    }
}