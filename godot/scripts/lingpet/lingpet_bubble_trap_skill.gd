extends RefCounted

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PROJECTILE_SPEED := 220.0
const PROJECTILE_RADIUS := 22.0
const PROJECTILE_WOBBLE_AMPLITUDE := 15.0
const PROJECTILE_WOBBLE_SECONDARY_AMPLITUDE := 5.5
const PROJECTILE_WOBBLE_FREQ := 4.2
const PROJECTILE_SPEED_PULSE_FREQ := 5.4
const PROJECTILE_SPEED_PULSE_STRENGTH := 0.14
const BUBBLE_RADIUS := 82.0
const CAPTURE_BUBBLE_PADDING := 18.0
const STAGE1_BOSS_VISUAL_CENTER_Y_OFFSET := 25.0
const STAGE2_BOSS_VISUAL_CENTER_Y_OFFSET := 31.0
const STAGE3_BOSS_VISUAL_CENTER_Y_OFFSET := 31.0
const STAGE4_BOSS_VISUAL_CENTER_Y_OFFSET := 34.0
const DEFAULT_BOSS_VISUAL_CENTER_Y_OFFSET := 25.0
const SHOT_INTERVAL_SECONDS := 0.6
const SHOT_COUNT_MIN := 2
const SHOT_COUNT_MAX := 3
const FOLLOW_LAUNCH_OFFSET_Y := -24.0
const SHOT_X_OFFSETS := [0.0, -26.0, 26.0]
const CAPTURE_DURATION_MIN_SECONDS := 2.5
const CAPTURE_DURATION_MAX_SECONDS := 3.0
const CAPTURE_FLOAT_SPEED := 56.0
const CAPTURE_STATUS_REFRESH_FRAMES := 4.0
const BURST_FLASH_SECONDS := 0.34
const TRAIL_MAX_POINTS := 10
const BURST_PARTICLES := 24
const PARTICLE_MAX := 72
const PARTICLE_GRAVITY := 120.0
const BALL_RADIUS_FALLBACK := 14.3
const STATUS_SOURCE := "maribo_bubble_trap_capture"
const INNER_BUBBLE_SIZE_VARIANCE := 0.30
const INNER_BUBBLE_OFFSETS := [
	Vector2(-0.44, -0.18),
	Vector2(-0.28, 0.30),
	Vector2(0.30, -0.34),
	Vector2(0.42, 0.10),
	Vector2(0.02, 0.34),
	Vector2(-0.04, -0.04),
]
const INNER_BUBBLE_RADII := [0.17, 0.11, 0.13, 0.10, 0.08, 0.06]

var _projectile_active := false
var _projectile_pos := Vector2.ZERO
var _projectile_vel := Vector2.ZERO
var _trail: Array[Vector2] = []
var _projectiles: Array = []
var _shot_count_target := 0
var _shots_launched := 0
var _shot_interval_timer := 0.0
var _last_launch_origin := Vector2.ZERO
var _capture_timer := 0.0
var _capture_duration_seconds := CAPTURE_DURATION_MIN_SECONDS
var _bubble_center := Vector2.ZERO
var _capture_bubble_radius := BUBBLE_RADIUS
var _capture_float_dir := 1.0
var _capture_visual_seed := 0.0
var _burst_timer := 0.0
var _burst_pos := Vector2.ZERO
var _particles: Array = []
var _capture_count := 0
var _pop_count := 0
var _last_burst_reason := ""


func reset() -> void:
	_clear_projectiles()
	_reset_shot_sequence()
	_capture_timer = 0.0
	_capture_duration_seconds = CAPTURE_DURATION_MIN_SECONDS
	_bubble_center = Vector2.ZERO
	_capture_bubble_radius = BUBBLE_RADIUS
	_capture_float_dir = 1.0
	_capture_visual_seed = 0.0
	_burst_timer = 0.0
	_burst_pos = Vector2.ZERO
	_particles.clear()
	_last_burst_reason = ""


