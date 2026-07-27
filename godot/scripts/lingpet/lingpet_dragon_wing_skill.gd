extends RefCounted

const LingpetDragonWingRenderer := preload("res://scripts/lingpet/lingpet_dragon_wing_renderer.gd")
const LingpetDragonWingPayloadFactory := preload("res://scripts/lingpet/lingpet_dragon_wing_payload_factory.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const DURATION_SECONDS := 2.5
# IMPORTANT: ball_vel lives in px/frame units (ball_speed_policy.gd: base 7.65,
# normal game speed cap ~26, sub-step threshold 12). Every force / cap below is
# expressed in that px/frame world. Do NOT reintroduce px/second-scale values
# (forces near 1.0, caps in the hundreds) — that is what made this skill pump
# the ball toward an unguardable ~640 px/frame launch.
const WIND_FORCE := 0.08
const WIND_VARIATION_MIN := 0.7
const WIND_VARIATION_MAX := 1.3
const WIND_REVERSE_CHANCE := 0.15
const WIND_REVERSE_MULTIPLIER := -0.5
const WALL_DAMP_MARGIN := 50.0
const WALL_DAMP_MULTIPLIER := 0.2
const OPPONENT_Y_WIND_DIRECTION := -1.0
const OPPONENT_Y_WIND_FORCE := 0.04
const OPPONENT_Y_WIND_VARIATION_MIN := 0.85
const OPPONENT_Y_WIND_VARIATION_MAX := 1.15
const OPPONENT_Y_PARTICLE_SPEED_MIN := 28.0
const OPPONENT_Y_PARTICLE_SPEED_MAX := 84.0
const PARTICLE_SPAWN_CHANCE_PER_FRAME := 0.40
const PARTICLE_MAX := 72
const SWIRL_CENTER_SIDE_OFFSET := 58.0
const SWIRL_CENTER_UP_OFFSET := 44.0
const SWIRL_CENTER_FOLLOW_SPEED := 7.5
const SWIRL_ORBIT_RADIUS := 62.0
const SWIRL_FIELD_RADIUS := 230.0
# Steering weights only shape the desired vortex DIRECTION (they get normalized),
# so they are unitless. The vortex redirects the ball; it must not pump speed.
const SWIRL_TANGENTIAL_WEIGHT := 1.0
const SWIRL_INWARD_WEIGHT := 0.30
const SWIRL_SIDE_DRIFT_WEIGHT := 0.35
const SWIRL_UPDRAFT_WEIGHT := 0.20
const SWIRL_STEER_RATE := 0.06
const SWIRL_SPEED_EASE := 0.10
const SWIRL_TARGET_SPEED := 9.5
const SWIRL_MAX_BALL_SPEED := 11.0
const SWIRL_MAX_UPWARD_SPEED := 5.5
const SWIRL_RISING_SIDE_THRESHOLD := 1.5
const SWIRL_MIN_SIDE_RATIO_WHEN_RISING := 0.9
const SWIRL_MIN_SIDE_SPEED_CAP := 7.0
const SWIRL_PARTICLE_TANGENTIAL_ACCEL := 185.0
const SWIRL_PARTICLE_INWARD_ACCEL := 72.0
const SWIRL_TRAIL_LIFE_SECONDS := 0.48
const SWIRL_TRAIL_MAX := 26
const DRAGON_SPEED := 330.0
const DRAGON_OFFSCREEN_MARGIN := 70.0
const DRAGON_HALF_WIDTH := 65.0
const DRAGON_HALF_HEIGHT := 35.0
const DRAGON_BOB_PIXELS := 8.0
const DRAGON_BOB_SPEED := 2.5
const DRAGON_TRAIL_LIFE_SECONDS := 0.34
const DRAGON_TRAIL_MAX := 14
const DRAGON_TRAIL_SPAWN_INTERVAL := 0.028
const HIT_COOLDOWN_SECONDS := 0.5
const HIT_FLASH_SECONDS := 0.32
const BALL_SPEED_MIN := 7.65
const BALL_SPEED_MULT_MIN := 1.05
const BALL_SPEED_MULT_MAX := 1.12

var _active := false
var _elapsed := 0.0
var _wind_direction := 1.0
var _wind_particles: Array[Dictionary] = []
var _flying_dragon: Dictionary = {}
var _hit_flash_timer := 0.0
var _last_hit_pos := Vector2.ZERO
var _last_hit_dir := Vector2.ZERO
var _ball_hit_count := 0
var _wind_tick_count := 0
var _swirl_tick_count := 0
var _swirl_center := Vector2.ZERO
var _swirl_spin_sign := 1.0
var _last_ball_pos := Vector2.ZERO
var _ball_swirl_trail: Array[Dictionary] = []
var _registry: Object = null
var _dragon_trail: Array[Dictionary] = []
var _dragon_trail_accum := 0.0
var _renderer: Object = LingpetDragonWingRenderer.new()


func reset() -> void:
	_active = false
	_elapsed = 0.0
	_wind_direction = 1.0
	_wind_particles.clear()
	_flying_dragon.clear()
	_hit_flash_timer = 0.0
	_last_hit_pos = Vector2.ZERO
	_last_hit_dir = Vector2.ZERO
	_swirl_tick_count = 0
	_swirl_center = Vector2.ZERO
	_swirl_spin_sign = 1.0
	_last_ball_pos = Vector2.ZERO
	_ball_swirl_trail.clear()
	_dragon_trail.clear()
	_dragon_trail_accum = 0.0


func prewarm() -> void:
	_renderer.prewarm()


func launch(origin: Vector2, _owner: Object = null, _launch_context: Dictionary = {}) -> void:
	reset()
	_renderer.prepare_launch()
	_active = true
	_elapsed = 0.0
	_wind_direction = 1.0 if randf() < 0.5 else -1.0
	_swirl_spin_sign = -_wind_direction
	_swirl_center = Vector2(clampf(origin.x, 40.0, FIELD_WIDTH - 40.0), clampf(origin.y - SWIRL_CENTER_UP_OFFSET, 70.0, FIELD_HEIGHT - 40.0))
	_spawn_flying_dragon(origin)
	for _i in range(18):
		_add_wind_particle(true)


func update(delta: float, owner: Object, registry: Object = null, _launch_context: Dictionary = {}) -> void:
	_registry = registry
	var safe_delta := maxf(0.0, delta)
	if safe_delta <= 0.0:
		return
	_hit_flash_timer = maxf(0.0, _hit_flash_timer - safe_delta)
	if _active:
		_elapsed += safe_delta
		_apply_wind_to_ball(owner, safe_delta)
		_maybe_spawn_wind_particle(safe_delta)
		if _elapsed >= DURATION_SECONDS:
			_active = false
	_update_flying_dragon(safe_delta, owner)
	_update_wind_particles(safe_delta)
	_update_ball_swirl_trail(safe_delta)
	_update_dragon_trail(safe_delta)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null or not has_visible_effects():
		return
	_renderer.draw_dragon_wing(
		canvas,
		shake_offset,
		_active,
		_elapsed,
		_swirl_envelope(),
		_swirl_center,
		_swirl_spin_sign,
		_last_ball_pos,
		_wind_direction,
		_wind_particles,
		_ball_swirl_trail,
		SWIRL_TRAIL_LIFE_SECONDS,
		_dragon_trail,
		DRAGON_TRAIL_LIFE_SECONDS,
		_flying_dragon,
		_hit_flash_timer,
		HIT_FLASH_SECONDS,
		_last_hit_pos,
		_last_hit_dir
	)


func has_visible_effects() -> bool:
	return _active or _is_flying_dragon_active() or not _wind_particles.is_empty() or not _ball_swirl_trail.is_empty() or not _dragon_trail.is_empty() or _hit_flash_timer > 0.0


func is_active() -> bool:
	return has_visible_effects()


func get_ball_hit_count_for_tests() -> int:
	return _ball_hit_count


func get_wind_tick_count_for_tests() -> int:
	return _wind_tick_count


func get_snapshot() -> Dictionary:
	return {
		"dragon_wing_active": _active,
		"dragon_wing_particle_count": _wind_particles.size(),
		"dragon_wing_dragon_active": _is_flying_dragon_active(),
		"dragon_wing_ball_hit_count": _ball_hit_count,
		"dragon_wing_wind_tick_count": _wind_tick_count,
		"dragon_wing_wind_direction": _wind_direction,
		"dragon_wing_wind_force": _wind_direction * WIND_FORCE if _active else 0.0,
		"dragon_wing_opponent_y_wind_force": OPPONENT_Y_WIND_DIRECTION * OPPONENT_Y_WIND_FORCE if _active else 0.0,
		"dragon_wing_swirl_active": _active and _last_ball_pos != Vector2.ZERO,
		"dragon_wing_swirl_center": _swirl_center,
		"dragon_wing_swirl_tick_count": _swirl_tick_count,
		"dragon_wing_ball_swirl_trail_count": _ball_swirl_trail.size(),
		"dragon_wing_duration": DURATION_SECONDS,
	}


func _spawn_flying_dragon(origin: Vector2) -> void:
	_flying_dragon = LingpetDragonWingPayloadFactory.build_flying_dragon(
		origin,
		_wind_direction,
		FIELD_WIDTH,
		DRAGON_OFFSCREEN_MARGIN
	)


func _apply_wind_to_ball(owner: Object, delta: float) -> void:
	if owner == null or not bool(_get_owner_value(owner, "ball_active", false)):
		return
	var ball_pos: Vector2 = _get_owner_vector2(owner, "ball_pos", Vector2.ZERO)
	var ball_vel: Vector2 = _get_owner_vector2(owner, "ball_vel", Vector2.ZERO)
	var fps_scale := delta * 60.0
	# Spiral vortex steering first: it redirects (rotates) the ball around a
	# moving center at a bounded speed, instead of adding raw force every frame.
	ball_vel = _apply_swirl_to_ball(ball_pos, ball_vel, delta)
	# Gentle directional wind on top: a readable side sweep plus a soft upward
	# push toward the boss. These are tiny px/frame nudges — the speed clamp
	# below keeps them from ever building into an unguardable ball.
	var base_wind := _wind_direction * WIND_FORCE
	var wind_variation := base_wind * randf_range(WIND_VARIATION_MIN, WIND_VARIATION_MAX)
	if (ball_pos.x < WALL_DAMP_MARGIN and base_wind < 0.0) or (ball_pos.x > FIELD_WIDTH - WALL_DAMP_MARGIN and base_wind > 0.0):
		wind_variation *= WALL_DAMP_MULTIPLIER
	if randf() < WIND_REVERSE_CHANCE:
		wind_variation *= WIND_REVERSE_MULTIPLIER
	var opponent_y_wind := (
		OPPONENT_Y_WIND_DIRECTION
		* OPPONENT_Y_WIND_FORCE
		* randf_range(OPPONENT_Y_WIND_VARIATION_MIN, OPPONENT_Y_WIND_VARIATION_MAX)
	)
	ball_vel.x += wind_variation * fps_scale
	ball_vel.y += opponent_y_wind * fps_scale
	ball_vel = _clamp_wind_ball_speed(ball_vel)
	owner.set("ball_vel", ball_vel)
	_wind_tick_count += 1
	_record_ball_swirl(ball_pos)


func _apply_swirl_to_ball(ball_pos: Vector2, ball_vel: Vector2, delta: float) -> Vector2:
	var target_center := ball_pos + Vector2(-_wind_direction * SWIRL_CENTER_SIDE_OFFSET, -SWIRL_CENTER_UP_OFFSET)
	if _swirl_center == Vector2.ZERO:
		_swirl_center = target_center
	var follow := clampf(delta * SWIRL_CENTER_FOLLOW_SPEED, 0.0, 1.0)
	_swirl_center = _swirl_center.lerp(target_center, follow)
	_swirl_center.x = clampf(_swirl_center.x, 40.0, FIELD_WIDTH - 40.0)
	_swirl_center.y = clampf(_swirl_center.y, 70.0, FIELD_HEIGHT - 40.0)

	var rel := ball_pos - _swirl_center
	if rel.length_squared() < 36.0:
		rel = Vector2(_wind_direction * SWIRL_ORBIT_RADIUS, 0.0)
	var radial_in := (-rel).normalized()
	var tangent := Vector2(-rel.y, rel.x).normalized() * _swirl_spin_sign
	var desired := (
		tangent * SWIRL_TANGENTIAL_WEIGHT
		+ radial_in * SWIRL_INWARD_WEIGHT
		+ Vector2(_wind_direction * SWIRL_SIDE_DRIFT_WEIGHT, -SWIRL_UPDRAFT_WEIGHT)
	)
	if desired.length_squared() < 0.0001:
		desired = tangent
	desired = desired.normalized()
	var envelope := _swirl_envelope()
	_swirl_tick_count += 1

	var speed := ball_vel.length()
	if speed < 0.001:
		return desired * minf(SWIRL_TARGET_SPEED, SWIRL_MAX_BALL_SPEED)
	var cur_dir := ball_vel / speed
	var steer := clampf(SWIRL_STEER_RATE * delta * 60.0 * envelope, 0.0, 1.0)
	var new_dir := cur_dir.lerp(desired, steer)
	if new_dir.length_squared() < 0.0001:
		new_dir = desired
	new_dir = new_dir.normalized()
	# Only ease an over-fast ball DOWN toward the steady swirl speed; never inflate
	# a slow ball. This guarantees the vortex cannot accelerate the ball past a
	# guardable band, which was the core "말도 안 되게 빨라짐" regression.
	var next_speed := speed
	if next_speed > SWIRL_TARGET_SPEED:
		var speed_follow := clampf(SWIRL_SPEED_EASE * delta * 60.0 * maxf(envelope, 0.2), 0.0, 1.0)
		next_speed = lerpf(next_speed, SWIRL_TARGET_SPEED, speed_follow)
	next_speed = clampf(next_speed, 0.0, SWIRL_MAX_BALL_SPEED)
	return new_dir * next_speed


func _clamp_wind_ball_speed(velocity: Vector2) -> Vector2:
	var next_vel := velocity
	var speed := next_vel.length()
	if speed > SWIRL_MAX_BALL_SPEED:
		next_vel = next_vel.normalized() * SWIRL_MAX_BALL_SPEED
	return _soften_too_vertical_updraft(next_vel)


func _soften_too_vertical_updraft(velocity: Vector2) -> Vector2:
	var next_vel := velocity
	if next_vel.y < -SWIRL_MAX_UPWARD_SPEED:
		next_vel.y = -SWIRL_MAX_UPWARD_SPEED
	if next_vel.y < -SWIRL_RISING_SIDE_THRESHOLD:
		var desired_side := minf(absf(next_vel.y) * SWIRL_MIN_SIDE_RATIO_WHEN_RISING, SWIRL_MIN_SIDE_SPEED_CAP)
		if absf(next_vel.x) < desired_side:
			var side_sign := 1.0 if next_vel.x >= 0.0 else -1.0
			if absf(next_vel.x) < 0.2:
				side_sign = _wind_direction
			next_vel.x = side_sign * lerpf(absf(next_vel.x), desired_side, 0.38)
	return next_vel


func _maybe_spawn_wind_particle(delta: float) -> void:
	if _wind_particles.size() >= PARTICLE_MAX:
		return
	var chance := minf(1.0, PARTICLE_SPAWN_CHANCE_PER_FRAME * delta * 60.0)
	if randf() < chance:
		_add_wind_particle(false)


func _add_wind_particle(initial: bool) -> void:
	if _wind_particles.size() >= PARTICLE_MAX:
		return
	_wind_particles.append(LingpetDragonWingPayloadFactory.build_wind_particle(
		initial,
		_wind_direction,
		FIELD_WIDTH,
		OPPONENT_Y_WIND_DIRECTION,
		OPPONENT_Y_PARTICLE_SPEED_MIN,
		OPPONENT_Y_PARTICLE_SPEED_MAX
	))


func _update_wind_particles(delta: float) -> void:
	if _wind_particles.is_empty():
		return
	var write_index := 0
	for read_index in range(_wind_particles.size()):
		var particle: Dictionary = _wind_particles[read_index]
		var pos: Vector2 = particle.get("pos", Vector2.ZERO)
		var vel: Vector2 = particle.get("vel", Vector2.ZERO)
		var phase := float(particle.get("phase", 0.0)) + delta * 6.0
		if _active and _swirl_center != Vector2.ZERO:
			var rel: Vector2 = pos - _swirl_center
			var rel_len := rel.length()
			if rel_len > 4.0 and rel_len < SWIRL_FIELD_RADIUS * 1.45:
				var tangent := Vector2(-rel.y, rel.x).normalized() * _swirl_spin_sign
				var inward := (-rel).normalized()
				vel += (tangent * SWIRL_PARTICLE_TANGENTIAL_ACCEL + inward * SWIRL_PARTICLE_INWARD_ACCEL) * delta
		pos += vel * delta
		pos.y += sin(phase) * 0.38 * delta * 60.0
		var life := float(particle.get("life", 0.0)) - delta
		particle["pos"] = pos
		particle["vel"] = vel
		particle["phase"] = phase
		particle["life"] = life
		if life > 0.0 and pos.x > -90.0 and pos.x < FIELD_WIDTH + 90.0:
			_wind_particles[write_index] = particle
			write_index += 1
	if write_index < _wind_particles.size():
		_wind_particles.resize(write_index)


func _record_ball_swirl(ball_pos: Vector2) -> void:
	_last_ball_pos = ball_pos
	_ball_swirl_trail.append(LingpetDragonWingPayloadFactory.build_ball_swirl_trail_entry(
		ball_pos,
		_elapsed,
		SWIRL_TRAIL_LIFE_SECONDS
	))
	while _ball_swirl_trail.size() > SWIRL_TRAIL_MAX:
		_ball_swirl_trail.remove_at(0)


func _update_ball_swirl_trail(delta: float) -> void:
	if _ball_swirl_trail.is_empty():
		return
	var write_index := 0
	for read_index in range(_ball_swirl_trail.size()):
		var entry: Dictionary = _ball_swirl_trail[read_index]
		var life := float(entry.get("life", 0.0)) - delta
		if life <= 0.0:
			continue
		entry["life"] = life
		_ball_swirl_trail[write_index] = entry
		write_index += 1
	if write_index < _ball_swirl_trail.size():
		_ball_swirl_trail.resize(write_index)


func _update_flying_dragon(delta: float, owner: Object) -> void:
	if not _is_flying_dragon_active():
		return
	var dragon := _flying_dragon
	var pos: Vector2 = dragon.get("pos", Vector2.ZERO)
	var dir := float(dragon.get("direction", _wind_direction))
	var wing_time := float(dragon.get("wing_time", 0.0)) + delta
	pos.x += dir * DRAGON_SPEED * delta
	pos.y = float(dragon.get("base_y", pos.y)) + sin(wing_time * DRAGON_BOB_SPEED) * DRAGON_BOB_PIXELS
	dragon["pos"] = pos
	dragon["wing_time"] = wing_time
	dragon["hit_cooldown"] = maxf(0.0, float(dragon.get("hit_cooldown", 0.0)) - delta)
	_dragon_trail_accum += delta
	if _dragon_trail_accum >= DRAGON_TRAIL_SPAWN_INTERVAL:
		_dragon_trail_accum = 0.0
		_dragon_trail.append(LingpetDragonWingPayloadFactory.build_dragon_trail_entry(pos, DRAGON_TRAIL_LIFE_SECONDS))
		while _dragon_trail.size() > DRAGON_TRAIL_MAX:
			_dragon_trail.remove_at(0)
	_try_hit_ball_with_flying_dragon(owner, dragon)
	if (dir > 0.0 and pos.x > FIELD_WIDTH + DRAGON_OFFSCREEN_MARGIN) or (dir < 0.0 and pos.x < -DRAGON_OFFSCREEN_MARGIN):
		dragon["active"] = false
	_flying_dragon = dragon


func _update_dragon_trail(delta: float) -> void:
	if _dragon_trail.is_empty():
		return
	var write_index := 0
	for read_index in range(_dragon_trail.size()):
		var entry: Dictionary = _dragon_trail[read_index]
		var life := float(entry.get("life", 0.0)) - delta
		if life <= 0.0:
			continue
		entry["life"] = life
		_dragon_trail[write_index] = entry
		write_index += 1
	if write_index < _dragon_trail.size():
		_dragon_trail.resize(write_index)


func _try_hit_ball_with_flying_dragon(owner: Object, dragon: Dictionary) -> void:
	if owner == null or float(dragon.get("hit_cooldown", 0.0)) > 0.0:
		return
	if not bool(_get_owner_value(owner, "ball_active", false)):
		return
	var ball_pos: Vector2 = _get_owner_vector2(owner, "ball_pos", Vector2.ZERO)
	var dragon_pos: Vector2 = dragon.get("pos", Vector2.ZERO)
	var ball_radius := _get_ball_radius(owner)
	if absf(ball_pos.x - dragon_pos.x) > DRAGON_HALF_WIDTH + ball_radius:
		return
	if absf(ball_pos.y - dragon_pos.y) > DRAGON_HALF_HEIGHT + ball_radius:
		return
	var ball_vel: Vector2 = _get_owner_vector2(owner, "ball_vel", Vector2.ZERO)
	# Farukiras is a player-side companion. Only catch balls travelling down
	# toward the player, then send them back up toward the boss.
	if ball_vel.y <= 0.0:
		return
	var current_speed := ball_vel.length()
	if current_speed < 8.0:
		current_speed = BALL_SPEED_MIN
	var boosted_speed := current_speed * randf_range(BALL_SPEED_MULT_MIN, BALL_SPEED_MULT_MAX)
	ball_vel.x = float(dragon.get("direction", _wind_direction)) * absf(boosted_speed) * 0.62
	ball_vel.y = -absf(boosted_speed) * 0.62
	ball_vel = _soften_too_vertical_updraft(ball_vel)
	owner.set("ball_vel", ball_vel)
	dragon["hit_cooldown"] = HIT_COOLDOWN_SECONDS
	_hit_flash_timer = HIT_FLASH_SECONDS
	_last_hit_pos = ball_pos
	# Cache the post-bounce direction so the hit flash can elongate along the
	# kick path instead of reading as a tiny isotropic puff behind the dragon.
	if ball_vel.length_squared() > 0.001:
		_last_hit_dir = ball_vel.normalized()
	else:
		_last_hit_dir = Vector2.ZERO
	_ball_hit_count += 1
	_play_ball_hit_feedback()






func _play_ball_hit_feedback() -> void:
	var audio: Object = _get_registry_instance(_registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_dragon_breath_ball_hit"):
		audio.play_dragon_breath_ball_hit()
	elif audio.has_method("play_wall_hit"):
		audio.play_wall_hit(0.0)
	elif audio.has_method("play_active_item"):
		audio.play_active_item()




func _swirl_envelope() -> float:
	if not _active:
		return 0.0
	var fade_in := _ease_out(clampf(_elapsed / 0.16, 0.0, 1.0))
	var fade_out := 1.0 - _ease_out(clampf((_elapsed - (DURATION_SECONDS - 0.42)) / 0.42, 0.0, 1.0))
	return fade_in * clampf(fade_out, 0.0, 1.0)


func _ease_out(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - c, 3.0)


func _is_flying_dragon_active() -> bool:
	return bool(_flying_dragon.get("active", false))


func _get_ball_radius(owner: Object) -> float:
	var ball_radius: float = float(_get_owner_value(owner, "ball_radius", 0.0))
	if ball_radius > 0.0:
		return ball_radius
	return maxf(6.0, float(_get_owner_value(owner, "ball_size", 20.0)) * 0.5)


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	return fallback if value == null else value


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, key, fallback)
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
