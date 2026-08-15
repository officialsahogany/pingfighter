param(
    [string]$GodotExe = "C:\Users\woduq\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [int[]]$Seeds = @(4, 12),
    [int]$RunsPerSeed = 3
)

$ErrorActionPreference = "Stop"
$tests = @()
foreach ($seedValue in $Seeds) {
    foreach ($runValue in 1..$RunsPerSeed) {
        $tests += @{ Seed = [int]$seedValue; Run = [int]$runValue }
    }
}
$evidenceRoot = Join-Path $ProjectPath ".tmp\plaza_r3c_lifecycle_prewarm_vulkan"
$logRoot = Join-Path $ProjectPath ".godot\codex_logs"
New-Item -ItemType Directory -Force -Path $evidenceRoot, $logRoot | Out-Null
$metrics = @()

foreach ($test in $tests) {
    $seed = [int]$test.Seed
    $run = [int]$test.Run
    $logPath = Join-Path $logRoot ("plaza_r3c_cold_seed{0:D2}_run{1}.engine.log" -f $seed, $run)
    if (Test-Path -LiteralPath $logPath) {
        Remove-Item -LiteralPath $logPath -Force
    }
    Write-Host ("==> fresh Vulkan process seed={0} run={1}" -f $seed, $run)
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    # Verbose ObjectDB detail is mandatory for distinguishing a real retained
    # Node/Resource from Godot's zero-reference disposal notice at shutdown.
    $verbosityArgs = @("--verbose")
    $output = & $GodotExe @verbosityArgs `
        --path $ProjectPath `
        --rendering-method mobile `
        --rendering-driver vulkan `
        --log-file $logPath `
        --script res://tests/plaza_r3c_lifecycle_prewarm_vulkan_qa.gd `
        -- `
        "--plaza-r3c-seed=$seed" `
        "--plaza-r3c-run=$run" `
        --plaza-r3c-rendering-driver=vulkan `
        "--plaza-r3c-engine-log-path=$logPath" 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    $outputLines = @($output | ForEach-Object { "$_" })
    $outputText = $outputLines -join "`n"
    $outputLines | Where-Object {
        $_ -match '^Godot Engine ' -or
        $_ -match '^Vulkan ' -or
        $_ -match '^plaza_r3c_lifecycle_prewarm_vulkan_qa:'
    } | ForEach-Object { Write-Host $_ }
    $terminal = "plaza_r3c_lifecycle_prewarm_vulkan_qa: ok seed=$seed run=$run"
    if ($exitCode -ne 0 -or -not $outputText.Contains($terminal)) {
        throw "R3-C Vulkan QA failed for seed=$seed run=$run (exit=$exitCode)"
    }
    if ($outputText.Contains("SCRIPT ERROR:") -or $outputText.Contains("Parse Error:")) {
        throw "R3-C Vulkan QA emitted a script error for seed=$seed run=$run"
    }
    $zeroRefDisposalCount = 0
    if ($outputText.Contains("ObjectDB instances leaked")) {
        $leakedInstanceLines = @($outputLines | Where-Object { $_ -match '^Leaked instance:' })
        $invalidLeakLines = @($leakedInstanceLines | Where-Object {
            $_ -notmatch '^Leaked instance: RefCounted:[0-9]+ - Reference count: 0\s*$'
        })
        if ($leakedInstanceLines.Count -eq 0 -or $invalidLeakLines.Count -gt 0 -or $outputText.Contains("Resources still in use")) {
            throw "R3-C Vulkan QA retained a Node, Resource, or referenced ObjectDB instance for seed=$seed run=$run"
        }
        $zeroRefDisposalCount = $leakedInstanceLines.Count
        Write-Host ("R3-C Vulkan QA: engine zero-ref disposal notices={0} seed={1} run={2}" -f $zeroRefDisposalCount, $seed, $run)
    }
    $metricsPath = Join-Path $evidenceRoot ("seed_{0:D2}_run_{1}\metrics.json" -f $seed, $run)
    if (-not (Test-Path -LiteralPath $metricsPath)) {
        throw "R3-C Vulkan QA did not produce $metricsPath"
    }
    $record = Get-Content -LiteralPath $metricsPath -Raw | ConvertFrom-Json
    if (-not [bool]$record.pass) {
        throw "R3-C Vulkan metrics reported failure for seed=$seed run=$run"
    }
    $record | Add-Member -NotePropertyName engine_zero_ref_disposal_notice_count -NotePropertyValue $zeroRefDisposalCount
    $metrics += $record
}

