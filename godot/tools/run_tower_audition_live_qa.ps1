param(
    [ValidateSet("dalji", "gaksi", "podo")]
    [string]$TargetOpening = "gaksi",
    [switch]$StartupOnly,
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$previousAppData = $env:APPDATA
$qaAppDataRoot = Join-Path $ProjectPath (".godot\codex_userdata\tower_audition_{0}_{1}" -f `
    $PID,
    [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff")
)

. (Join-Path $PSScriptRoot "assert_no_interactive_godot_game.ps1")
$validationPriorityContext = $null
try {
    $validationPriorityContext = Assert-NoInteractiveGodotGame `
        -ProjectPath $ProjectPath `
        -OperationName "Tower audition live Vulkan QA" `
        -AllowDuringPlay

    . (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
    . (Join-Path $PSScriptRoot "godot_output_classifier.ps1")
    $godot = Resolve-GodotConsolePath -GodotExe $GodotExe
    New-Item -ItemType Directory -Force -Path $qaAppDataRoot | Out-Null
    $env:APPDATA = $qaAppDataRoot
    $qaPath = "res://tools/tower_audition_live_qa.gd"
    $logDir = Join-Path $ProjectPath ".godot\codex_logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $mode = if ($StartupOnly) { "startup" } else { "full" }
    $logPath = Join-Path $logDir ("tower_audition_live_{0}_{1}_{2}_{3}.log" -f `
        $mode,
        $TargetOpening,
        $PID,
        [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff")
    )
    $arguments = @(
        "--path", $ProjectPath,
        "--windowed",
        "--rendering-method", "mobile",
        "--rendering-driver", "vulkan",
        "--log-file", $logPath,
        "-s", $qaPath,
        "--",
        "--target-opening=$TargetOpening"
    )
    if ($StartupOnly) {
        $arguments += "--startup-only"
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $godot @arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    $output | ForEach-Object { Write-Host $_ }
    $outputText = ($output | Out-String)
    $scriptErrors = @($output | Where-Object {
        $_.ToString() -match "SCRIPT ERROR:|CRASH|Segmentation fault|Fatal error"
    })
    $qaFailures = @($output | Where-Object {
        $_.ToString().Contains("[TowerAuditionLiveQA] FAILURE:")
    })
    $isolatedCacheErrors = @($output | Where-Object {
        $_.ToString() -match "Failed loading resource:|Cannot open file|Unable to open file"
    })
    $okMarker = if ($StartupOnly) {
        "tower_audition_live_qa: startup_ok"
    } else {
        "tower_audition_live_qa: full_run_ok"
    }
    if ($isolatedCacheErrors.Count -gt 0) {
        Write-Host (("Tower audition live QA observed {0} isolated-cache resource errors; " + `
            "they are reported separately from the terminal production-path assertion.") -f `
            $isolatedCacheErrors.Count)
    }
    if ($exitCode -ne 0 -or $scriptErrors.Count -gt 0 -or $qaFailures.Count -gt 0 -or -not $outputText.Contains($okMarker)) {
        Write-Host "Tower audition live QA log preserved for triage: $logPath"
        if ($exitCode -ne 0) {
            throw "$qaPath failed with exit code $exitCode"
        }
        if ($scriptErrors.Count -gt 0) {
            throw "$qaPath emitted a GDScript/runtime crash error despite exit code 0"
        }
        if ($qaFailures.Count -gt 0) {
            throw "$qaPath emitted an explicit QA failure"
        }
        throw "$qaPath did not emit its terminal marker"
    }
    Write-Host "Tower audition live Vulkan QA passed: mode=$mode opening=$TargetOpening log=$logPath"
}
finally {
    $env:APPDATA = $previousAppData
    Restore-GodotValidationPriority -Context $validationPriorityContext
}
