extends RefCounted

# 2026-07-31 7점제 재보정: 3/5(60%) -> 4/7(57%).
const SCORE_THRESHOLD := 4
const FREEZE_SEC := 3.0
const AURA_RADIUS := 90.0
const MAX_HITS := 5
const HIT_COOLDOWN_SEC := 0.30
const RIPPLE_SEC := 0.30
const RECHARGE_SEC := 10.0
const GAUGE_GAIN := 90.0
const FREE_SKILL_CHANCE := 0.30
const AURA_PARTICLE_COUNT := 24
const BURST_DURATION_SEC := 0.80
const AWAKENING_BURST_COUNT := 48
const DISPERSE_BURST_COUNT := 32

var awakened := false
var trigger_armed := false
var intro_pending := false
var intro_done := false
var active := false
var hit_count := 0
var depleted := false
var recharge_remaining_sec := 0.0
var hit_cooldown_remaining_sec := 0.0
var ripple_remaining_sec := 0.0
var elapsed_sec := 0.0
var free_clone_queued := false
var particles: Array = []
var burst_particles: Array = []
var draw_context: Dictionary = {}


func reset_full() -> void:
	awakened = false
	trigger_armed = false
	intro_pending = false
	intro_done = false
	active = false
	hit_count = 0
	depleted = false
	recharge_remaining_sec = 0.0
	hit_cooldown_remaining_sec = 0.0
	ripple_remaining_sec = 0.0
	elapsed_sec = 0.0
	free_clone_queued = false
	particles.clear()
	burst_particles.clear()
	draw_context.clear()


func clear_round_transients() -> void:
	# Awakening, spent durability, and recharge persist across ordinary scores.
	# Only an in-flight intro and contact/render transients are cancelled.
	intro_pending = false
	hit_cooldown_remaining_sec = 0.0
	ripple_remaining_sec = 0.0
	free_clone_queued = false
	burst_particles.clear()


func has_runtime_state() -> bool:
	return (
		awakened
		or trigger_armed
		or intro_pending
		or intro_done
		or active
		or depleted
		or free_clone_queued
		or not particles.is_empty()
		or not burst_particles.is_empty()
		or not draw_context.is_empty()
	)


func handle_score_event(score_result: Dictionary) -> void:
	if awakened or intro_done:
		return
	if int(score_result.get("player_score", 0)) >= SCORE_THRESHOLD:
		trigger_armed = true


func sync_trigger(context: Dictionary) -> void:
	if awakened or intro_done or trigger_armed:
		return
	if int(context.get("player_score", 0)) < SCORE_THRESHOLD:
		return
	if bool(context.get("waiting_for_serve", false)) or not bool(context.get("ball_active", true)):
		return
	trigger_armed = true


func try_begin_intro(gameplay_freeze_active: bool) -> bool:
	if (
		not trigger_armed
		or awakened
		or intro_done
		or intro_pending
		or gameplay_freeze_active
	):
		return false
	intro_pending = true
	return true


func complete_awakening(
	center: Vector2,
	rng: RandomNumberGenerator,
	superspeed_active: bool
) -> bool:
	if not intro_pending:
		return false
	intro_pending = false
	trigger_armed = false
	intro_done = true
	awakened = true
	active = true
	hit_count = 0
	depleted = false
	recharge_remaining_sec = 0.0
	hit_cooldown_remaining_sec = 0.0
	ripple_remaining_sec = 0.0
	_init_particles(rng)
	_spawn_burst(center, false, rng)
	sync_draw_context(center, superspeed_active)
	return true


func set_debug_awakened(value: bool) -> void:
	# Preserve the legacy debug seam: toggling this flag alone does not activate
	# or clear the aura lifecycle.
	awakened = value


func debug_force_complete(
	center: Vector2,
	rng: RandomNumberGenerator,
	superspeed_active: bool
) -> void:
	trigger_armed = true
	intro_pending = true
	complete_awakening(center, rng, superspeed_active)


func get_snapshot() -> Dictionary:
	return {
		"awakened": awakened,
		"trigger_armed": trigger_armed,
		"intro_pending": intro_pending,
		"intro_done": intro_done,
		"active": active,
		"hit_count": hit_count,
		"max_hits": MAX_HITS,
		"depleted": depleted,
		"recharge_remaining_sec": recharge_remaining_sec,
		"hit_cooldown_remaining_sec": hit_cooldown_remaining_sec,
		"ripple_remaining_sec": ripple_remaining_sec,
		"free_clone_queued": free_clone_queued,
		"particle_count": particles.size(),
		"burst_particle_count": burst_particles.size(),
	}


