extends RefCounted

var absorb_particles: Array = []
var aura_particles: Array = []
var projectiles: Array = []


func clear() -> void:
	absorb_particles.clear()
	aura_particles.clear()
	projectiles.clear()


func is_visible(cinematic_active: bool, round_effect_active: bool) -> bool:
	return cinematic_active or round_effect_active or not absorb_particles.is_empty() or not aura_particles.is_empty() or not projectiles.is_empty()


func build_absorb_particles(
	harvested: Array,
	weather_type: String,
	weather_color: Color,
	fallback_count: int,
	field_size: Vector2,
	absorb_frames: float
) -> void:
	absorb_particles.clear()
	if harvested.is_empty():
		for _i in range(max(0, fallback_count)):
			absorb_particles.append(_make_absorb_particle({
				"x": randf_range(20.0, field_size.x - 20.0),
				"y": randf_range(35.0, field_size.y - 35.0),
				"size": randf_range(2.5, 7.0),
				"color": weather_color,
			}, weather_type, weather_color, field_size, absorb_frames))
		return
	for particle_value in harvested:
		absorb_particles.append(_make_absorb_particle(_as_dict(particle_value), weather_type, weather_color, field_size, absorb_frames))


func update_absorb_particles(fps_scale: float, absorb_center: Vector2, cinematic_active: bool) -> void:
	if absorb_particles.is_empty():
		return
	var write_index := 0
	for read_index in range(absorb_particles.size()):
		var particle: Dictionary = _as_dict(absorb_particles[read_index])
		var life: float = float(particle.get("life", 0.0)) - fps_scale
		if life <= 0.0 and not cinematic_active:
			continue
		particle["life"] = max(0.0, life)
		var pos: Vector2 = _as_vector2(particle.get("position", absorb_center), absorb_center)
		var to_center: Vector2 = absorb_center - pos
		var angle: float = float(particle.get("angle", 0.0)) + float(particle.get("spin", 0.0)) * fps_scale
		var tangent: Vector2 = Vector2(cos(angle), sin(angle)) * min(6.0, to_center.length() * 0.025)
		var pull: float = clamp(0.035 * fps_scale, 0.0, 0.32)
		particle["position"] = pos.lerp(absorb_center + tangent, pull)
		particle["angle"] = angle
		absorb_particles[write_index] = particle
		write_index += 1
	if write_index < absorb_particles.size():
		absorb_particles.resize(write_index)


func spawn_aura_particles(center: Vector2, weather_type: String, count: int, weather_color: Color, max_count: int) -> void:
	if weather_type == "":
		return
	for _i in range(max(0, count)):
		var angle: float = randf_range(0.0, TAU)
		var radius: float = randf_range(12.0, 56.0)
		aura_particles.append({
			"position": center + Vector2(cos(angle), sin(angle)) * radius,
			"velocity": Vector2(cos(angle), sin(angle)) * randf_range(0.25, 1.4) + Vector2(randf_range(-0.4, 0.4), randf_range(-1.2, 0.3)),
			"life": randf_range(24.0, 58.0),
			"max_life": 58.0,
			"size": randf_range(2.0, 5.5),
			"color": weather_color,
		})
	while aura_particles.size() > max_count:
		aura_particles.remove_at(0)


func update_aura_particles(fps_scale: float) -> void:
	for index in range(aura_particles.size() - 1, -1, -1):
		var particle: Dictionary = _as_dict(aura_particles[index])
		var life: float = float(particle.get("life", 0.0)) - fps_scale
		if life <= 0.0:
			aura_particles.remove_at(index)
			continue
		var pos: Vector2 = _as_vector2(particle.get("position", Vector2.ZERO), Vector2.ZERO)
		var vel: Vector2 = _as_vector2(particle.get("velocity", Vector2.ZERO), Vector2.ZERO)
		particle["position"] = pos + vel * fps_scale
		particle["life"] = life
		aura_particles[index] = particle


func spawn_projectiles(
	ball_pos: Vector2,
	boss_center: Vector2,
	weather_type: String,
	weather_color: Color,
	projectile_speed: float,
	projectile_life_frames: float
) -> void:
	var direction: Vector2 = boss_center - ball_pos
	if direction.length() <= 0.01:
		direction = Vector2(0.0, -1.0)
	direction = direction.normalized()
	var count := 3 if weather_type == "rain" else 2
	for index in range(count):
		var spread: float = (float(index) - float(count - 1) * 0.5) * 0.16
		var shot_dir: Vector2 = direction.rotated(spread).normalized()
		projectiles.append({
			"position": ball_pos + shot_dir * 18.0,
			"velocity": shot_dir * projectile_speed,
			"life": projectile_life_frames,
			"max_life": projectile_life_frames,
			"size": 5.0 if weather_type == "rain" else 9.0,
			"weather_type": weather_type,
			"color": weather_color,
		})


func update_projectiles(fps_scale: float, boss_rect: Rect2, field_size: Vector2, margin: float = 80.0) -> Array:
	var hit_events: Array = []
	if projectiles.is_empty():
		return hit_events
	for index in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = _as_dict(projectiles[index])
		var life: float = float(projectile.get("life", 0.0)) - fps_scale
		var pos: Vector2 = _as_vector2(projectile.get("position", Vector2.ZERO), Vector2.ZERO)
		var vel: Vector2 = _as_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
		pos += vel * fps_scale
		projectile["life"] = life
		projectile["position"] = pos
		if life <= 0.0 or pos.y < -margin or pos.y > field_size.y + margin or pos.x < -margin or pos.x > field_size.x + margin:
			projectiles.remove_at(index)
			continue
		if boss_rect.has_point(pos):
			hit_events.append({
				"position": pos,
				"weather_type": str(projectile.get("weather_type", "")),
			})
			projectiles.remove_at(index)
			continue
		projectiles[index] = projectile
	return hit_events


func _make_absorb_particle(
	source: Dictionary,
	weather_type: String,
	weather_color: Color,
	field_size: Vector2,
	absorb_frames: float
) -> Dictionary:
	var source_pos := Vector2(
		float(source.get("x", randf_range(0.0, field_size.x))),
		float(source.get("y", randf_range(0.0, field_size.y)))
	)
	var color: Color = _as_color(source.get("color", weather_color), weather_color)
	var size: float = clamp(float(source.get("size", 4.0)), 1.5, 12.0)
	return {
		"position": source_pos,
		"origin": source_pos,
		"angle": randf_range(0.0, TAU),
		"spin": randf_range(-0.13, 0.13),
		"life": absorb_frames + randf_range(18.0, 54.0),
		"max_life": absorb_frames + 54.0,
		"size": size,
		"color": color,
		"weather_type": weather_type,
	}


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback
