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
        -OperationName "Guardian spring presentation Vulkan visual QA" `
        -AllowDuringPlay

    . (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
    . (Join-Path $PSScriptRoot "godot_output_classifier.ps1")
    $godot = Resolve-GodotConsolePath -GodotExe $GodotExe
    $qaPath = "res://tools/tower_guardian_spring_presentation_visual_qa.gd"
    $logDir = Join-Path $ProjectPath ".godot\codex_logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $logPath = Join-Path $logDir ("guardian_spring_presentation_visual_qa_{0}_{1}.log" -f $PID, [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff"))

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $godot `
            --path $ProjectPath `
            --windowed `
            --rendering-method mobile `
            --rendering-driver vulkan `
            --resolution 760x750 `
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
    if (
        $exitCode -ne 0 `
        -or $seriousErrors.Count -gt 0 `
        -or -not $outputText.Contains("tower_guardian_spring_presentation_visual_qa: GLOW_OUTSIDE_SILHOUETTE_PIXELS=0") `
        -or -not $outputText.Contains("tower_guardian_spring_presentation_visual_qa: CHOSIK_SWAP_DELTA_PIXELS=") `
        -or -not $outputText.Contains("ESC_RESTORE_DELTA_PIXELS=0") `
        -or -not $outputText.Contains("DIM_CORNER_PIXELS=") `
        -or -not $outputText.Contains("MIN_ICON_TEXT_GAP_PX=") `
        -or -not $outputText.Contains("tower_guardian_spring_presentation_visual_qa: DRAW_TOWER_FULLSCREEN_MAP_ABSORB_MID_AVG_USEC=") `
        -or -not $outputText.Contains("tower_guardian_spring_presentation_visual_qa: captures=first_visit_hidden_cards.png,palm_ascend_mid.png,palm_reveal.png,palm_confirmation.png,palm_absorb_mid.png,palm_impact.png,prayer_glow_mid.png,prayer_result.png,capsules_t0.png,capsules_t1.png,chosik_swap_dialog.png,chosik_swap_escape_restored.png") `
        -or -not $outputText.Contains("tower_guardian_spring_presentation_visual_qa: ok")
    ) {
        Write-Host "Guardian spring presentation visual QA log preserved for triage: $logPath"
        if ($exitCode -ne 0) { throw "$qaPath failed with exit code $exitCode" }
        if ($seriousErrors.Count -gt 0) { throw "$qaPath emitted a Godot error despite exit code 0" }
        throw "$qaPath did not emit its terminal markers"
    }
    Remove-Item -LiteralPath $logPath -Force
    if (-not (Get-ChildItem -LiteralPath $logDir -Force)) {
        Remove-Item -LiteralPath $logDir -Force
    }
    Write-Host "Guardian spring presentation Vulkan visual QA passed."
}
finally {
    Restore-GodotValidationPriority -Context $validationPriorityContext
}
