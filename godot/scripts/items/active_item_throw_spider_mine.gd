extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")


func throw_spider_mine(controller: Object, owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	deploy_mine(controller, owner, _get_vector2(pending_throw, "start_position", Vector2.ZERO))

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_throw"):
		audio.play_throw()


func deploy_mine(controller: Object, owner: Object, fallback_player_pos: Vector2 = Vector2.ZERO) -> void:
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var field_height: float = _get_float(controller, "FIELD_HEIGHT", 750.0)
	var mine_size: float = _get_float(controller, "SPIDER_MINE_SIZE", 26.0)
	var player_pos_fallback: Vector2 = fallback_player_pos
	if player_pos_fallback == Vector2.ZERO:
		player_pos_fallback = Vector2(field_width * 0.5, field_height - 50.0)
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", player_pos_fallback)
	var player_width: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", 155.0)))
	var player_height: float = 50.0
	var player_center := Vector2(player_pos.x + player_width * 0.5, player_pos.y + player_height * 0.5)
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "boss_pos", Vector2(field_width * 0.5 - 50.0, 25.0))
	var boss_width: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "boss_paddle_width", 100.0)))
	var boss_height: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "boss_hitbox_height", 40.0)))
	var side: String = "left" if player_center.x <= field_width * 0.5 else "right"
	var floor_center_y: float = min(
		player_pos.y + player_height - mine_size * 0.5 + 2.0,
		field_height - mine_size * 0.5 - _get_float(controller, "SPIDER_MINE_FLOOR_CLEARANCE", 10.0)
	)
	var wall_center_x: float = mine_size * 0.5 + _get_float(controller, "SPIDER_MINE_WALL_OFFSET", 18.0)
	if side == "right":
		wall_center_x = field_width - (mine_size * 0.5 + _get_float(controller, "SPIDER_MINE_WALL_OFFSET", 18.0))
	var corner_center_y: float = max(
		boss_pos.y + mine_size * 0.5 + _get_float(controller, "SPIDER_MINE_CORNER_OFFSET_Y", 12.0),
		mine_size * 0.5 + 12.0
	)
	corner_center_y = min(corner_center_y, boss_pos.y + boss_height + mine_size)

	var spawn_offset: float = mine_size + 10.0
	var start_x: float = player_pos.x - spawn_offset if side == "left" else player_pos.x + player_width + spawn_offset
	start_x = clamp(start_x, mine_size * 0.5 + 4.0, field_width - mine_size * 0.5 - 4.0)
	_get_array(controller, "spider_mines").append({
		"position": Vector2(start_x, floor_center_y),
		"wall_x": wall_center_x,
		"floor_y": floor_center_y,
		"corner_y": corner_center_y,
		"state": "spawn",
		"delay_timer": _get_float(controller, "SPIDER_MINE_START_DELAY_FRAMES", 60.0),
		"flash_timer": _get_float(controller, "SPIDER_MINE_START_DELAY_FRAMES", 60.0),
		"side": side,
		"size": mine_size,
		"glow_phase": 0.0,
		"armed_elapsed": 0.0,
		"step_phase": 0.0,
		"embed_timer": 0.0,
		"embed_depth": 0.0,
		"embed_slam_timer": 0.0,
		"boss_width": boss_width,
	})


