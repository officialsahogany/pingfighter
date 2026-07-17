extends RefCounted

const SmasherDashSpiritRenderer := preload("res://scripts/characters/smasher_dash_spirit_renderer.gd")

const PERK_ID := "dash_spirit"
const LASER_DURATION_FRAMES := 360.0
const LASER_WIDTH := 8.0
const INVINCIBLE_FRAMES := 10.0
const FULL_DASH_FRAMES := 15.0
const HALF_DASH_FRAMES := 11.0
const DASH_FRAME_SPEED := 40.0
const DASH_DISTANCE_SCALE := 0.7
const LASER_DISTANCE_RATIO := 0.5
const ELECTRIC_SEGMENT_COUNT := 5
const ELECTRIC_REFRESH_FRAMES := 5.0
const MAX_EVAPORATION_PARTICLES := 32
const BALL_DEFAULT_SIZE := 28.6
const PLAYER_DEFAULT_SIZE := Vector2(155.0, 50.0)
const PLAYER_BACK_LASER_Y_OFFSET := 30.0
const REFLECT_X_MULT := 0.8
const UPWARD_ALREADY_MOVING_MULT := 1.2
const REFLECT_SPEED_BOOST := 1.3

var lasers: Array[Dictionary] = []
var evaporation_particles: Array[Dictionary] = []
var renderer: Object = SmasherDashSpiritRenderer.new()


func reset() -> void:
	lasers.clear()
	evaporation_particles.clear()


func reset_round() -> void:
	reset()


func try_spawn_from_dash(
	direction: float,
	is_half: bool,
	player_pos: Vector2,
	player_size: Vector2,
	deps: Dictionary,
	dash_frames: float = 0.0,
	dash_distance_multiplier: float = 1.0
) -> bool:
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	var chance: float = _get_dash_spirit_chance(runtime_perk_state)
	if chance <= 0.0 or randf() >= chance:
		return false

	var normalized_direction: float = -1.0 if direction < 0.0 else 1.0
	var safe_player_size: Vector2 = Vector2(
		max(1.0, player_size.x),
		max(1.0, player_size.y)
	)
	var frames: float = dash_frames
	if frames <= 0.0:
		frames = HALF_DASH_FRAMES if is_half else FULL_DASH_FRAMES
	# 충돌 레이저 길이는 실 대쉬 거리와 함께 스케일해야 한다 — 신비의 주사위
	# dash_distance 배율이 실 이동만 늘리고 레이저가 base에 남으면 판정이
	# 시각 이동보다 짧아진다.
	var dash_distance: float = floor(frames * DASH_FRAME_SPEED * DASH_DISTANCE_SCALE * LASER_DISTANCE_RATIO * maxf(0.0, dash_distance_multiplier))
	var player_center: Vector2 = player_pos + safe_player_size * 0.5
	create_laser(player_center, normalized_direction, dash_distance, safe_player_size.x)
	return true


func create_laser(player_center: Vector2, direction: float, dash_distance: float, paddle_width: float = PLAYER_DEFAULT_SIZE.x) -> Dictionary:
	var normalized_direction: float = -1.0 if direction < 0.0 else 1.0
	var half_width: float = floor(max(1.0, paddle_width) * 0.5)
	var start_x: float = player_center.x + half_width if normalized_direction < 0.0 else player_center.x - half_width
	var end_x: float = start_x + normalized_direction * max(0.0, dash_distance)
	var y: float = player_center.y + PLAYER_BACK_LASER_Y_OFFSET
	var laser: Dictionary = {
		"start": Vector2(start_x, y),
		"end": Vector2(end_x, y),
		"remaining_time": LASER_DURATION_FRAMES,
		"duration": LASER_DURATION_FRAMES,
		"direction": normalized_direction,
		"alpha": 255.0,
		"electric_timer": 0.0,
		"electric_segments": _build_electric_segments(Vector2(start_x, y), Vector2(end_x, y), 3.0),
		"invincible_time": INVINCIBLE_FRAMES,
	}
	lasers.append(laser)
	return laser


func update_effects(fps_scale: float) -> void:
	_update_lasers(fps_scale)
	_update_evaporation_particles(fps_scale)


