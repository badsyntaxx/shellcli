function init {
    try {
        # Check if user has administrator privileges
        if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
            # If not, elevate privileges and restart function with current arguments
            Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
            Exit
<<<<<<< HEAD
=======
        } 

        # Customize console appearance
        $console = $host.UI.RawUI
        $console.BackgroundColor = "Black"
        $console.ForegroundColor = "Gray"
        $console.WindowTitle = "CHASED Scripts"
        Clear-Host
        Write-Host

        # Display a stylized menu prompt
        Write-Host " Chased Scripts: Root"
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
>>>>>>> 4037059d0a08a29ceab227fd5f522c9a2e2f7d03
        }
        
        # Create the main script file
        New-Item -Path "$env:TEMP\CHASED-Script.ps1" -ItemType File -Force | Out-Null

        # add-script -subPath $subPath -script $fileFunc -ProgressText "Loading script..."
        add-script -subpath "core" -script "framework" -ProgressText "Loading framework..."

        # Add a final line that will invoke the desired function
        Add-Content -Path "$env:TEMP\CHASED-Script.ps1" -Value "invoke-script 'get-cscommand'"

        # Execute the combined script
        $chasedScript = Get-Content -Path "$env:TEMP\CHASED-Script.ps1" -Raw
        Invoke-Expression "$chasedScript"
    } catch {
        # Error handling: display an error message and prompt for a new command
        Write-Host "    Could not initialize: $($_.Exception.Message) | init-$($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
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
    $download = get-script -Url "$url/$subPath/$script.ps1" -Target "$env:TEMP\$script.ps1"
    if (!$download) { throw "Could not acquire dependency. ($url/$subPath/$script.ps1)" }

    # Append the script to the main script
    $rawScript = Get-Content -Path "$env:TEMP\$script.ps1" -Raw -ErrorAction SilentlyContinue
    Add-Content -Path "$env:TEMP\CHASED-Script.ps1" -Value $rawScript

    # Remove the script file
    Get-Item -ErrorAction SilentlyContinue "$env:TEMP\$script.ps1" | Remove-Item -ErrorAction SilentlyContinue
}

function get-script {
    param (
        [Parameter(Mandatory)]
        [string] $Url,
        [Parameter(Mandatory)]
        [string] $Target
    )
  
    Process {
        $downloadComplete = $true 
        try {
            # Create web request and get response
            $request = [System.Net.HttpWebRequest]::Create($Url)
            $response = $request.GetResponse()
  
            # Check for unauthorized or non-existent file
            if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403 -or $response.StatusCode -eq 404) {
                throw "Remote file error: $($response.StatusCode) - '$Url'"
            }
  
            # Handle relative target path
            if ($Target -match '^\.\\') { 
                $Target = Join-Path (Get-Location) ($Target -Split '^\.')[1] 
            }
  
            # Open streams for reading and writing
            $reader = $response.GetResponseStream()
            $writer = New-Object System.IO.FileStream $Target, "Create"
            $buffer = new-object byte[] 1048576
  
            # Read data in chunks and write to target file
            do {
                $count = $reader.Read($buffer, 0, $buffer.Length)
                $writer.Write($buffer, 0, $count)
            } while ($count -gt 0)
  
            # Close streams silently (assuming success)
            if ($downloadComplete) { return $true } else { return $false }
        } catch {
            return $false
        } finally {
            $reader.Close()
            $writer.Close()
        }
    }
}
  

# Invoke the root of CHASED scripts
init