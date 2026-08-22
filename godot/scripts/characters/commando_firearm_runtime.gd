extends RefCounted

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const RuntimePerkModalTimeShift := preload("res://scripts/core/runtime_perk_modal_time_shift.gd")
const CommandoFirearmAk47InputState := preload("res://scripts/characters/commando_firearm_ak47_input_state.gd")
const CommandoFirearmAmmoWeaponInputState := preload("res://scripts/characters/commando_firearm_ammo_weapon_input_state.gd")
const CommandoFirearmAudioDispatcher := preload("res://scripts/characters/commando_firearm_audio_dispatcher.gd")
const CommandoFirearmBowlingTrapGuardState := preload("res://scripts/characters/commando_firearm_bowling_trap_guard_state.gd")
const CommandoFirearmControlState := preload("res://scripts/characters/commando_firearm_control_state.gd")
const CommandoFirearmDrawStateResolver := preload("res://scripts/characters/commando_firearm_draw_state_resolver.gd")
const CommandoFirearmEffectUpdateState := preload("res://scripts/characters/commando_firearm_effect_update_state.gd")
const CommandoFirearmFireResultState := preload("res://scripts/characters/commando_firearm_fire_result_state.gd")
const CommandoFirearmFireSpawnState := preload("res://scripts/characters/commando_firearm_fire_spawn_state.gd")
const CommandoFirearmLingeringEffectState := preload("res://scripts/characters/commando_firearm_lingering_effect_state.gd")
const CommandoFirearmLingeringNetFieldState := preload("res://scripts/characters/commando_firearm_lingering_net_field_state.gd")
const CommandoFirearmPistolInputState := preload("res://scripts/characters/commando_firearm_pistol_input_state.gd")
const CommandoFirearmPistolEnhanceState := preload("res://scripts/characters/commando_firearm_pistol_enhance_state.gd")
const CommandoFirearmProfileCatalog := preload("res://scripts/characters/commando_firearm_profile_catalog.gd")
const CommandoFirearmProfileResolver := preload("res://scripts/characters/commando_firearm_profile_resolver.gd")
const CommandoFirearmProjectileImpactState := preload("res://scripts/characters/commando_firearm_projectile_impact_state.gd")
const CommandoFirearmProjectileMotionState := preload("res://scripts/characters/commando_firearm_projectile_motion_state.gd")
const CommandoFirearmRuntimeLifecycleState := preload("res://scripts/characters/commando_firearm_runtime_lifecycle_state.gd")
const CommandoFirearmRuntimeConfigCatalog := preload("res://scripts/characters/commando_firearm_runtime_config_catalog.gd")
const CommandoFirearmSlingshotState := preload("res://scripts/characters/commando_firearm_slingshot_state.gd")
const CommandoFirearmSupportAircraftGeometry := preload("res://scripts/characters/commando_firearm_support_aircraft_geometry.gd")
const CommandoFirearmSupportCallResolver := preload("res://scripts/characters/commando_firearm_support_call_resolver.gd")
const CommandoFirearmSuicideDroneState := preload("res://scripts/characters/commando_firearm_suicide_drone_state.gd")
const CommandoFirearmTimerState := preload("res://scripts/characters/commando_firearm_timer_state.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")
const GrenadeExplosionDrawer := preload("res://scripts/effects/grenade_explosion_drawer.gd")
const RuntimePerkProgression := preload("res://scripts/characters/runtime_perk_progression.gd")

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
# Launch fan: the captured ball is fired upward (toward the boss) at a RANDOM angle within
# +/-40 deg of vertical. At capture, launch_direction is rolled as a continuous random
# multiplier in [-1, 1] (roll_launch_direction); at release launch_angle = -90deg +
# direction * this half-angle. Was PI/8 (22.5 deg, discrete -1/0/1) before the +/-40 deg
# random-fan change.
const BOWLING_TRAP_LAUNCH_FAN_HALF_ANGLE := PI * 40.0 / 180.0
const BOWLING_TRAP_MIN_FIELD_Y_RATIO := 0.6
# Intentional +30% buff over Python parity (per design request): base = item_effects/
# bowling_trap.py KNOCKBACK_POWER 22.0 ("라그나로크 수준의 긴 넉백"), now 22.0 * 1.3 = 28.6
# for ~30% more boss travel (~146px -> ~190px at 60fps with 0.85 decay; distance scales
# linearly with initial knockback velocity). This deliberately exceeds the Python source value.
# Do NOT reuse DYNAMITE_BOSS_KNOCKBACK_POWER (104.0): that launched the boss ~660-780px (the
# full field width) so the guard hit slammed the boss all the way into the wall.
const BOWLING_TRAP_GUARD_KNOCKBACK_POWER := 28.6
# 2.5초 스턴. Python 원본 item_effects/bowling_trap.py STUN_DURATION=60f(1초)에서
# 의도적 상향(포팅 패리티 이탈). SEC*60 형태는 horn_strawberry / lingpet 스턴 상수 관례와 동일.
const BOWLING_TRAP_GUARD_STUN_SEC := 2.5
const BOWLING_TRAP_GUARD_STUN_FRAMES := BOWLING_TRAP_GUARD_STUN_SEC * 60.0
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
const PISTOL_ENHANCE_PERK_ID := "pistol_enhance"


