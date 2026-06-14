extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PHASE_IDLE := 0
const PHASE_ROAR := 1

const ROAR_SECONDS := 0.60
const VFX_SECONDS := 1.80
const SHOCKWAVE_GROW_SECONDS := 0.09
const COMPANION_CAST_PROGRESS_MAX := 0.92
const ROAR_RADIUS_BY_LEVEL := [180.0, 198.0, 216.0, 234.0, 252.0]
const BALL_BOOST_BY_LEVEL := [2.60, 2.85, 3.10, 3.35, 3.60]
const TRIGGER_NEAR_RATIO := 0.595
const TRIGGER_FAR_RATIO := 0.913
const BOOST_DISTANCE_WIDTH := 1.0
const ROAR_ARM_TRAVEL_FACTOR := 1.5
const ROAR_ARM_MARGIN := 6.0
const ROAR_LAUNCH_SPEED_MAX := 60.0
const ROAR_REFLECT_MIN_UPWARD_COMPONENT := 0.25
const DEFAULT_CATCH_HEIGHT := 54.0
const DEFAULT_BALL_SIZE := 28.6
const REFLECT_JITTER_RADIANS := 0.5235987756
const SCREEN_FLASH_STATE_ALPHA := 200.0 / 255.0
const SCREEN_FLASH_DRAW_ALPHA_CAP := 120.0 / 255.0
const RING_COUNT := 6
const RING_DELAY_SECONDS := 0.055
const RING_LIFE_SECONDS := 0.42
const SPARK_COUNT := 16
const IMPACT_PARTICLE_COUNT := 40
const PARTICLE_MAX := 80
const PARTICLE_LIFE_SECONDS := 0.66

var _phase := PHASE_IDLE
var _phase_timer := 0.0
var _vfx_timer := 0.0
var _origin := Vector2.ZERO
var _active_skill_level := 1
var _roar_radius := ROAR_RADIUS_BY_LEVEL[0]
var _ball_boost := BALL_BOOST_BY_LEVEL[0]
var _trigger_distance := 0.0
var _last_trigger_distance := 0.0
var _last_arm_min_gap := 0.0
var _last_can_arm_gap := 0.0
var _last_reflected := false
var _last_result := "idle"
var _last_boost_multiplier := 0.0
var _last_ball_speed_pre := 0.0
var _last_ball_speed_after := 0.0
var _last_ball_pos := Vector2.ZERO
var _last_reflect_dir := Vector2(0.0, -1.0)
var _roar_sound_count := 0
var _reflect_count := 0
var _whiff_count := 0
var _registry: Object = null
var _particles: Array[Dictionary] = []
var _trigger_distances_for_tests: Array[float] = []
var _jitter_degrees_for_tests: Array[float] = []


func reset() -> void:
	_phase = PHASE_IDLE
	_phase_timer = 0.0
	_vfx_timer = 0.0
	_origin = Vector2.ZERO
	_active_skill_level = 1
	_roar_radius = ROAR_RADIUS_BY_LEVEL[0]
	_ball_boost = BALL_BOOST_BY_LEVEL[0]
	_trigger_distance = 0.0
	_last_trigger_distance = 0.0
	_last_arm_min_gap = 0.0
	_last_can_arm_gap = 0.0
	_last_reflected = false
	_last_result = "idle"
	_last_boost_multiplier = 0.0
	_last_ball_speed_pre = 0.0
	_last_ball_speed_after = 0.0
	_last_ball_pos = Vector2.ZERO
	_last_reflect_dir = Vector2(0.0, -1.0)
	_roar_sound_count = 0
	_reflect_count = 0
	_whiff_count = 0
	_particles.clear()


func cancel(owner: Object = null, registry: Object = null) -> void:
	if registry != null:
		_registry = registry
	_clear_owner_boost(owner)
	reset()


func prewarm() -> void:
	pass


func can_arm(params: Dictionary) -> bool:
	if not bool(params.get("ball_active", false)):
		return false
	if not bool(params.get("companion_visible", false)):
		return false
	var owner: Object = params.get("owner", null) as Object
	if owner == null:
		return false
	if bool(BattleSceneOwnerReader.get_value(owner, "skip_ball_motion_step", false)):
		return false
	var companion_pos: Vector2 = _as_vector2(params.get("companion_pos", Vector2.ZERO), Vector2.ZERO)
	if companion_pos == Vector2.ZERO:
		return false
	var ball_pos: Vector2 = _get_context_or_owner_vector2(params, owner, "ball_pos", Vector2.ZERO)
	var ball_vel: Vector2 = _get_context_or_owner_vector2(params, owner, "ball_vel", Vector2.ZERO)
	if ball_vel.y <= 0.0:
		return false
	var active_level := _get_active_skill_level(params)
	var roar_radius := _get_roar_radius_for_context(params, active_level)
	if _trigger_distance <= 0.0:
		_trigger_distance = _consume_trigger_distance_roll(roar_radius)
	var ball_radius := maxf(1.0, float(params.get(
		"ball_radius",
		float(_get_context_or_owner_value(params, owner, "ball_size", DEFAULT_BALL_SIZE)) * 0.5
	)))
	var catch_height := maxf(1.0, float(params.get("companion_catch_height", DEFAULT_CATCH_HEIGHT)))
	var catch_half_height := catch_height * 0.5
	_last_arm_min_gap = catch_half_height + ball_radius + maxf(0.0, ball_vel.y) * ROAR_ARM_TRAVEL_FACTOR + ROAR_ARM_MARGIN
	_last_can_arm_gap = companion_pos.y - ball_pos.y
	if _last_can_arm_gap <= _last_arm_min_gap:
		return false
	if _last_can_arm_gap > _trigger_distance:
		return false
	return absf(ball_pos.x - companion_pos.x) <= roar_radius


func launch(origin: Vector2, owner: Object = null, launch_context: Dictionary = {}) -> bool:
	var cycle_trigger_distance := _trigger_distance
	reset()
	var ctx_registry: Variant = launch_context.get("registry", null)
	if typeof(ctx_registry) == TYPE_OBJECT and is_instance_valid(ctx_registry):
		_registry = ctx_registry as Object
	_active_skill_level = _get_active_skill_level(launch_context)
	_roar_radius = _get_roar_radius_for_context(launch_context, _active_skill_level)
	_ball_boost = _get_ball_boost_for_context(launch_context, _active_skill_level)
	_origin = Vector2(clampf(origin.x, 0.0, FIELD_WIDTH), clampf(origin.y, 0.0, FIELD_HEIGHT))
	_trigger_distance = cycle_trigger_distance if cycle_trigger_distance > 0.0 else _consume_trigger_distance_roll(_roar_radius)
	_last_trigger_distance = _trigger_distance
	_begin_roar_vfx(false)
	_play_roar_feedback()
	if _try_reflect_ball(owner):
		_begin_roar_vfx(true)
		_apply_feedback_shake(0.065, 2.2)
	else:
		_last_result = "whiff"
		_whiff_count += 1
		_apply_feedback_shake(0.025, 0.85)
	_trigger_distance = 0.0
	return true


func update(delta: float, _owner: Object = null, registry: Object = null, _launch_context: Dictionary = {}) -> void:
	if registry != null:
		_registry = registry
	var safe_delta := maxf(0.0, delta)
	if _phase == PHASE_ROAR:
		_phase_timer += safe_delta
		if _phase_timer >= ROAR_SECONDS:
			_phase = PHASE_IDLE
	if _vfx_timer > 0.0:
		_vfx_timer = maxf(0.0, _vfx_timer - safe_delta)
	_update_particles(safe_delta)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	if _vfx_timer <= 0.0 and _particles.is_empty():
		return
	var elapsed := VFX_SECONDS - _vfx_timer
	_draw_screen_flash(canvas)
	_draw_roar_zone(canvas, _origin + shake_offset, elapsed)
	_draw_particles(canvas, shake_offset)
	if _last_reflected:
		_draw_ball_glow(canvas, _last_ball_pos + shake_offset, elapsed)


