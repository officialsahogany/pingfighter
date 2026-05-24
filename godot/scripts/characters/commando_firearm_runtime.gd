extends RefCounted

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const CommandoFirearmAudioDispatcher := preload("res://scripts/characters/commando_firearm_audio_dispatcher.gd")
const CommandoFirearmBowlingTrapGeometry := preload("res://scripts/characters/commando_firearm_bowling_trap_geometry.gd")
const CommandoFirearmBowlingTrapGuardState := preload("res://scripts/characters/commando_firearm_bowling_trap_guard_state.gd")
const CommandoFirearmControlState := preload("res://scripts/characters/commando_firearm_control_state.gd")
const CommandoFirearmCooldownState := preload("res://scripts/characters/commando_firearm_cooldown_state.gd")
const CommandoFirearmDrawStateResolver := preload("res://scripts/characters/commando_firearm_draw_state_resolver.gd")
const CommandoFirearmFireResultState := preload("res://scripts/characters/commando_firearm_fire_result_state.gd")
const CommandoFirearmFireSheetResolver := preload("res://scripts/characters/commando_firearm_fire_sheet_resolver.gd")
const CommandoFirearmHitFeedbackDispatcher := preload("res://scripts/characters/commando_firearm_hit_feedback_dispatcher.gd")
const CommandoFirearmHitResultState := preload("res://scripts/characters/commando_firearm_hit_result_state.gd")
const CommandoFirearmInputResolver := preload("res://scripts/characters/commando_firearm_input_resolver.gd")
const CommandoFirearmLingeringEffectState := preload("res://scripts/characters/commando_firearm_lingering_effect_state.gd")
const CommandoFirearmLingeringFireFlameState := preload("res://scripts/characters/commando_firearm_lingering_fire_flame_state.gd")
const CommandoFirearmLingeringNetFieldState := preload("res://scripts/characters/commando_firearm_lingering_net_field_state.gd")
const CommandoFirearmLingeringStatusState := preload("res://scripts/characters/commando_firearm_lingering_status_state.gd")
const CommandoFirearmMuzzleFlashResolver := preload("res://scripts/characters/commando_firearm_muzzle_flash_resolver.gd")
const CommandoFirearmOriginGeometry := preload("res://scripts/characters/commando_firearm_origin_geometry.gd")
const CommandoFirearmPendingResultState := preload("res://scripts/characters/commando_firearm_pending_result_state.gd")
const CommandoFirearmPistolFeedbackState := preload("res://scripts/characters/commando_firearm_pistol_feedback_state.gd")
const CommandoFirearmPistolReloadState := preload("res://scripts/characters/commando_firearm_pistol_reload_state.gd")
const CommandoFirearmProfileResolver := preload("res://scripts/characters/commando_firearm_profile_resolver.gd")
const CommandoFirearmProjectileImpactState := preload("res://scripts/characters/commando_firearm_projectile_impact_state.gd")
const CommandoFirearmProjectileMotionState := preload("res://scripts/characters/commando_firearm_projectile_motion_state.gd")
const CommandoFirearmProjectileSpawnState := preload("res://scripts/characters/commando_firearm_projectile_spawn_state.gd")
const CommandoFirearmShellCasingState := preload("res://scripts/characters/commando_firearm_shell_casing_state.gd")
const CommandoFirearmSlingshotState := preload("res://scripts/characters/commando_firearm_slingshot_state.gd")
const CommandoFirearmSupportAircraftGeometry := preload("res://scripts/characters/commando_firearm_support_aircraft_geometry.gd")
const CommandoFirearmSupportCallResolver := preload("res://scripts/characters/commando_firearm_support_call_resolver.gd")
const CommandoFirearmSupportProjectileResolver := preload("res://scripts/characters/commando_firearm_support_projectile_resolver.gd")
const CommandoFirearmSuicideDroneState := preload("res://scripts/characters/commando_firearm_suicide_drone_state.gd")
const CommandoFirearmTimerState := preload("res://scripts/characters/commando_firearm_timer_state.gd")
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

