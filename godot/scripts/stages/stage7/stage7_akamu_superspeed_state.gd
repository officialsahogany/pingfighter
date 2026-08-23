extends RefCounted

const BossSkillTriggerClass := preload("res://scripts/stages/common/boss_skill_trigger_class.gd")

const LEGACY_FPS := 60.0
const DURATION_SEC := 10.0
const ACTIVATION_FREEZE_SEC := 0.350
const TEXT_SEC := 1.50
# User-approved R5 departure from legacy: this one source gates both the first
# activation after Awakening unlock and every reuse after natural expiry.
const COOLDOWN_SEC := 50.0
const DASH_RECOVERY_FRAMES := 1.0
const AFTERIMAGE_COUNT := 5
const AFTERIMAGE_DELAY_SEC := 0.060
const AFTERIMAGE_FADE_SEC := 0.80
const DARK_PARTICLE_MAX := 200
const TRAIL_MAX := 30
const TRAIL_SPAWN_INTERVAL_FRAMES := 2.0
const TRAIL_ALPHA_FADE_PER_FRAME := 2.0 / 255.0
const GAUGE_COST := 250.0
const DARK_PALETTE := [
	Color(20.0 / 255.0, 10.0 / 255.0, 30.0 / 255.0, 1.0),
	Color(30.0 / 255.0, 5.0 / 255.0, 15.0 / 255.0, 1.0),
	Color(15.0 / 255.0, 15.0 / 255.0, 25.0 / 255.0, 1.0),
	Color(25.0 / 255.0, 5.0 / 255.0, 25.0 / 255.0, 1.0),
	Color(10.0 / 255.0, 10.0 / 255.0, 10.0 / 255.0, 1.0),
	Color(40.0 / 255.0, 10.0 / 255.0, 40.0 / 255.0, 1.0),
	Color(50.0 / 255.0, 15.0 / 255.0, 20.0 / 255.0, 1.0),
]

var active := false
var remaining_sec := 0.0
var text_remaining_sec := 0.0
var cooldown_remaining_sec := 0.0
var dash_active := false
var dash_timer_frames := 0.0
var dash_duration_frames := 0.0
var dash_direction := 0
var dash_target_center_x := 0.0
var dash_recovery_frames := 0.0
var motion_frame_accumulator := 0.0
var boss_pos := Vector2.ZERO
var boss_size := Vector2(100.0, 40.0)
var visual_scale := 1.0
var trail_spawn_accumulator := 0.0
var afterimages: Array = []
var dark_particles: Array = []
var trails: Array = []


func reset_full() -> void:
	clear_round_transients()
	cooldown_remaining_sec = 0.0


func clear_round_transients() -> void:
	active = false
	remaining_sec = 0.0
	text_remaining_sec = 0.0
	dash_active = false
	dash_timer_frames = 0.0
	dash_duration_frames = 0.0
	dash_direction = 0
	dash_target_center_x = 0.0
	dash_recovery_frames = 0.0
	motion_frame_accumulator = 0.0
	boss_pos = Vector2.ZERO
	boss_size = Vector2(100.0, 40.0)
	visual_scale = 1.0
	trail_spawn_accumulator = 0.0
	afterimages.clear()
	dark_particles.clear()
	trails.clear()


func has_runtime_state() -> bool:
	return (
		active
		or cooldown_remaining_sec > 0.0
		or dash_active
		or not afterimages.is_empty()
		or not dark_particles.is_empty()
		or not trails.is_empty()
	)


func get_snapshot() -> Dictionary:
	return {
		"active": active,
		"remaining_sec": remaining_sec,
		"text_remaining_sec": text_remaining_sec,
		"cooldown_remaining_sec": cooldown_remaining_sec,
		"cooldown_total_sec": COOLDOWN_SEC,
		"dash_active": dash_active,
		"dash_direction": dash_direction,
		"dash_target_center_x": dash_target_center_x,
		"afterimage_count": afterimages.size(),
		"dark_particle_count": dark_particles.size(),
		"trail_count": trails.size(),
	}


