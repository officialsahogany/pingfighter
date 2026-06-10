extends RefCounted

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const CommandoFirearmAk47InputState := preload("res://scripts/characters/commando_firearm_ak47_input_state.gd")
const CommandoFirearmAmmoWeaponInputState := preload("res://scripts/characters/commando_firearm_ammo_weapon_input_state.gd")
const CommandoFirearmAudioDispatcher := preload("res://scripts/characters/commando_firearm_audio_dispatcher.gd")
const CommandoFirearmBowlingTrapGeometry := preload("res://scripts/characters/commando_firearm_bowling_trap_geometry.gd")
const CommandoFirearmBowlingTrapGuardState := preload("res://scripts/characters/commando_firearm_bowling_trap_guard_state.gd")
const CommandoFirearmControlState := preload("res://scripts/characters/commando_firearm_control_state.gd")
const CommandoFirearmCooldownState := preload("res://scripts/characters/commando_firearm_cooldown_state.gd")
const CommandoFirearmDrawStateResolver := preload("res://scripts/characters/commando_firearm_draw_state_resolver.gd")
const CommandoFirearmEffectUpdateState := preload("res://scripts/characters/commando_firearm_effect_update_state.gd")
const CommandoFirearmFireResultState := preload("res://scripts/characters/commando_firearm_fire_result_state.gd")
const CommandoFirearmFireSpawnState := preload("res://scripts/characters/commando_firearm_fire_spawn_state.gd")
const CommandoFirearmInputResolver := preload("res://scripts/characters/commando_firearm_input_resolver.gd")
const CommandoFirearmLingeringEffectState := preload("res://scripts/characters/commando_firearm_lingering_effect_state.gd")
const CommandoFirearmLingeringNetFieldState := preload("res://scripts/characters/commando_firearm_lingering_net_field_state.gd")
const CommandoFirearmPistolInputState := preload("res://scripts/characters/commando_firearm_pistol_input_state.gd")
const CommandoFirearmProfileResolver := preload("res://scripts/characters/commando_firearm_profile_resolver.gd")
const CommandoFirearmProjectileImpactState := preload("res://scripts/characters/commando_firearm_projectile_impact_state.gd")
const CommandoFirearmProjectileMotionState := preload("res://scripts/characters/commando_firearm_projectile_motion_state.gd")
const CommandoFirearmSlingshotState := preload("res://scripts/characters/commando_firearm_slingshot_state.gd")
const CommandoFirearmSupportAircraftGeometry := preload("res://scripts/characters/commando_firearm_support_aircraft_geometry.gd")
const CommandoFirearmSupportCallResolver := preload("res://scripts/characters/commando_firearm_support_call_resolver.gd")
const CommandoFirearmSuicideDroneState := preload("res://scripts/characters/commando_firearm_suicide_drone_state.gd")
const CommandoFirearmTimerState := preload("res://scripts/characters/commando_firearm_timer_state.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")
const GrenadeExplosionDrawer := preload("res://scripts/effects/grenade_explosion_drawer.gd")

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
const BOWLING_TRAP_GUARD_KNOCKBACK_POWER := ActiveItemThrowController.DYNAMITE_BOSS_KNOCKBACK_POWER
const BOWLING_TRAP_GUARD_STUN_FRAMES := 60.0
const BOWLING_TRAP_GUARD_KNOCKBACK_FRAMES := ActiveItemThrowController.DYNAMITE_BOSS_KNOCKBACK_FRAMES
const BOWLING_TRAP_GUARD_SPEED_REDUCTION := 0.7
const BOWLING_TRAP_GUARD_KNOCKBACK_DECAY := ActiveItemThrowController.GRENADE_BOSS_KNOCKBACK_DECAY
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
const PISTOL_AMMO_MAX := 5
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
const AK47_AMMO_MAX := 90
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
const AK47_BOSS_KNOCKBACK_POWER := 8.0
const AK47_BOSS_KNOCKBACK_VELOCITY_SCALE := 0.10
const AK47_BOSS_KNOCKBACK_FRAMES := 3.0
const AK47_BOSS_KNOCKBACK_DECAY_PER_FRAME := 0.72
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
const NET_GUN_AMMO_MAX := 4
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
const SUICIDE_DRONE_KNOCKBACK_POWER := 12.0
const SUICIDE_DRONE_KNOCKBACK_FRAMES := PISTOL_BOSS_KNOCKBACK_FRAMES
const SUICIDE_DRONE_KNOCKBACK_DECAY_PER_FRAME := PISTOL_BOSS_KNOCKBACK_DECAY_PER_FRAME

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
		"stun_frames": 12.0,
		"knockback_power": AK47_BOSS_KNOCKBACK_POWER,
		"knockback_velocity_scale": AK47_BOSS_KNOCKBACK_VELOCITY_SCALE,
		"knockback_frames": AK47_BOSS_KNOCKBACK_FRAMES,
		"knockback_decay_per_frame": AK47_BOSS_KNOCKBACK_DECAY_PER_FRAME,
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
		"knockback_power": SUICIDE_DRONE_KNOCKBACK_POWER,
		"knockback_frames": SUICIDE_DRONE_KNOCKBACK_FRAMES,
		"knockback_decay_per_frame": SUICIDE_DRONE_KNOCKBACK_DECAY_PER_FRAME,
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
	var timed_result: Dictionary = CommandoFirearmTimerState.advance_runtime_firearm_timers(
		self,
		config,
		deps,
		1.0,
		AK47_RECOIL_RECOVERY_PER_FRAME,
		PISTOL_PENDING_FIRE_GEOMETRY_KEYS,
		BASE_WEAPON_ID,
		PISTOL_POST_FIRE_ANIMATION_FRAMES
	)
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
	return CommandoFirearmEffectUpdateState.advance_runtime_effects(
		self,
		fps_scale,
		context,
		deps,
		{
			"weapon_profiles": WEAPON_PROFILES,
			"weapon_profile_overrides": WEAPON_PROFILE_OVERRIDES,
			"weapon_hit_feedback": WEAPON_HIT_FEEDBACK,
			"hit_feedback_profile_overrides": HIT_FEEDBACK_PROFILE_OVERRIDES,
			"base_weapon_id": BASE_WEAPON_ID,
			"field_width": FIELD_WIDTH,
			"field_height": FIELD_HEIGHT,
			"support_aircraft_start_x": SUPPORT_AIRCRAFT_START_X,
			"support_aircraft_y": SUPPORT_AIRCRAFT_Y,
			"support_aircraft_speed": SUPPORT_AIRCRAFT_SPEED,
			"support_bomb_interval_frames": SUPPORT_BOMB_INTERVAL_FRAMES,
			"support_aircraft_finish_margin": SUPPORT_AIRCRAFT_FINISH_MARGIN,
			"support_aircraft_curve_amplitude": SUPPORT_AIRCRAFT_CURVE_AMPLITUDE,
			"support_aircraft_curve_frequency": SUPPORT_AIRCRAFT_CURVE_FREQUENCY,
			"support_aircraft_curve_secondary_ratio": SUPPORT_AIRCRAFT_CURVE_SECONDARY_RATIO,
			"support_bomb_initial_vy": SUPPORT_BOMB_INITIAL_VY,
			"support_bomb_gravity": SUPPORT_BOMB_GRAVITY,
			"support_bomb_horizontal_jitter": SUPPORT_BOMB_HORIZONTAL_JITTER,
			"support_opponent_wall_y": SUPPORT_OPPONENT_WALL_Y,
			"support_missile_flight_frames": SUPPORT_MISSILE_FLIGHT_FRAMES,
			"support_missile_life_frames": SUPPORT_MISSILE_LIFE_FRAMES,
			"support_bomb_random_x_range": SUPPORT_BOMB_RANDOM_X_RANGE,
			"projectile_limit": PROJECTILE_LIMIT,
			"grenade_explosion_duration_frames": float(GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_DURATION_FRAMES),
			"flash_limit": FLASH_LIMIT,
			"bowling_trap_install_frames": BOWLING_TRAP_INSTALL_FRAMES,
			"bowling_trap_capture_frames": BOWLING_TRAP_CAPTURE_FRAMES,
			"bowling_trap_capture_ball_offset": BOWLING_TRAP_CAPTURE_BALL_OFFSET,
			"bowling_trap_height": BOWLING_TRAP_HEIGHT,
			"bowling_trap_capture_height": BOWLING_TRAP_CAPTURE_HEIGHT,
			"bowling_trap_width": BOWLING_TRAP_WIDTH,
			"trap_launch_speed_multiplier": BOWLING_TRAP_LAUNCH_SPEED_MULTIPLIER,
			"trap_launch_angle_step": BOWLING_TRAP_LAUNCH_ANGLE_STEP,
			"bowling_trap_guard_speed_reduction": BOWLING_TRAP_GUARD_SPEED_REDUCTION,
			"bowling_trap_guard_knockback_power": BOWLING_TRAP_GUARD_KNOCKBACK_POWER,
			"bowling_trap_guard_stun_frames": BOWLING_TRAP_GUARD_STUN_FRAMES,
			"pistol_wall_bounce_margin": PISTOL_WALL_BOUNCE_MARGIN,
			"pistol_wall_bounce_max": PISTOL_WALL_BOUNCE_MAX,
			"pistol_wall_bounce_damping": PISTOL_WALL_BOUNCE_DAMPING,
			"bazooka_acceleration": BAZOOKA_ACCELERATION,
			"bazooka_max_speed": BAZOOKA_MAX_SPEED,
			"bazooka_smoke_trail_limit": BAZOOKA_SMOKE_TRAIL_LIMIT,
			"net_gun_muzzle_source": COMMANDO_NET_GUN_FIRE_MUZZLE_SOURCE,
			"fire_sheet_source_cell_size": COMMANDO_FIRE_SHEET_SOURCE_CELL_SIZE,
			"fire_sheet_player_foot_y_offset": COMMANDO_FIRE_SHEET_PLAYER_FOOT_Y_OFFSET,
			"net_gun_rope_trail_limit": NET_GUN_ROPE_TRAIL_LIMIT,
			"suicide_drone_size": SUICIDE_DRONE_SIZE,
			"suicide_drone_rotor_base_speed": SUICIDE_DRONE_ROTOR_BASE_SPEED,
			"suicide_drone_cooldown_frames": SUICIDE_DRONE_COOLDOWN_FRAMES,
			"suicide_drone_ball_speed_multiplier": SUICIDE_DRONE_BALL_SPEED_MULTIPLIER,
			"suicide_drone_ball_fan_degrees": SUICIDE_DRONE_BALL_FAN_DEGREES,
			"ak47_shell_gravity": AK47_SHELL_GRAVITY,
			"ak47_shell_bounce_decay": AK47_SHELL_BOUNCE_DECAY,
			"ak47_shell_max_bounces": AK47_SHELL_MAX_BOUNCES,
			"net_gun_dash_break_frames": NET_GUN_DASH_BREAK_FRAMES,
			"lingering_effect_phase_step": LINGERING_EFFECT_PHASE_STEP,
			"net_gun_width": NET_GUN_WIDTH,
			"net_gun_min_height": NET_GUN_MIN_HEIGHT,
			"lingering_status_target": LINGERING_STATUS_TARGET,
			"lingering_status_id_slow": LINGERING_STATUS_ID_SLOW,
			"lingering_status_duration_frames": LINGERING_STATUS_DEFAULT_DURATION_FRAMES,
			"lingering_status_interval_frames": LINGERING_STATUS_DEFAULT_INTERVAL_FRAMES,
			"lingering_status_slow_multiplier": LINGERING_STATUS_DEFAULT_SLOW_MULTIPLIER,
			"lingering_status_min_slow_multiplier": LINGERING_STATUS_MIN_SLOW_MULTIPLIER,
			"lingering_status_max_slow_multiplier": LINGERING_STATUS_MAX_SLOW_MULTIPLIER,
			"lingering_status_source": LINGERING_STATUS_DEFAULT_SOURCE,
		}
	)


