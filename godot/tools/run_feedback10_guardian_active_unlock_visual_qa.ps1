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
        -OperationName "Feedback10 Guardian active unlock Vulkan visual QA" `
        -AllowDuringPlay

    . (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
    . (Join-Path $PSScriptRoot "godot_output_classifier.ps1")
    $godot = Resolve-GodotConsolePath -GodotExe $GodotExe
    $qaPath = "res://tools/feedback10_guardian_active_unlock_visual_qa.gd"
    $logDir = Join-Path $ProjectPath ".godot\codex_logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $logPath = Join-Path $logDir ("feedback10_guardian_active_unlock_visual_qa_{0}_{1}.log" -f $PID, [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff"))

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $godot `
            --path $ProjectPath `
            --windowed `
            --rendering-method mobile `
            --rendering-driver vulkan `
            --resolution 2020x1246 `
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
    $captureDir = Join-Path $ProjectPath ".godot\codex_captures"
    $tabCapture = Join-Path $captureDir "feedback10_guardian_active_unlock_tab.png"
    $railCapture = Join-Path $captureDir "feedback10_guardian_active_unlock_rail.png"
    if (
        $exitCode -ne 0 `
        -or $seriousErrors.Count -gt 0 `
        -or -not $outputText.Contains("feedback10_guardian_active_unlock_visual_qa: TAB_ACTIVE_CARDS=2 RAIL_CARDS=2") `
        -or -not $outputText.Contains("feedback10_guardian_active_unlock_visual_qa: captures=feedback10_guardian_active_unlock_tab.png,feedback10_guardian_active_unlock_rail.png") `
        -or -not $outputText.Contains("feedback10_guardian_active_unlock_visual_qa: ok") `
        -or -not (Test-Path -LiteralPath $tabCapture -PathType Leaf) `
        -or -not (Test-Path -LiteralPath $railCapture -PathType Leaf)
    ) {
        Write-Host "Feedback10 Guardian active unlock visual QA log preserved for triage: $logPath"
        if ($exitCode -ne 0) { throw "$qaPath failed with exit code $exitCode" }
        if ($seriousErrors.Count -gt 0) { throw "$qaPath emitted a Godot error despite exit code 0" }
        throw "$qaPath did not emit its terminal markers or captures"
    }
    Remove-Item -LiteralPath $logPath -Force
    if (-not (Get-ChildItem -LiteralPath $logDir -Force)) {
        Remove-Item -LiteralPath $logDir -Force
    }
    Write-Host "Feedback10 Guardian active unlock Vulkan visual QA passed."
}
finally {
    Restore-GodotValidationPriority -Context $validationPriorityContext
}
