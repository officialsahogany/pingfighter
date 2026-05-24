extends RefCounted

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const CommandoFirearmAk47HitState := preload("res://scripts/characters/commando_firearm_ak47_hit_state.gd")
const CommandoFirearmAudioDispatcher := preload("res://scripts/characters/commando_firearm_audio_dispatcher.gd")
const CommandoFirearmBowlingTrapGeometry := preload("res://scripts/characters/commando_firearm_bowling_trap_geometry.gd")
const CommandoFirearmControlState := preload("res://scripts/characters/commando_firearm_control_state.gd")
const CommandoFirearmCooldownState := preload("res://scripts/characters/commando_firearm_cooldown_state.gd")
const CommandoFirearmDrawStateResolver := preload("res://scripts/characters/commando_firearm_draw_state_resolver.gd")
const CommandoFirearmFireResultState := preload("res://scripts/characters/commando_firearm_fire_result_state.gd")
const CommandoFirearmFireSheetResolver := preload("res://scripts/characters/commando_firearm_fire_sheet_resolver.gd")
const CommandoFirearmHitGeometry := preload("res://scripts/characters/commando_firearm_hit_geometry.gd")
const CommandoFirearmHitFeedbackDispatcher := preload("res://scripts/characters/commando_firearm_hit_feedback_dispatcher.gd")
const CommandoFirearmHitResultState := preload("res://scripts/characters/commando_firearm_hit_result_state.gd")
const CommandoFirearmImpactFlashResolver := preload("res://scripts/characters/commando_firearm_impact_flash_resolver.gd")
const CommandoFirearmInputResolver := preload("res://scripts/characters/commando_firearm_input_resolver.gd")
const CommandoFirearmLingeringEffectState := preload("res://scripts/characters/commando_firearm_lingering_effect_state.gd")
const CommandoFirearmLingeringFireFlameState := preload("res://scripts/characters/commando_firearm_lingering_fire_flame_state.gd")
const CommandoFirearmLingeringNetFieldState := preload("res://scripts/characters/commando_firearm_lingering_net_field_state.gd")
const CommandoFirearmLingeringStatusState := preload("res://scripts/characters/commando_firearm_lingering_status_state.gd")
const CommandoFirearmMuzzleFlashResolver := preload("res://scripts/characters/commando_firearm_muzzle_flash_resolver.gd")
const CommandoFirearmOriginGeometry := preload("res://scripts/characters/commando_firearm_origin_geometry.gd")
const CommandoFirearmPendingResultState := preload("res://scripts/characters/commando_firearm_pending_result_state.gd")
const CommandoFirearmPistolFeedbackState := preload("res://scripts/characters/commando_firearm_pistol_feedback_state.gd")
const CommandoFirearmPistolHitState := preload("res://scripts/characters/commando_firearm_pistol_hit_state.gd")
const CommandoFirearmProfileResolver := preload("res://scripts/characters/commando_firearm_profile_resolver.gd")
const CommandoFirearmProjectileImpactState := preload("res://scripts/characters/commando_firearm_projectile_impact_state.gd")
const CommandoFirearmProjectileMotionState := preload("res://scripts/characters/commando_firearm_projectile_motion_state.gd")
const CommandoFirearmProjectileSpawnState := preload("res://scripts/characters/commando_firearm_projectile_spawn_state.gd")
const CommandoFirearmShellCasingState := preload("res://scripts/characters/commando_firearm_shell_casing_state.gd")
const CommandoFirearmSlingshotState := preload("res://scripts/characters/commando_firearm_slingshot_state.gd")
const CommandoFirearmStage2RockInteractionResolver := preload("res://scripts/characters/commando_firearm_stage2_rock_interaction_resolver.gd")
const CommandoFirearmSupportAircraftGeometry := preload("res://scripts/characters/commando_firearm_support_aircraft_geometry.gd")
const CommandoFirearmSupportCallResolver := preload("res://scripts/characters/commando_firearm_support_call_resolver.gd")
const CommandoFirearmSupportProjectileResolver := preload("res://scripts/characters/commando_firearm_support_projectile_resolver.gd")
const CommandoFirearmSuicideDroneBallBoostResolver := preload("res://scripts/characters/commando_firearm_suicide_drone_ball_boost_resolver.gd")
const CommandoFirearmSuicideDroneGeometry := preload("res://scripts/characters/commando_firearm_suicide_drone_geometry.gd")
const CommandoFirearmSuicideDroneState := preload("res://scripts/characters/commando_firearm_suicide_drone_state.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const SWITCH_FIRE_SUPPRESS_MSEC := 70
const FIRE_DEBOUNCE_MSEC := 120
const PROJECTILE_LIMIT := 36
const FLASH_LIMIT := 24
const HIT_EVENT_LIMIT := 20
const LINGERING_EFFECT_LIMIT := 18
const LINGERING_EFFECT_PHASE_STEP := 0.12
const LINGERING_STATUS_TARGET := "boss"
const LINGERING_STATUS_ID_SLOW := "slow"
const LINGERING_STATUS_DEFAULT_DURATION_FRAMES := 18.0
const LINGERING_STATUS_DEFAULT_INTERVAL_FRAMES := 12.0
const LINGERING_STATUS_INITIAL_COOLDOWN_FRAMES := 0.0
const LINGERING_STATUS_DEFAULT_SOURCE := "commando_firearm_lingering"
const LINGERING_STATUS_DEFAULT_SLOW_MULTIPLIER := 1.0
const LINGERING_STATUS_MIN_SLOW_MULTIPLIER := 0.0
const LINGERING_STATUS_MAX_SLOW_MULTIPLIER := 1.0
const SUPPORT_CALL_LIMIT := 4
const SUPPORT_CALL_LOCK_FRAMES := 42.0
const SUPPORT_CALL_DELAY_MIN_FRAMES := 120.0
const SUPPORT_CALL_DELAY_MAX_FRAMES := 180.0
const SUPPORT_BOMB_INTERVAL_FRAMES := 18.0
const SUPPORT_BOMB_MIN_COUNT := 2
const SUPPORT_BOMB_MAX_COUNT := 2
const SUPPORT_BOMB_INITIAL_VY := 0.0
const SUPPORT_BOMB_GRAVITY := 0.0
const SUPPORT_BOMB_HORIZONTAL_JITTER := 0.0
const SUPPORT_BOMB_RANDOM_X_RANGE := CommandoFirearmSupportCallResolver.SUPPORT_BOMB_RANDOM_X_RANGE
const SUPPORT_MISSILE_FLIGHT_FRAMES := 90.0
const SUPPORT_MISSILE_LIFE_FRAMES := 150.0
const SUPPORT_OPPONENT_WALL_Y := 22.0
const SUPPORT_AIRCRAFT_DROP_ARM_FRAMES := 42.0
const SUPPORT_AIRCRAFT_START_X := -360.0
const SUPPORT_AIRCRAFT_FINISH_MARGIN := 360.0
const SUPPORT_AIRCRAFT_Y := 320.0
const SUPPORT_AIRCRAFT_SPEED := 10.8
const SUPPORT_AIRCRAFT_CURVE_AMPLITUDE := 44.0
const SUPPORT_AIRCRAFT_CURVE_FREQUENCY := 0.055
const SUPPORT_AIRCRAFT_CURVE_SECONDARY_RATIO := 0.35
const SUPPORT_AIRCRAFT_COLLISION_SIZE := Vector2(160.0, 50.0)
const BOWLING_TRAP_LIMIT := 6
const BOWLING_TRAP_INSTALL_FRAMES := 48.0
const BOWLING_TRAP_CAPTURE_FRAMES := 90.0
const BOWLING_TRAP_AMMO_MAX := 3
const BOWLING_TRAP_COOLDOWN_FRAMES := 120.0
const BOWLING_TRAP_CONTROL_LOCK_FRAMES := 30.0
const BOWLING_TRAP_WIDTH := 60.0
const BOWLING_TRAP_HEIGHT := 20.0
const BOWLING_TRAP_CAPTURE_HEIGHT := 40.0
const BOWLING_TRAP_CAPTURE_BALL_OFFSET := Vector2(0.0, -15.0)
const BOWLING_TRAP_LAUNCH_SPEED_MULTIPLIER := 4.0
const BOWLING_TRAP_LAUNCH_ANGLE_STEP := PI / 8.0
const BOWLING_TRAP_MIN_FIELD_Y_RATIO := 0.6
const BOWLING_TRAP_GUARD_KNOCKBACK_POWER := 22.0
const BOWLING_TRAP_GUARD_STUN_FRAMES := 60.0
const BOWLING_TRAP_GUARD_KNOCKBACK_FRAMES := 36.0
const BOWLING_TRAP_GUARD_SPEED_REDUCTION := 0.7
const BOWLING_TRAP_GUARD_KNOCKBACK_DECAY := 0.85
const SHELL_CASING_LIMIT := 36
const BASE_WEAPON_ID := "pistol"
const SLINGSHOT_BASE_BULLET_SPEED := 25.0
const PISTOL_BULLET_SPEED := 25.0
const BERETTA_BULLET_SPEED := 30.0
const BERETTA_FIRE_RATE_MULTIPLIER := 2.0
const SLINGSHOT_COOLDOWN_FRAMES := 0.0
const SLINGSHOT_CONTROL_LOCK_FRAMES := 12.0
const SLINGSHOT_GAUGE_COST := 20.0
const SLINGSHOT_GAUGE_DRAIN_INTERVAL_FRAMES := 30.0
const SLINGSHOT_CHARGE_THRESHOLD_1 := 30.0
const SLINGSHOT_CHARGE_THRESHOLD_2 := 90.0
const SLINGSHOT_CHARGE_THRESHOLD_3 := 180.0
const SLINGSHOT_PELLET_SIZE := 6.0
const SLINGSHOT_SPEED_MULT := {1: 0.7, 2: 1.0, 3: 1.3}
const SLINGSHOT_PYTHON_SPEED_BY_LEVEL := {1: 18.0, 2: 25.0, 3: 32.0}
const SLINGSHOT_KNOCKBACK_MULT := {1: 0.7, 2: 1.0, 3: 1.5}
const SLINGSHOT_STUN_MULT := {1: 0.7, 2: 1.0, 3: 1.3}
const PISTOL_BOSS_DAMAGE_HIT_THRESHOLD := 3
const PISTOL_HEAD_SHOT_CHANCE := 0.10
const PISTOL_LEG_SHOT_CHANCE := 0.12
const PISTOL_NORMAL_GAUGE_GAIN := 30.0
const PISTOL_HEAD_SHOT_GAUGE_GAIN := 50.0
const PISTOL_LEG_SHOT_GAUGE_GAIN := 40.0
const PISTOL_HEAD_SHOT_STUN_FRAMES := 90.0
const COMMANDO_PISTOL_HEAD_SHOT_STUN_FRAMES := 108.0
const PISTOL_LEG_SHOT_SLOW_FRAMES := 132.0
const PISTOL_LEG_SHOT_SLOW_MULTIPLIER := 0.70
const PISTOL_BOSS_KNOCKBACK_POWER := 8.0
const PISTOL_BOSS_KNOCKBACK_FRAMES := 18.0
const PISTOL_BOSS_KNOCKBACK_DECAY_PER_FRAME := 0.85
const PISTOL_HIT_TEXT_TIMER_FRAMES := 60.0
const PISTOL_HIT_TUNING := {
	"combo_hit_threshold": PISTOL_BOSS_DAMAGE_HIT_THRESHOLD,
	"normal_gauge_gain": PISTOL_NORMAL_GAUGE_GAIN,
	"head_gauge_gain": PISTOL_HEAD_SHOT_GAUGE_GAIN,
	"leg_gauge_gain": PISTOL_LEG_SHOT_GAUGE_GAIN,
	"base_head_stun_frames": PISTOL_HEAD_SHOT_STUN_FRAMES,
	"commando_head_stun_frames": COMMANDO_PISTOL_HEAD_SHOT_STUN_FRAMES,
	"leg_slow_frames": PISTOL_LEG_SHOT_SLOW_FRAMES,
	"leg_slow_multiplier": PISTOL_LEG_SHOT_SLOW_MULTIPLIER,
	"normal_knockback_power": PISTOL_BOSS_KNOCKBACK_POWER,
	"normal_knockback_frames": PISTOL_BOSS_KNOCKBACK_FRAMES,
	"normal_knockback_decay_per_frame": PISTOL_BOSS_KNOCKBACK_DECAY_PER_FRAME,
	"hit_text_timer_frames": PISTOL_HIT_TEXT_TIMER_FRAMES,
}
const PISTOL_FEEDBACK_LIMIT := 4
const PISTOL_AMMO_MAX := 4
const PISTOL_COOLDOWN_FRAMES := 60.0
const BERETTA_COOLDOWN_FRAMES := PISTOL_COOLDOWN_FRAMES / BERETTA_FIRE_RATE_MULTIPLIER
const PISTOL_CONTROL_LOCK_FRAMES := 18.0
const PISTOL_FIRE_DELAY_FRAMES := 24.0
# Frames the back-view pistol-fire sheet keeps animating AFTER the shot
# resolves. The 24-frame fire-delay window plays the windup (sheet frames
# 0..3, low-ready -> peak aim) and the 18-frame post-fire window plays the
# muzzle / smoke / lower / ready frames (sheet frames 4..7). Frame 4 (muzzle
# flash) is the first cell shown once `CommandoFirearmAudioDispatcher.play_fire_audio()` triggers, so the
# visual flash lines up with `gunshot.wav`.
const PISTOL_POST_FIRE_ANIMATION_FRAMES := 18.0
const COMMANDO_WEAPON_FIRE_SHEET_FRAME_COUNT := 8
const COMMANDO_WEAPON_FIRE_SHEET_DEFAULT_FRAMES := 40.0
const COMMANDO_WEAPON_FIRE_SHEET_LONG_FRAMES := 60.0
# Source-cell muzzle anchors for the standardized 160x160 Commando authored
# fire sheets. These map the gameplay projectile / muzzle-flash origin to the
# visible weapon tip instead of the paddle center.
const COMMANDO_PISTOL_FIRE_MUZZLE_SOURCE := Vector2(118.0, 82.0)
const COMMANDO_BAZOOKA_FIRE_MUZZLE_SOURCE := Vector2(134.0, 69.0)
const COMMANDO_NET_GUN_FIRE_MUZZLE_SOURCE := Vector2(106.0, 82.0)
const COMMANDO_FIRE_SHEET_SOURCE_CELL_SIZE := Vector2(160.0, 160.0)
const COMMANDO_FIRE_SHEET_PLAYER_FOOT_Y_OFFSET := 12.0
const PISTOL_SPREAD_RADIANS := PI / 12.0
const BERETTA_SPREAD_RADIANS := PISTOL_SPREAD_RADIANS * 0.70
const PISTOL_WALL_BOUNCE_MARGIN := 10.0
const PISTOL_WALL_BOUNCE_MAX := 1
const PISTOL_WALL_BOUNCE_DAMPING := 0.85
const PISTOL_EMPTY_RELOAD_GAUGE_COST := 150.0
const PISTOL_SHELL_LIFETIME_FRAMES := 150.0
const PISTOL_PENDING_FIRE_GEOMETRY_KEYS := [
	"player_pos",
	"player_speed",
	"paddle_width",
	"paddle_height",
	"player_paddle_width",
	"player_paddle_height",
	"player_paddle_scale",
	"boss_pos",
	"boss_vel",
	"boss_paddle_width",
	"boss_hitbox_height",
	"width",
	"height",
]
const DOPING_POTION_HEAD_LEG_MULTIPLIER := 2.0
const DOPING_POTION_FIRE_RATE_MULTIPLIER := 0.5
const DOPING_POTION_PISTOL_COOLDOWN_FRAMES := 30.0
const DOPING_POTION_PISTOL_CONTROL_LOCK_FRAMES := 9.0
const DOPING_POTION_PISTOL_SPEED_MULTIPLIER := 1.2
const DOPING_POTION_BERETTA_COOLDOWN_FRAMES := 15.0
const DOPING_POTION_AK47_FIRE_INTERVAL_FRAMES := 3.0
const DOPING_POTION_BAZOOKA_COOLDOWN_FRAMES := 60.0
const DOPING_POTION_BAZOOKA_CONTROL_LOCK_FRAMES := 15.0
const DOPING_POTION_DEFAULTS := {
	"head_leg_multiplier": DOPING_POTION_HEAD_LEG_MULTIPLIER,
	"fire_rate_multiplier": DOPING_POTION_FIRE_RATE_MULTIPLIER,
	"pistol_cooldown_frames": DOPING_POTION_PISTOL_COOLDOWN_FRAMES,
	"pistol_control_lock_frames": DOPING_POTION_PISTOL_CONTROL_LOCK_FRAMES,
	"pistol_speed_multiplier": DOPING_POTION_PISTOL_SPEED_MULTIPLIER,
	"beretta_cooldown_frames": DOPING_POTION_BERETTA_COOLDOWN_FRAMES,
	"ak47_fire_interval_frames": DOPING_POTION_AK47_FIRE_INTERVAL_FRAMES,
	"bazooka_cooldown_frames": DOPING_POTION_BAZOOKA_COOLDOWN_FRAMES,
	"bazooka_control_lock_frames": DOPING_POTION_BAZOOKA_CONTROL_LOCK_FRAMES,
}
const AK47_BOSS_DAMAGE_HIT_THRESHOLD := 20
const AK47_AMMO_MAX := 60
const AK47_DURATION_FRAMES := 1800.0
const AK47_FIRE_INTERVAL_FRAMES := 6.0
const AK47_INITIAL_BURST_SHOTS := 2
const AK47_BULLET_SPEED := 16.0
const AK47_BULLET_LIFE_FRAMES := 60.0
const AK47_BASE_SPREAD_RADIANS := 0.15
const AK47_RECOIL_PER_SHOT := 0.03
const AK47_MAX_RECOIL := 0.15
const AK47_RECOIL_RECOVERY_PER_FRAME := 0.02
const AK47_MOVEMENT_SPEED_MULTIPLIER := 0.5
const AK47_SHELL_LIFETIME_FRAMES := 180.0
const AK47_SHELL_GRAVITY := 0.40
const AK47_SHELL_BOUNCE_DECAY := 0.50
const AK47_SHELL_MAX_BOUNCES := 3
const BAZOOKA_AMMO_MAX := 4
const BAZOOKA_COOLDOWN_FRAMES := 120.0
const BAZOOKA_CONTROL_LOCK_FRAMES := 30.0
const BAZOOKA_FIRE_ANIMATION_FRAMES := 15.0
const BAZOOKA_FIRING_POSE_FRAMES := 30.0
const BAZOOKA_MUZZLE_FLASH_FRAMES := 5.0
const BAZOOKA_INITIAL_SPEED := 3.0
const BAZOOKA_ACCELERATION := 0.8
const BAZOOKA_MAX_SPEED := 35.0
const BAZOOKA_EXPLOSION_RADIUS := 108.5
const BAZOOKA_KNOCKBACK_POWER := 40.0
const BAZOOKA_KNOCKBACK_FRAMES := 18.0
const BAZOOKA_KNOCKBACK_DECAY_PER_FRAME := 0.85
const BAZOOKA_STUN_FRAMES := 90.0
const BAZOOKA_SMOKE_TRAIL_LIMIT := 10
const NET_GUN_AMMO_MAX := 3
const NET_GUN_COOLDOWN_FRAMES := 120.0
const NET_GUN_CONTROL_LOCK_FRAMES := 30.0
const NET_GUN_THROW_POSE_FRAMES := 30.0
const NET_GUN_HARPOON_FLASH_FRAMES := 6.0
const NET_GUN_PROJECTILE_SPEED := 18.0
const NET_GUN_FIELD_DURATION_FRAMES := 240.0
const NET_GUN_DISSOLVE_FRAMES := 21.0
const NET_GUN_DASH_BREAK_FRAMES := 24.0
const NET_GUN_WIDTH := 280.0
const NET_GUN_HEIGHT := 140.0
const NET_GUN_MIN_HEIGHT := 90.0
const NET_GUN_ROPE_TRAIL_LIMIT := 18
const NET_GUN_PLAYER_SLOW_MULTIPLIER := 1.0
const NET_CONSTRICT_STEP := 0.04
const NET_CONSTRICT_MIN := 0.6
const NET_CONSTRICT_WINDOW_MSEC := 400
const SUICIDE_DRONE_AMMO_MAX := 4
const SUICIDE_DRONE_COOLDOWN_FRAMES := 90.0
const SUICIDE_DRONE_GRACE_FRAMES := 6.0
const SUICIDE_DRONE_ACCEL := 1.2
const SUICIDE_DRONE_MAX_SPEED := 14.0
const SUICIDE_DRONE_SIZE := Vector2(48.0, 48.0)
const SUICIDE_DRONE_ROTOR_BASE_SPEED := 18.0
const SUICIDE_DRONE_ROTOR_SPEED_SCALE := 2.0
const SUICIDE_DRONE_BALL_SPEED_MULTIPLIER := 3.0
const SUICIDE_DRONE_BALL_FAN_DEGREES := 25.0
const SUICIDE_DRONE_LIFE_FRAMES := 3600.0

const WEAPON_PROFILES := {
	"pistol": {
		"kind": "bullet",
		"speed": PISTOL_BULLET_SPEED,
		"radius": 4.4,
		"hitbox_size": Vector2(9.0, 9.0),
		"life_frames": 44.0,
		"trail": 30.0,
		"impact_radius": 16.0,
		"color": Color(0.96, 0.82, 0.36),
		"secondary": Color(1.0, 0.52, 0.18),
	},
	"commando_pistol": {
		"kind": "bullet",
		"speed": BERETTA_BULLET_SPEED,
		"radius": 5.0,
		"hitbox_size": Vector2(10.0, 10.0),
		"life_frames": 44.0,
		"trail": 34.0,
		"impact_radius": 16.0,
		"color": Color(1.0, 0.86, 0.40),
		"secondary": Color(1.0, 0.50, 0.18),
	},
	"ak47": {
		"kind": "bullet",
		"speed": AK47_BULLET_SPEED,
		"radius": 3.6,
		"hitbox_size": Vector2(6.0, 6.0),
		"life_frames": AK47_BULLET_LIFE_FRAMES,
		"trail": 40.0,
		"impact_radius": 12.0,
		"color": Color(0.95, 1.0, 0.50),
		"secondary": Color(0.72, 0.94, 0.25),
	},
	"bazooka": {
		"kind": "rocket",
		"speed": BAZOOKA_INITIAL_SPEED,
		"acceleration": BAZOOKA_ACCELERATION,
		"max_speed": BAZOOKA_MAX_SPEED,
		"radius": 9.5,
		"hitbox_size": Vector2(20.0, 30.0),
		"hitbox_offset": Vector2(0.0, 5.0),
		"life_frames": 72.0,
		"trail": 48.0,
		"impact_radius": 46.0,
		"explosion_radius": BAZOOKA_EXPLOSION_RADIUS,
		"smoke_trail_limit": BAZOOKA_SMOKE_TRAIL_LIMIT,
		"vertical_launch": true,
		"muzzle_flash_frames": BAZOOKA_MUZZLE_FLASH_FRAMES,
		"color": Color(1.0, 0.46, 0.18),
		"secondary": Color(1.0, 0.88, 0.38),
	},
	"net_gun": {
		"kind": "net",
		"speed": NET_GUN_PROJECTILE_SPEED,
		"radius": 13.0,
		"hitbox_size": Vector2(12.0, 12.0),
		"boss_inflate": Vector2(60.0, 40.0),
		"segment_radius": 6.0,
		"life_frames": 64.0,
		"trail": 20.0,
		"impact_radius": 36.0,
		"rope_trail_limit": NET_GUN_ROPE_TRAIL_LIMIT,
		"muzzle_flash_frames": NET_GUN_HARPOON_FLASH_FRAMES,
		"color": Color(0.42, 1.0, 0.52),
		"secondary": Color(0.18, 0.65, 0.28),
	},
	"fire_support": {
		"kind": "support",
		"speed": SUPPORT_BOMB_INITIAL_VY,
		"initial_vy": SUPPORT_BOMB_INITIAL_VY,
		"gravity": SUPPORT_BOMB_GRAVITY,
		"horizontal_jitter": SUPPORT_BOMB_HORIZONTAL_JITTER,
		"flight_frames": SUPPORT_MISSILE_FLIGHT_FRAMES,
		"radius": 7.0,
		"hitbox_size": Vector2(14.0, 14.0),
		"life_frames": SUPPORT_MISSILE_LIFE_FRAMES,
		"trail": 52.0,
		"impact_radius": 54.0,
		"explosion_radius": ActiveItemThrowController.GRENADE_EXPLOSION_RADIUS,
		"color": Color(1.0, 0.34, 0.16),
		"secondary": Color(1.0, 0.82, 0.25),
	},
	"bowling_trap": {
		"kind": "trap",
		"speed": 8.5,
		"radius": 12.0,
		"life_frames": 84.0,
		"trail": 22.0,
		"impact_radius": 30.0,
		"color": Color(0.95, 0.18, 0.24),
		"secondary": Color(0.22, 0.10, 0.12),
	},
	"suicide_drone": {
		"kind": "drone",
		"speed": 0.0,
		"radius": 24.0,
		"hitbox_size": SUICIDE_DRONE_SIZE,
		"life_frames": SUICIDE_DRONE_LIFE_FRAMES,
		"trail": 26.0,
		"impact_radius": 40.0,
		"explosion_radius": 150.0,
		"max_speed": SUICIDE_DRONE_MAX_SPEED,
		"acceleration": SUICIDE_DRONE_ACCEL,
		"color": Color(1.0, 0.42, 0.18),
		"secondary": Color(0.45, 0.86, 1.0),
	},
}

const WEAPON_HIT_FEEDBACK := {
	"pistol": {"intensity": 0.46, "shake_amount": 0.040, "shake_intensity": 1.25},
	"commando_pistol": {"intensity": 0.50, "shake_amount": 0.045, "shake_intensity": 1.4},
	"ak47": {"intensity": 0.36, "shake_amount": 0.030, "shake_intensity": 1.1},
	"bazooka": {"intensity": 1.12, "shake_amount": 0.140, "shake_intensity": 3.2},
	"net_gun": {"intensity": 0.76, "shake_amount": 0.070, "shake_intensity": 1.8},
	"fire_support": {"intensity": 1.25, "shake_amount": 0.24, "shake_intensity": 7.0},
	"bowling_trap": {"intensity": 0.82, "shake_amount": 0.085, "shake_intensity": 2.1},
	"suicide_drone": {"intensity": 1.05, "shake_amount": 0.125, "shake_intensity": 3.0},
}

const WEAPON_HIT_RESULTS := {
	"pistol": {
		"stun_frames": 42.0,
		"knockback_power": PISTOL_BOSS_KNOCKBACK_POWER,
		"damage_units": 0,
	},
	"commando_pistol": {
		"stun_frames": 42.0,
		"knockback_power": PISTOL_BOSS_KNOCKBACK_POWER,
		"damage_units": 0,
	},
	"ak47": {
		"stun_frames": 6.0,
		"knockback_power": 6.0,
		"knockback_velocity_scale": 0.35,
		"damage_units": 0,
	},
	"bazooka": {
		"stun_frames": BAZOOKA_STUN_FRAMES,
		"knockback_power": BAZOOKA_KNOCKBACK_POWER,
		"knockback_frames": BAZOOKA_KNOCKBACK_FRAMES,
		"knockback_decay_per_frame": BAZOOKA_KNOCKBACK_DECAY_PER_FRAME,
		"damage_units": 2,
	},
	"net_gun": {
		"damage_units": 0,
	},
	"fire_support": {
		"stun_frames": ActiveItemThrowController.GRENADE_BOSS_STUN_FRAMES,
		"knockback_power": ActiveItemThrowController.GRENADE_BOSS_KNOCKBACK_POWER,
		"knockback_frames": ActiveItemThrowController.GRENADE_BOSS_KNOCKBACK_FRAMES,
		"knockback_decay_per_frame": ActiveItemThrowController.GRENADE_BOSS_KNOCKBACK_DECAY,
		"damage_units": 1,
	},
	"bowling_trap": {
		"stun_frames": 60.0,
		"knockback_power": 7.0,
		"damage_units": 0,
	},
	"suicide_drone": {
		"stun_frames": 48.0,
		"knockback_power": 0.0,
		"damage_units": 0,
	},
}

const WEAPON_LINGERING_EFFECTS := {
	"net_gun": {
		"kind": "net_field",
		"duration_frames": NET_GUN_FIELD_DURATION_FRAMES,
		"dissolve_frames": NET_GUN_DISSOLVE_FRAMES,
		"dash_break_frames": NET_GUN_DASH_BREAK_FRAMES,
		"width": NET_GUN_WIDTH,
		"height": NET_GUN_HEIGHT,
		"min_height": NET_GUN_MIN_HEIGHT,
		"color": Color(0.42, 1.0, 0.52),
		"secondary": Color(0.72, 0.95, 1.0),
	},
	"bowling_trap": {
		"kind": "trap_clamp",
		"duration_frames": 90.0,
		"width": 92.0,
		"height": 42.0,
		"color": Color(0.95, 0.18, 0.24),
		"secondary": Color(0.22, 0.10, 0.12),
	},
	"suicide_drone": {
		"kind": "fire_zone",
		"duration_frames": 150.0,
		"width": 150.0,
		"height": 60.0,
		"color": Color(1.0, 0.28, 0.08),
		"secondary": Color(1.0, 0.78, 0.18),
	},
}

const WEAPON_PROFILE_OVERRIDES := {
	"fire_support": {
		"explosion_radius": ActiveItemThrowController.GRENADE_EXPLOSION_RADIUS,
	},
}
const HIT_FEEDBACK_PROFILE_OVERRIDES := {
	"fire_support": {
		"shake_amount": 0.24,
		"shake_intensity": 7.0,
	},
}
const HIT_RESULT_PROFILE_OVERRIDES := {
	"fire_support": {
		"stun_frames": ActiveItemThrowController.GRENADE_BOSS_STUN_FRAMES,
		"knockback_power": ActiveItemThrowController.GRENADE_BOSS_KNOCKBACK_POWER,
		"knockback_frames": ActiveItemThrowController.GRENADE_BOSS_KNOCKBACK_FRAMES,
		"knockback_decay_per_frame": ActiveItemThrowController.GRENADE_BOSS_KNOCKBACK_DECAY,
	},
}

var last_fire_msec := -100000
var projectiles: Array = []
var muzzle_flashes: Array = []
var impact_flashes: Array = []
var lingering_effects: Array = []
var shell_casings: Array = []
var pistol_feedbacks: Array = []
var support_calls: Array = []
var bowling_traps: Array = []
var hit_events: Array = []
var pending_boss_damage_units := 0
var pending_boss_damage_sources: Array = []
var pending_special_gauge_gain := 0.0
var pending_special_gauge_sources: Array = []
var pending_special_gauge_hit_kind := ""
var pending_pistol_feedback_timer_frames := 0.0
var pistol_boss_hit_count := 0
var ak47_boss_hit_count := 0
var slingshot_charging := false
var slingshot_charge_timer_frames := 0.0
var slingshot_charge_level := 0
var slingshot_cooldown_frames := 0.0
var slingshot_gauge_spent := 0.0
var slingshot_last_action_pressed := false
var slingshot_control_lock_frames := 0.0
var pistol_cooldown_frames := 0.0
var pistol_cooldown_max_frames := PISTOL_COOLDOWN_FRAMES
var pistol_control_lock_frames := 0.0
var pistol_control_lock_max_frames := PISTOL_CONTROL_LOCK_FRAMES
var pistol_fire_delay_frames := 0.0
var pistol_post_fire_animation_frames := 0.0
var pistol_pending_config: Dictionary = {}
var ak47_fire_interval_frames := 0.0
var ak47_fire_interval_max_frames := AK47_FIRE_INTERVAL_FRAMES
var ak47_burst_shots_remaining := 0
var ak47_trigger_held := false
var ak47_last_action_pressed := false
var ak47_recoil_accumulation := 0.0
var bazooka_cooldown_frames := 0.0
var bazooka_cooldown_max_frames := BAZOOKA_COOLDOWN_FRAMES
var bazooka_control_lock_frames := 0.0
var bazooka_control_lock_max_frames := BAZOOKA_CONTROL_LOCK_FRAMES
var bazooka_fire_animation_frames := 0.0
var bazooka_firing_pose_frames := 0.0
var bazooka_muzzle_flash_frames := 0.0
var net_gun_cooldown_frames := 0.0
var net_gun_control_lock_frames := 0.0
var net_gun_throw_pose_frames := 0.0
var net_gun_harpoon_flash_frames := 0.0
var net_gun_last_dash_active := false
var net_constrict_last_dir := 0
var net_constrict_last_tick_msec := 0
var bowling_trap_cooldown_frames := 0.0
var bowling_trap_control_lock_frames := 0.0
var bowling_trap_install_pose_frames := 0.0
var bowling_trap_last_action_pressed := false
var suicide_drone_cooldown_frames := 0.0
var suicide_drone_last_action_pressed := false
var bowling_trap_guard_armed := false
var bowling_trap_guard_original_speed := 0.0
var bowling_trap_guard_restore_speed := 0.0
var bowling_trap_guard_source := ""
var shot_serial := 0
var pistol_pending_weapon_id := ""
var weapon_fire_sheet_id := ""
var weapon_fire_sheet_timer_frames := 0.0
var weapon_fire_sheet_max_frames := 0.0
var serve_wait_fire_suppressed_until_release := false


func update_input(input_snapshot: Dictionary, special_gauge: float, config: Dictionary, deps: Dictionary) -> Dictionary:
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	if weapon_controller == null or not weapon_controller.has_method("get_snapshot"):
		return {}
	var now_msec: int = Time.get_ticks_msec()
	_update_net_constrict_input(input_snapshot, now_msec, deps)
	var current_weapon: Dictionary = weapon_controller.get_current_weapon_data()
	var weapon_id: String = str(current_weapon.get("weapon_id", BASE_WEAPON_ID))
	if weapon_controller.has_method("update_timers"):
		CommandoFirearmAudioDispatcher.play_reload_progress_audio(weapon_controller.update_timers(1.0), deps)
	if _should_suppress_fire_input_for_serve_wait(input_snapshot, config, deps):
		return {}
	var timed_result: Dictionary = _update_firearm_timers(config, deps, 1.0)
	if bool(timed_result.get("fired", false)):
		return timed_result
	if CommandoFirearmSuicideDroneState.has_active_projectile(projectiles):
		return _update_active_suicide_drone_input(input_snapshot, special_gauge, config, deps)
	var reset_result: Dictionary = _handle_firearm_reset_input(input_snapshot, special_gauge, weapon_controller, now_msec)
	if not reset_result.is_empty():
		if bool(reset_result.get("weapon_switched", false)):
			CommandoFirearmAudioDispatcher.play_first_audio_method(deps, ["play_commando_weapon_change"])
		return reset_result
	current_weapon = weapon_controller.get_current_weapon_data()
	weapon_id = str(current_weapon.get("weapon_id", BASE_WEAPON_ID))
	if weapon_id == BASE_WEAPON_ID:
		_clear_ak47_trigger_state()
		if slingshot_charging:
			special_gauge = _cancel_slingshot_charge(special_gauge)
		return _update_pistol_input(input_snapshot, special_gauge, config, deps, current_weapon, now_msec)
	if slingshot_charging:
		special_gauge = _cancel_slingshot_charge(special_gauge)
	if weapon_id == "commando_pistol":
		_clear_ak47_trigger_state()
		return _update_pistol_input(input_snapshot, special_gauge, config, deps, current_weapon, now_msec)
	if weapon_id == "ak47":
		return _update_ak47_input(input_snapshot, special_gauge, config, deps, current_weapon, now_msec)
	if weapon_id == "bazooka":
		_clear_ak47_trigger_state()
		return _update_bazooka_input(input_snapshot, special_gauge, config, deps, current_weapon, now_msec)
	if weapon_id == "net_gun":
		_clear_ak47_trigger_state()
		return _update_net_gun_input(input_snapshot, special_gauge, config, deps, current_weapon, now_msec)
	if weapon_id == "bowling_trap":
		_clear_ak47_trigger_state()
		return _update_bowling_trap_input(input_snapshot, special_gauge, config, deps, current_weapon, now_msec)
	if weapon_id == "suicide_drone":
		_clear_ak47_trigger_state()
		return _update_suicide_drone_input(input_snapshot, special_gauge, config, deps, current_weapon, now_msec)
	_clear_ak47_trigger_state()
	if not bool(input_snapshot.get("action_pressed", false)):
		return {}
	if not CommandoFirearmInputResolver.input_action_just_pressed(input_snapshot):
		return {}
	if bool(input_snapshot.get("down_pressed", false)):
		return {}
	if CommandoFirearmInputResolver.is_fire_suppressed_after_switch(
		weapon_controller,
		now_msec,
		SWITCH_FIRE_SUPPRESS_MSEC
	):
		return {}
	if now_msec - last_fire_msec < FIRE_DEBOUNCE_MSEC:
		return {}
	if not CommandoFirearmCooldownState.is_ready(weapon_id, now_msec, deps):
		return {
			"handled": true,
			"weapon_id": weapon_id,
			"fire_failed": true,
			"special_gauge": special_gauge,
		}
	if not bool(current_weapon.get("can_fire", true)):
		return {
			"handled": true,
			"weapon_id": weapon_id,
			"fire_failed": true,
			"special_gauge": special_gauge,
		}
	if weapon_controller.has_method("consume_current_weapon_ammo"):
		if not bool(weapon_controller.consume_current_weapon_ammo(1)):
			return {
				"handled": true,
				"weapon_id": weapon_id,
				"fire_failed": true,
				"special_gauge": special_gauge,
			}
	last_fire_msec = now_msec
	if weapon_id != "pistol":
		CommandoFirearmCooldownState.trigger_configured_cooldown(weapon_id, now_msec, deps)
	_spawn_firearm_effect(weapon_id, config, deps)
	CommandoFirearmAudioDispatcher.play_fire_audio(weapon_id, deps)
	return {
		"handled": true,
		"weapon_id": weapon_id,
		"fired": true,
		"special_gauge": special_gauge,
		"skill_gold_award": 0,
	}


func _should_suppress_fire_input_for_serve_wait(
	input_snapshot: Dictionary,
	config: Dictionary,
	deps: Dictionary
) -> bool:
	var action_pressed: bool = bool(input_snapshot.get("action_pressed", false))
	var round_state: Object = deps.get("round_state", null)
	var waiting_for_serve: bool = false
	if round_state != null and round_state.has_method("is_waiting_for_serve"):
		waiting_for_serve = bool(round_state.is_waiting_for_serve())
	elif config.has("waiting_for_serve"):
		waiting_for_serve = bool(config.get("waiting_for_serve", false))
	if waiting_for_serve:
		if action_pressed:
			serve_wait_fire_suppressed_until_release = true
		_clear_serve_wait_firearm_input_state()
		return true
	if not serve_wait_fire_suppressed_until_release:
		return false
	if action_pressed:
		_clear_serve_wait_firearm_input_state()
		return true
	serve_wait_fire_suppressed_until_release = false
	return false


func _clear_serve_wait_firearm_input_state() -> void:
	_clear_ak47_trigger_state()
	ak47_last_action_pressed = false
	bowling_trap_last_action_pressed = false
	suicide_drone_last_action_pressed = false
	if slingshot_charging:
		slingshot_charging = false
		slingshot_charge_timer_frames = 0.0
		slingshot_charge_level = 0
		slingshot_gauge_spent = 0.0
	slingshot_last_action_pressed = false
	slingshot_control_lock_frames = 0.0
	pistol_fire_delay_frames = 0.0
	pistol_control_lock_frames = 0.0
	pistol_pending_config.clear()
	pistol_pending_weapon_id = ""


func _handle_firearm_reset_input(
	input_snapshot: Dictionary,
	special_gauge: float,
	weapon_controller: Object,
	now_msec: int
) -> Dictionary:
	var reset_pressed: bool = bool(input_snapshot.get(
		"firearm_reset_just_pressed",
		input_snapshot.get("mouse_middle_just_pressed", false)
	))
	if not reset_pressed:
		return {}
	if weapon_controller == null:
		return {}
	var previous_weapon_id := BASE_WEAPON_ID
	if weapon_controller.has_method("get_current_weapon_data"):
		previous_weapon_id = str(weapon_controller.get_current_weapon_data().get("weapon_id", BASE_WEAPON_ID))
	var switched := false
	if weapon_controller.has_method("select_base_weapon"):
		switched = bool(weapon_controller.select_base_weapon(now_msec))
	elif weapon_controller.has_method("set_current_weapon"):
		switched = bool(weapon_controller.set_current_weapon(BASE_WEAPON_ID))
	if not switched:
		return {}
	_clear_ak47_trigger_state()
	if slingshot_charging:
		special_gauge = _cancel_slingshot_charge(special_gauge)
	return {
		"handled": true,
		"weapon_id": BASE_WEAPON_ID,
		"current_weapon_id": BASE_WEAPON_ID,
		"previous_weapon_id": previous_weapon_id,
		"weapon_switched": previous_weapon_id != BASE_WEAPON_ID,
		"firearm_reset": true,
		"special_gauge": special_gauge,
	}


func reset() -> void:
	last_fire_msec = -100000
	projectiles.clear()
	muzzle_flashes.clear()
	impact_flashes.clear()
	lingering_effects.clear()
	shell_casings.clear()
	pistol_feedbacks.clear()
	support_calls.clear()
	bowling_traps.clear()
	pistol_pending_weapon_id = ""
	hit_events.clear()
	serve_wait_fire_suppressed_until_release = false
	pending_boss_damage_units = 0
	pending_boss_damage_sources.clear()
	pending_special_gauge_gain = 0.0
	pending_special_gauge_sources.clear()
	pending_special_gauge_hit_kind = ""
	pending_pistol_feedback_timer_frames = 0.0
	pistol_boss_hit_count = 0
	ak47_boss_hit_count = 0
	slingshot_charging = false
	slingshot_charge_timer_frames = 0.0
	slingshot_charge_level = 0
	slingshot_cooldown_frames = 0.0
	slingshot_gauge_spent = 0.0
	slingshot_last_action_pressed = false
	slingshot_control_lock_frames = 0.0
	pistol_cooldown_frames = 0.0
	pistol_cooldown_max_frames = PISTOL_COOLDOWN_FRAMES
	pistol_control_lock_frames = 0.0
	pistol_control_lock_max_frames = PISTOL_CONTROL_LOCK_FRAMES
	pistol_fire_delay_frames = 0.0
	pistol_post_fire_animation_frames = 0.0
	pistol_pending_config.clear()
	ak47_fire_interval_frames = 0.0
	ak47_fire_interval_max_frames = AK47_FIRE_INTERVAL_FRAMES
	ak47_burst_shots_remaining = 0
	ak47_trigger_held = false
	ak47_last_action_pressed = false
	ak47_recoil_accumulation = 0.0
	bazooka_cooldown_frames = 0.0
	bazooka_cooldown_max_frames = BAZOOKA_COOLDOWN_FRAMES
	bazooka_control_lock_frames = 0.0
	bazooka_control_lock_max_frames = BAZOOKA_CONTROL_LOCK_FRAMES
	bazooka_fire_animation_frames = 0.0
	bazooka_firing_pose_frames = 0.0
	bazooka_muzzle_flash_frames = 0.0
	net_gun_cooldown_frames = 0.0
	net_gun_control_lock_frames = 0.0
	net_gun_throw_pose_frames = 0.0
	net_gun_harpoon_flash_frames = 0.0
	net_gun_last_dash_active = false
	bowling_trap_cooldown_frames = 0.0
	bowling_trap_control_lock_frames = 0.0
	bowling_trap_install_pose_frames = 0.0
	bowling_trap_last_action_pressed = false
	suicide_drone_cooldown_frames = 0.0
	suicide_drone_last_action_pressed = false
	weapon_fire_sheet_id = ""
	weapon_fire_sheet_timer_frames = 0.0
	weapon_fire_sheet_max_frames = 0.0
	_clear_bowling_trap_guard()


func reset_round(deps: Dictionary = {}) -> void:
	CommandoFirearmAudioDispatcher.stop_all_support_aircraft_audio(support_calls, deps)
	CommandoFirearmAudioDispatcher.stop_suicide_drone_audio(deps)
	var carried_bowling_traps: Array = []
	if bool(deps.get("preserve_bowling_traps", true)):
		carried_bowling_traps = CommandoFirearmBowlingTrapGeometry.build_round_carryover(
			bowling_traps,
			BOWLING_TRAP_CAPTURE_BALL_OFFSET
		)
	reset()
	bowling_traps = carried_bowling_traps


func has_visible_effects() -> bool:
	return CommandoFirearmDrawStateResolver.has_visible_effects(
		[
			projectiles,
			muzzle_flashes,
			impact_flashes,
			lingering_effects,
			shell_casings,
			pistol_feedbacks,
			support_calls,
			bowling_traps,
		],
		[
			slingshot_control_lock_frames,
			pistol_fire_delay_frames,
			pistol_post_fire_animation_frames,
			weapon_fire_sheet_timer_frames,
			pistol_control_lock_frames,
			bazooka_control_lock_frames,
			bazooka_fire_animation_frames,
			bazooka_firing_pose_frames,
			bazooka_muzzle_flash_frames,
			net_gun_control_lock_frames,
			net_gun_throw_pose_frames,
			net_gun_harpoon_flash_frames,
			bowling_trap_control_lock_frames,
			bowling_trap_install_pose_frames,
			suicide_drone_cooldown_frames,
		]
	)


func needs_effect_update() -> bool:
	return CommandoFirearmControlState.needs_effect_update(
		has_visible_effects(),
		pending_boss_damage_units,
		pending_special_gauge_gain
	)


func is_player_control_locked() -> bool:
	return CommandoFirearmControlState.is_player_control_locked(
		[
			slingshot_control_lock_frames,
			pistol_control_lock_frames,
			bazooka_control_lock_frames,
			net_gun_control_lock_frames,
			bowling_trap_control_lock_frames,
		],
		CommandoFirearmSupportCallResolver.has_active_lock(support_calls),
		CommandoFirearmSuicideDroneState.has_active_projectile(projectiles)
	)


func get_movement_speed_multiplier() -> float:
	return CommandoFirearmControlState.get_movement_speed_multiplier(
		CommandoFirearmSuicideDroneState.has_active_projectile(projectiles),
		ak47_trigger_held,
		CommandoFirearmLingeringNetFieldState.has_active_hooked_net_field(lingering_effects),
		AK47_MOVEMENT_SPEED_MULTIPLIER,
		NET_GUN_PLAYER_SLOW_MULTIPLIER
	)


func is_bowling_trap_guard_armed() -> bool:
	return bowling_trap_guard_armed


func consume_bowling_trap_boss_guard(ball_vel: Vector2, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if not bowling_trap_guard_armed:
		return {}

	var source: String = bowling_trap_guard_source
	if source == "":
		source = "commando_bowling_trap_guard"
	var restore_speed: float = max(1.0, bowling_trap_guard_restore_speed)
	_clear_bowling_trap_guard()

	var next_ball_vel: Vector2 = CommandoFirearmBowlingTrapGeometry.soften_guard_ball(ball_vel, restore_speed)
	var stage2_boss_immune := false
	if int(context.get("current_stage", 0)) == 2:
		stage2_boss_immune = (
			bool(context.get("stage2_speed_defense_status_immunity_active", false))
			or bool(context.get("stage2_speed_defense_active", false))
		)
	var stage2_skill_state: Object = deps.get("stage2_boss_skill_state", null)
	if (
		not stage2_boss_immune
		and stage2_skill_state != null
		and stage2_skill_state.has_method("is_boss_status_immune")
		and bool(stage2_skill_state.is_boss_status_immune())
	):
		stage2_boss_immune = true
	var registry: Object = deps.get("registry", null)
	var registry_stage2_skill_state: Object = CommandoFirearmValueUtils.get_instance(registry, "stage2_boss_skill_state")
	if (
		not stage2_boss_immune
		and registry_stage2_skill_state != null
		and registry_stage2_skill_state.has_method("is_boss_status_immune")
		and bool(registry_stage2_skill_state.is_boss_status_immune())
	):
		stage2_boss_immune = true
	if stage2_boss_immune:
		return CommandoFirearmBowlingTrapGeometry.build_guard_immune_result(next_ball_vel)

	var boss_center: Vector2 = CommandoFirearmOriginGeometry.get_boss_target_pos(context, FIELD_WIDTH)
	var knockback_vel: float = CommandoFirearmBowlingTrapGeometry.get_guard_knockback_velocity(
		boss_center,
		context,
		FIELD_WIDTH,
		BOWLING_TRAP_GUARD_KNOCKBACK_POWER
	)
	var feedback_profile: Dictionary = CommandoFirearmProfileResolver.get_hit_feedback_profile(
		"bowling_trap",
		WEAPON_HIT_FEEDBACK,
		HIT_FEEDBACK_PROFILE_OVERRIDES
	)
	var profile: Dictionary = CommandoFirearmProfileResolver.get_weapon_profile(
		"bowling_trap",
		WEAPON_PROFILES,
		WEAPON_PROFILE_OVERRIDES
	)
	var status_effect_state: Object = deps.get("status_effect_state", null)
	var applied_status := false
	if status_effect_state != null and status_effect_state.has_method("apply_status"):
		status_effect_state.apply_status(
			"boss",
			"stun",
			BOWLING_TRAP_GUARD_STUN_FRAMES,
			CommandoFirearmBowlingTrapGeometry.build_guard_status_data(
				knockback_vel,
				BOWLING_TRAP_GUARD_KNOCKBACK_FRAMES,
				BOWLING_TRAP_GUARD_KNOCKBACK_DECAY,
				source
			),
			source
		)
		applied_status = true

	var ai_state: Object = deps.get("ai_state", null)
	if not applied_status and ai_state != null and ai_state.has_method("start_paddle_hit_knockback"):
		ai_state.start_paddle_hit_knockback(
			knockback_vel,
			BOWLING_TRAP_GUARD_KNOCKBACK_FRAMES,
			BOWLING_TRAP_GUARD_KNOCKBACK_DECAY,
			true
		)

	CommandoFirearmHitFeedbackDispatcher.spawn_shared_impact_particles(
		boss_center,
		CommandoFirearmValueUtils.get_color(profile.get("color", Color.WHITE), Color.WHITE),
		next_ball_vel,
		float(feedback_profile.get("intensity", 0.82)),
		deps
	)
	CommandoFirearmHitFeedbackDispatcher.trigger_hit_feedback(feedback_profile, deps)
	CommandoFirearmHitFeedbackDispatcher.trigger_boss_hit_animation(context, deps)
	CommandoFirearmHitFeedbackDispatcher.register_ball_hit_pulse(boss_center, next_ball_vel, 0.9, "bowling_trap_guard", deps, BASE_WEAPON_ID)
	return CommandoFirearmBowlingTrapGeometry.build_guard_hit_result(
		next_ball_vel,
		knockback_vel,
		source,
		BOWLING_TRAP_GUARD_STUN_FRAMES,
		restore_speed
	)


func is_fire_support_aircraft_audio_active() -> bool:
	for value in support_calls:
		@warning_ignore("shadowed_variable_base_class")
		var call: Dictionary = CommandoFirearmValueUtils.get_dict(value)
		if bool(call.get("aircraft_audio_active", false)):
			return true
	return false


func get_fire_support_aircraft_collision_rect(call_id: int = 0) -> Rect2:
	for value in support_calls:
		@warning_ignore("shadowed_variable_base_class")
		var call: Dictionary = CommandoFirearmValueUtils.get_dict(value)
		if not bool(call.get("aircraft_active", false)):
			continue
		if call_id != 0 and int(call.get("id", 0)) != call_id:
			continue
		return CommandoFirearmSupportAircraftGeometry.get_collision_rect(
			call,
			Vector2(SUPPORT_AIRCRAFT_START_X, SUPPORT_AIRCRAFT_Y),
			SUPPORT_AIRCRAFT_COLLISION_SIZE
		)
	return Rect2()


func resolve_ball_collision(scene: Dictionary, context: Dictionary, _deps: Dictionary = {}) -> bool:
	var ball_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(scene.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var previous_ball_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(
		scene.get("previous_ball_pos", context.get("ball_pos", ball_pos)),
		ball_pos
	)
	var ball_radius: float = max(1.0, float(context.get("ball_size", scene.get("ball_size", 28.6))) * 0.5)
	for value in support_calls:
		@warning_ignore("shadowed_variable_base_class")
		var call: Dictionary = CommandoFirearmValueUtils.get_dict(value)
		if CommandoFirearmSupportAircraftGeometry.ball_path_hits(
			call,
			previous_ball_pos,
			ball_pos,
			ball_radius,
			Vector2(SUPPORT_AIRCRAFT_START_X, SUPPORT_AIRCRAFT_Y),
			SUPPORT_AIRCRAFT_COLLISION_SIZE
		):
			# Python FireSupportAircraft deliberately ignores ball hits; keep the
			# collision route visible without starting a crash lifecycle.
			return false
	return false


func update_effects(fps_scale: float, _current_msec: int, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	muzzle_flashes = CommandoFirearmValueUtils.advance_timed_effects(muzzle_flashes, fps_scale)
	_update_support_calls(fps_scale, context, deps)
	var ball_motion_result: Dictionary = _update_bowling_traps(fps_scale, context, deps)
	if not ball_motion_result.is_empty():
		context.merge(ball_motion_result, true)
	var projectile_result: Dictionary = _update_projectiles(fps_scale, context, deps)
	if not projectile_result.is_empty():
		context.merge(projectile_result, true)
	shell_casings = CommandoFirearmShellCasingState.advance_shells(
		shell_casings,
		fps_scale,
		FIELD_WIDTH,
		FIELD_HEIGHT,
		AK47_SHELL_GRAVITY,
		AK47_SHELL_BOUNCE_DECAY,
		AK47_SHELL_MAX_BOUNCES
	)
	pistol_feedbacks = CommandoFirearmPistolFeedbackState.advance_feedbacks(pistol_feedbacks, fps_scale)
	impact_flashes = CommandoFirearmValueUtils.advance_timed_effects(impact_flashes, fps_scale)
	var lingering_result: Dictionary = _update_lingering_effects(fps_scale, context, deps)
	if not lingering_result.is_empty():
		context.merge(lingering_result, true)
	var result: Dictionary = ball_motion_result.duplicate(true)
	if not projectile_result.is_empty():
		result.merge(projectile_result, true)
	if not lingering_result.is_empty():
		result.merge(lingering_result, true)
	var damage_result: Dictionary = CommandoFirearmPendingResultState.build_boss_damage_result(
		pending_boss_damage_units,
		pending_boss_damage_sources
	)
	if not damage_result.is_empty():
		result.merge(damage_result, true)
		pending_boss_damage_units = 0
		pending_boss_damage_sources.clear()
	var gauge_result: Dictionary = CommandoFirearmPendingResultState.build_special_gauge_result(
		pending_special_gauge_gain,
		pending_special_gauge_sources,
		pending_special_gauge_hit_kind,
		pending_pistol_feedback_timer_frames
	)
	if not gauge_result.is_empty():
		result.merge(gauge_result, true)
		pending_special_gauge_gain = 0.0
		pending_special_gauge_sources.clear()
		pending_special_gauge_hit_kind = ""
		pending_pistol_feedback_timer_frames = 0.0
	return result


func get_recent_hit_events() -> Array:
	return hit_events.duplicate(true)


func get_actor_draw_context() -> Dictionary:
	var slingshot_state: Dictionary = CommandoFirearmDrawStateResolver.build_slingshot_state(
		slingshot_charging,
		slingshot_charge_timer_frames,
		slingshot_charge_level,
		SLINGSHOT_CHARGE_THRESHOLD_3,
		SLINGSHOT_GAUGE_DRAIN_INTERVAL_FRAMES,
		slingshot_cooldown_frames,
		SLINGSHOT_COOLDOWN_FRAMES,
		slingshot_gauge_spent,
		slingshot_control_lock_frames,
		SLINGSHOT_CONTROL_LOCK_FRAMES
	)
	var pistol_state: Dictionary = CommandoFirearmDrawStateResolver.build_pistol_state(
		pistol_cooldown_frames,
		pistol_cooldown_max_frames,
		pistol_control_lock_frames,
		pistol_control_lock_max_frames,
		pistol_fire_delay_frames,
		PISTOL_FIRE_DELAY_FRAMES,
		pistol_post_fire_animation_frames,
		PISTOL_POST_FIRE_ANIMATION_FRAMES
	)
	var weapon_fire_sheet_state: Dictionary = CommandoFirearmDrawStateResolver.build_weapon_fire_sheet_state(
		weapon_fire_sheet_id,
		weapon_fire_sheet_timer_frames,
		weapon_fire_sheet_max_frames,
		COMMANDO_WEAPON_FIRE_SHEET_FRAME_COUNT
	)
	var ak47_state: Dictionary = CommandoFirearmDrawStateResolver.build_ak47_state(
		ak47_trigger_held,
		ak47_fire_interval_frames,
		ak47_fire_interval_max_frames,
		ak47_burst_shots_remaining,
		ak47_recoil_accumulation,
		get_movement_speed_multiplier()
	)
	var bazooka_state: Dictionary = CommandoFirearmDrawStateResolver.build_bazooka_state(
		bazooka_cooldown_frames,
		bazooka_cooldown_max_frames,
		bazooka_control_lock_frames,
		bazooka_control_lock_max_frames,
		bazooka_fire_animation_frames,
		BAZOOKA_FIRE_ANIMATION_FRAMES,
		bazooka_firing_pose_frames,
		BAZOOKA_FIRING_POSE_FRAMES,
		bazooka_muzzle_flash_frames,
		BAZOOKA_MUZZLE_FLASH_FRAMES
	)
	var net_gun_state: Dictionary = CommandoFirearmDrawStateResolver.build_net_gun_state(
		net_gun_cooldown_frames,
		NET_GUN_COOLDOWN_FRAMES,
		net_gun_control_lock_frames,
		NET_GUN_CONTROL_LOCK_FRAMES,
		net_gun_throw_pose_frames,
		NET_GUN_THROW_POSE_FRAMES,
		net_gun_harpoon_flash_frames,
		NET_GUN_HARPOON_FLASH_FRAMES,
		get_movement_speed_multiplier(),
		CommandoFirearmLingeringNetFieldState.has_active_hooked_net_field(lingering_effects)
	)
	var bowling_trap_state: Dictionary = CommandoFirearmDrawStateResolver.build_bowling_trap_state(
		bowling_trap_cooldown_frames,
		BOWLING_TRAP_COOLDOWN_FRAMES,
		bowling_trap_control_lock_frames,
		BOWLING_TRAP_CONTROL_LOCK_FRAMES,
		bowling_trap_install_pose_frames,
		BOWLING_TRAP_INSTALL_FRAMES,
		CommandoFirearmBowlingTrapGeometry.has_installing_trap(bowling_traps),
		CommandoFirearmBowlingTrapGeometry.get_install_progress(bowling_traps)
	)
	var suicide_drone_index: int = CommandoFirearmSuicideDroneState.get_active_projectile_index(projectiles)
	var suicide_drone_projectile: Dictionary = {}
	if suicide_drone_index >= 0:
		suicide_drone_projectile = CommandoFirearmValueUtils.get_dict(projectiles[suicide_drone_index])
	var suicide_drone_state: Dictionary = CommandoFirearmDrawStateResolver.build_suicide_drone_state(
		suicide_drone_index >= 0,
		suicide_drone_cooldown_frames,
		SUICIDE_DRONE_COOLDOWN_FRAMES,
		float(suicide_drone_projectile.get("grace_timer_frames", 0.0)),
		CommandoFirearmValueUtils.get_vector2(suicide_drone_projectile.get("pos", Vector2.ZERO), Vector2.ZERO),
		CommandoFirearmValueUtils.get_vector2(suicide_drone_projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	)
	return CommandoFirearmDrawStateResolver.build_actor_context(
		has_visible_effects(),
		projectiles,
		muzzle_flashes,
		impact_flashes,
		lingering_effects,
		shell_casings,
		pistol_feedbacks,
		pistol_state,
		slingshot_state,
		ak47_state,
		bazooka_state,
		net_gun_state,
		bowling_trap_state,
		suicide_drone_state,
		weapon_fire_sheet_state,
		support_calls,
		bowling_traps
	)


func _update_firearm_timers(config: Dictionary, deps: Dictionary, fps_scale: float = 1.0) -> Dictionary:
	var step: float = max(0.0, float(fps_scale))
	if step <= 0.0:
		return {}
	slingshot_control_lock_frames = max(0.0, slingshot_control_lock_frames - step)
	pistol_cooldown_frames = max(0.0, pistol_cooldown_frames - step)
	pistol_control_lock_frames = max(0.0, pistol_control_lock_frames - step)
	ak47_fire_interval_frames = max(0.0, ak47_fire_interval_frames - step)
	bazooka_cooldown_frames = max(0.0, bazooka_cooldown_frames - step)
	bazooka_control_lock_frames = max(0.0, bazooka_control_lock_frames - step)
	bazooka_fire_animation_frames = max(0.0, bazooka_fire_animation_frames - step)
	bazooka_firing_pose_frames = max(0.0, bazooka_firing_pose_frames - step)
	bazooka_muzzle_flash_frames = max(0.0, bazooka_muzzle_flash_frames - step)
	net_gun_cooldown_frames = max(0.0, net_gun_cooldown_frames - step)
	net_gun_control_lock_frames = max(0.0, net_gun_control_lock_frames - step)
	net_gun_throw_pose_frames = max(0.0, net_gun_throw_pose_frames - step)
	net_gun_harpoon_flash_frames = max(0.0, net_gun_harpoon_flash_frames - step)
	bowling_trap_cooldown_frames = max(0.0, bowling_trap_cooldown_frames - step)
	bowling_trap_control_lock_frames = max(0.0, bowling_trap_control_lock_frames - step)
	bowling_trap_install_pose_frames = max(0.0, bowling_trap_install_pose_frames - step)
	suicide_drone_cooldown_frames = max(0.0, suicide_drone_cooldown_frames - step)
	if not ak47_trigger_held:
		ak47_recoil_accumulation = max(0.0, ak47_recoil_accumulation - AK47_RECOIL_RECOVERY_PER_FRAME * step)
	pistol_post_fire_animation_frames = max(0.0, pistol_post_fire_animation_frames - step)
	weapon_fire_sheet_timer_frames = max(0.0, weapon_fire_sheet_timer_frames - step)
	if weapon_fire_sheet_timer_frames <= 0.0:
		weapon_fire_sheet_id = ""
		weapon_fire_sheet_max_frames = 0.0
	if pistol_fire_delay_frames <= 0.0:
		return {}
	CommandoFirearmValueUtils.refresh_pending_fire_geometry(
		pistol_pending_config,
		config,
		PISTOL_PENDING_FIRE_GEOMETRY_KEYS
	)
	pistol_fire_delay_frames = max(0.0, pistol_fire_delay_frames - step)
	if pistol_fire_delay_frames > 0.0:
		return CommandoFirearmFireResultState.build_pistol_shot_pending_result(
			str(pistol_pending_weapon_id if pistol_pending_weapon_id != "" else "commando_pistol"),
			pistol_fire_delay_frames,
			pistol_control_lock_frames
		)
	var shot_config: Dictionary = pistol_pending_config.duplicate(true)
	if shot_config.is_empty():
		shot_config = config
	var shot_weapon_id: String = str(pistol_pending_weapon_id if pistol_pending_weapon_id != "" else "commando_pistol")
	pistol_pending_config.clear()
	pistol_pending_weapon_id = ""
	_spawn_firearm_effect(shot_weapon_id, shot_config, deps)
	CommandoFirearmAudioDispatcher.play_fire_audio(shot_weapon_id, deps)
	# Start the post-fire animation window so the renderer plays the muzzle /
	# smoke / lower / ready frames after the shot resolves. Frame 4 (muzzle
	# flash) is the first cell shown during this window, so it lines up with
	# `CommandoFirearmAudioDispatcher.play_fire_audio()` above.
	pistol_post_fire_animation_frames = PISTOL_POST_FIRE_ANIMATION_FRAMES
	return CommandoFirearmFireResultState.build_pistol_delayed_fire_result(
		shot_weapon_id,
		pistol_cooldown_frames,
		pistol_control_lock_frames
	)


func _update_pistol_input(
	input_snapshot: Dictionary,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	current_weapon: Dictionary,
	now_msec: int
) -> Dictionary:
	var weapon_id: String = str(current_weapon.get("weapon_id", "commando_pistol"))
	if not bool(input_snapshot.get("action_pressed", false)):
		return {}
	if input_snapshot.has("action_just_pressed") and not bool(input_snapshot.get("action_just_pressed", false)):
		return {}
	if bool(input_snapshot.get("down_pressed", false)):
		return {}
	if CommandoFirearmInputResolver.is_fire_suppressed_after_switch(
		deps.get("commando_weapon_controller", null),
		now_msec,
		SWITCH_FIRE_SUPPRESS_MSEC
	):
		return {}
	if pistol_fire_delay_frames > 0.0:
		return CommandoFirearmFireResultState.build_pistol_fire_failed_result(weapon_id, special_gauge, "pistol_animation_busy", pistol_cooldown_frames, pistol_control_lock_frames, pistol_fire_delay_frames)
	if pistol_cooldown_frames > 0.0:
		return CommandoFirearmFireResultState.build_pistol_fire_failed_result(weapon_id, special_gauge, "pistol_cooldown", pistol_cooldown_frames, pistol_control_lock_frames, pistol_fire_delay_frames)
	if bool(current_weapon.get("reloading", false)):
		return CommandoFirearmFireResultState.build_pistol_fire_failed_result(weapon_id, special_gauge, "pistol_reloading", pistol_cooldown_frames, pistol_control_lock_frames, pistol_fire_delay_frames)
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	var ammo_current: int = int(current_weapon.get("ammo_current", 0))
	var magazines_current: int = int(current_weapon.get("magazines_current", 0))
	if ammo_current <= 0:
		if weapon_id == BASE_WEAPON_ID:
			return _reload_base_pistol_from_fire_input(special_gauge, deps)
		return CommandoFirearmFireResultState.build_pistol_fire_failed_result(weapon_id, special_gauge, "pistol_empty", pistol_cooldown_frames, pistol_control_lock_frames, pistol_fire_delay_frames)
	if weapon_controller != null and weapon_controller.has_method("consume_current_weapon_ammo"):
		if not bool(weapon_controller.consume_current_weapon_ammo(1)):
			return CommandoFirearmFireResultState.build_pistol_fire_failed_result(weapon_id, special_gauge, "pistol_ammo_unavailable", pistol_cooldown_frames, pistol_control_lock_frames, pistol_fire_delay_frames)
	last_fire_msec = now_msec
	var doping_defaults: Dictionary = DOPING_POTION_DEFAULTS
	var doping_context: Dictionary = CommandoFirearmValueUtils.get_doping_potion_context_from_deps(
		deps,
		doping_defaults
	)
	var doping_active: bool = bool(doping_context.get("active", false))
	pistol_cooldown_max_frames = CommandoFirearmValueUtils.get_pistol_cooldown_frames(
		weapon_id,
		doping_context,
		doping_active,
		PISTOL_COOLDOWN_FRAMES,
		BERETTA_COOLDOWN_FRAMES,
		DOPING_POTION_PISTOL_COOLDOWN_FRAMES
	)
	pistol_control_lock_max_frames = CommandoFirearmValueUtils.get_pistol_control_lock_frames(
		doping_context,
		doping_active,
		PISTOL_CONTROL_LOCK_FRAMES,
		DOPING_POTION_PISTOL_CONTROL_LOCK_FRAMES
	)
	pistol_cooldown_frames = pistol_cooldown_max_frames
	pistol_control_lock_frames = pistol_control_lock_max_frames
	pistol_fire_delay_frames = PISTOL_FIRE_DELAY_FRAMES
	pistol_pending_config = config.duplicate(true)
	pistol_pending_weapon_id = weapon_id
	CommandoFirearmValueUtils.apply_doping_potion_to_pistol_config(
		pistol_pending_config,
		doping_context,
		doping_defaults
	)
	CommandoFirearmAudioDispatcher.play_first_audio_method(deps, ["play_commando_pistol_ready"])
	var updated_weapon: Dictionary = current_weapon
	if weapon_controller != null and weapon_controller.has_method("get_current_weapon_data"):
		updated_weapon = weapon_controller.get_current_weapon_data()
	return CommandoFirearmFireResultState.build_pistol_shot_queued_result(
		weapon_id,
		updated_weapon,
		max(0, ammo_current - 1),
		int(current_weapon.get("ammo_max", PISTOL_AMMO_MAX)),
		magazines_current,
		pistol_cooldown_frames,
		pistol_control_lock_frames,
		pistol_fire_delay_frames,
		doping_context,
		doping_active,
		special_gauge
	)


func _reload_base_pistol_from_fire_input(special_gauge: float, deps: Dictionary) -> Dictionary:
	if special_gauge < PISTOL_EMPTY_RELOAD_GAUGE_COST:
		return CommandoFirearmFireResultState.build_pistol_fire_failed_result(BASE_WEAPON_ID, special_gauge, "pistol_reload_gauge_insufficient", pistol_cooldown_frames, pistol_control_lock_frames, pistol_fire_delay_frames)
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	if weapon_controller == null or not weapon_controller.has_method("start_weapon_reload"):
		return CommandoFirearmFireResultState.build_pistol_fire_failed_result(BASE_WEAPON_ID, special_gauge, "pistol_reload_unavailable", pistol_cooldown_frames, pistol_control_lock_frames, pistol_fire_delay_frames)
	if not bool(weapon_controller.start_weapon_reload(BASE_WEAPON_ID)):
		return CommandoFirearmFireResultState.build_pistol_fire_failed_result(BASE_WEAPON_ID, special_gauge, "pistol_reload_unavailable", pistol_cooldown_frames, pistol_control_lock_frames, pistol_fire_delay_frames)
	var updated_weapon: Dictionary = {}
	if weapon_controller.has_method("get_current_weapon_data"):
		updated_weapon = weapon_controller.get_current_weapon_data()
	CommandoFirearmAudioDispatcher.play_first_audio_method(deps, ["play_commando_pistol_reload_start"])
	var next_gauge: float = max(0.0, special_gauge - PISTOL_EMPTY_RELOAD_GAUGE_COST)
	return CommandoFirearmFireResultState.build_base_pistol_reload_started_result(
		BASE_WEAPON_ID,
		next_gauge,
		updated_weapon,
		PISTOL_AMMO_MAX,
		PISTOL_FIRE_DELAY_FRAMES,
		PISTOL_EMPTY_RELOAD_GAUGE_COST
	)


func _update_ak47_input(
	input_snapshot: Dictionary,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	current_weapon: Dictionary,
	now_msec: int
) -> Dictionary:
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	var action_pressed: bool = bool(input_snapshot.get("action_pressed", false))
	var previous_action_pressed: bool = ak47_last_action_pressed
	var action_just_pressed: bool = bool(input_snapshot.get("action_just_pressed", action_pressed and not previous_action_pressed))
	ak47_last_action_pressed = action_pressed
	if not action_pressed or bool(input_snapshot.get("down_pressed", false)):
		_clear_ak47_trigger_state()
		return {}
	if CommandoFirearmInputResolver.is_fire_suppressed_after_switch(
		weapon_controller,
		now_msec,
		SWITCH_FIRE_SUPPRESS_MSEC
	):
		ak47_trigger_held = true
		return {}
	if action_just_pressed:
		ak47_trigger_held = true
		ak47_burst_shots_remaining = AK47_INITIAL_BURST_SHOTS
		ak47_fire_interval_frames = 0.0
	else:
		ak47_trigger_held = true
	var doping_context: Dictionary = CommandoFirearmValueUtils.get_doping_potion_context_from_deps(
		deps,
		DOPING_POTION_DEFAULTS
	)
	var doping_active: bool = bool(doping_context.get("active", false))
	var ammo_current: int = int(current_weapon.get("ammo_current", 0))
	if ammo_current <= 0 or not bool(current_weapon.get("can_fire", true)):
		_clear_ak47_trigger_state()
		return CommandoFirearmFireResultState.build_fire_failed_result("ak47", special_gauge, "ak47_empty", {
			"fire_interval_frames": ak47_fire_interval_frames,
			"burst_shots_remaining": ak47_burst_shots_remaining,
			"movement_speed_multiplier": get_movement_speed_multiplier(),
		})
	if weapon_controller != null and weapon_controller.has_method("consume_current_weapon_duration"):
		weapon_controller.consume_current_weapon_duration(1.0)
	if weapon_controller != null and weapon_controller.has_method("get_current_weapon_data"):
		current_weapon = weapon_controller.get_current_weapon_data()
	if ak47_fire_interval_frames > 0.0:
		return CommandoFirearmFireResultState.build_ak47_holding_result(
			special_gauge,
			ak47_fire_interval_frames,
			ak47_burst_shots_remaining,
			AK47_MOVEMENT_SPEED_MULTIPLIER
		)
	if weapon_controller != null and weapon_controller.has_method("consume_current_weapon_ammo"):
		if not bool(weapon_controller.consume_current_weapon_ammo(1)):
			_clear_ak47_trigger_state()
			return CommandoFirearmFireResultState.build_fire_failed_result("ak47", special_gauge, "ak47_ammo_unavailable", {
				"fire_interval_frames": ak47_fire_interval_frames,
				"burst_shots_remaining": ak47_burst_shots_remaining,
				"movement_speed_multiplier": get_movement_speed_multiplier(),
			})
	last_fire_msec = now_msec
	_spawn_firearm_effect(
		"ak47",
		config,
		deps,
		CommandoFirearmProfileResolver.build_ak47_fire_profile(
			WEAPON_PROFILES,
			WEAPON_PROFILE_OVERRIDES,
			ak47_recoil_accumulation,
			AK47_BASE_SPREAD_RADIANS
		)
	)
	CommandoFirearmAudioDispatcher.play_fire_audio("ak47", deps)
	CommandoFirearmCooldownState.trigger_skill_cooldown(
		"ak47",
		now_msec,
		deps,
		doping_context,
		doping_active,
		DOPING_POTION_FIRE_RATE_MULTIPLIER
	)
	ak47_recoil_accumulation = min(AK47_MAX_RECOIL, ak47_recoil_accumulation + AK47_RECOIL_PER_SHOT)
	if ak47_burst_shots_remaining > 0:
		ak47_burst_shots_remaining -= 1
	ak47_fire_interval_max_frames = CommandoFirearmValueUtils.get_ak47_fire_interval_frames(
		doping_context,
		doping_active,
		AK47_FIRE_INTERVAL_FRAMES,
		DOPING_POTION_AK47_FIRE_INTERVAL_FRAMES
	)
	ak47_fire_interval_frames = ak47_fire_interval_max_frames
	var updated_weapon: Dictionary = current_weapon
	if weapon_controller != null and weapon_controller.has_method("get_current_weapon_data"):
		updated_weapon = weapon_controller.get_current_weapon_data()
	var remaining_ammo: int = int(updated_weapon.get("ammo_current", max(0, ammo_current - 1)))
	if str(updated_weapon.get("weapon_id", "ak47")) != "ak47":
		remaining_ammo = max(0, ammo_current - 1)
	if remaining_ammo <= 0:
		_clear_ak47_trigger_state()
	var movement_multiplier: float = AK47_MOVEMENT_SPEED_MULTIPLIER if remaining_ammo > 0 else 1.0
	var ammo_max_result: int = int(updated_weapon.get("ammo_max", current_weapon.get("ammo_max", AK47_AMMO_MAX)))
	if str(updated_weapon.get("weapon_id", "ak47")) != "ak47":
		ammo_max_result = int(current_weapon.get("ammo_max", AK47_AMMO_MAX))
	return CommandoFirearmFireResultState.build_ak47_fired_result(
		remaining_ammo,
		ammo_max_result,
		updated_weapon,
		AK47_DURATION_FRAMES,
		ak47_fire_interval_frames,
		ak47_burst_shots_remaining,
		ak47_recoil_accumulation,
		movement_multiplier,
		special_gauge
	)


func _clear_ak47_trigger_state() -> void:
	ak47_trigger_held = false
	ak47_burst_shots_remaining = 0


func _update_bazooka_input(
	input_snapshot: Dictionary,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	current_weapon: Dictionary,
	now_msec: int
) -> Dictionary:
	var action_pressed: bool = bool(input_snapshot.get("action_pressed", false))
	var action_just_pressed: bool = bool(input_snapshot.get("action_just_pressed", action_pressed))
	if not action_pressed:
		return {}
	if not action_just_pressed:
		return {}
	if bool(input_snapshot.get("down_pressed", false)):
		return {}
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	if CommandoFirearmInputResolver.is_fire_suppressed_after_switch(
		weapon_controller,
		now_msec,
		SWITCH_FIRE_SUPPRESS_MSEC
	):
		return {}
	var failure_fields := {
		"cooldown_frames": bazooka_cooldown_frames,
		"control_lock_frames": bazooka_control_lock_frames,
		"fire_animation_frames": bazooka_fire_animation_frames,
		"firing_pose_frames": bazooka_firing_pose_frames,
		"muzzle_flash_frames": bazooka_muzzle_flash_frames,
	}
	if bazooka_control_lock_frames > 0.0:
		return CommandoFirearmFireResultState.build_fire_failed_result("bazooka", special_gauge, "bazooka_control_lock", failure_fields)
	if bazooka_cooldown_frames > 0.0:
		return CommandoFirearmFireResultState.build_fire_failed_result("bazooka", special_gauge, "bazooka_cooldown", failure_fields)
	if not CommandoFirearmCooldownState.is_ready("bazooka", now_msec, deps):
		return CommandoFirearmFireResultState.build_fire_failed_result("bazooka", special_gauge, "configured_cooldown", failure_fields)
	var ammo_current: int = int(current_weapon.get("ammo_current", 0))
	if ammo_current <= 0 or not bool(current_weapon.get("can_fire", true)):
		return CommandoFirearmFireResultState.build_fire_failed_result("bazooka", special_gauge, "bazooka_empty", failure_fields)
	if weapon_controller != null and weapon_controller.has_method("consume_current_weapon_ammo"):
		if not bool(weapon_controller.consume_current_weapon_ammo(1)):
			return CommandoFirearmFireResultState.build_fire_failed_result("bazooka", special_gauge, "bazooka_ammo_unavailable", failure_fields)
	last_fire_msec = now_msec
	var doping_context: Dictionary = CommandoFirearmValueUtils.get_doping_potion_context_from_deps(
		deps,
		DOPING_POTION_DEFAULTS
	)
	var doping_active: bool = bool(doping_context.get("active", false))
	bazooka_cooldown_max_frames = CommandoFirearmValueUtils.get_bazooka_cooldown_frames(
		doping_context,
		doping_active,
		BAZOOKA_COOLDOWN_FRAMES,
		DOPING_POTION_BAZOOKA_COOLDOWN_FRAMES
	)
	bazooka_control_lock_max_frames = CommandoFirearmValueUtils.get_bazooka_control_lock_frames(
		doping_context,
		doping_active,
		BAZOOKA_CONTROL_LOCK_FRAMES,
		DOPING_POTION_BAZOOKA_CONTROL_LOCK_FRAMES
	)
	bazooka_cooldown_frames = bazooka_cooldown_max_frames
	bazooka_control_lock_frames = bazooka_control_lock_max_frames
	bazooka_fire_animation_frames = BAZOOKA_FIRE_ANIMATION_FRAMES
	bazooka_firing_pose_frames = BAZOOKA_FIRING_POSE_FRAMES
	bazooka_muzzle_flash_frames = BAZOOKA_MUZZLE_FLASH_FRAMES
	CommandoFirearmCooldownState.trigger_skill_cooldown(
		"bazooka",
		now_msec,
		deps,
		doping_context,
		doping_active,
		DOPING_POTION_FIRE_RATE_MULTIPLIER
	)
	_spawn_firearm_effect(
		"bazooka",
		config,
		deps,
		CommandoFirearmProfileResolver.get_weapon_profile(
			"bazooka",
			WEAPON_PROFILES,
			WEAPON_PROFILE_OVERRIDES
		)
	)
	CommandoFirearmAudioDispatcher.play_fire_audio("bazooka", deps)
	var updated_weapon: Dictionary = current_weapon
	if weapon_controller != null and weapon_controller.has_method("get_current_weapon_data"):
		updated_weapon = weapon_controller.get_current_weapon_data()
	return CommandoFirearmFireResultState.build_ammo_weapon_fired_result(
		"bazooka",
		updated_weapon,
		max(0, ammo_current - 1),
		BAZOOKA_AMMO_MAX,
		special_gauge,
		{
			"cooldown_frames": bazooka_cooldown_frames,
			"control_lock_frames": bazooka_control_lock_frames,
			"fire_animation_frames": bazooka_fire_animation_frames,
			"firing_pose_frames": bazooka_firing_pose_frames,
			"muzzle_flash_frames": bazooka_muzzle_flash_frames,
		}
	)


func _update_net_gun_input(
	input_snapshot: Dictionary,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	current_weapon: Dictionary,
	now_msec: int
) -> Dictionary:
	var action_pressed: bool = bool(input_snapshot.get("action_pressed", false))
	var action_just_pressed: bool = bool(input_snapshot.get("action_just_pressed", action_pressed))
	if not action_pressed:
		return {}
	if not action_just_pressed:
		return {}
	if bool(input_snapshot.get("down_pressed", false)):
		return {}
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	if CommandoFirearmInputResolver.is_fire_suppressed_after_switch(
		weapon_controller,
		now_msec,
		SWITCH_FIRE_SUPPRESS_MSEC
	):
		return {}
	var failure_fields := {
		"cooldown_frames": net_gun_cooldown_frames,
		"control_lock_frames": net_gun_control_lock_frames,
		"throw_pose_frames": net_gun_throw_pose_frames,
		"harpoon_flash_frames": net_gun_harpoon_flash_frames,
	}
	if net_gun_control_lock_frames > 0.0:
		return CommandoFirearmFireResultState.build_fire_failed_result("net_gun", special_gauge, "net_gun_control_lock", failure_fields)
	if net_gun_cooldown_frames > 0.0:
		return CommandoFirearmFireResultState.build_fire_failed_result("net_gun", special_gauge, "net_gun_cooldown", failure_fields)
	if not CommandoFirearmCooldownState.is_ready("net_gun", now_msec, deps):
		return CommandoFirearmFireResultState.build_fire_failed_result("net_gun", special_gauge, "configured_cooldown", failure_fields)
	var ammo_current: int = int(current_weapon.get("ammo_current", 0))
	if ammo_current <= 0 or not bool(current_weapon.get("can_fire", true)):
		return CommandoFirearmFireResultState.build_fire_failed_result("net_gun", special_gauge, "net_gun_empty", failure_fields)
	if weapon_controller != null and weapon_controller.has_method("consume_current_weapon_ammo"):
		if not bool(weapon_controller.consume_current_weapon_ammo(1)):
			return CommandoFirearmFireResultState.build_fire_failed_result("net_gun", special_gauge, "net_gun_ammo_unavailable", failure_fields)
	last_fire_msec = now_msec
	net_gun_cooldown_frames = NET_GUN_COOLDOWN_FRAMES
	net_gun_control_lock_frames = NET_GUN_CONTROL_LOCK_FRAMES
	net_gun_throw_pose_frames = NET_GUN_THROW_POSE_FRAMES
	net_gun_harpoon_flash_frames = NET_GUN_HARPOON_FLASH_FRAMES
	CommandoFirearmCooldownState.trigger_configured_cooldown("net_gun", now_msec, deps)
	_spawn_firearm_effect(
		"net_gun",
		config,
		deps,
		CommandoFirearmProfileResolver.get_weapon_profile(
			"net_gun",
			WEAPON_PROFILES,
			WEAPON_PROFILE_OVERRIDES
		)
	)
	CommandoFirearmAudioDispatcher.play_fire_audio("net_gun", deps)
	var updated_weapon: Dictionary = current_weapon
	if weapon_controller != null and weapon_controller.has_method("get_current_weapon_data"):
		updated_weapon = weapon_controller.get_current_weapon_data()
	return CommandoFirearmFireResultState.build_ammo_weapon_fired_result(
		"net_gun",
		updated_weapon,
		max(0, ammo_current - 1),
		NET_GUN_AMMO_MAX,
		special_gauge,
		{
			"cooldown_frames": net_gun_cooldown_frames,
			"control_lock_frames": net_gun_control_lock_frames,
			"throw_pose_frames": net_gun_throw_pose_frames,
			"harpoon_flash_frames": net_gun_harpoon_flash_frames,
		}
	)


func _update_bowling_trap_input(
	input_snapshot: Dictionary,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	current_weapon: Dictionary,
	now_msec: int
) -> Dictionary:
	var action_pressed: bool = bool(input_snapshot.get("action_pressed", false))
	if not action_pressed:
		bowling_trap_last_action_pressed = false
		return {}
	var action_just_pressed: bool = bool(input_snapshot.get(
		"action_just_pressed",
		action_pressed and not bowling_trap_last_action_pressed
	))
	bowling_trap_last_action_pressed = action_pressed
	if not action_just_pressed:
		return {}
	if bool(input_snapshot.get("down_pressed", false)):
		return {}
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	if CommandoFirearmInputResolver.is_fire_suppressed_after_switch(
		weapon_controller,
		now_msec,
		SWITCH_FIRE_SUPPRESS_MSEC
	):
		return {}
	var failure_fields := {
		"cooldown_frames": bowling_trap_cooldown_frames,
		"control_lock_frames": bowling_trap_control_lock_frames,
		"install_pose_frames": bowling_trap_install_pose_frames,
	}
	if bowling_trap_control_lock_frames > 0.0:
		return CommandoFirearmFireResultState.build_fire_failed_result("bowling_trap", special_gauge, "bowling_trap_control_lock", failure_fields)
	if bowling_trap_cooldown_frames > 0.0:
		return CommandoFirearmFireResultState.build_fire_failed_result("bowling_trap", special_gauge, "bowling_trap_cooldown", failure_fields)
	if CommandoFirearmBowlingTrapGeometry.has_installing_trap(bowling_traps):
		return CommandoFirearmFireResultState.build_fire_failed_result("bowling_trap", special_gauge, "bowling_trap_installing", failure_fields)
	if not CommandoFirearmBowlingTrapGeometry.is_install_in_player_field(
		config,
		FIELD_WIDTH,
		FIELD_HEIGHT,
		BOWLING_TRAP_MIN_FIELD_Y_RATIO
	):
		return CommandoFirearmFireResultState.build_fire_failed_result("bowling_trap", special_gauge, "bowling_trap_install_field", failure_fields)
	if not CommandoFirearmCooldownState.is_ready("bowling_trap", now_msec, deps):
		return CommandoFirearmFireResultState.build_fire_failed_result("bowling_trap", special_gauge, "configured_cooldown", failure_fields)
	var ammo_current: int = int(current_weapon.get("ammo_current", 0))
	if ammo_current <= 0 or not bool(current_weapon.get("can_fire", true)):
		return CommandoFirearmFireResultState.build_fire_failed_result("bowling_trap", special_gauge, "bowling_trap_empty", failure_fields)
	if weapon_controller != null and weapon_controller.has_method("consume_current_weapon_ammo"):
		if not bool(weapon_controller.consume_current_weapon_ammo(1)):
			return CommandoFirearmFireResultState.build_fire_failed_result("bowling_trap", special_gauge, "bowling_trap_ammo_unavailable", failure_fields)
	last_fire_msec = now_msec
	bowling_trap_cooldown_frames = BOWLING_TRAP_COOLDOWN_FRAMES
	bowling_trap_control_lock_frames = BOWLING_TRAP_CONTROL_LOCK_FRAMES
	bowling_trap_install_pose_frames = BOWLING_TRAP_INSTALL_FRAMES
	CommandoFirearmCooldownState.trigger_configured_cooldown("bowling_trap", now_msec, deps)
	_spawn_firearm_effect(
		"bowling_trap",
		config,
		deps,
		CommandoFirearmProfileResolver.get_weapon_profile(
			"bowling_trap",
			WEAPON_PROFILES,
			WEAPON_PROFILE_OVERRIDES
		)
	)
	CommandoFirearmAudioDispatcher.play_fire_audio("bowling_trap", deps)
	var updated_weapon: Dictionary = current_weapon
	if weapon_controller != null and weapon_controller.has_method("get_current_weapon_data"):
		updated_weapon = weapon_controller.get_current_weapon_data()
	return CommandoFirearmFireResultState.build_ammo_weapon_fired_result(
		"bowling_trap",
		updated_weapon,
		max(0, ammo_current - 1),
		BOWLING_TRAP_AMMO_MAX,
		special_gauge,
		{
			"cooldown_frames": bowling_trap_cooldown_frames,
			"control_lock_frames": bowling_trap_control_lock_frames,
			"install_pose_frames": bowling_trap_install_pose_frames,
			"install_progress": 0.0,
		}
	)


func _update_suicide_drone_input(
	input_snapshot: Dictionary,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	current_weapon: Dictionary,
	now_msec: int
) -> Dictionary:
	var action_pressed: bool = bool(input_snapshot.get("action_pressed", false))
	if not action_pressed:
		return {}
	if not CommandoFirearmInputResolver.input_action_just_pressed(input_snapshot):
		return {}
	if bool(input_snapshot.get("down_pressed", false)):
		return {}
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	if CommandoFirearmInputResolver.is_fire_suppressed_after_switch(
		weapon_controller,
		now_msec,
		SWITCH_FIRE_SUPPRESS_MSEC
	):
		return {}
	if suicide_drone_cooldown_frames > 0.0:
		return CommandoFirearmSuicideDroneState.build_fire_failed_result(special_gauge, "suicide_drone_cooldown", suicide_drone_cooldown_frames)
	if CommandoFirearmSuicideDroneState.has_active_projectile(projectiles):
		return CommandoFirearmSuicideDroneState.build_fire_failed_result(special_gauge, "suicide_drone_active", suicide_drone_cooldown_frames)
	if not CommandoFirearmCooldownState.is_ready("suicide_drone", now_msec, deps):
		return CommandoFirearmSuicideDroneState.build_fire_failed_result(special_gauge, "configured_cooldown", suicide_drone_cooldown_frames)
	var ammo_current: int = int(current_weapon.get("ammo_current", 0))
	if ammo_current <= 0 or not bool(current_weapon.get("can_fire", true)):
		return CommandoFirearmSuicideDroneState.build_fire_failed_result(special_gauge, "suicide_drone_empty", suicide_drone_cooldown_frames)
	if weapon_controller != null and weapon_controller.has_method("consume_current_weapon_ammo"):
		if not bool(weapon_controller.consume_current_weapon_ammo(1)):
			return CommandoFirearmSuicideDroneState.build_fire_failed_result(special_gauge, "suicide_drone_ammo_unavailable", suicide_drone_cooldown_frames)
	last_fire_msec = now_msec
	suicide_drone_last_action_pressed = action_pressed
	var fire_sheet_state: Dictionary = CommandoFirearmFireSheetResolver.build_animation_state(
		"suicide_drone",
		COMMANDO_WEAPON_FIRE_SHEET_DEFAULT_FRAMES,
		COMMANDO_WEAPON_FIRE_SHEET_LONG_FRAMES,
		COMMANDO_WEAPON_FIRE_SHEET_FRAME_COUNT
	)
	if not fire_sheet_state.is_empty():
		weapon_fire_sheet_id = str(fire_sheet_state.get("id", ""))
		weapon_fire_sheet_timer_frames = float(fire_sheet_state.get("timer_frames", 0.0))
		weapon_fire_sheet_max_frames = float(fire_sheet_state.get("max_frames", 0.0))
	_spawn_suicide_drone(config)
	CommandoFirearmAudioDispatcher.play_fire_audio("suicide_drone", deps)
	CommandoFirearmCooldownState.trigger_configured_cooldown("suicide_drone", now_msec, deps)
	var updated_weapon: Dictionary = current_weapon
	if weapon_controller != null and weapon_controller.has_method("get_current_weapon_data"):
		updated_weapon = weapon_controller.get_current_weapon_data()
	return CommandoFirearmSuicideDroneState.build_fire_result(
		updated_weapon,
		ammo_current,
		SUICIDE_DRONE_AMMO_MAX,
		SUICIDE_DRONE_GRACE_FRAMES,
		special_gauge
	)


func _update_active_suicide_drone_input(
	input_snapshot: Dictionary,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var index: int = CommandoFirearmSuicideDroneState.get_active_projectile_index(projectiles)
	if index < 0:
		return {}
	var projectile: Dictionary = CommandoFirearmValueUtils.get_dict(projectiles[index])
	var input_vector: Vector2 = CommandoFirearmInputResolver.get_suicide_drone_input_vector(input_snapshot)
	var next_projectile: Dictionary = CommandoFirearmSuicideDroneState.apply_input(
		projectile,
		input_vector,
		SUICIDE_DRONE_ACCEL,
		SUICIDE_DRONE_MAX_SPEED,
		SUICIDE_DRONE_ROTOR_BASE_SPEED,
		SUICIDE_DRONE_ROTOR_SPEED_SCALE
	)
	projectile.clear()
	projectile.merge(next_projectile, true)
	projectiles[index] = projectile
	var action_pressed: bool = bool(input_snapshot.get("action_pressed", false))
	var action_just_pressed: bool = bool(input_snapshot.get(
		"action_just_pressed",
		action_pressed and not suicide_drone_last_action_pressed
	))
	suicide_drone_last_action_pressed = action_pressed
	if float(projectile.get("grace_timer_frames", 0.0)) <= 0.0 and action_just_pressed:
		var detonate_result: Dictionary = _detonate_suicide_drone_at_index(index, projectile, "manual", config, deps)
		detonate_result["special_gauge"] = special_gauge
		return detonate_result
	return CommandoFirearmSuicideDroneState.build_active_input_result(projectile, special_gauge)


func _spawn_suicide_drone(config: Dictionary) -> void:
	var profile: Dictionary = CommandoFirearmProfileResolver.get_weapon_profile(
		"suicide_drone",
		WEAPON_PROFILES,
		WEAPON_PROFILE_OVERRIDES
	)
	var origin: Vector2 = CommandoFirearmSuicideDroneGeometry.get_spawn_pos(
		config,
		FIELD_WIDTH,
		FIELD_HEIGHT,
		SUICIDE_DRONE_SIZE
	)
	var shot_id: int = _next_shot_id()
	CommandoFirearmValueUtils.append_limited(
		projectiles,
		CommandoFirearmSuicideDroneState.build_projectile(
			profile,
			origin,
			CommandoFirearmOriginGeometry.get_boss_target_pos(config, FIELD_WIDTH),
			shot_id,
			CommandoFirearmSuicideDroneGeometry.get_player_lock_pos(config, FIELD_WIDTH, FIELD_HEIGHT),
			SUICIDE_DRONE_SIZE,
			SUICIDE_DRONE_MAX_SPEED,
			SUICIDE_DRONE_ACCEL,
			SUICIDE_DRONE_LIFE_FRAMES,
			SUICIDE_DRONE_GRACE_FRAMES,
			SUICIDE_DRONE_ROTOR_BASE_SPEED
		),
		PROJECTILE_LIMIT
	)
	CommandoFirearmValueUtils.append_limited(
		muzzle_flashes,
		CommandoFirearmMuzzleFlashResolver.build_flash(origin, Vector2.UP, profile, "suicide_drone"),
		FLASH_LIMIT
	)

func _advance_slingshot_charge(special_gauge: float) -> Dictionary:
	var charge_result: Dictionary = CommandoFirearmSlingshotState.advance_charge(
		slingshot_charge_timer_frames,
		slingshot_gauge_spent,
		special_gauge,
		SLINGSHOT_GAUGE_COST,
		SLINGSHOT_GAUGE_DRAIN_INTERVAL_FRAMES,
		SLINGSHOT_CHARGE_THRESHOLD_1,
		SLINGSHOT_CHARGE_THRESHOLD_2,
		SLINGSHOT_CHARGE_THRESHOLD_3
	)
	slingshot_charge_timer_frames = float(charge_result.get("charge_timer_frames", slingshot_charge_timer_frames))
	slingshot_charge_level = int(charge_result.get("charge_level", slingshot_charge_level))
	slingshot_gauge_spent = float(charge_result.get("gauge_spent", slingshot_gauge_spent))
	return {
		"special_gauge": float(charge_result.get("special_gauge", special_gauge)),
		"force_release": bool(charge_result.get("force_release", false)),
	}


func _release_slingshot(special_gauge: float, config: Dictionary, deps: Dictionary, reason: String = "released") -> Dictionary:
	var charge_level: int = slingshot_charge_level
	var charge_time: float = slingshot_charge_timer_frames
	slingshot_charging = false
	slingshot_charge_timer_frames = 0.0
	slingshot_charge_level = 0
	slingshot_gauge_spent = 0.0
	if charge_time < SLINGSHOT_GAUGE_DRAIN_INTERVAL_FRAMES or charge_level < 1:
		return CommandoFirearmSlingshotState.build_charge_canceled_result(BASE_WEAPON_ID, special_gauge)
	var slingshot_profile: Dictionary = CommandoFirearmSlingshotState.build_fire_profile(
		CommandoFirearmProfileResolver.get_weapon_profile(
			BASE_WEAPON_ID,
			WEAPON_PROFILES,
			WEAPON_PROFILE_OVERRIDES
		),
		charge_level,
		SLINGSHOT_PYTHON_SPEED_BY_LEVEL,
		SLINGSHOT_BASE_BULLET_SPEED,
		SLINGSHOT_PELLET_SIZE
	)
	_spawn_firearm_effect(BASE_WEAPON_ID, config, deps, slingshot_profile)
	CommandoFirearmAudioDispatcher.play_fire_audio(BASE_WEAPON_ID, deps)
	last_fire_msec = Time.get_ticks_msec()
	slingshot_cooldown_frames = SLINGSHOT_COOLDOWN_FRAMES
	slingshot_control_lock_frames = SLINGSHOT_CONTROL_LOCK_FRAMES
	return CommandoFirearmSlingshotState.build_release_result(
		BASE_WEAPON_ID,
		charge_level,
		charge_time,
		SLINGSHOT_CONTROL_LOCK_FRAMES,
		reason,
		special_gauge
	)


func _cancel_slingshot_charge(special_gauge: float) -> float:
	slingshot_charging = false
	slingshot_charge_timer_frames = 0.0
	slingshot_charge_level = 0
	slingshot_gauge_spent = 0.0
	return special_gauge


func _spawn_firearm_effect(weapon_id: String, config: Dictionary, deps: Dictionary, profile_override: Dictionary = {}) -> void:
	var fire_sheet_state: Dictionary = CommandoFirearmFireSheetResolver.build_animation_state(
		weapon_id,
		COMMANDO_WEAPON_FIRE_SHEET_DEFAULT_FRAMES,
		COMMANDO_WEAPON_FIRE_SHEET_LONG_FRAMES,
		COMMANDO_WEAPON_FIRE_SHEET_FRAME_COUNT
	)
	if not fire_sheet_state.is_empty():
		weapon_fire_sheet_id = str(fire_sheet_state.get("id", ""))
		weapon_fire_sheet_timer_frames = float(fire_sheet_state.get("timer_frames", 0.0))
		weapon_fire_sheet_max_frames = float(fire_sheet_state.get("max_frames", 0.0))
	var profile: Dictionary = profile_override.duplicate(true)
	if profile.is_empty():
		profile = CommandoFirearmProfileResolver.get_weapon_profile(
			weapon_id,
			WEAPON_PROFILES,
			WEAPON_PROFILE_OVERRIDES
		)
	var doping_context: Dictionary = CommandoFirearmValueUtils.normalize_doping_potion_context(
		config,
		DOPING_POTION_DEFAULTS
	)
	if weapon_id == "commando_pistol" and bool(doping_context.get("active", false)):
		profile["speed"] = float(profile.get("speed", PISTOL_BULLET_SPEED)) * float(doping_context.get("pistol_speed_multiplier", DOPING_POTION_PISTOL_SPEED_MULTIPLIER))
		profile["color"] = Color(1.0, 0.47, 0.24)
		profile["secondary"] = Color(1.0, 0.78, 0.22)
	if (
		CommandoFirearmValueUtils.is_pistol_weapon(weapon_id, BASE_WEAPON_ID)
		and not bool(profile.get("slingshot", false))
		and not profile.has("angle_offset")
	):
		var spread_radians: float = BERETTA_SPREAD_RADIANS if weapon_id == "commando_pistol" else PISTOL_SPREAD_RADIANS
		profile["angle_offset"] = randf_range(-spread_radians, spread_radians)
	var kind: String = str(profile.get("kind", "bullet"))
	var origin: Vector2 = CommandoFirearmOriginGeometry.get_firearm_origin(
		weapon_id,
		config,
		profile,
		Vector2(FIELD_WIDTH, FIELD_HEIGHT),
		COMMANDO_FIRE_SHEET_SOURCE_CELL_SIZE,
		COMMANDO_FIRE_SHEET_PLAYER_FOOT_Y_OFFSET,
		COMMANDO_PISTOL_FIRE_MUZZLE_SOURCE,
		COMMANDO_BAZOOKA_FIRE_MUZZLE_SOURCE,
		COMMANDO_NET_GUN_FIRE_MUZZLE_SOURCE,
		BASE_WEAPON_ID
	)
	var target: Vector2 = CommandoFirearmOriginGeometry.get_boss_target_pos(config, FIELD_WIDTH)
	var aim_origin: Vector2 = CommandoFirearmOriginGeometry.get_firearm_aim_origin(weapon_id, origin)
	var angle_offset: float = float(profile.get("angle_offset", 0.0))
	var direction: Vector2 = CommandoFirearmProjectileSpawnState.get_fire_direction(
		target,
		aim_origin,
		bool(profile.get("vertical_launch", false)),
		angle_offset
	)
	CommandoFirearmValueUtils.append_limited(
		muzzle_flashes,
		CommandoFirearmMuzzleFlashResolver.build_flash(origin, direction, profile, weapon_id),
		FLASH_LIMIT
	)
	if kind == "support":
		_start_support_call(origin, target, profile, weapon_id, deps)
		return
	if kind == "trap" or weapon_id == "bowling_trap":
		_start_bowling_trap_install(config, profile, weapon_id)
		return
	var speed: float = float(profile.get("speed", 16.0))
	var shot_id: int = _next_shot_id()
	var projectile: Dictionary = CommandoFirearmProjectileSpawnState.build_projectile(
		weapon_id,
		kind,
		shot_id,
		origin,
		target,
		direction,
		speed,
		angle_offset,
		aim_origin,
		profile,
		doping_context,
		BAZOOKA_SMOKE_TRAIL_LIMIT,
		NET_GUN_ROPE_TRAIL_LIMIT,
		DOPING_POTION_HEAD_LEG_MULTIPLIER,
		DOPING_POTION_PISTOL_SPEED_MULTIPLIER
	)
	CommandoFirearmValueUtils.append_limited(projectiles, projectile, PROJECTILE_LIMIT)
	if weapon_id == "ak47":
		CommandoFirearmValueUtils.append_limited(
			shell_casings,
			CommandoFirearmShellCasingState.build_ak47_shell(
				origin,
				direction,
				config,
				shot_id,
				FIELD_HEIGHT,
				AK47_SHELL_LIFETIME_FRAMES
			),
			SHELL_CASING_LIMIT
		)
	elif weapon_id == "pistol" or weapon_id == "commando_pistol":
		CommandoFirearmValueUtils.append_limited(
			shell_casings,
			CommandoFirearmShellCasingState.build_pistol_shell(
				origin,
				direction,
				config,
				shot_id,
				weapon_id,
				FIELD_HEIGHT,
				PISTOL_SHELL_LIFETIME_FRAMES
			),
			SHELL_CASING_LIMIT
		)


func _start_support_call(origin: Vector2, target: Vector2, profile: Dictionary, weapon_id: String, deps: Dictionary) -> void:
	var call_id: int = _next_shot_id()
	var delay_frames: float = CommandoFirearmSupportCallResolver.get_delay_frames(
		call_id,
		target,
		SUPPORT_CALL_DELAY_MIN_FRAMES,
		SUPPORT_CALL_DELAY_MAX_FRAMES
	)
	var bomb_count: int = CommandoFirearmSupportCallResolver.get_bomb_count(
		call_id,
		target,
		SUPPORT_BOMB_MIN_COUNT,
		SUPPORT_BOMB_MAX_COUNT
	)
	while support_calls.size() >= max(1, SUPPORT_CALL_LIMIT):
		var evicted: Dictionary = CommandoFirearmValueUtils.get_dict(support_calls.pop_front())
		CommandoFirearmAudioDispatcher.stop_support_aircraft_audio(evicted, deps)
	support_calls.append(CommandoFirearmSupportCallResolver.build_call_payload(
		call_id,
		origin,
		target,
		profile,
		weapon_id,
		delay_frames,
		bomb_count,
		SUPPORT_CALL_LOCK_FRAMES,
		SUPPORT_AIRCRAFT_DROP_ARM_FRAMES,
		SUPPORT_AIRCRAFT_Y,
		SUPPORT_AIRCRAFT_SPEED,
		SUPPORT_AIRCRAFT_CURVE_AMPLITUDE,
		SUPPORT_AIRCRAFT_CURVE_FREQUENCY,
		SUPPORT_AIRCRAFT_CURVE_SECONDARY_RATIO,
		SUPPORT_AIRCRAFT_START_X
	))
	CommandoFirearmAudioDispatcher.play_first_audio_method(deps, ["play_commando_fire_support_radio", "play_commando_supply_radio"])
	CommandoFirearmValueUtils.append_limited(impact_flashes, CommandoFirearmSupportCallResolver.build_marker_flash(
		weapon_id,
		target,
		profile,
		SUPPORT_CALL_LOCK_FRAMES
	), FLASH_LIMIT)


func _start_bowling_trap_install(config: Dictionary, profile: Dictionary, weapon_id: String) -> void:
	var trap_pos: Vector2 = CommandoFirearmBowlingTrapGeometry.get_install_pos(
		config,
		FIELD_WIDTH,
		FIELD_HEIGHT,
		BOWLING_TRAP_WIDTH,
		BOWLING_TRAP_HEIGHT,
		BOWLING_TRAP_MIN_FIELD_Y_RATIO
	)
	var trap_id: int = _next_shot_id()
	CommandoFirearmValueUtils.append_limited(bowling_traps, CommandoFirearmBowlingTrapGeometry.build_install_trap(
		trap_pos,
		profile,
		weapon_id,
		trap_id,
		BOWLING_TRAP_WIDTH,
		BOWLING_TRAP_HEIGHT,
		BOWLING_TRAP_INSTALL_FRAMES,
		BOWLING_TRAP_CAPTURE_BALL_OFFSET
	), BOWLING_TRAP_LIMIT)
	CommandoFirearmValueUtils.append_limited(impact_flashes, CommandoFirearmBowlingTrapGeometry.build_install_marker_flash(
		trap_pos,
		profile,
		weapon_id
	), FLASH_LIMIT)


func _spawn_support_round(
	target: Vector2,
	profile: Dictionary,
	weapon_id: String,
	call_id: int = 0,
	spawn_index: int = 0,
	support_aircraft_pos: Vector2 = Vector2(SUPPORT_AIRCRAFT_START_X, SUPPORT_AIRCRAFT_Y)
) -> void:
	CommandoFirearmValueUtils.append_limited(projectiles, CommandoFirearmSupportProjectileResolver.build_projectile(
		target,
		profile,
		weapon_id,
		_next_shot_id(),
		call_id,
		spawn_index,
		FIELD_WIDTH,
		FIELD_HEIGHT,
		support_aircraft_pos.y,
		SUPPORT_BOMB_INITIAL_VY,
		SUPPORT_BOMB_GRAVITY,
		SUPPORT_BOMB_HORIZONTAL_JITTER,
		support_aircraft_pos,
		SUPPORT_OPPONENT_WALL_Y,
		SUPPORT_MISSILE_FLIGHT_FRAMES,
		SUPPORT_MISSILE_LIFE_FRAMES,
		"opponent_wall"
	), PROJECTILE_LIMIT)


func _update_support_calls(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var step: float = max(0.0, fps_scale)
	var profile: Dictionary = CommandoFirearmProfileResolver.get_weapon_profile(
		"fire_support",
		WEAPON_PROFILES,
		WEAPON_PROFILE_OVERRIDES
	)
	for index in range(support_calls.size() - 1, -1, -1):
		@warning_ignore("shadowed_variable_base_class")
		var call: Dictionary = CommandoFirearmValueUtils.get_dict(support_calls[index])
		var advance_result: Dictionary = CommandoFirearmSupportCallResolver.advance_call(
			call,
			step,
			Vector2(SUPPORT_AIRCRAFT_START_X, SUPPORT_AIRCRAFT_Y),
			Vector2(SUPPORT_AIRCRAFT_SPEED, 0.0),
			SUPPORT_BOMB_INTERVAL_FRAMES,
			FIELD_WIDTH,
			SUPPORT_AIRCRAFT_FINISH_MARGIN,
			SUPPORT_AIRCRAFT_CURVE_AMPLITUDE,
			SUPPORT_AIRCRAFT_CURVE_FREQUENCY,
			SUPPORT_AIRCRAFT_CURVE_SECONDARY_RATIO
		)
		call = CommandoFirearmValueUtils.get_dict(advance_result.get("call", call))
		if bool(advance_result.get("started_aircraft", false)):
			CommandoFirearmAudioDispatcher.start_support_aircraft_audio(call, deps)
		if bool(advance_result.get("spawn_bomb", false)):
			_spawn_support_bomb(call, profile, context, int(advance_result.get("spawn_index", 0)))
		if bool(advance_result.get("finished", false)):
			CommandoFirearmAudioDispatcher.stop_support_aircraft_audio(call, deps)
			support_calls.remove_at(index)
		else:
			support_calls[index] = call


@warning_ignore("shadowed_variable_base_class")
func _spawn_support_bomb(call: Dictionary, profile: Dictionary, context: Dictionary, spawn_index: int) -> void:
	var target_fallback: Vector2 = CommandoFirearmOriginGeometry.get_boss_target_pos(context, FIELD_WIDTH)
	var target: Vector2 = CommandoFirearmValueUtils.get_vector2(call.get("target", target_fallback), target_fallback)
	var bomb_target: Vector2 = CommandoFirearmSupportCallResolver.get_bomb_target(
		target,
		spawn_index,
		FIELD_WIDTH,
		FIELD_HEIGHT,
		int(call.get("id", 0)),
		SUPPORT_BOMB_RANDOM_X_RANGE
	)
	bomb_target.y = SUPPORT_OPPONENT_WALL_Y
	var aircraft_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(call.get("aircraft_pos", Vector2(SUPPORT_AIRCRAFT_START_X, SUPPORT_AIRCRAFT_Y)), Vector2(SUPPORT_AIRCRAFT_START_X, SUPPORT_AIRCRAFT_Y))
	_spawn_support_round(
		bomb_target,
		profile,
		"fire_support",
		int(call.get("id", 0)),
		spawn_index,
		aircraft_pos
	)


func _update_bowling_traps(fps_scale: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	var step: float = max(0.0, fps_scale)
	var result: Dictionary = {}
	for index in range(bowling_traps.size() - 1, -1, -1):
		var trap: Dictionary = CommandoFirearmValueUtils.get_dict(bowling_traps[index])
		var state: String = str(trap.get("state", "waiting"))
		if state == "installing":
			_update_bowling_trap_install(index, trap, step)
		elif state == "waiting":
			if (
				result.is_empty()
				and CommandoFirearmBowlingTrapGeometry.hits_ball(
					trap,
					context,
					BOWLING_TRAP_HEIGHT,
					BOWLING_TRAP_CAPTURE_HEIGHT,
					BOWLING_TRAP_WIDTH
				)
			):
				_capture_bowling_trap_ball(index, trap, context, deps)
				result = CommandoFirearmBowlingTrapGeometry.build_capture_result(CommandoFirearmValueUtils.get_dict(bowling_traps[index]))
		elif state == "capturing":
			if result.is_empty():
				result = _update_bowling_trap_capture(index, trap, step, context, deps)
			else:
				_update_bowling_trap_capture(index, trap, step, context, deps)
		elif state == "launching" or state == "inactive":
			bowling_traps.remove_at(index)
		else:
			bowling_traps[index] = trap
	return result


func _update_bowling_trap_install(index: int, trap: Dictionary, fps_scale: float) -> void:
	bowling_traps[index] = CommandoFirearmBowlingTrapGeometry.update_install_state(
		trap,
		fps_scale,
		BOWLING_TRAP_INSTALL_FRAMES
	)


func _capture_bowling_trap_ball(index: int, trap: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var captured_trap: Dictionary = CommandoFirearmBowlingTrapGeometry.build_capture_state(
		trap,
		context,
		BOWLING_TRAP_CAPTURE_FRAMES,
		BOWLING_TRAP_CAPTURE_BALL_OFFSET
	)
	var ball_vel: Vector2 = CommandoFirearmValueUtils.get_vector2(captured_trap.get("captured_original_vel", Vector2.ZERO), Vector2.ZERO)
	var captured_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(captured_trap.get("captured_ball_pos", Vector2.ZERO), Vector2.ZERO)
	bowling_traps[index] = captured_trap
	CommandoFirearmHitFeedbackDispatcher.trigger_hit_feedback(
		CommandoFirearmProfileResolver.get_hit_feedback_profile(
			"bowling_trap",
			WEAPON_HIT_FEEDBACK,
			HIT_FEEDBACK_PROFILE_OVERRIDES
		),
		deps
	)
	CommandoFirearmHitFeedbackDispatcher.register_ball_hit_pulse(captured_pos, ball_vel, 0.62, "bowling_trap_capture", deps, BASE_WEAPON_ID)
	CommandoFirearmAudioDispatcher.play_impact_audio("bowling_trap", deps)


func _update_bowling_trap_capture(index: int, trap: Dictionary, fps_scale: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	var next_trap: Dictionary = CommandoFirearmBowlingTrapGeometry.update_capture_state(
		trap,
		fps_scale,
		BOWLING_TRAP_CAPTURE_FRAMES
	)
	if CommandoFirearmBowlingTrapGeometry.is_capture_complete(next_trap):
		var launch_result: Dictionary = _release_bowling_trap_ball(next_trap, context, deps)
		bowling_traps.remove_at(index)
		return launch_result
	bowling_traps[index] = next_trap
	return CommandoFirearmBowlingTrapGeometry.build_capture_result(next_trap)


func _release_bowling_trap_ball(trap: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	var motion: Dictionary = CommandoFirearmBowlingTrapGeometry.build_release_motion(
		trap,
		BOWLING_TRAP_CAPTURE_BALL_OFFSET,
		BOWLING_TRAP_LAUNCH_SPEED_MULTIPLIER,
		BOWLING_TRAP_LAUNCH_ANGLE_STEP
	)
	var profile: Dictionary = CommandoFirearmProfileResolver.get_weapon_profile(
		"bowling_trap",
		WEAPON_PROFILES,
		WEAPON_PROFILE_OVERRIDES
	)
	var pseudo_projectile: Dictionary = CommandoFirearmBowlingTrapGeometry.build_release_pseudo_projectile(
		trap,
		motion,
		profile
	)
	_spawn_impact_flash(pseudo_projectile)
	_spawn_lingering_effect("bowling_trap", pseudo_projectile, context)
	CommandoFirearmHitFeedbackDispatcher.trigger_hit_feedback(
		CommandoFirearmProfileResolver.get_hit_feedback_profile(
			"bowling_trap",
			WEAPON_HIT_FEEDBACK,
			HIT_FEEDBACK_PROFILE_OVERRIDES
		),
		deps
	)
	var captured_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(motion.get("captured_pos", Vector2.ZERO), Vector2.ZERO)
	var launch_vel: Vector2 = CommandoFirearmValueUtils.get_vector2(motion.get("launch_vel", Vector2.ZERO), Vector2.ZERO)
	CommandoFirearmHitFeedbackDispatcher.register_ball_hit_pulse(captured_pos, launch_vel, 0.86, "bowling_trap_launch", deps, BASE_WEAPON_ID)
	var guard_state: Dictionary = CommandoFirearmBowlingTrapGeometry.build_guard_state(
		trap,
		float(motion.get("original_speed", 1.0)),
		BOWLING_TRAP_GUARD_SPEED_REDUCTION
	)
	bowling_trap_guard_armed = bool(guard_state.get("armed", false))
	bowling_trap_guard_original_speed = float(guard_state.get("original_speed", 0.0))
	bowling_trap_guard_restore_speed = float(guard_state.get("restore_speed", 0.0))
	bowling_trap_guard_source = str(guard_state.get("source", ""))
	return CommandoFirearmBowlingTrapGeometry.build_release_result(
		motion,
		bowling_trap_guard_source,
		BOWLING_TRAP_GUARD_KNOCKBACK_POWER,
		BOWLING_TRAP_GUARD_STUN_FRAMES,
		BOWLING_TRAP_GUARD_SPEED_REDUCTION
	)


func _clear_bowling_trap_guard() -> void:
	var guard_state: Dictionary = CommandoFirearmBowlingTrapGeometry.build_cleared_guard_state()
	bowling_trap_guard_armed = bool(guard_state.get("armed", false))
	bowling_trap_guard_original_speed = float(guard_state.get("original_speed", 0.0))
	bowling_trap_guard_restore_speed = float(guard_state.get("restore_speed", 0.0))
	bowling_trap_guard_source = str(guard_state.get("source", ""))


func _update_projectiles(fps_scale: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	var step: float = max(0.0, fps_scale)
	var result: Dictionary = {}
	for index in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = CommandoFirearmValueUtils.get_dict(projectiles[index])
		var projectile_kind: String = CommandoFirearmValueUtils.get_projectile_kind(projectile)
		var projectile_weapon_id: String = CommandoFirearmValueUtils.get_projectile_weapon_id(
			projectile,
			BASE_WEAPON_ID
		)
		var is_pistol_projectile: bool = CommandoFirearmValueUtils.is_pistol_weapon(
			projectile_weapon_id,
			BASE_WEAPON_ID
		)
		var pos: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
		var velocity: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
		if projectile_kind == "drone":
			velocity = CommandoFirearmSuicideDroneState.get_homing_velocity(
				pos,
				projectile,
				CommandoFirearmOriginGeometry.get_boss_target_pos(context, FIELD_WIDTH),
				fps_scale
			)
		elif projectile_kind == "rocket":
			var motion_result: Dictionary = CommandoFirearmProjectileMotionState.update_rocket_motion(
				projectile,
				pos,
				velocity,
				step,
				BAZOOKA_ACCELERATION,
				BAZOOKA_MAX_SPEED,
				BAZOOKA_SMOKE_TRAIL_LIMIT
			)
			projectile.clear()
			projectile.merge(CommandoFirearmValueUtils.get_dict(motion_result.get("projectile", projectile)), true)
			velocity = CommandoFirearmValueUtils.get_vector2(motion_result.get("velocity", velocity), velocity)
		if projectile.has("gravity"):
			velocity.y += float(projectile.get("gravity", 0.0)) * step
		var prev_pos: Vector2 = pos
		pos += velocity * step
		if is_pistol_projectile:
			var field_width: float = max(PISTOL_WALL_BOUNCE_MARGIN * 2.0, float(context.get("width", FIELD_WIDTH)))
			var bounce_result: Dictionary = CommandoFirearmProjectileMotionState.apply_pistol_side_wall_bounce(
				projectile,
				pos,
				velocity,
				field_width,
				PISTOL_WALL_BOUNCE_MARGIN,
				PISTOL_WALL_BOUNCE_MAX,
				PISTOL_WALL_BOUNCE_DAMPING
			)
			if bool(bounce_result.get("bounced", false)):
				projectile.clear()
				projectile.merge(CommandoFirearmValueUtils.get_dict(bounce_result.get("projectile", projectile)), true)
				pos = CommandoFirearmValueUtils.get_vector2(projectile.get("pos", pos), pos)
				velocity = CommandoFirearmValueUtils.get_vector2(projectile.get("velocity", velocity), velocity)
		projectile["prev_pos"] = prev_pos
		projectile["pos"] = pos
		projectile["velocity"] = velocity
		var rock_bounce_result: Dictionary = CommandoFirearmStage2RockInteractionResolver.apply_pistol_rock_bounce(
			projectile,
			context,
			deps,
			is_pistol_projectile
		)
		if bool(rock_bounce_result.get("consumed", false)):
			projectiles.remove_at(index)
			continue
		if bool(rock_bounce_result.get("bounced", false)):
			pos = CommandoFirearmValueUtils.get_vector2(projectile.get("pos", pos), pos)
			velocity = CommandoFirearmValueUtils.get_vector2(projectile.get("velocity", velocity), velocity)
		if projectile_kind == "net":
			var next_projectile: Dictionary = CommandoFirearmProjectileMotionState.update_net_projectile_rope(
				projectile,
				pos,
				CommandoFirearmOriginGeometry.get_commando_fire_sheet_world_pos(
					context,
					COMMANDO_NET_GUN_FIRE_MUZZLE_SOURCE,
					Vector2(FIELD_WIDTH, FIELD_HEIGHT),
					COMMANDO_FIRE_SHEET_SOURCE_CELL_SIZE,
					COMMANDO_FIRE_SHEET_PLAYER_FOOT_Y_OFFSET
				),
				NET_GUN_ROPE_TRAIL_LIMIT
			)
			projectile.clear()
			projectile.merge(next_projectile, true)
		projectile["prev_pos"] = CommandoFirearmValueUtils.get_vector2(projectile.get("prev_pos", prev_pos), prev_pos)
		projectile["pos"] = pos
		projectile["velocity"] = velocity
		projectile["life_frames"] = max(0.0, float(projectile.get("life_frames", 0.0)) - step)
		projectiles[index] = projectile
		if projectile_kind == "drone":
			var drone_result: Dictionary = _resolve_suicide_drone_collision(index, projectile, context, deps, step)
			if not drone_result.is_empty():
				result.merge(drone_result, true)
				context.merge(drone_result, true)
				continue
			continue
		var impact_reason: String = CommandoFirearmProjectileImpactState.get_impact_reason(
			projectile,
			context,
			WEAPON_PROFILES,
			WEAPON_PROFILE_OVERRIDES,
			BASE_WEAPON_ID,
			Vector2(FIELD_WIDTH, FIELD_HEIGHT),
			FIELD_WIDTH
		)
		if impact_reason != "":
			_spawn_impact_flash(projectile)
			_destroy_stage2_rocks_for_projectile_impact(projectile, context, deps)
			if impact_reason == "target":
				_register_projectile_hit(projectile, context, deps)
			elif impact_reason == "wall":
				var wall_result: Dictionary = _register_projectile_environment_impact(projectile, impact_reason, context, deps)
				result.merge(wall_result, true)
				context.merge(wall_result, true)
			elif CommandoFirearmHitGeometry.is_net_gun_weapon(projectile_weapon_id):
				_spawn_net_dissolve_effect(projectile, context)
			projectiles.remove_at(index)
			if projectile_kind == "drone" and not CommandoFirearmSuicideDroneState.has_active_projectile(projectiles):
				CommandoFirearmAudioDispatcher.stop_suicide_drone_audio(deps)
	return result


func _spawn_pistol_hit_feedback(hit_kind: String, context: Dictionary) -> void:
	var boss_rect: Rect2 = CommandoFirearmHitGeometry.get_boss_rect(context, FIELD_WIDTH)
	var feedback: Dictionary = CommandoFirearmPistolFeedbackState.build_feedback(
		hit_kind,
		boss_rect,
		Vector2(FIELD_WIDTH, FIELD_HEIGHT),
		PISTOL_HIT_TEXT_TIMER_FRAMES,
		"헤드샷!",
		"레그샷!"
	)
	if feedback.is_empty():
		return
	CommandoFirearmValueUtils.append_limited(pistol_feedbacks, feedback, PISTOL_FEEDBACK_LIMIT)


func _resolve_suicide_drone_collision(
	index: int,
	projectile: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	fps_scale: float
) -> Dictionary:
	if not bool(projectile.get("manual_control", false)):
		return {}
	var step: float = max(0.0, fps_scale)
	projectile = CommandoFirearmSuicideDroneState.advance_active_projectile(
		projectile,
		step,
		Vector2(FIELD_WIDTH, FIELD_HEIGHT),
		SUICIDE_DRONE_SIZE,
		SUICIDE_DRONE_ROTOR_BASE_SPEED
	)
	projectiles[index] = projectile
	if float(projectile.get("grace_timer_frames", 0.0)) > 0.0:
		return {}
	if CommandoFirearmSuicideDroneGeometry.hits_ball(projectile, context, SUICIDE_DRONE_SIZE):
		return _detonate_suicide_drone_at_index(index, projectile, "ball_hit", context, deps)
	if CommandoFirearmSuicideDroneGeometry.hits_boss_rect(
		projectile,
		CommandoFirearmHitGeometry.get_boss_rect(context, FIELD_WIDTH),
		SUICIDE_DRONE_SIZE
	):
		return _detonate_suicide_drone_at_index(index, projectile, "boss_hit", context, deps)
	if CommandoFirearmSuicideDroneGeometry.hits_top_wall(projectile, SUICIDE_DRONE_SIZE):
		return _detonate_suicide_drone_at_index(index, projectile, "boss_back_wall", context, deps)
	if float(projectile.get("life_frames", 0.0)) <= 0.0:
		return _detonate_suicide_drone_at_index(index, projectile, "expired", context, deps)
	return {}


func _detonate_suicide_drone_at_index(
	index: int,
	projectile: Dictionary,
	reason: String,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	if index >= 0 and index < projectiles.size():
		projectiles.remove_at(index)
	_spawn_impact_flash(projectile)
	var pos: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var hit_boss: bool = CommandoFirearmSuicideDroneGeometry.explosion_hits_boss(
		projectile,
		CommandoFirearmHitGeometry.get_boss_rect(context, FIELD_WIDTH),
		CommandoFirearmHitGeometry.get_explosion_radius(
			projectile,
			CommandoFirearmProfileResolver.get_weapon_profile(
				"suicide_drone",
				WEAPON_PROFILES,
				WEAPON_PROFILE_OVERRIDES
			)
		)
	)
	if hit_boss:
		_register_projectile_hit(projectile, context, deps)
	else:
		_spawn_suicide_drone_fire_zone(projectile, context, deps)
		CommandoFirearmHitFeedbackDispatcher.spawn_shared_impact_particles(pos, CommandoFirearmValueUtils.get_color(projectile.get("color", Color.WHITE), Color.WHITE), CommandoFirearmValueUtils.get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO), 1.0, deps)
		CommandoFirearmHitFeedbackDispatcher.trigger_hit_feedback(
			CommandoFirearmProfileResolver.get_hit_feedback_profile(
				"suicide_drone",
				WEAPON_HIT_FEEDBACK,
				HIT_FEEDBACK_PROFILE_OVERRIDES
			),
			deps
		)
		CommandoFirearmHitFeedbackDispatcher.register_ball_hit_pulse(pos, CommandoFirearmValueUtils.get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO), 0.86, "suicide_drone", deps, BASE_WEAPON_ID)
		CommandoFirearmAudioDispatcher.play_impact_audio("suicide_drone", deps)
	CommandoFirearmAudioDispatcher.stop_suicide_drone_audio(deps)
	suicide_drone_cooldown_frames = SUICIDE_DRONE_COOLDOWN_FRAMES
	var result: Dictionary = CommandoFirearmSuicideDroneState.build_detonation_result(
		reason,
		pos,
		hit_boss,
		suicide_drone_cooldown_frames
	)
	if reason == "ball_hit":
		result.merge(
			CommandoFirearmSuicideDroneBallBoostResolver.build_boost_result(
				projectile,
				context,
				SUICIDE_DRONE_BALL_SPEED_MULTIPLIER,
				SUICIDE_DRONE_BALL_FAN_DEGREES
			),
			true
		)
	return result


func _spawn_impact_flash(projectile: Dictionary) -> void:
	var weapon_id: String = CommandoFirearmValueUtils.get_projectile_weapon_id(projectile, BASE_WEAPON_ID)
	CommandoFirearmValueUtils.append_limited(
		impact_flashes,
		CommandoFirearmImpactFlashResolver.build_flash(
			projectile,
			CommandoFirearmProfileResolver.get_weapon_profile(
				weapon_id,
				WEAPON_PROFILES,
				WEAPON_PROFILE_OVERRIDES
			),
			float(ActiveItemThrowController.GRENADE_EXPLOSION_DURATION_FRAMES)
		),
		FLASH_LIMIT
	)


func _register_projectile_hit(projectile: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var weapon_id: String = CommandoFirearmValueUtils.get_projectile_weapon_id(projectile, BASE_WEAPON_ID)
	var pos: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var velocity: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	var feedback_profile: Dictionary = CommandoFirearmProfileResolver.get_hit_feedback_profile(
		weapon_id,
		WEAPON_HIT_FEEDBACK,
		HIT_FEEDBACK_PROFILE_OVERRIDES
	)
	var intensity: float = float(feedback_profile.get("intensity", 0.5))
	var color: Color = CommandoFirearmValueUtils.get_color(projectile.get("color", Color.WHITE), Color.WHITE)
	var combat_result: Dictionary = _apply_weapon_hit_result(weapon_id, projectile, context, deps)
	var damage_state: Dictionary = CommandoFirearmPendingResultState.queue_boss_damage_state(
		pending_boss_damage_units,
		pending_boss_damage_sources,
		combat_result
	)
	pending_boss_damage_units = int(damage_state.get("units", pending_boss_damage_units))
	pending_boss_damage_sources = CommandoFirearmValueUtils.get_array(damage_state.get("sources", pending_boss_damage_sources))
	var gauge_state: Dictionary = CommandoFirearmPendingResultState.queue_special_gauge_state(
		pending_special_gauge_gain,
		pending_special_gauge_sources,
		pending_special_gauge_hit_kind,
		pending_pistol_feedback_timer_frames,
		combat_result
	)
	pending_special_gauge_gain = float(gauge_state.get("gain", pending_special_gauge_gain))
	pending_special_gauge_sources = CommandoFirearmValueUtils.get_array(gauge_state.get("sources", pending_special_gauge_sources))
	pending_special_gauge_hit_kind = str(gauge_state.get("hit_kind", pending_special_gauge_hit_kind))
	pending_pistol_feedback_timer_frames = float(gauge_state.get("feedback_timer_frames", pending_pistol_feedback_timer_frames))
	var lingering_result: Dictionary = {}
	if weapon_id == "suicide_drone":
		lingering_result = _spawn_suicide_drone_fire_zone(projectile, context, deps)
	else:
		lingering_result = _spawn_lingering_effect(weapon_id, projectile, context)
	if not lingering_result.is_empty():
		combat_result["lingering_effect"] = lingering_result
	var hit_event: Dictionary = CommandoFirearmProjectileImpactState.build_hit_event(
		projectile,
		weapon_id,
		CommandoFirearmValueUtils.get_projectile_kind(projectile, "bullet"),
		pos,
		velocity,
		intensity,
		combat_result
	)
	CommandoFirearmValueUtils.append_limited(hit_events, hit_event, HIT_EVENT_LIMIT)
	CommandoFirearmHitFeedbackDispatcher.spawn_shared_impact_particles(pos, color, velocity, intensity, deps)
	CommandoFirearmHitFeedbackDispatcher.trigger_hit_feedback(feedback_profile, deps)
	CommandoFirearmHitFeedbackDispatcher.trigger_boss_hit_animation(context, deps)
	CommandoFirearmHitFeedbackDispatcher.register_ball_hit_pulse(pos, velocity, intensity, weapon_id, deps, BASE_WEAPON_ID)
	CommandoFirearmAudioDispatcher.play_impact_audio(weapon_id, deps)


func _register_projectile_environment_impact(projectile: Dictionary, reason: String, _context: Dictionary, deps: Dictionary) -> Dictionary:
	var weapon_id: String = CommandoFirearmValueUtils.get_projectile_weapon_id(projectile, BASE_WEAPON_ID)
	var pos: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var velocity: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	var feedback_profile: Dictionary = CommandoFirearmProfileResolver.get_hit_feedback_profile(
		weapon_id,
		WEAPON_HIT_FEEDBACK,
		HIT_FEEDBACK_PROFILE_OVERRIDES
	)
	var intensity: float = float(feedback_profile.get("intensity", 0.5))
	var color: Color = CommandoFirearmValueUtils.get_color(projectile.get("color", Color.WHITE), Color.WHITE)
	CommandoFirearmHitFeedbackDispatcher.spawn_shared_impact_particles(pos, color, velocity, intensity, deps)
	CommandoFirearmHitFeedbackDispatcher.trigger_hit_feedback(feedback_profile, deps)
	CommandoFirearmAudioDispatcher.play_impact_audio(weapon_id, deps)
	return CommandoFirearmProjectileImpactState.build_environment_impact_result(weapon_id, reason, pos)


func _destroy_stage2_rocks_for_projectile_impact(projectile: Dictionary, context: Dictionary, deps: Dictionary) -> int:
	var weapon_id: String = CommandoFirearmValueUtils.get_projectile_weapon_id(projectile, BASE_WEAPON_ID)
	var profile: Dictionary = CommandoFirearmProfileResolver.get_weapon_profile(
		weapon_id,
		WEAPON_PROFILES,
		WEAPON_PROFILE_OVERRIDES
	)
	return CommandoFirearmStage2RockInteractionResolver.destroy_projectile_impact_rocks(
		projectile,
		context,
		deps,
		weapon_id,
		CommandoFirearmHitGeometry.get_explosion_radius(projectile, profile)
	)


func _apply_weapon_hit_result(weapon_id: String, projectile: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	var profile: Dictionary = CommandoFirearmProfileResolver.get_hit_result_profile(
		weapon_id,
		WEAPON_HIT_RESULTS,
		HIT_RESULT_PROFILE_OVERRIDES
	)
	if profile.is_empty():
		return {}
	var status_effect_state: Object = deps.get("status_effect_state", null)
	var source: String = "commando_firearm_%s" % weapon_id
	var pos: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var velocity: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	var result: Dictionary = CommandoFirearmHitResultState.build_base_result(source, int(profile.get("damage_units", 0)))
	CommandoFirearmSlingshotState.apply_hit_effects(
		weapon_id,
		projectile,
		result,
		BASE_WEAPON_ID,
		SLINGSHOT_STUN_MULT,
		SLINGSHOT_KNOCKBACK_MULT
	)
	_apply_pistol_hit_effects(weapon_id, projectile, context, result)
	_apply_ak47_accumulated_boss_damage(weapon_id, result)
	var stun_frames: float = float(profile.get("stun_frames", 0.0))
	if result.has("stun_frames"):
		stun_frames = float(result.get("stun_frames", stun_frames))
	if stun_frames > 0.0:
		var knockback_profile: Dictionary = CommandoFirearmHitGeometry.get_result_hit_profile(profile, result)
		var knockback_vel: float = CommandoFirearmHitGeometry.get_hit_knockback_velocity(
			knockback_profile,
			pos,
			velocity,
			CommandoFirearmOriginGeometry.get_boss_target_pos(context, FIELD_WIDTH)
		)
		var stun_source: String = str(result.get("stun_source", source))
		result["stun_frames"] = stun_frames
		result["knockback_vel"] = knockback_vel
		if knockback_profile.has("knockback_frames"):
			result["knockback_frames"] = float(knockback_profile.get("knockback_frames", 0.0))
		if knockback_profile.has("knockback_decay_per_frame"):
			result["knockback_decay_per_frame"] = float(knockback_profile.get("knockback_decay_per_frame", 1.0))
		if status_effect_state != null and status_effect_state.has_method("apply_status"):
			status_effect_state.apply_status(
				"boss",
				"stun",
				stun_frames,
				CommandoFirearmHitResultState.build_stun_status_data(knockback_vel, stun_source, result),
				stun_source
			)
			result["stun_applied"] = true
	elif bool(result.get("knockback_without_stun", false)):
		var knockback_only_profile: Dictionary = CommandoFirearmHitGeometry.get_result_hit_profile(profile, result)
		var knockback_only_vel: float = CommandoFirearmHitGeometry.get_hit_knockback_velocity(
			knockback_only_profile,
			pos,
			velocity,
			CommandoFirearmOriginGeometry.get_boss_target_pos(context, FIELD_WIDTH)
		)
		result["knockback_vel"] = knockback_only_vel
		var ai_state: Object = deps.get("ai_state", null)
		if ai_state != null and ai_state.has_method("start_paddle_hit_knockback"):
			ai_state.start_paddle_hit_knockback(
				knockback_only_vel,
				float(result.get("knockback_frames", 18.0)),
				float(result.get("knockback_decay_per_frame", 0.85)),
				true
			)
			result["knockback_applied"] = true
	var slow_frames: float = float(profile.get("slow_frames", 0.0))
	if result.has("slow_frames"):
		slow_frames = float(result.get("slow_frames", slow_frames))
	if slow_frames > 0.0:
		var slow_source: String = str(result.get("slow_source", "%s_slow" % source))
		var slow_multiplier: float = clamp(float(result.get("slow_multiplier", profile.get("slow_multiplier", 1.0))), 0.0, 1.0)
		result["slow_frames"] = slow_frames
		result["slow_multiplier"] = slow_multiplier
		if status_effect_state != null and status_effect_state.has_method("apply_status"):
			status_effect_state.apply_status(
				"boss",
				"slow",
				slow_frames,
				CommandoFirearmHitResultState.build_slow_status_data(slow_multiplier, slow_source),
				slow_source
			)
			result["slow_applied"] = true
	return result


func _apply_pistol_hit_effects(weapon_id: String, projectile: Dictionary, context: Dictionary, result: Dictionary) -> void:
	if not CommandoFirearmValueUtils.is_pistol_weapon(weapon_id, BASE_WEAPON_ID):
		return
	var shot_roll: float = CommandoFirearmValueUtils.get_pistol_shot_roll(projectile, context)
	var doping_multiplier: float = CommandoFirearmValueUtils.get_pistol_hit_doping_multiplier(
		projectile,
		context,
		DOPING_POTION_HEAD_LEG_MULTIPLIER
	)
	var hit_chances: Dictionary = CommandoFirearmValueUtils.get_pistol_hit_chances(
		context,
		doping_multiplier,
		PISTOL_HEAD_SHOT_CHANCE,
		PISTOL_LEG_SHOT_CHANCE
	)
	var head_chance: float = float(hit_chances.get("head_chance", 0.0))
	var leg_chance: float = float(hit_chances.get("leg_chance", 0.0))
	var hit_payload: Dictionary = CommandoFirearmPistolHitState.build_hit_payload(
		weapon_id,
		pistol_boss_hit_count,
		shot_roll,
		head_chance,
		leg_chance,
		doping_multiplier,
		PISTOL_HIT_TUNING
	)
	pistol_boss_hit_count = int(hit_payload.get("next_hit_count", pistol_boss_hit_count))
	result.merge(CommandoFirearmValueUtils.get_dict(hit_payload.get("result_fields", {})), true)
	var feedback_hit_kind: String = str(hit_payload.get("feedback_hit_kind", ""))
	if feedback_hit_kind != "":
		_spawn_pistol_hit_feedback(feedback_hit_kind, context)
	var damage_units_delta: int = int(hit_payload.get("damage_units_delta", 0))
	if damage_units_delta <= 0:
		return
	result["damage_units"] = max(0, int(result.get("damage_units", 0))) + damage_units_delta
	result["damage_sources"] = CommandoFirearmValueUtils.get_array(hit_payload.get("damage_sources", []))


func _apply_ak47_accumulated_boss_damage(weapon_id: String, result: Dictionary) -> void:
	var hit_payload: Dictionary = CommandoFirearmAk47HitState.build_accumulated_damage_payload(
		weapon_id,
		ak47_boss_hit_count,
		int(result.get("damage_units", 0)),
		AK47_BOSS_DAMAGE_HIT_THRESHOLD
	)
	if hit_payload.is_empty():
		return
	ak47_boss_hit_count = int(hit_payload.get("next_hit_count", ak47_boss_hit_count))
	result.merge(CommandoFirearmValueUtils.get_dict(hit_payload.get("result_fields", {})), true)


func _spawn_lingering_effect(weapon_id: String, projectile: Dictionary, context: Dictionary) -> Dictionary:
	var profile: Dictionary = CommandoFirearmProfileResolver.get_lingering_effect_profile(
		weapon_id,
		WEAPON_LINGERING_EFFECTS
	)
	if profile.is_empty():
		return {}
	var is_net: bool = weapon_id == "net_gun"
	var dissolve: bool = bool(projectile.get("net_dissolve", false))
	var duration: float = CommandoFirearmLingeringEffectState.get_duration(
		profile,
		is_net,
		dissolve,
		NET_GUN_DISSOLVE_FRAMES
	)
	var projectile_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var pos: Vector2 = CommandoFirearmLingeringNetFieldState.get_lingering_effect_pos(
		profile,
		projectile,
		context,
		projectile_pos,
		CommandoFirearmOriginGeometry.get_boss_target_pos(context, FIELD_WIDTH),
		FIELD_WIDTH,
		FIELD_HEIGHT,
		NET_GUN_WIDTH,
		NET_GUN_MIN_HEIGHT,
		NET_GUN_HEIGHT
	)
	var effect_id: int = int(projectile.get("id", 0))
	if effect_id == 0:
		effect_id = _next_shot_id()
	var net_effect_height: float = CommandoFirearmLingeringNetFieldState.get_net_effect_height(
		profile,
		context,
		NET_GUN_MIN_HEIGHT,
		NET_GUN_HEIGHT
	)
	var effect_size: Vector2 = CommandoFirearmLingeringEffectState.get_size(
		profile,
		projectile,
		is_net,
		NET_GUN_WIDTH,
		net_effect_height
	)
	var effect: Dictionary = CommandoFirearmLingeringEffectState.build_effect(
		weapon_id,
		profile,
		projectile,
		pos,
		effect_id,
		effect_size,
		duration
	)
	if is_net:
		CommandoFirearmLingeringNetFieldState.apply_net_fields(
			effect,
			profile,
			projectile,
			CommandoFirearmOriginGeometry.get_commando_fire_sheet_world_pos(
				context,
				COMMANDO_NET_GUN_FIRE_MUZZLE_SOURCE,
				Vector2(FIELD_WIDTH, FIELD_HEIGHT),
				COMMANDO_FIRE_SHEET_SOURCE_CELL_SIZE,
				COMMANDO_FIRE_SHEET_PLAYER_FOOT_Y_OFFSET
			),
			pos,
			effect_size,
			effect_id,
			dissolve,
			NET_GUN_DASH_BREAK_FRAMES,
			NET_GUN_PLAYER_SLOW_MULTIPLIER
		)
	CommandoFirearmLingeringStatusState.apply_effect_status_fields(
		effect,
		profile,
		dissolve,
		LINGERING_STATUS_DEFAULT_DURATION_FRAMES,
		LINGERING_STATUS_DEFAULT_INTERVAL_FRAMES,
		LINGERING_STATUS_INITIAL_COOLDOWN_FRAMES,
		LINGERING_STATUS_DEFAULT_SLOW_MULTIPLIER
	)
	if CommandoFirearmLingeringEffectState.is_fire_zone(effect):
		effect["flames"] = CommandoFirearmLingeringFireFlameState.build_flames(effect)
	CommandoFirearmValueUtils.append_limited(lingering_effects, effect, LINGERING_EFFECT_LIMIT)
	return CommandoFirearmLingeringEffectState.build_spawn_result(effect, duration)


func _spawn_suicide_drone_fire_zone(projectile: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	var pos: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	var registry: Object = deps.get("registry", null)
	if active_item_runtime == null:
		active_item_runtime = CommandoFirearmValueUtils.get_instance(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("trigger_molotov_fire_zone"):
		active_item_runtime.trigger_molotov_fire_zone(pos, null, registry, false)
		return {
			"kind": "fire_zone",
			"duration_frames": ActiveItemThrowController.MOLOTOV_FIRE_DURATION_FRAMES,
			"source": "active_item_molotov_fire_zone",
		}
	return _spawn_lingering_effect("suicide_drone", projectile, context)


func _spawn_net_dissolve_effect(projectile: Dictionary, context: Dictionary) -> Dictionary:
	var net_projectile: Dictionary = projectile.duplicate(true)
	net_projectile["net_dissolve"] = true
	return _spawn_lingering_effect("net_gun", net_projectile, context)


func _update_lingering_effects(fps_scale: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	var step: float = CommandoFirearmLingeringEffectState.get_timer_step(fps_scale)
	var result: Dictionary = {}
	var dash_trigger_result: Dictionary = CommandoFirearmLingeringNetFieldState.get_dash_trigger_result(
		context,
		deps,
		net_gun_last_dash_active
	)
	net_gun_last_dash_active = bool(dash_trigger_result.get("dash_active", false))
	if bool(dash_trigger_result.get("dash_triggered", false)):
		CommandoFirearmLingeringNetFieldState.break_active_hooked_net_fields(
			lingering_effects,
			NET_GUN_DASH_BREAK_FRAMES
		)
	for index in range(lingering_effects.size() - 1, -1, -1):
		var effect: Dictionary = CommandoFirearmValueUtils.get_dict(lingering_effects[index])
		CommandoFirearmLingeringEffectState.advance_timers(effect, step, LINGERING_EFFECT_PHASE_STEP)
		if CommandoFirearmLingeringEffectState.is_fire_zone(effect):
			effect["flames"] = CommandoFirearmLingeringFireFlameState.get_flames_for_frame(effect, step)
		if CommandoFirearmLingeringEffectState.is_active(effect):
			_apply_active_lingering_effect(index, effect, step, context, deps, result)
		else:
			lingering_effects.remove_at(index)
	return result


func _apply_active_lingering_effect(
	index: int,
	effect: Dictionary,
	fps_scale: float,
	context: Dictionary,
	deps: Dictionary,
	result: Dictionary
) -> void:
	var should_sync_rope_origin: bool = CommandoFirearmLingeringNetFieldState.is_active_hooked_net_field(effect)
	if not should_sync_rope_origin:
		should_sync_rope_origin = (
			CommandoFirearmLingeringNetFieldState.is_net_gun_effect(effect)
			and bool(effect.get("rope_broken", false))
			and bool(effect.get("dissolve", false))
			and CommandoFirearmLingeringEffectState.get_rope_snap_timer(effect) > 0.0
		)
	if should_sync_rope_origin:
		effect["origin"] = CommandoFirearmOriginGeometry.get_commando_fire_sheet_world_pos(
			context,
			COMMANDO_NET_GUN_FIRE_MUZZLE_SOURCE,
			Vector2(FIELD_WIDTH, FIELD_HEIGHT),
			COMMANDO_FIRE_SHEET_SOURCE_CELL_SIZE,
			COMMANDO_FIRE_SHEET_PLAYER_FOOT_Y_OFFSET
		)
	var status_application: Dictionary = CommandoFirearmLingeringStatusState.get_status_application(effect, deps)
	if (
		CommandoFirearmLingeringStatusState.has_status_application(status_application)
		and CommandoFirearmLingeringStatusState.can_apply_status(
			effect,
			context,
			CommandoFirearmLingeringEffectState.get_timer_step(fps_scale)
		)
	):
		var status_effect_state: Object = CommandoFirearmLingeringStatusState.get_status_application_state(status_application)
		var status_id: String = CommandoFirearmLingeringStatusState.get_status_application_id(status_application)
		if status_effect_state != null and status_id != "":
			var data: Dictionary = CommandoFirearmLingeringStatusState.build_status_data(
				effect,
				status_id,
				LINGERING_STATUS_ID_SLOW,
				LINGERING_STATUS_DEFAULT_SLOW_MULTIPLIER,
				LINGERING_STATUS_MIN_SLOW_MULTIPLIER,
				LINGERING_STATUS_MAX_SLOW_MULTIPLIER
			)
			status_effect_state.apply_status(
				CommandoFirearmLingeringStatusState.get_status_target(LINGERING_STATUS_TARGET),
				status_id,
				CommandoFirearmLingeringStatusState.get_status_duration(
					effect,
					LINGERING_STATUS_DEFAULT_DURATION_FRAMES
				),
				data,
				CommandoFirearmLingeringStatusState.get_status_source(effect, LINGERING_STATUS_DEFAULT_SOURCE)
			)
			CommandoFirearmLingeringStatusState.reset_status_cooldown(
				effect,
				LINGERING_STATUS_DEFAULT_INTERVAL_FRAMES
			)
	var clamp_result: Dictionary = CommandoFirearmLingeringNetFieldState.apply_net_field_boss_clamp(
		effect,
		context,
		NET_GUN_WIDTH,
		NET_GUN_MIN_HEIGHT
	)
	CommandoFirearmLingeringEffectState.merge_clamp_result(result, context, clamp_result)
	lingering_effects[index] = effect


func _update_net_constrict_input(input_snapshot: Dictionary, now_msec: int, deps: Dictionary) -> void:
	# Mirrors pingfighter.py _update_net_constrict: alternating L/R input within
	# a short window narrows hooked nets by NET_CONSTRICT_STEP, floored at NET_CONSTRICT_MIN.
	var active_indices: Array[int] = []
	for index in range(lingering_effects.size()):
		var effect: Dictionary = CommandoFirearmValueUtils.get_dict(lingering_effects[index])
		if CommandoFirearmLingeringNetFieldState.is_net_constrict_candidate(effect, NET_CONSTRICT_MIN):
			active_indices.append(index)
	if active_indices.is_empty():
		return
	var dir_input: int = CommandoFirearmLingeringNetFieldState.get_net_constrict_input_direction(input_snapshot)
	if not CommandoFirearmLingeringNetFieldState.should_record_net_constrict_input(dir_input, net_constrict_last_dir):
		return
	if CommandoFirearmLingeringNetFieldState.should_apply_net_constrict_input(
		dir_input,
		now_msec,
		net_constrict_last_dir,
		net_constrict_last_tick_msec,
		NET_CONSTRICT_WINDOW_MSEC
	):
		for index in active_indices:
			var effect: Dictionary = CommandoFirearmValueUtils.get_dict(lingering_effects[index])
			effect["constrict_factor"] = CommandoFirearmLingeringNetFieldState.get_next_net_constrict_factor(
				effect,
				NET_CONSTRICT_MIN,
				NET_CONSTRICT_STEP
			)
			lingering_effects[index] = effect
		var audio: Object = deps.get("game_audio", null)
		if audio != null and audio.has_method("play_commando_net_gun_capture"):
			audio.play_commando_net_gun_capture()
	net_constrict_last_dir = dir_input
	net_constrict_last_tick_msec = now_msec


func _next_shot_id() -> int:
	shot_serial += 1
	return shot_serial