static func _build_pistol_enhance_spread_degrees() -> Array:
	var values: Array = [0.0]
	values.append_array(RuntimePerkProgression.get_authored_values_reference(
		PISTOL_ENHANCE_PERK_ID, "spread_degrees"
	))
	return values


static var PISTOL_ENHANCE_SPREAD_DEGREES: Array = _build_pistol_enhance_spread_degrees()
static var PISTOL_ENHANCE_SPEED_BONUS_PER_LEVEL: float = RuntimePerkProgression.get_value(PISTOL_ENHANCE_PERK_ID, "speed_bonus_pct", 1) / 100.0
static var PISTOL_ENHANCE_KNOCKBACK_BONUS_PER_LEVEL: float = RuntimePerkProgression.get_value(PISTOL_ENHANCE_PERK_ID, "knockback_bonus_pct", 1) / 100.0
static var PISTOL_ENHANCE_TUNING: Dictionary = {
	"perk_id": PISTOL_ENHANCE_PERK_ID,
	"base_ammo_max": PISTOL_AMMO_MAX,
	"base_spread_radians": PISTOL_SPREAD_RADIANS,
	"spread_degrees": PISTOL_ENHANCE_SPREAD_DEGREES,
	"speed_bonus_per_level": PISTOL_ENHANCE_SPEED_BONUS_PER_LEVEL,
	"knockback_bonus_per_level": PISTOL_ENHANCE_KNOCKBACK_BONUS_PER_LEVEL,
	"beretta_spread_radians": BERETTA_SPREAD_RADIANS,
}
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
const AK47_BULLET_SPEED := 23.04
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
const RUNTIME_LIFECYCLE_RESET_DEFAULTS := {
	"pistol_cooldown_frames": PISTOL_COOLDOWN_FRAMES,
	"pistol_control_lock_frames": PISTOL_CONTROL_LOCK_FRAMES,
	"ak47_fire_interval_frames": AK47_FIRE_INTERVAL_FRAMES,
	"bazooka_cooldown_frames": BAZOOKA_COOLDOWN_FRAMES,
	"bazooka_control_lock_frames": BAZOOKA_CONTROL_LOCK_FRAMES,
}
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

