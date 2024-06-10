function remove-user {
    try {
        $user = select-user

        $choice = read-option -options $([ordered]@{
                "Delete" = "Also delete the users data."
                "Keep"   = "Do not delete the users data."
            }) -lineAfter

        if ($choice -eq 0) { $deleteData = $true }
        if ($choice -eq 1) { $deleteData = $false }

        if ($deleteData) { $alert = "Delete this account and its data?" } 
        else { $alert = "Delete this account?" }
        
        get-closing -Script "remove-user" -customText $alert

        if ($deleteData) {
            $dir = (Get-CimInstance Win32_UserProfile -Filter "SID = '$((Get-LocalUser $user["Name"]).Sid)'").LocalPath
            if ($null -ne $dir -And (Test-Path -Path $dir)) { Remove-Item -Path $dir -Recurse -Force }
        }

        if ($null -eq $dir) { 
            write-text -type 'success' -text "User data deleted." 
        } else {
            write-text -type 'error' -text "Unable to delete user data."
        }

        Remove-LocalUser -Name $user["Name"] | Out-Null
        if (Get-LocalUser -Name $user["Name"] -ErrorAction SilentlyContinue | Out-Null) {
            exit-script -type "error" -text "Could not remove user."
        } 

        exit-script -type 'success' -text "User removed." -lineAfter
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "remove-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

