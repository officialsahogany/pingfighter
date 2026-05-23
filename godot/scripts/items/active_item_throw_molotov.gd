extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")


func throw_molotov(controller: Object, owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	var start_pos: Vector2 = _get_player_throw_start(owner, pending_throw, 25.0)
	var target_pos: Vector2 = _get_vector2(pending_throw, "target_position", Vector2(start_pos.x, 15.0))
	var direction: Vector2 = target_pos - start_pos
	if direction.length() <= 0.001:
		direction = Vector2.UP
	else:
		direction = direction.normalized()
	direction = direction.rotated(deg_to_rad(randf_range(
		-_get_float(controller, "MOLOTOV_AIM_ERROR_DEGREES"),
		_get_float(controller, "MOLOTOV_AIM_ERROR_DEGREES")
	)))
	var speed: float = _get_float(controller, "MOLOTOV_SPEED_PER_FRAME") * _get_commando_throw_speed_multiplier(controller, registry)
	var velocity: Vector2 = direction * speed
	var position: Vector2 = start_pos
	var trail := [start_pos]
	if _is_commando_arm_equipped(controller, registry):
		position += velocity
		trail.append(position)
	_get_array(controller, "molotovs").append({
		"position": position,
		"velocity": velocity,
		"target_y": target_pos.y,
		"rotation_degrees": 0.0,
		"rotation_speed": 10.0,
		"trail": trail,
	})

	_play_throw_audio(registry)


func update_molotovs(controller: Object, owner: Object, registry: Object, delta: float) -> void:
	var molotovs: Array = _get_array(controller, "molotovs")
	if molotovs.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var field_height: float = _get_float(controller, "FIELD_HEIGHT", 750.0)
	var write_index := 0
	for read_index in range(molotovs.size()):
		var molotov: Dictionary = molotovs[read_index]
		var pos: Vector2 = _get_vector2(molotov, "position", Vector2.ZERO)
		var vel: Vector2 = _get_vector2(molotov, "velocity", Vector2.ZERO)
		pos += vel * fps_scale
		molotov["position"] = pos
		molotov["rotation_degrees"] = fposmod(
			float(molotov.get("rotation_degrees", 0.0))
			+ float(molotov.get("rotation_speed", 10.0)) * fps_scale,
			360.0
		)
		var trail: Array = molotov.get("trail", [])
		trail.append(pos)
		while trail.size() > 6:
			trail.pop_front()
		molotov["trail"] = trail

		var wall_margin := 10.0
		if pos.x <= wall_margin:
			pos.x = wall_margin
			vel.x = abs(vel.x) * 0.7
			if vel.y > 0.0:
				vel.y = -abs(vel.y) * 0.5
			molotov["position"] = pos
			molotov["velocity"] = vel
		elif pos.x >= field_width - wall_margin:
			pos.x = field_width - wall_margin
			vel.x = -abs(vel.x) * 0.7
			if vel.y > 0.0:
				vel.y = -abs(vel.y) * 0.5
			molotov["position"] = pos
			molotov["velocity"] = vel

		if pos.x < -100.0 or pos.x > field_width + 100.0 or pos.y > field_height + 100.0:
			continue
		var target_y: float = float(molotov.get("target_y", 15.0))
		var explode_y: float = 10.0 if pos.y <= 10.0 else target_y
		if pos.y <= target_y or pos.y <= 10.0:
			trigger_fire_zone(controller, owner, registry, Vector2(pos.x, explode_y))
			continue
		molotovs[write_index] = molotov
		write_index += 1
	if write_index < molotovs.size():
		molotovs.resize(write_index)


func trigger_fire_zone(
	controller: Object,
	_owner: Object,
	registry: Object,
	center: Vector2,
	play_feedback_audio: bool = true
) -> void:
	var duration_frames: float = _get_float(controller, "MOLOTOV_FIRE_DURATION_FRAMES")
	var fire_width: float = _get_commando_range_value(controller, registry, _get_float(controller, "MOLOTOV_FIRE_WIDTH"))
	var fire_height: float = _get_commando_range_value(controller, registry, _get_float(controller, "MOLOTOV_FIRE_HEIGHT"))
	var zone_center: Vector2 = _resolve_fire_zone_center(controller, center, fire_width, fire_height)
	# zone_id is a monotonic counter the renderer uses to match a fire zone
	# to its modular VFX host across frames. age_frames lets the renderer
	# detect the first frame so it can fire the one-shot explosion burst.
	var next_zone_id: int = 1
	if controller != null:
		var current_id: Variant = controller.get("_molotov_zone_id_counter")
		if current_id is int:
			next_zone_id = int(current_id) + 1
		controller.set("_molotov_zone_id_counter", next_zone_id)
	var fire_zone := {
		"zone_id": next_zone_id,
		"age_frames": 0.0,
		"position": zone_center,
		"width": fire_width,
		"height": fire_height,
		"duration_frames": duration_frames,
		"max_duration_frames": duration_frames,
		"flames": [],
		"spread_timer": 0.0,
		"push_timer": 0.0,
		"boss_in_fire": false,
	}
	seed_flames(controller, fire_zone, zone_center, int(_get_float(controller, "MOLOTOV_FIRE_INITIAL_FLAMES")), 30.0, 10.0)
	_get_array(controller, "molotov_fire_zones").append(fire_zone)

	if play_feedback_audio:
		var feedback: Object = _get_instance(registry, "battle_feedback_state")
		if feedback != null and feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(0.10, 3.0)
		var audio: Object = _get_instance(registry, "game_audio")
		if audio != null and audio.has_method("play_molotov_explosion"):
			audio.play_molotov_explosion()


func update_fire_zones(controller: Object, owner: Object, registry: Object, delta: float) -> void:
	var fire_zones: Array = _get_array(controller, "molotov_fire_zones")
	if fire_zones.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(
		owner,
		"boss_pos",
		Vector2(field_width * 0.5 - 50.0, 25.0)
	)
	var boss_center := Vector2(boss_pos.x + 50.0, boss_pos.y + 20.0)
	var write_index := 0
	for read_index in range(fire_zones.size()):
		var zone: Dictionary = fire_zones[read_index]
		var duration_frames: float = (
			float(zone.get("duration_frames", _get_float(controller, "MOLOTOV_FIRE_DURATION_FRAMES")))
			- fps_scale
		)
		if duration_frames <= 0.0:
			continue
		zone["duration_frames"] = duration_frames
		zone["age_frames"] = float(zone.get("age_frames", 0.0)) + fps_scale
		var center: Vector2 = _get_vector2(zone, "position", Vector2(field_width * 0.5, 15.0))
		var width: float = float(zone.get("width", _get_float(controller, "MOLOTOV_FIRE_WIDTH")))
		var height: float = float(zone.get("height", _get_float(controller, "MOLOTOV_FIRE_HEIGHT")))
		var spread_timer: float = float(zone.get("spread_timer", 0.0)) + fps_scale
		if spread_timer >= _get_float(controller, "MOLOTOV_FIRE_SPAWN_INTERVAL_FRAMES"):
			spread_timer = fmod(spread_timer, _get_float(controller, "MOLOTOV_FIRE_SPAWN_INTERVAL_FRAMES"))
			var flames: Array = zone.get("flames", [])
			if flames.size() < int(_get_float(controller, "MOLOTOV_FIRE_MAX_FLAMES")):
				seed_flames(
					controller,
					zone,
					center,
					int(_get_float(controller, "MOLOTOV_FIRE_SPAWN_COUNT")),
					width * 0.5,
					height * 0.5
				)
		zone["spread_timer"] = spread_timer
		update_flames(zone, fps_scale)

		var x_in_range: bool = abs(boss_center.x - center.x) < (width * 0.25 + 50.0)
		var y_in_range: bool = abs(boss_center.y - center.y) < 60.0
		var in_fire: bool = x_in_range and y_in_range
		zone["boss_in_fire"] = in_fire
		var push_timer: float = float(zone.get("push_timer", 0.0)) + fps_scale
		if push_timer >= _get_float(controller, "MOLOTOV_FIRE_PUSH_INTERVAL_FRAMES"):
			push_timer = fmod(push_timer, _get_float(controller, "MOLOTOV_FIRE_PUSH_INTERVAL_FRAMES"))
			if in_fire:
				push_boss_from_fire(controller, owner, registry, center, boss_center)
				boss_pos = BattleSceneOwnerReader.get_vector2(owner, "boss_pos", boss_pos)
				boss_center = Vector2(boss_pos.x + 50.0, boss_pos.y + 20.0)
		zone["push_timer"] = push_timer
		fire_zones[write_index] = zone
		write_index += 1
	if write_index < fire_zones.size():
		fire_zones.resize(write_index)


func seed_flames(_controller: Object, zone: Dictionary, center: Vector2, count: int, spread_x: float, spread_y: float) -> void:
	var flames: Array = zone.get("flames", [])
	for _i in range(count):
		flames.append({
			"position": center + Vector2(randf_range(-spread_x, spread_x), randf_range(-spread_y, spread_y)),
			"size": randf_range(8.0, 20.0),
			"lifetime_frames": randf_range(20.0, 40.0),
			"max_lifetime_frames": 40.0,
			"color_phase": randf(),
		})
	zone["flames"] = flames


func _resolve_fire_zone_center(controller: Object, center: Vector2, fire_width: float, _fire_height: float) -> Vector2:
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var margin_x: float = max(10.0, fire_width * 0.5)
	return Vector2(
		clamp(center.x, margin_x, max(margin_x, field_width - margin_x)),
		max(center.y, _get_molotov_fire_min_center_y(controller))
	)


func _get_molotov_fire_min_center_y(controller: Object) -> float:
	var configured_y: float = _get_float(controller, "MOLOTOV_FIRE_MIN_CENTER_Y", -1.0)
	if configured_y > 0.0:
		return configured_y
	var fire_height: float = _get_float(controller, "MOLOTOV_FIRE_HEIGHT", 60.0)
	return max(10.0, fire_height * 0.5 + 10.0)


func update_flames(zone: Dictionary, fps_scale: float) -> void:
	var flames: Array = zone.get("flames", [])
	var write_index := 0
	for read_index in range(flames.size()):
		var flame_value: Variant = flames[read_index]
		if not (flame_value is Dictionary):
			continue
		var flame: Dictionary = flame_value
		var lifetime_frames: float = float(flame.get("lifetime_frames", 0.0)) - fps_scale
		var size: float = float(flame.get("size", 10.0)) * pow(0.97, fps_scale)
		if lifetime_frames <= 0.0 or size < 2.0:
			continue
		var pos: Vector2 = _get_vector2(flame, "position", Vector2.ZERO)
		var phase: float = float(flame.get("color_phase", 0.0)) * TAU + lifetime_frames * 0.09
		pos.y -= (0.18 + 0.16 * (0.5 + 0.5 * sin(phase))) * fps_scale
		pos.x += sin(phase * 1.7) * 0.32 * fps_scale
		flame["position"] = pos
		flame["lifetime_frames"] = lifetime_frames
		flame["size"] = size
		flames[write_index] = flame
		write_index += 1
	if write_index < flames.size():
		flames.resize(write_index)
	zone["flames"] = flames


func push_boss_from_fire(controller: Object, owner: Object, registry: Object, center: Vector2, boss_center: Vector2) -> void:
	if owner == null:
		return
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(
		owner,
		"boss_pos",
		Vector2(field_width * 0.5 - 50.0, 25.0)
	)
	var push_dir: float = -1.0 if boss_center.x < center.x else 1.0
	boss_pos.x = clamp(
		boss_pos.x + push_dir * _get_float(controller, "MOLOTOV_FIRE_PUSH_FORCE"),
		0.0,
		field_width - 100.0
	)
	owner.set("boss_pos", boss_pos)
	var feedback: Object = _get_instance(registry, "battle_feedback_state")
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(0.035, 1.1)


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


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