func get_recent_hit_events() -> Array:
	return hit_events.duplicate(true)


func get_actor_draw_context() -> Dictionary:
	return CommandoFirearmDrawStateResolver.build_runtime_draw_context(
		self,
		DRAW_CONTEXT_TIMING,
		get_movement_speed_multiplier()
	)


func _update_pistol_input(
	input_snapshot: Dictionary,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	current_weapon: Dictionary,
	now_msec: int
) -> Dictionary:
	return CommandoFirearmPistolInputState.update_runtime_input(
		self,
		input_snapshot,
		special_gauge,
		config,
		deps,
		current_weapon,
		now_msec,
		{
			"base_weapon_id": BASE_WEAPON_ID,
			"commando_pistol_weapon_id": "commando_pistol",
			"switch_fire_suppress_msec": SWITCH_FIRE_SUPPRESS_MSEC,
			"doping_potion_defaults": DOPING_POTION_DEFAULTS,
			"pistol_ammo_max": PISTOL_AMMO_MAX,
			"pistol_cooldown_frames": PISTOL_COOLDOWN_FRAMES,
			"beretta_cooldown_frames": BERETTA_COOLDOWN_FRAMES,
			"pistol_control_lock_frames": PISTOL_CONTROL_LOCK_FRAMES,
			"pistol_fire_delay_frames": PISTOL_FIRE_DELAY_FRAMES,
			"pistol_post_fire_animation_frames": PISTOL_POST_FIRE_ANIMATION_FRAMES,
			"commando_pistol_control_lock_frames": 0.0,
			"commando_pistol_fire_delay_frames": 0.0,
			"pistol_empty_reload_gauge_cost": PISTOL_EMPTY_RELOAD_GAUGE_COST,
			"doping_potion_pistol_cooldown_frames": DOPING_POTION_PISTOL_COOLDOWN_FRAMES,
			"doping_potion_pistol_control_lock_frames": DOPING_POTION_PISTOL_CONTROL_LOCK_FRAMES,
		}
	)


