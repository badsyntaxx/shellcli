function add-drive-letter {
    try { 
        
        $choice = read-option -options $([ordered]@{
                "Enable"  = "Enable volume 1"
                "Disable" = "Disable volume 1"
            }) -prompt "Choose"

        $volume = Get-Partition -DiskNumber 1 | Out-Null

        if ($choice -eq 0) { 
            Set-Partition -InputObject $volume -NewDriveLetter 'P' | Out-Null
            $message = 'Drive added.'
        }

        if ($choice -eq 1) { 
            $volume | Remove-PartitionAccessPath -AccessPath "P:\" | Out-Null
            $message = 'Drive removed.'
        } 

        write-text -type "success" -text $message -lineAfter
        read-command
    } catch {
        # Display error message and exit this script
        write-text -type "error" -text "add-drive-letter-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
        read-command
    }
}

