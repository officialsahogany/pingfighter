extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")


func get_gauntlet_context(registry: Object) -> Dictionary:
	var runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if runtime == null:
		return {
			"equipped": false,
			"launch_speed_multiplier": 1.0,
			"homing_multiplier": 1.0,
			"knockback_multiplier": 1.0,
			"stun_multiplier": 1.0,
	}
	var equipped := false
	if runtime.has_method("is_reinforced_boomerang_gauntlet_effect_active"):
		equipped = bool(runtime.is_reinforced_boomerang_gauntlet_effect_active())
	elif runtime.has_method("is_reinforced_boomerang_gauntlet_equipped"):
		equipped = bool(runtime.is_reinforced_boomerang_gauntlet_equipped())
	return {
		"equipped": equipped,
		"launch_speed_multiplier": (
			float(runtime.get_boomerang_launch_speed_multiplier())
			if equipped and runtime.has_method("get_boomerang_launch_speed_multiplier")
			else 1.0
		),
		"homing_multiplier": (
			float(runtime.get_boomerang_homing_multiplier())
			if equipped and runtime.has_method("get_boomerang_homing_multiplier")
			else 1.0
		),
		"knockback_multiplier": (
			float(runtime.get_boomerang_knockback_multiplier())
			if equipped and runtime.has_method("get_boomerang_knockback_multiplier")
			else 1.0
		),
		"stun_multiplier": (
			float(runtime.get_boomerang_stun_multiplier())
			if equipped and runtime.has_method("get_boomerang_stun_multiplier")
			else 1.0
		),
	}


