extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const LingpetCompanionBodyHitState := preload("res://scripts/lingpet/lingpet_companion_body_hit_state.gd")
const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")
const LingpetSoulClonePayloadFactory := preload("res://scripts/lingpet/lingpet_soul_clone_payload_factory.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const TEXTURE_PATH := "res://assets/sprites/lingpet/rabi_companion_walk.png"
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const ACTIVE_DURATION := 15.0
const ACTIVE_DURATION_BY_LEVEL := [15.0, 16.0, 17.0, 18.0, 20.0]
const CLONE_COUNT_BY_LEVEL := [1, 1, 2, 2, 3]
const CLONE_CATCH_WIDTH := 74.0
const CLONE_CATCH_HEIGHT := 42.0
const CLONE_DRAW_SIZE := Vector2(86.0, 86.0)
const CLONE_STRIKE_DRAW_SIZE := Vector2(100.0, 100.0)
const CLONE_MIN_SPEED := 116.0
const CLONE_MAX_SPEED := 168.0
const TARGET_MIN_X := 58.0
const TARGET_MAX_X := FIELD_WIDTH - 58.0
const TARGET_MIN_Y := 440.0
const TARGET_MAX_Y := FIELD_HEIGHT - 58.0
const TARGET_TOLERANCE := 16.0
const TARGET_INTERVAL_MIN := 0.72
const TARGET_INTERVAL_MAX := 1.55
const PARTICLE_MAX := 96
const AMBIENT_PARTICLE_INTERVAL := 0.055
const VANISH_PARTICLE_COUNT := 18
const BALL_HIT_PARTICLE_COUNT := 14

var _texture: Texture2D = null
var _active := false
var _elapsed := 0.0
var _active_duration := ACTIVE_DURATION
var _active_skill_level := 1
var _clone_count := 1
var _clones: Array[Dictionary] = []
var _seed := 0
var _hit_count := 0
var _last_hit_pos := Vector2.ZERO
var _particles: Array[Dictionary] = []


func reset() -> void:
	_active = false
	_elapsed = 0.0
	_active_duration = ACTIVE_DURATION
	_active_skill_level = 1
	_clone_count = 1
	_clones.clear()
	_seed = 0
	_hit_count = 0
	_last_hit_pos = Vector2.ZERO
	_particles.clear()


func cancel(_owner: Object = null, _registry: Object = null) -> void:
	reset()


func prewarm() -> void:
	_ensure_texture()


func launch(origin: Vector2, owner: Object = null, launch_context: Dictionary = {}) -> bool:
	reset()
	_ensure_texture()
	_active = true
	_elapsed = 0.0
	_active_skill_level = _get_active_skill_level(launch_context)
	_active_duration = _get_duration_for_context(launch_context, _active_skill_level)
	_clone_count = _get_clone_count_for_context(launch_context, _active_skill_level)
	_seed = _build_seed(origin, owner)
	var launch_pos := _resolve_launch_pos(origin)
	for index in range(_clone_count):
		var clone_pos := _resolve_launch_pos(launch_pos + _get_launch_offset(index, _clone_count))
		_clones.append(_make_clone(index, clone_pos, owner))
		_spawn_burst(clone_pos, VANISH_PARTICLE_COUNT, 1.0)
	return not _clones.is_empty()


func update(delta: float, owner: Object, registry: Object = null, _launch_context: Dictionary = {}) -> void:
	var safe_delta := maxf(0.0, delta)
	_update_particles(safe_delta)
	if not _active:
		return
	_elapsed += safe_delta
	if _elapsed >= _active_duration:
		_end_clone()
		return
	for index in range(_clones.size()):
		var clone := _clones[index]
		_advance_clone_runtime(clone, safe_delta)
		_update_motion(safe_delta, owner, clone)
		_resolve_ball_hit(owner, registry, clone)
		_update_ambient_wisps(safe_delta, clone)
		_clones[index] = clone


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	_draw_particles(canvas, shake_offset)
	if not _active:
		return
	var texture := _ensure_texture()
	var remaining_ratio := clampf((_active_duration - _elapsed) / maxf(0.001, _active_duration), 0.0, 1.0)
	var fade_alpha := clampf(minf(_elapsed / 0.28, remaining_ratio / 0.12), 0.0, 1.0)
	for clone_value in _clones:
		var clone := clone_value as Dictionary
		var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.006 + float(clone.get("bob_phase", 0.0)))
		var clone_pos := _get_clone_vector2(clone, "pos", Vector2.ZERO)
		var draw_center := clone_pos + shake_offset + Vector2(0.0, sin(float(Time.get_ticks_msec()) * 0.0048 + float(clone.get("bob_phase", 0.0))) * 2.4)
		_draw_clone_aura(canvas, draw_center, fade_alpha, pulse)
		if texture == null:
			_draw_procedural_fallback(canvas, draw_center)
		else:
			_draw_clone_sprite(canvas, texture, clone, draw_center, fade_alpha, pulse)


