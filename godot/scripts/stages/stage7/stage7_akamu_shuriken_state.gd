extends RefCounted

const PlayerKnockbackImmunity := preload("res://scripts/stages/common/player_knockback_immunity.gd")

const LEGACY_FPS := 60.0
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const GAUGE_COST := 30.0
const CAST_SEC := 0.30
const COOLDOWN_MIN_MSEC := 8000
const COOLDOWN_MAX_MSEC := 25000
const PENDING_DELAY_SEC := 0.20
const SPEED_PER_FRAME := 20.0
const SIZE := Vector2(18.0, 10.0)
const OFFSCREEN_MARGIN := 20.0
const SLOW_FRAMES := 120.0
const SLOW_MULTIPLIER := 0.20
const GAUGE_DRAIN_TICK_FRAMES := 30.0
const GAUGE_DRAIN_AMOUNT := 15.0
const GAUGE_DRAIN_TICKS := 4
const STATUS_SOURCE := "stage7_akamu_shuriken"
const MAX_ACTIVE := 8
const SPIN_RADIANS_PER_SEC := TAU * 15.0
const HIT_PARTICLE_MAX := 32
const SMOKE_OPACITY_THRESHOLD := 50.0 / 255.0

var scheduler_armed := false
var casting := false
var cast_elapsed_sec := 0.0
var cast_boss_pos := Vector2.ZERO
var cooldown_remaining_sec := 0.0
var cooldown_total_sec := 0.0
var pending_remaining: Array = []
var gauge_ticks_left := 0
var gauge_tick_frames_remaining := 0.0
var projectiles: Array = []
var hit_particles: Array = []


func reset_full() -> void:
	clear_round_transients()
	scheduler_armed = false
	cooldown_remaining_sec = 0.0
	cooldown_total_sec = 0.0


func clear_round_transients() -> void:
	projectiles.clear()
	hit_particles.clear()
	cancel_cast_and_pending()
	gauge_ticks_left = 0
	gauge_tick_frames_remaining = 0.0


func cancel_cast_and_pending() -> void:
	casting = false
	cast_elapsed_sec = 0.0
	cast_boss_pos = Vector2.ZERO
	pending_remaining.clear()


func has_runtime_state() -> bool:
	return (
		scheduler_armed
		or casting
		or not pending_remaining.is_empty()
		or gauge_ticks_left > 0
		or not projectiles.is_empty()
		or not hit_particles.is_empty()
	)


func set_cooldown_remaining(value: float, total: float = -1.0) -> void:
	scheduler_armed = true
	cooldown_remaining_sec = maxf(0.0, value)
	cooldown_total_sec = maxf(
		0.001,
		total if total >= 0.0 else maxf(value, float(COOLDOWN_MIN_MSEC) / 1000.0)
	)


func get_snapshot() -> Dictionary:
	return {
		"scheduler_armed": scheduler_armed,
		"casting": casting,
		"cast_elapsed_sec": cast_elapsed_sec,
		"cooldown_remaining_sec": cooldown_remaining_sec,
		"cooldown_total_sec": cooldown_total_sec,
		"pending_count": pending_remaining.size(),
		"projectile_count": projectiles.size(),
		"gauge_ticks_left": gauge_ticks_left,
		"gauge_tick_frames_remaining": gauge_tick_frames_remaining,
	}


func build_hud_skill(boss_gauge: float, skill_paused: bool, blocked_by_other_skill: bool) -> Dictionary:
	var cooldown_total: float = maxf(0.001, cooldown_total_sec)
	var live_projectiles: bool = not projectiles.is_empty()
	var cooldown_progress := 0.0
	if scheduler_armed:
		cooldown_progress = clampf(1.0 - cooldown_remaining_sec / cooldown_total, 0.0, 1.0)
	var ready: bool = (
		not skill_paused
		and scheduler_armed
		and cooldown_remaining_sec <= 0.0
		and boss_gauge >= GAUGE_COST
		and not casting
		and not blocked_by_other_skill
	)
	var shuriken_status := "charging"
	if live_projectiles:
		shuriken_status = "active"
	elif skill_paused:
		shuriken_status = "paused"
	elif casting:
		shuriken_status = "casting"
	elif ready:
		shuriken_status = "ready"
	return {
		"id": "stage7_shuriken",
		"name": "수리검",
		"color": Color(0.72, 0.78, 0.88),
		"cost": GAUGE_COST,
		"progress": cooldown_progress,
		"cooldown_remaining": cooldown_remaining_sec,
		"cooldown_total": cooldown_total,
		"next_activation_remaining": maxf(
			cooldown_remaining_sec,
			maxf(0.0, GAUGE_COST - boss_gauge)
		),
		"ready": ready,
		"active": live_projectiles or (casting and not skill_paused),
		"implemented": true,
		"status": shuriken_status,
	}


