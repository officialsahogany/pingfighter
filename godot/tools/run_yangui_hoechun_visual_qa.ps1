param(
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

# Manual acceptance lane by design: this captures a real Vulkan window and
# records hardware-local draw submission timings. See
# docs/yangui_hoechun_wave_visual_qa.md for the gate and CI rationale.

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "assert_no_interactive_godot_game.ps1")
$validationPriorityContext = $null
try {
    $validationPriorityContext = Assert-NoInteractiveGodotGame `
        -ProjectPath $ProjectPath `
        -OperationName "Yangui Hoechun Vulkan visual QA" `
        -AllowDuringPlay

    . (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
    . (Join-Path $PSScriptRoot "godot_output_classifier.ps1")
    $godot = Resolve-GodotConsolePath -GodotExe $GodotExe
    $qaPath = "res://tests/yangui_hoechun_visual_qa.gd"
    $okMarker = "yangui_hoechun_visual_qa: ok"
    $logDir = Join-Path $ProjectPath ".godot\codex_logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $timestamp = [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff")
    $logPath = Join-Path $logDir ("yangui_hoechun_visual_qa_{0}_{1}.log" -f $PID, $timestamp)

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $godot `
            --path $ProjectPath `
            --windowed `
            --resolution 760x750 `
            --rendering-method mobile `
            --rendering-driver vulkan `
            --log-file $logPath `
            -s $qaPath 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    $output | ForEach-Object { Write-Host $_ }
    $outputText = ($output | Out-String)
    $seriousErrors = @($output | Where-Object {
        Test-GodotSeriousErrorLine -Line $_.ToString()
    })
    $pixelSealCount = ([regex]::Matches($outputText, "\[YanguiPixelSeal\]")).Count
    if (
        $exitCode -ne 0 `
        -or $seriousErrors.Count -gt 0 `
        -or -not $outputText.Contains($okMarker) `
        -or -not $outputText.Contains("[YanguiVisualTimingSeal]") `
        -or -not $outputText.Contains("[YanguiCyanDominanceSeal]") `
        -or -not $outputText.Contains("[YanguiDrawBudgetSeal]") `
        -or -not $outputText.Contains("[YanguiVisualPaletteSeal]") `
        -or -not $outputText.Contains("yangui_hoechun_visual_qa: captures=6") `
        -or $pixelSealCount -ne 6
    ) {
        Write-Host "Yangui Hoechun visual QA log preserved for triage: $logPath"
        if ($exitCode -ne 0) {
            throw "$qaPath failed with exit code $exitCode"
        }
        if ($seriousErrors.Count -gt 0) {
            throw "$qaPath emitted a Godot error despite exit code 0"
        }
        throw "$qaPath did not emit every timing/cyan/budget/palette/pixel terminal marker"
    }
    Remove-Item -LiteralPath $logPath -Force
    if (-not (Get-ChildItem -LiteralPath $logDir -Force)) {
        Remove-Item -LiteralPath $logDir -Force
    }
    Write-Host "Yangui Hoechun Vulkan visual QA passed."
}
finally {
    Restore-GodotValidationPriority -Context $validationPriorityContext
}