func has_visible_effects() -> bool:
	return _active or not _particles.is_empty()


func is_active() -> bool:
	return _active


func get_hit_count_for_tests() -> int:
	return _hit_count


func get_snapshot() -> Dictionary:
	var primary_clone := _get_primary_clone()
	return {
		"soul_clone_active": _active,
		"soul_clone_elapsed": _elapsed,
		"soul_clone_duration": _active_duration,
		"soul_clone_remaining": maxf(0.0, _active_duration - _elapsed) if _active else 0.0,
		"soul_clone_active_skill_level": _active_skill_level,
		"soul_clone_clone_count": _clones.size() if _active else 0,
		"soul_clone_configured_clone_count": _clone_count,
		"soul_clone_positions": _get_clone_positions(),
		"soul_clone_target_positions": _get_clone_target_positions(),
		"soul_clone_velocities": _get_clone_velocities(),
		"soul_clone_pos": _get_clone_vector2(primary_clone, "pos", Vector2.ZERO),
		"soul_clone_target_pos": _get_clone_vector2(primary_clone, "target_pos", Vector2.ZERO),
		"soul_clone_velocity": _get_clone_vector2(primary_clone, "velocity", Vector2.ZERO),
		"soul_clone_hit_count": _hit_count,
		"soul_clone_last_hit_pos": _last_hit_pos,
		"soul_clone_catch_width": CLONE_CATCH_WIDTH,
		"soul_clone_catch_height": CLONE_CATCH_HEIGHT,
		"soul_clone_particle_count": _particles.size(),
	}


func _ensure_texture() -> Texture2D:
	if _texture != null:
		return _texture
	_texture = ProjectResourceLoader.load_imported_texture(
		TEXTURE_PATH,
		"[LingpetSoulClone] missing Rabi clone texture: %s",
		"[LingpetSoulClone] failed to load Rabi clone texture: %s"
	)
	return _texture


func _make_clone(index: int, clone_pos: Vector2, owner: Object) -> Dictionary:
	return {
		"index": index,
		"pos": clone_pos,
		"target_pos": _pick_target(owner),
		"velocity": Vector2.ZERO,
		"speed": _next_range(CLONE_MIN_SPEED, CLONE_MAX_SPEED),
		"target_timer": _next_range(TARGET_INTERVAL_MIN, TARGET_INTERVAL_MAX),
		"face_left": false,
		"wisp_timer": _next_range(0.0, AMBIENT_PARTICLE_INTERVAL),
		"bob_phase": _next_range(0.0, TAU),
		"body_hit_state": LingpetCompanionBodyHitState.new(),
		"animator": LingpetCompanionSpriteAnimator.new(),
	}


func _resolve_launch_pos(origin: Vector2) -> Vector2:
	var fallback := Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - 110.0)
	var pos := origin if origin != Vector2.ZERO else fallback
	return Vector2(clampf(pos.x, TARGET_MIN_X, TARGET_MAX_X), clampf(pos.y, TARGET_MIN_Y, TARGET_MAX_Y))


func _advance_clone_runtime(clone: Dictionary, delta: float) -> void:
	var body_hit_state: Object = clone.get("body_hit_state", null) as Object
	if body_hit_state != null:
		body_hit_state.advance(delta)
	var animator: Object = clone.get("animator", null) as Object
	if animator != null:
		animator.advance(delta)


func _update_motion(delta: float, owner: Object, clone: Dictionary) -> void:
	if delta <= 0.0:
		clone["velocity"] = Vector2.ZERO
		return
	var clone_pos := _get_clone_vector2(clone, "pos", Vector2.ZERO)
	var target_pos := _get_clone_vector2(clone, "target_pos", Vector2.ZERO)
	var target_timer := maxf(0.0, float(clone.get("target_timer", 0.0)) - delta)
	if target_pos == Vector2.ZERO or clone_pos.distance_to(target_pos) <= TARGET_TOLERANCE or target_timer <= 0.0:
		target_pos = _pick_target(owner)
		clone["target_pos"] = target_pos
		clone["speed"] = _next_range(CLONE_MIN_SPEED, CLONE_MAX_SPEED)
		target_timer = _next_range(TARGET_INTERVAL_MIN, TARGET_INTERVAL_MAX)
	clone["target_timer"] = target_timer
	var offset := target_pos - clone_pos
	var distance := offset.length()
	if distance <= 0.01:
		clone["velocity"] = Vector2.ZERO
		return
	var direction := offset / distance
	var speed := float(clone.get("speed", CLONE_MIN_SPEED))
	var step := minf(distance, speed * delta)
	var previous_pos := clone_pos
	clone_pos += direction * step
	clone_pos.x = clampf(clone_pos.x, TARGET_MIN_X, TARGET_MAX_X)
	clone_pos.y = clampf(clone_pos.y, TARGET_MIN_Y, TARGET_MAX_Y)
	var velocity := (clone_pos - previous_pos) / maxf(0.001, delta)
	clone["pos"] = clone_pos
	clone["velocity"] = velocity
	if absf(velocity.x) > 0.05:
		clone["face_left"] = velocity.x < 0.0


