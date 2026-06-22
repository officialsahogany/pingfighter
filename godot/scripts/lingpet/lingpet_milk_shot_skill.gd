extends RefCounted

const CommandoFirearmHitGeometry := preload("res://scripts/characters/commando_firearm_hit_geometry.gd")
const LingpetMilkShotPayloadFactory := preload("res://scripts/lingpet/lingpet_milk_shot_payload_factory.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PROJECTILE_SPEED := 1150.0
const MEGA_PROJECTILE_SPEED := 1150.0
const PROJECTILE_RADIUS := 5.5
const PROJECTILE_DECEL_START_DISTANCE := 175.0
const PROJECTILE_DECEL_MIN_FACTOR := 0.42
const PROJECTILE_MAX_AGE_SECONDS := 1.8
const NORMAL_FIRE_INTERVAL := 0.12
const NORMAL_MUZZLE_OFFSET_X := 18.0
const NORMAL_MUZZLE_OFFSET_Y := -10.0
const MEGA_FAN_HALF_ANGLE_DEGREES := 40.0
const PARTICLE_MAX := 128
const STATUS_SOURCE := "milkring_milk_shot"
const KNOCKBACK_FRAMES := 18.0
const KNOCKBACK_DECAY_PER_FRAME := 0.85
const KNOCKBACK_VELOCITY_SCALE := 0.0
const FRAME_VELOCITY_SCALE := 1.0 / 60.0
const STUN_SECONDS_BY_LEVEL := [0.3, 0.4, 0.5, 0.6, 0.7]
const KNOCKBACK_POWER_BY_LEVEL := [8.0, 10.0, 12.0, 14.0, 16.0]
const PROJECTILE_COUNT_BY_LEVEL := [8, 8, 10, 10, 12]  # total milk shots = volley count [4,4,5,5,6] x 2 (left/right pair per volley)
const FIRE_DURATION_SECONDS_BY_LEVEL := [0.8, 0.92, 1.05, 1.18, 1.3]
const MEGA_CHANCE_BY_LEVEL := [0.0, 0.0, 0.30, 0.30, 0.30]
const MEGA_PROJECTILE_COUNT_BY_LEVEL := [0, 0, 30, 40, 50]
const MEGA_DURATION_SECONDS_BY_LEVEL := [0.0, 0.0, 1.0, 1.25, 1.5]
const MODE_NORMAL := "normal"
const MODE_MEGA := "mega"

var _active := false
var _mode := MODE_NORMAL
var _origin := Vector2.ZERO
var _active_skill_level := 1
var _elapsed := 0.0
var _fire_duration := 0.8
var _fire_timer := 0.0
var _fire_interval := 0.2
var _projectile_limit := 4
var _spawn_cursor := 0
var _launch_shot_count := 0
var _launch_hit_count := 0
var _shot_count := 0
var _hit_count := 0
var _stun_seconds := 0.5
var _knockback_power := 8.0
var _mega_chance := 0.0
var _last_mega_roll := 1.0
var _last_stun_frames := 0.0
var _last_knockback_velocity := 0.0
var _projectiles: Array[Dictionary] = []
var _hit_particles: Array[Dictionary] = []
var _muzzle_splashes: Array[Dictionary] = []
var _registry: Object = null


func reset() -> void:
	_active = false
	_mode = MODE_NORMAL
	_origin = Vector2.ZERO
	_elapsed = 0.0
	_fire_duration = 0.8
	_fire_timer = 0.0
	_fire_interval = 0.2
	_projectile_limit = 4
	_spawn_cursor = 0
	_launch_shot_count = 0
	_launch_hit_count = 0
	_projectiles.clear()
	_hit_particles.clear()
	_muzzle_splashes.clear()
	_registry = null


func cancel(_owner: Object = null, _registry_arg: Object = null) -> void:
	reset()


func prewarm() -> void:
	pass


func launch(origin: Vector2, owner: Object = null, launch_context: Dictionary = {}) -> bool:
	reset()
	_registry = launch_context.get("registry", null) as Object
	_origin = _get_launch_origin(origin, launch_context)
	_active_skill_level = _get_active_skill_level(launch_context)
	_sync_level_values(launch_context)
	_mode = _pick_launch_mode(launch_context)
	_configure_projectile_sequence(launch_context)
	_active = true
	_emit_next_fire_event(owner, _registry)
	return true


func update(delta: float, owner: Object, registry: Object = null, _launch_context: Dictionary = {}) -> void:
	if registry != null:
		_registry = registry
	var safe_delta := maxf(0.0, delta)
	if _active:
		_elapsed += safe_delta
		_fire_timer += safe_delta
		while _fire_timer >= _fire_interval and _spawn_cursor < _projectile_limit:
			_fire_timer -= _fire_interval
			_emit_next_fire_event(owner, _registry)
		if _elapsed >= _fire_duration and _spawn_cursor >= _projectile_limit:
			_active = false
	_update_projectiles(safe_delta, owner, _registry)
	_update_particles(safe_delta)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	_draw_muzzle_splashes(canvas, shake_offset)
	_draw_projectiles(canvas, shake_offset)
	_draw_hit_particles(canvas, shake_offset)


func has_visible_effects() -> bool:
	return _active or not _projectiles.is_empty() or not _hit_particles.is_empty() or not _muzzle_splashes.is_empty()


func is_active() -> bool:
	return _active or not _projectiles.is_empty()


func get_projectile_count_for_tests() -> int:
	return _projectiles.size()


func get_shot_count_for_tests() -> int:
	return _shot_count


func get_hit_count_for_tests() -> int:
	return _hit_count


func get_snapshot() -> Dictionary:
	return {
		"milk_shot_active": _active,
		"milk_shot_mode": _mode,
		"milk_shot_active_skill_level": _active_skill_level,
		"milk_shot_origin": _origin,
		"milk_shot_elapsed": _elapsed,
		"milk_shot_fire_duration": _fire_duration,
		"milk_shot_projectile_limit": _projectile_limit,
		"milk_shot_spawn_cursor": _spawn_cursor,
		"milk_shot_projectile_count": _projectiles.size(),
		"milk_shot_launch_shot_count": _launch_shot_count,
		"milk_shot_launch_hit_count": _launch_hit_count,
		"milk_shot_shot_count": _shot_count,
		"milk_shot_hit_count": _hit_count,
		"milk_shot_stun_seconds": _stun_seconds,
		"milk_shot_knockback_power": _knockback_power,
		"milk_shot_mega_chance": _mega_chance,
		"milk_shot_last_mega_roll": _last_mega_roll,
		"milk_shot_last_stun_frames": _last_stun_frames,
		"milk_shot_last_knockback_velocity": _last_knockback_velocity,
		"milk_shot_particle_count": _hit_particles.size() + _muzzle_splashes.size(),
	}


func _sync_level_values(launch_context: Dictionary) -> void:
	_stun_seconds = _get_context_float(
		launch_context,
		"stun_duration_seconds",
		_get_level_float(STUN_SECONDS_BY_LEVEL, _active_skill_level, 0.5)
	)
	_knockback_power = _get_context_float(
		launch_context,
		"knockback_power",
		_get_level_float(KNOCKBACK_POWER_BY_LEVEL, _active_skill_level, 8.0)
	)
	_mega_chance = clampf(_get_context_float(
		launch_context,
		"mega_chance",
		_get_level_float(MEGA_CHANCE_BY_LEVEL, _active_skill_level, 0.0)
	), 0.0, 1.0)


func _pick_launch_mode(launch_context: Dictionary) -> String:
	_last_mega_roll = _consume_mega_roll(launch_context)
	if _mega_chance > 0.0 and _last_mega_roll < _mega_chance:
		return MODE_MEGA
	return MODE_NORMAL


func _configure_projectile_sequence(launch_context: Dictionary) -> void:
	if _mode == MODE_MEGA:
		_projectile_limit = maxi(1, int(round(_get_context_float(
			launch_context,
			"mega_projectile_count",
			_get_level_float(MEGA_PROJECTILE_COUNT_BY_LEVEL, _active_skill_level, 0.0)
		))))
		_fire_duration = maxf(0.05, _get_context_float(
			launch_context,
			"mega_duration_seconds",
			_get_level_float(MEGA_DURATION_SECONDS_BY_LEVEL, _active_skill_level, 1.0)
		))
		_fire_interval = _fire_duration / float(maxi(1, _projectile_limit))
		return
	_projectile_limit = maxi(1, int(round(_get_context_float(
		launch_context,
		"projectile_count",
		_get_level_float(PROJECTILE_COUNT_BY_LEVEL, _active_skill_level, 4.0)
	))))
	_fire_duration = maxf(0.05, _get_context_float(
		launch_context,
		"fire_duration_seconds",
		_get_level_float(FIRE_DURATION_SECONDS_BY_LEVEL, _active_skill_level, 0.8)
	))
	_fire_interval = NORMAL_FIRE_INTERVAL


func _emit_next_fire_event(owner: Object, registry: Object) -> void:
	if _spawn_cursor >= _projectile_limit:
		return
	if _mode == MODE_MEGA:
		_emit_mega_projectile(owner, registry)
		return
	_emit_normal_volley(owner, registry)


func _emit_normal_volley(owner: Object, registry: Object) -> void:
	var muzzles := [
		_origin + Vector2(-NORMAL_MUZZLE_OFFSET_X, NORMAL_MUZZLE_OFFSET_Y),
		_origin + Vector2(NORMAL_MUZZLE_OFFSET_X, NORMAL_MUZZLE_OFFSET_Y),
	]
	var fired := false
	for muzzle in muzzles:
		if _spawn_cursor >= _projectile_limit:
			break
		var muzzle_pos: Vector2 = _clamp_to_field(muzzle)
		var target := _get_boss_center(owner)
		var angle := atan2(target.y - muzzle_pos.y, target.x - muzzle_pos.x)
		var direction := Vector2(cos(angle), sin(angle))
		_add_projectile(muzzle_pos, direction, PROJECTILE_SPEED, angle)
		_spawn_muzzle_splash(muzzle_pos, direction)
		fired = true
	if fired:
		_play_fire_feedback(registry)


func _emit_mega_projectile(owner: Object, registry: Object) -> void:
	var target := _get_boss_center(owner)
	var base_angle := atan2(target.y - _origin.y, target.x - _origin.x)
	var half_angle := deg_to_rad(MEGA_FAN_HALF_ANGLE_DEGREES)
	var ratio := 0.5
	if _projectile_limit > 1:
		ratio = float(_spawn_cursor) / float(_projectile_limit - 1)
	var angle := base_angle - half_angle + half_angle * 2.0 * ratio
	var direction := Vector2(cos(angle), sin(angle))
	var side_offset := Vector2(-direction.y, direction.x) * sin(ratio * TAU) * 10.0
	var muzzle_pos := _clamp_to_field(_origin + side_offset)
	_add_projectile(muzzle_pos, direction, MEGA_PROJECTILE_SPEED, angle)
	if (_spawn_cursor % 3) == 1:
		_spawn_muzzle_splash(muzzle_pos, direction)
	if (_spawn_cursor % 6) == 1:
		_play_fire_feedback(registry)


func _add_projectile(muzzle_pos: Vector2, direction: Vector2, speed: float, angle: float) -> void:
	_projectiles.append(LingpetMilkShotPayloadFactory.build_projectile(
		muzzle_pos,
		direction,
		speed,
		angle,
		_spawn_cursor,
		_mode
	))
	while _projectiles.size() > 80:
		_projectiles.remove_at(0)
	_spawn_cursor += 1
	_launch_shot_count += 1
	_shot_count += 1


func _update_projectiles(delta: float, owner: Object, registry: Object) -> void:
	if _projectiles.is_empty():
		return
	var boss_rect := _get_boss_rect(owner)
	var boss_center := boss_rect.get_center()
	var next_projectiles: Array[Dictionary] = []
	for projectile in _projectiles:
		var pos: Vector2 = _as_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
		var vel: Vector2 = _as_vector2(projectile.get("vel", Vector2.ZERO), Vector2.ZERO)
		var age := float(projectile.get("age", 0.0)) + delta
		var speed_factor := 1.0
		var dist_to_boss := pos.distance_to(boss_center)
		if dist_to_boss < PROJECTILE_DECEL_START_DISTANCE:
			speed_factor = lerpf(PROJECTILE_DECEL_MIN_FACTOR, 1.0, clampf(dist_to_boss / PROJECTILE_DECEL_START_DISTANCE, 0.0, 1.0))
		pos += vel * delta * speed_factor
		if age > PROJECTILE_MAX_AGE_SECONDS:
			continue
		if _is_out_of_bounds(pos):
			continue
		if _projectile_hits_boss(pos, boss_rect):
			var hit_angle := float(projectile.get("angle", atan2(vel.y, vel.x)))
			_apply_boss_hit_status(owner, registry, pos, vel, boss_rect)
			_spawn_hit_particles(pos, hit_angle)
			_play_hit_feedback(registry)
			_launch_hit_count += 1
			_hit_count += 1
			continue
		projectile["pos"] = pos
		projectile["age"] = age
		next_projectiles.append(projectile)
	_projectiles = next_projectiles


func _update_particles(delta: float) -> void:
	if not _hit_particles.is_empty():
		var next_hit: Array[Dictionary] = []
		for particle in _hit_particles:
			var age := float(particle.get("age", 0.0)) + delta
			var life := maxf(0.001, float(particle.get("life", 0.25)))
			if age >= life:
				continue
			var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO)
			var vel: Vector2 = _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
			pos += vel * delta
			vel.y += 120.0 * delta
			vel *= 0.96
			particle["age"] = age
			particle["pos"] = pos
			particle["vel"] = vel
			next_hit.append(particle)
		_hit_particles = next_hit
	if not _muzzle_splashes.is_empty():
		var next_splash: Array[Dictionary] = []
		for splash in _muzzle_splashes:
			var age := float(splash.get("age", 0.0)) + delta
			var life := maxf(0.001, float(splash.get("life", 0.2)))
			if age >= life:
				continue
			var pos: Vector2 = _as_vector2(splash.get("pos", Vector2.ZERO), Vector2.ZERO)
			var vel: Vector2 = _as_vector2(splash.get("vel", Vector2.ZERO), Vector2.ZERO)
			pos += vel * delta
			vel *= 0.92
			splash["age"] = age
			splash["pos"] = pos
			splash["vel"] = vel
			next_splash.append(splash)
		_muzzle_splashes = next_splash


func _projectile_hits_boss(pos: Vector2, boss_rect: Rect2) -> bool:
	if boss_rect.size.x <= 0.0 or boss_rect.size.y <= 0.0:
		return false
	var boss_center := boss_rect.get_center()
	var hit_radius := boss_rect.size.x * 0.5 + PROJECTILE_RADIUS + 10.0
	return pos.distance_squared_to(boss_center) <= hit_radius * hit_radius


func _apply_boss_hit_status(owner: Object, registry: Object, hit_pos: Vector2, velocity: Vector2, boss_rect: Rect2) -> void:
	var profile := {
		"knockback_power": _knockback_power,
		"knockback_velocity_scale": KNOCKBACK_VELOCITY_SCALE,
	}
	var frame_velocity := velocity * FRAME_VELOCITY_SCALE
	var knockback_velocity := CommandoFirearmHitGeometry.get_hit_knockback_velocity(
		profile,
		hit_pos,
		frame_velocity,
		boss_rect.get_center()
	)
	_last_knockback_velocity = knockback_velocity
	_last_stun_frames = maxf(1.0, _stun_seconds * 60.0)
	var status_state := _get_registry_instance(registry, "status_effect_state")
	if status_state != null and status_state.has_method("apply_status"):
		status_state.apply_status(
			"boss",
			"stun",
			_last_stun_frames,
			LingpetMilkShotPayloadFactory.build_boss_stun_status_data(
				knockback_velocity,
				KNOCKBACK_FRAMES,
				KNOCKBACK_DECAY_PER_FRAME,
				STATUS_SOURCE
			),
			STATUS_SOURCE
		)
		return
	var ai_state := _get_registry_instance(registry, "boss_ai_state")
	if ai_state != null and ai_state.has_method("start_paddle_hit_knockback"):
		ai_state.start_paddle_hit_knockback(knockback_velocity, KNOCKBACK_FRAMES, KNOCKBACK_DECAY_PER_FRAME, true)
	elif owner != null:
		owner.set("boss_vel", knockback_velocity)


