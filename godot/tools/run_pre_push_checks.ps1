#requires -Version 5.1
<#
.SYNOPSIS
    Local pre-push gate for the Godot project (환격전).

.DESCRIPTION
    Runs the same checks as .github/workflows/godot-ci.yml so regressions are
    caught locally instead of waiting on (or paying LFS quota for) GitHub
    Actions: redacted project-secret scan, headless load check, GDScript warning
    scan, smoke-runner classifier regression, and the focused smoke set. Reuses
    the existing tools/run_*.ps1 scripts and resolves the Godot binary once so
    every step shares it.

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
$repoRoot = Split-Path (Split-Path $tools -Parent) -Parent

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
    "res://tests/character_info_passive_ui_retire_smoke.gd",
    "res://tests/character_info_chukjisin_haeng_attribution_smoke.gd",
    "res://tests/character_info_stat_source_attribution_smoke.gd",
    "res://tests/runtime_perk_debug_grants_smoke.gd",
    "res://tests/perk_tooltip_dual_panel_smoke.gd",
    "res://tests/perk_status_owned_tooltip_smoke.gd",
    "res://tests/perk_choice_per_card_description_smoke.gd",
    "res://tests/perk_overlay_dash_token_slot_cells_smoke.gd",
    "res://tests/angel_blessing_status_tooltip_smoke.gd",
    "res://tests/mythic_perk_offer_chance_smoke.gd",
    "res://tests/perk_offer_owned_upgrade_priority_smoke.gd",
    "res://tests/perk_status_panel_render_capture_smoke.gd",
    "res://tests/mythic_reveal_backdrop_smoke.gd",
    "res://tests/mythic_reveal_render_capture_smoke.gd",
    "res://tests/perk_conversion_overflow_scaling_smoke.gd",
    "res://tests/runtime_perk_overflow_description_smoke.gd",
    "res://tests/runtime_perk_progression_equivalence_smoke.gd",
    "res://tests/perk_polish_amplify_smoke.gd",
    "res://tests/project_resource_loader_import_preference_smoke.gd",
    "res://tests/battle_boot_resource_prewarm_smoke.gd",
    "res://tests/stage2_molewang_boss_port_smoke.gd",
    "res://tests/stage2_arachne_boss_port_smoke.gd",
    "res://tests/variant_boss_ball_path_snapshot_smoke.gd",
    "res://tests/tower_currency_display_term_ban_smoke.gd",
    "res://tests/ingame_gold_hud_smoke.gd",
    "res://tests/smasher_walk_motion_drive_smoke.gd",
    "res://tests/tower_ascent_map_hint_smoke.gd",
    "res://tests/tower_map_iconography_contract_smoke.gd",
    "res://tests/tower_route_serve_wind_target_smoke.gd",
    "res://tests/active_item_effect_controller_reset_smoke.gd",
    "res://tests/tower_map_camera_tracking_smoke.gd",
    "res://tests/tower_fullscreen_map_content_scale_smoke.gd",
    "res://tests/tower_character_exclusive_item_acquisition_smoke.gd",
    "res://tests/tower_guardian_spring_chosik_bridge_smoke.gd",
    "res://tests/tower_map_walker_zoom_intro_smoke.gd",
    "res://tests/tower_noncombat_node_background_retention_smoke.gd",
    "res://tests/runtime_perk_choice_stats_band_smoke.gd",
    "res://tests/tower_card_chosik_tooltip_smoke.gd",
    "res://tests/tower_card_absorption_direction_smoke.gd",
    "res://tests/runtime_perk_description_emphasis_smoke.gd",
    "res://tests/tower_noncombat_node_background_contract_smoke.gd",
    "res://tests/stage7_akamu_superspeed_unlock_cooldown_smoke.gd",
    "res://tests/stage7_akamu_golden_clone_starpoint_smoke.gd",
    "res://tests/tower_boss_routing_smoke.gd",
    "res://tests/tower_node_modal_pointer_smoke.gd",
    "res://tests/tower_node_modal_feedback_smoke.gd",
    "res://tests/tower_ascent_vertical_slice_smoke.gd",
    "res://tests/tower_start_card_smoke.gd",
    "res://tests/tower_battle_muhon_hud_smoke.gd",
    "res://tests/default_dash_token_baseline_smoke.gd",
    "res://tests/tower_ascent_route_serve_smoke.gd",
    "res://tests/tower_ascent_map_overlay_render_smoke.gd",
    "res://tests/tower_ascent_map_topology_smoke.gd",
    "res://tests/tower_reward_pick_smoke.gd",
    "res://tests/battle_scene_modal_overlap_input_smoke.gd",
    "res://tests/battle_reward_modal_input_router_owner_smoke.gd",
    "res://tests/mythic_perk_acquisition_cinematic_smoke.gd",
    "res://tests/active_item_cooldown_modal_pause_smoke.gd",
    "res://tests/tower_ascent_chest_contract_smoke.gd",
    "res://tests/tower_ascent_shop_node_smoke.gd",
    "res://tests/tower_ascent_training_node_smoke.gd",
    "res://tests/tower_route_screen_cleanup_smoke.gd",
    "res://tests/variant_boss_skill_name_rebrand_smoke.gd",
    "res://tests/stage3_boss_skillcard_atlas_contract_smoke.gd",
    "res://tests/tower_route_wind_and_pickup_smoke.gd",
    "res://tests/stage2_variant_crisis_rockfall_smoke.gd",
    "res://tests/tower_battle_gold_hud_live_sync_smoke.gd",
    "res://tests/tower_map_scroll_wiring_contract_smoke.gd",
    "res://tests/stage3_variant_boss_renderer_transform_smoke.gd",
    "res://tests/playfield_draw_transform_retention_pixel_smoke.gd",
    "res://tests/training_card_stat_preview_smoke.gd",
    "res://tests/tower_ascent_phase_c_node_visual_qa_contract_smoke.gd",
    "res://tests/tower_ascent_fallen_monk_node_smoke.gd",
    "res://tests/tower_ascent_guardian_spring_node_smoke.gd",
    "res://tests/treasure_map_perk_port_smoke.gd",
    "res://tests/common_mugong_item_rebrand_smoke.gd",
    "res://tests/match_player_skill_deps_builder_smoke.gd",
    "res://tests/online_match_mvp_smoke.gd",
    "res://tests/online_enet_loopback_smoke.gd",
    "res://tests/online_session_loopback_smoke.gd",
    "res://tests/battle_scene_overlay_frame_perf_smoke.gd",
    "res://tests/lingpet_duration_field_gauge_smoke.gd",
    "res://tests/weather_event_render_budget_smoke.gd",
    "res://tests/limit_league_tier_smoke.gd",
    "res://tests/stage1_han_miryang_prologue_smoke.gd",
    "res://tests/stage1_variant_boss_routing_smoke.gd",
    "res://tests/stage7_akamu_prebattle_video_smoke.gd",
    "res://tests/victory_highlight_replay_smoke.gd",
    "res://tests/victory_highlight_frame_product_smoke.gd",
    "res://tests/victory_highlight_frame_failure_recovery_smoke.gd",
    "res://tests/stage7_akamu_prebattle_live_frame_smoke.gd",
    "res://tests/stage7_akamu_slice6_result_loading_smoke.gd",
    "res://tests/stage7_akamu_result_scene_smoke.gd",
    "res://tests/boss_skill_hud_gauge_cover_smoke.gd",
    "res://tests/odins_eye_afterimage_dive_smoke.gd",
    "res://tests/odins_eye_actor_context_merge_smoke.gd",
    "res://tests/odins_eye_audio_smoke.gd",
    "res://tests/odins_eye_catalog_smoke.gd",
    "res://tests/odins_eye_chance_gem_floor_smoke.gd",
    "res://tests/odins_eye_dark_swamp_state_smoke.gd",
    "res://tests/odins_eye_dark_swamp_runtime_smoke.gd",
    "res://tests/odins_eye_death_cinematic_smoke.gd",
    "res://tests/odins_eye_finalize_paddle_land_smoke.gd",
    "res://tests/odins_eye_presentation_fx_host_smoke.gd",
    "res://tests/odins_eye_presentation_renderer_smoke.gd",
    "res://tests/odins_eye_revival_penalty_smoke.gd",
    "res://tests/odins_eye_skill_hud_smoke.gd",
    "res://tests/stage_debug_picker_runtime_reset_smoke.gd",
    "res://tests/battle_playfield_effects_drawer_character_gate_smoke.gd",
    "res://tests/perk_slot_limit_smoke.gd",
    "res://tests/mobile_touch_accept_channel_smoke.gd",
    "res://tests/perk_fusion_state_smoke.gd",
    "res://tests/perk_fusion_outcome_rules_smoke.gd",
    "res://tests/perk_fusion_result_builder_smoke.gd",
    "res://tests/perk_fusion_penalty_lane_builder_smoke.gd",
    "res://tests/perk_fusion_byproduct_catalog_smoke.gd",
    "res://tests/perk_fusion_byproduct_runtime_smoke.gd",
    "res://tests/perk_fusion_offer_planner_smoke.gd",
    "res://tests/perk_fusion_modal_flow_smoke.gd",
    "res://tests/perk_fusion_modal_input_smoke.gd",
    "res://tests/perk_fusion_localization_smoke.gd",
    "res://tests/perk_fusion_display_projection_smoke.gd",
    "res://tests/perk_fusion_projection_cache_smoke.gd",
    "res://tests/perk_fusion_display_consumer_smoke.gd",
    "res://tests/perk_fusion_tooltip_worst_case_smoke.gd",
    "res://tests/perk_fusion_icon_runtime_smoke.gd",
    "res://tests/perk_fusion_overlay_renderer_smoke.gd",
    "res://tests/perk_fusion_result_icon_prepare_smoke.gd",
    "res://tests/perk_fusion_value_hooks_smoke.gd",
    "res://tests/mystic_dice_state_smoke.gd",
    "res://tests/mystic_dice_offer_rotation_smoke.gd",
    "res://tests/mystic_dice_modal_flow_smoke.gd",
    "res://tests/mystic_dice_modal_input_smoke.gd",
    "res://tests/mystic_dice_modal_commit_smoke.gd",
    "res://tests/mystic_dice_stat_apply_smoke.gd",
    "res://tests/mystic_dice_paddle_effect_smoke.gd",
    "res://tests/mystic_dice_display_projection_smoke.gd",
    "res://tests/mystic_dice_overlay_renderer_smoke.gd",
    "res://tests/runtime_perk_modal_input_smoke.gd",
    "res://tests/perk_fusion_ball_event_hooks_smoke.gd",
    "res://tests/perk_fusion_character_skill_edge_smoke.gd",
    "res://tests/perk_fusion_commando_skill_edge_smoke.gd",
    "res://tests/perk_fusion_round_boundary_integration_smoke.gd",
    "res://tests/runtime_perk_fusion_integration_smoke.gd",
    "res://tests/runtime_perk_fusion_modal_integration_smoke.gd",
    "res://tests/runtime_perk_fusion_offer_integration_smoke.gd",
    "res://tests/perk_fusion_cold_boot_timeline_smoke.gd",
    "res://tests/perk_fusion_cold_boot_presentation_smoke.gd",
    "res://tests/perk_fusion_cold_boot_cinematic_smoke.gd",
    "res://tests/smasher_plasma_fx_host_smoke.gd",
    "res://tests/smasher_plasma_charge_size_speed_smoke.gd",
    "res://tests/smasher_plasma_visual_render_smoke.gd",
    "res://tests/smasher_plasma_playfield_clip_smoke.gd",
    "res://tests/smasher_plasma_clip_letterbox_pixel_smoke.gd",
    "res://tests/smasher_plasma_cooldown_tooltip_text_smoke.gd",
    "res://tests/pause_menu_audio_controller_owner_smoke.gd",
    "res://tests/pause_menu_content_catalog_owner_smoke.gd",
    "res://tests/pause_menu_controls_settings_controller_owner_smoke.gd",
    "res://tests/pause_menu_display_settings_controller_owner_smoke.gd",
    "res://tests/pause_menu_input_command_router_smoke.gd",
    "res://tests/pause_menu_language_settings_controller_owner_smoke.gd",
    "res://tests/pause_menu_options_renderer_owner_smoke.gd",
    "res://tests/pause_menu_overlay_layout_owner_smoke.gd",
    "res://tests/pause_menu_pointer_command_router_smoke.gd",
    "res://tests/pause_menu_selection_feedback_renderer_owner_smoke.gd",
    "res://tests/plaza_status_snapshot_builder_owner_smoke.gd",
    "res://tests/plaza_hwangyeok_building_r1_production_smoke.gd",
    "res://tests/lingpet_overflow_guardian_snapshot_builder_owner_smoke.gd",
    "res://tests/lingpet_rail_card_surface_builder_owner_smoke.gd",
    "res://tests/lingpet_egg_runtime_smoke.gd",
    "res://tests/lingpet_acquisition_lifecycle_coordinator_owner_smoke.gd",
    "res://tests/lingpet_companion_motion_coordinator_refactor_smoke.gd",
    "res://tests/lingpet_companion_player_runtime_resolver_smoke.gd",
    "res://tests/lingpet_guardian_duration_lifecycle_coordinator_owner_smoke.gd",
    "res://tests/lingpet_guardian_enhance_flow_coordinator_owner_smoke.gd",
    "res://tests/lingpet_guardian_enhance_presentation_coordinator_owner_smoke.gd",
    "res://tests/lingpet_egg_crack_capture_smoke.gd",
    "res://tests/player_socket_glow_smoke.gd",
    "res://tests/player_socket_part_overlay_smoke.gd",
    "res://tests/lingpet_mount_state_smoke.gd",
    "res://tests/perk_resume_player_bounce_speed_restore_smoke.gd",
    "res://tests/soul_burst_dash_boost_free_dash_smoke.gd",
    "res://tests/smasher_dash_spirit_laser_geometry_smoke.gd",
    "res://tests/smasher_power_smash_screen_shake_parity_smoke.gd",
    "res://tests/wall_leap_entry_gate_smoke.gd",
    "res://tests/wall_leap_mount_arbitration_smoke.gd",
    "res://tests/wall_leap_ball_passthrough_smoke.gd",
    "res://tests/wall_leap_ball_speed_scope_smoke.gd",
    "res://tests/wall_leap_slash_facing_smoke.gd",
    "res://tests/wall_leap_blast_status_smoke.gd",
    "res://tests/wall_leap_forced_return_smoke.gd",
    "res://tests/wall_leap_reset_paths_smoke.gd",
    "res://tests/wall_leap_modal_pause_smoke.gd",
    "res://tests/wall_leap_perk_acquisition_smoke.gd",
    "res://tests/wall_leap_floor_save_scope_smoke.gd",
    "res://tests/wall_leap_blade_projectile_smoke.gd",
    "res://tests/wall_leap_facing_smoke.gd",
    "res://tests/wall_leap_blast_vfx_smoke.gd",
    "res://tests/wall_leap_ball_return_target_smoke.gd",
    "res://tests/lingpet_mokrin_transform_registration_smoke.gd",
    "res://tests/lingpet_mokrin_transform_render_guard_smoke.gd",
    "res://tests/lingpet_static_front_presentation_smoke.gd",
    "res://tests/lingpet_baekrin_static_activation_smoke.gd",
    "res://tests/lingpet_mount_saddle_gate_smoke.gd",
    "res://tests/lingpet_rail_card_permit_branch_smoke.gd",
    "res://tests/battle_scene_state_horn_strawberry_schema_smoke.gd",
    "res://tests/lingpet_mount_topdown_readiness_smoke.gd",
    "res://tests/lingpet_mount_body_presentation_reconcile_smoke.gd",
    "res://tests/lingpet_topdown_mount_render_smoke.gd"
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
    Invoke-Step "interactive-play validation guard regression" {
        & (Join-Path $tools "verify_interactive_play_validation_guard.ps1") -ProjectPath (Join-Path $repoRoot "godot")
    }
    Invoke-Step "headless load check" {
        & (Join-Path $tools "run_headless_load_check.ps1") -GodotExe $godot
    }

    Invoke-Step "stage7 asset tool regression (python, 13 cases)" {
        # 코덱스 2026-07-14: 수동 게이트였던 자산 도구 봉인(스테이징 검증·
        # 정책 씰·승격/QA 우회 진입점 가드·E2E 라이브 센티널)을 프리푸시에 등재.
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

    if ($Mode -ne "load") {
        Invoke-Step "smoke runner classifier regression" {
            & (Join-Path $tools "verify_smoke_runner_classifier.ps1") -GodotExe $godot
        }
        Invoke-Step "nightly smoke status regression" {
            & (Join-Path $tools "verify_nightly_smoke_status.ps1")
        }
    } else {
        Write-Host ""
        Write-Host "--- smoke runner classifier regression SKIPPED (mode=load) ---"
        Write-Host "--- nightly smoke status regression SKIPPED (mode=load) ---"
    }

    if ($Mode -eq "all") {
        Invoke-Step "full smoke suite (all *_smoke.gd)" {
    Invoke-Step "project secret scanner regression" {
        & (Join-Path $repoRoot "tools\verify_project_secret_scanner.ps1")
    }
    Invoke-Step "redacted project secret scan" {
        & (Join-Path $repoRoot "tools\verify_no_project_secrets.ps1") -RepoRoot $repoRoot
    }

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