func prewarm() -> void:
	pass


func update(delta: float, owner: Object, registry: Object = null, launch_context: Dictionary = {}) -> void:
	var safe_delta: float = maxf(0.0, delta)
	_burst_timer = maxf(0.0, _burst_timer - safe_delta)
	_update_shot_sequence(safe_delta, owner, launch_context)
	if not _projectiles.is_empty():
		_update_projectiles(safe_delta, owner, registry)
	if _capture_timer > 0.0:
		_update_capture(safe_delta, owner, registry)
	if not _particles.is_empty():
		_update_particles(safe_delta)


func launch(origin: Vector2, _owner: Object = null, _launch_context: Dictionary = {}) -> void:
	_clear_projectiles()
	_shot_count_target = _pick_shot_count(origin)
	_shots_launched = 0
	_shot_interval_timer = SHOT_INTERVAL_SECONDS
	_last_launch_origin = origin
	_launch_next_projectile(origin)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	if _capture_timer > 0.0:
		_draw_capture_bubble(canvas, _bubble_center + shake_offset)
	for projectile_value in _projectiles:
		var projectile := projectile_value as Dictionary
		_draw_projectile(canvas, projectile, shake_offset)
	if _burst_timer > 0.0:
		_draw_burst(canvas, _burst_pos + shake_offset)
	if not _particles.is_empty():
		_draw_particles(canvas, shake_offset)


func has_visible_effects() -> bool:
	return not _projectiles.is_empty() or _capture_timer > 0.0 or _burst_timer > 0.0 or not _particles.is_empty()


func is_projectile_active() -> bool:
	return not _projectiles.is_empty()


func is_shot_sequence_active() -> bool:
	return _shots_launched < _shot_count_target


func is_capture_active() -> bool:
	return _capture_timer > 0.0


func get_capture_count_for_tests() -> int:
	return _capture_count


func get_pop_count_for_tests() -> int:
	return _pop_count


func get_snapshot() -> Dictionary:
	var primary_projectile := _get_primary_projectile()
	return {
		"bubble_trap_projectile_active": not _projectiles.is_empty(),
		"bubble_trap_projectile_count": _projectiles.size(),
		"bubble_trap_projectile_pos": primary_projectile.get("pos", Vector2.ZERO),
		"bubble_trap_projectile_positions": _get_projectile_positions(),
		"bubble_trap_projectile_visual_radii": _get_projectile_visual_radii(),
		"bubble_trap_inner_bubble_size_variance": INNER_BUBBLE_SIZE_VARIANCE,
		"bubble_trap_shot_count_target": _shot_count_target,
		"bubble_trap_shots_launched": _shots_launched,
		"bubble_trap_next_shot_timer": _shot_interval_timer if is_shot_sequence_active() else 0.0,
		"bubble_trap_capture_active": _capture_timer > 0.0,
		"bubble_trap_capture_timer": _capture_timer,
		"bubble_trap_capture_duration": _capture_duration_seconds,
		"bubble_trap_center": _bubble_center,
		"bubble_trap_radius": _capture_bubble_radius,
		"bubble_trap_burst_active": _burst_timer > 0.0,
		"bubble_trap_burst_pos": _burst_pos,
		"bubble_trap_last_burst_reason": _last_burst_reason,
		"bubble_trap_capture_count": _capture_count,
		"bubble_trap_pop_count": _pop_count,
	}


func _update_shot_sequence(delta: float, owner: Object, launch_context: Dictionary) -> void:
	if delta <= 0.0:
		return
	if not is_shot_sequence_active():
		return
	_shot_interval_timer -= delta
	while _shot_interval_timer <= 0.0 and is_shot_sequence_active():
		_launch_next_projectile(_get_follow_launch_origin(owner, launch_context))
		_shot_interval_timer += SHOT_INTERVAL_SECONDS


