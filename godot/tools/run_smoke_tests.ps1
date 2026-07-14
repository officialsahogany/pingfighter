param(
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string[]]$Tests = @()
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")

function Get-SmokeTests {
    if ($Tests.Count -gt 0) {
        return $Tests
    }

    $testsDir = Join-Path $ProjectPath "tests"
    if (-not (Test-Path -LiteralPath $testsDir -PathType Container)) {
        throw "Godot tests directory not found: $testsDir"
    }

    return Get-ChildItem -LiteralPath $testsDir -Filter "*_smoke.gd" |
        Sort-Object Name |
        ForEach-Object { "res://tests/$($_.Name)" }
}

function Invoke-GodotSmoke {
    param(
        [string]$GodotPath,
        [string]$SmokePath
    )

    Write-Host ""
    Write-Host "==> $SmokePath"
    $smokeLogDir = Join-Path $ProjectPath ".godot\codex_logs"
    New-Item -ItemType Directory -Force -Path $smokeLogDir | Out-Null
    $testSlug = ([System.IO.Path]::GetFileNameWithoutExtension($SmokePath)) -replace "[^A-Za-z0-9_.-]", "_"
    $smokeLogPath = Join-Path $smokeLogDir ("smoke_{0}_{1}_{2}.log" -f $testSlug, $PID, [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff"))
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $GodotPath --headless --path $ProjectPath --log-file $smokeLogPath -s $SmokePath 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
        if (Test-Path -LiteralPath $smokeLogPath -PathType Leaf) {
            Remove-Item -LiteralPath $smokeLogPath -Force
        }
        if ((Test-Path -LiteralPath $smokeLogDir -PathType Container) -and -not (Get-ChildItem -LiteralPath $smokeLogDir -Force)) {
            Remove-Item -LiteralPath $smokeLogDir -Force
        }
    }
    $output | ForEach-Object { Write-Host $_ }

    $outputText = ($output | Out-String)
    $seriousErrorLines = @($output | Where-Object {
        $line = $_.ToString()
        ($line -notmatch "Failed to read the root certificate store") -and
            (($line -match "^(SCRIPT ERROR|ERROR:|FATAL:)") -or
                ($line -match "(Parse Error|Compile Error|Failed to load script|Invalid call|GDScript backtrace)"))
    })
    $testName = [System.IO.Path]::GetFileNameWithoutExtension($SmokePath)
    $hasOkMarker = $outputText -match [regex]::Escape("${testName}: ok")
    # Opt-in leak gate: a smoke containing the literal marker
    # "expect-zero-object-leaks" fails when Godot reports leaked ObjectDB
    # instances at exit (the warning is otherwise ignored, so leak
    # regressions would stay silently GREEN).
    $expectZeroLeaks = $false
    $smokeLocalPath = Join-Path $ProjectPath ($SmokePath -replace '^res://', '')
    if (Test-Path -LiteralPath $smokeLocalPath -PathType Leaf) {
        $expectZeroLeaks = (Get-Content -LiteralPath $smokeLocalPath -Raw) -match 'expect-zero-object-leaks'
    }

    if ($exitCode -ne 0) {
        throw "$SmokePath failed with exit code $exitCode"
    }
    if ($seriousErrorLines.Count -gt 0) {
        throw "$SmokePath emitted a Godot error despite exit code 0"
    }
    if (-not $hasOkMarker) {
        throw "$SmokePath did not print its ok marker"
    }
    if ($expectZeroLeaks -and ($outputText -match 'ObjectDB instances leaked')) {
        throw "$SmokePath leaked ObjectDB instances at exit (expect-zero-object-leaks gate)"
    }
}

$godotPath = Resolve-GodotConsolePath -GodotExe $GodotExe
$smokeTests = @(Get-SmokeTests)

Write-Host "Godot: $godotPath"
Write-Host "Project: $ProjectPath"
Write-Host "Smoke count: $($smokeTests.Count)"

foreach ($smokeTest in $smokeTests) {
    Invoke-GodotSmoke -GodotPath $godotPath -SmokePath $smokeTest
}

Write-Host ""
Write-Host "All Godot smoke tests passed."
