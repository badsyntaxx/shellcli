function add-drive-letter {
    try { 
        
        $choice = get-option -Options $([ordered]@{
                "Enable"  = "Enable volume 1"
                "Disable" = "Disable volume 1"
            }) -lineAfter -lineBefore

        $volume = Get-Partition -DiskNumber 1

        if ($choice -eq 0) { 
            Set-Partition -InputObject $volume -NewDriveLetter 'P' 
        }

        if ($choice -eq 1) { 
            $volume | Remove-PartitionAccessPath -AccessPath "P:\"

        } 

        exit-script -Type "success" -Text $message -lineAfter
    } catch {
        # Display error message and end the script
        exit-script -Type "error" -Text "add-drive-letter-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

