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
    full  (default) -> load check + warning scan + focused smokes ($focusedSmoke)
    all              -> load check + warning scan + FULL smoke suite (all
                        tests/*_smoke.gd discovered by run_smoke_tests.ps1;
                        slow, opt-in -- intended for big refactors before a push)
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
if ($Mode -notin @("full", "all", "light", "load")) {
    throw "Unknown GODOT_PREPUSH_MODE '$Mode' (expected full | all | light | load)"
}

# Keep this list in lockstep with FOCUSED_SMOKE_TESTS in
# .github/workflows/godot-ci.yml. The two are separate literal copies; if you
# add/remove a focused smoke, edit BOTH.
$focusedSmoke = @(
    "res://tests/project_resource_loader_import_preference_smoke.gd",
    "res://tests/battle_boot_resource_prewarm_smoke.gd",
    "res://tests/match_player_skill_deps_builder_smoke.gd",
    "res://tests/battle_scene_overlay_frame_perf_smoke.gd",
    "res://tests/weather_event_render_budget_smoke.gd",
    "res://tests/limit_league_tier_smoke.gd",
    "res://tests/stage7_akamu_prebattle_video_smoke.gd",
    "res://tests/stage7_akamu_prebattle_live_frame_smoke.gd",
    "res://tests/stage7_akamu_slice6_result_loading_smoke.gd",
    "res://tests/stage7_akamu_result_scene_smoke.gd",
    "res://tests/boss_skill_hud_gauge_cover_smoke.gd",
    "res://tests/stage_debug_picker_runtime_reset_smoke.gd",
    "res://tests/battle_playfield_effects_drawer_character_gate_smoke.gd"
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

    Invoke-Step "stage7 asset tool regression (python, 13 cases)" {
        # 코덱스 2026-07-14: 수동 게이트였던 자산 도구 봉인(스테이징 검증·
        # 정책 씰·승격/QA 우회 진입점 가드·E2E 라이브 센티널)을 프리푸시에 등재.
        $repoRoot = Split-Path (Split-Path $tools -Parent) -Parent
        $python = "C:\Users\woduq\AppData\Local\Programs\Python\Python312\python.exe"
        if (-not (Test-Path -LiteralPath $python)) { $python = "python" }
        & $python (Join-Path $repoRoot "tools\test_prepare_stage7_akamu_promotion.py")
        if ($LASTEXITCODE -ne 0) { throw "stage7 asset tool regression failed ($LASTEXITCODE)" }
    }

    if ($Mode -eq "full" -or $Mode -eq "all") {
        Invoke-Step "warning scan" {
            & (Join-Path $tools "run_warning_scan.ps1") -GodotExe $godot
        }
    } else {
        Write-Host ""
        Write-Host "--- warning scan SKIPPED (mode=$Mode) ---"
    }

    if ($Mode -eq "all") {
        Invoke-Step "full smoke suite (all *_smoke.gd)" {
            # No -Tests -> run_smoke_tests.ps1 globs every tests/*_smoke.gd.
            & (Join-Path $tools "run_smoke_tests.ps1") -GodotExe $godot
        }
    } elseif ($Mode -ne "load") {
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
