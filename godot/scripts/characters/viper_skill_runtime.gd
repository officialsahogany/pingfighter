extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const ChaosSpearFxHost := preload("res://scripts/characters/viper_chaos_spear_fx_host.gd")
const EmpStrikeFxHost := preload("res://scripts/characters/viper_emp_strike_fx_host.gd")
const ViperSkillAudioRouter := preload("res://scripts/characters/viper_skill_audio_router.gd")
const ViperSkillBladeEffectRenderer := preload("res://scripts/characters/viper_skill_blade_effect_renderer.gd")
const ViperSkillChaosSpearEffectRenderer := preload("res://scripts/characters/viper_skill_chaos_spear_effect_renderer.gd")
const ViperSkillContextBuilder := preload("res://scripts/characters/viper_skill_context_builder.gd")
const ViperSkillDualGlitchEffectRenderer := preload("res://scripts/characters/viper_skill_dual_glitch_effect_renderer.gd")
const ViperSkillFloatingTextRenderer := preload("res://scripts/characters/viper_skill_floating_text_renderer.gd")
const ViperSkillFxHostController := preload("res://scripts/characters/viper_skill_fx_host_controller.gd")
const ViperSkillKickEffectRenderer := preload("res://scripts/characters/viper_skill_kick_effect_renderer.gd")
const ViperSkillParticleDrawer := preload("res://scripts/characters/viper_skill_particle_drawer.gd")
const ViperSkillRuntimeActionRouter := preload("res://scripts/characters/viper_skill_runtime_action_router.gd")
const ViperSkillShadowEffectRenderer := preload("res://scripts/characters/viper_skill_shadow_effect_renderer.gd")
const ViperSkillSnapshotBuilder := preload("res://scripts/characters/viper_skill_snapshot_builder.gd")
const ViperSkillScaling := preload("res://scripts/characters/viper_skill_scaling.gd")
const ViperSkillTimerGaugeRenderer := preload("res://scripts/characters/viper_skill_timer_gauge_renderer.gd")
const ViperSkillVisibilityQuery := preload("res://scripts/characters/viper_skill_visibility_query.gd")
const ViperSkillGeometry := preload("res://scripts/characters/viper_skill_geometry.gd")
const CHAOS_FX_DISK_HEIGHT := 220.0

const SHADOW_STEP := "shadow_step"
const MARSHAL_KICK := "marshal_kick"
const PHANTOM_KICK := "phantom_kick"
const DOUBLE_MARSHAL_KICK := "double_marshal_kick"
const BLADE_RUSH := "blade_rush"
const DARK_BLADE := "dark_blade"
const NERVE_STRIKE := "nerve_strike"
const CHAOS_SPEAR := "chaos_spear"
const CORE_FLIP := "core_flip"
const DIVE_STRIKE := "dive_strike"
const DUAL_GLITCH := "dual_glitch"
const IGNITION_AURA := "ignition_aura"
const SHADOW_STEP_DASH_GRACE_FRAMES := 36.0
const SHADOW_STEP_READY_FRAMES := 60.0
const MARSHAL_KICK_READY_FRAMES := 90.0
const MARSHAL_KICK_JUMP_FRAMES := 24.72
const MARSHAL_KICK_CLING_FRAMES := 15.0
const MARSHAL_KICK_CHARGE_FRAMES := 23.4
const MARSHAL_KICK_RECLIMB_FRAMES := 10.8
const MARSHAL_KICK_RETURN_FRAMES := 21.0
const MARSHAL_KICK_HIT_RADIUS := 90.0
const MARSHAL_KICK_RECLIMB_THRESHOLD := 120.0
const MARSHAL_KICK_WALL_INSET := 15.0
const MARSHAL_KICK_SPEED_MULT := 2.2
const MARSHAL_KICK_MIN_SPEED := 11.0
const MARSHAL_KICK_DOUBLE_SPEED_MULT := 2.8
const MARSHAL_KICK_DOUBLE_MIN_SPEED := 14.0
const MARSHAL_KICK_DOUBLE_FAST_MULT := 1.3
const MARSHAL_KICK_PHANTOM_DELAY_FRAMES := 12.0
const MARSHAL_KICK_DMK_FREEZE_FRAMES := 60.0
const MARSHAL_KICK_DMK_TEXT_FRAMES := 80.0
const MARSHAL_KICK_CURVE_FRAMES := 50.0
const MARSHAL_DOUBLE_HIT_CURVE_FRAMES_MULT := 2.5
const MARSHAL_KICK_CURVE_FORCE := 2.0
const MARSHAL_KICK_IMPACT_OBJECT_RADIUS := 150.0
const MARSHAL_KICK_TRAIL_MAX := 60
const CHAOS_CMD_WINDOW_MSEC := 600
const CHAOS_CMD_BUFFER_MAX := 6
const CHAOS_STARTUP_FRAMES := 45.0
const CHAOS_TRAVEL_FRAMES := 16.8
const CHAOS_IMPACT_FRAMES := 21.6
const CHAOS_BLACKHOLE_FRAMES := 180.0
const CHAOS_FADE_FRAMES := 25.2
const CHAOS_PULL_RADIUS := 175.0
const CHAOS_INGRESS_FRAMES := 31.2
const CHAOS_VISUAL_LENGTH := 78.0
const CHAOS_GOLD_TICK_FRAMES := 6.0
const CHAOS_GOLD_PER_TICK := 1
const CHAOS_OBJECT_GOLD := 5
const SHADOW_STEP_HOLOGRAM_FRAMES := 30.0
const SHADOW_STEP_WAVE_SPEED := 25.0
const SHADOW_STEP_WAVE_TRAIL_MAX := 12
const SHADOW_STEP_WAVE_COLLISION_SIZE := Vector2(110.0, 90.0)
const SHADOW_STEP_WAVE_GRADIENT_SIZE := Vector2(280.0, 220.0)
const SHADOW_STEP_HIT_SPEED_MIN := 1.48
const SHADOW_STEP_HIT_SPEED_MAX := 1.96
const SHADOW_STEP_HIT_CURVE_MIN := 10.0
const SHADOW_STEP_HIT_CURVE_MAX := 50.0
const SHADOW_STEP_HIT_FORCE_MIN := 0.4
const SHADOW_STEP_HIT_FORCE_MAX := 2.0
const SHADOW_STEP_MIN_HIT_SPEED := 10.0
const SHADOW_STEP_KICK_READY_FRAMES := 300.0
const SHADOW_STEP_PHANTOM_FRAMES := 18.0
const SHADOW_STEP_MARSHAL_DELAY_FRAMES := 18.0
const SHADOW_STEP_PADDLE_HIT_PADDING := 40.0
const SHADOW_STEP_PADDLE_HIT_SOURCE := "paddle"
const SHADOW_STEP_PADDLE_HIT_WINDOW_MSEC := 5000
const SHADOW_STEP_ACTIVATION_VALID_AFTER_MSEC := -99999
const CORE_FLIP_MARSHAL_DELAY_FRAMES := 6.0
const SHADOW_STEP_HIT_GOLD := 16
const SHADOW_STEP_AIRBORNE_GOLD_MULT := 1.5
const SHADOW_STEP_STARBURST_FRAMES := 5
const SHADOW_STEP_STARBURST_FRAME_DURATION := 3.0
const BLADE_SPIN_FRAMES := 24.0
const BLADE_DECEL_FRAMES := 12.0
const BLADE_REST_FRAMES := 66.0
const BLADE_DARK_REST_FRAMES := 90.0
const BLADE_DARK_SPIN_MULT := 2.5
const BLADE_DARK_TIME_MULT := 1.5
const BLADE_NORMAL_SPIN_TURNS := 2.0
const BLADE_DARK_SPIN_TURNS := 3.0
const BLADE_PROJECTILE_SPEED := 12.0
const BLADE_BASE_WIDTH := 350.0
const BLADE_BASE_RANGE := 250.0
const BLADE_HITBOX_HEIGHT := 55.0
const BLADE_DARK_HITBOX_HEIGHT := 83.0
const BLADE_FADEOUT_FRAMES := 30.0
const BLADE_TRAIL_MAX := 20
const BLADE_FOLLOWUP_TRAIL_MAX := 16
const BLADE_FOLLOWUP_START_Y_OFFSET := -20.0
const BLADE_COMBO_DELAY_FRAMES := 30.0
const BLADE_DASH_RELEASE_DELAY_FRAMES := 18.0
const DARK_BLADE_WINDOW_FRAMES := 180.0
const DARK_BLADE_DEFAULT_BALL_SIZE := 28.6
const BLADE_HIT_GOLD := 30
const AIR_BLADE_MAX_BALL_SPEED := 40.0
const DARK_BLADE_MAX_BALL_SPEED := 50.0
const AIR_BLADE_HIT_SPEED_MULT := 2.1
const DARK_BLADE_HIT_SPEED_MULT := 2.4
const AIR_BLADE_HIT_SHAKE_AMOUNT := 0.15
const DARK_BLADE_HIT_SHAKE_AMOUNT := 0.20
const AIR_BLADE_HIT_SHAKE_INTENSITY := 4.8
const DARK_BLADE_HIT_SHAKE_INTENSITY := 6.0
const AIR_BLADE_HIT_PULSE_KIND := "viper_blade"
const DARK_BLADE_HIT_PULSE_KIND := "viper_dark_blade"
const AIR_BLADE_HIT_PULSE_INTENSITY := 0.86
const DARK_BLADE_HIT_PULSE_INTENSITY := 1.0
const AIR_BLADE_FALLBACK_HIT_COLOR := Color(1.0, 0.38, 1.0, 1.0)
const DARK_BLADE_FALLBACK_HIT_COLOR := Color(1.0, 0.16, 0.24, 1.0)
const AIR_BLADE_FALLBACK_PARTICLE_INTENSITY := 1.25
const DARK_BLADE_FALLBACK_PARTICLE_INTENSITY := 1.6
const AIR_BLADE_FALLBACK_EXPLOSION_SCALE := 0.82
const DARK_BLADE_FALLBACK_EXPLOSION_SCALE := 1.05
const AIR_BLADE_FALLBACK_EXPLOSION_INTENSITY := 0.95
const DARK_BLADE_FALLBACK_EXPLOSION_INTENSITY := 1.15
const BLADE_HIT_PLAYER_COLLISION_COOLDOWN := 6.0
const BLADE_AMP_FOLLOWUP_WIDTH_SCALE := 0.72
const BLADE_AMP_FOLLOWUP_RANGE_SCALE := 0.88
const BLADE_AMP_FOLLOWUP_HIT_SPEED_SCALE := 0.55
const BLADE_AMP_FOLLOWUP_MIN_WIDTH := 80.0
const BLADE_DUAL_GLITCH_REPLICA_MIN_SCALE := 0.1
const BLADE_DUAL_GLITCH_REPLICA_HIT_SPEED_SCALE := 1.0
const BLADE_PREP_FALL_SPEED := 3.0
const BLADE_AIRBORNE_MOVE_BONUS_MAX := 2.15
const BLADE_JETPACK_MAX_HEIGHT := 200.0
const DIVE_HOLD_REQUIRED_MSEC := 300
const DIVE_PREP_FRAMES := 24.0
const DIVE_SPEED := 15.0
const DIVE_GAUGE_COST := 150.0
const DIVE_JETPACK_MAX_HEIGHT := 200.0
const DIVE_SHOCKWAVE_HEIGHT := 120.0
const DIVE_SHOCKWAVE_FRAMES := 60.0
const DIVE_SHOCKWAVE_START_RADIUS := 34.0
const DIVE_SHOCKWAVE_BASE_MAX_RADIUS := 300.0
const DIVE_SHOCKWAVE_RING_HALF_THICKNESS := 24.0
const DIVE_SLIP_DURATION_MIN := 54.0
const DIVE_SLIP_DURATION_MAX := 90.0
const DIVE_SLIP_SPEED := 4.0
const DIVE_PARTICLE_LIMIT := 150
const DIVE_CHARGE_PARTICLE_LIMIT := 80
const DIVE_PLAYER_COLLISION_COOLDOWN := 6.0
const DIVE_HIT_TEXT_FRAMES := 50.0
const DIVE_HIT_TEXT_FLOAT_Y := 36.0
const DUAL_GLITCH_CMD_WINDOW_MSEC := 1200
const DUAL_GLITCH_STARTUP_FRAMES := 48.0
const DUAL_GLITCH_SPAWN_FRAMES := 22.8
const DUAL_GLITCH_ACTIVE_FRAMES := 900.0
const DUAL_GLITCH_FADE_FRAMES := 18.0
const DUAL_GLITCH_EVAPORATION_FRAMES := 13.2
const DUAL_GLITCH_OFFSET_PADDING := -15.0
const DUAL_GLITCH_ALPHA := 0.63
const DUAL_GLITCH_WIGGLE_AMPLITUDE := 3.0
const DUAL_GLITCH_DIVE_STAGGER_FRAMES := 12.0
const DUAL_GLITCH_DIVE_TELEGRAPH_FRAMES := 6.0
const DUAL_GLITCH_TIMER_BAR_SIZE := Vector2(150.0, 12.0)
const DUAL_GLITCH_TIMER_BAR_MARGIN := Vector2(16.0, 28.0)
const DUAL_GLITCH_TIMER_STACK_SPACING := 18.0
const DUAL_GLITCH_TIMER_STACK_KEY := "dual_glitch"
const IGNITION_HOLD_REQUIRED_MSEC := 500
const IGNITION_DURATION_FRAMES := 1500.0
const IGNITION_GAUGE_COST := 230.0
const IGNITION_PARTICLE_LIMIT := 180
const IGNITION_CHARGE_PARTICLE_LIMIT := 80
const IGNITION_EMBER_LIMIT := 54
const IGNITION_EMBER_INTERVAL_FRAMES := 8.4
const IGNITION_TIMER_BAR_SIZE := Vector2(150.0, 12.0)
const IGNITION_TIMER_BAR_MARGIN := Vector2(16.0, 28.0)
const IGNITION_TIMER_STACK_SPACING := 18.0
const IGNITION_TIMER_STACK_KEY := "ignition_aura"
const IGNITION_AURA_EFFECT_SHEET_PATH := "res://assets/sprites/effects/viper_ignition_aura_effect_sheet.png"
const IGNITION_AURA_EFFECT_SHEET_COLS := 4
const IGNITION_AURA_EFFECT_SHEET_ROWS := 4
const IGNITION_AURA_EFFECT_FRAME_INTERVAL_MSEC := 70
const BLADE_COMBO_POP_MIN_OFFSET := -40.0
const BLADE_COMBO_POP_EXTRA := 80.0
const DARK_BLADE_AUTO_FIRE_START_FRAMES := 48.0
const DARK_BLADE_AUTO_FIRE_END_FRAMES := 84.0
const DARK_BLADE_AUTO_FIRE_NEAR_Y := 150.0
# Python parity: Air Blade fires at W+0.6s; Venom Edge opens 0.5s later.
# Full window is W+1.1s..1.7s. With Dark Blade also equipped, Venom owns
# W+1.1s..1.4s and Dark Blade owns W+1.4s..1.7s.
const NERVE_STRIKE_WINDOW_START_FRAMES := 66.0
const NERVE_STRIKE_WINDOW_END_FRAMES := 102.0
const NERVE_STRIKE_DARK_BLADE_SPLIT_FRAMES := 84.0
const NERVE_STRIKE_DASH_FRAMES := 30.0
const NERVE_STRIKE_SLASH_HIT_FRAMES := 138.0
const NERVE_STRIKE_SLASH_MISS_FRAMES := 18.0
const NERVE_STRIKE_RETURN_HIT_FRAMES := 15.0
const NERVE_STRIKE_RETURN_MISS_FRAMES := 9.0
const NERVE_STRIKE_HIT_RADIUS := 120.0
const NERVE_STRIKE_CONFUSION_FRAMES := 150.0
const NERVE_STRIKE_HIT_GOLD := 60
const NERVE_STRIKE_MISS_TEXT_FRAMES := 60.0
const NERVE_STRIKE_MISS_TEXT_FLOAT_Y := 34.0
const NERVE_STRIKE_SLASH_TRIGGER_RATIO := 0.45
# Keep the actual dash destination behind the boss body; the high eye-slash
# read is owned by the dedicated strike sheet.
const NERVE_STRIKE_TARGET_Y_OFFSET := 0.0
const NERVE_STRIKE_TRACKING_END_RATIO := 0.80
const NERVE_STRIKE_TRACKING_STRENGTH := 0.12
const NERVE_STRIKE_SLASH_VFX_FRAMES := 30.0
const DUAL_GLITCH_NERVE_STAGGER_FRAMES := 12.0
const DUAL_GLITCH_NERVE_TRAVEL_FRAMES := 13.2
const DUAL_GLITCH_NERVE_SLASH_FRAMES := 12.0
const FOUR_POISONS_PREP_REDUCTION_PCT_BY_LEVEL := [0, 8, 16, 25, 33, 40]
const FOUR_POISONS_PREP_REDUCTION_PCT_PER_EXTRA_LEVEL := 4
const FOUR_POISONS_PREP_REDUCTION_PCT_CAP := 70
const FOUR_POISONS_EMP_SLEEP_PCT_BY_LEVEL := [0, 5, 10, 15, 20, 25]
const FOUR_POISONS_EMP_SLEEP_PCT_PER_EXTRA_LEVEL := 5
const FOUR_POISONS_EMP_SLEEP_PCT_CAP := 50
const FOUR_POISONS_COOLDOWN_REDUCTION_PCT_BY_LEVEL := [0, 0, 0, 10, 15, 20]
const FOUR_POISONS_COOLDOWN_REDUCTION_PCT_PER_EXTRA_LEVEL := 4
const FOUR_POISONS_COOLDOWN_REDUCTION_PCT_CAP := 40
const FOUR_POISONS_VENOM_CONFUSION_PCT_BY_LEVEL := [0, 12, 24, 36, 48, 70]
const FOUR_POISONS_VENOM_CONFUSION_PCT_PER_EXTRA_LEVEL := 10
const FOUR_POISONS_VENOM_CONFUSION_PCT_CAP := 150
const FOUR_POISONS_DUAL_GLITCH_DURATION_PCT_BY_LEVEL := [0, 7, 14, 20, 27, 33]
const FOUR_POISONS_DUAL_GLITCH_DURATION_PCT_PER_EXTRA_LEVEL := 5
const FOUR_POISONS_DUAL_GLITCH_DURATION_PCT_CAP := 45
const FOUR_POISONS_DUAL_GLITCH_CLONE_HP_BY_LEVEL := [2, 2, 2, 3, 3, 4]
const FOUR_POISONS_DUAL_GLITCH_CLONE_HP_CAP := 6
const CORE_FLIP_READY_WINDOW_MSEC := 700
const CORE_FLIP_DASH_SUCCESS_WINDOW_MSEC := 400
const CORE_FLIP_DASH_START_UNSET_MSEC := -100000
const CORE_FLIP_DASH_START_VALID_AFTER_MSEC := -99999
const CORE_FLIP_INPUT_FRAME_UNSET := -999999
const CORE_FLIP_INPUT_FRAME_GAP := 4
const CORE_FLIP_INPUT_MAX_AGE_FRAMES := 16
const CORE_FLIP_DEFAULT_PADDLE_SIZE := Vector2(155.0, 50.0)
const CORE_FLIP_PHASE0_FRAMES := 24.0
const CORE_FLIP_PHASE1_FRAMES := 105.3
const CORE_FLIP_PHASE2_FRAMES := 23.4
const CORE_FLIP_PHASE3_FRAMES := 9.0
const CORE_FLIP_ZIGZAG_LEG_FRAMES := 28.08
const CORE_FLIP_ZIGZAG_CLING_FRAMES := 11.7
const CORE_FLIP_KICK_TRIGGER_Y := 200.0
const CORE_FLIP_APEX_OFFSET_Y := -30.0
const CORE_FLIP_HIT_RADIUS := 60.0
const CORE_FLIP_SPEED_MULT := 2.2
const CORE_FLIP_MIN_SPEED := 11.0
const CORE_FLIP_HIT_GOLD := 30
const CORE_FLIP_START_SHAKE_AMOUNT := 0.14
const CORE_FLIP_START_SHAKE_INTENSITY := 4.5
const CORE_FLIP_HIT_SHAKE_AMOUNT := 0.15
const CORE_FLIP_HIT_SHAKE_INTENSITY := 6.0
const CORE_FLIP_HIT_PULSE_INTENSITY := 0.92
const CORE_FLIP_HIT_PULSE_KIND := "viper_core_flip"
const CORE_FLIP_DARK_BLADE_HANDOFF_FRAMES := 30.0
const CORE_FLIP_MISS_TEXT_FRAMES := 50.0
const CORE_FLIP_MISS_TEXT_FLOAT_Y := 34.0
const KICK_ENHANCE_KNOCKBACK_BALL_CHANCE_CAP := 100
const KICK_ENHANCE_KNOCKBACK_BALL_FIXED_PCT := 150
const PHANTOM_KICK_KNOCKBACK_DISTANCE := 18.0
const PHANTOM_KICK_KNOCKBACK_FRAMES := 36.0
const PHANTOM_KICK_KNOCKBACK_DECAY := 0.88
const KICK_GUARD_KNOCKBACK_FIRE_BASE := 22.0
const KICK_GUARD_KNOCKBACK_FRAMES := 18.0
const KICK_GUARD_KNOCKBACK_DECAY := 0.85
const KICK_GUARD_DISTANCE_MULTIPLIER := 1.56

const VIPER_HOLOGRAM_ATTACK_LEFT_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_left_attack_sheet.png"
const VIPER_HOLOGRAM_ATTACK_RIGHT_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_right_attack_sheet.png"
const VIPER_HOLOGRAM_FRAME_SIZE := Vector2(160.0, 160.0)
const VIPER_HOLOGRAM_BASE_VISUAL_SIZE := Vector2(160.0, 160.0)
const VIPER_HOLOGRAM_ATTACK_GRID_COLS := 4
const VIPER_HOLOGRAM_ATTACK_FRAME_COUNT := 8
const VIPER_HOLOGRAM_BASE_PADDLE_WIDTH := 155.0
const VIPER_HOLOGRAM_FEET_OFFSET := 12.0
const SHADOW_HIT_SHAKE_AMOUNT_BASE := 0.09
const SHADOW_HIT_SHAKE_AMOUNT_CENTER_BONUS := 0.07
const SHADOW_HIT_SHAKE_INTENSITY_BASE := 3.2
const SHADOW_HIT_SHAKE_INTENSITY_CENTER_BONUS := 1.8
const SHADOW_HIT_PARTICLE_INTENSITY_BASE := 0.72
const SHADOW_HIT_PARTICLE_INTENSITY_CENTER_BONUS := 0.36
const SHADOW_HIT_ENERGY_SCALE_BASE := 0.48
const SHADOW_HIT_ENERGY_SCALE_CENTER_BONUS := 0.22
const SHADOW_HIT_ENERGY_INTENSITY_BASE := 0.62
const SHADOW_HIT_ENERGY_INTENSITY_CENTER_BONUS := 0.30
const MARSHAL_HIT_SHAKE_AMOUNT := 0.13
const MARSHAL_DOUBLE_HIT_SHAKE_AMOUNT := 0.20
const MARSHAL_HIT_SHAKE_INTENSITY := 3.6
const MARSHAL_DOUBLE_HIT_SHAKE_INTENSITY := 5.0
const MARSHAL_HIT_PARTICLE_INTENSITY := 0.86
const MARSHAL_DOUBLE_HIT_PARTICLE_INTENSITY := 1.30
const MARSHAL_HIT_ENERGY_SCALE := 0.58
const MARSHAL_DOUBLE_HIT_ENERGY_SCALE := 0.82
const MARSHAL_HIT_PULSE_KIND := "viper_marshal"
const MARSHAL_DOUBLE_HIT_PULSE_KIND := "viper_double_marshal"
const MARSHAL_HIT_ENERGY_INTENSITY := 0.72
const MARSHAL_DOUBLE_HIT_ENERGY_INTENSITY := 0.96
const MARSHAL_FALLBACK_HIT_COLOR := Color(0.72, 0.0, 1.0, 1.0)
const MARSHAL_HIT_PLAYER_COLLISION_COOLDOWN := 6.0
const MARSHAL_HIT_GOLD := 30
const MARSHAL_DOUBLE_HIT_GOLD := 50
const MARSHAL_HIT_MOTION_PARTICLE_COUNT := 14
const MARSHAL_DOUBLE_HIT_MOTION_PARTICLE_COUNT := 22
const MARSHAL_HIT_MOTION_PARTICLE_SPREAD := 10.0
const MARSHAL_HIT_MOTION_PARTICLE_LIFE_MIN := 18.0
const MARSHAL_HIT_MOTION_PARTICLE_LIFE_MAX := 34.0
const MARSHAL_HIT_MOTION_PARTICLE_KIND := "impact"
const MARSHAL_HIT_MOTION_PARTICLE_CHANCE := 1.0
const CORE_FLIP_HIT_MOTION_PARTICLE_COUNT := 18
const CORE_FLIP_HIT_MOTION_PARTICLE_SPREAD := 12.0
const CORE_FLIP_HIT_MOTION_PARTICLE_LIFE_MIN := 20.0
const CORE_FLIP_HIT_MOTION_PARTICLE_LIFE_MAX := 38.0
const CORE_FLIP_HIT_MOTION_PARTICLE_KIND := "impact"
const CORE_FLIP_HIT_MOTION_PARTICLE_CHANCE := 1.0
const PHANTOM_HIT_PARTICLE_COUNT := 85
const PHANTOM_HIT_PARTICLE_MAX_COUNT := 90
const VIPER_HIT_PARTICLE_GLOW_SIZE_THRESHOLD := 3.2