func set_debug_active(value: bool) -> void:
	active = value
	if value:
		remaining_sec = maxf(remaining_sec, DURATION_SEC)
	else:
		remaining_sec = 0.0
		text_remaining_sec = 0.0
		dash_active = false


func set_cooldown_remaining(value: float) -> void:
	cooldown_remaining_sec = maxf(0.0, value)


func tick_cooldown(delta: float) -> void:
	cooldown_remaining_sec = maxf(0.0, cooldown_remaining_sec - delta)


func try_start(
	context: Dictionary,
	boss_gauge: float,
	is_awakened: bool,
	blocked: bool,
	start_pos: Vector2,
	fallback_boss_size: Vector2
) -> Dictionary:
	if (
		active
		or not is_awakened
		or cooldown_remaining_sec > 0.0
		or boss_gauge < GAUGE_COST
		or blocked
	):
		return {"started": false, "boss_gauge": boss_gauge}
	boss_size = _as_vector2(
		context.get("boss_paddle_size", Vector2(
			float(context.get("boss_paddle_width", fallback_boss_size.x)),
			float(context.get("boss_hitbox_height", fallback_boss_size.y))
		)),
		fallback_boss_size
	)
	visual_scale = clampf(float(context.get("boss_paddle_shrink_scale", 1.0)), 0.2, 1.0)
	active = true
	remaining_sec = DURATION_SEC
	text_remaining_sec = TEXT_SEC
	cooldown_remaining_sec = 0.0
	dash_active = false
	dash_timer_frames = 0.0
	dash_duration_frames = 0.0
	dash_direction = 0
	dash_target_center_x = 0.0
	dash_recovery_frames = 0.0
	motion_frame_accumulator = 0.0
	boss_pos = start_pos
	trail_spawn_accumulator = 0.0
	afterimages.clear()
	dark_particles.clear()
	trails.clear()
	return {"started": true, "boss_gauge": maxf(0.0, boss_gauge - GAUGE_COST)}


func advance_freeze(delta: float) -> void:
	if not active:
		return
	remaining_sec = maxf(0.0, remaining_sec - delta)
	text_remaining_sec = maxf(0.0, text_remaining_sec - delta)


func advance_runtime(
	frame_scale: float,
	delta: float,
	context: Dictionary,
	rng: RandomNumberGenerator,
	effect_boss_pos: Variant = null,
	effect_boss_size: Variant = null
) -> Dictionary:
	boss_pos = _as_vector2(context.get("boss_pos", boss_pos), boss_pos)
	boss_size = _as_vector2(
		context.get("boss_paddle_size", Vector2(
			float(context.get("boss_paddle_width", boss_size.x)),
			float(context.get("boss_hitbox_height", boss_size.y))
		)),
		boss_size
	)
	var follow_pos: Vector2 = boss_pos if active else _as_vector2(effect_boss_pos, boss_pos)
	var follow_size: Vector2 = boss_size if active else _as_vector2(effect_boss_size, boss_size)
	_update_afterimages(frame_scale, delta, follow_pos + follow_size * 0.5)
	if not active:
		return {}
	remaining_sec = maxf(0.0, remaining_sec - delta)
	text_remaining_sec = maxf(0.0, text_remaining_sec - delta)
	if remaining_sec <= 0.0:
		_end()
		return {"ended": true}
	# BossAI advances movement before ball physics. This accumulator owns only
	# FPS-stable render payload generation.
	motion_frame_accumulator += frame_scale
	while motion_frame_accumulator + 0.000001 >= 1.0:
		_spawn_dark_particles(rng)
		_advance_dark_particles_tick()
		trail_spawn_accumulator += 1.0
		if trail_spawn_accumulator + 0.000001 >= TRAIL_SPAWN_INTERVAL_FRAMES:
			trail_spawn_accumulator = 0.0
			_spawn_trail()
		_advance_trails_tick()
		motion_frame_accumulator -= 1.0
	return {}


