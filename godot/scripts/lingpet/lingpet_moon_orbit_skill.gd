extends RefCounted

const LingpetMoonOrbitPayloadFactory := preload("res://scripts/lingpet/lingpet_moon_orbit_payload_factory.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PROJECTILE_SPEED := 620.0
const PROJECTILE_RADIUS := 9.0
const WALL_Y := 12.0
const ORBIT_DROP_Y := 50.0
const ORBIT_HALF_WIDTH := 220.0
const ORBIT_HALF_HEIGHT := 54.0
const ORBIT_DURATION_SECONDS := 4.0
const SLOW_MULTIPLIER := 0.72
const SLOW_REFRESH_FRAMES := 4.0
const BURST_FLASH_SECONDS := 0.42
const TRAIL_MAX_POINTS := 12
const SPARK_PARTICLES := 18
const AMBIENT_INTERVAL := 0.12
const AMBIENT_BURST := 2
const PARTICLE_MAX := 54
const STATUS_SOURCE := "draft_bat_moon_orbit_field"

var _projectile_active := false
var _projectile_pos := Vector2.ZERO
var _projectile_vel := Vector2.ZERO
var _trail: Array[Vector2] = []
var _orbit_pos := Vector2.ZERO
var _orbit_timer := 0.0
var _burst_timer := 0.0
var _particles: Array = []
var _ambient_timer := 0.0
var _orbit_seed := 0


func reset() -> void:
	_projectile_active = false
	_projectile_pos = Vector2.ZERO
	_projectile_vel = Vector2.ZERO
	_trail.clear()
	_orbit_pos = Vector2.ZERO
	_orbit_timer = 0.0
	_burst_timer = 0.0
	_particles.clear()
	_ambient_timer = 0.0
	_orbit_seed = 0


func prewarm() -> void:
	pass


func update(delta: float, owner: Object, registry: Object = null) -> void:
	var safe_delta: float = maxf(0.0, delta)
	_burst_timer = maxf(0.0, _burst_timer - safe_delta)
	var orbit_delta: float = safe_delta
	if _projectile_active:
		_trail.append(_projectile_pos)
		while _trail.size() > TRAIL_MAX_POINTS:
			_trail.remove_at(0)
		var wall_y: float = _get_wall_y(owner)
		var next_projectile_pos: Vector2 = _projectile_pos + _projectile_vel * safe_delta
		if next_projectile_pos.y <= wall_y:
			var distance_to_wall: float = maxf(0.0, _projectile_pos.y - wall_y)
			var travel_time := 0.0
			if absf(_projectile_vel.y) > 0.001:
				travel_time = clampf(distance_to_wall / absf(_projectile_vel.y), 0.0, safe_delta)
			_projectile_pos += _projectile_vel * travel_time
			_projectile_pos.y = wall_y
			_spawn_orbit_field(owner)
			orbit_delta = maxf(0.0, safe_delta - travel_time)
		else:
			_projectile_pos = next_projectile_pos

	if _orbit_timer > 0.0:
		_orbit_timer = maxf(0.0, _orbit_timer - orbit_delta)
		if _orbit_timer > 0.0:
			_apply_boss_slow(owner, registry)

	if not _particles.is_empty() or _orbit_timer > 0.0:
		_update_particles(safe_delta)


func launch(origin: Vector2) -> void:
	_projectile_active = true
	_projectile_pos = origin
	_projectile_vel = Vector2(0.0, -PROJECTILE_SPEED)
	_trail.clear()
	_trail.append(origin)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	if _orbit_timer > 0.0:
		_draw_orbit_field(canvas, _orbit_pos + shake_offset)
	if not _particles.is_empty():
		_draw_particles(canvas, shake_offset)
	if _burst_timer > 0.0:
		_draw_burst(canvas, _orbit_pos - Vector2(0.0, ORBIT_DROP_Y) + shake_offset)
	if _projectile_active:
		_draw_projectile(canvas, _projectile_pos + shake_offset, shake_offset)


func has_visible_effects() -> bool:
	return _projectile_active or _orbit_timer > 0.0 or _burst_timer > 0.0 or not _particles.is_empty()


func is_projectile_active() -> bool:
	return _projectile_active


func is_orbit_field_active() -> bool:
	return _orbit_timer > 0.0


func get_particle_count_for_tests() -> int:
	return _particles.size()


func get_snapshot() -> Dictionary:
	return {
		"moon_orbit_projectile_active": _projectile_active,
		"moon_orbit_projectile_pos": _projectile_pos,
		"moon_orbit_field_active": _orbit_timer > 0.0,
		"moon_orbit_field_pos": _orbit_pos,
		"moon_orbit_field_timer": _orbit_timer,
		"moon_orbit_field_half_width": ORBIT_HALF_WIDTH,
		"moon_orbit_field_half_height": ORBIT_HALF_HEIGHT,
		"moon_orbit_slow_multiplier": SLOW_MULTIPLIER,
	}


func _spawn_orbit_field(owner: Object) -> void:
	var wall_y: float = _get_wall_y(owner)
	var impact_pos := Vector2(
		clampf(_projectile_pos.x, PROJECTILE_RADIUS, FIELD_WIDTH - PROJECTILE_RADIUS),
		wall_y
	)
	_projectile_active = false
	_projectile_vel = Vector2.ZERO
	_trail.clear()
	_orbit_pos = Vector2(
		impact_pos.x,
		clampf(impact_pos.y + ORBIT_DROP_Y, PROJECTILE_RADIUS, FIELD_HEIGHT - PROJECTILE_RADIUS)
	)
	_orbit_timer = ORBIT_DURATION_SECONDS
	_burst_timer = BURST_FLASH_SECONDS
	_ambient_timer = 0.0
	_orbit_seed = int(absf(round(impact_pos.x * 11.0 + impact_pos.y * 29.0))) % 4096
	_spawn_burst_particles(impact_pos)


func _spawn_burst_particles(origin: Vector2) -> void:
	for _i in range(SPARK_PARTICLES):
		_add_particle(LingpetMoonOrbitPayloadFactory.build_burst_particle(origin))


func _add_particle(particle: Dictionary) -> void:
	if _particles.size() >= PARTICLE_MAX:
		return
	_particles.append(particle)


func _update_particles(delta: float) -> void:
	if delta <= 0.0:
		return
	var kept: Array = []
	for particle in _particles:
		var life: float = float(particle["life"]) - delta
		if life <= 0.0:
			continue
		var vel: Vector2 = particle["vel"]
		if int(particle["kind"]) == 0:
			vel.y += 230.0 * delta
			vel *= 0.96
		else:
			vel *= 0.90
			vel.y -= 18.0 * delta
		particle["vel"] = vel
		particle["pos"] = (particle["pos"] as Vector2) + vel * delta
		particle["life"] = life
		kept.append(particle)
	_particles = kept

	if _orbit_timer > 0.0:
		_ambient_timer -= delta
		if _ambient_timer <= 0.0:
			_ambient_timer = AMBIENT_INTERVAL
			for _i in range(AMBIENT_BURST):
				_add_particle(
					LingpetMoonOrbitPayloadFactory.build_ambient_particle(
						_orbit_pos,
						ORBIT_HALF_WIDTH,
						ORBIT_HALF_HEIGHT
					)
				)


func _apply_boss_slow(owner: Object, registry: Object) -> void:
	if registry == null or not _is_boss_touching_orbit(owner):
		return
	var status_state: Object = _get_registry_instance(registry, "status_effect_state")
	if status_state == null or not status_state.has_method("apply_status"):
		return
	status_state.apply_status(
		"boss",
		"slow",
		SLOW_REFRESH_FRAMES,
		LingpetMoonOrbitPayloadFactory.build_slow_status_data(SLOW_MULTIPLIER),
		STATUS_SOURCE
	)


func _is_boss_touching_orbit(owner: Object) -> bool:
	if _orbit_timer <= 0.0:
		return false
	var boss_rect: Rect2 = _get_boss_rect(owner)
	var closest := Vector2(
		clampf(_orbit_pos.x, boss_rect.position.x, boss_rect.end.x),
		clampf(_orbit_pos.y, boss_rect.position.y, boss_rect.end.y)
	)
	var dx: float = closest.x - _orbit_pos.x
	var dy: float = closest.y - _orbit_pos.y
	var rx: float = maxf(1.0, ORBIT_HALF_WIDTH)
	var ry: float = maxf(1.0, ORBIT_HALF_HEIGHT)
	return (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) <= 1.0


func _get_boss_rect(owner: Object) -> Rect2:
	var boss_pos: Vector2 = _get_owner_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	var boss_w: float = maxf(1.0, float(_get_owner_value(owner, "boss_paddle_width", 100.0)))
	var boss_h: float = maxf(1.0, float(_get_owner_value(owner, "boss_hitbox_height", 40.0)))
	return Rect2(boss_pos, Vector2(boss_w, boss_h))


func _get_wall_y(owner: Object) -> float:
	return clampf(float(_get_owner_value(owner, "boss_wall_y", WALL_Y)), 0.0, FIELD_HEIGHT * 0.35)


func _draw_projectile(canvas: CanvasItem, pos: Vector2, shake_offset: Vector2) -> void:
	for i in range(_trail.size()):
		var trail_pos: Vector2 = _trail[i] + shake_offset
		var ratio: float = float(i + 1) / float(maxi(1, _trail.size()))
		canvas.draw_circle(trail_pos, lerpf(2.0, 5.0, ratio), Color(0.72, 0.48, 1.0, 0.10 + 0.26 * ratio))
		if i > 0:
			var prev_pos: Vector2 = _trail[i - 1] + shake_offset
			canvas.draw_line(prev_pos, trail_pos, Color(0.96, 0.82, 1.0, 0.34 * ratio), maxf(1.0, 2.6 * ratio), true)

	var dir: Vector2 = _projectile_vel.normalized()
	if dir.length_squared() <= 0.001:
		dir = Vector2(0.0, -1.0)
	var side: Vector2 = dir.orthogonal()
	var core_points := PackedVector2Array([
		pos + dir * 18.0 + side * 2.0,
		pos + side * 11.0,
		pos - dir * 12.0 + side * 3.0,
		pos - dir * 17.0 - side * 2.0,
		pos - side * 10.0,
	])
	canvas.draw_colored_polygon(core_points, Color(0.56, 0.32, 1.0, 0.84))
	canvas.draw_polyline(PackedVector2Array([core_points[0], core_points[1], core_points[2], core_points[3], core_points[4], core_points[0]]), Color(0.92, 0.78, 1.0, 0.92), 1.5, true)
	canvas.draw_circle(pos, PROJECTILE_RADIUS + 6.0, Color(0.62, 0.36, 1.0, 0.18))


func _draw_orbit_field(canvas: CanvasItem, center: Vector2) -> void:
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var life_ratio: float = clampf(_orbit_timer / ORBIT_DURATION_SECONDS, 0.0, 1.0)
	var appear_lin: float = clampf((ORBIT_DURATION_SECONDS - _orbit_timer) / 0.28, 0.0, 1.0)
	var fade: float = clampf(life_ratio / 0.20, 0.0, 1.0)
	var alpha: float = clampf(appear_lin * fade, 0.0, 1.0)
	if alpha <= 0.01:
		return
	var seed_phase: float = float(_orbit_seed) * 0.017
	var pulse: float = 0.92 + 0.08 * sin(time_seconds * 2.1 + seed_phase)
	var rx: float = ORBIT_HALF_WIDTH * (0.76 + 0.24 * appear_lin)
	var ry: float = ORBIT_HALF_HEIGHT * (0.80 + 0.20 * appear_lin)
	_draw_ellipse_fill(canvas, center, rx, ry, Color(0.18, 0.08, 0.36, alpha * 0.34))
	_draw_ellipse_outline(canvas, center, rx * pulse, ry * pulse, Color(0.72, 0.48, 1.0, alpha * 0.64), 2.0)
	_draw_ellipse_outline(canvas, center, rx * 0.66, ry * 0.55, Color(0.96, 0.82, 1.0, alpha * 0.32), 1.4)
	for i in range(3):
		var phase: float = fmod(time_seconds * (0.28 + i * 0.09) + float(i) * 0.28 + seed_phase, 1.0)
		var arc_center := center + Vector2((phase - 0.5) * rx * 0.42, sin(phase * TAU) * ry * 0.12)
		_draw_crescent_arc(canvas, arc_center, rx * (0.24 + i * 0.05), ry * (0.30 + i * 0.04), phase, Color(0.88, 0.72, 1.0, alpha * (0.38 - i * 0.07)))


func _draw_burst(canvas: CanvasItem, center: Vector2) -> void:
	var ratio: float = clampf(_burst_timer / BURST_FLASH_SECONDS, 0.0, 1.0)
	var expansion: float = 1.0 - ratio
	var rx: float = lerpf(30.0, 112.0, expansion)
	var ry: float = lerpf(12.0, 42.0, expansion)
	_draw_ellipse_outline(canvas, center, rx, ry, Color(0.88, 0.70, 1.0, 0.72 * ratio), 2.2)
	_draw_ellipse_fill(canvas, center, rx * 0.62, ry * 0.62, Color(0.46, 0.18, 1.0, 0.20 * ratio))


func _draw_particles(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for particle in _particles:
		var max_life: float = maxf(0.01, float(particle["max_life"]))
		var life_t: float = clampf(float(particle["life"]) / max_life, 0.0, 1.0)
		var alpha: float = clampf(life_t * 1.35, 0.0, 1.0)
		if alpha <= 0.02:
			continue
		var pos: Vector2 = (particle["pos"] as Vector2) + shake_offset
		var size: float = float(particle["size"]) * (0.76 + 0.24 * life_t)
		var color := Color(0.90, 0.74, 1.0, alpha * 0.78) if int(particle["kind"]) == 0 else Color(0.68, 0.46, 1.0, alpha * 0.48)
		canvas.draw_circle(pos, size, color)


func _draw_ellipse_fill(canvas: CanvasItem, center: Vector2, rx: float, ry: float, color: Color) -> void:
	if rx <= 0.5 or ry <= 0.5 or color.a <= 0.0:
		return
	var points := PackedVector2Array()
	var segments := 48
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	canvas.draw_colored_polygon(points, color)


func _draw_ellipse_outline(canvas: CanvasItem, center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	if rx <= 0.5 or ry <= 0.5 or color.a <= 0.0:
		return
	var points := PackedVector2Array()
	var segments := 64
	for i in range(segments + 1):
		var angle: float = TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	canvas.draw_polyline(points, color, maxf(1.0, width), true)


func _draw_crescent_arc(canvas: CanvasItem, center: Vector2, rx: float, ry: float, phase: float, color: Color) -> void:
	if rx <= 0.5 or ry <= 0.5 or color.a <= 0.0:
		return
	var points := PackedVector2Array()
	var start_angle: float = -PI * 0.78 + phase * TAU
	var end_angle: float = start_angle + PI * 1.24
	var segments := 20
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var angle: float = lerpf(start_angle, end_angle, t)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	canvas.draw_polyline(points, color, 1.8, true)


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner != null and owner.get(key) != null:
		return owner.get(key)
	return fallback


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, key, fallback)
	return value if value is Vector2 else fallback


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry != null and registry.has_method("get_instance"):
		return registry.get_instance(key)
	return null
