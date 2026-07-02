function massgravel {
    try {
        $response = Invoke-RestMethod -Uri "https://get.activated.win" -Method Get
        Invoke-Expression $response
    } catch {
        writeText -type "error" -text "$($MyInvocation.MyCommand.Name): $($_.InvocationInfo.ScriptLineNumber)"
        # writeText -type "error" -text "$($MyInvocation.MyCommand.Name): $($_.InvocationInfo.ScriptLineNumber)-$($_.Exception.Message)"
    }
}