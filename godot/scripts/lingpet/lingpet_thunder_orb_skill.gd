extends RefCounted

const LingpetThunderOrbPayloadFactory := preload("res://scripts/lingpet/lingpet_thunder_orb_payload_factory.gd")
const LingpetThunderOrbRenderer := preload("res://scripts/lingpet/lingpet_thunder_orb_renderer.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const ORB_SPEED := 605.0
const ORB_RADIUS := 10.0
const ORB_VISUAL_RADIUS := 30.0
const EXPLOSION_RADIUS := 170.0
const EXPLOSION_DURATION_SECONDS := 0.20
const STUN_DURATION_SECONDS := 1.4
const STUN_REFRESH_FRAMES := 4.0
const TOTAL_DURATION_SECONDS := 6.0
const TARGET_Y_TOP := 65.0
const SPEED_MULT_START := 3.6
const SPEED_MULT_END := 0.05
const DECEL_DURATION_SECONDS := 0.8
const DECEL_SOFTEN_AFTER_SECONDS := 0.5
const TRAVEL_STEP_SECONDS := 1.0 / 60.0
const TRAIL_MAX_POINTS := 16
const EXPLOSION_PARTICLES_LARGE := 20
const EXPLOSION_PARTICLES_SMALL := 35
const PARTICLE_MAX := 72
const STATUS_SOURCE := "lumion_thunder_orb_electric_stun"
# Lv.3+ post-explosion mini-sparks: after the blast, residual sparks crackle near
# the explosion site at MINI_SPARK_INTERVAL spacing, count == active level
# (Lv.3->3, Lv.4->4, Lv.5->5; none below Lv.3). Each is a brief radial CC zone:
# the boss (CENTER distance, per the radial-CC rule) within MINI_SPARK_HIT_RADIUS
# is stunned MINI_SPARK_STUN_SECONDS, but ONLY when no electric stun is currently
# active (메인 감전 중엔 무효 — no double-application / extension).
const MINI_SPARK_LEVEL_MIN := 3
const MINI_SPARK_INTERVAL := 0.3
const MINI_SPARK_STUN_SECONDS := 0.5
const MINI_SPARK_SPAWN_DX := 50.0
const MINI_SPARK_SPAWN_DY := 18.0
const MINI_SPARK_HIT_RADIUS := 48.0
const MINI_SPARK_PARTICLES := 12
# Mini-spark burst visuals. The gameplay constants above (hit radius / count /
# stun / interval) are UNCHANGED — only the on-screen read is beefed up so the
# post-stun sparks are actually noticeable instead of a near-invisible particle
# puff. MINI_SPARK_VISUAL_RADIUS == MINI_SPARK_HIT_RADIUS so the crackle reads the
# real CC zone, while staying clearly smaller than the 170px main blast.
const MINI_SPARK_LARGE_PARTICLES := 5
const MINI_SPARK_FLASH_SECONDS := 0.24

# Horus-parity visual identity: a BLUE-WHITE energy orb (gold only as a faint
# outer-arc accent), ported from the original PingFighter hero "Horus" thunder
# orb. Re-implemented with Godot immediate-draw batched primitives + angle-math
# rotation (no per-frame Surface allocation / transform.rotate — the two causes
# of the Python version's frame drops).
const ORB_ROTATION_SPEED_DEG := 280.0
const ENERGY_PARTICLE_MAX := 20
const ENERGY_COLORS: Array[Color] = [
	Color(0.78, 0.90, 1.0), Color(0.59, 0.78, 1.0), Color(0.39, 0.70, 1.0), Color(1.0, 1.0, 1.0),
]
const LARGE_PARTICLE_COLORS: Array[Color] = [
	Color(0.78, 0.90, 1.0), Color(1.0, 1.0, 1.0), Color(0.59, 0.82, 1.0),
]

const PHASE_IDLE := 0
const PHASE_TRAVELING := 1
const PHASE_EXPLODING := 2
const PHASE_STUN := 3

var _phase := PHASE_IDLE
var _orb_pos := Vector2.ZERO
var _orb_vel := Vector2.ZERO
var _base_orb_vel := Vector2.ZERO
var _launch_x := 0.0
var _target_y := TARGET_Y_TOP
var _decel_timer := 0.0
var _elapsed := 0.0
var _trail: Array[Vector2] = []
var _explosion_pos := Vector2.ZERO
var _explosion_timer := 0.0
var _explosion_particles: Array = []
var _electric_stun_timer := 0.0
var _electric_stun_center := Vector2.ZERO
var _explosion_count := 0
var _shock_applied_count := 0
var _shock_applied_this_explosion := false
var _electric_loop_active := false
var _visual_seed := 0.0
var _orb_rotation := 0.0
var _energy_particles: Array = []
# Per-launch electric-stun duration. Defaults to the const, but the companion
# launch path overrides it from the level-scaled `stun_duration_seconds`
# (Lv.1 0.8s -> Lv.5 1.6s) so higher active-skill levels stun longer.
var _stun_duration_seconds := STUN_DURATION_SECONDS
# Per-launch main-blast radius (BOTH the visual blast and the boss-CENTER CC
# reach). Defaults to the const, overridden from the level-scaled
# `explosion_radius` (Lv.1 136px = 20% narrower -> Lv.5 170px full).
var _explosion_radius := EXPLOSION_RADIUS
# Last registry seen during update(), cached so reset() (round / pet transition)
# can stop a live electric-shock loop and clear our stun source even though the
# host reset path is registry-less.
var _registry: Object = null
var _mini_spark_total := 0
var _mini_spark_started := false
var _mini_spark_remaining := 0
var _mini_spark_timer := 0.0
var _mini_spark_index := 0
var _mini_spark_applied_count := 0
var _mini_spark_offset_scale := 1.0  # tests force 0.0 to spawn sparks at the blast center
# Active mini-spark burst visuals: [{pos: Vector2, timer: float, seed: float}, ...].
# Outlives _mini_spark_remaining by up to MINI_SPARK_FLASH_SECONDS so the final
# spark's crackle finishes drawing even after the chain count hits 0.
var _mini_spark_flashes: Array = []
var _renderer: Object = LingpetThunderOrbRenderer.new()


func reset() -> void:
	# If a round / pet transition resets us mid-stun, actively stop the electric
	# shock loop and clear our status source (the host reset path passes no
	# registry, so setting _electric_loop_active = false alone would leak the
	# audio loop and the lumion_thunder_orb_electric_stun status).
	if _electric_loop_active or _electric_stun_timer > 0.0:
		_sync_electric_audio(_registry, false)
		_clear_boss_electric_stun(_registry)
	_phase = PHASE_IDLE
	_orb_pos = Vector2.ZERO
	_orb_vel = Vector2.ZERO
	_base_orb_vel = Vector2.ZERO
	_launch_x = 0.0
	_target_y = TARGET_Y_TOP
	_decel_timer = 0.0
	_elapsed = 0.0
	_trail.clear()
	_explosion_pos = Vector2.ZERO
	_explosion_timer = 0.0
	_explosion_particles.clear()
	_electric_stun_timer = 0.0
	_electric_stun_center = Vector2.ZERO
	_shock_applied_this_explosion = false
	_electric_loop_active = false
	_visual_seed = 0.0
	_orb_rotation = 0.0
	_energy_particles.clear()
	_stun_duration_seconds = STUN_DURATION_SECONDS
	_explosion_radius = EXPLOSION_RADIUS
	_mini_spark_total = 0
	_mini_spark_started = false
	_mini_spark_remaining = 0
	_mini_spark_timer = 0.0
	_mini_spark_index = 0
	_mini_spark_applied_count = 0
	_mini_spark_flashes.clear()


func prewarm() -> void:
	pass


func update(delta: float, owner: Object, registry: Object = null) -> void:
	_registry = registry
	var safe_delta: float = maxf(0.0, delta)
	if safe_delta <= 0.0:
		if _phase == PHASE_STUN:
			_apply_boss_electric_stun(registry)
		return

	_elapsed += safe_delta
	if _phase == PHASE_TRAVELING and _elapsed > TOTAL_DURATION_SECONDS:
		_start_explosion(owner, registry)

	var remaining_delta := safe_delta
	if _phase == PHASE_TRAVELING:
		remaining_delta = _advance_travel(remaining_delta, owner, registry)
	if _phase == PHASE_TRAVELING:
		_update_orb_visual_state(safe_delta)

	if _phase == PHASE_EXPLODING and remaining_delta > 0.0:
		remaining_delta = _update_explosion(remaining_delta, owner, registry)
	if _phase == PHASE_STUN and remaining_delta > 0.0:
		_update_electric_stun(remaining_delta, owner, registry)

	# Mini-sparks run on their own schedule, independent of phase (they may fire
	# while PHASE_STUN from the main blast or after it returns to IDLE).
	if _mini_spark_remaining > 0:
		_update_mini_sparks(safe_delta, owner, registry)

	if not _explosion_particles.is_empty():
		_update_particles(safe_delta)

	if not _mini_spark_flashes.is_empty():
		_update_mini_spark_flashes(safe_delta)


func launch(origin: Vector2, owner: Object = null, launch_context: Dictionary = {}) -> void:
	reset()
	var ctx_stun := float(launch_context.get("stun_duration_seconds", 0.0))
	_stun_duration_seconds = ctx_stun if ctx_stun > 0.0 else STUN_DURATION_SECONDS
	var ctx_radius := float(launch_context.get("explosion_radius", 0.0))
	_explosion_radius = ctx_radius if ctx_radius > 0.0 else EXPLOSION_RADIUS
	var level := int(launch_context.get("active_skill_level", 1))
	_mini_spark_total = level if level >= MINI_SPARK_LEVEL_MIN else 0
	_phase = PHASE_TRAVELING
	_orb_pos = Vector2(clampf(origin.x, ORB_RADIUS, FIELD_WIDTH - ORB_RADIUS), origin.y)
	_launch_x = _orb_pos.x
	_target_y = _get_target_y(owner)
	_base_orb_vel = Vector2(0.0, -ORB_SPEED)
	_orb_vel = _base_orb_vel * SPEED_MULT_START
	_decel_timer = 0.0
	_elapsed = 0.0
	_trail.append(_orb_pos)
	_visual_seed = _seeded_unit(_orb_pos.x + _orb_pos.y, 17.0)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	if not _explosion_particles.is_empty():
		_renderer.draw_particles(canvas, _explosion_particles, shake_offset)
	if _explosion_timer > 0.0:
		_renderer.draw_explosion(
			canvas,
			_explosion_pos + shake_offset,
			_explosion_timer,
			EXPLOSION_DURATION_SECONDS,
			_explosion_radius,
			_visual_seed
		)
	if not _mini_spark_flashes.is_empty():
		_renderer.draw_mini_spark_flashes(
			canvas,
			_mini_spark_flashes,
			shake_offset,
			MINI_SPARK_FLASH_SECONDS,
			MINI_SPARK_HIT_RADIUS
		)
	if _phase == PHASE_TRAVELING:
		_renderer.draw_orb(
			canvas,
			_orb_pos + shake_offset,
			shake_offset,
			_elapsed,
			_visual_seed,
			_orb_rotation,
			ORB_VISUAL_RADIUS,
			_trail,
			_energy_particles
		)


func has_visible_effects() -> bool:
	return _phase != PHASE_IDLE or not _explosion_particles.is_empty() or _mini_spark_remaining > 0 or not _mini_spark_flashes.is_empty()


func is_active() -> bool:
	return _phase != PHASE_IDLE or _mini_spark_remaining > 0


func is_projectile_active() -> bool:
	return _phase == PHASE_TRAVELING


func is_explosion_active() -> bool:
	return _phase == PHASE_EXPLODING


func is_electric_stun_active() -> bool:
	return _electric_stun_timer > 0.0


func get_particle_count_for_tests() -> int:
	return _explosion_particles.size()


func get_shock_applied_count_for_tests() -> int:
	return _shock_applied_count


func get_mini_spark_applied_count_for_tests() -> int:
	return _mini_spark_applied_count


func get_mini_spark_total_for_tests() -> int:
	return _mini_spark_total


func get_mini_spark_remaining_for_tests() -> int:
	return _mini_spark_remaining


func set_mini_spark_offset_scale_for_tests(value: float) -> void:
	_mini_spark_offset_scale = maxf(0.0, value)


func get_snapshot() -> Dictionary:
	return {
		"thunder_orb_projectile_active": _phase == PHASE_TRAVELING,
		"thunder_orb_projectile_pos": _orb_pos,
		"thunder_orb_projectile_speed": _orb_vel.length(),
		"thunder_orb_speed_multiplier": _get_speed_multiplier(),
		"thunder_orb_target_y": _target_y,
		"thunder_orb_decel_timer": _decel_timer,
		"thunder_orb_explosion_active": _phase == PHASE_EXPLODING,
		"thunder_orb_explosion_pos": _explosion_pos,
		"thunder_orb_explosion_radius": _explosion_radius,
		"thunder_orb_explosion_count": _explosion_count,
		"thunder_orb_electric_stun_active": _electric_stun_timer > 0.0,
		"thunder_orb_electric_stun_timer": _electric_stun_timer,
		"thunder_orb_shock_applied_count": _shock_applied_count,
		"thunder_orb_particle_count": _explosion_particles.size(),
		"thunder_orb_mini_spark_remaining": _mini_spark_remaining,
		"thunder_orb_mini_spark_applied_count": _mini_spark_applied_count,
	}


func _advance_travel(delta: float, owner: Object, registry: Object) -> float:
	var remaining := maxf(0.0, delta)
	while remaining > 0.0 and _phase == PHASE_TRAVELING:
		var step := minf(remaining, TRAVEL_STEP_SECONDS)
		var unused := _advance_travel_step(step, owner, registry)
		remaining -= step
		if _phase != PHASE_TRAVELING:
			remaining += unused
			break
	return maxf(0.0, remaining)


func _advance_travel_step(delta: float, owner: Object, registry: Object) -> float:
	_trail.append(_orb_pos)
	while _trail.size() > TRAIL_MAX_POINTS:
		_trail.remove_at(0)
	_update_orb_velocity(delta)
	var next_pos := _orb_pos + _orb_vel * delta
	next_pos.x = _launch_x
	if next_pos.y <= _target_y:
		var travel_time := 0.0
		if absf(_orb_vel.y) > 0.001:
			travel_time = clampf(absf(_orb_pos.y - _target_y) / absf(_orb_vel.y), 0.0, delta)
		_orb_pos += _orb_vel * travel_time
		_orb_pos.x = _launch_x
		_orb_pos.y = _target_y
		_start_explosion(owner, registry)
		return maxf(0.0, delta - travel_time)
	_orb_pos = next_pos
	return 0.0


func _update_orb_velocity(delta: float) -> void:
	_decel_timer = minf(DECEL_DURATION_SECONDS, _decel_timer + maxf(0.0, delta))
	var t := clampf(_decel_timer / DECEL_DURATION_SECONDS, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 2.0)
	if _decel_timer > DECEL_SOFTEN_AFTER_SECONDS:
		var half_t := DECEL_SOFTEN_AFTER_SECONDS / DECEL_DURATION_SECONDS
		var eased_half: float = 1.0 - pow(1.0 - half_t, 2.0)
		eased = eased_half + (eased - eased_half) * 0.5
	var speed_mult: float = SPEED_MULT_START + (SPEED_MULT_END - SPEED_MULT_START) * eased
	_orb_vel = _base_orb_vel * speed_mult


# Advances the orb's cheap visual state: angle-math rotation (drives the hex
# frame / arcs without transform.rotate) plus the floating energy motes that
# drift up off the orb. Both Python frame-drop sources (per-frame Surface alloc,
# transform.rotate) are avoided.
func _update_orb_visual_state(delta: float) -> void:
	_orb_rotation = fmod(_orb_rotation + deg_to_rad(ORB_ROTATION_SPEED_DEG) * delta, TAU)
	var kept: Array = []
	for p in _energy_particles:
		var life: float = float(p["life"]) - delta
		if life <= 0.0:
			continue
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		p["life"] = life
		kept.append(p)
	_energy_particles = kept
	if _energy_particles.size() < ENERGY_PARTICLE_MAX and randf() < 0.6:
		_energy_particles.append(LingpetThunderOrbPayloadFactory.build_energy_particle(_orb_pos, ORB_VISUAL_RADIUS, ENERGY_COLORS))


func _start_explosion(_owner: Object, registry: Object) -> void:
	if _phase == PHASE_EXPLODING or _phase == PHASE_STUN:
		return
	_phase = PHASE_EXPLODING
	_explosion_pos = Vector2(clampf(_orb_pos.x, ORB_RADIUS, FIELD_WIDTH - ORB_RADIUS), clampf(_orb_pos.y, 0.0, FIELD_HEIGHT))
	_explosion_timer = EXPLOSION_DURATION_SECONDS
	_explosion_count += 1
	_shock_applied_this_explosion = false
	_orb_vel = Vector2.ZERO
	_trail.clear()
	_spawn_explosion_particles(_explosion_pos)
	_play_explosion_feedback(registry)
	# The blast is judged only after the explosion animation finishes (see
	# _update_explosion), matching the original Horus thunder orb — NOT at
	# explosion start. So no stun / electric loop is started here.


func _update_explosion(delta: float, owner: Object, registry: Object) -> float:
	var previous_timer := _explosion_timer
	_explosion_timer = maxf(0.0, _explosion_timer - delta)
	if _explosion_timer > 0.0:
		return 0.0
	# Explosion animation finished — judge the blast NOW (boss CENTER within
	# EXPLOSION_RADIUS) and only then begin the stun + electric loop.
	var unused_delta := maxf(0.0, delta - previous_timer)
	_try_begin_electric_stun(owner, registry)
	if _electric_stun_timer > 0.0:
		_phase = PHASE_STUN
	else:
		_phase = PHASE_IDLE
		# No main stun caught the boss -> the lingering mini-sparks start right
		# after the blast (there is no main stun to wait out).
		_begin_mini_sparks()
	return unused_delta


func _try_begin_electric_stun(owner: Object, registry: Object) -> void:
	if _shock_applied_this_explosion:
		return
	var boss_center := _get_boss_rect(owner).get_center()
	# Original Horus geometry: pure boss-CENTER distance <= EXPLOSION_RADIUS, NOT
	# a circle-vs-rect overlap. A boss merely clipping the blast edge must not be
	# stunned (CLAUDE.md radial-CC geometry rule).
	if _explosion_pos.distance_to(boss_center) > _explosion_radius:
		return
	_electric_stun_center = boss_center
	_shock_applied_this_explosion = true
	_shock_applied_count += 1
	_electric_stun_timer = _stun_duration_seconds
	_apply_boss_electric_stun(registry)
	_sync_electric_audio(registry, true)


func _update_electric_stun(delta: float, owner: Object, registry: Object) -> void:
	_electric_stun_center = _get_boss_rect(owner).get_center()
	_electric_stun_timer = maxf(0.0, _electric_stun_timer - delta)
	if _electric_stun_timer > 0.0:
		_apply_boss_electric_stun(registry)
		_sync_electric_audio(registry, true)
		return
	_clear_boss_electric_stun(registry)
	_sync_electric_audio(registry, false)
	_phase = PHASE_IDLE
	# Main electric stun just ended -> begin the lingering mini-spark chain (once).
	# A later mini-stun ending re-enters here, but _begin_mini_sparks no-ops after
	# the first start (메인 감전중엔 무효 is satisfied because the chain starts only
	# now, after the main stun is gone).
	_begin_mini_sparks()


func _begin_mini_sparks() -> void:
	if _mini_spark_total <= 0 or _mini_spark_started:
		return
	_mini_spark_started = true
	_mini_spark_remaining = _mini_spark_total
	_mini_spark_timer = MINI_SPARK_INTERVAL
	_mini_spark_index = 0


func _update_mini_sparks(delta: float, owner: Object, registry: Object) -> void:
	if _mini_spark_remaining <= 0:
		return
	_mini_spark_timer -= delta
	if _mini_spark_timer > 0.0:
		return
	var carry := _mini_spark_timer
	_fire_mini_spark(owner, registry)
	_mini_spark_remaining -= 1
	_mini_spark_index += 1
	# At most one spark per update so a catch-up delta spike cannot collapse the
	# whole 0.3s-spaced chain into a single frame.
	_mini_spark_timer = (MINI_SPARK_INTERVAL + carry) if _mini_spark_remaining > 0 else 0.0


func _fire_mini_spark(owner: Object, registry: Object) -> void:
	# A spark "appears" this call — play one of the random spark zaps per spark
	# instance, regardless of whether it lands a CC hit below.
	_play_mini_spark_sound(registry)
	var side := 1.0 if _mini_spark_index % 2 == 0 else -1.0  # alternate both sides (양쪽)
	var dx := side * lerpf(20.0, MINI_SPARK_SPAWN_DX, _seeded_unit(_visual_seed + float(_mini_spark_index) * 3.3, 11.0)) * _mini_spark_offset_scale
	var dy := (_seeded_unit(_visual_seed + float(_mini_spark_index) * 5.7, 23.0) - 0.5) * 2.0 * MINI_SPARK_SPAWN_DY * _mini_spark_offset_scale
	var spark_pos := Vector2(
		clampf(_explosion_pos.x + dx, ORB_RADIUS, FIELD_WIDTH - ORB_RADIUS),
		clampf(_explosion_pos.y + dy, 0.0, FIELD_HEIGHT)
	)
	# Crackle visual: scattered RANDOM electric sparks (drawn in
	# _draw_mini_spark_flashes — no central orb / ring / flash) plus a beefier
	# particle puff. Far stronger read than the old 8-particle-only spark.
	# Registered even on a CC miss so the spark is always visible where it lands.
	_mini_spark_flashes.append({
		"pos": spark_pos,
		"timer": MINI_SPARK_FLASH_SECONDS,
		"seed": _seeded_unit(_visual_seed + float(_mini_spark_index) * 4.1, 31.0),
	})
	for _i in range(MINI_SPARK_LARGE_PARTICLES):
		_add_particle(LingpetThunderOrbPayloadFactory.build_large_explosion_particle(spark_pos, LARGE_PARTICLE_COLORS))
	for _i in range(MINI_SPARK_PARTICLES):
		_add_particle(LingpetThunderOrbPayloadFactory.build_small_explosion_particle(spark_pos, ENERGY_COLORS))
	# Radial CC: boss CENTER within hit radius; only when no electric stun is
	# active (메인 감전 중엔 무효 — no double-application / extension).
	if _electric_stun_timer > 0.0:
		return
	var boss_center := _get_boss_rect(owner).get_center()
	if spark_pos.distance_to(boss_center) > MINI_SPARK_HIT_RADIUS:
		return
	_electric_stun_center = boss_center
	_electric_stun_timer = MINI_SPARK_STUN_SECONDS
	_mini_spark_applied_count += 1
	_phase = PHASE_STUN
	_apply_boss_electric_stun(registry)
	_sync_electric_audio(registry, true)


func _update_mini_spark_flashes(delta: float) -> void:
	var kept: Array = []
	for flash in _mini_spark_flashes:
		var timer: float = float(flash["timer"]) - delta
		if timer <= 0.0:
			continue
		flash["timer"] = timer
		kept.append(flash)
	_mini_spark_flashes = kept


func _apply_boss_electric_stun(registry: Object) -> void:
	var status_state: Object = _get_registry_instance(registry, "status_effect_state")
	if status_state == null or not status_state.has_method("apply_status"):
		return
	status_state.apply_status(
		"boss",
		"stun",
		STUN_REFRESH_FRAMES,
		LingpetThunderOrbPayloadFactory.build_electric_stun_status_data(),
		STATUS_SOURCE
	)


func _clear_boss_electric_stun(registry: Object) -> void:
	var status_state: Object = _get_registry_instance(registry, "status_effect_state")
	if status_state != null and status_state.has_method("clear_status"):
		status_state.clear_status("boss", "stun", STATUS_SOURCE)


func _spawn_explosion_particles(origin: Vector2) -> void:
	for _i in range(EXPLOSION_PARTICLES_LARGE):
		_add_particle(LingpetThunderOrbPayloadFactory.build_large_explosion_particle(origin, LARGE_PARTICLE_COLORS))
	for _i in range(EXPLOSION_PARTICLES_SMALL):
		_add_particle(LingpetThunderOrbPayloadFactory.build_small_explosion_particle(origin, ENERGY_COLORS))


func _add_particle(particle: Dictionary) -> void:
	if _explosion_particles.size() >= PARTICLE_MAX:
		return
	_explosion_particles.append(particle)


func _update_particles(delta: float) -> void:
	var kept: Array = []
	for particle in _explosion_particles:
		var life: float = float(particle["life"]) - delta
		if life <= 0.0:
			continue
		var vel: Vector2 = particle["vel"]
		vel *= 0.86 if int(particle["kind"]) == 0 else 0.80
		vel.y += 20.0 * delta
		particle["vel"] = vel
		particle["pos"] = (particle["pos"] as Vector2) + vel * delta
		particle["life"] = life
		kept.append(particle)
	_explosion_particles = kept


func _get_boss_rect(owner: Object) -> Rect2:
	var boss_pos: Vector2 = _get_owner_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	var boss_w: float = maxf(1.0, float(_get_owner_value(owner, "boss_paddle_width", 100.0)))
	var boss_h: float = maxf(1.0, float(_get_owner_value(owner, "boss_hitbox_height", 40.0)))
	return Rect2(boss_pos, Vector2(boss_w, boss_h))


func _get_target_y(owner: Object) -> float:
	var wall_y := clampf(float(_get_owner_value(owner, "boss_wall_y", TARGET_Y_TOP)), 0.0, FIELD_HEIGHT * 0.35)
	return clampf(maxf(TARGET_Y_TOP, wall_y), ORB_RADIUS, FIELD_HEIGHT * 0.35)


func _get_speed_multiplier() -> float:
	if absf(ORB_SPEED) <= 0.001:
		return 0.0
	return absf(_orb_vel.y) / ORB_SPEED


func _sync_electric_audio(registry: Object, active: bool) -> void:
	if _electric_loop_active == active:
		return
	var audio: Object = _get_registry_instance(registry, "game_audio")
	if audio == null:
		_electric_loop_active = active
		return
	if audio.has_method("sync_electric_shock_loop"):
		audio.sync_electric_shock_loop(active)
	elif active and audio.has_method("play_electric_shock_loop"):
		audio.play_electric_shock_loop()
	elif not active and audio.has_method("stop_electric_shock_loop"):
		audio.stop_electric_shock_loop()
	_electric_loop_active = active


func _play_explosion_feedback(registry: Object) -> void:
	var audio: Object = _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_thunder_orb_boom"):
		audio.play_thunder_orb_boom()
	elif audio.has_method("play_ragnarok_boom"):
		audio.play_ragnarok_boom()
	elif audio.has_method("play_grenade_explosion"):
		audio.play_grenade_explosion()


func _play_mini_spark_sound(registry: Object) -> void:
	var audio: Object = _get_registry_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_mini_spark"):
		audio.play_mini_spark()


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner != null and owner.get(key) != null:
		return owner.get(key)
	return fallback


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


func _seeded_unit(seed_value: float, salt: float) -> float:
	var hashed := sin(seed_value * 9283.33 + salt * 47.77) * 43758.5453
	return hashed - floor(hashed)
