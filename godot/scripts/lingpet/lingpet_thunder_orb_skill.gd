extends RefCounted

const LingpetThunderOrbPayloadFactory := preload("res://scripts/lingpet/lingpet_thunder_orb_payload_factory.gd")

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
const MINI_SPARK_VISUAL_RADIUS := 48.0  # scatter bound for the random sparks (== hit radius)
const MINI_SPARK_BOLT_COUNT := 10
const MINI_SPARK_DOT_COUNT := 6

# Horus-parity visual identity: a BLUE-WHITE energy orb (gold only as a faint
# outer-arc accent), ported from the original PingFighter hero "Horus" thunder
# orb. Re-implemented with Godot immediate-draw batched primitives + angle-math
# rotation (no per-frame Surface allocation / transform.rotate — the two causes
# of the Python version's frame drops).
const ORB_ROTATION_SPEED_DEG := 280.0
const ENERGY_PARTICLE_MAX := 20
const ORB_INNER_COLOR := Color(0.78, 0.90, 1.0)
const ORB_RING_COLOR := Color(0.31, 0.63, 1.0)
const ARC_GLOW_COLOR := Color(0.24, 0.51, 1.0)
const ARC_CORE_COLOR := Color(0.78, 0.90, 1.0)
const TRAIL_COLOR := Color(0.39, 0.70, 1.0)
const OUTER_ARC_COLORS: Array[Color] = [
	Color(0.47, 0.71, 1.0), Color(0.31, 0.55, 1.0), Color(0.63, 0.78, 1.0),
	Color(1.0, 0.94, 0.47), Color(1.0, 0.86, 0.31),
]
const SPARK_COLORS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 0.90), Color(0.78, 0.90, 1.0),
]
const RING_COLORS: Array[Color] = [
	Color(0.39, 0.70, 1.0), Color(0.59, 0.82, 1.0), Color(0.31, 0.63, 1.0),
	Color(0.71, 0.86, 1.0), Color(0.24, 0.55, 0.94),
]
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
		_draw_particles(canvas, shake_offset)
	if _explosion_timer > 0.0:
		_draw_explosion(canvas, _explosion_pos + shake_offset)
	if not _mini_spark_flashes.is_empty():
		_draw_mini_spark_flashes(canvas, shake_offset)
	# The on-boss electric arcs during the stun are now drawn by the shared,
	# source-agnostic BossElectrocutionFieldHost (driven from the boss actor
	# renderer via the central `electric_stun` -> `boss_electric_stun_active`
	# flag), so Lumion's shock looks identical to Ragnarok's and any future
	# electric stun. `_draw_boss_electric_stun` is retained as a fallback
	# reference but intentionally no longer called here.
	if _phase == PHASE_TRAVELING:
		_draw_orb(canvas, _orb_pos + shake_offset, shake_offset)


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


func _draw_mini_spark_flashes(canvas: CanvasItem, shake_offset: Vector2) -> void:
	# Chaotic SCATTERED electric sparks — deliberately NO central orb / ring /
	# flash core. Each short zig-zag bolt jumps between two RANDOM points inside
	# the spark radius (not radiating from one centre), re-rolled per discrete
	# tick and randomly skipped, so the whole thing snaps and scatters like a
	# live short-circuit. A few tiny spark dots flick on/off at random spots.
	for flash in _mini_spark_flashes:
		var life_t: float = clampf(float(flash["timer"]) / MINI_SPARK_FLASH_SECONDS, 0.0, 1.0)  # 1 -> 0
		var center: Vector2 = (flash["pos"] as Vector2) + shake_offset
		var seed_v: float = float(flash["seed"])
		var progress: float = 1.0 - life_t  # 0 -> 1
		var tick: float = floorf(progress * 13.0)  # discrete electric flicker

		for i in range(MINI_SPARK_BOLT_COUNT):
			# Re-roll this bolt each tick; randomly skip some for a flickery scatter.
			if _seeded_unit(seed_v + float(i) * 7.3, tick + 5.0) > 0.66:
				continue
			var rng_base: float = seed_v + float(i) * 3.1 + tick
			var anchor_ang: float = _seeded_unit(rng_base, 1.0) * TAU
			var anchor_rad: float = MINI_SPARK_VISUAL_RADIUS * (0.10 + 0.78 * _seeded_unit(rng_base, 2.0))
			var bolt_start: Vector2 = center + Vector2(cos(anchor_ang), sin(anchor_ang)) * anchor_rad
			var jump_ang: float = _seeded_unit(rng_base, 3.0) * TAU
			var jump_len: float = MINI_SPARK_VISUAL_RADIUS * (0.16 + 0.36 * _seeded_unit(rng_base, 4.0))
			var bolt_end: Vector2 = bolt_start + Vector2(cos(jump_ang), sin(jump_ang)) * jump_len
			var bolt_pts: PackedVector2Array = _build_bolt(bolt_start, bolt_end, rng_base, 3, 8.0)
			var glow: Color = OUTER_ARC_COLORS[i % OUTER_ARC_COLORS.size()]
			canvas.draw_polyline(bolt_pts, Color(glow.r, glow.g, glow.b, 0.40 * life_t), 2.5, true)
			canvas.draw_polyline(bolt_pts, Color(1.0, 1.0, 1.0, 0.88 * life_t), 1.0, true)

		# Tiny scattered spark dots (random flicker) — sparks, not an orb.
		for j in range(MINI_SPARK_DOT_COUNT):
			if _seeded_unit(seed_v + float(j) * 5.7, tick + 11.0) > 0.5:
				continue
			var dot_ang: float = _seeded_unit(seed_v + float(j) * 5.7, tick + 1.0) * TAU
			var dot_rad: float = MINI_SPARK_VISUAL_RADIUS * _seeded_unit(seed_v + float(j) * 5.7, tick + 2.0)
			var dot_pos: Vector2 = center + Vector2(cos(dot_ang), sin(dot_ang)) * dot_rad
			var dot_r: float = 1.0 + _seeded_unit(seed_v + float(j) * 5.7, tick + 3.0) * 1.4
			canvas.draw_circle(dot_pos, dot_r, Color(1.0, 1.0, 0.9, 0.9 * life_t))


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


