extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")


func throw_tear_gas(controller: Object, owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	var start_pos: Vector2 = _get_player_throw_start(owner, pending_throw, 25.0)
	var target_pos: Vector2 = _get_vector2(pending_throw, "target_position", start_pos + Vector2(0.0, -120.0))
	var direction: Vector2 = target_pos - start_pos
	if direction.length() <= 0.001:
		direction = Vector2.UP
	else:
		direction = direction.normalized()
	direction = direction.rotated(deg_to_rad(randf_range(
		-_get_float(controller, "TEAR_GAS_AIM_ERROR_DEGREES"),
		_get_float(controller, "TEAR_GAS_AIM_ERROR_DEGREES")
	)))
	_get_array(controller, "tear_gas_projectiles").append({
		"position": start_pos,
		"velocity": direction * _get_float(controller, "TEAR_GAS_SPEED_PER_FRAME"),
		"target_position": target_pos,
		"rotation_degrees": 0.0,
		"timer_frames": 0.0,
		"emitted": false,
		"arrived": false,
		"trail": [start_pos],
	})

	_play_throw_audio(registry)


func update_projectiles(controller: Object, owner: Object, registry: Object, delta: float) -> void:
	var projectiles: Array = _get_array(controller, "tear_gas_projectiles")
	if projectiles.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var write_index := 0
	for read_index in range(projectiles.size()):
		var projectile: Dictionary = projectiles[read_index]
		var arrived: bool = bool(projectile.get("arrived", false))
		var emitted: bool = bool(projectile.get("emitted", false))
		var pos: Vector2 = _get_vector2(projectile, "position", Vector2.ZERO)
		var vel: Vector2 = _get_vector2(projectile, "velocity", Vector2.ZERO)
		var target: Vector2 = _get_vector2(projectile, "target_position", pos)

		if not arrived:
			pos += vel * fps_scale
			projectile["position"] = pos
			projectile["velocity"] = vel
			projectile["rotation_degrees"] = fposmod(
				float(projectile.get("rotation_degrees", 0.0)) + 13.0 * fps_scale,
				360.0
			)
			var trail: Array = projectile.get("trail", [])
			trail.append(pos)
			while trail.size() > 6:
				trail.pop_front()
			projectile["trail"] = trail

			var wall_margin := 10.0
			var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
			if pos.x <= wall_margin:
				pos.x = wall_margin
				vel.x = abs(vel.x) * 0.7
				if vel.y > 0.0:
					vel.y = -abs(vel.y) * 0.5
				projectile["position"] = pos
				projectile["velocity"] = vel
			elif pos.x >= field_width - wall_margin:
				pos.x = field_width - wall_margin
				vel.x = -abs(vel.x) * 0.7
				if vel.y > 0.0:
					vel.y = -abs(vel.y) * 0.5
				projectile["position"] = pos
				projectile["velocity"] = vel

			if (
				pos.x < -100.0
				or pos.x > field_width + 100.0
				or pos.y > _get_float(controller, "FIELD_HEIGHT", 750.0) + 100.0
			):
				continue
			if (
				pos.distance_to(target) < _get_float(controller, "TEAR_GAS_TARGET_REACHED_DISTANCE")
				or pos.y <= 10.0
			):
				projectile["position"] = target if pos.y > 10.0 else Vector2(pos.x, 10.0)
				projectile["arrived"] = true
				projectile["timer_frames"] = 0.0
			projectiles[write_index] = projectile
			write_index += 1
			continue

		if not emitted:
			var timer_frames: float = float(projectile.get("timer_frames", 0.0)) + fps_scale
			projectile["timer_frames"] = timer_frames
			if timer_frames >= _get_float(controller, "TEAR_GAS_ARMED_DELAY_FRAMES"):
				projectile["emitted"] = true
				trigger_zone(controller, registry, pos, owner)
				continue
			projectiles[write_index] = projectile
			write_index += 1
	if write_index < projectiles.size():
		projectiles.resize(write_index)


func update_zones(controller: Object, owner: Object, registry: Object, delta: float) -> void:
	var zones: Array = _get_array(controller, "tear_gas_zones")
	if zones.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(
		owner,
		"boss_pos",
		Vector2(field_width * 0.5 - 50.0, 25.0)
	)
	var boss_width: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "boss_paddle_width", 100.0)))
	var boss_height: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "boss_hitbox_height", 40.0)))
	var max_opacity: float = _get_float(controller, "TEAR_GAS_MAX_OPACITY", 0.82)
	var write_index := 0
	for read_index in range(zones.size()):
		var zone: Dictionary = zones[read_index]
		var remaining: float = float(zone.get("duration_frames", _get_float(controller, "TEAR_GAS_ZONE_DURATION_FRAMES"))) - fps_scale
		if remaining <= 0.0:
			_notify_stage4_smoke_zone_expired(owner, registry, zone)
			continue
		zone["duration_frames"] = remaining
		var max_duration: float = max(
			1.0,
			float(zone.get("max_duration_frames", _get_float(controller, "TEAR_GAS_ZONE_DURATION_FRAMES")))
		)
		var elapsed: float = max_duration - remaining
		zone["radius"] = min(
			_get_float(controller, "TEAR_GAS_MAX_RADIUS"),
			float(zone.get("radius", 0.0)) + _get_float(controller, "TEAR_GAS_EXPANSION_RATE") * fps_scale
		)
		zone["radius_x"] = min(
			_get_float(controller, "TEAR_GAS_MAX_RADIUS_X"),
			float(zone.get("radius_x", 0.0)) + _get_float(controller, "TEAR_GAS_EXPANSION_RATE_X") * fps_scale
		)
		if elapsed < 30.0:
			zone["opacity"] = min(max_opacity, float(zone.get("opacity", 0.0)) + 0.045 * fps_scale)
		elif remaining < 60.0:
			zone["opacity"] = max(0.0, min(max_opacity, float(zone.get("opacity", max_opacity))) - 0.018 * fps_scale)
		else:
			zone["opacity"] = max_opacity

		var burst_timer: float = max(0.0, float(zone.get("burst_timer", 0.0)) - fps_scale)
		zone["burst_timer"] = burst_timer
		zone["burst_ring_radius"] = float(zone.get("burst_ring_radius", 0.0)) + 12.0 * fps_scale

		var center: Vector2 = _get_vector2(zone, "position", Vector2(field_width * 0.5, 120.0))
		var spawn_timer: float = float(zone.get("spawn_timer", 0.0)) + fps_scale
		if (
			remaining > 60.0
			and spawn_timer >= _get_float(controller, "TEAR_GAS_PARTICLE_SPAWN_INTERVAL_FRAMES")
		):
			spawn_timer = fmod(spawn_timer, _get_float(controller, "TEAR_GAS_PARTICLE_SPAWN_INTERVAL_FRAMES"))
			_seed_particles(controller, zone, center, int(_get_float(controller, "TEAR_GAS_PARTICLE_SPAWN_COUNT")))
		zone["spawn_timer"] = spawn_timer
		_update_zone_particles(controller, zone, fps_scale)
		_sync_stage4_brazier_from_zone(controller, owner, registry, zone)

		var radius_y: float = max(1.0, float(zone.get("radius", _get_float(controller, "TEAR_GAS_MAX_RADIUS"))))
		var radius_x: float = max(1.0, float(zone.get("radius_x", _get_float(controller, "TEAR_GAS_MAX_RADIUS_X"))))
		# Contact ellipse is scaled down to the VISIBLE smoke body so the pause
		# fires only when the boss is actually inside the rendered cloud, not the
		# (much larger) full expansion radius. The cloud is flatter vertically
		# than it is wide, so X and Y use SEPARATE scales (a shared scale left the
		# vertical reach ~2x the visible body and paused the top-of-field boss
		# while it was rendered above the cloud).
		var contact_scale_x: float = _get_float(controller, "TEAR_GAS_BOSS_CONTACT_RADIUS_SCALE_X", 0.66)
		var contact_scale_y: float = _get_float(controller, "TEAR_GAS_BOSS_CONTACT_RADIUS_SCALE_Y", 0.40)
		var in_gas: bool = (
			_is_boss_rect_in_gas(center, radius_x * contact_scale_x, radius_y * contact_scale_y, boss_pos, boss_width, boss_height)
			and float(zone.get("opacity", 0.0)) > 0.12
		)
		zone["boss_in_gas"] = in_gas
		if in_gas:
			_set_float(
				controller,
				"tear_gas_boss_pause_timer_frames",
				max(
					_get_float(controller, "tear_gas_boss_pause_timer_frames"),
					_get_float(controller, "TEAR_GAS_BOSS_PAUSE_LATCH_FRAMES")
				)
			)
			_set_float(
				controller,
				"tear_gas_boss_pause_text_timer_frames",
				max(
					_get_float(controller, "tear_gas_boss_pause_text_timer_frames"),
					_get_float(controller, "TEAR_GAS_TEXT_DURATION_FRAMES")
				)
			)

		zones[write_index] = zone
		write_index += 1
	if write_index < zones.size():
		zones.resize(write_index)


