extends RefCounted

const PADDLE_SPEED := 6.0
const PADDLE_MAX_SPEED := 6.0
const PADDLE_ACCEL := 0.5
const PADDLE_DECEL := 0.5
const PADDLE_TURN_DECEL := 1.0
const KNOCKBACK_DECAY_PER_FRAME := 0.92
const KNOCKBACK_WALL_BOUNCE_KEEP_RATIO := 0.70
const SPEED_EPSILON := 0.01

var knockback_vel: float = 0.0
var knockback_timer: float = 0.0
var knockback_decay_per_frame: float = KNOCKBACK_DECAY_PER_FRAME
var knockback_cleansable: bool = true
var knockback_resist_pct: float = 0.0


func reset() -> void:
	knockback_vel = 0.0
	knockback_timer = 0.0
	knockback_decay_per_frame = KNOCKBACK_DECAY_PER_FRAME
	knockback_cleansable = true
	# Posture Correction is a persistent build stat. Owner sync updates it when
	# the build changes; a rally reset only clears the current knockback motion.


func start_knockback(
	velocity: float,
	frames: float = 18.0,
	decay_per_frame: float = KNOCKBACK_DECAY_PER_FRAME,
	replace_current: bool = false,
	cleansable: bool = true
) -> bool:
	var resist_scale: float = get_knockback_resist_scale()
	var effective_velocity: float = velocity * resist_scale
	if abs(effective_velocity) <= 0.3:
		if replace_current or is_zero_approx(resist_scale):
			clear_knockback()
		return false
	if replace_current or knockback_timer <= 0.0 or abs(effective_velocity) >= abs(knockback_vel):
		knockback_vel = effective_velocity
		knockback_decay_per_frame = clamp(decay_per_frame * resist_scale, 0.0, 1.0)
		knockback_cleansable = cleansable
	var effective_frames: float = maxf(0.0, frames) * resist_scale
	knockback_timer = max(knockback_timer, effective_frames)
	return true


func set_knockback_resist_pct(value: float) -> void:
	set_posture_correction_pct(value)


func set_posture_correction_pct(value: float) -> void:
	knockback_resist_pct = clamp(float(value), 0.0, 100.0)
	if is_zero_approx(get_knockback_resist_scale()):
		clear_knockback()


func get_knockback_resist_pct() -> float:
	return knockback_resist_pct


func get_posture_correction_pct() -> float:
	return knockback_resist_pct


func get_knockback_resist_scale() -> float:
	return max(0.0, 1.0 - knockback_resist_pct / 100.0)


func clear_knockback() -> void:
	knockback_vel = 0.0
	knockback_timer = 0.0
	knockback_decay_per_frame = KNOCKBACK_DECAY_PER_FRAME
	knockback_cleansable = true


func clear_status_effects() -> void:
	clear_knockback()


func has_status_effect() -> bool:
	return knockback_cleansable and _is_knockback_motion_active()


func get_status_snapshot() -> Dictionary:
	return {
		"knockback_active": has_status_effect(),
		"knockback_motion_active": _is_knockback_motion_active(),
		"knockback_cleansable": knockback_cleansable,
		"knockback_vel": knockback_vel,
		"knockback_timer": knockback_timer,
		"posture_correction_pct": get_posture_correction_pct(),
		"knockback_resist_pct": knockback_resist_pct,
		"knockback_resist_scale": get_knockback_resist_scale(),
	}


func update_horizontal(
	delta: float,
	player_pos: Vector2,
	player_speed: float,
	direction: float,
	play_left: float,
	play_right: float,
	paddle_width: float,
	config: Dictionary = {}
) -> Dictionary:
	var fps_scale: float = delta * 60.0
	var input_direction: float = _normalize_direction(direction)
	var paddle_max_speed: float = max(0.0, float(config.get("paddle_max_speed", PADDLE_MAX_SPEED)))
	paddle_max_speed *= max(0.0, float(config.get("paddle_max_speed_multiplier", 1.0)))
	var paddle_accel: float = max(0.0, float(config.get("paddle_accel", PADDLE_ACCEL)))
	var paddle_decel: float = max(0.0, float(config.get("paddle_decel", PADDLE_DECEL)))
	var paddle_turn_decel: float = max(0.0, float(config.get("paddle_turn_decel", PADDLE_TURN_DECEL)))
	if bool(config.get("gravitybelt_instant_movement", config.get("gravitybelt_active", false))):
		player_speed = input_direction * paddle_max_speed
	elif input_direction != 0.0:
		player_speed = _accelerate_with_turn_inertia(
			player_speed,
			input_direction,
			paddle_max_speed,
			paddle_accel * fps_scale,
			paddle_turn_decel * fps_scale
		)
	else:
		player_speed = move_toward(player_speed, 0.0, paddle_decel * fps_scale)

	player_pos.x += player_speed * fps_scale
	player_pos = _apply_knockback(player_pos, play_left, play_right, paddle_width, fps_scale)
	player_pos.x = clamp(player_pos.x, play_left, play_right - paddle_width)

	return {
		"player_pos": player_pos,
		"player_speed": player_speed,
	}


func _normalize_direction(direction: float) -> float:
	if direction < 0.0:
		return -1.0
	if direction > 0.0:
		return 1.0
	return 0.0


func _accelerate_with_turn_inertia(
	player_speed: float,
	direction: float,
	max_speed: float,
	accel_step: float,
	turn_decel_step: float
) -> float:
	if max_speed <= SPEED_EPSILON:
		return 0.0

	var target_speed: float = direction * max_speed
	if direction < 0.0:
		if player_speed > target_speed:
			player_speed -= accel_step
		if player_speed > 0.0:
			player_speed -= turn_decel_step
	elif direction > 0.0:
		if player_speed < target_speed:
			player_speed += accel_step
		if player_speed < 0.0:
			player_speed += turn_decel_step

	return clamp(player_speed, -max_speed, max_speed)


func _apply_knockback(
	player_pos: Vector2,
	play_left: float,
	play_right: float,
	paddle_width: float,
	fps_scale: float
) -> Vector2:
	if knockback_timer <= 0.0 or abs(knockback_vel) <= 0.3:
		knockback_vel = 0.0
		knockback_timer = 0.0
		knockback_decay_per_frame = KNOCKBACK_DECAY_PER_FRAME
		knockback_cleansable = true
		return player_pos

	player_pos.x += knockback_vel * fps_scale
	var min_x: float = play_left
	var max_x: float = play_right - paddle_width
	if player_pos.x < min_x:
		player_pos.x = min_x
		knockback_vel = abs(knockback_vel) * KNOCKBACK_WALL_BOUNCE_KEEP_RATIO
	elif player_pos.x > max_x:
		player_pos.x = max_x
		knockback_vel = -abs(knockback_vel) * KNOCKBACK_WALL_BOUNCE_KEEP_RATIO

	knockback_vel *= pow(knockback_decay_per_frame, fps_scale)
	knockback_timer = max(0.0, knockback_timer - fps_scale)
	if knockback_timer <= 0.0 or abs(knockback_vel) <= 0.3:
		knockback_vel = 0.0
		knockback_timer = 0.0
		knockback_decay_per_frame = KNOCKBACK_DECAY_PER_FRAME
		knockback_cleansable = true
	return player_pos


func _is_knockback_motion_active() -> bool:
	return knockback_timer > 0.0 and abs(knockback_vel) > 0.3