func _pick_target(owner: Object) -> Vector2:
	var player_center_x := FIELD_WIDTH * 0.5
	if owner != null:
		var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5 - 77.5, FIELD_HEIGHT - 50.0))
		var player_width: float = float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", 155.0))
		player_center_x = player_pos.x + player_width * 0.5
	var anchor_x := clampf(player_center_x + _next_range(-170.0, 170.0), TARGET_MIN_X, TARGET_MAX_X)
	var roam_roll := _next_unit()
	if roam_roll < 0.34:
		anchor_x = _next_range(TARGET_MIN_X, TARGET_MAX_X)
	return Vector2(anchor_x, _next_range(TARGET_MIN_Y, TARGET_MAX_Y))


func _resolve_ball_hit(owner: Object, registry: Object, clone: Dictionary) -> void:
	if owner == null:
		return
	var body_hit_state: Object = clone.get("body_hit_state", null) as Object
	var animator: Object = clone.get("animator", null) as Object
	if body_hit_state == null or animator == null:
		return
	var hit_result: Dictionary = body_hit_state.resolve_ball_hit(
		owner,
		registry,
		_get_clone_vector2(clone, "pos", Vector2.ZERO),
		CLONE_CATCH_WIDTH,
		CLONE_CATCH_HEIGHT,
		0.0,
		true,
		bool(animator.strike_active)
	)
	if not bool(hit_result.get("hit", false)):
		return
	_hit_count += 1
	_last_hit_pos = body_hit_state.last_contact_pos
	if bool(hit_result.get("should_begin_strike", false)):
		animator.begin_strike(LingpetCompanionSpriteAnimator.STRIKE_IMPACT_FRAME)
	_spawn_burst(_last_hit_pos, BALL_HIT_PARTICLE_COUNT, 1.15)


func _end_clone() -> void:
	if not _active:
		return
	_active = false
	for clone_value in _clones:
		var clone := clone_value as Dictionary
		var body_hit_state: Object = clone.get("body_hit_state", null) as Object
		if body_hit_state != null:
			body_hit_state.ball_was_inside = false
		_spawn_burst(_get_clone_vector2(clone, "pos", Vector2.ZERO), VANISH_PARTICLE_COUNT, 0.85)
	_clones.clear()


func _update_ambient_wisps(delta: float, clone: Dictionary) -> void:
	var wisp_timer := maxf(0.0, float(clone.get("wisp_timer", 0.0)) - delta)
	if wisp_timer > 0.0:
		clone["wisp_timer"] = wisp_timer
		return
	clone["wisp_timer"] = AMBIENT_PARTICLE_INTERVAL
	if _particles.size() >= PARTICLE_MAX:
		return
	var clone_pos := _get_clone_vector2(clone, "pos", Vector2.ZERO)
	var drift := Vector2(_next_range(-10.0, 10.0), _next_range(-34.0, -16.0))
	_add_particle(
		clone_pos + Vector2(_next_range(-22.0, 22.0), _next_range(-12.0, 18.0)),
		drift,
		_next_range(0.35, 0.74),
		_next_range(1.4, 3.2),
		Color(0.48, 0.88, 1.0, _next_range(0.22, 0.42))
	)


func _spawn_burst(center: Vector2, count: int, speed_scale: float) -> void:
	var safe_count := maxi(1, count)
	for i in range(safe_count):
		var angle := TAU * float(i) / float(safe_count) + _next_range(-0.12, 0.12)
		var dir := Vector2(cos(angle), sin(angle))
		_add_particle(
			center + dir * _next_range(5.0, 19.0),
			dir * _next_range(24.0, 76.0) * speed_scale + Vector2(0.0, _next_range(-24.0, -8.0)),
			_next_range(0.34, 0.72),
			_next_range(2.0, 4.6),
			Color(0.62, 0.88, 1.0, _next_range(0.36, 0.68))
		)


