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
        -OperationName "Feedback12 R6 Laurel leaf count Vulkan visual QA" `
        -AllowDuringPlay

    . (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
    . (Join-Path $PSScriptRoot "godot_output_classifier.ps1")
    $godot = Resolve-GodotConsolePath -GodotExe $GodotExe
    $qaPath = "res://tools/feedback12_r6_laurel_leaf_count_visual_qa.gd"
    $logDir = Join-Path $ProjectPath ".godot\codex_logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $logPath = Join-Path $logDir ("feedback12_r6_laurel_leaf_count_visual_qa_{0}_{1}.log" -f $PID, [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff"))
    if ([string]::IsNullOrWhiteSpace($OutputDir)) {
        $OutputDir = Join-Path $ProjectPath ".godot\codex_artifacts\feedback12_r6_laurel_leaf_count"
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
    $captures = @(
        (Join-Path $OutputDir "feedback12_r6_rank_1_leaves_1_2020x1246.png"),
        (Join-Path $OutputDir "feedback12_r6_rank_2_leaves_2_2020x1246.png"),
        (Join-Path $OutputDir "feedback12_r6_rank_3_leaves_3_2020x1246.png")
    )
    $missingCapture = @($captures | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) })
    if (
        $exitCode -ne 0 `
        -or $seriousErrors.Count -gt 0 `
        -or -not $outputText.Contains("feedback12_r6_laurel_leaf_count_visual_qa: captures=3") `
        -or -not $outputText.Contains("feedback12_r6_laurel_leaf_count_visual_qa: ok") `
        -or $missingCapture.Count -gt 0
    ) {
        Write-Host "Feedback12 R6 visual QA log preserved for triage: $logPath"
        if ($exitCode -ne 0) { throw "$qaPath failed with exit code $exitCode" }
        if ($seriousErrors.Count -gt 0) { throw "$qaPath emitted a Godot error despite exit code 0" }
        throw "$qaPath did not emit its terminal markers or captures"
    }
    Remove-Item -LiteralPath $logPath -Force
    if (-not (Get-ChildItem -LiteralPath $logDir -Force)) {
        Remove-Item -LiteralPath $logDir -Force
    }
    Write-Host "Feedback12 R6 Laurel leaf count Vulkan visual QA passed: $OutputDir"
}
finally {
    Restore-GodotValidationPriority -Context $validationPriorityContext
}
