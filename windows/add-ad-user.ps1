function add-ad-user {
    try {
        write-text -type "fail" -text "Editing domain users doesn't work yet."
        exit-script

        Get-Item -ErrorAction SilentlyContinue "$path\add-ad-user.ps1" | Remove-Item -ErrorAction SilentlyContinue
        Write-Host " Chased Scripts: Add Domain User v0321240710"
        Write-Host "$des" -ForegroundColor DarkGray

        write-text -type "label" -text "Enter name"  -lineAfter
        $name = read-input -prompt "" -Validate "^([a-zA-Z0-9 _\-]{1,64})$"  -CheckExistingUser

        write-text -type "label" -text "Enter sam name"  -lineAfter
        $samAccountName = read-input -prompt "" -Validate "^([a-zA-Z0-9 _\-]{1,20})$"  -CheckExistingUser

        write-text -type "label" -text "Enter password"  -lineAfter
        $password = read-input -prompt "" -IsSecure
        
        write-text -type "label" -text "Set group membership"  -lineAfter
        $choice = read-option -options @("Administrator", "Standard user")
        
        if ($choice -eq 0) { $group = 'Administrators' } else { $group = "Users" }
        if ($group -eq 'Administrators') { $groupDisplay = 'Administrator' } else { $groupDisplay = 'Standard user' }

        write-text -type "label" -text "YOU'RE ABOUT TO CREATE A NEW AD USER!"  -lineAfter

        $choice = read-option -options @(
            "Submit  - Confirm and apply." 
            "Reset   - Start over at the beginning."
            "Exit    - Run a different command."
        ) -lineAfter

        if ($choice -ne 0 -and $choice -ne 2) { invoke-script -script "add-ad-user" }
        if ($choice -eq 2) { throw "This function is under construction." }

        New-ADUser -Name $name 
        -SamAccountName $samAccountName 
        -GivenName $GivenName 
        -Surname $Surname 
        -UserPrincipalName "$UserPrincipalName@$domainName.com" 
        -AccountPassword $password 
        -Enabled $true

        Add-LocalGroupMember -Group $group -Member $name -ErrorAction Stop

        $data = get-userdata -Username $name

        write-text -type "list" -List $data -lineAfter

        exit-script -type "success" -text "The user account was created."
    } catch {
        # Display error message and exit this script
        exit-script -type "error" -text "add-domain-user-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)" -lineAfter
    }
}

