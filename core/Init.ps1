function initializeShellCLI {
    try {
        # Check if user has administrator privileges
        if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
            Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
            Exit
        }
        
        # Create the main script file
        New-Item -Path "$env:SystemRoot\Temp\SHELLCLI.ps1" -ItemType File -Force | Out-Null

        $url = "https://raw.githubusercontent.com/badsyntaxx/shellcli/main"

        # Download the framework script
        $download = getScript -Url "$url/core/Framework.ps1" -Target "$env:SystemRoot\Temp\Framework.ps1"
        if ($download) { 
            # Append the framework to the main script
            $rawScript = Get-Content -Path "$env:SystemRoot\Temp\Framework.ps1" -Raw -ErrorAction SilentlyContinue
            Add-Content -Path "$env:SystemRoot\Temp\SHELLCLI.ps1" -Value $rawScript

            # Remove the script file
            Get-Item -ErrorAction SilentlyContinue "$env:SystemRoot\Temp\Framework.ps1" | Remove-Item -ErrorAction SilentlyContinue

            # Load commands and start shell
            Add-Content -Path "$env:SystemRoot\Temp\SHELLCLI.ps1" -Value 'Load-Commands -CommandsPath "https://raw.githubusercontent.com/badsyntaxx/shellcli/main/core/commands.json"'
            Add-Content -Path "$env:SystemRoot\Temp\SHELLCLI.ps1" -Value 'invokeScript -script "readCommand -command `"help`"" -initialize $true'

            # Execute the combined script
            $shellCLI = Get-Content -Path "$env:SystemRoot\Temp\SHELLCLI.ps1" -Raw
            Invoke-Expression $shellCLI
        }
    } catch {
        Write-Host "  initializeShellCLI-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -ForegroundColor "Red"
    }
}

# Invoke the root of Shell CLI
initializeShellCLI

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
            $request = [System.Net.HttpWebRequest]::Create($url)
            $response = $request.GetResponse()
            
            if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403 -or $response.StatusCode -eq 404) {
                throw "Remote file error: $($response.StatusCode) - '$url'"
            }
  
            if ($target -match '^\.\\') { 
                $target = Join-Path (Get-Location) ($target -Split '^\.')[1] 
            }
  
            $reader = $response.GetResponseStream()
            $writer = New-Object System.IO.FileStream $target, "Create"
            $buffer = new-object byte[] 1048576
  
            do {
                $count = $reader.Read($buffer, 0, $buffer.Length)
                $writer.Write($buffer, 0, $count)
            } while ($count -gt 0)
  
            if ($downloadComplete) { 
                return $true 
            } else { 
                return $false 
            }
        } catch {
            Write-Host $($_.Exception.Message)
            Read-Host
            return $false
        } finally {
            if ($reader) { $reader.Close() }
            if ($writer) { $writer.Close() }
        }
    }
}

# Invoke the root of Shell CLI
initializeShellCLI