func notify_dash_started(
	new_boss_pos: Vector2,
	new_boss_size: Vector2,
	direction: int,
	target_center_x: float,
	duration_frames: float
) -> void:
	if not active:
		return
	boss_pos = new_boss_pos
	boss_size = new_boss_size
	dash_active = true
	dash_direction = direction
	dash_target_center_x = target_center_x
	dash_duration_frames = duration_frames
	dash_timer_frames = duration_frames
	_spawn_afterimages(new_boss_pos + new_boss_size * 0.5)


func notify_dash_finished(new_boss_pos: Vector2) -> void:
	boss_pos = new_boss_pos
	dash_active = false
	dash_direction = 0
	dash_target_center_x = 0.0
	dash_duration_frames = 0.0
	dash_timer_frames = 0.0


func build_hud_skill(
	boss_gauge: float,
	is_awakened: bool,
	skill_paused: bool,
	blocked: bool
) -> Dictionary:
	var ready: bool = (
		is_awakened
		and not skill_paused
		and not active
		and cooldown_remaining_sec <= 0.0
		and boss_gauge >= GAUGE_COST
		and not blocked
	)
	var skill_status := "locked"
	if active:
		skill_status = "active"
	elif not is_awakened:
		skill_status = "locked"
	elif skill_paused:
		skill_status = "paused"
	elif ready:
		skill_status = "ready"
	else:
		skill_status = "charging"
	var progress := 0.0
	if active:
		progress = clampf(remaining_sec / DURATION_SEC, 0.0, 1.0)
	elif cooldown_remaining_sec > 0.0:
		progress = clampf(1.0 - cooldown_remaining_sec / COOLDOWN_SEC, 0.0, 1.0)
	else:
		progress = clampf(boss_gauge / GAUGE_COST, 0.0, 1.0)
	return {
		"id": "stage7_superspeed",
		"name": "극정호신",
		"color": Color(0.96, 0.46, 0.18),
		"cost": GAUGE_COST,
		"progress": progress,
		"cooldown_remaining": cooldown_remaining_sec,
		"cooldown_total": COOLDOWN_SEC,
		"cooldown_contract": "time",
		"initial_ready_allowed": false,
		"trigger_type": BossSkillTriggerClass.TRIGGER_INSTANT,
		"duration_remaining": remaining_sec,
		"duration_total": DURATION_SEC,
		"next_activation_remaining": maxf(
			cooldown_remaining_sec,
			maxf(remaining_sec, maxf(0.0, GAUGE_COST - boss_gauge))
		),
		"ready": ready,
		"active": active,
		"implemented": true,
		"status": skill_status,
	}


func _finish_dash() -> void:
	dash_active = false
	dash_timer_frames = 0.0
	dash_duration_frames = 0.0
	dash_direction = 0
	dash_target_center_x = 0.0
	dash_recovery_frames = DASH_RECOVERY_FRAMES


func _end() -> void:
	if not active:
		return
	active = false
	remaining_sec = 0.0
	text_remaining_sec = 0.0
	cooldown_remaining_sec = COOLDOWN_SEC
	_finish_dash()
	dash_recovery_frames = 0.0
	motion_frame_accumulator = 0.0
	dark_particles.clear()
	trails.clear()
	trail_spawn_accumulator = 0.0


func _spawn_afterimages(center: Vector2) -> void:
	for index in range(AFTERIMAGE_COUNT):
		afterimages.append({
			"kind": "superspeed_ghost",
			"center": center,
			"size": boss_size,
			"visual_scale": visual_scale,
			"delay_remaining_sec": float(index) * AFTERIMAGE_DELAY_SEC,
			"age_sec": 0.0,
			"base_alpha": float(180 - index * 25) / 255.0,
			"alpha": float(180 - index * 25) / 255.0,
			"follow_speed": maxf(0.02, 0.08 - float(index) * 0.012),
			"index": index,
		})