func should_start_cast(
	delta: float,
	boss_gauge: float,
	blocked_by_other_skill: bool,
	rng: RandomNumberGenerator
) -> bool:
	if not scheduler_armed:
		arm_cooldown(rng)
		return false
	cooldown_remaining_sec = maxf(0.0, cooldown_remaining_sec - delta)
	if cooldown_remaining_sec > 0.0:
		return false
	return boss_gauge >= GAUGE_COST and not blocked_by_other_skill


func start_cast(context: Dictionary, boss_gauge: float) -> float:
	casting = true
	cast_elapsed_sec = 0.0
	cast_boss_pos = _as_vector2(
		context.get("boss_pos", Vector2(330.0, 25.0)),
		Vector2(330.0, 25.0)
	)
	return maxf(0.0, boss_gauge - GAUGE_COST)


func advance_cast(delta: float) -> bool:
	cast_elapsed_sec += delta
	if cast_elapsed_sec + 0.000001 < CAST_SEC:
		return false
	casting = false
	cast_elapsed_sec = 0.0
	cast_boss_pos = Vector2.ZERO
	return true


func queue_awakened_bonus() -> void:
	pending_remaining.append(PENDING_DELAY_SEC)


func advance_pending(delta: float) -> int:
	if pending_remaining.is_empty():
		return 0
	var due_count := 0
	var write_index := 0
	for read_index in range(pending_remaining.size()):
		var remaining: float = float(pending_remaining[read_index]) - delta
		if remaining <= 0.000001:
			due_count += 1
			continue
		pending_remaining[write_index] = remaining
		write_index += 1
	if write_index < pending_remaining.size():
		pending_remaining.resize(write_index)
	return due_count


func spawn_from_context(context: Dictionary, from_pending: bool, deps: Dictionary) -> Vector2:
	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2(330.0, 25.0)), Vector2(330.0, 25.0))
	var boss_size := Vector2(
		maxf(1.0, float(context.get("boss_paddle_width", 100.0))),
		maxf(1.0, float(context.get("boss_hitbox_height", 40.0)))
	)
	var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2(302.5, 690.0)), Vector2(302.5, 690.0))
	var player_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	var origin: Vector2 = boss_pos + boss_size * 0.5
	var target: Vector2 = player_pos + player_size * 0.5
	append_shuriken(origin, target, from_pending)
	_play_audio(deps, &"play_stage7_akamu_shuriken_shoot")
	return target


func append_shuriken(origin: Vector2, target: Vector2, from_pending: bool) -> void:
	var direction: Vector2 = target - origin
	if direction.length_squared() <= 0.000001:
		direction = Vector2.DOWN
	while projectiles.size() >= MAX_ACTIVE:
		projectiles.pop_front()
	projectiles.append({
		"center": origin,
		"prev_center": origin,
		"velocity": direction.normalized() * SPEED_PER_FRAME,
		"size": SIZE,
		"radius": 18.0,
		"angle": 0.0,
		"from_pending": from_pending,
	})


func arm_cooldown(rng: RandomNumberGenerator) -> void:
	scheduler_armed = true
	cooldown_total_sec = float(rng.randi_range(COOLDOWN_MIN_MSEC, COOLDOWN_MAX_MSEC)) / 1000.0
	cooldown_remaining_sec = cooldown_total_sec