func resolve_collision(
	ball_pos: Vector2,
	ball_vel: Vector2,
	boss_center: Vector2,
	collision_allowed: bool,
	skill_cooldown_paused: bool,
	superspeed_active: bool,
	rng: RandomNumberGenerator
) -> Dictionary:
	if (
		not awakened
		or not active
		or depleted
		or hit_cooldown_remaining_sec > 0.0
		or not collision_allowed
		or ball_vel.y >= 0.0
		or ball_pos.distance_squared_to(boss_center) > AURA_RADIUS * AURA_RADIUS
	):
		return {}
	hit_count = mini(MAX_HITS, hit_count + 1)
	hit_cooldown_remaining_sec = HIT_COOLDOWN_SEC
	ripple_remaining_sec = RIPPLE_SEC
	var reflected_velocity := Vector2(
		ball_vel.x + rng.randf_range(-2.0, 2.0),
		absf(ball_vel.y) * 1.1
	)
	var cloud_roll := false
	var clone_roll := false
	if not skill_cooldown_paused:
		cloud_roll = rng.randf() < FREE_SKILL_CHANCE
		clone_roll = rng.randf() < FREE_SKILL_CHANCE
	if hit_count >= MAX_HITS:
		depleted = true
		recharge_remaining_sec = RECHARGE_SEC
	sync_draw_context(boss_center, superspeed_active)
	return {
		"ball_pos": ball_pos,
		"ball_vel": reflected_velocity,
		"stage7_akamu_wind_aura_hit": true,
		"stage7_akamu_wind_aura_hits": hit_count,
		"stage7_akamu_wind_aura_depleted": depleted,
		"stage7_akamu_wind_aura_reward_suppressed": skill_cooldown_paused,
		"_wind_aura_gauge_gain": 0.0 if skill_cooldown_paused else GAUGE_GAIN,
		"_wind_aura_cloud_roll": cloud_roll,
		"_wind_aura_clone_roll": clone_roll,
		"_wind_aura_disperse_burst_pending": hit_count >= MAX_HITS,
	}


func spawn_depletion_burst(
	center: Vector2,
	rng: RandomNumberGenerator,
	superspeed_active: bool
) -> void:
	_spawn_burst(center, true, rng)
	sync_draw_context(center, superspeed_active)


func advance_runtime(
	frame_scale: float,
	delta: float,
	center: Vector2,
	superspeed_active: bool
) -> void:
	hit_cooldown_remaining_sec = maxf(0.0, hit_cooldown_remaining_sec - delta)
	ripple_remaining_sec = maxf(0.0, ripple_remaining_sec - delta)
	_update_visuals(frame_scale, delta)
	_update_burst_particles(frame_scale, delta)
	sync_draw_context(center, superspeed_active)


func advance_freeze_visuals(
	frame_scale: float,
	delta: float,
	center: Vector2,
	superspeed_active: bool
) -> void:
	_update_visuals(frame_scale, delta)
	_update_burst_particles(frame_scale, delta)
	sync_draw_context(center, superspeed_active)


func tick_recharge(
	delta: float,
	rng: RandomNumberGenerator,
	center: Vector2,
	superspeed_active: bool
) -> bool:
	if not depleted:
		return false
	recharge_remaining_sec = maxf(0.0, recharge_remaining_sec - delta)
	if recharge_remaining_sec > 0.0:
		sync_draw_context(center, superspeed_active)
		return false
	depleted = false
	hit_count = 0
	ripple_remaining_sec = 0.0
	_init_particles(rng)
	sync_draw_context(center, superspeed_active)
	return true


func sync_draw_context(center: Vector2, superspeed_active: bool) -> void:
	if not awakened or not active:
		draw_context.clear()
		return
	var strength := 0.0
	if not depleted:
		strength = float(MAX_HITS - hit_count) / float(MAX_HITS)
	draw_context["active"] = true
	draw_context["center"] = center
	draw_context["radius"] = AURA_RADIUS
	draw_context["strength"] = clampf(strength, 0.0, 1.0)
	draw_context["hit_count"] = hit_count
	draw_context["max_hits"] = MAX_HITS
	draw_context["remaining_hits"] = maxi(0, MAX_HITS - hit_count)
	draw_context["depleted"] = depleted
	draw_context["recharge_remaining"] = recharge_remaining_sec
	draw_context["recharge_total"] = RECHARGE_SEC
	draw_context["ripple_intensity"] = get_ripple_intensity()
	draw_context["superspeed"] = superspeed_active
	draw_context["elapsed_sec"] = elapsed_sec
	draw_context["particles"] = particles


func get_ripple_intensity() -> float:
	if ripple_remaining_sec <= 0.0:
		return 0.0
	var progress: float = 1.0 - ripple_remaining_sec / RIPPLE_SEC
	return sin(clampf(progress, 0.0, 1.0) * PI) * (1.0 - progress * 0.5)


func clear_hit_cooldown() -> void:
	hit_cooldown_remaining_sec = 0.0


func queue_free_clone() -> void:
	free_clone_queued = true


func clear_free_clone_queue() -> void:
	free_clone_queued = false


func take_free_clone_queue() -> bool:
	if not free_clone_queued:
		return false
	free_clone_queued = false
	return true