func _spawn_hit_particles(pos: Vector2, hit_angle: float) -> void:
	for i in range(10):
		_hit_particles.append(LingpetMilkShotPayloadFactory.build_hit_particle(pos, hit_angle, i))
	while _hit_particles.size() > PARTICLE_MAX:
		_hit_particles.remove_at(0)


func _spawn_muzzle_splash(pos: Vector2, direction: Vector2) -> void:
	_muzzle_splashes.append(LingpetMilkShotPayloadFactory.build_muzzle_splash(pos, direction))
	while _muzzle_splashes.size() > 48:
		_muzzle_splashes.remove_at(0)


func _draw_projectiles(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for projectile in _projectiles:
		var pos: Vector2 = _as_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var vel: Vector2 = _as_vector2(projectile.get("vel", Vector2.ZERO), Vector2.ZERO)
		var direction := vel.normalized() if vel.length_squared() > 0.001 else Vector2(cos(float(projectile.get("angle", 0.0))), sin(float(projectile.get("angle", 0.0))))
		var is_mega := str(projectile.get("mode", MODE_NORMAL)) == MODE_MEGA
		var trail_length := 22.0 if is_mega else 18.0
		var width := 3.6 if is_mega else 4.4
		canvas.draw_line(pos - direction * trail_length, pos, Color(0.72, 0.94, 1.0, 0.30), width + 2.0, true)
		canvas.draw_line(pos - direction * trail_length * 0.65, pos + direction * 4.0, Color(1.0, 1.0, 0.96, 0.92), width, true)
		canvas.draw_circle(pos, PROJECTILE_RADIUS, Color(0.92, 0.98, 1.0, 0.96))
		canvas.draw_circle(pos - direction * 2.2, PROJECTILE_RADIUS * 0.45, Color(1.0, 1.0, 1.0, 0.96))


func _draw_hit_particles(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for particle in _hit_particles:
		var age := float(particle.get("age", 0.0))
		var life := maxf(0.001, float(particle.get("life", 0.25)))
		var ratio := clampf(1.0 - age / life, 0.0, 1.0)
		var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size := float(particle.get("size", 3.0)) * (0.45 + ratio * 0.55)
		var color := Color(1.0, 1.0, 1.0, 0.82 * ratio) if bool(particle.get("foam", false)) else Color(0.76, 0.92, 1.0, 0.70 * ratio)
		canvas.draw_circle(pos, size, color)


func _draw_muzzle_splashes(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for splash in _muzzle_splashes:
		var age := float(splash.get("age", 0.0))
		var life := maxf(0.001, float(splash.get("life", 0.2)))
		var ratio := clampf(1.0 - age / life, 0.0, 1.0)
		var pos: Vector2 = _as_vector2(splash.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		canvas.draw_circle(pos, float(splash.get("size", 4.0)) * (0.5 + ratio * 0.5), Color(0.86, 0.98, 1.0, 0.36 * ratio))


func _play_fire_feedback(registry: Object) -> void:
	var audio := _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_ragnarok_shot"):
		audio.play_ragnarok_shot()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func _play_hit_feedback(registry: Object) -> void:
	var audio := _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_commando_bullet_impact"):
		audio.play_commando_bullet_impact()
	elif audio.has_method("play_paddle_hit"):
		audio.play_paddle_hit()


func _get_launch_origin(origin: Vector2, launch_context: Dictionary) -> Vector2:
	return _clamp_to_field(_as_vector2(launch_context.get("companion_pos", origin), origin))


func _get_boss_rect(owner: Object) -> Rect2:
	var boss_pos := _get_owner_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	var boss_w := maxf(1.0, float(_get_owner_value(owner, "boss_paddle_width", 100.0)))
	var boss_h := maxf(1.0, float(_get_owner_value(owner, "boss_hitbox_height", 40.0)))
	return Rect2(boss_pos, Vector2(boss_w, boss_h))


func _get_boss_center(owner: Object) -> Vector2:
	return _get_boss_rect(owner).get_center()


func _get_active_skill_level(launch_context: Dictionary) -> int:
	return clampi(int(launch_context.get("active_skill_level", launch_context.get("skill_level", 1))), 1, 5)


func _consume_mega_roll(launch_context: Dictionary) -> float:
	if launch_context.has("milk_shot_mega_roll"):
		return clampf(float(launch_context.get("milk_shot_mega_roll", 1.0)), 0.0, 1.0)
	if launch_context.has("mega_roll"):
		return clampf(float(launch_context.get("mega_roll", 1.0)), 0.0, 1.0)
	return randf()


func _get_context_float(source: Dictionary, key: String, fallback: float) -> float:
	if not source.has(key):
		return fallback
	var value := float(source.get(key, fallback))
	return fallback if value < 0.0 else value


func _get_level_float(values: Array, level: int, fallback: float) -> float:
	if values.is_empty():
		return fallback
	var index := clampi(level, 1, values.size()) - 1
	return float(values[index])


func _clamp_to_field(pos: Vector2) -> Vector2:
	return Vector2(clampf(pos.x, 8.0, FIELD_WIDTH - 8.0), clampf(pos.y, 8.0, FIELD_HEIGHT - 8.0))


func _is_out_of_bounds(pos: Vector2) -> bool:
	return pos.x < -40.0 or pos.x > FIELD_WIDTH + 40.0 or pos.y < -40.0 or pos.y > FIELD_HEIGHT + 40.0


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	return fallback if value == null else value


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, key, fallback)
	if value is Vector2:
		return value
	return fallback


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