func trigger_zone(controller: Object, registry: Object, center: Vector2, owner: Object = null) -> void:
	var duration_frames: float = _get_commando_duration_frames(
		controller,
		registry,
		_get_float(controller, "TEAR_GAS_ZONE_DURATION_FRAMES")
	)
	var zone_center: Vector2 = _resolve_gas_zone_center(controller, center)
	var gas_zone := {
		"position": zone_center,
		"radius": 0.0,
		"max_radius": _get_float(controller, "TEAR_GAS_MAX_RADIUS"),
		"radius_x": 0.0,
		"max_radius_x": _get_float(controller, "TEAR_GAS_MAX_RADIUS_X"),
		"duration_frames": duration_frames,
		"max_duration_frames": duration_frames,
		"opacity": 0.0,
		"expansion_rate": _get_float(controller, "TEAR_GAS_EXPANSION_RATE"),
		"expansion_rate_x": _get_float(controller, "TEAR_GAS_EXPANSION_RATE_X"),
		"burst_timer": _get_float(controller, "TEAR_GAS_BURST_FRAMES"),
		"burst_ring_radius": 0.0,
		"particles": [],
		"spawn_timer": 0.0,
		"boss_in_gas": false,
	}
	_seed_initial_particles(controller, gas_zone, zone_center)
	_get_array(controller, "tear_gas_zones").append(gas_zone)
	_sync_stage4_brazier_from_zone(controller, owner, registry, gas_zone)

	var feedback: Object = _get_instance(registry, "battle_feedback_state")
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(0.07, 2.0)
	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null:
		if audio.has_method("play_smokebomb"):
			audio.play_smokebomb()
		elif audio.has_method("play_active_item"):
			audio.play_active_item()


