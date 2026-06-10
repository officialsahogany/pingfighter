extends RefCounted
const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const ChaosSpearFxHost := preload("res://scripts/characters/viper_chaos_spear_fx_host.gd")
const EmpStrikeFxHost := preload("res://scripts/characters/viper_emp_strike_fx_host.gd")
const ViperSkillAudioRouter := preload("res://scripts/characters/viper_skill_audio_router.gd")
const ViperSkillActivationRuntime := preload("res://scripts/characters/viper_skill_activation_runtime.gd")
const ViperSkillBladeEffectRenderer := preload("res://scripts/characters/viper_skill_blade_effect_renderer.gd")
const ViperSkillBladeBallMotionRuntime := preload("res://scripts/characters/viper_skill_blade_ball_motion_runtime.gd")
const ViperSkillBladeMotionRuntime := preload("res://scripts/characters/viper_skill_blade_motion_runtime.gd")
const ViperSkillBladeWindowRuntime := preload("res://scripts/characters/viper_skill_blade_window_runtime.gd")
const ViperSkillChaosSpearEffectRenderer := preload("res://scripts/characters/viper_skill_chaos_spear_effect_renderer.gd")
const ViperSkillChaosSpearBallMotionRuntime := preload("res://scripts/characters/viper_skill_chaos_spear_ball_motion_runtime.gd")
const ViperSkillChaosSpearRuntime := preload("res://scripts/characters/viper_skill_chaos_spear_runtime.gd")
const ViperSkillCommandTracker := preload("res://scripts/characters/viper_skill_command_tracker.gd")
const ViperSkillContextBuilder := preload("res://scripts/characters/viper_skill_context_builder.gd")
const ViperSkillContactRuntime := preload("res://scripts/characters/viper_skill_contact_runtime.gd")
const ViperSkillCoreFlipRuntime := preload("res://scripts/characters/viper_skill_core_flip_runtime.gd")
const ViperSkillDrawRuntime := preload("res://scripts/characters/viper_skill_draw_runtime.gd")
const ViperSkillDualGlitchCloneRuntime := preload("res://scripts/characters/viper_skill_dual_glitch_clone_runtime.gd")
const ViperSkillDualGlitchEffectRenderer := preload("res://scripts/characters/viper_skill_dual_glitch_effect_renderer.gd")
const ViperSkillEmpStrikeBallMotionRuntime := preload("res://scripts/characters/viper_skill_emp_strike_ball_motion_runtime.gd")
const ViperSkillEmpStrikeRuntime := preload("res://scripts/characters/viper_skill_emp_strike_runtime.gd")
const ViperSkillFloatingTextRenderer := preload("res://scripts/characters/viper_skill_floating_text_renderer.gd")
const ViperSkillFxHostController := preload("res://scripts/characters/viper_skill_fx_host_controller.gd")
const ViperSkillIgnitionAuraRuntime := preload("res://scripts/characters/viper_skill_ignition_aura_runtime.gd")
const ViperSkillMarshalKickRuntime := preload("res://scripts/characters/viper_skill_marshal_kick_runtime.gd")
const ViperSkillMarshalWindowRuntime := preload("res://scripts/characters/viper_skill_marshal_window_runtime.gd")
const ViperSkillNerveCloneRuntime := preload("res://scripts/characters/viper_skill_nerve_clone_runtime.gd")
const ViperSkillNerveStrikeRuntime := preload("res://scripts/characters/viper_skill_nerve_strike_runtime.gd")
const ViperSkillKickEffectRenderer := preload("res://scripts/characters/viper_skill_kick_effect_renderer.gd")
const ViperSkillParticleDrawer := preload("res://scripts/characters/viper_skill_particle_drawer.gd")
const ViperSkillResetRuntime := preload("res://scripts/characters/viper_skill_reset_runtime.gd")
const ViperSkillRuntimeActionRouter := preload("res://scripts/characters/viper_skill_runtime_action_router.gd")
const ViperSkillShadowEffectRenderer := preload("res://scripts/characters/viper_skill_shadow_effect_renderer.gd")
const ViperSkillShadowStepBallMotionRuntime := preload("res://scripts/characters/viper_skill_shadow_step_ball_motion_runtime.gd")
const ViperSkillShadowStepRuntime := preload("res://scripts/characters/viper_skill_shadow_step_runtime.gd")
const ViperSkillSnapshotBuilder := preload("res://scripts/characters/viper_skill_snapshot_builder.gd")
const ViperSkillScaling := preload("res://scripts/characters/viper_skill_scaling.gd")
const ViperSkillTimerGaugeRenderer := preload("res://scripts/characters/viper_skill_timer_gauge_renderer.gd")
const ViperSkillTransientEffectRuntime := preload("res://scripts/characters/viper_skill_transient_effect_runtime.gd")
const ViperSkillVisibilityQuery := preload("res://scripts/characters/viper_skill_visibility_query.gd")
const ViperSkillGeometry := preload("res://scripts/characters/viper_skill_geometry.gd")
const ViperPhantomKickCutinState := preload("res://scripts/characters/viper_phantom_kick_cutin_state.gd")
const CHAOS_FX_DISK_HEIGHT := 220.0
const SHADOW_STEP := "shadow_step"; const MARSHAL_KICK := "marshal_kick"; const PHANTOM_KICK := "phantom_kick"; const DOUBLE_MARSHAL_KICK := "double_marshal_kick"
const BLADE_RUSH := "blade_rush"; const DARK_BLADE := "dark_blade"; const NERVE_STRIKE := "nerve_strike"; const CHAOS_SPEAR := "chaos_spear"; const CORE_FLIP := "core_flip"
const DIVE_STRIKE := "dive_strike"; const DUAL_GLITCH := "dual_glitch"; const IGNITION_AURA := "ignition_aura"
const SHADOW_STEP_DASH_GRACE_FRAMES := 36.0; const SHADOW_STEP_READY_FRAMES := 60.0
const MARSHAL_KICK_READY_FRAMES := 90.0; const MARSHAL_KICK_JUMP_FRAMES := 24.72; const MARSHAL_KICK_CLING_FRAMES := 15.0; const MARSHAL_KICK_CHARGE_FRAMES := 23.4
const MARSHAL_KICK_RECLIMB_FRAMES := 10.8; const MARSHAL_KICK_RETURN_FRAMES := 21.0; const MARSHAL_KICK_HIT_RADIUS := 90.0; const MARSHAL_KICK_RECLIMB_THRESHOLD := 120.0
const MARSHAL_KICK_WALL_INSET := 15.0; const MARSHAL_KICK_SPEED_MULT := 2.2; const MARSHAL_KICK_MIN_SPEED := 11.0
const MARSHAL_KICK_DOUBLE_SPEED_MULT := 2.8; const MARSHAL_KICK_DOUBLE_MIN_SPEED := 14.0; const MARSHAL_KICK_DOUBLE_FAST_MULT := 1.3; const MARSHAL_KICK_SHADOW_CHAIN_PREP_MULT := 0.8; const MARSHAL_KICK_PHANTOM_CHAIN_PREP_MULT := 0.8
const MARSHAL_KICK_PHANTOM_DELAY_FRAMES := 12.0; const MARSHAL_KICK_DMK_FREEZE_FRAMES := 99.0; const MARSHAL_KICK_DMK_TEXT_FRAMES := 80.0  # 99f = 1.65s wall-brace freeze, matches Smasher power-smash cut-in length (POWER_SMASH_FREEZE_DURATION); the phantom-kick cut-in is synced to this freeze (dmk_freeze_frames/60).
const MARSHAL_KICK_CURVE_FRAMES := 50.0; const MARSHAL_DOUBLE_HIT_CURVE_FRAMES_MULT := 2.5; const MARSHAL_KICK_CURVE_FORCE := 2.0; const MARSHAL_KICK_IMPACT_OBJECT_RADIUS := 150.0; const MARSHAL_KICK_TRAIL_MAX := 60
const CHAOS_CMD_WINDOW_MSEC := 600; const CHAOS_CMD_BUFFER_MAX := 6; const CHAOS_STARTUP_FRAMES := 45.0; const CHAOS_TRAVEL_FRAMES := 16.8; const CHAOS_IMPACT_FRAMES := 21.6
const CHAOS_BLACKHOLE_FRAMES := 180.0; const CHAOS_FADE_FRAMES := 25.2; const CHAOS_PULL_RADIUS := 175.0; const CHAOS_INGRESS_FRAMES := 31.2; const CHAOS_VISUAL_LENGTH := 78.0
const CHAOS_GOLD_TICK_FRAMES := 6.0; const CHAOS_GOLD_PER_TICK := 1; const CHAOS_OBJECT_GOLD := 5
const SHADOW_STEP_HOLOGRAM_FRAMES := 30.0; const SHADOW_STEP_WAVE_SPEED := 25.0; const SHADOW_STEP_WAVE_TRAIL_MAX := 12
const SHADOW_STEP_WAVE_COLLISION_SIZE := Vector2(110.0, 90.0); const SHADOW_STEP_WAVE_GRADIENT_SIZE := Vector2(280.0, 220.0)
const SHADOW_STEP_HIT_SPEED_MIN := 1.48; const SHADOW_STEP_HIT_SPEED_MAX := 1.96; const SHADOW_STEP_HIT_CURVE_MIN := 10.0; const SHADOW_STEP_HIT_CURVE_MAX := 50.0
const SHADOW_STEP_HIT_FORCE_MIN := 0.4; const SHADOW_STEP_HIT_FORCE_MAX := 2.0; const SHADOW_STEP_MIN_HIT_SPEED := 10.0; const SHADOW_STEP_KICK_READY_FRAMES := 300.0
const SHADOW_STEP_PHANTOM_FRAMES := 18.0; const SHADOW_STEP_MARSHAL_DELAY_FRAMES := 18.0; const SHADOW_STEP_PADDLE_HIT_PADDING := 40.0
const SHADOW_STEP_PADDLE_HIT_SOURCE := "paddle"; const SHADOW_STEP_PADDLE_HIT_WINDOW_MSEC := 5000; const SHADOW_STEP_ACTIVATION_VALID_AFTER_MSEC := -99999
const CORE_FLIP_MARSHAL_DELAY_FRAMES := 6.0; const SHADOW_STEP_HIT_GOLD := 16; const SHADOW_STEP_AIRBORNE_GOLD_MULT := 1.5
const SHADOW_STEP_STARBURST_FRAMES := 5; const SHADOW_STEP_STARBURST_FRAME_DURATION := 3.0
const BLADE_SPIN_FRAMES := 24.0; const BLADE_DECEL_FRAMES := 12.0; const BLADE_REST_FRAMES := 66.0; const BLADE_DARK_REST_FRAMES := 90.0
const BLADE_DARK_SPIN_MULT := 2.5; const BLADE_DARK_TIME_MULT := 1.5; const BLADE_NORMAL_SPIN_TURNS := 2.0; const BLADE_DARK_SPIN_TURNS := 3.0
const BLADE_PROJECTILE_SPEED := 12.0; const BLADE_BASE_WIDTH := 350.0; const BLADE_BASE_RANGE := 250.0; const BLADE_HITBOX_HEIGHT := 55.0; const BLADE_DARK_HITBOX_HEIGHT := 83.0
const BLADE_FADEOUT_FRAMES := 30.0; const BLADE_TRAIL_MAX := 20; const BLADE_FOLLOWUP_TRAIL_MAX := 16; const BLADE_FOLLOWUP_START_Y_OFFSET := -20.0
# DARK_BLADE_WINDOW_FRAMES: intentional divergence from the Python original (180f / 3s) —
# tightened to 60f (1s) for a continuous-combo chain feel (2026-06-11 design decision).
const BLADE_COMBO_DELAY_FRAMES := 30.0; const BLADE_DASH_RELEASE_DELAY_FRAMES := 18.0; const DARK_BLADE_WINDOW_FRAMES := 60.0; const DARK_BLADE_DEFAULT_BALL_SIZE := 28.6; const BLADE_HIT_GOLD := 30
const AIR_BLADE_MAX_BALL_SPEED := 40.0; const DARK_BLADE_MAX_BALL_SPEED := 50.0; const AIR_BLADE_HIT_SPEED_MULT := 2.1; const DARK_BLADE_HIT_SPEED_MULT := 2.4
const AIR_BLADE_HIT_SHAKE_AMOUNT := 0.15; const DARK_BLADE_HIT_SHAKE_AMOUNT := 0.20; const AIR_BLADE_HIT_SHAKE_INTENSITY := 4.8; const DARK_BLADE_HIT_SHAKE_INTENSITY := 6.0
const AIR_BLADE_HIT_PULSE_KIND := "viper_blade"; const DARK_BLADE_HIT_PULSE_KIND := "viper_dark_blade"; const AIR_BLADE_HIT_PULSE_INTENSITY := 0.86; const DARK_BLADE_HIT_PULSE_INTENSITY := 1.0
const AIR_BLADE_FALLBACK_HIT_COLOR := Color(1.0, 0.38, 1.0, 1.0); const DARK_BLADE_FALLBACK_HIT_COLOR := Color(1.0, 0.16, 0.24, 1.0)
const AIR_BLADE_FALLBACK_PARTICLE_INTENSITY := 1.25; const DARK_BLADE_FALLBACK_PARTICLE_INTENSITY := 1.6; const AIR_BLADE_FALLBACK_EXPLOSION_SCALE := 0.82; const DARK_BLADE_FALLBACK_EXPLOSION_SCALE := 1.05
const AIR_BLADE_FALLBACK_EXPLOSION_INTENSITY := 0.95; const DARK_BLADE_FALLBACK_EXPLOSION_INTENSITY := 1.15; const BLADE_HIT_PLAYER_COLLISION_COOLDOWN := 6.0
const BLADE_AMP_FOLLOWUP_WIDTH_SCALE := 0.72; const BLADE_AMP_FOLLOWUP_RANGE_SCALE := 0.88; const BLADE_AMP_FOLLOWUP_HIT_SPEED_SCALE := 0.55; const BLADE_AMP_FOLLOWUP_MIN_WIDTH := 80.0
const BLADE_DUAL_GLITCH_REPLICA_MIN_SCALE := 0.1; const BLADE_DUAL_GLITCH_REPLICA_HIT_SPEED_SCALE := 1.0; const BLADE_PREP_FALL_SPEED := 3.0; const BLADE_AIRBORNE_MOVE_BONUS_MAX := 2.15; const BLADE_JETPACK_MAX_HEIGHT := 200.0
const DIVE_HOLD_REQUIRED_MSEC := 300; const DIVE_PREP_FRAMES := 24.0; const DIVE_SPEED := 15.0; const DIVE_GAUGE_COST := 150.0; const DIVE_JETPACK_MAX_HEIGHT := 200.0
const DIVE_SHOCKWAVE_HEIGHT := 120.0; const DIVE_SHOCKWAVE_FRAMES := 60.0; const DIVE_SHOCKWAVE_START_RADIUS := 34.0; const DIVE_SHOCKWAVE_BASE_MAX_RADIUS := 300.0; const DIVE_SHOCKWAVE_RING_HALF_THICKNESS := 24.0
const DIVE_SLIP_DURATION_MIN := 54.0; const DIVE_SLIP_DURATION_MAX := 90.0; const DIVE_SLIP_SPEED := 4.0; const DIVE_PARTICLE_LIMIT := 150; const DIVE_CHARGE_PARTICLE_LIMIT := 80
const DIVE_PLAYER_COLLISION_COOLDOWN := 6.0; const DIVE_HIT_TEXT_FRAMES := 50.0; const DIVE_HIT_TEXT_FLOAT_Y := 36.0
const DUAL_GLITCH_CMD_WINDOW_MSEC := 1200; const DUAL_GLITCH_STARTUP_FRAMES := 48.0; const DUAL_GLITCH_SPAWN_FRAMES := 22.8; const DUAL_GLITCH_ACTIVE_FRAMES := 900.0
const DUAL_GLITCH_FADE_FRAMES := 18.0; const DUAL_GLITCH_EVAPORATION_FRAMES := 13.2; const DUAL_GLITCH_OFFSET_PADDING := -15.0; const DUAL_GLITCH_ALPHA := 0.63; const DUAL_GLITCH_WIGGLE_AMPLITUDE := 3.0
const DUAL_GLITCH_DIVE_STAGGER_FRAMES := 12.0; const DUAL_GLITCH_DIVE_TELEGRAPH_FRAMES := 6.0; const DUAL_GLITCH_TIMER_BAR_SIZE := Vector2(150.0, 12.0); const DUAL_GLITCH_TIMER_BAR_MARGIN := Vector2(16.0, 28.0)
const DUAL_GLITCH_TIMER_STACK_SPACING := 18.0; const DUAL_GLITCH_TIMER_STACK_KEY := "dual_glitch"
const IGNITION_HOLD_REQUIRED_MSEC := 500; const IGNITION_DURATION_FRAMES := 1500.0; const IGNITION_GAUGE_COST := 230.0; const IGNITION_PARTICLE_LIMIT := 180; const IGNITION_CHARGE_PARTICLE_LIMIT := 80
const IGNITION_EMBER_LIMIT := 54; const IGNITION_EMBER_INTERVAL_FRAMES := 8.4; const IGNITION_TIMER_BAR_SIZE := Vector2(150.0, 12.0); const IGNITION_TIMER_BAR_MARGIN := Vector2(16.0, 28.0)
const IGNITION_TIMER_STACK_SPACING := 18.0; const IGNITION_TIMER_STACK_KEY := "ignition_aura"; const IGNITION_AURA_EFFECT_SHEET_PATH := "res://assets/sprites/effects/viper_ignition_aura_effect_sheet.png"
const IGNITION_AURA_EFFECT_SHEET_COLS := 4; const IGNITION_AURA_EFFECT_SHEET_ROWS := 4; const IGNITION_AURA_EFFECT_FRAME_INTERVAL_MSEC := 70
const BLADE_COMBO_POP_MIN_OFFSET := -40.0; const BLADE_COMBO_POP_EXTRA := 80.0; const DARK_BLADE_AUTO_FIRE_START_FRAMES := 48.0; const DARK_BLADE_AUTO_FIRE_END_FRAMES := 84.0; const DARK_BLADE_AUTO_FIRE_NEAR_Y := 150.0
const BLADE_AIR_RISE_FRAMES := 18.0; const BLADE_DARK_RISE_FRAMES := 27.0; const BLADE_AIR_JUMP_PEAK := 80.0; const BLADE_DARK_JUMP_PEAK := 320.0
# Python parity: Air Blade W+0.6; Venom W+1.1..1.4; Dark Blade W+1.4..1.7.
const NERVE_STRIKE_WINDOW_START_FRAMES := 66.0; const NERVE_STRIKE_WINDOW_END_FRAMES := 102.0; const NERVE_STRIKE_DARK_BLADE_SPLIT_FRAMES := 84.0
const NERVE_STRIKE_DASH_FRAMES := 30.0; const NERVE_STRIKE_SLASH_HIT_FRAMES := 138.0; const NERVE_STRIKE_SLASH_MISS_FRAMES := 18.0; const NERVE_STRIKE_RETURN_HIT_FRAMES := 15.0; const NERVE_STRIKE_RETURN_MISS_FRAMES := 9.0
const NERVE_STRIKE_HIT_RADIUS := 120.0; const NERVE_STRIKE_CONFUSION_FRAMES := 150.0; const NERVE_STRIKE_HIT_GOLD := 60; const NERVE_STRIKE_MISS_TEXT_FRAMES := 60.0; const NERVE_STRIKE_MISS_TEXT_FLOAT_Y := 34.0
const NERVE_STRIKE_SLASH_TRIGGER_RATIO := 0.45
# Keep dash behind the boss body; the strike sheet owns the high eye-slash read.
const NERVE_STRIKE_TARGET_Y_OFFSET := 0.0; const NERVE_STRIKE_TRACKING_END_RATIO := 0.80; const NERVE_STRIKE_TRACKING_STRENGTH := 0.12; const NERVE_STRIKE_SLASH_VFX_FRAMES := 30.0
const DUAL_GLITCH_NERVE_STAGGER_FRAMES := 12.0; const DUAL_GLITCH_NERVE_TRAVEL_FRAMES := 13.2; const DUAL_GLITCH_NERVE_SLASH_FRAMES := 12.0
const FOUR_POISONS_PREP_REDUCTION_PCT_BY_LEVEL := [0, 8, 16, 25, 33, 40]; const FOUR_POISONS_PREP_REDUCTION_PCT_PER_EXTRA_LEVEL := 4; const FOUR_POISONS_PREP_REDUCTION_PCT_CAP := 70
const FOUR_POISONS_EMP_SLEEP_PCT_BY_LEVEL := [0, 5, 10, 15, 20, 25]; const FOUR_POISONS_EMP_SLEEP_PCT_PER_EXTRA_LEVEL := 5; const FOUR_POISONS_EMP_SLEEP_PCT_CAP := 50
const FOUR_POISONS_COOLDOWN_REDUCTION_PCT_BY_LEVEL := [0, 0, 0, 10, 15, 20]; const FOUR_POISONS_COOLDOWN_REDUCTION_PCT_PER_EXTRA_LEVEL := 4; const FOUR_POISONS_COOLDOWN_REDUCTION_PCT_CAP := 40
const FOUR_POISONS_VENOM_CONFUSION_PCT_BY_LEVEL := [0, 12, 24, 36, 48, 70]; const FOUR_POISONS_VENOM_CONFUSION_PCT_PER_EXTRA_LEVEL := 10; const FOUR_POISONS_VENOM_CONFUSION_PCT_CAP := 150
const FOUR_POISONS_DUAL_GLITCH_DURATION_PCT_BY_LEVEL := [0, 7, 14, 20, 27, 33]; const FOUR_POISONS_DUAL_GLITCH_DURATION_PCT_PER_EXTRA_LEVEL := 5; const FOUR_POISONS_DUAL_GLITCH_DURATION_PCT_CAP := 45
const FOUR_POISONS_DUAL_GLITCH_CLONE_HP_BY_LEVEL := [2, 2, 2, 3, 3, 4]; const FOUR_POISONS_DUAL_GLITCH_CLONE_HP_CAP := 6
const CORE_FLIP_READY_WINDOW_MSEC := 700; const CORE_FLIP_DASH_SUCCESS_WINDOW_MSEC := 400; const CORE_FLIP_DASH_START_UNSET_MSEC := -100000; const CORE_FLIP_DASH_START_VALID_AFTER_MSEC := -99999
const CORE_FLIP_INPUT_FRAME_UNSET := -999999; const CORE_FLIP_INPUT_FRAME_GAP := 4; const CORE_FLIP_INPUT_MAX_AGE_FRAMES := 16; const CORE_FLIP_DEFAULT_PADDLE_SIZE := Vector2(155.0, 50.0)
const CORE_FLIP_PHASE0_FRAMES := 24.0; const CORE_FLIP_PHASE1_FRAMES := 105.3; const CORE_FLIP_PHASE2_FRAMES := 23.4; const CORE_FLIP_PHASE3_FRAMES := 9.0
const CORE_FLIP_ZIGZAG_LEG_FRAMES := 28.08; const CORE_FLIP_ZIGZAG_CLING_FRAMES := 11.7; const CORE_FLIP_KICK_TRIGGER_Y := 200.0; const CORE_FLIP_APEX_OFFSET_Y := -30.0
const CORE_FLIP_HIT_RADIUS := 60.0; const CORE_FLIP_SPEED_MULT := 2.2; const CORE_FLIP_MIN_SPEED := 11.0; const CORE_FLIP_HIT_GOLD := 30
const CORE_FLIP_START_SHAKE_AMOUNT := 0.14; const CORE_FLIP_START_SHAKE_INTENSITY := 4.5; const CORE_FLIP_HIT_SHAKE_AMOUNT := 0.15; const CORE_FLIP_HIT_SHAKE_INTENSITY := 6.0
const CORE_FLIP_HIT_PULSE_INTENSITY := 0.92; const CORE_FLIP_HIT_PULSE_KIND := "viper_core_flip"; const CORE_FLIP_DARK_BLADE_HANDOFF_FRAMES := 30.0; const CORE_FLIP_MISS_TEXT_FRAMES := 50.0; const CORE_FLIP_MISS_TEXT_FLOAT_Y := 34.0
const KICK_ENHANCE_KNOCKBACK_BALL_CHANCE_CAP := 100; const KICK_ENHANCE_KNOCKBACK_BALL_FIXED_PCT := 150
const PHANTOM_KICK_KNOCKBACK_DISTANCE := 18.0; const PHANTOM_KICK_KNOCKBACK_FRAMES := 36.0; const PHANTOM_KICK_KNOCKBACK_DECAY := 0.88
const KICK_GUARD_KNOCKBACK_FIRE_BASE := 22.0; const KICK_GUARD_KNOCKBACK_FRAMES := 18.0; const KICK_GUARD_KNOCKBACK_DECAY := 0.85; const KICK_GUARD_DISTANCE_MULTIPLIER := 1.56
const KICK_GUARD_BALL_SPEED_REDUCTION_PCT := 50
const VIPER_HOLOGRAM_ATTACK_LEFT_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_left_attack_sheet.png"; const VIPER_HOLOGRAM_ATTACK_RIGHT_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_right_attack_sheet.png"
const VIPER_HOLOGRAM_FRAME_SIZE := Vector2(160.0, 160.0); const VIPER_HOLOGRAM_BASE_VISUAL_SIZE := Vector2(160.0, 160.0); const VIPER_HOLOGRAM_ATTACK_GRID_COLS := 4; const VIPER_HOLOGRAM_ATTACK_FRAME_COUNT := 8
const VIPER_HOLOGRAM_BASE_PADDLE_WIDTH := 155.0; const VIPER_HOLOGRAM_FEET_OFFSET := 12.0
const SHADOW_HIT_SHAKE_AMOUNT_BASE := 0.09; const SHADOW_HIT_SHAKE_AMOUNT_CENTER_BONUS := 0.07; const SHADOW_HIT_SHAKE_INTENSITY_BASE := 3.2; const SHADOW_HIT_SHAKE_INTENSITY_CENTER_BONUS := 1.8
const SHADOW_HIT_PARTICLE_INTENSITY_BASE := 0.72; const SHADOW_HIT_PARTICLE_INTENSITY_CENTER_BONUS := 0.36; const SHADOW_HIT_ENERGY_SCALE_BASE := 0.48; const SHADOW_HIT_ENERGY_SCALE_CENTER_BONUS := 0.22
const SHADOW_HIT_ENERGY_INTENSITY_BASE := 0.62; const SHADOW_HIT_ENERGY_INTENSITY_CENTER_BONUS := 0.30
const MARSHAL_HIT_SHAKE_AMOUNT := 0.13; const MARSHAL_DOUBLE_HIT_SHAKE_AMOUNT := 0.20; const MARSHAL_HIT_SHAKE_INTENSITY := 3.6; const MARSHAL_DOUBLE_HIT_SHAKE_INTENSITY := 5.0
const MARSHAL_HIT_PARTICLE_INTENSITY := 0.86; const MARSHAL_DOUBLE_HIT_PARTICLE_INTENSITY := 1.30; const MARSHAL_HIT_ENERGY_SCALE := 0.58; const MARSHAL_DOUBLE_HIT_ENERGY_SCALE := 0.82
const MARSHAL_HIT_PULSE_KIND := "viper_marshal"; const MARSHAL_DOUBLE_HIT_PULSE_KIND := "viper_double_marshal"; const MARSHAL_HIT_ENERGY_INTENSITY := 0.72; const MARSHAL_DOUBLE_HIT_ENERGY_INTENSITY := 0.96
const MARSHAL_FALLBACK_HIT_COLOR := Color(0.72, 0.0, 1.0, 1.0); const MARSHAL_HIT_PLAYER_COLLISION_COOLDOWN := 6.0; const MARSHAL_HIT_GOLD := 30; const MARSHAL_DOUBLE_HIT_GOLD := 50
const MARSHAL_HIT_MOTION_PARTICLE_COUNT := 14; const MARSHAL_DOUBLE_HIT_MOTION_PARTICLE_COUNT := 22; const MARSHAL_HIT_MOTION_PARTICLE_SPREAD := 10.0
const MARSHAL_HIT_MOTION_PARTICLE_LIFE_MIN := 18.0; const MARSHAL_HIT_MOTION_PARTICLE_LIFE_MAX := 34.0; const MARSHAL_HIT_MOTION_PARTICLE_KIND := "impact"; const MARSHAL_HIT_MOTION_PARTICLE_CHANCE := 1.0
const CORE_FLIP_HIT_MOTION_PARTICLE_COUNT := 18; const CORE_FLIP_HIT_MOTION_PARTICLE_SPREAD := 12.0; const CORE_FLIP_HIT_MOTION_PARTICLE_LIFE_MIN := 20.0; const CORE_FLIP_HIT_MOTION_PARTICLE_LIFE_MAX := 38.0
const CORE_FLIP_HIT_MOTION_PARTICLE_KIND := "impact"; const CORE_FLIP_HIT_MOTION_PARTICLE_CHANCE := 1.0; const PHANTOM_HIT_PARTICLE_COUNT := 85; const PHANTOM_HIT_PARTICLE_MAX_COUNT := 90; const VIPER_HIT_PARTICLE_GLOW_SIZE_THRESHOLD := 3.2
var previous_down_pressed := false; var previous_left_pressed := false; var previous_up_pressed := false; var previous_right_pressed := false
var input_sequence_frame := 0; var core_flip_left_press_frame := CORE_FLIP_INPUT_FRAME_UNSET; var core_flip_right_press_frame := CORE_FLIP_INPUT_FRAME_UNSET
var previous_dash_active := false; var previous_dash_recovering := false
var audio_router: Object = ViperSkillAudioRouter.new(); var blade_effect_renderer: Object = ViperSkillBladeEffectRenderer.new(); var chaos_spear_effect_renderer: Object = ViperSkillChaosSpearEffectRenderer.new(); var command_tracker: Object = ViperSkillCommandTracker.new()
var context_builder: Object = ViperSkillContextBuilder.new(); var dual_glitch_effect_renderer: Object = ViperSkillDualGlitchEffectRenderer.new(); var floating_text_renderer: Object = ViperSkillFloatingTextRenderer.new()
var fx_host_controller: Object = ViperSkillFxHostController.new(); var kick_effect_renderer: Object = ViperSkillKickEffectRenderer.new(); var particle_drawer: Object = ViperSkillParticleDrawer.new()
var runtime_action_router: Object = ViperSkillRuntimeActionRouter.new(); var shadow_effect_renderer: Object = ViperSkillShadowEffectRenderer.new(); var snapshot_builder: Object = ViperSkillSnapshotBuilder.new()
var skill_scaling: Object = ViperSkillScaling.new(); var timer_gauge_renderer: Object = ViperSkillTimerGaugeRenderer.new(); var visibility_query: Object = ViperSkillVisibilityQuery.new()
var cutin_state: Object = ViperPhantomKickCutinState.new()
var dash_origin_pos := Vector2.ZERO; var dash_origin_valid := false; var dash_grace_frames := 0.0
var shadow_step_ready_frames := 0.0; var shadow_step_activation_msec := -100000
var shadow_hologram_active := false; var shadow_hologram_frames := 0.0; var shadow_hologram_origin := Vector2.ZERO; var shadow_hologram_target := Vector2.ZERO
var shadow_hologram_kick_dir := 1; var shadow_hologram_kick_hit := false; var shadow_hologram_dest_shock_spawned := false; var shadow_paddle_size := Vector2(155.0, 50.0)
var shadow_wave_active := false; var shadow_wave_pos := Vector2.ZERO; var shadow_wave_target_x := 0.0; var shadow_wave_dir := 1; var shadow_wave_hit_ball := false
var shadow_wave_trail: Array = []; var shadow_kick_ready := false; var shadow_kick_ready_frames := 0.0
var shadow_hit_consumed := false; var shadow_was_airborne := false; var shadow_marshal_delay_frames := 0.0; var shadow_marshal_delay_from_shadow_step := false; var shadow_marshal_delay_from_core_flip := false
var shadow_curve_active := false; var shadow_curve_timer := 0.0; var shadow_curve_total := 0.0; var shadow_curve_force := 0.0; var shadow_curve_dir := 1
var shadow_starburst_active := false; var shadow_starburst_pos := Vector2.ZERO; var shadow_starburst_frame := 0; var shadow_starburst_timer := 0.0; var shadow_starburst_is_double := false
var phantom_strike_active := false; var phantom_strike_frames := 0.0; var phantom_strike_curve_dir := 1
var blade_motion_active := false; var blade_motion_phase := 0; var blade_motion_frames := 0.0; var blade_motion_total_frames := 0.0; var blade_spin_angle := 0.0; var blade_dark_mode := false
var blade_motion_start_pos := Vector2.ZERO; var blade_motion_pos := Vector2.ZERO; var blade_phase2_base_y := 0.0; var blade_paddle_size := Vector2(155.0, 50.0)
var blade_projectile_active := false; var blade_projectile_pos := Vector2.ZERO; var blade_projectile_start_y := 0.0; var blade_projectile_target_y := 0.0
var blade_projectile_width := BLADE_BASE_WIDTH; var blade_projectile_hit_ball := false; var blade_projectile_trail: Array = []
var blade_projectile_fadeout := false; var blade_projectile_fadeout_frames := 0.0; var blade_air_combo_window := false; var blade_air_fire_frames := 0.0
var blade_dark_combo_window := false; var blade_dark_fire_frames := 0.0; var blade_hit_speed_cap_active := 0.0
var dark_blade_window := false; var dark_blade_window_frames := 0.0; var blade_spin_sound_active := false; var blade_spin_audio: Object = null; var blade_followup_projectiles: Array = []
var nerve_strike_active := false; var nerve_strike_phase := 0; var nerve_strike_phase_frames := 0.0
var nerve_strike_start_pos := Vector2.ZERO; var nerve_strike_pos := Vector2.ZERO; var nerve_strike_dash_target_pos := Vector2.ZERO
var nerve_strike_return_start_pos := Vector2.ZERO; var nerve_strike_return_target_pos := Vector2.ZERO; var nerve_strike_paddle_size := Vector2(155.0, 50.0); var nerve_strike_floor_y := 700.0
var nerve_strike_hit_confirmed := false; var nerve_strike_combo_used := false; var nerve_strike_freeze_active := false; var nerve_strike_slash_triggered := false
var nerve_strike_release_ball_hit_pending := false; var nerve_strike_release_ball_hit_paddle_x := 0.0; var nerve_strike_release_ball_hit_paddle_w := 155.0; var nerve_strike_release_ball_hit_pos := Vector2.ZERO
var nerve_strike_slash_vfx_frames := 0.0; var nerve_strike_slash_center := Vector2.ZERO; var nerve_strike_cast_id := 0
var nerve_strike_miss_text_timer := 0.0; var nerve_strike_miss_text_pos := Vector2.ZERO; var nerve_strike_clone_slashes: Array = []
var dive_hold_start_msec := 0; var dive_hold_ratio := 0.0; var dive_hold_player_pos := Vector2.ZERO; var dive_hold_paddle_size := Vector2(155.0, 50.0); var dive_charge_particles: Array = []
var dive_active := false; var dive_phase := 0; var dive_phase_frames := 0.0; var dive_player_pos := Vector2.ZERO; var dive_paddle_size := Vector2(155.0, 50.0); var dive_floor_y := 700.0
var dive_height_snapshot := 0.0; var dive_prep_frames_snapshot := DIVE_PREP_FRAMES; var dive_shockwave_timer := 0.0; var dive_shockwave_pos := Vector2.ZERO
var dive_shockwave_max_radius := DIVE_SHOCKWAVE_BASE_MAX_RADIUS; var dive_shockwave_boss_effect_applied := false; var dive_ball_boosted := false; var dive_particles: Array = []
var dive_slip_timer := 0.0; var dive_slip_duration := 0.0; var dive_slip_vel := 0.0
var dive_hit_text_timer := 0.0; var dive_hit_text_pos := Vector2.ZERO; var dive_hit_text_height_ratio := 0.0
var dive_effect_start_msec := 0; var dive_shockwave_spawn_msec := 0; var dive_hit_feedback_msec := 0
var ignition_hold_start_msec := 0; var ignition_hold_ratio := 0.0; var ignition_hold_player_pos := Vector2.ZERO; var ignition_hold_paddle_size := Vector2(155.0, 50.0)
var ignition_active := false; var ignition_remaining_frames := 0.0; var ignition_total_frames := IGNITION_DURATION_FRAMES; var ignition_player_pos := Vector2.ZERO; var ignition_paddle_size := Vector2(155.0, 50.0)
var ignition_burst_particles: Array = []; var ignition_charge_particles: Array = []; var ignition_live_embers: Array = []; var ignition_ember_timer := 0.0; var ignition_start_msec := 0
var ignition_aura_effect_texture: Texture2D = null; var ignition_aura_effect_load_attempted := false
var dual_glitch_cmd_buffer: Array = []; var dual_glitch_state := "idle"; var dual_glitch_phase_frames := 0.0; var dual_glitch_active_total_frames := DUAL_GLITCH_ACTIVE_FRAMES
var dual_glitch_locked_player_x := 0.0; var dual_glitch_locked_player_x_valid := false; var dual_glitch_base_pos := Vector2.ZERO; var dual_glitch_paddle_size := Vector2(155.0, 50.0)
var dual_glitch_clones: Array = []; var dual_glitch_clone_dive_entries: Array = []; var dual_glitch_fade_reason := ""; var dual_glitch_start_msec := 0
var marshal_ready := false; var marshal_ready_frames := 0.0; var marshal_phantom_allowed := false; var marshal_ready_from_shadow_step_chain := false; var marshal_ready_from_core_flip_chain := false
var double_marshal_ready := false; var double_marshal_ready_frames := 0.0; var marshal_first_hit_pending := false; var marshal_first_hit_delay_frames := 0.0
var marshal_is_double := false; var marshal_from_shadow_step_chain := false; var marshal_from_core_flip_chain := false; var phantom_kick_knockback_pending := false; var phantom_kick_speed_limit_disabled := false; var kick_skill_knockback_pending_pct := 0; var kick_guard_speed_reduction_pending_pct := 0
var phantom_aura_active := false; var dmk_freeze_active := false; var dmk_freeze_frames := 0.0; var dmk_text_active := false; var dmk_text_frames := 0.0
# Venom Edge strike: front-view eye-slash sheet at the boss back position.
var venom_edge_strike_active := false; var venom_edge_strike_elapsed_frames := 0.0
const VENOM_EDGE_STRIKE_TOTAL_FRAMES := 36.0  # ~0.6s at 60fps, 8 cells -> ~4.5 frames per cell
# Venom Edge stationary: hold Cell 1 behind boss until runtime clears it.
var venom_edge_stationary_active := false; var core_flip_ready_msec := 0; var core_flip_consumed := true; var core_flip_buffered_until_msec := 0; var core_flip_last_dash_start_msec := CORE_FLIP_DASH_START_UNSET_MSEC
var core_flip_attack_active := false; var core_flip_attack_phase := 0; var core_flip_phase_frames := 0.0; var core_flip_paddle_size := CORE_FLIP_DEFAULT_PADDLE_SIZE
var core_flip_origin_center := Vector2.ZERO; var core_flip_target_center := Vector2.ZERO; var core_flip_apex_center := Vector2.ZERO; var core_flip_visual_pos := Vector2.ZERO; var core_flip_return_start_center := Vector2.ZERO
var core_flip_kick_dir := 1; var core_flip_ball_hit := false; var core_flip_spin_angle_degrees := 0.0; var core_flip_spin_sound_started := false; var core_flip_kick_sound_played := false
var core_flip_dark_blade_handoff_frames := 0.0; var core_flip_web_lines: Array = []; var core_flip_miss_text_timer := 0.0; var core_flip_miss_text_pos := Vector2.ZERO
var marshal_active := false; var marshal_phase := 0; var marshal_phase_frames := 0.0; var marshal_paddle_size := Vector2(155.0, 50.0)
var marshal_start_pos := Vector2.ZERO; var marshal_visual_pos := Vector2.ZERO; var marshal_wall_pos := Vector2.ZERO
var marshal_wall_side := 0  # +1 if wall is to viewer-right of start, -1 to viewer-left, 0 inactive
var marshal_reclimb_start_pos := Vector2.ZERO; var marshal_charge_start_pos := Vector2.ZERO; var marshal_return_start_pos := Vector2.ZERO
var marshal_ball_hit := false; var marshal_activation_msec := -100000; var marshal_hit_msec := -100000
var marshal_last_hit_pos := Vector2.ZERO; var marshal_charge_target_pos := Vector2.ZERO; var marshal_web_lines: Array = []; var marshal_particles: Array = []; var phantom_hit_particles: Array = []
var chaos_cmd_buffer: Array = []; var chaos_state := "idle"; var chaos_phase_frames := 0.0
var chaos_origin := Vector2.ZERO; var chaos_target := Vector2.ZERO; var chaos_current := Vector2.ZERO
var chaos_prev_ball_center := Vector2.ZERO; var chaos_prev_ball_valid := false; var chaos_blackhole_ball_origin := Vector2.ZERO; var chaos_blackhole_origin_valid := false
var chaos_base_radius := 52.0; var chaos_orbit_seed := 0.0; var chaos_flight_angle := 0.0; var chaos_impact_seed := 0.0
var chaos_locked_player_x := 0.0; var chaos_locked_player_x_valid := false; var chaos_absorb_pulses: Array = []
var chaos_cancel_flash_frames := 0.0; var chaos_absorb_poll_frames := 0.0; var chaos_gold_ticks_paid := 0; var chaos_explosion_shaken := false
var chaos_fx_host: Node = null; var chaos_fx_host_add_pending := false; var chaos_fx_spawn_msec_seed: int = 0
var emp_fx_host: Node = null; var emp_fx_host_add_pending := false; var chaos_release_pending := false; var chaos_release_velocity := Vector2.ZERO
var viper_hologram_attack_left_sheet: Texture2D; var viper_hologram_attack_right_sheet: Texture2D
var _asset_prewarm_step_index := 0
func _init() -> void:
	pass
