function add-driveLetter {
    try { 
        $choice = readOption -options $([ordered]@{
                "Enable"  = "Enable volume 1"
                "Disable" = "Disable volume 1"
            }) -prompt "Choose"

        $volume = Get-Partition -DiskNumber 1

        if ($choice -eq 0) { 
            Set-Partition -InputObject $volume -NewDriveLetter 'P'
            $message = 'Drive added.'
        }

        if ($choice -eq 1) { 
            $volume | Remove-PartitionAccessPath -AccessPath "P:\"
            $message = 'Drive removed.'
        } 

        writeText -type "success" -text $message -lineAfter
    } catch {
        writeText -type "error" -text "add-drive-letter-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}

