extends RefCounted

const BallEffectPayloadFactory := preload("res://scripts/ball/ball_effect_payload_factory.gd")

const BALL_GHOST_MAX_LENGTH := 4
const BALL_GHOST_FADE_SPEED := 0.75
const BALL_GHOST_MIN_DISTANCE := 8.0
const BALL_GHOST_INITIAL_ALPHA := 72.0 / 255.0

var ghost_trail: Array[Dictionary] = []


func clear() -> void:
	ghost_trail.clear()


func update(ball_center: Vector2, ball_size: float, fps_scale: float) -> void:
	if ghost_trail.is_empty():
		ghost_trail.append(BallEffectPayloadFactory.build_ghost_trail_point(ball_center, BALL_GHOST_INITIAL_ALPHA, ball_size))
	else:
		_append_interpolated_points(ball_center, ball_size)

	while ghost_trail.size() > BALL_GHOST_MAX_LENGTH:
		ghost_trail.pop_front()

	var write_idx: int = 0
	var fade: float = pow(BALL_GHOST_FADE_SPEED, fps_scale)
	for i in range(ghost_trail.size()):
		var p: Dictionary = ghost_trail[i]
		var alpha: float = float(p["alpha"]) * fade
		var age: float = float(p["age"]) + fps_scale
		if alpha > 3.0 / 255.0:
			p["alpha"] = alpha
			p["age"] = age
			ghost_trail[write_idx] = p
			write_idx += 1
	ghost_trail.resize(write_idx)


func get_trail() -> Array[Dictionary]:
	return ghost_trail


func _append_interpolated_points(ball_center: Vector2, ball_size: float) -> void:
	var last_point: Dictionary = ghost_trail[ghost_trail.size() - 1]
	var last_pos: Vector2 = last_point["pos"]
	var delta_pos: Vector2 = ball_center - last_pos
	var distance: float = delta_pos.length()
	if distance < BALL_GHOST_MIN_DISTANCE:
		return
	var segments: int = int(distance / BALL_GHOST_MIN_DISTANCE)
	segments = clampi(segments, 1, 2)
	for step in range(1, segments + 1):
		var t: float = float(step) / float(segments)
		ghost_trail.append(BallEffectPayloadFactory.build_ghost_trail_point(last_pos.lerp(ball_center, t), BALL_GHOST_INITIAL_ALPHA, ball_size))
