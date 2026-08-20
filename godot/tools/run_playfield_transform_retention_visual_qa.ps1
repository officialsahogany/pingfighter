param(
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$OutputDir = "",
    [switch]$Counterproof
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "assert_no_interactive_godot_game.ps1")
$validationPriorityContext = $null
try {
    $validationPriorityContext = Assert-NoInteractiveGodotGame `
        -ProjectPath $ProjectPath `
        -OperationName "Playfield transform retention Vulkan visual QA" `
        -AllowDuringPlay

    . (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
    . (Join-Path $PSScriptRoot "godot_output_classifier.ps1")
    $godot = Resolve-GodotConsolePath -GodotExe $GodotExe
    $qaPath = "res://tests/playfield_draw_transform_retention_pixel_smoke.gd"
    $logDir = Join-Path $ProjectPath ".godot\codex_logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $timestamp = [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff")
    $logPath = Join-Path $logDir ("playfield_transform_retention_{0}_{1}.log" -f $PID, $timestamp)
    if ([string]::IsNullOrWhiteSpace($OutputDir)) {
        $suffix = if ($Counterproof) { "counterproof" } else { "green" }
        $OutputDir = Join-Path $ProjectPath ".godot\codex_artifacts\playfield_transform_retention\$suffix"
    }

    $godotArgs = @(
        "--path", $ProjectPath,
        "--windowed",
        "--resolution", "2020x1246",
        "--rendering-method", "mobile",
        "--rendering-driver", "vulkan",
        "--log-file", $logPath,
        "-s", $qaPath,
        "--",
        "--output-dir=$OutputDir"
    )
    if ($Counterproof) {
        $godotArgs += "--force-legacy-reset"
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $godot @godotArgs 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    $output | ForEach-Object { Write-Host $_ }
    $outputText = ($output | Out-String)
    if ($Counterproof) {
        if (
            $exitCode -eq 0 `
            -or -not $outputText.Contains("forced legacy reset should make the GREEN assertions RED") `
            -or -not $outputText.Contains("left pillar")
        ) {
            Write-Host "Transform counterproof log preserved for triage: $logPath"
            throw "Legacy transform reset did not drive the pixel seal RED as required"
        }
        Write-Host "Playfield transform retention counterproof: RED (expected)"
        Write-Host "Counterproof log preserved: $logPath"
        return
    }

    $seriousErrors = @($output | Where-Object {
        Test-GodotSeriousErrorLine -Line $_.ToString()
    })
    if (
        $exitCode -ne 0 `
        -or $seriousErrors.Count -gt 0 `
        -or -not $outputText.Contains("playfield_draw_transform_retention_pixel_smoke: captures=4") `
        -or -not $outputText.Contains("playfield_draw_transform_retention_pixel_smoke: ok") `
        -or ([regex]::Matches($outputText, "left_pillar_pixels=0")).Count -ne 4
    ) {
        Write-Host "Transform visual QA log preserved for triage: $logPath"
        if ($exitCode -ne 0) {
            throw "$qaPath failed with exit code $exitCode"
        }
        if ($seriousErrors.Count -gt 0) {
            throw "$qaPath emitted a Godot error despite exit code 0"
        }
        throw "$qaPath did not emit every pixel-seal terminal marker"
    }
    Remove-Item -LiteralPath $logPath -Force
    if (-not (Get-ChildItem -LiteralPath $logDir -Force)) {
        Remove-Item -LiteralPath $logDir -Force
    }
    Write-Host "Playfield transform retention Vulkan visual QA passed: $OutputDir"
}
finally {
    Restore-GodotValidationPriority -Context $validationPriorityContext
}