static var PROFILE_CATALOG: Dictionary = CommandoFirearmProfileCatalog.build_catalog({
	"pistol_bullet_speed": PISTOL_BULLET_SPEED,
	"beretta_bullet_speed": BERETTA_BULLET_SPEED,
	"ak47_bullet_speed": AK47_BULLET_SPEED,
	"ak47_bullet_life_frames": AK47_BULLET_LIFE_FRAMES,
	"bazooka_initial_speed": BAZOOKA_INITIAL_SPEED,
	"bazooka_acceleration": BAZOOKA_ACCELERATION,
	"bazooka_max_speed": BAZOOKA_MAX_SPEED,
	"bazooka_explosion_radius": BAZOOKA_EXPLOSION_RADIUS,
	"bazooka_smoke_trail_limit": BAZOOKA_SMOKE_TRAIL_LIMIT,
	"bazooka_muzzle_flash_frames": BAZOOKA_MUZZLE_FLASH_FRAMES,
	"net_gun_projectile_speed": NET_GUN_PROJECTILE_SPEED,
	"net_gun_rope_trail_limit": NET_GUN_ROPE_TRAIL_LIMIT,
	"net_gun_harpoon_flash_frames": NET_GUN_HARPOON_FLASH_FRAMES,
	"support_bomb_initial_vy": SUPPORT_BOMB_INITIAL_VY,
	"support_bomb_gravity": SUPPORT_BOMB_GRAVITY,
	"support_bomb_horizontal_jitter": SUPPORT_BOMB_HORIZONTAL_JITTER,
	"support_missile_flight_frames": SUPPORT_MISSILE_FLIGHT_FRAMES,
	"support_missile_life_frames": SUPPORT_MISSILE_LIFE_FRAMES,
	"grenade_explosion_radius": ActiveItemThrowController.GRENADE_EXPLOSION_RADIUS,
	"suicide_drone_size": SUICIDE_DRONE_SIZE,
	"suicide_drone_life_frames": SUICIDE_DRONE_LIFE_FRAMES,
	"suicide_drone_max_speed": SUICIDE_DRONE_MAX_SPEED,
	"suicide_drone_accel": SUICIDE_DRONE_ACCEL,
	"pistol_boss_knockback_power": PISTOL_BOSS_KNOCKBACK_POWER,
	"ak47_boss_knockback_power": AK47_BOSS_KNOCKBACK_POWER,
	"ak47_knockback_velocity_scale": AK47_BOSS_KNOCKBACK_VELOCITY_SCALE,
	"ak47_knockback_frames": AK47_BOSS_KNOCKBACK_FRAMES,
	"ak47_knockback_decay_per_frame": AK47_BOSS_KNOCKBACK_DECAY_PER_FRAME,
	"bazooka_stun_frames": BAZOOKA_STUN_FRAMES,
	"bazooka_knockback_power": BAZOOKA_KNOCKBACK_POWER,
	"bazooka_knockback_frames": BAZOOKA_KNOCKBACK_FRAMES,
	"bazooka_knockback_decay_per_frame": BAZOOKA_KNOCKBACK_DECAY_PER_FRAME,
	"grenade_boss_stun_frames": ActiveItemThrowController.GRENADE_BOSS_STUN_FRAMES,
	"grenade_boss_knockback_power": ActiveItemThrowController.GRENADE_BOSS_KNOCKBACK_POWER,
	"grenade_boss_knockback_frames": ActiveItemThrowController.GRENADE_BOSS_KNOCKBACK_FRAMES,
	"grenade_boss_knockback_decay": ActiveItemThrowController.GRENADE_BOSS_KNOCKBACK_DECAY,
	"suicide_drone_knockback_power": SUICIDE_DRONE_KNOCKBACK_POWER,
	"suicide_drone_knockback_frames": SUICIDE_DRONE_KNOCKBACK_FRAMES,
	"suicide_drone_knockback_decay_per_frame": SUICIDE_DRONE_KNOCKBACK_DECAY_PER_FRAME,
	"net_gun_field_duration_frames": NET_GUN_FIELD_DURATION_FRAMES,
	"net_gun_dissolve_frames": NET_GUN_DISSOLVE_FRAMES,
	"net_gun_dash_break_frames": NET_GUN_DASH_BREAK_FRAMES,
	"net_gun_width": NET_GUN_WIDTH,
	"net_gun_height": NET_GUN_HEIGHT,
	"net_gun_min_height": NET_GUN_MIN_HEIGHT,
})
static var WEAPON_PROFILES: Dictionary = PROFILE_CATALOG["weapon_profiles"]