func _draw_orb(canvas: CanvasItem, pos: Vector2, shake_offset: Vector2) -> void:
	var vr := ORB_VISUAL_RADIUS
	var time_seconds := float(Time.get_ticks_msec()) / 1000.0

	# Trail (blue).
	for i in range(_trail.size()):
		var trail_pos: Vector2 = _trail[i] + shake_offset
		var ratio: float = float(i + 1) / float(maxi(1, _trail.size()))
		canvas.draw_circle(trail_pos, lerpf(4.0, 12.0, ratio), Color(TRAIL_COLOR.r, TRAIL_COLOR.g, TRAIL_COLOR.b, 0.06 + 0.20 * ratio))
		if i > 0:
			var prev_pos: Vector2 = _trail[i - 1] + shake_offset
			canvas.draw_line(prev_pos, trail_pos, Color(0.62, 0.80, 1.0, 0.24 * ratio), maxf(1.0, 3.0 * ratio), true)

	# Floating energy motes (behind the core).
	for p in _energy_particles:
		var lt: float = clampf(float(p["life"]) / maxf(0.01, float(p["max_life"])), 0.0, 1.0)
		var mote_col: Color = p["color"]
		canvas.draw_circle((p["pos"] as Vector2) + shake_offset, maxf(1.0, float(p["size"]) * lt), Color(mote_col.r, mote_col.g, mote_col.b, 0.78 * lt))

	# Multi-layer blue-white energy core (Horus: 2 glows + 3 body + 2 cores).
	var pulse := 1.0 + 0.10 * sin(time_seconds * 5.0 + _visual_seed * TAU)
	var orb_r := vr * 0.40 * pulse
	canvas.draw_circle(pos, orb_r * 1.6, Color(ORB_INNER_COLOR.r, ORB_INNER_COLOR.g, ORB_INNER_COLOR.b, 0.20))
	canvas.draw_circle(pos, orb_r * 1.2, Color(ORB_INNER_COLOR.r, ORB_INNER_COLOR.g, ORB_INNER_COLOR.b, 0.31))
	canvas.draw_circle(pos, orb_r, Color(ORB_INNER_COLOR.r, ORB_INNER_COLOR.g, ORB_INNER_COLOR.b, 0.63))
	canvas.draw_circle(pos, orb_r * 0.75, Color(0.82, 0.92, 1.0, 0.75))
	canvas.draw_circle(pos, orb_r * 0.5, Color(0.86, 0.94, 1.0, 0.86))
	canvas.draw_circle(pos, maxf(2.0, orb_r * 0.35), Color(1.0, 1.0, 1.0, 0.94))
	canvas.draw_circle(pos, maxf(1.0, orb_r * 0.175), Color(1.0, 1.0, 1.0, 0.98))

	# Rotating hexagonal frame + orb->vertex arcs (angle-math rotation, no
	# transform.rotate). Wobble on the mid point keeps the arcs alive.
	var hex_r := vr * 1.15
	var hex_pts := PackedVector2Array()
	for i in range(6):
		var v_ang: float = TAU * float(i) / 6.0 - PI * 0.5 + _orb_rotation
		hex_pts.append(pos + Vector2(cos(v_ang), sin(v_ang)) * hex_r)
	canvas.draw_arc(pos, hex_r * 0.92, 0.0, TAU, 40, Color(ORB_RING_COLOR.r, ORB_RING_COLOR.g, ORB_RING_COLOR.b, 0.5), 1.5, true)
	for i in range(6):
		var a_ang: float = TAU * float(i) / 6.0 - PI * 0.5 + _orb_rotation
		var arc_start := pos + Vector2(cos(a_ang), sin(a_ang)) * (orb_r * 0.9)
		var wobble: float = sin(time_seconds * 8.0 + float(i) * 1.1) * deg_to_rad(5.0)
		var mid_ang: float = a_ang + deg_to_rad(10.0) + wobble
		var mid := pos + Vector2(cos(mid_ang), sin(mid_ang)) * (hex_r * 0.55)
		var arc_pts := PackedVector2Array([arc_start, mid, hex_pts[i]])
		canvas.draw_polyline(arc_pts, Color(ARC_GLOW_COLOR.r, ARC_GLOW_COLOR.g, ARC_GLOW_COLOR.b, 0.35), 3.0, true)
		canvas.draw_polyline(arc_pts, Color(ARC_CORE_COLOR.r, ARC_CORE_COLOR.g, ARC_CORE_COLOR.b, 0.86), 1.0, true)
	for hp in hex_pts:
		canvas.draw_circle(hp, 3.0, Color(0.70, 0.86, 1.0, 0.78))
		canvas.draw_circle(hp, 1.0, Color(1.0, 1.0, 1.0, 0.63))

	# Per-frame outer crackle arcs (blue + faint gold accent).
	var outer_n := 2 + (randi() % 3)
	for _k in range(outer_n):
		var oa := randf_range(0.0, TAU)
		var osr := vr * randf_range(0.8, 1.3)
		var os := pos + Vector2(cos(oa), sin(oa)) * osr
		var oa2 := oa + randf_range(-0.6, 0.6)
		var oer := osr + randf_range(5.0, 12.0)
		var oe := pos + Vector2(cos(oa2), sin(oa2)) * oer
		var oc: Color = OUTER_ARC_COLORS[randi() % OUTER_ARC_COLORS.size()]
		canvas.draw_line(os, oe, Color(oc.r, oc.g, oc.b, 0.85), 1.0, true)
	# Occasional white discharge spark.
	if randf() < 0.6:
		var spark_a := randf_range(0.0, TAU)
		var spark_sr := vr * randf_range(0.6, 1.1)
		var spark_s := pos + Vector2(cos(spark_a), sin(spark_a)) * spark_sr
		var spark_e := pos + Vector2(cos(spark_a), sin(spark_a)) * (spark_sr + randf_range(4.0, 10.0))
		canvas.draw_line(spark_s, spark_e, SPARK_COLORS[randi() % SPARK_COLORS.size()], 1.0, true)


