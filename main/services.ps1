function listServices {
    $orderedServices = [ordered]@{}
    Get-Service | ForEach-Object { 
        $orderedServices[$_.Name] = $_.Status  # Store only the status
    }
    writeText -type "table" -table $orderedServices
}

<# function allServicesMenu {
    $orderedServices = [ordered]@{}
    Get-Service | ForEach-Object { 
        $orderedServices[$_.Name] = $_.Status  # Store only the status
    }
    
    $choice = readOption -options $orderedServices -prompt "Select a service." -returnKey
    
    actionMenu -serviceName $choice
} #>

function serviceMenu {
    $choice = readOption -options $([ordered]@{
            "Start"   = "Start-Service"
            "Stop"    = "Stop-Service"
            "Restart" = "Restart-Service"
            "Status"  = "Get-Service"
        }) -prompt "Select an action for the service." -lineAfter -returnKey

    if ($choice) {
        try {
            $serviceName = readInput -prompt "Enter the name of the service:"
            
            # Check if the service exists
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            
            if ($null -eq $service) {
                writeText -type "notice" -text "Service '$serviceName' does not exist. Please check the service name and try again."
                readCommand
            }
            
            writeText -type "notice" -text "$choice action executed on service '$serviceName'."
            
            switch ($choice) {
                "Start" { startService -serviceName $serviceName }
                "Stop" { stopService -serviceName $serviceName }
                "Restart" { restartService -serviceName $serviceName }
                "Status" { getServiceStatus -serviceName $serviceName }
            }
        } catch {
            writeText -type "error" -text "$($MyInvocation.MyCommand.Name): $($_.InvocationInfo.ScriptLineNumber)-$($_.Exception.Message)"
        }
    }
}

function stopService {
    param (
        [Parameter(Mandatory = $false)]
        [string]$serviceName
    )

    try {
        if ($null -eq $serviceName -or $serviceName.Trim() -eq "") {
            $serviceName = readInput -prompt "Enter the name of the service to stop:"
        }

        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            writeText -type "notice" -text "Service '$serviceName' does not exist. Please check the service name and try again."
            readCommand
        }

        Stop-Service -Name $serviceName -Force

        Start-Sleep 3  # Wait for a moment to allow the service to start

        getServiceStatus -serviceName $serviceName
    } catch {
        # writeText -type "error" -text "$($MyInvocation.MyCommand.Name): $($_.InvocationInfo.ScriptLineNumber)"
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name): $($_.InvocationInfo.ScriptLineNumber)-$($_.Exception.Message)"
    }
}

function startService {
    param (
        [Parameter(Mandatory = $false)]
        [string]$serviceName
    )

    try {
        if ($null -eq $serviceName -or $serviceName.Trim() -eq "") {
            $serviceName = readInput -prompt "Enter the name of the service to start:"
        }

        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            writeText -type "notice" -text "Service '$serviceName' does not exist. Please check the service name and try again."
            readCommand
        }

        Start-Service -Name $serviceName

        Start-Sleep 3  # Wait for a moment to allow the service to start

        getServiceStatus -serviceName $serviceName
    } catch {
        # writeText -type "error" -text "$($MyInvocation.MyCommand.Name): $($_.InvocationInfo.ScriptLineNumber)"
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name): $($_.InvocationInfo.ScriptLineNumber)-$($_.Exception.Message)"
    }
}

function restartService {
    param (
        [Parameter(Mandatory = $false)]
        [string]$serviceName
    )

    try {
        if ($null -eq $serviceName -or $serviceName.Trim() -eq "") {
            $serviceName = readInput -prompt "Enter the name of the service to restart:"
        }

        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            writeText -type "notice" -text "Service '$serviceName' does not exist. Please check the service name and try again."
            readCommand
        }

        Restart-Service -Name $serviceName -Force

        Start-Sleep 3  # Wait for a moment to allow the service to start

        getServiceStatus -serviceName $serviceName
    } catch {
        # writeText -type "error" -text "$($MyInvocation.MyCommand.Name): $($_.InvocationInfo.ScriptLineNumber)"
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name): $($_.InvocationInfo.ScriptLineNumber)-$($_.Exception.Message)"
    }
}

