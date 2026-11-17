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
function selectPrinters {
    <#
        Lets the user pick any number of the printers. Returns Cancelled (they backed out, or the
        menu failed) and Printers (the ones picked). Nothing is removed here.
    #>
    param (
        [Parameter(Mandatory = $true)]
        $printers
    )

    # Numbered, so that no printer's name can be mistaken for one of the menu's own entries.
    $labels = [ordered]@{}
    $number = 0
    foreach ($printer in $printers) {
        $number++
        $labels["$number. $($printer.Name)"] = $printer
    }

    $selected = @()

    while ($true) {
        $available = [ordered]@{}

        if ($selected.Count -gt 0) {
            $available["Done"] = "Review the $($selected.Count) printer(s) chosen."
        } else {
            $available["All printers"] = "Choose every printer in the list."
        }
        foreach ($label in $labels.Keys) {
            if ($selected -notcontains $label) { $available[$label] = describePrinter -printer $labels[$label] }
        }
        $available["Cancel"] = "Remove nothing and exit this function."

        if ($selected.Count -eq 0) { $prompt = "Select a printer to remove:" } else { $prompt = "Select another printer or 'Done':" }

        $choice = readOption -options $available -prompt $prompt -returnKey

        # A menu that returned nothing counts as a cancel, so the loop always ends.
        if (-not $choice -or $choice -eq "Cancel") {
            return [pscustomobject]@{ Cancelled = $true; Printers = @() }
        }
        if ($choice -eq "Done") { break }
        if ($choice -eq "All printers") {
            $selected = @($labels.Keys)
            break
        }

        $selected += $choice
    }

    return [pscustomobject]@{ Cancelled = $false; Printers = @($selected | ForEach-Object { $labels[$_] }) }
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
        $table = [ordered]@{}
        foreach ($printer in $printers) { $table[$printer.Name] = describePrinter -printer $printer }
        writeText -type "list" -List $table -lineAfter

        # --- Choose ---

        $selection = selectPrinters -printers $printers
        if ($selection.Cancelled) { return }

        $chosen = @($selection.Printers)

        # --- Say exactly what will happen ---

        writeText -type "notice" -text "This removes $($chosen.Count) printer(s) from this computer:"
        foreach ($printer in $chosen) {
            writeText -type "plain" -text "  $($printer.Name)"
            if ($printer.Default) { writeText -type "plain" -text "    - It is the default printer; Windows will pick another." }
            if ($printer.Shared) { writeText -type "plain" -text "    - It is shared$(if ($printer.ShareName) { " as '$($printer.ShareName)'" }): other computers lose access to it." }
            if ($printer.Jobs -gt 0) { writeText -type "plain" -text "    - It has $($printer.Jobs) print job(s) waiting; they are cancelled." }
            if ($printer.RemoteDesktop) { writeText -type "plain" -text "    - It is a Remote Desktop session printer; Windows makes it again at the next Remote Desktop sign-in." }
        }

        $answer = readOption -options $([ordered]@{
                "Cancel" = "Remove nothing."
                "Remove" = "Remove the $($chosen.Count) printer(s) listed above."
            }) -prompt "Do you want to continue?" -returnKey
        if ($answer -ne "Remove") { return }

        # --- Remove ---

        $removed = @()
        $gone = @()
        $failed = @()

        foreach ($item in $chosen) {
            try {
                # Look the printer up again by its exact name (Remove-Printer -Name takes wildcards):
                # it may have gone, or changed, since the list was made.
                $current = @(Get-Printer -ErrorAction Stop | Where-Object { "$($_.Name)" -ceq $item.Name }) | Select-Object -First 1
                if (-not $current) {
                    $gone += $item.Name
                    continue
                }

                Remove-Printer -InputObject $current -ErrorAction Stop
                log -msg "Removed printer $($item.Name) (driver: $($item.Driver), port: $($item.Port))."
                $removed += $item.Name
            } catch {
                $reason = (($_.Exception.Message -split "\r?\n") | Where-Object { $_.Trim() } | Select-Object -First 1)
                $failed += [pscustomobject]@{ Name = $item.Name; Reason = "$reason".Trim() }
                log -msg "Could not remove printer $($item.Name): $($_.Exception.Message)" -lvl "WARNING"
            }
        }

        # --- Check, instead of trusting that no error means it is gone ---

        if ($removed.Count -gt 0) {
            $remaining = @()
            try { $remaining = @(Get-Printer -ErrorAction Stop | ForEach-Object { "$($_.Name)" }) } catch { }

            foreach ($name in @($removed)) {
                if ($remaining -ccontains $name) {
                    $removed = @($removed | Where-Object { $_ -cne $name })
                    $failed += [pscustomobject]@{ Name = $name; Reason = "it is still installed after being removed" }
                }
            }
        }

        # --- The result ---

        if ($removed.Count -gt 0 -and $failed.Count -eq 0) {
            writeText -type "success" -text "Removed $($removed.Count) printer(s): $($removed -join ', ')"
        } elseif ($removed.Count -gt 0) {
            writeText -type "notice" -text "Removed $($removed.Count) printer(s): $($removed -join ', ')"
        }

        if ($gone.Count -gt 0) {
            writeText -type "plain" -text "Already gone by the time they were reached: $($gone -join ', ')"
        }

        if ($failed.Count -gt 0) {
            writeText -type "error" -text "$($failed.Count) printer(s) could not be removed:"
            foreach ($item in $failed) { writeText -type "plain" -text "  $($item.Name): $($item.Reason)" }
        }

        if ($removed.Count -gt 0) {
            writeText -type "plain" -text "The printers' ports and drivers are left in place, so a printer can be added again quickly."
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
