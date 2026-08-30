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
        -OperationName "Feedback12 R4 Chosik ready glow Vulkan visual QA" `
        -AllowDuringPlay

    . (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
    . (Join-Path $PSScriptRoot "godot_output_classifier.ps1")
    $godot = Resolve-GodotConsolePath -GodotExe $GodotExe
    $qaPath = "res://tools/feedback12_r4_chosik_ready_glow_visual_qa.gd"
    $logDir = Join-Path $ProjectPath ".godot\codex_logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $logPath = Join-Path $logDir ("feedback12_r4_chosik_ready_glow_visual_qa_{0}_{1}.log" -f $PID, [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff"))
    if ([string]::IsNullOrWhiteSpace($OutputDir)) {
        $OutputDir = Join-Path $ProjectPath ".godot\codex_artifacts\feedback12_r4_chosik_ready_glow"
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
    $readyCapture = Join-Path $OutputDir "feedback12_r4_ready_2020x1246.png"
    $unavailableCapture = Join-Path $OutputDir "feedback12_r4_unavailable_2020x1246.png"
    if (
        $exitCode -ne 0 `
        -or $seriousErrors.Count -gt 0 `
        -or -not $outputText.Contains("feedback12_r4_chosik_ready_glow_visual_qa: captures=2") `
        -or -not $outputText.Contains("feedback12_r4_chosik_ready_glow_visual_qa: ok") `
        -or -not (Test-Path -LiteralPath $readyCapture -PathType Leaf) `
        -or -not (Test-Path -LiteralPath $unavailableCapture -PathType Leaf)
    ) {
        Write-Host "Feedback12 R4 visual QA log preserved for triage: $logPath"
        if ($exitCode -ne 0) { throw "$qaPath failed with exit code $exitCode" }
        if ($seriousErrors.Count -gt 0) { throw "$qaPath emitted a Godot error despite exit code 0" }
        throw "$qaPath did not emit its terminal markers or captures"
    }
    Remove-Item -LiteralPath $logPath -Force
    if (-not (Get-ChildItem -LiteralPath $logDir -Force)) {
        Remove-Item -LiteralPath $logDir -Force
    }
    Write-Host "Feedback12 R4 Chosik ready glow Vulkan visual QA passed: $OutputDir"
}
finally {
    Restore-GodotValidationPriority -Context $validationPriorityContext
}
