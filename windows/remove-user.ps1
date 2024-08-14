function remove-user {
    try {
        $user = select-user -prompt "Select an account to remove." -lineBefore
        $dir = (Get-CimInstance Win32_UserProfile -Filter "SID = '$((Get-LocalUser $user["Name"]).Sid)'").LocalPath

        Remove-LocalUser -Name $user["Name"] | Out-Null
        if (Get-LocalUser -Name $user["Name"] -ErrorAction SilentlyContinue | Out-Null) {
            exit-script -type "error" -text "Could not remove user."
        } 

        write-text -type 'success' -text "The user account has been removed from the system." -lineBefore

        $choice = read-option -options $([ordered]@{
                "Delete" = "Also delete the users data."
                "Keep"   = "Do not delete the users data."
            }) -prompt "Do you also want to delete the users data?" -lineBefore

        if ($choice -eq 0) { 
            if ($null -ne $dir) { Remove-Item -Path $dir -Recurse -Force }
        }

        if ($null -eq $dir) { 
            write-text -type 'success' -text "The user data has been deleted." -lineBefore  
        } else {
            write-text -type 'error' -text "Unable to delete user data." -lineBefore 
        }

        exit-script
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "remove-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}
<# #################################################################################################################################### #>
<# #################################################################################################################################### #>
<# #################################################################################################################################### #>

