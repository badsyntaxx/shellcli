function add-intechadmin {
    try {
        write-welcome -Title "Add InTechAdmin Account" -Description "Add an InTech administrator account to this PC." -Command "intech add admin"

        write-text -Type "header" -Text "Getting credentials" -LineBefore -LineAfter

        $accountName = "InTechAdmin"
        $downloads = [ordered]@{
            "$env:TEMP\KEY.txt"    = "https://drive.google.com/uc?export=download&id=1EGASU9cvnl5E055krXXcXUcgbr4ED4ry"
            "$env:TEMP\PHRASE.txt" = "https://drive.google.com/uc?export=download&id=1jbppZfGusqAUM2aU7V4IeK0uHG2OYgoY"
        }

        foreach ($d in $downloads.Keys) { $download = get-download -Url $downloads[$d] -Target $d } 
        if (!$download) { throw "Unable to acquire credentials." }

        $password = Get-Content -Path "$env:TEMP\PHRASE.txt" | ConvertTo-SecureString -Key (Get-Content -Path "$env:TEMP\KEY.txt")

        write-text -Type "done" -Text "Credentials acquired."

        $account = Get-LocalUser -Name $accountName -ErrorAction SilentlyContinue

        if ($null -eq $account) {
            write-text -Type "header" -Text "Creating account" -LineBefore -LineAfter
            New-LocalUser -Name $accountName -Password $password -FullName "" -Description "InTech Administrator" -AccountNeverExpires -PasswordNeverExpires -ErrorAction stop | Out-Null
            write-text -Type "done" -Text "Account created."
            $finalMessage = "Success! The InTechAdmin account has been created."
        } else {
            write-text -Type "header" -Text "InTechAdmin account already exists!" -LineBefore -LineAfter
            write-text -Text "Updating password..."
            $account | Set-LocalUser -Password $password

            $finalMessage = "Success! The password was updated and the groups were applied."
        }

        write-text -Text "Updating group membership..."
        Add-LocalGroupMember -Group "Administrators" -Member $accountName -ErrorAction SilentlyContinue
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $accountName -ErrorAction SilentlyContinue
        Add-LocalGroupMember -Group "Users" -Member $accountName -ErrorAction SilentlyContinue

        Remove-Item -Path "$env:TEMP\PHRASE.txt"
        Remove-Item -Path "$env:TEMP\KEY.txt"

        exit-script -Type "success" -Text $finalMessage
    } catch {
        # Display error message and end the script
        exit-script -Type "error" -Text "add-intechadmin-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -LineAfter
    }
}