func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass
func prewarm_assets_step() -> bool:
	match _asset_prewarm_step_index:
		0:
			ImpactFlareTextureCache.prewarm()
		1:
			ImpactShockwaveTextureCache.prewarm()
		2:
			if not bool(ChaosSpearFxHost.prewarm_assets_step()):
				return false
		3:
			if not bool(EmpStrikeFxHost.prewarm_assets_step()):
				return false
		4:
			if not bool(particle_drawer.prewarm_ignition_aura_assets(self, IGNITION_AURA_EFFECT_SHEET_PATH)):
				return false
		_:
			_asset_prewarm_step_index = 0
			return true
	_asset_prewarm_step_index += 1
	return false
func prewarm_runtime_nodes(owner: Object = null) -> void: fx_host_controller.prewarm_viper_fx_hosts(self, owner)
func prewarm_runtime_nodes_step(owner: Object = null) -> bool:
	prewarm_runtime_nodes(owner)
	return true
func reset() -> void: reset_round({"preserve_ignition_aura": false, "preserve_dual_glitch": false})
func reset_round(deps: Dictionary = {}) -> void: ViperSkillResetRuntime.reset_round(self, deps, {"core_flip_input_frame_unset": CORE_FLIP_INPUT_FRAME_UNSET, "shadow_step_activation_unset_msec": -100000, "ignition_duration_frames": IGNITION_DURATION_FRAMES})
func _clear_dmk_presentation_state() -> void: dmk_freeze_active = false; dmk_freeze_frames = 0.0; dmk_text_active = false; dmk_text_frames = 0.0
func open_marshal_kick_window(from_shadow_step_chain: bool = false, from_core_flip_chain: bool = false) -> void:
	if marshal_active:
		return
	marshal_ready = true; marshal_ready_frames = MARSHAL_KICK_READY_FRAMES; marshal_phantom_allowed = true; marshal_ready_from_shadow_step_chain = from_shadow_step_chain; marshal_ready_from_core_flip_chain = from_core_flip_chain
	_clear_double_marshal_ready_window()