const DRAW_CONTEXT_TIMING := {
	"slingshot_charge_threshold_frames": SLINGSHOT_CHARGE_THRESHOLD_3,
	"slingshot_charge_tick_interval_frames": SLINGSHOT_GAUGE_DRAIN_INTERVAL_FRAMES,
	"slingshot_cooldown_max_frames": SLINGSHOT_COOLDOWN_FRAMES,
	"slingshot_control_lock_max_frames": SLINGSHOT_CONTROL_LOCK_FRAMES,
	"pistol_fire_delay_max_frames": PISTOL_FIRE_DELAY_FRAMES,
	"pistol_post_fire_animation_max_frames": PISTOL_POST_FIRE_ANIMATION_FRAMES,
	"weapon_fire_sheet_frame_count": COMMANDO_WEAPON_FIRE_SHEET_FRAME_COUNT,
	"bazooka_fire_animation_max_frames": BAZOOKA_FIRE_ANIMATION_FRAMES,
	"bazooka_firing_pose_max_frames": BAZOOKA_FIRING_POSE_FRAMES,
	"bazooka_muzzle_flash_max_frames": BAZOOKA_MUZZLE_FLASH_FRAMES,
	"net_gun_cooldown_max_frames": NET_GUN_COOLDOWN_FRAMES,
	"net_gun_control_lock_max_frames": NET_GUN_CONTROL_LOCK_FRAMES,
	"net_gun_throw_pose_max_frames": NET_GUN_THROW_POSE_FRAMES,
	"net_gun_harpoon_flash_max_frames": NET_GUN_HARPOON_FLASH_FRAMES,
	"bowling_trap_cooldown_max_frames": BOWLING_TRAP_COOLDOWN_FRAMES,
	"bowling_trap_control_lock_max_frames": BOWLING_TRAP_CONTROL_LOCK_FRAMES,
	"bowling_trap_install_pose_max_frames": BOWLING_TRAP_INSTALL_FRAMES,
	"suicide_drone_cooldown_max_frames": SUICIDE_DRONE_COOLDOWN_FRAMES,
}

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
	var net_constrict_result: Dictionary = CommandoFirearmLingeringNetFieldState.apply_net_constrict_input(
		lingering_effects,
		input_snapshot,
		now_msec,
		net_constrict_last_dir,
		net_constrict_last_tick_msec,
		NET_CONSTRICT_MIN,
		NET_CONSTRICT_STEP,
		NET_CONSTRICT_WINDOW_MSEC,
		deps.get("game_audio", null)
	)
	if not net_constrict_result.is_empty():
		lingering_effects = CommandoFirearmValueUtils.get_array(net_constrict_result.get("effects", lingering_effects))
		net_constrict_last_dir = int(net_constrict_result.get("last_dir", net_constrict_last_dir))
		net_constrict_last_tick_msec = int(net_constrict_result.get("last_tick_msec", net_constrict_last_tick_msec))
	var current_weapon: Dictionary = weapon_controller.get_current_weapon_data()
	var weapon_id: String = str(current_weapon.get("weapon_id", BASE_WEAPON_ID))
	if weapon_controller.has_method("update_timers"):
		CommandoFirearmAudioDispatcher.play_reload_progress_audio(weapon_controller.update_timers(1.0), deps)
	var serve_wait_suppression: Dictionary = CommandoFirearmControlState.get_serve_wait_fire_suppression(
		input_snapshot,
		config,
		deps,
		serve_wait_fire_suppressed_until_release
	)
	serve_wait_fire_suppressed_until_release = bool(serve_wait_suppression.get(
		"suppressed_until_release",
		serve_wait_fire_suppressed_until_release
	))
	if bool(serve_wait_suppression.get("clear_input_state", false)):
		CommandoFirearmControlState.apply_serve_wait_firearm_input_cleared(self)
	if bool(serve_wait_suppression.get("suppressed", false)):
		return {}
	var timed_result: Dictionary = _update_firearm_timers(config, deps, 1.0)
	if bool(timed_result.get("fired", false)):
		return timed_result
	if CommandoFirearmSuicideDroneState.has_active_projectile(projectiles):
		return _update_active_suicide_drone_input(input_snapshot, special_gauge, config, deps)
	var reset_result: Dictionary = CommandoFirearmControlState.handle_firearm_reset_input(
		input_snapshot,
		special_gauge,
		weapon_controller,
		now_msec,
		self,
		BASE_WEAPON_ID
	)
	if not reset_result.is_empty():
		if bool(reset_result.get("weapon_switched", false)):
			CommandoFirearmAudioDispatcher.play_first_audio_method(deps, ["play_commando_weapon_change"])
		return reset_result
	current_weapon = weapon_controller.get_current_weapon_data()
	weapon_id = str(current_weapon.get("weapon_id", BASE_WEAPON_ID))
	if weapon_id == BASE_WEAPON_ID:
		CommandoFirearmControlState.apply_ak47_trigger_cleared(self)
		if slingshot_charging:
			CommandoFirearmSlingshotState.apply_canceled_state(self)
		return _update_pistol_input(input_snapshot, special_gauge, config, deps, current_weapon, now_msec)
	if slingshot_charging:
		CommandoFirearmSlingshotState.apply_canceled_state(self)
	if weapon_id == "commando_pistol":
		CommandoFirearmControlState.apply_ak47_trigger_cleared(self)
		return _update_pistol_input(input_snapshot, special_gauge, config, deps, current_weapon, now_msec)
	if weapon_id == "ak47":
		return _update_ak47_input(input_snapshot, special_gauge, config, deps, current_weapon, now_msec)
	if weapon_id == "bazooka":
		CommandoFirearmControlState.apply_ak47_trigger_cleared(self)
		return _update_bazooka_input(input_snapshot, special_gauge, config, deps, current_weapon, now_msec)
	if weapon_id == "net_gun":
		CommandoFirearmControlState.apply_ak47_trigger_cleared(self)
		return _update_net_gun_input(input_snapshot, special_gauge, config, deps, current_weapon, now_msec)
	if weapon_id == "bowling_trap":
		CommandoFirearmControlState.apply_ak47_trigger_cleared(self)
		return _update_bowling_trap_input(input_snapshot, special_gauge, config, deps, current_weapon, now_msec)
	if weapon_id == "suicide_drone":
		CommandoFirearmControlState.apply_ak47_trigger_cleared(self)
		return _update_suicide_drone_input(input_snapshot, special_gauge, config, deps, current_weapon, now_msec)
	CommandoFirearmControlState.apply_ak47_trigger_cleared(self)
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
	CommandoFirearmBowlingTrapGeometry.apply_guard_state(
		self,
		CommandoFirearmBowlingTrapGeometry.build_cleared_guard_state()
	)


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
	return CommandoFirearmDrawStateResolver.has_runtime_visible_effects(self)