func _draw_explosion(canvas: CanvasItem, center: Vector2) -> void:
	var ratio := clampf(_explosion_timer / EXPLOSION_DURATION_SECONDS, 0.0, 1.0)  # 1 -> 0
	var progress := 1.0 - ratio  # 0 -> 1
	var current_r := _explosion_radius * clampf(progress * 1.1, 0.0, 1.0)
	var flick := floorf(progress * 60.0)  # discrete per-frame re-seed for the web

	# Initial flash (outer blue glow + white centre) — first 40% of the burst.
	if progress < 0.4:
		var flash_f := 1.0 - progress / 0.4
		canvas.draw_circle(center, current_r * 0.9, Color(0.39, 0.70, 1.0, 0.31 * flash_f))
		canvas.draw_circle(center, current_r * 0.5, Color(1.0, 1.0, 1.0, 0.86 * flash_f))

	# Five time-staggered shockwave rings (blue palette, thickness 4 -> 1).
	for ring_idx in range(5):
		var ring_delay := float(ring_idx) * 0.07
		var ring_prog := progress - ring_delay
		if ring_prog <= 0.0:
			continue
		var ring_r := _explosion_radius * minf(1.0, ring_prog * 1.4)
		var ring_a := (0.86 - float(ring_idx) * 0.12) * (1.0 - minf(1.0, ring_prog))
		if ring_r <= 0.0 or ring_a <= 0.0:
			continue
		var ring_w := maxf(1.0, 4.0 - float(ring_idx))
		var rc: Color = RING_COLORS[ring_idx]
		if ring_w >= 2.0:
			canvas.draw_arc(center, ring_r + 2.0, 0.0, TAU, 56, Color(rc.r, rc.g, rc.b, ring_a / 3.0), ring_w + 2.0, true)
		canvas.draw_arc(center, ring_r, 0.0, TAU, 56, Color(rc.r, rc.g, rc.b, ring_a), ring_w, true)

	# Inner energy field.
	canvas.draw_circle(center, current_r * 0.9, Color(0.08, 0.31, 0.71, 0.20 * ratio))
	canvas.draw_circle(center, current_r * 0.5, Color(0.24, 0.55, 0.90, 0.35 * ratio))

	# Lightning web: 12-22 radial bolts (glow 4 / mid 2 / core 1) + circular
	# connections between adjacent bolt endpoints.
	var arc_count := 12 + int(progress * 10.0)
	var web_pts := PackedVector2Array()
	for i in range(arc_count):
		var bolt_seed := _visual_seed + float(i) * 2.1 + flick
		var ang := (float(i) / float(arc_count)) * TAU + (_seeded_unit(bolt_seed, 3.0) - 0.5) * 0.3
		var dir := Vector2(cos(ang), sin(ang))
		var s := center + dir * (current_r * 0.1)
		var e := center + dir * (current_r * lerpf(0.85, 1.15, _seeded_unit(bolt_seed, 7.0)))
		var pts := _build_bolt(s, e, bolt_seed, 4, 14.0)
		web_pts.append(e)
		var glow: Color = OUTER_ARC_COLORS[i % OUTER_ARC_COLORS.size()]
		canvas.draw_polyline(pts, Color(glow.r, glow.g, glow.b, 0.39 * ratio), 4.0, true)
		var mid_c: Color = SPARK_COLORS[i % SPARK_COLORS.size()]
		canvas.draw_polyline(pts, Color(mid_c.r, mid_c.g, mid_c.b, 0.80 * ratio), 2.0, true)
		canvas.draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.92 * ratio), 1.0, true)
	for i in range(web_pts.size()):
		if _seeded_unit(_visual_seed + float(i) * 1.7, flick + 51.0) < 0.7:
			var p1 := web_pts[i]
			var p2 := web_pts[(i + 1) % web_pts.size()]
			var cmid := (p1 + p2) * 0.5 + Vector2(
				(_seeded_unit(_visual_seed + float(i), flick + 5.0) - 0.5) * 16.0,
				(_seeded_unit(_visual_seed + float(i), flick + 9.0) - 0.5) * 16.0
			)
			canvas.draw_polyline(PackedVector2Array([p1, cmid, p2]), Color(0.86, 0.94, 1.0, 0.7 * ratio), 1.4, true)

	# Bright centre core glow (3 layers), fading as the burst ends.
	var core_f := ratio
	canvas.draw_circle(center, maxf(3.0, 18.0 * core_f), Color(0.31, 0.63, 1.0, 0.5 * core_f))
	canvas.draw_circle(center, maxf(2.0, 12.0 * core_f), Color(0.78, 0.90, 1.0, 0.86 * core_f))
	canvas.draw_circle(center, maxf(1.0, 6.0 * core_f), Color(1.0, 1.0, 1.0, core_f))