func throw_boomerang(controller: Object, owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", _get_vector2(pending_throw, "start_position", Vector2.ZERO))
	var start_pos := Vector2(player_pos.x + 155.0 * 0.5, player_pos.y + 25.0)
	var target_pos: Vector2 = _get_vector2(
		pending_throw,
		"target_position",
		Vector2(start_pos.x, _get_float(controller, "BOOMERANG_MAX_TRAVEL_Y", 25.0))
	)
	var curve_dir: int = -1 if randf() < 0.5 else 1
	var gauntlet_context: Dictionary = get_gauntlet_context(registry)
	var gauntlet_equipped: bool = bool(gauntlet_context.get("equipped", false))
	var commando_speed_multiplier: float = _get_commando_boomerang_speed_multiplier(controller, registry)
	var speed_jitter: float = (
		randf_range(0.95, 1.05) * float(gauntlet_context.get("launch_speed_multiplier", 1.0)) * commando_speed_multiplier
		if gauntlet_equipped
		else commando_speed_multiplier
	)
	_get_array(controller, "boomerangs").append({
		"position": start_pos,
		"start_position": start_pos,
		"phase": "outgoing",
		"travel_t": 0.0,
		"angle_degrees": 0.0,
		"curve_dir": curve_dir,
		"main_amp": _get_float(controller, "BOOMERANG_CURVE_AMPLITUDE", 60.0) * (randf_range(0.9, 1.1) if gauntlet_equipped else randf_range(0.7, 1.4)),
		"wobble_amp": randf_range(3.0, 8.0) if gauntlet_equipped else randf_range(8.0, 20.0),
		"wobble_freq": randf_range(2.0, 3.2) if gauntlet_equipped else randf_range(2.5, 4.5),
		"wind_drift": randf_range(-8.0, 8.0) if gauntlet_equipped else randf_range(-25.0, 25.0),
		"speed_jitter": speed_jitter,
		"homing_offset_x": 0.0,
		"homing_multiplier": float(gauntlet_context.get("homing_multiplier", 1.0)),
		"knockback_multiplier": float(gauntlet_context.get("knockback_multiplier", 1.0)),
		"stun_multiplier": float(gauntlet_context.get("stun_multiplier", 1.0)),
		"gauntlet_equipped": gauntlet_equipped,
		"commando_arm_speed_multiplier": commando_speed_multiplier,
		"target_boss_x": target_pos.x,
		"hit_boss": false,
		"return_wobble_phase": randf_range(0.0, TAU),
		"return_wobble_amp": randf_range(15.0, 35.0) * (0.5 if gauntlet_equipped else 1.0),
		"return_wobble_freq": randf_range(0.08, 0.15),
		"return_ramp_t": 0.0,
		"picked_items": [],
		"trail": [start_pos],
	})

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null:
		if audio.has_method("play_throw"):
			audio.play_throw()
		if audio.has_method("play_boomerang_loop"):
			audio.play_boomerang_loop()


func update_boomerangs(
	controller: Object,
	owner: Object,
	registry: Object,
	delta: float,
	collect_items_callback: Callable,
	boomerang_return_callback: Callable
) -> void:
	var boomerangs: Array = _get_array(controller, "boomerangs")
	if boomerangs.is_empty():
		return

	var fps_scale: float = delta * 60.0
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var field_height: float = _get_float(controller, "FIELD_HEIGHT", 750.0)
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2(field_width * 0.5 - 77.5, field_height - 50.0))
	var player_center := Vector2(player_pos.x + 155.0 * 0.5, player_pos.y + 25.0)
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "boss_pos", Vector2(field_width * 0.5 - 50.0, 25.0))
	var boss_rect := Rect2(boss_pos, Vector2(100.0, 40.0))
	var ball_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_pos", Vector2.ZERO)
	var ball_active: bool = bool(BattleSceneOwnerReader.get_value(owner, "ball_active", false))
	var ball_rect := Rect2(ball_pos - Vector2(14.3, 14.3), Vector2(28.6, 28.6))
	var write_index := 0
	for read_index in range(boomerangs.size()):
		var boomerang: Dictionary = boomerangs[read_index]
		var pos: Vector2 = _get_vector2(boomerang, "position", player_center)
		var phase: String = str(boomerang.get("phase", "outgoing"))
		boomerang["angle_degrees"] = fposmod(
			float(boomerang.get("angle_degrees", 0.0))
			+ _get_float(controller, "BOOMERANG_ROTATION_SPEED", 18.0) * fps_scale,
			360.0
		)

		if phase == "outgoing":
			pos = update_outgoing(controller, boomerang, boss_rect, fps_scale)
			boomerang["position"] = pos
			try_apply_boss_hit(controller, boomerang, boss_rect, registry)
			if ball_active and intersects_rect(controller, pos, ball_rect):
				spawn_break_particles(controller, pos)
				play_destroyed_audio(registry)
				continue
			if float(boomerang.get("travel_t", 0.0)) >= 1.0:
				boomerang["phase"] = "returning"
				boomerang["start_position"] = pos

		else:
			pos = update_returning(controller, boomerang, player_center, fps_scale)
			boomerang["position"] = pos
			collect_items(controller, boomerang, pos, collect_items_callback)
			if ball_active and intersects_rect(controller, pos, ball_rect):
				spawn_break_particles(controller, pos)
				play_destroyed_audio(registry)
				continue
			if pos.distance_to(player_center) < 30.0:
				if boomerang_return_callback.is_valid():
					boomerang_return_callback.call(owner, {"picked_items": boomerang.get("picked_items", [])}, registry)
				play_returned_audio(registry)
				continue

		add_trail_point(controller, boomerang, pos)
		spawn_trail_particle(controller, pos, bool(boomerang.get("gauntlet_equipped", false)))
		boomerangs[write_index] = boomerang
		write_index += 1

	if write_index < boomerangs.size():
		boomerangs.resize(write_index)
	if boomerangs.is_empty():
		var audio: Object = _get_instance(registry, "game_audio")
		if audio != null and audio.has_method("stop_boomerang_loop"):
			audio.stop_boomerang_loop()