func _update_ak47_input(
	input_snapshot: Dictionary,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	current_weapon: Dictionary,
	now_msec: int
) -> Dictionary:
	return CommandoFirearmAk47InputState.update_runtime_input(
		self,
		input_snapshot,
		special_gauge,
		config,
		deps,
		current_weapon,
		now_msec,
		{
			"switch_fire_suppress_msec": SWITCH_FIRE_SUPPRESS_MSEC,
			"weapon_profiles": WEAPON_PROFILES,
			"weapon_profile_overrides": WEAPON_PROFILE_OVERRIDES,
			"doping_potion_defaults": DOPING_POTION_DEFAULTS,
			"doping_fire_rate_multiplier": DOPING_POTION_FIRE_RATE_MULTIPLIER,
			"doping_ak47_fire_interval_frames": DOPING_POTION_AK47_FIRE_INTERVAL_FRAMES,
			"ak47_ammo_max": AK47_AMMO_MAX,
			"ak47_duration_frames": AK47_DURATION_FRAMES,
			"ak47_fire_interval_frames": AK47_FIRE_INTERVAL_FRAMES,
			"ak47_initial_burst_shots": AK47_INITIAL_BURST_SHOTS,
			"ak47_base_spread_radians": AK47_BASE_SPREAD_RADIANS,
			"ak47_recoil_per_shot": AK47_RECOIL_PER_SHOT,
			"ak47_max_recoil": AK47_MAX_RECOIL,
			"ak47_movement_speed_multiplier": AK47_MOVEMENT_SPEED_MULTIPLIER,
		}
	)