func _draw_boss_electric_stun(canvas: CanvasItem, shake_offset: Vector2) -> void:
	var center := (_electric_stun_center if _electric_stun_center != Vector2.ZERO else _get_default_boss_center()) + shake_offset
	var now_msec := float(Time.get_ticks_msec())
	var ratio := clampf(_electric_stun_timer / maxf(0.05, _stun_duration_seconds), 0.0, 1.0)
	var alpha := clampf(ratio / 0.16, 0.0, 1.0)
	# Discrete ~16Hz re-seed so the arcs snap frame-to-frame like a live
	# electric discharge instead of smoothly rotating. Matches the Ragnarok
	# stun's tick flicker and the project electric-shader recipe (discrete-time
	# resampling beats sin-based wander for an electric read).
	var tick := float(int(now_msec / 60.0))
	canvas.draw_circle(center, 54.0 + sin(now_msec * 0.01) * 3.0, Color(0.25, 0.75, 1.0, 0.12 * alpha))
	for idx in range(8):
		var seed_a := _seeded_unit(_visual_seed + float(idx) * 5.3, tick)
		var seed_b := _seeded_unit(_visual_seed + float(idx) * 7.1, tick + 13.0)
		var angle_a: float = TAU * (float(idx) / 8.0 + (seed_a - 0.5) * 0.12)
		var angle_b: float = angle_a + 0.62 + seed_b * 0.52
		var reach_a: float = 50.0 + seed_a * 12.0
		var reach_b: float = 50.0 + seed_b * 14.0
		var start := center + Vector2(cos(angle_a) * reach_a, sin(angle_a) * reach_a * 0.36)
		var end := center + Vector2(cos(angle_b) * reach_b, sin(angle_b) * reach_b * 0.36)
		_draw_lightning(canvas, start, end, Color(1.0, 0.96, 0.32, 0.70 * alpha), 1.5, _visual_seed + float(idx) * 5.3, 9.0, tick + float(idx))
	# Per-tick spark dots scattered over the boss for a buzzing electric read.
	for spark_idx in range(4):
		var sx := _seeded_unit(_visual_seed + float(spark_idx) * 3.7, tick + float(spark_idx) * 2.0)
		var sy := _seeded_unit(_visual_seed + float(spark_idx) * 9.1, tick + 5.0)
		var spark_pos := center + Vector2((sx - 0.5) * 96.0, (sy - 0.5) * 38.0)
		canvas.draw_circle(spark_pos, 1.0 + sx * 1.6, Color(1.0, 1.0, 0.85, 0.8 * alpha))