func update_boss_pause(controller: Object, delta: float) -> void:
	var fps_scale: float = delta * 60.0
	var pause_frames: float = _get_float(controller, "tear_gas_boss_pause_timer_frames")
	if pause_frames > 0.0:
		_set_float(controller, "tear_gas_boss_pause_timer_frames", max(0.0, pause_frames - fps_scale))
	var text_frames: float = _get_float(controller, "tear_gas_boss_pause_text_timer_frames")
	if text_frames > 0.0:
		_set_float(controller, "tear_gas_boss_pause_text_timer_frames", max(0.0, text_frames - fps_scale))


func _sync_stage4_brazier_from_zone(_controller: Object, owner: Object, registry: Object, zone: Dictionary) -> void:
	if bool(zone.get("stage4_brazier_smoke", false)):
		return
	if int(BattleSceneOwnerReader.get_value(owner, "current_stage", 1)) != 4:
		return
	if float(zone.get("opacity", 0.0)) <= 0.12:
		return
	var radius: float = maxf(0.0, float(zone.get("radius", 0.0)))
	if radius < 50.0:
		return
	var center: Vector2 = _get_vector2(zone, "position", Vector2.ZERO)
	var deps: Dictionary = _build_stage4_deps(registry)
	var background: Object = _get_instance(registry, "stage4_pillar_background")
	var lit := false
	if background != null and background.has_method("check_smoke_touches_brazier"):
		lit = bool(background.check_smoke_touches_brazier(center.x, center.y, radius, deps))
	else:
		var map_state: Object = _get_instance(registry, "stage4_map_state")
		if map_state != null and map_state.has_method("check_smoke_touches_brazier"):
			lit = bool(map_state.check_smoke_touches_brazier(center.x, center.y, radius, deps))
	if lit:
		zone["stage4_brazier_smoke"] = true


