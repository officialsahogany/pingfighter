param(
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [ValidateSet("phase1", "phase2")]
    [string]$Phase = "phase1",
    [ValidateRange(-1.0, 1.0)]
    [double]$Progress = -1.0,
    [switch]$MissingIcon
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "assert_no_interactive_godot_game.ps1")
$validationPriorityContext = $null
try {
    $validationPriorityContext = Assert-NoInteractiveGodotGame `
        -ProjectPath $ProjectPath `
        -OperationName "Tower-ascent combat map-overlay Vulkan visual QA" `
        -AllowDuringPlay

    . (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
    . (Join-Path $PSScriptRoot "godot_output_classifier.ps1")
    $godot = Resolve-GodotConsolePath -GodotExe $GodotExe
    $qaPath = "res://tools/tower_ascent_map_overlay_visual_qa.gd"
    $logDir = Join-Path $ProjectPath ".godot\codex_logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $logPath = Join-Path $logDir ("tower_map_overlay_visual_qa_{0}_{1}.log" -f $PID, [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff"))

    $previousErrorActionPreference = $ErrorActionPreference
    $previousCapturePhase = $env:TOWER_ASCENT_MAP_QA_PHASE
	$previousCaptureProgress = $env:TOWER_ASCENT_MAP_QA_PROGRESS
    $previousMissingIcon = $env:TOWER_ASCENT_MAP_QA_MISSING_ICON
    $env:TOWER_ASCENT_MAP_QA_PHASE = $Phase
	$env:TOWER_ASCENT_MAP_QA_PROGRESS = if ($Progress -lt 0.0) { "" } else { $Progress.ToString([System.Globalization.CultureInfo]::InvariantCulture) }
    $env:TOWER_ASCENT_MAP_QA_MISSING_ICON = if ($MissingIcon) { "1" } else { "0" }
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
        $env:TOWER_ASCENT_MAP_QA_PHASE = $previousCapturePhase
		$env:TOWER_ASCENT_MAP_QA_PROGRESS = $previousCaptureProgress
        $env:TOWER_ASCENT_MAP_QA_MISSING_ICON = $previousMissingIcon
    }

    $output | ForEach-Object { Write-Host $_ }
    $outputText = ($output | Out-String)
    $seriousErrors = @($output | Where-Object {
        Test-GodotSeriousErrorLine -Line $_.ToString()
    })
    $okMarker = "tower_ascent_map_overlay_visual_qa: ok"
    if ($exitCode -ne 0 -or $seriousErrors.Count -gt 0 -or -not $outputText.Contains($okMarker)) {
        Write-Host "Tower map-overlay visual QA log preserved for triage: $logPath"
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
    Write-Host "Tower-ascent map-overlay Vulkan visual QA passed."
}
finally {
    Restore-GodotValidationPriority -Context $validationPriorityContext
}