func _add_particle(pos: Vector2, vel: Vector2, life: float, radius: float, color: Color) -> void:
	if _particles.size() >= PARTICLE_MAX:
		_particles.pop_front()
	_particles.append(LingpetSoulClonePayloadFactory.build_particle(pos, vel, life, radius, color))


func _update_particles(delta: float) -> void:
	if delta <= 0.0 or _particles.is_empty():
		return
	for i in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[i]
		var life := float(particle.get("life", 0.0)) - delta
		if life <= 0.0:
			_particles.remove_at(i)
			continue
		var vel: Vector2 = particle.get("vel", Vector2.ZERO)
		vel *= pow(0.82, delta * 4.0)
		particle["vel"] = vel
		particle["pos"] = (particle.get("pos", Vector2.ZERO) as Vector2) + vel * delta
		particle["life"] = life
		_particles[i] = particle


func _draw_particles(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for particle_value in _particles:
		var particle := particle_value as Dictionary
		var life := float(particle.get("life", 0.0))
		var max_life := maxf(0.01, float(particle.get("max_life", life)))
		var ratio := clampf(life / max_life, 0.0, 1.0)
		var color: Color = particle.get("color", Color(0.6, 0.9, 1.0, 0.4))
		color.a *= ratio
		var radius := maxf(0.5, float(particle.get("radius", 2.0)) * (0.55 + 0.45 * ratio))
		var pos: Vector2 = particle.get("pos", Vector2.ZERO)
		canvas.draw_circle(pos + shake_offset, radius, color)


func _draw_clone_aura(canvas: CanvasItem, center: Vector2, alpha: float, pulse: float) -> void:
	var outer_radius := lerpf(35.0, 44.0, pulse)
	var inner_radius := lerpf(22.0, 28.0, 1.0 - pulse)
	canvas.draw_circle(center, outer_radius, Color(0.18, 0.62, 1.0, 0.075 * alpha))
	canvas.draw_circle(center, inner_radius, Color(0.58, 0.92, 1.0, 0.10 * alpha))
	canvas.draw_arc(center, outer_radius * 0.82, -PI * 0.5, PI * 1.2, 36, Color(0.70, 0.96, 1.0, 0.34 * alpha), 1.6, true)


func _draw_clone_sprite(canvas: CanvasItem, texture: Texture2D, clone: Dictionary, center: Vector2, alpha: float, pulse: float) -> void:
	var animator: Object = clone.get("animator", null) as Object
	if animator == null:
		return
	var velocity := _get_clone_vector2(clone, "velocity", Vector2.ZERO)
	var mode := LingpetCompanionSpriteAnimator.MODE_STRIKE if animator.strike_active else LingpetCompanionSpriteAnimator.MODE_WALK
	var draw_size := CLONE_STRIKE_DRAW_SIZE if animator.strike_active else CLONE_DRAW_SIZE
	var speed_ratio := clampf(velocity.length() / CLONE_MAX_SPEED, 0.12, 1.0)
	var rects: Dictionary = animator.build_draw_rects(texture, mode, center, 0.0, 0.0, 0.0, speed_ratio, draw_size)
	if rects.is_empty():
		return
	var dest_rect: Rect2 = rects.get("dest", Rect2())
	var source_rect: Rect2 = rects.get("source", Rect2())
	var trail_offset := Vector2(-signf(velocity.x) * 5.0, 3.0)
	if velocity.length() <= 1.0:
		trail_offset = Vector2(0.0, 4.0)
	var trail_color := Color(0.33, 0.72, 1.0, 0.16 * alpha)
	var second_trail_color := Color(0.75, 0.52, 1.0, 0.10 * alpha)
	var face_left := bool(clone.get("face_left", false))
	_draw_region(canvas, texture, source_rect, Rect2(dest_rect.position + trail_offset * 1.7, dest_rect.size), second_trail_color, face_left)
	_draw_region(canvas, texture, source_rect, Rect2(dest_rect.position + trail_offset, dest_rect.size), trail_color, face_left)
	var main_color := Color(0.76 + 0.08 * pulse, 0.95, 1.0, 0.67 * alpha)
	_draw_region(canvas, texture, source_rect, dest_rect, main_color, face_left)


func _draw_region(canvas: CanvasItem, texture: Texture2D, source_rect: Rect2, target_rect: Rect2, modulate: Color, face_left: bool) -> void:
	if face_left:
		_draw_flipped_texture_region(canvas, texture, source_rect, target_rect, modulate)
	else:
		canvas.draw_texture_rect_region(texture, target_rect, source_rect, modulate, false, true)


func _draw_flipped_texture_region(canvas: CanvasItem, texture: Texture2D, source_rect: Rect2, target_rect: Rect2, modulate: Color) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var points := PackedVector2Array([
		target_rect.position,
		Vector2(target_rect.end.x, target_rect.position.y),
		target_rect.end,
		Vector2(target_rect.position.x, target_rect.end.y),
	])
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_min.x, uv_max.y),
		Vector2(uv_max.x, uv_max.y),
	])
	var colors := PackedColorArray([modulate, modulate, modulate, modulate])
	canvas.draw_polygon(points, colors, uvs, texture)


