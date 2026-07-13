#requires -Version 5.1
<#
.SYNOPSIS
    Nightly FULL-suite smoke runner for 디스크하츠 - 링피아 (Godot).

.DESCRIPTION
    The automatic pre-push / CI gate only runs a small focused subset. This job
    closes that gap on a schedule: it runs the headless load check + the FULL
    smoke suite (all *_smoke.gd under godot/tests), captures the complete
    console output to a persistent timestamped log, records PASS/FAIL in
    LAST_RESULT.txt, prunes old logs, and exits with the suite's status.

    Non-blocking by design: a failure is logged for review, never pushed or
    committed. The GDScript warning scan is intentionally NOT run here -- it
    already runs on every real `git push` (pre-push `full` mode) and is the
    known intermittently-flaky step, which would add false FAILs to the log.

    Register it with install_nightly_smoke_task.ps1 (Windows Scheduled Task),
    or run on demand:
        powershell -ExecutionPolicy Bypass -File godot\tools\run_nightly_smoke.ps1

.PARAMETER GodotExe
    Explicit Godot console exe (forwarded to the sub-scripts). Falls back to the
    usual env / PATH / disk-search resolution.

.PARAMETER LogDir
    Where to write logs. Default: %LOCALAPPDATA%\LingpiaNightlySmoke (per-user,
    persistent, never committed).

.PARAMETER KeepLast
    Number of recent run logs to retain (default 30). Failing logs are retained
    like any other; only count-based pruning is applied.
#>
param(
    [string]$GodotExe = "",
    [string]$LogDir = "",
    [int]$KeepLast = 30
)

$ErrorActionPreference = "Stop"
$tools = $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($LogDir)) {
    $LogDir = Join-Path $env:LOCALAPPDATA "LingpiaNightlySmoke"
}
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$LogDir = (Resolve-Path -LiteralPath $LogDir).Path

$stamp = [DateTime]::Now.ToString("yyyyMMdd_HHmmss")
$logPath = Join-Path $LogDir ("nightly_smoke_{0}.log" -f $stamp)

. (Join-Path $tools "resolve_godot_exe.ps1")
$godot = Resolve-GodotConsolePath -GodotExe $GodotExe

$started = Get-Date
("=== 디스크하츠 - 링피아 nightly full smoke (load + all smokes): {0} ===" -f $stamp) | Tee-Object -FilePath $logPath
("Godot: {0}" -f $godot) | Tee-Object -FilePath $logPath -Append
("LogDir: {0}" -f $LogDir) | Tee-Object -FilePath $logPath -Append

function Invoke-Sub {
    param([string]$Name, [scriptblock]$Body)
    ("" ) | Tee-Object -FilePath $logPath -Append
    ("--- {0} ---" -f $Name) | Tee-Object -FilePath $logPath -Append
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $Body *>&1 | Tee-Object -FilePath $logPath -Append
        ("--- {0}: PASS ---" -f $Name) | Tee-Object -FilePath $logPath -Append
        return 0
    }
    catch {
        ("--- {0}: FAIL ({1}) ---" -f $Name, $_.Exception.Message) | Tee-Object -FilePath $logPath -Append
        return 1
    }
    finally {
        $ErrorActionPreference = $prev
    }
}

$loadResult = Invoke-Sub "headless load check" {
    & (Join-Path $tools "run_headless_load_check.ps1") -GodotExe $godot
}
$smokeResult = Invoke-Sub "full smoke suite (all *_smoke.gd)" {
    & (Join-Path $tools "run_smoke_tests.ps1") -GodotExe $godot
}

$code = if (($loadResult -eq 0) -and ($smokeResult -eq 0)) { 0 } else { 1 }
$elapsed = [int]((Get-Date) - $started).TotalSeconds
$result = if ($code -eq 0) { "PASS" } else { "FAIL" }
$summary = ("{0} | RESULT={1} EXIT={2} ELAPSED={3}s | LOG={4}" -f $stamp, $result, $code, $elapsed, $logPath)

("") | Tee-Object -FilePath $logPath -Append
("=== {0} ===" -f $summary) | Tee-Object -FilePath $logPath -Append
Set-Content -LiteralPath (Join-Path $LogDir "LAST_RESULT.txt") -Value $summary -Encoding UTF8

# Count-based prune (keep newest $KeepLast run logs).
Get-ChildItem -LiteralPath $LogDir -Filter "nightly_smoke_*.log" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -Skip $KeepLast |
    Remove-Item -Force -ErrorAction SilentlyContinue

exit $code
