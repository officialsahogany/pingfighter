function Get-NightlyStepExitCode {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$StepOutput
    )

    if ($StepOutput.Count -eq 0) {
        throw "Nightly step produced no status code"
    }

    $code = 0
    $rawStatus = $StepOutput[$StepOutput.Count - 1]
    if (-not [int]::TryParse([string]$rawStatus, [ref]$code) -or
        $code -notin @(0, 1)) {
        throw "Nightly step ended with an invalid status code: $rawStatus"
    }
    return $code
}

function Get-NightlyCombinedExitCode {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$LoadOutput,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$SmokeOutput
    )

    $loadCode = Get-NightlyStepExitCode -StepOutput $LoadOutput
    $smokeCode = Get-NightlyStepExitCode -StepOutput $SmokeOutput
    if ($loadCode -eq 0 -and $smokeCode -eq 0) {
        return 0
    }
    return 1
}