func _update_bazooka_input(
	input_snapshot: Dictionary,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	current_weapon: Dictionary,
	now_msec: int
) -> Dictionary:
	return CommandoFirearmAmmoWeaponInputState.update_runtime_bazooka_input(
		self,
		input_snapshot,
		special_gauge,
		config,
		deps,
		current_weapon,
		now_msec,
		{
			"switch_fire_suppress_msec": SWITCH_FIRE_SUPPRESS_MSEC,
			"weapon_profiles": WEAPON_PROFILES,
			"weapon_profile_overrides": WEAPON_PROFILE_OVERRIDES,
			"doping_potion_defaults": DOPING_POTION_DEFAULTS,
			"doping_fire_rate_multiplier": DOPING_POTION_FIRE_RATE_MULTIPLIER,
			"doping_bazooka_cooldown_frames": DOPING_POTION_BAZOOKA_COOLDOWN_FRAMES,
			"doping_bazooka_control_lock_frames": DOPING_POTION_BAZOOKA_CONTROL_LOCK_FRAMES,
			"bazooka_ammo_max": BAZOOKA_AMMO_MAX,
			"bazooka_cooldown_frames": BAZOOKA_COOLDOWN_FRAMES,
			"bazooka_control_lock_frames": BAZOOKA_CONTROL_LOCK_FRAMES,
			"bazooka_fire_animation_frames": BAZOOKA_FIRE_ANIMATION_FRAMES,
			"bazooka_firing_pose_frames": BAZOOKA_FIRING_POSE_FRAMES,
			"bazooka_muzzle_flash_frames": BAZOOKA_MUZZLE_FLASH_FRAMES,
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
	return CommandoFirearmAmmoWeaponInputState.update_runtime_net_gun_input(
		self,
		input_snapshot,
		special_gauge,
		config,
		deps,
		current_weapon,
		now_msec,
		{
			"switch_fire_suppress_msec": SWITCH_FIRE_SUPPRESS_MSEC,
			"weapon_profiles": WEAPON_PROFILES,
			"weapon_profile_overrides": WEAPON_PROFILE_OVERRIDES,
			"net_gun_ammo_max": NET_GUN_AMMO_MAX,
			"net_gun_cooldown_frames": NET_GUN_COOLDOWN_FRAMES,
			"net_gun_control_lock_frames": NET_GUN_CONTROL_LOCK_FRAMES,
			"net_gun_throw_pose_frames": NET_GUN_THROW_POSE_FRAMES,
			"net_gun_harpoon_flash_frames": NET_GUN_HARPOON_FLASH_FRAMES,
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
	return CommandoFirearmAmmoWeaponInputState.update_runtime_bowling_trap_input(
		self,
		input_snapshot,
		special_gauge,
		config,
		deps,
		current_weapon,
		now_msec,
		{
			"switch_fire_suppress_msec": SWITCH_FIRE_SUPPRESS_MSEC,
			"weapon_profiles": WEAPON_PROFILES,
			"weapon_profile_overrides": WEAPON_PROFILE_OVERRIDES,
			"field_width": FIELD_WIDTH,
			"field_height": FIELD_HEIGHT,
			"bowling_trap_min_field_y_ratio": BOWLING_TRAP_MIN_FIELD_Y_RATIO,
			"bowling_trap_ammo_max": BOWLING_TRAP_AMMO_MAX,
			"bowling_trap_cooldown_frames": BOWLING_TRAP_COOLDOWN_FRAMES,
			"bowling_trap_control_lock_frames": BOWLING_TRAP_CONTROL_LOCK_FRAMES,
			"bowling_trap_install_frames": BOWLING_TRAP_INSTALL_FRAMES,
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
	return CommandoFirearmSuicideDroneState.update_runtime_input(
		self,
		input_snapshot,
		special_gauge,
		config,
		deps,
		current_weapon,
		now_msec,
		{
			"switch_fire_suppress_msec": SWITCH_FIRE_SUPPRESS_MSEC,
			"weapon_profiles": WEAPON_PROFILES,
			"weapon_profile_overrides": WEAPON_PROFILE_OVERRIDES,
			"field_width": FIELD_WIDTH,
			"field_height": FIELD_HEIGHT,
			"fire_sheet_default_frames": COMMANDO_WEAPON_FIRE_SHEET_DEFAULT_FRAMES,
			"fire_sheet_long_frames": COMMANDO_WEAPON_FIRE_SHEET_LONG_FRAMES,
			"fire_sheet_frame_count": COMMANDO_WEAPON_FIRE_SHEET_FRAME_COUNT,
			"suicide_drone_ammo_max": SUICIDE_DRONE_AMMO_MAX,
			"suicide_drone_grace_frames": SUICIDE_DRONE_GRACE_FRAMES,
			"suicide_drone_accel": SUICIDE_DRONE_ACCEL,
			"suicide_drone_max_speed": SUICIDE_DRONE_MAX_SPEED,
			"suicide_drone_size": SUICIDE_DRONE_SIZE,
			"suicide_drone_rotor_base_speed": SUICIDE_DRONE_ROTOR_BASE_SPEED,
			"suicide_drone_life_frames": SUICIDE_DRONE_LIFE_FRAMES,
			"projectile_limit": PROJECTILE_LIMIT,
			"flash_limit": FLASH_LIMIT,
		}
	)


func _update_active_suicide_drone_input(
	input_snapshot: Dictionary,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	return CommandoFirearmSuicideDroneState.update_runtime_active_input(
		self,
		input_snapshot,
		special_gauge,
		config,
		deps,
		{
			"weapon_profiles": WEAPON_PROFILES,
			"weapon_profile_overrides": WEAPON_PROFILE_OVERRIDES,
			"weapon_hit_feedback": WEAPON_HIT_FEEDBACK,
			"hit_feedback_profile_overrides": HIT_FEEDBACK_PROFILE_OVERRIDES,
			"base_weapon_id": BASE_WEAPON_ID,
			"field_width": FIELD_WIDTH,
			"suicide_drone_accel": SUICIDE_DRONE_ACCEL,
			"suicide_drone_max_speed": SUICIDE_DRONE_MAX_SPEED,
			"suicide_drone_rotor_base_speed": SUICIDE_DRONE_ROTOR_BASE_SPEED,
			"suicide_drone_rotor_speed_scale": SUICIDE_DRONE_ROTOR_SPEED_SCALE,
			"suicide_drone_cooldown_frames": SUICIDE_DRONE_COOLDOWN_FRAMES,
			"suicide_drone_ball_speed_multiplier": SUICIDE_DRONE_BALL_SPEED_MULTIPLIER,
			"suicide_drone_ball_fan_degrees": SUICIDE_DRONE_BALL_FAN_DEGREES,
			"grenade_explosion_duration_frames": float(GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_DURATION_FRAMES),
			"flash_limit": FLASH_LIMIT,
		}
	)


func _spawn_firearm_effect(weapon_id: String, config: Dictionary, deps: Dictionary, profile_override: Dictionary = {}) -> void:
	CommandoFirearmFireSpawnState.spawn_runtime_firearm_effect(
		self,
		weapon_id,
		config,
		deps,
		profile_override,
		{
			"weapon_profiles": WEAPON_PROFILES,
			"weapon_profile_overrides": WEAPON_PROFILE_OVERRIDES,
			"doping_potion_defaults": DOPING_POTION_DEFAULTS,
			"base_weapon_id": BASE_WEAPON_ID,
			"field_width": FIELD_WIDTH,
			"field_height": FIELD_HEIGHT,
			"fire_sheet_default_frames": COMMANDO_WEAPON_FIRE_SHEET_DEFAULT_FRAMES,
			"fire_sheet_long_frames": COMMANDO_WEAPON_FIRE_SHEET_LONG_FRAMES,
			"fire_sheet_frame_count": COMMANDO_WEAPON_FIRE_SHEET_FRAME_COUNT,
			"fire_sheet_source_cell_size": COMMANDO_FIRE_SHEET_SOURCE_CELL_SIZE,
			"fire_sheet_player_foot_y_offset": COMMANDO_FIRE_SHEET_PLAYER_FOOT_Y_OFFSET,
			"pistol_muzzle_source": COMMANDO_PISTOL_FIRE_MUZZLE_SOURCE,
			"bazooka_muzzle_source": COMMANDO_BAZOOKA_FIRE_MUZZLE_SOURCE,
			"net_gun_muzzle_source": COMMANDO_NET_GUN_FIRE_MUZZLE_SOURCE,
			"pistol_bullet_speed": PISTOL_BULLET_SPEED,
			"doping_potion_head_leg_multiplier": DOPING_POTION_HEAD_LEG_MULTIPLIER,
			"doping_potion_pistol_speed_multiplier": DOPING_POTION_PISTOL_SPEED_MULTIPLIER,
			"pistol_spread_radians": PISTOL_SPREAD_RADIANS,
			"beretta_spread_radians": BERETTA_SPREAD_RADIANS,
			"flash_limit": FLASH_LIMIT,
			"support_call_limit": SUPPORT_CALL_LIMIT,
			"support_call_delay_min_frames": SUPPORT_CALL_DELAY_MIN_FRAMES,
			"support_call_delay_max_frames": SUPPORT_CALL_DELAY_MAX_FRAMES,
			"support_bomb_min_count": SUPPORT_BOMB_MIN_COUNT,
			"support_bomb_max_count": SUPPORT_BOMB_MAX_COUNT,
			"support_call_lock_frames": SUPPORT_CALL_LOCK_FRAMES,
			"support_aircraft_drop_arm_frames": SUPPORT_AIRCRAFT_DROP_ARM_FRAMES,
			"support_aircraft_y": SUPPORT_AIRCRAFT_Y,
			"support_aircraft_speed": SUPPORT_AIRCRAFT_SPEED,
			"support_aircraft_curve_amplitude": SUPPORT_AIRCRAFT_CURVE_AMPLITUDE,
			"support_aircraft_curve_frequency": SUPPORT_AIRCRAFT_CURVE_FREQUENCY,
			"support_aircraft_curve_secondary_ratio": SUPPORT_AIRCRAFT_CURVE_SECONDARY_RATIO,
			"support_aircraft_start_x": SUPPORT_AIRCRAFT_START_X,
			"bowling_trap_width": BOWLING_TRAP_WIDTH,
			"bowling_trap_height": BOWLING_TRAP_HEIGHT,
			"bowling_trap_min_field_y_ratio": BOWLING_TRAP_MIN_FIELD_Y_RATIO,
			"bowling_trap_install_frames": BOWLING_TRAP_INSTALL_FRAMES,
			"bowling_trap_capture_ball_offset": BOWLING_TRAP_CAPTURE_BALL_OFFSET,
			"bowling_trap_limit": BOWLING_TRAP_LIMIT,
			"default_projectile_speed": 16.0,
			"bazooka_smoke_trail_limit": BAZOOKA_SMOKE_TRAIL_LIMIT,
			"net_gun_rope_trail_limit": NET_GUN_ROPE_TRAIL_LIMIT,
			"projectile_limit": PROJECTILE_LIMIT,
			"ak47_shell_lifetime_frames": AK47_SHELL_LIFETIME_FRAMES,
			"pistol_shell_lifetime_frames": PISTOL_SHELL_LIFETIME_FRAMES,
			"shell_casing_limit": SHELL_CASING_LIMIT,
		}
	)


func _update_projectiles(fps_scale: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	return CommandoFirearmProjectileMotionState.advance_runtime_projectiles(
		projectiles,
		impact_flashes,
		self,
		fps_scale,
		context,
		deps,
		{
			"weapon_profiles": WEAPON_PROFILES,
			"weapon_profile_overrides": WEAPON_PROFILE_OVERRIDES,
			"weapon_hit_feedback": WEAPON_HIT_FEEDBACK,
			"hit_feedback_profile_overrides": HIT_FEEDBACK_PROFILE_OVERRIDES,
			"base_weapon_id": BASE_WEAPON_ID,
			"field_width": FIELD_WIDTH,
			"field_height": FIELD_HEIGHT,
			"pistol_wall_bounce_margin": PISTOL_WALL_BOUNCE_MARGIN,
			"pistol_wall_bounce_max": PISTOL_WALL_BOUNCE_MAX,
			"pistol_wall_bounce_damping": PISTOL_WALL_BOUNCE_DAMPING,
			"bazooka_acceleration": BAZOOKA_ACCELERATION,
			"bazooka_max_speed": BAZOOKA_MAX_SPEED,
			"bazooka_smoke_trail_limit": BAZOOKA_SMOKE_TRAIL_LIMIT,
			"net_gun_muzzle_source": COMMANDO_NET_GUN_FIRE_MUZZLE_SOURCE,
			"fire_sheet_source_cell_size": COMMANDO_FIRE_SHEET_SOURCE_CELL_SIZE,
			"fire_sheet_player_foot_y_offset": COMMANDO_FIRE_SHEET_PLAYER_FOOT_Y_OFFSET,
			"net_gun_rope_trail_limit": NET_GUN_ROPE_TRAIL_LIMIT,
			"suicide_drone_size": SUICIDE_DRONE_SIZE,
			"suicide_drone_rotor_base_speed": SUICIDE_DRONE_ROTOR_BASE_SPEED,
			"suicide_drone_cooldown_frames": SUICIDE_DRONE_COOLDOWN_FRAMES,
			"suicide_drone_ball_speed_multiplier": SUICIDE_DRONE_BALL_SPEED_MULTIPLIER,
			"suicide_drone_ball_fan_degrees": SUICIDE_DRONE_BALL_FAN_DEGREES,
			"grenade_explosion_duration_frames": float(GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_DURATION_FRAMES),
			"flash_limit": FLASH_LIMIT,
		}
	)


func _register_projectile_hit(projectile: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	CommandoFirearmProjectileImpactState.register_runtime_projectile_hit(
		self,
		projectile,
		context,
		deps,
		{
			"weapon_hit_feedback": WEAPON_HIT_FEEDBACK,
			"hit_feedback_profile_overrides": HIT_FEEDBACK_PROFILE_OVERRIDES,
			"weapon_hit_results": WEAPON_HIT_RESULTS,
			"hit_result_profile_overrides": HIT_RESULT_PROFILE_OVERRIDES,
			"base_weapon_id": BASE_WEAPON_ID,
			"slingshot_stun_multipliers": SLINGSHOT_STUN_MULT,
			"slingshot_knockback_multipliers": SLINGSHOT_KNOCKBACK_MULT,
			"doping_potion_head_leg_multiplier": DOPING_POTION_HEAD_LEG_MULTIPLIER,
			"pistol_head_shot_chance": PISTOL_HEAD_SHOT_CHANCE,
			"pistol_leg_shot_chance": PISTOL_LEG_SHOT_CHANCE,
			"pistol_hit_tuning": PISTOL_HIT_TUNING,
			"field_width": FIELD_WIDTH,
			"field_height": FIELD_HEIGHT,
			"pistol_hit_text_timer_frames": PISTOL_HIT_TEXT_TIMER_FRAMES,
			"pistol_head_shot_label": "헤드샷!",
			"pistol_leg_shot_label": "레그샷!",
			"pistol_feedback_limit": PISTOL_FEEDBACK_LIMIT,
			"ak47_boss_damage_hit_threshold": AK47_BOSS_DAMAGE_HIT_THRESHOLD,
			"hit_event_limit": HIT_EVENT_LIMIT,
		}
	)


func _spawn_lingering_effect(weapon_id: String, projectile: Dictionary, context: Dictionary) -> Dictionary:
	return CommandoFirearmLingeringEffectState.spawn_runtime_lingering_effect(
		self,
		weapon_id,
		projectile,
		context,
		{
			"weapon_lingering_effects": WEAPON_LINGERING_EFFECTS,
			"field_width": FIELD_WIDTH,
			"field_height": FIELD_HEIGHT,
			"net_gun_width": NET_GUN_WIDTH,
			"net_gun_height": NET_GUN_HEIGHT,
			"net_gun_min_height": NET_GUN_MIN_HEIGHT,
			"net_gun_dissolve_frames": NET_GUN_DISSOLVE_FRAMES,
			"net_gun_dash_break_frames": NET_GUN_DASH_BREAK_FRAMES,
			"net_gun_player_slow_multiplier": NET_GUN_PLAYER_SLOW_MULTIPLIER,
			"net_gun_muzzle_source": COMMANDO_NET_GUN_FIRE_MUZZLE_SOURCE,
			"fire_sheet_source_cell_size": COMMANDO_FIRE_SHEET_SOURCE_CELL_SIZE,
			"fire_sheet_player_foot_y_offset": COMMANDO_FIRE_SHEET_PLAYER_FOOT_Y_OFFSET,
			"status_duration_frames": LINGERING_STATUS_DEFAULT_DURATION_FRAMES,
			"status_interval_frames": LINGERING_STATUS_DEFAULT_INTERVAL_FRAMES,
			"status_initial_cooldown_frames": LINGERING_STATUS_INITIAL_COOLDOWN_FRAMES,
			"status_slow_multiplier": LINGERING_STATUS_DEFAULT_SLOW_MULTIPLIER,
			"effect_limit": LINGERING_EFFECT_LIMIT,
		}
	)
