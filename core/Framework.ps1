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
        $console.ForegroundColor = "DarkGray"
        $console.WindowTitle = "ShellCLI"

        if ($initialize) {
            Clear-Host
            Write-Host
            Write-Host " $([char]0x250C)" -NoNewline -ForegroundColor "Gray"
            Write-Host " Try" -NoNewline
            Write-Host " help" -ForegroundColor "Cyan" -NoNewline
            Write-Host " or" -NoNewline
            Write-Host " menu" -NoNewline -ForegroundColor "Cyan"
            Write-Host " if you get stuck."
            Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
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
        Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
        if ($command -eq "") { 
            Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
            Write-Host " $([char]0x2502)" -NoNewline -ForegroundColor "Gray"
            Write-Host " $([char]0x203A) " -NoNewline  -ForegroundColor "Cyan"
            $command = Read-Host 
            Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
        }

        $command = $command.ToLower()
        $command = $command.Trim()
        $filteredCommand = filterCommands -command $command
        $commandDirectory = $filteredCommand[0]
        $commandFile = $filteredCommand[1]
        $commandFunction = $filteredCommand[2]

        New-Item -Path "$env:SystemRoot\Temp\SHELLCLI.ps1" -ItemType File -Force | Out-Null
        addScript -directory $commandDirectory -file $commandFile
        addScript -directory "core" -file "Framework"
        Add-Content -Path "$env:SystemRoot\Temp\SHELLCLI.ps1" -Value "invokeScript '$commandFunction'"
        Add-Content -Path "$env:SystemRoot\Temp\SHELLCLI.ps1" -Value "readCommand"

        $shellCLI = Get-Content -Path "$env:SystemRoot\Temp\SHELLCLI.ps1" -Raw
        Invoke-Expression $shellCLI
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
            "" { $commandArray = $("windows", "Helpers", "shellCLI") }
            "help" { $commandArray = $("windows", "Helpers", "writeHelp") }
            "menu" { $commandArray = $("windows", "Helpers", "readMenu") }
            "toggle context menu" { $commandArray = $("windows", "Toggle Context Menu", "toggleContextMenu") }
            "enable context menu" { $commandArray = $("windows", "Toggle Context Menu", "enableContextMenu") }
            "disable context menu" { $commandArray = $("windows", "Toggle Context Menu", "disableContextMenu") }
            "toggle admin" { $commandArray = $("windows", "Toggle Admin", "toggleAdmin") }
            "enable admin" { $commandArray = $("windows", "Toggle Admin", "enableAdmin") }
            "disable admin" { $commandArray = $("windows", "Toggle Admin", "disableAdmin") }
            "list users" { $commandArray = $("windows", "User", "listUsers") }
            "add user" { $commandArray = $("windows", "User", "addUser") }
            "add local user" { $commandArray = $("windows", "User", "addLocalUser") }
            "add ad user" { $commandArray = $("windows", "User", "addADUser") }
            "add drive letter" { $commandArray = $("windows", "Add Drive Letter", "addDriveLetter") }
            "remove user" { $commandArray = $("windows", "User", "removeUser") }
            "edit hostname" { $commandArray = $("windows", "Edit Hostname", "editHostname") }
            "edit description" { $commandArray = $("windows", "Edit Hostname", "editDescription") }
            "edit user" { $commandArray = $("windows", "Edit User", "editUser") }
            "edit user name" { $commandArray = $("windows", "Edit User", "editUserName") }
            "edit user password" { $commandArray = $("windows", "Edit User", "editUserPassword") }
            "edit user group" { $commandArray = $("windows", "Edit User", "editUserGroup") }
            "edit net adapter" { $commandArray = $("windows", "Edit Net Adapter", "editNetAdapter") }
            "get wifi creds" { $commandArray = $("windows", "Get Wifi Creds", "getWifiCreds") }
            "get software" { $commandArray = $("windows", "Get Software", "getSoftware") }
            "schedule task" { $commandArray = $("windows", "Schedule Task", "scheduleTask") }
            "update windows" { $commandArray = $("windows", "Update Windows", "updateWindows") }
            "repair windows" { $commandArray = $("windows", "Repair Windows", "repairWindows") }
            "plugins" { $commandArray = $("plugins", "Helpers", "plugins") }
            "plugins menu" { $commandArray = $("plugins", "Helpers", "readMenu") }
            "plugins help" { $commandArray = $("plugins", "Helpers", "writeHelp") }
            "plugins reclaimw11" { $commandArray = $("plugins", "ReclaimW11", "reclaimw11") }
            "plugins massgravel" { $commandArray = $("plugins", "massgravel", "massgravel") }
            "plugins win11debloat" { $commandArray = $("plugins", "win11Debloat", "win11Debloat") }
            "share gpu with vm" { $commandArray = ("windows", "Share GPU with VM", "shareGPUWithVM") }
            "copy host gpu drivers to vm" { $commandArray = ("windows", "Share GPU with VM", "copyHostGPUDriversToVM") }
            "install host gpu drivers on vm" { $commandArray = ("windows", "Share GPU with VM", "installHostGPUDriversOnVM") }
            "partition gpu" { $commandArray = ("windows", "Share GPU with VM", "partitionGPU") }
            "generate encrypted password" { $commandArray = ("windows", "Generate Encrypted Password", "generateEncryptedPassword") }
            "add premade account" { $commandArray = ("windows", "Add Premade Account", "addPremadeAccount") }
            default { 
                if ($command -ne "help" -and $command -ne "" -and $command -match "^(?-i)(\w+(-\w+)*)") {
                    if (Get-command $matches[1] -ErrorAction SilentlyContinue) {
                        $output = Invoke-Expression -Command $command 
                        $output | Format-Table | Out-String | ForEach-Object { Write-Host $_ }
                        readCommand
                    }
                }
                Write-Host " $([char]0x251C)" -NoNewline -ForegroundColor "Gray"
                Write-Host "  Unrecognized command `"$command`". Try" -NoNewline -ForegroundColor "White"
                Write-Host " help" -ForegroundColor "Cyan" -NoNewline
                Write-Host " or" -NoNewline -ForegroundColor "White"
                Write-Host " menu" -NoNewline -ForegroundColor "Cyan"
                Write-Host " to learn more." -ForegroundColor "White"
                readCommand 
            }
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

        $download = getDownload -url "$url/$directory/$file.ps1" -target "$env:SystemRoot\Temp\$file.ps1" -hide

        if ($download -eq $true) {
            $rawScript = Get-Content -Path "$env:SystemRoot\Temp\$file.ps1" -Raw -ErrorAction SilentlyContinue
            Add-Content -Path "$env:SystemRoot\Temp\SHELLCLI.ps1" -Value $rawScript

            Get-Item -ErrorAction SilentlyContinue "$env:SystemRoot\Temp\$file.ps1" | Remove-Item -ErrorAction SilentlyContinue
        }
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
        [string]$Color = "DarkGray",
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
        if ($lineBefore) { Write-Host " $([char]0x2502)" -ForegroundColor "Gray" }

        # Format output based on the specified Type
        if ($type -eq "header") {
            # $l = $([char]0x2500)
            Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
            Write-Host " $([char]0x251C)" -NoNewline -ForegroundColor "Gray"
            Write-Host " $text " -ForegroundColor "White"
        }

        if ($type -eq "prompt") {
            Write-Host " $([char]0x251C)" -NoNewline -ForegroundColor "Gray"
            Write-Host " $text" -ForegroundColor "Gray"
        }

        if ($type -eq 'success') { 
            Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
            Write-Host " $([char]0x251C)" -NoNewline -ForegroundColor "Gray"
            Write-Host " $([char]0x2713) $text"  -ForegroundColor "Green"
            Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
        }

        if ($type -eq 'error') { 
            Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
            Write-Host " $([char]0x251C)" -NoNewline -ForegroundColor "Gray"
            Write-Host " X $text" -ForegroundColor "Red"
            Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
        }

        if ($type -eq 'notice') { 
            Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
            Write-Host " $([char]0x251C)" -NoNewline -ForegroundColor "Gray"
            Write-Host " ! $text" -ForegroundColor "Yellow" 
            Write-Host " $([char]0x2502)" -ForegroundColor "Gray"
        }

        if ($type -eq 'plain') {
            if ($label -ne "") { 
                if ($Color -eq "Gray") {
                    $Color = 'DarkCyan'
                }
                Write-Host " $([char]0x2502)" -NoNewline -ForegroundColor "Gray"
                Write-Host " $label`: " -NoNewline -ForegroundColor "Gray"
                Write-Host "$text" -ForegroundColor $Color 
            } else {
                Write-Host " $([char]0x2502)" -NoNewline -ForegroundColor "Gray"
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
                Write-Host " $([char]0x2502)" -NoNewline -ForegroundColor "Gray"
                Write-Host " $($orderedKeys) $(" " * ($longestKeyLength - $orderedKeys.Length)) - $($List[$orderedKeys])"
            } else {
                # Loop through each option and display with padding and color
                for ($i = 0; $i -lt $orderedKeys.Count; $i++) {
                    $key = $orderedKeys[$i]
                    $padding = " " * ($longestKeyLength - $key.Length)
                    Write-Host " $([char]0x2502)" -NoNewline -ForegroundColor "Gray"
                    Write-Host "   $($key): $padding $($List[$key])" -ForegroundColor $Color
                }
            }
        }

        # Add a new line after output if specified
        if ($lineAfter) { Write-Host " $([char]0x2502)" -ForegroundColor "Gray" }
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
        if ($lineBefore) { Write-Host " $([char]0x2502)" -ForegroundColor "Gray" }

        # Get current cursor position
        $currPos = $host.UI.RawUI.CursorPosition

        Write-Host " $([char]0x2502)" -NoNewline -ForegroundColor "Gray"
        # Write-Host " ? " -NoNewline -ForegroundColor "Cyan"
        Write-Host "   $prompt " -NoNewline

        if ($IsSecure) { 
            $userInput = Read-Host -AsSecureString 
        } else { 
            $userInput = Read-Host 
        }

        # Check for existing user if requested
        if ($CheckExistingUser) {
            $account = Get-LocalUser -Name $userInput -ErrorAction SilentlyContinue
            if ($null -ne $account) { $ErrorMessage = "An account with that name already exists." }
        }

        if ($userInput -eq "" -or $userInput.Length -eq 0) { 
            readCommand
        } 

        # Validate user input against provided regular expression
        if ($userInput -notmatch $Validate) { 
            $ErrorMessage = "Invalid input. Please try again." 
        } 

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
        
        Write-Host " $([char]0x2502)" -NoNewline -ForegroundColor "Gray"
        # Write-Host " ? " -ForegroundColor "Cyan" -NoNewline
        if ($IsSecure -and ($userInput.Length -eq 0)) { 
            Write-Host "   $prompt                                                "
        } else { 
            Write-Host "   $prompt " -NoNewline
            Write-Host "$userInput                                             " -ForegroundColor "DarkCyan"
        }

        # Add a new line after prompt if specified
        if ($lineAfter) { Write-Host " $([char]0x2502)" -ForegroundColor "Gray" }
    
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
        [string]$prompt, # Provide a specific prompt if necessary
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
        if ($lineBefore) { Write-Host " $([char]0x2502)" -ForegroundColor "Gray" }

        # Get current cursor position
        # $promptPos = $host.UI.RawUI.CursorPosition

        Write-Host " $([char]0x251C)" -NoNewline -ForegroundColor "Gray"
        # Write-Host " ? " -NoNewline -ForegroundColor "Cyan"
        Write-Host " $prompt " -ForegroundColor "Gray"

        # Initialize variables for user input handling
        $vkeycode = 0
        $pos = 0
        $oldPos = 0

        # Get a list of keys from the options dictionary
        $orderedKeys = $options.Keys | ForEach-Object { $_ }

        # Get an array of all values
        # $values = $options.Values

        # Find the length of the longest key for padding
        $longestKeyLength = ($orderedKeys | ForEach-Object { "$_".Length } | Measure-Object -Maximum).Maximum

        # Find the length of the longest value
        # $longestValueLength = ($values | ForEach-Object { "$_".Length } | Measure-Object -Maximum).Maximum

        # Display single option if only one exists
        if ($orderedKeys.Count -eq 1) {
            Write-Host " $([char]0x2502)" -NoNewline -ForegroundColor "Gray"
            Write-Host " $([char]0x2192)" -ForegroundColor "DarkCyan" -NoNewline
            Write-Host "   $($orderedKeys) $(" " * ($longestKeyLength - $orderedKeys.Length)) - $($options[$orderedKeys])" -ForegroundColor "DarkCyan"
        } else {
            # Loop through each option and display with padding and color
            for ($i = 0; $i -lt $orderedKeys.Count; $i++) {
                $key = $orderedKeys[$i]
                $padding = " " * ($longestKeyLength - $key.Length)
                if ($i -eq $pos) { 
                    Write-Host " $([char]0x2502)" -NoNewline -ForegroundColor "Gray"
                    Write-Host " $([char]0x2192)" -ForegroundColor "DarkCyan" -NoNewline  
                    Write-Host " $key $padding - $($options[$key])" -ForegroundColor "DarkCyan"
                } else { 
                    Write-Host " $([char]0x2502)" -NoNewline -ForegroundColor "Gray"
                    Write-Host "   $key $padding - $($options[$key])"
                }
            }
        }

        # Get the current cursor position
        $currPos = $host.UI.RawUI.CursorPosition

        # Loop for user input to select an option
        While ($vkeycode -ne 13) {
            $press = $host.ui.rawui.readkey("NoEcho, IncludeKeyDown")
            $vkeycode = $press.virtualkeycode
            if ($orderedKeys.Count -ne 1) { 
                $oldPos = $pos;
                if ($vkeycode -eq 38) { $pos-- }
                if ($vkeycode -eq 40) { $pos++ }
                if ($pos -lt 0) { $pos = 0 }
                if ($pos -ge $orderedKeys.Count) { $pos = $orderedKeys.Count - 1 }

                # Calculate positions for redrawing menu items
                $menuLen = $orderedKeys.Count
                $menuOldPos = New-Object System.Management.Automation.Host.Coordinates($currPos.X, ($currPos.Y - ($menuLen - $oldPos)))
                $menuNewPos = New-Object System.Management.Automation.Host.Coordinates($currPos.X, ($currPos.Y - ($menuLen - $pos)))
                $oldKey = $orderedKeys[$oldPos]
                $newKey = $orderedKeys[$pos]
            
                # Re-draw the previously selected and newly selected options
                $host.UI.RawUI.CursorPosition = $menuOldPos
                Write-Host " $([char]0x2502)" -NoNewline -ForegroundColor "Gray"
                Write-Host "   $($orderedKeys[$oldPos]) $(" " * ($longestKeyLength - $oldKey.Length)) - $($options[$orderedKeys[$oldPos]])"
                $host.UI.RawUI.CursorPosition = $menuNewPos
                Write-Host " $([char]0x2502)" -NoNewline -ForegroundColor "Gray"
                Write-Host " $([char]0x2192)" -ForegroundColor "DarkCyan" -NoNewline
                Write-Host " $($orderedKeys[$pos]) $(" " * ($longestKeyLength - $newKey.Length)) - $($options[$orderedKeys[$pos]])" -ForegroundColor "DarkCyan"
                $host.UI.RawUI.CursorPosition = $currPos
            }
        }

        <# # Clear the menu by overwriting it with spaces
        $menuLines = $options.Count
        $newY = $promptPos.Y + 1 # Calculate the new Y position
        for ($i = 0; $i -lt $menuLines; $i++) {
            # Ensure the Y position is within the terminal bounds
            if ($newY -ge 0 -and $newY -lt $host.UI.RawUI.WindowSize.Height) {
                $host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates($promptPos.X, $newY)
                Write-Host (" " * ($host.UI.RawUI.WindowSize.Width - 1)) # Clear each line with spaces
            }
            $newY++ # Move to the next line
        }

        # Move the cursor back to the prompt position
        if ($promptPos.Y -ge 0 -and $promptPos.Y -lt $host.UI.RawUI.WindowSize.Height) {
            $host.UI.RawUI.CursorPosition = $promptPos
        }

        # Display the selected option on the same line as the prompt
        Write-Host "? " -NoNewline -ForegroundColor "Green"
        Write-Host "$prompt " -NoNewline
        Write-Host "$($orderedKeys[$pos])" -ForegroundColor "DarkCyan" #>

        # Add a line break after the menu if lineAfter is specified
        if ($lineAfter) { Write-Host " $([char]0x2502)" -ForegroundColor "Gray" }

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
        [parameter(Mandatory)]
        [string]$url,
        [parameter(Mandatory)]
        [string]$target,
        [parameter(Mandatory = $false)]
        [string]$label = "",
        [parameter(Mandatory = $false)]
        [string]$failText = 'Download failed...',
        [parameter(Mandatory = $false)]
        [switch]$lineBefore = $false,
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false,
        [parameter(Mandatory = $false)]
        [switch]$hide = $false
    )
    Begin {
        <# Write-Host "  From: " -NoNewline
        Write-Host "$url" -ForegroundColor Magenta
        Write-Host "  To: " -NoNewline
        Write-Host "$target" -ForegroundColor Magenta #>
        
        function Show-Progress {
            param (
                [parameter(Mandatory)]
                [Single]$totalValue,
                [parameter(Mandatory)]
                [Single]$currentValue,
                [parameter(Mandatory = $false)]
                [switch]$complete = $false
            )
            
            # calc %
            $barSize = 30
            $percent = $currentValue / $totalValue
            $percentComplete = $percent * 100
  
            # build progressbar with string function
            $curBarSize = $barSize * $percent
            $progbar = ""
            $progbar = $progbar.PadRight($curBarSize, [char]9608)
            $progbar = $progbar.PadRight($barSize, [char]9617)

            if ($complete) {
                Write-Host -NoNewLine "`r  $progbar Complete"
            } else {
                Write-Host -NoNewLine "`r  $progbar $($percentComplete.ToString("##0.00").PadLeft(6))%"
            }          
        }
    }
    Process {
        $downloadComplete = $true 
        for ($retryCount = 1; $retryCount -le 2; $retryCount++) {
            try {
                $storeEAP = $ErrorActionPreference
                $ErrorActionPreference = 'Stop'
        
                # invoke request
                $request = [System.Net.HttpWebRequest]::Create($url)
                $response = $request.GetResponse()
  
                if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403 -or $response.StatusCode -eq 404) {
                    throw "Remote file either doesn't exist, is unauthorized, or is forbidden for '$url'."
                }
  
                if ($target -match '^\.\\') {
                    $target = Join-Path (Get-Location -PSProvider "FileSystem") ($target -Split '^\.')[1]
                }
            
                if ($target -and !(Split-Path $target)) {
                    $target = Join-Path (Get-Location -PSProvider "FileSystem") $target
                }

                if ($target) {
                    $fileDirectory = $([System.IO.Path]::GetDirectoryName($target))
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
                $writer = new-object System.IO.FileStream $target, "Create"
                
                if ($lineBefore) { Write-Host }

                if (-not $hide -and $label -ne "") {
                    Write-Host  "  $label" -ForegroundColor "Yellow"
                }
                # start download
                $finalBarCount = 0 #Show final bar only one time
                do {
                    $count = $reader.Read($buffer, 0, $buffer.Length)
          
                    $writer.Write($buffer, 0, $count)
              
                    $total += $count
                    $totalMB = $total / 1024 / 1024
                    if (-not $hide) {
                        if ($fullSize -gt 0) {
                            Show-Progress -totalValue $fullSizeMB -currentValue $totalMB
                        }

                        if ($total -eq $fullSize -and $count -eq 0 -and $finalBarCount -eq 0) {
                            Show-Progress -totalValue $fullSizeMB -currentValue $totalMB -complete
                            $finalBarCount++
                        }
                    }
                } while ($count -gt 0)

                if (-not $hide) {
                    Write-Host
                }

                # Prevent the following output from appearing on the same line as the progress bar
                if ($lineAfter) { 
                    Write-Host
                }
                
                if ($downloadComplete) { 
                    return $true 
                } else { 
                    return $false 
                }
            } catch {
                $downloadComplete = $false
            
                if ($retryCount -lt 2) {
                    writeText -type "plain" -text "Retrying..."
                    Start-Sleep -Seconds 1
                } else {
                    writeText -type "error" -text "getDownload-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
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
        [string]$prompt = "Select a user account.",
        [parameter(Mandatory = $false)]
        [switch]$lineBefore = $false,
        [parameter(Mandatory = $false)]
        [switch]$lineAfter = $false,
        [parameter(Mandatory = $false)]
        [switch]$writeResult = $false
    )

    try {
        # Add a line break before the menu if lineBefore is specified
        if ($lineBefore) { Write-Host " $([char]0x2502)" -ForegroundColor "Gray" }
         
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
        if ($lineAfter) { Write-Host " $([char]0x2502)" -ForegroundColor "Gray" }

        # Return the user data dictionary
        return $data
    } catch {
        writeText -type "error" -text "selectUser-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}