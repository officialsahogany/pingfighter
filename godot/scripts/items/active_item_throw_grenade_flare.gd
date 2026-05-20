extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")


func throw_grenade(controller: Object, owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	var start_pos: Vector2 = _get_player_throw_start(owner, pending_throw, 25.0)
	var target_pos: Vector2 = _get_vector2(pending_throw, "target_position", start_pos + Vector2(0.0, -120.0))
	var direction: Vector2 = target_pos - start_pos
	if direction.length() <= 0.001:
		direction = Vector2.UP
	else:
		direction = direction.normalized()
	direction = direction.rotated(deg_to_rad(randf_range(-_get_float(controller, "GRENADE_AIM_ERROR_DEGREES"), _get_float(controller, "GRENADE_AIM_ERROR_DEGREES"))))
	var speed: float = _get_float(controller, "GRENADE_SPEED_PER_FRAME") * _get_commando_throw_speed_multiplier(controller, registry)
	var velocity: Vector2 = direction * speed
	var position: Vector2 = start_pos
	var trail := [start_pos]
	if _is_commando_arm_equipped(controller, registry):
		position += velocity
		trail.append(position)
	_get_array(controller, "grenades").append({
		"position": position,
		"velocity": velocity,
		"target_position": target_pos,
		"rotation_degrees": 0.0,
		"trail": trail,
	})

	_play_throw_audio(registry)


func throw_flare(controller: Object, owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	var start_pos: Vector2 = _get_player_throw_start(owner, pending_throw, 25.0)
	var target_pos: Vector2 = _get_vector2(pending_throw, "target_position", start_pos + Vector2(0.0, -120.0))
	var direction: Vector2 = target_pos - start_pos
	if direction.length() <= 0.001:
		direction = Vector2.UP
	else:
		direction = direction.normalized()
	direction = direction.rotated(deg_to_rad(randf_range(-_get_float(controller, "FLARE_AIM_ERROR_DEGREES"), _get_float(controller, "FLARE_AIM_ERROR_DEGREES"))))
	var speed: float = _get_float(controller, "FLARE_SPEED_PER_FRAME") * _get_commando_throw_speed_multiplier(controller, registry)
	var velocity: Vector2 = direction * speed
	var position: Vector2 = start_pos
	var trail := [start_pos]
	if _is_commando_arm_equipped(controller, registry):
		position += velocity
		trail.append(position)
	_get_array(controller, "flares").append({
		"position": position,
		"velocity": velocity,
		"target_position": target_pos,
		"rotation_degrees": 0.0,
		"timer_frames": 0.0,
		"exploded": false,
		"arrived": false,
		"trail": trail,
	})

	_play_throw_audio(registry)


func update_grenades(
	controller: Object,
	owner: Object,
	registry: Object,
	delta: float,
	explosion_callback: Callable = Callable()
) -> void:
	var grenades: Array = _get_array(controller, "grenades")
	if grenades.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var write_index := 0
	for read_index in range(grenades.size()):
		var grenade: Dictionary = grenades[read_index]
		var pos: Vector2 = _get_vector2(grenade, "position", Vector2.ZERO)
		var vel: Vector2 = _get_vector2(grenade, "velocity", Vector2.ZERO)
		var target: Vector2 = _get_vector2(grenade, "target_position", pos)
		pos += vel * fps_scale
		grenade["position"] = pos
		grenade["velocity"] = vel
		grenade["rotation_degrees"] = fposmod(float(grenade.get("rotation_degrees", 0.0)) + 15.0 * fps_scale, 360.0)
		var trail: Array = grenade.get("trail", [])
		trail.append(pos)
		while trail.size() > 6:
			trail.pop_front()
		grenade["trail"] = trail

		if pos.distance_to(target) <= _get_float(controller, "GRENADE_TARGET_REACHED_DISTANCE"):
			_trigger_grenade_impact(controller, owner, registry, pos, explosion_callback)
			continue
		if pos.y <= 10.0:
			_trigger_grenade_impact(controller, owner, registry, Vector2(pos.x, 10.0), explosion_callback)
			continue

		var wall_margin := 10.0
		var field_width: float = _get_float(controller, "FIELD_WIDTH")
		if pos.x <= wall_margin:
			pos.x = wall_margin
			vel.x = abs(vel.x) * 0.7
			if vel.y > 0.0:
				vel.y = -abs(vel.y) * 0.5
			grenade["position"] = pos
			grenade["velocity"] = vel
		elif pos.x >= field_width - wall_margin:
			pos.x = field_width - wall_margin
			vel.x = -abs(vel.x) * 0.7
			if vel.y > 0.0:
				vel.y = -abs(vel.y) * 0.5
			grenade["position"] = pos
			grenade["velocity"] = vel

		if pos.x < -100.0 or pos.x > field_width + 100.0 or pos.y > _get_float(controller, "FIELD_HEIGHT") + 100.0:
			continue
		grenades[write_index] = grenade
		write_index += 1
	if write_index < grenades.size():
		grenades.resize(write_index)


func update_flares(
	controller: Object,
	owner: Object,
	registry: Object,
	delta: float,
	flash_callback: Callable = Callable()
) -> void:
	var flares: Array = _get_array(controller, "flares")
	if flares.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var write_index := 0
	for read_index in range(flares.size()):
		var flare: Dictionary = flares[read_index]
		var arrived: bool = bool(flare.get("arrived", false))
		var exploded: bool = bool(flare.get("exploded", false))
		var pos: Vector2 = _get_vector2(flare, "position", Vector2.ZERO)
		var vel: Vector2 = _get_vector2(flare, "velocity", Vector2.ZERO)
		var target: Vector2 = _get_vector2(flare, "target_position", pos)

		if not arrived:
			pos += vel * fps_scale
			flare["position"] = pos
			flare["velocity"] = vel
			flare["rotation_degrees"] = fposmod(float(flare.get("rotation_degrees", 0.0)) + 12.0 * fps_scale, 360.0)
			var trail: Array = flare.get("trail", [])
			trail.append(pos)
			while trail.size() > 6:
				trail.pop_front()
			flare["trail"] = trail

			if pos.y <= 10.0:
				pos.y = 10.0
				flare["position"] = pos
				flare["arrived"] = true
				flares[write_index] = flare
				write_index += 1
				continue

			var wall_margin := 10.0
			var field_width: float = _get_float(controller, "FIELD_WIDTH")
			if pos.x <= wall_margin:
				pos.x = wall_margin
				vel.x = abs(vel.x) * 0.7
				if vel.y > 0.0:
					vel.y = -abs(vel.y) * 0.5
				flare["position"] = pos
				flare["velocity"] = vel
			elif pos.x >= field_width - wall_margin:
				pos.x = field_width - wall_margin
				vel.x = -abs(vel.x) * 0.7
				if vel.y > 0.0:
					vel.y = -abs(vel.y) * 0.5
				flare["position"] = pos
				flare["velocity"] = vel

			if pos.x < -100.0 or pos.x > field_width + 100.0 or pos.y > _get_float(controller, "FIELD_HEIGHT") + 100.0:
				continue
			if pos.distance_to(target) < _get_float(controller, "FLARE_TARGET_REACHED_DISTANCE"):
				flare["position"] = target
				flare["arrived"] = true
			flares[write_index] = flare
			write_index += 1
			continue

		if not exploded:
			var timer_frames: float = float(flare.get("timer_frames", 0.0)) + fps_scale
			flare["timer_frames"] = timer_frames
			if timer_frames >= _get_float(controller, "FLARE_ARMED_DELAY_FRAMES"):
				flare["exploded"] = true
				_trigger_flare_impact(controller, owner, registry, pos, flash_callback)
				continue
			flares[write_index] = flare
			write_index += 1
	if write_index < flares.size():
		flares.resize(write_index)


func trigger_grenade_explosion(controller: Object, owner: Object, registry: Object, center: Vector2) -> void:
	var radius: float = _get_commando_range_value(controller, registry, _get_float(controller, "GRENADE_EXPLOSION_RADIUS"))
	var explosion_center: Vector2 = _resolve_radial_effect_center(controller, center, radius)
	_get_array(controller, "explosion_zones").append({
		"position": explosion_center,
		"radius": radius,
		"duration_frames": _get_float(controller, "GRENADE_EXPLOSION_DURATION_FRAMES"),
		"max_duration_frames": _get_float(controller, "GRENADE_EXPLOSION_DURATION_FRAMES"),
		"active": true,
		"source": "grenade",
	})
	apply_grenade_boss_effect(controller, owner, explosion_center, radius)

	var feedback: Object = _get_instance(registry, "battle_feedback_state")
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(0.24, 7.0)

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_grenade_explosion"):
		audio.play_grenade_explosion()


func apply_grenade_boss_effect(controller: Object, owner: Object, center: Vector2, radius: float) -> void:
	if owner == null:
		return
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "boss_pos", Vector2(field_width * 0.5 - 50.0, 25.0))
	var boss_center := Vector2(boss_pos.x + 50.0, boss_pos.y + 20.0)
	if boss_center.distance_to(center) > radius:
		return
	_set_float(
		controller,
		"grenade_boss_stun_timer_frames",
		max(_get_float(controller, "grenade_boss_stun_timer_frames"), _get_float(controller, "GRENADE_BOSS_STUN_FRAMES"))
	)
	_set_float(
		controller,
		"grenade_boss_knockback_timer_frames",
		max(_get_float(controller, "grenade_boss_knockback_timer_frames"), _get_float(controller, "GRENADE_BOSS_KNOCKBACK_FRAMES"))
	)
	var direction: float = 1.0 if boss_center.x >= center.x else -1.0
	var knockback_vel: float = direction * _get_float(controller, "GRENADE_BOSS_KNOCKBACK_POWER")
	if abs(knockback_vel) >= abs(_get_float(controller, "grenade_boss_knockback_vel")):
		_set_float(controller, "grenade_boss_knockback_vel", knockback_vel)


func trigger_flare_flash(controller: Object, owner: Object, registry: Object, center: Vector2) -> void:
	var radius: float = _get_commando_range_value(controller, registry, _get_float(controller, "FLARE_RADIUS"))
	var flash_center: Vector2 = _resolve_radial_effect_center(controller, center, radius)
	_get_array(controller, "flare_zones").append({
		"position": flash_center,
		"radius": radius,
		"duration_frames": _get_float(controller, "FLARE_ZONE_DURATION_FRAMES"),
		"max_duration_frames": _get_float(controller, "FLARE_ZONE_DURATION_FRAMES"),
		"intensity": 1.0,
		"flash": true,
	})
	apply_flare_boss_confusion(controller, owner, flash_center, radius)

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_flashbomb"):
		audio.play_flashbomb()


func apply_flare_boss_confusion(controller: Object, owner: Object, center: Vector2, radius: float) -> void:
	if owner == null:
		return
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "boss_pos", Vector2(field_width * 0.5 - 50.0, 25.0))
	var boss_center := Vector2(boss_pos.x + 50.0, boss_pos.y + 20.0)
	if boss_center.distance_to(center) > radius:
		return
	_set_float(
		controller,
		"flare_boss_confused_timer_frames",
		max(_get_float(controller, "flare_boss_confused_timer_frames"), _get_float(controller, "FLARE_BOSS_CONFUSION_FRAMES"))
	)