func _update_visuals(frame_scale: float, delta: float) -> void:
	if not active or not awakened:
		return
	elapsed_sec += delta
	for value in particles:
		if not (value is Dictionary):
			continue
		var particle: Dictionary = value
		particle["angle"] = float(particle.get("angle", 0.0)) \
			+ float(particle.get("speed", 0.03)) * frame_scale
		particle["radius"] = float(particle.get("base_radius", 64.0)) \
			+ sin(elapsed_sec * 3.0 + float(particle.get("phase", 0.0))) * 10.0


func _init_particles(rng: RandomNumberGenerator) -> void:
	particles.clear()
	var palette: Array[Color] = [
		Color(100.0 / 255.0, 220.0 / 255.0, 1.0, 150.0 / 255.0),
		Color(150.0 / 255.0, 1.0, 200.0 / 255.0, 130.0 / 255.0),
		Color(200.0 / 255.0, 240.0 / 255.0, 1.0, 140.0 / 255.0),
		Color(80.0 / 255.0, 200.0 / 255.0, 230.0 / 255.0, 160.0 / 255.0),
	]
	for index in range(AURA_PARTICLE_COUNT):
		var base_radius: float = rng.randf_range(50.0, 80.0)
		particles.append({
			"angle": float(index) / float(AURA_PARTICLE_COUNT) * TAU,
			"radius": base_radius,
			"base_radius": base_radius,
			"size": float(rng.randi_range(3, 8)),
			"speed": rng.randf_range(0.02, 0.05),
			"color": palette[rng.randi_range(0, palette.size() - 1)],
			"phase": rng.randf_range(0.0, TAU),
		})


func _spawn_burst(center: Vector2, disperse: bool, rng: RandomNumberGenerator) -> void:
	burst_particles.clear()
	var count := DISPERSE_BURST_COUNT if disperse else AWAKENING_BURST_COUNT
	var palette: Array[Color] = [
		Color(100.0 / 255.0, 220.0 / 255.0, 1.0, 1.0),
		Color(150.0 / 255.0, 1.0, 200.0 / 255.0, 1.0),
		Color(200.0 / 255.0, 240.0 / 255.0, 1.0, 1.0),
		Color(80.0 / 255.0, 200.0 / 255.0, 230.0 / 255.0, 1.0),
		Color(120.0 / 255.0, 180.0 / 255.0, 1.0, 1.0),
	]
	for _index in range(count):
		var angle: float = rng.randf_range(0.0, TAU)
		var speed: float = rng.randf_range(5.0, 15.0) if disperse else rng.randf_range(8.0, 25.0)
		var spawn_pos := center
		if disperse:
			spawn_pos += Vector2.RIGHT.rotated(angle) * rng.randf_range(30.0, AURA_RADIUS)
		# Legacy quirk: both burst variants effectively begin at alpha 1.0.
		var initial_alpha := 1.0
		burst_particles.append({
			"pos": spawn_pos,
			"vel": Vector2.RIGHT.rotated(angle) * speed,
			"size": float(rng.randi_range(2, 6) if disperse else rng.randi_range(4, 12)),
			"rotation": rng.randf_range(0.0, TAU),
			"rotation_speed": rng.randf_range(-0.17, 0.17) if disperse else rng.randf_range(-0.26, 0.26),
			"color": palette[rng.randi_range(0, 2 if disperse else palette.size() - 1)],
			"initial_alpha": initial_alpha,
			"alpha": initial_alpha,
			"age_sec": 0.0,
			"duration_sec": BURST_DURATION_SEC,
			"kind": "disperse" if disperse else "awakening",
		})


func _update_burst_particles(frame_scale: float, delta: float) -> void:
	if burst_particles.is_empty():
		return
	var write_index := 0
	for read_index in range(burst_particles.size()):
		var particle: Dictionary = burst_particles[read_index]
		var age_sec: float = float(particle.get("age_sec", 0.0)) + delta
		var duration_sec: float = maxf(0.001, float(particle.get("duration_sec", BURST_DURATION_SEC)))
		if age_sec >= duration_sec:
			continue
		var velocity: Vector2 = _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
		velocity *= pow(0.94, frame_scale)
		particle["pos"] = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) \
			+ velocity * frame_scale
		particle["vel"] = velocity
		particle["size"] = maxf(1.0, float(particle.get("size", 1.0)) * pow(0.98, frame_scale))
		particle["rotation"] = float(particle.get("rotation", 0.0)) \
			+ float(particle.get("rotation_speed", 0.0)) * frame_scale
		particle["age_sec"] = age_sec
		particle["alpha"] = float(particle.get("initial_alpha", 1.0)) \
			* (1.0 - age_sec / duration_sec)
		burst_particles[write_index] = particle
		write_index += 1
	if write_index < burst_particles.size():
		burst_particles.resize(write_index)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
