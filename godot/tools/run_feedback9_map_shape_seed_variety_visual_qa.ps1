param(
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [int[]]$Seeds = @(1009, 8928, 16847)
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "assert_no_interactive_godot_game.ps1")
. (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
. (Join-Path $PSScriptRoot "godot_output_classifier.ps1")

$validationPriorityContext = $null
$caller = [System.Diagnostics.Process]::GetCurrentProcess()
$originalPriority = $caller.PriorityClass
$previousSeed = $env:TOWER_ASCENT_MAP_QA_SEED
$previousPhase = $env:TOWER_ASCENT_MAP_QA_PHASE
$previousMissingIcon = $env:TOWER_ASCENT_MAP_QA_MISSING_ICON
$previousProgress = $env:TOWER_ASCENT_MAP_QA_PROGRESS

try {
    $validationPriorityContext = Assert-NoInteractiveGodotGame `
        -ProjectPath $ProjectPath `
        -OperationName "Feedback 9 map-shape seed-variety Vulkan QA" `
        -AllowDuringPlay
    if ($caller.PriorityClass -notin @('BelowNormal', 'Idle')) {
        $caller.PriorityClass = 'BelowNormal'
    }
    if ($caller.PriorityClass -notin @('BelowNormal', 'Idle')) {
        throw "Feedback 9 map-shape seed-variety Vulkan QA requires BelowNormal priority"
    }
    Write-Host "Validation priority: $($caller.PriorityClass)"

    $godotPath = Resolve-GodotConsolePath -GodotExe $GodotExe
    $logDir = Join-Path $ProjectPath "logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $captureDir = Join-Path $ProjectPath ".godot\codex_captures\tower_map_overlay"
    $env:TOWER_ASCENT_MAP_QA_PHASE = "phase1"
    $env:TOWER_ASCENT_MAP_QA_MISSING_ICON = "0"
    $env:TOWER_ASCENT_MAP_QA_PROGRESS = ""

    foreach ($seed in $Seeds) {
        $env:TOWER_ASCENT_MAP_QA_SEED = [string]$seed
        $logPath = Join-Path $logDir (
            "feedback9_map_shape_seed_{0}_{1}_{2}.log" -f `
                $seed, $PID, [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff")
        )
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $output = & $godotPath `
                --path $ProjectPath `
                --log-file $logPath `
                -s res://tools/tower_ascent_map_overlay_visual_qa.gd 2>&1
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
        $output | ForEach-Object { Write-Host $_ }
        if ($exitCode -ne 0) {
            throw "seed $seed Vulkan QA failed with exit code $exitCode (log: $logPath)"
        }
        $seriousErrors = @($output | Where-Object {
            Test-GodotSeriousErrorLine -Line $_.ToString()
        })
        if ($seriousErrors.Count -gt 0) {
            throw "seed $seed Vulkan QA emitted a Godot error (log: $logPath)"
        }
        $outputText = $output | Out-String
        if ($outputText -notmatch 'tower_ascent_map_overlay_visual_qa: ok') {
            throw "seed $seed Vulkan QA did not print its ok marker (log: $logPath)"
        }
        $capturePath = Join-Path $captureDir "map_overlay_human_realm_seed_$seed.png"
        if (-not (Test-Path -LiteralPath $capturePath -PathType Leaf)) {
            throw "seed $seed Vulkan QA did not materialize capture: $capturePath"
        }
        Write-Host "Capture: $capturePath"
        Write-Host "Log: $logPath"
    }
    Write-Host "Feedback 9 map-shape seed-variety Vulkan QA passed."
}
finally {
    $env:TOWER_ASCENT_MAP_QA_SEED = $previousSeed
    $env:TOWER_ASCENT_MAP_QA_PHASE = $previousPhase
    $env:TOWER_ASCENT_MAP_QA_MISSING_ICON = $previousMissingIcon
    $env:TOWER_ASCENT_MAP_QA_PROGRESS = $previousProgress
    Restore-GodotValidationPriority -Context $validationPriorityContext
    if ($caller.PriorityClass -ne $originalPriority) {
        $caller.PriorityClass = $originalPriority
    }
}