static var WEAPON_HIT_FEEDBACK: Dictionary = PROFILE_CATALOG["weapon_hit_feedback"]

static var WEAPON_HIT_RESULTS: Dictionary = PROFILE_CATALOG["weapon_hit_results"]

static var WEAPON_LINGERING_EFFECTS: Dictionary = PROFILE_CATALOG["weapon_lingering_effects"]

static var WEAPON_PROFILE_OVERRIDES: Dictionary = PROFILE_CATALOG["weapon_profile_overrides"]
static var HIT_FEEDBACK_PROFILE_OVERRIDES: Dictionary = PROFILE_CATALOG["hit_feedback_profile_overrides"]
static var HIT_RESULT_PROFILE_OVERRIDES: Dictionary = PROFILE_CATALOG["hit_result_profile_overrides"]
static var RUNTIME_CONFIGS: Dictionary = CommandoFirearmRuntimeConfigCatalog.build_configs({
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
	"weapon_profiles": WEAPON_PROFILES,
	"weapon_profile_overrides": WEAPON_PROFILE_OVERRIDES,
	"weapon_hit_feedback": WEAPON_HIT_FEEDBACK,
	"hit_feedback_profile_overrides": HIT_FEEDBACK_PROFILE_OVERRIDES,
	"weapon_hit_results": WEAPON_HIT_RESULTS,
	"hit_result_profile_overrides": HIT_RESULT_PROFILE_OVERRIDES,
	"weapon_lingering_effects": WEAPON_LINGERING_EFFECTS,
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
	"doping_bazooka_cooldown_frames": DOPING_POTION_BAZOOKA_COOLDOWN_FRAMES,
	"doping_bazooka_control_lock_frames": DOPING_POTION_BAZOOKA_CONTROL_LOCK_FRAMES,
	"bazooka_ammo_max": BAZOOKA_AMMO_MAX,
	"bazooka_cooldown_frames": BAZOOKA_COOLDOWN_FRAMES,
	"bazooka_control_lock_frames": BAZOOKA_CONTROL_LOCK_FRAMES,
	"bazooka_fire_animation_frames": BAZOOKA_FIRE_ANIMATION_FRAMES,
	"bazooka_firing_pose_frames": BAZOOKA_FIRING_POSE_FRAMES,
	"bazooka_muzzle_flash_frames": BAZOOKA_MUZZLE_FLASH_FRAMES,
	"net_gun_ammo_max": NET_GUN_AMMO_MAX,
	"net_gun_cooldown_frames": NET_GUN_COOLDOWN_FRAMES,
	"net_gun_control_lock_frames": NET_GUN_CONTROL_LOCK_FRAMES,
	"net_gun_throw_pose_frames": NET_GUN_THROW_POSE_FRAMES,
	"net_gun_harpoon_flash_frames": NET_GUN_HARPOON_FLASH_FRAMES,
	"field_width": FIELD_WIDTH,
	"field_height": FIELD_HEIGHT,
	"bowling_trap_min_field_y_ratio": BOWLING_TRAP_MIN_FIELD_Y_RATIO,
	"bowling_trap_ammo_max": BOWLING_TRAP_AMMO_MAX,
	"bowling_trap_cooldown_frames": BOWLING_TRAP_COOLDOWN_FRAMES,
	"bowling_trap_control_lock_frames": BOWLING_TRAP_CONTROL_LOCK_FRAMES,
	"bowling_trap_install_frames": BOWLING_TRAP_INSTALL_FRAMES,
	"fire_sheet_default_frames": COMMANDO_WEAPON_FIRE_SHEET_DEFAULT_FRAMES,
	"fire_sheet_long_frames": COMMANDO_WEAPON_FIRE_SHEET_LONG_FRAMES,
	"fire_sheet_frame_count": COMMANDO_WEAPON_FIRE_SHEET_FRAME_COUNT,
	"fire_sheet_source_cell_size": COMMANDO_FIRE_SHEET_SOURCE_CELL_SIZE,
	"fire_sheet_player_foot_y_offset": COMMANDO_FIRE_SHEET_PLAYER_FOOT_Y_OFFSET,
	"suicide_drone_ammo_max": SUICIDE_DRONE_AMMO_MAX,
	"suicide_drone_grace_frames": SUICIDE_DRONE_GRACE_FRAMES,
	"suicide_drone_accel": SUICIDE_DRONE_ACCEL,
	"suicide_drone_max_speed": SUICIDE_DRONE_MAX_SPEED,
	"suicide_drone_size": SUICIDE_DRONE_SIZE,
	"suicide_drone_rotor_base_speed": SUICIDE_DRONE_ROTOR_BASE_SPEED,
	"suicide_drone_rotor_speed_scale": SUICIDE_DRONE_ROTOR_SPEED_SCALE,
	"suicide_drone_life_frames": SUICIDE_DRONE_LIFE_FRAMES,
	"suicide_drone_cooldown_frames": SUICIDE_DRONE_COOLDOWN_FRAMES,
	"suicide_drone_ball_speed_multiplier": SUICIDE_DRONE_BALL_SPEED_MULTIPLIER,
	"suicide_drone_ball_fan_degrees": SUICIDE_DRONE_BALL_FAN_DEGREES,
	"grenade_explosion_duration_frames": float(GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_DURATION_FRAMES),
	"projectile_limit": PROJECTILE_LIMIT,
	"flash_limit": FLASH_LIMIT,
	"pistol_muzzle_source": COMMANDO_PISTOL_FIRE_MUZZLE_SOURCE,
	"bazooka_muzzle_source": COMMANDO_BAZOOKA_FIRE_MUZZLE_SOURCE,
	"net_gun_muzzle_source": COMMANDO_NET_GUN_FIRE_MUZZLE_SOURCE,
	"pistol_bullet_speed": PISTOL_BULLET_SPEED,
	"doping_potion_head_leg_multiplier": DOPING_POTION_HEAD_LEG_MULTIPLIER,
	"doping_potion_pistol_speed_multiplier": DOPING_POTION_PISTOL_SPEED_MULTIPLIER,
	"support_call_limit": SUPPORT_CALL_LIMIT,
	"support_call_delay_min_frames": SUPPORT_CALL_DELAY_MIN_FRAMES,
	"support_call_delay_max_frames": SUPPORT_CALL_DELAY_MAX_FRAMES,
	"support_bomb_min_count": SUPPORT_BOMB_MIN_COUNT,
	"support_bomb_max_count": SUPPORT_BOMB_MAX_COUNT,
	"support_call_lock_frames": SUPPORT_CALL_LOCK_FRAMES,
	"support_aircraft_drop_arm_frames": SUPPORT_AIRCRAFT_DROP_ARM_FRAMES,
	"support_aircraft_y": SUPPORT_AIRCRAFT_Y,
	"support_aircraft_speed": SUPPORT_AIRCRAFT_SPEED,
	"support_bomb_interval_frames": SUPPORT_BOMB_INTERVAL_FRAMES,
	"support_aircraft_finish_margin": SUPPORT_AIRCRAFT_FINISH_MARGIN,
	"support_bomb_initial_vy": SUPPORT_BOMB_INITIAL_VY,
	"support_bomb_gravity": SUPPORT_BOMB_GRAVITY,
	"support_bomb_horizontal_jitter": SUPPORT_BOMB_HORIZONTAL_JITTER,
	"support_missile_flight_frames": SUPPORT_MISSILE_FLIGHT_FRAMES,
	"support_missile_life_frames": SUPPORT_MISSILE_LIFE_FRAMES,
	"support_aircraft_curve_amplitude": SUPPORT_AIRCRAFT_CURVE_AMPLITUDE,
	"support_aircraft_curve_frequency": SUPPORT_AIRCRAFT_CURVE_FREQUENCY,
	"support_aircraft_curve_secondary_ratio": SUPPORT_AIRCRAFT_CURVE_SECONDARY_RATIO,
	"support_aircraft_start_x": SUPPORT_AIRCRAFT_START_X,
	"support_opponent_wall_y": SUPPORT_OPPONENT_WALL_Y,
	"support_bomb_random_x_range": SUPPORT_BOMB_RANDOM_X_RANGE,
	"bowling_trap_width": BOWLING_TRAP_WIDTH,
	"bowling_trap_height": BOWLING_TRAP_HEIGHT,
	"bowling_trap_capture_ball_offset": BOWLING_TRAP_CAPTURE_BALL_OFFSET,
	"bowling_trap_capture_frames": BOWLING_TRAP_CAPTURE_FRAMES,
	"bowling_trap_capture_height": BOWLING_TRAP_CAPTURE_HEIGHT,
	"trap_launch_speed_multiplier": BOWLING_TRAP_LAUNCH_SPEED_MULTIPLIER,
	"trap_launch_fan_half_angle": BOWLING_TRAP_LAUNCH_FAN_HALF_ANGLE,
	"bowling_trap_guard_speed_reduction": BOWLING_TRAP_GUARD_SPEED_REDUCTION,
	"bowling_trap_guard_knockback_power": BOWLING_TRAP_GUARD_KNOCKBACK_POWER,
	"bowling_trap_guard_stun_frames": BOWLING_TRAP_GUARD_STUN_FRAMES,
	"bowling_trap_limit": BOWLING_TRAP_LIMIT,
	"default_projectile_speed": 16.0,
	"bazooka_smoke_trail_limit": BAZOOKA_SMOKE_TRAIL_LIMIT,
	"net_gun_rope_trail_limit": NET_GUN_ROPE_TRAIL_LIMIT,
	"ak47_shell_lifetime_frames": AK47_SHELL_LIFETIME_FRAMES,
	"ak47_shell_gravity": AK47_SHELL_GRAVITY,
	"ak47_shell_bounce_decay": AK47_SHELL_BOUNCE_DECAY,
	"ak47_shell_max_bounces": AK47_SHELL_MAX_BOUNCES,
	"pistol_shell_lifetime_frames": PISTOL_SHELL_LIFETIME_FRAMES,
	"shell_casing_limit": SHELL_CASING_LIMIT,
	"pistol_wall_bounce_margin": PISTOL_WALL_BOUNCE_MARGIN,
	"pistol_wall_bounce_max": PISTOL_WALL_BOUNCE_MAX,
	"pistol_wall_bounce_damping": PISTOL_WALL_BOUNCE_DAMPING,
	"bazooka_acceleration": BAZOOKA_ACCELERATION,
	"bazooka_max_speed": BAZOOKA_MAX_SPEED,
	"slingshot_stun_multipliers": SLINGSHOT_STUN_MULT,
	"slingshot_knockback_multipliers": SLINGSHOT_KNOCKBACK_MULT,
	"pistol_head_shot_chance": PISTOL_HEAD_SHOT_CHANCE,
	"pistol_leg_shot_chance": PISTOL_LEG_SHOT_CHANCE,
	"pistol_hit_tuning": PISTOL_HIT_TUNING,
	"pistol_hit_text_timer_frames": PISTOL_HIT_TEXT_TIMER_FRAMES,
	"pistol_head_shot_label": "헤드샷!",
	"pistol_leg_shot_label": "레그샷!",
	"pistol_feedback_limit": PISTOL_FEEDBACK_LIMIT,
	"ak47_boss_damage_hit_threshold": AK47_BOSS_DAMAGE_HIT_THRESHOLD,
	"hit_event_limit": HIT_EVENT_LIMIT,
	"net_gun_width": NET_GUN_WIDTH,
	"net_gun_height": NET_GUN_HEIGHT,
	"net_gun_min_height": NET_GUN_MIN_HEIGHT,
	"net_gun_dissolve_frames": NET_GUN_DISSOLVE_FRAMES,
	"net_gun_dash_break_frames": NET_GUN_DASH_BREAK_FRAMES,
	"net_gun_player_slow_multiplier": NET_GUN_PLAYER_SLOW_MULTIPLIER,
	"status_duration_frames": LINGERING_STATUS_DEFAULT_DURATION_FRAMES,
	"status_interval_frames": LINGERING_STATUS_DEFAULT_INTERVAL_FRAMES,
	"status_initial_cooldown_frames": LINGERING_STATUS_INITIAL_COOLDOWN_FRAMES,
	"status_slow_multiplier": LINGERING_STATUS_DEFAULT_SLOW_MULTIPLIER,
	"effect_limit": LINGERING_EFFECT_LIMIT,
	"lingering_effect_phase_step": LINGERING_EFFECT_PHASE_STEP,
	"lingering_status_target": LINGERING_STATUS_TARGET,
	"lingering_status_id_slow": LINGERING_STATUS_ID_SLOW,
	"lingering_status_duration_frames": LINGERING_STATUS_DEFAULT_DURATION_FRAMES,
	"lingering_status_interval_frames": LINGERING_STATUS_DEFAULT_INTERVAL_FRAMES,
	"lingering_status_slow_multiplier": LINGERING_STATUS_DEFAULT_SLOW_MULTIPLIER,
	"lingering_status_min_slow_multiplier": LINGERING_STATUS_MIN_SLOW_MULTIPLIER,
	"lingering_status_max_slow_multiplier": LINGERING_STATUS_MAX_SLOW_MULTIPLIER,
	"lingering_status_source": LINGERING_STATUS_DEFAULT_SOURCE,
})