func update_projectiles(
	frame_scale: float,
	delta: float,
	context: Dictionary,
	deps: Dictionary,
	result: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	if projectiles.is_empty():
		return
	var player_rect := _get_player_rect(context)
	var player_center: Vector2 = player_rect.get_center()
	var write_index := 0
	for read_index in range(projectiles.size()):
		var shuriken: Dictionary = projectiles[read_index]
		var previous: Vector2 = _as_vector2(shuriken.get("center", Vector2.ZERO), Vector2.ZERO)
		var velocity: Vector2 = _as_vector2(
			shuriken.get("velocity", Vector2.DOWN * SPEED_PER_FRAME),
			Vector2.DOWN * SPEED_PER_FRAME
		)
		var center: Vector2 = previous + velocity * frame_scale
		shuriken["prev_center"] = previous
		shuriken["center"] = center
		shuriken["angle"] = fposmod(float(shuriken.get("angle", 0.0)) + SPIN_RADIANS_PER_SEC * delta, TAU)
		var player_hit_point: Variant = _get_player_hit_point(previous, center, player_rect)
		if player_hit_point != null:
			if _is_player_in_smoke(player_center, context, deps):
				result["stage7_akamu_shuriken_smoke_absorbed"] = true
				continue
			_register_hit(player_hit_point as Vector2, velocity, context, deps, result, rng)
			continue
		if _is_out_of_bounds(center):
			continue
		projectiles[write_index] = shuriken
		write_index += 1
	if write_index < projectiles.size():
		projectiles.resize(write_index)


func update_gauge_drain(frame_scale: float, context: Dictionary, result: Dictionary) -> void:
	if gauge_ticks_left <= 0:
		return
	gauge_tick_frames_remaining -= frame_scale
	while gauge_ticks_left > 0 and gauge_tick_frames_remaining <= 0.0:
		var gauge: float = maxf(0.0, float(result.get("special_gauge", context.get("special_gauge", 0.0))))
		var drain: float = minf(GAUGE_DRAIN_AMOUNT, gauge)
		if drain > 0.0:
			result["special_gauge"] = gauge - drain
		gauge_ticks_left -= 1
		if gauge_ticks_left > 0:
			gauge_tick_frames_remaining += GAUGE_DRAIN_TICK_FRAMES
		else:
			gauge_tick_frames_remaining = 0.0


func spawn_hit_particles(center: Vector2, velocity: Vector2, rng: RandomNumberGenerator) -> void:
	var bullet_angle: float = velocity.angle() if velocity.length_squared() > 0.000001 else PI * 0.5
	var count: int = rng.randi_range(8, 12)
	for _index in range(count):
		while hit_particles.size() >= HIT_PARTICLE_MAX:
			hit_particles.pop_front()
		var spread_angle: float = bullet_angle + PI + rng.randf_range(-PI / 3.0, PI / 3.0)
		var speed: float = rng.randf_range(3.0, 12.0)
		var life: float = float(rng.randi_range(20, 40)) / LEGACY_FPS
		hit_particles.append({
			"pos": center + Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-5.0, 5.0)),
			"vel": Vector2(
				cos(spread_angle) * speed,
				sin(spread_angle) * speed - rng.randf_range(2.0, 5.0)
			),
			"life": life,
			"max_life": life,
			"radius": rng.randf_range(2.0, 5.0),
			"gravity_per_frame": rng.randf_range(0.3, 0.6),
			"base_alpha": 1.0,
			"color": Color(0.72, 0.05, 0.10, 1.0),
		})


func update_hit_particles(delta: float) -> void:
	if hit_particles.is_empty():
		return
	var frame_scale: float = clampf(delta, 0.0, 0.1) * LEGACY_FPS
	var write_index := 0
	for read_index in range(hit_particles.size()):
		var particle: Dictionary = hit_particles[read_index]
		if not particle.has("life"):
			hit_particles[write_index] = particle
			write_index += 1
			continue
		var life: float = float(particle.get("life", 0.0)) - delta
		if life <= 0.0:
			continue
		var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO)
		var vel: Vector2 = _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
		pos += vel * frame_scale
		particle["pos"] = pos
		if particle.has("gravity_per_frame"):
			vel.y += float(particle.get("gravity_per_frame", 0.0)) * frame_scale
			particle["vel"] = vel
		else:
			particle["vel"] = vel * pow(0.92, frame_scale)
		particle["life"] = life
		var color: Color = particle.get("color", Color(0.72, 0.05, 0.10, 0.82))
		color.a = float(particle.get("base_alpha", 0.82)) \
			* clampf(life / maxf(0.001, float(particle.get("max_life", life))), 0.0, 1.0)
		particle["color"] = color
		hit_particles[write_index] = particle
		write_index += 1
	if write_index < hit_particles.size():
		hit_particles.resize(write_index)


