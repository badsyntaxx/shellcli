function findDC {
    try {
        nltest /dsgetdc:
    } catch {
        writeText -type "error" -text "findDC-$($_.InvocationInfo.ScriptLineNumber) | $($_.Exception.Message)"
    }
}