func update_outgoing(controller: Object, boomerang: Dictionary, boss_rect: Rect2, fps_scale: float) -> Vector2:
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var field_height: float = _get_float(controller, "FIELD_HEIGHT", 750.0)
	var max_travel_y: float = _get_float(controller, "BOOMERANG_MAX_TRAVEL_Y", 25.0)
	var curve_amplitude: float = _get_float(controller, "BOOMERANG_CURVE_AMPLITUDE", 60.0)
	var homing_strength: float = _get_float(controller, "BOOMERANG_HOMING_STRENGTH", 0.35)
	var start_pos: Vector2 = _get_vector2(boomerang, "start_position", Vector2(field_width * 0.5, field_height - 50.0))
	var travel_height: float = max(1.0, start_pos.y - max_travel_y)
	var speed_multiplier: float = max(0.05, float(boomerang.get("speed_jitter", 1.0)))
	var travel_t: float = min(
		1.0,
		float(boomerang.get("travel_t", 0.0)) + (_get_float(controller, "BOOMERANG_SPEED_PER_FRAME", 9.8) * speed_multiplier / travel_height) * fps_scale
	)
	boomerang["travel_t"] = travel_t

	var boss_center_x: float = boss_rect.position.x + boss_rect.size.x * 0.5
	if bool(boomerang.get("gauntlet_equipped", false)):
		var eased_t: float = 1.0 - pow(1.0 - travel_t, 3.0)
		var target_boss_x: float = float(boomerang.get("target_boss_x", boss_center_x))
		var direct_x: float = lerp(start_pos.x, target_boss_x, eased_t)
		var arc_offset: float = sin(travel_t * PI) * float(boomerang.get("main_amp", curve_amplitude)) * 0.6 * float(boomerang.get("curve_dir", 1))
		var wobble_boost: float = sin(travel_t * PI * float(boomerang.get("wobble_freq", 2.6))) * float(boomerang.get("wobble_amp", 4.0))
		var drift_boost: float = float(boomerang.get("wind_drift", 0.0)) * travel_t
		var base_boost_x: float = direct_x + arc_offset + wobble_boost + drift_boost
		var homing_boost: float = max(0.0, travel_t - 0.15) * homing_strength * float(boomerang.get("homing_multiplier", 1.0))
		var offset_boost: float = float(boomerang.get("homing_offset_x", 0.0))
		offset_boost += (boss_center_x - base_boost_x) * homing_boost * 0.10 * fps_scale
		offset_boost = clamp(offset_boost, -field_width * 0.5, field_width * 0.5)
		boomerang["homing_offset_x"] = offset_boost
		return Vector2(
			clamp(base_boost_x + offset_boost, 10.0, field_width - 10.0),
			lerp(start_pos.y, max_travel_y, eased_t)
		)

	var main_curve: float = sin(travel_t * PI * 1.2) * float(boomerang.get("main_amp", curve_amplitude)) * float(boomerang.get("curve_dir", 1))
	var wobble: float = sin(travel_t * PI * float(boomerang.get("wobble_freq", 3.0))) * float(boomerang.get("wobble_amp", 12.0))
	var drift: float = float(boomerang.get("wind_drift", 0.0)) * travel_t
	var base_x: float = start_pos.x + main_curve + wobble + drift + randf_range(-1.5, 1.5)

	var homing_factor: float = max(0.0, travel_t - 0.2) * homing_strength
	var homing_offset: float = float(boomerang.get("homing_offset_x", 0.0))
	homing_offset += (boss_center_x - base_x) * homing_factor * 0.08 * fps_scale
	homing_offset = clamp(homing_offset, -field_width * 0.4, field_width * 0.4)
	boomerang["homing_offset_x"] = homing_offset

	return Vector2(
		clamp(base_x + homing_offset, 10.0, field_width - 10.0),
		lerp(start_pos.y, max_travel_y, travel_t)
	)


func update_returning(controller: Object, boomerang: Dictionary, player_center: Vector2, fps_scale: float) -> Vector2:
	var pos: Vector2 = _get_vector2(boomerang, "position", player_center)
	var to_player: Vector2 = player_center - pos
	var distance: float = to_player.length()
	if distance <= 0.001:
		return pos

	var direction: Vector2 = to_player / distance
	var perpendicular := Vector2(-direction.y, direction.x)
	var phase: float = float(boomerang.get("return_wobble_phase", 0.0)) + float(boomerang.get("return_wobble_freq", 0.1)) * fps_scale
	boomerang["return_wobble_phase"] = phase
	var lateral: float = sin(phase) * float(boomerang.get("return_wobble_amp", 22.0)) * min(1.0, distance / 200.0)
	var speed_multiplier: float = max(0.05, float(boomerang.get("speed_jitter", 1.0)))
	var return_ramp := 1.0
	if bool(boomerang.get("gauntlet_equipped", false)):
		var ramp_t: float = min(1.0, float(boomerang.get("return_ramp_t", 0.0)) + fps_scale / 48.0)
		boomerang["return_ramp_t"] = ramp_t
		return_ramp = 0.5 + 1.1 * ramp_t * ramp_t
	return (
		pos
		+ direction * _get_float(controller, "BOOMERANG_RETURN_SPEED_PER_FRAME", 8.4) * speed_multiplier * return_ramp * fps_scale
		+ perpendicular * lateral * 0.15 * fps_scale
	)