func _clear_marshal_ready_window() -> void: marshal_ready = false; marshal_ready_frames = 0.0; marshal_ready_from_shadow_step_chain = false; marshal_ready_from_core_flip_chain = false
func _clear_double_marshal_ready_window() -> void: double_marshal_ready = false; double_marshal_ready_frames = 0.0
func _clear_marshal_first_hit_pending() -> void: marshal_first_hit_pending = false; marshal_first_hit_delay_frames = 0.0
func try_activate_before_movement(delta: float, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary) -> Dictionary: return ViperSkillActivationRuntime.try_activate_before_movement(self, delta, player_pos, special_gauge, config, deps, _get_activation_runtime_constants())
func _get_activation_runtime_constants() -> Dictionary: return {"shadow_step": SHADOW_STEP, "marshal_kick": MARSHAL_KICK, "phantom_kick": PHANTOM_KICK, "blade_rush": BLADE_RUSH, "dark_blade": DARK_BLADE, "nerve_strike": NERVE_STRIKE, "chaos_spear": CHAOS_SPEAR, "core_flip": CORE_FLIP, "dive_strike": DIVE_STRIKE, "dual_glitch": DUAL_GLITCH, "ignition_aura": IGNITION_AURA, "shadow_step_ready_frames": SHADOW_STEP_READY_FRAMES, "shadow_step_kick_ready_frames": SHADOW_STEP_KICK_READY_FRAMES, "shadow_step_phantom_frames": SHADOW_STEP_PHANTOM_FRAMES, "chaos_cmd_window_msec": CHAOS_CMD_WINDOW_MSEC, "chaos_cmd_buffer_max": CHAOS_CMD_BUFFER_MAX, "chaos_cooldown_seconds": 30.0, "core_flip_ready_window_msec": CORE_FLIP_READY_WINDOW_MSEC, "core_flip_input_frame_gap": CORE_FLIP_INPUT_FRAME_GAP, "core_flip_input_max_age_frames": CORE_FLIP_INPUT_MAX_AGE_FRAMES, "core_flip_fallback_cost": 120.0, "core_flip_start_shake_amount": CORE_FLIP_START_SHAKE_AMOUNT, "core_flip_start_shake_intensity": CORE_FLIP_START_SHAKE_INTENSITY, "core_flip_apex_offset_y": CORE_FLIP_APEX_OFFSET_Y, "dual_glitch_window_msec": DUAL_GLITCH_CMD_WINDOW_MSEC, "dual_glitch_active_frames": DUAL_GLITCH_ACTIVE_FRAMES, "dual_glitch_duration_pct_values": FOUR_POISONS_DUAL_GLITCH_DURATION_PCT_BY_LEVEL, "dual_glitch_duration_pct_cap": FOUR_POISONS_DUAL_GLITCH_DURATION_PCT_CAP, "dual_glitch_duration_pct_per_extra": FOUR_POISONS_DUAL_GLITCH_DURATION_PCT_PER_EXTRA_LEVEL, "dual_glitch_clone_hp_values": FOUR_POISONS_DUAL_GLITCH_CLONE_HP_BY_LEVEL, "dual_glitch_clone_hp_cap": FOUR_POISONS_DUAL_GLITCH_CLONE_HP_CAP, "dual_glitch_cooldown_seconds": 40.0, "nerve_window_start_frames": NERVE_STRIKE_WINDOW_START_FRAMES, "nerve_window_end_frames": NERVE_STRIKE_WINDOW_END_FRAMES, "nerve_dark_blade_split_frames": NERVE_STRIKE_DARK_BLADE_SPLIT_FRAMES, "nerve_fallback_cost": 90.0, "nerve_cooldown_base": 35.0, "ignition_hold_required_msec": IGNITION_HOLD_REQUIRED_MSEC, "ignition_duration_frames": IGNITION_DURATION_FRAMES, "ignition_gauge_cost": IGNITION_GAUGE_COST, "ignition_particle_limit": IGNITION_PARTICLE_LIMIT, "ignition_charge_particle_limit": IGNITION_CHARGE_PARTICLE_LIMIT, "ignition_fallback_cooldown_seconds": 70.0, "dive_gauge_cost": DIVE_GAUGE_COST, "dive_hold_required_msec": DIVE_HOLD_REQUIRED_MSEC, "dive_charge_particle_limit": DIVE_CHARGE_PARTICLE_LIMIT, "dive_min_airborne_height": 20.0}
func observe_after_movement(delta: float, before_player_pos: Vector2, _after_player_pos: Vector2, deps: Dictionary) -> void:
	if dual_glitch_state in ["spawn", "active", "fade"]:
		dual_glitch_base_pos = _after_player_pos
	var dash_snapshot: Dictionary = visibility_query.get_dash_snapshot(deps.get("dash_state", null)); var dash_active: bool = bool(dash_snapshot.get("active", false)); var dash_recovering: bool = bool(dash_snapshot.get("recovering", false))
	if dash_active and not previous_dash_active:
		dash_origin_pos = before_player_pos; dash_origin_valid = true; core_flip_last_dash_start_msec = Time.get_ticks_msec(); core_flip_consumed = bool(dash_snapshot.get("is_half", false)); core_flip_ready_msec = 0; core_flip_buffered_until_msec = 0
	if dash_active or dash_recovering:
		dash_grace_frames = SHADOW_STEP_DASH_GRACE_FRAMES
	else:
		dash_grace_frames = max(0.0, dash_grace_frames - delta * 60.0)
		if dash_grace_frames <= 0.0:
			dash_origin_valid = false
	previous_dash_active = dash_active; previous_dash_recovering = dash_recovering