var last_fire_msec := -100000
var _runtime_perk_modal_pause_started_msec := -1
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


static func get_pistol_enhance_ammo_bonus(level: int) -> int:
	return CommandoFirearmPistolEnhanceState.get_ammo_bonus(level)


static func get_pistol_enhance_spread_radians(level: int) -> float:
	return CommandoFirearmPistolEnhanceState.get_spread_radians(level, PISTOL_ENHANCE_TUNING)


static func get_pistol_enhance_speed_multiplier(level: int) -> float:
	return CommandoFirearmPistolEnhanceState.get_speed_multiplier(level, PISTOL_ENHANCE_TUNING)


static func get_pistol_enhance_knockback_multiplier(level: int) -> float:
	return CommandoFirearmPistolEnhanceState.get_knockback_multiplier(level, PISTOL_ENHANCE_TUNING)


func _sync_base_pistol_enhance_ammo(deps: Dictionary, weapon_controller: Object) -> void:
	CommandoFirearmPistolEnhanceState.sync_base_pistol_ammo(deps, weapon_controller, PISTOL_ENHANCE_TUNING)


func _build_firearm_spawn_options(deps: Dictionary) -> Dictionary:
	return CommandoFirearmPistolEnhanceState.build_spawn_options(deps, PISTOL_ENHANCE_TUNING)