func try_apply_boss_hit(controller: Object, boomerang: Dictionary, boss_rect: Rect2, registry: Object) -> void:
	if bool(boomerang.get("hit_boss", false)):
		return
	var pos: Vector2 = _get_vector2(boomerang, "position", Vector2.ZERO)
	if not intersects_rect(controller, pos, boss_rect):
		return

	boomerang["hit_boss"] = true
	var stun_multiplier: float = max(0.0, float(boomerang.get("stun_multiplier", 1.0)))
	var knockback_multiplier: float = max(0.0, float(boomerang.get("knockback_multiplier", 1.0)))
	_set_float(
		controller,
		"grenade_boss_stun_timer_frames",
		max(_get_float(controller, "grenade_boss_stun_timer_frames"), _get_float(controller, "BOOMERANG_STUN_FRAMES", 36.0) * stun_multiplier)
	)
	_set_float(
		controller,
		"grenade_boss_knockback_timer_frames",
		max(_get_float(controller, "grenade_boss_knockback_timer_frames"), _get_float(controller, "BOOMERANG_KNOCKBACK_FRAMES", 15.0))
	)
	var boss_center_x: float = boss_rect.position.x + boss_rect.size.x * 0.5
	var direction: float = 1.0 if pos.x >= boss_center_x else -1.0
	var knockback_vel: float = direction * _get_float(controller, "BOOMERANG_KNOCKBACK_POWER", 28.0) * knockback_multiplier
	if abs(knockback_vel) >= abs(_get_float(controller, "grenade_boss_knockback_vel")):
		_set_float(controller, "grenade_boss_knockback_vel", knockback_vel)

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null:
		if audio.has_method("play_boomerang_hit"):
			audio.play_boomerang_hit()
		elif audio.has_method("play_paddle_hit"):
			audio.play_paddle_hit()


func collect_items(controller: Object, boomerang: Dictionary, pos: Vector2, collect_items_callback: Callable) -> void:
	if not collect_items_callback.is_valid():
		return
	var picked_value: Variant = collect_items_callback.call(pos, _get_float(controller, "BOOMERANG_ITEM_PICKUP_RADIUS", 55.0))
	if not (picked_value is Array):
		return
	var picked_items: Array = boomerang.get("picked_items", [])
	for picked in picked_value:
		if picked is Dictionary:
			picked_items.append(picked)
	boomerang["picked_items"] = picked_items


func intersects_rect(controller: Object, pos: Vector2, target_rect: Rect2) -> bool:
	var collision_size: float = _get_float(controller, "BOOMERANG_COLLISION_SIZE", 31.0)
	var boomerang_rect := Rect2(
		pos - Vector2(collision_size, collision_size) * 0.5,
		Vector2(collision_size, collision_size)
	)
	return boomerang_rect.intersects(target_rect)


func add_trail_point(controller: Object, boomerang: Dictionary, pos: Vector2) -> void:
	var trail: Array = boomerang.get("trail", [])
	trail.append(pos)
	while trail.size() > int(_get_float(controller, "BOOMERANG_TRAIL_MAX_POINTS", 10.0)):
		trail.pop_front()
	boomerang["trail"] = trail