func get_snapshot() -> Dictionary: return snapshot_builder.build(self)
func is_air_blade_dash_window_open(deps: Dictionary = {}) -> bool: return (blade_motion_active and blade_motion_phase == 2) and not blade_dark_mode and blade_motion_frames >= BLADE_DASH_RELEASE_DELAY_FRAMES and not visibility_query.is_control_locked(deps)
func is_dark_blade_rising_contact_active() -> bool: return blade_motion_active and blade_dark_mode and blade_motion_phase == 2 and blade_motion_frames <= BLADE_DARK_RISE_FRAMES
func sync_blade_motion_position(player_pos: Vector2) -> void:
	if blade_motion_active:
		blade_motion_pos = player_pos
func get_actor_draw_context() -> Dictionary: return context_builder.build_actor_draw_context(self)
func get_ball_collision_context() -> Dictionary: return context_builder.build_ball_collision_context(self)
func get_blade_hit_speed_cap() -> float: return max(0.0, blade_hit_speed_cap_active)
func clear_blade_hit_speed_cap() -> void: blade_hit_speed_cap_active = 0.0
func is_phantom_kick_speed_limit_disabled() -> bool: return phantom_kick_speed_limit_disabled
func get_boss_ai_context() -> Dictionary: return context_builder.build_boss_ai_context(self)
func get_emp_shockwave_progress() -> float: return ViperSkillGeometry.emp_strike_shockwave_progress(dive_shockwave_timer, dive_shockwave_pos, DIVE_SHOCKWAVE_FRAMES)
func get_emp_shockwave_radius() -> float: return ViperSkillGeometry.emp_strike_shockwave_radius(dive_shockwave_timer, dive_shockwave_pos, DIVE_SHOCKWAVE_FRAMES, DIVE_SHOCKWAVE_START_RADIUS, dive_shockwave_max_radius)
func is_kick_skill_knockback_ball_active() -> bool: return visibility_query.is_kick_skill_knockback_ball_active(self)
func is_dmk_freeze_active() -> bool: return visibility_query.is_dmk_freeze_active(self)
func begin_phantom_kick_cutin(duration: float) -> void: cutin_state.begin(duration, PHANTOM_KICK)
func is_cutin_active() -> bool: return cutin_state.is_active()
func get_cutin_progress() -> float: return cutin_state.get_progress()
func get_cutin_phase() -> String: return cutin_state.get_phase()
func has_visible_effects() -> bool: return visibility_query.has_visible_effects(self)
func needs_ball_motion_update() -> bool: return visibility_query.needs_ball_motion_update(self)
func needs_effect_update() -> bool: return visibility_query.needs_effect_update(self)
func is_chaos_blackhole_audio_active() -> bool: return visibility_query.is_chaos_blackhole_audio_active(self)
func update_effects(fps_scale: float, _current_msec: int, context: Dictionary, deps: Dictionary) -> Dictionary:
	ViperSkillShadowStepRuntime.update_effects(self, fps_scale, context, deps, {"hologram_frames": SHADOW_STEP_HOLOGRAM_FRAMES, "marshal_kick": MARSHAL_KICK, "phantom_kick": PHANTOM_KICK, "starburst_frames": SHADOW_STEP_STARBURST_FRAMES, "starburst_frame_duration": SHADOW_STEP_STARBURST_FRAME_DURATION})
	ViperSkillBladeWindowRuntime.update_windows(self, fps_scale, context, deps, {"combo_delay_frames": BLADE_COMBO_DELAY_FRAMES})
	ViperSkillTransientEffectRuntime.update_nerve_transients(self, fps_scale)
	ViperSkillNerveCloneRuntime.update_clone_slashes(self, fps_scale, context, deps, {"travel_frames": DUAL_GLITCH_NERVE_TRAVEL_FRAMES, "hit_radius": NERVE_STRIKE_HIT_RADIUS, "slash_frames": DUAL_GLITCH_NERVE_SLASH_FRAMES})
	ViperSkillTransientEffectRuntime.update_dive_and_core_transients(self, fps_scale)
	ViperSkillMarshalWindowRuntime.update_windows(self, fps_scale, context, deps, {"marshal_kick": MARSHAL_KICK, "phantom_kick": PHANTOM_KICK, "double_marshal_kick": DOUBLE_MARSHAL_KICK, "marshal_ready_frames": MARSHAL_KICK_READY_FRAMES})
	ViperSkillTransientEffectRuntime.update_venom_and_marshal_transients(self, fps_scale, VENOM_EDGE_STRIKE_TOTAL_FRAMES)
	if cutin_state.is_active():
		cutin_state.update(fps_scale / 60.0)
	ViperSkillIgnitionAuraRuntime.update_effects(self, fps_scale, context, deps, {"ember_interval_frames": IGNITION_EMBER_INTERVAL_FRAMES, "ember_limit": IGNITION_EMBER_LIMIT})
	ViperSkillDualGlitchCloneRuntime.update_clone_lifecycle(self, fps_scale, context, {"startup_frames": DUAL_GLITCH_STARTUP_FRAMES, "spawn_frames": DUAL_GLITCH_SPAWN_FRAMES, "fade_frames": DUAL_GLITCH_FADE_FRAMES, "evaporation_frames": DUAL_GLITCH_EVAPORATION_FRAMES})
	ViperSkillDualGlitchCloneRuntime.update_clone_dive_entries(self, fps_scale, deps, {"telegraph_frames": DUAL_GLITCH_DIVE_TELEGRAPH_FRAMES, "shockwave_frames": DIVE_SHOCKWAVE_FRAMES, "particle_limit": DIVE_PARTICLE_LIMIT})
	return ViperSkillChaosSpearRuntime.update_effects(self, fps_scale, context, deps, {"startup_frames": CHAOS_STARTUP_FRAMES, "travel_frames": CHAOS_TRAVEL_FRAMES, "impact_frames": CHAOS_IMPACT_FRAMES, "blackhole_frames": CHAOS_BLACKHOLE_FRAMES, "fade_frames": CHAOS_FADE_FRAMES, "prep_reduction_values": FOUR_POISONS_PREP_REDUCTION_PCT_BY_LEVEL, "prep_reduction_cap": FOUR_POISONS_PREP_REDUCTION_PCT_CAP, "prep_reduction_per_extra": FOUR_POISONS_PREP_REDUCTION_PCT_PER_EXTRA_LEVEL})
