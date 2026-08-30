extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")


func throw_banana(controller: Object, owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	var start_pos: Vector2 = _get_player_throw_start(owner, pending_throw, 15.0)
	var land_y: float = _get_float(controller, "BANANA_LAND_Y")
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var raw_target_pos: Vector2 = _get_vector2(
		pending_throw,
		"target_position",
		Vector2(start_pos.x, land_y)
	)
	var target_pos := Vector2(clamp(raw_target_pos.x, 30.0, field_width - 30.0), land_y)
	var speed_per_frame: float = _get_float(controller, "BANANA_THROW_SPEED_PER_FRAME")
	var travel_frames: float = max(1.0, abs(start_pos.y - target_pos.y) / max(0.001, speed_per_frame))
	var projectile_count := 2 if _get_owned_perk_level(owner, registry, "banana_master") > 0 else 1
	var projectiles: Array = _get_array(controller, "banana_projectiles")
	var presentation_rng := _build_throw_presentation_rng(
		start_pos,
		target_pos,
		projectiles.size()
	)
	for projectile_index in range(projectile_count):
		var lateral_offset := 0.0
		if projectile_count == 2:
			lateral_offset = -18.0 if projectile_index == 0 else 18.0
		var projectile_target := Vector2(
			clamp(target_pos.x + lateral_offset, 30.0, field_width - 30.0),
			land_y
		)
		projectiles.append({
			"position": start_pos,
			"velocity": Vector2(
				(projectile_target.x - start_pos.x) / travel_frames,
				-speed_per_frame
			),
			"target_position": projectile_target,
			"rotation_degrees": 0.0,
			"rotation_speed": presentation_rng.randf_range(8.0, 15.0) * (
				-1.0 if presentation_rng.randf() < 0.5 else 1.0
			),
			"trail": [start_pos],
		})

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null:
		if audio.has_method("play_throw"):
			audio.play_throw()
		if audio.has_method("play_banana_throw"):
			audio.play_banana_throw()


func update_bananas(controller: Object, owner: Object, registry: Object, delta: float) -> void:
	var fps_scale: float = delta * 60.0
	update_projectiles(controller, registry, fps_scale)
	update_landed(controller, owner, registry, fps_scale)


func update_projectiles(controller: Object, registry: Object, fps_scale: float) -> void:
	var projectiles: Array = _get_array(controller, "banana_projectiles")
	if projectiles.is_empty():
		return
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var field_height: float = _get_float(controller, "FIELD_HEIGHT", 750.0)
	var land_y: float = _get_float(controller, "BANANA_LAND_Y")
	var write_index := 0
	for read_index in range(projectiles.size()):
		var projectile: Dictionary = projectiles[read_index]
		var pos: Vector2 = _get_vector2(projectile, "position", Vector2.ZERO)
		var vel: Vector2 = _get_vector2(projectile, "velocity", Vector2.ZERO)
		pos += vel * fps_scale
		projectile["position"] = pos
		projectile["rotation_degrees"] = fposmod(
			float(projectile.get("rotation_degrees", 0.0))
			+ float(projectile.get("rotation_speed", 11.0)) * fps_scale,
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
			land_banana(controller, landing_pos, registry)
			continue
		if pos.y > field_height + 50.0:
			continue
		projectiles[write_index] = projectile
		write_index += 1
	if write_index < projectiles.size():
		projectiles.resize(write_index)


func land_banana(controller: Object, pos: Vector2, _registry: Object) -> void:
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var land_y: float = _get_float(controller, "BANANA_LAND_Y")
	var duration_frames: float = _get_float(controller, "BANANA_LAND_DURATION_FRAMES")
	var landed_x: float = clamp(pos.x, 30.0, field_width - 30.0)
	_get_array(controller, "landed_bananas").append({
		"position": Vector2(landed_x, land_y),
		"timer_frames": duration_frames,
		"max_timer_frames": duration_frames,
		"slip_triggered": false,
	})


func update_landed(controller: Object, owner: Object, registry: Object, fps_scale: float) -> void:
	var landed_bananas: Array = _get_array(controller, "landed_bananas")
	if landed_bananas.is_empty():
		return
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var land_y: float = _get_float(controller, "BANANA_LAND_Y")
	var duration_frames: float = _get_float(controller, "BANANA_LAND_DURATION_FRAMES")
	var collision_size: Vector2 = _get_vector2_property(controller, "BANANA_COLLISION_RECT", Vector2(80.0, 50.0))
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(
		owner,
		"boss_pos",
		Vector2(field_width * 0.5 - 50.0, 25.0)
	)
	var boss_rect := Rect2(boss_pos, Vector2(100.0, 40.0))
	var write_index := 0
	for read_index in range(landed_bananas.size()):
		var landed: Dictionary = landed_bananas[read_index]
		var timer_frames: float = float(landed.get("timer_frames", duration_frames)) - fps_scale
		if timer_frames <= 0.0:
			continue
		landed["timer_frames"] = timer_frames
		var pos: Vector2 = _get_vector2(landed, "position", Vector2(field_width * 0.5, land_y))
		var banana_rect := Rect2(
			Vector2(pos.x - collision_size.x * 0.5, 20.0),
			collision_size
		)
		if not bool(landed.get("slip_triggered", false)) and boss_rect.intersects(banana_rect):
			landed["slip_triggered"] = true
			_set_float(
				controller,
				"banana_boss_slip_timer_frames",
				max(_get_float(controller, "banana_boss_slip_timer_frames"), _get_float(controller, "BANANA_SLIP_DURATION_FRAMES"))
			)
			_set_float(controller, "banana_boss_slip_direction", get_boss_slip_direction(owner))
			spawn_burst_particles(controller, pos)
			var audio: Object = _get_instance(registry, "game_audio")
			if audio != null and audio.has_method("play_banana_slip"):
				audio.play_banana_slip()
			continue
		landed_bananas[write_index] = landed
		write_index += 1
	if write_index < landed_bananas.size():
		landed_bananas.resize(write_index)


func get_boss_slip_direction(owner: Object) -> float:
	var boss_vel_value: Variant = BattleSceneOwnerReader.get_value(owner, "boss_vel", 0.0)
	var boss_vel_type: int = typeof(boss_vel_value)
	var boss_vel: float = (
		float(boss_vel_value)
		if boss_vel_type == TYPE_INT or boss_vel_type == TYPE_FLOAT
		else 0.0
	)
	if abs(boss_vel) > 0.2:
		return sign(boss_vel)
	return -1.0 if randf() < 0.5 else 1.0


func spawn_burst_particles(controller: Object, pos: Vector2) -> void:
	var colors := [
		Color(1.0, 225.0 / 255.0, 50.0 / 255.0, 1.0),
		Color(227.0 / 255.0, 189.0 / 255.0, 52.0 / 255.0, 1.0),
		Color(198.0 / 255.0, 156.0 / 255.0, 41.0 / 255.0, 1.0),
		Color(1.0, 1.0, 200.0 / 255.0, 1.0),
		Color(139.0 / 255.0, 90.0 / 255.0, 43.0 / 255.0, 1.0),
	]
	var particles: Array = _get_array(controller, "banana_particles")
	var particle_cap: int = maxi(0, int(_get_float(controller, "BANANA_PARTICLE_CAP", 12.0)))
	var presentation_rng := _build_burst_presentation_rng(pos, particles.size())
	for _i in range(int(_get_float(controller, "BANANA_BURST_PARTICLE_COUNT"))):
		if particle_cap > 0 and particles.size() >= particle_cap:
			particles.pop_front()
		var angle: float = presentation_rng.randf_range(0.0, TAU)
		var speed: float = presentation_rng.randf_range(3.0, 8.0)
		particles.append({
			"position": pos,
			"velocity": Vector2(cos(angle), sin(angle)) * speed + Vector2(0.0, -3.0),
			"life_frames": presentation_rng.randf_range(20.0, 40.0),
			"max_life_frames": 40.0,
			"size": presentation_rng.randf_range(3.0, 7.0),
			"color": colors[presentation_rng.randi_range(0, colors.size() - 1)],
		})


func update_particles(controller: Object, delta: float) -> void:
	var particles: Array = _get_array(controller, "banana_particles")
	if particles.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var write_index := 0
	for read_index in range(particles.size()):
		var particle: Dictionary = particles[read_index]
		var life_frames: float = float(particle.get("life_frames", 0.0)) - fps_scale
		if life_frames <= 0.0:
			continue
		var pos: Vector2 = _get_vector2(particle, "position", Vector2.ZERO)
		var velocity: Vector2 = _get_vector2(particle, "velocity", Vector2.ZERO)
		pos += velocity * fps_scale
		velocity.y += 0.5 * fps_scale
		particle["life_frames"] = life_frames
		particle["position"] = pos
		particle["velocity"] = velocity
		particles[write_index] = particle
		write_index += 1
	if write_index < particles.size():
		particles.resize(write_index)


func update_boss_slip(controller: Object, delta: float) -> void:
	var fps_scale: float = delta * 60.0
	var timer_frames: float = _get_float(controller, "banana_boss_slip_timer_frames")
	if timer_frames <= 0.0:
		_set_float(controller, "banana_boss_slip_timer_frames", 0.0)
		_set_float(controller, "banana_boss_slip_direction", 0.0)
		return
	timer_frames = max(0.0, timer_frames - fps_scale)
	_set_float(controller, "banana_boss_slip_timer_frames", timer_frames)
	if timer_frames <= 0.0:
		_set_float(controller, "banana_boss_slip_direction", 0.0)


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


func _get_owned_perk_level(owner: Object, registry: Object, perk_id: String) -> int:
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state != null:
		if runtime_perk_state.has_method("get_runtime_skill_level"):
			return maxi(0, int(runtime_perk_state.get_runtime_skill_level(perk_id)))
		var state_levels_value: Variant = runtime_perk_state.get("runtime_skill_levels")
		if state_levels_value is Dictionary:
			return maxi(0, int((state_levels_value as Dictionary).get(perk_id, 0)))
	var owner_levels := BattleSceneOwnerReader.get_dictionary(owner, "runtime_perk_levels")
	return maxi(0, int(owner_levels.get(perk_id, 0)))


func _build_throw_presentation_rng(
	start_pos: Vector2,
	target_pos: Vector2,
	existing_projectile_count: int
) -> RandomNumberGenerator:
	# Visual-only rotation never advances the authoritative/global RNG. Stable
	# geometry and the existing presentation count make replayed throws repeatable.
	var rng := RandomNumberGenerator.new()
	var seed_key := "%.3f:%.3f:%.3f:%.3f:%d" % [
		start_pos.x,
		start_pos.y,
		target_pos.x,
		target_pos.y,
		existing_projectile_count,
	]
	rng.seed = int(seed_key.hash()) & 0x7fffffff
	return rng


func _build_burst_presentation_rng(
	pos: Vector2,
	existing_particle_count: int
) -> RandomNumberGenerator:
	# Landing particles are presentation-only and must not consume the shared
	# gameplay RNG, including the second Banana Master landing.
	var rng := RandomNumberGenerator.new()
	var seed_key := "banana_burst_v1:%.3f:%.3f:%d" % [
		pos.x,
		pos.y,
		existing_particle_count,
	]
	rng.seed = int(seed_key.hash()) & 0x7fffffff
	return rng