func resolve_ball_collision(scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	if lasers.is_empty():
		return {}

	var ball_pos: Vector2 = _get_vector2(scene, "ball_pos", _get_vector2(context, "ball_pos", Vector2.ZERO))
	var ball_size: float = max(1.0, float(context.get("ball_size", BALL_DEFAULT_SIZE)))
	var ball_radius: float = ball_size * 0.5
	var threshold: float = ball_radius + floor(LASER_WIDTH * 0.5)
	for index in range(lasers.size()):
		var laser: Dictionary = lasers[index]
		if float(laser.get("invincible_time", 0.0)) > 0.0:
			continue
		if _distance_to_laser(ball_pos, laser) > threshold:
			continue

		var next_vel: Vector2 = _build_reflected_velocity(
			_get_vector2(scene, "ball_vel", _get_vector2(context, "ball_vel", Vector2.ZERO)),
			ball_pos,
			_get_player_center(context)
		)
		_create_laser_evaporation_effect(laser)
		lasers.remove_at(index)
		_play_delete_sound(deps)
		_trigger_feedback(deps)
		return {
			"ball_vel": next_vel,
			"dash_spirit_blocked": true,
		}
	return {}


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if renderer != null and renderer.has_method("draw"):
		renderer.draw(canvas, lasers, evaporation_particles, shake_offset)


func get_snapshot() -> Dictionary:
	return {
		"lasers": lasers,
		"evaporation_particles": evaporation_particles,
	}


func has_visible_effects() -> bool:
	return not lasers.is_empty() or not evaporation_particles.is_empty()


func needs_effect_update() -> bool:
	return has_visible_effects()


func _get_dash_spirit_chance(runtime_perk_state: Object) -> float:
	if runtime_perk_state == null:
		return 0.0
	if runtime_perk_state.has_method("get_runtime_skill_bonus"):
		return max(0.0, float(runtime_perk_state.get_runtime_skill_bonus(PERK_ID)))
	if runtime_perk_state.has_method("get_runtime_skill_level"):
		return max(0.0, float(runtime_perk_state.get_runtime_skill_level(PERK_ID)) * 0.07)
	return 0.0


func _update_lasers(fps_scale: float) -> void:
	var write_index := 0
	for read_index in range(lasers.size()):
		var laser: Dictionary = lasers[read_index]
		var remaining: float = float(laser.get("remaining_time", 0.0)) - fps_scale
		laser["remaining_time"] = remaining
		laser["electric_timer"] = float(laser.get("electric_timer", 0.0)) + fps_scale
		laser["invincible_time"] = max(0.0, float(laser.get("invincible_time", 0.0)) - fps_scale)
		laser["alpha"] = 255.0 * clamp(remaining / LASER_DURATION_FRAMES, 0.0, 1.0)
		if float(laser.get("electric_timer", 0.0)) >= ELECTRIC_REFRESH_FRAMES:
			laser["electric_timer"] = fmod(float(laser.get("electric_timer", 0.0)), ELECTRIC_REFRESH_FRAMES)
			_refresh_electric_segments(laser)
		if remaining > 0.0:
			lasers[write_index] = laser
			write_index += 1
	if write_index < lasers.size():
		lasers.resize(write_index)


func _update_evaporation_particles(fps_scale: float) -> void:
	var write_index := 0
	for read_index in range(evaporation_particles.size()):
		var particle: Dictionary = evaporation_particles[read_index]
		var lifetime: float = float(particle.get("lifetime", 0.0)) - fps_scale
		var max_lifetime: float = max(1.0, float(particle.get("max_lifetime", 1.0)))
		if lifetime <= 0.0:
			continue
		var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO)
		var velocity: Vector2 = _as_vector2(particle.get("velocity", Vector2.ZERO), Vector2.ZERO)
		pos += velocity * fps_scale
		velocity.x = velocity.x * pow(0.98, fps_scale) + sin((pos.x + lifetime) * 0.07) * 0.045 * fps_scale
		velocity.y *= pow(0.99, fps_scale)
		var life_ratio: float = clamp(lifetime / max_lifetime, 0.0, 1.0)
		if life_ratio > 0.7:
			particle["size"] = float(particle.get("max_size", 1.0)) * (1.0 - (life_ratio - 0.7) / 0.3) * 0.8
		else:
			particle["size"] = float(particle.get("max_size", 1.0)) * life_ratio
		particle["alpha"] = int(180.0 * life_ratio)
		if int(particle.get("alpha", 0)) <= 0 or float(particle.get("size", 0.0)) <= 0.0:
			continue
		particle["pos"] = pos
		particle["velocity"] = velocity
		particle["lifetime"] = lifetime
		evaporation_particles[write_index] = particle
		write_index += 1
	if write_index < evaporation_particles.size():
		evaporation_particles.resize(write_index)