func apply_shadow_step_ball_motion(fps_scale: float, scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	return ViperSkillShadowStepBallMotionRuntime.apply_motion(self, fps_scale, scene, context, deps, {"wave_speed": SHADOW_STEP_WAVE_SPEED, "wave_trail_max": SHADOW_STEP_WAVE_TRAIL_MAX, "wave_collision_size": SHADOW_STEP_WAVE_COLLISION_SIZE, "wave_gradient_size": SHADOW_STEP_WAVE_GRADIENT_SIZE, "hologram_frames": SHADOW_STEP_HOLOGRAM_FRAMES})
func _get_shadow_step_hit_constants() -> Dictionary: return {"dark_blade": DARK_BLADE, "core_flip_dash_start_valid_after_msec": CORE_FLIP_DASH_START_VALID_AFTER_MSEC, "marshal_delay_frames": SHADOW_STEP_MARSHAL_DELAY_FRAMES, "hit_speed_min": SHADOW_STEP_HIT_SPEED_MIN, "hit_speed_max": SHADOW_STEP_HIT_SPEED_MAX, "hit_curve_min": SHADOW_STEP_HIT_CURVE_MIN, "hit_curve_max": SHADOW_STEP_HIT_CURVE_MAX, "hit_force_min": SHADOW_STEP_HIT_FORCE_MIN, "hit_force_max": SHADOW_STEP_HIT_FORCE_MAX, "min_hit_speed": SHADOW_STEP_MIN_HIT_SPEED, "hit_gold": SHADOW_STEP_HIT_GOLD, "airborne_gold_mult": SHADOW_STEP_AIRBORNE_GOLD_MULT, "shake_amount_base": SHADOW_HIT_SHAKE_AMOUNT_BASE, "shake_amount_center_bonus": SHADOW_HIT_SHAKE_AMOUNT_CENTER_BONUS, "shake_intensity_base": SHADOW_HIT_SHAKE_INTENSITY_BASE, "shake_intensity_center_bonus": SHADOW_HIT_SHAKE_INTENSITY_CENTER_BONUS, "particle_intensity_base": SHADOW_HIT_PARTICLE_INTENSITY_BASE, "particle_intensity_center_bonus": SHADOW_HIT_PARTICLE_INTENSITY_CENTER_BONUS, "energy_scale_base": SHADOW_HIT_ENERGY_SCALE_BASE, "energy_scale_center_bonus": SHADOW_HIT_ENERGY_SCALE_CENTER_BONUS, "energy_intensity_base": SHADOW_HIT_ENERGY_INTENSITY_BASE, "energy_intensity_center_bonus": SHADOW_HIT_ENERGY_INTENSITY_CENTER_BONUS}
func apply_blade_rush_ball_motion(fps_scale: float, scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	return ViperSkillBladeBallMotionRuntime.apply_motion(self, fps_scale, scene, context, deps, {"projectile_speed": BLADE_PROJECTILE_SPEED, "trail_max": BLADE_TRAIL_MAX, "followup_trail_max": BLADE_FOLLOWUP_TRAIL_MAX, "hitbox_height": BLADE_HITBOX_HEIGHT, "dark_hitbox_height": BLADE_DARK_HITBOX_HEIGHT, "fadeout_frames": BLADE_FADEOUT_FRAMES, "base_width": BLADE_BASE_WIDTH})
func apply_chaos_spear_ball_motion(fps_scale: float, scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	return ViperSkillChaosSpearBallMotionRuntime.apply_motion(self, fps_scale, scene, context, deps, {"blackhole_frames": CHAOS_BLACKHOLE_FRAMES, "ingress_frames": CHAOS_INGRESS_FRAMES, "gold_tick_frames": CHAOS_GOLD_TICK_FRAMES, "gold_per_tick": CHAOS_GOLD_PER_TICK, "object_gold": CHAOS_OBJECT_GOLD, "pull_radius": CHAOS_PULL_RADIUS, "absorb_poll_frames": 5.4})
func apply_emp_strike_ball_motion(_fps_scale: float, scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	return ViperSkillEmpStrikeBallMotionRuntime.apply_motion(self, scene, context, deps, _get_emp_strike_runtime_constants())
func _get_contact_runtime_constants() -> Dictionary: return {"core_flip": CORE_FLIP, "core_flip_dash_start_valid_after_msec": CORE_FLIP_DASH_START_VALID_AFTER_MSEC, "core_flip_dash_success_window_msec": CORE_FLIP_DASH_SUCCESS_WINDOW_MSEC, "phantom_kick_knockback_distance": PHANTOM_KICK_KNOCKBACK_DISTANCE, "phantom_kick_knockback_frames": PHANTOM_KICK_KNOCKBACK_FRAMES, "phantom_kick_knockback_decay": PHANTOM_KICK_KNOCKBACK_DECAY, "kick_guard_knockback_fire_base": KICK_GUARD_KNOCKBACK_FIRE_BASE, "kick_guard_distance_multiplier": KICK_GUARD_DISTANCE_MULTIPLIER, "kick_guard_knockback_frames": KICK_GUARD_KNOCKBACK_FRAMES, "kick_guard_knockback_decay": KICK_GUARD_KNOCKBACK_DECAY, "kick_guard_speed_reduction_pct": KICK_GUARD_BALL_SPEED_REDUCTION_PCT, "shadow_step_activation_valid_after_msec": SHADOW_STEP_ACTIVATION_VALID_AFTER_MSEC, "shadow_step_paddle_hit_window_msec": SHADOW_STEP_PADDLE_HIT_WINDOW_MSEC, "shadow_step_paddle_hit_padding": SHADOW_STEP_PADDLE_HIT_PADDING, "shadow_step_paddle_hit_source": SHADOW_STEP_PADDLE_HIT_SOURCE}
func register_player_ball_contact(deps: Dictionary = {}, _context: Dictionary = {}) -> void: ViperSkillContactRuntime.register_player_ball_contact(self, deps, _get_contact_runtime_constants())
func release_chaos_blackhole_from_hit(deps: Dictionary = {}, context: Dictionary = {}) -> bool:
	return _release_chaos_blackhole_from_hit_result(deps, context)
func _reset_core_flip_runtime(clear_window: bool = false) -> void:
	if clear_window:
		core_flip_consumed = true; core_flip_ready_msec = 0; core_flip_buffered_until_msec = 0; core_flip_last_dash_start_msec = CORE_FLIP_DASH_START_UNSET_MSEC
	core_flip_attack_active = false; core_flip_attack_phase = 0; core_flip_phase_frames = 0.0; core_flip_paddle_size = CORE_FLIP_DEFAULT_PADDLE_SIZE; core_flip_origin_center = Vector2.ZERO; core_flip_target_center = Vector2.ZERO; core_flip_apex_center = Vector2.ZERO; core_flip_visual_pos = Vector2.ZERO; core_flip_return_start_center = Vector2.ZERO; core_flip_kick_dir = 1; core_flip_ball_hit = false; core_flip_spin_angle_degrees = 0.0; core_flip_spin_sound_started = false; core_flip_kick_sound_played = false
	if clear_window:
		core_flip_dark_blade_handoff_frames = 0.0; core_flip_miss_text_timer = 0.0; core_flip_miss_text_pos = Vector2.ZERO
	core_flip_web_lines.clear()
func _is_core_flip_ready_window_active(now_msec: int) -> bool:
	if core_flip_ready_msec <= 0 or core_flip_consumed or (core_flip_last_dash_start_msec > CORE_FLIP_DASH_START_VALID_AFTER_MSEC and core_flip_ready_msec < core_flip_last_dash_start_msec):
		return false
	if now_msec > core_flip_ready_msec + CORE_FLIP_READY_WINDOW_MSEC:
		core_flip_ready_msec = 0; core_flip_buffered_until_msec = 0
		return false
	return true
func _has_viper_attack_motion_active(include_dive: bool = false) -> bool: return (include_dive and dive_active) or core_flip_attack_active or marshal_active or blade_motion_active or blade_projectile_active
func _get_skill_cost_with_fallback(skill_config: Object, skill_name: String, fallback_cost: float) -> float: var configured_cost: float = visibility_query.get_skill_cost(skill_config, skill_name); return configured_cost if configured_cost > 0.0 else fallback_cost
func _get_skill_cooldown_seconds_with_fallback(skill_config: Object, skill_name: String, fallback_seconds: float, reject_nonpositive: bool = true) -> float: var cooldown_seconds: float = float(skill_config.get_cooldown_seconds(skill_name)) if skill_config != null and skill_config.has_method("get_cooldown_seconds") else fallback_seconds; return fallback_seconds if reject_nonpositive and cooldown_seconds <= 0.0 else cooldown_seconds
func _can_activate_configured_skill(skill_config: Object, special_gauge: float, deps: Dictionary, skill_name: String, now_msec: int = -1) -> bool: return visibility_query.is_skill_equipped(skill_config, skill_name) and special_gauge >= visibility_query.get_skill_cost(skill_config, skill_name) and visibility_query.is_configured_skill_ready(skill_name, deps, now_msec)
func _has_lateral_skill_input(input_snapshot: Dictionary) -> bool: return bool(input_snapshot.get("left_pressed", false)) or bool(input_snapshot.get("right_pressed", false)) or abs(float(input_snapshot.get("direction", 0.0))) > 0.01
func _update_core_flip(delta: float, _player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary) -> Dictionary:
	return ViperSkillCoreFlipRuntime.update_motion(self, delta, special_gauge, config, deps, {"core_flip": CORE_FLIP, "dark_blade": DARK_BLADE, "phase0_frames": CORE_FLIP_PHASE0_FRAMES, "phase1_frames": CORE_FLIP_PHASE1_FRAMES, "phase2_frames": CORE_FLIP_PHASE2_FRAMES, "phase3_frames": CORE_FLIP_PHASE3_FRAMES, "zigzag_leg_frames": CORE_FLIP_ZIGZAG_LEG_FRAMES, "zigzag_cling_frames": CORE_FLIP_ZIGZAG_CLING_FRAMES, "kick_trigger_y": CORE_FLIP_KICK_TRIGGER_Y, "hit_radius": CORE_FLIP_HIT_RADIUS, "speed_mult": CORE_FLIP_SPEED_MULT, "min_speed": CORE_FLIP_MIN_SPEED, "marshal_curve_frames": MARSHAL_KICK_CURVE_FRAMES, "marshal_curve_force": MARSHAL_KICK_CURVE_FORCE, "marshal_delay_frames": CORE_FLIP_MARSHAL_DELAY_FRAMES, "hit_shake_amount": CORE_FLIP_HIT_SHAKE_AMOUNT, "hit_shake_intensity": CORE_FLIP_HIT_SHAKE_INTENSITY, "hit_pulse_intensity": CORE_FLIP_HIT_PULSE_INTENSITY, "hit_pulse_kind": CORE_FLIP_HIT_PULSE_KIND, "hit_motion_count": CORE_FLIP_HIT_MOTION_PARTICLE_COUNT, "hit_motion_spread": CORE_FLIP_HIT_MOTION_PARTICLE_SPREAD, "hit_motion_kind": CORE_FLIP_HIT_MOTION_PARTICLE_KIND, "hit_motion_chance": CORE_FLIP_HIT_MOTION_PARTICLE_CHANCE, "hit_motion_life_min": CORE_FLIP_HIT_MOTION_PARTICLE_LIFE_MIN, "hit_motion_life_max": CORE_FLIP_HIT_MOTION_PARTICLE_LIFE_MAX, "hit_gold": CORE_FLIP_HIT_GOLD, "dark_blade_handoff_frames": CORE_FLIP_DARK_BLADE_HANDOFF_FRAMES, "miss_text_frames": CORE_FLIP_MISS_TEXT_FRAMES, "apex_offset_y": CORE_FLIP_APEX_OFFSET_Y})
func consume_phantom_kick_knockback(ball_pos: Vector2, boss_pos: Vector2, boss_width: float, deps: Dictionary = {}) -> Dictionary: return ViperSkillContactRuntime.consume_phantom_kick_knockback(self, ball_pos, boss_pos, boss_width, deps, _get_contact_runtime_constants())
func consume_kick_skill_knockback(ball_pos: Vector2, boss_pos: Vector2, boss_width: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary: return ViperSkillContactRuntime.consume_kick_skill_knockback(self, ball_pos, boss_pos, boss_width, context, deps, _get_contact_runtime_constants())
func consume_kick_guard_speed_reduction(ball_vel: Vector2, context: Dictionary, deps: Dictionary = {}) -> Dictionary: return ViperSkillContactRuntime.consume_kick_guard_speed_reduction(self, ball_vel, context, deps, _get_contact_runtime_constants())
func _is_stage2_speed_defense_boss_immune(context: Dictionary = {}, deps: Dictionary = {}) -> bool:
	return visibility_query.is_stage2_speed_defense_boss_immune(context, deps)
func apply_shadow_step_paddle_hit(ball_vel: Vector2, context: Dictionary, deps: Dictionary = {}) -> Dictionary: return ViperSkillContactRuntime.apply_shadow_step_paddle_hit(self, ball_vel, context, deps, _get_contact_runtime_constants())
func _clear_shadow_kick_ready() -> void: shadow_kick_ready = false; shadow_kick_ready_frames = 0.0
func _get_draw_runtime_constants() -> Dictionary: return {"dive_shockwave_frames": DIVE_SHOCKWAVE_FRAMES, "dive_jetpack_max_height": DIVE_JETPACK_MAX_HEIGHT, "dive_hit_text_frames": DIVE_HIT_TEXT_FRAMES, "dual_glitch_dive_telegraph_frames": DUAL_GLITCH_DIVE_TELEGRAPH_FRAMES, "dive_hit_text_float_y": DIVE_HIT_TEXT_FLOAT_Y, "ignition_aura_effect_sheet_path": IGNITION_AURA_EFFECT_SHEET_PATH, "ignition_aura_effect_sheet_cols": IGNITION_AURA_EFFECT_SHEET_COLS, "ignition_aura_effect_sheet_rows": IGNITION_AURA_EFFECT_SHEET_ROWS, "ignition_aura_effect_frame_interval_msec": IGNITION_AURA_EFFECT_FRAME_INTERVAL_MSEC, "ignition_timer_bar_size": IGNITION_TIMER_BAR_SIZE, "ignition_timer_bar_margin": IGNITION_TIMER_BAR_MARGIN, "ignition_timer_stack_spacing": IGNITION_TIMER_STACK_SPACING, "ignition_timer_stack_key": IGNITION_TIMER_STACK_KEY, "dual_glitch_startup_frames": DUAL_GLITCH_STARTUP_FRAMES, "dual_glitch_spawn_frames": DUAL_GLITCH_SPAWN_FRAMES, "dual_glitch_fade_frames": DUAL_GLITCH_FADE_FRAMES, "dual_glitch_evaporation_frames": DUAL_GLITCH_EVAPORATION_FRAMES, "dual_glitch_offset_padding": DUAL_GLITCH_OFFSET_PADDING, "dual_glitch_alpha": DUAL_GLITCH_ALPHA, "dual_glitch_wiggle_amplitude": DUAL_GLITCH_WIGGLE_AMPLITUDE, "dual_glitch_timer_bar_size": DUAL_GLITCH_TIMER_BAR_SIZE, "dual_glitch_timer_bar_margin": DUAL_GLITCH_TIMER_BAR_MARGIN, "dual_glitch_timer_stack_spacing": DUAL_GLITCH_TIMER_STACK_SPACING, "dual_glitch_timer_stack_key": DUAL_GLITCH_TIMER_STACK_KEY, "blade_base_width": BLADE_BASE_WIDTH, "blade_hitbox_height": BLADE_HITBOX_HEIGHT, "blade_dark_hitbox_height": BLADE_DARK_HITBOX_HEIGHT, "blade_fadeout_frames": BLADE_FADEOUT_FRAMES, "blade_rest_frames": BLADE_REST_FRAMES, "blade_dark_rest_frames": BLADE_DARK_REST_FRAMES, "nerve_dash_frames": NERVE_STRIKE_DASH_FRAMES, "nerve_return_hit_frames": NERVE_STRIKE_RETURN_HIT_FRAMES, "nerve_return_miss_frames": NERVE_STRIKE_RETURN_MISS_FRAMES, "nerve_slash_vfx_frames": NERVE_STRIKE_SLASH_VFX_FRAMES, "dual_glitch_nerve_stagger_frames": DUAL_GLITCH_NERVE_STAGGER_FRAMES, "dual_glitch_nerve_slash_frames": DUAL_GLITCH_NERVE_SLASH_FRAMES, "nerve_miss_text_frames": NERVE_STRIKE_MISS_TEXT_FRAMES, "nerve_miss_text_float_y": NERVE_STRIKE_MISS_TEXT_FLOAT_Y, "core_flip_phase0_frames": CORE_FLIP_PHASE0_FRAMES, "core_flip_phase2_frames": CORE_FLIP_PHASE2_FRAMES, "core_flip_miss_text_frames": CORE_FLIP_MISS_TEXT_FRAMES, "core_flip_miss_text_float_y": CORE_FLIP_MISS_TEXT_FLOAT_Y, "viper_hit_particle_glow_size_threshold": VIPER_HIT_PARTICLE_GLOW_SIZE_THRESHOLD, "marshal_dmk_freeze_frames": MARSHAL_KICK_DMK_FREEZE_FRAMES, "marshal_dmk_text_frames": MARSHAL_KICK_DMK_TEXT_FRAMES, "shadow_step_hologram_frames": SHADOW_STEP_HOLOGRAM_FRAMES, "viper_hologram_base_visual_size": VIPER_HOLOGRAM_BASE_VISUAL_SIZE, "viper_hologram_base_paddle_width": VIPER_HOLOGRAM_BASE_PADDLE_WIDTH, "viper_hologram_feet_offset": VIPER_HOLOGRAM_FEET_OFFSET, "shadow_step_starburst_frames": SHADOW_STEP_STARBURST_FRAMES, "chaos_startup_frames": CHAOS_STARTUP_FRAMES, "chaos_travel_frames": CHAOS_TRAVEL_FRAMES, "chaos_impact_frames": CHAOS_IMPACT_FRAMES, "chaos_blackhole_frames": CHAOS_BLACKHOLE_FRAMES, "chaos_fade_frames": CHAOS_FADE_FRAMES, "chaos_fx_disk_height": CHAOS_FX_DISK_HEIGHT, "chaos_visual_length": CHAOS_VISUAL_LENGTH}
func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO, node_fx_layout: Dictionary = {}, timer_stack: Object = null, perf_logger: Object = null, effect_lod_scale: float = 1.0) -> void: ViperSkillDrawRuntime.draw(self, canvas, shake_offset, node_fx_layout, timer_stack, perf_logger, effect_lod_scale, _get_draw_runtime_constants())
# Venom Edge runtime trigger for the behind-boss eye-slash strike.
func trigger_venom_edge_strike() -> void: venom_edge_strike_active = true; venom_edge_strike_elapsed_frames = 0.0
# Post-arrival stationary hold; strike state overrides it in the renderer.
func start_venom_edge_stationary() -> void: venom_edge_stationary_active = true
func end_venom_edge_stationary() -> void: venom_edge_stationary_active = false
func _clear_phantom_kick_chain_window() -> void: marshal_phantom_allowed = false; marshal_from_shadow_step_chain = false; marshal_from_core_flip_chain = false; _clear_double_marshal_ready_window(); _clear_marshal_first_hit_pending()
func _can_start_chaos_spear(special_gauge: float, config: Dictionary, deps: Dictionary, now_msec: int) -> bool: return ViperSkillChaosSpearRuntime.can_start(self, special_gauge, config, deps, now_msec, {"skill_name": CHAOS_SPEAR})
func _start_chaos_spear(player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, now_msec: int) -> Dictionary: return ViperSkillChaosSpearRuntime.start(self, player_pos, special_gauge, config, deps, now_msec, {"skill_name": CHAOS_SPEAR, "cooldown_seconds": 30.0})
func _release_chaos_blackhole(early_hit: bool, context: Dictionary, deps: Dictionary) -> void:
	if chaos_state != "blackhole":
		return
	if early_hit:
		chaos_release_pending = false; chaos_release_velocity = Vector2.ZERO
	else:
		var current_vel: Vector2 = _get_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO); var release_speed: float = max(max(16.0, 8.0 * 2.0), current_vel.length() * 1.6); var release_angle: float = randf_range(0.0, TAU)
		chaos_release_velocity = Vector2(cos(release_angle), sin(release_angle)) * release_speed; chaos_release_pending = true
	chaos_prev_ball_valid = false; chaos_blackhole_origin_valid = false; chaos_state = "fade"; chaos_phase_frames = 0.0
	if early_hit:
		chaos_cancel_flash_frames = 16.0
	audio_router.stop_chaos_phase_sounds(deps)
func _release_chaos_blackhole_from_hit_result(deps: Dictionary, context: Dictionary = {}) -> bool:
	if chaos_state != "blackhole":
		return false
	_release_chaos_blackhole(true, context, deps)
	return true
func _mark_result_released_chaos_hit(result: Dictionary, released: bool) -> Dictionary:
	if released:
		result["skip_ball_motion_step"] = false
	return result
func _reset_dual_glitch_runtime(clear_command: bool = false) -> void:
	dual_glitch_state = "idle"; dual_glitch_phase_frames = 0.0; dual_glitch_active_total_frames = DUAL_GLITCH_ACTIVE_FRAMES; dual_glitch_locked_player_x = 0.0; dual_glitch_locked_player_x_valid = false; dual_glitch_base_pos = Vector2.ZERO; dual_glitch_paddle_size = Vector2(155.0, 50.0)
	dual_glitch_clones.clear(); dual_glitch_clone_dive_entries.clear(); dual_glitch_fade_reason = ""; dual_glitch_start_msec = 0
	if clear_command:
		dual_glitch_cmd_buffer.clear()
func _reset_chaos_spear_runtime(clear_command: bool = false, deps: Dictionary = {}) -> void:
	audio_router.stop_all_chaos_spear_sounds(deps)
	chaos_state = "idle"; chaos_phase_frames = 0.0; chaos_origin = Vector2.ZERO; chaos_target = Vector2.ZERO; chaos_current = Vector2.ZERO; chaos_prev_ball_center = Vector2.ZERO; chaos_prev_ball_valid = false; chaos_blackhole_ball_origin = Vector2.ZERO; chaos_blackhole_origin_valid = false; chaos_base_radius = 52.0
	chaos_orbit_seed = 0.0; chaos_flight_angle = 0.0; chaos_impact_seed = 0.0; chaos_locked_player_x = 0.0; chaos_locked_player_x_valid = false; chaos_absorb_pulses.clear(); chaos_cancel_flash_frames = 0.0; chaos_absorb_poll_frames = 0.0; chaos_gold_ticks_paid = 0
	chaos_explosion_shaken = false; chaos_release_pending = false; chaos_release_velocity = Vector2.ZERO
	if clear_command:
		chaos_cmd_buffer.clear()
	fx_host_controller.hide_fx_host(chaos_fx_host)
func _get_four_poisons_scaled_pct(deps: Dictionary, values: Array, cap: int, per_extra_level: int) -> int: return skill_scaling.get_four_poisons_scaled_pct(visibility_query.get_runtime_skill_level(deps, "four_poisons"), values, cap, per_extra_level)
func _is_dual_glitch_clone_replication_active(deps: Dictionary) -> bool: return dual_glitch_state == "active" and visibility_query.get_runtime_skill_level(deps, "four_poisons") >= 5
func _enter_dual_glitch_fade(reason: String) -> void:
	if dual_glitch_state == "fade":
		return
	dual_glitch_state = "fade"; dual_glitch_phase_frames = 0.0; dual_glitch_locked_player_x_valid = false; dual_glitch_fade_reason = reason
func get_dual_glitch_clone_rects(context: Dictionary = {}, collision_only: bool = true) -> Array:
	if not context.is_empty():
		dual_glitch_base_pos = _get_vector2(context.get("player_pos", dual_glitch_base_pos), dual_glitch_base_pos); dual_glitch_paddle_size = _get_vector2(context.get("player_paddle_size", dual_glitch_paddle_size), dual_glitch_paddle_size)
	var rects: Array = []
	for entry_value in _get_dual_glitch_clone_rect_entries(collision_only, not collision_only):
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			rects.append(entry.get("rect", Rect2()))
	return rects
func _get_dual_glitch_clone_rect_entries(collision_only: bool, include_evaporating: bool) -> Array:
	return visibility_query.get_dual_glitch_clone_rect_entries(self, collision_only, include_evaporating, DUAL_GLITCH_EVAPORATION_FRAMES, DUAL_GLITCH_OFFSET_PADDING)
func apply_dual_glitch_clone_ball_hit(context: Dictionary = {}, _deps: Dictionary = {}) -> Dictionary:
	if not (dual_glitch_state in ["active", "fade"]):
		return {"hit": false}
	var clone_index: int = int(context.get("viper_dual_glitch_clone_index", -1))
	if clone_index < 0 or clone_index >= dual_glitch_clones.size():
		return {"hit": false}
	var clone_value: Variant = dual_glitch_clones[clone_index]
	if not (clone_value is Dictionary):
		return {"hit": false}
	var clone: Dictionary = clone_value
	if not visibility_query.is_dual_glitch_clone_alive(clone):
		return {"hit": false}
	var hp: int = max(0, int(clone.get("hp", 0)) - 1)
	clone["hp"] = hp
	var destroyed := hp <= 0
	if destroyed:
		clone["collision_enabled"] = false; clone["evaporation_frames"] = 0.0
	dual_glitch_clones[clone_index] = clone
	if destroyed and not visibility_query.has_living_dual_glitch_clone(dual_glitch_clones):
		_enter_dual_glitch_fade("destroyed")
	return {"hit": true, "clone_destroyed": destroyed, "clone_hp": hp}
func _reset_ignition_aura_hold() -> void: ignition_hold_start_msec = 0; ignition_hold_ratio = 0.0; ignition_hold_player_pos = Vector2.ZERO; ignition_hold_paddle_size = Vector2(155.0, 50.0)
func _set_runtime_ignition_aura_bonus(deps: Dictionary, active: bool) -> void:
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	if runtime_perk_state != null and runtime_perk_state.has_method("set_viper_ignition_aura_active"):
		var state_changed := not runtime_perk_state.has_method("is_viper_ignition_aura_active") or bool(runtime_perk_state.is_viper_ignition_aura_active()) != active
		runtime_perk_state.set_viper_ignition_aura_active(active)
		if state_changed and runtime_perk_state.has_method("refresh_viper_ignition_aura_dynamic_effects"):
			runtime_perk_state.refresh_viper_ignition_aura_dynamic_effects(deps.get("registry", null), deps.get("owner", null))
func _get_emp_strike_runtime_constants() -> Dictionary: return {"skill_name": DIVE_STRIKE, "gauge_cost": DIVE_GAUGE_COST, "cooldown_seconds": 70.0, "prep_frames": DIVE_PREP_FRAMES, "speed": DIVE_SPEED, "shockwave_height": DIVE_SHOCKWAVE_HEIGHT, "shockwave_frames": DIVE_SHOCKWAVE_FRAMES, "shockwave_base_max_radius": DIVE_SHOCKWAVE_BASE_MAX_RADIUS, "shockwave_ring_half_thickness": DIVE_SHOCKWAVE_RING_HALF_THICKNESS, "particle_limit": DIVE_PARTICLE_LIMIT, "jetpack_max_height": DIVE_JETPACK_MAX_HEIGHT, "player_collision_cooldown": DIVE_PLAYER_COLLISION_COOLDOWN, "hit_text_frames": DIVE_HIT_TEXT_FRAMES, "hit_gold": 20, "slip_duration_min": DIVE_SLIP_DURATION_MIN, "slip_duration_max": DIVE_SLIP_DURATION_MAX, "slip_speed": DIVE_SLIP_SPEED, "dual_glitch_dive_stagger_frames": DUAL_GLITCH_DIVE_STAGGER_FRAMES, "prep_reduction_values": FOUR_POISONS_PREP_REDUCTION_PCT_BY_LEVEL, "prep_reduction_cap": FOUR_POISONS_PREP_REDUCTION_PCT_CAP, "prep_reduction_per_extra": FOUR_POISONS_PREP_REDUCTION_PCT_PER_EXTRA_LEVEL, "sleep_pct_values": FOUR_POISONS_EMP_SLEEP_PCT_BY_LEVEL, "sleep_pct_cap": FOUR_POISONS_EMP_SLEEP_PCT_CAP, "sleep_pct_per_extra": FOUR_POISONS_EMP_SLEEP_PCT_PER_EXTRA_LEVEL}
func _start_dive_strike(player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, now_msec: int) -> Dictionary:
	return ViperSkillEmpStrikeRuntime.start_strike(self, player_pos, special_gauge, config, deps, now_msec, _get_emp_strike_runtime_constants())
func _update_dive_strike(delta: float, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary) -> Dictionary:
	return ViperSkillEmpStrikeRuntime.update_strike(self, delta, player_pos, special_gauge, config, deps, _get_emp_strike_runtime_constants())
func _start_dive_slip_for_height(ball_pos: Vector2, context: Dictionary, deps: Dictionary, height_snapshot: float, max_refresh: bool) -> void:
	ViperSkillEmpStrikeRuntime.start_slip_for_height(self, ball_pos, context, deps, height_snapshot, max_refresh, _get_emp_strike_runtime_constants())
func apply_emp_slip_boss_motion(boss_pos: Vector2, context: Dictionary, fps_scale: float) -> Dictionary: return ViperSkillEmpStrikeRuntime.apply_slip_boss_motion(self, boss_pos, context, fps_scale)
func _reset_dive_runtime(clear_hold: bool = false) -> void:
	ViperSkillEmpStrikeRuntime.reset_runtime(self, clear_hold, _get_emp_strike_runtime_constants())
func _reset_dive_hold() -> void: ViperSkillEmpStrikeRuntime.reset_hold(self)
func _play_dive_prep_sound(deps: Dictionary) -> void: audio_router.play_dive_prep_sound(deps)
func _play_dive_strike_sound(deps: Dictionary) -> void: audio_router.play_dive_strike_sound(deps)
func _get_nerve_strike_runtime_constants() -> Dictionary: return {"skill_name": NERVE_STRIKE, "gauge_cost": 90.0, "cooldown_base": 35.0, "target_y_offset": NERVE_STRIKE_TARGET_Y_OFFSET, "dash_frames": NERVE_STRIKE_DASH_FRAMES, "tracking_end_ratio": NERVE_STRIKE_TRACKING_END_RATIO, "tracking_strength": NERVE_STRIKE_TRACKING_STRENGTH, "hit_radius": NERVE_STRIKE_HIT_RADIUS, "hit_gold": NERVE_STRIKE_HIT_GOLD, "miss_text_frames": NERVE_STRIKE_MISS_TEXT_FRAMES, "slash_hit_frames": NERVE_STRIKE_SLASH_HIT_FRAMES, "slash_miss_frames": NERVE_STRIKE_SLASH_MISS_FRAMES, "slash_trigger_ratio": NERVE_STRIKE_SLASH_TRIGGER_RATIO, "slash_vfx_frames": NERVE_STRIKE_SLASH_VFX_FRAMES, "return_hit_frames": NERVE_STRIKE_RETURN_HIT_FRAMES, "return_miss_frames": NERVE_STRIKE_RETURN_MISS_FRAMES, "confusion_frames": NERVE_STRIKE_CONFUSION_FRAMES, "venom_confusion_values": FOUR_POISONS_VENOM_CONFUSION_PCT_BY_LEVEL, "venom_confusion_cap": FOUR_POISONS_VENOM_CONFUSION_PCT_CAP, "venom_confusion_per_extra": FOUR_POISONS_VENOM_CONFUSION_PCT_PER_EXTRA_LEVEL, "dual_glitch_nerve_stagger_frames": DUAL_GLITCH_NERVE_STAGGER_FRAMES}
func _start_nerve_strike(player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, now_msec: int) -> Dictionary:
	return ViperSkillNerveStrikeRuntime.start_strike(self, player_pos, special_gauge, config, deps, now_msec, _get_nerve_strike_runtime_constants())
func _update_nerve_strike(delta: float, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary) -> Dictionary:
	return ViperSkillNerveStrikeRuntime.update_strike(self, delta, player_pos, special_gauge, config, deps, _get_nerve_strike_runtime_constants())
func _enter_nerve_strike_return_phase(config: Dictionary, deps: Dictionary) -> void: ViperSkillNerveStrikeRuntime.enter_return_phase(self, config, deps)
func _reset_nerve_strike_runtime(clear_clones: bool = false) -> void: ViperSkillNerveStrikeRuntime.reset_runtime(self, clear_clones)
func _get_four_poisons_additive_cooldown_seconds(skill_name: String, skill_config: Object, deps: Dictionary, fallback_base_seconds: float) -> float: return skill_scaling.get_four_poisons_additive_cooldown_seconds(skill_name, skill_config, fallback_base_seconds, visibility_query.get_runtime_skill_level(deps, "four_poisons"), FOUR_POISONS_COOLDOWN_REDUCTION_PCT_BY_LEVEL, FOUR_POISONS_COOLDOWN_REDUCTION_PCT_CAP, FOUR_POISONS_COOLDOWN_REDUCTION_PCT_PER_EXTRA_LEVEL, NERVE_STRIKE, DIVE_STRIKE, CHAOS_SPEAR, DUAL_GLITCH)
func _apply_nerve_strike_confusion(deps: Dictionary) -> void: ViperSkillNerveStrikeRuntime.apply_confusion(self, deps, _get_nerve_strike_runtime_constants())
func _get_nerve_strike_boss_center(config: Dictionary) -> Vector2: return ViperSkillNerveStrikeRuntime.get_boss_center(config)
func _spawn_nerve_strike_slash_feedback(center: Vector2, deps: Dictionary) -> void: ViperSkillNerveStrikeRuntime.spawn_slash_feedback(self, center, deps)
func _can_start_dark_blade_from_window(special_gauge: float, config: Dictionary, deps: Dictionary) -> bool:
	if not dark_blade_window or blade_motion_active or blade_projectile_active or chaos_state == "startup" or not bool(config.get("ball_active", true)) or not (visibility_query.is_viper_airborne(deps) or (core_flip_attack_active and core_flip_ball_hit) or core_flip_dark_blade_handoff_frames > 0.0 or marshal_active) or visibility_query.is_control_locked(deps):
		return false
	var skill_config: Object = visibility_query.get_viper_skill_config(deps)
	return visibility_query.is_skill_equipped(skill_config, DARK_BLADE) and special_gauge >= _get_blade_skill_cost(skill_config, deps, DARK_BLADE) and visibility_query.is_configured_skill_ready(DARK_BLADE, deps, -1)
func _trigger_orb_gauge_spin(deps: Dictionary, now_msec: int) -> void:
	var orb_hud_state: Object = deps.get("orb_hud_state", null)
	if orb_hud_state != null and orb_hud_state.has_method("trigger_gauge_spin"):
		orb_hud_state.trigger_gauge_spin(now_msec)
func _trigger_configured_skill_cooldown(skill_name: String, skill_config: Object, deps: Dictionary, now_msec: int) -> void:
	var skill_state: Object = visibility_query.get_viper_skill_state(deps)
	if skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown(skill_name, now_msec, skill_config)
func _get_blade_motion_runtime_constants() -> Dictionary: return {"blade_rush": BLADE_RUSH, "dark_blade": DARK_BLADE, "marshal_kick": MARSHAL_KICK, "phantom_kick": PHANTOM_KICK, "spin_frames": BLADE_SPIN_FRAMES, "decel_frames": BLADE_DECEL_FRAMES, "rest_frames": BLADE_REST_FRAMES, "dark_rest_frames": BLADE_DARK_REST_FRAMES, "dark_spin_mult": BLADE_DARK_SPIN_MULT, "dark_time_mult": BLADE_DARK_TIME_MULT, "normal_spin_turns": BLADE_NORMAL_SPIN_TURNS, "dark_spin_turns": BLADE_DARK_SPIN_TURNS, "projectile_speed": BLADE_PROJECTILE_SPEED, "base_width": BLADE_BASE_WIDTH, "base_range": BLADE_BASE_RANGE, "hitbox_height": BLADE_HITBOX_HEIGHT, "dark_hitbox_height": BLADE_DARK_HITBOX_HEIGHT, "fadeout_frames": BLADE_FADEOUT_FRAMES, "trail_max": BLADE_TRAIL_MAX, "followup_trail_max": BLADE_FOLLOWUP_TRAIL_MAX, "followup_start_y_offset": BLADE_FOLLOWUP_START_Y_OFFSET, "combo_delay_frames": BLADE_COMBO_DELAY_FRAMES, "dark_window_frames": DARK_BLADE_WINDOW_FRAMES, "dark_default_ball_size": DARK_BLADE_DEFAULT_BALL_SIZE, "hit_gold": BLADE_HIT_GOLD, "air_max_ball_speed": AIR_BLADE_MAX_BALL_SPEED, "dark_max_ball_speed": DARK_BLADE_MAX_BALL_SPEED, "air_hit_speed_mult": AIR_BLADE_HIT_SPEED_MULT, "dark_hit_speed_mult": DARK_BLADE_HIT_SPEED_MULT, "air_hit_shake_amount": AIR_BLADE_HIT_SHAKE_AMOUNT, "dark_hit_shake_amount": DARK_BLADE_HIT_SHAKE_AMOUNT, "air_hit_shake_intensity": AIR_BLADE_HIT_SHAKE_INTENSITY, "dark_hit_shake_intensity": DARK_BLADE_HIT_SHAKE_INTENSITY, "air_hit_pulse_kind": AIR_BLADE_HIT_PULSE_KIND, "dark_hit_pulse_kind": DARK_BLADE_HIT_PULSE_KIND, "air_hit_pulse_intensity": AIR_BLADE_HIT_PULSE_INTENSITY, "dark_hit_pulse_intensity": DARK_BLADE_HIT_PULSE_INTENSITY, "air_fallback_hit_color": AIR_BLADE_FALLBACK_HIT_COLOR, "dark_fallback_hit_color": DARK_BLADE_FALLBACK_HIT_COLOR, "air_fallback_particle_intensity": AIR_BLADE_FALLBACK_PARTICLE_INTENSITY, "dark_fallback_particle_intensity": DARK_BLADE_FALLBACK_PARTICLE_INTENSITY, "air_fallback_explosion_scale": AIR_BLADE_FALLBACK_EXPLOSION_SCALE, "dark_fallback_explosion_scale": DARK_BLADE_FALLBACK_EXPLOSION_SCALE, "air_fallback_explosion_intensity": AIR_BLADE_FALLBACK_EXPLOSION_INTENSITY, "dark_fallback_explosion_intensity": DARK_BLADE_FALLBACK_EXPLOSION_INTENSITY, "player_collision_cooldown": BLADE_HIT_PLAYER_COLLISION_COOLDOWN, "amp_followup_width_scale": BLADE_AMP_FOLLOWUP_WIDTH_SCALE, "amp_followup_range_scale": BLADE_AMP_FOLLOWUP_RANGE_SCALE, "amp_followup_hit_speed_scale": BLADE_AMP_FOLLOWUP_HIT_SPEED_SCALE, "amp_followup_min_width": BLADE_AMP_FOLLOWUP_MIN_WIDTH, "dual_glitch_replica_min_scale": BLADE_DUAL_GLITCH_REPLICA_MIN_SCALE, "dual_glitch_replica_hit_speed_scale": BLADE_DUAL_GLITCH_REPLICA_HIT_SPEED_SCALE, "prep_fall_speed": BLADE_PREP_FALL_SPEED, "airborne_move_bonus_max": BLADE_AIRBORNE_MOVE_BONUS_MAX, "jetpack_max_height": BLADE_JETPACK_MAX_HEIGHT, "combo_pop_min_offset": BLADE_COMBO_POP_MIN_OFFSET, "combo_pop_extra": BLADE_COMBO_POP_EXTRA, "dark_auto_fire_start_frames": DARK_BLADE_AUTO_FIRE_START_FRAMES, "dark_auto_fire_end_frames": DARK_BLADE_AUTO_FIRE_END_FRAMES, "dark_auto_fire_near_y": DARK_BLADE_AUTO_FIRE_NEAR_Y, "air_rise_frames": BLADE_AIR_RISE_FRAMES, "dark_rise_frames": BLADE_DARK_RISE_FRAMES, "air_jump_peak": BLADE_AIR_JUMP_PEAK, "dark_jump_peak": BLADE_DARK_JUMP_PEAK, "marshal_ready_frames": MARSHAL_KICK_READY_FRAMES}
func _start_blade_motion(player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, dark_mode: bool, now_msec: int, trigger_cooldown: bool = true, pop_up_from_combo: bool = false) -> Dictionary: return ViperSkillBladeMotionRuntime.start_motion(self, player_pos, special_gauge, config, deps, dark_mode, now_msec, trigger_cooldown, pop_up_from_combo, _get_blade_motion_runtime_constants())
func _enter_blade_spin_phase() -> void: ViperSkillBladeMotionRuntime.enter_spin_phase(self)
func _reset_blade_motion_combo_windows() -> void: ViperSkillBladeMotionRuntime.reset_combo_windows(self)
func _open_dark_blade_start_window() -> void: ViperSkillBladeMotionRuntime.open_dark_blade_start_window(self, _get_blade_motion_runtime_constants())
func _update_blade_motion(delta: float, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary) -> Dictionary: return ViperSkillBladeMotionRuntime.update_motion(self, delta, player_pos, special_gauge, config, deps, _get_blade_motion_runtime_constants())
func _launch_blade_projectile(player_pos: Vector2, config: Dictionary, deps: Dictionary) -> void: ViperSkillBladeMotionRuntime.launch_projectile(self, player_pos, config, deps, _get_blade_motion_runtime_constants())
func _reset_primary_blade_projectile_runtime_state() -> void: ViperSkillBladeMotionRuntime.reset_primary_projectile_runtime_state(self)
func _apply_blade_hit(scene: Dictionary, context: Dictionary, deps: Dictionary, dark_mode: bool, allow_gold: bool, allow_followup: bool, allow_combo: bool, hit_speed_scale: float) -> Dictionary: return ViperSkillBladeMotionRuntime.apply_hit(self, scene, context, deps, dark_mode, allow_gold, allow_followup, allow_combo, hit_speed_scale, _get_blade_motion_runtime_constants())
func _append_blade_followup_projectile(pos: Vector2, start_y: float, target_y: float, width: float, dark_mode: bool, hit_speed_scale: float, extra_fields: Dictionary) -> void: ViperSkillBladeMotionRuntime.append_followup_projectile(self, pos, start_y, target_y, width, dark_mode, hit_speed_scale, extra_fields)
func _destroy_blade_stage2_rocks(blade_rect: Rect2, deps: Dictionary, context: Dictionary) -> int: return ViperSkillBladeMotionRuntime.destroy_stage2_rocks(blade_rect, deps, context)
func _get_blade_skill_cost(skill_config: Object, deps: Dictionary, skill_name: String) -> float: return ViperSkillBladeMotionRuntime.get_skill_cost(self, skill_config, deps, skill_name, _get_blade_motion_runtime_constants())
func _register_ball_hit_pulse(ball_pos: Vector2, ball_vel: Vector2, deps: Dictionary, intensity: float, kind: String) -> bool: return particle_drawer.register_ball_hit_pulse(ball_pos, ball_vel, deps.get("ball_effects", null), intensity, kind)
func _spawn_fallback_hit_impact(ball_pos: Vector2, impact_velocity: Vector2, deps: Dictionary, hit_color: Color, particle_intensity: float, explosion_scale: float, explosion_intensity: float) -> void: particle_drawer.spawn_fallback_hit_impact(ball_pos, impact_velocity, deps.get("impact_effects", null), hit_color, particle_intensity, explosion_scale, explosion_intensity)
func _reset_blade_motion_only(deps: Dictionary = {}) -> void: ViperSkillBladeMotionRuntime.reset_motion_only(self, deps, _get_blade_motion_runtime_constants())
func _clear_blade_projectile() -> void: ViperSkillBladeMotionRuntime.clear_projectile(self, _get_blade_motion_runtime_constants())
func _get_marshal_kick_runtime_constants() -> Dictionary: return {"marshal_kick": MARSHAL_KICK, "phantom_kick": PHANTOM_KICK, "double_marshal_kick": DOUBLE_MARSHAL_KICK, "dark_blade": DARK_BLADE, "jump_frames": MARSHAL_KICK_JUMP_FRAMES, "cling_frames": MARSHAL_KICK_CLING_FRAMES, "charge_frames": MARSHAL_KICK_CHARGE_FRAMES, "reclimb_frames": MARSHAL_KICK_RECLIMB_FRAMES, "return_frames": MARSHAL_KICK_RETURN_FRAMES, "hit_radius": MARSHAL_KICK_HIT_RADIUS, "reclimb_threshold": MARSHAL_KICK_RECLIMB_THRESHOLD, "wall_inset": MARSHAL_KICK_WALL_INSET, "speed_mult": MARSHAL_KICK_SPEED_MULT, "min_speed": MARSHAL_KICK_MIN_SPEED, "double_speed_mult": MARSHAL_KICK_DOUBLE_SPEED_MULT, "double_min_speed": MARSHAL_KICK_DOUBLE_MIN_SPEED, "double_fast_mult": MARSHAL_KICK_DOUBLE_FAST_MULT, "shadow_chain_prep_mult": MARSHAL_KICK_SHADOW_CHAIN_PREP_MULT, "phantom_chain_prep_mult": MARSHAL_KICK_PHANTOM_CHAIN_PREP_MULT, "phantom_delay_frames": MARSHAL_KICK_PHANTOM_DELAY_FRAMES, "dmk_freeze_frames": MARSHAL_KICK_DMK_FREEZE_FRAMES, "dmk_text_frames": MARSHAL_KICK_DMK_TEXT_FRAMES, "curve_frames": MARSHAL_KICK_CURVE_FRAMES, "double_hit_curve_frames_mult": MARSHAL_DOUBLE_HIT_CURVE_FRAMES_MULT, "curve_force": MARSHAL_KICK_CURVE_FORCE, "impact_object_radius": MARSHAL_KICK_IMPACT_OBJECT_RADIUS, "trail_max": MARSHAL_KICK_TRAIL_MAX, "hit_shake_amount": MARSHAL_HIT_SHAKE_AMOUNT, "double_hit_shake_amount": MARSHAL_DOUBLE_HIT_SHAKE_AMOUNT, "hit_shake_intensity": MARSHAL_HIT_SHAKE_INTENSITY, "double_hit_shake_intensity": MARSHAL_DOUBLE_HIT_SHAKE_INTENSITY, "hit_particle_intensity": MARSHAL_HIT_PARTICLE_INTENSITY, "double_hit_particle_intensity": MARSHAL_DOUBLE_HIT_PARTICLE_INTENSITY, "hit_energy_scale": MARSHAL_HIT_ENERGY_SCALE, "double_hit_energy_scale": MARSHAL_DOUBLE_HIT_ENERGY_SCALE, "hit_pulse_kind": MARSHAL_HIT_PULSE_KIND, "double_hit_pulse_kind": MARSHAL_DOUBLE_HIT_PULSE_KIND, "hit_energy_intensity": MARSHAL_HIT_ENERGY_INTENSITY, "double_hit_energy_intensity": MARSHAL_DOUBLE_HIT_ENERGY_INTENSITY, "fallback_hit_color": MARSHAL_FALLBACK_HIT_COLOR, "player_collision_cooldown": MARSHAL_HIT_PLAYER_COLLISION_COOLDOWN, "hit_gold": MARSHAL_HIT_GOLD, "double_hit_gold": MARSHAL_DOUBLE_HIT_GOLD, "hit_motion_particle_count": MARSHAL_HIT_MOTION_PARTICLE_COUNT, "double_hit_motion_particle_count": MARSHAL_DOUBLE_HIT_MOTION_PARTICLE_COUNT, "hit_motion_spread": MARSHAL_HIT_MOTION_PARTICLE_SPREAD, "hit_motion_life_min": MARSHAL_HIT_MOTION_PARTICLE_LIFE_MIN, "hit_motion_life_max": MARSHAL_HIT_MOTION_PARTICLE_LIFE_MAX, "hit_motion_kind": MARSHAL_HIT_MOTION_PARTICLE_KIND, "hit_motion_chance": MARSHAL_HIT_MOTION_PARTICLE_CHANCE, "phantom_hit_particle_count": PHANTOM_HIT_PARTICLE_COUNT, "phantom_hit_particle_max_count": PHANTOM_HIT_PARTICLE_MAX_COUNT, "knockback_chance_cap": KICK_ENHANCE_KNOCKBACK_BALL_CHANCE_CAP, "knockback_fixed_pct": KICK_ENHANCE_KNOCKBACK_BALL_FIXED_PCT, "shadow_airborne_gold_mult": SHADOW_STEP_AIRBORNE_GOLD_MULT}
func _start_marshal_kick(skill_name: String, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary) -> Dictionary: return ViperSkillMarshalKickRuntime.start_kick(self, skill_name, player_pos, special_gauge, config, deps, _get_marshal_kick_runtime_constants())
func _update_marshal_kick(delta: float, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary) -> Dictionary: return ViperSkillMarshalKickRuntime.update_kick(self, delta, player_pos, special_gauge, config, deps, _get_marshal_kick_runtime_constants())
func _update_marshal_charge_phase(config: Dictionary, deps: Dictionary, result: Dictionary) -> Vector2: return ViperSkillMarshalKickRuntime.update_charge_phase(self, config, deps, result, _get_marshal_kick_runtime_constants())
func _enter_marshal_charge(config: Dictionary, deps: Dictionary) -> void: ViperSkillMarshalKickRuntime.enter_charge(self, config, deps)
func _enter_marshal_return(return_start_pos: Vector2) -> void: ViperSkillMarshalKickRuntime.enter_return(self, return_start_pos)
func _enter_marshal_freeze_phase(next_phase: int, deps: Dictionary) -> void: ViperSkillMarshalKickRuntime.enter_freeze_phase(self, next_phase, deps, _get_marshal_kick_runtime_constants())
func _reset_marshal_runtime_fields() -> void: ViperSkillMarshalKickRuntime.reset_runtime(self)
func _apply_shadow_step_hit(hit_center: Vector2, hit_size: Vector2, curve_dir: int, source: String, scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary: return ViperSkillShadowStepRuntime.apply_hit(self, hit_center, hit_size, curve_dir, source, scene, context, deps, _get_shadow_step_hit_constants())
func _set_shadow_curve(frames: float, force: float, curve_dir: int) -> void: shadow_curve_active = frames > 0.0; shadow_curve_timer = max(0.0, frames); shadow_curve_total = max(1.0, frames); shadow_curve_force = max(0.0, force); shadow_curve_dir = 1 if curve_dir >= 0 else -1
func _spawn_marshal_motion_particle(pos: Vector2, kind: String, chance: float = 1.0, life_override: float = -1.0) -> void: ViperSkillMarshalKickRuntime.spawn_motion_particle(self, pos, kind, chance, life_override, _get_marshal_kick_runtime_constants())
func _destroy_marshal_impact_objects(center: Vector2, deps: Dictionary) -> void: ViperSkillMarshalKickRuntime.destroy_impact_objects(center, deps, _get_marshal_kick_runtime_constants())
func _set_marshal_web_line_to_wall(from_pos: Vector2, config: Dictionary) -> void: ViperSkillMarshalKickRuntime.set_web_line_to_wall(self, from_pos, config)
func _cancel_dash_until_key_release(dash_state: Object) -> void: ViperSkillMarshalKickRuntime.cancel_dash_until_key_release(dash_state)
func _get_marshal_duration_frames(base_frames: float, deps: Dictionary, double_fast: bool = false) -> float: return ViperSkillMarshalKickRuntime.get_duration_frames(self, base_frames, deps, double_fast, _get_marshal_kick_runtime_constants())
func _get_marshal_prep_duration_frames(base_frames: float, deps: Dictionary, double_fast: bool = false, config: Dictionary = {}) -> float: return ViperSkillMarshalKickRuntime.get_prep_duration_frames(self, base_frames, config, deps, double_fast, _get_marshal_kick_runtime_constants())
func _get_marshal_prep_duration_mult(deps: Dictionary, config: Dictionary = {}) -> float: return ViperSkillMarshalKickRuntime.get_prep_duration_mult(self, deps, _get_marshal_kick_runtime_constants(), config)
func _mark_kick_skill_knockback_pending(deps: Dictionary) -> void: ViperSkillMarshalKickRuntime.mark_kick_skill_knockback_pending(self, deps, _get_marshal_kick_runtime_constants())
func _mark_kick_guard_speed_reduction_pending() -> void: ViperSkillMarshalKickRuntime.mark_kick_guard_speed_reduction_pending(self, _get_contact_runtime_constants())
func _get_viper_hologram_attack_sheet(kick_dir: int) -> Texture2D: return shadow_effect_renderer.get_viper_hologram_attack_sheet(self, kick_dir, VIPER_HOLOGRAM_ATTACK_LEFT_SHEET_PATH, VIPER_HOLOGRAM_ATTACK_RIGHT_SHEET_PATH)
func _get_viper_hologram_attack_source_region(progress: float) -> Rect2: return shadow_effect_renderer.get_viper_hologram_attack_source_region(progress, VIPER_HOLOGRAM_ATTACK_FRAME_COUNT, VIPER_HOLOGRAM_ATTACK_GRID_COLS, VIPER_HOLOGRAM_FRAME_SIZE)
func _draw_chaos_spear(canvas: CanvasItem, tip: Vector2, angle: float, alpha: float, scale: float) -> void:
	chaos_spear_effect_renderer.draw_chaos_spear(canvas, tip, angle, alpha, scale, CHAOS_VISUAL_LENGTH)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2: return value if value is Vector2 else fallback
