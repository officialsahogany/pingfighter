#requires -Version 5.1

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "nightly_smoke_result_policy.ps1")

function Assert-Status {
    param(
        [string]$Label,
        [int]$Expected,
        [int]$Actual
    )

    if ($Actual -ne $Expected) {
        throw "$Label expected $Expected, got $Actual"
    }
}

# Tee-Object writes each logged line to the success stream. The aggregate
# policy must read the final explicit status instead of comparing the entire
# noisy output array to a scalar.
$noisyPass = @("engine output", "terminal ok", 0)
$noisyFail = @("engine output", "terminal failure", 1)

$legacyArrayComparison = (($noisyPass -eq 0) -and ($noisyPass -eq 0))
if ($legacyArrayComparison) {
    throw "nightly fixture no longer reproduces the legacy array-comparison bug"
}

Assert-Status "pass/pass" 0 (Get-NightlyCombinedExitCode `
    -LoadOutput $noisyPass -SmokeOutput $noisyPass)
Assert-Status "pass/fail" 1 (Get-NightlyCombinedExitCode `
    -LoadOutput $noisyPass -SmokeOutput $noisyFail)
Assert-Status "fail/pass" 1 (Get-NightlyCombinedExitCode `
    -LoadOutput $noisyFail -SmokeOutput $noisyPass)

$invalidRejected = $false
try {
    $null = Get-NightlyCombinedExitCode `
        -LoadOutput @("engine output without status") `
        -SmokeOutput $noisyPass
}
catch {
    $invalidRejected = $_.Exception.Message -match "invalid status code"
}
if (-not $invalidRejected) {
    throw "nightly status policy accepted output without a final status code"
}

Write-Host "nightly smoke status policy: ok"
