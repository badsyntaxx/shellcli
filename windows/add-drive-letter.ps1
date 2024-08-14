function add-drive-letter {
    try { 
        
        $choice = read-option -options $([ordered]@{
                "Enable"  = "Enable volume 1"
                "Disable" = "Disable volume 1"
            }) -lineAfter 

        $volume = Get-Partition -DiskNumber 1 | Out-Null

        if ($choice -eq 0) { 
            Set-Partition -InputObject $volume -NewDriveLetter 'P' | Out-Null
            $message = 'Drive added.'
        }

        if ($choice -eq 1) { 
            $volume | Remove-PartitionAccessPath -AccessPath "P:\" | Out-Null
            $message = 'Drive removed.'
        } 

        exit-script -type "success" -text $message -lineAfter
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "add-drive-letter-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