func has_visible_effects() -> bool:
	return _phase != PHASE_IDLE or _vfx_timer > 0.0 or not _particles.is_empty()


func is_active() -> bool:
	return has_visible_effects()


func has_companion_position_override() -> bool:
	return _phase == PHASE_ROAR


func get_companion_position_override(fallback: Vector2 = Vector2.ZERO) -> Vector2:
	return _origin if _phase == PHASE_ROAR else fallback


func get_companion_cast_pose_progress() -> float:
	if _phase != PHASE_ROAR:
		return -1.0
	return lerpf(0.0, COMPANION_CAST_PROGRESS_MAX, clampf(_phase_timer / ROAR_SECONDS, 0.0, 1.0))


func get_snapshot() -> Dictionary:
	return {
		"wild_roar_active": is_active(),
		"wild_roar_phase": _phase,
		"wild_roar_phase_roar": PHASE_ROAR,
		"wild_roar_origin": _origin,
		"wild_roar_roar_seconds": ROAR_SECONDS,
		"wild_roar_vfx_seconds": VFX_SECONDS,
		"wild_roar_phase_timer": _phase_timer,
		"wild_roar_vfx_timer": _vfx_timer,
		"wild_roar_active_skill_level": _active_skill_level,
		"wild_roar_radius": _roar_radius,
		"wild_roar_radius_by_level": ROAR_RADIUS_BY_LEVEL.duplicate(),
		"wild_roar_ball_boost": _ball_boost,
		"wild_roar_ball_boost_by_level": BALL_BOOST_BY_LEVEL.duplicate(),
		"wild_roar_trigger_distance": _trigger_distance,
		"wild_roar_last_trigger_distance": _last_trigger_distance,
		"wild_roar_last_arm_min_gap": _last_arm_min_gap,
		"wild_roar_last_can_arm_gap": _last_can_arm_gap,
		"wild_roar_last_reflected": _last_reflected,
		"wild_roar_last_result": _last_result,
		"wild_roar_last_boost_multiplier": _last_boost_multiplier,
		"wild_roar_last_ball_speed_pre": _last_ball_speed_pre,
		"wild_roar_last_ball_speed_after": _last_ball_speed_after,
		"wild_roar_last_reflect_dir": _last_reflect_dir,
		"wild_roar_launch_speed_max": ROAR_LAUNCH_SPEED_MAX,
		"wild_roar_reflect_min_upward_component": ROAR_REFLECT_MIN_UPWARD_COMPONENT,
		"wild_roar_screen_flash_state_alpha": SCREEN_FLASH_STATE_ALPHA,
		"wild_roar_screen_flash_draw_alpha_cap": SCREEN_FLASH_DRAW_ALPHA_CAP,
		"wild_roar_companion_override_active": has_companion_position_override(),
		"wild_roar_companion_cast_pose_progress": get_companion_cast_pose_progress(),
		"wild_roar_particle_count": _particles.size(),
		"wild_roar_reflect_count": _reflect_count,
		"wild_roar_whiff_count": _whiff_count,
		"wild_roar_sound_count": _roar_sound_count,
	}


func set_trigger_distances_for_tests(values: Array) -> void:
	_trigger_distances_for_tests.clear()
	for value in values:
		if value is int or value is float:
			_trigger_distances_for_tests.append(float(value))


func set_jitter_degrees_for_tests(values: Array) -> void:
	_jitter_degrees_for_tests.clear()
	for value in values:
		if value is int or value is float:
			_jitter_degrees_for_tests.append(float(value))


func get_reflect_count_for_tests() -> int:
	return _reflect_count


func get_whiff_count_for_tests() -> int:
	return _whiff_count


func get_last_arm_min_gap_for_tests() -> float:
	return _last_arm_min_gap