func update_mines(controller: Object, owner: Object, registry: Object, delta: float) -> void:
	var fps_scale: float = delta * 60.0
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "boss_pos", Vector2(field_width * 0.5 - 50.0, 25.0))
	var boss_width: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "boss_paddle_width", 100.0)))
	var boss_height: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "boss_hitbox_height", 40.0)))
	var boss_rect := Rect2(boss_pos, Vector2(boss_width, boss_height))
	var mines: Array = _get_array(controller, "spider_mines")
	var write_index := 0
	var any_walking: bool = false

	for read_index in range(mines.size()):
		var mine: Dictionary = mines[read_index]
		var state: String = str(mine.get("state", "spawn"))
		if state == "spawn":
			var delay_timer: float = float(mine.get("delay_timer", _get_float(controller, "SPIDER_MINE_START_DELAY_FRAMES", 60.0))) - fps_scale
			mine["delay_timer"] = delay_timer
			if delay_timer <= 0.0:
				mine["state"] = "floor"
				mine["flash_timer"] = 30.0
		elif state == "floor":
			any_walking = true
			mine["step_phase"] = float(mine.get("step_phase", 0.0)) + 0.42 * fps_scale
			var pos: Vector2 = _get_vector2(mine, "position", Vector2.ZERO)
			pos.y = float(mine.get("floor_y", pos.y))
			mine["position"] = pos
			if move_towards(mine, Vector2(float(mine.get("wall_x", pos.x)), float(mine.get("floor_y", pos.y))), _get_float(controller, "SPIDER_MINE_TRAVEL_SPEED", 11.0) * fps_scale):
				mine["state"] = "wall"
		elif state == "wall":
			any_walking = true
			mine["step_phase"] = float(mine.get("step_phase", 0.0)) + 0.38 * fps_scale
			var pos: Vector2 = _get_vector2(mine, "position", Vector2.ZERO)
			pos.x = float(mine.get("wall_x", pos.x))
			mine["position"] = pos
			if move_towards(mine, Vector2(float(mine.get("wall_x", pos.x)), float(mine.get("corner_y", pos.y))), _get_float(controller, "SPIDER_MINE_CLIMB_SPEED", 8.4) * fps_scale):
				mine["state"] = "embedding"
				mine["embed_timer"] = _get_float(controller, "SPIDER_MINE_EMBED_DELAY_FRAMES", 60.0)
		elif state == "embedding":
			var pos: Vector2 = Vector2(float(mine.get("wall_x", 0.0)), float(mine.get("corner_y", 0.0)))
			mine["position"] = pos
			mine["step_phase"] = float(mine.get("step_phase", 0.0)) + 0.12 * fps_scale
			var prev_timer: float = float(mine.get("embed_timer", 0.0))
			var embed_timer: float = prev_timer - fps_scale
			mine["embed_timer"] = embed_timer
			if embed_timer <= 0.0:
				mine["state"] = "armed"
				mine["embed_slam_timer"] = 10.0
				mine["embed_depth"] = _get_float(controller, "SPIDER_MINE_MAX_EMBED_DEPTH", 6.0)
				mine["step_phase"] = 0.0
				play_setup_audio(registry)
		elif state == "armed":
			var pos: Vector2 = Vector2(float(mine.get("wall_x", 0.0)), float(mine.get("corner_y", 0.0)))
			mine["position"] = pos
			var armed_elapsed: float = float(mine.get("armed_elapsed", 0.0)) + fps_scale
			mine["armed_elapsed"] = armed_elapsed
			mine["step_phase"] = float(mine.get("step_phase", 0.0)) + 0.05 * fps_scale
			var embed_slam_timer: float = float(mine.get("embed_slam_timer", 0.0))
			if embed_slam_timer > 0.0:
				embed_slam_timer = max(0.0, embed_slam_timer - fps_scale)
				mine["embed_slam_timer"] = embed_slam_timer
				mine["embed_depth"] = _get_float(controller, "SPIDER_MINE_MAX_EMBED_DEPTH", 6.0) * (embed_slam_timer / 10.0)
			else:
				mine["embed_depth"] = max(2.5, float(mine.get("embed_depth", 0.0)) * pow(0.90, fps_scale))
			if armed_elapsed >= _get_float(controller, "SPIDER_MINE_SELF_DESTRUCT_FRAMES", 240.0):
				trigger_explosion(controller, owner, registry, mine, "timer")
			elif get_mine_rect(controller, mine).intersects(boss_rect):
				trigger_explosion(controller, owner, registry, mine, "boss")
		elif state == "exploding":
			var explosion_timer: float = float(mine.get("explosion_timer", _get_float(controller, "SPIDER_MINE_EXPLOSION_DURATION_FRAMES", 22.0))) - fps_scale
			if explosion_timer <= 0.0:
				continue
			mine["explosion_timer"] = explosion_timer

		mine["glow_phase"] = float(mine.get("glow_phase", 0.0)) + 0.08 * fps_scale
		mine["flash_timer"] = max(0.0, float(mine.get("flash_timer", 0.0)) - fps_scale)
		mines[write_index] = mine
		write_index += 1

	if write_index < mines.size():
		mines.resize(write_index)
	sync_walk_audio(registry, any_walking)
	update_slow(controller, delta)


func move_towards(mine: Dictionary, target: Vector2, speed: float) -> bool:
	var pos: Vector2 = _get_vector2(mine, "position", target)
	var delta_pos: Vector2 = target - pos
	var distance: float = delta_pos.length()
	if distance <= speed or distance <= 0.001:
		mine["position"] = target
		return true
	mine["position"] = pos + delta_pos / distance * speed
	return false


func get_mine_rect(controller: Object, mine: Dictionary) -> Rect2:
	var size: float = float(mine.get("size", _get_float(controller, "SPIDER_MINE_SIZE", 26.0)))
	var center: Vector2 = _get_vector2(mine, "position", Vector2.ZERO) + Vector2(0.0, float(mine.get("embed_depth", 0.0)))
	return Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size))


func trigger_explosion(controller: Object, owner: Object, registry: Object, mine: Dictionary, reason: String) -> void:
	if str(mine.get("state", "")) == "exploding":
		return
	mine["state"] = "exploding"
	mine["explosion_timer"] = _get_float(controller, "SPIDER_MINE_EXPLOSION_DURATION_FRAMES", 22.0)
	mine["max_explosion_timer"] = _get_float(controller, "SPIDER_MINE_EXPLOSION_DURATION_FRAMES", 22.0)
	var impact_pos: Vector2 = _get_vector2(mine, "position", Vector2.ZERO) + Vector2(0.0, float(mine.get("embed_depth", 0.0)))
	spawn_particles(controller, impact_pos)

	if reason == "boss":
		apply_boss_effect(controller, owner, impact_pos)

	var feedback: Object = _get_instance(registry, "battle_feedback_state")
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(0.18 if reason == "boss" else 0.08, 5.0 if reason == "boss" else 2.0)
	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_grenade_explosion"):
		audio.play_grenade_explosion()