var previous_down_pressed := false
var previous_left_pressed := false
var previous_up_pressed := false
var previous_right_pressed := false
var input_sequence_frame := 0
var core_flip_left_press_frame := CORE_FLIP_INPUT_FRAME_UNSET
var core_flip_right_press_frame := CORE_FLIP_INPUT_FRAME_UNSET
var previous_dash_active := false
var previous_dash_recovering := false
var audio_router: Object = ViperSkillAudioRouter.new()
var blade_effect_renderer: Object = ViperSkillBladeEffectRenderer.new()
var chaos_spear_effect_renderer: Object = ViperSkillChaosSpearEffectRenderer.new()
var context_builder: Object = ViperSkillContextBuilder.new()
var dual_glitch_effect_renderer: Object = ViperSkillDualGlitchEffectRenderer.new()
var floating_text_renderer: Object = ViperSkillFloatingTextRenderer.new()
var fx_host_controller: Object = ViperSkillFxHostController.new()
var kick_effect_renderer: Object = ViperSkillKickEffectRenderer.new()
var particle_drawer: Object = ViperSkillParticleDrawer.new()
var runtime_action_router: Object = ViperSkillRuntimeActionRouter.new()
var shadow_effect_renderer: Object = ViperSkillShadowEffectRenderer.new()
var snapshot_builder: Object = ViperSkillSnapshotBuilder.new()
var skill_scaling: Object = ViperSkillScaling.new()
var timer_gauge_renderer: Object = ViperSkillTimerGaugeRenderer.new()
var visibility_query: Object = ViperSkillVisibilityQuery.new()
var dash_origin_pos := Vector2.ZERO
var dash_origin_valid := false
var dash_grace_frames := 0.0
var shadow_step_ready_frames := 0.0
var shadow_step_activation_msec := -100000
var shadow_hologram_active := false
var shadow_hologram_frames := 0.0
var shadow_hologram_origin := Vector2.ZERO
var shadow_hologram_target := Vector2.ZERO
var shadow_hologram_kick_dir := 1
var shadow_hologram_kick_hit := false
var shadow_hologram_dest_shock_spawned := false
var shadow_paddle_size := Vector2(155.0, 50.0)
var shadow_wave_active := false
var shadow_wave_pos := Vector2.ZERO
var shadow_wave_target_x := 0.0
var shadow_wave_dir := 1
var shadow_wave_hit_ball := false
var shadow_wave_trail: Array = []
var shadow_kick_ready := false
var shadow_kick_ready_frames := 0.0
var shadow_hit_consumed := false
var shadow_was_airborne := false
var shadow_marshal_delay_frames := 0.0
var shadow_curve_active := false
var shadow_curve_timer := 0.0
var shadow_curve_total := 0.0
var shadow_curve_force := 0.0
var shadow_curve_dir := 1
var shadow_starburst_active := false
var shadow_starburst_pos := Vector2.ZERO
var shadow_starburst_frame := 0
var shadow_starburst_timer := 0.0
var shadow_starburst_is_double := false
var phantom_strike_active := false
var phantom_strike_frames := 0.0
var phantom_strike_curve_dir := 1
var blade_motion_active := false
var blade_motion_phase := 0
var blade_motion_frames := 0.0
var blade_motion_total_frames := 0.0
var blade_spin_angle := 0.0
var blade_dark_mode := false
var blade_motion_start_pos := Vector2.ZERO
var blade_motion_pos := Vector2.ZERO
var blade_phase2_base_y := 0.0
var blade_paddle_size := Vector2(155.0, 50.0)
var blade_projectile_active := false
var blade_projectile_pos := Vector2.ZERO
var blade_projectile_start_y := 0.0
var blade_projectile_target_y := 0.0
var blade_projectile_width := BLADE_BASE_WIDTH
var blade_projectile_hit_ball := false
var blade_projectile_trail: Array = []
var blade_projectile_fadeout := false
var blade_projectile_fadeout_frames := 0.0
var blade_air_combo_window := false
var blade_air_fire_frames := 0.0
var blade_dark_combo_window := false
var blade_dark_fire_frames := 0.0
var blade_hit_speed_cap_active := 0.0
var dark_blade_window := false
var dark_blade_window_frames := 0.0
var blade_spin_sound_active := false
var blade_spin_audio: Object = null
var blade_followup_projectiles: Array = []
var nerve_strike_active := false
var nerve_strike_phase := 0
var nerve_strike_phase_frames := 0.0
var nerve_strike_start_pos := Vector2.ZERO
var nerve_strike_pos := Vector2.ZERO
var nerve_strike_dash_target_pos := Vector2.ZERO
var nerve_strike_return_start_pos := Vector2.ZERO
var nerve_strike_return_target_pos := Vector2.ZERO
var nerve_strike_paddle_size := Vector2(155.0, 50.0)
var nerve_strike_floor_y := 700.0
var nerve_strike_hit_confirmed := false
var nerve_strike_combo_used := false
var nerve_strike_freeze_active := false
var nerve_strike_slash_triggered := false
var nerve_strike_slash_vfx_frames := 0.0
var nerve_strike_slash_center := Vector2.ZERO
var nerve_strike_cast_id := 0
var nerve_strike_miss_text_timer := 0.0
var nerve_strike_miss_text_pos := Vector2.ZERO
var nerve_strike_clone_slashes: Array = []
var dive_hold_start_msec := 0
var dive_hold_ratio := 0.0
var dive_hold_player_pos := Vector2.ZERO
var dive_hold_paddle_size := Vector2(155.0, 50.0)
var dive_charge_particles: Array = []
var dive_active := false
var dive_phase := 0
var dive_phase_frames := 0.0
var dive_player_pos := Vector2.ZERO
var dive_paddle_size := Vector2(155.0, 50.0)
var dive_floor_y := 700.0
var dive_height_snapshot := 0.0
var dive_prep_frames_snapshot := DIVE_PREP_FRAMES
var dive_shockwave_timer := 0.0
var dive_shockwave_pos := Vector2.ZERO
var dive_shockwave_max_radius := DIVE_SHOCKWAVE_BASE_MAX_RADIUS
var dive_shockwave_boss_effect_applied := false
var dive_ball_boosted := false
var dive_particles: Array = []
var dive_slip_timer := 0.0
var dive_slip_duration := 0.0
var dive_slip_vel := 0.0
var dive_hit_text_timer := 0.0
var dive_hit_text_pos := Vector2.ZERO
var dive_hit_text_height_ratio := 0.0
var dive_effect_start_msec := 0
var dive_shockwave_spawn_msec := 0
var dive_hit_feedback_msec := 0
var ignition_hold_start_msec := 0
var ignition_hold_ratio := 0.0
var ignition_hold_player_pos := Vector2.ZERO
var ignition_hold_paddle_size := Vector2(155.0, 50.0)
var ignition_active := false
var ignition_remaining_frames := 0.0
var ignition_total_frames := IGNITION_DURATION_FRAMES
var ignition_player_pos := Vector2.ZERO
var ignition_paddle_size := Vector2(155.0, 50.0)
var ignition_burst_particles: Array = []
var ignition_charge_particles: Array = []
var ignition_live_embers: Array = []
var ignition_ember_timer := 0.0
var ignition_start_msec := 0
var ignition_aura_effect_texture: Texture2D = null
var ignition_aura_effect_load_attempted := false
var dual_glitch_cmd_buffer: Array = []
var dual_glitch_state := "idle"
var dual_glitch_phase_frames := 0.0
var dual_glitch_active_total_frames := DUAL_GLITCH_ACTIVE_FRAMES
var dual_glitch_locked_player_x := 0.0
var dual_glitch_locked_player_x_valid := false
var dual_glitch_base_pos := Vector2.ZERO
var dual_glitch_paddle_size := Vector2(155.0, 50.0)
var dual_glitch_clones: Array = []
var dual_glitch_clone_dive_entries: Array = []
var dual_glitch_fade_reason := ""
var dual_glitch_start_msec := 0
var marshal_ready := false
var marshal_ready_frames := 0.0
var marshal_phantom_allowed := false
var double_marshal_ready := false
var double_marshal_ready_frames := 0.0
var marshal_first_hit_pending := false
var marshal_first_hit_delay_frames := 0.0
var marshal_is_double := false
var phantom_kick_knockback_pending := false
var phantom_kick_speed_limit_disabled := false
var kick_skill_knockback_pending_pct := 0
var phantom_aura_active := false
var dmk_freeze_active := false
var dmk_freeze_frames := 0.0
var dmk_text_active := false
var dmk_text_frames := 0.0
# Venom Edge strike state: front-view eye-slash that plays at the boss's
# back position and is partially hidden by the boss sprite.
# Driven by frame counter (8 frames over VENOM_EDGE_STRIKE_TOTAL_FRAMES game frames).
# Triggered by the Venom Edge runtime through trigger_venom_edge_strike();
# the asset (viper_subculture_venom_edge_strike_sheet.png) is already loaded.
var venom_edge_strike_active := false
var venom_edge_strike_elapsed_frames := 0.0
const VENOM_EDGE_STRIKE_TOTAL_FRAMES := 36.0  # ~0.6s at 60fps, 8 cells -> ~4.5 frames per cell
# Venom Edge stationary state: Viper has arrived behind the boss and is
# holding a front-facing pose (face visible) before/after the slash. Held
# indefinitely until cleared, so Venom Edge runtime code can run any
# windup / pause logic between teleport-in and strike. Renders Cell 1 of the
# strike sheet (arrival pose) at the boss position. Strike-active overrides
# stationary at the renderer (priority order in stage1_player_sprite_renderer).
var venom_edge_stationary_active := false
var core_flip_ready_msec := 0
var core_flip_consumed := true
var core_flip_buffered_until_msec := 0
var core_flip_last_dash_start_msec := CORE_FLIP_DASH_START_UNSET_MSEC
var core_flip_attack_active := false
var core_flip_attack_phase := 0
var core_flip_phase_frames := 0.0
var core_flip_paddle_size := CORE_FLIP_DEFAULT_PADDLE_SIZE
var core_flip_origin_center := Vector2.ZERO
var core_flip_target_center := Vector2.ZERO
var core_flip_apex_center := Vector2.ZERO
var core_flip_visual_pos := Vector2.ZERO
var core_flip_return_start_center := Vector2.ZERO
var core_flip_kick_dir := 1
var core_flip_ball_hit := false
var core_flip_spin_angle_degrees := 0.0
var core_flip_spin_sound_started := false
var core_flip_kick_sound_played := false
var core_flip_dark_blade_handoff_frames := 0.0
var core_flip_web_lines: Array = []
var core_flip_miss_text_timer := 0.0
var core_flip_miss_text_pos := Vector2.ZERO
var marshal_active := false
var marshal_phase := 0
var marshal_phase_frames := 0.0
var marshal_paddle_size := Vector2(155.0, 50.0)
var marshal_start_pos := Vector2.ZERO
var marshal_visual_pos := Vector2.ZERO
var marshal_wall_pos := Vector2.ZERO
var marshal_wall_side := 0  # +1 if wall is to viewer-right of start, -1 to viewer-left, 0 inactive
var marshal_reclimb_start_pos := Vector2.ZERO
var marshal_charge_start_pos := Vector2.ZERO
var marshal_return_start_pos := Vector2.ZERO
var marshal_ball_hit := false
var marshal_activation_msec := -100000
var marshal_hit_msec := -100000
var marshal_last_hit_pos := Vector2.ZERO
var marshal_charge_target_pos := Vector2.ZERO
var marshal_web_lines: Array = []
var marshal_particles: Array = []
var phantom_hit_particles: Array = []
var chaos_cmd_buffer: Array = []
var chaos_state := "idle"
var chaos_phase_frames := 0.0
var chaos_origin := Vector2.ZERO
var chaos_target := Vector2.ZERO
var chaos_current := Vector2.ZERO
var chaos_prev_ball_center := Vector2.ZERO
var chaos_prev_ball_valid := false
var chaos_blackhole_ball_origin := Vector2.ZERO
var chaos_blackhole_origin_valid := false
var chaos_base_radius := 52.0
var chaos_orbit_seed := 0.0
var chaos_flight_angle := 0.0
var chaos_impact_seed := 0.0
var chaos_locked_player_x := 0.0
var chaos_locked_player_x_valid := false
var chaos_absorb_pulses: Array = []
var chaos_cancel_flash_frames := 0.0
var chaos_absorb_poll_frames := 0.0
var chaos_gold_ticks_paid := 0
var chaos_explosion_shaken := false
var chaos_fx_host: Node = null
var chaos_fx_host_add_pending := false
var chaos_fx_spawn_msec_seed: int = 0
var emp_fx_host: Node = null
var emp_fx_host_add_pending := false
var chaos_release_pending := false
var chaos_release_velocity := Vector2.ZERO
var viper_hologram_attack_left_sheet: Texture2D
var viper_hologram_attack_right_sheet: Texture2D


func _init() -> void:
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()
	ChaosSpearFxHost.prewarm_assets()
	EmpStrikeFxHost.prewarm_assets()


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	ChaosSpearFxHost.prewarm_assets()
	EmpStrikeFxHost.prewarm_assets()
	return bool(particle_drawer.prewarm_ignition_aura_assets(self, IGNITION_AURA_EFFECT_SHEET_PATH))


func prewarm_runtime_nodes(owner: Object = null) -> void:
	fx_host_controller.prewarm_viper_fx_hosts(self, owner)


func prewarm_runtime_nodes_step(owner: Object = null) -> bool:
	prewarm_runtime_nodes(owner)
	return true


func reset() -> void:
	reset_round({"preserve_ignition_aura": false})


func reset_round(deps: Dictionary = {}) -> void:
	var preserve_ignition_aura := bool(deps.get("preserve_ignition_aura", true)) and ignition_active and ignition_remaining_frames > 0.0
	previous_down_pressed = false
	previous_left_pressed = false
	previous_up_pressed = false
	previous_right_pressed = false
	input_sequence_frame = 0
	core_flip_left_press_frame = CORE_FLIP_INPUT_FRAME_UNSET
	core_flip_right_press_frame = CORE_FLIP_INPUT_FRAME_UNSET
	previous_dash_active = false
	previous_dash_recovering = false
	dash_origin_pos = Vector2.ZERO
	dash_origin_valid = false
	dash_grace_frames = 0.0
	shadow_step_ready_frames = 0.0
	shadow_step_activation_msec = -100000
	_reset_shadow_step_runtime()
	_clear_marshal_ready_window()
	marshal_phantom_allowed = false
	_clear_double_marshal_ready_window()
	_clear_marshal_first_hit_pending()
	phantom_kick_knockback_pending = false
	phantom_kick_speed_limit_disabled = false
	kick_skill_knockback_pending_pct = 0
	_clear_dmk_presentation_state()
	venom_edge_strike_active = false
	venom_edge_strike_elapsed_frames = 0.0
	venom_edge_stationary_active = false
	_reset_core_flip_runtime(true)
	_reset_chaos_spear_runtime(true, deps)
	_reset_dual_glitch_runtime(true)
	if preserve_ignition_aura:
		# Ignition Aura is an explicit cross-round carryover exception: keep the
		# timed buff, but clear hold / one-shot particles at the score boundary.
		_reset_ignition_aura_hold()
		ignition_burst_particles.clear()
		ignition_charge_particles.clear()
		ignition_live_embers.clear()
		ignition_ember_timer = 0.0
		_set_runtime_ignition_aura_bonus(deps, true)
	else:
		_set_runtime_ignition_aura_bonus(deps, false)
		_reset_ignition_aura_hold()
		ignition_active = false
		ignition_remaining_frames = 0.0
		ignition_total_frames = IGNITION_DURATION_FRAMES
		ignition_player_pos = Vector2.ZERO
		ignition_paddle_size = Vector2(155.0, 50.0)
		ignition_burst_particles.clear()
		ignition_charge_particles.clear()
		ignition_live_embers.clear()
		ignition_ember_timer = 0.0
		ignition_start_msec = 0
	_reset_nerve_strike_runtime(true)
	_reset_blade_motion_only()
	_clear_blade_projectile()
	clear_blade_hit_speed_cap()
	dark_blade_window = false
	dark_blade_window_frames = 0.0
	nerve_strike_combo_used = false
	blade_followup_projectiles.clear()
	_reset_dive_runtime(true)
	_reset_marshal_runtime_fields()
	marshal_particles.clear()
	phantom_hit_particles.clear()


func _clear_dmk_presentation_state() -> void:
	dmk_freeze_active = false
	dmk_freeze_frames = 0.0
	dmk_text_active = false
	dmk_text_frames = 0.0


func open_marshal_kick_window() -> void:
	if marshal_active:
		return
	marshal_ready = true
	marshal_ready_frames = MARSHAL_KICK_READY_FRAMES
	marshal_phantom_allowed = true
	_clear_double_marshal_ready_window()


func _clear_marshal_ready_window() -> void:
	marshal_ready = false
	marshal_ready_frames = 0.0


func _clear_double_marshal_ready_window() -> void:
	double_marshal_ready = false
	double_marshal_ready_frames = 0.0


func _clear_marshal_first_hit_pending() -> void:
	marshal_first_hit_pending = false
	marshal_first_hit_delay_frames = 0.0