func _begin_roar_vfx(reflected: bool) -> void:
	_phase = PHASE_ROAR
	_phase_timer = 0.0
	_vfx_timer = VFX_SECONDS
	_particles.clear()
	_spawn_roar_sparks(_origin)
	if reflected:
		_spawn_impact_particles(_last_ball_pos)


func _try_reflect_ball(owner: Object) -> bool:
	if owner == null:
		return false
	if not bool(BattleSceneOwnerReader.get_value(owner, "ball_active", false)):
		return false
	var ball_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_pos", Vector2.ZERO)
	var ball_vel: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_vel", Vector2.ZERO)
	var dist := _origin.distance_to(ball_pos)
	_last_ball_pos = ball_pos
	_last_ball_speed_pre = ball_vel.length()
	_last_ball_speed_after = _last_ball_speed_pre
	if dist <= 1.0 or dist >= _roar_radius or _last_ball_speed_pre <= 0.001:
		return false
	var normal := (ball_pos - _origin).normalized()
	var reflected := ball_vel - 2.0 * ball_vel.dot(normal) * normal
	var angle := (Vector2(0.0, -1.0) if reflected.length_squared() <= 0.0001 else reflected.normalized()).angle()
	angle += _consume_jitter_radians()
	var reflect_dir := Vector2(cos(angle), sin(angle)).normalized()
	reflect_dir = _with_min_upward_component(reflect_dir)
	_last_reflect_dir = reflect_dir
	_last_boost_multiplier = _get_boost_multiplier(_last_trigger_distance, _roar_radius, _ball_boost)
	var boosted_speed := minf(_last_ball_speed_pre * _last_boost_multiplier, ROAR_LAUNCH_SPEED_MAX)
	var boosted_vel := reflect_dir * boosted_speed
	_last_ball_speed_after = boosted_vel.length()
	owner.set("ball_vel", boosted_vel)
	owner.set("lingpet_wild_roar_ball_boost_active", true)
	owner.set("lingpet_wild_roar_ball_restore_speed", _last_ball_speed_pre)
	_last_reflected = true
	_last_result = "reflected"
	_reflect_count += 1
	return true


func _get_boost_multiplier(trigger_distance: float, roar_radius: float, max_boost: float) -> float:
	var near := roar_radius * TRIGGER_NEAR_RATIO
	var far := maxf(near + 0.001, roar_radius * TRIGGER_FAR_RATIO)
	var t := clampf((trigger_distance - near) / (far - near), 0.0, 1.0)
	return maxf(0.1, max_boost - t * BOOST_DISTANCE_WIDTH)


func _with_min_upward_component(direction: Vector2) -> Vector2:
	if direction.length_squared() <= 0.0001:
		return Vector2(0.0, -1.0)
	var result := direction.normalized()
	if result.y <= -ROAR_REFLECT_MIN_UPWARD_COMPONENT:
		return result
	var x_sign := signf(result.x)
	if is_zero_approx(x_sign):
		return Vector2(0.0, -1.0)
	var horizontal := sqrt(maxf(0.0, 1.0 - ROAR_REFLECT_MIN_UPWARD_COMPONENT * ROAR_REFLECT_MIN_UPWARD_COMPONENT))
	return Vector2(x_sign * horizontal, -ROAR_REFLECT_MIN_UPWARD_COMPONENT)


func _spawn_roar_sparks(center: Vector2) -> void:
	for index in range(SPARK_COUNT):
		if _particles.size() >= PARTICLE_MAX:
			_particles.pop_front()
		var angle := TAU * float(index) / float(SPARK_COUNT) + randf_range(-0.13, 0.13)
		var speed := randf_range(135.0, 285.0)
		_particles.append({
			"position": center + Vector2(cos(angle), sin(angle)) * randf_range(8.0, 24.0),
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"life": PARTICLE_LIFE_SECONDS,
			"max_life": PARTICLE_LIFE_SECONDS,
			"size": randf_range(2.0, 5.5),
			"color": Color(1.0, randf_range(0.66, 0.92), 0.18, randf_range(0.70, 0.95)),
		})