func _notify_stage4_smoke_zone_expired(owner: Object, registry: Object, zone: Dictionary) -> void:
	if not bool(zone.get("stage4_brazier_smoke", false)):
		return
	if int(BattleSceneOwnerReader.get_value(owner, "current_stage", 1)) != 4:
		return
	var deps: Dictionary = _build_stage4_deps(registry)
	var background: Object = _get_instance(registry, "stage4_pillar_background")
	if background != null and background.has_method("trigger_smoke_grenade_monk_return"):
		background.trigger_smoke_grenade_monk_return(deps)
		return
	var map_state: Object = _get_instance(registry, "stage4_map_state")
	if map_state != null and map_state.has_method("trigger_smoke_grenade_monk_return"):
		map_state.trigger_smoke_grenade_monk_return(deps)


func _resolve_gas_zone_center(controller: Object, center: Vector2) -> Vector2:
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var radius_x: float = _get_float(controller, "TEAR_GAS_MAX_RADIUS_X", 240.0)
	var margin_x: float = min(field_width * 0.5, max(10.0, radius_x))
	return Vector2(
		clamp(center.x, margin_x, max(margin_x, field_width - margin_x)),
		center.y
	)


func _is_boss_rect_in_gas(
	center: Vector2,
	radius_x: float,
	radius_y: float,
	boss_pos: Vector2,
	boss_width: float,
	boss_height: float
) -> bool:
	var left: float = boss_pos.x
	var right: float = boss_pos.x + boss_width
	var top: float = boss_pos.y
	var bottom: float = boss_pos.y + boss_height
	var closest_x: float = clamp(center.x, min(left, right), max(left, right))
	var closest_y: float = clamp(center.y, min(top, bottom), max(top, bottom))
	var normalized_dx: float = (closest_x - center.x) / max(1.0, radius_x)
	var normalized_dy: float = (closest_y - center.y) / max(1.0, radius_y)
	return normalized_dx * normalized_dx + normalized_dy * normalized_dy <= 1.0


func _build_stage4_deps(registry: Object) -> Dictionary:
	return {
		"current_stage": 4,
		"registry": registry,
		"audio": _get_instance(registry, "game_audio"),
		"stage4_map_state": _get_instance(registry, "stage4_map_state"),
		"stage4_temple_destruction_event": _get_instance(registry, "stage4_temple_destruction_event"),
		"stage4_bird_event": _get_instance(registry, "stage4_bird_event"),
		"stage4_brazier_monk_event": _get_instance(registry, "stage4_brazier_monk_event"),
	}


