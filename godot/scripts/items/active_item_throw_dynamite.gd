extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")


func throw_dynamite(controller: Object, owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	var start_pos: Vector2 = _get_player_throw_start(owner, pending_throw, 15.0)
	var land_y: float = _get_float(controller, "DYNAMITE_LAND_Y")
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var raw_target_pos: Vector2 = _get_vector2(
		pending_throw,
		"target_position",
		Vector2(start_pos.x, land_y)
	)
	var target_pos := Vector2(clamp(raw_target_pos.x, 20.0, field_width - 20.0), land_y)
	var speed_per_frame: float = _get_float(controller, "DYNAMITE_THROW_SPEED_PER_FRAME")
	var gravity_per_frame: float = _get_float(controller, "DYNAMITE_GRAVITY_PER_FRAME")
	var travel_frames: float = _estimate_rising_crossing_frames(
		start_pos.y,
		target_pos.y,
		speed_per_frame,
		gravity_per_frame
	)
	_get_array(controller, "dynamites").append({
		"position": start_pos,
		"velocity": Vector2(
			(target_pos.x - start_pos.x) / travel_frames,
			-speed_per_frame
		),
		"target_position": target_pos,
		"rotation_degrees": 0.0,
		"rotation_speed": randf_range(5.0, 15.0),
		"trail": [start_pos],
	})

	_play_throw_audio(registry)


func update_dynamites(controller: Object, owner: Object, registry: Object, delta: float) -> void:
	var fps_scale: float = delta * 60.0
	update_projectiles(controller, registry, fps_scale)
	update_placed(controller, owner, registry, fps_scale)


func update_projectiles(controller: Object, registry: Object, fps_scale: float) -> void:
	_update_projectiles(controller, registry, fps_scale)


func update_placed(controller: Object, owner: Object, registry: Object, fps_scale: float) -> void:
	_update_placed(controller, owner, registry, fps_scale)


func place_dynamite(controller: Object, pos: Vector2, registry: Object) -> void:
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var placed_x: float = clamp(pos.x, 20.0, field_width - 20.0)
	_get_array(controller, "placed_dynamites").append({
		"position": Vector2(
			placed_x,
			randf_range(
				_get_float(controller, "DYNAMITE_PLACED_MIN_Y"),
				_get_float(controller, "DYNAMITE_PLACED_MAX_Y")
			)
		),
		"countdown_frames": _get_float(controller, "DYNAMITE_COUNTDOWN_FRAMES"),
		"max_countdown_frames": _get_float(controller, "DYNAMITE_COUNTDOWN_FRAMES"),
		"pulse_timer": 0.0,
		"nudge_vx": 0.0,
		"wobble_angle": 0.0,
		"wobble_vel": 0.0,
		"fuse_player": play_fuse(registry),
	})


func stop_all_fuses(controller: Object, registry: Object) -> void:
	for placed in _get_array(controller, "placed_dynamites"):
		if placed is Dictionary:
			stop_fuse(placed, registry)


func play_fuse(registry: Object) -> Variant:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio == null or not audio.has_method("play_dynamite_fuse"):
		return null
	return audio.play_dynamite_fuse()


func stop_fuse(placed: Dictionary, registry: Object) -> void:
	var fuse_player: Variant = placed.get("fuse_player", null)
	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("stop_dynamite_fuse"):
		audio.stop_dynamite_fuse(fuse_player)
		return
	if typeof(fuse_player) != TYPE_OBJECT or not is_instance_valid(fuse_player):
		return
	if not (fuse_player is AudioStreamPlayer):
		return
	var player: AudioStreamPlayer = fuse_player
	if player.playing:
		player.stop()
	if player.is_inside_tree():
		player.queue_free()


func detonate_placed_on_round_end(controller: Object, owner: Object, registry: Object) -> int:
	var placed_dynamites: Array = _get_array(controller, "placed_dynamites")
	if placed_dynamites.is_empty():
		return 0
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var fallback_pos := Vector2(field_width * 0.5, _get_float(controller, "DYNAMITE_PLACED_MAX_Y"))
	var detonation_queue: Array[Dictionary] = []
	for placed_value in placed_dynamites:
		if placed_value is Dictionary:
			detonation_queue.append(placed_value)
	placed_dynamites.clear()

	for placed in detonation_queue:
		var pos: Vector2 = _get_vector2(placed, "position", fallback_pos)
		stop_fuse(placed, registry)
		trigger_explosion(controller, owner, registry, pos)
	return detonation_queue.size()


func trigger_explosion(controller: Object, owner: Object, registry: Object, center: Vector2) -> void:
	var duration_frames: float = _get_float(controller, "DYNAMITE_EXPLOSION_DURATION_FRAMES")
	var explosion := {
		"position": center,
		"timer_frames": duration_frames,
		"max_timer_frames": duration_frames,
		"progress": 0.0,
		"shockwave_radius": 0.0,
		"secondary_waves": [
			{"radius": 0.0, "speed": 25.0, "delay_frames": 0.0},
			{"radius": 0.0, "speed": 17.0, "delay_frames": 5.0},
		],
		"particles": [],
		"sparks": [],
		"smoke_clouds": [],
	}
	_seed_explosion_particles(controller, explosion, center)
	_get_array(controller, "dynamite_explosions").append(explosion)
	apply_boss_effect(controller, owner, center)

	var feedback: Object = _get_instance(registry, "battle_feedback_state")
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(0.67, 35.0)

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null:
		if audio.has_method("play_dynamite_explosion"):
			audio.play_dynamite_explosion()
		elif audio.has_method("play_grenade_explosion"):
			audio.play_grenade_explosion()


func update_explosions(controller: Object, delta: float) -> void:
	var explosions: Array = _get_array(controller, "dynamite_explosions")
	if explosions.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var write_index := 0
	for read_index in range(explosions.size()):
		var explosion: Dictionary = explosions[read_index]
		var timer_frames: float = float(explosion.get("timer_frames", 0.0)) - fps_scale
		if timer_frames <= 0.0:
			continue
		var max_timer_frames: float = max(
			1.0,
			float(explosion.get("max_timer_frames", _get_float(controller, "DYNAMITE_EXPLOSION_DURATION_FRAMES")))
		)
		explosion["timer_frames"] = timer_frames
		explosion["progress"] = 1.0 - timer_frames / max_timer_frames
		explosion["shockwave_radius"] = min(
			_get_float(controller, "DYNAMITE_EXPLOSION_RADIUS"),
			float(explosion.get("shockwave_radius", 0.0)) + 30.0 * fps_scale
		)
		var frames_elapsed: float = max_timer_frames - timer_frames

		var secondary_waves: Array = explosion.get("secondary_waves", [])
		for wave in secondary_waves:
			if not (wave is Dictionary):
				continue
			if frames_elapsed >= float(wave.get("delay_frames", 0.0)):
				wave["radius"] = float(wave.get("radius", 0.0)) + float(wave.get("speed", 18.0)) * fps_scale
		explosion["secondary_waves"] = secondary_waves

		explosion["particles"] = _update_particle_array(
			explosion.get("particles", []),
			fps_scale,
			0.4,
			0.95,
			0.97,
			-0.3,
			true
		)
		explosion["sparks"] = _update_particle_array(
			explosion.get("sparks", []),
			fps_scale,
			0.8,
			0.92,
			1.0,
			0.0,
			false
		)
		explosion["smoke_clouds"] = _update_smoke_clouds(explosion.get("smoke_clouds", []), fps_scale)
		explosions[write_index] = explosion
		write_index += 1
	if write_index < explosions.size():
		explosions.resize(write_index)


func apply_boss_effect(controller: Object, owner: Object, center: Vector2) -> void:
	_apply_boss_effect(controller, owner, center)


func _update_projectiles(controller: Object, registry: Object, fps_scale: float) -> void:
	var dynamites: Array = _get_array(controller, "dynamites")
	if dynamites.is_empty():
		return
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var field_height: float = _get_float(controller, "FIELD_HEIGHT", 750.0)
	var write_index := 0
	for read_index in range(dynamites.size()):
		var dynamite: Dictionary = dynamites[read_index]
		var pos: Vector2 = _get_vector2(dynamite, "position", Vector2.ZERO)
		var vel: Vector2 = _get_vector2(dynamite, "velocity", Vector2.ZERO)
		vel.y += _get_float(controller, "DYNAMITE_GRAVITY_PER_FRAME") * fps_scale
		pos += vel * fps_scale
		dynamite["position"] = pos
		dynamite["velocity"] = vel
		dynamite["rotation_degrees"] = fposmod(
			float(dynamite.get("rotation_degrees", 0.0))
			+ float(dynamite.get("rotation_speed", 10.0)) * fps_scale,
			360.0
		)
		var trail: Array = dynamite.get("trail", [])
		trail.append(pos)
		while trail.size() > 6:
			trail.pop_front()
		dynamite["trail"] = trail

		if pos.x <= 10.0:
			pos.x = 10.0
			vel.x = abs(vel.x) * 0.8
			dynamite["position"] = pos
			dynamite["velocity"] = vel
		elif pos.x >= field_width - 10.0:
			pos.x = field_width - 10.0
			vel.x = -abs(vel.x) * 0.8
			dynamite["position"] = pos
			dynamite["velocity"] = vel

		if pos.y <= _get_float(controller, "DYNAMITE_LAND_Y"):
			var placed_pos: Vector2 = _get_vector2(dynamite, "target_position", pos)
			placed_pos.y = _get_float(controller, "DYNAMITE_LAND_Y")
			place_dynamite(controller, placed_pos, registry)
			continue
		if pos.y > field_height + 50.0:
			continue
		dynamites[write_index] = dynamite
		write_index += 1
	if write_index < dynamites.size():
		dynamites.resize(write_index)


func _update_placed(controller: Object, owner: Object, registry: Object, fps_scale: float) -> void:
	var placed_dynamites: Array = _get_array(controller, "placed_dynamites")
	if placed_dynamites.is_empty():
		return
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(
		owner,
		"boss_pos",
		Vector2(field_width * 0.5 - 50.0, 25.0)
	)
	var boss_center_x: float = boss_pos.x + 50.0
	var write_index := 0
	for read_index in range(placed_dynamites.size()):
		var placed: Dictionary = placed_dynamites[read_index]
		var pos: Vector2 = _get_vector2(
			placed,
			"position",
			Vector2(field_width * 0.5, _get_float(controller, "DYNAMITE_PLACED_MAX_Y"))
		)
		var nudge_vx: float = float(placed.get("nudge_vx", 0.0))
		var wobble_angle: float = float(placed.get("wobble_angle", 0.0))
		var wobble_vel: float = float(placed.get("wobble_vel", 0.0))
		var prox_dx: float = boss_center_x - pos.x
		var abs_dx: float = abs(prox_dx)
		if abs_dx < _get_float(controller, "DYNAMITE_PUSH_RANGE") and abs_dx > 1.0:
			var push_strength: float = (
				(1.0 - abs_dx / _get_float(controller, "DYNAMITE_PUSH_RANGE"))
				* _get_float(controller, "DYNAMITE_PUSH_STRENGTH")
			)
			var push_dir_x: float = -1.0 if prox_dx > 0.0 else 1.0
			nudge_vx += push_dir_x * push_strength * fps_scale
			wobble_vel += push_dir_x * push_strength * 2.5 * fps_scale
		nudge_vx = clamp(nudge_vx, -3.0, 3.0)

		if abs(nudge_vx) > 0.05:
			pos.x += nudge_vx * fps_scale
			nudge_vx *= pow(0.80, fps_scale)
			pos.x = clamp(pos.x, 20.0, field_width - 20.0)
		else:
			nudge_vx = 0.0

		wobble_vel += -wobble_angle * 0.2 * fps_scale
		wobble_vel *= pow(0.85, fps_scale)
		wobble_angle = clamp(wobble_angle + wobble_vel * fps_scale, -12.0, 12.0)
		if abs(wobble_angle) < 0.3 and abs(wobble_vel) < 0.3:
			wobble_angle = 0.0
			wobble_vel = 0.0

		var countdown_frames: float = float(
			placed.get("countdown_frames", _get_float(controller, "DYNAMITE_COUNTDOWN_FRAMES"))
		) - fps_scale
		placed["position"] = pos
		placed["nudge_vx"] = nudge_vx
		placed["wobble_angle"] = wobble_angle
		placed["wobble_vel"] = wobble_vel
		placed["countdown_frames"] = countdown_frames
		placed["pulse_timer"] = float(placed.get("pulse_timer", 0.0)) + fps_scale
		if countdown_frames <= 0.0:
			stop_fuse(placed, registry)
			trigger_explosion(controller, owner, registry, pos)
			continue
		placed_dynamites[write_index] = placed
		write_index += 1
	if write_index < placed_dynamites.size():
		placed_dynamites.resize(write_index)


func _seed_explosion_particles(controller: Object, explosion: Dictionary, center: Vector2) -> void:
	var particles: Array = explosion.get("particles", [])
	for _i in range(int(_get_float(controller, "DYNAMITE_EXPLOSION_FIRE_PARTICLE_COUNT"))):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(12.0, 35.0)
		var color_types: Array = _get_array(controller, "DYNAMITE_PARTICLE_COLOR_TYPES")
		var color_type: String = "fire"
		if not color_types.is_empty():
			color_type = str(color_types[randi() % color_types.size()])
		particles.append({
			"position": center,
			"velocity": Vector2(cos(angle), sin(angle)) * speed + Vector2(0.0, -5.0),
			"size": randf_range(3.0, 14.0),
			"color_type": color_type,
			"life_frames": randf_range(15.0, 30.0),
			"max_life_frames": 30.0,
		})
	explosion["particles"] = particles

	var sparks: Array = explosion.get("sparks", [])
	for _i in range(int(_get_float(controller, "DYNAMITE_EXPLOSION_SPARK_COUNT"))):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(25.0, 50.0)
		sparks.append({
			"position": center,
			"velocity": Vector2(cos(angle), sin(angle)) * speed + Vector2(0.0, -8.0),
			"life_frames": randf_range(10.0, 20.0),
			"max_life_frames": 20.0,
		})
	explosion["sparks"] = sparks

	var smoke_clouds: Array = explosion.get("smoke_clouds", [])
	for _i in range(int(_get_float(controller, "DYNAMITE_EXPLOSION_SMOKE_CLOUD_COUNT"))):
		var angle: float = randf_range(0.0, TAU)
		var distance: float = randf_range(20.0, 60.0)
		smoke_clouds.append({
			"position": center + Vector2(cos(angle), sin(angle)) * distance,
			"velocity": Vector2(cos(angle) * 2.0, -randf_range(1.0, 3.0)),
			"size": randf_range(20.0, 40.0),
			"life_frames": randf_range(20.0, 36.0),
			"max_life_frames": 36.0,
		})
	explosion["smoke_clouds"] = smoke_clouds


func _apply_boss_effect(controller: Object, owner: Object, center: Vector2) -> void:
	if owner == null:
		return
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(
		owner,
		"boss_pos",
		Vector2(field_width * 0.5 - 50.0, 25.0)
	)
	var boss_center := Vector2(boss_pos.x + 50.0, boss_pos.y + 20.0)
	if boss_center.distance_to(center) > _get_float(controller, "DYNAMITE_EXPLOSION_RADIUS"):
		return
	_set_float(
		controller,
		"grenade_boss_stun_timer_frames",
		max(_get_float(controller, "grenade_boss_stun_timer_frames"), _get_float(controller, "DYNAMITE_BOSS_STUN_FRAMES"))
	)
	_set_float(
		controller,
		"grenade_boss_knockback_timer_frames",
		max(
			_get_float(controller, "grenade_boss_knockback_timer_frames"),
			_get_float(controller, "DYNAMITE_BOSS_KNOCKBACK_FRAMES")
		)
	)
	var direction: float = 1.0 if boss_center.x >= center.x else -1.0
	var knockback_vel: float = direction * _get_float(controller, "DYNAMITE_BOSS_KNOCKBACK_POWER")
	if abs(knockback_vel) >= abs(_get_float(controller, "grenade_boss_knockback_vel")):
		_set_float(controller, "grenade_boss_knockback_vel", knockback_vel)


func _update_particle_array(
	particles: Array,
	fps_scale: float,
	gravity: float,
	x_friction: float,
	y_friction: float,
	size_delta: float,
	has_size: bool
) -> Array:
	var write_index := 0
	for read_index in range(particles.size()):
		var particle_value: Variant = particles[read_index]
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var life_frames: float = float(particle.get("life_frames", 0.0)) - fps_scale
		if life_frames <= 0.0:
			continue
		var pos: Vector2 = _get_vector2(particle, "position", Vector2.ZERO)
		var velocity: Vector2 = _get_vector2(particle, "velocity", Vector2.ZERO)
		pos += velocity * fps_scale
		velocity.y += gravity * fps_scale
		velocity.x *= pow(x_friction, fps_scale)
		velocity.y *= pow(y_friction, fps_scale)
		particle["life_frames"] = life_frames
		particle["position"] = pos
		particle["velocity"] = velocity
		if has_size:
			particle["size"] = max(0.5, float(particle.get("size", 1.0)) + size_delta * fps_scale)
		particles[write_index] = particle
		write_index += 1
	if write_index < particles.size():
		particles.resize(write_index)
	return particles


func _update_smoke_clouds(smoke_clouds: Array, fps_scale: float) -> Array:
	var write_index := 0
	for read_index in range(smoke_clouds.size()):
		var cloud_value: Variant = smoke_clouds[read_index]
		if not (cloud_value is Dictionary):
			continue
		var cloud: Dictionary = cloud_value
		var life_frames: float = float(cloud.get("life_frames", 0.0)) - fps_scale
		if life_frames <= 0.0:
			continue
		var pos: Vector2 = _get_vector2(cloud, "position", Vector2.ZERO)
		var velocity: Vector2 = _get_vector2(cloud, "velocity", Vector2.ZERO)
		pos += velocity * fps_scale
		cloud["life_frames"] = life_frames
		cloud["position"] = pos
		cloud["size"] = float(cloud.get("size", 20.0)) + 0.8 * fps_scale
		smoke_clouds[write_index] = cloud
		write_index += 1
	if write_index < smoke_clouds.size():
		smoke_clouds.resize(write_index)
	return smoke_clouds


func _get_player_throw_start(owner: Object, pending_throw: Dictionary, y_offset: float) -> Vector2:
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(
		owner,
		"player_pos",
		_get_vector2(pending_throw, "start_position", Vector2.ZERO)
	)
	return Vector2(player_pos.x + 155.0 * 0.5, player_pos.y + y_offset)


func _estimate_rising_crossing_frames(start_y: float, target_y: float, speed_per_frame: float, gravity_per_frame: float) -> float:
	var vertical_distance: float = abs(start_y - target_y)
	var speed: float = max(0.001, speed_per_frame)
	var gravity: float = max(0.0, gravity_per_frame)
	if vertical_distance <= 0.001 or gravity <= 0.001:
		return max(1.0, vertical_distance / speed)

	var a: float = gravity * 0.5
	var b: float = gravity * 0.5 - speed
	var c: float = vertical_distance
	var discriminant: float = b * b - 4.0 * a * c
	if discriminant <= 0.0:
		return max(1.0, vertical_distance / speed)
	var root := (-b - sqrt(discriminant)) / (2.0 * a)
	return max(1.0, root)


func _play_throw_audio(registry: Object) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_throw"):
		audio.play_throw()


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
	if source != null:
		source.set(key, value)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