func update_input(input_snapshot: Dictionary, special_gauge: float, config: Dictionary, deps: Dictionary) -> Dictionary:
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	if weapon_controller == null or not weapon_controller.has_method("get_snapshot"):
		return {}
	_sync_base_pistol_enhance_ammo(deps, weapon_controller)
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
	if CommandoFirearmControlState.apply_runtime_serve_wait_fire_suppression(
		self,
		input_snapshot,
		config,
		deps
	):
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
	return CommandoFirearmAmmoWeaponInputState.update_runtime_generic_weapon_input(
		self,
		input_snapshot,
		special_gauge,
		config,
		deps,
		current_weapon,
		now_msec,
		SWITCH_FIRE_SUPPRESS_MSEC,
		FIRE_DEBOUNCE_MSEC,
		RUNTIME_CONFIGS["fire_spawn"]
	)


func reset() -> void:
	_runtime_perk_modal_pause_started_msec = -1
	CommandoFirearmRuntimeLifecycleState.reset_runtime(self, RUNTIME_LIFECYCLE_RESET_DEFAULTS)


func reset_round(deps: Dictionary = {}) -> void:
	_runtime_perk_modal_pause_started_msec = -1
	CommandoFirearmRuntimeLifecycleState.reset_round(
		self,
		deps,
		RUNTIME_LIFECYCLE_RESET_DEFAULTS,
		BOWLING_TRAP_CAPTURE_BALL_OFFSET
	)