func _update_afterimages(frame_scale: float, delta: float, target_center: Vector2) -> void:
	if afterimages.is_empty():
		return
	var write_index := 0
	for read_index in range(afterimages.size()):
		var ghost: Dictionary = afterimages[read_index]
		var previous_delay: float = maxf(0.0, float(ghost.get("delay_remaining_sec", 0.0)))
		var delay_remaining: float = maxf(0.0, previous_delay - delta)
		ghost["delay_remaining_sec"] = delay_remaining
		if delay_remaining > 0.0:
			afterimages[write_index] = ghost
			write_index += 1
			continue
		var active_delta: float = delta if previous_delay <= 0.0 else maxf(0.0, delta - previous_delay)
		var age_sec: float = float(ghost.get("age_sec", 0.0)) + active_delta
		if age_sec >= AFTERIMAGE_FADE_SEC:
			continue
		var follow_speed: float = clampf(float(ghost.get("follow_speed", 0.05)), 0.0, 1.0)
		var active_frame_scale: float = frame_scale if previous_delay <= 0.0 else active_delta * LEGACY_FPS
		var follow_blend: float = 1.0 - pow(1.0 - follow_speed, active_frame_scale)
		ghost["center"] = _as_vector2(ghost.get("center", target_center), target_center).lerp(
			target_center,
			follow_blend
		)
		ghost["age_sec"] = age_sec
		ghost["alpha"] = float(ghost.get("base_alpha", 0.5)) \
			* (1.0 - age_sec / AFTERIMAGE_FADE_SEC)
		afterimages[write_index] = ghost
		write_index += 1
	if write_index < afterimages.size():
		afterimages.resize(write_index)


func _spawn_dark_particles(rng: RandomNumberGenerator) -> void:
	var count: int = rng.randi_range(3, 5)
	for _index in range(count):
		var life_frames: float = float(rng.randi_range(30, 60))
		dark_particles.append({
			"pos": Vector2(
				rng.randf_range(boss_pos.x - 20.0, boss_pos.x + boss_size.x + 20.0),
				rng.randf_range(boss_pos.y - 15.0, boss_pos.y + boss_size.y + 10.0)
			),
			"vel": Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-2.5, -0.8)),
			"radius": rng.randf_range(3.0, 8.0),
			"life_frames": life_frames,
			"max_life_frames": life_frames,
			"color": DARK_PALETTE[rng.randi_range(0, DARK_PALETTE.size() - 1)],
		})
	while dark_particles.size() > DARK_PARTICLE_MAX:
		dark_particles.pop_front()


func _advance_dark_particles_tick() -> void:
	var write_index := 0
	for read_index in range(dark_particles.size()):
		var particle: Dictionary = dark_particles[read_index]
		particle["pos"] = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) \
			+ _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
		var velocity: Vector2 = _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
		velocity.x *= 0.98
		velocity.y *= 0.95
		particle["vel"] = velocity
		particle["radius"] = float(particle.get("radius", 1.0)) * 0.97
		particle["life_frames"] = float(particle.get("life_frames", 0.0)) - 1.0
		if float(particle.get("life_frames", 0.0)) <= 0.0 or float(particle.get("radius", 0.0)) < 1.0:
			continue
		dark_particles[write_index] = particle
		write_index += 1
	if write_index < dark_particles.size():
		dark_particles.resize(write_index)


func _spawn_trail() -> void:
	trails.append({
		"kind": "superspeed_trail",
		"center": boss_pos + boss_size * 0.5,
		"size": boss_size,
		"visual_scale": visual_scale,
		"alpha": 180.0 / 255.0,
	})
	while trails.size() > TRAIL_MAX:
		trails.pop_front()


func _advance_trails_tick() -> void:
	var write_index := 0
	for read_index in range(trails.size()):
		var trail: Dictionary = trails[read_index]
		var alpha: float = float(trail.get("alpha", 0.0)) - TRAIL_ALPHA_FADE_PER_FRAME
		if alpha <= 0.0:
			continue
		trail["alpha"] = alpha
		trails[write_index] = trail
		write_index += 1
	if write_index < trails.size():
		trails.resize(write_index)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