func _update_projectiles(delta: float, owner: Object, registry: Object) -> void:
	if delta <= 0.0:
		return
	var kept: Array = []
	for projectile_value in _projectiles:
		var projectile := projectile_value as Dictionary
		if _update_projectile(projectile, delta, owner, registry):
			kept.append(projectile)
	_projectiles = kept
	_sync_primary_projectile()


func _update_projectile(projectile: Dictionary, delta: float, owner: Object, registry: Object) -> bool:
	var pos: Vector2 = projectile.get("pos", Vector2.ZERO)
	var trail: Array = projectile.get("trail", [])
	trail.append(pos)
	while trail.size() > TRAIL_MAX_POINTS:
		trail.remove_at(0)
	var age: float = maxf(0.0, float(projectile.get("age", 0.0)) + delta)
	var origin_x: float = float(projectile.get("origin_x", pos.x))
	var phase: float = float(projectile.get("phase", 0.0))
	var radius: float = _get_projectile_radius(projectile)
	var speed_scale: float = 1.0 + sin(age * PROJECTILE_SPEED_PULSE_FREQ + phase * 1.31) * PROJECTILE_SPEED_PULSE_STRENGTH
	var wobble_x: float = (
		sin(age * PROJECTILE_WOBBLE_FREQ + phase) * PROJECTILE_WOBBLE_AMPLITUDE
		+ sin(age * PROJECTILE_WOBBLE_FREQ * 1.73 + phase * 0.61) * PROJECTILE_WOBBLE_SECONDARY_AMPLITUDE
	)
	var next_pos := Vector2(
		clampf(origin_x + wobble_x, radius, FIELD_WIDTH - radius),
		pos.y - PROJECTILE_SPEED * maxf(0.20, speed_scale) * delta
	)
	if _ball_hits_circle(owner, next_pos, radius):
		_burst_projectile_at(next_pos, registry, "ball")
		return false
	var boss_rect: Rect2 = _get_boss_rect(owner)
	if _capture_timer <= 0.0 and _circle_hits_rect(next_pos, radius, boss_rect):
		_begin_capture(owner, boss_rect, registry)
		return false
	if next_pos.y < -radius or next_pos.y > FIELD_HEIGHT + radius:
		_burst_projectile_at(next_pos, registry, "miss")
		return false
	projectile["pos"] = next_pos
	projectile["vel"] = (next_pos - pos) / maxf(0.0001, delta)
	projectile["age"] = age
	projectile["trail"] = trail
	return true


func _update_capture(delta: float, owner: Object, registry: Object) -> void:
	if delta < 0.0:
		return
	if _ball_hits_circle(owner, _bubble_center, _capture_bubble_radius):
		_burst_capture_at(_bubble_center, registry, "captured_ball")
		return
	_capture_timer = maxf(0.0, _capture_timer - delta)
	if _capture_timer <= 0.0:
		_burst_capture_at(_bubble_center, registry, "expire")
		return
	_step_bubble_float(delta, owner)
	_apply_capture_to_owner(owner)
	_apply_boss_stun(registry)


func _begin_capture(owner: Object, boss_rect: Rect2, registry: Object) -> void:
	_capture_bubble_radius = _get_capture_bubble_radius(owner, boss_rect)
	_bubble_center = _get_boss_visual_center(owner, boss_rect, _capture_bubble_radius)
	_capture_duration_seconds = _pick_capture_duration_seconds(_bubble_center)
	_capture_timer = _capture_duration_seconds
	_capture_visual_seed = _seeded_unit(_bubble_center.x + _bubble_center.y, float(_capture_count) + 11.0)
	_capture_float_dir = -1.0 if _deterministic_unit(_bubble_center) < 0.5 else 1.0
	_capture_count += 1
	_last_burst_reason = ""
	_spawn_burst_particles(_bubble_center, 0.65)
	_apply_capture_to_owner(owner)
	_apply_boss_stun(registry)
	_play_hydro_feedback(registry)


func _burst_projectile_at(pos: Vector2, registry: Object, reason: String) -> void:
	_record_burst(pos, registry, reason)