func _draw_particles(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for particle in _explosion_particles:
		var max_life: float = maxf(0.01, float(particle["max_life"]))
		var life_t: float = clampf(float(particle["life"]) / max_life, 0.0, 1.0)
		var pos: Vector2 = (particle["pos"] as Vector2) + shake_offset
		var size: float = float(particle["size"]) * (0.7 + 0.3 * life_t)
		var base: Color = particle.get("color", ORB_INNER_COLOR)
		var alpha: float = (0.72 if int(particle["kind"]) == 0 else 0.6) * life_t
		canvas.draw_circle(pos, size, Color(base.r, base.g, base.b, alpha))


# Zig-zag bolt point builder shared by the explosion lightning web (glow / mid /
# core strokes). Re-seeded per frame by the caller for a crackling flicker.
func _build_bolt(start: Vector2, end: Vector2, seed_value: float, segments: int, jitter: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var delta := end - start
	var normal := delta.orthogonal()
	if normal.length_squared() > 0.001:
		normal = normal.normalized()
	var seg: int = maxi(2, segments)
	for k in range(seg + 1):
		var t := float(k) / float(seg)
		var taper := 1.0 - absf(t * 2.0 - 1.0) * 0.25
		var j := (_seeded_unit(seed_value, float(k) + 1.0) - 0.5) * jitter * taper
		pts.append(start.lerp(end, t) + normal * j)
	return pts


func _draw_lightning(
	canvas: CanvasItem,
	start: Vector2,
	end: Vector2,
	color: Color,
	width: float,
	seed_value: float,
	bend: float,
	flicker_seed: float = -1.0
) -> void:
	var points := PackedVector2Array()
	var delta := end - start
	var normal := delta.orthogonal()
	if normal.length_squared() > 0.001:
		normal = normal.normalized()
	var segments := 4
	# Default: continuous wander keyed off elapsed time (orb / explosion bolts).
	# flicker_seed >= 0 swaps in a discrete per-tick phase so the zig-zag snaps
	# and holds instead of drifting (boss electric-stun arcs).
	var jitter_phase: float = (_elapsed * 13.0) if flicker_seed < 0.0 else flicker_seed
	for idx in range(segments + 1):
		var t := float(idx) / float(segments)
		var jitter := (_seeded_unit(seed_value, float(idx) + jitter_phase) - 0.5) * bend * (1.0 - absf(t * 2.0 - 1.0) * 0.22)
		points.append(start.lerp(end, t) + normal * jitter)
	canvas.draw_polyline(points, color, width, true)


func _get_boss_rect(owner: Object) -> Rect2:
	var boss_pos: Vector2 = _get_owner_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	var boss_w: float = maxf(1.0, float(_get_owner_value(owner, "boss_paddle_width", 100.0)))
	var boss_h: float = maxf(1.0, float(_get_owner_value(owner, "boss_hitbox_height", 40.0)))
	return Rect2(boss_pos, Vector2(boss_w, boss_h))


func _get_default_boss_center() -> Vector2:
	return Vector2(FIELD_WIDTH * 0.5, 45.0)


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
