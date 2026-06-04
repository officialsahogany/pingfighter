extends RefCounted

const HydroPuddleTextureCache := preload("res://scripts/effects/hydro_puddle_texture_cache.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PROJECTILE_SPEED := 560.0
const PROJECTILE_RADIUS := 8.0
const WALL_Y := 12.0
const PUDDLE_DROP_Y := 62.0
const PUDDLE_HALF_WIDTH := 134.4
const PUDDLE_HALF_HEIGHT := 33.6
const PUDDLE_DURATION_SECONDS := 5.0
const SLOW_MULTIPLIER := 0.65
const SLOW_REFRESH_FRAMES := 4.0
const SPLASH_FLASH_SECONDS := 0.48
const TRAIL_MAX_POINTS := 10
const SPLASH_PARTICLES := 20
const PARTICLE_GRAVITY := 360.0
const AMBIENT_INTERVAL := 0.14
const AMBIENT_BURST := 2
const PARTICLE_MAX := 64
const STATUS_SOURCE := "maribo_hydro_sphere_puddle"

var _projectile_active := false
var _projectile_pos := Vector2.ZERO
var _projectile_vel := Vector2.ZERO
var _trail: Array[Vector2] = []
var _puddle_pos := Vector2.ZERO
var _puddle_timer := 0.0
var _splash_timer := 0.0
var _puddle_seed := 0
var _particles: Array = []
var _ambient_timer := 0.0
var _textures_prewarmed := false


func reset() -> void:
	_projectile_active = false
	_projectile_pos = Vector2.ZERO
	_projectile_vel = Vector2.ZERO
	_trail.clear()
	_puddle_pos = Vector2.ZERO
	_puddle_timer = 0.0
	_splash_timer = 0.0
	_puddle_seed = 0
	_particles.clear()
	_ambient_timer = 0.0


func prewarm() -> void:
	if _textures_prewarmed:
		return
	HydroPuddleTextureCache.prewarm()
	_textures_prewarmed = true


func update(delta: float, owner: Object, registry: Object = null) -> void:
	var safe_delta: float = maxf(0.0, delta)
	_splash_timer = maxf(0.0, _splash_timer - safe_delta)
	var puddle_delta: float = safe_delta
	if _projectile_active:
		_trail.append(_projectile_pos)
		while _trail.size() > TRAIL_MAX_POINTS:
			_trail.remove_at(0)
		var wall_y: float = _get_wall_y(owner)
		var next_projectile_pos: Vector2 = _projectile_pos + _projectile_vel * safe_delta
		if next_projectile_pos.y <= wall_y:
			var distance_to_wall: float = maxf(0.0, _projectile_pos.y - wall_y)
			var travel_time: float = 0.0
			if absf(_projectile_vel.y) > 0.001:
				travel_time = clampf(distance_to_wall / absf(_projectile_vel.y), 0.0, safe_delta)
			_projectile_pos += _projectile_vel * travel_time
			_projectile_pos.y = wall_y
			_spawn_puddle(owner)
			puddle_delta = maxf(0.0, safe_delta - travel_time)
		else:
			_projectile_pos = next_projectile_pos

	if _puddle_timer > 0.0:
		_puddle_timer = maxf(0.0, _puddle_timer - puddle_delta)
		if _puddle_timer > 0.0:
			_apply_boss_slow(owner, registry)

	if not _particles.is_empty() or _puddle_timer > 0.0:
		_update_particles(safe_delta)


func launch(origin: Vector2) -> void:
	prewarm()
	_projectile_active = true
	_projectile_pos = origin
	_projectile_vel = Vector2(0.0, -PROJECTILE_SPEED)
	_trail.clear()
	_trail.append(origin)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	if _puddle_timer > 0.0:
		_draw_puddle(canvas, _puddle_pos + shake_offset)
	if not _particles.is_empty():
		_draw_particles(canvas, shake_offset)
	if _splash_timer > 0.0:
		_draw_splash(canvas, _puddle_pos - Vector2(0.0, PUDDLE_DROP_Y) + shake_offset)
	if _projectile_active:
		_draw_projectile(canvas, _projectile_pos + shake_offset, shake_offset)


func has_visible_effects() -> bool:
	return _projectile_active or _puddle_timer > 0.0 or _splash_timer > 0.0 or not _particles.is_empty()


func is_projectile_active() -> bool:
	return _projectile_active


func is_puddle_active() -> bool:
	return _puddle_timer > 0.0


func get_particle_count_for_tests() -> int:
	return _particles.size()


func get_snapshot() -> Dictionary:
	return {
		"hydro_sphere_projectile_active": _projectile_active,
		"hydro_sphere_projectile_pos": _projectile_pos,
		"hydro_sphere_puddle_active": _puddle_timer > 0.0,
		"hydro_sphere_puddle_pos": _puddle_pos,
		"hydro_sphere_puddle_timer": _puddle_timer,
		"hydro_sphere_puddle_half_width": PUDDLE_HALF_WIDTH,
		"hydro_sphere_puddle_half_height": PUDDLE_HALF_HEIGHT,
		"hydro_sphere_slow_multiplier": SLOW_MULTIPLIER,
	}


func _spawn_puddle(owner: Object) -> void:
	var wall_y: float = _get_wall_y(owner)
	var impact_pos := Vector2(
		clampf(_projectile_pos.x, PROJECTILE_RADIUS, FIELD_WIDTH - PROJECTILE_RADIUS),
		wall_y
	)
	_projectile_active = false
	_projectile_vel = Vector2.ZERO
	_trail.clear()
	_puddle_pos = Vector2(
		impact_pos.x,
		clampf(impact_pos.y + PUDDLE_DROP_Y, PROJECTILE_RADIUS, FIELD_HEIGHT - PROJECTILE_RADIUS)
	)
	_puddle_timer = PUDDLE_DURATION_SECONDS
	_splash_timer = SPLASH_FLASH_SECONDS
	_puddle_seed = int(absf(round(impact_pos.x * 17.0 + impact_pos.y * 31.0))) % 4096
	_ambient_timer = 0.0
	_spawn_splash_burst(impact_pos)


func _spawn_splash_burst(origin: Vector2) -> void:
	for i in range(SPLASH_PARTICLES):
		var angle: float = -PI * 0.5 + (randf() - 0.5) * PI * 1.05
		var speed: float = randf_range(150.0, 360.0)
		_add_particle(
			origin + Vector2(randf_range(-10.0, 10.0), randf_range(-4.0, 4.0)),
			Vector2(cos(angle), sin(angle)) * speed,
			randf_range(0.34, 0.62),
			randf_range(3.0, 7.0),
			0
		)


func _add_particle(pos: Vector2, vel: Vector2, life: float, size: float, kind: int) -> void:
	if _particles.size() >= PARTICLE_MAX:
		return
	_particles.append({
		"pos": pos,
		"vel": vel,
		"life": life,
		"max_life": maxf(0.01, life),
		"size": size,
		"kind": kind,
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
		if int(particle["kind"]) == 0:
			vel.y += PARTICLE_GRAVITY * delta
		else:
			vel.y -= 26.0 * delta
			vel *= 0.92
		particle["vel"] = vel
		particle["pos"] = (particle["pos"] as Vector2) + vel * delta
		particle["life"] = life
		kept.append(particle)
	_particles = kept

	if _puddle_timer > 0.0:
		_ambient_timer -= delta
		if _ambient_timer <= 0.0:
			_ambient_timer = AMBIENT_INTERVAL
			for i in range(AMBIENT_BURST):
				var ux: float = randf_range(-0.92, 0.92)
				var uy: float = randf_range(-0.55, 0.55)
				var spawn := _puddle_pos + Vector2(ux * PUDDLE_HALF_WIDTH, uy * PUDDLE_HALF_HEIGHT)
				_add_particle(spawn, Vector2(randf_range(-12.0, 12.0), randf_range(-28.0, -10.0)), randf_range(0.5, 0.95), randf_range(2.0, 4.2), 1)


func _apply_boss_slow(owner: Object, registry: Object) -> void:
	if registry == null or not _is_boss_touching_puddle(owner):
		return
	var status_state: Object = _get_registry_instance(registry, "status_effect_state")
	if status_state == null or not status_state.has_method("apply_status"):
		return
	status_state.apply_status(
		"boss",
		"slow",
		SLOW_REFRESH_FRAMES,
		{
			"multiplier": SLOW_MULTIPLIER,
			"cleansable": true,
			"visual": "maribo_hydro_sphere",
		},
		STATUS_SOURCE
	)


func _is_boss_touching_puddle(owner: Object) -> bool:
	if _puddle_timer <= 0.0:
		return false
	var boss_rect: Rect2 = _get_boss_rect(owner)
	var closest := Vector2(
		clampf(_puddle_pos.x, boss_rect.position.x, boss_rect.end.x),
		clampf(_puddle_pos.y, boss_rect.position.y, boss_rect.end.y)
	)
	var dx: float = closest.x - _puddle_pos.x
	var dy: float = closest.y - _puddle_pos.y
	var rx: float = maxf(1.0, PUDDLE_HALF_WIDTH)
	var ry: float = maxf(1.0, PUDDLE_HALF_HEIGHT)
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
		canvas.draw_circle(trail_pos, lerpf(2.0, 5.5, ratio), Color(0.26, 0.98, 1.0, 0.10 + 0.24 * ratio))
		if i > 0:
			var prev_pos: Vector2 = _trail[i - 1] + shake_offset
			canvas.draw_line(prev_pos, trail_pos, Color(0.60, 1.0, 1.0, 0.30 * ratio), maxf(1.0, 3.0 * ratio), true)

	var dir: Vector2 = _projectile_vel.normalized()
	if dir.length_squared() <= 0.001:
		dir = Vector2(0.0, -1.0)
	var side: Vector2 = dir.orthogonal()
	var spear_points := PackedVector2Array([
		pos + dir * 24.0,
		pos + side * 8.0,
		pos - dir * 18.0,
		pos - side * 8.0,
	])
	canvas.draw_colored_polygon(spear_points, Color(0.44, 1.0, 1.0, 0.86))
	canvas.draw_polyline(PackedVector2Array([spear_points[0], spear_points[1], spear_points[2], spear_points[3], spear_points[0]]), Color(0.90, 1.0, 1.0, 0.92), 1.6, true)
	canvas.draw_circle(pos, PROJECTILE_RADIUS + 7.0, Color(0.14, 0.88, 1.0, 0.18))


func _draw_puddle(canvas: CanvasItem, center: Vector2) -> void:
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var life_ratio: float = clampf(_puddle_timer / PUDDLE_DURATION_SECONDS, 0.0, 1.0)
	var appear_lin: float = clampf((PUDDLE_DURATION_SECONDS - _puddle_timer) / 0.34, 0.0, 1.0)
	var appear: float = _ease_out_back(appear_lin)
	var fade: float = clampf(life_ratio / 0.18, 0.0, 1.0)
	var alpha: float = clampf(minf(appear_lin * 1.6, 1.0) * fade, 0.0, 1.0)
	if alpha <= 0.01:
		return
	var grow: float = 0.72 + 0.28 * appear
	var rx: float = PUDDLE_HALF_WIDTH * grow
	var ry: float = PUDDLE_HALF_HEIGHT * grow
	var pulse: float = 0.92 + 0.08 * sin(time_seconds * 2.3)
	var surface: Texture2D = HydroPuddleTextureCache.get_surface_texture()
	_blit_hydro(canvas, surface, center, rx, ry, Color(0.16, 0.74, 0.95, alpha * 0.46))
	_blit_hydro_caustic(canvas, center, rx * 0.94, ry * 0.94, Color(0.55, 1.0, 1.0, alpha * 0.42), time_seconds)
	_blit_hydro_caustic(canvas, center, rx * 0.76, ry * 0.76, Color(0.85, 1.0, 1.0, alpha * 0.30), -time_seconds * 0.8 + 2.0)
	_blit_hydro(canvas, surface, center, rx * 0.5, ry * 0.5, Color(0.80, 1.0, 1.0, alpha * 0.30 * pulse))
	_blit_hydro(canvas, HydroPuddleTextureCache.get_foam_ring_texture(), center, rx * 1.02, ry * 1.04, Color(0.82, 1.0, 1.0, alpha * 0.85 * pulse))


func _draw_splash(canvas: CanvasItem, center: Vector2) -> void:
	var ratio: float = clampf(_splash_timer / SPLASH_FLASH_SECONDS, 0.0, 1.0)
	var expansion: float = 1.0 - ratio
	var radius: float = lerpf(26.0, 104.0, expansion)
	_blit_hydro(canvas, HydroPuddleTextureCache.get_surface_texture(), center, radius, radius, Color(0.52, 1.0, 1.0, 0.34 * ratio))
	_blit_hydro(canvas, HydroPuddleTextureCache.get_foam_ring_texture(), center, radius * 0.92, radius * 0.92, Color(0.92, 1.0, 1.0, 0.70 * ratio))


func _draw_particles(canvas: CanvasItem, shake_offset: Vector2) -> void:
	var tex: Texture2D = HydroPuddleTextureCache.get_droplet_texture()
	if tex == null:
		return
	for particle in _particles:
		var max_life: float = maxf(0.01, float(particle["max_life"]))
		var life_t: float = clampf(float(particle["life"]) / max_life, 0.0, 1.0)
		var is_splash: bool = int(particle["kind"]) == 0
		var alpha: float = clampf(life_t * 1.4, 0.0, 1.0) if is_splash else life_t
		if alpha <= 0.02:
			continue
		var size: float = float(particle["size"]) * (0.7 + 0.3 * life_t)
		var pos: Vector2 = (particle["pos"] as Vector2) + shake_offset
		var color: Color = Color(0.74, 1.0, 1.0, alpha * 0.92) if is_splash else Color(0.56, 0.96, 1.0, alpha * 0.58)
		canvas.draw_texture_rect(tex, Rect2(pos - Vector2(size, size), Vector2(size * 2.0, size * 2.0)), false, color)


func _blit_hydro(canvas: CanvasItem, tex: Texture2D, center: Vector2, rx: float, ry: float, color: Color) -> void:
	if tex == null or rx <= 0.5 or ry <= 0.5 or color.a <= 0.0:
		return
	canvas.draw_texture_rect(tex, Rect2(center - Vector2(rx, ry), Vector2(rx * 2.0, ry * 2.0)), false, color)


func _blit_hydro_caustic(canvas: CanvasItem, center: Vector2, rx: float, ry: float, color: Color, time_seconds: float) -> void:
	if rx <= 0.5 or ry <= 0.5 or color.a <= 0.0:
		return
	var tex: Texture2D = HydroPuddleTextureCache.get_caustic_texture()
	if tex == null:
		return
	var seed_phase: float = float(_puddle_seed) * 0.013
	var breathe: float = 1.0 + 0.07 * sin(time_seconds * 1.4 + seed_phase)
	var width: float = rx * breathe
	var height: float = ry * breathe
	canvas.draw_texture_rect(tex, Rect2(center - Vector2(width, height), Vector2(width * 2.0, height * 2.0)), false, color)


func _ease_out_back(x: float) -> float:
	var clamped: float = clampf(x, 0.0, 1.0)
	var s := 1.70158
	var u: float = clamped - 1.0
	return 1.0 + (s + 1.0) * pow(u, 3.0) + s * pow(u, 2.0)


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
