extends RefCounted

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const VITAMIN_PILL_SPEED_MULTIPLIER := 1.5
const VITAMIN_PILL_FLASH_FRAMES := 10.0
const STRANGE_VIAL_FLASH_FRAMES := 12.0
const DOPING_POTION_FLASH_FRAMES := 12.0
const DOPING_POTION_HEAD_LEG_MULTIPLIER := 2.0
const DOPING_POTION_FIRE_RATE_MULTIPLIER := 0.5
const DOPING_POTION_PISTOL_COOLDOWN_FRAMES := 30.0
const DOPING_POTION_PISTOL_CONTROL_LOCK_FRAMES := 9.0
const DOPING_POTION_PISTOL_SPEED_MULTIPLIER := 1.2
const DOPING_POTION_BERETTA_COOLDOWN_FRAMES := 15.0
const DOPING_POTION_AK47_FIRE_INTERVAL_FRAMES := 3.0
const DOPING_POTION_BAZOOKA_COOLDOWN_FRAMES := 60.0
const DOPING_POTION_BAZOOKA_CONTROL_LOCK_FRAMES := 15.0
const AIPILL_FLASH_FRAMES := 12.0
const STOPWATCH_RECOVERY_FRAMES := 60.0
const STOPWATCH_FLASH_FRAMES := 10.0
const HOLY_BARRIER_HEIGHT := 20.0
const HOLY_BARRIER_Y_OFFSET := 5.0


func build_brick_wall_context(
	installing: bool,
	install_timer_frames: float,
	install_initial_frames: float,
	pending_wall: Dictionary,
	walls: Array[Dictionary],
	particles: Array[Dictionary]
) -> Dictionary:
	return {
		"installing": installing,
		"install_timer_frames": install_timer_frames,
		"install_initial_frames": install_initial_frames,
		"pending_wall": pending_wall,
		"walls": walls,
		"particles": particles,
	}


func build_long_boost_timer_context(active: bool, timer_frames: float, initial_timer_frames: float) -> Dictionary:
	return {
		"active": active,
		"timer_frames": timer_frames,
		"initial_timer_frames": initial_timer_frames,
	}


func build_vitamin_pill_timer_context(
	active: bool,
	timer_frames: float,
	initial_timer_frames: float,
	phase: float,
	flash_timer_frames: float,
	player_center: Vector2
) -> Dictionary:
	return {
		"active": active,
		"timer_frames": timer_frames,
		"initial_timer_frames": initial_timer_frames,
		"phase": phase,
		"flash_timer_frames": flash_timer_frames,
		"flash_initial_frames": VITAMIN_PILL_FLASH_FRAMES,
		"player_center": player_center,
		"speed_multiplier": VITAMIN_PILL_SPEED_MULTIPLIER if active else 1.0,
	}


func build_strange_vial_timer_context(
	active: bool,
	timer_frames: float,
	initial_timer_frames: float,
	effect_type: String,
	phase: float,
	flash_timer_frames: float,
	player_center: Vector2,
	paddle_scale: float,
	speed_multiplier: float,
	target_scale: float,
	target_speed_multiplier: float
) -> Dictionary:
	return {
		"active": active,
		"timer_frames": timer_frames,
		"initial_timer_frames": initial_timer_frames,
		"effect_type": effect_type,
		"phase": phase,
		"flash_timer_frames": flash_timer_frames,
		"flash_initial_frames": STRANGE_VIAL_FLASH_FRAMES,
		"player_center": player_center,
		"paddle_scale": paddle_scale,
		"speed_multiplier": speed_multiplier,
		"target_scale": target_scale,
		"target_speed_multiplier": target_speed_multiplier,
	}


func build_aipill_context(active: bool, phase: float, flash_timer_frames: float) -> Dictionary:
	return {
		"active": active,
		"phase": phase,
		"flash_timer_frames": flash_timer_frames,
		"flash_initial_frames": AIPILL_FLASH_FRAMES,
	}


func build_doping_potion_context(
	active: bool,
	timer_frames: float,
	initial_timer_frames: float,
	phase: float,
	flash_timer_frames: float,
	player_center: Vector2,
	use_count: int
) -> Dictionary:
	return {
		"active": active and timer_frames > 0.0,
		"timer_frames": timer_frames,
		"initial_timer_frames": initial_timer_frames,
		"phase": phase,
		"flash_timer_frames": flash_timer_frames,
		"flash_initial_frames": DOPING_POTION_FLASH_FRAMES,
		"player_center": player_center,
		"use_count": max(0, use_count),
		"head_leg_multiplier": DOPING_POTION_HEAD_LEG_MULTIPLIER if active and timer_frames > 0.0 else 1.0,
		"fire_rate_multiplier": DOPING_POTION_FIRE_RATE_MULTIPLIER if active and timer_frames > 0.0 else 1.0,
		"pistol_cooldown_frames": DOPING_POTION_PISTOL_COOLDOWN_FRAMES,
		"pistol_control_lock_frames": DOPING_POTION_PISTOL_CONTROL_LOCK_FRAMES,
		"pistol_speed_multiplier": DOPING_POTION_PISTOL_SPEED_MULTIPLIER if active and timer_frames > 0.0 else 1.0,
		"beretta_cooldown_frames": DOPING_POTION_BERETTA_COOLDOWN_FRAMES,
		"ak47_fire_interval_frames": DOPING_POTION_AK47_FIRE_INTERVAL_FRAMES,
		"bazooka_cooldown_frames": DOPING_POTION_BAZOOKA_COOLDOWN_FRAMES,
		"bazooka_control_lock_frames": DOPING_POTION_BAZOOKA_CONTROL_LOCK_FRAMES,
	}


