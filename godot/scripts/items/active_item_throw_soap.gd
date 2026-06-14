extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")


func throw_soap(controller: Object, owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	var start_pos: Vector2 = _get_player_throw_start(owner, pending_throw, 15.0)
	var land_y: float = _get_float(controller, "SOAP_LAND_Y")
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var raw_target_pos: Vector2 = _get_vector2(
		pending_throw,
		"target_position",
		Vector2(start_pos.x, land_y)
	)
	var target_pos := Vector2(clamp(raw_target_pos.x, 30.0, field_width - 30.0), land_y)
	var speed_per_frame: float = _get_float(controller, "SOAP_THROW_SPEED_PER_FRAME")
	var travel_frames: float = max(1.0, abs(start_pos.y - target_pos.y) / max(0.001, speed_per_frame))
	_get_array(controller, "soap_projectiles").append({
		"position": start_pos,
		"velocity": Vector2(
			(target_pos.x - start_pos.x) / travel_frames,
			-speed_per_frame
		),
		"target_position": target_pos,
		"rotation_degrees": 0.0,
		"rotation_speed": randf_range(5.0, 10.0) * (-1.0 if randf() < 0.5 else 1.0),
		"trail": [start_pos],
	})

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null:
		if audio.has_method("play_throw"):
			audio.play_throw()
		if audio.has_method("play_soap_throw"):
			audio.play_soap_throw()


func update_soaps(controller: Object, owner: Object, registry: Object, delta: float) -> void:
	var fps_scale: float = delta * 60.0
	update_projectiles(controller, registry, fps_scale)
	update_landed(controller, owner, registry, fps_scale)


func update_projectiles(controller: Object, registry: Object, fps_scale: float) -> void:
	var projectiles: Array = _get_array(controller, "soap_projectiles")
	if projectiles.is_empty():
		return
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var field_height: float = _get_float(controller, "FIELD_HEIGHT", 750.0)
	var land_y: float = _get_float(controller, "SOAP_LAND_Y")
	var write_index := 0
	for read_index in range(projectiles.size()):
		var projectile: Dictionary = projectiles[read_index]
		var pos: Vector2 = _get_vector2(projectile, "position", Vector2.ZERO)
		var vel: Vector2 = _get_vector2(projectile, "velocity", Vector2.ZERO)
		pos += vel * fps_scale
		projectile["position"] = pos
		projectile["rotation_degrees"] = fposmod(
			float(projectile.get("rotation_degrees", 0.0))
			+ float(projectile.get("rotation_speed", 7.0)) * fps_scale,
			360.0
		)
		var trail: Array = projectile.get("trail", [])
		trail.append(pos)
		while trail.size() > 6:
			trail.pop_front()
		projectile["trail"] = trail

		if pos.x <= 10.0:
			pos.x = 10.0
			vel.x = abs(vel.x) * 0.7
			projectile["position"] = pos
			projectile["velocity"] = vel
		elif pos.x >= field_width - 10.0:
			pos.x = field_width - 10.0
			vel.x = -abs(vel.x) * 0.7
			projectile["position"] = pos
			projectile["velocity"] = vel

		if pos.y <= land_y and vel.y < 0.0:
			var landing_pos: Vector2 = _get_vector2(projectile, "target_position", pos)
			landing_pos.y = land_y
			land_soap(controller, landing_pos, registry)
			continue
		if pos.y > field_height + 50.0:
			continue
		projectiles[write_index] = projectile
		write_index += 1
	if write_index < projectiles.size():
		projectiles.resize(write_index)


func land_soap(controller: Object, pos: Vector2, registry: Object) -> void:
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var land_y: float = _get_float(controller, "SOAP_LAND_Y")
	var duration_frames: float = _get_float(controller, "SOAP_LAND_DURATION_FRAMES")
	var landed_x: float = clamp(pos.x, 30.0, field_width - 30.0)
	_get_array(controller, "landed_soaps").append({
		"position": Vector2(landed_x, land_y),
		"timer_frames": duration_frames,
		"max_timer_frames": duration_frames,
		"triggered": false,
		"wobble_phase": randf_range(0.0, TAU),
	})
	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_soap_land"):
		audio.play_soap_land()


func update_landed(controller: Object, owner: Object, registry: Object, fps_scale: float) -> void:
	var landed_soaps: Array = _get_array(controller, "landed_soaps")
	if landed_soaps.is_empty():
		return
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var land_y: float = _get_float(controller, "SOAP_LAND_Y")
	var duration_frames: float = _get_float(controller, "SOAP_LAND_DURATION_FRAMES")
	var collision_size: Vector2 = _get_vector2_property(controller, "SOAP_COLLISION_RECT", Vector2(70.0, 50.0))
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(
		owner,
		"boss_pos",
		Vector2(field_width * 0.5 - 50.0, 25.0)
	)
	var boss_rect := Rect2(boss_pos, Vector2(100.0, 40.0))
	var write_index := 0
	for read_index in range(landed_soaps.size()):
		var landed: Dictionary = landed_soaps[read_index]
		var timer_frames: float = float(landed.get("timer_frames", duration_frames)) - fps_scale
		if timer_frames <= 0.0:
			continue
		landed["timer_frames"] = timer_frames
		landed["wobble_phase"] = float(landed.get("wobble_phase", 0.0)) + 0.08 * fps_scale
		var pos: Vector2 = _get_vector2(landed, "position", Vector2(field_width * 0.5, land_y))
		var soap_rect := Rect2(
			Vector2(pos.x - collision_size.x * 0.5, 20.0),
			collision_size
		)
		if not bool(landed.get("triggered", false)) and boss_rect.intersects(soap_rect):
			landed["triggered"] = true
			_set_float(
				controller,
				"soap_boss_slip_timer_frames",
				max(_get_float(controller, "soap_boss_slip_timer_frames"), _get_float(controller, "SOAP_DEBUFF_DURATION_FRAMES"))
			)
			_set_float(controller, "soap_foam_spawn_timer_frames", 0.0)
			spawn_burst_particles(controller, pos)
			var audio: Object = _get_instance(registry, "game_audio")
			if audio != null and audio.has_method("play_soap_slip"):
				audio.play_soap_slip()
			continue
		landed_soaps[write_index] = landed
		write_index += 1
	if write_index < landed_soaps.size():
		landed_soaps.resize(write_index)


func spawn_burst_particles(controller: Object, pos: Vector2) -> void:
	var colors: Array = _get_array_property(controller, "SOAP_BURST_PARTICLE_COLORS")
	if colors.is_empty():
		colors = [
			Color(200.0 / 255.0, 230.0 / 255.0, 1.0, 1.0),
			Color(220.0 / 255.0, 240.0 / 255.0, 1.0, 1.0),
			Color(180.0 / 255.0, 220.0 / 255.0, 1.0, 1.0),
			Color(1.0, 1.0, 1.0, 1.0),
			Color(200.0 / 255.0, 1.0, 240.0 / 255.0, 1.0),
		]
	var particles: Array = _get_array(controller, "soap_particles")
	for _i in range(int(_get_float(controller, "SOAP_BURST_PARTICLE_COUNT"))):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(1.5, 5.0)
		particles.append({
			"position": pos + Vector2(randf_range(-10.0, 10.0), randf_range(-5.0, 5.0)),
			"velocity": Vector2(cos(angle), sin(angle)) * speed + Vector2(0.0, -2.0),
			"age": 0.0,
			"lifetime": randf_range(0.50, 1.0),
			"radius": randf_range(3.0, 8.0),
			"color": colors[randi() % colors.size()],
		})


func update_particles(controller: Object, delta: float) -> void:
	var particles: Array = _get_array(controller, "soap_particles")
	if particles.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var write_index := 0
	for read_index in range(particles.size()):
		var particle: Dictionary = particles[read_index]
		var age: float = float(particle.get("age", 0.0)) + delta
		var lifetime: float = max(0.001, float(particle.get("lifetime", 0.8)))
		if age >= lifetime:
			continue
		var pos: Vector2 = _get_vector2(particle, "position", Vector2.ZERO)
		var velocity: Vector2 = _get_vector2(particle, "velocity", Vector2.ZERO)
		pos += velocity * fps_scale
		velocity.y += 0.15 * fps_scale
		particle["age"] = age
		particle["position"] = pos
		particle["velocity"] = velocity
		particle["radius"] = max(0.5, float(particle.get("radius", 4.0)) * pow(0.98, fps_scale))
		particles[write_index] = particle
		write_index += 1
	if write_index < particles.size():
		particles.resize(write_index)


func update_foam_trails(controller: Object, delta: float) -> void:
	var trails: Array = _get_array(controller, "soap_foam_trails")
	if trails.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var write_index := 0
	for read_index in range(trails.size()):
		var foam: Dictionary = trails[read_index]
		var life_frames: float = float(foam.get("life_frames", 0.0)) - fps_scale
		if life_frames <= 0.0:
			continue
		foam["life_frames"] = life_frames
		trails[write_index] = foam
		write_index += 1
	if write_index < trails.size():
		trails.resize(write_index)


func update_boss_slip(controller: Object, owner: Object, delta: float) -> void:
	var fps_scale: float = delta * 60.0
	var timer_frames: float = _get_float(controller, "soap_boss_slip_timer_frames")
	if timer_frames <= 0.0:
		_set_float(controller, "soap_boss_slip_timer_frames", 0.0)
		_set_float(controller, "soap_foam_spawn_timer_frames", 0.0)
		return
	timer_frames = max(0.0, timer_frames - fps_scale)
	_set_float(controller, "soap_boss_slip_timer_frames", timer_frames)
	if owner == null:
		return
	var foam_spawn_timer: float = _get_float(controller, "soap_foam_spawn_timer_frames") + fps_scale
	if foam_spawn_timer < _get_float(controller, "SOAP_FOAM_SPAWN_INTERVAL_FRAMES"):
		_set_float(controller, "soap_foam_spawn_timer_frames", foam_spawn_timer)
		return
	_set_float(controller, "soap_foam_spawn_timer_frames", 0.0)
	var trails: Array = _get_array(controller, "soap_foam_trails")
	if trails.size() >= int(_get_float(controller, "SOAP_FOAM_TRAIL_CAP")):
		return
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(
		owner,
		"boss_pos",
		Vector2(field_width * 0.5 - 50.0, 25.0)
	)
	var foam_life_frames: float = randf_range(30.0, 50.0)
	trails.append({
		"position": Vector2(
			boss_pos.x + 50.0 + randf_range(-30.0, 30.0),
			boss_pos.y + 40.0 + randf_range(-2.0, 3.0)
		),
		"size": randf_range(4.0, 9.0),
		"life_frames": foam_life_frames,
		"max_life_frames": foam_life_frames,
	})


func _get_player_throw_start(owner: Object, pending_throw: Dictionary, y_offset: float) -> Vector2:
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(
		owner,
		"player_pos",
		_get_vector2(pending_throw, "start_position", Vector2.ZERO)
	)
	return Vector2(player_pos.x + 155.0 * 0.5, player_pos.y + y_offset)


func _get_array(source: Object, key: String) -> Array:
	if source == null:
		return []
	var value: Variant = source.get(key)
	if value is Array:
		return value
	return []


func _get_array_property(source: Object, key: String) -> Array:
	if source == null:
		return []
	var value: Variant = source.get(key)
	if value is Array:
		return value
	return []


func _get_float(source: Object, key: String, fallback: float = 0.0) -> float:
	if source == null:
		return fallback
	var value: Variant = source.get(key)
	if value is float or value is int:
		return float(value)
	return fallback


func _set_float(source: Object, key: String, value: float) -> void:
	if source == null:
		return
	source.set(key, value)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_vector2_property(source: Object, key: String, fallback: Vector2) -> Vector2:
	if source == null:
		return fallback
	var value: Variant = source.get(key)
	if value is Vector2:
		return value
	return fallback


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