if ($metrics.Count -ne ($Seeds.Count * $RunsPerSeed)) {
    throw "R3-C Vulkan QA fresh-process metric count mismatch, got $($metrics.Count)"
}
$summaryRuns = @()
foreach ($record in $metrics) {
    $cold = [int64]$record.cold_status.cold_prewarm_usec
    $warm = [int64]$record.warm_status.warm_prewarm_usec
    $activation = [int64]$record.window.r3_first_visible_activation_usec
    $wholeFrame = [int64]$record.window.whole_first_visible_frame_usec
    $changedSamples = [int64]$record.window.first_visible_changed_sample_pixels
    $p95 = [double]$record.owner_cadence.p95_usec
    $captureSha = [string]$record.capture.sha256
    if ($warm -gt $cold) { throw "warm prewarm exceeded cold prewarm" }
    if ($activation -gt 2000) { throw "first-visible R3 work exceeded 2ms" }
    if ($changedSamples -lt 1000) { throw "first-visible R3 pixel sentinel was empty" }
    if ($p95 -ge 2000.0) { throw "owner cadence p95 exceeded 2ms" }
    if ($captureSha.Length -ne 64) { throw "first-visible capture SHA-256 was missing" }
    $summaryRuns += [ordered]@{
        seed = [int]$record.map_seed
        run = [int]$record.run_index
        cold_prewarm_usec = $cold
        warm_prewarm_usec = $warm
        first_visible_r3_usec = $activation
        whole_first_visible_frame_usec = $wholeFrame
        first_visible_changed_sample_pixels = $changedSamples
        owner_cadence_p95_usec = $p95
        capture_sha256 = $captureSha
        engine_zero_ref_disposal_notice_count = [int]$record.engine_zero_ref_disposal_notice_count
    }
}
$seedCaptureHashes = [ordered]@{}
foreach ($seedValue in $Seeds) {
    $hashes = @($summaryRuns | Where-Object { $_.seed -eq $seedValue } | ForEach-Object { $_.capture_sha256 } | Sort-Object -Unique)
    if ($hashes.Count -ne 1) {
        throw "same-seed first-visible capture was not deterministic for seed=$seedValue"
    }
    $seedCaptureHashes[[string]$seedValue] = $hashes[0]
}
if ($Seeds.Count -gt 1) {
    $crossSeedHashes = @($seedCaptureHashes.Values | Sort-Object -Unique)
    if ($crossSeedHashes.Count -ne $Seeds.Count) {
        throw "different seeds produced the same first-visible capture"
    }
}
$aggregate = [ordered]@{
    schema = "plaza_r3c_cold_vulkan_aggregate_v1"
    pass = $true
    fresh_process_count = $metrics.Count
    seeds = $Seeds
    runs_per_seed = $RunsPerSeed
    seed_capture_sha256 = $seedCaptureHashes
    engine_zero_ref_disposal_notice_count = [int](($summaryRuns | ForEach-Object { [int]$_['engine_zero_ref_disposal_notice_count'] } | Measure-Object -Sum).Sum)
    runs = $summaryRuns
}
$aggregatePath = Join-Path $evidenceRoot "aggregate_metrics.json"
$aggregate | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $aggregatePath -Encoding utf8
Write-Host ("plaza_r3c_cold_vulkan_aggregate: ok fresh_processes={0}" -f $metrics.Count)
Write-Host "Evidence: $aggregatePath"