# 퍽 모달 동안 벽시계 앵커 동결. 규칙은 runtime_perk_modal_time_shift.gd 참조.
# 발사 디바운스(`last_fire_msec`)와 그물 조임 틱(`net_constrict_last_tick_msec`)
# 둘 다 "지금 - 앵커" 로 재는 값이라 모달이 지나가면 즉시 열려버린다.
func pause_runtime_perk_modal_time(current_msec: int) -> void:
	_runtime_perk_modal_pause_started_msec = RuntimePerkModalTimeShift.begin_pause(
		_runtime_perk_modal_pause_started_msec, current_msec
	)


func resume_runtime_perk_modal_time(current_msec: int) -> void:
	if _runtime_perk_modal_pause_started_msec < 0:
		return
	var pause_started_msec: int = _runtime_perk_modal_pause_started_msec
	_runtime_perk_modal_pause_started_msec = -1
	shift_runtime_perk_modal_time(pause_started_msec, current_msec)


func shift_runtime_perk_modal_time(pause_started_msec: int, resumed_msec: int) -> void:
	var delta_msec: int = RuntimePerkModalTimeShift.resolve_paused_duration(pause_started_msec, resumed_msec)
	if delta_msec <= 0:
		return
	last_fire_msec = RuntimePerkModalTimeShift.shift_anchor(last_fire_msec, delta_msec)
	net_constrict_last_tick_msec = RuntimePerkModalTimeShift.shift_anchor(
		net_constrict_last_tick_msec, delta_msec
	)


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
		RUNTIME_CONFIGS["effect_update"]
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
		RUNTIME_CONFIGS["pistol_input"]
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
		RUNTIME_CONFIGS["ak47_input"]
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
		RUNTIME_CONFIGS["bazooka_input"]
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
		RUNTIME_CONFIGS["net_gun_input"]
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
		RUNTIME_CONFIGS["bowling_trap_input"]
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
		RUNTIME_CONFIGS["suicide_drone_input"]
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
		RUNTIME_CONFIGS["active_suicide_drone_input"]
	)


