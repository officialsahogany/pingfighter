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
        -OperationName "Boss skillcard cooldown motion Vulkan visual QA" `
        -AllowDuringPlay

    . (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
    . (Join-Path $PSScriptRoot "godot_output_classifier.ps1")
    $godot = Resolve-GodotConsolePath -GodotExe $GodotExe
    $qaPath = "res://tools/boss_skill_card_cooldown_motion_visual_qa.gd"
    $logDir = Join-Path $ProjectPath ".godot\codex_logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $logPath = Join-Path $logDir ("boss_skill_card_cooldown_motion_visual_qa_{0}_{1}.log" -f `
        $PID,
        [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff")
    )

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
    $okMarker = "boss_skill_card_cooldown_motion_visual_qa: ok"
    if ($exitCode -ne 0 -or $seriousErrors.Count -gt 0 -or -not $outputText.Contains($okMarker)) {
        Write-Host "Boss skillcard cooldown motion visual QA log preserved for triage: $logPath"
        if ($exitCode -ne 0) {
            throw "$qaPath failed with exit code $exitCode"
        }
        if ($seriousErrors.Count -gt 0) {
            throw "$qaPath emitted a Godot error despite exit code 0"
        }
        throw "$qaPath did not emit its ok marker"
    }
    Remove-Item -LiteralPath $logPath -Force
    if (-not (Get-ChildItem -LiteralPath $logDir -Force)) {
        Remove-Item -LiteralPath $logDir -Force
    }
    Write-Host "Boss skillcard cooldown motion Vulkan visual QA passed: 5 bosses x 5 sequential frames."
}
finally {
    Restore-GodotValidationPriority -Context $validationPriorityContext
}
