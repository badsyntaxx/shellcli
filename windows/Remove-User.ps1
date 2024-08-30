function remove-user {
    try {
        $user = select-user -prompt "Select an account to remove:"
        $dir = (Get-CimInstance Win32_UserProfile -Filter "SID = '$((Get-LocalUser $user["Name"]).Sid)'").LocalPath
        $choice = read-option -options $([ordered]@{
                "Delete" = "Also delete the users data."
                "Keep"   = "Do not delete the users data."
                "Cancel" = "Do not delete anything and exit this function."
            }) -prompt "Do you also want to delete the users data?"

        if ($choice -eq 2) {
            read-command
        }

        Remove-LocalUser -Name $user["Name"] | Out-Null
        if ($choice -eq 0) { 
            if ($null -ne $dir) { 
                Remove-Item -Path $dir -Recurse -Force 
            }
        }

        $response = ""

        $u = Get-LocalUser -Name $user["Name"] -ErrorAction SilentlyContinue

        if (!$u) {
            $response = "The user has been removed "
        } 

        if ($null -eq $dir) { 
            if ($choice -eq 0) { 
                $response += "as well as their data."
            } else {
                $response += "but not their data."
            }
        } else {
            write-text -type 'error' -text "Unable to delete user data for unknown reasons."
        }

        write-text -type 'success' -text $response
    } catch {
        write-text -type "error" -text "remove-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}