func try_activate_before_movement(
	delta: float,
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var input_reader: Object = deps.get("input_reader", null)
	var input_snapshot: Dictionary = input_reader.get_snapshot() if input_reader != null else {}
	input_sequence_frame += 1
	var now_msec: int = Time.get_ticks_msec()
	var down_pressed: bool = bool(input_snapshot.get("down_pressed", false))
	var pressed_edge: bool = down_pressed and not previous_down_pressed
	var up_pressed: bool = bool(input_snapshot.get("up_pressed", false))
	var up_edge: bool = up_pressed and not previous_up_pressed
	previous_down_pressed = down_pressed
	_record_viper_command_inputs(input_snapshot, now_msec, visibility_query.get_viper_skill_config(deps), deps)
	if nerve_strike_active:
		return _update_nerve_strike(delta, player_pos, special_gauge, config, deps)
	if dual_glitch_state == "startup":
		var dual_startup_pos: Vector2 = player_pos
		if dual_glitch_locked_player_x_valid:
			var dual_play_left: float = float(config.get("play_left", 0.0))
			var dual_play_right: float = float(config.get("play_right", 760.0))
			dual_startup_pos.x = clamp(dual_glitch_locked_player_x, dual_play_left, max(dual_play_left, dual_play_right - ViperSkillGeometry.get_paddle_size(config).x))
		dual_glitch_base_pos = dual_startup_pos
		return {
			"handled": true,
			"activated": false,
			"skill_name": DUAL_GLITCH,
			"player_pos": dual_startup_pos,
			"player_speed": 0.0,
			"special_gauge": special_gauge,
			"locked_player_x": dual_startup_pos.x,
		}
	if dive_active:
		return _update_dive_strike(delta, player_pos, special_gauge, config, deps)
	if core_flip_attack_active:
		if up_edge and _can_start_dark_blade_from_window(special_gauge, config, deps):
			var core_flip_blade_handoff_pos: Vector2 = core_flip_visual_pos
			_reset_core_flip_runtime(false)
			return _start_blade_motion(core_flip_blade_handoff_pos, special_gauge, config, deps, true, now_msec)
		return _update_core_flip(delta, player_pos, special_gauge, config, deps)
	if _is_core_flip_ready_window_active(now_msec):
		var core_flip_pressed_combo: bool = bool(input_snapshot.get("left_pressed", false)) and bool(input_snapshot.get("right_pressed", false))
		var core_flip_left_press_age: int = input_sequence_frame - core_flip_left_press_frame
		var core_flip_right_press_age: int = input_sequence_frame - core_flip_right_press_frame
		var core_flip_stored_combo: bool = (
			core_flip_left_press_age >= 0
			and core_flip_left_press_age <= CORE_FLIP_INPUT_MAX_AGE_FRAMES
			and core_flip_right_press_age >= 0
			and core_flip_right_press_age <= CORE_FLIP_INPUT_MAX_AGE_FRAMES
			and abs(core_flip_left_press_frame - core_flip_right_press_frame) <= CORE_FLIP_INPUT_FRAME_GAP
		)
		if core_flip_pressed_combo or core_flip_stored_combo:
			core_flip_buffered_until_msec = core_flip_ready_msec + CORE_FLIP_READY_WINDOW_MSEC
		if (
			core_flip_buffered_until_msec >= now_msec
			and not _has_viper_attack_motion_active(true)
			and not shadow_hologram_active
			and chaos_state == "idle"
		):
			var core_flip_dash_snapshot: Dictionary = visibility_query.get_dash_snapshot(deps.get("dash_state", null))
			if (
				not bool(core_flip_dash_snapshot.get("active", false))
				and not visibility_query.is_control_locked(deps)
				and bool(config.get("ball_active", true))
				and not visibility_query.is_round_waiting_for_serve(deps)
			):
				var core_flip_skill_config: Object = visibility_query.get_viper_skill_config(deps)
				var core_flip_cost: float = visibility_query.get_skill_cost(core_flip_skill_config, CORE_FLIP)
				core_flip_cost = core_flip_cost if core_flip_cost > 0.0 else 120.0
				if (
					visibility_query.is_skill_equipped(core_flip_skill_config, CORE_FLIP)
					and special_gauge >= core_flip_cost
					and visibility_query.is_configured_skill_ready(CORE_FLIP, deps, now_msec)
				):
					return _start_core_flip(player_pos, special_gauge, config, deps, now_msec)
	if _check_dual_glitch_command(now_msec):
		if (
			dual_glitch_state == "idle"
			and not _has_viper_attack_motion_active(true)
			and chaos_state != "startup"
			and not (visibility_query.is_dash_motion_busy(deps) or visibility_query.is_control_locked(deps))
			and bool(config.get("ball_active", false))
			and not visibility_query.is_round_waiting_for_serve(deps)
		):
			var dual_glitch_skill_config: Object = visibility_query.get_viper_skill_config(deps)
			if _can_activate_configured_skill(dual_glitch_skill_config, special_gauge, deps, DUAL_GLITCH, now_msec):
				return _start_dual_glitch(player_pos, special_gauge, config, deps, now_msec)
	var blade_combo_result: Dictionary = {}
	if up_edge and blade_motion_active and blade_motion_phase == 2:
		if not blade_dark_mode:
			blade_combo_result = _try_start_blade_combo_from_air_blade_motion(player_pos, special_gauge, config, deps, now_msec)
		else:
			blade_combo_result = _try_start_blade_combo_from_dark_blade_motion(player_pos, special_gauge, config, deps, now_msec)
	if not blade_combo_result.is_empty():
		return blade_combo_result
	if chaos_state == "startup":
		var chaos_startup_pos: Vector2 = player_pos
		if chaos_locked_player_x_valid:
			var chaos_play_left: float = float(config.get("play_left", 0.0))
			var chaos_play_right: float = float(config.get("play_right", 760.0))
			chaos_startup_pos.x = clamp(
				chaos_locked_player_x,
				chaos_play_left,
				max(chaos_play_left, chaos_play_right - ViperSkillGeometry.get_paddle_size(config).x)
			)
		return {
			"handled": true,
			"activated": false,
			"skill_name": CHAOS_SPEAR,
			"player_pos": chaos_startup_pos,
			"player_speed": 0.0,
			"special_gauge": special_gauge,
			"allow_jetpack_overlay": true,
			"locked_player_x": chaos_startup_pos.x,
		}
	if (
		_check_chaos_command(now_msec)
		and _can_start_chaos_spear(special_gauge, config, deps, now_msec)
	):
		return _start_chaos_spear(player_pos, special_gauge, config, deps, now_msec)
	var ignition_result: Dictionary = _try_update_ignition_aura_hold(input_snapshot, player_pos, special_gauge, config, deps, now_msec)
	if not ignition_result.is_empty():
		return ignition_result

	shadow_step_ready_frames = max(0.0, shadow_step_ready_frames - delta * 60.0)
	if blade_motion_active:
		return _update_blade_motion(delta, player_pos, special_gauge, config, deps)
	if marshal_active:
		if up_edge and _can_start_dark_blade_from_window(special_gauge, config, deps):
			var marshal_blade_handoff_pos: Vector2 = marshal_visual_pos
			_reset_marshal_runtime_fields()
			_clear_dmk_presentation_state()
			marshal_particles.clear()
			return _start_blade_motion(marshal_blade_handoff_pos, special_gauge, config, deps, true, now_msec)
		return _update_marshal_kick(delta, player_pos, special_gauge, config, deps)
	var dive_result: Dictionary = _try_update_dive_hold(input_snapshot, player_pos, special_gauge, config, deps, now_msec)
	if not dive_result.is_empty():
		return dive_result
	if pressed_edge:
		var marshal_skill_name: String = visibility_query.get_marshal_skill_to_fire(self, MARSHAL_KICK, PHANTOM_KICK)
		if (
			marshal_skill_name != ""
			and not visibility_query.is_control_locked(deps)
			and not _has_lateral_skill_input(input_snapshot)
		):
			var marshal_skill_config: Object = visibility_query.get_viper_skill_config(deps)
			if (
				visibility_query.is_skill_equipped(marshal_skill_config, marshal_skill_name)
				and special_gauge >= visibility_query.get_marshal_skill_cost(marshal_skill_config, marshal_skill_name, PHANTOM_KICK)
				and visibility_query.is_configured_skill_ready(marshal_skill_name, deps, -1)
			):
				var marshal_now_msec: int = Time.get_ticks_msec()
				var marshal_start_skill_config: Object = visibility_query.get_viper_skill_config(deps)
				var marshal_start_skill_name: String = marshal_skill_name
				var marshal_is_double_start: bool = marshal_start_skill_name == PHANTOM_KICK
				var marshal_next_gauge: float = max(
					0.0,
					special_gauge - visibility_query.get_marshal_skill_cost(marshal_start_skill_config, marshal_start_skill_name, PHANTOM_KICK)
				)
				_trigger_configured_cooldown_and_orb_gauge_spin(
					marshal_start_skill_name,
					marshal_start_skill_config,
					deps,
					marshal_now_msec
				)
				runtime_action_router.trigger_feedback(deps, 0.12, 4.0)
				_cancel_dash_until_key_release(deps.get("dash_state", null))
				audio_router.play_marshal_backstep_sound(deps)
				_clear_marshal_ready_window()
				_clear_double_marshal_ready_window()
				_clear_marshal_first_hit_pending()
				marshal_is_double = marshal_is_double_start
				phantom_aura_active = marshal_is_double_start
				phantom_kick_knockback_pending = false
				_clear_dmk_presentation_state()
				marshal_active = true
				marshal_phase = 0
				marshal_phase_frames = 0.0
				marshal_paddle_size = ViperSkillGeometry.get_paddle_size(config)
				marshal_start_pos = player_pos
				marshal_visual_pos = player_pos
				var marshal_field_width: float = float(config.get("width", config.get("play_right", 760.0)))
				var marshal_player_center: Vector2 = ViperSkillGeometry.player_center(player_pos, config)
				var marshal_ball_pos: Vector2 = ViperSkillGeometry.get_ball_pos(config)
				var marshal_wall_target: Dictionary = ViperSkillGeometry.marshal_initial_wall_target(
					player_pos,
					marshal_player_center,
					marshal_ball_pos,
					marshal_paddle_size,
					marshal_field_width,
					float(config.get("player_floor_y", 700.0)),
					MARSHAL_KICK_WALL_INSET,
					200.0,
					650.0,
					50.0,
					200.0
				)
				marshal_wall_pos = _get_vector2(marshal_wall_target.get("pos", player_pos), player_pos)
				marshal_wall_side = int(marshal_wall_target.get("side", 0))
				marshal_reclimb_start_pos = Vector2.ZERO
				marshal_charge_start_pos = Vector2.ZERO
				marshal_return_start_pos = Vector2.ZERO
				marshal_ball_hit = false
				marshal_activation_msec = marshal_now_msec
				marshal_hit_msec = -100000
				marshal_last_hit_pos = Vector2.ZERO
				marshal_charge_target_pos = Vector2.ZERO
				marshal_web_lines.clear()
				marshal_particles.clear()
				_set_marshal_web_line_to_wall(marshal_start_pos, config)
				return {
					"handled": true,
					"activated": true,
					"skill_name": marshal_start_skill_name,
					"player_pos": player_pos,
					"player_speed": 0.0,
					"special_gauge": marshal_next_gauge,
				}
	if up_edge:
		if _can_start_dark_blade_from_window(special_gauge, config, deps):
			return _start_blade_motion(player_pos, special_gauge, config, deps, true, now_msec)
		if _can_start_air_blade(special_gauge, config, deps):
			return _start_blade_motion(player_pos, special_gauge, config, deps, false, now_msec)
	if (
		pressed_edge
		and dash_origin_valid
		and dash_grace_frames > 0.0
		and not _has_lateral_skill_input(input_snapshot)
		and not (shadow_hologram_active or shadow_wave_active or shadow_marshal_delay_frames > 0.0)
		and not marshal_ready
		and not marshal_active
		and not core_flip_attack_active
		and not visibility_query.is_control_locked(deps)
	):
		var shadow_skill_config: Object = visibility_query.get_viper_skill_config(deps)
		if _can_activate_configured_skill(shadow_skill_config, special_gauge, deps, SHADOW_STEP):
			return _start_shadow_step(player_pos, special_gauge, config, deps, now_msec)
	return {"handled": false, "activated": false, "special_gauge": special_gauge}


func observe_after_movement(delta: float, before_player_pos: Vector2, _after_player_pos: Vector2, deps: Dictionary) -> void:
	if dual_glitch_state in ["spawn", "active", "fade"]:
		dual_glitch_base_pos = _after_player_pos
	var dash_snapshot: Dictionary = visibility_query.get_dash_snapshot(deps.get("dash_state", null))
	var dash_active: bool = bool(dash_snapshot.get("active", false))
	var dash_recovering: bool = bool(dash_snapshot.get("recovering", false))
	if dash_active and not previous_dash_active:
		dash_origin_pos = before_player_pos
		dash_origin_valid = true
		core_flip_last_dash_start_msec = Time.get_ticks_msec()
		core_flip_consumed = bool(dash_snapshot.get("is_half", false))
		core_flip_ready_msec = 0
		core_flip_buffered_until_msec = 0
	if dash_active or dash_recovering:
		dash_grace_frames = SHADOW_STEP_DASH_GRACE_FRAMES
	else:
		dash_grace_frames = max(0.0, dash_grace_frames - delta * 60.0)
		if dash_grace_frames <= 0.0:
			dash_origin_valid = false
	previous_dash_active = dash_active
	previous_dash_recovering = dash_recovering


func get_snapshot() -> Dictionary:
	return snapshot_builder.build(self)


func is_air_blade_dash_window_open(deps: Dictionary = {}) -> bool:
	return (
		(blade_motion_active and blade_motion_phase == 2)
		and not blade_dark_mode
		and blade_motion_frames >= BLADE_DASH_RELEASE_DELAY_FRAMES
		and not visibility_query.is_control_locked(deps)
	)


func sync_blade_motion_position(player_pos: Vector2) -> void:
	if blade_motion_active:
		blade_motion_pos = player_pos


func get_actor_draw_context() -> Dictionary:
	return context_builder.build_actor_draw_context(self)


func get_ball_collision_context() -> Dictionary:
	return context_builder.build_ball_collision_context(self)


func get_blade_hit_speed_cap() -> float:
	return max(0.0, blade_hit_speed_cap_active)


func clear_blade_hit_speed_cap() -> void:
	blade_hit_speed_cap_active = 0.0


func is_phantom_kick_speed_limit_disabled() -> bool:
	return phantom_kick_speed_limit_disabled


func get_boss_ai_context() -> Dictionary:
	return context_builder.build_boss_ai_context(self)


func get_emp_shockwave_progress() -> float:
	return ViperSkillGeometry.emp_strike_shockwave_progress(
		dive_shockwave_timer,
		dive_shockwave_pos,
		DIVE_SHOCKWAVE_FRAMES
	)


func get_emp_shockwave_radius() -> float:
	return ViperSkillGeometry.emp_strike_shockwave_radius(
		dive_shockwave_timer,
		dive_shockwave_pos,
		DIVE_SHOCKWAVE_FRAMES,
		DIVE_SHOCKWAVE_START_RADIUS,
		dive_shockwave_max_radius
	)


func is_kick_skill_knockback_ball_active() -> bool:
	return visibility_query.is_kick_skill_knockback_ball_active(self)


func is_dmk_freeze_active() -> bool:
	return visibility_query.is_dmk_freeze_active(self)


func has_visible_effects() -> bool:
	return visibility_query.has_visible_effects(self)


func needs_ball_motion_update() -> bool:
	return visibility_query.needs_ball_motion_update(self)


func needs_effect_update() -> bool:
	return visibility_query.needs_effect_update(self)


func is_chaos_blackhole_audio_active() -> bool:
	return visibility_query.is_chaos_blackhole_audio_active(self)


func update_effects(fps_scale: float, _current_msec: int, context: Dictionary, deps: Dictionary) -> Dictionary:
	if shadow_kick_ready:
		shadow_kick_ready_frames = max(0.0, shadow_kick_ready_frames - fps_scale)
		if shadow_kick_ready_frames <= 0.0:
			_clear_shadow_kick_ready()
	if shadow_hologram_active:
		shadow_hologram_frames += fps_scale
		var shadow_hologram_progress: float = _get_shadow_hologram_progress()
		if shadow_hologram_progress >= 0.95 and not shadow_hologram_dest_shock_spawned:
			shadow_hologram_dest_shock_spawned = true
			particle_drawer.spawn_shadow_activation_feedback(shadow_hologram_target, deps.get("impact_effects", null), 0.75)
		if shadow_hologram_progress >= 1.0:
			shadow_hologram_active = false
	if phantom_strike_active:
		phantom_strike_frames = max(0.0, phantom_strike_frames - fps_scale)
		if phantom_strike_frames <= 0.0:
			phantom_strike_active = false
	if shadow_marshal_delay_frames > 0.0:
		shadow_marshal_delay_frames = max(0.0, shadow_marshal_delay_frames - fps_scale)
		if shadow_marshal_delay_frames <= 0.0:
			if core_flip_attack_active:
				shadow_marshal_delay_frames = 1.0
			elif not marshal_active:
				var shadow_skill_config: Object = visibility_query.get_viper_skill_config(deps)
				if visibility_query.is_skill_equipped(shadow_skill_config, MARSHAL_KICK):
					if visibility_query.context_has_enough_gauge(context, visibility_query.get_marshal_skill_cost(shadow_skill_config, MARSHAL_KICK, PHANTOM_KICK)):
						if visibility_query.is_configured_skill_ready(MARSHAL_KICK, deps, -1):
							open_marshal_kick_window()
	if shadow_starburst_active:
		shadow_starburst_timer += fps_scale
		while shadow_starburst_timer >= SHADOW_STEP_STARBURST_FRAME_DURATION and shadow_starburst_active:
			shadow_starburst_timer -= SHADOW_STEP_STARBURST_FRAME_DURATION
			shadow_starburst_frame += 1
			if shadow_starburst_frame >= SHADOW_STEP_STARBURST_FRAMES:
				shadow_starburst_active = false
	if core_flip_dark_blade_handoff_frames > 0.0:
		core_flip_dark_blade_handoff_frames = max(0.0, core_flip_dark_blade_handoff_frames - fps_scale)
	if dark_blade_window:
		dark_blade_window_frames = max(0.0, dark_blade_window_frames - fps_scale)
		var core_flip_dark_ready := (core_flip_attack_active and core_flip_ball_hit) or core_flip_dark_blade_handoff_frames > 0.0
		var marshal_dark_ready := marshal_active
		if dark_blade_window_frames <= 0.0 or (
			not visibility_query.is_viper_airborne(deps)
			and not bool(context.get("viper_jetpack_airborne", false))
			and not core_flip_dark_ready
			and not marshal_dark_ready
		):
			dark_blade_window = false
			dark_blade_window_frames = 0.0
			core_flip_dark_blade_handoff_frames = 0.0
	if blade_motion_active and blade_motion_phase == 2:
		if blade_dark_mode:
			blade_dark_fire_frames += fps_scale
			if blade_dark_fire_frames >= BLADE_COMBO_DELAY_FRAMES:
				blade_dark_combo_window = true
		else:
			blade_air_fire_frames += fps_scale
			if blade_air_fire_frames >= BLADE_COMBO_DELAY_FRAMES:
				blade_air_combo_window = true
	elif not blade_motion_active:
		_reset_blade_motion_combo_windows()
	if nerve_strike_miss_text_timer > 0.0:
		nerve_strike_miss_text_timer = max(0.0, nerve_strike_miss_text_timer - fps_scale)
	if nerve_strike_slash_vfx_frames > 0.0:
		nerve_strike_slash_vfx_frames = max(0.0, nerve_strike_slash_vfx_frames - fps_scale)
	_update_nerve_strike_clone_slashes(fps_scale, context, deps)
	if dive_hit_text_timer > 0.0:
		dive_hit_text_timer = max(0.0, dive_hit_text_timer - fps_scale)
	particle_drawer.update_dive_particle_array(dive_charge_particles, fps_scale)
	particle_drawer.update_dive_particle_array(dive_particles, fps_scale)
	if core_flip_miss_text_timer > 0.0:
		core_flip_miss_text_timer = max(0.0, core_flip_miss_text_timer - fps_scale)
	var marshal_timer_skill_config: Object = visibility_query.get_viper_skill_config(deps)
	if marshal_ready:
		marshal_ready_frames = max(0.0, marshal_ready_frames - fps_scale)
		if marshal_ready_frames <= 0.0 or not visibility_query.context_has_enough_gauge(context, visibility_query.get_marshal_skill_cost(marshal_timer_skill_config, MARSHAL_KICK, PHANTOM_KICK)):
			_clear_marshal_ready_window()
	if marshal_first_hit_pending:
		marshal_first_hit_delay_frames = max(0.0, marshal_first_hit_delay_frames - fps_scale)
		if marshal_first_hit_delay_frames <= 0.0:
			_clear_marshal_first_hit_pending()
			if (
				marshal_phantom_allowed
				and shadow_was_airborne
				and _has_phantom_kick_chain_skill(marshal_timer_skill_config, deps)
				and visibility_query.context_has_enough_gauge(context, visibility_query.get_marshal_skill_cost(marshal_timer_skill_config, PHANTOM_KICK, PHANTOM_KICK))
				and visibility_query.is_configured_skill_ready(PHANTOM_KICK, deps, -1)
			):
				double_marshal_ready = true
				double_marshal_ready_frames = MARSHAL_KICK_READY_FRAMES
			else:
				_clear_phantom_kick_chain_window()
	if double_marshal_ready:
		double_marshal_ready_frames = max(0.0, double_marshal_ready_frames - fps_scale)
		if double_marshal_ready_frames <= 0.0 or not visibility_query.context_has_enough_gauge(context, visibility_query.get_marshal_skill_cost(marshal_timer_skill_config, PHANTOM_KICK, PHANTOM_KICK)):
			_clear_phantom_kick_chain_window()
	if dmk_freeze_active:
		var dmk_prep_mult: float = skill_scaling.get_marshal_prep_duration_mult(visibility_query.get_runtime_skill_level(deps, "kick_enhance"))
		dmk_freeze_frames = max(0.0, dmk_freeze_frames - fps_scale / max(0.1, dmk_prep_mult))
		if dmk_freeze_frames <= 0.0:
			dmk_freeze_active = false
	if dmk_text_active:
		dmk_text_frames = max(0.0, dmk_text_frames - fps_scale)
		if dmk_text_frames <= 0.0:
			dmk_text_active = false
	if venom_edge_strike_active:
		venom_edge_strike_elapsed_frames += fps_scale
		if venom_edge_strike_elapsed_frames >= VENOM_EDGE_STRIKE_TOTAL_FRAMES:
			venom_edge_strike_active = false
			venom_edge_strike_elapsed_frames = 0.0
	particle_drawer.update_particle_list(marshal_particles, fps_scale, 0.985, 0.0)
	particle_drawer.update_particle_list(phantom_hit_particles, fps_scale, 0.97, 0.04)
	_update_ignition_aura_runtime(fps_scale, context, deps)
	_update_dual_glitch_runtime(fps_scale, context)
	_update_dual_glitch_clone_dive_entries(fps_scale, deps)
	chaos_spear_effect_renderer.update_chaos_absorb_pulses(chaos_absorb_pulses, chaos_target, fps_scale)
	if chaos_cancel_flash_frames > 0.0:
		chaos_cancel_flash_frames = max(0.0, chaos_cancel_flash_frames - fps_scale)
	if chaos_state != "idle" and (visibility_query.should_stop_viper_context_effect(context) or visibility_query.is_round_waiting_for_serve(deps)):
		_reset_chaos_spear_runtime(true, deps)
		return {}
	if chaos_state == "idle":
		return {}
	chaos_phase_frames += fps_scale
	match chaos_state:
		"startup":
			_update_chaos_startup_phase(context, deps)
		"flying":
			_update_chaos_flying_phase(deps)
		"impact":
			_update_chaos_impact_phase(context, deps)
		"blackhole":
			if chaos_phase_frames >= CHAOS_BLACKHOLE_FRAMES:
				_release_chaos_blackhole(false, context, deps)
		"fade":
			if chaos_phase_frames >= CHAOS_FADE_FRAMES:
				audio_router.stop_chaos_blackhole_sound(deps)
				_reset_chaos_spear_runtime(false)
	return {}


func apply_shadow_step_ball_motion(fps_scale: float, scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if not bool(context.get("ball_active", false)):
		return result
	var motion_context: Dictionary = _build_viper_ball_motion_context(scene, context)
	var ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO)

	if shadow_wave_active:
		var wave_motion: Dictionary = ViperSkillGeometry.shadow_step_wave_motion(
			shadow_wave_pos,
			shadow_wave_dir,
			SHADOW_STEP_WAVE_SPEED,
			fps_scale,
			shadow_wave_target_x
		)
		shadow_wave_pos = _get_vector2(wave_motion.get("pos", shadow_wave_pos), shadow_wave_pos)
		shadow_wave_trail.append(shadow_wave_pos)
		while shadow_wave_trail.size() > SHADOW_STEP_WAVE_TRAIL_MAX:
			shadow_wave_trail.pop_front()
		if bool(wave_motion.get("reached_target", false)):
			shadow_wave_active = false
			shadow_wave_trail.clear()
		if shadow_wave_active and not shadow_wave_hit_ball and not shadow_hit_consumed:
			var wave_rect: Rect2 = ViperSkillGeometry.shadow_step_wave_rect(shadow_wave_pos, SHADOW_STEP_WAVE_COLLISION_SIZE)
			if wave_rect.intersects(ViperSkillGeometry.ball_rect(scene, motion_context)):
				shadow_wave_hit_ball = true
				result = _apply_shadow_step_hit(
					shadow_wave_pos,
					SHADOW_STEP_WAVE_GRADIENT_SIZE,
					shadow_hologram_kick_dir,
					"wave",
					scene,
					motion_context,
					deps
				)
		ball_vel = _get_vector2(result.get("ball_vel", ball_vel), ball_vel)

	if result.is_empty() and shadow_hologram_active:
		result = _try_shadow_hologram_hit(scene, motion_context, deps)
		ball_vel = _get_vector2(result.get("ball_vel", ball_vel), ball_vel)

	if shadow_curve_active and ball_vel.length() > 0.0:
		var curve_motion: Dictionary = ViperSkillGeometry.shadow_step_curve_motion(
			ball_vel,
			shadow_curve_timer,
			shadow_curve_total,
			shadow_curve_force,
			shadow_curve_dir,
			fps_scale
		)
		var curved_vel: Vector2 = _get_vector2(curve_motion.get("ball_vel", ball_vel), ball_vel)
		shadow_curve_timer = float(curve_motion.get("timer", 0.0))
		shadow_curve_active = bool(curve_motion.get("active", false))
		if curved_vel != ball_vel:
			result["ball_vel"] = curved_vel
	return result


func apply_blade_rush_ball_motion(fps_scale: float, scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if not (blade_projectile_active or not blade_followup_projectiles.is_empty()):
		return result
	var motion_context: Dictionary = _build_viper_ball_motion_context(scene, context)
	if blade_projectile_active:
		result = _advance_blade_projectile(fps_scale, scene, motion_context, deps)
		if not result.is_empty():
			scene.merge(result, true)
			motion_context.merge(result, true)
	if not blade_followup_projectiles.is_empty():
		var follow_result: Dictionary = _advance_blade_followup_projectiles(fps_scale, scene, motion_context, deps)
		if not follow_result.is_empty():
			result.merge(follow_result, true)
	return result


func apply_chaos_spear_ball_motion(fps_scale: float, scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if chaos_release_pending:
		result["ball_vel"] = chaos_release_velocity
		result["skip_ball_motion_step"] = false
		result["ball_impact_boost"] = 1.0
		chaos_release_pending = false
		chaos_release_velocity = Vector2.ZERO
	if chaos_state != "blackhole":
		return result
	if not bool(context.get("ball_active", false)):
		return result

	var center: Vector2 = chaos_target
	var elapsed_frames: float = max(0.0, chaos_phase_frames)
	var progress: float = clamp(elapsed_frames / max(1.0, CHAOS_BLACKHOLE_FRAMES), 0.0, 1.0)
	var angle: float = chaos_orbit_seed + elapsed_frames * 0.1833
	var radius_ratio: float = 0.42 + 0.28 * (0.5 + 0.5 * sin(elapsed_frames * 0.1515))
	var radius: float = max(36.0, chaos_base_radius * radius_ratio * (1.0 - 0.35 * progress))
	var orbit_pos: Vector2 = Vector2(
		center.x + cos(angle) * radius,
		center.y + sin(angle * 1.35 + chaos_orbit_seed * 0.7) * radius * 0.75
	)
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	if not chaos_blackhole_origin_valid:
		chaos_blackhole_ball_origin = ball_pos
		chaos_blackhole_origin_valid = true
		chaos_prev_ball_center = ball_pos
		chaos_prev_ball_valid = true
	var ingress_t: float = 1.0 - pow(1.0 - clamp(elapsed_frames / max(1.0, CHAOS_INGRESS_FRAMES), 0.0, 1.0), 3.0)
	var new_pos: Vector2 = chaos_blackhole_ball_origin.lerp(orbit_pos, ingress_t)
	var prev_pos: Vector2 = chaos_prev_ball_center if chaos_prev_ball_valid else ball_pos
	result["ball_pos"] = new_pos
	result["ball_vel"] = new_pos - prev_pos
	result["skip_ball_motion_step"] = true
	result["player_collision_cooldown"] = max(6.0, float(scene.get("player_collision_cooldown", 0.0)))
	result["ball_impact_boost"] = 1.0
	chaos_prev_ball_center = new_pos
	chaos_prev_ball_valid = true
	var gold_award: int = 0
	var target_gold_ticks: int = int(floor(elapsed_frames / CHAOS_GOLD_TICK_FRAMES))
	if target_gold_ticks > chaos_gold_ticks_paid:
		gold_award += (target_gold_ticks - chaos_gold_ticks_paid) * CHAOS_GOLD_PER_TICK
		chaos_gold_ticks_paid = target_gold_ticks
	chaos_absorb_poll_frames += fps_scale
	if chaos_absorb_poll_frames >= 5.4:
		chaos_absorb_poll_frames = 0.0
		gold_award += _absorb_chaos_field_objects(center, deps) * CHAOS_OBJECT_GOLD
	if gold_award > 0:
		var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
		if runtime_perk_state != null and runtime_perk_state.has_method("award_gold"):
			result["runtime_perk_gold"] = int(runtime_perk_state.award_gold(gold_award))
	return result


func apply_emp_strike_ball_motion(_fps_scale: float, scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	if not bool(context.get("ball_active", false)):
		return {}
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", context.get("ball_pos", Vector2.ZERO)), Vector2.ZERO)
	if dive_active and dive_phase == 2 and not dive_ball_boosted:
		var primary_vertical_gap: float = dive_shockwave_pos.y - ball_pos.y
		if primary_vertical_gap >= 0.0 and primary_vertical_gap <= DIVE_SHOCKWAVE_HEIGHT:
			dive_ball_boosted = true
			var primary_ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", context.get("ball_vel", Vector2.ZERO)), Vector2.ZERO)
			var primary_next_vel: Vector2 = ViperSkillGeometry.emp_strike_hit_velocity(primary_ball_vel)
			var primary_released_chaos: bool = _release_chaos_blackhole_from_hit_result(deps, context)
			_start_dive_slip_for_height(ball_pos, context, deps, dive_height_snapshot, false)
			dive_hit_text_timer = DIVE_HIT_TEXT_FRAMES
			dive_hit_text_pos = ball_pos
			dive_hit_text_height_ratio = clamp(dive_height_snapshot / DIVE_JETPACK_MAX_HEIGHT, 0.0, 1.0)
			dive_hit_feedback_msec = Time.get_ticks_msec()
			runtime_action_router.trigger_feedback(deps, 0.20, 5.5)
			if not _register_ball_hit_pulse(ball_pos, primary_next_vel, deps, 0.92, "viper_emp_strike"):
				_spawn_fallback_hit_impact(ball_pos, primary_next_vel, deps, Color(0.40, 0.90, 1.0, 1.0), 1.25, 0.86, 1.0)
			var primary_result := {
				"ball_vel": primary_next_vel,
				"ball_impact_boost": max(1.0, float(scene.get("ball_impact_boost", 1.0))),
				"player_collision_cooldown": max(DIVE_PLAYER_COLLISION_COOLDOWN, float(scene.get("player_collision_cooldown", 0.0))),
			}
			primary_result.merge(runtime_action_router.award_skill_gold(deps, 20), true)
			return _mark_result_released_chaos_hit(primary_result, primary_released_chaos)
	if dual_glitch_clone_dive_entries.is_empty():
		return {}
	for index in range(dual_glitch_clone_dive_entries.size()):
		var entry_value: Variant = dual_glitch_clone_dive_entries[index]
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if not bool(entry.get("activated", false)) or bool(entry.get("ball_boosted", false)):
			continue
		var clone_vertical_gap: float = float(entry.get("y", dive_shockwave_pos.y)) - ball_pos.y
		if clone_vertical_gap < 0.0 or clone_vertical_gap > DIVE_SHOCKWAVE_HEIGHT:
			continue
		entry["ball_boosted"] = true
		dual_glitch_clone_dive_entries[index] = entry
		var clone_ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", context.get("ball_vel", Vector2.ZERO)), Vector2.ZERO)
		var clone_next_vel: Vector2 = ViperSkillGeometry.emp_strike_hit_velocity(clone_ball_vel)
		var clone_released_chaos: bool = _release_chaos_blackhole_from_hit_result(deps, context)
		_start_dive_slip_for_height(ball_pos, context, deps, float(entry.get("height_snapshot", dive_height_snapshot)), true)
		runtime_action_router.trigger_feedback(deps, 0.13, 3.6)
		_register_ball_hit_pulse(ball_pos, clone_next_vel, deps, 0.58, "viper_dual_glitch_emp")
		var clone_result: Dictionary = {
			"ball_vel": clone_next_vel,
			"ball_impact_boost": max(1.0, float(scene.get("ball_impact_boost", 1.0))),
			"player_collision_cooldown": max(DIVE_PLAYER_COLLISION_COOLDOWN, float(scene.get("player_collision_cooldown", 0.0))),
			"viper_dual_glitch_clone_emp_hit": true,
		}
		return _mark_result_released_chaos_hit(clone_result, clone_released_chaos)
	return {}


func register_player_ball_contact(deps: Dictionary = {}, _context: Dictionary = {}) -> void:
	var dash_snapshot: Dictionary = visibility_query.get_dash_snapshot(deps.get("dash_state", null))
	_try_open_core_flip_ready_from_contact(dash_snapshot, deps)
	var four_poisons_level: int = visibility_query.get_runtime_skill_level(deps, "four_poisons")
	if dive_active and dive_phase == 0 and four_poisons_level < 3:
		_reset_dive_runtime(false)
	if dual_glitch_state == "startup" and four_poisons_level < 3:
		_reset_dual_glitch_runtime(false)
	if chaos_state == "startup":
		if four_poisons_level < 3:
			_reset_chaos_spear_runtime(false)
	elif chaos_state == "blackhole":
		_release_chaos_blackhole(true, {}, deps)


func release_chaos_blackhole_from_hit(deps: Dictionary = {}, context: Dictionary = {}) -> bool:
	return _release_chaos_blackhole_from_hit_result(deps, context)


func _play_shadow_step_hit_feedback(ball_pos: Vector2, next_vel: Vector2, center_t: float, deps: Dictionary) -> void:
	runtime_action_router.trigger_feedback(
		deps,
		SHADOW_HIT_SHAKE_AMOUNT_BASE + center_t * SHADOW_HIT_SHAKE_AMOUNT_CENTER_BONUS,
		SHADOW_HIT_SHAKE_INTENSITY_BASE + center_t * SHADOW_HIT_SHAKE_INTENSITY_CENTER_BONUS
	)
	if not _register_ball_hit_pulse(
		ball_pos,
		next_vel,
		deps,
		SHADOW_HIT_ENERGY_INTENSITY_BASE + center_t * SHADOW_HIT_ENERGY_INTENSITY_CENTER_BONUS,
		"viper_shadow_step"
	):
		_spawn_fallback_hit_impact(
			ball_pos,
			next_vel,
			deps,
			Color(0.72, 0.0, 1.0, 1.0),
			SHADOW_HIT_PARTICLE_INTENSITY_BASE + center_t * SHADOW_HIT_PARTICLE_INTENSITY_CENTER_BONUS,
			SHADOW_HIT_ENERGY_SCALE_BASE + center_t * SHADOW_HIT_ENERGY_SCALE_CENTER_BONUS,
			SHADOW_HIT_ENERGY_INTENSITY_BASE + center_t * SHADOW_HIT_ENERGY_INTENSITY_CENTER_BONUS
		)


func _finish_shadow_step_hit(
	ball_pos: Vector2,
	next_vel: Vector2,
	center_t: float,
	curve_frames: float,
	curve_force: float,
	safe_dir: int,
	scene: Dictionary,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var released_chaos: bool = _release_chaos_blackhole_from_hit_result(deps, context)
	_set_shadow_curve(curve_frames, curve_force, safe_dir)
	audio_router.play_shadow_kick_sound(deps)
	_play_shadow_step_hit_feedback(ball_pos, next_vel, center_t, deps)
	_mark_kick_skill_knockback_pending(deps)
	shadow_starburst_active = true
	shadow_starburst_pos = ball_pos
	shadow_starburst_frame = 0
	shadow_starburst_timer = 0.0
	shadow_starburst_is_double = false
	var result := {
		"ball_vel": next_vel,
		"ball_impact_boost": max(1.0, float(scene.get("ball_impact_boost", 1.0))),
		"player_collision_cooldown": max(6.0, float(scene.get("player_collision_cooldown", 0.0))),
	}
	var gold_award: int = SHADOW_STEP_HIT_GOLD
	if shadow_was_airborne:
		gold_award = int(float(gold_award) * SHADOW_STEP_AIRBORNE_GOLD_MULT)
	result.merge(runtime_action_router.award_skill_gold(deps, gold_award), true)
	return _mark_result_released_chaos_hit(result, released_chaos)


func _try_open_core_flip_ready_from_contact(dash_snapshot: Dictionary, deps: Dictionary) -> void:
	if bool(dash_snapshot.get("is_half", false)):
		return
	if core_flip_consumed:
		return
	if core_flip_last_dash_start_msec <= CORE_FLIP_DASH_START_VALID_AFTER_MSEC:
		return
	var now_msec: int = Time.get_ticks_msec()
	var dash_active: bool = bool(dash_snapshot.get("active", false))
	var dash_elapsed_msec := now_msec - core_flip_last_dash_start_msec
	if dash_elapsed_msec < 0:
		return
	if not (dash_active or dash_elapsed_msec <= CORE_FLIP_DASH_SUCCESS_WINDOW_MSEC):
		return
	var skill_config: Object = visibility_query.get_viper_skill_config(deps)
	if visibility_query.is_skill_equipped(skill_config, CORE_FLIP):
		core_flip_ready_msec = now_msec
		core_flip_buffered_until_msec = 0


func _reset_core_flip_runtime(clear_window: bool = false) -> void:
	if clear_window:
		core_flip_consumed = true
		core_flip_ready_msec = 0
		core_flip_buffered_until_msec = 0
		core_flip_last_dash_start_msec = CORE_FLIP_DASH_START_UNSET_MSEC
	core_flip_attack_active = false
	core_flip_attack_phase = 0
	core_flip_phase_frames = 0.0
	core_flip_paddle_size = CORE_FLIP_DEFAULT_PADDLE_SIZE
	core_flip_origin_center = Vector2.ZERO
	core_flip_target_center = Vector2.ZERO
	core_flip_apex_center = Vector2.ZERO
	core_flip_visual_pos = Vector2.ZERO
	core_flip_return_start_center = Vector2.ZERO
	core_flip_kick_dir = 1
	core_flip_ball_hit = false
	core_flip_spin_angle_degrees = 0.0
	core_flip_spin_sound_started = false
	core_flip_kick_sound_played = false
	if clear_window:
		core_flip_dark_blade_handoff_frames = 0.0
		core_flip_miss_text_timer = 0.0
		core_flip_miss_text_pos = Vector2.ZERO
	core_flip_web_lines.clear()


func _is_core_flip_ready_window_active(now_msec: int) -> bool:
	if core_flip_ready_msec <= 0 or core_flip_consumed:
		return false
	if (
		core_flip_last_dash_start_msec > CORE_FLIP_DASH_START_VALID_AFTER_MSEC
		and core_flip_ready_msec < core_flip_last_dash_start_msec
	):
		return false
	if now_msec > core_flip_ready_msec + CORE_FLIP_READY_WINDOW_MSEC:
		core_flip_ready_msec = 0
		core_flip_buffered_until_msec = 0
		return false
	return true


func _has_viper_attack_motion_active(include_dive: bool = false) -> bool:
	return (
		(include_dive and dive_active)
		or core_flip_attack_active
		or marshal_active
		or blade_motion_active
		or blade_projectile_active
	)


func _get_skill_cost_with_fallback(skill_config: Object, skill_name: String, fallback_cost: float) -> float:
	var configured_cost: float = visibility_query.get_skill_cost(skill_config, skill_name)
	return configured_cost if configured_cost > 0.0 else fallback_cost


func _get_skill_cooldown_seconds_with_fallback(
	skill_config: Object,
	skill_name: String,
	fallback_seconds: float,
	reject_nonpositive: bool = true
) -> float:
	var cooldown_seconds: float = float(skill_config.get_cooldown_seconds(skill_name)) if skill_config != null and skill_config.has_method("get_cooldown_seconds") else fallback_seconds
	return fallback_seconds if reject_nonpositive and cooldown_seconds <= 0.0 else cooldown_seconds


func _can_activate_configured_skill(
	skill_config: Object,
	special_gauge: float,
	deps: Dictionary,
	skill_name: String,
	now_msec: int = -1
) -> bool:
	return (
		visibility_query.is_skill_equipped(skill_config, skill_name)
		and special_gauge >= visibility_query.get_skill_cost(skill_config, skill_name)
		and visibility_query.is_configured_skill_ready(skill_name, deps, now_msec)
	)


func _has_lateral_skill_input(input_snapshot: Dictionary) -> bool:
	return (
		bool(input_snapshot.get("left_pressed", false))
		or bool(input_snapshot.get("right_pressed", false))
		or abs(float(input_snapshot.get("direction", 0.0))) > 0.01
	)


func _build_core_flip_motion_result(player_pos: Vector2, special_gauge: float, activated: bool, config: Dictionary) -> Dictionary:
	return {
		"handled": true,
		"activated": activated,
		"skill_name": CORE_FLIP,
		"player_pos": player_pos,
		"player_speed": 0.0,
		"special_gauge": special_gauge,
		"player_collision_cooldown": max(6.0, float(config.get("player_collision_cooldown", 0.0))),
	}


func _start_core_flip(
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	now_msec: int
) -> Dictionary:
	var skill_config: Object = visibility_query.get_viper_skill_config(deps)
	var cost: float = visibility_query.get_skill_cost(skill_config, CORE_FLIP)
	cost = cost if cost > 0.0 else 120.0
	var next_gauge: float = max(0.0, special_gauge - cost)
	_trigger_configured_cooldown_and_orb_gauge_spin(CORE_FLIP, skill_config, deps, now_msec)
	_cancel_dash_until_key_release(deps.get("dash_state", null))
	runtime_action_router.trigger_feedback(deps, CORE_FLIP_START_SHAKE_AMOUNT, CORE_FLIP_START_SHAKE_INTENSITY)
	core_flip_consumed = true
	core_flip_ready_msec = 0
	core_flip_buffered_until_msec = 0
	core_flip_attack_active = true
	core_flip_attack_phase = 0
	core_flip_phase_frames = 0.0
	core_flip_paddle_size = ViperSkillGeometry.get_paddle_size(config)
	core_flip_origin_center = player_pos + core_flip_paddle_size * 0.5
	core_flip_target_center = ViperSkillGeometry.get_ball_pos(config)
	var core_flip_start_motion: Dictionary = ViperSkillGeometry.core_flip_start_motion(
		core_flip_origin_center,
		core_flip_target_center,
		CORE_FLIP_APEX_OFFSET_Y
	)
	core_flip_apex_center = _get_vector2(core_flip_start_motion.get("apex_center", core_flip_target_center), core_flip_target_center)
	core_flip_visual_pos = player_pos
	core_flip_return_start_center = core_flip_origin_center
	core_flip_kick_dir = int(core_flip_start_motion.get("kick_dir", core_flip_kick_dir))
	core_flip_ball_hit = false
	core_flip_spin_angle_degrees = 0.0
	core_flip_spin_sound_started = true
	core_flip_kick_sound_played = false
	core_flip_web_lines.clear()
	_clear_marshal_ready_window()
	_clear_double_marshal_ready_window()
	_clear_marshal_first_hit_pending()
	shadow_marshal_delay_frames = 0.0
	audio_router.play_core_flip_spin_sound(deps)
	return _build_core_flip_motion_result(player_pos, next_gauge, true, config)


func _update_core_flip(
	delta: float,
	_player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var fps_scale: float = delta * 60.0
	core_flip_phase_frames += fps_scale
	var next_pos: Vector2 = core_flip_visual_pos
	var result := _build_core_flip_motion_result(core_flip_visual_pos, special_gauge, false, config)
	match core_flip_attack_phase:
		0:
			core_flip_web_lines.clear()
			var t0: float = ViperSkillGeometry.core_flip_phase_progress(core_flip_phase_frames, CORE_FLIP_PHASE0_FRAMES)
			core_flip_spin_angle_degrees = ViperSkillGeometry.core_flip_spin_degrees(0, t0)
			next_pos = ViperSkillGeometry.center_to_player_pos(core_flip_origin_center, config, core_flip_paddle_size)
			if t0 >= 1.0:
				_enter_core_flip_phase(1, deps)
		1:
			next_pos = _update_core_flip_wall_climb_phase(config, deps)
		2:
			next_pos = _update_core_flip_kick_phase(config, deps, result)
		3:
			next_pos = _update_core_flip_return_phase(config, deps)
	core_flip_visual_pos = next_pos
	result["player_pos"] = next_pos
	return result


func _update_core_flip_wall_climb_phase(config: Dictionary, deps: Dictionary) -> Vector2:
	var phase1_cap: float = skill_scaling.get_core_flip_duration_frames(CORE_FLIP_PHASE1_FRAMES, visibility_query.get_runtime_skill_level(deps, "kick_enhance"))
	var t1: float = ViperSkillGeometry.core_flip_phase_progress(core_flip_phase_frames, phase1_cap)
	core_flip_target_center = ViperSkillGeometry.get_ball_pos(config)
	core_flip_spin_angle_degrees = ViperSkillGeometry.core_flip_spin_degrees(1, t1)
	var leg_frames: float = skill_scaling.get_core_flip_duration_frames(CORE_FLIP_ZIGZAG_LEG_FRAMES, visibility_query.get_runtime_skill_level(deps, "kick_enhance"))
	var cling_frames: float = skill_scaling.get_core_flip_duration_frames(CORE_FLIP_ZIGZAG_CLING_FRAMES, visibility_query.get_runtime_skill_level(deps, "kick_enhance"))
	var center1: Vector2 = ViperSkillGeometry.core_flip_wall_climb_center(
		t1,
		config,
		core_flip_paddle_size,
		core_flip_origin_center,
		core_flip_target_center,
		core_flip_kick_dir,
		core_flip_phase_frames,
		leg_frames,
		cling_frames,
		CORE_FLIP_KICK_TRIGGER_Y
	)
	var next_pos: Vector2 = ViperSkillGeometry.center_to_player_pos(center1, config, core_flip_paddle_size)
	var wall_contact: Dictionary = ViperSkillGeometry.core_flip_wall_contact_state(
		center1,
		float(config.get("width", 760.0)),
		core_flip_phase_frames,
		leg_frames,
		cling_frames
	)
	var web_line_to: Vector2 = _get_vector2(wall_contact.get("line_to", center1), center1)
	core_flip_web_lines.clear()
	core_flip_web_lines.append({"from": center1, "to": web_line_to})
	var wall_touch_count: int = int(wall_contact.get("touch_count", 0))
	if ViperSkillGeometry.core_flip_should_enter_kick_phase(wall_touch_count, t1):
		core_flip_apex_center = center1
		core_flip_target_center = ViperSkillGeometry.get_ball_pos(config)
		core_flip_kick_dir = ViperSkillGeometry.core_flip_kick_direction(core_flip_apex_center, core_flip_target_center)
		_enter_core_flip_phase(2, deps)
	return next_pos


func _try_apply_core_flip_kick_hit(kick_center: Vector2, config: Dictionary, deps: Dictionary, result: Dictionary) -> void:
	if core_flip_ball_hit:
		return
	if not ViperSkillGeometry.core_flip_kick_hits_ball(kick_center, ViperSkillGeometry.get_ball_pos(config), CORE_FLIP_HIT_RADIUS):
		return
	core_flip_ball_hit = true
	core_flip_target_center = kick_center
	if not core_flip_kick_sound_played:
		audio_router.play_core_flip_kick_sound(deps)
		core_flip_kick_sound_played = true
	var current_vel: Vector2 = _get_vector2(config.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var current_speed: float = current_vel.length()
	var next_speed: float = skill_scaling.get_core_flip_hit_speed(
		current_speed,
		visibility_query.get_runtime_skill_level(deps, "kick_enhance"),
		CORE_FLIP_SPEED_MULT,
		CORE_FLIP_MIN_SPEED
	)
	var next_vel: Vector2 = ViperSkillGeometry.core_flip_bank_velocity(
		next_speed,
		core_flip_kick_dir,
		config,
		visibility_query.get_runtime_skill_level(deps, "kick_enhance")
	)
	var ball_pos: Vector2 = ViperSkillGeometry.get_ball_pos(config)
	var released_chaos: bool = _release_chaos_blackhole_from_hit_result(deps, config)
	_set_shadow_curve(MARSHAL_KICK_CURVE_FRAMES, MARSHAL_KICK_CURVE_FORCE, 1 if next_vel.x > 0.0 else -1)
	shadow_was_airborne = true
	shadow_marshal_delay_frames = CORE_FLIP_MARSHAL_DELAY_FRAMES
	marshal_phantom_allowed = true
	if visibility_query.is_skill_equipped(visibility_query.get_viper_skill_config(deps), DARK_BLADE):
		_open_dark_blade_start_window()
	else:
		dark_blade_window = false
	shadow_starburst_active = true
	shadow_starburst_pos = ball_pos
	shadow_starburst_frame = 0
	shadow_starburst_timer = 0.0
	shadow_starburst_is_double = false
	runtime_action_router.trigger_feedback(deps, CORE_FLIP_HIT_SHAKE_AMOUNT, CORE_FLIP_HIT_SHAKE_INTENSITY)
	var pulse_registered := _register_ball_hit_pulse(ball_pos, next_vel, deps, CORE_FLIP_HIT_PULSE_INTENSITY, CORE_FLIP_HIT_PULSE_KIND)
	for _i in range(CORE_FLIP_HIT_MOTION_PARTICLE_COUNT):
		_spawn_marshal_motion_particle(
			ball_pos + Vector2(
				randf_range(-CORE_FLIP_HIT_MOTION_PARTICLE_SPREAD, CORE_FLIP_HIT_MOTION_PARTICLE_SPREAD),
				randf_range(-CORE_FLIP_HIT_MOTION_PARTICLE_SPREAD, CORE_FLIP_HIT_MOTION_PARTICLE_SPREAD)
			),
			CORE_FLIP_HIT_MOTION_PARTICLE_KIND,
			CORE_FLIP_HIT_MOTION_PARTICLE_CHANCE,
			randf_range(CORE_FLIP_HIT_MOTION_PARTICLE_LIFE_MIN, CORE_FLIP_HIT_MOTION_PARTICLE_LIFE_MAX)
		)
	if not pulse_registered:
		_spawn_fallback_hit_impact(ball_pos, next_vel, deps, Color(1.0, 0.43, 0.78, 1.0), 1.15, 0.74, 0.92)
	_destroy_marshal_impact_objects(ball_pos, deps)
	_mark_kick_skill_knockback_pending(deps)
	var mythic_item_runtime: Object = visibility_query.get_mythic_item_runtime(deps)
	if mythic_item_runtime != null and mythic_item_runtime.has_method("try_venom_mist_poison_ball"):
		mythic_item_runtime.try_venom_mist_poison_ball(deps)
	var core_flip_hit_result := {
		"ball_vel": next_vel,
		"ball_impact_boost": max(1.0, float(config.get("ball_impact_boost", 1.0))),
		"player_collision_cooldown": max(6.0, float(config.get("player_collision_cooldown", 0.0))),
	}
	core_flip_hit_result.merge(runtime_action_router.award_skill_gold(deps, CORE_FLIP_HIT_GOLD), true)
	result.merge(_mark_result_released_chaos_hit(core_flip_hit_result, released_chaos), true)
	if visibility_query.is_skill_equipped(visibility_query.get_viper_skill_config(deps), DARK_BLADE):
		_open_dark_blade_start_window()


func _update_core_flip_kick_phase(config: Dictionary, deps: Dictionary, result: Dictionary) -> Vector2:
	core_flip_web_lines.clear()
	var p2_duration: float = skill_scaling.get_core_flip_duration_frames(CORE_FLIP_PHASE2_FRAMES, visibility_query.get_runtime_skill_level(deps, "kick_enhance"))
	var t2: float = ViperSkillGeometry.core_flip_phase_progress(core_flip_phase_frames, p2_duration)
	if not core_flip_ball_hit:
		core_flip_target_center = ViperSkillGeometry.get_ball_pos(config)
	var kick_motion: Dictionary = ViperSkillGeometry.core_flip_kick_motion(
		core_flip_apex_center,
		core_flip_target_center,
		t2
	)
	var kick_center: Vector2 = _get_vector2(kick_motion.get("center", core_flip_apex_center), core_flip_apex_center)
	core_flip_kick_dir = int(kick_motion.get("dir", core_flip_kick_dir))
	core_flip_spin_angle_degrees = ViperSkillGeometry.core_flip_spin_degrees(2, t2)
	var next_pos: Vector2 = ViperSkillGeometry.center_to_player_pos(kick_center, config, core_flip_paddle_size)
	_try_apply_core_flip_kick_hit(kick_center, config, deps, result)
	if t2 >= 1.0:
		if not core_flip_ball_hit:
			core_flip_miss_text_timer = CORE_FLIP_MISS_TEXT_FRAMES
			core_flip_miss_text_pos = ViperSkillGeometry.core_flip_miss_text_pos(
				core_flip_origin_center,
				CORE_FLIP_APEX_OFFSET_Y
			)
		core_flip_return_start_center = kick_center
		_enter_core_flip_phase(3, deps)
	return next_pos


func _update_core_flip_return_phase(config: Dictionary, deps: Dictionary) -> Vector2:
	core_flip_web_lines.clear()
	var t3: float = ViperSkillGeometry.core_flip_phase_progress(core_flip_phase_frames, CORE_FLIP_PHASE3_FRAMES)
	var return_motion: Dictionary = ViperSkillGeometry.core_flip_return_motion(
		core_flip_return_start_center,
		core_flip_origin_center,
		t3
	)
	core_flip_spin_angle_degrees = float(return_motion.get("spin_degrees", core_flip_spin_angle_degrees))
	var return_center: Vector2 = _get_vector2(return_motion.get("center", core_flip_origin_center), core_flip_origin_center)
	var next_pos: Vector2 = ViperSkillGeometry.center_to_player_pos(return_center, config, core_flip_paddle_size)
	if t3 >= 1.0:
		next_pos = ViperSkillGeometry.center_to_player_pos(core_flip_origin_center, config, core_flip_paddle_size)
		if dark_blade_window and visibility_query.is_skill_equipped(visibility_query.get_viper_skill_config(deps), DARK_BLADE):
			core_flip_dark_blade_handoff_frames = CORE_FLIP_DARK_BLADE_HANDOFF_FRAMES
		else:
			core_flip_dark_blade_handoff_frames = 0.0
		_reset_core_flip_runtime(false)
	return next_pos


func _enter_core_flip_phase(next_phase: int, deps: Dictionary) -> void:
	core_flip_attack_phase = next_phase
	core_flip_phase_frames = 0.0
	if next_phase == 1:
		audio_router.play_marshal_backstep_sound(deps)


func consume_phantom_kick_knockback(ball_pos: Vector2, boss_pos: Vector2, boss_width: float, deps: Dictionary = {}) -> Dictionary:
	phantom_kick_speed_limit_disabled = false
	if not phantom_kick_knockback_pending:
		return {}
	phantom_kick_knockback_pending = false
	if _is_stage2_speed_defense_boss_immune({}, deps):
		return {}
	var knockback_vel: float = ViperSkillGeometry.phantom_kick_knockback_velocity(
		ball_pos,
		boss_pos,
		boss_width,
		PHANTOM_KICK_KNOCKBACK_DISTANCE
	)
	var ai_state: Object = deps.get("ai_state", null)
	if ai_state != null and ai_state.has_method("start_paddle_hit_knockback"):
		ai_state.start_paddle_hit_knockback(knockback_vel, PHANTOM_KICK_KNOCKBACK_FRAMES, PHANTOM_KICK_KNOCKBACK_DECAY, true)
	return {"boss_vel": knockback_vel}


func consume_kick_skill_knockback(ball_pos: Vector2, boss_pos: Vector2, boss_width: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	var bonus_pct: int = max(0, kick_skill_knockback_pending_pct)
	kick_skill_knockback_pending_pct = 0
	if bonus_pct <= 0:
		return {}
	if _is_stage2_speed_defense_boss_immune(context, deps):
		return {"viper_knockback_overlay_active": false}
	var knockback_vel: float = ViperSkillGeometry.kick_guard_knockback_velocity(
		boss_pos,
		boss_width,
		context,
		bonus_pct,
		KICK_GUARD_KNOCKBACK_FIRE_BASE,
		KICK_GUARD_DISTANCE_MULTIPLIER
	)
	if abs(knockback_vel) <= 0.01:
		return {"viper_knockback_overlay_active": false}
	runtime_action_router.trigger_feedback(deps, 0.10, 4.0)
	audio_router.play_kick_guard_knockback_sound(deps)
	var intensity: float = clamp(float(bonus_pct) / 150.0, 0.7, 1.4)
	_spawn_fallback_hit_impact(
		ball_pos,
		Vector2(0.0, 22.0),
		deps,
		Color(1.0, 0.23, 0.08, 1.0),
		1.15 * intensity,
		0.72 * intensity,
		0.92
	)
	var ai_state: Object = deps.get("ai_state", null)
	if ai_state != null and ai_state.has_method("start_paddle_hit_knockback"):
		ai_state.start_paddle_hit_knockback(knockback_vel, KICK_GUARD_KNOCKBACK_FRAMES, KICK_GUARD_KNOCKBACK_DECAY, true)
	return {
		"boss_vel": knockback_vel,
		"viper_knockback_overlay_active": false,
		"kick_skill_knockback_consumed": true,
	}


func _is_stage2_speed_defense_boss_immune(context: Dictionary = {}, deps: Dictionary = {}) -> bool:
	return visibility_query.is_stage2_speed_defense_boss_immune(context, deps)


func apply_shadow_step_paddle_hit(ball_vel: Vector2, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if not shadow_kick_ready or shadow_hit_consumed:
		return {}
	if shadow_step_activation_msec > SHADOW_STEP_ACTIVATION_VALID_AFTER_MSEC:
		var elapsed_msec: int = Time.get_ticks_msec() - shadow_step_activation_msec
		if elapsed_msec > SHADOW_STEP_PADDLE_HIT_WINDOW_MSEC:
			_clear_shadow_kick_ready()
			return {}
	var player_pos: Vector2 = _get_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(context.get("player_paddle_size", ViperSkillGeometry.get_paddle_size(context)), ViperSkillGeometry.get_paddle_size(context))
	var hit_center: Vector2 = player_pos + player_size * 0.5
	var hit_size: Vector2 = Vector2(
		player_size.x + SHADOW_STEP_PADDLE_HIT_PADDING,
		player_size.y + SHADOW_STEP_PADDLE_HIT_PADDING
	)
	var scene: Dictionary = {
		"ball_pos": ViperSkillGeometry.get_ball_pos(context),
		"ball_vel": ball_vel,
		"ball_impact_boost": float(context.get("ball_impact_boost", 1.0)),
	}
	var result: Dictionary = _apply_shadow_step_hit(
		hit_center,
		hit_size,
		shadow_hologram_kick_dir,
		SHADOW_STEP_PADDLE_HIT_SOURCE,
		scene,
		context,
		deps
	)
	if not result.is_empty():
		result["hit"] = true
		result["suppress_base_gauge"] = true
	return result


func _clear_shadow_kick_ready() -> void:
	shadow_kick_ready = false
	shadow_kick_ready_frames = 0.0


func draw(
	canvas: CanvasItem,
	shake_offset: Vector2 = Vector2.ZERO,
	node_fx_layout: Dictionary = {},
	timer_stack: Object = null,
	perf_logger: Object = null,
	effect_lod_scale: float = 1.0
) -> void:
	if canvas == null or not has_visible_effects():
		fx_host_controller.hide_fx_host(chaos_fx_host)
		fx_host_controller.hide_fx_host(emp_fx_host)
		return
	var clamped_lod_scale: float = max(0.1, effect_lod_scale)
	var sample_start: int = _perf_begin(perf_logger)
	var emp_fx_synced: bool = fx_host_controller.sync_emp_strike_fx(
		self,
		canvas,
		shake_offset,
		node_fx_layout,
		visibility_query,
		particle_drawer,
		DIVE_SHOCKWAVE_FRAMES,
		DIVE_JETPACK_MAX_HEIGHT,
		DIVE_HIT_TEXT_FRAMES
	)
	if not emp_fx_synced:
		particle_drawer.draw_dive_effects(
			canvas,
			shake_offset,
			self,
			floating_text_renderer,
			DIVE_SHOCKWAVE_FRAMES,
			DUAL_GLITCH_DIVE_TELEGRAPH_FRAMES,
			DIVE_HIT_TEXT_FRAMES,
			DIVE_HIT_TEXT_FLOAT_Y,
			clamped_lod_scale
		)
	_perf_end(perf_logger, "viper.skill.emp_dive", sample_start)

	sample_start = _perf_begin(perf_logger)
	var ignition_aura_ratio: float = visibility_query.get_ignition_aura_ratio(self)
	particle_drawer.draw_ignition_aura_effects(
		canvas,
		shake_offset,
		self,
		ignition_aura_ratio,
		IGNITION_AURA_EFFECT_SHEET_PATH,
		IGNITION_AURA_EFFECT_SHEET_COLS,
		IGNITION_AURA_EFFECT_SHEET_ROWS,
		IGNITION_AURA_EFFECT_FRAME_INTERVAL_MSEC,
		clamped_lod_scale
	)
	timer_gauge_renderer.draw_ignition_aura_runtime_timer_gauge(
		canvas,
		timer_stack,
		self,
		IGNITION_TIMER_BAR_SIZE,
		IGNITION_TIMER_BAR_MARGIN,
		IGNITION_TIMER_STACK_SPACING,
		IGNITION_TIMER_STACK_KEY
	)
	_perf_end(perf_logger, "viper.skill.ignition_aura", sample_start)

	sample_start = _perf_begin(perf_logger)
	dual_glitch_effect_renderer.draw_dual_glitch_runtime_effects(
		canvas,
		shake_offset,
		self,
		_get_dual_glitch_clone_rect_entries(false, true),
		DUAL_GLITCH_STARTUP_FRAMES,
		DUAL_GLITCH_SPAWN_FRAMES,
		DUAL_GLITCH_FADE_FRAMES,
		DUAL_GLITCH_EVAPORATION_FRAMES,
		DUAL_GLITCH_OFFSET_PADDING,
		DUAL_GLITCH_ALPHA,
		DUAL_GLITCH_WIGGLE_AMPLITUDE
	)
	timer_gauge_renderer.draw_dual_glitch_runtime_timer_gauge(
		canvas,
		timer_stack,
		self,
		DUAL_GLITCH_TIMER_BAR_SIZE,
		DUAL_GLITCH_TIMER_BAR_MARGIN,
		DUAL_GLITCH_TIMER_STACK_SPACING,
		DUAL_GLITCH_TIMER_STACK_KEY
	)
	_perf_end(perf_logger, "viper.skill.dual_glitch", sample_start)

	sample_start = _perf_begin(perf_logger)
	blade_effect_renderer.draw_blade_effects(
		canvas,
		shake_offset,
		self,
		blade_effect_renderer.get_draw_constants(
			BLADE_BASE_WIDTH,
			BLADE_HITBOX_HEIGHT,
			BLADE_DARK_HITBOX_HEIGHT,
			BLADE_FADEOUT_FRAMES,
			BLADE_REST_FRAMES,
			BLADE_DARK_REST_FRAMES
		)
	)
	_perf_end(perf_logger, "viper.skill.blade", sample_start)

	sample_start = _perf_begin(perf_logger)
	particle_drawer.draw_nerve_strike_runtime_effects(
		canvas,
		shake_offset,
		self,
		NERVE_STRIKE_DASH_FRAMES,
		NERVE_STRIKE_RETURN_HIT_FRAMES,
		NERVE_STRIKE_RETURN_MISS_FRAMES,
		NERVE_STRIKE_SLASH_VFX_FRAMES,
		DUAL_GLITCH_NERVE_STAGGER_FRAMES,
		DUAL_GLITCH_NERVE_SLASH_FRAMES
	)
	floating_text_renderer.draw_nerve_strike_miss_text(
		canvas,
		nerve_strike_miss_text_timer,
		nerve_strike_miss_text_pos,
		shake_offset,
		NERVE_STRIKE_MISS_TEXT_FRAMES,
		NERVE_STRIKE_MISS_TEXT_FLOAT_Y
	)
	_perf_end(perf_logger, "viper.skill.nerve_strike", sample_start)

	sample_start = _perf_begin(perf_logger)
	kick_effect_renderer.draw_core_flip_effects(
		canvas,
		shake_offset,
		self,
		CORE_FLIP_PHASE0_FRAMES,
		CORE_FLIP_PHASE2_FRAMES
	)
	floating_text_renderer.draw_core_flip_miss_text(
		canvas,
		core_flip_miss_text_timer,
		core_flip_miss_text_pos,
		shake_offset,
		CORE_FLIP_MISS_TEXT_FRAMES,
		CORE_FLIP_MISS_TEXT_FLOAT_Y
	)
	_perf_end(perf_logger, "viper.skill.core_flip", sample_start)

	sample_start = _perf_begin(perf_logger)
	kick_effect_renderer.draw_marshal_effect_stack(
		canvas,
		shake_offset,
		self,
		particle_drawer,
		VIPER_HIT_PARTICLE_GLOW_SIZE_THRESHOLD,
		MARSHAL_KICK_DMK_FREEZE_FRAMES,
		MARSHAL_KICK_DMK_TEXT_FRAMES,
		clamped_lod_scale
	)
	_perf_end(perf_logger, "viper.skill.marshal", sample_start)

	sample_start = _perf_begin(perf_logger)
	shadow_effect_renderer.draw_shadow_step_wave(canvas, shake_offset, self)
	var shadow_draw_constants: Dictionary = shadow_effect_renderer.get_draw_constants(
		SHADOW_STEP_HOLOGRAM_FRAMES,
		VIPER_HOLOGRAM_BASE_VISUAL_SIZE,
		VIPER_HOLOGRAM_BASE_PADDLE_WIDTH,
		VIPER_HOLOGRAM_FEET_OFFSET,
		SHADOW_STEP_STARBURST_FRAMES
	)
	shadow_effect_renderer.draw_shadow_step_hologram(canvas, shake_offset, self, shadow_draw_constants)
	shadow_effect_renderer.draw_shadow_starburst(canvas, shake_offset, self, shadow_draw_constants)
	_perf_end(perf_logger, "viper.skill.shadow_step", sample_start)

	sample_start = _perf_begin(perf_logger)
	var absorb_center: Vector2 = chaos_target + shake_offset
	chaos_spear_effect_renderer.draw_chaos_absorb_pulses(canvas, absorb_center, chaos_absorb_pulses, shake_offset)
	var chaos_fx_synced := false
	if chaos_state != "idle":
		chaos_fx_synced = fx_host_controller.sync_chaos_spear_fx(
			self,
			canvas,
			shake_offset,
			node_fx_layout,
			chaos_spear_effect_renderer,
			CHAOS_STARTUP_FRAMES,
			CHAOS_TRAVEL_FRAMES,
			CHAOS_IMPACT_FRAMES,
			CHAOS_BLACKHOLE_FRAMES,
			CHAOS_FADE_FRAMES,
			CHAOS_FX_DISK_HEIGHT
		)
	chaos_spear_effect_renderer.draw_chaos_fallback_effects(
		canvas,
		shake_offset,
		self,
		chaos_fx_synced,
		CHAOS_STARTUP_FRAMES,
		CHAOS_IMPACT_FRAMES,
		CHAOS_FADE_FRAMES,
		CHAOS_VISUAL_LENGTH
	)
	if not chaos_fx_synced:
		fx_host_controller.hide_fx_host(chaos_fx_host)
	chaos_spear_effect_renderer.draw_chaos_cancel_flash(canvas, chaos_cancel_flash_frames)
	_perf_end(perf_logger, "viper.skill.chaos_spear", sample_start)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


# Public trigger for Venom Edge eye-slash strike. The Venom Edge runtime calls
# this on successful activation; the strike sheet plays at the boss's position
# (drawn before the boss so the boss covers the lower
# half of viper from the player's view).
func trigger_venom_edge_strike() -> void:
	venom_edge_strike_active = true
	venom_edge_strike_elapsed_frames = 0.0


# Stationary state for the post-arrival, pre-strike pause behind the boss.
# Held indefinitely until the Venom Edge runtime calls
# end_venom_edge_stationary() (or trigger_venom_edge_strike(), which the
# renderer treats as overriding stationary). Renders Cell 1 of the strike
# sheet (front-facing arrival pose with face visible) at the boss position.
func start_venom_edge_stationary() -> void:
	venom_edge_stationary_active = true


func end_venom_edge_stationary() -> void:
	venom_edge_stationary_active = false


func _has_phantom_kick_chain_skill(skill_config: Object, deps: Dictionary) -> bool:
	return (
		visibility_query.get_runtime_skill_level(deps, DOUBLE_MARSHAL_KICK) > 0
		and visibility_query.is_skill_equipped(skill_config, PHANTOM_KICK)
	)


func _clear_phantom_kick_chain_window() -> void:
	marshal_phantom_allowed = false
	_clear_double_marshal_ready_window()
	_clear_marshal_first_hit_pending()


func _record_viper_command_inputs(input_snapshot: Dictionary, now_msec: int, skill_config: Object, deps: Dictionary) -> void:
	var left_pressed: bool = bool(input_snapshot.get("left_pressed", false))
	var up_pressed: bool = bool(input_snapshot.get("up_pressed", false))
	var right_pressed: bool = bool(input_snapshot.get("right_pressed", false))
	var left_edge: bool = left_pressed and not previous_left_pressed
	var up_edge: bool = up_pressed and not previous_up_pressed
	var right_edge: bool = right_pressed and not previous_right_pressed
	var can_record: bool = chaos_state == "idle" and visibility_query.is_skill_equipped(skill_config, CHAOS_SPEAR)
	_record_dual_glitch_command(left_edge, right_edge, up_edge, now_msec, skill_config, deps)
	if left_edge:
		core_flip_left_press_frame = input_sequence_frame
	if right_edge:
		core_flip_right_press_frame = input_sequence_frame
	if can_record:
		if left_edge:
			_push_chaos_command("a", now_msec)
		if up_edge:
			_push_chaos_command("w", now_msec)
		if right_edge:
			_push_chaos_command("d", now_msec)
	previous_left_pressed = left_pressed
	previous_up_pressed = up_pressed
	previous_right_pressed = right_pressed


func _record_dual_glitch_command(
	left_edge: bool,
	right_edge: bool,
	up_edge: bool,
	now_msec: int,
	skill_config: Object,
	deps: Dictionary
) -> void:
	if up_edge:
		_clear_dual_glitch_command_buffer()
	if (
		dual_glitch_state != "idle"
		or not visibility_query.is_skill_equipped(skill_config, DUAL_GLITCH)
		or not visibility_query.is_configured_skill_ready(DUAL_GLITCH, deps, -1)
		or _is_core_flip_ready_window_active(now_msec)
	):
		_clear_dual_glitch_command_buffer()
		return
	if not dual_glitch_cmd_buffer.is_empty():
		var first: Dictionary = dual_glitch_cmd_buffer[0]
		if now_msec - int(first.get("time", 0)) > DUAL_GLITCH_CMD_WINDOW_MSEC:
			_clear_dual_glitch_command_buffer()
	if left_edge:
		_push_dual_glitch_command("a", now_msec)
	if right_edge:
		_push_dual_glitch_command("d", now_msec)


func _push_dual_glitch_command(key_char: String, now_msec: int) -> void:
	if not dual_glitch_cmd_buffer.is_empty():
		var first: Dictionary = dual_glitch_cmd_buffer[0]
		if now_msec - int(first.get("time", 0)) > DUAL_GLITCH_CMD_WINDOW_MSEC:
			_clear_dual_glitch_command_buffer()
	var progress: int = dual_glitch_cmd_buffer.size()
	var expected_key := "a" if progress == 0 or progress == 2 or progress >= 4 else "d"
	var entry := {"key": key_char, "time": now_msec}
	if key_char == expected_key:
		if progress == 0:
			dual_glitch_cmd_buffer = [entry]
		else:
			dual_glitch_cmd_buffer.append(entry)
		return
	if key_char == "a":
		dual_glitch_cmd_buffer = [entry]
	else:
		dual_glitch_cmd_buffer = []


func _check_dual_glitch_command(now_msec: int) -> bool:
	if not dual_glitch_cmd_buffer.is_empty():
		var first: Dictionary = dual_glitch_cmd_buffer[0]
		if now_msec - int(first.get("time", 0)) > DUAL_GLITCH_CMD_WINDOW_MSEC:
			_clear_dual_glitch_command_buffer()
	if dual_glitch_cmd_buffer.size() < 4:
		return false
	var first_entry: Dictionary = dual_glitch_cmd_buffer[0]
	var second_entry: Dictionary = dual_glitch_cmd_buffer[1]
	var third_entry: Dictionary = dual_glitch_cmd_buffer[2]
	var fourth_entry: Dictionary = dual_glitch_cmd_buffer[3]
	if (
		str(first_entry.get("key", "")) != "a"
		or str(second_entry.get("key", "")) != "d"
		or str(third_entry.get("key", "")) != "a"
		or str(fourth_entry.get("key", "")) != "d"
	):
		return false
	_clear_dual_glitch_command_buffer()
	return true


func _clear_dual_glitch_command_buffer() -> void:
	dual_glitch_cmd_buffer.clear()


func _push_chaos_command(key_char: String, now_msec: int) -> void:
	chaos_cmd_buffer.append({"key": key_char, "time": now_msec})
	while chaos_cmd_buffer.size() > CHAOS_CMD_BUFFER_MAX:
		chaos_cmd_buffer.pop_front()


func _check_chaos_command(now_msec: int) -> bool:
	if chaos_cmd_buffer.size() < 3:
		return false
	var first: Dictionary = chaos_cmd_buffer[chaos_cmd_buffer.size() - 3]
	var second: Dictionary = chaos_cmd_buffer[chaos_cmd_buffer.size() - 2]
	var third: Dictionary = chaos_cmd_buffer[chaos_cmd_buffer.size() - 1]
	if str(first.get("key", "")) != "a" or str(second.get("key", "")) != "w" or str(third.get("key", "")) != "d":
		return false
	var first_time: int = int(first.get("time", 0))
	var second_time: int = int(second.get("time", 0))
	var third_time: int = int(third.get("time", 0))
	if second_time - first_time > CHAOS_CMD_WINDOW_MSEC:
		return false
	if third_time - second_time > CHAOS_CMD_WINDOW_MSEC:
		return false
	if now_msec - third_time > CHAOS_CMD_WINDOW_MSEC:
		return false
	_clear_chaos_spear_command_buffer()
	return true


func _clear_chaos_spear_command_buffer() -> void:
	chaos_cmd_buffer.clear()


func _start_dual_glitch(
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	now_msec: int
) -> Dictionary:
	var skill_config: Object = visibility_query.get_viper_skill_config(deps)
	var cost: float = visibility_query.get_skill_cost(skill_config, DUAL_GLITCH)
	var next_gauge: float = max(0.0, special_gauge - cost)
	dual_glitch_state = "startup"
	dual_glitch_phase_frames = 0.0
	var duration_pct: float = float(_get_four_poisons_scaled_pct(
		deps,
		FOUR_POISONS_DUAL_GLITCH_DURATION_PCT_BY_LEVEL,
		FOUR_POISONS_DUAL_GLITCH_DURATION_PCT_CAP,
		FOUR_POISONS_DUAL_GLITCH_DURATION_PCT_PER_EXTRA_LEVEL
	))
	dual_glitch_active_total_frames = max(1.0, DUAL_GLITCH_ACTIVE_FRAMES * (1.0 + duration_pct / 100.0))
	dual_glitch_locked_player_x = player_pos.x
	dual_glitch_locked_player_x_valid = true
	dual_glitch_base_pos = player_pos
	dual_glitch_paddle_size = ViperSkillGeometry.get_paddle_size(config)
	dual_glitch_fade_reason = ""
	dual_glitch_start_msec = now_msec
	_clear_dual_glitch_command_buffer()
	dual_glitch_clones.clear()
	var clone_hp: int = skill_scaling.get_dual_glitch_clone_hp(
		visibility_query.get_runtime_skill_level(deps, "four_poisons"),
		FOUR_POISONS_DUAL_GLITCH_CLONE_HP_BY_LEVEL,
		FOUR_POISONS_DUAL_GLITCH_CLONE_HP_CAP
	)
	for side in [-1, 1]:
		dual_glitch_clones.append({
			"side": side,
			"hp": clone_hp,
			"max_hp": clone_hp,
			"collision_enabled": true,
			"evaporation_frames": -1.0,
		})
	var cooldown_seconds: float = _get_skill_cooldown_seconds_with_fallback(skill_config, DUAL_GLITCH, 45.0)
	cooldown_seconds = _get_four_poisons_additive_cooldown_seconds(DUAL_GLITCH, skill_config, deps, cooldown_seconds)
	_trigger_runtime_cooldown_and_orb_gauge_spin(
		DUAL_GLITCH,
		now_msec,
		skill_config,
		deps,
		cooldown_seconds
	)
	runtime_action_router.trigger_feedback(deps, 0.09, 3.2)
	return {
		"handled": true,
		"activated": true,
		"skill_name": DUAL_GLITCH,
		"player_pos": Vector2(dual_glitch_locked_player_x, player_pos.y),
		"player_speed": 0.0,
		"special_gauge": next_gauge,
		"locked_player_x": dual_glitch_locked_player_x,
	}


func _can_start_chaos_spear(
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	now_msec: int
) -> bool:
	if chaos_state != "idle":
		return false
	if visibility_query.is_control_locked(deps):
		return false
	if not bool(config.get("ball_active", false)):
		return false
	var jetpack_state: Object = deps.get("viper_jetpack_state", null)
	if jetpack_state != null and jetpack_state.has_method("is_airborne") and bool(jetpack_state.is_airborne(2.0)):
		return false
	if visibility_query.is_round_waiting_for_serve(deps):
		return false
	var skill_config: Object = visibility_query.get_viper_skill_config(deps)
	return _can_activate_configured_skill(skill_config, special_gauge, deps, CHAOS_SPEAR, now_msec)


func _start_chaos_spear(
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	now_msec: int
) -> Dictionary:
	var skill_config: Object = visibility_query.get_viper_skill_config(deps)
	var cost: float = visibility_query.get_skill_cost(skill_config, CHAOS_SPEAR)
	var player_center: Vector2 = ViperSkillGeometry.player_center(player_pos, config)
	var ball_pos: Vector2 = ViperSkillGeometry.get_ball_pos(config)
	chaos_target = Vector2(
		float(config.get("width", 760.0)) * 0.5,
		float(config.get("height", 750.0)) * 0.5 + 60.0
	)
	chaos_origin = Vector2(player_center.x, player_pos.y - 6.0)
	chaos_current = chaos_origin
	chaos_phase_frames = 0.0
	chaos_prev_ball_valid = false
	chaos_blackhole_origin_valid = false
	chaos_base_radius = clamp(ball_pos.distance_to(chaos_target), 84.0, 264.0)
	chaos_orbit_seed = randf_range(0.0, TAU)
	chaos_flight_angle = (chaos_target - chaos_origin).angle()
	chaos_impact_seed = randf_range(0.0, TAU)
	chaos_locked_player_x = player_pos.x
	chaos_locked_player_x_valid = true
	chaos_absorb_poll_frames = 0.0
	chaos_gold_ticks_paid = 0
	chaos_explosion_shaken = false
	chaos_release_pending = false
	chaos_release_velocity = Vector2.ZERO
	chaos_state = "startup"
	var next_gauge: float = max(0.0, special_gauge - cost)
	_trigger_configured_cooldown_and_orb_gauge_spin(CHAOS_SPEAR, skill_config, deps, now_msec)
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(0.08, 3.5)
	audio_router.play_chaos_windup_sound(deps)
	return {
		"handled": true,
		"activated": true,
		"skill_name": CHAOS_SPEAR,
		"player_pos": Vector2(chaos_locked_player_x, player_pos.y),
		"player_speed": 0.0,
		"special_gauge": next_gauge,
		"allow_jetpack_overlay": true,
		"locked_player_x": chaos_locked_player_x,
	}


func _update_chaos_startup_phase(context: Dictionary, deps: Dictionary) -> void:
	var player_pos: Vector2 = _get_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	chaos_current = Vector2(player_pos.x + player_size.x * 0.5, player_pos.y - 6.0)
	var prep_reduction_pct: float = float(_get_four_poisons_prep_reduction_pct(deps))
	var frame_scale: float = max(0.0, 1.0 - prep_reduction_pct / 100.0)
	var chaos_startup_frames: float = max(1.0, CHAOS_STARTUP_FRAMES * frame_scale)
	if chaos_phase_frames >= chaos_startup_frames:
		audio_router.stop_chaos_windup_sound(deps)
		chaos_state = "flying"
		chaos_phase_frames = 0.0
		chaos_origin = chaos_current
		chaos_flight_angle = (chaos_target - chaos_origin).angle()
		chaos_locked_player_x_valid = false
		audio_router.play_chaos_flying_sound(deps)


func _update_chaos_flying_phase(deps: Dictionary) -> void:
	var center: Vector2 = chaos_target
	var travel_frames: float = max(1.0, CHAOS_TRAVEL_FRAMES)
	var travel_t: float = clamp(chaos_phase_frames / travel_frames, 0.0, 1.0)
	var inverse_t: float = 1.0 - travel_t
	var ease_t: float = 1.0 - pow(inverse_t, 3.0)
	chaos_current = chaos_origin.lerp(center, ease_t)
	if travel_t >= 1.0:
		audio_router.stop_chaos_flying_sound(deps)
		chaos_state = "impact"
		chaos_phase_frames = 0.0
		chaos_current = chaos_target
		chaos_impact_seed = randf_range(0.0, TAU)
		chaos_explosion_shaken = false
		runtime_action_router.trigger_feedback(deps, 0.23, 5.5)
		audio_router.play_chaos_impact_sound(deps)
		audio_router.play_chaos_blackhole_sound(deps)


func _update_chaos_impact_phase(context: Dictionary, deps: Dictionary) -> void:
	if chaos_phase_frames >= CHAOS_IMPACT_FRAMES * 0.45 and not chaos_explosion_shaken:
		chaos_explosion_shaken = true
		runtime_action_router.trigger_feedback(deps, 0.40, 8.0)
	if chaos_phase_frames >= CHAOS_IMPACT_FRAMES:
		chaos_state = "blackhole"
		chaos_phase_frames = 0.0
		chaos_current = chaos_target
		var ball_pos: Vector2 = _get_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
		chaos_prev_ball_center = ball_pos
		chaos_prev_ball_valid = true
		chaos_blackhole_ball_origin = chaos_prev_ball_center
		chaos_blackhole_origin_valid = true
		chaos_absorb_poll_frames = 0.0
		chaos_gold_ticks_paid = 0
		chaos_fx_spawn_msec_seed = Time.get_ticks_msec()


func _release_chaos_blackhole(early_hit: bool, context: Dictionary, deps: Dictionary) -> void:
	if chaos_state != "blackhole":
		return
	if early_hit:
		chaos_release_pending = false
		chaos_release_velocity = Vector2.ZERO
	else:
		var current_vel: Vector2 = _get_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
		var release_speed: float = max(max(16.0, 8.0 * 2.0), current_vel.length() * 1.6)
		var release_angle: float = randf_range(0.0, TAU)
		chaos_release_velocity = Vector2(cos(release_angle), sin(release_angle)) * release_speed
		chaos_release_pending = true
	chaos_prev_ball_valid = false
	chaos_blackhole_origin_valid = false
	chaos_state = "fade"
	chaos_phase_frames = 0.0
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
	dual_glitch_state = "idle"
	dual_glitch_phase_frames = 0.0
	dual_glitch_active_total_frames = DUAL_GLITCH_ACTIVE_FRAMES
	dual_glitch_locked_player_x = 0.0
	dual_glitch_locked_player_x_valid = false
	dual_glitch_base_pos = Vector2.ZERO
	dual_glitch_paddle_size = Vector2(155.0, 50.0)
	dual_glitch_clones.clear()
	dual_glitch_clone_dive_entries.clear()
	dual_glitch_fade_reason = ""
	dual_glitch_start_msec = 0
	if clear_command:
		_clear_dual_glitch_command_buffer()


func _reset_chaos_spear_runtime(clear_command: bool = false, deps: Dictionary = {}) -> void:
	audio_router.stop_all_chaos_spear_sounds(deps)
	chaos_state = "idle"
	chaos_phase_frames = 0.0
	chaos_origin = Vector2.ZERO
	chaos_target = Vector2.ZERO
	chaos_current = Vector2.ZERO
	chaos_prev_ball_center = Vector2.ZERO
	chaos_prev_ball_valid = false
	chaos_blackhole_ball_origin = Vector2.ZERO
	chaos_blackhole_origin_valid = false
	chaos_base_radius = 52.0
	chaos_orbit_seed = 0.0
	chaos_flight_angle = 0.0
	chaos_impact_seed = 0.0
	chaos_locked_player_x = 0.0
	chaos_locked_player_x_valid = false
	chaos_absorb_pulses.clear()
	chaos_cancel_flash_frames = 0.0
	chaos_absorb_poll_frames = 0.0
	chaos_gold_ticks_paid = 0
	chaos_explosion_shaken = false
	chaos_release_pending = false
	chaos_release_velocity = Vector2.ZERO
	if clear_command:
		_clear_chaos_spear_command_buffer()
	fx_host_controller.hide_fx_host(chaos_fx_host)


func _get_four_poisons_prep_reduction_pct(deps: Dictionary) -> int:
	return skill_scaling.get_four_poisons_prep_reduction_pct(
		visibility_query.get_runtime_skill_level(deps, "four_poisons"),
		FOUR_POISONS_PREP_REDUCTION_PCT_BY_LEVEL,
		FOUR_POISONS_PREP_REDUCTION_PCT_CAP,
		FOUR_POISONS_PREP_REDUCTION_PCT_PER_EXTRA_LEVEL
	)


func _get_four_poisons_scaled_pct(deps: Dictionary, values: Array, cap: int, per_extra_level: int) -> int:
	return skill_scaling.get_four_poisons_scaled_pct(visibility_query.get_runtime_skill_level(deps, "four_poisons"), values, cap, per_extra_level)


func _is_dual_glitch_clone_replication_active(deps: Dictionary) -> bool:
	return dual_glitch_state == "active" and visibility_query.get_runtime_skill_level(deps, "four_poisons") >= 5


func _update_dual_glitch_runtime(fps_scale: float, context: Dictionary) -> void:
	if dual_glitch_state == "idle":
		return
	if visibility_query.should_stop_viper_context_effect(context):
		_reset_dual_glitch_runtime(true)
		return
	dual_glitch_base_pos = _get_vector2(context.get("player_pos", dual_glitch_base_pos), dual_glitch_base_pos)
	dual_glitch_paddle_size = _get_vector2(context.get("player_paddle_size", dual_glitch_paddle_size), dual_glitch_paddle_size)
	dual_glitch_phase_frames += fps_scale
	for index in range(dual_glitch_clones.size()):
		var clone_value: Variant = dual_glitch_clones[index]
		if not (clone_value is Dictionary):
			continue
		var clone: Dictionary = clone_value
		var evaporation_frames: float = float(clone.get("evaporation_frames", -1.0))
		if evaporation_frames >= 0.0:
			clone["evaporation_frames"] = evaporation_frames + fps_scale
			dual_glitch_clones[index] = clone
	match dual_glitch_state:
		"startup":
			if dual_glitch_phase_frames >= DUAL_GLITCH_STARTUP_FRAMES:
				dual_glitch_state = "spawn"
				dual_glitch_phase_frames = 0.0
				dual_glitch_locked_player_x_valid = false
		"spawn":
			if dual_glitch_phase_frames >= DUAL_GLITCH_SPAWN_FRAMES:
				dual_glitch_state = "active"
				dual_glitch_phase_frames = 0.0
		"active":
			if not visibility_query.has_living_dual_glitch_clone(dual_glitch_clones):
				_enter_dual_glitch_fade("destroyed")
			elif dual_glitch_phase_frames >= dual_glitch_active_total_frames:
				_enter_dual_glitch_fade("timeout")
		"fade":
			if dual_glitch_phase_frames >= DUAL_GLITCH_FADE_FRAMES:
				_reset_dual_glitch_runtime(false)
	var alive: Array = []
	for clone_value in dual_glitch_clones:
		if not (clone_value is Dictionary):
			continue
		var clone: Dictionary = clone_value
		if (
			visibility_query.is_dual_glitch_clone_alive(clone)
			or visibility_query.is_dual_glitch_clone_evaporating(clone, DUAL_GLITCH_EVAPORATION_FRAMES)
		):
			alive.append(clone)
	dual_glitch_clones = alive


func _enter_dual_glitch_fade(reason: String) -> void:
	if dual_glitch_state == "fade":
		return
	dual_glitch_state = "fade"
	dual_glitch_phase_frames = 0.0
	dual_glitch_locked_player_x_valid = false
	dual_glitch_fade_reason = reason


func get_dual_glitch_clone_rects(context: Dictionary = {}, collision_only: bool = true) -> Array:
	if not context.is_empty():
		dual_glitch_base_pos = _get_vector2(context.get("player_pos", dual_glitch_base_pos), dual_glitch_base_pos)
		dual_glitch_paddle_size = _get_vector2(context.get("player_paddle_size", dual_glitch_paddle_size), dual_glitch_paddle_size)
	var entries: Array = _get_dual_glitch_clone_rect_entries(collision_only, not collision_only)
	var rects: Array = []
	for entry_value in entries:
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			rects.append(entry.get("rect", Rect2()))
	return rects


func _get_dual_glitch_clone_rect_entries(collision_only: bool, include_evaporating: bool) -> Array:
	return visibility_query.get_dual_glitch_clone_rect_entries(
		self,
		collision_only,
		include_evaporating,
		DUAL_GLITCH_EVAPORATION_FRAMES,
		DUAL_GLITCH_OFFSET_PADDING
	)


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
		clone["collision_enabled"] = false
		clone["evaporation_frames"] = 0.0
	dual_glitch_clones[clone_index] = clone
	if destroyed and not visibility_query.has_living_dual_glitch_clone(dual_glitch_clones):
		_enter_dual_glitch_fade("destroyed")
	return {
		"hit": true,
		"clone_destroyed": destroyed,
		"clone_hp": hp,
	}


func _spawn_dual_glitch_clone_dive_entries_for_current_cast(deps: Dictionary) -> void:
	if not _is_dual_glitch_clone_replication_active(deps):
		return
	var origins: Array = visibility_query.get_dual_glitch_replication_origins(_get_dual_glitch_clone_rect_entries(true, false))
	if origins.is_empty():
		return
	var floor_y: float = dive_shockwave_pos.y
	for origin_value in origins:
		if not (origin_value is Dictionary):
			continue
		var origin: Dictionary = origin_value
		var side: int = int(origin.get("side", 0))
		if side == 0:
			continue
		var delay_mult: float = 1.0 if side < 0 else 2.0
		dual_glitch_clone_dive_entries.append({
			"side": side,
			"x": float(origin.get("x", dive_shockwave_pos.x)),
			"y": floor_y,
			"start_y": float(origin.get("y", floor_y)),
			"delay_frames": DUAL_GLITCH_DIVE_STAGGER_FRAMES * delay_mult,
			"timer": 0.0,
			"activated": false,
			"ball_boosted": false,
			"height_snapshot": dive_height_snapshot,
			"telegraph": false,
		})


func _update_dual_glitch_clone_dive_entries(fps_scale: float, deps: Dictionary) -> void:
	if dual_glitch_clone_dive_entries.is_empty():
		return
	var updated: Array = []
	for entry_value in dual_glitch_clone_dive_entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if not bool(entry.get("activated", false)):
			var delay_frames: float = max(0.0, float(entry.get("delay_frames", 0.0)) - fps_scale)
			entry["delay_frames"] = delay_frames
			entry["telegraph"] = delay_frames > 0.0 and delay_frames <= DUAL_GLITCH_DIVE_TELEGRAPH_FRAMES
			if delay_frames <= 0.0:
				entry["activated"] = true
				entry["telegraph"] = false
				entry["timer"] = DIVE_SHOCKWAVE_FRAMES
				var center := Vector2(float(entry.get("x", dive_shockwave_pos.x)), float(entry.get("y", dive_shockwave_pos.y)))
				particle_drawer.spawn_dual_glitch_clone_dive_particles(dive_particles, center, DIVE_PARTICLE_LIMIT)
				runtime_action_router.trigger_feedback(deps, 0.08, 2.4)
		else:
			entry["timer"] = max(0.0, float(entry.get("timer", 0.0)) - fps_scale)
		if (not bool(entry.get("activated", false))) or float(entry.get("timer", 0.0)) > 0.0:
			updated.append(entry)
	dual_glitch_clone_dive_entries = updated


func _absorb_chaos_field_objects(center: Vector2, deps: Dictionary) -> int:
	var absorbed: Array = []
	var seen_instance_ids: Dictionary = {}
	for key in ["stage1_balloon_event", "stage_background", "stage2_pillar_background"]:
		var target: Object = deps.get(key, null)
		if target == null or not target.has_method("absorb_chaos_spear_objects"):
			continue
		var instance_id: int = target.get_instance_id()
		if seen_instance_ids.has(instance_id):
			continue
		seen_instance_ids[instance_id] = true
		var entries: Variant = target.absorb_chaos_spear_objects(center, CHAOS_PULL_RADIUS, deps)
		if entries is Array:
			for entry in entries:
				if entry is Dictionary:
					absorbed.append(entry)
	for entry in absorbed:
		var pos: Vector2 = _get_vector2(entry.get("position", center), center)
		var strength: float = float(entry.get("strength", 1.0))
		var color_value: Variant = entry.get("color", Color(0.78, 0.48, 1.0, 1.0))
		var color: Color = color_value if color_value is Color else Color(0.78, 0.48, 1.0, 1.0)
		var pulse_center: Vector2 = chaos_target
		var delta: Vector2 = pulse_center - pos
		var dist: float = max(1.0, delta.length())
		var inward: float = 0.8 + strength * 0.4
		var tangential: float = randf_range(-1.0, 1.0) * 1.4
		var velocity: Vector2 = delta / dist * inward + Vector2(-delta.y, delta.x) / dist * tangential
		chaos_absorb_pulses.append({
			"pos": pos,
			"vel": velocity,
			"size": max(6.0, 12.0 * strength),
			"base_size": max(6.0, 12.0 * strength),
			"life": 60.0,
			"max_life": 60.0,
			"color": color,
			"consumed": false,
		})
	return absorbed.size()


func _try_update_ignition_aura_hold(
	input_snapshot: Dictionary,
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	now_msec: int
) -> Dictionary:
	var up_pressed: bool = bool(input_snapshot.get("up_pressed", false))
	if not up_pressed:
		_reset_ignition_aura_hold()
		return {}
	if not _can_hold_ignition_aura(input_snapshot, player_pos, special_gauge, config, deps, now_msec):
		_reset_ignition_aura_hold()
		return {}

	if ignition_hold_start_msec <= 0:
		ignition_hold_start_msec = now_msec
		ignition_charge_particles.clear()
	ignition_hold_player_pos = player_pos
	ignition_hold_paddle_size = ViperSkillGeometry.get_paddle_size(config)
	var elapsed_msec: int = max(0, now_msec - ignition_hold_start_msec)
	ignition_hold_ratio = clamp(float(elapsed_msec) / float(IGNITION_HOLD_REQUIRED_MSEC), 0.0, 1.0)
	particle_drawer.spawn_ignition_charge_particles(
		ignition_charge_particles,
		player_pos,
		ignition_hold_paddle_size,
		ignition_hold_ratio,
		IGNITION_CHARGE_PARTICLE_LIMIT
	)
	if elapsed_msec >= IGNITION_HOLD_REQUIRED_MSEC:
		_reset_ignition_aura_hold()
		return _start_ignition_aura(player_pos, special_gauge, config, deps, now_msec)
	return {
		"handled": false,
		"activated": false,
		"special_gauge": special_gauge,
	}


func _can_hold_ignition_aura(
	input_snapshot: Dictionary,
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	now_msec: int
) -> bool:
	if (
		ignition_active
		or dive_active
		or dive_hold_start_msec > 0
		or dual_glitch_state != "idle"
		or _has_viper_attack_motion_active()
		or chaos_state != "idle"
		or shadow_hologram_active
		or shadow_wave_active
		or shadow_marshal_delay_frames > 0.0
		or phantom_strike_active
		or marshal_ready
		or double_marshal_ready
	):
		return false
	if visibility_query.is_dash_motion_busy(deps) or visibility_query.is_control_locked(deps):
		return false
	if not bool(config.get("ball_active", true)) or bool(config.get("waiting_for_serve", false)):
		return false
	if visibility_query.is_round_waiting_for_serve(deps):
		return false
	if bool(input_snapshot.get("down_pressed", false)) or _has_lateral_skill_input(input_snapshot):
		return false
	if runtime_action_router.get_viper_airborne_height(deps, config, player_pos) > 5.0:
		return false
	var skill_config: Object = visibility_query.get_viper_skill_config(deps)
	if not visibility_query.is_skill_equipped(skill_config, IGNITION_AURA):
		return false
	var cost: float = _get_skill_cost_with_fallback(skill_config, IGNITION_AURA, IGNITION_GAUGE_COST)
	if special_gauge < cost:
		return false
	return visibility_query.is_configured_skill_ready(IGNITION_AURA, deps, now_msec)


func _start_ignition_aura(
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	now_msec: int
) -> Dictionary:
	var skill_config: Object = visibility_query.get_viper_skill_config(deps)
	var cost: float = _get_skill_cost_with_fallback(skill_config, IGNITION_AURA, IGNITION_GAUGE_COST)
	var next_gauge: float = max(0.0, special_gauge - cost)
	var skill_state: Object = visibility_query.get_viper_skill_state(deps)
	if skill_state != null:
		if skill_state.has_method("trigger_configured_cooldown"):
			skill_state.trigger_configured_cooldown(IGNITION_AURA, now_msec, skill_config)
		elif skill_state.has_method("trigger_cooldown"):
			var cooldown_seconds := _get_skill_cooldown_seconds_with_fallback(skill_config, IGNITION_AURA, 80.0)
			skill_state.trigger_cooldown(IGNITION_AURA, now_msec, cooldown_seconds)
	_trigger_orb_gauge_spin(deps, now_msec)
	audio_router.play_ignition_aura_sound(deps)
	runtime_action_router.trigger_feedback(deps, 0.14, 4.2)
	ignition_active = true
	ignition_total_frames = IGNITION_DURATION_FRAMES
	ignition_remaining_frames = ignition_total_frames
	ignition_player_pos = player_pos
	ignition_paddle_size = ViperSkillGeometry.get_paddle_size(config)
	ignition_ember_timer = 0.0
	ignition_start_msec = now_msec
	_set_runtime_ignition_aura_bonus(deps, true)
	particle_drawer.spawn_ignition_aura_burst(
		ignition_burst_particles,
		player_pos + ViperSkillGeometry.get_paddle_size(config) * 0.5,
		IGNITION_PARTICLE_LIMIT
	)
	return {
		"handled": true,
		"activated": true,
		"skill_name": IGNITION_AURA,
		"player_pos": player_pos,
		"player_speed": 0.0,
		"special_gauge": next_gauge,
	}


func _update_ignition_aura_runtime(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	particle_drawer.update_ignition_particle_array(ignition_charge_particles, fps_scale)
	particle_drawer.update_ignition_particle_array(ignition_burst_particles, fps_scale)
	particle_drawer.update_ignition_particle_array(ignition_live_embers, fps_scale)
	if not ignition_active:
		return
	var ignition_character_type: String = ""
	if context.has("selected_character_type"):
		ignition_character_type = str(context.get("selected_character_type", "viper")).strip_edges().to_lower()
	if ignition_character_type != "" and ignition_character_type != "viper":
		_finish_ignition_aura(deps)
		return
	if bool(context.get("waiting_for_serve", false)) or not bool(context.get("ball_active", true)):
		ignition_player_pos = _get_vector2(context.get("player_pos", ignition_player_pos), ignition_player_pos)
		ignition_paddle_size = _get_vector2(context.get("player_paddle_size", ignition_paddle_size), ignition_paddle_size)
		_set_runtime_ignition_aura_bonus(deps, true)
		return

	ignition_player_pos = _get_vector2(context.get("player_pos", ignition_player_pos), ignition_player_pos)
	ignition_paddle_size = _get_vector2(context.get("player_paddle_size", ignition_paddle_size), ignition_paddle_size)
	_set_runtime_ignition_aura_bonus(deps, true)
	ignition_remaining_frames = max(0.0, ignition_remaining_frames - fps_scale)
	ignition_ember_timer -= fps_scale
	if ignition_ember_timer <= 0.0:
		ignition_ember_timer = IGNITION_EMBER_INTERVAL_FRAMES
		particle_drawer.spawn_ignition_live_embers(
			ignition_live_embers,
			ignition_player_pos,
			ignition_paddle_size,
			IGNITION_EMBER_LIMIT
		)
	if ignition_remaining_frames <= 0.0:
		_finish_ignition_aura(deps)


func _finish_ignition_aura(deps: Dictionary) -> void:
	if not ignition_active and ignition_remaining_frames <= 0.0:
		_set_runtime_ignition_aura_bonus(deps, false)
		return
	ignition_active = false
	ignition_remaining_frames = 0.0
	ignition_ember_timer = 0.0
	_set_runtime_ignition_aura_bonus(deps, false)


func _reset_ignition_aura_hold() -> void:
	ignition_hold_start_msec = 0
	ignition_hold_ratio = 0.0
	ignition_hold_player_pos = Vector2.ZERO
	ignition_hold_paddle_size = Vector2(155.0, 50.0)


func _set_runtime_ignition_aura_bonus(deps: Dictionary, active: bool) -> void:
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	if runtime_perk_state != null and runtime_perk_state.has_method("set_viper_ignition_aura_active"):
		var state_changed := true
		if runtime_perk_state.has_method("is_viper_ignition_aura_active"):
			state_changed = bool(runtime_perk_state.is_viper_ignition_aura_active()) != active
		runtime_perk_state.set_viper_ignition_aura_active(active)
		if state_changed and runtime_perk_state.has_method("refresh_viper_ignition_aura_dynamic_effects"):
			runtime_perk_state.refresh_viper_ignition_aura_dynamic_effects(
				deps.get("registry", null),
				deps.get("owner", null)
			)


func _try_update_dive_hold(
	input_snapshot: Dictionary,
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	now_msec: int
) -> Dictionary:
	var down_pressed: bool = bool(input_snapshot.get("down_pressed", false))
	if not down_pressed:
		_reset_dive_hold()
		return {}
	if _has_viper_attack_motion_active(true):
		_reset_dive_hold()
		return {}
	if marshal_ready or double_marshal_ready or shadow_hologram_active or shadow_wave_active or shadow_marshal_delay_frames > 0.0:
		_reset_dive_hold()
		return {}
	if chaos_state != "idle":
		_reset_dive_hold()
		return {}
	if visibility_query.is_dash_motion_busy(deps) or visibility_query.is_control_locked(deps):
		_reset_dive_hold()
		return {}
	if not bool(config.get("ball_active", true)):
		_reset_dive_hold()
		return {}
	if visibility_query.is_round_waiting_for_serve(deps):
		_reset_dive_hold()
		return {}
	if _has_lateral_skill_input(input_snapshot):
		_reset_dive_hold()
		return {}
	if runtime_action_router.get_viper_airborne_height(deps, config, player_pos) <= 20.0:
		_reset_dive_hold()
		return {}
	var skill_config: Object = visibility_query.get_viper_skill_config(deps)
	if not visibility_query.is_skill_equipped(skill_config, DIVE_STRIKE):
		_reset_dive_hold()
		return {}
	var cost: float = _get_skill_cost_with_fallback(skill_config, DIVE_STRIKE, DIVE_GAUGE_COST)
	if special_gauge < cost:
		_reset_dive_hold()
		return {}
	if not visibility_query.is_configured_skill_ready(DIVE_STRIKE, deps, now_msec):
		_reset_dive_hold()
		return {}

	if dive_hold_start_msec <= 0:
		dive_hold_start_msec = now_msec
		dive_charge_particles.clear()
	dive_hold_player_pos = player_pos
	dive_hold_paddle_size = ViperSkillGeometry.get_paddle_size(config)
	var elapsed_msec: int = max(0, now_msec - dive_hold_start_msec)
	dive_hold_ratio = clamp(float(elapsed_msec) / float(DIVE_HOLD_REQUIRED_MSEC), 0.0, 1.0)
	particle_drawer.spawn_dive_charge_particles(
		dive_charge_particles,
		player_pos,
		dive_hold_paddle_size,
		dive_hold_ratio,
		DIVE_CHARGE_PARTICLE_LIMIT
	)
	if elapsed_msec >= DIVE_HOLD_REQUIRED_MSEC:
		_reset_dive_hold()
		return _start_dive_strike(player_pos, special_gauge, config, deps, now_msec)
	return {
		"handled": false,
		"activated": false,
		"special_gauge": special_gauge,
	}


func _start_dive_strike(
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	now_msec: int
) -> Dictionary:
	var skill_config: Object = visibility_query.get_viper_skill_config(deps)
	var cost: float = _get_skill_cost_with_fallback(skill_config, DIVE_STRIKE, DIVE_GAUGE_COST)
	var next_gauge: float = max(0.0, special_gauge - cost)
	var cooldown_seconds := _get_skill_cooldown_seconds_with_fallback(skill_config, DIVE_STRIKE, 70.0, false)
	_trigger_runtime_cooldown_and_orb_gauge_spin(
		DIVE_STRIKE,
		now_msec,
		skill_config,
		deps,
		_get_four_poisons_additive_cooldown_seconds(DIVE_STRIKE, skill_config, deps, cooldown_seconds)
	)
	runtime_action_router.interrupt_viper_jetpack_thrust(deps)
	audio_router.play_dive_prep_sound(deps)
	runtime_action_router.trigger_feedback(deps, 0.08, 3.2)
	dive_active = true
	dive_phase = 0
	dive_phase_frames = 0.0
	dive_paddle_size = ViperSkillGeometry.get_paddle_size(config)
	dive_floor_y = ViperSkillGeometry.player_floor_y(config)
	dive_player_pos = player_pos
	dive_height_snapshot = max(0.0, runtime_action_router.get_viper_airborne_height(deps, config, player_pos))
	var prep_reduction_pct: float = float(_get_four_poisons_prep_reduction_pct(deps))
	dive_prep_frames_snapshot = max(1.0, DIVE_PREP_FRAMES * max(0.0, 1.0 - prep_reduction_pct / 100.0))
	dive_effect_start_msec = now_msec
	dive_shockwave_spawn_msec = 0
	dive_hit_feedback_msec = 0
	if dive_height_snapshot > 0.0:
		dive_player_pos.y = dive_floor_y - dive_height_snapshot
	dive_shockwave_timer = 0.0
	dive_shockwave_pos = ViperSkillGeometry.emp_strike_shockwave_pos(dive_player_pos, dive_paddle_size, dive_floor_y)
	dive_ball_boosted = false
	dive_particles.clear()
	runtime_action_router.set_viper_jetpack_offset_y(deps, dive_player_pos.y - dive_floor_y)
	return {
		"handled": true,
		"activated": true,
		"skill_name": DIVE_STRIKE,
		"player_pos": dive_player_pos,
		"player_speed": 0.0,
		"special_gauge": next_gauge,
		"player_collision_cooldown": DIVE_PLAYER_COLLISION_COOLDOWN,
	}


func _update_dive_strike(
	delta: float,
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var fps_scale: float = max(0.0, delta * 60.0)
	if dive_phase == 2:
		var previous_radius: float = get_emp_shockwave_radius()
		dive_shockwave_timer = max(0.0, dive_shockwave_timer - fps_scale)
		if (
			not dive_shockwave_boss_effect_applied
			and ViperSkillGeometry.dive_shockwave_ring_touches_boss(
				previous_radius,
				get_emp_shockwave_radius(),
				config,
				dive_shockwave_pos,
				DIVE_SHOCKWAVE_RING_HALF_THICKNESS
			)
		):
			var slip_reference_pos: Vector2 = dive_shockwave_pos
			var ring_ball_pos: Variant = config.get("ball_pos", null)
			if ring_ball_pos is Vector2:
				slip_reference_pos = ring_ball_pos
			_start_dive_slip_for_height(
				slip_reference_pos,
				config,
				deps,
				dive_height_snapshot,
				true
			)
			dive_shockwave_boss_effect_applied = true
		if dive_shockwave_timer <= 0.0:
			dive_active = false
			dive_phase = 0
			dive_phase_frames = 0.0
			dive_ball_boosted = false
			dive_shockwave_timer = 0.0
		return {
			"handled": false,
			"activated": false,
			"special_gauge": special_gauge,
		}

	dive_phase_frames += fps_scale
	if dive_paddle_size == Vector2.ZERO:
		dive_paddle_size = ViperSkillGeometry.get_paddle_size(config)
	dive_floor_y = ViperSkillGeometry.player_floor_y(config)
	match dive_phase:
		0:
			dive_player_pos.x = player_pos.x
			var prep_center: Vector2 = dive_player_pos + ViperSkillGeometry.get_paddle_size(config) * 0.5
			var prep_progress: float = clamp(dive_phase_frames / max(1.0, dive_prep_frames_snapshot), 0.0, 1.0)
			particle_drawer.spawn_dive_prep_particles(
				dive_particles,
				prep_center,
				prep_progress,
				fps_scale,
				DIVE_PARTICLE_LIMIT
			)
			runtime_action_router.set_viper_jetpack_offset_y(deps, dive_player_pos.y - dive_floor_y)
			if dive_phase_frames >= dive_prep_frames_snapshot:
				dive_phase = 1
				dive_phase_frames = 0.0
		1:
			dive_player_pos.x = player_pos.x
			dive_player_pos.y = min(dive_floor_y, dive_player_pos.y + DIVE_SPEED * fps_scale)
			runtime_action_router.set_viper_jetpack_offset_y(deps, dive_player_pos.y - dive_floor_y)
			var trail_anchor := Vector2(
				dive_player_pos.x + ViperSkillGeometry.get_paddle_size(config).x * 0.5,
				dive_player_pos.y + ViperSkillGeometry.get_paddle_size(config).y
			)
			particle_drawer.spawn_dive_trail_particles(
				dive_particles,
				trail_anchor.x,
				trail_anchor.y,
				fps_scale,
				DIVE_PARTICLE_LIMIT
			)
			if dive_player_pos.y >= dive_floor_y:
				dive_phase = 2
				dive_phase_frames = 0.0
				dive_floor_y = ViperSkillGeometry.player_floor_y(config)
				dive_player_pos.y = dive_floor_y
				dive_shockwave_timer = DIVE_SHOCKWAVE_FRAMES
				dive_shockwave_pos = ViperSkillGeometry.emp_strike_shockwave_pos(dive_player_pos, dive_paddle_size, dive_floor_y)
				dive_shockwave_spawn_msec = Time.get_ticks_msec()
				dive_shockwave_max_radius = ViperSkillGeometry.dive_shockwave_boss_reach_radius(
					config,
					dive_shockwave_pos,
					DIVE_SHOCKWAVE_BASE_MAX_RADIUS,
					DIVE_SHOCKWAVE_RING_HALF_THICKNESS
				)
				dive_shockwave_boss_effect_applied = false
				dive_ball_boosted = false
				runtime_action_router.set_viper_jetpack_offset_y(deps, 0.0)
				runtime_action_router.trigger_feedback(deps, 0.18, 5.0)
				audio_router.play_dive_strike_sound(deps)
				particle_drawer.spawn_dive_landing_particles(
					dive_particles,
					dive_shockwave_pos,
					DIVE_PARTICLE_LIMIT,
					DIVE_JETPACK_MAX_HEIGHT
				)
				_spawn_dual_glitch_clone_dive_entries_for_current_cast(deps)
	return {
		"handled": true,
		"activated": false,
		"skill_name": DIVE_STRIKE,
		"player_pos": dive_player_pos,
		"player_speed": 0.0,
		"special_gauge": special_gauge,
		"player_collision_cooldown": DIVE_PLAYER_COLLISION_COOLDOWN,
	}


func _start_dive_slip_for_height(
	ball_pos: Vector2,
	context: Dictionary,
	deps: Dictionary,
	height_snapshot: float,
	max_refresh: bool
) -> void:
	var start_state: Dictionary = ViperSkillGeometry.emp_slip_start_state(
		ball_pos,
		context,
		height_snapshot,
		DIVE_JETPACK_MAX_HEIGHT,
		DIVE_SLIP_DURATION_MIN,
		DIVE_SLIP_DURATION_MAX,
		_get_four_poisons_scaled_pct(
			deps,
			FOUR_POISONS_EMP_SLEEP_PCT_BY_LEVEL,
			FOUR_POISONS_EMP_SLEEP_PCT_CAP,
			FOUR_POISONS_EMP_SLEEP_PCT_PER_EXTRA_LEVEL
		),
		DIVE_SLIP_SPEED
	)
	var duration: float = float(start_state.get("duration", 1.0))
	if max_refresh:
		dive_slip_duration = max(dive_slip_duration, duration)
		dive_slip_timer = max(dive_slip_timer, duration)
	else:
		dive_slip_duration = duration
		dive_slip_timer = duration
	dive_slip_vel = float(start_state.get("slip_vel", 0.0))


func apply_emp_slip_boss_motion(boss_pos: Vector2, context: Dictionary, fps_scale: float) -> Dictionary:
	var motion: Dictionary = ViperSkillGeometry.emp_slip_boss_motion(
		boss_pos,
		context,
		fps_scale,
		dive_slip_timer,
		dive_slip_duration,
		dive_slip_vel
	)
	dive_slip_timer = float(motion.get("slip_timer", 0.0))
	dive_slip_vel = float(motion.get("slip_vel", 0.0))
	return {
		"boss_pos": _get_vector2(motion.get("boss_pos", boss_pos), boss_pos),
		"boss_vel": float(motion.get("boss_vel", 0.0)),
	}


func _reset_dive_runtime(clear_hold: bool = false) -> void:
	if clear_hold:
		_reset_dive_hold()
	dive_active = false
	dive_phase = 0
	dive_phase_frames = 0.0
	dive_player_pos = Vector2.ZERO
	dive_paddle_size = Vector2(155.0, 50.0)
	dive_floor_y = 700.0
	dive_height_snapshot = 0.0
	dive_prep_frames_snapshot = DIVE_PREP_FRAMES
	dive_shockwave_timer = 0.0
	dive_shockwave_pos = Vector2.ZERO
	dive_shockwave_max_radius = DIVE_SHOCKWAVE_BASE_MAX_RADIUS
	dive_shockwave_boss_effect_applied = false
	dive_ball_boosted = false
	dive_particles.clear()
	dive_slip_timer = 0.0
	dive_slip_duration = 0.0
	dive_slip_vel = 0.0
	dive_hit_text_timer = 0.0
	dive_hit_text_pos = Vector2.ZERO
	dive_hit_text_height_ratio = 0.0
	dive_effect_start_msec = 0
	dive_shockwave_spawn_msec = 0
	dive_hit_feedback_msec = 0
	fx_host_controller.hide_fx_host(emp_fx_host)


func _reset_dive_hold() -> void:
	dive_hold_start_msec = 0
	dive_hold_ratio = 0.0
	dive_hold_player_pos = Vector2.ZERO
	dive_hold_paddle_size = Vector2(155.0, 50.0)
	dive_charge_particles.clear()
	if not dive_active:
		fx_host_controller.hide_fx_host(emp_fx_host)


func _trigger_runtime_cooldown_and_orb_gauge_spin(
	skill_name: String,
	now_msec: int,
	skill_config: Object,
	deps: Dictionary,
	cooldown_seconds: float
) -> void:
	runtime_action_router.trigger_viper_runtime_cooldown(
		skill_name,
		now_msec,
		skill_config,
		deps,
		cooldown_seconds,
		visibility_query
	)
	_trigger_orb_gauge_spin(deps, now_msec)


func _play_dive_prep_sound(deps: Dictionary) -> void:
	audio_router.play_dive_prep_sound(deps)


func _play_dive_strike_sound(deps: Dictionary) -> void:
	audio_router.play_dive_strike_sound(deps)


func _try_start_blade_combo_from_air_blade_motion(
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	now_msec: int
) -> Dictionary:
	var combo_skill_config: Object = visibility_query.get_viper_skill_config(deps)
	var nerve_and_dark_blade_equipped: bool = (
		visibility_query.is_skill_equipped(combo_skill_config, NERVE_STRIKE)
		and visibility_query.is_skill_equipped(combo_skill_config, DARK_BLADE)
	)
	var nerve_strike_window_end_frame: float = (
		NERVE_STRIKE_DARK_BLADE_SPLIT_FRAMES
		if nerve_and_dark_blade_equipped
		else NERVE_STRIKE_WINDOW_END_FRAMES
	)
	var nerve_strike_combo_window_active: bool = (
		not nerve_strike_combo_used
		and not nerve_strike_active
		and blade_motion_total_frames >= NERVE_STRIKE_WINDOW_START_FRAMES
		and blade_motion_total_frames < nerve_strike_window_end_frame
	)
	if nerve_strike_combo_window_active:
		if _can_start_nerve_strike_combo(special_gauge, config, deps, now_msec):
			_clear_blade_projectile()
			return _start_nerve_strike(player_pos, special_gauge, config, deps, now_msec)
		if nerve_and_dark_blade_equipped and blade_motion_total_frames < NERVE_STRIKE_DARK_BLADE_SPLIT_FRAMES:
			return {}
	var dark_blade_split_combo_window_active: bool = (
		nerve_and_dark_blade_equipped
		and blade_motion_total_frames >= NERVE_STRIKE_DARK_BLADE_SPLIT_FRAMES
		and blade_motion_total_frames <= NERVE_STRIKE_WINDOW_END_FRAMES
	)
	if _can_start_dark_blade_combo_from_blade_motion(
		combo_skill_config,
		special_gauge,
		config,
		deps,
		dark_blade_split_combo_window_active,
		blade_air_combo_window
	):
		_clear_blade_projectile()
		return _start_blade_motion(player_pos, special_gauge, config, deps, true, now_msec, true, true)
	return {}


func _try_start_blade_combo_from_dark_blade_motion(
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	now_msec: int
) -> Dictionary:
	if not (blade_dark_mode and blade_dark_combo_window):
		return {}
	if visibility_query.is_control_locked(deps) or not bool(config.get("ball_active", true)):
		return {}
	var skill_config: Object = visibility_query.get_viper_skill_config(deps)
	if not visibility_query.is_skill_equipped(skill_config, BLADE_RUSH):
		return {}
	if special_gauge < _get_blade_skill_cost(skill_config, deps, BLADE_RUSH):
		return {}
	_clear_blade_projectile()
	return _start_blade_motion(player_pos, special_gauge, config, deps, false, now_msec, false, true)


func _can_start_dark_blade_combo_from_blade_motion(
	skill_config: Object,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	split_combo_window_active: bool,
	air_combo_window_active: bool
) -> bool:
	if not (split_combo_window_active or air_combo_window_active):
		return false
	if visibility_query.is_control_locked(deps) or not bool(config.get("ball_active", true)):
		return false
	if not visibility_query.is_skill_equipped(skill_config, DARK_BLADE):
		return false
	return (
		special_gauge >= _get_blade_skill_cost(skill_config, deps, DARK_BLADE)
		and visibility_query.is_configured_skill_ready(DARK_BLADE, deps, -1)
	)


func _can_start_nerve_strike_combo(special_gauge: float, config: Dictionary, deps: Dictionary, now_msec: int) -> bool:
	if nerve_strike_combo_used or nerve_strike_active or blade_dark_mode:
		return false
	if visibility_query.is_control_locked(deps) or not bool(config.get("ball_active", true)):
		return false
	var skill_config: Object = visibility_query.get_viper_skill_config(deps)
	if not visibility_query.is_skill_equipped(skill_config, NERVE_STRIKE):
		return false
	if special_gauge < _get_skill_cost_with_fallback(skill_config, NERVE_STRIKE, 90.0):
		return false
	var skill_state: Object = visibility_query.get_viper_skill_state(deps)
	if skill_state == null:
		return true
	if skill_state.has_method("get_cooldown_remaining"):
		return skill_state.get_cooldown_remaining(
			NERVE_STRIKE,
			now_msec,
			_get_four_poisons_additive_cooldown_seconds(NERVE_STRIKE, skill_config, deps, 40.0)
		) <= 0.0
	return visibility_query.is_configured_skill_ready(NERVE_STRIKE, deps, now_msec)


func _start_nerve_strike(
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	now_msec: int
) -> Dictionary:
	var skill_config: Object = visibility_query.get_viper_skill_config(deps)
	var cost: float = _get_skill_cost_with_fallback(skill_config, NERVE_STRIKE, 90.0)
	var next_gauge: float = max(0.0, special_gauge - cost)
	_trigger_runtime_cooldown_and_orb_gauge_spin(
		NERVE_STRIKE,
		now_msec,
		skill_config,
		deps,
		_get_four_poisons_additive_cooldown_seconds(NERVE_STRIKE, skill_config, deps, 40.0)
	)
	runtime_action_router.trigger_feedback(deps, 0.12, 4.2)
	runtime_action_router.interrupt_viper_jetpack_thrust(deps)
	audio_router.stop_blade_spin_sound(self, deps)
	_reset_blade_motion_only(deps)
	nerve_strike_cast_id += 1
	nerve_strike_active = true
	nerve_strike_phase = 0
	nerve_strike_phase_frames = 0.0
	nerve_strike_start_pos = player_pos
	nerve_strike_pos = player_pos
	nerve_strike_dash_target_pos = ViperSkillGeometry.nerve_strike_target_pos(config, NERVE_STRIKE_TARGET_Y_OFFSET)
	nerve_strike_return_start_pos = Vector2.ZERO
	nerve_strike_return_target_pos = Vector2.ZERO
	nerve_strike_paddle_size = ViperSkillGeometry.get_paddle_size(config)
	nerve_strike_floor_y = ViperSkillGeometry.player_floor_y(config)
	nerve_strike_hit_confirmed = false
	nerve_strike_combo_used = true
	nerve_strike_freeze_active = false
	nerve_strike_slash_triggered = false
	nerve_strike_slash_vfx_frames = 0.0
	nerve_strike_slash_center = ViperSkillGeometry.nerve_strike_target_center(config, NERVE_STRIKE_TARGET_Y_OFFSET)
	audio_router.play_nerve_strike_moving_sound(deps)
	_spawn_dual_glitch_clone_nerve_slashes_for_current_cast(deps, config)
	return {
		"handled": true,
		"activated": true,
		"skill_name": NERVE_STRIKE,
		"player_pos": nerve_strike_pos,
		"player_speed": 0.0,
		"special_gauge": next_gauge,
	}


func _update_nerve_strike(
	delta: float,
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var fps_scale: float = max(0.0, delta * 60.0)
	nerve_strike_phase_frames += fps_scale
	var result := {
		"handled": true,
		"activated": false,
		"skill_name": NERVE_STRIKE,
		"player_pos": player_pos,
		"player_speed": 0.0,
		"special_gauge": special_gauge,
	}
	match nerve_strike_phase:
		0:
			result.merge(_update_nerve_strike_dash(config, deps), true)
		1:
			result.merge(_update_nerve_strike_slash(config, deps), true)
		2:
			result.merge(_update_nerve_strike_return(deps), true)
		_:
			_reset_nerve_strike_runtime(false)
	if nerve_strike_active:
		result["player_pos"] = nerve_strike_pos
	return result


func _enter_nerve_strike_return_phase(config: Dictionary, deps: Dictionary) -> void:
	nerve_strike_phase = 2
	nerve_strike_phase_frames = 0.0
	nerve_strike_freeze_active = false
	nerve_strike_return_start_pos = nerve_strike_pos
	nerve_strike_return_target_pos = ViperSkillGeometry.nerve_strike_return_target_pos(config)
	audio_router.play_nerve_strike_moving_sound(deps)


func _update_nerve_strike_dash(config: Dictionary, deps: Dictionary) -> Dictionary:
	var motion: Dictionary = ViperSkillGeometry.nerve_strike_dash_motion(
		nerve_strike_start_pos,
		nerve_strike_dash_target_pos,
		ViperSkillGeometry.nerve_strike_target_pos(config, NERVE_STRIKE_TARGET_Y_OFFSET),
		nerve_strike_phase_frames,
		NERVE_STRIKE_DASH_FRAMES,
		NERVE_STRIKE_TRACKING_END_RATIO,
		NERVE_STRIKE_TRACKING_STRENGTH
	)
	var progress: float = float(motion.get("progress", 0.0))
	nerve_strike_dash_target_pos = _get_vector2(motion.get("target_pos", nerve_strike_dash_target_pos), nerve_strike_dash_target_pos)
	nerve_strike_pos = _get_vector2(motion.get("pos", nerve_strike_pos), nerve_strike_pos)
	if progress < 1.0:
		return {}

	var nerve_strike_player_center: Vector2 = nerve_strike_pos + nerve_strike_paddle_size * 0.5
	nerve_strike_hit_confirmed = ViperSkillGeometry.nerve_strike_hits_target(
		nerve_strike_player_center,
		_get_nerve_strike_boss_center(config),
		NERVE_STRIKE_HIT_RADIUS
	)
	nerve_strike_phase = 1
	nerve_strike_phase_frames = 0.0
	nerve_strike_slash_triggered = false
	nerve_strike_slash_center = _get_nerve_strike_boss_center(config)
	if nerve_strike_hit_confirmed:
		nerve_strike_freeze_active = true
		audio_router.play_phantom_show_sound(deps)
		runtime_action_router.trigger_feedback(deps, 0.18, 5.2)
		var mythic_item_runtime: Object = visibility_query.get_mythic_item_runtime(deps)
		if mythic_item_runtime != null and mythic_item_runtime.has_method("try_spawn_venom_mist_at_boss"):
			mythic_item_runtime.try_spawn_venom_mist_at_boss(nerve_strike_slash_center, deps, false)
		return runtime_action_router.award_skill_gold(deps, NERVE_STRIKE_HIT_GOLD)
	nerve_strike_miss_text_timer = NERVE_STRIKE_MISS_TEXT_FRAMES
	nerve_strike_miss_text_pos = ViperSkillGeometry.nerve_strike_miss_text_pos(
		ViperSkillGeometry.nerve_strike_target_center(config, NERVE_STRIKE_TARGET_Y_OFFSET),
		-20.0
	)
	_enter_nerve_strike_return_phase(config, deps)
	return {}


func _update_nerve_strike_slash(config: Dictionary, deps: Dictionary) -> Dictionary:
	var duration: float = NERVE_STRIKE_SLASH_HIT_FRAMES if nerve_strike_hit_confirmed else NERVE_STRIKE_SLASH_MISS_FRAMES
	var progress: float = ViperSkillGeometry.nerve_strike_phase_progress(nerve_strike_phase_frames, duration)
	nerve_strike_pos = nerve_strike_dash_target_pos
	if ViperSkillGeometry.nerve_strike_should_trigger_slash(
		nerve_strike_hit_confirmed,
		nerve_strike_slash_triggered,
		progress,
		NERVE_STRIKE_SLASH_TRIGGER_RATIO
	):
		nerve_strike_slash_triggered = true
		nerve_strike_slash_vfx_frames = NERVE_STRIKE_SLASH_VFX_FRAMES
		nerve_strike_slash_center = _get_nerve_strike_boss_center(config)
		trigger_venom_edge_strike()
		audio_router.play_nerve_strike_attack_sound(deps)
		_spawn_nerve_strike_slash_feedback(nerve_strike_slash_center, deps)
	if progress < 1.0:
		return {}

	if nerve_strike_hit_confirmed:
		_apply_nerve_strike_confusion(deps)
	_enter_nerve_strike_return_phase(config, deps)
	return {}


func _update_nerve_strike_return(deps: Dictionary) -> Dictionary:
	var return_frames: float = NERVE_STRIKE_RETURN_HIT_FRAMES if nerve_strike_hit_confirmed else NERVE_STRIKE_RETURN_MISS_FRAMES
	var motion: Dictionary = ViperSkillGeometry.nerve_strike_return_motion(
		nerve_strike_return_start_pos,
		nerve_strike_return_target_pos,
		nerve_strike_phase_frames,
		return_frames
	)
	var progress: float = float(motion.get("progress", 0.0))
	nerve_strike_pos = _get_vector2(motion.get("pos", nerve_strike_pos), nerve_strike_pos)
	if progress < 1.0:
		return {}
	nerve_strike_pos = nerve_strike_return_target_pos
	var final_pos: Vector2 = nerve_strike_pos
	runtime_action_router.force_viper_jetpack_land(deps)
	_reset_nerve_strike_runtime(false)
	return {"player_pos": final_pos}


func _reset_nerve_strike_runtime(clear_clones: bool = false) -> void:
	nerve_strike_active = false
	nerve_strike_phase = 0
	nerve_strike_phase_frames = 0.0
	nerve_strike_start_pos = Vector2.ZERO
	nerve_strike_pos = Vector2.ZERO
	nerve_strike_dash_target_pos = Vector2.ZERO
	nerve_strike_return_start_pos = Vector2.ZERO
	nerve_strike_return_target_pos = Vector2.ZERO
	nerve_strike_paddle_size = Vector2(155.0, 50.0)
	nerve_strike_floor_y = 700.0
	nerve_strike_hit_confirmed = false
	nerve_strike_freeze_active = false
	nerve_strike_slash_triggered = false
	nerve_strike_slash_vfx_frames = 0.0
	nerve_strike_slash_center = Vector2.ZERO
	if clear_clones:
		nerve_strike_combo_used = false
		nerve_strike_miss_text_timer = 0.0
		nerve_strike_miss_text_pos = Vector2.ZERO
		nerve_strike_clone_slashes.clear()


func _get_four_poisons_additive_cooldown_seconds(
	skill_name: String,
	skill_config: Object,
	deps: Dictionary,
	fallback_base_seconds: float
) -> float:
	return skill_scaling.get_four_poisons_additive_cooldown_seconds(
		skill_name,
		skill_config,
		fallback_base_seconds,
		visibility_query.get_runtime_skill_level(deps, "four_poisons"),
		FOUR_POISONS_COOLDOWN_REDUCTION_PCT_BY_LEVEL,
		FOUR_POISONS_COOLDOWN_REDUCTION_PCT_CAP,
		FOUR_POISONS_COOLDOWN_REDUCTION_PCT_PER_EXTRA_LEVEL,
		NERVE_STRIKE,
		DIVE_STRIKE,
		CHAOS_SPEAR,
		DUAL_GLITCH
	)


func _apply_nerve_strike_confusion(deps: Dictionary) -> void:
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state == null:
		var registry: Object = deps.get("registry", null)
		if registry != null and registry.has_method("get_instance"):
			status_effect_state = registry.get_instance("status_effect_state")
	if status_effect_state == null or not status_effect_state.has_method("apply_status"):
		return
	var venom_confusion_pct: int = _get_four_poisons_scaled_pct(
		deps,
		FOUR_POISONS_VENOM_CONFUSION_PCT_BY_LEVEL,
		FOUR_POISONS_VENOM_CONFUSION_PCT_CAP,
		FOUR_POISONS_VENOM_CONFUSION_PCT_PER_EXTRA_LEVEL
	)
	var confusion_multiplier: float = 1.0 + float(venom_confusion_pct) / 100.0
	status_effect_state.apply_status(
		"boss",
		"confusion",
		round(NERVE_STRIKE_CONFUSION_FRAMES * confusion_multiplier),
		{"cleansable": true},
		"viper_nerve_strike"
	)


func _get_nerve_strike_boss_center(config: Dictionary) -> Vector2:
	return ViperSkillGeometry.nerve_strike_boss_center(config)


func _spawn_nerve_strike_slash_feedback(center: Vector2, deps: Dictionary) -> void:
	runtime_action_router.trigger_feedback(deps, 0.16, 5.0)
	_spawn_fallback_hit_impact(
		center,
		Vector2(0.0, 24.0),
		deps,
		Color(0.72, 0.12, 0.95, 1.0),
		1.4,
		0.95,
		1.10
	)


func _spawn_dual_glitch_clone_nerve_slashes_for_current_cast(deps: Dictionary, config: Dictionary) -> void:
	if not _is_dual_glitch_clone_replication_active(deps):
		return
	var origins: Array = visibility_query.get_dual_glitch_replication_origins(_get_dual_glitch_clone_rect_entries(true, false))
	if origins.is_empty():
		return
	var boss_center: Vector2 = _get_nerve_strike_boss_center(config)
	for origin_value in origins:
		if not (origin_value is Dictionary):
			continue
		var origin: Dictionary = origin_value
		var side: int = int(origin.get("side", 0))
		if side == 0:
			continue
		var delay_mult: float = 1.0 if side < 0 else 2.0
		var start := Vector2(
			float(origin.get("x", boss_center.x)),
			float(origin.get("y", boss_center.y))
		)
		nerve_strike_clone_slashes.append({
			"cast_id": nerve_strike_cast_id,
			"side": side,
			"state": "pending",
			"delay_frames": DUAL_GLITCH_NERVE_STAGGER_FRAMES * delay_mult,
			"timer": 0.0,
			"origin": start,
			"pos": start,
			"target": boss_center,
			"hit_applied": false,
		})


func _update_nerve_strike_clone_slashes(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if nerve_strike_clone_slashes.is_empty():
		return
	var updated: Array = []
	for entry_value in nerve_strike_clone_slashes:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var state: String = str(entry.get("state", "pending"))
		match state:
			"pending":
				var delay_frames: float = max(0.0, float(entry.get("delay_frames", 0.0)) - fps_scale)
				entry["delay_frames"] = delay_frames
				if delay_frames <= 0.0:
					entry["state"] = "travel"
					entry["timer"] = 0.0
					entry["target"] = _get_nerve_strike_boss_center(context)
			"travel":
				var origin: Vector2 = _get_vector2(entry.get("origin", Vector2.ZERO), Vector2.ZERO)
				var live_target: Vector2 = _get_nerve_strike_boss_center(context)
				var current_target: Vector2 = _get_vector2(entry.get("target", origin), origin)
				var motion: Dictionary = ViperSkillGeometry.nerve_strike_clone_slash_motion(
					origin,
					current_target,
					live_target,
					float(entry.get("timer", 0.0)),
					fps_scale,
					DUAL_GLITCH_NERVE_TRAVEL_FRAMES,
					0.70,
					0.16
				)
				var progress: float = float(motion.get("progress", 0.0))
				var target: Vector2 = _get_vector2(motion.get("target", current_target), current_target)
				entry["timer"] = float(motion.get("timer", 0.0))
				entry["target"] = target
				entry["pos"] = _get_vector2(motion.get("pos", origin), origin)
				if progress >= 1.0:
					var pos: Vector2 = _get_vector2(entry.get("pos", target), target)
					var hit: bool = ViperSkillGeometry.nerve_strike_hits_target(pos, live_target, NERVE_STRIKE_HIT_RADIUS)
					if hit and not bool(entry.get("hit_applied", false)):
						entry["hit_applied"] = true
						_apply_nerve_strike_confusion(deps)
						_spawn_nerve_strike_slash_feedback(pos, deps)
					entry["state"] = "slash"
					entry["timer"] = DUAL_GLITCH_NERVE_SLASH_FRAMES
			"slash":
				entry["timer"] = max(0.0, float(entry.get("timer", 0.0)) - fps_scale)
			_:
				entry["timer"] = 0.0
		if str(entry.get("state", "")) != "slash" or float(entry.get("timer", 0.0)) > 0.0:
			updated.append(entry)
	nerve_strike_clone_slashes = updated


func _can_start_air_blade(special_gauge: float, config: Dictionary, deps: Dictionary) -> bool:
	if _has_viper_attack_motion_active() or chaos_state == "startup":
		return false
	if dark_blade_window:
		return false
	if not bool(config.get("ball_active", true)):
		return false
	if not visibility_query.is_viper_airborne(deps):
		return false
	if visibility_query.is_control_locked(deps):
		return false
	var skill_config: Object = visibility_query.get_viper_skill_config(deps)
	if not visibility_query.is_skill_equipped(skill_config, BLADE_RUSH):
		return false
	if special_gauge < _get_blade_skill_cost(skill_config, deps, BLADE_RUSH):
		return false
	return visibility_query.is_configured_skill_ready(BLADE_RUSH, deps, -1)


func _can_start_dark_blade_from_window(special_gauge: float, config: Dictionary, deps: Dictionary) -> bool:
	if not dark_blade_window:
		return false
	if blade_motion_active or blade_projectile_active or chaos_state == "startup":
		return false
	if not bool(config.get("ball_active", true)):
		return false
	var core_flip_dark_ready := (core_flip_attack_active and core_flip_ball_hit) or core_flip_dark_blade_handoff_frames > 0.0
	var marshal_dark_ready := marshal_active
	if not (visibility_query.is_viper_airborne(deps) or core_flip_dark_ready or marshal_dark_ready):
		return false
	if visibility_query.is_control_locked(deps):
		return false
	var skill_config: Object = visibility_query.get_viper_skill_config(deps)
	if not visibility_query.is_skill_equipped(skill_config, DARK_BLADE):
		return false
	if special_gauge < _get_blade_skill_cost(skill_config, deps, DARK_BLADE):
		return false
	return visibility_query.is_configured_skill_ready(DARK_BLADE, deps, -1)


func _start_blade_motion(
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	dark_mode: bool,
	now_msec: int,
	trigger_cooldown: bool = true,
	pop_up_from_combo: bool = false
) -> Dictionary:
	var skill_config: Object = visibility_query.get_viper_skill_config(deps)
	var skill_name: String = DARK_BLADE if dark_mode else BLADE_RUSH
	var cost: float = _get_blade_skill_cost(skill_config, deps, skill_name)
	var next_gauge: float = max(0.0, special_gauge - cost)
	if trigger_cooldown:
		_trigger_configured_skill_cooldown(skill_name, skill_config, deps, now_msec)
	_trigger_orb_gauge_spin(deps, now_msec)
	runtime_action_router.trigger_feedback(deps, 0.10 if dark_mode else 0.08, 4.2 if dark_mode else 3.4)
	runtime_action_router.interrupt_viper_jetpack_thrust(deps)
	var blade_audio: Object = deps.get("audio", null)
	if blade_audio != null and blade_audio.has_method("play_viper_blade_spin"):
		blade_audio.play_viper_blade_spin()
		blade_spin_sound_active = true
		blade_spin_audio = blade_audio
	var start_pos: Vector2 = ViperSkillGeometry.blade_motion_start_position(
		player_pos,
		ViperSkillGeometry.player_floor_y(config),
		pop_up_from_combo,
		BLADE_COMBO_POP_MIN_OFFSET,
		BLADE_COMBO_POP_EXTRA
	)
	blade_motion_active = true
	_enter_blade_spin_phase()
	blade_dark_mode = dark_mode
	blade_motion_start_pos = start_pos
	blade_motion_pos = start_pos
	blade_phase2_base_y = start_pos.y
	blade_paddle_size = ViperSkillGeometry.get_paddle_size(config)
	_reset_blade_motion_combo_windows()
	dark_blade_window = false
	dark_blade_window_frames = 0.0
	core_flip_dark_blade_handoff_frames = 0.0
	if dark_mode:
		_clear_blade_projectile()
	return {
		"handled": true,
		"activated": true,
		"skill_name": skill_name,
		"player_pos": start_pos,
		"player_speed": float(config.get("player_speed", 0.0)),
		"special_gauge": next_gauge,
	}


func _trigger_orb_gauge_spin(deps: Dictionary, now_msec: int) -> void:
	var orb_hud_state: Object = deps.get("orb_hud_state", null)
	if orb_hud_state != null and orb_hud_state.has_method("trigger_gauge_spin"):
		orb_hud_state.trigger_gauge_spin(now_msec)


func _trigger_configured_cooldown_and_orb_gauge_spin(
	skill_name: String,
	skill_config: Object,
	deps: Dictionary,
	now_msec: int
) -> void:
	_trigger_configured_skill_cooldown(skill_name, skill_config, deps, now_msec)
	_trigger_orb_gauge_spin(deps, now_msec)


func _trigger_configured_skill_cooldown(skill_name: String, skill_config: Object, deps: Dictionary, now_msec: int) -> void:
	var skill_state: Object = visibility_query.get_viper_skill_state(deps)
	if skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown(skill_name, now_msec, skill_config)


func _enter_blade_spin_phase() -> void:
	blade_motion_phase = 0
	blade_motion_frames = 0.0
	blade_motion_total_frames = 0.0
	blade_spin_angle = 0.0


func _reset_blade_motion_combo_windows() -> void:
	blade_air_fire_frames = 0.0
	blade_air_combo_window = false
	blade_dark_fire_frames = 0.0
	blade_dark_combo_window = false


func _open_dark_blade_start_window() -> void:
	dark_blade_window = true
	dark_blade_window_frames = DARK_BLADE_WINDOW_FRAMES


func _update_blade_motion(
	delta: float,
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var fps_scale: float = max(0.0, delta * 60.0)
	blade_motion_frames += fps_scale
	blade_motion_total_frames += fps_scale
	var next_pos: Vector2 = player_pos
	var next_speed: float = 0.0
	if not visibility_query.is_dash_motion_busy(deps):
		var input_snapshot: Dictionary = {}
		var input_reader: Object = deps.get("input_reader", null)
		if input_reader != null and input_reader.has_method("get_snapshot"):
			var raw_input_snapshot: Variant = input_reader.get_snapshot()
			if raw_input_snapshot is Dictionary:
				input_snapshot = raw_input_snapshot
		var direction: float = float(input_snapshot.get("direction", 0.0))
		if abs(direction) > 0.01:
			direction = -1.0 if direction < 0.0 else 1.0
		else:
			var left_pressed: bool = bool(input_snapshot.get("left_pressed", false))
			var right_pressed: bool = bool(input_snapshot.get("right_pressed", false))
			direction = 0.0 if left_pressed == right_pressed else (-1.0 if left_pressed else 1.0)
		var movement_result: Dictionary = ViperSkillGeometry.blade_horizontal_control_motion(
			player_pos,
			float(config.get("player_speed", 0.0)),
			direction,
			fps_scale,
			config,
			ViperSkillGeometry.player_floor_y(config),
			ViperSkillGeometry.get_paddle_size(config).x,
			BLADE_JETPACK_MAX_HEIGHT,
			BLADE_AIRBORNE_MOVE_BONUS_MAX,
			blade_dark_mode
		)
		next_pos = _get_vector2(movement_result.get("player_pos", player_pos), player_pos)
		next_speed = float(movement_result.get("player_speed", config.get("player_speed", 0.0)))
	blade_motion_pos.x = next_pos.x
	var spin_frames: float = BLADE_SPIN_FRAMES * (BLADE_DARK_SPIN_MULT if blade_dark_mode else 1.0)
	var decel_frames: float = BLADE_DECEL_FRAMES * (BLADE_DARK_TIME_MULT if blade_dark_mode else 1.0)
	var rest_frames: float = BLADE_DARK_REST_FRAMES if blade_dark_mode else BLADE_REST_FRAMES
	var spin_turns: float = BLADE_DARK_SPIN_TURNS if blade_dark_mode else BLADE_NORMAL_SPIN_TURNS
	if blade_motion_phase < 2:
		blade_motion_pos.y = ViperSkillGeometry.blade_prep_fall_y(
			player_pos.y,
			ViperSkillGeometry.player_floor_y(config),
			fps_scale,
			BLADE_PREP_FALL_SPEED
		)
		next_pos = blade_motion_pos
	if ViperSkillGeometry.blade_dark_should_auto_fire(
		blade_dark_mode,
		blade_motion_phase,
		blade_motion_total_frames,
		DARK_BLADE_AUTO_FIRE_START_FRAMES,
		DARK_BLADE_AUTO_FIRE_END_FRAMES,
		_get_vector2(config.get("ball_vel", Vector2.ZERO), Vector2.ZERO),
		_get_vector2(config.get("ball_pos", Vector2.ZERO), Vector2.ZERO),
		float(config.get("ball_size", DARK_BLADE_DEFAULT_BALL_SIZE)),
		blade_motion_pos,
		ViperSkillGeometry.get_paddle_size(config),
		DARK_BLADE_AUTO_FIRE_NEAR_Y
	):
		blade_motion_phase = 1
		blade_motion_frames = decel_frames
	match blade_motion_phase:
		0:
			var t0: float = ViperSkillGeometry.blade_motion_phase_progress(blade_motion_frames, spin_frames)
			blade_spin_angle = ViperSkillGeometry.blade_motion_spin_angle(0, t0, spin_turns)
			if t0 >= 1.0:
				blade_motion_phase = 1
				blade_motion_frames = 0.0
			next_pos = blade_motion_pos
		1:
			var t1: float = ViperSkillGeometry.blade_motion_phase_progress(blade_motion_frames, decel_frames)
			blade_spin_angle = ViperSkillGeometry.blade_motion_spin_angle(1, t1, spin_turns)
			if t1 >= 1.0:
				blade_motion_phase = 2
				blade_motion_frames = 0.0
				blade_spin_angle = 0.0
				blade_phase2_base_y = min(blade_motion_pos.y, ViperSkillGeometry.player_floor_y(config))
				audio_router.stop_blade_spin_sound(self, deps)
				_launch_blade_projectile(blade_motion_pos, config, deps)
			next_pos = blade_motion_pos
		2:
			var floor_y: float = ViperSkillGeometry.player_floor_y(config)
			var jump_up_frames: float = 27.0 if blade_dark_mode else 18.0
			var jump_peak: float = 320.0 if blade_dark_mode else 80.0
			next_pos = ViperSkillGeometry.blade_motion_rest_position(
				blade_motion_pos.x,
				blade_phase2_base_y,
				floor_y,
				blade_motion_frames,
				jump_up_frames,
				rest_frames,
				jump_peak
			)
			blade_motion_pos = next_pos
			if blade_motion_frames >= rest_frames:
				next_pos = Vector2(blade_motion_pos.x, floor_y)
				_reset_blade_motion_only()
				runtime_action_router.force_viper_jetpack_land(deps)
	blade_motion_pos = next_pos
	return {
		"handled": true,
		"activated": false,
		"skill_name": DARK_BLADE if blade_dark_mode else BLADE_RUSH,
		"player_pos": next_pos,
		"player_speed": next_speed,
		"special_gauge": special_gauge,
	}


func _launch_blade_projectile(player_pos: Vector2, config: Dictionary, deps: Dictionary) -> void:
	audio_router.play_blade_fire_sound(deps)
	var spec: Dictionary = ViperSkillGeometry.blade_projectile_launch_spec(
		player_pos,
		ViperSkillGeometry.get_paddle_size(config),
		visibility_query.get_runtime_skill_level(deps, "blade_amp"),
		blade_dark_mode,
		BLADE_BASE_WIDTH,
		BLADE_BASE_RANGE,
		-20.0
	)
	var size_mult: float = float(spec.get("size_mult", 1.0))
	var range_mult: float = float(spec.get("range_mult", 1.0))
	var launch_pos: Vector2 = _get_vector2(spec.get("pos", Vector2.ZERO), Vector2.ZERO)
	var start_y: float = float(spec.get("start_y", launch_pos.y))
	blade_projectile_active = true
	blade_projectile_pos = launch_pos
	blade_projectile_start_y = start_y
	blade_projectile_target_y = float(spec.get("target_y", start_y))
	blade_projectile_width = float(spec.get("width", BLADE_BASE_WIDTH))
	_reset_primary_blade_projectile_runtime_state()
	if blade_dark_mode:
		blade_dark_fire_frames = 0.0
		blade_dark_combo_window = false
	else:
		blade_air_fire_frames = 0.0
		blade_air_combo_window = false
		nerve_strike_combo_used = false
	var impact_effects: Object = deps.get("impact_effects", null)
	if impact_effects != null and impact_effects.has_method("create_energy_explosion"):
		impact_effects.create_energy_explosion(
			blade_projectile_pos,
			0.72 if blade_dark_mode else 0.58,
			0.88 if blade_dark_mode else 0.72
		)
	_spawn_dual_glitch_clone_blades_for_current_cast(deps, blade_dark_mode, size_mult, range_mult)


func _reset_primary_blade_projectile_runtime_state() -> void:
	blade_projectile_hit_ball = false
	blade_projectile_trail.clear()
	blade_projectile_fadeout = false
	blade_projectile_fadeout_frames = 0.0


func _advance_blade_projectile(fps_scale: float, scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var blade_amp_level: int = max(0, visibility_query.get_runtime_skill_level(deps, "blade_amp"))
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", context.get("ball_pos", Vector2.ZERO)), Vector2.ZERO)
	blade_projectile_pos = ViperSkillGeometry.blade_projectile_motion(
		blade_projectile_pos,
		ball_pos,
		fps_scale,
		BLADE_PROJECTILE_SPEED,
		blade_amp_level,
		blade_dark_mode,
		ViperSkillGeometry.blade_projectile_allows_homing(
			blade_projectile_hit_ball,
			blade_projectile_fadeout
		)
	)
	blade_projectile_trail = ViperSkillGeometry.blade_projectile_trail_next(
		blade_projectile_trail,
		blade_projectile_pos,
		BLADE_TRAIL_MAX
	)
	var projectile_rect: Rect2 = ViperSkillGeometry.blade_rect(blade_projectile_pos, blade_projectile_width, blade_dark_mode, BLADE_HITBOX_HEIGHT, BLADE_DARK_HITBOX_HEIGHT)
	_destroy_blade_stage2_rocks(projectile_rect, deps, context)
	if ViperSkillGeometry.blade_projectile_hits_ball(
		projectile_rect,
		ViperSkillGeometry.ball_rect(scene, context),
		bool(context.get("ball_active", false)),
		blade_projectile_hit_ball,
		blade_projectile_fadeout
	):
		blade_projectile_hit_ball = true
		result = _apply_blade_hit(scene, context, deps, blade_dark_mode, true, true, true, 1.0)
	if ViperSkillGeometry.blade_projectile_should_start_fadeout(
		blade_projectile_pos.y,
		blade_projectile_target_y,
		blade_projectile_fadeout
	):
		blade_projectile_fadeout = true
		blade_projectile_fadeout_frames = BLADE_FADEOUT_FRAMES
	var fadeout_tick: Dictionary = ViperSkillGeometry.blade_projectile_fadeout_tick(
		blade_projectile_fadeout,
		blade_projectile_fadeout_frames,
		fps_scale
	)
	blade_projectile_fadeout_frames = float(fadeout_tick.get("frames", blade_projectile_fadeout_frames))
	if bool(fadeout_tick.get("expired", false)):
		_clear_blade_projectile()
	return result


func _advance_blade_followup_projectiles(fps_scale: float, scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var updated: Array = []
	var blade_amp_level: int = max(0, visibility_query.get_runtime_skill_level(deps, "blade_amp"))
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", context.get("ball_pos", Vector2.ZERO)), Vector2.ZERO)
	for projectile_value in blade_followup_projectiles:
		if not (projectile_value is Dictionary):
			continue
		var projectile: Dictionary = projectile_value
		var dark_mode: bool = bool(projectile.get("dark_mode", false))
		var pos: Vector2 = _get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
		pos = ViperSkillGeometry.blade_projectile_motion(
			pos,
			ball_pos,
			fps_scale,
			BLADE_PROJECTILE_SPEED,
			blade_amp_level,
			dark_mode,
			ViperSkillGeometry.blade_projectile_allows_homing(
				bool(projectile.get("hit_ball", false)),
				bool(projectile.get("fadeout", false))
			)
		)
		projectile["pos"] = pos
		var trail: Array = projectile.get("trail", [])
		projectile["trail"] = ViperSkillGeometry.blade_projectile_trail_next(
			trail,
			pos,
			BLADE_FOLLOWUP_TRAIL_MAX
		)
		var projectile_rect := ViperSkillGeometry.blade_rect(
			pos,
			float(projectile.get("width", BLADE_BASE_WIDTH)),
			dark_mode,
			BLADE_HITBOX_HEIGHT,
			BLADE_DARK_HITBOX_HEIGHT
		)
		_destroy_blade_stage2_rocks(projectile_rect, deps, context)
		if ViperSkillGeometry.blade_projectile_hits_ball(
			projectile_rect,
			ViperSkillGeometry.ball_rect(scene, context),
			bool(context.get("ball_active", false)),
			bool(projectile.get("hit_ball", false)),
			bool(projectile.get("fadeout", false))
		):
			projectile["hit_ball"] = true
			result = _apply_blade_hit(
				scene,
				context,
				deps,
				dark_mode,
				bool(projectile.get("allow_gold", false)),
				bool(projectile.get("allow_followup", false)),
				bool(projectile.get("allow_combo", false)),
				float(projectile.get("hit_speed_scale", 1.0))
			)
			projectile["fadeout"] = true
			projectile["fadeout_frames"] = BLADE_FADEOUT_FRAMES
		if ViperSkillGeometry.blade_projectile_should_start_fadeout(
			pos.y,
			float(projectile.get("target_y", pos.y)),
			bool(projectile.get("fadeout", false))
		):
			projectile["fadeout"] = true
			projectile["fadeout_frames"] = BLADE_FADEOUT_FRAMES
		var fadeout_frames: float = float(projectile.get("fadeout_frames", 0.0))
		var fadeout_tick: Dictionary = ViperSkillGeometry.blade_projectile_fadeout_tick(
			bool(projectile.get("fadeout", false)),
			fadeout_frames,
			fps_scale
		)
		projectile["fadeout_frames"] = float(fadeout_tick.get("frames", fadeout_frames))
		if bool(fadeout_tick.get("expired", false)):
			continue
		updated.append(projectile)
	blade_followup_projectiles = updated
	return result


func _apply_blade_hit(
	scene: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	dark_mode: bool,
	allow_gold: bool,
	allow_followup: bool,
	allow_combo: bool,
	hit_speed_scale: float
) -> Dictionary:
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", context.get("ball_pos", Vector2.ZERO)), Vector2.ZERO)
	var ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", context.get("ball_vel", Vector2.ZERO)), Vector2.ZERO)
	var impact_boost: float = max(1.0, float(scene.get("ball_impact_boost", 1.0)))
	var speed_cap: float = DARK_BLADE_MAX_BALL_SPEED if dark_mode else AIR_BLADE_MAX_BALL_SPEED
	var next_vel: Vector2 = ViperSkillGeometry.blade_hit_velocity(
		ball_vel,
		impact_boost,
		speed_cap,
		visibility_query.get_runtime_skill_level(deps, "blade_amp"),
		dark_mode,
		hit_speed_scale,
		AIR_BLADE_HIT_SPEED_MULT,
		DARK_BLADE_HIT_SPEED_MULT
	)
	blade_hit_speed_cap_active = speed_cap
	var released_chaos: bool = _release_chaos_blackhole_from_hit_result(deps, context)
	if dark_mode and allow_combo:
		var skill_config: Object = visibility_query.get_viper_skill_config(deps)
		if (
			visibility_query.is_skill_equipped(skill_config, MARSHAL_KICK)
			and visibility_query.context_has_enough_gauge(context, visibility_query.get_marshal_skill_cost(skill_config, MARSHAL_KICK, PHANTOM_KICK))
			and visibility_query.is_configured_skill_ready(MARSHAL_KICK, deps, -1)
		):
			marshal_ready = true
			marshal_ready_frames = MARSHAL_KICK_READY_FRAMES
			marshal_phantom_allowed = false
			_clear_double_marshal_ready_window()
			_clear_marshal_first_hit_pending()
	runtime_action_router.trigger_feedback(
		deps,
		DARK_BLADE_HIT_SHAKE_AMOUNT if dark_mode else AIR_BLADE_HIT_SHAKE_AMOUNT,
		DARK_BLADE_HIT_SHAKE_INTENSITY if dark_mode else AIR_BLADE_HIT_SHAKE_INTENSITY
	)
	var pulse_kind: String = DARK_BLADE_HIT_PULSE_KIND if dark_mode else AIR_BLADE_HIT_PULSE_KIND
	var pulse_intensity: float = DARK_BLADE_HIT_PULSE_INTENSITY if dark_mode else AIR_BLADE_HIT_PULSE_INTENSITY
	if not _register_ball_hit_pulse(ball_pos, next_vel, deps, pulse_intensity, pulse_kind):
		var hit_color := DARK_BLADE_FALLBACK_HIT_COLOR if dark_mode else AIR_BLADE_FALLBACK_HIT_COLOR
		_spawn_fallback_hit_impact(
			ball_pos,
			next_vel,
			deps,
			hit_color,
			DARK_BLADE_FALLBACK_PARTICLE_INTENSITY if dark_mode else AIR_BLADE_FALLBACK_PARTICLE_INTENSITY,
			DARK_BLADE_FALLBACK_EXPLOSION_SCALE if dark_mode else AIR_BLADE_FALLBACK_EXPLOSION_SCALE,
			DARK_BLADE_FALLBACK_EXPLOSION_INTENSITY if dark_mode else AIR_BLADE_FALLBACK_EXPLOSION_INTENSITY
		)
	if allow_followup:
		var blade_amp_level: int = max(0, visibility_query.get_runtime_skill_level(deps, "blade_amp"))
		var chance_pct: int = skill_scaling.get_blade_amp_followup_chance_pct(blade_amp_level)
		if chance_pct > 0 and randf() < float(chance_pct) / 100.0:
			var player_pos: Vector2 = _get_vector2(context.get("player_pos", blade_motion_pos), blade_motion_pos)
			var player_size: Vector2 = _get_vector2(context.get("player_paddle_size", blade_paddle_size), blade_paddle_size)
			var spec: Dictionary = ViperSkillGeometry.blade_projectile_launch_spec(
				player_pos,
				player_size,
				blade_amp_level,
				dark_mode,
				BLADE_BASE_WIDTH,
				BLADE_BASE_RANGE,
				BLADE_FOLLOWUP_START_Y_OFFSET,
				BLADE_AMP_FOLLOWUP_WIDTH_SCALE,
				BLADE_AMP_FOLLOWUP_RANGE_SCALE,
				BLADE_AMP_FOLLOWUP_MIN_WIDTH
			)
			var followup_pos: Vector2 = _get_vector2(spec.get("pos", Vector2.ZERO), Vector2.ZERO)
			var start_y: float = float(spec.get("start_y", followup_pos.y))
			_append_blade_followup_projectile(
				followup_pos,
				start_y,
				float(spec.get("target_y", start_y)),
				float(spec.get("width", BLADE_BASE_WIDTH)),
				dark_mode,
				BLADE_AMP_FOLLOWUP_HIT_SPEED_SCALE,
				{}
			)
	var result := {
		"ball_vel": next_vel,
		"ball_impact_boost": impact_boost,
		"player_collision_cooldown": max(BLADE_HIT_PLAYER_COLLISION_COOLDOWN, float(scene.get("player_collision_cooldown", 0.0))),
	}
	if allow_gold:
		result.merge(runtime_action_router.award_skill_gold(deps, BLADE_HIT_GOLD), true)
	return _mark_result_released_chaos_hit(result, released_chaos)


func _spawn_dual_glitch_clone_blades_for_current_cast(
	deps: Dictionary,
	dark_mode: bool,
	size_mult: float,
	range_mult: float
) -> void:
	if not _is_dual_glitch_clone_replication_active(deps):
		return
	var origins: Array = visibility_query.get_dual_glitch_replication_origins(_get_dual_glitch_clone_rect_entries(true, false))
	if origins.is_empty():
		return
	var width: float = BLADE_BASE_WIDTH * max(BLADE_DUAL_GLITCH_REPLICA_MIN_SCALE, size_mult)
	var travel: float = BLADE_BASE_RANGE * max(BLADE_DUAL_GLITCH_REPLICA_MIN_SCALE, range_mult)
	for origin_value in origins:
		if not (origin_value is Dictionary):
			continue
		var origin: Dictionary = origin_value
		var start_y: float = float(origin.get("y", dual_glitch_base_pos.y)) + BLADE_FOLLOWUP_START_Y_OFFSET
		_append_blade_followup_projectile(
			Vector2(float(origin.get("x", dual_glitch_base_pos.x)), start_y),
			start_y,
			start_y - travel,
			width,
			dark_mode,
			BLADE_DUAL_GLITCH_REPLICA_HIT_SPEED_SCALE,
			{
				"dual_glitch_replica": true,
				"side": int(origin.get("side", 0)),
			}
		)


func _append_blade_followup_projectile(
	pos: Vector2,
	start_y: float,
	target_y: float,
	width: float,
	dark_mode: bool,
	hit_speed_scale: float,
	extra_fields: Dictionary
) -> void:
	var projectile := {
		"pos": pos,
		"start_y": start_y,
		"target_y": target_y,
		"width": width,
		"dark_mode": dark_mode,
		"trail": [],
		"fadeout": false,
		"fadeout_frames": 0.0,
		"hit_ball": false,
		"allow_gold": false,
		"allow_followup": false,
		"allow_combo": false,
		"hit_speed_scale": hit_speed_scale,
	}
	for key in extra_fields.keys():
		projectile[key] = extra_fields[key]
	blade_followup_projectiles.append(projectile)


func _destroy_blade_stage2_rocks(blade_rect: Rect2, deps: Dictionary, context: Dictionary) -> int:
	if int(context.get("current_stage", 1)) != 2:
		return 0
	var hit_count := 0
	var seen_instance_ids: Dictionary = {}
	for key in ["stage_background", "stage2_pillar_background"]:
		var target: Object = deps.get(key, null)
		if target == null or not target.has_method("resolve_blade_projectile_collision"):
			continue
		var instance_id: int = target.get_instance_id()
		if seen_instance_ids.has(instance_id):
			continue
		seen_instance_ids[instance_id] = true
		hit_count += max(0, int(target.resolve_blade_projectile_collision(blade_rect, deps, context)))
	return hit_count


func _get_blade_skill_cost(skill_config: Object, deps: Dictionary, skill_name: String) -> float:
	return skill_scaling.get_blade_skill_cost(visibility_query.get_skill_cost(skill_config, skill_name), visibility_query.get_runtime_skill_level(deps, "blade_amp"), skill_name, BLADE_RUSH, DARK_BLADE)


func _register_ball_hit_pulse(ball_pos: Vector2, ball_vel: Vector2, deps: Dictionary, intensity: float, kind: String) -> bool:
	return particle_drawer.register_ball_hit_pulse(ball_pos, ball_vel, deps.get("ball_effects", null), intensity, kind)


func _spawn_fallback_hit_impact(
	ball_pos: Vector2,
	impact_velocity: Vector2,
	deps: Dictionary,
	hit_color: Color,
	particle_intensity: float,
	explosion_scale: float,
	explosion_intensity: float
) -> void:
	particle_drawer.spawn_fallback_hit_impact(
		ball_pos,
		impact_velocity,
		deps.get("impact_effects", null),
		hit_color,
		particle_intensity,
		explosion_scale,
		explosion_intensity
	)


func _reset_blade_motion_only(deps: Dictionary = {}) -> void:
	audio_router.stop_blade_spin_sound(self, deps)
	blade_motion_active = false
	_enter_blade_spin_phase()
	blade_dark_mode = false
	blade_motion_start_pos = Vector2.ZERO
	blade_motion_pos = Vector2.ZERO
	blade_phase2_base_y = 0.0
	blade_paddle_size = Vector2(155.0, 50.0)
	_reset_blade_motion_combo_windows()


func _clear_blade_projectile() -> void:
	blade_projectile_active = false
	blade_projectile_pos = Vector2.ZERO
	blade_projectile_start_y = 0.0
	blade_projectile_target_y = 0.0
	blade_projectile_width = BLADE_BASE_WIDTH
	_reset_primary_blade_projectile_runtime_state()


func _update_marshal_kick(
	delta: float,
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var fps_scale: float = delta * 60.0
	marshal_phase_frames += fps_scale
	var result := {
		"handled": true,
		"activated": false,
		"skill_name": PHANTOM_KICK if marshal_is_double else MARSHAL_KICK,
		"player_pos": player_pos,
		"player_speed": 0.0,
		"special_gauge": special_gauge,
	}
	var next_pos: Vector2 = _update_marshal_phase_position(player_pos, config, deps, result)
	marshal_visual_pos = next_pos
	result["player_pos"] = next_pos
	return result


func _update_marshal_phase_position(player_pos: Vector2, config: Dictionary, deps: Dictionary, result: Dictionary) -> Vector2:
	var next_pos: Vector2 = player_pos
	match marshal_phase:
		0:
			next_pos = _update_marshal_jump_phase(config, deps)
		1:
			next_pos = _update_marshal_cling_phase(config, deps)
		3:
			next_pos = _update_marshal_reclimb_phase(config, deps)
		6:
			if not dmk_freeze_active:
				_enter_marshal_charge(config, deps)
			next_pos = marshal_wall_pos
		2:
			next_pos = _update_marshal_charge_phase(config, deps, result)
		5:
			if not dmk_freeze_active:
				_enter_marshal_return(marshal_return_start_pos)
			next_pos = marshal_return_start_pos
		4:
			next_pos = _update_marshal_return_phase(config)
	return next_pos


func _update_marshal_jump_phase(config: Dictionary, deps: Dictionary) -> Vector2:
	var jump_progress: float = ViperSkillGeometry.marshal_phase_progress(
		marshal_phase_frames,
		_get_marshal_duration_frames(MARSHAL_KICK_JUMP_FRAMES, deps, true)
	)
	var next_pos: Vector2 = ViperSkillGeometry.marshal_jump_position(marshal_start_pos, marshal_wall_pos, jump_progress)
	_set_marshal_web_line_to_wall(next_pos, config)
	_spawn_marshal_motion_particle(ViperSkillGeometry.player_center(next_pos, config), "trail", 0.65)
	if jump_progress >= 1.0:
		_enter_marshal_phase(1, marshal_wall_pos)
		runtime_action_router.trigger_feedback(deps, 0.08, 3.0)
	return next_pos


func _update_marshal_cling_phase(config: Dictionary, deps: Dictionary) -> Vector2:
	var cling_progress: float = ViperSkillGeometry.marshal_phase_progress(
		marshal_phase_frames,
		_get_marshal_duration_frames(MARSHAL_KICK_CLING_FRAMES, deps)
	)
	if cling_progress >= 1.0:
		var ball_pos: Vector2 = ViperSkillGeometry.get_ball_pos(config)
		var marshal_wall_center: Vector2 = ViperSkillGeometry.player_center(marshal_wall_pos, config)
		if ViperSkillGeometry.marshal_should_reclimb(ball_pos, marshal_wall_center, MARSHAL_KICK_RECLIMB_THRESHOLD):
			_enter_marshal_reclimb_from_cling(ball_pos, marshal_wall_center, config, deps)
		elif marshal_is_double:
			_enter_marshal_freeze_phase(6, deps)
		else:
			_enter_marshal_charge(config, deps)
	return marshal_wall_pos


func _enter_marshal_reclimb_from_cling(ball_pos: Vector2, marshal_wall_center: Vector2, config: Dictionary, deps: Dictionary) -> void:
	marshal_reclimb_start_pos = marshal_wall_pos
	marshal_wall_pos = ViperSkillGeometry.marshal_reclimb_wall_target(
		marshal_wall_center,
		ball_pos,
		ViperSkillGeometry.get_paddle_size(config),
		float(config.get("width", config.get("play_right", 760.0))),
		MARSHAL_KICK_WALL_INSET,
		-50.0,
		120.0,
		650.0
	)
	_enter_marshal_phase(3, marshal_reclimb_start_pos)
	_set_marshal_web_line_to_wall(marshal_reclimb_start_pos, config)
	audio_router.play_marshal_backstep_sound(deps)


func _update_marshal_reclimb_phase(config: Dictionary, deps: Dictionary) -> Vector2:
	var reclimb_progress: float = ViperSkillGeometry.marshal_phase_progress(
		marshal_phase_frames,
		_get_marshal_duration_frames(MARSHAL_KICK_RECLIMB_FRAMES, deps)
	)
	var next_pos: Vector2 = ViperSkillGeometry.marshal_reclimb_position(marshal_reclimb_start_pos, marshal_wall_pos, reclimb_progress)
	_set_marshal_web_line_to_wall(next_pos, config)
	_spawn_marshal_motion_particle(ViperSkillGeometry.player_center(next_pos, config), "trail", 0.8)
	if reclimb_progress >= 1.0:
		runtime_action_router.trigger_feedback(deps, 0.06, 2.0)
		marshal_web_lines.clear()
		if marshal_is_double:
			_enter_marshal_freeze_phase(6, deps)
		else:
			_enter_marshal_charge(config, deps)
	return next_pos


func _update_marshal_charge_phase(config: Dictionary, deps: Dictionary, result: Dictionary) -> Vector2:
	var charge_progress: float = ViperSkillGeometry.marshal_phase_progress(
		marshal_phase_frames,
		_get_marshal_duration_frames(MARSHAL_KICK_CHARGE_FRAMES, deps, true)
	)
	var charge_ball_pos: Vector2 = ViperSkillGeometry.get_ball_pos(config)
	marshal_charge_target_pos = charge_ball_pos
	var next_pos: Vector2 = ViperSkillGeometry.marshal_charge_position(
		marshal_charge_start_pos,
		charge_ball_pos,
		ViperSkillGeometry.get_paddle_size(config),
		charge_progress
	)
	_spawn_marshal_motion_particle(ViperSkillGeometry.player_center(next_pos, config), "charge", 0.75)
	if not marshal_ball_hit:
		var ball_pos: Vector2 = ViperSkillGeometry.get_ball_pos(config)
		var player_center: Vector2 = ViperSkillGeometry.player_center(next_pos, config)
		if ViperSkillGeometry.marshal_charge_hits_ball(player_center, ball_pos, MARSHAL_KICK_HIT_RADIUS):
			marshal_ball_hit = true
			marshal_hit_msec = Time.get_ticks_msec()
			marshal_last_hit_pos = ball_pos
			var current_vel: Vector2 = _get_vector2(config.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
			var current_speed: float = current_vel.length()
			var next_speed: float = skill_scaling.get_marshal_hit_speed(
				current_speed,
				visibility_query.get_runtime_skill_level(deps, "kick_enhance"),
				marshal_is_double,
				MARSHAL_KICK_SPEED_MULT,
				MARSHAL_KICK_MIN_SPEED,
				MARSHAL_KICK_DOUBLE_SPEED_MULT,
				MARSHAL_KICK_DOUBLE_MIN_SPEED
			)
			var width: float = float(config.get("width", config.get("play_right", 760.0)))
			var kick_dir: int = ViperSkillGeometry.marshal_wall_kick_dir(ViperSkillGeometry.player_center(marshal_wall_pos, config), width)
			var aim_level: int = visibility_query.get_runtime_skill_level(deps, "kick_enhance")
			var boss_pos: Vector2 = _get_vector2(
				config.get("boss_pos", Vector2(float(config.get("width", 760.0)) * 0.5, 25.0)),
				Vector2.ZERO
			)
			var angle: float = ViperSkillGeometry.marshal_launch_angle(kick_dir, ball_pos, boss_pos, aim_level, marshal_is_double)
			var next_vel: Vector2 = ViperSkillGeometry.aimed_kick_launch_velocity(next_speed, angle)
			var released_chaos: bool = _release_chaos_blackhole_from_hit_result(deps, config)
			var curve_frames: float = MARSHAL_KICK_CURVE_FRAMES * (MARSHAL_DOUBLE_HIT_CURVE_FRAMES_MULT if marshal_is_double else 1.0)
			var curve_dir: int = 1 if next_vel.x > 0.0 else -1
			_set_shadow_curve(curve_frames, MARSHAL_KICK_CURVE_FORCE, curve_dir)
			shadow_starburst_active = true
			shadow_starburst_pos = ball_pos
			shadow_starburst_frame = 0
			shadow_starburst_timer = 0.0
			shadow_starburst_is_double = marshal_is_double
			if visibility_query.is_skill_equipped(visibility_query.get_viper_skill_config(deps), DARK_BLADE):
				_open_dark_blade_start_window()
			runtime_action_router.trigger_feedback(
				deps,
				MARSHAL_DOUBLE_HIT_SHAKE_AMOUNT if marshal_is_double else MARSHAL_HIT_SHAKE_AMOUNT,
				MARSHAL_DOUBLE_HIT_SHAKE_INTENSITY if marshal_is_double else MARSHAL_HIT_SHAKE_INTENSITY
			)
			var pulse_kind: String = MARSHAL_DOUBLE_HIT_PULSE_KIND if marshal_is_double else MARSHAL_HIT_PULSE_KIND
			var pulse_intensity: float = MARSHAL_DOUBLE_HIT_ENERGY_INTENSITY if marshal_is_double else MARSHAL_HIT_ENERGY_INTENSITY
			var pulse_registered := _register_ball_hit_pulse(ball_pos, next_vel, deps, pulse_intensity, pulse_kind)
			if not pulse_registered:
				_spawn_fallback_hit_impact(
					ball_pos,
					next_vel,
					deps,
					MARSHAL_FALLBACK_HIT_COLOR,
					MARSHAL_DOUBLE_HIT_PARTICLE_INTENSITY if marshal_is_double else MARSHAL_HIT_PARTICLE_INTENSITY,
					MARSHAL_DOUBLE_HIT_ENERGY_SCALE if marshal_is_double else MARSHAL_HIT_ENERGY_SCALE,
					MARSHAL_DOUBLE_HIT_ENERGY_INTENSITY if marshal_is_double else MARSHAL_HIT_ENERGY_INTENSITY
				)
			for _i in range(MARSHAL_DOUBLE_HIT_MOTION_PARTICLE_COUNT if marshal_is_double else MARSHAL_HIT_MOTION_PARTICLE_COUNT):
				_spawn_marshal_motion_particle(
					ball_pos + Vector2(
						randf_range(-MARSHAL_HIT_MOTION_PARTICLE_SPREAD, MARSHAL_HIT_MOTION_PARTICLE_SPREAD),
						randf_range(-MARSHAL_HIT_MOTION_PARTICLE_SPREAD, MARSHAL_HIT_MOTION_PARTICLE_SPREAD)
					),
					MARSHAL_HIT_MOTION_PARTICLE_KIND,
					MARSHAL_HIT_MOTION_PARTICLE_CHANCE,
					randf_range(MARSHAL_HIT_MOTION_PARTICLE_LIFE_MIN, MARSHAL_HIT_MOTION_PARTICLE_LIFE_MAX)
				)
			_destroy_marshal_impact_objects(ball_pos, deps)
			if marshal_is_double:
				phantom_kick_knockback_pending = true
				phantom_kick_speed_limit_disabled = true
				particle_drawer.spawn_phantom_hit_particles(
					phantom_hit_particles,
					ball_pos,
					PHANTOM_HIT_PARTICLE_COUNT,
					PHANTOM_HIT_PARTICLE_MAX_COUNT
				)
				audio_router.play_phantom_hit_sound(deps)
				_clear_phantom_kick_chain_window()
			else:
				var skill_config: Object = visibility_query.get_viper_skill_config(deps)
				if shadow_was_airborne and marshal_phantom_allowed and _has_phantom_kick_chain_skill(skill_config, deps):
					marshal_first_hit_pending = true
					marshal_first_hit_delay_frames = MARSHAL_KICK_PHANTOM_DELAY_FRAMES
				else:
					_clear_phantom_kick_chain_window()
			_mark_kick_skill_knockback_pending(deps)
			var marshal_hit_result := {
				"ball_vel": next_vel,
				"ball_impact_boost": max(1.0, float(config.get("ball_impact_boost", 1.0))),
				"player_collision_cooldown": max(MARSHAL_HIT_PLAYER_COLLISION_COOLDOWN, float(config.get("player_collision_cooldown", 0.0))),
				"viper_phantom_kick_knockback_pending": phantom_kick_knockback_pending,
			}
			var gold_award: int = MARSHAL_DOUBLE_HIT_GOLD if marshal_is_double else MARSHAL_HIT_GOLD
			if shadow_was_airborne:
				gold_award = int(float(gold_award) * SHADOW_STEP_AIRBORNE_GOLD_MULT)
			marshal_hit_result.merge(runtime_action_router.award_skill_gold(deps, gold_award), true)
			result.merge(_mark_result_released_chaos_hit(marshal_hit_result, released_chaos), true)
			if marshal_is_double:
				marshal_phase = 5
				marshal_phase_frames = 0.0
				marshal_return_start_pos = next_pos
			else:
				_enter_marshal_return(next_pos)
	if charge_progress >= 1.0 and marshal_phase == 2:
		_enter_marshal_return(next_pos)
	return next_pos


func _update_marshal_return_phase(config: Dictionary) -> Vector2:
	var return_progress: float = ViperSkillGeometry.marshal_phase_progress(marshal_phase_frames, MARSHAL_KICK_RETURN_FRAMES)
	var paddle_size: Vector2 = ViperSkillGeometry.get_paddle_size(config)
	var play_left: float = float(config.get("play_left", 0.0))
	var play_right: float = float(config.get("play_right", config.get("width", 760.0)))
	var target_y: float = float(config.get("player_floor_y", float(config.get("height", 750.0)) - paddle_size.y))
	var return_target: Vector2 = ViperSkillGeometry.marshal_return_target(
		marshal_return_start_pos,
		paddle_size,
		play_left,
		play_right,
		target_y
	)
	var next_pos: Vector2 = ViperSkillGeometry.marshal_return_position(marshal_return_start_pos, return_target, return_progress)
	_spawn_marshal_motion_particle(ViperSkillGeometry.player_center(next_pos, config), "trail", 0.4)
	if return_progress >= 1.0:
		next_pos = return_target
		_reset_marshal_runtime_fields()
	return next_pos


func _enter_marshal_phase(next_phase: int, phase_pos: Vector2) -> void:
	marshal_phase = next_phase
	marshal_phase_frames = 0.0
	if next_phase == 1:
		marshal_wall_pos = phase_pos
		marshal_web_lines.clear()


func _enter_marshal_charge(config: Dictionary, deps: Dictionary) -> void:
	marshal_phase = 2
	marshal_phase_frames = 0.0
	marshal_charge_start_pos = marshal_wall_pos
	marshal_charge_target_pos = ViperSkillGeometry.get_ball_pos(config)
	marshal_web_lines.clear()
	audio_router.play_marshal_charge_sound(deps)


func _enter_marshal_return(return_start_pos: Vector2) -> void:
	marshal_phase = 4
	marshal_phase_frames = 0.0
	marshal_return_start_pos = return_start_pos
	marshal_web_lines.clear()


func _enter_marshal_freeze_phase(next_phase: int, deps: Dictionary) -> void:
	marshal_phase = next_phase
	marshal_phase_frames = 0.0
	dmk_freeze_active = true
	dmk_freeze_frames = MARSHAL_KICK_DMK_FREEZE_FRAMES
	dmk_text_active = true
	dmk_text_frames = MARSHAL_KICK_DMK_TEXT_FRAMES + MARSHAL_KICK_DMK_FREEZE_FRAMES
	audio_router.play_phantom_show_sound(deps)


func _reset_marshal_runtime_fields() -> void:
	marshal_active = false
	marshal_phase = 0
	marshal_wall_side = 0
	marshal_phase_frames = 0.0
	marshal_is_double = false
	phantom_aura_active = false
	marshal_paddle_size = Vector2(155.0, 50.0)
	marshal_start_pos = Vector2.ZERO
	marshal_visual_pos = Vector2.ZERO
	marshal_wall_pos = Vector2.ZERO
	marshal_reclimb_start_pos = Vector2.ZERO
	marshal_charge_start_pos = Vector2.ZERO
	marshal_return_start_pos = Vector2.ZERO
	marshal_ball_hit = false
	marshal_activation_msec = -100000
	marshal_hit_msec = -100000
	marshal_last_hit_pos = Vector2.ZERO
	marshal_charge_target_pos = Vector2.ZERO
	marshal_web_lines.clear()


func _start_shadow_step(
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	now_msec: int
) -> Dictionary:
	var skill_config: Object = visibility_query.get_viper_skill_config(deps)
	var player_size: Vector2 = ViperSkillGeometry.get_paddle_size(config)
	var target_pos: Vector2 = ViperSkillGeometry.clamp_player_pos(
		dash_origin_pos,
		float(config.get("play_left", 0.0)),
		float(config.get("play_right", 760.0)),
		player_size.x
	)
	var origin_center: Vector2 = player_pos + player_size * 0.5
	var target_center: Vector2 = target_pos + player_size * 0.5
	var reverse_dir: int = 1 if target_center.x > origin_center.x else -1
	var next_gauge: float = max(0.0, special_gauge - visibility_query.get_skill_cost(skill_config, SHADOW_STEP))
	_trigger_configured_cooldown_and_orb_gauge_spin(SHADOW_STEP, skill_config, deps, now_msec)
	_cancel_dash_until_key_release(deps.get("dash_state", null))
	audio_router.play_shadow_step_sound(deps)
	runtime_action_router.trigger_feedback(deps, 0.10, 5.0)
	particle_drawer.spawn_shadow_activation_feedback(origin_center, deps.get("impact_effects", null), 1.0)
	_prime_shadow_step_runtime(player_size, origin_center, target_center, reverse_dir, deps, now_msec)
	return {
		"handled": true,
		"activated": true,
		"player_pos": target_pos,
		"player_speed": 0.0,
		"special_gauge": next_gauge,
		"skill_name": SHADOW_STEP,
	}


func _prime_shadow_step_runtime(
	player_size: Vector2,
	origin_center: Vector2,
	target_center: Vector2,
	reverse_dir: int,
	deps: Dictionary,
	now_msec: int
) -> void:
	dash_origin_valid = false
	dash_grace_frames = 0.0
	previous_dash_active = false
	previous_dash_recovering = false
	shadow_step_ready_frames = SHADOW_STEP_READY_FRAMES
	shadow_step_activation_msec = now_msec
	shadow_paddle_size = player_size
	shadow_hologram_active = true
	shadow_hologram_frames = 0.0
	shadow_hologram_origin = origin_center
	shadow_hologram_target = target_center
	shadow_hologram_kick_dir = reverse_dir
	shadow_hologram_kick_hit = false
	shadow_hologram_dest_shock_spawned = false
	shadow_wave_active = true
	shadow_wave_pos = origin_center
	shadow_wave_target_x = target_center.x
	shadow_wave_dir = reverse_dir
	shadow_wave_hit_ball = false
	shadow_wave_trail.clear()
	shadow_kick_ready = true
	shadow_kick_ready_frames = SHADOW_STEP_KICK_READY_FRAMES
	shadow_hit_consumed = false
	shadow_was_airborne = visibility_query.is_viper_airborne(deps)
	shadow_marshal_delay_frames = 0.0
	shadow_curve_active = false
	phantom_strike_active = true
	phantom_strike_frames = SHADOW_STEP_PHANTOM_FRAMES
	phantom_strike_curve_dir = reverse_dir


func _reset_shadow_step_runtime() -> void:
	shadow_hologram_active = false
	shadow_hologram_frames = 0.0
	shadow_hologram_origin = Vector2.ZERO
	shadow_hologram_target = Vector2.ZERO
	shadow_hologram_kick_dir = 1
	shadow_hologram_kick_hit = false
	shadow_hologram_dest_shock_spawned = false
	shadow_paddle_size = Vector2(155.0, 50.0)
	shadow_wave_active = false
	shadow_wave_pos = Vector2.ZERO
	shadow_wave_target_x = 0.0
	shadow_wave_dir = 1
	shadow_wave_hit_ball = false
	shadow_wave_trail.clear()
	_clear_shadow_kick_ready()
	shadow_hit_consumed = false
	shadow_was_airborne = false
	shadow_marshal_delay_frames = 0.0
	shadow_curve_active = false
	shadow_curve_timer = 0.0
	shadow_curve_total = 0.0
	shadow_curve_force = 0.0
	shadow_curve_dir = 1
	shadow_starburst_active = false
	shadow_starburst_pos = Vector2.ZERO
	shadow_starburst_frame = 0
	shadow_starburst_timer = 0.0
	shadow_starburst_is_double = false
	phantom_strike_active = false
	phantom_strike_frames = 0.0
	phantom_strike_curve_dir = 1


func _get_shadow_hologram_progress() -> float:
	return ViperSkillGeometry.shadow_step_hologram_progress(
		shadow_hologram_frames,
		SHADOW_STEP_HOLOGRAM_FRAMES
	)


func _build_viper_ball_motion_context(scene: Dictionary, context: Dictionary) -> Dictionary:
	var motion_context: Dictionary = context.duplicate()
	motion_context.merge(scene, true)
	return motion_context


func _try_shadow_hologram_hit(scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	if shadow_hit_consumed or shadow_hologram_kick_hit:
		return {}
	if _get_shadow_hologram_progress() <= 0.30:
		return {}
	var collision_size := Vector2(shadow_paddle_size.x + 60.0, shadow_paddle_size.y + 50.0)
	var hit_rect: Rect2 = ViperSkillGeometry.shadow_step_hologram_hit_rect(
		shadow_hologram_target,
		shadow_paddle_size,
		Vector2(60.0, 50.0)
	)
	if not hit_rect.intersects(ViperSkillGeometry.ball_rect(scene, context)):
		return {}
	shadow_hologram_kick_hit = true
	return _apply_shadow_step_hit(
		hit_rect.get_center(),
		collision_size + Vector2(120.0, 160.0),
		shadow_hologram_kick_dir,
		"hologram",
		scene,
		context,
		deps
	)


func _apply_shadow_step_hit(
	hit_center: Vector2,
	hit_size: Vector2,
	curve_dir: int,
	_source: String,
	scene: Dictionary,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	if shadow_hit_consumed:
		return {}
	shadow_hit_consumed = true
	_clear_shadow_kick_ready()
	shadow_hologram_kick_hit = true
	shadow_wave_hit_ball = true
	phantom_strike_active = false
	phantom_strike_frames = 0.0
	shadow_marshal_delay_frames = SHADOW_STEP_MARSHAL_DELAY_FRAMES
	if not core_flip_consumed and core_flip_last_dash_start_msec > CORE_FLIP_DASH_START_VALID_AFTER_MSEC:
		core_flip_ready_msec = Time.get_ticks_msec()
		core_flip_buffered_until_msec = 0
	if shadow_was_airborne and visibility_query.is_skill_equipped(visibility_query.get_viper_skill_config(deps), DARK_BLADE):
		_open_dark_blade_start_window()

	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", context.get("ball_pos", Vector2.ZERO)), Vector2.ZERO)
	var ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", context.get("ball_vel", Vector2.ZERO)), Vector2.ZERO)
	var hit_profile: Dictionary = ViperSkillGeometry.shadow_step_hit_profile(
		ball_pos,
		hit_center,
		hit_size,
		SHADOW_STEP_HIT_SPEED_MIN,
		SHADOW_STEP_HIT_SPEED_MAX,
		SHADOW_STEP_HIT_CURVE_MIN,
		SHADOW_STEP_HIT_CURVE_MAX,
		SHADOW_STEP_HIT_FORCE_MIN,
		SHADOW_STEP_HIT_FORCE_MAX
	)
	var center_t: float = float(hit_profile.get("center_t", 0.0))
	var speed_mult: float = float(hit_profile.get("speed_mult", SHADOW_STEP_HIT_SPEED_MIN))
	var curve_frames: float = float(hit_profile.get("curve_frames", SHADOW_STEP_HIT_CURVE_MIN))
	var curve_force: float = float(hit_profile.get("curve_force", SHADOW_STEP_HIT_FORCE_MIN))
	var safe_dir: int = 1 if curve_dir >= 0 else -1
	var current_speed: float = ball_vel.length()
	var speed_bonus: float = 1.0 + float(visibility_query.get_runtime_skill_level(deps, "kick_enhance")) * 0.04
	var raw_multiplier: float = speed_mult * speed_bonus
	var multiplier: float = raw_multiplier
	var ball_physics: Object = deps.get("ball_physics", null)
	if ball_physics != null and ball_physics.has_method("apply_dampened_multiplier"):
		multiplier = float(ball_physics.apply_dampened_multiplier(current_speed, raw_multiplier))
	var next_speed: float = max(current_speed * multiplier, SHADOW_STEP_MIN_HIT_SPEED)
	var aim_level: int = visibility_query.get_runtime_skill_level(deps, "kick_enhance")
	var aim_ball_pos: Vector2 = ViperSkillGeometry.get_ball_pos(context)
	var boss_pos: Vector2 = _get_vector2(
		context.get("boss_pos", Vector2(float(context.get("width", 760.0)) * 0.5, 25.0)),
		Vector2(float(context.get("width", 760.0)) * 0.5, 25.0)
	)
	var launch_angle: float = ViperSkillGeometry.aimed_kick_launch_angle(safe_dir, aim_ball_pos, boss_pos, aim_level, 0.24, 15.0)
	var next_vel: Vector2 = ViperSkillGeometry.aimed_kick_launch_velocity(next_speed, launch_angle)
	return _finish_shadow_step_hit(ball_pos, next_vel, center_t, curve_frames, curve_force, safe_dir, scene, context, deps)


func _set_shadow_curve(frames: float, force: float, curve_dir: int) -> void:
	shadow_curve_active = frames > 0.0
	shadow_curve_timer = max(0.0, frames)
	shadow_curve_total = max(1.0, frames)
	shadow_curve_force = max(0.0, force)
	shadow_curve_dir = 1 if curve_dir >= 0 else -1


func _spawn_marshal_motion_particle(pos: Vector2, kind: String, chance: float = 1.0, life_override: float = -1.0) -> void:
	particle_drawer.spawn_marshal_motion_particle(
		marshal_particles,
		pos,
		kind,
		chance,
		life_override,
		MARSHAL_KICK_TRAIL_MAX
	)


func _destroy_marshal_impact_objects(center: Vector2, deps: Dictionary) -> void:
	var seen_instance_ids: Dictionary = {}
	for key in ["stage1_balloon_event", "stage_background", "stage2_pillar_background"]:
		var target: Object = deps.get(key, null)
		if target == null or not target.has_method("absorb_chaos_spear_objects"):
			continue
		var instance_id: int = target.get_instance_id()
		if seen_instance_ids.has(instance_id):
			continue
		seen_instance_ids[instance_id] = true
		target.absorb_chaos_spear_objects(center, MARSHAL_KICK_IMPACT_OBJECT_RADIUS, deps)


func _set_marshal_web_line_to_wall(from_pos: Vector2, config: Dictionary) -> void:
	marshal_web_lines.clear()
	marshal_web_lines.append({
		"from": ViperSkillGeometry.player_center(from_pos, config),
		"to": ViperSkillGeometry.player_center(marshal_wall_pos, config),
	})


func _cancel_dash_until_key_release(dash_state: Object) -> void:
	if dash_state == null:
		return
	if dash_state.has_method("cancel_until_key_release"):
		dash_state.cancel_until_key_release()
	elif dash_state.has_method("reset_round"):
		dash_state.reset_round()


func _get_marshal_duration_frames(base_frames: float, deps: Dictionary, double_fast: bool = false) -> float:
	return skill_scaling.get_marshal_duration_frames(base_frames, visibility_query.get_runtime_skill_level(deps, "kick_enhance"), marshal_is_double, double_fast, MARSHAL_KICK_DOUBLE_FAST_MULT)


func _mark_kick_skill_knockback_pending(deps: Dictionary) -> void:
	kick_skill_knockback_pending_pct = 0
	var level: int = visibility_query.get_runtime_skill_level(deps, "kick_enhance")
	var effective_level: int = max(0, level)
	var chance_pct: int = 0 if effective_level < 3 else min(KICK_ENHANCE_KNOCKBACK_BALL_CHANCE_CAP, (effective_level - 2) * 10)
	if chance_pct <= 0:
		return
	if randf() * 100.0 >= float(chance_pct):
		return
	var bonus_pct: int = 0 if level < 3 else KICK_ENHANCE_KNOCKBACK_BALL_FIXED_PCT
	if bonus_pct <= 0:
		return
	kick_skill_knockback_pending_pct = bonus_pct


func _get_viper_hologram_attack_sheet(kick_dir: int) -> Texture2D:
	return shadow_effect_renderer.get_viper_hologram_attack_sheet(
		self,
		kick_dir,
		VIPER_HOLOGRAM_ATTACK_LEFT_SHEET_PATH,
		VIPER_HOLOGRAM_ATTACK_RIGHT_SHEET_PATH
	)


func _get_viper_hologram_attack_source_region(progress: float) -> Rect2:
	return shadow_effect_renderer.get_viper_hologram_attack_source_region(
		progress,
		VIPER_HOLOGRAM_ATTACK_FRAME_COUNT,
		VIPER_HOLOGRAM_ATTACK_GRID_COLS,
		VIPER_HOLOGRAM_FRAME_SIZE
	)


func _draw_chaos_spear(canvas: CanvasItem, tip: Vector2, angle: float, alpha: float, scale: float) -> void:
	chaos_spear_effect_renderer.draw_chaos_spear(canvas, tip, angle, alpha, scale, CHAOS_VISUAL_LENGTH)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
