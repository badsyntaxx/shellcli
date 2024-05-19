function invoke-script {
    param (
        [parameter(Mandatory = $true)]
        [string]$ScriptName
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
        $console.WindowTitle = "CHASED Scripts"
        Clear-Host
        Write-Host

        # Display a stylized menu prompt
        Write-Host " CHASED|Scripts: Root"
        Write-Host " Enter `"" -ForegroundColor DarkGray -NoNewLine
        Write-Host "menu" -ForegroundColor Cyan -NoNewLine
        Write-Host "`" if you don't know commands." -ForegroundColor DarkGray
        Write-Host

        # Call the script specified by the parameter
        Invoke-Expression $ScriptName
    } catch {
        # Error handling: display error message and give an opportunity to run another command
        Write-Host "Initialization Error: $($_.Exception.Message)" -ForegroundColor Red
        get-cscommand
    }
}

function get-cscommand {
    param (
        [Parameter(Mandatory = $false)]
        [string]$command = ""
    )

    try {
        # Right carrot icon, this is a prompt for a command in CHASED Scripts
        Write-Host "  $([char]0x203A) " -NoNewline 

        # Get the command from the user
        if ($command -eq "") { $command = Read-Host }
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

        add-script -subPath $subPath -script $fileFunc -ProgressText "Loading script..."
        add-script -subpath "core" -script "framework" -ProgressText "Loading framework..."

        # Add a final line that will invoke the desired function
        Add-Content -Path "$env:TEMP\CHASED-Script.ps1" -Value "invoke-script '$fileFunc'"

        # Execute the combined script
        $chasedScript = Get-Content -Path "$env:TEMP\CHASED-Script.ps1" -Raw
        Invoke-Expression "$chasedScript"
    } catch {
        # Error handling: display an error message and prompt for a new command
        Write-Host "    Unknown command: $($_.Exception.Message) | init-$($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
        get-cscommand
    }
}

function add-script {
    param (
        [Parameter(Mandatory)]
        [string]$subPath,
        [Parameter(Mandatory)]
        [string]$script,
        [Parameter(Mandatory)]
        [string]$progressText
    )

    $url = "https://raw.githubusercontent.com/badsyntaxx/chased-scripts/main"

    # Download the script
    $download = get-script -Url "$url/$subPath/$script.ps1" -Target "$env:TEMP\$script.ps1" -progressText $progressText
    if (!$download) { throw "Could not acquire dependency." }

    # Append the script to the main script
    $rawScript = Get-Content -Path "$env:TEMP\$script.ps1" -Raw -ErrorAction SilentlyContinue
    Add-Content -Path "$env:TEMP\CHASED-Script.ps1" -Value $rawScript

    # Remove the script file
    Get-Item -ErrorAction SilentlyContinue "$env:TEMP\$script.ps1" | Remove-Item -ErrorAction SilentlyContinue
}

function get-script {
    param (
        [Parameter(Mandatory)]
        [string]$Url,
        [Parameter(Mandatory)]
        [string]$Target,
        [Parameter(Mandatory)]
        [string]$ProgressText
    )

    # Define a nested function for displaying download progress
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
                [int]$BarSize = 40,
                [Parameter()]
                [switch]$Complete
            )
            
            # Calculate percentage completion
            $percent = $CurrentValue / $TotalValue
            $percentComplete = $percent * 100
  
            # Calculate progress bar size based on percentage
            $curBarSize = $BarSize * $percent

            # Build the progress bar using block characters
            $progbar = ""
            $progbar = $progbar.PadRight($curBarSize, [char]9608) # dark shade block
            $progbar = $progbar.PadRight($BarSize, [char]9617) # light shade block

            # Display progress details with optional completion marker
            if (!$Complete.IsPresent) {
                Write-Host -NoNewLine "`r    $ProgressText $progbar $($percentComplete.ToString("##0.00").PadLeft(6))%"
            } else {
                Write-Host -NoNewLine "`r    $ProgressText $progbar $($percentComplete.ToString("##0.00").PadLeft(6))%"                    
            }              
             
        }
    }
    Process {
        $downloadComplete = $true # Flag to track successful download
        try {
            # Temporarily change error action preference to stop on errors
            $storeEAP = $ErrorActionPreference
            $ErrorActionPreference = 'Stop'

            # Create a web request object for the specified URL
            $request = [System.Net.HttpWebRequest]::Create($Url)

            # Get the response from the web request
            $response = $request.GetResponse()

            # Check for unauthorized or non-existent remote file
            if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403 -or $response.StatusCode -eq 404) {
                throw "Remote file either doesn't exist, is unauthorized, or is forbidden for '$Url'."
            }

            # Handle relative target path based on current location
            if ($Target -match '^\.\\') { $Target = Join-Path (Get-Location -PSProvider "FileSystem") ($Target -Split '^\.')[1] }

            # Resolve full target path if necessary
            if ($Target -and !(Split-Path $Target)) { $Target = Join-Path (Get-Location -PSProvider "FileSystem") $Target }

            # Create target directory if it doesn't exist. Should never have to do this, CHASED scripts always targets %temp%
            if ($Target) {
                $fileDirectory = $([System.IO.Path]::GetDirectoryName($Target))
                if (!(Test-Path($fileDirectory))) { [System.IO.Directory]::CreateDirectory($fileDirectory) | Out-Null }
            }

            # Get file size from response
            [long]$fullSize = $response.ContentLength
            $fullSizeMB = $fullSize / 1024 / 1024

            # Create a buffer for reading data
            [byte[]]$buffer = new-object byte[] 1048576

            # Variables to track download progress
            [long]$total = [long]$count = 0
            $reader = $response.GetResponseStream()
            $writer = new-object System.IO.FileStream $Target, "Create"
            $finalBarCount = 0 # Flag to show final progress bar only once

            # Read data from the response stream in chunks
            do {
                $count = $reader.Read($buffer, 0, $buffer.Length)
        
                # Write the read data to the target file
                $writer.Write($buffer, 0, $count)
            
                # Update total downloaded bytes and calculate MB
                $total += $count
                $totalMB = $total / 1024 / 1024
        
                # Display download progress if file size is known
                if ($fullSize -gt 0) {
                    Show-Progress -TotalValue $fullSizeMB -CurrentValue $totalMB -ProgressText $ProgressText
                }

                # Check for completion and display final progress bar (only once)
                if ($total -eq $fullSize -and $count -eq 0 -and $finalBarCount -eq 0) {
                    Show-Progress -TotalValue $fullSizeMB -CurrentValue $totalMB -ProgressText $ProgressText -Complete
                    $finalBarCount++
                }
            } while ($count -gt 0) # Continue reading until all data is downloaded

            # Prevent the following output from appearing on the same line as the progress bar
            Write-Host 

            # Return true if download was successful, false otherwise
            if ($downloadComplete) { return $true } else { return $false }
        } catch {
            # write-text -Type "fail" -Text "$($_.Exception.Message)"
        } finally {
            # Close streams and restore error action preference
            if ($reader) { $reader.Close() }
            if ($writer) { $writer.Flush(); $writer.Close() }
            $ErrorActionPreference = $storeEAP
            [GC]::Collect()
        } 
           
    }
}

# Invoke the root of CHASED scripts
invoke-script -script "get-cscommand"