function getServiceExecutable {
    <#
        The program a service runs, taken from the command line stored for it
        (Win32_Service.PathName): the quoted path, or an unquoted one up to .exe.
        Returns $null if there is none or it cannot be read.
    #>
    param (
        [Parameter(Mandatory = $false)]
        [string]$commandLine
    )

    if ([string]::IsNullOrWhiteSpace($commandLine)) { return $null }

    $text = [Environment]::ExpandEnvironmentVariables($commandLine.Trim())

    if ($text.StartsWith('"')) {
        $end = $text.IndexOf('"', 1)
        if ($end -le 1) { return $null }
        $path = $text.Substring(1, $end - 1)
    } elseif ($text -match '^(.+?\.exe)(\s|$)') {
        $path = $Matches[1]
    } else {
        $path = ($text -split '\s+')[0]
    }

    # Forms Windows accepts for the same file: \\?\C:\... , \??\C:\... and \SystemRoot\...
    if ($path.StartsWith('\\?\') -or $path.StartsWith('\??\')) { $path = $path.Substring(4) }
    if ($path.StartsWith('\SystemRoot\', [System.StringComparison]::OrdinalIgnoreCase)) {
        $path = [Environment]::GetFolderPath("Windows") + $path.Substring(11)
    }

    return $path
}

function findService {
    <#
        The Win32_Service with exactly this name, or $null. Exact: unlike Get-Service -Name
        there are no wildcards. (In a WQL string a backslash and a single quote are escaped
        with a backslash.)
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$name
    )

    $escaped = $name -replace '\\', '\\' -replace "'", "\'"
    return (Get-CimInstance -ClassName Win32_Service -Filter "Name='$escaped'" -ErrorAction Stop | Select-Object -First 1)
}

function getServiceController {
    <#
        The ServiceController for exactly this name. Get-Service -Name treats * ? [ ] and the
        backtick as wildcard syntax, which could find a different service or none at all.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$name
    )

    Add-Type -AssemblyName System.ServiceProcess
    return (New-Object System.ServiceProcess.ServiceController($name))
}

function getRunningDependentNames {
    <# Names of the services that depend on this one and are not stopped. #>
    param (
        [Parameter(Mandatory = $true)]
        $controller
    )

    $running = @(@($controller.DependentServices) | Where-Object { $_ -and "$($_.Status)" -ne "Stopped" })
    return @($running | ForEach-Object { $_.Name })
}

function deleteService {
    param (
        [Parameter(Mandatory = $false)]
        [string]$serviceName
    )

    $stopped = $false

    try {
        if ($null -eq $serviceName -or $serviceName.Trim() -eq "") {
            $serviceName = readInput -prompt "Enter the name of the service to delete:"
        }

        # readInput has already said why when nothing was typed.
        if ($null -eq $serviceName) { return }

        $serviceName = $serviceName.Trim()
        if ($serviceName -eq "") {
            writeText -type "notice" -text "No service name was given."
            return
        }

        # Exact name only: a wildcard must never choose which service gets deleted.
        $service = findService -name $serviceName

        if ($null -eq $service) {
            writeText -type "notice" -text "Service '$serviceName' does not exist. Use the service name (see 'services'), not its display name."
            return
        }

        $name = $service.Name

        # --- Guards: refuse before asking anything ---

        # Services that belong to Windows run from the Windows folder (svchost.exe and friends).
        # Deleting one can leave Windows unable to start, and there is no undo.
        $executable = getServiceExecutable -commandLine $service.PathName
        if ($executable) {
            # Resolve .. and . so a path cannot hide that it is inside the Windows folder.
            try { $executable = [System.IO.Path]::GetFullPath($executable) } catch { }
        }
        $windowsDirectory = [Environment]::GetFolderPath("Windows")
        if ($executable -and $executable.StartsWith($windowsDirectory + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
            writeText -type "error" -text "$name is part of Windows ($executable). Deleting it can stop Windows from working, so ShellCLI will not do it."
            return
        }

        # A service other services need: do not pull it out from under ones that are running.
        $controller = getServiceController -name $name
        $runningDependents = @(getRunningDependentNames -controller $controller)
        if ($runningDependents.Count -gt 0) {
            writeText -type "error" -text "$name is needed by running services: $($runningDependents -join ', ')"
            writeText -type "plain" -text "Stop or delete those first."
            return
        }

        # --- Say exactly what will happen, and make the user type the name ---

        $dependents = @(@($controller.DependentServices) | Where-Object { $_ })

        writeText -type "notice" -text "This permanently deletes the service $name ($($service.DisplayName))."
        writeText -type "plain" -text "  Runs:    $($service.PathName)"
        writeText -type "plain" -text "  Account: $($service.StartName)"
        if (-not $executable) {
            writeText -type "plain" -text "  ShellCLI could not tell which program this service runs, so it cannot check whether it belongs to Windows."
        }
        if ($service.State -ne "Stopped") {
            writeText -type "plain" -text "  It is $($service.State) and will be stopped first."
        }
        if ($dependents.Count -gt 0) {
            writeText -type "plain" -text "  These stopped services depend on it and will no longer start: $(($dependents | ForEach-Object { $_.Name }) -join ', ')"
        }
        writeText -type "plain" -text "  The program's files are not deleted."

        $typed = readInput -prompt "Type the service name to confirm:" -allowBlank
        if ($null -eq $typed -or "$typed".Trim() -ne $name) {
            writeText -type "notice" -text "That is not the service name. Nothing was deleted."
            return
        }

        # Things can change while the name is being typed: look again before acting.
        $service = findService -name $name
        if ($null -eq $service) {
            writeText -type "notice" -text "Service '$name' no longer exists."
            return
        }
        $controller = getServiceController -name $name
        $runningDependents = @(getRunningDependentNames -controller $controller)
        if ($runningDependents.Count -gt 0) {
            writeText -type "error" -text "$name is now needed by running services: $($runningDependents -join ', ')"
            writeText -type "plain" -text "Stop or delete those first. Nothing was deleted."
            return
        }

        # Written to the log so there is a record of what was deleted.
        log -msg "Deleting service $name ($($service.DisplayName)). Path: $($service.PathName). Account: $($service.StartName). Start mode: $($service.StartMode). State: $($service.State)."

        # --- Stop it, then delete it ---

        if ($service.State -ne "Stopped") {
            writeText -type "plain" -text "Stopping $name..."
            try {
                if ($service.State -ne "Stop Pending") { $controller.Stop() }
                $controller.WaitForStatus("Stopped", (New-TimeSpan -Seconds 30))
                $stopped = $true
            } catch {
                # The useful reason is the innermost exception.
                $inner = $_.Exception
                while ($inner.InnerException) { $inner = $inner.InnerException }

                if ($inner.GetType().Name -eq "TimeoutException") {
                    writeText -type "error" -text "$name did not stop within 30 seconds, so it was not deleted. It may still be stopping; check it with 'service status'."
                } else {
                    writeText -type "error" -text "Could not stop $name, so it was not deleted: $($inner.Message)"
                }
                return
            }

            # Stopping can finish the job: a service already marked for deletion goes away once it stops.
            $service = findService -name $name
            if ($null -eq $service) {
                writeText -type "success" -text "Service '$name' was deleted (it was removed as soon as it stopped)."
                return
            }
        }

        try {
            $result = Invoke-CimMethod -InputObject $service -MethodName Delete -ErrorAction Stop
        } catch {
            # If it vanished in the meantime the goal is reached; otherwise this is a real failure.
            $checked = $false
            $remaining = $null
            try { $remaining = findService -name $name; $checked = $true } catch { }
            if ($checked -and $null -eq $remaining) {
                writeText -type "success" -text "Service '$name' was deleted."
                return
            }
            throw
        }

        if ($result.ReturnValue -ne 0) {
            $reasons = @{
                1  = "This service cannot be deleted."
                2  = "Access is denied. The service's own security settings do not allow it to be deleted, even by an administrator."
                3  = "Services that depend on it are still running."
                8  = "Windows reported an unknown failure."
                11 = "The service database is locked. Try again in a moment."
                16 = "It is already marked for deletion. It disappears once nothing has it open, or after a restart."
            }
            $reason = $reasons[[int]$result.ReturnValue]
            if (-not $reason) { $reason = "Windows returned code $($result.ReturnValue)." }

            writeText -type "error" -text "Could not delete ${name}: $reason"
            # A service marked for deletion cannot be started again, so only offer that otherwise.
            if ($stopped -and $result.ReturnValue -ne 16) {
                writeText -type "plain" -text "It was stopped first and is still stopped. Start it again with 'start service'."
            }
            return
        }

        # A service something still has open is only marked for deletion, and stays listed until that is released.
        try {
            $stillThere = findService -name $name
        } catch {
            writeText -type "notice" -text "The delete was accepted, but ShellCLI could not confirm the result: $($_.Exception.Message)"
            return
        }

        if ($null -eq $stillThere) {
            writeText -type "success" -text "Service '$name' was deleted."
        } else {
            writeText -type "notice" -text "Service '$name' is marked for deletion. It disappears once nothing has it open, or after a restart."
        }
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name): $($_.InvocationInfo.ScriptLineNumber)-$($_.Exception.Message)"
        if ($stopped) { writeText -type "plain" -text "The service had been stopped and is still stopped. Start it again with 'start service'." }
    }
}

function getServiceStatus {
    param (
        [Parameter(Mandatory = $false)]
        [string]$serviceName
    )

    try {
        if ($null -eq $serviceName -or $serviceName.Trim() -eq "") {
            $serviceName = readInput -prompt "Enter the name of the service to check status for:"
        }

        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            writeText -type "notice" -text "Service '$serviceName' does not exist. Please check the service name and try again."
            readCommand
        }
            
        writeText -type "plain" -text "Service '$serviceName' is: $($service.Status)"
    } catch {
        # writeText -type "error" -text "$($MyInvocation.MyCommand.Name): $($_.InvocationInfo.ScriptLineNumber)"
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name): $($_.InvocationInfo.ScriptLineNumber)-$($_.Exception.Message)"
    }
}
