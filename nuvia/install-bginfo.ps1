function install-bginfo {
    try {
        write-welcome -Title "Install BGInfo" -Description "Install BGInfo with various DSO flavor profiles." -Command "intech intall bginfo"
        
        # Check if the current PowerShell session is running as the system account
        if ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -eq 'NT AUTHORITY\SYSTEM') {
            write-text -Type "notice" -Text "RUNNING AS SYSTEM: Changes wont apply until reboot. Run as logged user for instant results." -LineBefore
        }

        $url = "https://drive.google.com/uc?export=download&id=18gFWHawWknKufHXjcmMUB0SwGoSlbBEk" 
        $target = "Nuvia" 

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

        exit-script -Type "success" -Text "BGInfo installed and applied." -LineBefore -LineAfter
    } catch {
        # Display error message and end the script
        exit-script -Type "error" -Text "Error | Install-Bginfo-$($_.InvocationInfo.ScriptLineNumber)"
    }
}