func _seed_initial_particles(controller: Object, zone: Dictionary, center: Vector2) -> void:
	var particles: Array = zone.get("particles", [])
	for _i in range(16):
		var side := -1.0 if randf() < 0.5 else 1.0
		_append_particle(
			controller,
			particles,
			center,
			Vector2(randf_range(-20.0, 20.0), randf_range(-5.0, 5.0)),
			Vector2(side * randf_range(1.5, 4.5), randf_range(-0.8, -0.1)),
			randf_range(18.0, 35.0),
			randf_range(90.0, 160.0),
			160.0,
			"smoke_cloud",
			randf_range(1.3, 2.0),
			0.0,
			1.0
		)
	for _i in range(7):
		_append_particle(
			controller,
			particles,
			center,
			Vector2(randf_range(-40.0, 40.0), randf_range(-3.0, 3.0)),
			Vector2(randf_range(-0.5, 0.5), randf_range(-1.8, -0.4)),
			randf_range(8.0, 18.0),
			randf_range(50.0, 100.0),
			100.0,
			"smoke_pillar",
			randf_range(0.5, 0.8),
			0.3,
			1.0
		)
	for _i in range(6):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(1.0, 5.0)
		_append_particle(
			controller,
			particles,
			center,
			Vector2(randf_range(-15.0, 15.0), randf_range(-5.0, 5.0)),
			Vector2(cos(angle) * speed, sin(angle) * speed * 0.5 - 0.5),
			randf_range(2.0, 6.0),
			randf_range(20.0, 50.0),
			50.0,
			"smoke_wisp",
			1.0,
			0.5,
			1.0
		)
	for _i in range(3):
		var angle: float = randf_range(0.0, TAU)
		_append_particle(
			controller,
			particles,
			center,
			Vector2(cos(angle) * randf_range(5.0, 15.0), sin(angle) * randf_range(3.0, 8.0)),
			Vector2(cos(angle) * randf_range(2.0, 5.0), sin(angle) * randf_range(0.5, 2.0) - 0.8),
			randf_range(3.0, 7.0),
			randf_range(40.0, 80.0),
			80.0,
			"smoke_tendril",
			randf_range(1.5, 3.0),
			0.7,
			1.0
		)
	zone["particles"] = particles


func _seed_particles(controller: Object, zone: Dictionary, center: Vector2, count: int) -> void:
	var particles: Array = zone.get("particles", [])
	var remaining_capacity: int = max(0, int(_get_float(controller, "TEAR_GAS_PARTICLE_CAP")) - particles.size())
	var spawn_count: int = min(count, remaining_capacity)
	var radius_x: float = max(1.0, float(zone.get("radius_x", 30.0)))
	var radius_y: float = max(1.0, float(zone.get("radius", 30.0)))
	for _i in range(spawn_count):
		var roll: float = randf()
		if roll < 0.48:
			var side := -1.0 if randf() < 0.5 else 1.0
			var angle: float = randf_range(0.0, TAU)
			_append_particle(
				controller,
				particles,
				center,
				Vector2(cos(angle) * randf_range(0.0, radius_x * 0.6), sin(angle) * randf_range(0.0, radius_y * 0.5)),
				Vector2(side * randf_range(0.3, 1.5), randf_range(-0.5, -0.05)),
				randf_range(20.0, 42.0),
				randf_range(50.0, 110.0),
				110.0,
				"smoke_cloud",
				randf_range(1.3, 2.0),
				0.0,
				1.0
			)
		elif roll < 0.70:
			_append_particle(
				controller,
				particles,
				center,
				Vector2(randf_range(-radius_x * 0.4, radius_x * 0.4), randf_range(-radius_y * 0.2, radius_y * 0.2)),
				Vector2(randf_range(-0.4, 0.4), randf_range(-1.5, -0.3)),
				randf_range(6.0, 15.0),
				randf_range(35.0, 70.0),
				70.0,
				"smoke_pillar",
				randf_range(0.5, 0.8),
				0.3,
				1.0
			)
		elif roll < 0.90:
			var angle: float = randf_range(0.0, TAU)
			_append_particle(
				controller,
				particles,
				center,
				Vector2(randf_range(-radius_x * 0.5, radius_x * 0.5), randf_range(-radius_y * 0.3, radius_y * 0.3)),
				Vector2(cos(angle) * randf_range(0.5, 2.0), randf_range(-0.8, -0.1)),
				randf_range(2.0, 5.0),
				randf_range(15.0, 40.0),
				40.0,
				"smoke_wisp",
				1.0,
				0.5,
				1.0
			)
		elif radius_x > 30.0:
			var angle: float = randf_range(0.0, TAU)
			_append_particle(
				controller,
				particles,
				center,
				Vector2(cos(angle) * radius_x * 0.7, sin(angle) * radius_y * 0.5),
				Vector2(cos(angle) * randf_range(1.0, 3.0), sin(angle) * randf_range(0.3, 1.0) - 0.5),
				randf_range(3.0, 7.0),
				randf_range(30.0, 60.0),
				60.0,
				"smoke_tendril",
				randf_range(1.5, 3.0),
				0.7,
				1.0
			)
	zone["particles"] = particles