func update_explosion_zones(controller: Object, delta: float) -> void:
	var zones: Array = _get_array(controller, "explosion_zones")
	if zones.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var write_index := 0
	for read_index in range(zones.size()):
		var zone: Dictionary = zones[read_index]
		var remaining: float = float(zone.get("duration_frames", 0.0)) - fps_scale
		if remaining <= 0.0:
			continue
		zone["duration_frames"] = remaining
		zones[write_index] = zone
		write_index += 1
	if write_index < zones.size():
		zones.resize(write_index)


func update_flare_zones(controller: Object, delta: float) -> void:
	var zones: Array = _get_array(controller, "flare_zones")
	if zones.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var write_index := 0
	for read_index in range(zones.size()):
		var zone: Dictionary = zones[read_index]
		var remaining: float = float(zone.get("duration_frames", 0.0)) - fps_scale
		if remaining <= 0.0:
			continue
		zone["duration_frames"] = remaining
		if bool(zone.get("flash", false)):
			if remaining > 6.0:
				zone["intensity"] = 1.0
			elif remaining > 3.0:
				zone["intensity"] = 0.3
			else:
				zone["intensity"] = 0.8
		else:
			zone["intensity"] = remaining / max(1.0, float(zone.get("max_duration_frames", _get_float(controller, "FLARE_ZONE_DURATION_FRAMES"))))
		zones[write_index] = zone
		write_index += 1
	if write_index < zones.size():
		zones.resize(write_index)


