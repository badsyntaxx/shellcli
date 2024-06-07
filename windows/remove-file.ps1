function remove-file {
    try {
        Write-Welcome -Title "Force Delete File" -Description "Forcefully delete a file." -Command "remove file"

        do {
            Write-Text -Type 'header' -Text 'Enter or paste the path and file' -lineBefore -lineAfter
            $filepath = Get-Input -lineAfter

            $file = Get-Item $filepath -ErrorAction SilentlyContinue

            if ($file) {
                $file | Remove-Item -Force 
            } else {
                write-text -Type "error" -Text "Could not find the file. Check that the path for typos."
            }
        } while (!$file)

        $file = Get-Item $filepath -ErrorAction SilentlyContinue
        if (!$file) { exit-script -Type "success" -Text "File successfully deleted." -lineAfter }
    } catch {
        # Display error message and end the script
        exit-script -Type "error" -Text "remove-file-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

