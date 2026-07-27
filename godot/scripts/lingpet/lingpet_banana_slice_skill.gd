extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const LingpetBananaSlicePayloadFactory := preload("res://scripts/lingpet/lingpet_banana_slice_payload_factory.gd")
const LingpetBananaSliceRenderer := preload("res://scripts/lingpet/lingpet_banana_slice_renderer.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PHASE_IDLE := 0
const PHASE_PREPARE := 1

const PREPARE_SECONDS := 0.30
const BANANA_COUNT_BY_LEVEL := [1, 1, 2, 2, 2]
const SECOND_THROW_DELAY_SECONDS := 0.15
const LAND_Y := 45.0
const LAND_SECONDS := 3.0
const LAND_X_MIN := 30.0
const LAND_X_MAX := 730.0
const LAND_RANDOM_MIN := 40.0
const LAND_RANDOM_MAX := 720.0
const LAND_RANDOM_MIN_GAP := 120.0
const LAND_RANDOM_ATTEMPTS := 20
const COLLISION_SIZE := Vector2(80.0, 50.0)
const BOSS_PADDLE_WIDTH := 100.0
const BOSS_HITBOX_HEIGHT := 40.0
const THROW_SPEED_Y_PER_FRAME := -20.0
const THROW_AIM_X_DIVISOR := 30.0
const THROW_SPEED_X_MAX_PER_FRAME := 6.0
const WALL_LEFT := 10.0
const WALL_RIGHT := 750.0
const WALL_BOUNCE_SCALE := 0.70
const PROJECTILE_CULL_TOP := -50.0
const PROJECTILE_CULL_BOTTOM := 800.0
# Lv.1 intentionally starts below the legacy 0.8s banana slip, then scales
# back to the original parity duration by Lv.5.
const SLIP_SECONDS_BY_LEVEL := [0.45, 0.55, 0.65, 0.72, 0.80]
const SLIP_SPEED_BY_LEVEL := [15.0, 16.25, 17.5, 18.75, 20.0]
const SLIP_CENTER_EPSILON := 10.0
const BURST_PARTICLE_COUNT := 12
const BURST_PARTICLE_MAX := 48
const BURST_GRAVITY := 1200.0
const COMPANION_CAST_PROGRESS_MAX := 0.92

var _phase := PHASE_IDLE
var _phase_timer := 0.0
var _origin := Vector2.ZERO
var _projectiles: Array[Dictionary] = []
var _landed_bananas: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _slip_timer := 0.0
var _slip_direction := 0.0
var _active_skill_level := 1
var _banana_count := 1
var _slip_seconds := 0.45
var _slip_speed_per_frame := 15.0
var _registry: Object = null
var _landing_xs_for_tests: Array[float] = []
var _slip_direction_rolls_for_tests: Array[float] = []
var _throw_sound_count := 0
var _slip_sound_count := 0
var _renderer: Object = LingpetBananaSliceRenderer.new()


func reset() -> void:
	_phase = PHASE_IDLE
	_phase_timer = 0.0
	_origin = Vector2.ZERO
	_projectiles.clear()
	_landed_bananas.clear()
	_particles.clear()
	_slip_timer = 0.0
	_slip_direction = 0.0
	_active_skill_level = 1
	_banana_count = _get_banana_count_for_level(_active_skill_level)
	_slip_seconds = _get_slip_seconds_for_level(_active_skill_level)
	_slip_speed_per_frame = _get_slip_speed_for_level(_active_skill_level)
	_throw_sound_count = 0
	_slip_sound_count = 0


func cancel(_owner: Object = null, registry: Object = null) -> void:
	if registry != null:
		_registry = registry
	reset()


func prewarm() -> void:
	_renderer.prewarm()


func launch(origin: Vector2, _owner: Object = null, launch_context: Dictionary = {}) -> bool:
	reset()
	_renderer.prewarm()
	var ctx_registry: Variant = launch_context.get("registry", null)
	if typeof(ctx_registry) == TYPE_OBJECT and is_instance_valid(ctx_registry):
		_registry = ctx_registry as Object
	_active_skill_level = _get_active_skill_level(launch_context)
	_banana_count = _get_banana_count_for_context(launch_context, _active_skill_level)
	_slip_seconds = _get_slip_seconds_for_context(launch_context, _active_skill_level)
	_slip_speed_per_frame = _get_slip_speed_for_context(launch_context, _active_skill_level)
	_origin = Vector2(clampf(origin.x, 32.0, FIELD_WIDTH - 32.0), clampf(origin.y, 80.0, FIELD_HEIGHT - 32.0))
	_phase = PHASE_PREPARE
	_phase_timer = 0.0
	return true


func update(delta: float, owner: Object = null, registry: Object = null, _launch_context: Dictionary = {}) -> void:
	if registry != null:
		_registry = registry
	var safe_delta := maxf(0.0, delta)
	_update_particles(safe_delta)
	_update_slip(safe_delta)
	if _phase == PHASE_PREPARE:
		_phase_timer += safe_delta
		if _phase_timer >= PREPARE_SECONDS:
			_execute_throw()
			_phase = PHASE_IDLE
			_phase_timer = 0.0
			return
	_update_projectiles(safe_delta)
	_update_landed(safe_delta, owner)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	var prepare_active := _phase == PHASE_PREPARE
	var prepare_progress := clampf(_phase_timer / PREPARE_SECONDS, 0.0, 1.0) if prepare_active else 0.0
	_renderer.draw_banana_slice(
		canvas,
		shake_offset,
		prepare_active,
		prepare_progress,
		_get_prepare_banana_pos(prepare_progress),
		_projectiles,
		_landed_bananas,
		_particles
	)


func has_visible_effects() -> bool:
	# The boss-slip window MUST be part of this predicate: the companion skill
	# idle-update gate cuts update() whenever this returns false while the skill
	# is on cooldown, but get_boss_ai_context() keeps being polled every frame
	# outside that gate. Dropping the slip here freezes _slip_timer at whatever
	# is left after the burst particles die (0.33~0.67s) while the boss keeps
	# reading slip_active forever -> boss slides into a wall and never recovers.
	# Same idiom as dwarf_magic (_needs_owner_sync) and sand_prison (_owns_clamp).
	return (
		_phase != PHASE_IDLE
		or not _projectiles.is_empty()
		or not _landed_bananas.is_empty()
		or not _particles.is_empty()
		or _slip_timer > 0.0
	)


func is_active() -> bool:
	return has_visible_effects()


func has_companion_position_override() -> bool:
	return _phase == PHASE_PREPARE


func get_companion_position_override(fallback: Vector2 = Vector2.ZERO) -> Vector2:
	return _origin if _phase == PHASE_PREPARE else fallback


func get_companion_cast_pose_progress() -> float:
	if _phase != PHASE_PREPARE:
		return -1.0
	return lerpf(0.0, COMPANION_CAST_PROGRESS_MAX, clampf(_phase_timer / PREPARE_SECONDS, 0.0, 1.0))


func get_boss_ai_context() -> Dictionary:
	if _slip_timer <= 0.0 or absf(_slip_direction) <= 0.001:
		return {}
	return {
		"lingpet_banana_slice_boss_slip_active": true,
		"lingpet_banana_slice_boss_slip_direction": _slip_direction,
		"lingpet_banana_slice_boss_slip_speed": _slip_speed_per_frame * clampf(_slip_timer / maxf(0.001, _slip_seconds), 0.0, 1.0),
	}


func get_snapshot() -> Dictionary:
	return {
		"banana_slice_active": is_active(),
		"banana_slice_phase": _phase,
		"banana_slice_phase_prepare": PHASE_PREPARE,
		"banana_slice_prepare_seconds": PREPARE_SECONDS,
		"banana_slice_prepare_timer": _phase_timer,
		"banana_slice_active_skill_level": _active_skill_level,
		"banana_slice_banana_count": _banana_count,
		"banana_slice_banana_count_by_level": BANANA_COUNT_BY_LEVEL.duplicate(),
		"banana_slice_projectile_count": _projectiles.size(),
		"banana_slice_landed_count": _landed_bananas.size(),
		"banana_slice_particle_count": _particles.size(),
		"banana_slice_slip_active": _slip_timer > 0.0,
		"banana_slice_slip_seconds": _slip_seconds,
		"banana_slice_slip_seconds_by_level": SLIP_SECONDS_BY_LEVEL.duplicate(),
		"banana_slice_slip_timer": _slip_timer,
		"banana_slice_slip_direction": _slip_direction,
		"banana_slice_slip_initial_speed": _slip_speed_per_frame,
		"banana_slice_slip_speed_by_level": SLIP_SPEED_BY_LEVEL.duplicate(),
		"banana_slice_slip_speed": float(get_boss_ai_context().get("lingpet_banana_slice_boss_slip_speed", 0.0)),
		"banana_slice_throw_sound_count": _throw_sound_count,
		"banana_slice_slip_sound_count": _slip_sound_count,
		"banana_slice_banana_texture_loaded": _renderer.is_banana_texture_loaded(),
		"banana_slice_companion_override_active": has_companion_position_override(),
		"banana_slice_companion_cast_pose_progress": get_companion_cast_pose_progress(),
		"banana_slice_projectiles": _projectiles.duplicate(true),
		"banana_slice_landed_bananas": _landed_bananas.duplicate(true),
	}


func set_landing_xs_for_tests(xs: Array) -> void:
	_landing_xs_for_tests.clear()
	for value in xs:
		if value is int or value is float:
			_landing_xs_for_tests.append(float(value))


func set_slip_direction_rolls_for_tests(rolls: Array) -> void:
	_slip_direction_rolls_for_tests.clear()
	for value in rolls:
		if value is int or value is float:
			_slip_direction_rolls_for_tests.append(float(value))


func get_projectile_count_for_tests() -> int:
	return _projectiles.size()


func get_landed_count_for_tests() -> int:
	return _landed_bananas.size()


func get_slip_state_for_tests() -> Dictionary:
	return {
		"active": _slip_timer > 0.0,
		"timer": _slip_timer,
		"direction": _slip_direction,
		"speed": float(get_boss_ai_context().get("lingpet_banana_slice_boss_slip_speed", 0.0)),
	}


func force_land_for_tests(pos: Vector2, timer: float = LAND_SECONDS) -> void:
	_landed_bananas.append(
		LingpetBananaSlicePayloadFactory.build_landed_banana(pos, LAND_X_MIN, LAND_X_MAX, LAND_Y, timer, LAND_SECONDS)
	)


func force_throw_for_tests() -> void:
	if _phase != PHASE_PREPARE:
		_phase = PHASE_PREPARE
		_phase_timer = PREPARE_SECONDS
	_execute_throw()
	_phase = PHASE_IDLE
	_phase_timer = 0.0


func _execute_throw() -> void:
	var targets := _pick_landing_xs(_banana_count)
	var start_pos := _get_prepare_banana_pos(1.0)
	for index in range(_banana_count):
		var target_x := float(targets[index])
		_projectiles.append(
			LingpetBananaSlicePayloadFactory.build_projectile(
				start_pos,
				target_x,
				index,
				LAND_Y,
				THROW_AIM_X_DIVISOR,
				THROW_SPEED_X_MAX_PER_FRAME,
				THROW_SPEED_Y_PER_FRAME,
				SECOND_THROW_DELAY_SECONDS
			)
		)
	_play_throw_feedback()


func _update_projectiles(delta: float) -> void:
	if _projectiles.is_empty():
		return
	var fps_scale := delta * 60.0
	var write_index := 0
	for read_index in range(_projectiles.size()):
		var projectile := _projectiles[read_index]
		var delay := maxf(0.0, float(projectile.get("delay", 0.0)) - delta)
		projectile["delay"] = delay
		if delay > 0.0:
			_projectiles[write_index] = projectile
			write_index += 1
			continue
		var pos := _get_vector2(projectile, "position", Vector2.ZERO)
		var vel := _get_vector2(projectile, "velocity", Vector2.ZERO)
		pos += vel * fps_scale
		projectile["rotation_degrees"] = fposmod(
			float(projectile.get("rotation_degrees", 0.0))
			+ float(projectile.get("rotation_speed_degrees", 0.0)) * delta,
			360.0
		)
		if pos.x <= WALL_LEFT:
			pos.x = WALL_LEFT
			vel.x = absf(vel.x) * WALL_BOUNCE_SCALE
		elif pos.x >= WALL_RIGHT:
			pos.x = WALL_RIGHT
			vel.x = -absf(vel.x) * WALL_BOUNCE_SCALE
		projectile["position"] = pos
		projectile["velocity"] = vel
		var trail: Array = projectile.get("trail", []) as Array
		trail.append(pos)
		while trail.size() > 6:
			trail.pop_front()
		projectile["trail"] = trail
		if pos.y <= LAND_Y and vel.y < 0.0:
			_land_banana(Vector2(pos.x, LAND_Y))
			continue
		if pos.y < PROJECTILE_CULL_TOP or pos.y > PROJECTILE_CULL_BOTTOM:
			continue
		_projectiles[write_index] = projectile
		write_index += 1
	if write_index < _projectiles.size():
		_projectiles.resize(write_index)


func _land_banana(pos: Vector2) -> void:
	_landed_bananas.append(
		LingpetBananaSlicePayloadFactory.build_landed_banana(pos, LAND_X_MIN, LAND_X_MAX, LAND_Y, LAND_SECONDS)
	)


func _update_landed(delta: float, owner: Object) -> void:
	if _landed_bananas.is_empty():
		return
	var boss_rect := _get_boss_rect(owner)
	var write_index := 0
	for read_index in range(_landed_bananas.size()):
		var landed := _landed_bananas[read_index]
		var timer := float(landed.get("timer", LAND_SECONDS)) - delta
		if timer <= 0.0:
			continue
		landed["timer"] = timer
		var pos := _get_vector2(landed, "position", Vector2(FIELD_WIDTH * 0.5, LAND_Y))
		var banana_rect := Rect2(pos - COLLISION_SIZE * 0.5, COLLISION_SIZE)
		if not bool(landed.get("slip_triggered", false)) and boss_rect.intersects(banana_rect):
			landed["slip_triggered"] = true
			_start_boss_slip(owner, pos)
			_spawn_burst_particles(pos)
			_play_slip_feedback()
			continue
		_landed_bananas[write_index] = landed
		write_index += 1
	if write_index < _landed_bananas.size():
		_landed_bananas.resize(write_index)


func _start_boss_slip(owner: Object, banana_pos: Vector2) -> void:
	_slip_timer = _slip_seconds
	var boss_rect := _get_boss_rect(owner)
	var paddle_cx := boss_rect.position.x + boss_rect.size.x * 0.5
	var delta_x := paddle_cx - banana_pos.x
	if absf(delta_x) < SLIP_CENTER_EPSILON:
		_slip_direction = -1.0 if _consume_slip_direction_roll() < 0.5 else 1.0
	else:
		_slip_direction = -1.0 if delta_x > 0.0 else 1.0


func _update_slip(delta: float) -> void:
	if _slip_timer <= 0.0:
		_slip_timer = 0.0
		_slip_direction = 0.0
		return
	_slip_timer = maxf(0.0, _slip_timer - delta)
	if _slip_timer <= 0.0:
		_slip_direction = 0.0


func _spawn_burst_particles(pos: Vector2) -> void:
	for _i in range(BURST_PARTICLE_COUNT):
		if _particles.size() >= BURST_PARTICLE_MAX:
			_particles.pop_front()
		_particles.append(LingpetBananaSlicePayloadFactory.build_burst_particle(pos))


func _update_particles(delta: float) -> void:
	if _particles.is_empty():
		return
	var write_index := 0
	for read_index in range(_particles.size()):
		var particle := _particles[read_index]
		var life := float(particle.get("life", 0.0)) - delta
		if life <= 0.0:
			continue
		var pos := _get_vector2(particle, "position", Vector2.ZERO)
		var vel := _get_vector2(particle, "velocity", Vector2.ZERO)
		pos += vel * delta
		vel.y += BURST_GRAVITY * delta
		particle["life"] = life
		particle["position"] = pos
		particle["velocity"] = vel
		_particles[write_index] = particle
		write_index += 1
	if write_index < _particles.size():
		_particles.resize(write_index)


func _pick_landing_xs(count: int) -> Array[float]:
	var positions: Array[float] = []
	for index in range(count):
		if index < _landing_xs_for_tests.size():
			positions.append(clampf(_landing_xs_for_tests[index], LAND_RANDOM_MIN, LAND_RANDOM_MAX))
			continue
		var candidate := randf_range(LAND_RANDOM_MIN, LAND_RANDOM_MAX)
		for _attempt in range(LAND_RANDOM_ATTEMPTS):
			candidate = randf_range(LAND_RANDOM_MIN, LAND_RANDOM_MAX)
			var ok := true
			for existing in positions:
				if absf(candidate - float(existing)) < LAND_RANDOM_MIN_GAP:
					ok = false
					break
			if ok:
				break
		positions.append(candidate)
	return positions


func _get_active_skill_level(launch_context: Dictionary) -> int:
	return clampi(int(launch_context.get("active_skill_level", launch_context.get("skill_level", 1))), 1, 5)


func _get_banana_count_for_context(launch_context: Dictionary, active_skill_level: int) -> int:
	var fallback := _get_banana_count_for_level(active_skill_level)
	if launch_context.has("banana_count"):
		var context_count := float(launch_context.get("banana_count", -1.0))
		if context_count > 0.0:
			return clampi(int(round(context_count)), 1, 4)
	return fallback


func _get_slip_seconds_for_context(launch_context: Dictionary, active_skill_level: int) -> float:
	var fallback := _get_slip_seconds_for_level(active_skill_level)
	if launch_context.has("slip_seconds"):
		var context_seconds := float(launch_context.get("slip_seconds", -1.0))
		if context_seconds > 0.0:
			return context_seconds
	return fallback


func _get_slip_speed_for_context(launch_context: Dictionary, active_skill_level: int) -> float:
	var fallback := _get_slip_speed_for_level(active_skill_level)
	if launch_context.has("slip_speed"):
		var context_speed := float(launch_context.get("slip_speed", -1.0))
		if context_speed > 0.0:
			return context_speed
	return fallback


func _get_banana_count_for_level(active_skill_level: int) -> int:
	var index := clampi(active_skill_level, 1, BANANA_COUNT_BY_LEVEL.size()) - 1
	return clampi(int(BANANA_COUNT_BY_LEVEL[index]), 1, 4)


func _get_slip_seconds_for_level(active_skill_level: int) -> float:
	var index := clampi(active_skill_level, 1, SLIP_SECONDS_BY_LEVEL.size()) - 1
	return maxf(0.001, float(SLIP_SECONDS_BY_LEVEL[index]))


func _get_slip_speed_for_level(active_skill_level: int) -> float:
	var index := clampi(active_skill_level, 1, SLIP_SPEED_BY_LEVEL.size()) - 1
	return maxf(0.0, float(SLIP_SPEED_BY_LEVEL[index]))


func _get_prepare_banana_pos(progress: float) -> Vector2:
	return _origin + Vector2(0.0, lerpf(0.0, -20.0, clampf(progress, 0.0, 1.0)))


func _get_boss_rect(owner: Object) -> Rect2:
	var boss_pos := BattleSceneOwnerReader.get_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - BOSS_PADDLE_WIDTH * 0.5, 25.0))
	var boss_width := maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "boss_paddle_width", BOSS_PADDLE_WIDTH)))
	var boss_height := maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "boss_hitbox_height", BOSS_HITBOX_HEIGHT)))
	return Rect2(boss_pos, Vector2(boss_width, boss_height))


func _play_throw_feedback() -> void:
	_throw_sound_count += 1
	var audio := _get_registry_instance(_registry, "game_audio")
	if audio != null and audio.has_method("play_banana_throw"):
		audio.play_banana_throw()


func _play_slip_feedback() -> void:
	_slip_sound_count += 1
	var audio := _get_registry_instance(_registry, "game_audio")
	if audio != null and audio.has_method("play_banana_slip"):
		audio.play_banana_slip()


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _consume_slip_direction_roll() -> float:
	if not _slip_direction_rolls_for_tests.is_empty():
		return clampf(float(_slip_direction_rolls_for_tests.pop_front()), 0.0, 1.0)
	return randf()


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
