function removeUser {
    try {
        $user = selectUser -prompt "Select an account to remove:"
        $userProfile = Get-CimInstance Win32_UserProfile -Filter "SID = '$((Get-LocalUser $user["Name"]).Sid)'"
        $dir = $userProfile.LocalPath

        $choice = readOption -options $([ordered]@{
                "Delete" = "Also delete the users data."
                "Keep"   = "Do not delete the users data."
                "Cancel" = "Do not delete anything and exit this function."
            }) -prompt "Do you also want to delete the users data?"

        if ($choice -eq 2) {
            return
        }

        Remove-LocalUser -Name $user["Name"] | Out-Null

        $response = "The user has been removed"
        if ($choice -eq 0 -and $dir) { 
            try {
                Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
                
                # Verify profile folder deletion
                $u = Get-LocalUser -Name $user["Name"] -ErrorAction SilentlyContinue
                $profileStillExists = Get-CimInstance Win32_UserProfile -Filter "SID = '$((Get-LocalUser $user["Name"]).Sid)'" -ErrorAction SilentlyContinue

                if (!$u -and $null -eq $profileStillExists) {
                    $response += " as well as their data."
                } else {
                    writeText -type 'error' -text "Unable to delete user data for unknown reasons."
                    $response += " but their data could not be fully deleted."
                }
            } catch {
                writeText -type 'error' -text "Failed to delete user profile folder: $($_.Exception.Message)"
                $response += " but their data could not be deleted."
            }
        } elseif ($choice -eq 1) {
            $response += " but not their data."
        }

        writeText -type 'success' -text $response
    } catch {
        writeText -type "error" -text "removeUser-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}