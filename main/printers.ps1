function getDefaultPrinterName {
    <#
        The default printer of the account ShellCLI runs as, asked of Windows itself
        (GetDefaultPrinter). The copy Windows keeps in the registry can be out of date, and
        asking WMI takes nearly a minute on a computer that has Remote Desktop printers.
    #>
    try {
        if (-not ("ShellCLI.WinSpool" -as [type])) {
            Add-Type -Namespace ShellCLI -Name WinSpool -ErrorAction Stop -MemberDefinition '[System.Runtime.InteropServices.DllImport("winspool.drv", CharSet = System.Runtime.InteropServices.CharSet.Unicode, SetLastError = true)] public static extern bool GetDefaultPrinter(System.Text.StringBuilder name, ref int size);'
        }

        $size = 0
        [void][ShellCLI.WinSpool]::GetDefaultPrinter($null, [ref]$size)

        if ($size -gt 0) {
            $buffer = New-Object System.Text.StringBuilder $size
            if ([ShellCLI.WinSpool]::GetDefaultPrinter($buffer, [ref]$size)) { return $buffer.ToString() }
        }

        return $null
    } catch { }

    # Where Add-Type is not allowed: the registry copy, "name,winspool,port".
    try {
        $device = (Get-ItemProperty -LiteralPath "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows" -Name Device -ErrorAction Stop).Device
        if ($device) { return ($device -replace ',[^,]*,[^,]*$', '') }
    } catch { }

    return $null
}
function getInstalledPrinters {
    <#
        Every installed printer, with what is worth knowing before one is removed: whether it is
        the default, is shared, has jobs waiting, or is a Remote Desktop session printer (Windows
        makes those again at every Remote Desktop sign-in).
    #>
    $defaultName = getDefaultPrinterName

    $installed = @()

    foreach ($printer in @(Get-Printer -ErrorAction Stop)) {
        $jobs = 0
        try { $jobs = @(Get-PrintJob -PrinterObject $printer -ErrorAction Stop).Count } catch { }

        $installed += [pscustomobject]@{
            Kind          = "Printer"
            Name          = "$($printer.Name)"
            Driver        = "$($printer.DriverName)"
            Port          = "$($printer.PortName)"
            Type          = "$($printer.Type)"
            Status        = "$($printer.PrinterStatus)"
            Shared        = [bool]$printer.Shared
            ShareName     = "$($printer.ShareName)"
            Default       = ($null -ne $defaultName -and [string]::Equals("$($printer.Name)", $defaultName, [System.StringComparison]::OrdinalIgnoreCase))
            Jobs          = $jobs
            RemoteDesktop = ("$($printer.DriverName)" -eq "Remote Desktop Easy Print" -or "$($printer.PortName)" -cmatch '^TS\d+$')
        }
    }

    return $installed
}
function findInstalledPrinter {
    <#
        The installed printer with exactly this name (Windows treats names as the same whatever
        their case), or $null if there is none. Throws if the printers cannot be listed, so
        that "could not look" is never read as "not there".
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$name
    )

    return (@(Get-Printer -ErrorAction Stop | Where-Object { [string]::Equals("$($_.Name)", $name, [System.StringComparison]::OrdinalIgnoreCase) }) | Select-Object -First 1)
}
function describePrinter {
    <# One line about a printer (or a leftover entry), for the list and the menu. #>
    param (
        [Parameter(Mandatory = $true)]
        $printer
    )

    if ($printer.Kind -eq "Leftover") {
        if ($printer.Entries -gt 1) { return "leftover entry: $($printer.Entries) device entries, no printer is installed under this name" }
        return "leftover entry: no printer is installed under this name"
    }

    $parts = @($printer.Driver, $printer.Port, $printer.Status)

    if ($printer.Default) { $parts += "default" }
    if ($printer.Shared) { $parts += "shared" }
    if ($printer.Jobs -gt 0) { $parts += "$($printer.Jobs) job(s) waiting" }
    if ($printer.RemoteDesktop) { $parts += "Remote Desktop" }

    return ($parts | Where-Object { $_ }) -join " | "
}
function getPrintQueueNodes {
    <#
        The device entries Windows keeps for print queues that are present (Device Manager,
        Print queues): Name and InstanceId, in the form SWD\PRINTENUM\{guid}. The form is what
        marks one (the class Windows gives it is not relied on). Throws if the devices cannot
        be listed.
    #>
    $nodes = @()

    foreach ($device in @(Get-PnpDevice -PresentOnly -ErrorAction Stop)) {
        if ("$($device.InstanceId)" -match '^SWD\\PRINTENUM\\\{[0-9A-Fa-f-]{36}\}$') {
            $nodes += [pscustomobject]@{ Name = "$($device.FriendlyName)"; InstanceId = "$($device.InstanceId)" }
        }
    }

    return $nodes
}
function getPrinterConnectionsRoot {
    <# Where the current account's connections to shared printers are kept. #>
    return "HKCU:\Printers\Connections"
}
function getPerMachineConnectionsRoot {
    <# Where connections to shared printers are kept for every user of the computer. #>
    return "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Connections"
}
function getPnpUtilCommand {
    <#
        What to run for pnputil.exe, or $null where this Windows cannot do
        "pnputil /remove-device" (it came with Windows 10 version 2004, build 19041). A 32-bit
        PowerShell on 64-bit Windows does not see the 64-bit one under System32.
    #>
    try { if ([Environment]::OSVersion.Version.Build -lt 19041) { return $null } } catch { }

    if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
        $sysnative = Join-Path $env:SystemRoot "Sysnative\pnputil.exe"
        if (Test-Path -LiteralPath $sysnative) { return $sysnative }
        return $null
    }

    if (Get-Command -Name "pnputil.exe" -ErrorAction SilentlyContinue) { return "pnputil.exe" }

    return $null
}
function getPrinterLeftovers {
    <#
        What Windows still has for a printer name: its present device entries (Nodes), the
        account's saved connection to it if it was a shared printer (Connection, a registry
        path), and a connection set up for every user of the computer (PerMachine, a registry
        path; Windows adds the printer again at the next sign-in, so it is only ever reported).
        Checked is false when the device entries could not be listed.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$name
    )

    $result = [pscustomobject]@{ Checked = $true; Nodes = @(); Connection = $null; PerMachine = $null }

    try {
        $result.Nodes = @(getPrintQueueNodes | Where-Object { [string]::Equals($_.Name, $name, [System.StringComparison]::OrdinalIgnoreCase) })
    } catch {
        $result.Checked = $false
    }

    # A connection to a print server (\\server\printer) is kept as ,,server,printer
    if ($name -match '^\\\\[^\\]+\\[^\\]+$') {
        $keyName = ($name -replace '\\', ',')

        $key = (getPrinterConnectionsRoot) + "\" + $keyName
        if (Test-Path -LiteralPath $key) { $result.Connection = $key }

        $key = (getPerMachineConnectionsRoot) + "\" + $keyName
        if (Test-Path -LiteralPath $key) { $result.PerMachine = $key }
    }

    return $result
}
function getLeftoverPrinterEntries {
    <#
        Print queue device entries that Windows still has although no printer is installed under
        that name, one entry for each name (Entries says how many device entries it has).
        Settings can go on listing these, as "Driver is unavailable". Remote Desktop session
        printers are never offered: they belong to sessions, and someone else's session can make
        theirs look like leftovers from here. Windows words the session suffix in the language
        of the computer, so any name that ends like one, "(word number)", is skipped.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        $printers
    )

    $names = @($printers | ForEach-Object { $_.Name })
    $seen = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::OrdinalIgnoreCase)
    $leftovers = @()

    foreach ($node in @(getPrintQueueNodes)) {
        if (-not $node.Name) { continue }
        if ($node.Name -match '\(redirected \d+\)\s*$|\bin session \d+\s*$|\([^()\d]*\s\d+\)\s*$') { continue }

        $installed = $false
        foreach ($name in $names) {
            if ([string]::Equals($node.Name, $name, [System.StringComparison]::OrdinalIgnoreCase)) { $installed = $true; break }
        }
        if ($installed) { continue }

        if ($seen.ContainsKey($node.Name)) { $seen[$node.Name].Entries++; continue }

        $entry = [pscustomobject]@{ Kind = "Leftover"; Name = $node.Name; InstanceId = $node.InstanceId; Entries = 1 }
        $seen[$node.Name] = $entry
        $leftovers += $entry
    }

    return $leftovers
}
function removePrintQueueNode {
    <#
        Removes one print queue device entry with pnputil. Only an entry of exactly the form
        SWD\PRINTENUM\{guid} is ever passed to it. Returns "Removed", "Reboot" (it worked and a
        restart finishes it), "Failed", or "Unavailable" (this Windows has no way to do it).
        Whether the entry is really gone is for the caller to check.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$instanceId
    )

    if ($instanceId -notmatch '^SWD\\PRINTENUM\\\{[0-9A-Fa-f-]{36}\}$') { return "Failed" }

    $command = getPnpUtilCommand
    if (-not $command) { return "Unavailable" }

    try {
        $output = & $command /remove-device $instanceId 2>&1
        $exitCode = $LASTEXITCODE
    } catch {
        log -msg "pnputil could not be run for ${instanceId}: $($_.Exception.Message)" -lvl "WARNING"
        return "Failed"
    }

    log -msg "pnputil /remove-device $instanceId exited with $exitCode. $((($output | ForEach-Object { "$_" }) -join ' ') -replace '\s+', ' ')"

    if ($exitCode -eq 3010) { return "Reboot" }
    if ($exitCode -eq 0) { return "Removed" }

    return "Failed"
}
function restartPrintSpooler {
    <# Restarts the Print Spooler and waits for it. Throws if it does not come back. #>
    $controller = Get-Service -Name "Spooler" -ErrorAction Stop
    Restart-Service -InputObject $controller -Force -ErrorAction Stop
    $controller.WaitForStatus("Running", (New-TimeSpan -Seconds 30))
}
function newLeftoverResult {
    <#
        What clearPrinterLeftovers reports. Clean is $true, $false (something is left) or $null
        (it could not be checked). Removed and Remains are lines of text. The rest says what kind
        of thing is left, so that the advice given matches it: Nodes (device entries to remove by
        hand), Reboot (device entries a restart finishes), Connection (a saved connection),
        PerMachine, Installed (the printer is installed after all), NoPnpUtil (this Windows has
        no way to remove device entries from here).
    #>
    param (
        $Clean,
        $Removed = @(),
        $Remains = @(),
        [bool]$Installed = $false,
        [int]$Nodes = 0,
        [bool]$Reboot = $false,
        [bool]$Connection = $false,
        [bool]$PerMachine = $false,
        [bool]$NoPnpUtil = $false
    )

    return [pscustomobject]@{
        Clean      = $Clean
        Removed    = @($Removed)
        Remains    = @($Remains)
        Installed  = $Installed
        Nodes      = $Nodes
        Reboot     = $Reboot
        Connection = $Connection
        PerMachine = $PerMachine
        NoPnpUtil  = $NoPnpUtil
    }
}
function clearPrinterLeftovers {
    <#
        Removes what Windows keeps for a printer whose queue is gone: the account's saved
        connection to it, and its print queue device entries (what Settings goes on listing as
        "Driver is unavailable"). If an entry is still there afterwards it offers to restart the
        Print Spooler, which is what makes Windows let go of one that is stuck, and tries again
        for the entries that were stuck. What is reported as removed is what a check afterwards
        found gone. It never touches the entries of a printer that is installed, and checks
        again after the restart in case the printer came back. Returns the result of
        newLeftoverResult.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$name
    )

    try {
        $installed = findInstalledPrinter -name $name
    } catch {
        log -msg "Could not list the printers to check '${name}': $($_.Exception.Message)" -lvl "WARNING"
        return (newLeftoverResult -Clean $null -Remains @("Windows would not list the printers, so ShellCLI could not check"))
    }
    if ($installed) {
        return (newLeftoverResult -Clean $false -Installed $true -Remains @("the printer is still installed, so its entries were left alone"))
    }

    $left = getPrinterLeftovers -name $name
    if (-not $left.Checked) {
        return (newLeftoverResult -Clean $null -Remains @("Windows would not list its device entries, so ShellCLI could not check"))
    }

    $canRemove = [bool](getPnpUtilCommand)
    $attempted = @()
    $exitedZero = @()
    $reboot = @()
    $connectionGone = $false
    $backAgain = $false

    if ($left.Connection) {
        try {
            Remove-Item -LiteralPath $left.Connection -Recurse -Force -ErrorAction Stop
            $connectionGone = $true
        } catch {
            log -msg "Could not remove $($left.Connection): $($_.Exception.Message)" -lvl "WARNING"
        }
    }

    if ($canRemove) {
        foreach ($node in $left.Nodes) {
            $attempted += $node.InstanceId
            $outcome = removePrintQueueNode -instanceId $node.InstanceId
            if ($outcome -eq "Removed") { $exitedZero += $node.InstanceId } elseif ($outcome -eq "Reboot") { $reboot += $node.InstanceId }
        }
    }

    $left = getPrinterLeftovers -name $name

    # Entries that are still there and that a restart can help with: not the ones that only
    # wait for the computer to restart.
    $stuck = @()
    if ($left.Checked) { $stuck = @($left.Nodes | Where-Object { $reboot -notcontains $_.InstanceId }) }

    if ($canRemove -and $stuck.Count -gt 0) {
        $dependents = @()
        try { $dependents = @((Get-Service -Name "Spooler" -ErrorAction Stop).DependentServices | Where-Object { "$($_.Status)" -ne "Stopped" } | ForEach-Object { $_.Name }) } catch { }

        writeText -type "notice" -text "Windows is still holding $($stuck.Count) device entr$(if ($stuck.Count -eq 1) { 'y' } else { 'ies' }) for '$name'. Restarting the Print Spooler usually makes it let go."
        writeText -type "plain" -text "  - Printing stops for a few seconds, and a document being printed right now may need to be sent again."
        if ($dependents.Count -gt 0) { writeText -type "plain" -text "  - It also restarts: $($dependents -join ', ')." }

        $answer = readOption -options $([ordered]@{
                "Cancel"  = "Leave it as it is."
                "Restart" = "Restart the Print Spooler and remove the entries again."
            }) -prompt "Do you want to restart the Print Spooler?" -returnKey

        if ($answer -eq "Restart") {
            $stuckIds = @($stuck | ForEach-Object { $_.InstanceId })

            try {
                restartPrintSpooler

                # The printer may have been made again (a policy, a connection for every user).
                if (findInstalledPrinter -name $name) {
                    $backAgain = $true
                } else {
                    $left = getPrinterLeftovers -name $name

                    # Only the entries that were stuck: a new entry is somebody's live printer.
                    foreach ($node in $left.Nodes) {
                        if ($stuckIds -notcontains $node.InstanceId) { continue }
                        $attempted += $node.InstanceId
                        $outcome = removePrintQueueNode -instanceId $node.InstanceId
                        if ($outcome -eq "Removed") { $exitedZero += $node.InstanceId } elseif ($outcome -eq "Reboot") { $reboot += $node.InstanceId }
                    }

                    $left = getPrinterLeftovers -name $name
                }
            } catch {
                log -msg "The Print Spooler restart did not finish cleanly: $($_.Exception.Message)" -lvl "WARNING"
                writeText -type "error" -text "The Print Spooler restart did not finish cleanly: $((($_.Exception.Message -split "\r?\n") | Select-Object -First 1))"
            }
        }
    }

    $removed = @()

    if (-not $left.Checked) {
        if ($connectionGone) { $removed += "the saved connection to it" }
        foreach ($id in @($exitedZero | Select-Object -Unique)) { $removed += "a device entry ($id)" }
        return (newLeftoverResult -Clean $null -Removed $removed -Remains @("Windows would not list its device entries, so ShellCLI could not check"))
    }

    # Removed means gone when looked at again, not "pnputil said it worked".
    if ($connectionGone -and -not $left.Connection) { $removed += "the saved connection to it" }
    $present = @($left.Nodes | ForEach-Object { $_.InstanceId })
    foreach ($id in @($attempted | Select-Object -Unique)) {
        if ($present -notcontains $id) { $removed += "a device entry ($id)" }
    }

    if ($backAgain) {
        return (newLeftoverResult -Clean $false -Installed $true -Removed $removed -Remains @("the printer is back after the restart, so its entries were left alone"))
    }

    $remains = @()
    foreach ($node in $left.Nodes) {
        $line = "a device entry ($($node.InstanceId))"
        if (-not $canRemove) {
            $line += ": this version of Windows has no 'pnputil /remove-device' to remove it with"
        } elseif ($reboot -contains $node.InstanceId) {
            $line += ": Windows finishes removing it when the computer restarts"
        }
        $remains += $line
    }
    if ($left.Connection) { $remains += "the saved connection to it ($($left.Connection))" }
    if ($left.PerMachine) { $remains += "a connection set up for every user of this computer ($($left.PerMachine)): Windows adds the printer again at the next sign-in" }

    $byHand = @($left.Nodes | Where-Object { $reboot -notcontains $_.InstanceId })

    return (newLeftoverResult -Clean ($remains.Count -eq 0) -Removed $removed -Remains $remains `
            -Nodes $byHand.Count -Reboot ($byHand.Count -lt @($left.Nodes).Count) -Connection ([bool]$left.Connection) `
            -PerMachine ([bool]$left.PerMachine) -NoPnpUtil ((-not $canRemove) -and @($left.Nodes).Count -gt 0))
}
function tryClearPrinterLeftovers {
    <#
        clearPrinterLeftovers, for after the printer itself has been dealt with: whatever goes
        wrong in it is reported as "could not check" and never hides what already happened.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$name
    )

    try {
        return (clearPrinterLeftovers -name $name)
    } catch {
        log -msg "Could not clear what Windows keeps for printer ${name}: $($_.Exception.Message)" -lvl "WARNING"
        return (newLeftoverResult -Clean $null -Remains @("$((($_.Exception.Message -split "\r?\n") | Select-Object -First 1))"))
    }
}
function selectPrinter {
    <#
        Lets the user pick one printer (or leftover entry) from the list. Returns it, or $null if
        they backed out (or the menu failed). Nothing is removed here.
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
function showLeftoverResult {
    <# Says what clearPrinterLeftovers did, and what to do about what is left. #>
    param (
        [Parameter(Mandatory = $true)]
        $result,
        [Parameter(Mandatory = $true)]
        [string]$name
    )

    foreach ($item in $result.Removed) { writeText -type "plain" -text "Removed $item." }

    if ($result.Clean -eq $true) {
        if ($result.Removed.Count -eq 0) {
            writeText -type "plain" -text "Windows reports nothing left for '$name'."
        }
        writeText -type "plain" -text "If Settings still lists it, close Settings and open it again: it keeps its list while it is open."
    } elseif ($result.Clean -eq $false) {
        writeText -type "notice" -text "Still left for '$name': $($result.Remains -join '; ')"

        if ($result.Nodes -gt 0) {
            if ($result.NoPnpUtil) { writeText -type "plain" -text "This version of Windows cannot remove a device entry from here." }
            writeText -type "plain" -text "Remove it by hand: Device Manager > View > Show hidden devices > Print queues > right-click the entry > Uninstall device. A restart also clears it."
        }
        if ($result.Reboot) { writeText -type "plain" -text "Restart the computer to finish removing the device entry." }
        if ($result.Connection) { writeText -type "plain" -text "Delete the saved connection by hand: remove the registry key named above." }
        if ($result.PerMachine) {
            writeText -type "plain" -text "Remove it where it was set up (the Group Policy or script that adds it), or run:"
            writeText -type "plain" -text ('  rundll32 printui.dll,PrintUIEntry /gd /n"{0}"' -f $name)
            writeText -type "plain" -text "It is deleted at the next sign-in."
        }
    } else {
        writeText -type "notice" -text "Could not check what Windows still has for '$name': $($result.Remains -join '; ')"
    }
}
function removeLeftoverEntry {
    <# Removes a leftover entry the user picked: print queue device entries with no printer behind them. #>
    param (
        [Parameter(Mandatory = $true)]
        $entry
    )

    $count = 1
    if ($entry.Entries -gt 1) { $count = $entry.Entries }

    $have = $null
    try { $have = getPrinterLeftovers -name $entry.Name } catch { }

    writeText -type "notice" -text "This removes the leftover entry '$($entry.Name)'$(if ($count -gt 1) { " ($count device entries)" }). No printer is installed under that name; it is only what Windows still lists."
    if ($have -and $have.Connection) { writeText -type "plain" -text "  - It also removes this account's saved connection to it." }
    writeText -type "plain" -text "  - If this is another signed-in person's printer, it disappears from their list until they sign in again."

    $answer = readOption -options $([ordered]@{
            "Cancel" = "Remove nothing."
            "Remove" = "Remove the leftover entry '$($entry.Name)'."
        }) -prompt "Do you want to continue?" -returnKey
    if ($answer -ne "Remove") { return }

    $result = tryClearPrinterLeftovers -name $entry.Name
    log -msg "Leftover entries for printer '$($entry.Name)'. Removed: $($result.Removed -join '; '). Left: $($result.Remains -join '; ')."

    if ($result.Clean -eq $true -and $result.Removed.Count -gt 0) {
        writeText -type "success" -text "Removed the leftover entry '$($entry.Name)'."
    }
    showLeftoverResult -result $result -name $entry.Name
}
function removeOnePrinter {
    <# Removes the printer the user picked, checks it is gone, and clears what Windows keeps for it. #>
    param (
        [Parameter(Mandatory = $true)]
        $printer,
        [Parameter(Mandatory = $true)]
        $printers
    )

    $name = $printer.Name

    # --- Say exactly what will happen ---

    writeText -type "notice" -text "This removes the printer '$name' from this computer."
    if ($printer.Default) {
        if (@($printers).Count -gt 1) { writeText -type "plain" -text "  - It is the default printer; Windows will pick another." } else { writeText -type "plain" -text "  - It is the default printer, and there is no other printer to take over." }
    }
    if ($printer.Shared) { writeText -type "plain" -text "  - It is shared$(if ($printer.ShareName) { " as '$($printer.ShareName)'" }): other computers lose access to it." }
    if ($printer.Jobs -gt 0) { writeText -type "plain" -text "  - It has $($printer.Jobs) print job(s) waiting. Windows finishes removing a printer once its jobs are done, so it may stay listed until they print or are cancelled." }
    if ($printer.RemoteDesktop) { writeText -type "plain" -text "  - It is a Remote Desktop session printer; Windows makes it again at the next Remote Desktop sign-in." }

    $answer = readOption -options $([ordered]@{
            "Cancel" = "Remove nothing."
            "Remove" = "Remove '$name'."
        }) -prompt "Do you want to continue?" -returnKey
    if ($answer -ne "Remove") { return }

    # --- Remove ---

    try {
        # Look the printer up again by its exact name (Remove-Printer -Name takes wildcards): it
        # may have gone, or changed, since the list was made.
        $current = findInstalledPrinter -name $name

        if (-not $current) {
            writeText -type "plain" -text "'$name' is already gone."
            $result = tryClearPrinterLeftovers -name $name
            showLeftoverResult -result $result -name $name
            return
        }

        if ("$($current.DriverName)" -ne $printer.Driver -or "$($current.PortName)" -ne $printer.Port) {
            writeText -type "error" -text "'$name' has changed since the list was made (a different driver or port), so it was not removed. Run the command again."
            return
        }

        # -Confirm:$false: the question was asked above, once.
        Remove-Printer -InputObject $current -Confirm:$false -ErrorAction Stop
    } catch {
        $reason = (($_.Exception.Message -split "\r?\n") | Where-Object { $_.Trim() } | Select-Object -First 1)
        if (-not "$reason".Trim()) { $reason = $_.Exception.GetType().Name }
        log -msg "Could not remove printer ${name}: $($_.Exception.Message)" -lvl "WARNING"
        writeText -type "error" -text "Could not remove '${name}': $("$reason".Trim())"
        return
    }

    # --- Check, instead of trusting that no error means it is gone ---

    $still = $null
    $checked = $false
    try {
        $still = findInstalledPrinter -name $name
        $checked = $true
    } catch { }

    if ($still -and "$($still.PrinterStatus)" -match "PendingDeletion") {
        # Windows removes a printer once its jobs are done: with jobs stuck, that never happens.
        $jobs = @()
        try { $jobs = @(Get-PrintJob -PrinterObject $still -ErrorAction Stop) } catch { }

        writeText -type "notice" -text "'$name' is marked for deletion: Windows removes it once its print jobs are done$(if ($jobs.Count -gt 0) { " ($($jobs.Count) waiting)" })."

        if ($jobs.Count -gt 0) {
            $answer = readOption -options $([ordered]@{
                    "Cancel" = "Leave the jobs; the printer goes when they have printed."
                    "Clear"  = "Cancel the $($jobs.Count) waiting print job(s) so the printer can go now."
                }) -prompt "Do you want to cancel the print jobs?" -returnKey

            if ($answer -eq "Clear") {
                try {
                    $jobs | Remove-PrintJob -ErrorAction Stop
                    log -msg "Cancelled $($jobs.Count) print job(s) of printer $name so that it could be removed."
                } catch {
                    writeText -type "error" -text "Could not cancel the print jobs: $((($_.Exception.Message -split "\r?\n") | Select-Object -First 1))"
                }

                for ($i = 0; $i -lt 10; $i++) {
                    try { $still = findInstalledPrinter -name $name } catch { $checked = $false; break }
                    if (-not $still) { break }
                    Start-Sleep -Seconds 1
                }
            }
        }
    }

    if (-not $checked) {
        log -msg "Removed printer $name, but could not check that it is gone." -lvl "WARNING"
        writeText -type "notice" -text "Windows reported no error removing '$name', but ShellCLI could not check that it is gone."
        return
    }

    if ($still) {
        log -msg "Printer $name is still installed after Remove-Printer." -lvl "WARNING"
        writeText -type "error" -text "'$name' is still installed after it was removed."
        return
    }

    log -msg "Removed printer $name (driver: $($printer.Driver), port: $($printer.Port))."

    # --- What Windows keeps after the queue is gone ---

    $result = tryClearPrinterLeftovers -name $name

    if ($result.Clean -eq $true) {
        writeText -type "success" -text "Removed the printer '$name'."
    } elseif ($result.Installed) {
        writeText -type "notice" -text "Removed the printer '$name', but it is installed again (below)."
    } elseif ($result.Clean -eq $false) {
        writeText -type "success" -text "Removed the printer '$name'. Windows still has entries for it (below)."
    } else {
        writeText -type "success" -text "Removed the printer '$name'. ShellCLI could not check what Windows keeps for it (below)."
    }
    showLeftoverResult -result $result -name $name

    writeText -type "plain" -text "Its port and driver are left in place."
}
function removePrinters {
    try {
        $service = Get-Service -Name "Spooler" -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            writeText -type "error" -text "The Print Spooler service (Spooler) is not installed, so this computer has no printers to manage."
            return
        }
        if ("$($service.Status)" -ne "Running") {
            if ("$($service.Status)" -eq "Stopped") {
                writeText -type "notice" -text "The Print Spooler service is stopped, so printers cannot be listed or removed. Start it with 'start service' (the service is Spooler)."
            } else {
                writeText -type "notice" -text "The Print Spooler service is $($service.Status) rather than running, so printers cannot be listed or removed right now. Try again in a moment."
            }
            return
        }

        $printers = @(getInstalledPrinters)

        # Entries Windows still lists for printers that are no longer there.
        $leftovers = @()
        try { $leftovers = @(getLeftoverPrinterEntries -printers $printers) } catch { }

        if ($printers.Count -eq 0 -and $leftovers.Count -eq 0) {
            writeText -type "notice" -text "No printers are installed on this computer."
            return
        }

        if ($printers.Count -gt 0) {
            writeText -type "plain" -text "Printers on this computer: $($printers.Count)"
            $list = [ordered]@{}
            foreach ($item in $printers) { $list[$item.Name] = describePrinter -printer $item }
            writeText -type "list" -List $list -lineAfter
        }

        if ($leftovers.Count -gt 0) {
            writeText -type "plain" -text "Leftover entries (Windows may list these in Settings as 'Driver is unavailable'): $($leftovers.Count)"
            $list = [ordered]@{}
            foreach ($item in $leftovers) { $list[$item.Name] = describePrinter -printer $item }
            writeText -type "list" -List $list -lineAfter
        }

        # --- Choose one ---

        $picked = selectPrinter -printers (@($printers) + @($leftovers))
        if ($null -eq $picked) { return }

        if ($picked.Kind -eq "Leftover") {
            removeLeftoverEntry -entry $picked
        } else {
            removeOnePrinter -printer $picked -printers $printers
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
            if ("$($service.Status)" -eq "Stopped") {
                writeText -type "notice" -text "The Print Spooler service is stopped, so printers cannot be listed. Start it with 'start service' (the service is Spooler)."
            } else {
                writeText -type "notice" -text "The Print Spooler service is $($service.Status) rather than running, so printers cannot be listed right now. Try again in a moment."
            }
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