func apply_boss_effect(controller: Object, owner: Object, impact_pos: Vector2) -> void:
	if owner == null:
		return
	var field_width: float = _get_float(controller, "FIELD_WIDTH", 760.0)
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "boss_pos", Vector2(field_width * 0.5 - 50.0, 25.0))
	var boss_width: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "boss_paddle_width", 100.0)))
	var boss_center_x: float = boss_pos.x + boss_width * 0.5
	var edge_margin: float = max(10.0, boss_width * 0.5)
	var knockback_direction: float = 1.0
	if boss_pos.x <= edge_margin:
		knockback_direction = 1.0
	elif boss_pos.x + boss_width >= field_width - edge_margin:
		knockback_direction = -1.0
	else:
		knockback_direction = 1.0 if impact_pos.x < boss_center_x else -1.0
	_set_float(
		controller,
		"grenade_boss_stun_timer_frames",
		max(_get_float(controller, "grenade_boss_stun_timer_frames"), _get_float(controller, "SPIDER_MINE_BOSS_STUN_FRAMES", 6.0))
	)
	_set_float(
		controller,
		"grenade_boss_knockback_timer_frames",
		max(_get_float(controller, "grenade_boss_knockback_timer_frames"), _get_float(controller, "SPIDER_MINE_BOSS_STUN_FRAMES", 6.0))
	)
	var knockback_vel: float = knockback_direction * _get_float(controller, "SPIDER_MINE_BOSS_KNOCKBACK_POWER", 33.33)
	if abs(knockback_vel) >= abs(_get_float(controller, "grenade_boss_knockback_vel")):
		_set_float(controller, "grenade_boss_knockback_vel", knockback_vel)
	_set_float(controller, "spider_mine_slow_timer_frames", _get_float(controller, "SPIDER_MINE_SLOW_DURATION_FRAMES", 180.0))
	_set_float(controller, "spider_mine_slow_text_timer_frames", _get_float(controller, "SPIDER_MINE_TEXT_DURATION_FRAMES", 60.0))


func update_slow(controller: Object, delta: float) -> void:
	var fps_scale: float = delta * 60.0
	var slow_timer: float = _get_float(controller, "spider_mine_slow_timer_frames")
	if slow_timer > 0.0:
		_set_float(controller, "spider_mine_slow_timer_frames", max(0.0, slow_timer - fps_scale))
	var text_timer: float = _get_float(controller, "spider_mine_slow_text_timer_frames")
	if text_timer > 0.0:
		_set_float(controller, "spider_mine_slow_text_timer_frames", max(0.0, text_timer - fps_scale))


func spawn_particles(controller: Object, pos: Vector2) -> void:
	var colors := [
		Color(255.0 / 255.0, 160.0 / 255.0, 90.0 / 255.0, 1.0),
		Color(255.0 / 255.0, 230.0 / 255.0, 180.0 / 255.0, 1.0),
		Color(150.0 / 255.0, 110.0 / 255.0, 220.0 / 255.0, 1.0),
		Color(70.0 / 255.0, 80.0 / 255.0, 120.0 / 255.0, 1.0),
	]
	var particles: Array = _get_array(controller, "spider_mine_particles")
	for _i in range(int(_get_float(controller, "SPIDER_MINE_PARTICLE_COUNT", 16.0))):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(2.0, 10.0)
		particles.append({
			"position": pos + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0)),
			"velocity": Vector2(cos(angle), sin(angle)) * speed + Vector2(0.0, -2.0),
			"life_frames": randf_range(18.0, 34.0),
			"max_life_frames": 34.0,
			"size": randf_range(2.0, 6.0),
			"color": colors[randi() % colors.size()],
		})


func update_particles(controller: Object, delta: float) -> void:
	var particles: Array = _get_array(controller, "spider_mine_particles")
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
		velocity.y += 0.22 * fps_scale
		velocity.x *= pow(0.97, fps_scale)
		particle["life_frames"] = life_frames
		particle["position"] = pos
		particle["velocity"] = velocity
		particle["size"] = max(0.5, float(particle.get("size", 3.0)) * pow(0.98, fps_scale))
		particles[write_index] = particle
		write_index += 1
	if write_index < particles.size():
		particles.resize(write_index)


func play_setup_audio(registry: Object) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_spider_mine_setup"):
		audio.play_spider_mine_setup()
	elif audio.has_method("play_paddle_hit"):
		audio.play_paddle_hit()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func sync_walk_audio(registry: Object, active: bool) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("sync_spider_mine_walk_loop"):
		audio.sync_spider_mine_walk_loop(active)
	elif active and audio.has_method("play_spider_mine_walk_loop"):
		audio.play_spider_mine_walk_loop()
	elif not active and audio.has_method("stop_spider_mine_walk_loop"):
		audio.stop_spider_mine_walk_loop()


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


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
