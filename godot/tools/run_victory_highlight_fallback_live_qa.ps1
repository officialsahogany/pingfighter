param(
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$previousAppData = $env:APPDATA
$qaAppDataRoot = Join-Path $ProjectPath (".godot\codex_userdata\victory_highlight_fallback_{0}_{1}" -f `
    $PID,
    [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff")
)

. (Join-Path $PSScriptRoot "assert_no_interactive_godot_game.ps1")
$validationPriorityContext = $null
try {
    $validationPriorityContext = Assert-NoInteractiveGodotGame `
        -ProjectPath $ProjectPath `
        -OperationName "Victory highlight continue revival live Vulkan QA" `
        -AllowDuringPlay

    . (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
    . (Join-Path $PSScriptRoot "godot_output_classifier.ps1")
    $godot = Resolve-GodotConsolePath -GodotExe $GodotExe
    New-Item -ItemType Directory -Force -Path $qaAppDataRoot | Out-Null
    $env:APPDATA = $qaAppDataRoot
    $qaPath = "res://tools/victory_highlight_fallback_live_qa.gd"
    $logDir = Join-Path $ProjectPath ".godot\codex_logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $logPath = Join-Path $logDir ("victory_highlight_fallback_live_qa_{0}_{1}.log" -f `
        $PID,
        [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff")
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $godot `
            --path $ProjectPath `
            --windowed `
            --resolution 1280x900 `
            --rendering-method mobile `
            --rendering-driver vulkan `
            --log-file $logPath `
            -s $qaPath `
            -- `
            --victory-highlight-frame-capture-debug 2>&1
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
    $qaFailures = @($output | Where-Object {
        $_.ToString().Contains("[VictoryHighlightFallbackLiveQA] FAILURE:")
    })
    $okMarker = "victory_highlight_fallback_live_qa: ok"
    if (
        $exitCode -ne 0 `
        -or $seriousErrors.Count -gt 0 `
        -or $qaFailures.Count -gt 0 `
        -or -not $outputText.Contains($okMarker)
    ) {
        Write-Host "Victory highlight fallback live QA log preserved for triage: $logPath"
        if ($exitCode -ne 0) {
            throw "$qaPath failed with exit code $exitCode"
        }
        if ($seriousErrors.Count -gt 0) {
            throw "$qaPath emitted a Godot error despite exit code 0"
        }
        if ($qaFailures.Count -gt 0) {
            throw "$qaPath emitted an explicit QA failure"
        }
        throw "$qaPath did not emit its terminal marker"
    }
    Write-Host "Victory highlight continue revival live Vulkan QA passed: log=$logPath"
}
finally {
    $env:APPDATA = $previousAppData
    Restore-GodotValidationPriority -Context $validationPriorityContext
}