func _burst_capture_at(pos: Vector2, registry: Object, reason: String) -> void:
	var was_capturing := _capture_timer > 0.0
	_capture_timer = 0.0
	_bubble_center = Vector2.ZERO
	_capture_bubble_radius = BUBBLE_RADIUS
	_record_burst(pos, registry, reason)
	if was_capturing:
		_clear_boss_stun(registry)


func _step_bubble_float(delta: float, owner: Object) -> void:
	var boss_rect: Rect2 = _get_boss_rect(owner)
	var half_width: float = maxf(_capture_bubble_radius, boss_rect.size.x * 0.5)
	_bubble_center.x += _capture_float_dir * CAPTURE_FLOAT_SPEED * delta
	if _bubble_center.x <= half_width:
		_bubble_center.x = half_width
		_capture_float_dir = 1.0
	elif _bubble_center.x >= FIELD_WIDTH - half_width:
		_bubble_center.x = FIELD_WIDTH - half_width
		_capture_float_dir = -1.0


func _apply_capture_to_owner(owner: Object) -> void:
	if owner == null:
		return
	var boss_rect: Rect2 = _get_boss_rect(owner)
	var visual_offset := _get_boss_visual_center_y_offset(owner)
	var next_pos := Vector2(
		clampf(_bubble_center.x - boss_rect.size.x * 0.5, 0.0, maxf(0.0, FIELD_WIDTH - boss_rect.size.x)),
		_bubble_center.y - boss_rect.size.y * 0.5 - visual_offset
	)
	owner.set("boss_pos", next_pos)
	if owner.get("boss_vel") != null:
		owner.set("boss_vel", 0.0)


func _record_burst(pos: Vector2, registry: Object, reason: String) -> void:
	_burst_pos = Vector2(
		clampf(pos.x, -BUBBLE_RADIUS, FIELD_WIDTH + BUBBLE_RADIUS),
		clampf(pos.y, -BUBBLE_RADIUS, FIELD_HEIGHT + BUBBLE_RADIUS)
	)
	_burst_timer = BURST_FLASH_SECONDS
	_last_burst_reason = reason
	_pop_count += 1
	_spawn_burst_particles(_burst_pos, 1.0)
	_play_hydro_feedback(registry)


func _clear_projectiles() -> void:
	_projectiles.clear()
	_projectile_active = false
	_projectile_pos = Vector2.ZERO
	_projectile_vel = Vector2.ZERO
	_trail.clear()


func _reset_shot_sequence() -> void:
	_shot_count_target = 0
	_shots_launched = 0
	_shot_interval_timer = 0.0
	_last_launch_origin = Vector2.ZERO


func _launch_next_projectile(origin: Vector2) -> void:
	if _shots_launched >= _shot_count_target:
		return
	var offset_x: float = float(SHOT_X_OFFSETS[_shots_launched % SHOT_X_OFFSETS.size()])
	var shot_origin := Vector2(clampf(origin.x + offset_x, PROJECTILE_RADIUS, FIELD_WIDTH - PROJECTILE_RADIUS), origin.y)
	var trail: Array[Vector2] = []
	trail.append(shot_origin)
	var visual_seed := _seeded_unit(shot_origin.x + shot_origin.y, float(_shots_launched) + float(_capture_count + _pop_count) * 3.17)
	var radius_scale := lerpf(0.92, 1.08, _seeded_unit(visual_seed, 5.0))
	_projectiles.append({
		"pos": shot_origin,
		"vel": Vector2(0.0, -PROJECTILE_SPEED),
		"trail": trail,
		"age": 0.0,
		"origin_x": shot_origin.x,
		"phase": visual_seed * TAU,
		"visual_seed": visual_seed,
		"radius_scale": radius_scale,
	})
	_shots_launched += 1
	_last_launch_origin = shot_origin
	_sync_primary_projectile()