func _draw_procedural_fallback(canvas: CanvasItem, center: Vector2) -> void:
	canvas.draw_circle(center, 24.0, Color(0.50, 0.86, 1.0, 0.32))
	canvas.draw_arc(center, 31.0, 0.0, TAU, 28, Color(0.72, 0.96, 1.0, 0.56), 2.0, true)


func _build_seed(origin: Vector2, owner: Object) -> int:
	var player_pos := Vector2(FIELD_WIDTH * 0.5 - 77.5, FIELD_HEIGHT - 50.0)
	if owner != null:
		player_pos = BattleSceneOwnerReader.get_vector2(owner, "player_pos", player_pos)
	var raw_seed := int(absf(round(origin.x * 17.0 + origin.y * 19.0 + player_pos.x * 23.0 + player_pos.y * 29.0 + float(Time.get_ticks_msec() % 997))))
	return maxi(1, raw_seed % 2147483647)


func _get_active_skill_level(launch_context: Dictionary) -> int:
	return clampi(int(launch_context.get("active_skill_level", launch_context.get("skill_level", 1))), 1, CLONE_COUNT_BY_LEVEL.size())


func _get_clone_count_for_context(launch_context: Dictionary, active_skill_level: int) -> int:
	var fallback := int(round(_get_level_value(CLONE_COUNT_BY_LEVEL, active_skill_level, 1.0)))
	if launch_context.has("clone_count"):
		var context_count := int(round(float(launch_context.get("clone_count", fallback))))
		if context_count > 0:
			return clampi(context_count, 1, int(CLONE_COUNT_BY_LEVEL[CLONE_COUNT_BY_LEVEL.size() - 1]))
	return fallback


func _get_duration_for_context(launch_context: Dictionary, active_skill_level: int) -> float:
	var fallback := _get_level_value(ACTIVE_DURATION_BY_LEVEL, active_skill_level, ACTIVE_DURATION)
	if launch_context.has("duration_seconds"):
		var context_duration := float(launch_context.get("duration_seconds", fallback))
		if context_duration > 0.0:
			return maxf(0.1, context_duration)
	return fallback


func _get_level_value(values: Array, active_skill_level: int, fallback: float) -> float:
	if values.is_empty():
		return fallback
	var index := clampi(active_skill_level, 1, values.size()) - 1
	return float(values[index])


func _get_launch_offset(index: int, clone_count: int) -> Vector2:
	match clone_count:
		2:
			return Vector2(-34.0 if index == 0 else 34.0, -8.0)
		3:
			var offsets := [Vector2(-52.0, -8.0), Vector2(0.0, 10.0), Vector2(52.0, -8.0)]
			return offsets[clampi(index, 0, offsets.size() - 1)]
		_:
			return Vector2.ZERO


func _get_primary_clone() -> Dictionary:
	if _clones.is_empty():
		return {}
	return _clones[0] as Dictionary


func _get_clone_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if not _active:
		return positions
	for clone_value in _clones:
		positions.append(_get_clone_vector2(clone_value as Dictionary, "pos", Vector2.ZERO))
	return positions


func _get_clone_target_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if not _active:
		return positions
	for clone_value in _clones:
		positions.append(_get_clone_vector2(clone_value as Dictionary, "target_pos", Vector2.ZERO))
	return positions


func _get_clone_velocities() -> Array[Vector2]:
	var velocities: Array[Vector2] = []
	if not _active:
		return velocities
	for clone_value in _clones:
		velocities.append(_get_clone_vector2(clone_value as Dictionary, "velocity", Vector2.ZERO))
	return velocities


func _get_clone_vector2(clone: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = clone.get(key, fallback)
	return value if value is Vector2 else fallback


func _next_range(min_value: float, max_value: float) -> float:
	return lerpf(min_value, max_value, _next_unit())


func _next_unit() -> float:
	if _seed <= 0:
		_seed = 991
	_seed = int((_seed * 1103515245 + 12345) % 2147483647)
	return float(_seed % 10000) / 10000.0