func _spawn_firearm_effect(weapon_id: String, config: Dictionary, deps: Dictionary, profile_override: Dictionary = {}) -> void:
	var spawn_options: Dictionary = _build_firearm_spawn_options(deps)
	CommandoFirearmFireSpawnState.spawn_runtime_firearm_effect(
		self,
		weapon_id,
		config,
		deps,
		profile_override,
		_build_runtime_fire_spawn_config(spawn_options)
	)


func _build_runtime_fire_spawn_config(spawn_options: Dictionary) -> Dictionary:
	var runtime_config: Dictionary = RUNTIME_CONFIGS["fire_spawn"].duplicate()
	runtime_config.merge(spawn_options, true)
	return runtime_config


func _update_projectiles(fps_scale: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	return CommandoFirearmProjectileMotionState.advance_runtime_projectiles(
		projectiles,
		impact_flashes,
		self,
		fps_scale,
		context,
		deps,
		RUNTIME_CONFIGS["projectile_update"]
	)


func _register_projectile_hit(projectile: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	CommandoFirearmProjectileImpactState.register_runtime_projectile_hit(
		self,
		projectile,
		context,
		deps,
		RUNTIME_CONFIGS["projectile_hit"]
	)


func _spawn_lingering_effect(weapon_id: String, projectile: Dictionary, context: Dictionary) -> Dictionary:
	return CommandoFirearmLingeringEffectState.spawn_runtime_lingering_effect(
		self,
		weapon_id,
		projectile,
		context,
		RUNTIME_CONFIGS["lingering_spawn"]
	)
