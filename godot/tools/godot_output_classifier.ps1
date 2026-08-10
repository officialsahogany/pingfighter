function Test-GodotBenignCertificateErrorLine {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line)

    return $Line -match '^\s*ERROR: Failed to read the root certificate store\.\s*$'
}

function Test-GodotSeriousErrorLine {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line)

    return (-not (Test-GodotBenignCertificateErrorLine -Line $Line)) -and
        ($Line -match '^\s*(SCRIPT ERROR|ERROR:|FATAL:)')
}

function Test-GodotLeakDiagnosticLine {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line)

    return ($Line -match 'ObjectDB instances leaked at exit') -or
        ($Line -match 'RID allocations.*leaked')
}
