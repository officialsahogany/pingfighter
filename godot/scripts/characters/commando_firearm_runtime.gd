extends RefCounted

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const CommandoFirearmAudioResolver := preload("res://scripts/characters/commando_firearm_audio_resolver.gd")
const CommandoFirearmBowlingTrapGeometry := preload("res://scripts/characters/commando_firearm_bowling_trap_geometry.gd")
const CommandoFirearmControlState := preload("res://scripts/characters/commando_firearm_control_state.gd")
const CommandoFirearmDrawStateResolver := preload("res://scripts/characters/commando_firearm_draw_state_resolver.gd")
const CommandoFirearmFireResultState := preload("res://scripts/characters/commando_firearm_fire_result_state.gd")
const CommandoFirearmFireSheetResolver := preload("res://scripts/characters/commando_firearm_fire_sheet_resolver.gd")
const CommandoFirearmHitGeometry := preload("res://scripts/characters/commando_firearm_hit_geometry.gd")
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
const CommandoFirearmProfileResolver := preload("res://scripts/characters/commando_firearm_profile_resolver.gd")
const CommandoFirearmProjectileMotionState := preload("res://scripts/characters/commando_firearm_projectile_motion_state.gd")
const CommandoFirearmShellCasingState := preload("res://scripts/characters/commando_firearm_shell_casing_state.gd")
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
const SUPPORT_BOMB_INTERVAL_FRAMES := 60.0
const SUPPORT_BOMB_MIN_COUNT := 5
const SUPPORT_BOMB_MAX_COUNT := 7
const SUPPORT_BOMB_INITIAL_VY := 2.0
const SUPPORT_BOMB_GRAVITY := 0.35
const SUPPORT_BOMB_HORIZONTAL_JITTER := 1.1
const SUPPORT_AIRCRAFT_DROP_ARM_FRAMES := 60.0
const SUPPORT_AIRCRAFT_Y := 52.0
const SUPPORT_AIRCRAFT_SPEED := 1.8
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
const BERETTA_FIRE_RATE_MULTIPLIER := 1.3
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
# flash) is the first cell shown once `_play_fire_audio()` triggers, so the
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
const DOPING_POTION_PISTOL_COOLDOWN_FRAMES := 30.0
const DOPING_POTION_PISTOL_CONTROL_LOCK_FRAMES := 9.0
const DOPING_POTION_PISTOL_SPEED_MULTIPLIER := 1.2
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
const NET_GUN_PLAYER_SLOW_MULTIPLIER := 0.7
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
		"radius": 7.0,
		"hitbox_size": Vector2(14.0, 14.0),
		"life_frames": 240.0,
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
		"slow_frames": 240.0,
		"slow_multiplier": 0.35,
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
		"knockback_power": 8.0,
		"slow_frames": 150.0,
		"slow_multiplier": 0.65,
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
		"status_id": LINGERING_STATUS_ID_SLOW,
		"status_duration_frames": 20.0,
		"status_interval_frames": 12.0,
		"slow_multiplier": 0.35,
		"player_slow_multiplier": NET_GUN_PLAYER_SLOW_MULTIPLIER,
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
		"status_id": LINGERING_STATUS_ID_SLOW,
		"status_duration_frames": 36.0,
		"status_interval_frames": 30.0,
		"slow_multiplier": 0.5,
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
var ak47_burst_shots_remaining := 0
var ak47_trigger_held := false
var ak47_last_action_pressed := false
var ak47_recoil_accumulation := 0.0
var bazooka_cooldown_frames := 0.0
var bazooka_control_lock_frames := 0.0
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


func update_input(input_snapshot: Dictionary, special_gauge: float, config: Dictionary, deps: Dictionary) -> Dictionary:
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	if weapon_controller == null or not weapon_controller.has_method("get_snapshot"):
		return {}
	var now_msec: int = Time.get_ticks_msec()
	_update_net_constrict_input(input_snapshot, now_msec, deps)
	var current_weapon: Dictionary = weapon_controller.get_current_weapon_data()
	var weapon_id: String = str(current_weapon.get("weapon_id", BASE_WEAPON_ID))
	if weapon_controller.has_method("update_timers"):
		_play_reload_progress_audio(weapon_controller.update_timers(1.0), deps)
	var timed_result: Dictionary = _update_firearm_timers(config, deps, 1.0)
	if bool(timed_result.get("fired", false)):
		return timed_result
	if _has_active_suicide_drone_projectile():
		return _update_active_suicide_drone_input(input_snapshot, special_gauge, config, deps)
	var reset_result: Dictionary = _handle_firearm_reset_input(input_snapshot, special_gauge, weapon_controller, now_msec)
	if not reset_result.is_empty():
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
	if not _input_action_just_pressed(input_snapshot):
		return {}
	if bool(input_snapshot.get("down_pressed", false)):
		return {}
	if _is_fire_suppressed_after_switch(weapon_controller, now_msec):
		return {}
	if now_msec - last_fire_msec < FIRE_DEBOUNCE_MSEC:
		return {}
	if not _is_ready(weapon_id, now_msec, deps):
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
	var skill_state: Object = deps.get("skill_state", null)
	var skill_config: Object = deps.get("skill_config", null)
	if weapon_id != "pistol" and skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown(weapon_id, now_msec, skill_config)
	_spawn_firearm_effect(weapon_id, config, deps)
	_play_fire_audio(weapon_id, deps)
	return {
		"handled": true,
		"weapon_id": weapon_id,
		"fired": true,
		"special_gauge": special_gauge,
		"skill_gold_award": 0,
	}


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
	ak47_burst_shots_remaining = 0
	ak47_trigger_held = false
	ak47_last_action_pressed = false
	ak47_recoil_accumulation = 0.0
	bazooka_cooldown_frames = 0.0
	bazooka_control_lock_frames = 0.0
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
	_stop_all_support_aircraft_audio(deps)
	_stop_suicide_drone_audio(deps)
	var carried_bowling_traps: Array = []
	if bool(deps.get("preserve_bowling_traps", true)):
		carried_bowling_traps = _build_bowling_trap_round_carryover()
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
		_has_active_support_call_lock(),
		_has_active_suicide_drone_projectile()
	)


func get_movement_speed_multiplier() -> float:
	return CommandoFirearmControlState.get_movement_speed_multiplier(
		_has_active_suicide_drone_projectile(),
		ak47_trigger_held,
		_has_hooked_net_field(),
		AK47_MOVEMENT_SPEED_MULTIPLIER,
		NET_GUN_PLAYER_SLOW_MULTIPLIER
	)


func is_bowling_trap_guard_armed() -> bool:
	return bowling_trap_guard_armed


func _has_active_support_call_lock() -> bool:
	return CommandoFirearmSupportCallResolver.has_active_lock(support_calls)


