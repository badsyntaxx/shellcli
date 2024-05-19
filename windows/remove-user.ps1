function remove-user {
    try {
        write-welcome  -Title "Remove User" -Description "Remove an existing user account from the system." -Command "remove user"

        $user = select-user

        write-text -Type "header" -Text "Delete user data" -LineAfter
        $choice = get-option -Options $([ordered]@{
                "Delete" = "Also delete the users data."
                "Keep"   = "Do not delete the users data."
            })

        if ($choice -eq 0) { $deleteData = $true }
        if ($choice -eq 1) { $deleteData = $false }

        if ($deleteData) { write-text -Type "header" -Text "YOU'RE ABOUT TO DELETE THIS ACCOUNT AND ITS DATA!" -LineBefore -LineAfter } 
        else { write-text -Type "header" -Text "YOU'RE ABOUT TO DELETE THIS ACCOUNT!" -LineBefore -LineAfter }
        
        get-closing -Script "remove-user"

        if ($deleteData) {
            $dir = (Get-CimInstance Win32_UserProfile -Filter "SID = '$((Get-LocalUser $user["Name"]).Sid)'").LocalPath
            if ($null -ne $dir -And (Test-Path -Path $dir)) { Remove-Item -Path $dir -Recurse -Force }
        }

        if ($null -eq $dir) { write-text -Type "done" -Text "User data deleted." }

        Remove-LocalUser -Name $user["Name"] | Out-Null

        if (Get-LocalUser -Name $user["Name"] -ErrorAction SilentlyContinue | Out-Null) {
            write-text -Type "fail" -Text "Could not remove user."
        } else {
            write-text -Type "done" -Text "User removed."
        }

        exit-script -Type "success" -Text "The user has been deleted." -LineAfter
    } catch {
        # Display error message and end the script
        exit-script -Type "error" -Text "remove-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -LineAfter
    }
}