func update_grenade_boss_effect(controller: Object, delta: float) -> void:
	var fps_scale: float = delta * 60.0
	_set_float(
		controller,
		"grenade_boss_stun_timer_frames",
		max(0.0, _get_float(controller, "grenade_boss_stun_timer_frames") - fps_scale)
	)
	var knockback_timer: float = _get_float(controller, "grenade_boss_knockback_timer_frames")
	var knockback_vel: float = _get_float(controller, "grenade_boss_knockback_vel")
	if knockback_timer > 0.0:
		knockback_timer = max(0.0, knockback_timer - fps_scale)
		knockback_vel *= pow(_get_float(controller, "GRENADE_BOSS_KNOCKBACK_DECAY"), fps_scale)
		_set_float(controller, "grenade_boss_knockback_timer_frames", knockback_timer)
		_set_float(controller, "grenade_boss_knockback_vel", knockback_vel)
		if knockback_timer <= 0.0 or abs(knockback_vel) <= 0.3:
			_set_float(controller, "grenade_boss_knockback_timer_frames", 0.0)
			_set_float(controller, "grenade_boss_knockback_vel", 0.0)
	elif abs(knockback_vel) > 0.0:
		_set_float(controller, "grenade_boss_knockback_vel", 0.0)


func update_flare_boss_confusion(controller: Object, delta: float) -> void:
	var fps_scale: float = delta * 60.0
	_set_float(
		controller,
		"flare_boss_confused_timer_frames",
		max(0.0, _get_float(controller, "flare_boss_confused_timer_frames") - fps_scale)
	)