func _spawn_impact_particles(center: Vector2) -> void:
	for _index in range(IMPACT_PARTICLE_COUNT):
		if _particles.size() >= PARTICLE_MAX:
			_particles.pop_front()
		var angle := randf_range(-PI, 0.0)
		var speed := randf_range(180.0, 420.0)
		_particles.append({
			"position": center + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0)),
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"life": randf_range(0.30, 0.72),
			"max_life": 0.72,
			"size": randf_range(2.5, 7.0),
			"color": Color(1.0, 0.96, randf_range(0.32, 0.62), randf_range(0.70, 1.0)),
		})


func _update_particles(delta: float) -> void:
	if _particles.is_empty():
		return
	var write_index := 0
	for read_index in range(_particles.size()):
		var particle := _particles[read_index]
		var life := float(particle.get("life", 0.0)) - delta
		if life <= 0.0:
			continue
		var pos := _as_vector2(particle.get("position", Vector2.ZERO), Vector2.ZERO)
		var vel := _as_vector2(particle.get("velocity", Vector2.ZERO), Vector2.ZERO)
		pos += vel * delta
		vel *= pow(0.10, delta)
		particle["life"] = life
		particle["position"] = pos
		particle["velocity"] = vel
		_particles[write_index] = particle
		write_index += 1
	if write_index < _particles.size():
		_particles.resize(write_index)


func _draw_screen_flash(canvas: CanvasItem) -> void:
	var flash_fade := clampf(_vfx_timer / VFX_SECONDS, 0.0, 1.0)
	var state_alpha := SCREEN_FLASH_STATE_ALPHA * flash_fade
	var draw_alpha := minf(state_alpha, SCREEN_FLASH_DRAW_ALPHA_CAP)
	if draw_alpha <= 0.0:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(FIELD_WIDTH, FIELD_HEIGHT)), Color(1.0, 0.88, 0.28, draw_alpha * 0.34), true)


func _draw_roar_zone(canvas: CanvasItem, center: Vector2, elapsed: float) -> void:
	var grow := clampf(elapsed / SHOCKWAVE_GROW_SECONDS, 0.0, 1.0)
	var eased_grow := 1.0 - pow(1.0 - grow, 3.0)
	var base_alpha := clampf(_vfx_timer / VFX_SECONDS, 0.0, 1.0)
	canvas.draw_circle(center, _roar_radius * eased_grow, Color(1.0, 0.70, 0.08, 0.055 * base_alpha))
	for index in range(RING_COUNT):
		var ring_elapsed := elapsed - float(index) * RING_DELAY_SECONDS
		if ring_elapsed < 0.0 or ring_elapsed > RING_LIFE_SECONDS:
			continue
		var t := clampf(ring_elapsed / RING_LIFE_SECONDS, 0.0, 1.0)
		var radius := lerpf(_roar_radius * 0.16, _roar_radius, 1.0 - pow(1.0 - t, 2.0))
		var alpha := (1.0 - t) * (0.66 if index == 0 else 0.42)
		var color := Color(1.0, 0.82, 0.16, alpha)
		canvas.draw_arc(center, radius, 0.0, TAU, 72, color, lerpf(4.5, 1.4, t), true)
		if index % 2 == 0:
			canvas.draw_arc(center, radius * 0.78, 0.0, TAU, 56, Color(0.35, 0.95, 1.0, alpha * 0.28), 1.4, true)
	for spoke in range(10):
		var angle := TAU * float(spoke) / 10.0 + elapsed * 2.2
		var start := center + Vector2(cos(angle), sin(angle)) * _roar_radius * 0.18 * eased_grow
		var end := center + Vector2(cos(angle), sin(angle)) * _roar_radius * (0.54 + 0.20 * sin(elapsed * 8.0 + float(spoke)))
		canvas.draw_line(start, end, Color(1.0, 0.90, 0.34, 0.18 * base_alpha), 2.0, true)


