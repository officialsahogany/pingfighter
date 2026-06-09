#requires -Version 5.1
<#
.SYNOPSIS
    Local pre-push gate for the Godot project (디스크하츠 - 링피아).

.DESCRIPTION
    Runs the same checks as .github/workflows/godot-ci.yml so regressions are
    caught locally instead of waiting on (or paying LFS quota for) GitHub
    Actions: headless load check, GDScript warning scan, and the focused smoke
    set. Reuses the existing tools/run_*.ps1 scripts and resolves the Godot
    binary once so every step shares it.

    Invoked automatically by .git/hooks/pre-push (only when the pushed commits
    touch godot/). Can also be run on demand:

        powershell -ExecutionPolicy Bypass -File godot\tools\run_pre_push_checks.ps1

.PARAMETER GodotExe
    Explicit Godot console exe. Falls back to $env:GODOT_CONSOLE_EXE /
    $env:GODOT_EXE / PATH / disk search via resolve_godot_exe.ps1.

.PARAMETER Mode
    full  (default) -> load check + warning scan + focused smokes
    light            -> load check + focused smokes (skip warning scan)
    load             -> load check only
    Also read from $env:GODOT_PREPUSH_MODE.
#>
param(
    [string]$GodotExe = "",
    [string]$Mode = ""
)

$ErrorActionPreference = "Stop"
$tools = $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($Mode)) { $Mode = $env:GODOT_PREPUSH_MODE }
if ([string]::IsNullOrWhiteSpace($Mode)) { $Mode = "full" }
$Mode = $Mode.ToLowerInvariant()
if ($Mode -notin @("full", "light", "load")) {
    throw "Unknown GODOT_PREPUSH_MODE '$Mode' (expected full | light | load)"
}

$focusedSmoke = @(
    "res://tests/project_resource_loader_import_preference_smoke.gd",
    "res://tests/battle_boot_resource_prewarm_smoke.gd",
    "res://tests/match_player_skill_deps_builder_smoke.gd",
    "res://tests/battle_scene_overlay_frame_perf_smoke.gd",
    "res://tests/weather_event_render_budget_smoke.gd"
)

# Resolve Godot once and reuse for every step (avoids 3x disk search).
. (Join-Path $tools "resolve_godot_exe.ps1")
$godot = Resolve-GodotConsolePath -GodotExe $GodotExe

$started = Get-Date
Write-Host "=== Godot pre-push checks (mode=$Mode) ==="
Write-Host "Godot: $godot"

function Invoke-Step {
    param([string]$Name, [scriptblock]$Body)
    Write-Host ""
    Write-Host "--- $Name ---"
    $t0 = Get-Date
    & $Body
    $dt = [int]((Get-Date) - $t0).TotalSeconds
    Write-Host ("--- $Name OK ({0}s) ---" -f $dt)
}

try {
    Invoke-Step "headless load check" {
        & (Join-Path $tools "run_headless_load_check.ps1") -GodotExe $godot
    }

    if ($Mode -eq "full") {
        Invoke-Step "warning scan" {
            & (Join-Path $tools "run_warning_scan.ps1") -GodotExe $godot
        }
    } else {
        Write-Host ""
        Write-Host "--- warning scan SKIPPED (mode=$Mode) ---"
    }

    if ($Mode -ne "load") {
        Invoke-Step ("focused smoke ({0})" -f $focusedSmoke.Count) {
            & (Join-Path $tools "run_smoke_tests.ps1") -GodotExe $godot -Tests $focusedSmoke
        }
    } else {
        Write-Host ""
        Write-Host "--- focused smoke SKIPPED (mode=load) ---"
    }
}
catch {
    $elapsed = [int]((Get-Date) - $started).TotalSeconds
    Write-Host ""
    Write-Host ("=== Godot pre-push checks FAILED after {0}s ===" -f $elapsed) -ForegroundColor Red
    Write-Host ("    {0}" -f $_.Exception.Message) -ForegroundColor Red
    Write-Host "    (bypass once with: SKIP_GODOT_PREPUSH=1 git push   or   git push --no-verify)"
    exit 1
}

$elapsed = [int]((Get-Date) - $started).TotalSeconds
Write-Host ""
Write-Host ("=== Godot pre-push checks PASSED ({0}s) ===" -f $elapsed) -ForegroundColor Green
exit 0