func clear_boss_disable_effects_if_stage2_speed_defense(controller: Object, registry: Object) -> void:
	if not is_stage2_speed_defense_boss_immune(registry):
		return
	_set_float(controller, "grenade_boss_stun_timer_frames", 0.0)
	_set_float(controller, "grenade_boss_knockback_timer_frames", 0.0)
	_set_float(controller, "grenade_boss_knockback_vel", 0.0)
	_set_float(controller, "flare_boss_confused_timer_frames", 0.0)


func is_stage2_speed_defense_boss_immune(registry: Object) -> bool:
	var stage2_skill_state: Object = _get_instance(registry, "stage2_boss_skill_state")
	return (
		stage2_skill_state != null
		and stage2_skill_state.has_method("is_boss_status_immune")
		and bool(stage2_skill_state.is_boss_status_immune())
	)


func _get_player_throw_start(owner: Object, pending_throw: Dictionary, y_offset: float) -> Vector2:
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(
		owner,
		"player_pos",
		_get_vector2(pending_throw, "start_position", Vector2.ZERO)
	)
	return Vector2(player_pos.x + 155.0 * 0.5, player_pos.y + y_offset)


func _call_projectile_callback(callback: Callable, owner: Object, registry: Object, position: Vector2) -> void:
	if callback.is_valid():
		callback.call(owner, registry, position)


func _trigger_grenade_impact(
	controller: Object,
	owner: Object,
	registry: Object,
	position: Vector2,
	callback: Callable
) -> void:
	if callback.is_valid():
		callback.call(owner, registry, position)
		return
	trigger_grenade_explosion(controller, owner, registry, position)


func _trigger_flare_impact(
	controller: Object,
	owner: Object,
	registry: Object,
	position: Vector2,
	callback: Callable
) -> void:
	if callback.is_valid():
		callback.call(owner, registry, position)
		return
	trigger_flare_flash(controller, owner, registry, position)


func _resolve_radial_effect_center(controller: Object, center: Vector2, radius: float) -> Vector2:
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var margin_x: float = min(field_width * 0.5, max(10.0, radius))
	return Vector2(
		clamp(center.x, margin_x, max(margin_x, field_width - margin_x)),
		center.y
	)


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


func _get_commando_throw_speed_multiplier(controller: Object, registry: Object) -> float:
	if controller != null and controller.has_method("get_commando_arm_throw_speed_multiplier"):
		return max(0.0, float(controller.get_commando_arm_throw_speed_multiplier(registry, false)))
	return 1.0


func _get_commando_range_value(controller: Object, registry: Object, base_value: float) -> float:
	if controller != null and controller.has_method("get_commando_arm_range_value"):
		return max(0.0, float(controller.get_commando_arm_range_value(base_value, registry)))
	return max(0.0, float(base_value))


func _is_commando_arm_equipped(controller: Object, registry: Object) -> bool:
	if controller != null and controller.has_method("is_commando_arm_equipped"):
		return bool(controller.is_commando_arm_equipped(registry))
	return false


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
