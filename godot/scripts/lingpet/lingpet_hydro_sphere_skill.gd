extends RefCounted

const LingpetHydroSphereRenderer := preload("res://scripts/lingpet/lingpet_hydro_sphere_renderer.gd")
const LingpetHydroSpherePayloadFactory := preload("res://scripts/lingpet/lingpet_hydro_sphere_payload_factory.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PROJECTILE_SPEED := 560.0
const PROJECTILE_RADIUS := 8.0
const WALL_Y := 12.0
const PUDDLE_DROP_Y := 62.0
const PUDDLE_HALF_WIDTH := 134.4
const PUDDLE_HALF_WIDTH_BY_LEVEL := [94.08, 114.24, 134.4, 154.56, 174.72]
const PUDDLE_HALF_HEIGHT := 33.6
const PUDDLE_DURATION_SECONDS := 5.0
const SLOW_MULTIPLIER := 0.65
const SLOW_MULTIPLIER_BY_LEVEL := [0.80, 0.80, 0.65, 0.65, 0.45]
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
var _active_skill_level := 1
var _puddle_half_width := PUDDLE_HALF_WIDTH
var _slow_multiplier := SLOW_MULTIPLIER
var _particles: Array = []
var _ambient_timer := 0.0
var _renderer: Object = LingpetHydroSphereRenderer.new()


func reset() -> void:
	_projectile_active = false
	_projectile_pos = Vector2.ZERO
	_projectile_vel = Vector2.ZERO
	_trail.clear()
	_puddle_pos = Vector2.ZERO
	_puddle_timer = 0.0
	_splash_timer = 0.0
	_puddle_seed = 0
	_active_skill_level = 1
	_puddle_half_width = PUDDLE_HALF_WIDTH
	_slow_multiplier = SLOW_MULTIPLIER
	_particles.clear()
	_ambient_timer = 0.0


func prewarm() -> void:
	_renderer.prewarm()


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


func launch(origin: Vector2, launch_context: Dictionary = {}) -> void:
	_active_skill_level = _get_active_skill_level(launch_context)
	_puddle_half_width = _get_level_float(PUDDLE_HALF_WIDTH_BY_LEVEL, _active_skill_level, PUDDLE_HALF_WIDTH)
	_slow_multiplier = _get_level_float(SLOW_MULTIPLIER_BY_LEVEL, _active_skill_level, SLOW_MULTIPLIER)
	prewarm()
	_projectile_active = true
	_projectile_pos = origin
	_projectile_vel = Vector2(0.0, -PROJECTILE_SPEED)
	_trail.clear()
	_trail.append(origin)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	var visual_time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	_renderer.draw_hydro_sphere(
		canvas,
		shake_offset,
		visual_time_seconds,
		_projectile_active,
		_projectile_pos,
		_projectile_vel,
		PROJECTILE_RADIUS,
		_trail,
		_puddle_pos,
		_puddle_timer,
		PUDDLE_DURATION_SECONDS,
		_puddle_seed,
		_puddle_half_width,
		PUDDLE_HALF_HEIGHT,
		PUDDLE_DROP_Y,
		_splash_timer,
		SPLASH_FLASH_SECONDS,
		_particles
	)


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
		"hydro_sphere_active_skill_level": _active_skill_level,
		"hydro_sphere_projectile_active": _projectile_active,
		"hydro_sphere_projectile_pos": _projectile_pos,
		"hydro_sphere_puddle_active": _puddle_timer > 0.0,
		"hydro_sphere_puddle_pos": _puddle_pos,
		"hydro_sphere_puddle_timer": _puddle_timer,
		"hydro_sphere_puddle_half_width": _puddle_half_width,
		"hydro_sphere_puddle_half_height": PUDDLE_HALF_HEIGHT,
		"hydro_sphere_slow_multiplier": _slow_multiplier,
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
	for _i in range(SPLASH_PARTICLES):
		_add_particle(LingpetHydroSpherePayloadFactory.build_splash_particle(origin))


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
			for _i in range(AMBIENT_BURST):
				_add_particle(
					LingpetHydroSpherePayloadFactory.build_ambient_particle(
						_puddle_pos,
						_puddle_half_width,
						PUDDLE_HALF_HEIGHT
					)
				)


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
		LingpetHydroSpherePayloadFactory.build_slow_status_data(_slow_multiplier),
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
	var rx: float = maxf(1.0, _puddle_half_width)
	var ry: float = maxf(1.0, PUDDLE_HALF_HEIGHT)
	return (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) <= 1.0


func _get_boss_rect(owner: Object) -> Rect2:
	var boss_pos: Vector2 = _get_owner_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	var boss_w: float = maxf(1.0, float(_get_owner_value(owner, "boss_paddle_width", 100.0)))
	var boss_h: float = maxf(1.0, float(_get_owner_value(owner, "boss_hitbox_height", 40.0)))
	return Rect2(boss_pos, Vector2(boss_w, boss_h))


func _get_wall_y(owner: Object) -> float:
	return clampf(float(_get_owner_value(owner, "boss_wall_y", WALL_Y)), 0.0, FIELD_HEIGHT * 0.35)


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner != null and owner.get(key) != null:
		return owner.get(key)
	return fallback


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, key, fallback)
	return value if value is Vector2 else fallback


func _get_active_skill_level(launch_context: Dictionary) -> int:
	return clampi(int(launch_context.get("active_skill_level", launch_context.get("skill_level", 1))), 1, PUDDLE_HALF_WIDTH_BY_LEVEL.size())


func _get_level_float(values: Array, active_skill_level: int, fallback: float) -> float:
	if values.is_empty():
		return fallback
	var index := clampi(active_skill_level, 1, values.size()) - 1
	return float(values[index])


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry != null and registry.has_method("get_instance"):
		return registry.get_instance(key)
	return null
