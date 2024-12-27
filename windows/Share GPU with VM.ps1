function shareGPUWithVM {
    try {
        # Create a menu with options and descriptions using an ordered hashtable
        $choice = readOption -options $([ordered]@{
                "copy host gpu drivers to vm"    = "Copy the host GPU drivers to a temp folder on the VM. (RUN ON HOST WHILE VM IS RUNNING)"
                "install host gpu drivers on vm" = "Install the copied GPU drivers on the VM. (RUN ON VM)"
                "partition gpu"                  = "Partition the GPU. (RUN ON HOST WHILE VM IS OFF)"
                "Cancel"                         = "Select nothing and exit this menu."
            }) -prompt "Select a Chaste Scripts function:" -returnKey

        if ($choice -eq "Cancel") {
            readCommand
        }

        Write-Host
        Write-Host ": "  -ForegroundColor "DarkCyan" -NoNewline
        Write-Host "Running command:" -NoNewline -ForegroundColor "DarkGray"
        Write-Host " $choice" -ForegroundColor "Gray"

        readCommand -command $choice
    } catch {
        writeText -type "error" -text "readMenu-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}

function copyHostGPUDriversToVM {

    $vmName = readInput -prompt "Enter the name of the VM:"

    # Check VM status
    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if (-not $vm) {
        writeText -type "error" -text "VM 'WorkVM' not found"
        readCommand
    }
    if ($vm.State -ne 'Running') {
        writeText -type "error" -text "VM 'WorkVM' is not running (Current state: $($vm.State))"
        readCommand
    }

    # Check Integration Services
    $services = Get-VMIntegrationService -VMName $vmName
    $guestService = $services | Where-Object { $_.Name -eq "Guest Service Interface" }
    if (-not $guestService.Enabled) {
        writeText -type "notice" -text "Guest Service Interface is not enabled. Attempting to enable..."  -lineBefore
        Enable-VMIntegrationService -VMName $vmName -Name "Guest Service Interface"
        writeText -type "notice" -text "Waiting for service to initialize..." -lineAfter
        Start-Sleep -Seconds 30  # Give the service time to fully initialize
    }

    # Verify service is running
    $guestService = Get-VMIntegrationService -VMName $vmName | Where-Object { $_.Name -eq "Guest Service Interface" }
    if (-not $guestService.PrimaryOperationalStatus -eq 'OK') {
        writeText -type "error" -text "Guest Service Interface is not in OK state. Please make sure Integration Services are properly installed in the VM."
        writeText -type "notice" -text "You may need to install/update the VM Integration Services inside the VM."
        readCommand
    }

    writeText -type "plain" -text "VM and Integration Services verified. Proceeding with file copy..." -lineBefore -lineAfter

    # Find the nv_ folder and display its name
    $sourceFolder = Get-ChildItem -Path "C:\Windows\System32\DriverStore\FileRepository" -Directory | Where-Object { $_.Name -like "nv_*" } | Select-Object -First 1

    if ($sourceFolder) {
        writeText -type "notice" -text "Found driver folder: $($sourceFolder.Name)" -lineBefore
        writeText -type "plain" -text "Full path: $($sourceFolder.FullName)"
    } else {
        writeText -type "error" -text "No folder starting with 'nv_' found"
        readCommand
    }

    # Create a temporary directory in VM's C: drive
    $tempVMPath = "C:\TempDrivers"

    # Function to recursively copy directory contents
    function Copy-VMDirectory {
        param (
            [string]$VMName,
            [string]$SourcePath,
            [string]$DestinationPath
        )
    
        # Get all files in the directory and subdirectories
        $files = Get-ChildItem -Path $SourcePath -Recurse -File
    
        foreach ($file in $files) {
            # Calculate relative path from source root
            $relativePath = $file.FullName.Substring($SourcePath.Length + 1)
            $targetPath = Join-Path $DestinationPath $relativePath
        
            try {
                writeText -type "plain" -text "Copying $($file.Name)..."
                Copy-VMFile -VMName $VMName `
                    -SourcePath $file.FullName `
                    -DestinationPath $targetPath `
                    -CreateFullPath -FileSource Host
            } catch {
                writeText -type "error" -text "Failed to copy $($file.Name): $_"
            }
        }
    }

    # Copy the nv_dispi folder contents to temp location
    if ($sourceFolder) {
        writeText -type "notice" -text "Copying driver folder $($sourceFolder.Name)..."  -lineBefore
        Copy-VMDirectory -VMName $vmName `
            -SourcePath $sourceFolder.FullName `
            -DestinationPath "$tempVMPath\DriverStore\$($sourceFolder.Name)"
    }

    # Create a directory for System32 files
    $system32TempPath = "$tempVMPath\System32Files"

    # Now copy nv* files from System32 to temp location
    $sourceFiles = Get-ChildItem -Path "C:\Windows\System32" -File | Where-Object { $_.Name -like "nv*" }
    writeText -type "notice" -text "Copying nv files to System32 $($sourceFolder.Name)..." -lineBefore
    foreach ($file in $sourceFiles) {
        try {
            writeText -type "plain" -text "Copying $($file.Name)..."
            Copy-VMFile -VMName $vmName `
                -SourcePath $file.FullName `
                -DestinationPath "$system32TempPath\$($file.Name)" `
                -CreateFullPath -FileSource Host
        } catch {
            writeText -type "error" -text "Failed to copy $($file.Name): $_"
        }
    }

    writeText -type "success" -text "Files copied to the VM at $tempVMPath. Now run the 'install host gpu drivers on vm' command on the VM."

    readCommand
}

function installHostGPUDriversOnVM {
    # Create a temporary directory in VM's C: drive
    $tempVMPath = "C:\TempDrivers"

    # Create a directory for System32 files
    $system32TempPath = "$tempVMPath\System32Files"

    writeText -type "notice" -text "Installing GPU drivers on VM..." -lineBefore

    # Create HostDriverStore directory if it doesn't exist
    New-Item -Path "C:\Windows\System32\HostDriverStore\FileRepository" -ItemType Directory -Force

    # Move driver store files - copying the entire folder structure
    $sourceDriverFolder = Get-ChildItem -Path "C:\TempDrivers\DriverStore" -Directory | Select-Object -First 1
    if ($sourceDriverFolder) {
        Copy-Item -Path $sourceDriverFolder.FullName -Destination "C:\Windows\System32\HostDriverStore\FileRepository" -Recurse -Force
        writeText -type "plain" -text "Copied driver folder to HostDriverStore"
    }

    writeText -type "notice" -text "Copying nv* files to System32..." -lineBefore

    # Move System32 files
    $sourceSystem32 = "$system32TempPath\*"
    $destSystem32 = "C:\Windows\System32"
    Copy-Item -Path $sourceSystem32 -Destination $destSystem32 -Force

    # Clean up temp directory
    Remove-Item -Path "C:\TempDrivers" -Recurse -Force

    writeText -type "success" -text "Host GPU drivers installed on VM. You should shutdown the VM and run the 'partition gpu' command on the host."
}

function partitionGPU {
    $vm = readInput -prompt "Enter VM name:" # "WorkVM"
    
    writeText -type "plain" -text "Adding GPU Partition Adapter to VM '$vm'..."
    Add-VMGpuPartitionAdapter -VMName $vm
    writeText -type "plain" -text "Setting GPU Partition Adapter values..."
    Set-VMGpuPartitionAdapter -VMName $vm -MinPartitionVRAM 80000000 -MaxPartitionVRAM 100000000 -OptimalPartitionVRAM 100000000 -MinPartitionEncode 80000000 -MaxPartitionEncode 100000000 -OptimalPartitionEncode 100000000 -MinPartitionDecode 80000000 -MaxPartitionDecode 100000000 -OptimalPartitionDecode 100000000 -MinPartitionCompute 80000000 -MaxPartitionCompute 100000000 -OptimalPartitionCompute 100000000
    
    writeText -type "plain" -text "Setting VM values..."
    Set-VM -GuestControlledCacheTypes $true -VMName $vm
    Set-VM -LowMemoryMappedIoSpace 1Gb -VMName $vm
    Set-VM -HighMemoryMappedIoSpace 32GB -VMName $vm
    
    writeText -type "success" -text "GPU Partition Adapter added to VM '$vm'."

    readCommand
}