func _append_particle(
	controller: Object,
	particles: Array,
	center: Vector2,
	offset: Vector2,
	velocity: Vector2,
	size: float,
	life_frames: float,
	max_life_frames: float,
	particle_type: String,
	aspect: float,
	depth_min: float,
	depth_max: float
) -> void:
	if particles.size() >= int(_get_float(controller, "TEAR_GAS_PARTICLE_CAP")):
		return
	particles.append({
		"position": center + offset,
		"velocity": velocity,
		"size": size,
		"life_frames": life_frames,
		"max_life_frames": max_life_frames,
		"type": particle_type,
		"aspect": aspect,
		"variant": randi() % 4,
		"tone": randi() % 3,
		"depth": randf_range(depth_min, depth_max),
		"phase": randf_range(0.0, TAU),
		"seed": randi(),
	})


func _update_zone_particles(controller: Object, zone: Dictionary, fps_scale: float) -> void:
	var particles: Array = zone.get("particles", [])
	var write_index := 0
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var center: Vector2 = _get_vector2(zone, "position", Vector2(field_width * 0.5, 120.0))
	var zone_bottom: float = center.y + float(zone.get("radius", _get_float(controller, "TEAR_GAS_MAX_RADIUS"))) * 0.8
	for read_index in range(particles.size()):
		var particle_value: Variant = particles[read_index]
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var life_frames: float = float(particle.get("life_frames", 0.0)) - fps_scale
		if life_frames <= 0.0:
			continue
		var pos: Vector2 = _get_vector2(particle, "position", Vector2.ZERO)
		var vel: Vector2 = _get_vector2(particle, "velocity", Vector2.ZERO)
		var particle_type: String = str(particle.get("type", "smoke_cloud"))
		if particle_type == "smoke_cloud" or particle_type == "smoke_pillar" or particle_type == "smoke_tendril":
			vel.x += randf_range(-0.15, 0.15) * fps_scale
			vel.y += randf_range(-0.08, 0.08) * fps_scale
		pos += vel * fps_scale
		var size: float = max(1.0, float(particle.get("size", 10.0)))
		if particle_type == "smoke_cloud":
			size *= pow(1.003, fps_scale)
			vel.x *= pow(0.97, fps_scale)
			vel.y -= 0.01 * fps_scale
			if pos.y > zone_bottom:
				vel.y *= -0.2
				vel.x *= 1.3
				pos.y = zone_bottom
		elif particle_type == "smoke_pillar":
			size *= pow(1.005, fps_scale)
			vel.x *= pow(0.95, fps_scale)
			vel.y *= pow(0.98, fps_scale)
		elif particle_type == "smoke_tendril":
			size *= pow(0.985, fps_scale)
			vel.x *= pow(0.96, fps_scale)
			vel.y *= pow(0.95, fps_scale)
		elif particle_type == "smoke_wisp":
			size *= pow(0.97, fps_scale)
			vel.x *= pow(0.94, fps_scale)
			vel.y *= pow(0.96, fps_scale)
		else:
			size *= pow(0.99, fps_scale)
		var min_size := 2.0 if particle_type == "smoke_wisp" or particle_type == "smoke_tendril" else 4.0
		if size < min_size:
			continue
		particle["position"] = pos
		particle["velocity"] = vel
		particle["life_frames"] = life_frames
		particle["size"] = size
		particles[write_index] = particle
		write_index += 1
	if write_index < particles.size():
		particles.resize(write_index)
	zone["particles"] = particles


func _get_player_throw_start(owner: Object, pending_throw: Dictionary, y_offset: float) -> Vector2:
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(
		owner,
		"player_pos",
		_get_vector2(pending_throw, "start_position", Vector2.ZERO)
	)
	return Vector2(player_pos.x + 155.0 * 0.5, player_pos.y + y_offset)


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


func _get_commando_duration_frames(controller: Object, registry: Object, base_frames: float) -> float:
	if controller != null and controller.has_method("get_commando_arm_duration_frames"):
		return max(0.0, float(controller.get_commando_arm_duration_frames(base_frames, registry)))
	return max(0.0, float(base_frames))


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