func needs_effect_update() -> bool:
	return CommandoFirearmControlState.needs_runtime_effect_update(self, has_visible_effects())


func is_player_control_locked() -> bool:
	return CommandoFirearmControlState.is_runtime_player_control_locked(
		self,
		CommandoFirearmSupportCallResolver.has_active_lock(support_calls),
		CommandoFirearmSuicideDroneState.has_active_projectile(projectiles)
	)


func get_movement_speed_multiplier() -> float:
	return CommandoFirearmControlState.get_runtime_movement_speed_multiplier(
		self,
		CommandoFirearmSuicideDroneState.has_active_projectile(projectiles),
		CommandoFirearmLingeringNetFieldState.has_active_hooked_net_field(lingering_effects),
		AK47_MOVEMENT_SPEED_MULTIPLIER,
		NET_GUN_PLAYER_SLOW_MULTIPLIER
	)


func is_bowling_trap_guard_armed() -> bool:
	return bowling_trap_guard_armed


func consume_bowling_trap_boss_guard(ball_vel: Vector2, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	return CommandoFirearmBowlingTrapGuardState.consume_runtime_boss_guard(
		self,
		ball_vel,
		context,
		deps,
		FIELD_WIDTH,
		BASE_WEAPON_ID,
		WEAPON_PROFILES,
		WEAPON_PROFILE_OVERRIDES,
		WEAPON_HIT_FEEDBACK,
		HIT_FEEDBACK_PROFILE_OVERRIDES,
		BOWLING_TRAP_GUARD_KNOCKBACK_POWER,
		BOWLING_TRAP_GUARD_STUN_FRAMES,
		BOWLING_TRAP_GUARD_KNOCKBACK_FRAMES,
		BOWLING_TRAP_GUARD_KNOCKBACK_DECAY
	)


func is_fire_support_aircraft_audio_active() -> bool:
	return CommandoFirearmSupportAircraftGeometry.has_active_aircraft_audio(support_calls)


func get_fire_support_aircraft_collision_rect(call_id: int = 0) -> Rect2:
	return CommandoFirearmSupportAircraftGeometry.get_active_collision_rect(
		support_calls,
		call_id,
		Vector2(SUPPORT_AIRCRAFT_START_X, SUPPORT_AIRCRAFT_Y),
		SUPPORT_AIRCRAFT_COLLISION_SIZE
	)


func resolve_ball_collision(scene: Dictionary, context: Dictionary, _deps: Dictionary = {}) -> bool:
	return CommandoFirearmSupportAircraftGeometry.resolve_ball_collision(
		support_calls,
		scene,
		context,
		Vector2(SUPPORT_AIRCRAFT_START_X, SUPPORT_AIRCRAFT_Y),
		SUPPORT_AIRCRAFT_COLLISION_SIZE
	)


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
	var pending_result: Dictionary = CommandoFirearmPendingResultState.consume_runtime_pending_results(self)
	if not pending_result.is_empty():
		result.merge(pending_result, true)
	return result


func get_recent_hit_events() -> Array:
	return hit_events.duplicate(true)


func get_actor_draw_context() -> Dictionary:
	return CommandoFirearmDrawStateResolver.build_runtime_draw_context(
		self,
		DRAW_CONTEXT_TIMING,
		get_movement_speed_multiplier()
	)


func _update_firearm_timers(config: Dictionary, deps: Dictionary, fps_scale: float = 1.0) -> Dictionary:
	var step: float = max(0.0, float(fps_scale))
	if step <= 0.0:
		return {}
	CommandoFirearmTimerState.advance_runtime_timers(self, step, AK47_RECOIL_RECOVERY_PER_FRAME)
	var pending_fire: Dictionary = CommandoFirearmTimerState.advance_pending_pistol_fire(
		self,
		config,
		step,
		PISTOL_PENDING_FIRE_GEOMETRY_KEYS,
		BASE_WEAPON_ID
	)
	if pending_fire.is_empty():
		return {}
	if bool(pending_fire.get("pending", false)):
		return CommandoFirearmValueUtils.get_dict(pending_fire.get("result", {}))
	var shot_config: Dictionary = CommandoFirearmValueUtils.get_dict(pending_fire.get("shot_config", config))
	var shot_weapon_id: String = str(pending_fire.get("weapon_id", BASE_WEAPON_ID))
	_spawn_firearm_effect(shot_weapon_id, shot_config, deps)
	CommandoFirearmAudioDispatcher.play_fire_audio(shot_weapon_id, deps)
	# Start the post-fire animation window so the renderer plays the muzzle /
	# smoke / lower / ready frames after the shot resolves. Frame 4 (muzzle
	# flash) is the first cell shown during this window, so it lines up with
	# `CommandoFirearmAudioDispatcher.play_fire_audio()` above.
	pistol_post_fire_animation_frames = PISTOL_POST_FIRE_ANIMATION_FRAMES
	return CommandoFirearmValueUtils.get_dict(pending_fire.get("result", {}))


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
			return CommandoFirearmPistolReloadState.start_base_empty_reload(
				special_gauge,
				deps,
				BASE_WEAPON_ID,
				pistol_cooldown_frames,
				pistol_control_lock_frames,
				pistol_fire_delay_frames,
				PISTOL_AMMO_MAX,
				PISTOL_FIRE_DELAY_FRAMES,
				PISTOL_EMPTY_RELOAD_GAUGE_COST
			)
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
		CommandoFirearmControlState.apply_ak47_trigger_cleared(self)
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
		CommandoFirearmControlState.apply_ak47_trigger_cleared(self)
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
			CommandoFirearmControlState.apply_ak47_trigger_cleared(self)
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
		CommandoFirearmControlState.apply_ak47_trigger_cleared(self)
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
	var failure_fields := CommandoFirearmFireResultState.build_runtime_bazooka_timing_fields(self)
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
		CommandoFirearmFireResultState.build_runtime_bazooka_timing_fields(self)
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
	var failure_fields := CommandoFirearmFireResultState.build_runtime_net_gun_timing_fields(self)
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
		CommandoFirearmFireResultState.build_runtime_net_gun_timing_fields(self)
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
	var failure_fields := CommandoFirearmFireResultState.build_runtime_bowling_trap_timing_fields(self)
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
		CommandoFirearmFireResultState.build_runtime_bowling_trap_timing_fields(self, true, 0.0)
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
	var profile: Dictionary = CommandoFirearmProfileResolver.get_weapon_profile(
		"suicide_drone",
		WEAPON_PROFILES,
		WEAPON_PROFILE_OVERRIDES
	)
	CommandoFirearmSuicideDroneState.append_spawn_effects(
		projectiles,
		muzzle_flashes,
		config,
		profile,
		CommandoFirearmProjectileSpawnState.claim_next_shot_id(self),
		FIELD_WIDTH,
		FIELD_HEIGHT,
		SUICIDE_DRONE_SIZE,
		SUICIDE_DRONE_MAX_SPEED,
		SUICIDE_DRONE_ACCEL,
		SUICIDE_DRONE_LIFE_FRAMES,
		SUICIDE_DRONE_GRACE_FRAMES,
		SUICIDE_DRONE_ROTOR_BASE_SPEED,
		PROJECTILE_LIMIT,
		FLASH_LIMIT
	)
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
	CommandoFirearmProjectileMotionState.replace_projectile_payload(projectile, next_projectile)
	projectiles[index] = projectile
	var action_pressed: bool = bool(input_snapshot.get("action_pressed", false))
	var action_just_pressed: bool = bool(input_snapshot.get(
		"action_just_pressed",
		action_pressed and not suicide_drone_last_action_pressed
	))
	suicide_drone_last_action_pressed = action_pressed
	if float(projectile.get("grace_timer_frames", 0.0)) <= 0.0 and action_just_pressed:
		var detonate_result: Dictionary = CommandoFirearmSuicideDroneState.detonate_runtime_projectile_at_index(
			projectiles,
			index,
			impact_flashes,
			self,
			projectile,
			"manual",
			config,
			deps,
			WEAPON_PROFILES,
			WEAPON_PROFILE_OVERRIDES,
			WEAPON_HIT_FEEDBACK,
			HIT_FEEDBACK_PROFILE_OVERRIDES,
			BASE_WEAPON_ID,
			FIELD_WIDTH,
			SUICIDE_DRONE_COOLDOWN_FRAMES,
			SUICIDE_DRONE_BALL_SPEED_MULTIPLIER,
			SUICIDE_DRONE_BALL_FAN_DEGREES,
			float(ActiveItemThrowController.GRENADE_EXPLOSION_DURATION_FRAMES),
			FLASH_LIMIT
		)
		detonate_result["special_gauge"] = special_gauge
		return detonate_result
	return CommandoFirearmSuicideDroneState.build_active_input_result(projectile, special_gauge)


func _spawn_firearm_effect(weapon_id: String, config: Dictionary, deps: Dictionary, profile_override: Dictionary = {}) -> void:
	CommandoFirearmFireSheetResolver.apply_runtime_animation_state(
		self,
		weapon_id,
		COMMANDO_WEAPON_FIRE_SHEET_DEFAULT_FRAMES,
		COMMANDO_WEAPON_FIRE_SHEET_LONG_FRAMES,
		COMMANDO_WEAPON_FIRE_SHEET_FRAME_COUNT
	)
	var spawn_profile_state: Dictionary = CommandoFirearmProfileResolver.build_spawn_profile_state(
		weapon_id,
		profile_override,
		WEAPON_PROFILES,
		WEAPON_PROFILE_OVERRIDES,
		config,
		DOPING_POTION_DEFAULTS,
		BASE_WEAPON_ID,
		PISTOL_BULLET_SPEED,
		DOPING_POTION_PISTOL_SPEED_MULTIPLIER,
		PISTOL_SPREAD_RADIANS,
		BERETTA_SPREAD_RADIANS
	)
	var profile: Dictionary = CommandoFirearmValueUtils.get_dict(spawn_profile_state.get("profile", {}))
	var doping_context: Dictionary = CommandoFirearmValueUtils.get_dict(spawn_profile_state.get("doping_context", {}))
	var kind: String = str(profile.get("kind", "bullet"))
	var spawn_geometry_state: Dictionary = CommandoFirearmOriginGeometry.build_firearm_spawn_geometry_state(
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
	var origin: Vector2 = CommandoFirearmValueUtils.get_vector2(spawn_geometry_state.get("origin", Vector2.ZERO), Vector2.ZERO)
	var target: Vector2 = CommandoFirearmValueUtils.get_vector2(spawn_geometry_state.get("target", Vector2.ZERO), Vector2.ZERO)
	var aim_origin: Vector2 = CommandoFirearmValueUtils.get_vector2(spawn_geometry_state.get("aim_origin", origin), origin)
	var angle_offset: float = float(spawn_geometry_state.get("angle_offset", 0.0))
	var direction: Vector2 = CommandoFirearmValueUtils.get_vector2(spawn_geometry_state.get("direction", Vector2.UP), Vector2.UP)
	CommandoFirearmMuzzleFlashResolver.append_runtime_flash(
		muzzle_flashes,
		origin,
		direction,
		profile,
		weapon_id,
		FLASH_LIMIT
	)
	if kind == "support":
		var support_start: Dictionary = CommandoFirearmSupportCallResolver.append_runtime_start_effects(
			support_calls,
			impact_flashes,
			self,
			origin,
			target,
			profile,
			weapon_id,
			SUPPORT_CALL_LIMIT,
			FLASH_LIMIT,
			SUPPORT_CALL_DELAY_MIN_FRAMES,
			SUPPORT_CALL_DELAY_MAX_FRAMES,
			SUPPORT_BOMB_MIN_COUNT,
			SUPPORT_BOMB_MAX_COUNT,
			SUPPORT_CALL_LOCK_FRAMES,
			SUPPORT_AIRCRAFT_DROP_ARM_FRAMES,
			SUPPORT_AIRCRAFT_Y,
			SUPPORT_AIRCRAFT_SPEED,
			SUPPORT_AIRCRAFT_CURVE_AMPLITUDE,
			SUPPORT_AIRCRAFT_CURVE_FREQUENCY,
			SUPPORT_AIRCRAFT_CURVE_SECONDARY_RATIO,
			SUPPORT_AIRCRAFT_START_X
		)
		CommandoFirearmAudioDispatcher.dispatch_support_call_start_audio(support_start, deps)
		return
	if kind == "trap" or weapon_id == "bowling_trap":
		CommandoFirearmBowlingTrapGeometry.append_runtime_install_effects(
			bowling_traps,
			impact_flashes,
			self,
			config,
			profile,
			weapon_id,
			FIELD_WIDTH,
			FIELD_HEIGHT,
			BOWLING_TRAP_WIDTH,
			BOWLING_TRAP_HEIGHT,
			BOWLING_TRAP_MIN_FIELD_Y_RATIO,
			BOWLING_TRAP_INSTALL_FRAMES,
			BOWLING_TRAP_CAPTURE_BALL_OFFSET,
			BOWLING_TRAP_LIMIT,
			FLASH_LIMIT
		)
		return
	CommandoFirearmProjectileSpawnState.append_runtime_projectile(
		projectiles,
		shell_casings,
		self,
		weapon_id,
		kind,
		origin,
		target,
		direction,
		angle_offset,
		aim_origin,
		profile,
		doping_context,
		config,
		16.0,
		BAZOOKA_SMOKE_TRAIL_LIMIT,
		NET_GUN_ROPE_TRAIL_LIMIT,
		DOPING_POTION_HEAD_LEG_MULTIPLIER,
		DOPING_POTION_PISTOL_SPEED_MULTIPLIER,
		PROJECTILE_LIMIT,
		FIELD_HEIGHT,
		AK47_SHELL_LIFETIME_FRAMES,
		PISTOL_SHELL_LIFETIME_FRAMES,
		SHELL_CASING_LIMIT
	)


func _update_support_calls(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var step: float = max(0.0, fps_scale)
	var profile: Dictionary = CommandoFirearmProfileResolver.get_weapon_profile(
		"fire_support",
		WEAPON_PROFILES,
		WEAPON_PROFILE_OVERRIDES
	)
	var support_result: Dictionary = CommandoFirearmSupportProjectileResolver.advance_runtime_calls(
		support_calls,
		projectiles,
		self,
		context,
		profile,
		step,
		Vector2(FIELD_WIDTH, FIELD_HEIGHT),
		SUPPORT_AIRCRAFT_START_X,
		SUPPORT_AIRCRAFT_Y,
		SUPPORT_AIRCRAFT_SPEED,
		SUPPORT_BOMB_INTERVAL_FRAMES,
		SUPPORT_AIRCRAFT_FINISH_MARGIN,
		SUPPORT_AIRCRAFT_CURVE_AMPLITUDE,
		SUPPORT_AIRCRAFT_CURVE_FREQUENCY,
		SUPPORT_AIRCRAFT_CURVE_SECONDARY_RATIO,
		SUPPORT_BOMB_INITIAL_VY,
		SUPPORT_BOMB_GRAVITY,
		SUPPORT_BOMB_HORIZONTAL_JITTER,
		SUPPORT_OPPONENT_WALL_Y,
		SUPPORT_MISSILE_FLIGHT_FRAMES,
		SUPPORT_MISSILE_LIFE_FRAMES,
		SUPPORT_BOMB_RANDOM_X_RANGE,
		PROJECTILE_LIMIT
	)
	CommandoFirearmAudioDispatcher.dispatch_support_aircraft_audio_events(
		CommandoFirearmValueUtils.get_array(support_result.get("audio_events", [])),
		deps
	)


func _update_bowling_traps(fps_scale: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	var step: float = max(0.0, fps_scale)
	var profile: Dictionary = CommandoFirearmProfileResolver.get_weapon_profile(
		"bowling_trap",
		WEAPON_PROFILES,
		WEAPON_PROFILE_OVERRIDES
	)
	var trap_update: Dictionary = CommandoFirearmBowlingTrapGeometry.advance_runtime_traps(
		bowling_traps,
		context,
		step,
		profile,
		BOWLING_TRAP_INSTALL_FRAMES,
		BOWLING_TRAP_CAPTURE_FRAMES,
		BOWLING_TRAP_CAPTURE_BALL_OFFSET,
		BOWLING_TRAP_HEIGHT,
		BOWLING_TRAP_CAPTURE_HEIGHT,
		BOWLING_TRAP_WIDTH,
		BOWLING_TRAP_LAUNCH_SPEED_MULTIPLIER,
		BOWLING_TRAP_LAUNCH_ANGLE_STEP,
		BOWLING_TRAP_GUARD_SPEED_REDUCTION,
		BOWLING_TRAP_GUARD_KNOCKBACK_POWER,
		BOWLING_TRAP_GUARD_STUN_FRAMES
	)
	CommandoFirearmBowlingTrapGeometry.dispatch_runtime_update_events(
		CommandoFirearmValueUtils.get_array(trap_update.get("events", [])),
		impact_flashes,
		self,
		context,
		deps,
		WEAPON_PROFILES,
		WEAPON_PROFILE_OVERRIDES,
		WEAPON_HIT_FEEDBACK,
		HIT_FEEDBACK_PROFILE_OVERRIDES,
		BASE_WEAPON_ID,
		float(ActiveItemThrowController.GRENADE_EXPLOSION_DURATION_FRAMES),
		FLASH_LIMIT
	)
	return CommandoFirearmValueUtils.get_dict(trap_update.get("result", {}))


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
		var motion_result: Dictionary = CommandoFirearmProjectileMotionState.advance_runtime_projectile_motion(
			projectile,
			projectile_kind,
			projectile_weapon_id,
			is_pistol_projectile,
			context,
			deps,
			step,
			Vector2(FIELD_WIDTH, FIELD_HEIGHT),
			PISTOL_WALL_BOUNCE_MARGIN,
			PISTOL_WALL_BOUNCE_MAX,
			PISTOL_WALL_BOUNCE_DAMPING,
			BAZOOKA_ACCELERATION,
			BAZOOKA_MAX_SPEED,
			BAZOOKA_SMOKE_TRAIL_LIMIT,
			COMMANDO_NET_GUN_FIRE_MUZZLE_SOURCE,
			COMMANDO_FIRE_SHEET_SOURCE_CELL_SIZE,
			COMMANDO_FIRE_SHEET_PLAYER_FOOT_Y_OFFSET,
			NET_GUN_ROPE_TRAIL_LIMIT
		)
		if bool(motion_result.get("consumed", false)):
			projectiles.remove_at(index)
			continue
		projectile = CommandoFirearmValueUtils.get_dict(motion_result.get("projectile", projectile))
		projectiles[index] = projectile
		if projectile_kind == "drone":
			var drone_result: Dictionary = CommandoFirearmSuicideDroneState.resolve_runtime_collision_at_index(
				projectiles,
				index,
				impact_flashes,
				self,
				projectile,
				context,
				deps,
				step,
				Vector2(FIELD_WIDTH, FIELD_HEIGHT),
				SUICIDE_DRONE_SIZE,
				SUICIDE_DRONE_ROTOR_BASE_SPEED,
				FIELD_WIDTH,
				WEAPON_PROFILES,
				WEAPON_PROFILE_OVERRIDES,
				WEAPON_HIT_FEEDBACK,
				HIT_FEEDBACK_PROFILE_OVERRIDES,
				BASE_WEAPON_ID,
				SUICIDE_DRONE_COOLDOWN_FRAMES,
				SUICIDE_DRONE_BALL_SPEED_MULTIPLIER,
				SUICIDE_DRONE_BALL_FAN_DEGREES,
				float(ActiveItemThrowController.GRENADE_EXPLOSION_DURATION_FRAMES),
				FLASH_LIMIT
			)
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
			var impact_result: Dictionary = CommandoFirearmProjectileImpactState.dispatch_runtime_impact(
				impact_flashes,
				self,
				projectile,
				impact_reason,
				projectile_weapon_id,
				context,
				deps,
				WEAPON_PROFILES,
				WEAPON_PROFILE_OVERRIDES,
				WEAPON_HIT_FEEDBACK,
				HIT_FEEDBACK_PROFILE_OVERRIDES,
				BASE_WEAPON_ID,
				float(ActiveItemThrowController.GRENADE_EXPLOSION_DURATION_FRAMES),
				FLASH_LIMIT
			)
			result.merge(impact_result, true)
			context.merge(impact_result, true)
			projectiles.remove_at(index)
	return result


func _register_projectile_hit(projectile: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var weapon_id: String = CommandoFirearmValueUtils.get_projectile_weapon_id(projectile, BASE_WEAPON_ID)
	var feedback_profile: Dictionary = CommandoFirearmProfileResolver.get_hit_feedback_profile(
		weapon_id,
		WEAPON_HIT_FEEDBACK,
		HIT_FEEDBACK_PROFILE_OVERRIDES
	)
	var combat_result: Dictionary = _apply_weapon_hit_result(weapon_id, projectile, context, deps)
	CommandoFirearmPendingResultState.queue_runtime_combat_result(self, combat_result)
	var lingering_result: Dictionary = {}
	if weapon_id == "suicide_drone":
		lingering_result = CommandoFirearmSuicideDroneState.trigger_active_item_fire_zone(projectile, deps)
		if lingering_result.is_empty():
			lingering_result = _spawn_lingering_effect(weapon_id, projectile, context)
	else:
		lingering_result = _spawn_lingering_effect(weapon_id, projectile, context)
	if not lingering_result.is_empty():
		combat_result["lingering_effect"] = lingering_result
	CommandoFirearmProjectileImpactState.append_runtime_boss_hit(
		hit_events,
		projectile,
		weapon_id,
		feedback_profile,
		combat_result,
		context,
		deps,
		BASE_WEAPON_ID,
		HIT_EVENT_LIMIT
	)


func _apply_weapon_hit_result(weapon_id: String, projectile: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	var hit_result_state: Dictionary = CommandoFirearmHitResultState.build_runtime_weapon_hit_result(
		weapon_id,
		projectile,
		context,
		deps,
		WEAPON_HIT_RESULTS,
		HIT_RESULT_PROFILE_OVERRIDES,
		BASE_WEAPON_ID,
		SLINGSHOT_STUN_MULT,
		SLINGSHOT_KNOCKBACK_MULT,
		pistol_boss_hit_count,
		pistol_feedbacks,
		DOPING_POTION_HEAD_LEG_MULTIPLIER,
		PISTOL_HEAD_SHOT_CHANCE,
		PISTOL_LEG_SHOT_CHANCE,
		PISTOL_HIT_TUNING,
		Vector2(FIELD_WIDTH, FIELD_HEIGHT),
		PISTOL_HIT_TEXT_TIMER_FRAMES,
		"헤드샷!",
		"레그샷!",
		PISTOL_FEEDBACK_LIMIT,
		ak47_boss_hit_count,
		AK47_BOSS_DAMAGE_HIT_THRESHOLD
	)
	pistol_boss_hit_count = int(hit_result_state.get("next_pistol_hit_count", pistol_boss_hit_count))
	ak47_boss_hit_count = int(hit_result_state.get("next_ak47_hit_count", ak47_boss_hit_count))
	return CommandoFirearmValueUtils.get_dict(hit_result_state.get("result", {}))


func _spawn_lingering_effect(weapon_id: String, projectile: Dictionary, context: Dictionary) -> Dictionary:
	var profile: Dictionary = CommandoFirearmProfileResolver.get_lingering_effect_profile(
		weapon_id,
		WEAPON_LINGERING_EFFECTS
	)
	if profile.is_empty():
		return {}
	return CommandoFirearmLingeringEffectState.append_runtime_spawn_effect(
		lingering_effects,
		self,
		weapon_id,
		profile,
		projectile,
		context,
		Vector2(FIELD_WIDTH, FIELD_HEIGHT),
		NET_GUN_WIDTH,
		NET_GUN_HEIGHT,
		NET_GUN_MIN_HEIGHT,
		NET_GUN_DISSOLVE_FRAMES,
		NET_GUN_DASH_BREAK_FRAMES,
		NET_GUN_PLAYER_SLOW_MULTIPLIER,
		COMMANDO_NET_GUN_FIRE_MUZZLE_SOURCE,
		COMMANDO_FIRE_SHEET_SOURCE_CELL_SIZE,
		COMMANDO_FIRE_SHEET_PLAYER_FOOT_Y_OFFSET,
		LINGERING_STATUS_DEFAULT_DURATION_FRAMES,
		LINGERING_STATUS_DEFAULT_INTERVAL_FRAMES,
		LINGERING_STATUS_INITIAL_COOLDOWN_FRAMES,
		LINGERING_STATUS_DEFAULT_SLOW_MULTIPLIER,
		LINGERING_EFFECT_LIMIT
	)


func _update_lingering_effects(fps_scale: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	var step: float = CommandoFirearmLingeringEffectState.get_timer_step(fps_scale)
	var result: Dictionary = {}
	var dash_trigger_result: Dictionary = CommandoFirearmLingeringNetFieldState.apply_dash_break_if_triggered(
		lingering_effects,
		context,
		deps,
		net_gun_last_dash_active,
		NET_GUN_DASH_BREAK_FRAMES
	)
	net_gun_last_dash_active = bool(dash_trigger_result.get("dash_active", false))
	for index in range(lingering_effects.size() - 1, -1, -1):
		var effect: Dictionary = CommandoFirearmValueUtils.get_dict(lingering_effects[index])
		CommandoFirearmLingeringEffectState.advance_timers(effect, step, LINGERING_EFFECT_PHASE_STEP)
		CommandoFirearmLingeringFireFlameState.update_effect_flames(effect, step)
		if CommandoFirearmLingeringEffectState.is_active(effect):
			_apply_active_lingering_effect(index, effect, step, context, deps, result)
		else:
			lingering_effects.remove_at(index)
	return result


func _apply_active_lingering_effect(
	index: int,
	effect: Dictionary,
	timer_step: float,
	context: Dictionary,
	deps: Dictionary,
	result: Dictionary
) -> void:
	var clamp_result: Dictionary = CommandoFirearmLingeringEffectState.apply_active_effect(
		effect,
		context,
		deps,
		timer_step,
		Vector2(FIELD_WIDTH, FIELD_HEIGHT),
		COMMANDO_NET_GUN_FIRE_MUZZLE_SOURCE,
		COMMANDO_FIRE_SHEET_SOURCE_CELL_SIZE,
		COMMANDO_FIRE_SHEET_PLAYER_FOOT_Y_OFFSET,
		NET_GUN_WIDTH,
		NET_GUN_MIN_HEIGHT,
		LINGERING_STATUS_TARGET,
		LINGERING_STATUS_ID_SLOW,
		LINGERING_STATUS_DEFAULT_DURATION_FRAMES,
		LINGERING_STATUS_DEFAULT_INTERVAL_FRAMES,
		LINGERING_STATUS_DEFAULT_SLOW_MULTIPLIER,
		LINGERING_STATUS_MIN_SLOW_MULTIPLIER,
		LINGERING_STATUS_MAX_SLOW_MULTIPLIER,
		LINGERING_STATUS_DEFAULT_SOURCE
	)
	CommandoFirearmLingeringEffectState.merge_clamp_result(result, context, clamp_result)
	lingering_effects[index] = effect
