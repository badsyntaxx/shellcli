function initializeChasteScripts {
    try {
        # Check if user has administrator privileges
        if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
            # If not, elevate privileges and restart function with current arguments
            Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
            Exit
        }
        
        # Create the main script file
        New-Item -Path "$env:SystemRoot\Temp\SHELLCLI.ps1" -ItemType File -Force | Out-Null

        $url = "https://raw.githubusercontent.com/badsyntaxx/shellcli/main"

        # Download the script
        $download = getScript -Url "$url/core/Framework.ps1" -Target "$env:SystemRoot\Temp\Framework.ps1"
        if ($download) { 
            # Append the script to the main script
            $rawScript = Get-Content -Path "$env:SystemRoot\Temp\Framework.ps1" -Raw -ErrorAction SilentlyContinue
            Add-Content -Path "$env:SystemRoot\Temp\SHELLCLI.ps1" -Value $rawScript

            # Remove the script file
            Get-Item -ErrorAction SilentlyContinue "$env:SystemRoot\Temp\Framework.ps1" | Remove-Item -ErrorAction SilentlyContinue

            # Add a final line that will invoke the desired function
            Add-Content -Path "$env:SystemRoot\Temp\SHELLCLI.ps1" -Value 'invokeScript -script "readCommand -command `"menu`"" -initialize $true'

            # Execute the combined script
            $shellCLI = Get-Content -Path "$env:SystemRoot\Temp\SHELLCLI.ps1" -Raw
            Invoke-Expression $shellCLI
        }
    } catch {
        Write-Host "  initializeChasteScripts-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -ForegroundColor "Red"
    }
}

function getScript {
    param (
        [Parameter(Mandatory)]
        [string]$url,
        [Parameter(Mandatory)]
        [string]$target
    )
  
    Process {
        $downloadComplete = $true 
        try {
            # Create web request and get response
            $request = [System.Net.HttpWebRequest]::Create($url)
            $response = $request.GetResponse()
            
            # Check for unauthorized or non-existent file
            if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403 -or $response.StatusCode -eq 404) {
                throw "Remote file error: $($response.StatusCode) - '$url'"
            }
  
            # Handle relative target path
            if ($target -match '^\.\\') { 
                $target = Join-Path (Get-Location) ($target -Split '^\.')[1] 
            }
  
            # Open streams for reading and writing
            $reader = $response.GetResponseStream()
            $writer = New-Object System.IO.FileStream $target, "Create"
            $buffer = new-object byte[] 1048576
  
            # Read data in chunks and write to target file
            do {
                $count = $reader.Read($buffer, 0, $buffer.Length)
                $writer.Write($buffer, 0, $count)
            } while ($count -gt 0)
  
            # Close streams silently (assuming success)
            if ($downloadComplete) { 
                return $true 
            } else { 
                return $false 
            }
        } catch {
            write-host $($_.Exception.Message)
            read-host
            return $false
        } finally {
            $reader.Close()
            $writer.Close()
        }
    }
}

# Invoke the root of CHASTE scripts
initializeChasteScripts