func _draw_particles(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for particle in _particles:
		var max_life := maxf(0.001, float(particle.get("max_life", PARTICLE_LIFE_SECONDS)))
		var alpha := clampf(float(particle.get("life", 0.0)) / max_life, 0.0, 1.0)
		var color: Color = particle.get("color", Color(1.0, 0.82, 0.2, 1.0))
		color.a *= alpha
		canvas.draw_circle(_as_vector2(particle.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset, float(particle.get("size", 3.0)) * (0.55 + alpha * 0.45), color)


func _draw_ball_glow(canvas: CanvasItem, center: Vector2, elapsed: float) -> void:
	var alpha := clampf(1.0 - elapsed / 0.75, 0.0, 1.0)
	if alpha <= 0.0:
		return
	canvas.draw_circle(center, 33.0, Color(1.0, 0.84, 0.18, 0.22 * alpha))
	canvas.draw_arc(center, 41.0, 0.0, TAU, 48, Color(1.0, 0.95, 0.40, 0.48 * alpha), 2.2, true)
	var streak_end := center + _last_reflect_dir * 54.0
	canvas.draw_line(center, streak_end, Color(1.0, 0.94, 0.35, 0.62 * alpha), 4.0, true)


func _play_roar_feedback() -> void:
	_roar_sound_count += 1
	var audio := _get_registry_instance(_registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_lingpet_wild_roar"):
		audio.play_lingpet_wild_roar()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func _apply_feedback_shake(amount: float, intensity: float) -> void:
	var feedback := _get_registry_instance(_registry, "battle_feedback_state")
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(amount, intensity)


func _clear_owner_boost(owner: Object) -> void:
	if owner == null:
		return
	owner.set("lingpet_wild_roar_ball_boost_active", false)
	owner.set("lingpet_wild_roar_ball_restore_speed", 0.0)


func _consume_trigger_distance_roll(roar_radius: float) -> float:
	var near := roar_radius * TRIGGER_NEAR_RATIO
	var far := roar_radius * TRIGGER_FAR_RATIO
	if not _trigger_distances_for_tests.is_empty():
		return clampf(float(_trigger_distances_for_tests.pop_front()), near, far)
	return randf_range(near, far)


func _consume_jitter_radians() -> float:
	if not _jitter_degrees_for_tests.is_empty():
		return deg_to_rad(clampf(float(_jitter_degrees_for_tests.pop_front()), -30.0, 30.0))
	return randf_range(-REFLECT_JITTER_RADIANS, REFLECT_JITTER_RADIANS)


func _get_active_skill_level(context: Dictionary) -> int:
	return clampi(int(context.get("active_skill_level", context.get("skill_level", 1))), 1, ROAR_RADIUS_BY_LEVEL.size())


func _get_roar_radius_for_context(context: Dictionary, active_skill_level: int) -> float:
	var context_radius := float(context.get("roar_radius", -1.0))
	if context_radius > 0.0:
		return context_radius
	return _get_array_level_value(ROAR_RADIUS_BY_LEVEL, active_skill_level, ROAR_RADIUS_BY_LEVEL[0])


func _get_ball_boost_for_context(context: Dictionary, active_skill_level: int) -> float:
	var context_boost := float(context.get("ball_boost", -1.0))
	if context_boost > 0.0:
		return context_boost
	return _get_array_level_value(BALL_BOOST_BY_LEVEL, active_skill_level, BALL_BOOST_BY_LEVEL[0])


func _get_array_level_value(values: Array, level: int, fallback: float) -> float:
	if values.is_empty():
		return fallback
	var index := clampi(level - 1, 0, values.size() - 1)
	return float(values[index])


func _get_context_or_owner_value(context: Dictionary, owner: Object, key: String, fallback: Variant) -> Variant:
	if context.has(key):
		return context.get(key, fallback)
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _get_context_or_owner_vector2(context: Dictionary, owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_context_or_owner_value(context, owner, key, fallback)
	return value if value is Vector2 else fallback


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance(key)
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			return cached as Object
	if registry.has_method("get_instance"):
		var value: Variant = registry.get_instance(key)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
	return null