func build_stopwatch_context(
	active: bool,
	timer_frames: float,
	initial_timer_frames: float,
	recovery_timer_frames: float,
	flash_timer_frames: float,
	clock_angle: float
) -> Dictionary:
	return {
		"active": active,
		"freeze_active": timer_frames > 0.0,
		"recovery_active": recovery_timer_frames > 0.0,
		"timer_frames": timer_frames,
		"initial_timer_frames": initial_timer_frames,
		"recovery_timer_frames": recovery_timer_frames,
		"recovery_initial_frames": STOPWATCH_RECOVERY_FRAMES,
		"flash_timer_frames": flash_timer_frames,
		"flash_initial_frames": STOPWATCH_FLASH_FRAMES,
		"clock_angle": clock_angle,
	}


func build_magnet_field_context(
	active: bool,
	timer_frames: float,
	initial_timer_frames: float,
	field_phase: float,
	player_center: Vector2
) -> Dictionary:
	var remaining_ratio: float = 0.0
	if active:
		remaining_ratio = clamp(timer_frames / max(1.0, initial_timer_frames), 0.0, 1.0)
	return {
		"active": active,
		"timer_frames": timer_frames,
		"initial_timer_frames": initial_timer_frames,
		"remaining_ratio": remaining_ratio,
		"field_phase": field_phase,
		"player_center": player_center,
		"width": FIELD_WIDTH,
		"height": FIELD_HEIGHT,
	}


func build_holy_barrier_context(active: bool, timer_frames: float, initial_timer_frames: float, glow_phase: float) -> Dictionary:
	return {
		"active": active,
		"timer_frames": timer_frames,
		"initial_timer_frames": initial_timer_frames,
		"glow_phase": glow_phase,
		"barrier_y": _holy_barrier_y(),
		"barrier_height": HOLY_BARRIER_HEIGHT,
		"width": FIELD_WIDTH,
	}


func build_dash_boost_context(
	active: bool,
	timer_frames: float,
	initial_timer_frames: float,
	glow_phase: float,
	player_center: Vector2
) -> Dictionary:
	var remaining_ratio: float = 0.0
	if active and initial_timer_frames > 0.0:
		remaining_ratio = clamp(timer_frames / max(1.0, initial_timer_frames), 0.0, 1.0)
	return {
		"active": active,
		"timer_frames": timer_frames,
		"initial_timer_frames": initial_timer_frames,
		"remaining_ratio": remaining_ratio,
		"glow_phase": glow_phase,
		"player_center": player_center,
		"width": FIELD_WIDTH,
		"height": FIELD_HEIGHT,
	}


func build_dash_boost_timer_context(active: bool, timer_frames: float, initial_timer_frames: float) -> Dictionary:
	return {
		"active": active,
		"timer_frames": timer_frames,
		"initial_timer_frames": initial_timer_frames,
	}


func build_holy_barrier_collision_context(active: bool) -> Dictionary:
	if not active:
		return {"holy_barrier_active": false}
	return {
		"holy_barrier_active": true,
		"holy_barrier_y": _holy_barrier_y(),
		"holy_barrier_height": HOLY_BARRIER_HEIGHT,
	}


func build_stopwatch_ball_context(
	active: bool,
	timer_frames: float,
	recovery_timer_frames: float,
	post_recovery_grace_frames: float,
	recovery_speed_ratio: float,
	original_ball_vel: Vector2
) -> Dictionary:
	var recovery_active: bool = active and timer_frames <= 0.0 and recovery_timer_frames > 0.0
	# Why: keep the upward-catch grace separate from `recovery_active` so it
	# only widens the player paddle's upward-catch window and does not also
	# disable speed limits or score blocking after recovery has ended.
	var post_recovery_grace_active: bool = not active and post_recovery_grace_frames > 0.0
	return {
		"stopwatch_score_blocking": active,
		"stopwatch_freeze_active": active and timer_frames > 0.0,
		"stopwatch_recovery_active": recovery_active,
		"stopwatch_post_recovery_grace_active": post_recovery_grace_active,
		"stopwatch_recovery_speed_ratio": recovery_speed_ratio if recovery_active else 1.0,
		"stopwatch_original_ball_vel": original_ball_vel,
	}


func _holy_barrier_y() -> float:
	return FIELD_HEIGHT - HOLY_BARRIER_Y_OFFSET - HOLY_BARRIER_HEIGHT
