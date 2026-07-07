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