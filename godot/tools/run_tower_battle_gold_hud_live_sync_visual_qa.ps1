param(
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "assert_no_interactive_godot_game.ps1")
$validationPriorityContext = $null
try {
    $validationPriorityContext = Assert-NoInteractiveGodotGame `
        -ProjectPath $ProjectPath `
        -OperationName "Tower battle gold HUD live-sync Vulkan QA" `
        -AllowDuringPlay

    . (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
    . (Join-Path $PSScriptRoot "godot_output_classifier.ps1")
    $godot = Resolve-GodotConsolePath -GodotExe $GodotExe
    $qaPath = "res://tools/tower_battle_gold_hud_live_sync_visual_qa.gd"
    $logDir = Join-Path $ProjectPath ".godot\codex_logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $logPath = Join-Path $logDir ("tower_battle_gold_hud_live_sync_visual_qa_{0}_{1}.log" -f $PID, [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff"))
    if ([string]::IsNullOrWhiteSpace($OutputDir)) {
        $OutputDir = Join-Path $ProjectPath ".godot\codex_artifacts\tower_battle_gold_hud_live_sync"
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $godot `
            --path $ProjectPath `
            --windowed `
            --resolution 2020x1246 `
            --rendering-method mobile `
            --rendering-driver vulkan `
            --log-file $logPath `
            -s $qaPath `
            -- `
            "--output-dir=$OutputDir" 2>&1
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
    $captureMarker = "tower_battle_gold_hud_live_sync_visual_qa: captures=3"
    $valueMarker = "tower_battle_gold_hud_live_sync_visual_qa: gold_before=0 gold_after=120 shop_gold=120 muhon=17"
    $okMarker = "tower_battle_gold_hud_live_sync_visual_qa: ok"
    if (
        $exitCode -ne 0 `
        -or $seriousErrors.Count -gt 0 `
        -or -not $outputText.Contains($captureMarker) `
        -or -not $outputText.Contains($valueMarker) `
        -or -not $outputText.Contains($okMarker)
    ) {
        Write-Host "Tower battle gold live-sync visual QA log preserved for triage: $logPath"
        if ($exitCode -ne 0) {
            throw "$qaPath failed with exit code $exitCode"
        }
        if ($seriousErrors.Count -gt 0) {
            throw "$qaPath emitted a Godot error despite exit code 0"
        }
        throw "$qaPath did not emit its capture and live-value terminal markers"
    }
    Remove-Item -LiteralPath $logPath -Force
    if (-not (Get-ChildItem -LiteralPath $logDir -Force)) {
        Remove-Item -LiteralPath $logDir -Force
    }
    Write-Host "Tower battle gold HUD live-sync Vulkan QA passed: $OutputDir"
}
finally {
    Restore-GodotValidationPriority -Context $validationPriorityContext
}
