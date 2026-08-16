param(
    [string]$GodotExe = "C:\Users\woduq\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "assert_no_interactive_godot_game.ps1")
$validationPriorityContext = $null
try {
$validationPriorityContext = Assert-NoInteractiveGodotGame -ProjectPath $ProjectPath -OperationName "R3-D production Vulkan QA" -AllowDuringPlay
$logRoot = Join-Path $ProjectPath ".godot\codex_logs"
$evidenceRoot = Join-Path $ProjectPath ".tmp\plaza_r3d_production_transition_vulkan"
New-Item -ItemType Directory -Force -Path $logRoot, $evidenceRoot | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
$logPath = Join-Path $logRoot "plaza_r3d_production_vulkan_$stamp.engine.log"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$output = & $GodotExe --verbose `
    --path $ProjectPath `
    --rendering-method mobile `
    --rendering-driver vulkan `
    --log-file $logPath `
    --script res://tests/plaza_r3d_production_transition_vulkan_qa.gd `
    -- `
    --plaza-r3d-rendering-driver=vulkan `
    "--plaza-r3d-engine-log-path=$logPath" 2>&1
$exitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
$outputLines = @($output | ForEach-Object { "$_" })
$outputText = $outputLines -join "`n"
$outputLines | Where-Object {
    $_ -match '^Godot Engine ' -or
    $_ -match '^Vulkan ' -or
    $_ -match '^plaza_r3d_production_transition_vulkan_qa:'
} | ForEach-Object { Write-Host $_ }

$terminal = "plaza_r3d_production_transition_vulkan_qa: ok"
if ($exitCode -ne 0 -or -not $outputText.Contains($terminal)) {
    throw "R3-D production Vulkan QA failed (exit=$exitCode, log=$logPath)"
}
if ($outputText.Contains("SCRIPT ERROR:") -or $outputText.Contains("Parse Error:")) {
    throw "R3-D production Vulkan QA emitted a script error (log=$logPath)"
}
if ($outputText.Contains("ObjectDB instances leaked")) {
    $leakedLines = @($outputLines | Where-Object { $_ -match '^Leaked instance:' })
    $invalidLines = @($leakedLines | Where-Object {
        $_ -notmatch '^Leaked instance: RefCounted:[0-9]+ - Reference count: 0\s*$'
    })
    if ($leakedLines.Count -eq 0 -or $invalidLines.Count -gt 0 -or $outputText.Contains("Resources still in use")) {
        throw "R3-D production Vulkan QA retained a Node, Resource, or referenced ObjectDB instance"
    }
    Write-Host ("R3-D Vulkan QA: engine zero-ref disposal notices={0}" -f $leakedLines.Count)
}

$metricsPath = Join-Path $evidenceRoot "metrics.json"
if (-not (Test-Path -LiteralPath $metricsPath)) {
    throw "R3-D production Vulkan QA did not produce $metricsPath"
}
$metrics = Get-Content -LiteralPath $metricsPath -Raw | ConvertFrom-Json
if (-not [bool]$metrics.pass) {
    throw "R3-D production Vulkan metrics reported failure"
}
if ([int]$metrics.map_seed -ne 12) {
    throw "R3-D production Vulkan metrics lost the stage_map_seed"
}
if ([double]$metrics.cadence.p95_usec -ge 2000.0) {
    throw "R3-D production Vulkan owner cadence p95 exceeded 2ms"
}
if ([int64]$metrics.timeline.loading_to_exterior_changed_samples -lt 1000) {
    throw "R3-D loading-to-exterior pixel transition was vacuous"
}
if ([string]$metrics.capture_sha256.loading -notmatch '^[0-9a-f]{64}$' -or
    [string]$metrics.capture_sha256.exterior -notmatch '^[0-9a-f]{64}$') {
    throw "R3-D production capture SHA-256 evidence is incomplete"
}

Write-Host ("plaza_r3d_production_vulkan: ok p95_usec={0} changed_samples={1}" -f `
    $metrics.cadence.p95_usec, $metrics.timeline.loading_to_exterior_changed_samples)
Write-Host "Evidence: $evidenceRoot"
}
finally {
    Restore-GodotValidationPriority -Context $validationPriorityContext
}