func _register_hit(
	center: Vector2,
	velocity: Vector2,
	context: Dictionary,
	deps: Dictionary,
	result: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	result["stage7_akamu_shuriken_hit"] = true
	result["stage7_akamu_shuriken_hit_count"] = int(result.get("stage7_akamu_shuriken_hit_count", 0)) + 1
	spawn_hit_particles(center, velocity, rng)
	_play_audio(deps, &"play_stage7_akamu_shuriken_hit")
	if PlayerKnockbackImmunity.is_cleanse_immune(deps, context):
		result["stage7_akamu_shuriken_cleansed"] = true
		return
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state != null and status_effect_state.has_method("apply_status"):
		status_effect_state.apply_status(
			"player",
			"slow",
			SLOW_FRAMES,
			{
				"multiplier": SLOW_MULTIPLIER,
				"cleansable": true,
				"visual_variant": "stage7_akamu_shuriken",
				"label": "수리검",
			},
			STATUS_SOURCE
		)
	var working_speed: float = float(result.get("player_speed", context.get("player_speed", 0.0)))
	result["player_speed"] = working_speed * SLOW_MULTIPLIER
	result["stage7_akamu_shuriken_slow_applied"] = true
	gauge_ticks_left = GAUGE_DRAIN_TICKS
	gauge_tick_frames_remaining = GAUGE_DRAIN_TICK_FRAMES


func _get_player_hit_point(from_pos: Vector2, to_pos: Vector2, player_rect: Rect2) -> Variant:
	var expanded: Rect2 = player_rect.grow_individual(SIZE.x * 0.5, SIZE.y * 0.5, SIZE.x * 0.5, SIZE.y * 0.5)
	if expanded.has_point(from_pos):
		return from_pos
	if expanded.has_point(to_pos):
		return to_pos
	var corners: Array[Vector2] = [
		expanded.position,
		Vector2(expanded.end.x, expanded.position.y),
		expanded.end,
		Vector2(expanded.position.x, expanded.end.y),
	]
	var closest_hit := Vector2.ZERO
	var closest_distance_squared := INF
	var found_hit := false
	for index in range(corners.size()):
		var next_index: int = (index + 1) % corners.size()
		var intersection: Variant = Geometry2D.segment_intersects_segment(
			from_pos,
			to_pos,
			corners[index],
			corners[next_index]
		)
		if intersection == null:
			continue
		var hit_point: Vector2 = intersection as Vector2
		var distance_squared: float = from_pos.distance_squared_to(hit_point)
		if not found_hit or distance_squared < closest_distance_squared:
			closest_hit = hit_point
			closest_distance_squared = distance_squared
			found_hit = true
	return closest_hit if found_hit else null


func _is_out_of_bounds(center: Vector2) -> bool:
	var half_size: Vector2 = SIZE * 0.5
	return (
		center.x + half_size.x < -OFFSCREEN_MARGIN
		or center.x - half_size.x > FIELD_WIDTH + OFFSCREEN_MARGIN
		or center.y + half_size.y < -OFFSCREEN_MARGIN
		or center.y - half_size.y > FIELD_HEIGHT + OFFSCREEN_MARGIN
	)


func _is_player_in_smoke(player_center: Vector2, context: Dictionary, deps: Dictionary) -> bool:
	if bool(context.get("player_in_smoke", false)):
		return true
	for value in _get_smoke_zones(context, deps):
		if not (value is Dictionary):
			continue
		var zone: Dictionary = value
		var opacity: float = float(zone.get("opacity", 0.0))
		var threshold: float = 50.0 if opacity > 1.0 else SMOKE_OPACITY_THRESHOLD
		if opacity <= threshold:
			continue
		var center: Vector2 = _as_vector2(zone.get("position", Vector2.ZERO), Vector2(
			float(zone.get("x", 0.0)),
			float(zone.get("y", 0.0))
		))
		var radius_y: float = maxf(0.0, float(zone.get("radius", 0.0)))
		var radius_x: float = maxf(0.0, float(zone.get("radius_x", radius_y)))
		if radius_x <= 0.0 or radius_y <= 0.0:
			continue
		var dx: float = (player_center.x - center.x) / radius_x
		var dy: float = (player_center.y - center.y) / radius_y
		if dx * dx + dy * dy <= 1.0:
			return true
	return false


func _get_smoke_zones(context: Dictionary, deps: Dictionary) -> Array:
	for key in ["stage3_smoke_zones", "smoke_zones", "active_item_tear_gas_zones", "tear_gas_zones"]:
		var context_value: Variant = context.get(key, [])
		if context_value is Array and not (context_value as Array).is_empty():
			return context_value
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null:
		if active_item_runtime.has_method("get_tear_gas_zones"):
			var runtime_zones: Variant = active_item_runtime.get_tear_gas_zones()
			if runtime_zones is Array and not (runtime_zones as Array).is_empty():
				return runtime_zones
		var throw_controller: Object = active_item_runtime.get("throw_controller")
		if throw_controller != null and throw_controller.has_method("get_tear_gas_zones"):
			var controller_zones: Variant = throw_controller.get_tear_gas_zones()
			if controller_zones is Array and not (controller_zones as Array).is_empty():
				return controller_zones
	return []


func _get_player_rect(context: Dictionary) -> Rect2:
	var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2(302.5, 690.0)), Vector2(302.5, 690.0))
	var player_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	return Rect2(player_pos, player_size)


func _play_audio(deps: Dictionary, method_name: StringName) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method(method_name):
		audio.call(method_name)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
