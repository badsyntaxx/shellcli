function getInstalledPrinters {
    <#
        Every installed printer, with what is worth knowing before one is removed: whether it is
        the default, is shared, has jobs waiting, or is a Remote Desktop session printer (Windows
        makes those again at every Remote Desktop sign-in).
    #>
    $defaultName = $null
    try {
        $defaultName = (Get-CimInstance -ClassName Win32_Printer -Filter "Default=True" -ErrorAction Stop | Select-Object -First 1).Name
    } catch { }

    $installed = @()

    foreach ($printer in @(Get-Printer -ErrorAction Stop)) {
        $jobs = 0
        try { $jobs = @(Get-PrintJob -PrinterObject $printer -ErrorAction Stop).Count } catch { }

        $installed += [pscustomobject]@{
            Name          = "$($printer.Name)"
            Driver        = "$($printer.DriverName)"
            Port          = "$($printer.PortName)"
            Type          = "$($printer.Type)"
            Status        = "$($printer.PrinterStatus)"
            Shared        = [bool]$printer.Shared
            ShareName     = "$($printer.ShareName)"
            Default       = ($null -ne $defaultName -and "$($printer.Name)" -ceq $defaultName)
            Jobs          = $jobs
            RemoteDesktop = ("$($printer.DriverName)" -eq "Remote Desktop Easy Print" -or "$($printer.PortName)" -cmatch '^TS\d+$')
        }
    }

    return $installed
}
function describePrinter {
    <# One line about a printer, for the list and the menu. #>
    param (
        [Parameter(Mandatory = $true)]
        $printer
    )

    $parts = @($printer.Driver, $printer.Port, $printer.Status)

    if ($printer.Default) { $parts += "default" }
    if ($printer.Shared) { $parts += "shared" }
    if ($printer.Jobs -gt 0) { $parts += "$($printer.Jobs) job(s) waiting" }
    if ($printer.RemoteDesktop) { $parts += "Remote Desktop" }

    return ($parts | Where-Object { $_ }) -join " | "
}
function selectPrinter {
    <#
        Lets the user pick one printer from the list. Returns it, or $null if they backed out
        (or the menu failed). Nothing is removed here.
    #>
    param (
        [Parameter(Mandatory = $true)]
        $printers
    )

    # Numbered, so that no printer's name can be mistaken for the menu's own Cancel entry.
    $labels = [ordered]@{}
    $options = [ordered]@{}
    $number = 0
    foreach ($printer in $printers) {
        $number++
        $label = "$number. $($printer.Name)"
        $labels[$label] = $printer
        $options[$label] = describePrinter -printer $printer
    }
    $options["Cancel"] = "Remove nothing and exit this function."

    $choice = readOption -options $options -prompt "Select the printer to remove:" -returnKey

    # Cancel, or a menu that returned nothing, picks nothing.
    if (-not $choice -or -not $labels.Contains($choice)) { return $null }

    return $labels[$choice]
}
function removePrinters {
    try {
        $service = Get-Service -Name "Spooler" -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            writeText -type "error" -text "The Print Spooler service (Spooler) is not installed, so this computer has no printers to manage."
            return
        }
        if ("$($service.Status)" -ne "Running") {
            writeText -type "notice" -text "The Print Spooler service is not running, so printers cannot be listed or removed. Start it with 'start service' (the service is Spooler)."
            return
        }

        $printers = @(getInstalledPrinters)
        if ($printers.Count -eq 0) {
            writeText -type "notice" -text "No printers are installed on this computer."
            return
        }

        writeText -type "plain" -text "Printers on this computer: $($printers.Count)"
        $list = [ordered]@{}
        foreach ($item in $printers) { $list[$item.Name] = describePrinter -printer $item }
        writeText -type "list" -List $list -lineAfter

        # --- Choose one ---

        $printer = selectPrinter -printers $printers
        if ($null -eq $printer) { return }

        # --- Say exactly what will happen ---

        writeText -type "notice" -text "This removes the printer '$($printer.Name)' from this computer."
        if ($printer.Default) { writeText -type "plain" -text "  - It is the default printer; Windows will pick another." }
        if ($printer.Shared) { writeText -type "plain" -text "  - It is shared$(if ($printer.ShareName) { " as '$($printer.ShareName)'" }): other computers lose access to it." }
        if ($printer.Jobs -gt 0) { writeText -type "plain" -text "  - It has $($printer.Jobs) print job(s) waiting; they are cancelled." }
        if ($printer.RemoteDesktop) { writeText -type "plain" -text "  - It is a Remote Desktop session printer; Windows makes it again at the next Remote Desktop sign-in." }

        $answer = readOption -options $([ordered]@{
                "Cancel" = "Remove nothing."
                "Remove" = "Remove '$($printer.Name)'."
            }) -prompt "Do you want to continue?" -returnKey
        if ($answer -ne "Remove") { return }

        # --- Remove ---

        try {
            # Look the printer up again by its exact name (Remove-Printer -Name takes wildcards):
            # it may have gone, or changed, since the list was made.
            $current = @(Get-Printer -ErrorAction Stop | Where-Object { "$($_.Name)" -ceq $printer.Name }) | Select-Object -First 1
            if (-not $current) {
                writeText -type "plain" -text "'$($printer.Name)' is already gone."
                return
            }

            Remove-Printer -InputObject $current -ErrorAction Stop
        } catch {
            $reason = (($_.Exception.Message -split "\r?\n") | Where-Object { $_.Trim() } | Select-Object -First 1)
            log -msg "Could not remove printer $($printer.Name): $($_.Exception.Message)" -lvl "WARNING"
            writeText -type "error" -text "Could not remove '$($printer.Name)': $("$reason".Trim())"
            return
        }

        log -msg "Removed printer $($printer.Name) (driver: $($printer.Driver), port: $($printer.Port))."

        # --- Check, instead of trusting that no error means it is gone ---

        $stillThere = $null
        try { $stillThere = (@(Get-Printer -ErrorAction Stop | Where-Object { "$($_.Name)" -ceq $printer.Name }).Count -gt 0) } catch { }

        if ($null -eq $stillThere) {
            writeText -type "notice" -text "Windows reported no error removing '$($printer.Name)', but ShellCLI could not check that it is gone."
        } elseif ($stillThere) {
            writeText -type "error" -text "'$($printer.Name)' is still installed after it was removed."
        } else {
            writeText -type "success" -text "Removed the printer '$($printer.Name)'."
            writeText -type "plain" -text "Its port and driver are left in place, so the printer can be added again quickly."
        }
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
function listPrinters {
    try {
        $service = Get-Service -Name "Spooler" -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            writeText -type "error" -text "The Print Spooler service (Spooler) is not installed, so this computer has no printers to list."
            return
        }
        if ("$($service.Status)" -ne "Running") {
            writeText -type "notice" -text "The Print Spooler service is not running, so printers cannot be listed. Start it with 'start service' (the service is Spooler)."
            return
        }

        $printers = @(getInstalledPrinters)
        if ($printers.Count -eq 0) {
            writeText -type "notice" -text "No printers are installed on this computer."
            return
        }

        writeText -type "plain" -text "Printers on this computer: $($printers.Count)"
        $list = [ordered]@{}
        foreach ($printer in $printers) { $list[$printer.Name] = describePrinter -printer $printer }
        writeText -type "list" -List $list
        writeText -type "plain" -text "Use 'remove printer' to remove any of them." -lineBefore
    } catch {
        writeText -type "error" -text "$($_.Exception.Message) ($($MyInvocation.MyCommand.Name)-$($_.InvocationInfo.ScriptLineNumber))"
    }
}