func consume_bowling_trap_boss_guard(ball_vel: Vector2, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if not bowling_trap_guard_armed:
		return {}

	var source: String = bowling_trap_guard_source
	if source == "":
		source = "commando_bowling_trap_guard"
	var restore_speed: float = max(1.0, bowling_trap_guard_restore_speed)
	_clear_bowling_trap_guard()

	var next_ball_vel: Vector2 = _soften_bowling_trap_guard_ball(ball_vel, restore_speed)
	if _is_stage2_speed_defense_boss_immune(context, deps):
		return CommandoFirearmBowlingTrapGeometry.build_guard_immune_result(next_ball_vel)

	var boss_center: Vector2 = _get_boss_target_pos(context)
	var knockback_vel: float = _get_bowling_trap_guard_knockback_velocity(boss_center, context)
	var feedback_profile: Dictionary = _get_hit_feedback_profile("bowling_trap")
	var profile: Dictionary = _get_weapon_profile("bowling_trap")
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

	_spawn_shared_impact_particles(
		boss_center,
		_get_color(profile.get("color", Color.WHITE), Color.WHITE),
		next_ball_vel,
		float(feedback_profile.get("intensity", 0.82)),
		deps
	)
	_trigger_hit_feedback(feedback_profile, deps)
	_trigger_boss_hit_animation(context, deps)
	_register_ball_hit_pulse(boss_center, next_ball_vel, 0.9, "bowling_trap_guard", deps)
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
		var call: Dictionary = _get_dict(value)
		if bool(call.get("aircraft_audio_active", false)):
			return true
	return false


func get_fire_support_aircraft_collision_rect(call_id: int = 0) -> Rect2:
	for value in support_calls:
		@warning_ignore("shadowed_variable_base_class")
		var call: Dictionary = _get_dict(value)
		if not bool(call.get("aircraft_active", false)):
			continue
		if call_id != 0 and int(call.get("id", 0)) != call_id:
			continue
		return _get_support_aircraft_collision_rect(call)
	return Rect2()


func resolve_ball_collision(scene: Dictionary, context: Dictionary, _deps: Dictionary = {}) -> bool:
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var previous_ball_pos: Vector2 = _get_vector2(
		scene.get("previous_ball_pos", context.get("ball_pos", ball_pos)),
		ball_pos
	)
	var ball_radius: float = max(1.0, float(context.get("ball_size", scene.get("ball_size", 28.6))) * 0.5)
	for value in support_calls:
		@warning_ignore("shadowed_variable_base_class")
		var call: Dictionary = _get_dict(value)
		if _support_aircraft_ball_path_hits(call, previous_ball_pos, ball_pos, ball_radius):
			# Python FireSupportAircraft deliberately ignores ball hits; keep the
			# collision route visible without starting a crash lifecycle.
			return false
	return false


func update_effects(fps_scale: float, _current_msec: int, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	_update_muzzle_flashes(fps_scale)
	_update_support_calls(fps_scale, context, deps)
	var ball_motion_result: Dictionary = _update_bowling_traps(fps_scale, context, deps)
	if not ball_motion_result.is_empty():
		context.merge(ball_motion_result, true)
	var projectile_result: Dictionary = _update_projectiles(fps_scale, context, deps)
	if not projectile_result.is_empty():
		context.merge(projectile_result, true)
	_update_shell_casings(fps_scale)
	_update_pistol_feedbacks(fps_scale)
	_update_impact_flashes(fps_scale)
	var lingering_result: Dictionary = _update_lingering_effects(fps_scale, context, deps)
	if not lingering_result.is_empty():
		context.merge(lingering_result, true)
	var result: Dictionary = ball_motion_result.duplicate(true)
	if not projectile_result.is_empty():
		result.merge(projectile_result, true)
	if not lingering_result.is_empty():
		result.merge(lingering_result, true)
	var damage_result: Dictionary = _consume_pending_boss_damage_result()
	if not damage_result.is_empty():
		result.merge(damage_result, true)
	var gauge_result: Dictionary = _consume_pending_special_gauge_result()
	if not gauge_result.is_empty():
		result.merge(gauge_result, true)
	return result


func get_recent_hit_events() -> Array:
	return hit_events.duplicate(true)


func get_actor_draw_context() -> Dictionary:
	return CommandoFirearmDrawStateResolver.build_actor_context(
		has_visible_effects(),
		projectiles,
		muzzle_flashes,
		impact_flashes,
		lingering_effects,
		shell_casings,
		pistol_feedbacks,
		_get_pistol_draw_state(),
		_get_slingshot_draw_state(),
		_get_ak47_draw_state(),
		_get_bazooka_draw_state(),
		_get_net_gun_draw_state(),
		_get_bowling_trap_draw_state(),
		_get_suicide_drone_draw_state(),
		_get_weapon_fire_sheet_draw_state(),
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
	_refresh_pending_pistol_fire_geometry(config)
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
	_play_fire_audio(shot_weapon_id, deps)
	# Start the post-fire animation window so the renderer plays the muzzle /
	# smoke / lower / ready frames after the shot resolves. Frame 4 (muzzle
	# flash) is the first cell shown during this window, so it lines up with
	# `_play_fire_audio()` above.
	pistol_post_fire_animation_frames = PISTOL_POST_FIRE_ANIMATION_FRAMES
	return CommandoFirearmFireResultState.build_pistol_delayed_fire_result(
		shot_weapon_id,
		pistol_cooldown_frames,
		pistol_control_lock_frames
	)


func _refresh_pending_pistol_fire_geometry(config: Dictionary) -> void:
	CommandoFirearmValueUtils.refresh_pending_fire_geometry(
		pistol_pending_config,
		config,
		PISTOL_PENDING_FIRE_GEOMETRY_KEYS
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
	if _is_fire_suppressed_after_switch(deps.get("commando_weapon_controller", null), now_msec):
		return {}
	if pistol_fire_delay_frames > 0.0:
		return _pistol_fire_failed(special_gauge, "pistol_animation_busy", weapon_id)
	if pistol_cooldown_frames > 0.0:
		return _pistol_fire_failed(special_gauge, "pistol_cooldown", weapon_id)
	if bool(current_weapon.get("reloading", false)):
		return _pistol_fire_failed(special_gauge, "pistol_reloading", weapon_id)
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	var ammo_current: int = int(current_weapon.get("ammo_current", 0))
	var magazines_current: int = int(current_weapon.get("magazines_current", 0))
	if ammo_current <= 0:
		if weapon_id == BASE_WEAPON_ID:
			return _reload_base_pistol_from_fire_input(special_gauge, deps)
		if weapon_id == "commando_pistol" and magazines_current > 0 and weapon_controller != null and weapon_controller.has_method("start_current_weapon_reload"):
			if bool(weapon_controller.start_current_weapon_reload()):
				_play_first_audio_method(deps, ["play_commando_pistol_reload_start"])
				return CommandoFirearmFireResultState.build_pistol_reload_started_result(
					weapon_id,
					special_gauge,
					"pistol_reload_started"
				)
		return _pistol_fire_failed(special_gauge, "pistol_empty", weapon_id)
	if weapon_controller != null and weapon_controller.has_method("consume_current_weapon_ammo"):
		if not bool(weapon_controller.consume_current_weapon_ammo(1)):
			return _pistol_fire_failed(special_gauge, "pistol_ammo_unavailable", weapon_id)
	last_fire_msec = now_msec
	var doping_context: Dictionary = _get_doping_potion_context_from_deps(deps)
	var doping_active: bool = bool(doping_context.get("active", false))
	pistol_cooldown_max_frames = _get_pistol_cooldown_frames(weapon_id, doping_context, doping_active)
	pistol_control_lock_max_frames = float(doping_context.get("pistol_control_lock_frames", DOPING_POTION_PISTOL_CONTROL_LOCK_FRAMES)) if doping_active else PISTOL_CONTROL_LOCK_FRAMES
	pistol_cooldown_frames = pistol_cooldown_max_frames
	pistol_control_lock_frames = pistol_control_lock_max_frames
	pistol_fire_delay_frames = PISTOL_FIRE_DELAY_FRAMES
	pistol_pending_config = config.duplicate(true)
	pistol_pending_weapon_id = weapon_id
	_apply_doping_potion_to_pistol_config(pistol_pending_config, doping_context)
	_play_first_audio_method(deps, ["play_commando_pistol_ready"])
	var updated_weapon: Dictionary = current_weapon
	if weapon_controller != null and weapon_controller.has_method("get_current_weapon_data"):
		updated_weapon = weapon_controller.get_current_weapon_data()
	return CommandoFirearmFireResultState.build_pistol_shot_queued_result(
		weapon_id,
		updated_weapon,
		max(0, ammo_current - 1),
		PISTOL_AMMO_MAX,
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
		return _pistol_fire_failed(special_gauge, "pistol_reload_gauge_insufficient", BASE_WEAPON_ID)
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	if weapon_controller == null or not weapon_controller.has_method("start_weapon_reload"):
		return _pistol_fire_failed(special_gauge, "pistol_reload_unavailable", BASE_WEAPON_ID)
	if not bool(weapon_controller.start_weapon_reload(BASE_WEAPON_ID)):
		return _pistol_fire_failed(special_gauge, "pistol_reload_unavailable", BASE_WEAPON_ID)
	var updated_weapon: Dictionary = {}
	if weapon_controller.has_method("get_current_weapon_data"):
		updated_weapon = weapon_controller.get_current_weapon_data()
	_play_first_audio_method(deps, ["play_commando_pistol_reload_start"])
	var next_gauge: float = max(0.0, special_gauge - PISTOL_EMPTY_RELOAD_GAUGE_COST)
	return CommandoFirearmFireResultState.build_base_pistol_reload_started_result(
		BASE_WEAPON_ID,
		next_gauge,
		updated_weapon,
		PISTOL_AMMO_MAX,
		PISTOL_FIRE_DELAY_FRAMES,
		PISTOL_EMPTY_RELOAD_GAUGE_COST
	)


func _pistol_fire_failed(special_gauge: float, reason: String, weapon_id: String = "commando_pistol") -> Dictionary:
	return CommandoFirearmFireResultState.build_fire_failed_result(weapon_id, special_gauge, reason, {
		"cooldown_frames": pistol_cooldown_frames,
		"control_lock_frames": pistol_control_lock_frames,
		"fire_delay_frames": pistol_fire_delay_frames,
	})


func _get_pistol_cooldown_frames(weapon_id: String, doping_context: Dictionary, doping_active: bool) -> float:
	return CommandoFirearmValueUtils.get_pistol_cooldown_frames(
		weapon_id,
		doping_context,
		doping_active,
		PISTOL_COOLDOWN_FRAMES,
		BERETTA_COOLDOWN_FRAMES,
		DOPING_POTION_PISTOL_COOLDOWN_FRAMES
	)


func _get_doping_potion_context_from_deps(deps: Dictionary) -> Dictionary:
	return CommandoFirearmValueUtils.get_doping_potion_context_from_deps(deps, _get_doping_potion_defaults())


func _get_doping_potion_context_from_config(config: Dictionary) -> Dictionary:
	return _normalize_doping_potion_context(config)


func _apply_doping_potion_to_pistol_config(config: Dictionary, doping_context: Dictionary) -> void:
	CommandoFirearmValueUtils.apply_doping_potion_to_pistol_config(
		config,
		doping_context,
		_get_doping_potion_defaults()
	)


func _normalize_doping_potion_context(context: Dictionary) -> Dictionary:
	return CommandoFirearmValueUtils.normalize_doping_potion_context(context, _get_doping_potion_defaults())


func _get_doping_potion_defaults() -> Dictionary:
	return {
		"head_leg_multiplier": DOPING_POTION_HEAD_LEG_MULTIPLIER,
		"pistol_cooldown_frames": DOPING_POTION_PISTOL_COOLDOWN_FRAMES,
		"pistol_control_lock_frames": DOPING_POTION_PISTOL_CONTROL_LOCK_FRAMES,
		"pistol_speed_multiplier": DOPING_POTION_PISTOL_SPEED_MULTIPLIER,
	}


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
	if _is_fire_suppressed_after_switch(weapon_controller, now_msec):
		ak47_trigger_held = true
		return {}
	if action_just_pressed:
		ak47_trigger_held = true
		ak47_burst_shots_remaining = AK47_INITIAL_BURST_SHOTS
		ak47_fire_interval_frames = 0.0
	else:
		ak47_trigger_held = true
	var ammo_current: int = int(current_weapon.get("ammo_current", 0))
	if ammo_current <= 0 or not bool(current_weapon.get("can_fire", true)):
		_clear_ak47_trigger_state()
		return _ak47_fire_failed(special_gauge, "ak47_empty")
	_consume_ak47_duration(weapon_controller, 1.0)
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
			return _ak47_fire_failed(special_gauge, "ak47_ammo_unavailable")
	last_fire_msec = now_msec
	_spawn_firearm_effect("ak47", config, deps, _get_ak47_fire_profile())
	_play_fire_audio("ak47", deps)
	_trigger_ak47_cooldown(now_msec, deps)
	ak47_recoil_accumulation = min(AK47_MAX_RECOIL, ak47_recoil_accumulation + AK47_RECOIL_PER_SHOT)
	if ak47_burst_shots_remaining > 0:
		ak47_burst_shots_remaining -= 1
	ak47_fire_interval_frames = AK47_FIRE_INTERVAL_FRAMES
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


func _ak47_fire_failed(special_gauge: float, reason: String) -> Dictionary:
	return CommandoFirearmFireResultState.build_fire_failed_result("ak47", special_gauge, reason, {
		"fire_interval_frames": ak47_fire_interval_frames,
		"burst_shots_remaining": ak47_burst_shots_remaining,
		"movement_speed_multiplier": get_movement_speed_multiplier(),
	})


func _consume_ak47_duration(weapon_controller: Object, frames: float) -> void:
	if weapon_controller == null or not weapon_controller.has_method("consume_current_weapon_duration"):
		return
	weapon_controller.consume_current_weapon_duration(frames)


func _trigger_ak47_cooldown(now_msec: int, deps: Dictionary) -> void:
	var skill_state: Object = deps.get("skill_state", null)
	var skill_config: Object = deps.get("skill_config", null)
	if skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown("ak47", now_msec, skill_config)


func _get_ak47_fire_profile() -> Dictionary:
	var profile: Dictionary = _get_weapon_profile("ak47")
	var spread: float = AK47_BASE_SPREAD_RADIANS + ak47_recoil_accumulation
	profile["angle_offset"] = randf_range(-spread, spread)
	profile["recoil_accumulation"] = ak47_recoil_accumulation
	return profile


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
	if _is_fire_suppressed_after_switch(weapon_controller, now_msec):
		return {}
	if bazooka_control_lock_frames > 0.0:
		return _bazooka_fire_failed(special_gauge, "bazooka_control_lock")
	if bazooka_cooldown_frames > 0.0:
		return _bazooka_fire_failed(special_gauge, "bazooka_cooldown")
	if not _is_ready("bazooka", now_msec, deps):
		return _bazooka_fire_failed(special_gauge, "configured_cooldown")
	var ammo_current: int = int(current_weapon.get("ammo_current", 0))
	if ammo_current <= 0 or not bool(current_weapon.get("can_fire", true)):
		return _bazooka_fire_failed(special_gauge, "bazooka_empty")
	if weapon_controller != null and weapon_controller.has_method("consume_current_weapon_ammo"):
		if not bool(weapon_controller.consume_current_weapon_ammo(1)):
			return _bazooka_fire_failed(special_gauge, "bazooka_ammo_unavailable")
	last_fire_msec = now_msec
	bazooka_cooldown_frames = BAZOOKA_COOLDOWN_FRAMES
	bazooka_control_lock_frames = BAZOOKA_CONTROL_LOCK_FRAMES
	bazooka_fire_animation_frames = BAZOOKA_FIRE_ANIMATION_FRAMES
	bazooka_firing_pose_frames = BAZOOKA_FIRING_POSE_FRAMES
	bazooka_muzzle_flash_frames = BAZOOKA_MUZZLE_FLASH_FRAMES
	var skill_state: Object = deps.get("skill_state", null)
	var skill_config: Object = deps.get("skill_config", null)
	if skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown("bazooka", now_msec, skill_config)
	_spawn_firearm_effect("bazooka", config, deps, _get_bazooka_fire_profile())
	_play_fire_audio("bazooka", deps)
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


func _bazooka_fire_failed(special_gauge: float, reason: String) -> Dictionary:
	return CommandoFirearmFireResultState.build_fire_failed_result("bazooka", special_gauge, reason, {
		"cooldown_frames": bazooka_cooldown_frames,
		"control_lock_frames": bazooka_control_lock_frames,
		"fire_animation_frames": bazooka_fire_animation_frames,
		"firing_pose_frames": bazooka_firing_pose_frames,
		"muzzle_flash_frames": bazooka_muzzle_flash_frames,
	})


func _get_bazooka_fire_profile() -> Dictionary:
	return _get_weapon_profile("bazooka")


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
	if _is_fire_suppressed_after_switch(weapon_controller, now_msec):
		return {}
	if net_gun_control_lock_frames > 0.0:
		return _net_gun_fire_failed(special_gauge, "net_gun_control_lock")
	if net_gun_cooldown_frames > 0.0:
		return _net_gun_fire_failed(special_gauge, "net_gun_cooldown")
	if not _is_ready("net_gun", now_msec, deps):
		return _net_gun_fire_failed(special_gauge, "configured_cooldown")
	var ammo_current: int = int(current_weapon.get("ammo_current", 0))
	if ammo_current <= 0 or not bool(current_weapon.get("can_fire", true)):
		return _net_gun_fire_failed(special_gauge, "net_gun_empty")
	if weapon_controller != null and weapon_controller.has_method("consume_current_weapon_ammo"):
		if not bool(weapon_controller.consume_current_weapon_ammo(1)):
			return _net_gun_fire_failed(special_gauge, "net_gun_ammo_unavailable")
	last_fire_msec = now_msec
	net_gun_cooldown_frames = NET_GUN_COOLDOWN_FRAMES
	net_gun_control_lock_frames = NET_GUN_CONTROL_LOCK_FRAMES
	net_gun_throw_pose_frames = NET_GUN_THROW_POSE_FRAMES
	net_gun_harpoon_flash_frames = NET_GUN_HARPOON_FLASH_FRAMES
	var skill_state: Object = deps.get("skill_state", null)
	var skill_config: Object = deps.get("skill_config", null)
	if skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown("net_gun", now_msec, skill_config)
	_spawn_firearm_effect("net_gun", config, deps, _get_net_gun_fire_profile())
	_play_fire_audio("net_gun", deps)
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


func _net_gun_fire_failed(special_gauge: float, reason: String) -> Dictionary:
	return CommandoFirearmFireResultState.build_fire_failed_result("net_gun", special_gauge, reason, {
		"cooldown_frames": net_gun_cooldown_frames,
		"control_lock_frames": net_gun_control_lock_frames,
		"throw_pose_frames": net_gun_throw_pose_frames,
		"harpoon_flash_frames": net_gun_harpoon_flash_frames,
	})


func _get_net_gun_fire_profile() -> Dictionary:
	return _get_weapon_profile("net_gun")


func _start_weapon_fire_sheet_animation(weapon_id: String) -> void:
	var fire_sheet_id: String = _normalize_weapon_fire_sheet_id(weapon_id)
	if fire_sheet_id == "":
		return
	weapon_fire_sheet_id = fire_sheet_id
	weapon_fire_sheet_max_frames = _get_weapon_fire_sheet_duration_frames(fire_sheet_id)
	var start_frame: int = _get_weapon_fire_sheet_start_frame(fire_sheet_id)
	var frame_duration: float = weapon_fire_sheet_max_frames / float(COMMANDO_WEAPON_FIRE_SHEET_FRAME_COUNT)
	weapon_fire_sheet_timer_frames = max(frame_duration, weapon_fire_sheet_max_frames - frame_duration * float(start_frame))


func _normalize_weapon_fire_sheet_id(weapon_id: String) -> String:
	return CommandoFirearmFireSheetResolver.normalize_weapon_fire_sheet_id(weapon_id)


func _get_weapon_fire_sheet_duration_frames(weapon_id: String) -> float:
	return CommandoFirearmFireSheetResolver.get_duration_frames(
		weapon_id,
		COMMANDO_WEAPON_FIRE_SHEET_DEFAULT_FRAMES,
		COMMANDO_WEAPON_FIRE_SHEET_LONG_FRAMES
	)


func _get_weapon_fire_sheet_start_frame(weapon_id: String) -> int:
	return CommandoFirearmFireSheetResolver.get_start_frame(weapon_id, COMMANDO_WEAPON_FIRE_SHEET_FRAME_COUNT)


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
	if _is_fire_suppressed_after_switch(weapon_controller, now_msec):
		return {}
	if bowling_trap_control_lock_frames > 0.0:
		return _bowling_trap_fire_failed(special_gauge, "bowling_trap_control_lock")
	if bowling_trap_cooldown_frames > 0.0:
		return _bowling_trap_fire_failed(special_gauge, "bowling_trap_cooldown")
	if _has_installing_bowling_trap():
		return _bowling_trap_fire_failed(special_gauge, "bowling_trap_installing")
	if not _is_bowling_trap_install_in_player_field(config):
		return _bowling_trap_fire_failed(special_gauge, "bowling_trap_install_field")
	if not _is_ready("bowling_trap", now_msec, deps):
		return _bowling_trap_fire_failed(special_gauge, "configured_cooldown")
	var ammo_current: int = int(current_weapon.get("ammo_current", 0))
	if ammo_current <= 0 or not bool(current_weapon.get("can_fire", true)):
		return _bowling_trap_fire_failed(special_gauge, "bowling_trap_empty")
	if weapon_controller != null and weapon_controller.has_method("consume_current_weapon_ammo"):
		if not bool(weapon_controller.consume_current_weapon_ammo(1)):
			return _bowling_trap_fire_failed(special_gauge, "bowling_trap_ammo_unavailable")
	last_fire_msec = now_msec
	bowling_trap_cooldown_frames = BOWLING_TRAP_COOLDOWN_FRAMES
	bowling_trap_control_lock_frames = BOWLING_TRAP_CONTROL_LOCK_FRAMES
	bowling_trap_install_pose_frames = BOWLING_TRAP_INSTALL_FRAMES
	var skill_state: Object = deps.get("skill_state", null)
	var skill_config: Object = deps.get("skill_config", null)
	if skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown("bowling_trap", now_msec, skill_config)
	_spawn_firearm_effect("bowling_trap", config, deps, _get_weapon_profile("bowling_trap"))
	_play_fire_audio("bowling_trap", deps)
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


func _bowling_trap_fire_failed(special_gauge: float, reason: String) -> Dictionary:
	return CommandoFirearmFireResultState.build_fire_failed_result("bowling_trap", special_gauge, reason, {
		"cooldown_frames": bowling_trap_cooldown_frames,
		"control_lock_frames": bowling_trap_control_lock_frames,
		"install_pose_frames": bowling_trap_install_pose_frames,
	})


func _is_bowling_trap_install_in_player_field(config: Dictionary) -> bool:
	return CommandoFirearmBowlingTrapGeometry.is_install_in_player_field(
		config,
		FIELD_WIDTH,
		FIELD_HEIGHT,
		BOWLING_TRAP_MIN_FIELD_Y_RATIO
	)


func _has_installing_bowling_trap() -> bool:
	return CommandoFirearmBowlingTrapGeometry.has_installing_trap(bowling_traps)


func _build_bowling_trap_round_carryover() -> Array:
	return CommandoFirearmBowlingTrapGeometry.build_round_carryover(
		bowling_traps,
		BOWLING_TRAP_CAPTURE_BALL_OFFSET
	)


func _get_bowling_trap_draw_state() -> Dictionary:
	return CommandoFirearmDrawStateResolver.build_bowling_trap_state(
		bowling_trap_cooldown_frames,
		BOWLING_TRAP_COOLDOWN_FRAMES,
		bowling_trap_control_lock_frames,
		BOWLING_TRAP_CONTROL_LOCK_FRAMES,
		bowling_trap_install_pose_frames,
		BOWLING_TRAP_INSTALL_FRAMES,
		_has_installing_bowling_trap(),
		CommandoFirearmBowlingTrapGeometry.get_install_progress(bowling_traps)
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
	if not _input_action_just_pressed(input_snapshot):
		return {}
	if bool(input_snapshot.get("down_pressed", false)):
		return {}
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	if _is_fire_suppressed_after_switch(weapon_controller, now_msec):
		return {}
	if suicide_drone_cooldown_frames > 0.0:
		return _suicide_drone_fire_failed(special_gauge, "suicide_drone_cooldown")
	if _has_active_suicide_drone_projectile():
		return _suicide_drone_fire_failed(special_gauge, "suicide_drone_active")
	if not _is_ready("suicide_drone", now_msec, deps):
		return _suicide_drone_fire_failed(special_gauge, "configured_cooldown")
	var ammo_current: int = int(current_weapon.get("ammo_current", 0))
	if ammo_current <= 0 or not bool(current_weapon.get("can_fire", true)):
		return _suicide_drone_fire_failed(special_gauge, "suicide_drone_empty")
	if weapon_controller != null and weapon_controller.has_method("consume_current_weapon_ammo"):
		if not bool(weapon_controller.consume_current_weapon_ammo(1)):
			return _suicide_drone_fire_failed(special_gauge, "suicide_drone_ammo_unavailable")
	last_fire_msec = now_msec
	suicide_drone_last_action_pressed = action_pressed
	_start_weapon_fire_sheet_animation("suicide_drone")
	_spawn_suicide_drone(config)
	_play_fire_audio("suicide_drone", deps)
	var skill_state: Object = deps.get("skill_state", null)
	var skill_config: Object = deps.get("skill_config", null)
	if skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown("suicide_drone", now_msec, skill_config)
	var updated_weapon: Dictionary = current_weapon
	if weapon_controller != null and weapon_controller.has_method("get_current_weapon_data"):
		updated_weapon = weapon_controller.get_current_weapon_data()
	return _build_suicide_drone_fire_result(updated_weapon, ammo_current, special_gauge)


func _update_active_suicide_drone_input(
	input_snapshot: Dictionary,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var index: int = _get_active_suicide_drone_index()
	if index < 0:
		return {}
	var projectile: Dictionary = _get_dict(projectiles[index])
	_apply_suicide_drone_input_to_projectile(projectile, input_snapshot)
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
	return _build_suicide_drone_active_input_result(projectile, special_gauge)


func _suicide_drone_fire_failed(special_gauge: float, reason: String) -> Dictionary:
	return CommandoFirearmSuicideDroneState.build_fire_failed_result(special_gauge, reason, suicide_drone_cooldown_frames)


func _spawn_suicide_drone(config: Dictionary) -> void:
	var profile: Dictionary = _get_weapon_profile("suicide_drone")
	var origin: Vector2 = _get_suicide_drone_spawn_pos(config)
	var shot_id: int = _next_shot_id()
	_append_limited(projectiles, _build_suicide_drone_projectile(profile, origin, config, shot_id), PROJECTILE_LIMIT)
	_spawn_muzzle_flash(origin, Vector2.UP, profile, "suicide_drone")


func _build_suicide_drone_fire_result(updated_weapon: Dictionary, ammo_current: int, special_gauge: float) -> Dictionary:
	return CommandoFirearmSuicideDroneState.build_fire_result(
		updated_weapon,
		ammo_current,
		SUICIDE_DRONE_AMMO_MAX,
		SUICIDE_DRONE_GRACE_FRAMES,
		special_gauge
	)


func _build_suicide_drone_active_input_result(projectile: Dictionary, special_gauge: float) -> Dictionary:
	return CommandoFirearmSuicideDroneState.build_active_input_result(projectile, special_gauge)


func _build_suicide_drone_projectile(
	profile: Dictionary,
	origin: Vector2,
	config: Dictionary,
	shot_id: int
) -> Dictionary:
	return CommandoFirearmSuicideDroneState.build_projectile(
		profile,
		origin,
		_get_boss_target_pos(config),
		shot_id,
		_get_player_lock_pos(config),
		SUICIDE_DRONE_SIZE,
		SUICIDE_DRONE_MAX_SPEED,
		SUICIDE_DRONE_ACCEL,
		SUICIDE_DRONE_LIFE_FRAMES,
		SUICIDE_DRONE_GRACE_FRAMES,
		SUICIDE_DRONE_ROTOR_BASE_SPEED
	)


func _get_suicide_drone_spawn_pos(config: Dictionary) -> Vector2:
	return CommandoFirearmSuicideDroneGeometry.get_spawn_pos(config, FIELD_WIDTH, FIELD_HEIGHT, SUICIDE_DRONE_SIZE)


func _get_player_lock_pos(config: Dictionary) -> Vector2:
	return CommandoFirearmSuicideDroneGeometry.get_player_lock_pos(config, FIELD_WIDTH, FIELD_HEIGHT)


func _apply_suicide_drone_input_to_projectile(projectile: Dictionary, input_snapshot: Dictionary) -> void:
	var input_vector: Vector2 = _get_suicide_drone_input_vector(input_snapshot)
	var next_projectile: Dictionary = _get_suicide_drone_input_projectile_state(input_vector, projectile)
	projectile.clear()
	projectile.merge(next_projectile, true)


func _get_suicide_drone_input_projectile_state(input_vector: Vector2, projectile: Dictionary) -> Dictionary:
	return CommandoFirearmSuicideDroneState.apply_input(
		projectile,
		input_vector,
		SUICIDE_DRONE_ACCEL,
		SUICIDE_DRONE_MAX_SPEED,
		SUICIDE_DRONE_ROTOR_BASE_SPEED,
		SUICIDE_DRONE_ROTOR_SPEED_SCALE
	)


func _get_suicide_drone_input_vector(input_snapshot: Dictionary) -> Vector2:
	return CommandoFirearmInputResolver.get_suicide_drone_input_vector(input_snapshot)


func _get_suicide_drone_draw_state() -> Dictionary:
	var index: int = _get_active_suicide_drone_index()
	var projectile: Dictionary = _get_dict(projectiles[index]) if index >= 0 else {}
	return CommandoFirearmDrawStateResolver.build_suicide_drone_state(
		index >= 0,
		suicide_drone_cooldown_frames,
		SUICIDE_DRONE_COOLDOWN_FRAMES,
		float(projectile.get("grace_timer_frames", 0.0)),
		_get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO),
		_get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	)


func _input_action_just_pressed(input_snapshot: Dictionary) -> bool:
	return CommandoFirearmInputResolver.input_action_just_pressed(input_snapshot)


func _is_ready(weapon_id: String, now_msec: int, deps: Dictionary) -> bool:
	if weapon_id == "pistol" or weapon_id == "":
		return true
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state == null or not skill_state.has_method("get_cooldown_remaining"):
		return true
	var skill_config: Object = deps.get("skill_config", null)
	var cooldown_seconds := 0.0
	if skill_config != null and skill_config.has_method("get_cooldown_seconds"):
		cooldown_seconds = float(skill_config.get_cooldown_seconds(weapon_id))
	return float(skill_state.get_cooldown_remaining(weapon_id, now_msec, cooldown_seconds)) <= 0.0


func _update_slingshot_input(input_snapshot: Dictionary, special_gauge: float, config: Dictionary, deps: Dictionary) -> Dictionary:
	slingshot_cooldown_frames = max(0.0, slingshot_cooldown_frames - 1.0)
	var action_pressed: bool = bool(input_snapshot.get("action_pressed", false))
	var action_just_pressed: bool = bool(input_snapshot.get("action_just_pressed", action_pressed and not slingshot_last_action_pressed))
	var action_just_released: bool = bool(input_snapshot.get("action_just_released", not action_pressed and slingshot_last_action_pressed))
	slingshot_last_action_pressed = action_pressed
	if bool(input_snapshot.get("down_pressed", false)):
		if slingshot_charging:
			special_gauge = _cancel_slingshot_charge(special_gauge)
		return {}
	if slingshot_charging:
		if not action_pressed or action_just_released:
			return _release_slingshot(special_gauge, config, deps, "released")
		var charge_drain_result: Dictionary = _advance_slingshot_charge(special_gauge)
		special_gauge = float(charge_drain_result.get("special_gauge", special_gauge))
		if bool(charge_drain_result.get("force_release", false)):
			return _release_slingshot(special_gauge, config, deps, "gauge_empty")
		return {
			"handled": true,
			"weapon_id": BASE_WEAPON_ID,
			"charging": true,
			"charge_timer_frames": slingshot_charge_timer_frames,
			"charge_level": slingshot_charge_level,
			"special_gauge": special_gauge,
		}
	if not action_just_pressed:
		return {}
	var now_msec: int = Time.get_ticks_msec()
	if _is_fire_suppressed_after_switch(deps.get("commando_weapon_controller", null), now_msec):
		return {}
	if slingshot_cooldown_frames > 0.0 or special_gauge < SLINGSHOT_GAUGE_COST:
		return {
			"handled": true,
			"weapon_id": BASE_WEAPON_ID,
			"fire_failed": true,
			"special_gauge": special_gauge,
			"failure_reason": "slingshot_not_ready",
		}
	slingshot_charging = true
	slingshot_charge_timer_frames = 0.0
	slingshot_charge_level = 0
	slingshot_gauge_spent = 0.0
	var drain_result: Dictionary = _advance_slingshot_charge(special_gauge)
	special_gauge = float(drain_result.get("special_gauge", special_gauge))
	return {
		"handled": true,
		"weapon_id": BASE_WEAPON_ID,
		"charging": true,
		"charge_timer_frames": slingshot_charge_timer_frames,
		"charge_level": slingshot_charge_level,
		"special_gauge": special_gauge,
	}


func _advance_slingshot_charge(special_gauge: float) -> Dictionary:
	slingshot_charge_timer_frames += 1.0
	var timer_int: int = int(round(slingshot_charge_timer_frames))
	if timer_int >= int(SLINGSHOT_GAUGE_DRAIN_INTERVAL_FRAMES) and timer_int % int(SLINGSHOT_GAUGE_DRAIN_INTERVAL_FRAMES) == 0:
		if special_gauge >= SLINGSHOT_GAUGE_COST:
			special_gauge = max(0.0, special_gauge - SLINGSHOT_GAUGE_COST)
			slingshot_gauge_spent += SLINGSHOT_GAUGE_COST
		else:
			_update_slingshot_charge_level()
			return {
				"special_gauge": special_gauge,
				"force_release": true,
			}
	_update_slingshot_charge_level()
	return {
		"special_gauge": special_gauge,
		"force_release": false,
	}


func _update_slingshot_charge_level() -> void:
	if slingshot_charge_timer_frames >= SLINGSHOT_CHARGE_THRESHOLD_3:
		slingshot_charge_level = 3
	elif slingshot_charge_timer_frames >= SLINGSHOT_CHARGE_THRESHOLD_2:
		slingshot_charge_level = 2
	elif slingshot_charge_timer_frames >= SLINGSHOT_CHARGE_THRESHOLD_1:
		slingshot_charge_level = 1
	else:
		slingshot_charge_level = 0


func _release_slingshot(special_gauge: float, config: Dictionary, deps: Dictionary, reason: String = "released") -> Dictionary:
	var charge_level: int = slingshot_charge_level
	var charge_time: float = slingshot_charge_timer_frames
	slingshot_charging = false
	slingshot_charge_timer_frames = 0.0
	slingshot_charge_level = 0
	slingshot_gauge_spent = 0.0
	if charge_time < SLINGSHOT_GAUGE_DRAIN_INTERVAL_FRAMES or charge_level < 1:
		return {
			"handled": true,
			"weapon_id": BASE_WEAPON_ID,
			"charge_canceled": true,
			"failure_reason": "slingshot_charge_short",
			"special_gauge": special_gauge,
		}
	_spawn_firearm_effect(BASE_WEAPON_ID, config, deps, _get_slingshot_fire_profile(charge_level))
	_play_fire_audio(BASE_WEAPON_ID, deps)
	last_fire_msec = Time.get_ticks_msec()
	slingshot_cooldown_frames = SLINGSHOT_COOLDOWN_FRAMES
	slingshot_control_lock_frames = SLINGSHOT_CONTROL_LOCK_FRAMES
	return {
		"handled": true,
		"weapon_id": BASE_WEAPON_ID,
		"fired": true,
		"charge_level": charge_level,
		"charge_time_frames": charge_time,
		"control_lock_frames": SLINGSHOT_CONTROL_LOCK_FRAMES,
		"release_reason": reason,
		"special_gauge": special_gauge,
		"skill_gold_award": 0,
	}


func _cancel_slingshot_charge(special_gauge: float) -> float:
	slingshot_charging = false
	slingshot_charge_timer_frames = 0.0
	slingshot_charge_level = 0
	slingshot_gauge_spent = 0.0
	return special_gauge


func _get_slingshot_fire_profile(charge_level: int) -> Dictionary:
	var level: int = clampi(charge_level, 1, 3)
	var profile: Dictionary = _get_weapon_profile(BASE_WEAPON_ID)
	profile["speed"] = float(SLINGSHOT_PYTHON_SPEED_BY_LEVEL.get(level, SLINGSHOT_BASE_BULLET_SPEED))
	profile["radius"] = SLINGSHOT_PELLET_SIZE + float(level - 1)
	profile["charge_level"] = level
	profile["slingshot"] = true
	if level >= 3:
		profile["color"] = Color(1.0, 0.78, 0.36)
		profile["secondary"] = Color(1.0, 0.92, 0.42)
	elif level == 2:
		profile["color"] = Color(0.82, 0.82, 0.88)
		profile["secondary"] = Color(0.96, 0.96, 1.0)
	return profile


func _get_slingshot_draw_state() -> Dictionary:
	return CommandoFirearmDrawStateResolver.build_slingshot_state(
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


func _get_pistol_draw_state() -> Dictionary:
	return CommandoFirearmDrawStateResolver.build_pistol_state(
		pistol_cooldown_frames,
		pistol_cooldown_max_frames,
		pistol_control_lock_frames,
		pistol_control_lock_max_frames,
		pistol_fire_delay_frames,
		PISTOL_FIRE_DELAY_FRAMES,
		pistol_post_fire_animation_frames,
		PISTOL_POST_FIRE_ANIMATION_FRAMES
	)


func _get_weapon_fire_sheet_draw_state() -> Dictionary:
	return CommandoFirearmDrawStateResolver.build_weapon_fire_sheet_state(
		weapon_fire_sheet_id,
		weapon_fire_sheet_timer_frames,
		weapon_fire_sheet_max_frames,
		COMMANDO_WEAPON_FIRE_SHEET_FRAME_COUNT
	)


func _get_ak47_draw_state() -> Dictionary:
	return CommandoFirearmDrawStateResolver.build_ak47_state(
		ak47_trigger_held,
		ak47_fire_interval_frames,
		AK47_FIRE_INTERVAL_FRAMES,
		ak47_burst_shots_remaining,
		ak47_recoil_accumulation,
		get_movement_speed_multiplier()
	)


func _get_bazooka_draw_state() -> Dictionary:
	return CommandoFirearmDrawStateResolver.build_bazooka_state(
		bazooka_cooldown_frames,
		BAZOOKA_COOLDOWN_FRAMES,
		bazooka_control_lock_frames,
		BAZOOKA_CONTROL_LOCK_FRAMES,
		bazooka_fire_animation_frames,
		BAZOOKA_FIRE_ANIMATION_FRAMES,
		bazooka_firing_pose_frames,
		BAZOOKA_FIRING_POSE_FRAMES,
		bazooka_muzzle_flash_frames,
		BAZOOKA_MUZZLE_FLASH_FRAMES
	)


func _get_net_gun_draw_state() -> Dictionary:
	return CommandoFirearmDrawStateResolver.build_net_gun_state(
		net_gun_cooldown_frames,
		NET_GUN_COOLDOWN_FRAMES,
		net_gun_control_lock_frames,
		NET_GUN_CONTROL_LOCK_FRAMES,
		net_gun_throw_pose_frames,
		NET_GUN_THROW_POSE_FRAMES,
		net_gun_harpoon_flash_frames,
		NET_GUN_HARPOON_FLASH_FRAMES,
		get_movement_speed_multiplier(),
		_has_hooked_net_field()
	)


func _spawn_firearm_effect(weapon_id: String, config: Dictionary, deps: Dictionary, profile_override: Dictionary = {}) -> void:
	_start_weapon_fire_sheet_animation(weapon_id)
	var profile: Dictionary = profile_override.duplicate(true) if not profile_override.is_empty() else _get_weapon_profile(weapon_id)
	var doping_context: Dictionary = _get_doping_potion_context_from_config(config)
	if weapon_id == "commando_pistol" and bool(doping_context.get("active", false)):
		profile["speed"] = float(profile.get("speed", PISTOL_BULLET_SPEED)) * float(doping_context.get("pistol_speed_multiplier", DOPING_POTION_PISTOL_SPEED_MULTIPLIER))
		profile["color"] = Color(1.0, 0.47, 0.24)
		profile["secondary"] = Color(1.0, 0.78, 0.22)
	if _is_pistol_weapon(weapon_id) and not bool(profile.get("slingshot", false)) and not profile.has("angle_offset"):
		profile["angle_offset"] = randf_range(-PISTOL_SPREAD_RADIANS, PISTOL_SPREAD_RADIANS)
	var kind: String = str(profile.get("kind", "bullet"))
	var origin: Vector2 = _get_firearm_origin(weapon_id, config, profile)
	var target: Vector2 = _get_boss_target_pos(config)
	var aim_origin: Vector2 = _get_firearm_aim_origin(weapon_id, config, origin)
	var direction: Vector2 = Vector2.UP if bool(profile.get("vertical_launch", false)) else target - aim_origin
	if not bool(profile.get("vertical_launch", false)):
		if direction.length() <= 0.001:
			direction = Vector2.UP
		else:
			direction = direction.normalized()
	var angle_offset: float = float(profile.get("angle_offset", 0.0))
	if abs(angle_offset) > 0.0001:
		direction = direction.rotated(angle_offset).normalized()
	_spawn_muzzle_flash(origin, direction, profile, weapon_id)
	if kind == "support":
		_start_support_call(origin, target, profile, weapon_id, deps)
		return
	if kind == "trap" or weapon_id == "bowling_trap":
		_start_bowling_trap_install(config, profile, weapon_id)
		return
	var speed: float = float(profile.get("speed", 16.0))
	var shot_id: int = _next_shot_id()
	var projectile := {
		"id": shot_id,
		"weapon_id": weapon_id,
		"kind": kind,
		"pos": origin,
		"prev_pos": origin,
		"target": target,
		"velocity": direction * speed,
		"speed": speed,
		"angle_offset": angle_offset,
		"radius": float(profile.get("radius", 5.0)),
		"trail": float(profile.get("trail", 24.0)),
		"life_frames": float(profile.get("life_frames", 45.0)),
		"max_life_frames": float(profile.get("life_frames", 45.0)),
		"impact_radius": float(profile.get("impact_radius", 18.0)),
		"color": profile.get("color", Color.WHITE),
		"secondary": profile.get("secondary", Color(1.0, 0.5, 0.2)),
	}
	if weapon_id == "commando_pistol" and bool(doping_context.get("active", false)):
		projectile["active_item_doping_potion_active"] = true
		projectile["active_item_doping_potion_head_leg_multiplier"] = float(doping_context.get("head_leg_multiplier", DOPING_POTION_HEAD_LEG_MULTIPLIER))
		projectile["active_item_doping_potion_pistol_speed_multiplier"] = float(doping_context.get("pistol_speed_multiplier", DOPING_POTION_PISTOL_SPEED_MULTIPLIER))
	if bool(profile.get("slingshot", false)):
		var charge_level: int = clampi(int(profile.get("charge_level", 1)), 1, 3)
		var stone_variant: int = abs(shot_id - 1) % 4
		projectile["slingshot"] = true
		projectile["charge_level"] = charge_level
		projectile["slingshot_stone_variant"] = stone_variant
		projectile["slingshot_stone_frame"] = (charge_level - 1) * 4 + stone_variant
	if profile.has("explosion_radius"):
		projectile["explosion_radius"] = float(profile.get("explosion_radius", float(profile.get("impact_radius", 18.0))))
	if profile.has("acceleration"):
		projectile["acceleration"] = float(profile.get("acceleration", 0.0))
	if profile.has("max_speed"):
		projectile["max_speed"] = float(profile.get("max_speed", speed))
	if profile.has("smoke_trail_limit"):
		projectile["smoke_trail_limit"] = int(profile.get("smoke_trail_limit", BAZOOKA_SMOKE_TRAIL_LIMIT))
		projectile["smoke_trail"] = []
	if weapon_id == "net_gun":
		projectile["origin"] = aim_origin
		projectile["rope_points"] = []
		projectile["rope_trail_limit"] = int(profile.get("rope_trail_limit", NET_GUN_ROPE_TRAIL_LIMIT))
	_append_limited(projectiles, projectile, PROJECTILE_LIMIT)
	if weapon_id == "ak47":
		_spawn_ak47_shell_casing(origin, direction, config, shot_id)
	elif weapon_id == "pistol" or weapon_id == "commando_pistol":
		_spawn_pistol_shell_casing(origin, direction, config, shot_id, weapon_id)


func _start_support_call(origin: Vector2, target: Vector2, profile: Dictionary, weapon_id: String, deps: Dictionary) -> void:
	var call_id: int = _next_shot_id()
	var delay_frames: float = _get_support_call_delay_frames(call_id, target)
	var bomb_count: int = _get_support_bomb_count(call_id, target)
	while support_calls.size() >= max(1, SUPPORT_CALL_LIMIT):
		var evicted: Dictionary = _get_dict(support_calls.pop_front())
		_stop_support_aircraft_audio(evicted, deps)
	support_calls.append(_build_support_call_payload(
		call_id,
		origin,
		target,
		profile,
		weapon_id,
		delay_frames,
		bomb_count
	))
	_play_first_audio_method(deps, ["play_commando_fire_support_radio", "play_commando_supply_radio"])
	_append_limited(impact_flashes, _build_support_marker_flash(weapon_id, target, profile), FLASH_LIMIT)


func _build_support_call_payload(
	call_id: int,
	origin: Vector2,
	target: Vector2,
	profile: Dictionary,
	weapon_id: String,
	delay_frames: float,
	bomb_count: int
) -> Dictionary:
	return CommandoFirearmSupportCallResolver.build_call_payload(
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
		SUPPORT_AIRCRAFT_SPEED
	)


func _build_support_marker_flash(weapon_id: String, target: Vector2, profile: Dictionary) -> Dictionary:
	return CommandoFirearmSupportCallResolver.build_marker_flash(
		weapon_id,
		target,
		profile,
		SUPPORT_CALL_LOCK_FRAMES
	)


func _get_support_call_delay_frames(call_id: int, target: Vector2) -> float:
	return CommandoFirearmSupportCallResolver.get_delay_frames(
		call_id,
		target,
		SUPPORT_CALL_DELAY_MIN_FRAMES,
		SUPPORT_CALL_DELAY_MAX_FRAMES
	)


func _get_support_bomb_count(call_id: int, target: Vector2) -> int:
	return CommandoFirearmSupportCallResolver.get_bomb_count(
		call_id,
		target,
		SUPPORT_BOMB_MIN_COUNT,
		SUPPORT_BOMB_MAX_COUNT
	)


func _support_call_seed(call_id: int, target: Vector2) -> int:
	return CommandoFirearmSupportCallResolver.support_call_seed(call_id, target)


func _start_bowling_trap_install(config: Dictionary, profile: Dictionary, weapon_id: String) -> void:
	var trap_pos: Vector2 = _get_bowling_trap_install_pos(config)
	var trap_id: int = _next_shot_id()
	_append_limited(bowling_traps, _build_bowling_trap_install_payload(
		trap_pos,
		profile,
		weapon_id,
		trap_id
	), BOWLING_TRAP_LIMIT)
	_append_limited(impact_flashes, _build_bowling_trap_install_marker_flash(
		trap_pos,
		profile,
		weapon_id
	), FLASH_LIMIT)


func _get_bowling_trap_install_pos(config: Dictionary) -> Vector2:
	return CommandoFirearmBowlingTrapGeometry.get_install_pos(
		config,
		FIELD_WIDTH,
		FIELD_HEIGHT,
		BOWLING_TRAP_WIDTH,
		BOWLING_TRAP_HEIGHT,
		BOWLING_TRAP_MIN_FIELD_Y_RATIO
	)


func _build_bowling_trap_install_payload(
	trap_pos: Vector2,
	profile: Dictionary,
	weapon_id: String,
	trap_id: int
) -> Dictionary:
	return CommandoFirearmBowlingTrapGeometry.build_install_trap(
		trap_pos,
		profile,
		weapon_id,
		trap_id,
		BOWLING_TRAP_WIDTH,
		BOWLING_TRAP_HEIGHT,
		BOWLING_TRAP_INSTALL_FRAMES,
		BOWLING_TRAP_CAPTURE_BALL_OFFSET
	)


func _build_bowling_trap_install_marker_flash(trap_pos: Vector2, profile: Dictionary, weapon_id: String) -> Dictionary:
	return CommandoFirearmBowlingTrapGeometry.build_install_marker_flash(trap_pos, profile, weapon_id)


func _spawn_support_round(target: Vector2, profile: Dictionary, weapon_id: String, call_id: int = 0, spawn_index: int = 0) -> void:
	_append_limited(projectiles, _build_support_round_projectile(
		target,
		profile,
		weapon_id,
		_next_shot_id(),
		call_id,
		spawn_index
	), PROJECTILE_LIMIT)


func _build_support_round_projectile(
	target: Vector2,
	profile: Dictionary,
	weapon_id: String,
	projectile_id: int,
	call_id: int = 0,
	spawn_index: int = 0
) -> Dictionary:
	return CommandoFirearmSupportProjectileResolver.build_projectile(
		target,
		profile,
		weapon_id,
		projectile_id,
		call_id,
		spawn_index,
		FIELD_WIDTH,
		FIELD_HEIGHT,
		SUPPORT_AIRCRAFT_Y,
		SUPPORT_BOMB_INITIAL_VY,
		SUPPORT_BOMB_GRAVITY,
		SUPPORT_BOMB_HORIZONTAL_JITTER
	)


func _spawn_muzzle_flash(origin: Vector2, direction: Vector2, profile: Dictionary, weapon_id: String) -> void:
	_append_limited(muzzle_flashes, _build_muzzle_flash(origin, direction, profile, weapon_id), FLASH_LIMIT)


func _build_muzzle_flash(origin: Vector2, direction: Vector2, profile: Dictionary, weapon_id: String) -> Dictionary:
	return CommandoFirearmMuzzleFlashResolver.build_flash(origin, direction, profile, weapon_id)


func _update_support_calls(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var step: float = max(0.0, fps_scale)
	var profile: Dictionary = _get_weapon_profile("fire_support")
	for index in range(support_calls.size() - 1, -1, -1):
		@warning_ignore("shadowed_variable_base_class")
		var call: Dictionary = _get_dict(support_calls[index])
		var advance_result: Dictionary = _advance_support_call(call, step)
		call = _get_dict(advance_result.get("call", call))
		if bool(advance_result.get("started_aircraft", false)):
			_start_support_aircraft_audio(call, deps)
		if bool(advance_result.get("spawn_bomb", false)):
			_spawn_support_bomb(call, profile, context, int(advance_result.get("spawn_index", 0)))
		if bool(advance_result.get("finished", false)):
			_stop_support_aircraft_audio(call, deps)
			support_calls.remove_at(index)
		else:
			support_calls[index] = call


func _advance_support_call(call_data: Dictionary, step: float) -> Dictionary:
	return CommandoFirearmSupportCallResolver.advance_call(
		call_data,
		step,
		Vector2(-140.0, SUPPORT_AIRCRAFT_Y),
		Vector2(SUPPORT_AIRCRAFT_SPEED, 0.0),
		SUPPORT_BOMB_INTERVAL_FRAMES,
		FIELD_WIDTH,
		150.0
	)


@warning_ignore("shadowed_variable_base_class")
func _spawn_support_bomb(call: Dictionary, profile: Dictionary, context: Dictionary, spawn_index: int) -> void:
	var target: Vector2 = _get_vector2(call.get("target", _get_boss_target_pos(context)), _get_boss_target_pos(context))
	var bomb_target: Vector2 = _get_support_bomb_target(target, spawn_index)
	_spawn_support_round(
		bomb_target,
		profile,
		"fire_support",
		int(call.get("id", 0)),
		spawn_index
	)


func _get_support_bomb_target(target: Vector2, spawn_index: int) -> Vector2:
	return CommandoFirearmSupportCallResolver.get_bomb_target(target, spawn_index, FIELD_WIDTH, FIELD_HEIGHT)


func _update_bowling_traps(fps_scale: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	var step: float = max(0.0, fps_scale)
	var result: Dictionary = {}
	for index in range(bowling_traps.size() - 1, -1, -1):
		var trap: Dictionary = _get_dict(bowling_traps[index])
		var state: String = str(trap.get("state", "waiting"))
		if state == "installing":
			_update_bowling_trap_install(index, trap, step)
		elif state == "waiting":
			if result.is_empty() and _bowling_trap_hits_ball(trap, context):
				_capture_bowling_trap_ball(index, trap, context, deps)
				result = _build_bowling_trap_capture_result(_get_dict(bowling_traps[index]))
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
	var ball_vel: Vector2 = _get_vector2(captured_trap.get("captured_original_vel", Vector2.ZERO), Vector2.ZERO)
	var captured_pos: Vector2 = _get_vector2(captured_trap.get("captured_ball_pos", Vector2.ZERO), Vector2.ZERO)
	bowling_traps[index] = captured_trap
	_trigger_hit_feedback(_get_hit_feedback_profile("bowling_trap"), deps)
	_register_ball_hit_pulse(captured_pos, ball_vel, 0.62, "bowling_trap_capture", deps)
	_play_impact_audio("bowling_trap", deps)


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
	return _build_bowling_trap_capture_result(next_trap)


func _build_bowling_trap_capture_result(trap: Dictionary) -> Dictionary:
	return CommandoFirearmBowlingTrapGeometry.build_capture_result(trap)


func _release_bowling_trap_ball(trap: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	var motion: Dictionary = CommandoFirearmBowlingTrapGeometry.build_release_motion(
		trap,
		BOWLING_TRAP_CAPTURE_BALL_OFFSET,
		BOWLING_TRAP_LAUNCH_SPEED_MULTIPLIER,
		BOWLING_TRAP_LAUNCH_ANGLE_STEP
	)
	var profile: Dictionary = _get_weapon_profile("bowling_trap")
	var pseudo_projectile: Dictionary = CommandoFirearmBowlingTrapGeometry.build_release_pseudo_projectile(
		trap,
		motion,
		profile
	)
	_spawn_impact_flash(pseudo_projectile)
	_spawn_lingering_effect("bowling_trap", pseudo_projectile, context)
	_trigger_hit_feedback(_get_hit_feedback_profile("bowling_trap"), deps)
	var captured_pos: Vector2 = _get_vector2(motion.get("captured_pos", Vector2.ZERO), Vector2.ZERO)
	var launch_vel: Vector2 = _get_vector2(motion.get("launch_vel", Vector2.ZERO), Vector2.ZERO)
	_register_ball_hit_pulse(captured_pos, launch_vel, 0.86, "bowling_trap_launch", deps)
	var guard_source: String = _arm_bowling_trap_guard(trap, float(motion.get("original_speed", 1.0)))
	return CommandoFirearmBowlingTrapGeometry.build_release_result(
		motion,
		guard_source,
		BOWLING_TRAP_GUARD_KNOCKBACK_POWER,
		BOWLING_TRAP_GUARD_STUN_FRAMES,
		BOWLING_TRAP_GUARD_SPEED_REDUCTION
	)


func _arm_bowling_trap_guard(trap: Dictionary, original_speed: float) -> String:
	var guard_state: Dictionary = CommandoFirearmBowlingTrapGeometry.build_guard_state(
		trap,
		original_speed,
		BOWLING_TRAP_GUARD_SPEED_REDUCTION
	)
	_apply_bowling_trap_guard_state(guard_state)
	return str(guard_state.get("source", ""))


func _clear_bowling_trap_guard() -> void:
	_apply_bowling_trap_guard_state(CommandoFirearmBowlingTrapGeometry.build_cleared_guard_state())


func _apply_bowling_trap_guard_state(guard_state: Dictionary) -> void:
	bowling_trap_guard_armed = bool(guard_state.get("armed", false))
	bowling_trap_guard_original_speed = float(guard_state.get("original_speed", 0.0))
	bowling_trap_guard_restore_speed = float(guard_state.get("restore_speed", 0.0))
	bowling_trap_guard_source = str(guard_state.get("source", ""))


func _soften_bowling_trap_guard_ball(ball_vel: Vector2, restore_speed: float) -> Vector2:
	return CommandoFirearmBowlingTrapGeometry.soften_guard_ball(ball_vel, restore_speed)


func _get_bowling_trap_guard_knockback_velocity(boss_center: Vector2, context: Dictionary) -> float:
	return CommandoFirearmBowlingTrapGeometry.get_guard_knockback_velocity(
		boss_center,
		context,
		FIELD_WIDTH,
		BOWLING_TRAP_GUARD_KNOCKBACK_POWER
	)


func _get_bowling_trap_launch_direction(shot_id: int) -> int:
	return CommandoFirearmBowlingTrapGeometry.get_launch_direction(shot_id)


func _bowling_trap_hits_ball(trap: Dictionary, context: Dictionary) -> bool:
	return CommandoFirearmBowlingTrapGeometry.hits_ball(
		trap,
		context,
		BOWLING_TRAP_HEIGHT,
		BOWLING_TRAP_CAPTURE_HEIGHT,
		BOWLING_TRAP_WIDTH
	)


func _update_projectiles(fps_scale: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	var step: float = max(0.0, fps_scale)
	var result: Dictionary = {}
	for index in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = _get_dict(projectiles[index])
		var projectile_kind: String = _get_projectile_kind(projectile)
		var projectile_weapon_id: String = _get_projectile_weapon_id(projectile)
		var pos: Vector2 = _get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
		var velocity: Vector2 = _get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
		if projectile_kind == "drone":
			velocity = _get_drone_velocity(pos, projectile, context, fps_scale)
		elif projectile_kind == "rocket":
			velocity = _update_rocket_motion(projectile, pos, velocity, step)
		if projectile.has("gravity"):
			velocity.y += float(projectile.get("gravity", 0.0)) * step
		var prev_pos: Vector2 = pos
		pos += velocity * step
		if _apply_pistol_side_wall_bounce(projectile, pos, velocity, context):
			pos = _get_vector2(projectile.get("pos", pos), pos)
			velocity = _get_vector2(projectile.get("velocity", velocity), velocity)
		if projectile_kind == "net":
			_update_net_projectile_rope(projectile, pos, context)
		projectile["prev_pos"] = prev_pos
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
		var impact_reason: String = _get_projectile_impact_reason(projectile, context)
		if impact_reason != "":
			_spawn_impact_flash(projectile)
			if impact_reason == "target":
				_register_projectile_hit(projectile, context, deps)
			elif impact_reason == "wall":
				var wall_result: Dictionary = _register_projectile_environment_impact(projectile, impact_reason, context, deps)
				result.merge(wall_result, true)
				context.merge(wall_result, true)
			elif _is_net_gun_weapon(projectile_weapon_id):
				_spawn_net_dissolve_effect(projectile, context)
			projectiles.remove_at(index)
			if projectile_kind == "drone" and not _has_active_suicide_drone_projectile():
				_stop_suicide_drone_audio(deps)
	return result


func _apply_pistol_side_wall_bounce(projectile: Dictionary, pos: Vector2, velocity: Vector2, context: Dictionary) -> bool:
	if not _is_wall_bouncing_pistol(projectile):
		return false
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
	if not bool(bounce_result.get("bounced", false)):
		return false
	projectile.clear()
	projectile.merge(_get_dict(bounce_result.get("projectile", projectile)), true)
	return true


func _is_wall_bouncing_pistol(projectile: Dictionary) -> bool:
	return _is_pistol_weapon(_get_projectile_weapon_id(projectile, ""))


func _update_rocket_motion(projectile: Dictionary, pos: Vector2, velocity: Vector2, step: float) -> Vector2:
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
	projectile.merge(_get_dict(motion_result.get("projectile", projectile)), true)
	return _get_vector2(motion_result.get("velocity", velocity), velocity)


func _update_net_projectile_rope(projectile: Dictionary, pos: Vector2, context: Dictionary) -> void:
	var next_projectile: Dictionary = CommandoFirearmProjectileMotionState.update_net_projectile_rope(
		projectile,
		pos,
		_get_net_gun_aim_origin(context),
		NET_GUN_ROPE_TRAIL_LIMIT
	)
	projectile.clear()
	projectile.merge(next_projectile, true)


func _spawn_ak47_shell_casing(origin: Vector2, direction: Vector2, config: Dictionary, shot_id: int) -> void:
	_append_limited(shell_casings, CommandoFirearmShellCasingState.build_ak47_shell(
		origin,
		direction,
		config,
		shot_id,
		FIELD_HEIGHT,
		AK47_SHELL_LIFETIME_FRAMES
	), SHELL_CASING_LIMIT)


func _spawn_pistol_shell_casing(origin: Vector2, direction: Vector2, config: Dictionary, shot_id: int, weapon_id: String = "commando_pistol") -> void:
	_append_limited(shell_casings, CommandoFirearmShellCasingState.build_pistol_shell(
		origin,
		direction,
		config,
		shot_id,
		weapon_id,
		FIELD_HEIGHT,
		PISTOL_SHELL_LIFETIME_FRAMES
	), SHELL_CASING_LIMIT)


func _update_shell_casings(fps_scale: float) -> void:
	var step: float = max(0.0, fps_scale)
	if step <= 0.0:
		return
	for index in range(shell_casings.size() - 1, -1, -1):
		var shell: Dictionary = _get_dict(shell_casings[index])
		var update_result: Dictionary = CommandoFirearmShellCasingState.advance_shell(
			shell,
			step,
			FIELD_WIDTH,
			FIELD_HEIGHT,
			AK47_SHELL_GRAVITY,
			AK47_SHELL_BOUNCE_DECAY,
			AK47_SHELL_MAX_BOUNCES
		)
		if not bool(update_result.get("active", false)):
			shell_casings.remove_at(index)
			continue
		shell_casings[index] = _get_dict(update_result.get("shell", shell))


func _spawn_pistol_hit_feedback(hit_kind: String, context: Dictionary) -> void:
	var feedback: Dictionary = _build_pistol_hit_feedback(hit_kind, context)
	if feedback.is_empty():
		return
	_append_limited(pistol_feedbacks, feedback, PISTOL_FEEDBACK_LIMIT)


func _build_pistol_hit_feedback(hit_kind: String, context: Dictionary) -> Dictionary:
	var boss_rect: Rect2 = _get_boss_rect(context)
	return CommandoFirearmPistolFeedbackState.build_feedback(
		hit_kind,
		boss_rect,
		Vector2(FIELD_WIDTH, FIELD_HEIGHT),
		PISTOL_HIT_TEXT_TIMER_FRAMES,
		"헤드샷!",
		"레그샷!"
	)


func _update_pistol_feedbacks(fps_scale: float) -> void:
	var step: float = max(0.0, fps_scale)
	if step <= 0.0:
		return
	for index in range(pistol_feedbacks.size() - 1, -1, -1):
		var feedback: Dictionary = _get_dict(pistol_feedbacks[index])
		var update_result: Dictionary = CommandoFirearmPistolFeedbackState.advance_feedback(feedback, step)
		if not bool(update_result.get("active", false)):
			pistol_feedbacks.remove_at(index)
			continue
		pistol_feedbacks[index] = _get_dict(update_result.get("feedback", feedback))


func _get_drone_velocity(pos: Vector2, projectile: Dictionary, context: Dictionary, fps_scale: float) -> Vector2:
	var target: Vector2 = _get_boss_target_pos(context)
	return CommandoFirearmSuicideDroneState.get_homing_velocity(pos, projectile, target, fps_scale)


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
	if _suicide_drone_hits_ball(projectile, context):
		return _detonate_suicide_drone_at_index(index, projectile, "ball_hit", context, deps)
	if _suicide_drone_hits_boss(projectile, context):
		return _detonate_suicide_drone_at_index(index, projectile, "boss_hit", context, deps)
	if _suicide_drone_hits_top_wall(projectile):
		return _detonate_suicide_drone_at_index(index, projectile, "boss_back_wall", context, deps)
	if float(projectile.get("life_frames", 0.0)) <= 0.0:
		return _detonate_suicide_drone_at_index(index, projectile, "expired", context, deps)
	return {}


func _clamp_suicide_drone_projectile(projectile: Dictionary) -> void:
	var next_projectile: Dictionary = CommandoFirearmSuicideDroneState.clamp_projectile(
		projectile,
		Vector2(FIELD_WIDTH, FIELD_HEIGHT),
		SUICIDE_DRONE_SIZE
	)
	projectile.clear()
	projectile.merge(next_projectile, true)


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
	var pos: Vector2 = _get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var hit_boss: bool = _suicide_drone_explosion_hits_boss(projectile, context)
	if hit_boss:
		_register_projectile_hit(projectile, context, deps)
	else:
		_spawn_lingering_effect("suicide_drone", projectile, context)
		_spawn_shared_impact_particles(pos, _get_color(projectile.get("color", Color.WHITE), Color.WHITE), _get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO), 1.0, deps)
		_trigger_hit_feedback(_get_hit_feedback_profile("suicide_drone"), deps)
		_register_ball_hit_pulse(pos, _get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO), 0.86, "suicide_drone", deps)
		_play_impact_audio("suicide_drone", deps)
	_stop_suicide_drone_audio(deps)
	suicide_drone_cooldown_frames = SUICIDE_DRONE_COOLDOWN_FRAMES
	var result: Dictionary = _build_suicide_drone_detonation_result(reason, pos, hit_boss)
	if reason == "ball_hit":
		result.merge(_build_suicide_drone_ball_boost_result(projectile, context), true)
	return result


func _build_suicide_drone_detonation_result(reason: String, pos: Vector2, hit_boss: bool) -> Dictionary:
	return CommandoFirearmSuicideDroneState.build_detonation_result(
		reason,
		pos,
		hit_boss,
		suicide_drone_cooldown_frames
	)


func _build_suicide_drone_ball_boost_result(projectile: Dictionary, context: Dictionary) -> Dictionary:
	return CommandoFirearmSuicideDroneBallBoostResolver.build_boost_result(
		projectile,
		context,
		SUICIDE_DRONE_BALL_SPEED_MULTIPLIER,
		SUICIDE_DRONE_BALL_FAN_DEGREES
	)


func _get_suicide_drone_ball_fan_angle(projectile: Dictionary) -> float:
	return CommandoFirearmSuicideDroneBallBoostResolver.get_fan_angle(projectile, SUICIDE_DRONE_BALL_FAN_DEGREES)


func _suicide_drone_hits_ball(projectile: Dictionary, context: Dictionary) -> bool:
	return CommandoFirearmSuicideDroneGeometry.hits_ball(projectile, context, SUICIDE_DRONE_SIZE)


func _suicide_drone_hits_boss(projectile: Dictionary, context: Dictionary) -> bool:
	return CommandoFirearmSuicideDroneGeometry.hits_boss_rect(
		projectile,
		_get_boss_rect(context),
		SUICIDE_DRONE_SIZE
	)


func _suicide_drone_explosion_hits_boss(projectile: Dictionary, context: Dictionary) -> bool:
	var profile: Dictionary = _get_weapon_profile("suicide_drone")
	var pos: Vector2 = _get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	return _circle_contains_rect_center(pos, _get_explosion_radius(projectile, profile), _get_boss_rect(context))


func _suicide_drone_hits_top_wall(projectile: Dictionary) -> bool:
	return CommandoFirearmSuicideDroneGeometry.hits_top_wall(projectile, SUICIDE_DRONE_SIZE)


func _get_suicide_drone_rect(projectile: Dictionary) -> Rect2:
	return CommandoFirearmSuicideDroneGeometry.get_rect(projectile, SUICIDE_DRONE_SIZE)


func _get_projectile_impact_reason(projectile: Dictionary, context: Dictionary) -> String:
	var target: Vector2 = _get_projectile_target(projectile, context)
	var weapon_id: String = _get_projectile_weapon_id(projectile)
	var profile: Dictionary = _get_weapon_profile(weapon_id)
	var boss_rect: Rect2 = _get_boss_rect(context)
	return CommandoFirearmHitGeometry.get_projectile_impact_reason(
		projectile,
		target,
		weapon_id,
		profile,
		boss_rect,
		Vector2(FIELD_WIDTH, FIELD_HEIGHT),
		FIELD_WIDTH
	)


func _support_bomb_reached_target_y(projectile: Dictionary, profile: Dictionary, boss_rect: Rect2) -> bool:
	return CommandoFirearmHitGeometry.support_bomb_reached_target_y(projectile, profile, boss_rect)


func _get_direct_hit_impact_reason(projectile: Dictionary, profile: Dictionary, boss_rect: Rect2) -> String:
	return CommandoFirearmHitGeometry.get_direct_hit_impact_reason(projectile, profile, boss_rect)


func _get_fire_support_target_y_impact_reason(
	weapon_id: String,
	projectile: Dictionary,
	profile: Dictionary,
	boss_rect: Rect2
) -> String:
	return CommandoFirearmHitGeometry.get_fire_support_target_y_impact_reason(
		weapon_id,
		projectile,
		profile,
		boss_rect
	)


func _get_net_passed_target_impact_reason(weapon_id: String, projectile: Dictionary, target: Vector2) -> String:
	return CommandoFirearmHitGeometry.get_net_passed_target_impact_reason(weapon_id, projectile, target)


func _get_explosive_wall_impact_reason(projectile: Dictionary, profile: Dictionary, boss_rect: Rect2) -> String:
	return CommandoFirearmHitGeometry.get_explosive_wall_impact_reason(
		projectile,
		profile,
		boss_rect,
		FIELD_WIDTH
	)


func _get_target_reached_impact_reason(
	weapon_id: String,
	projectile: Dictionary,
	profile: Dictionary,
	boss_rect: Rect2,
	target: Vector2
) -> String:
	return CommandoFirearmHitGeometry.get_target_reached_impact_reason(
		weapon_id,
		projectile,
		profile,
		boss_rect,
		target
	)


func _get_projectile_terminal_impact_reason(projectile: Dictionary) -> String:
	return CommandoFirearmHitGeometry.get_projectile_terminal_impact_reason(
		projectile,
		Vector2(FIELD_WIDTH, FIELD_HEIGHT)
	)


func _projectile_reached_target(projectile: Dictionary, target: Vector2) -> bool:
	return CommandoFirearmHitGeometry.projectile_reached_target(projectile, target)


func _projectile_out_of_bounds(projectile: Dictionary) -> bool:
	return CommandoFirearmHitGeometry.projectile_out_of_bounds(projectile, Vector2(FIELD_WIDTH, FIELD_HEIGHT))


func _get_target_reached_expire_reason(weapon_id: String, profile: Dictionary) -> String:
	return CommandoFirearmHitGeometry.get_target_reached_expire_reason(weapon_id, profile)


func _is_fire_support_weapon(weapon_id: String) -> bool:
	return CommandoFirearmHitGeometry.is_fire_support_weapon(weapon_id)


func _is_net_gun_weapon(weapon_id: String) -> bool:
	return CommandoFirearmHitGeometry.is_net_gun_weapon(weapon_id)


func _support_bomb_target_y_already_reached(projectile: Dictionary) -> bool:
	return CommandoFirearmHitGeometry.support_bomb_target_y_already_reached(projectile)


func _projectile_life_expired(projectile: Dictionary) -> bool:
	return CommandoFirearmHitGeometry.projectile_life_expired(projectile)


func _get_projectile_target(projectile: Dictionary, context: Dictionary) -> Vector2:
	return CommandoFirearmValueUtils.get_projectile_target(projectile, _get_boss_target_pos(context))


func _get_projectile_weapon_id(projectile: Dictionary, fallback_weapon_id: String = BASE_WEAPON_ID) -> String:
	return CommandoFirearmValueUtils.get_projectile_weapon_id(projectile, fallback_weapon_id)


func _get_projectile_kind(projectile: Dictionary, fallback_kind: String = "") -> String:
	return CommandoFirearmValueUtils.get_projectile_kind(projectile, fallback_kind)


func _target_reached_hitbox_hits_boss(projectile: Dictionary, profile: Dictionary, boss_rect: Rect2) -> bool:
	return CommandoFirearmHitGeometry.target_reached_hitbox_hits_boss(projectile, profile, boss_rect)


func _projectile_hitbox_hits_boss(projectile: Dictionary, profile: Dictionary, boss_rect: Rect2) -> bool:
	return CommandoFirearmHitGeometry.projectile_hitbox_hits_boss(projectile, profile, boss_rect)


func _net_projectile_hits_boss(projectile: Dictionary, profile: Dictionary, boss_rect: Rect2) -> bool:
	return CommandoFirearmHitGeometry.net_projectile_hits_boss(projectile, profile, boss_rect)


func _net_projectile_passed_target(projectile: Dictionary, target: Vector2) -> bool:
	return CommandoFirearmHitGeometry.net_projectile_passed_target(projectile, target)


func _is_explosive_wall_impact(projectile: Dictionary, profile: Dictionary) -> bool:
	return CommandoFirearmHitGeometry.is_explosive_wall_impact(projectile, profile, FIELD_WIDTH)


func _clamp_explosive_wall_impact(projectile: Dictionary, profile: Dictionary) -> void:
	CommandoFirearmHitGeometry.clamp_explosive_wall_impact(projectile, profile, FIELD_WIDTH)


func _explosive_wall_impact_hits_boss(projectile: Dictionary, profile: Dictionary, boss_rect: Rect2) -> bool:
	return CommandoFirearmHitGeometry.explosive_wall_impact_hits_boss(projectile, profile, boss_rect, FIELD_WIDTH)


func _get_projectile_hitbox_rect(projectile: Dictionary, profile: Dictionary) -> Rect2:
	return CommandoFirearmHitGeometry.get_projectile_hitbox_rect(projectile, profile)


func _get_explosion_radius(projectile: Dictionary, profile: Dictionary) -> float:
	return CommandoFirearmHitGeometry.get_explosion_radius(projectile, profile)


func _get_boss_rect(context: Dictionary) -> Rect2:
	return CommandoFirearmHitGeometry.get_boss_rect(context, FIELD_WIDTH)


func _expand_rect(rect: Rect2, amount: Vector2) -> Rect2:
	return CommandoFirearmHitGeometry.expand_rect(rect, amount)


func _circle_intersects_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	return CommandoFirearmHitGeometry.circle_intersects_rect(center, radius, rect)


func _circle_contains_rect_center(center: Vector2, radius: float, rect: Rect2) -> bool:
	return CommandoFirearmHitGeometry.circle_contains_rect_center(center, radius, rect)


func _segment_intersects_rect(from_pos: Vector2, to_pos: Vector2, rect: Rect2) -> bool:
	return CommandoFirearmHitGeometry.segment_intersects_rect(from_pos, to_pos, rect)


func _spawn_impact_flash(projectile: Dictionary) -> void:
	var weapon_id: String = _get_projectile_weapon_id(projectile)
	_append_limited(impact_flashes, _build_impact_flash(projectile, _get_weapon_profile(weapon_id)), FLASH_LIMIT)


func _build_impact_flash(projectile: Dictionary, profile: Dictionary) -> Dictionary:
	return CommandoFirearmImpactFlashResolver.build_flash(
		projectile,
		profile,
		float(ActiveItemThrowController.GRENADE_EXPLOSION_DURATION_FRAMES)
	)


func _register_projectile_hit(projectile: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var weapon_id: String = _get_projectile_weapon_id(projectile)
	var pos: Vector2 = _get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var velocity: Vector2 = _get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	var feedback_profile: Dictionary = _get_hit_feedback_profile(weapon_id)
	var intensity: float = float(feedback_profile.get("intensity", 0.5))
	var color: Color = _get_color(projectile.get("color", Color.WHITE), Color.WHITE)
	var combat_result: Dictionary = _apply_weapon_hit_result(weapon_id, projectile, context, deps)
	_queue_boss_damage(combat_result)
	_queue_special_gauge_gain(combat_result)
	var lingering_result: Dictionary = _spawn_lingering_effect(weapon_id, projectile, context)
	if not lingering_result.is_empty():
		combat_result["lingering_effect"] = lingering_result
	var hit_event := {
		"id": int(projectile.get("id", 0)),
		"weapon_id": weapon_id,
		"kind": _get_projectile_kind(projectile, "bullet"),
		"target": "boss",
		"pos": pos,
		"velocity": velocity,
		"intensity": intensity,
		"result": combat_result,
	}
	_append_limited(hit_events, hit_event, HIT_EVENT_LIMIT)
	_spawn_shared_impact_particles(pos, color, velocity, intensity, deps)
	_trigger_hit_feedback(feedback_profile, deps)
	_trigger_boss_hit_animation(context, deps)
	_register_ball_hit_pulse(pos, velocity, intensity, weapon_id, deps)
	_play_impact_audio(weapon_id, deps)


func _register_projectile_environment_impact(projectile: Dictionary, reason: String, _context: Dictionary, deps: Dictionary) -> Dictionary:
	var weapon_id: String = _get_projectile_weapon_id(projectile)
	var pos: Vector2 = _get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var velocity: Vector2 = _get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	var feedback_profile: Dictionary = _get_hit_feedback_profile(weapon_id)
	var intensity: float = float(feedback_profile.get("intensity", 0.5))
	var color: Color = _get_color(projectile.get("color", Color.WHITE), Color.WHITE)
	_spawn_shared_impact_particles(pos, color, velocity, intensity, deps)
	_trigger_hit_feedback(feedback_profile, deps)
	_play_impact_audio(weapon_id, deps)
	return {
		"commando_firearm_environment_impact": true,
		"commando_firearm_environment_impact_reason": reason,
		"commando_firearm_environment_impact_weapon_id": weapon_id,
		"commando_firearm_environment_impact_pos": pos,
	}


func _apply_weapon_hit_result(weapon_id: String, projectile: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	var profile: Dictionary = _get_hit_result_profile(weapon_id)
	if profile.is_empty():
		return {}
	var status_effect_state: Object = deps.get("status_effect_state", null)
	var source: String = "commando_firearm_%s" % weapon_id
	var pos: Vector2 = _get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var velocity: Vector2 = _get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	var result: Dictionary = CommandoFirearmHitResultState.build_base_result(source, int(profile.get("damage_units", 0)))
	_apply_slingshot_hit_effects(weapon_id, projectile, result)
	_apply_pistol_hit_effects(weapon_id, projectile, context, result)
	_apply_ak47_accumulated_boss_damage(weapon_id, result)
	var stun_frames: float = float(profile.get("stun_frames", 0.0))
	if result.has("stun_frames"):
		stun_frames = float(result.get("stun_frames", stun_frames))
	if stun_frames > 0.0:
		var knockback_profile: Dictionary = _get_result_hit_profile(profile, result)
		var knockback_vel: float = _get_hit_knockback_velocity(knockback_profile, pos, velocity, context)
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
		var knockback_only_profile: Dictionary = _get_result_hit_profile(profile, result)
		var knockback_only_vel: float = _get_hit_knockback_velocity(knockback_only_profile, pos, velocity, context)
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


func _apply_slingshot_hit_effects(weapon_id: String, projectile: Dictionary, result: Dictionary) -> void:
	if weapon_id != BASE_WEAPON_ID or not bool(projectile.get("slingshot", false)):
		return
	var charge_level: int = clampi(int(projectile.get("charge_level", 1)), 1, 3)
	var stun_mult: float = float(SLINGSHOT_STUN_MULT.get(charge_level, 1.0))
	var knockback_mult: float = float(SLINGSHOT_KNOCKBACK_MULT.get(charge_level, 1.0))
	result["slingshot_charge_level"] = charge_level
	result["commando_firearm_slingshot_charge_level"] = charge_level
	result["stun_frames"] = round(18.0 * stun_mult)
	result["stun_source"] = "commando_firearm_slingshot_charge_%d" % charge_level
	result["knockback_power"] = 14.0 * knockback_mult
	result["commando_firearm_special_gauge_source"] = "commando_firearm_slingshot_charge_%d" % charge_level


func _apply_pistol_hit_effects(weapon_id: String, projectile: Dictionary, context: Dictionary, result: Dictionary) -> void:
	if not _is_pistol_weapon(weapon_id):
		return
	var shot_roll: float = _get_pistol_shot_roll(projectile, context)
	var doping_multiplier: float = _get_pistol_hit_doping_multiplier(projectile, context)
	var hit_chances: Dictionary = _get_pistol_hit_chances(context, doping_multiplier)
	var head_chance: float = float(hit_chances.get("head_chance", 0.0))
	var leg_chance: float = float(hit_chances.get("leg_chance", 0.0))

	pistol_boss_hit_count += 1
	var damage_units := 0
	var damage_sources := []
	var hit_kind := "normal"
	var gauge_gain := PISTOL_NORMAL_GAUGE_GAIN
	if shot_roll < head_chance:
		hit_kind = "headshot"
		gauge_gain = PISTOL_HEAD_SHOT_GAUGE_GAIN
		result["stun_frames"] = COMMANDO_PISTOL_HEAD_SHOT_STUN_FRAMES if weapon_id == "commando_pistol" else PISTOL_HEAD_SHOT_STUN_FRAMES
		result["stun_source"] = "commando_firearm_pistol_headshot"
		result["knockback_power"] = 0.0
		result["knockback_velocity_scale"] = 0.0
		result["knockback_vel"] = 0.0
		result["knockback_active"] = false
		result["commando_firearm_pistol_feedback_timer_frames"] = PISTOL_HIT_TEXT_TIMER_FRAMES
		_spawn_pistol_hit_feedback(hit_kind, context)
		damage_units += 1
		damage_sources.append("commando_firearm_pistol_headshot")
	elif shot_roll < head_chance + leg_chance:
		hit_kind = "legshot"
		gauge_gain = PISTOL_LEG_SHOT_GAUGE_GAIN
		result["stun_frames"] = 0.0
		result["slow_frames"] = PISTOL_LEG_SHOT_SLOW_FRAMES
		result["slow_multiplier"] = PISTOL_LEG_SHOT_SLOW_MULTIPLIER
		result["slow_source"] = "commando_firearm_pistol_legshot"
		result["knockback_without_stun"] = true
		result["knockback_frames"] = 18.0
		result["commando_firearm_pistol_feedback_timer_frames"] = PISTOL_HIT_TEXT_TIMER_FRAMES
		_spawn_pistol_hit_feedback(hit_kind, context)
	else:
		result["knockback_power"] = PISTOL_BOSS_KNOCKBACK_POWER
		result["knockback_velocity_scale"] = 0.0
		result["knockback_frames"] = PISTOL_BOSS_KNOCKBACK_FRAMES
		result["knockback_decay_per_frame"] = PISTOL_BOSS_KNOCKBACK_DECAY_PER_FRAME

	if pistol_boss_hit_count >= PISTOL_BOSS_DAMAGE_HIT_THRESHOLD:
		pistol_boss_hit_count = 0
		damage_units += 1
		damage_sources.append("commando_firearm_pistol_combo")
		result["pistol_combo_damage_ready"] = true

	result["pistol_boss_hit_count"] = pistol_boss_hit_count
	result["pistol_shot_roll"] = shot_roll
	result["pistol_head_chance"] = head_chance
	result["pistol_leg_chance"] = leg_chance
	result["doping_potion_active"] = doping_multiplier > 1.0
	result["doping_potion_head_leg_multiplier"] = doping_multiplier
	result["pistol_hit_kind"] = hit_kind
	result["commando_firearm_pistol_hit_kind"] = hit_kind
	result["commando_firearm_special_gauge_gain"] = gauge_gain
	result["commando_firearm_special_gauge_source"] = "commando_firearm_pistol_%s" % hit_kind
	if damage_units <= 0:
		return
	result["damage_units"] = max(0, int(result.get("damage_units", 0))) + damage_units
	result["damage_sources"] = damage_sources


func _apply_ak47_accumulated_boss_damage(weapon_id: String, result: Dictionary) -> void:
	if weapon_id != "ak47":
		return
	ak47_boss_hit_count += 1
	if ak47_boss_hit_count < AK47_BOSS_DAMAGE_HIT_THRESHOLD:
		result["ak47_boss_hit_count"] = ak47_boss_hit_count
		return
	ak47_boss_hit_count = 0
	result["ak47_boss_hit_count"] = 0
	result["ak47_accumulated_damage_ready"] = true
	result["damage_units"] = max(1, int(result.get("damage_units", 0)))


func _is_pistol_weapon(weapon_id: String) -> bool:
	return CommandoFirearmValueUtils.is_pistol_weapon(weapon_id, BASE_WEAPON_ID)


func _get_pistol_hit_doping_multiplier(projectile: Dictionary, context: Dictionary) -> float:
	return CommandoFirearmValueUtils.get_pistol_hit_doping_multiplier(
		projectile,
		context,
		DOPING_POTION_HEAD_LEG_MULTIPLIER
	)


func _get_pistol_hit_chances(context: Dictionary, doping_multiplier: float) -> Dictionary:
	return CommandoFirearmValueUtils.get_pistol_hit_chances(
		context,
		doping_multiplier,
		PISTOL_HEAD_SHOT_CHANCE,
		PISTOL_LEG_SHOT_CHANCE
	)


func _get_pistol_shot_roll(projectile: Dictionary, context: Dictionary) -> float:
	return CommandoFirearmValueUtils.get_pistol_shot_roll(projectile, context)


func _queue_boss_damage(combat_result: Dictionary) -> void:
	var next_state: Dictionary = CommandoFirearmPendingResultState.queue_boss_damage_state(
		pending_boss_damage_units,
		pending_boss_damage_sources,
		combat_result
	)
	pending_boss_damage_units = int(next_state.get("units", pending_boss_damage_units))
	pending_boss_damage_sources = _get_array(next_state.get("sources", pending_boss_damage_sources))


func _queue_special_gauge_gain(combat_result: Dictionary) -> void:
	var next_state: Dictionary = CommandoFirearmPendingResultState.queue_special_gauge_state(
		pending_special_gauge_gain,
		pending_special_gauge_sources,
		pending_special_gauge_hit_kind,
		pending_pistol_feedback_timer_frames,
		combat_result
	)
	pending_special_gauge_gain = float(next_state.get("gain", pending_special_gauge_gain))
	pending_special_gauge_sources = _get_array(next_state.get("sources", pending_special_gauge_sources))
	pending_special_gauge_hit_kind = str(next_state.get("hit_kind", pending_special_gauge_hit_kind))
	pending_pistol_feedback_timer_frames = float(next_state.get("feedback_timer_frames", pending_pistol_feedback_timer_frames))


func _consume_pending_boss_damage_result() -> Dictionary:
	var result: Dictionary = CommandoFirearmPendingResultState.build_boss_damage_result(
		pending_boss_damage_units,
		pending_boss_damage_sources
	)
	if result.is_empty():
		return {}
	pending_boss_damage_units = 0
	pending_boss_damage_sources.clear()
	return result


func _consume_pending_special_gauge_result() -> Dictionary:
	var result: Dictionary = CommandoFirearmPendingResultState.build_special_gauge_result(
		pending_special_gauge_gain,
		pending_special_gauge_sources,
		pending_special_gauge_hit_kind,
		pending_pistol_feedback_timer_frames
	)
	if result.is_empty():
		return {}
	pending_special_gauge_gain = 0.0
	pending_special_gauge_sources.clear()
	pending_special_gauge_hit_kind = ""
	pending_pistol_feedback_timer_frames = 0.0
	return result


func _spawn_lingering_effect(weapon_id: String, projectile: Dictionary, context: Dictionary) -> Dictionary:
	var profile: Dictionary = _get_lingering_effect_profile(weapon_id)
	if profile.is_empty():
		return {}
	var is_net: bool = weapon_id == "net_gun"
	var dissolve: bool = bool(projectile.get("net_dissolve", false))
	var duration: float = _get_lingering_effect_duration(profile, is_net, dissolve)
	var pos: Vector2 = _get_lingering_effect_pos(profile, projectile, context)
	var effect_id: int = _get_lingering_effect_id(projectile)
	var effect_size: Vector2 = _get_lingering_effect_size(profile, projectile, context, is_net)
	var effect: Dictionary = _build_lingering_effect(weapon_id, profile, projectile, pos, effect_id, effect_size, duration)
	if is_net:
		_apply_lingering_net_fields(effect, profile, projectile, context, pos, effect_size, effect_id, dissolve)
	_apply_lingering_effect_status_fields(effect, profile, dissolve)
	_seed_lingering_fire_flames(effect)
	_append_limited(lingering_effects, effect, LINGERING_EFFECT_LIMIT)
	return _build_lingering_spawn_result(effect, duration)


func _get_lingering_effect_duration(profile: Dictionary, is_net: bool, dissolve: bool) -> float:
	return CommandoFirearmLingeringEffectState.get_duration(
		profile,
		is_net,
		dissolve,
		NET_GUN_DISSOLVE_FRAMES
	)


func _get_lingering_effect_size(
	profile: Dictionary,
	projectile: Dictionary,
	context: Dictionary,
	is_net: bool
) -> Vector2:
	return CommandoFirearmLingeringEffectState.get_size(
		profile,
		projectile,
		is_net,
		NET_GUN_WIDTH,
		_get_net_effect_height(profile, context)
	)


func _get_lingering_effect_id(projectile: Dictionary) -> int:
	var effect_id: int = int(projectile.get("id", 0))
	if effect_id == 0:
		return _next_shot_id()
	return effect_id


func _build_lingering_effect(
	weapon_id: String,
	profile: Dictionary,
	projectile: Dictionary,
	pos: Vector2,
	effect_id: int,
	effect_size: Vector2,
	duration: float
) -> Dictionary:
	return CommandoFirearmLingeringEffectState.build_effect(
		weapon_id,
		profile,
		projectile,
		pos,
		effect_id,
		effect_size,
		duration
	)


func _build_lingering_spawn_result(effect: Dictionary, duration: float) -> Dictionary:
	return CommandoFirearmLingeringEffectState.build_spawn_result(effect, duration)


func _apply_lingering_effect_status_fields(effect: Dictionary, profile: Dictionary, dissolve: bool) -> void:
	CommandoFirearmLingeringStatusState.apply_effect_status_fields(
		effect,
		profile,
		dissolve,
		LINGERING_STATUS_DEFAULT_DURATION_FRAMES,
		LINGERING_STATUS_DEFAULT_INTERVAL_FRAMES,
		LINGERING_STATUS_INITIAL_COOLDOWN_FRAMES,
		LINGERING_STATUS_DEFAULT_SLOW_MULTIPLIER
	)


func _apply_lingering_status_profile_base_fields(effect: Dictionary, profile: Dictionary, status_id: String) -> void:
	CommandoFirearmLingeringStatusState.apply_profile_base_fields(
		effect,
		profile,
		status_id,
		LINGERING_STATUS_DEFAULT_DURATION_FRAMES,
		LINGERING_STATUS_DEFAULT_INTERVAL_FRAMES,
		LINGERING_STATUS_INITIAL_COOLDOWN_FRAMES
	)


func _apply_lingering_status_profile_slow_multiplier(effect: Dictionary, profile: Dictionary) -> void:
	CommandoFirearmLingeringStatusState.apply_profile_slow_multiplier(
		effect,
		profile,
		LINGERING_STATUS_DEFAULT_SLOW_MULTIPLIER
	)


func _get_lingering_status_profile_id(profile: Dictionary) -> String:
	return CommandoFirearmLingeringStatusState.get_profile_id(profile)


func _get_lingering_status_profile_duration(profile: Dictionary) -> float:
	return CommandoFirearmLingeringStatusState.get_profile_duration(
		profile,
		LINGERING_STATUS_DEFAULT_DURATION_FRAMES
	)


func _get_lingering_status_profile_interval(profile: Dictionary) -> float:
	return CommandoFirearmLingeringStatusState.get_profile_interval(
		profile,
		LINGERING_STATUS_DEFAULT_INTERVAL_FRAMES
	)


func _get_lingering_status_initial_cooldown() -> float:
	return CommandoFirearmLingeringStatusState.get_initial_cooldown(LINGERING_STATUS_INITIAL_COOLDOWN_FRAMES)


func _has_lingering_status_profile_slow_multiplier(profile: Dictionary) -> bool:
	return CommandoFirearmLingeringStatusState.has_profile_slow_multiplier(profile)


func _get_lingering_status_profile_slow_multiplier(profile: Dictionary) -> float:
	return CommandoFirearmLingeringStatusState.get_profile_slow_multiplier(
		profile,
		LINGERING_STATUS_DEFAULT_SLOW_MULTIPLIER
	)


func _should_apply_lingering_effect_status_fields(status_id: String, dissolve: bool) -> bool:
	return CommandoFirearmLingeringStatusState.should_apply_effect_status_fields(status_id, dissolve)


func _apply_lingering_net_fields(
	effect: Dictionary,
	profile: Dictionary,
	projectile: Dictionary,
	context: Dictionary,
	pos: Vector2,
	effect_size: Vector2,
	effect_id: int,
	dissolve: bool
) -> void:
	CommandoFirearmLingeringNetFieldState.apply_net_fields(
		effect,
		profile,
		projectile,
		_get_net_gun_aim_origin(context),
		pos,
		effect_size,
		effect_id,
		dissolve,
		NET_GUN_DASH_BREAK_FRAMES,
		NET_GUN_PLAYER_SLOW_MULTIPLIER
	)


func _apply_lingering_net_lifecycle_fields(effect: Dictionary, dissolve: bool) -> void:
	CommandoFirearmLingeringNetFieldState.apply_lifecycle_fields(effect, dissolve)


func _get_lingering_net_rope_snap_duration(profile: Dictionary) -> float:
	return CommandoFirearmLingeringNetFieldState.get_rope_snap_duration(profile, NET_GUN_DASH_BREAK_FRAMES)


func _get_lingering_net_origin(projectile: Dictionary, context: Dictionary) -> Variant:
	return CommandoFirearmLingeringNetFieldState.get_origin(projectile, _get_net_gun_aim_origin(context))


func _get_lingering_net_player_slow_multiplier(profile: Dictionary) -> float:
	return CommandoFirearmLingeringNetFieldState.get_player_slow_multiplier(profile, NET_GUN_PLAYER_SLOW_MULTIPLIER)


func _apply_lingering_net_profile_fields(
	effect: Dictionary,
	profile: Dictionary,
	projectile: Dictionary,
	context: Dictionary
) -> void:
	CommandoFirearmLingeringNetFieldState.apply_profile_fields(
		effect,
		profile,
		projectile,
		_get_net_gun_aim_origin(context),
		NET_GUN_DASH_BREAK_FRAMES,
		NET_GUN_PLAYER_SLOW_MULTIPLIER
	)


func _apply_lingering_net_geometry_fields(effect: Dictionary, pos: Vector2, effect_size: Vector2, effect_id: int) -> void:
	CommandoFirearmLingeringNetFieldState.apply_geometry_fields(effect, pos, effect_size, effect_id)


func _get_lingering_net_deploy_x(pos: Vector2) -> float:
	return CommandoFirearmLingeringNetFieldState.get_deploy_x(pos)


func _get_lingering_net_rect(pos: Vector2, effect_size: Vector2) -> Rect2:
	return CommandoFirearmLingeringNetFieldState.get_net_rect(pos, effect_size)


func _get_lingering_net_initial_constrict_factor() -> float:
	return CommandoFirearmLingeringNetFieldState.get_initial_constrict_factor()


func _build_lingering_net_shape(effect_size: Vector2, effect_id: int) -> Array:
	return CommandoFirearmLingeringNetFieldState.build_net_shape(effect_size, effect_id)


func _seed_lingering_fire_flames(effect: Dictionary) -> void:
	if not _is_lingering_fire_zone(effect):
		return
	effect["flames"] = _build_lingering_fire_flames(effect)


func _spawn_net_dissolve_effect(projectile: Dictionary, context: Dictionary) -> Dictionary:
	var net_projectile: Dictionary = projectile.duplicate(true)
	net_projectile["net_dissolve"] = true
	return _spawn_lingering_effect("net_gun", net_projectile, context)


func _generate_net_shape(width: float, height: float, seed_value: int) -> Array:
	return CommandoFirearmLingeringNetFieldState.generate_net_shape(width, height, seed_value)


func _get_net_shape_seed_phase(seed_value: int) -> float:
	return CommandoFirearmLingeringNetFieldState.get_net_shape_seed_phase(seed_value)


func _get_net_shape_scale(angle: float, seed_phase: float) -> float:
	return CommandoFirearmLingeringNetFieldState.get_net_shape_scale(angle, seed_phase)


func _get_net_shape_point(width: float, height: float, point_index: int, point_count: int, seed_phase: float) -> Vector2:
	return CommandoFirearmLingeringNetFieldState.get_net_shape_point(width, height, point_index, point_count, seed_phase)


func _get_lingering_effect_pos(profile: Dictionary, projectile: Dictionary, context: Dictionary) -> Vector2:
	var pos: Vector2 = _get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	return CommandoFirearmLingeringNetFieldState.get_lingering_effect_pos(
		profile,
		projectile,
		context,
		pos,
		_get_boss_target_pos(context),
		FIELD_WIDTH,
		FIELD_HEIGHT,
		NET_GUN_WIDTH,
		NET_GUN_MIN_HEIGHT,
		NET_GUN_HEIGHT
	)


func _get_net_lingering_effect_pos(
	profile: Dictionary,
	projectile: Dictionary,
	context: Dictionary,
	pos: Vector2
) -> Vector2:
	return CommandoFirearmLingeringNetFieldState.get_net_lingering_effect_pos(
		profile,
		projectile,
		context,
		pos,
		_get_boss_target_pos(context),
		FIELD_WIDTH,
		FIELD_HEIGHT,
		NET_GUN_WIDTH,
		NET_GUN_MIN_HEIGHT,
		NET_GUN_HEIGHT
	)


func _get_default_lingering_effect_pos(profile: Dictionary, pos: Vector2) -> Vector2:
	return CommandoFirearmLingeringNetFieldState.get_default_lingering_effect_pos(profile, pos, FIELD_WIDTH, FIELD_HEIGHT)


func _get_net_effect_height(profile: Dictionary, context: Dictionary) -> float:
	return CommandoFirearmLingeringNetFieldState.get_net_effect_height(
		profile,
		context,
		NET_GUN_MIN_HEIGHT,
		NET_GUN_HEIGHT
	)


func _get_net_effect_desired_height(context: Dictionary) -> float:
	return CommandoFirearmLingeringNetFieldState.get_net_effect_desired_height(context)


func _get_net_effect_height_limits(profile: Dictionary) -> Vector2:
	return CommandoFirearmLingeringNetFieldState.get_net_effect_height_limits(
		profile,
		NET_GUN_MIN_HEIGHT,
		NET_GUN_HEIGHT
	)


func _build_lingering_fire_flames(effect: Dictionary) -> Array:
	return CommandoFirearmLingeringFireFlameState.build_flames(effect)


func _get_lingering_fire_flame_count() -> int:
	return CommandoFirearmLingeringFireFlameState.get_flame_count()


func _get_lingering_fire_effect_size(effect: Dictionary) -> Vector2:
	return CommandoFirearmLingeringFireFlameState.get_effect_size(effect)


func _get_lingering_fire_effect_width(effect: Dictionary) -> float:
	return CommandoFirearmLingeringFireFlameState.get_effect_width(effect)


func _get_lingering_fire_effect_height(effect: Dictionary) -> float:
	return CommandoFirearmLingeringFireFlameState.get_effect_height(effect)


func _get_lingering_fire_effect_dimension(effect: Dictionary, dimension_key: String, default_value: float) -> float:
	return CommandoFirearmLingeringFireFlameState.get_effect_dimension(effect, dimension_key, default_value)


func _build_lingering_fire_flame(flame_index: int, width: float, height: float) -> Dictionary:
	return CommandoFirearmLingeringFireFlameState.build_flame(flame_index, width, height)


func _get_lingering_fire_flame_angle(flame_index: int) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_angle(flame_index)


func _get_lingering_fire_flame_cycle_angle(angle_index: int) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_cycle_angle(angle_index)


func _get_lingering_fire_flame_ring(flame_index: int) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_ring(flame_index)


func _get_lingering_fire_flame_ring_factor(flame_index: int) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_ring_factor(flame_index)


func _get_lingering_fire_flame_ring_pattern_value(flame_index: int) -> int:
	return CommandoFirearmLingeringFireFlameState.get_flame_ring_pattern_value(flame_index)


func _get_lingering_fire_flame_pattern_value(flame_index: int, pattern_step: int, pattern_modulo: int) -> int:
	return CommandoFirearmLingeringFireFlameState.get_flame_pattern_value(flame_index, pattern_step, pattern_modulo)


func _get_lingering_fire_flame_offset(flame_index: int, width: float, height: float, angle: float) -> Vector2:
	return CommandoFirearmLingeringFireFlameState.get_flame_offset(flame_index, width, height, angle)


func _get_lingering_fire_flame_spawn_radius(width: float, height: float, ring: float) -> Vector2:
	return CommandoFirearmLingeringFireFlameState.get_flame_spawn_radius(width, height, ring)


func _get_lingering_fire_flame_spawn_radius_x(width: float, ring: float) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_spawn_radius_x(width, ring)


func _get_lingering_fire_flame_spawn_radius_y(height: float, ring: float) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_spawn_radius_y(height, ring)


func _get_lingering_fire_flame_offset_from_radius(angle: float, radius: Vector2) -> Vector2:
	return CommandoFirearmLingeringFireFlameState.get_flame_offset_from_radius(angle, radius)


func _get_lingering_fire_flame_size(flame_index: int) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_size(flame_index)


func _get_lingering_fire_flame_size_offset(flame_index: int) -> int:
	return CommandoFirearmLingeringFireFlameState.get_flame_size_offset(flame_index)


func _get_lingering_fire_flame_size_pattern_value(flame_index: int) -> int:
	return CommandoFirearmLingeringFireFlameState.get_flame_size_pattern_value(flame_index)


func _get_lingering_fire_flame_lifetime(flame_index: int) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_lifetime(flame_index)


func _get_lingering_fire_flame_lifetime_offset(flame_index: int) -> int:
	return CommandoFirearmLingeringFireFlameState.get_flame_lifetime_offset(flame_index)


func _get_lingering_fire_flame_lifetime_pattern_value(flame_index: int) -> int:
	return CommandoFirearmLingeringFireFlameState.get_flame_lifetime_pattern_value(flame_index)


func _get_lingering_fire_flame_phase(flame_index: int) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_phase(flame_index)


func _get_lingering_fire_flame_phase_spacing() -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_phase_spacing()


func _get_lingering_fire_flame_max_lifetime() -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_max_lifetime()


func _update_lingering_effects(fps_scale: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	var step: float = _get_lingering_effect_timer_step(fps_scale)
	var result: Dictionary = {}
	if _consume_net_gun_dash_trigger(context, deps):
		_break_hooked_net_fields()
	for index in range(lingering_effects.size() - 1, -1, -1):
		var effect: Dictionary = _get_lingering_effect_at_index(index)
		_advance_lingering_effect_frame(effect, step)
		if _is_lingering_effect_active(effect):
			_apply_active_lingering_effect(index, effect, step, context, deps, result)
		else:
			_remove_lingering_effect_at_index(index)
	return result


func _consume_net_gun_dash_trigger(context: Dictionary, deps: Dictionary = {}) -> bool:
	var dash_active: bool = _is_player_dash_active(context, deps)
	var dash_triggered: bool = dash_active and not net_gun_last_dash_active
	net_gun_last_dash_active = dash_active
	return dash_triggered


func _advance_lingering_effect_frame(effect: Dictionary, fps_scale: float) -> void:
	var step: float = _get_lingering_effect_timer_step(fps_scale)
	_advance_lingering_effect_timers(effect, step)
	if _is_lingering_fire_zone(effect):
		_update_lingering_fire_flames(effect, step)


func _advance_lingering_effect_timers(effect: Dictionary, fps_scale: float) -> void:
	CommandoFirearmLingeringEffectState.advance_timers(effect, fps_scale, LINGERING_EFFECT_PHASE_STEP)


func _get_lingering_effect_timer_step(fps_scale: float) -> float:
	return CommandoFirearmLingeringEffectState.get_timer_step(fps_scale)


func _get_next_lingering_effect_timer(effect: Dictionary, step: float) -> float:
	return CommandoFirearmLingeringEffectState.get_next_timer(effect, step)


func _get_next_lingering_effect_phase(effect: Dictionary, step: float) -> float:
	return CommandoFirearmLingeringEffectState.get_next_phase(effect, step, LINGERING_EFFECT_PHASE_STEP)


func _get_lingering_effect_timer(effect: Dictionary) -> float:
	return CommandoFirearmLingeringEffectState.get_timer(effect)


func _get_lingering_effect_phase(effect: Dictionary) -> float:
	return CommandoFirearmLingeringEffectState.get_phase(effect)


func _get_lingering_effect_phase_step(step: float) -> float:
	return CommandoFirearmLingeringEffectState.get_phase_step(step, LINGERING_EFFECT_PHASE_STEP)


func _should_advance_lingering_rope_snap_timer(effect: Dictionary) -> bool:
	return CommandoFirearmLingeringEffectState.should_advance_rope_snap_timer(effect)


func _get_next_lingering_rope_snap_timer(effect: Dictionary, step: float) -> float:
	return CommandoFirearmLingeringEffectState.get_next_rope_snap_timer(effect, step)


func _get_lingering_rope_snap_timer(effect: Dictionary) -> float:
	return CommandoFirearmLingeringEffectState.get_rope_snap_timer(effect)


func _is_lingering_fire_zone(effect: Dictionary) -> bool:
	return CommandoFirearmLingeringEffectState.is_fire_zone(effect)


func _is_lingering_effect_active(effect: Dictionary) -> bool:
	return CommandoFirearmLingeringEffectState.is_active(effect)


func _has_lingering_effect_timer(timer_frames: float) -> bool:
	return CommandoFirearmLingeringEffectState.has_timer(timer_frames)


func _merge_lingering_clamp_result(result: Dictionary, context: Dictionary, clamp_result: Dictionary) -> void:
	CommandoFirearmLingeringEffectState.merge_clamp_result(result, context, clamp_result)


func _has_lingering_clamp_result(clamp_result: Dictionary) -> bool:
	return CommandoFirearmLingeringEffectState.has_clamp_result(clamp_result)


func _apply_lingering_clamp_payload(target: Dictionary, clamp_result: Dictionary) -> void:
	CommandoFirearmLingeringEffectState.apply_clamp_payload(target, clamp_result)


func _apply_active_lingering_effect(
	index: int,
	effect: Dictionary,
	fps_scale: float,
	context: Dictionary,
	deps: Dictionary,
	result: Dictionary
) -> void:
	_apply_lingering_effect_status(effect, context, deps, fps_scale)
	_apply_active_lingering_clamp(effect, context, result)
	_store_lingering_effect_at_index(index, effect)


func _apply_active_lingering_clamp(effect: Dictionary, context: Dictionary, result: Dictionary) -> void:
	var clamp_result: Dictionary = _get_active_lingering_clamp_result(effect, context)
	_merge_lingering_clamp_result(result, context, clamp_result)


func _get_active_lingering_clamp_result(effect: Dictionary, context: Dictionary) -> Dictionary:
	return _apply_net_field_boss_clamp(effect, context)


func _store_lingering_effect_at_index(index: int, effect: Dictionary) -> void:
	lingering_effects[index] = effect


func _get_lingering_effect_at_index(index: int) -> Dictionary:
	return _get_dict(lingering_effects[index])


func _remove_lingering_effect_at_index(index: int) -> void:
	lingering_effects.remove_at(index)


func _break_hooked_net_fields() -> void:
	for index in range(lingering_effects.size()):
		var effect: Dictionary = _get_lingering_effect_at_index(index)
		if not _is_active_hooked_net_field(effect):
			continue
		_mark_hooked_net_field_broken(effect)
		_store_lingering_effect_at_index(index, effect)


func _mark_hooked_net_field_broken(effect: Dictionary) -> void:
	CommandoFirearmLingeringNetFieldState.mark_hooked_field_broken(effect, NET_GUN_DASH_BREAK_FRAMES)


func _update_net_constrict_input(input_snapshot: Dictionary, now_msec: int, deps: Dictionary) -> void:
	# Mirrors pingfighter.py _update_net_constrict: alternating L/R input within
	# a short window narrows hooked nets by NET_CONSTRICT_STEP, floored at NET_CONSTRICT_MIN.
	var active_indices: Array[int] = _get_net_constrict_candidate_indices()
	if active_indices.is_empty():
		return
	var dir_input: int = _get_net_constrict_input_direction(input_snapshot)
	if not _should_record_net_constrict_input(dir_input):
		return
	if _should_apply_net_constrict_input(dir_input, now_msec):
		_apply_net_constrict_to_indices(active_indices)
		_play_net_constrict_audio(deps)
	net_constrict_last_dir = dir_input
	net_constrict_last_tick_msec = now_msec


func _apply_net_field_boss_clamp(effect: Dictionary, context: Dictionary) -> Dictionary:
	return CommandoFirearmLingeringNetFieldState.apply_net_field_boss_clamp(
		effect,
		context,
		NET_GUN_WIDTH,
		NET_GUN_MIN_HEIGHT
	)


func _is_player_dash_active(context: Dictionary, deps: Dictionary = {}) -> bool:
	var dash_snapshot: Variant = context.get("dash_snapshot", {})
	if dash_snapshot is Dictionary:
		return bool((dash_snapshot as Dictionary).get("active", false))
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state != null and dash_state.has_method("get_snapshot"):
		var snapshot: Variant = dash_state.get_snapshot()
		if snapshot is Dictionary:
			return bool((snapshot as Dictionary).get("active", false))
	return false


func _has_hooked_net_field() -> bool:
	for value in lingering_effects:
		var effect: Dictionary = _get_dict(value)
		if _is_active_hooked_net_field(effect):
			return true
	return false


func _is_net_gun_effect(effect: Dictionary) -> bool:
	return CommandoFirearmLingeringNetFieldState.is_net_gun_effect(effect)


func _is_active_hooked_net_field(effect: Dictionary) -> bool:
	return CommandoFirearmLingeringNetFieldState.is_active_hooked_net_field(effect)


func _is_boss_clamping_net_field(effect: Dictionary) -> bool:
	return CommandoFirearmLingeringNetFieldState.is_boss_clamping_net_field(effect)


func _is_net_constrict_candidate(effect: Dictionary) -> bool:
	return CommandoFirearmLingeringNetFieldState.is_net_constrict_candidate(effect, NET_CONSTRICT_MIN)


func _get_net_constrict_candidate_indices() -> Array[int]:
	var active_indices: Array[int] = []
	for index in range(lingering_effects.size()):
		var effect: Dictionary = _get_lingering_effect_at_index(index)
		if _is_net_constrict_candidate(effect):
			active_indices.append(index)
	return active_indices


func _get_net_constrict_input_direction(input_snapshot: Dictionary) -> int:
	return CommandoFirearmLingeringNetFieldState.get_net_constrict_input_direction(input_snapshot)


func _should_record_net_constrict_input(dir_input: int) -> bool:
	return CommandoFirearmLingeringNetFieldState.should_record_net_constrict_input(dir_input, net_constrict_last_dir)


func _should_apply_net_constrict_input(dir_input: int, now_msec: int) -> bool:
	return CommandoFirearmLingeringNetFieldState.should_apply_net_constrict_input(
		dir_input,
		now_msec,
		net_constrict_last_dir,
		net_constrict_last_tick_msec,
		NET_CONSTRICT_WINDOW_MSEC
	)


func _get_next_net_constrict_factor(effect: Dictionary) -> float:
	return CommandoFirearmLingeringNetFieldState.get_next_net_constrict_factor(
		effect,
		NET_CONSTRICT_MIN,
		NET_CONSTRICT_STEP
	)


func _get_net_constrict_factor(effect: Dictionary) -> float:
	return CommandoFirearmLingeringNetFieldState.get_net_constrict_factor(
		effect,
		_get_lingering_net_initial_constrict_factor()
	)


func _apply_net_constrict_to_indices(active_indices: Array[int]) -> void:
	for index in active_indices:
		var effect: Dictionary = _get_lingering_effect_at_index(index)
		effect["constrict_factor"] = _get_next_net_constrict_factor(effect)
		_store_lingering_effect_at_index(index, effect)


func _play_net_constrict_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("game_audio", null)
	if audio != null and audio.has_method("play_commando_net_gun_capture"):
		audio.play_commando_net_gun_capture()


func _get_net_field_pos(effect: Dictionary) -> Vector2:
	return CommandoFirearmLingeringNetFieldState.get_net_field_pos(effect)


func _get_net_field_effect_width(effect: Dictionary) -> float:
	return CommandoFirearmLingeringNetFieldState.get_net_field_effect_width(effect, NET_GUN_WIDTH)


func _get_net_field_effect_height(effect: Dictionary) -> float:
	return CommandoFirearmLingeringNetFieldState.get_net_field_effect_height(effect, NET_GUN_MIN_HEIGHT)


func _get_net_field_boss_pos(context: Dictionary) -> Vector2:
	return CommandoFirearmLingeringNetFieldState.get_net_field_boss_pos(context)


func _get_net_field_boss_width(context: Dictionary) -> float:
	return CommandoFirearmLingeringNetFieldState.get_net_field_boss_width(context)


func _get_net_field_clamp_width(effect: Dictionary, width: float, boss_width: float) -> float:
	return CommandoFirearmLingeringNetFieldState.get_net_field_clamp_width(effect, width, boss_width)


func _get_net_field_min_boss_clamp_width(boss_width: float) -> float:
	return CommandoFirearmLingeringNetFieldState.get_net_field_min_boss_clamp_width(boss_width)


func _get_net_field_constricted_width(width: float, constrict_factor: float) -> float:
	return CommandoFirearmLingeringNetFieldState.get_net_field_constricted_width(width, constrict_factor)


func _get_net_field_clamp_rect(
	effect: Dictionary,
	pos: Vector2,
	width: float,
	height: float,
	boss_width: float
) -> Rect2:
	return CommandoFirearmLingeringNetFieldState.get_net_field_clamp_rect(effect, pos, width, height, boss_width)


func _get_net_field_clamp_size(effect: Dictionary, width: float, height: float, boss_width: float) -> Vector2:
	return CommandoFirearmLingeringNetFieldState.get_net_field_clamp_size(effect, width, height, boss_width)


func _get_net_field_clamp_origin(pos: Vector2, clamp_size: Vector2) -> Vector2:
	return CommandoFirearmLingeringNetFieldState.get_net_field_clamp_origin(pos, clamp_size)


func _get_net_field_clamped_boss_x(boss_x: float, boss_width: float, clamp_rect: Rect2) -> float:
	return CommandoFirearmLingeringNetFieldState.get_net_field_clamped_boss_x(boss_x, boss_width, clamp_rect)


func _get_net_field_safe_boss_width(boss_width: float) -> float:
	return CommandoFirearmLingeringNetFieldState.get_net_field_safe_boss_width(boss_width)


func _get_net_field_boss_clamp_min_x(clamp_rect: Rect2) -> float:
	return CommandoFirearmLingeringNetFieldState.get_net_field_boss_clamp_min_x(clamp_rect)


func _get_net_field_boss_clamp_max_x(boss_width: float, clamp_rect: Rect2) -> float:
	return CommandoFirearmLingeringNetFieldState.get_net_field_boss_clamp_max_x(boss_width, clamp_rect)


func _get_net_field_clamped_boss_pos(boss_pos: Vector2, boss_width: float, clamp_rect: Rect2) -> Vector2:
	return CommandoFirearmLingeringNetFieldState.get_net_field_clamped_boss_pos(boss_pos, boss_width, clamp_rect)


func _should_emit_net_field_boss_clamp_result(boss_pos: Vector2, clamped_pos: Vector2) -> bool:
	return CommandoFirearmLingeringNetFieldState.should_emit_net_field_boss_clamp_result(boss_pos, clamped_pos)


func _build_net_field_boss_clamp_result(boss_pos: Vector2, boss_width: float, clamp_rect: Rect2) -> Dictionary:
	return CommandoFirearmLingeringNetFieldState.build_net_field_boss_clamp_result(boss_pos, boss_width, clamp_rect)


func _update_lingering_fire_flames(effect: Dictionary, fps_scale: float) -> void:
	effect["flames"] = _get_lingering_fire_flames_for_frame(effect, fps_scale)


func _get_lingering_fire_flames_for_frame(effect: Dictionary, fps_scale: float) -> Array:
	return CommandoFirearmLingeringFireFlameState.get_flames_for_frame(effect, fps_scale)


func _get_lingering_fire_flames(effect: Dictionary) -> Array:
	return CommandoFirearmLingeringFireFlameState.get_flames(effect)


func _should_seed_lingering_fire_flames(flames: Array) -> bool:
	return CommandoFirearmLingeringFireFlameState.should_seed_flames(flames)


func _advance_lingering_fire_flames(flames: Array, effect: Dictionary, fps_scale: float) -> Array:
	return CommandoFirearmLingeringFireFlameState.advance_flames(flames, effect, fps_scale)


func _get_lingering_fire_flame_at_index(flames: Array, flame_index: int) -> Dictionary:
	return CommandoFirearmLingeringFireFlameState.get_flame_at_index(flames, flame_index)


func _advance_lingering_fire_flame(
	flame: Dictionary,
	flame_index: int,
	effect: Dictionary,
	fps_scale: float,
	width: float,
	height: float
) -> Dictionary:
	return CommandoFirearmLingeringFireFlameState.advance_flame(flame, flame_index, effect, fps_scale, width, height)


func _apply_lingering_fire_flame_frame_values(flame: Dictionary, lifetime: float, phase: float) -> Dictionary:
	return CommandoFirearmLingeringFireFlameState.apply_flame_frame_values(flame, lifetime, phase)


func _apply_lingering_fire_flame_motion(
	flame: Dictionary,
	flame_index: int,
	effect: Dictionary,
	lifetime: float,
	phase: float,
	fps_scale: float,
	width: float,
	height: float
) -> float:
	return CommandoFirearmLingeringFireFlameState.apply_flame_motion(
		flame,
		flame_index,
		effect,
		lifetime,
		phase,
		fps_scale,
		width,
		height
	)


func _apply_lingering_fire_flame_reset_motion(
	flame: Dictionary,
	flame_index: int,
	effect: Dictionary,
	width: float,
	height: float
) -> float:
	return CommandoFirearmLingeringFireFlameState.apply_flame_reset_motion(flame, flame_index, effect, width, height)


func _apply_lingering_fire_flame_drift_motion(
	flame: Dictionary,
	phase: float,
	fps_scale: float,
	width: float,
	height: float,
	lifetime: float
) -> float:
	return CommandoFirearmLingeringFireFlameState.apply_flame_drift_motion(flame, phase, fps_scale, width, height, lifetime)


func _should_reset_lingering_fire_flame(lifetime: float) -> bool:
	return CommandoFirearmLingeringFireFlameState.should_reset_flame(lifetime)


func _get_lingering_fire_flame_next_lifetime(flame: Dictionary, fps_scale: float) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_next_lifetime(flame, fps_scale)


func _get_lingering_fire_flame_next_phase(flame: Dictionary, fps_scale: float) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_next_phase(flame, fps_scale)


func _get_lingering_fire_flame_current_lifetime(flame: Dictionary) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_current_lifetime(flame)


func _get_lingering_fire_flame_current_phase(flame: Dictionary) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_current_phase(flame)


func _get_lingering_fire_flame_phase_step(fps_scale: float) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_phase_step(fps_scale)


func _reset_lingering_fire_flame(
	flame: Dictionary,
	flame_index: int,
	effect: Dictionary,
	width: float,
	height: float
) -> float:
	return CommandoFirearmLingeringFireFlameState.reset_flame(flame, flame_index, effect, width, height)


func _apply_lingering_fire_flame_reset_values(
	flame: Dictionary,
	flame_index: int,
	effect: Dictionary,
	width: float,
	height: float
) -> void:
	CommandoFirearmLingeringFireFlameState.apply_flame_reset_values(flame, flame_index, effect, width, height)


func _get_lingering_fire_flame_reset_angle(flame_index: int, effect: Dictionary) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_reset_angle(flame_index, effect)


func _get_lingering_fire_flame_reset_angle_index(flame_index: int, effect: Dictionary) -> int:
	return CommandoFirearmLingeringFireFlameState.get_flame_reset_angle_index(flame_index, effect)


func _get_lingering_fire_effect_id(effect: Dictionary) -> int:
	return CommandoFirearmLingeringFireFlameState.get_effect_id(effect)


func _get_lingering_fire_flame_reset_offset(
	flame_index: int,
	effect: Dictionary,
	width: float,
	height: float
) -> Vector2:
	return CommandoFirearmLingeringFireFlameState.get_flame_reset_offset(flame_index, effect, width, height)


func _get_lingering_fire_flame_reset_radius(width: float, height: float) -> Vector2:
	return CommandoFirearmLingeringFireFlameState.get_flame_reset_radius(width, height)


func _get_lingering_fire_flame_reset_radius_x(width: float) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_reset_radius_x(width)


func _get_lingering_fire_flame_reset_radius_y(height: float) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_reset_radius_y(height)


func _get_lingering_fire_flame_reset_size(flame_index: int) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_reset_size(flame_index)


func _get_lingering_fire_flame_reset_size_offset(flame_index: int) -> int:
	return CommandoFirearmLingeringFireFlameState.get_flame_reset_size_offset(flame_index)


func _get_lingering_fire_flame_reset_size_pattern_value(flame_index: int) -> int:
	return CommandoFirearmLingeringFireFlameState.get_flame_reset_size_pattern_value(flame_index)


func _get_lingering_fire_flame_reset_lifetime(flame_index: int) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_reset_lifetime(flame_index)


func _get_lingering_fire_flame_reset_lifetime_offset(flame_index: int) -> int:
	return CommandoFirearmLingeringFireFlameState.get_flame_reset_lifetime_offset(flame_index)


func _get_lingering_fire_flame_reset_lifetime_pattern_value(flame_index: int) -> int:
	return CommandoFirearmLingeringFireFlameState.get_flame_reset_lifetime_pattern_value(flame_index)


func _drift_lingering_fire_flame(flame: Dictionary, phase: float, fps_scale: float, width: float, height: float) -> void:
	CommandoFirearmLingeringFireFlameState.drift_flame(flame, phase, fps_scale, width, height)


func _get_lingering_fire_flame_drift_offset(
	flame: Dictionary,
	phase: float,
	fps_scale: float,
	width: float,
	height: float
) -> Vector2:
	return CommandoFirearmLingeringFireFlameState.get_flame_drift_offset(flame, phase, fps_scale, width, height)


func _get_lingering_fire_flame_current_offset(flame: Dictionary) -> Vector2:
	return CommandoFirearmLingeringFireFlameState.get_flame_current_offset(flame)


func _get_lingering_fire_flame_unclamped_drift_offset(flame: Dictionary, phase: float, fps_scale: float) -> Vector2:
	return CommandoFirearmLingeringFireFlameState.get_flame_unclamped_drift_offset(flame, phase, fps_scale)


func _get_lingering_fire_flame_drift_step(phase: float, fps_scale: float) -> Vector2:
	return CommandoFirearmLingeringFireFlameState.get_flame_drift_step(phase, fps_scale)


func _get_lingering_fire_flame_drift_wave_offset(phase: float, fps_scale: float) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_drift_wave_offset(phase, fps_scale)


func _get_lingering_fire_flame_drift_rise_offset(fps_scale: float) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_drift_rise_offset(fps_scale)


func _clamp_lingering_fire_flame_offset(offset: Vector2, width: float, height: float) -> Vector2:
	return CommandoFirearmLingeringFireFlameState.clamp_flame_offset(offset, width, height)


func _get_lingering_fire_flame_offset_bound(length: float) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_offset_bound(length)


func _get_lingering_fire_flame_drift_size(flame: Dictionary, fps_scale: float) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_drift_size(flame, fps_scale)


func _get_lingering_fire_flame_current_size(flame: Dictionary) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_current_size(flame)


func _get_lingering_fire_flame_unclamped_drift_size(flame: Dictionary, fps_scale: float) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_unclamped_drift_size(flame, fps_scale)


func _get_lingering_fire_flame_size_decay(fps_scale: float) -> float:
	return CommandoFirearmLingeringFireFlameState.get_flame_size_decay(fps_scale)


func _clamp_lingering_fire_flame_drift_size(size: float) -> float:
	return CommandoFirearmLingeringFireFlameState.clamp_flame_drift_size(size)


func _apply_lingering_effect_status(effect: Dictionary, context: Dictionary, deps: Dictionary, fps_scale: float) -> void:
	var status_application: Dictionary = _get_lingering_status_application(effect, deps)
	if not _has_lingering_status_application(status_application):
		return
	if not _can_apply_lingering_status(effect, context, fps_scale):
		return
	_apply_lingering_status_application(effect, status_application)


func _apply_lingering_status_application(effect: Dictionary, status_application: Dictionary) -> void:
	var status_effect_state: Object = _get_lingering_status_application_state(status_application)
	var status_id: String = _get_lingering_status_application_id(status_application)
	if status_effect_state == null or status_id == "":
		return
	_apply_ready_lingering_status(effect, status_effect_state, status_id)


func _get_lingering_status_id(effect: Dictionary) -> String:
	return CommandoFirearmLingeringStatusState.get_status_id(effect)


func _get_lingering_status_effect_state(deps: Dictionary) -> Object:
	return CommandoFirearmLingeringStatusState.get_status_effect_state(deps)


func _get_lingering_status_application(effect: Dictionary, deps: Dictionary) -> Dictionary:
	return CommandoFirearmLingeringStatusState.get_status_application(effect, deps)


func _has_lingering_status_application(status_application: Dictionary) -> bool:
	return CommandoFirearmLingeringStatusState.has_status_application(status_application)


func _get_lingering_status_application_id(status_application: Dictionary) -> String:
	return CommandoFirearmLingeringStatusState.get_status_application_id(status_application)


func _get_lingering_status_application_state(status_application: Dictionary) -> Object:
	return CommandoFirearmLingeringStatusState.get_status_application_state(status_application)


func _is_lingering_status_effect_state(status_effect_state: Object) -> bool:
	return CommandoFirearmLingeringStatusState.is_status_effect_state(status_effect_state)


func _can_apply_lingering_status(effect: Dictionary, context: Dictionary, fps_scale: float) -> bool:
	return CommandoFirearmLingeringStatusState.can_apply_status(
		effect,
		context,
		_get_lingering_effect_timer_step(fps_scale)
	)


func _is_lingering_status_ready_to_apply(cooldown: float, effect: Dictionary, context: Dictionary) -> bool:
	return CommandoFirearmLingeringStatusState.is_status_ready_to_apply(cooldown, effect, context)


func _apply_ready_lingering_status(effect: Dictionary, status_effect_state: Object, status_id: String) -> void:
	var data: Dictionary = _build_lingering_status_data(effect, status_id)
	_apply_lingering_status_to_boss(status_effect_state, effect, status_id, data)
	_reset_lingering_status_cooldown(effect)


func _apply_lingering_status_to_boss(
	status_effect_state: Object,
	effect: Dictionary,
	status_id: String,
	data: Dictionary
) -> void:
	status_effect_state.apply_status(
		_get_lingering_status_target(),
		status_id,
		_get_lingering_status_duration(effect),
		data,
		_get_lingering_status_source(effect)
	)


func _get_lingering_status_target() -> String:
	return CommandoFirearmLingeringStatusState.get_status_target(LINGERING_STATUS_TARGET)


func _get_lingering_status_duration(effect: Dictionary) -> float:
	return CommandoFirearmLingeringStatusState.get_status_duration(
		effect,
		LINGERING_STATUS_DEFAULT_DURATION_FRAMES
	)


func _get_lingering_status_source(effect: Dictionary) -> String:
	return CommandoFirearmLingeringStatusState.get_status_source(effect, LINGERING_STATUS_DEFAULT_SOURCE)


func _build_lingering_status_data(effect: Dictionary, status_id: String) -> Dictionary:
	return CommandoFirearmLingeringStatusState.build_status_data(
		effect,
		status_id,
		LINGERING_STATUS_ID_SLOW,
		LINGERING_STATUS_DEFAULT_SLOW_MULTIPLIER,
		LINGERING_STATUS_MIN_SLOW_MULTIPLIER,
		LINGERING_STATUS_MAX_SLOW_MULTIPLIER
	)


func _should_include_lingering_status_slow_multiplier(status_id: String) -> bool:
	return CommandoFirearmLingeringStatusState.should_include_status_slow_multiplier(
		status_id,
		LINGERING_STATUS_ID_SLOW
	)


func _get_lingering_status_data_source(effect: Dictionary) -> String:
	return CommandoFirearmLingeringStatusState.get_status_data_source(effect)


func _get_lingering_status_slow_multiplier(effect: Dictionary) -> float:
	return CommandoFirearmLingeringStatusState.get_status_slow_multiplier(
		effect,
		LINGERING_STATUS_DEFAULT_SLOW_MULTIPLIER,
		LINGERING_STATUS_MIN_SLOW_MULTIPLIER,
		LINGERING_STATUS_MAX_SLOW_MULTIPLIER
	)


func _reset_lingering_status_cooldown(effect: Dictionary) -> float:
	return CommandoFirearmLingeringStatusState.reset_status_cooldown(
		effect,
		LINGERING_STATUS_DEFAULT_INTERVAL_FRAMES
	)


func _get_lingering_status_interval(effect: Dictionary) -> float:
	return CommandoFirearmLingeringStatusState.get_status_interval(
		effect,
		LINGERING_STATUS_DEFAULT_INTERVAL_FRAMES
	)


func _advance_lingering_status_cooldown(effect: Dictionary, fps_scale: float) -> float:
	return CommandoFirearmLingeringStatusState.advance_status_cooldown(
		effect,
		_get_lingering_effect_timer_step(fps_scale)
	)


func _set_lingering_status_cooldown(effect: Dictionary, cooldown: float) -> float:
	return CommandoFirearmLingeringStatusState.set_status_cooldown(effect, cooldown)


func _get_lingering_status_cooldown(effect: Dictionary) -> float:
	return CommandoFirearmLingeringStatusState.get_status_cooldown(effect)


func _get_next_lingering_status_cooldown(effect: Dictionary, fps_scale: float) -> float:
	return CommandoFirearmLingeringStatusState.get_next_status_cooldown(
		effect,
		_get_lingering_effect_timer_step(fps_scale)
	)


func _is_lingering_status_cooldown_ready(cooldown: float) -> bool:
	return CommandoFirearmLingeringStatusState.is_status_cooldown_ready(cooldown)


func _lingering_effect_hits_boss(effect: Dictionary, context: Dictionary) -> bool:
	return CommandoFirearmLingeringStatusState.lingering_effect_hits_boss(effect, context)


func _do_lingering_rects_intersect(effect_rect: Rect2, boss_rect: Rect2) -> bool:
	return CommandoFirearmLingeringStatusState.do_lingering_rects_intersect(effect_rect, boss_rect)


func _get_lingering_effect_rect(effect: Dictionary) -> Rect2:
	return CommandoFirearmLingeringStatusState.get_lingering_effect_rect(effect)


func _get_lingering_effect_rect_pos(effect: Dictionary) -> Vector2:
	return CommandoFirearmLingeringStatusState.get_lingering_effect_rect_pos(effect)


func _get_lingering_effect_rect_width(effect: Dictionary) -> float:
	return CommandoFirearmLingeringStatusState.get_lingering_effect_rect_width(effect)


func _get_lingering_effect_rect_height(effect: Dictionary) -> float:
	return CommandoFirearmLingeringStatusState.get_lingering_effect_rect_height(effect)


func _get_lingering_effect_rect_size(effect: Dictionary) -> Vector2:
	return CommandoFirearmLingeringStatusState.get_lingering_effect_rect_size(effect)


func _get_lingering_boss_rect(context: Dictionary) -> Rect2:
	return CommandoFirearmLingeringStatusState.get_lingering_boss_rect(context)


func _get_lingering_boss_rect_pos(context: Dictionary) -> Vector2:
	return CommandoFirearmLingeringStatusState.get_lingering_boss_rect_pos(context)


func _get_lingering_boss_rect_width(context: Dictionary) -> float:
	return CommandoFirearmLingeringStatusState.get_lingering_boss_rect_width(context)


func _get_lingering_boss_rect_height(context: Dictionary) -> float:
	return CommandoFirearmLingeringStatusState.get_lingering_boss_rect_height(context)


func _get_lingering_boss_rect_size(context: Dictionary) -> Vector2:
	return CommandoFirearmLingeringStatusState.get_lingering_boss_rect_size(context)


func _get_hit_knockback_velocity(profile: Dictionary, pos: Vector2, velocity: Vector2, context: Dictionary) -> float:
	return CommandoFirearmHitGeometry.get_hit_knockback_velocity(
		profile,
		pos,
		velocity,
		_get_boss_target_pos(context)
	)


func _get_result_hit_profile(profile: Dictionary, result: Dictionary) -> Dictionary:
	return CommandoFirearmHitGeometry.get_result_hit_profile(profile, result)


func _get_hit_knockback_direction(pos: Vector2, velocity: Vector2, context: Dictionary) -> int:
	return CommandoFirearmHitGeometry.get_hit_knockback_direction(pos, velocity, _get_boss_target_pos(context))


func _is_stage2_speed_defense_boss_immune(context: Dictionary = {}, deps: Dictionary = {}) -> bool:
	if int(context.get("current_stage", 0)) == 2:
		if (
			bool(context.get("stage2_speed_defense_status_immunity_active", false))
			or bool(context.get("stage2_speed_defense_active", false))
		):
			return true
	var stage2_skill_state: Object = deps.get("stage2_boss_skill_state", null)
	if (
		stage2_skill_state != null
		and stage2_skill_state.has_method("is_boss_status_immune")
		and bool(stage2_skill_state.is_boss_status_immune())
	):
		return true
	var registry: Object = deps.get("registry", null)
	return _is_stage2_speed_defense_registry_immune(registry)


func _is_stage2_speed_defense_registry_immune(registry: Object) -> bool:
	var stage2_skill_state: Object = _get_instance(registry, "stage2_boss_skill_state")
	return (
		stage2_skill_state != null
		and stage2_skill_state.has_method("is_boss_status_immune")
		and bool(stage2_skill_state.is_boss_status_immune())
	)


func _spawn_shared_impact_particles(pos: Vector2, color: Color, velocity: Vector2, intensity: float, deps: Dictionary) -> void:
	var impact_effects: Object = deps.get("impact_effects", null)
	if impact_effects == null or not impact_effects.has_method("spawn_hit_particles"):
		return
	impact_effects.spawn_hit_particles(pos, color, velocity, intensity, velocity.length())


func _trigger_hit_feedback(feedback_profile: Dictionary, deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback == null:
		return
	var shake_amount: float = float(feedback_profile.get("shake_amount", 0.04))
	var shake_intensity: float = float(feedback_profile.get("shake_intensity", 1.2))
	if feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(shake_amount, shake_intensity)
	elif feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(shake_amount, shake_intensity)


func _trigger_boss_hit_animation(context: Dictionary, deps: Dictionary) -> void:
	var animation_state: Object = deps.get("animation_state", null)
	if animation_state == null or not animation_state.has_method("trigger_boss_hit"):
		return
	animation_state.trigger_boss_hit(
		float(context.get("boss_vel", 0.0)),
		bool(context.get("boss_has_hit_sprite", false))
	)


func _register_ball_hit_pulse(pos: Vector2, velocity: Vector2, intensity: float, weapon_id: String, deps: Dictionary) -> void:
	var ball_effects: Object = deps.get("ball_effects", null)
	if ball_effects == null or not ball_effects.has_method("register_hit_pulse"):
		return
	ball_effects.register_hit_pulse(pos, velocity, clamp(intensity, 0.0, 1.0), _get_ball_hit_pulse_kind(weapon_id))


func _get_ball_hit_pulse_kind(weapon_id: String) -> String:
	return CommandoFirearmAudioResolver.get_ball_hit_pulse_kind(weapon_id, BASE_WEAPON_ID)


@warning_ignore("shadowed_variable_base_class")
func _start_support_aircraft_audio(call: Dictionary, deps: Dictionary) -> void:
	if bool(call.get("aircraft_audio_active", false)):
		return
	call["aircraft_audio_active"] = true
	_play_first_audio_method(deps, ["play_commando_fire_support_aircraft_loop", "play_commando_supply_aircraft_loop"])


@warning_ignore("shadowed_variable_base_class")
func _stop_support_aircraft_audio(call: Dictionary, deps: Dictionary) -> void:
	if not bool(call.get("aircraft_audio_active", false)):
		return
	call["aircraft_audio_active"] = false
	_play_first_audio_method(deps, ["stop_commando_fire_support_aircraft_loop", "stop_commando_supply_aircraft_loop"])


func _stop_all_support_aircraft_audio(deps: Dictionary) -> void:
	for index in range(support_calls.size()):
		@warning_ignore("shadowed_variable_base_class")
		var call: Dictionary = _get_dict(support_calls[index])
		_stop_support_aircraft_audio(call, deps)
		support_calls[index] = call


@warning_ignore("shadowed_variable_base_class")
func _get_support_aircraft_collision_rect(call: Dictionary) -> Rect2:
	return CommandoFirearmSupportAircraftGeometry.get_collision_rect(
		call,
		Vector2(-140.0, SUPPORT_AIRCRAFT_Y),
		SUPPORT_AIRCRAFT_COLLISION_SIZE
	)


@warning_ignore("shadowed_variable_base_class")
func _support_aircraft_ball_path_hits(call: Dictionary, from_pos: Vector2, to_pos: Vector2, ball_radius: float) -> bool:
	return CommandoFirearmSupportAircraftGeometry.ball_path_hits(
		call,
		from_pos,
		to_pos,
		ball_radius,
		Vector2(-140.0, SUPPORT_AIRCRAFT_Y),
		SUPPORT_AIRCRAFT_COLLISION_SIZE
	)


func _play_fire_audio(weapon_id: String, deps: Dictionary) -> void:
	if weapon_id == "fire_support":
		# Fire-support activation already owns the radio cue in
		# _start_support_call(); do not layer a generic launch sound over it.
		return
	_play_weapon_audio_method(
		deps,
		_get_fire_audio_methods(weapon_id),
		"play_commando_firearm_fire",
		weapon_id
	)


func _play_impact_audio(weapon_id: String, deps: Dictionary) -> void:
	_play_weapon_audio_method(
		deps,
		_get_impact_audio_methods(weapon_id),
		"play_commando_firearm_impact",
		weapon_id
	)


func _get_fire_audio_methods(weapon_id: String) -> Array[String]:
	return CommandoFirearmAudioResolver.get_fire_audio_methods(weapon_id)


func _get_impact_audio_methods(weapon_id: String) -> Array[String]:
	return CommandoFirearmAudioResolver.get_impact_audio_methods(weapon_id)


func _play_weapon_audio_method(
	deps: Dictionary,
	method_names: Array[String],
	fallback_method: String,
	weapon_id: String
) -> void:
	var audio: Object = deps.get("audio", deps.get("game_audio", null))
	if audio == null:
		return
	for method_name in method_names:
		if audio.has_method(method_name):
			audio.call(method_name)
			return
	if audio.has_method(fallback_method):
		audio.call(fallback_method, weapon_id)


func _play_first_audio_method(deps: Dictionary, method_names: Array[String]) -> void:
	var audio: Object = deps.get("audio", deps.get("game_audio", null))
	if audio == null:
		return
	for method_name in method_names:
		if audio.has_method(method_name):
			audio.call(method_name)
			return


func _play_reload_progress_audio(timer_result: Dictionary, deps: Dictionary) -> void:
	var base_result: Dictionary = _get_dict(timer_result.get("base_pistol", {}))
	var pistol_result: Dictionary = _get_dict(timer_result.get("commando_pistol", {}))
	var rounds_added: int = int(base_result.get("reload_rounds_added", 0)) + int(pistol_result.get("reload_rounds_added", 0))
	for _i in range(max(0, rounds_added)):
		_play_first_audio_method(deps, ["play_commando_pistol_reload_round", "play_commando_pistol_reload_start"])


func _stop_suicide_drone_audio(deps: Dictionary) -> void:
	_play_first_audio_method(deps, ["stop_commando_suicide_drone_loop"])


func _has_active_suicide_drone_projectile() -> bool:
	return _get_active_suicide_drone_index() >= 0


func _get_active_suicide_drone_index() -> int:
	for index in range(projectiles.size()):
		var projectile: Dictionary = _get_dict(projectiles[index])
		if _is_suicide_drone_projectile(projectile):
			return index
	return -1


func _is_suicide_drone_projectile(projectile: Dictionary) -> bool:
	return _get_projectile_weapon_id(projectile, "") == "suicide_drone" and _get_projectile_kind(projectile) == "drone"


func _update_muzzle_flashes(fps_scale: float) -> void:
	muzzle_flashes = CommandoFirearmValueUtils.advance_timed_effects(muzzle_flashes, fps_scale)


func _update_impact_flashes(fps_scale: float) -> void:
	impact_flashes = CommandoFirearmValueUtils.advance_timed_effects(impact_flashes, fps_scale)


func _is_fire_suppressed_after_switch(weapon_controller: Object, now_msec: int) -> bool:
	return CommandoFirearmInputResolver.is_fire_suppressed_after_switch(
		weapon_controller,
		now_msec,
		SWITCH_FIRE_SUPPRESS_MSEC
	)


func _get_player_muzzle_pos(config: Dictionary) -> Vector2:
	return CommandoFirearmOriginGeometry.get_player_muzzle_pos(config, Vector2(FIELD_WIDTH, FIELD_HEIGHT))


func _get_firearm_origin(weapon_id: String, config: Dictionary, profile: Dictionary) -> Vector2:
	return CommandoFirearmOriginGeometry.get_firearm_origin(
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


func _get_firearm_aim_origin(weapon_id: String, _config: Dictionary, origin: Vector2) -> Vector2:
	return CommandoFirearmOriginGeometry.get_firearm_aim_origin(weapon_id, origin)


func _get_bazooka_muzzle_pos(config: Dictionary) -> Vector2:
	return _get_commando_fire_sheet_world_pos(config, COMMANDO_BAZOOKA_FIRE_MUZZLE_SOURCE)


func _get_net_gun_projectile_pos(config: Dictionary) -> Vector2:
	return _get_commando_fire_sheet_world_pos(config, COMMANDO_NET_GUN_FIRE_MUZZLE_SOURCE)


func _get_net_gun_aim_origin(config: Dictionary) -> Vector2:
	return _get_net_gun_projectile_pos(config)


func _get_pistol_fire_muzzle_pos(config: Dictionary) -> Vector2:
	return _get_commando_fire_sheet_world_pos(config, COMMANDO_PISTOL_FIRE_MUZZLE_SOURCE)


func _get_commando_fire_sheet_world_pos(config: Dictionary, source_pos: Vector2) -> Vector2:
	return CommandoFirearmOriginGeometry.get_commando_fire_sheet_world_pos(
		config,
		source_pos,
		Vector2(FIELD_WIDTH, FIELD_HEIGHT),
		COMMANDO_FIRE_SHEET_SOURCE_CELL_SIZE,
		COMMANDO_FIRE_SHEET_PLAYER_FOOT_Y_OFFSET
	)


func _get_player_pos_from_config(config: Dictionary) -> Vector2:
	return CommandoFirearmOriginGeometry.get_player_pos_from_config(config, Vector2(FIELD_WIDTH, FIELD_HEIGHT))


func _get_player_paddle_width_from_config(config: Dictionary) -> float:
	return CommandoFirearmOriginGeometry.get_player_paddle_width_from_config(config)


func _get_player_paddle_height_from_config(config: Dictionary) -> float:
	return CommandoFirearmOriginGeometry.get_player_paddle_height_from_config(config)


func _get_player_paddle_scale_from_config(config: Dictionary, paddle_width: float) -> float:
	return CommandoFirearmOriginGeometry.get_player_paddle_scale_from_config(config, paddle_width)


func _get_boss_target_pos(config: Dictionary) -> Vector2:
	return CommandoFirearmOriginGeometry.get_boss_target_pos(config, FIELD_WIDTH)


func _get_weapon_profile(weapon_id: String) -> Dictionary:
	return CommandoFirearmProfileResolver.get_weapon_profile(weapon_id, WEAPON_PROFILES, WEAPON_PROFILE_OVERRIDES)


func _get_hit_feedback_profile(weapon_id: String) -> Dictionary:
	return CommandoFirearmProfileResolver.get_hit_feedback_profile(weapon_id, WEAPON_HIT_FEEDBACK, HIT_FEEDBACK_PROFILE_OVERRIDES)


func _get_hit_result_profile(weapon_id: String) -> Dictionary:
	return CommandoFirearmProfileResolver.get_hit_result_profile(weapon_id, WEAPON_HIT_RESULTS, HIT_RESULT_PROFILE_OVERRIDES)


func _get_lingering_effect_profile(weapon_id: String) -> Dictionary:
	return CommandoFirearmProfileResolver.get_lingering_effect_profile(weapon_id, WEAPON_LINGERING_EFFECTS)


func _append_limited(target: Array, value: Dictionary, limit: int) -> void:
	CommandoFirearmValueUtils.append_limited(target, value, limit)


func _next_shot_id() -> int:
	shot_serial += 1
	return shot_serial


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return CommandoFirearmValueUtils.get_vector2(value, fallback)


func _get_color(value: Variant, fallback: Color) -> Color:
	return CommandoFirearmValueUtils.get_color(value, fallback)


func _get_dict(value: Variant) -> Dictionary:
	return CommandoFirearmValueUtils.get_dict(value)


func _get_array(value: Variant) -> Array:
	return CommandoFirearmValueUtils.get_array(value)


func _get_instance(registry: Object, key: String) -> Object:
	return CommandoFirearmValueUtils.get_instance(registry, key)