func _pick_shot_count(origin: Vector2) -> int:
	var span: int = maxi(0, SHOT_COUNT_MAX - SHOT_COUNT_MIN)
	if span <= 0:
		return SHOT_COUNT_MIN
	var roll := int(floor(_deterministic_unit(origin + Vector2(float(_capture_count), float(_pop_count))) * float(span + 1)))
	return clampi(SHOT_COUNT_MIN + roll, SHOT_COUNT_MIN, SHOT_COUNT_MAX)


func _get_follow_launch_origin(owner: Object, launch_context: Dictionary) -> Vector2:
	var companion_pos := _as_vector2(launch_context.get("companion_pos", Vector2.ZERO), Vector2.ZERO)
	if companion_pos == Vector2.ZERO:
		companion_pos = _get_owner_vector2(owner, "lingpet_companion_pos", Vector2.ZERO)
	if companion_pos == Vector2.ZERO:
		companion_pos = _get_owner_vector2(owner, "ringpet_companion_pos", Vector2.ZERO)
	if companion_pos != Vector2.ZERO:
		var radius := maxf(0.0, float(launch_context.get("companion_radius", 16.0)))
		return companion_pos + Vector2(0.0, -radius - 8.0)
	if _last_launch_origin != Vector2.ZERO:
		return _last_launch_origin + Vector2(0.0, FOLLOW_LAUNCH_OFFSET_Y)
	return Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - 80.0)


func _sync_primary_projectile() -> void:
	var primary := _get_primary_projectile()
	_projectile_active = not primary.is_empty()
	_projectile_pos = primary.get("pos", Vector2.ZERO)
	_projectile_vel = primary.get("vel", Vector2.ZERO)
	_trail.clear()
	var trail_value: Variant = primary.get("trail", [])
	if trail_value is Array:
		for point in trail_value:
			if point is Vector2:
				_trail.append(point)


func _get_primary_projectile() -> Dictionary:
	if _projectiles.is_empty():
		return {}
	return _projectiles[0] as Dictionary


func _get_projectile_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for projectile_value in _projectiles:
		var projectile := projectile_value as Dictionary
		positions.append(projectile.get("pos", Vector2.ZERO))
	return positions


func _get_projectile_visual_radii() -> Array[float]:
	var radii: Array[float] = []
	for projectile_value in _projectiles:
		var projectile := projectile_value as Dictionary
		radii.append(_get_projectile_radius(projectile))
	return radii


func _get_projectile_radius(projectile: Dictionary) -> float:
	return PROJECTILE_RADIUS * clampf(float(projectile.get("radius_scale", 1.0)), 0.70, 1.30)


func _apply_boss_stun(registry: Object) -> void:
	var status_state: Object = _get_registry_instance(registry, "status_effect_state")
	if status_state == null or not status_state.has_method("apply_status"):
		return
	status_state.apply_status(
		"boss",
		"stun",
		CAPTURE_STATUS_REFRESH_FRAMES,
		{
			"cleansable": true,
			"visual": "maribo_bubble_trap",
			"suppress_stun_stars": true,
		},
		STATUS_SOURCE
	)


func _clear_boss_stun(registry: Object) -> void:
	var status_state: Object = _get_registry_instance(registry, "status_effect_state")
	if status_state == null or not status_state.has_method("clear_status"):
		return
	status_state.clear_status("boss", "stun", STATUS_SOURCE)


func _spawn_burst_particles(origin: Vector2, strength: float) -> void:
	for _i in range(BURST_PARTICLES):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(70.0, 190.0) * maxf(0.1, strength)
		_add_particle(
			origin + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0)),
			Vector2(cos(angle), sin(angle)) * speed,
			randf_range(0.28, 0.62),
			randf_range(2.4, 5.8)
		)


func _add_particle(pos: Vector2, vel: Vector2, life: float, size: float) -> void:
	if _particles.size() >= PARTICLE_MAX:
		return
	_particles.append({
		"pos": pos,
		"vel": vel,
		"life": life,
		"max_life": maxf(0.01, life),
		"size": size,
	})


