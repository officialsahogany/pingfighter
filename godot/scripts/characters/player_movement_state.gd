extends RefCounted

const PADDLE_SPEED := 6.0
const PADDLE_MAX_SPEED := 6.0
const PADDLE_ACCEL := 0.5
const KNOCKBACK_DECAY_PER_FRAME := 0.92
const KNOCKBACK_WALL_BOUNCE_KEEP_RATIO := 0.70

var knockback_vel: float = 0.0
var knockback_timer: float = 0.0


func reset() -> void:
	knockback_vel = 0.0
	knockback_timer = 0.0


func start_knockback(velocity: float, frames: float = 18.0) -> void:
	if abs(velocity) >= abs(knockback_vel):
		knockback_vel = velocity
	knockback_timer = max(knockback_timer, frames)


func update_horizontal(
	delta: float,
	player_pos: Vector2,
	player_speed: float,
	direction: float,
	play_left: float,
	play_right: float,
	paddle_width: float
) -> Dictionary:
	var fps_scale: float = delta * 60.0
	if direction != 0.0:
		player_speed = move_toward(player_speed, direction * PADDLE_MAX_SPEED, PADDLE_ACCEL * fps_scale)
		if abs(player_speed) < PADDLE_SPEED:
			player_speed = direction * PADDLE_SPEED
	else:
		player_speed = move_toward(player_speed, 0.0, PADDLE_ACCEL * 2.0 * fps_scale)

	player_pos.x += player_speed * fps_scale
	player_pos = _apply_knockback(player_pos, play_left, play_right, paddle_width, fps_scale)
	player_pos.x = clamp(player_pos.x, play_left, play_right - paddle_width)

	return {
		"player_pos": player_pos,
		"player_speed": player_speed,
	}


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

	knockback_vel *= pow(KNOCKBACK_DECAY_PER_FRAME, fps_scale)
	knockback_timer = max(0.0, knockback_timer - fps_scale)
	if knockback_timer <= 0.0 or abs(knockback_vel) <= 0.3:
		knockback_vel = 0.0
		knockback_timer = 0.0
	return player_pos
