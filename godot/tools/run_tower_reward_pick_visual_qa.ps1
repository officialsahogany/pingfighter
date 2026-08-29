param(
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "assert_no_interactive_godot_game.ps1")
$validationPriorityContext = $null
try {
    $validationPriorityContext = Assert-NoInteractiveGodotGame `
        -ProjectPath $ProjectPath `
        -OperationName "Tower reward-pick Vulkan visual QA" `
        -AllowDuringPlay

    . (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
    . (Join-Path $PSScriptRoot "godot_output_classifier.ps1")
    $godot = Resolve-GodotConsolePath -GodotExe $GodotExe
    $qaPath = "res://tools/tower_reward_pick_visual_qa.gd"
    $logDir = Join-Path $ProjectPath ".godot\codex_logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $logPath = Join-Path $logDir ("tower_reward_pick_visual_qa_{0}_{1}.log" -f $PID, [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff"))

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $godot `
            --path $ProjectPath `
            --windowed `
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
    $okMarker = "tower_reward_pick_visual_qa: ok"
    $stableSlotMarker = "tower_reward_pick_visual_qa: stable_slot_captures=3"
    $legacyCaptureMarker = "tower_reward_pick_visual_qa: legacy_captures=10"
    $z16CaptureMarker = "tower_reward_pick_visual_qa: z16_captures=5"
    $captureMarker = "tower_reward_pick_visual_qa: captures=15"
    $chosikHoverMarker = "tower_reward_pick_visual_qa: chosik_hover_target=five_orb_hud mugong_ledger_landing=-1"
    if (
        $exitCode -ne 0 `
        -or $seriousErrors.Count -gt 0 `
        -or -not $outputText.Contains($okMarker) `
        -or -not $outputText.Contains($stableSlotMarker) `
        -or -not $outputText.Contains($legacyCaptureMarker) `
        -or -not $outputText.Contains($z16CaptureMarker) `
        -or -not $outputText.Contains($captureMarker) `
        -or -not $outputText.Contains($chosikHoverMarker)
    ) {
        Write-Host "Tower reward-pick visual QA log preserved for triage: $logPath"
        if ($exitCode -ne 0) {
            throw "$qaPath failed with exit code $exitCode"
        }
        if ($seriousErrors.Count -gt 0) {
            throw "$qaPath emitted a Godot error despite exit code 0"
        }
        throw "$qaPath did not emit its ten legacy plus five Z16 capture markers"
    }
    Remove-Item -LiteralPath $logPath -Force
    if (-not (Get-ChildItem -LiteralPath $logDir -Force)) {
        Remove-Item -LiteralPath $logDir -Force
    }
    Write-Host "Tower reward-pick Vulkan visual QA passed."
}
finally {
    Restore-GodotValidationPriority -Context $validationPriorityContext
}