func _build_electric_segments(start: Vector2, end: Vector2, offset_range: float) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	for index in range(ELECTRIC_SEGMENT_COUNT + 1):
		var t: float = float(index) / float(ELECTRIC_SEGMENT_COUNT)
		segments.append({
			"base": start.lerp(end, t),
			"offset": Vector2(randf_range(-offset_range, offset_range), randf_range(-offset_range, offset_range)),
		})
	return segments


func _refresh_electric_segments(laser: Dictionary) -> void:
	var segments: Array = _as_array(laser.get("electric_segments", []))
	for segment in segments:
		if segment is Dictionary:
			segment["offset"] = Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))


func _distance_to_laser(point: Vector2, laser: Dictionary) -> float:
	var start: Vector2 = _as_vector2(laser.get("start", Vector2.ZERO), Vector2.ZERO)
	var end: Vector2 = _as_vector2(laser.get("end", Vector2.ZERO), Vector2.ZERO)
	var segment: Vector2 = end - start
	var length_sq: float = segment.length_squared()
	if length_sq <= 0.0001:
		return point.distance_to(start)
	var t: float = clamp((point - start).dot(segment) / length_sq, 0.0, 1.0)
	return point.distance_to(start + segment * t)


func _build_reflected_velocity(ball_vel: Vector2, ball_pos: Vector2, player_center: Vector2) -> Vector2:
	var reflected: Vector2 = ball_vel
	if reflected.y > 0.0:
		reflected.y = -abs(reflected.y)
	else:
		reflected.y *= UPWARD_ALREADY_MOVING_MULT
	if ball_pos.x < player_center.x:
		reflected.x = abs(reflected.x) * REFLECT_X_MULT
	else:
		reflected.x = -abs(reflected.x) * REFLECT_X_MULT
	return reflected * REFLECT_SPEED_BOOST


func _create_laser_evaporation_effect(laser: Dictionary) -> void:
	var start: Vector2 = _as_vector2(laser.get("start", Vector2.ZERO), Vector2.ZERO)
	var end: Vector2 = _as_vector2(laser.get("end", Vector2.ZERO), Vector2.ZERO)
	var laser_length: float = abs(end.x - start.x)
	var particle_count: int = clampi(int(floor(laser_length / 17.0)), 6, 12)
	for _i in range(particle_count):
		var t: float = randf()
		var spawn_pos := Vector2(
			lerp(start.x, end.x, t),
			start.y + randf_range(-5.0, 5.0)
		)
		var size: float = randf_range(2.0, 5.0)
		var lifetime: float = float(randi_range(60, 120))
		evaporation_particles.append({
			"pos": spawn_pos,
			"velocity": Vector2(randf_range(-0.5, 0.5), randf_range(-2.5, -1.0)),
			"size": size,
			"max_size": size * 2.0,
			"lifetime": lifetime,
			"max_lifetime": lifetime,
			"color": Color(200.0 / 255.0, 230.0 / 255.0, 1.0),
			"alpha": 180,
		})
	while evaporation_particles.size() > MAX_EVAPORATION_PARTICLES:
		evaporation_particles.pop_front()


func _play_delete_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_dash_spirit_delete"):
		audio.play_dash_spirit_delete()


func _trigger_feedback(deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(0.10, 3.2)


func _get_player_center(context: Dictionary) -> Vector2:
	var player_pos: Vector2 = _get_vector2(context, "player_pos", Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(context, "player_paddle_size", PLAYER_DEFAULT_SIZE)
	return player_pos + player_size * 0.5


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return _as_vector2(source.get(key, fallback), fallback)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
