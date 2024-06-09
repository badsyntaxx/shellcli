function add-drive-letter {
    try { 
        
        $choice = get-option -options $([ordered]@{
                "Enable"  = "Enable volume 1"
                "Disable" = "Disable volume 1"
            }) -lineAfter 

        $volume = Get-Partition -DiskNumber 1

        if ($choice -eq 0) { 
            Set-Partition -InputObject $volume -NewDriveLetter 'P' 
        }

        if ($choice -eq 1) { 
            $volume | Remove-PartitionAccessPath -AccessPath "P:\"

        } 

        exit-script -type "success" -text $message -lineAfter
    } catch {
        # Display error message and end the script
        exit-script -type "error" -text "add-drive-letter-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