func _update_particles(delta: float) -> void:
	if delta <= 0.0:
		return
	var kept: Array = []
	for particle in _particles:
		var life: float = float(particle["life"]) - delta
		if life <= 0.0:
			continue
		var vel: Vector2 = particle["vel"]
		vel.y += PARTICLE_GRAVITY * delta
		vel *= 0.96
		particle["vel"] = vel
		particle["pos"] = (particle["pos"] as Vector2) + vel * delta
		particle["life"] = life
		kept.append(particle)
	_particles = kept


func _draw_projectile(canvas: CanvasItem, projectile: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = projectile.get("pos", Vector2.ZERO)
	var trail: Array = projectile.get("trail", [])
	var radius: float = _get_projectile_radius(projectile)
	var visual_seed: float = float(projectile.get("visual_seed", 0.0))
	for i in range(trail.size()):
		var trail_pos: Vector2 = (trail[i] as Vector2) + shake_offset
		var ratio: float = float(i + 1) / float(maxi(1, trail.size()))
		canvas.draw_circle(trail_pos, lerpf(radius * 0.20, radius * 0.52, ratio), Color(0.50, 0.95, 1.0, 0.05 + 0.17 * ratio))
		if i > 0:
			var prev_pos: Vector2 = (trail[i - 1] as Vector2) + shake_offset
			canvas.draw_line(prev_pos, trail_pos, Color(0.68, 1.0, 1.0, 0.28 * ratio), maxf(1.0, 2.8 * ratio), true)
	_draw_bubble_core(canvas, pos, radius, 0.92, 0.22, visual_seed)


func _draw_capture_bubble(canvas: CanvasItem, center: Vector2) -> void:
	var ratio: float = clampf(_capture_timer / maxf(0.01, _capture_duration_seconds), 0.0, 1.0)
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var pulse: float = 0.94 + 0.06 * sin(time_seconds * 7.2)
	var fade: float = clampf(ratio / 0.18, 0.0, 1.0)
	var radius := _capture_bubble_radius * pulse
	_draw_bubble_core(canvas, center, radius, 0.72 * fade, 0.30 * fade, _capture_visual_seed)
	canvas.draw_arc(center, radius * 0.74, -PI * 0.22, PI * 0.78, 24, Color(0.90, 1.0, 1.0, 0.44 * fade), 2.0, true)
	canvas.draw_circle(center + Vector2(-radius * 0.24, -radius * 0.20), radius * 0.12, Color(1.0, 1.0, 1.0, 0.28 * fade))


func _draw_burst(canvas: CanvasItem, center: Vector2) -> void:
	var ratio: float = clampf(_burst_timer / BURST_FLASH_SECONDS, 0.0, 1.0)
	var expansion: float = 1.0 - ratio
	var radius: float = lerpf(20.0, 76.0, expansion)
	canvas.draw_circle(center, radius * 0.55, Color(0.46, 0.96, 1.0, 0.18 * ratio))
	canvas.draw_arc(center, radius, 0.0, TAU, 40, Color(0.84, 1.0, 1.0, 0.58 * ratio), 2.2, true)
	for i in range(10):
		var angle: float = TAU * float(i) / 10.0 + expansion * 0.9
		var start: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 0.42
		var end: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		canvas.draw_line(start, end, Color(0.92, 1.0, 1.0, 0.36 * ratio), 1.4, true)


func _draw_bubble_core(canvas: CanvasItem, center: Vector2, radius: float, fill_alpha: float, rim_alpha: float, detail_seed: float = 0.0) -> void:
	if radius <= 0.5:
		return
	canvas.draw_circle(center, radius * 1.08, Color(0.42, 0.92, 1.0, fill_alpha * 0.10))
	canvas.draw_circle(center, radius, Color(0.40, 0.90, 1.0, fill_alpha * 0.24))
	canvas.draw_circle(center + Vector2(-radius * 0.18, -radius * 0.22), radius * 0.56, Color(0.86, 1.0, 1.0, fill_alpha * 0.15))
	canvas.draw_circle(center + Vector2(radius * 0.20, radius * 0.26), radius * 0.46, Color(0.17, 0.62, 0.84, fill_alpha * 0.07))
	_draw_inner_bubbles(canvas, center, radius, fill_alpha, detail_seed)
	canvas.draw_arc(center, radius, -PI * 0.08, PI * 1.44, 52, Color(0.86, 1.0, 1.0, rim_alpha + 0.34), 2.0, true)
	canvas.draw_arc(center, radius * 0.90, PI * 1.08, PI * 1.70, 24, Color(1.0, 1.0, 1.0, 0.46), 2.0, true)
	canvas.draw_arc(center, radius * 0.82, -PI * 0.14, PI * 0.20, 18, Color(0.20, 0.66, 0.84, 0.30), 1.6, true)
	canvas.draw_circle(center + Vector2(-radius * 0.34, -radius * 0.34), radius * 0.17, Color(1.0, 1.0, 1.0, 0.24))
	canvas.draw_circle(center + Vector2(radius * 0.16, radius * 0.42), radius * 0.09, Color(1.0, 1.0, 1.0, 0.18))


func _draw_inner_bubbles(canvas: CanvasItem, center: Vector2, radius: float, fill_alpha: float, detail_seed: float) -> void:
	for index in range(INNER_BUBBLE_OFFSETS.size()):
		var offset: Vector2 = INNER_BUBBLE_OFFSETS[index]
		var jitter_angle: float = _seeded_unit(detail_seed, float(index) + 17.0) * TAU
		var jitter_amount: float = radius * 0.045 * _seeded_unit(detail_seed, float(index) + 31.0)
		var bubble_pos := center + offset * radius + Vector2(cos(jitter_angle), sin(jitter_angle)) * jitter_amount
		var base_radius: float = float(INNER_BUBBLE_RADII[index]) * radius
		var inner_radius: float = maxf(1.2, base_radius * _get_inner_bubble_size_scale(detail_seed, index))
		canvas.draw_circle(bubble_pos, inner_radius, Color(0.80, 0.98, 1.0, fill_alpha * 0.16))
		canvas.draw_arc(bubble_pos, inner_radius, 0.0, TAU, 18, Color(0.94, 1.0, 1.0, 0.32), 1.1, true)
		canvas.draw_circle(bubble_pos + Vector2(-inner_radius * 0.26, -inner_radius * 0.24), maxf(0.8, inner_radius * 0.22), Color(1.0, 1.0, 1.0, 0.26))


func _draw_particles(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for particle in _particles:
		var max_life: float = maxf(0.01, float(particle["max_life"]))
		var life_t: float = clampf(float(particle["life"]) / max_life, 0.0, 1.0)
		var alpha: float = clampf(life_t * 1.35, 0.0, 1.0)
		if alpha <= 0.02:
			continue
		var pos: Vector2 = (particle["pos"] as Vector2) + shake_offset
		var size: float = float(particle["size"]) * (0.72 + 0.28 * life_t)
		canvas.draw_circle(pos, size, Color(0.70, 1.0, 1.0, alpha * 0.62))


func _ball_hits_circle(owner: Object, center: Vector2, radius: float) -> bool:
	if not bool(_get_owner_value(owner, "ball_active", false)):
		return false
	var ball_pos: Vector2 = _get_owner_vector2(owner, "ball_pos", Vector2.ZERO)
	var ball_radius: float = _get_ball_radius(owner)
	var hit_radius: float = maxf(0.0, radius) + ball_radius
	return ball_pos.distance_squared_to(center) <= hit_radius * hit_radius


func _circle_hits_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(
		clampf(center.x, rect.position.x, rect.end.x),
		clampf(center.y, rect.position.y, rect.end.y)
	)
	return center.distance_squared_to(closest) <= radius * radius


func _get_boss_rect(owner: Object) -> Rect2:
	var boss_pos: Vector2 = _get_owner_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	var boss_w: float = maxf(1.0, float(_get_owner_value(owner, "boss_paddle_width", 100.0)))
	var boss_h: float = maxf(1.0, float(_get_owner_value(owner, "boss_hitbox_height", 40.0)))
	return Rect2(boss_pos, Vector2(boss_w, boss_h))


func _get_boss_visual_center(owner: Object, boss_rect: Rect2, bubble_radius: float) -> Vector2:
	var visual_offset := _get_boss_visual_center_y_offset(owner)
	var visual_center := Vector2(
		boss_rect.position.x + boss_rect.size.x * 0.5,
		boss_rect.position.y + boss_rect.size.y * 0.5 + visual_offset
	)
	return Vector2(
		clampf(visual_center.x, bubble_radius, FIELD_WIDTH - bubble_radius),
		clampf(visual_center.y, bubble_radius, FIELD_HEIGHT - bubble_radius)
	)


func _get_capture_bubble_radius(owner: Object, boss_rect: Rect2) -> float:
	var visual_offset := absf(_get_boss_visual_center_y_offset(owner))
	var visual_height := boss_rect.size.y + visual_offset * 2.0
	var width_radius := boss_rect.size.x * 0.5 + CAPTURE_BUBBLE_PADDING
	var height_radius := visual_height * 0.5 + CAPTURE_BUBBLE_PADDING
	return maxf(BUBBLE_RADIUS, maxf(width_radius, height_radius))


func _pick_capture_duration_seconds(center: Vector2) -> float:
	var roll := _seeded_unit(center.x + center.y, float(_capture_count) + 71.0)
	return lerpf(CAPTURE_DURATION_MIN_SECONDS, CAPTURE_DURATION_MAX_SECONDS, roll)


func _get_boss_visual_center_y_offset(owner: Object) -> float:
	var explicit_offset: Variant = _get_owner_value(owner, "boss_visual_center_y_offset", null)
	if explicit_offset != null:
		return float(explicit_offset)
	match int(_get_owner_value(owner, "current_stage", 1)):
		1:
			return STAGE1_BOSS_VISUAL_CENTER_Y_OFFSET
		2:
			return STAGE2_BOSS_VISUAL_CENTER_Y_OFFSET
		3:
			return STAGE3_BOSS_VISUAL_CENTER_Y_OFFSET
		4:
			return STAGE4_BOSS_VISUAL_CENTER_Y_OFFSET
	return DEFAULT_BOSS_VISUAL_CENTER_Y_OFFSET


func _get_ball_radius(owner: Object) -> float:
	if owner == null:
		return BALL_RADIUS_FALLBACK
	var ball_radius: float = float(_get_owner_value(owner, "ball_radius", 0.0))
	if ball_radius > 0.0:
		return ball_radius
	var ball_size: float = float(_get_owner_value(owner, "ball_size", BALL_RADIUS_FALLBACK * 2.0))
	return maxf(1.0, ball_size * 0.5)


func _deterministic_unit(value: Vector2) -> float:
	var seed_value: float = value.x * 12.9898 + value.y * 78.233 + float(_capture_count + _pop_count) * 19.19
	var hashed: float = sin(seed_value) * 43758.5453
	return hashed - floor(hashed)


func _get_inner_bubble_size_scale(detail_seed: float, index: int) -> float:
	return lerpf(1.0 - INNER_BUBBLE_SIZE_VARIANCE, 1.0 + INNER_BUBBLE_SIZE_VARIANCE, _seeded_unit(detail_seed, float(index) + 53.0))


func _seeded_unit(seed_value: float, salt: float) -> float:
	var hashed: float = sin(seed_value * 9283.33 + salt * 47.77) * 43758.5453
	return hashed - floor(hashed)


func _play_hydro_feedback(registry: Object) -> void:
	var audio: Object = _get_registry_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_stage2_hydro"):
		audio.play_stage2_hydro()


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner != null and owner.get(key) != null:
		return owner.get(key)
	return fallback


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, key, fallback)
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
