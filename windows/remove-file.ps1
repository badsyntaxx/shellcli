function remove-file {
    try {
        Write-Welcome -Title "Force Delete File" -description "Forcefully delete a file." -command "remove file"

        do {
            Write-text -type 'header' -text 'Enter or paste the path and file'  -lineAfter
            $filepath = Get-Input -lineAfter

            $file = Get-Item $filepath -ErrorAction SilentlyContinue

            if ($file) {
                $file | Remove-Item -Force 
            } else {
                write-text -type "error" -text "Could not find the file. Check that the path for typos."
            }
        } while (!$file)

        $file = Get-Item $filepath -ErrorAction SilentlyContinue
        if (!$file) { exit-script -type "success" -text "File successfully deleted." -lineAfter }
    } catch {
        # Display error message and end the script
        exit-script -type "error" -text "remove-file-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