func spawn_trail_particle(controller: Object, pos: Vector2, gauntlet_equipped: bool = false) -> void:
	if randf() >= 0.4:
		return
	var colors := [
		Color(200.0 / 255.0, 150.0 / 255.0, 80.0 / 255.0, 0.78),
		Color(220.0 / 255.0, 180.0 / 255.0, 100.0 / 255.0, 0.78),
		Color(180.0 / 255.0, 120.0 / 255.0, 60.0 / 255.0, 0.78),
		Color(1.0, 210.0 / 255.0, 120.0 / 255.0, 0.78),
	]
	if gauntlet_equipped:
		colors = [
			Color(110.0 / 255.0, 220.0 / 255.0, 1.0, 0.84),
			Color(170.0 / 255.0, 245.0 / 255.0, 1.0, 0.78),
			Color(230.0 / 255.0, 1.0, 1.0, 0.72),
			Color(80.0 / 255.0, 180.0 / 255.0, 1.0, 0.70),
		]
	_get_array(controller, "boomerang_particles").append({
		"position": pos + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)),
		"velocity": Vector2.ZERO,
		"age": 0.0,
		"lifetime": 0.58 if gauntlet_equipped else 0.48,
		"radius": randf_range(2.5, 5.8) if gauntlet_equipped else randf_range(2.0, 5.0),
		"color": colors[randi() % colors.size()],
	})


func spawn_break_particles(controller: Object, pos: Vector2) -> void:
	var colors := [
		Color(180.0 / 255.0, 120.0 / 255.0, 60.0 / 255.0, 1.0),
		Color(160.0 / 255.0, 100.0 / 255.0, 40.0 / 255.0, 1.0),
		Color(140.0 / 255.0, 85.0 / 255.0, 35.0 / 255.0, 1.0),
		Color(200.0 / 255.0, 150.0 / 255.0, 80.0 / 255.0, 1.0),
		Color(230.0 / 255.0, 60.0 / 255.0, 50.0 / 255.0, 1.0),
		Color(60.0 / 255.0, 140.0 / 255.0, 230.0 / 255.0, 1.0),
	]
	var particles: Array = _get_array(controller, "boomerang_particles")
	for _i in range(int(_get_float(controller, "BOOMERANG_BREAK_PARTICLE_COUNT", 22.0))):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(1.2, 7.0)
		particles.append({
			"position": pos + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0)),
			"velocity": Vector2(cos(angle), sin(angle)) * speed + Vector2(0.0, -randf_range(0.6, 2.4)),
			"age": 0.0,
			"lifetime": _get_float(controller, "BOOMERANG_BREAK_PARTICLE_DURATION_SEC", 0.86),
			"radius": randf_range(2.0, 7.0),
			"color": colors[randi() % colors.size()],
		})


func update_particles(controller: Object, delta: float) -> void:
	var particles: Array = _get_array(controller, "boomerang_particles")
	if particles.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var write_index := 0
	for read_index in range(particles.size()):
		var particle: Dictionary = particles[read_index]
		var age: float = float(particle.get("age", 0.0)) + delta
		var lifetime: float = max(0.001, float(particle.get("lifetime", _get_float(controller, "BOOMERANG_BREAK_PARTICLE_DURATION_SEC", 0.86))))
		if age >= lifetime:
			continue
		var pos: Vector2 = _get_vector2(particle, "position", Vector2.ZERO)
		var velocity: Vector2 = _get_vector2(particle, "velocity", Vector2.ZERO)
		pos += velocity * fps_scale
		velocity.y += 0.15 * fps_scale
		velocity.x *= pow(0.98, fps_scale)
		particle["age"] = age
		particle["position"] = pos
		particle["velocity"] = velocity
		particles[write_index] = particle
		write_index += 1
	if write_index < particles.size():
		particles.resize(write_index)


func play_destroyed_audio(registry: Object) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_boomerang_break"):
		audio.play_boomerang_break()
	elif audio.has_method("play_boomerang_hit"):
		audio.play_boomerang_hit()


func play_returned_audio(registry: Object) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_item_get"):
		audio.play_item_get()


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


func _get_commando_boomerang_speed_multiplier(controller: Object, registry: Object) -> float:
	if controller != null and controller.has_method("get_commando_arm_throw_speed_multiplier"):
		return max(0.0, float(controller.get_commando_arm_throw_speed_multiplier(registry, true)))
	return 1.0


func _set_float(source: Object, key: String, value: float) -> void:
	if source == null:
		return
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
