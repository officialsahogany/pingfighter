extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const AfterglowFluidTextureCache := preload("res://scripts/effects/afterglow_fluid_texture_cache.gd")

const PASSIVE_ID := "lingpet_afterglow_leak"
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const ABSORB_TICK_SECONDS := 0.10
const DEFAULT_TOTAL_GAUGE := 6.0
const DEFAULT_TICK_COUNT := 6
const DEFAULT_DURATION_SECONDS := 2.8
const DEFAULT_ABSORB_RADIUS := 58.0
const MAX_RESIDUES := 4
const SEEP_FADE_SECONDS := 0.45
const ABSORB_FLASH_SECONDS := 0.26

# --- Visual envelope (decorative only; never gates the absorb gameplay) -------
const BURST_SECONDS := 0.26
const POUR_SECONDS := 0.40
const SPREAD_SECONDS := 0.55
const POOL_APPEAR_SECONDS := 0.14

# --- CPU particle sim ---------------------------------------------------------
const PARTICLE_MAX := 48
const PARTICLE_GRAVITY := 540.0
const BURST_CROWN_COUNT := 7
const BURST_GUSH_COUNT := 4
const BURST_SHARD_COUNT := 2
const AMBIENT_INTERVAL := 0.24
const ABSORB_WISP_COUNT := 2
const KIND_BURST := 0
const KIND_AMBIENT := 1
const KIND_WISP := 2

# --- "공명 유체" green-gold luminance palette (textures are white-baked) -------
const COLOR_GLOW := Color(0.20, 1.0, 0.62)
const COLOR_BODY := Color(0.32, 1.0, 0.72)
const COLOR_CORE := Color(0.88, 1.0, 0.74)
const COLOR_CAUSTIC := Color(0.72, 1.0, 0.78)
const COLOR_RIM := Color(0.82, 1.0, 0.70)
const COLOR_DROPLET_HOT := Color(1.0, 1.0, 0.84)
const COLOR_DROPLET_COOL := Color(0.50, 1.0, 0.70)

var _residues: Array[Dictionary] = []
var _particles: Array = []
var _ambient_timer := 0.0
var _last_gain := 0.0
var _trigger_count := 0
var _absorb_flash_timer := 0.0
var _last_absorb_pos := Vector2.ZERO
var _prewarmed := false


func advance(delta: float, owner: Object, registry: Object, passive_skill: Dictionary, companion_active: bool) -> void:
	var safe_delta: float = maxf(0.0, delta)
	_absorb_flash_timer = maxf(0.0, _absorb_flash_timer - safe_delta)
	if not _is_enabled(passive_skill, companion_active):
		reset_round_transients()
		return
	_ensure_prewarmed()
	for index in range(_residues.size() - 1, -1, -1):
		var residue: Dictionary = _residues[index]
		var previous_timer: float = maxf(0.0, float(residue.get("timer", 0.0)))
		var active_delta: float = minf(safe_delta, previous_timer)
		residue["timer"] = maxf(0.0, previous_timer - safe_delta)
		residue["age"] = float(residue.get("age", 0.0)) + active_delta
		residue["pulse"] = float(residue.get("pulse", 0.0)) + safe_delta
		residue["absorb_flash"] = maxf(0.0, float(residue.get("absorb_flash", 0.0)) - safe_delta)
		if active_delta > 0.0 and _is_player_in_absorb_range(owner, residue):
			_try_absorb_residue(owner, registry, residue, active_delta)
		if float(residue.get("timer", 0.0)) <= 0.0 or float(residue.get("remaining_gauge", 0.0)) <= 0.0:
			_residues.remove_at(index)
	_update_particles(safe_delta)
	_emit_ambient(safe_delta)


func spawn_from_hit(contact_pos: Vector2, passive_skill: Dictionary, companion_active: bool) -> bool:
	if not _is_enabled(passive_skill, companion_active):
		return false
	var total_gauge: float = maxf(0.0, float(passive_skill.get("afterglow_total_gauge", DEFAULT_TOTAL_GAUGE)))
	if total_gauge <= 0.0:
		return false
	_ensure_prewarmed()
	var tick_count: int = max(1, int(passive_skill.get("afterglow_tick_count", DEFAULT_TICK_COUNT)))
	var duration: float = maxf(0.35, float(passive_skill.get("afterglow_duration_seconds", DEFAULT_DURATION_SECONDS)))
	var floor_pos: Vector2 = _get_floor_pos(contact_pos)
	# Lift the burst origin so there is always a readable cascade down to the
	# floor pool: the smack flings the fluid up, then it pours back down. The
	# companion patrols the floor lane, so without this the "흘러내림" would be
	# only a few pixels tall.
	var origin_y: float = clampf(minf(contact_pos.y, floor_pos.y - 54.0), 40.0, floor_pos.y - 10.0)
	var origin: Vector2 = Vector2(clampf(contact_pos.x, 18.0, FIELD_WIDTH - 18.0), origin_y)
	var residue := {
		"pos": floor_pos,
		"origin": origin,
		"timer": duration,
		"duration": duration,
		"age": 0.0,
		"pulse": 0.0,
		"remaining_gauge": total_gauge,
		"total_gauge": total_gauge,
		"tick_gain": total_gauge / float(tick_count),
		"absorb_accum": 0.0,
		"absorb_radius": maxf(8.0, float(passive_skill.get("afterglow_absorb_radius", DEFAULT_ABSORB_RADIUS))),
		"seed": _stable_seed(contact_pos),
		"absorb_flash": ABSORB_FLASH_SECONDS,
	}
	_residues.append(residue)
	while _residues.size() > MAX_RESIDUES:
		_residues.remove_at(0)
	_spawn_burst(origin, floor_pos)
	return true


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	var now_msec: int = Time.get_ticks_msec()
	for residue in _residues:
		_draw_residue(canvas, residue, shake_offset, now_msec)
	_draw_particles(canvas, shake_offset)
	if _absorb_flash_timer > 0.0 and _last_absorb_pos != Vector2.ZERO:
		var ratio: float = clampf(_absorb_flash_timer / ABSORB_FLASH_SECONDS, 0.0, 1.0)
		var flash_pos: Vector2 = _last_absorb_pos + shake_offset
		_blit(canvas, AfterglowFluidTextureCache.get_glow_texture(), flash_pos, lerpf(20.0, 46.0, 1.0 - ratio), lerpf(20.0, 46.0, 1.0 - ratio), COLOR_DROPLET_HOT, 0.36 * ratio)
		canvas.draw_arc(flash_pos, lerpf(10.0, 32.0, 1.0 - ratio), 0.0, TAU, 36, Color(0.90, 1.0, 0.70, 0.55 * ratio), 2.0, true)


func reset_all() -> void:
	_residues.clear()
	_particles.clear()
	_ambient_timer = 0.0
	_last_gain = 0.0
	_trigger_count = 0
	_absorb_flash_timer = 0.0
	_last_absorb_pos = Vector2.ZERO


func reset_round_transients() -> void:
	_residues.clear()
	_particles.clear()
	_ambient_timer = 0.0
	_absorb_flash_timer = 0.0
	_last_absorb_pos = Vector2.ZERO


func has_visible_effects() -> bool:
	return not _residues.is_empty() or not _particles.is_empty() or _absorb_flash_timer > 0.0


func prewarm() -> void:
	_ensure_prewarmed()


func get_snapshot() -> Dictionary:
	var first_pos := Vector2.ZERO
	var first_remaining := 0.0
	var first_timer := 0.0
	if not _residues.is_empty():
		var first: Dictionary = _residues[0]
		first_pos = _as_vector2(first.get("pos", Vector2.ZERO), Vector2.ZERO)
		first_remaining = float(first.get("remaining_gauge", 0.0))
		first_timer = float(first.get("timer", 0.0))
	return {
		"afterglow_leak_active_count": _residues.size(),
		"afterglow_leak_last_gain": _last_gain,
		"afterglow_leak_trigger_count": _trigger_count,
		"afterglow_leak_first_pos": first_pos,
		"afterglow_leak_first_remaining_gauge": first_remaining,
		"afterglow_leak_first_timer": first_timer,
	}


func get_residue_count_for_tests() -> int:
	return _residues.size()


func get_particle_count_for_tests() -> int:
	return _particles.size()


func _try_absorb_residue(owner: Object, registry: Object, residue: Dictionary, delta: float) -> bool:
	if owner == null:
		return false
	var gauge_max: float = maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "special_gauge_max", 500.0)))
	var current_gauge: float = clampf(float(BattleSceneOwnerReader.get_value(owner, "special_gauge", 0.0)), 0.0, gauge_max)
	if current_gauge >= gauge_max:
		return false
	residue["absorb_accum"] = float(residue.get("absorb_accum", 0.0)) + maxf(0.0, delta)
	var did_absorb := false
	while float(residue.get("absorb_accum", 0.0)) >= ABSORB_TICK_SECONDS:
		residue["absorb_accum"] = float(residue.get("absorb_accum", 0.0)) - ABSORB_TICK_SECONDS
		var remaining: float = maxf(0.0, float(residue.get("remaining_gauge", 0.0)))
		if remaining <= 0.0:
			break
		current_gauge = clampf(float(BattleSceneOwnerReader.get_value(owner, "special_gauge", 0.0)), 0.0, gauge_max)
		if current_gauge >= gauge_max:
			break
		var applied_gain: float = minf(gauge_max - current_gauge, minf(remaining, maxf(0.0, float(residue.get("tick_gain", 0.0)))))
		if applied_gain <= 0.0:
			break
		owner.set("special_gauge", current_gauge + applied_gain)
		residue["remaining_gauge"] = remaining - applied_gain
		residue["absorb_flash"] = ABSORB_FLASH_SECONDS
		_last_gain = applied_gain
		_trigger_count += 1
		_last_absorb_pos = _as_vector2(residue.get("pos", Vector2.ZERO), Vector2.ZERO)
		_absorb_flash_timer = ABSORB_FLASH_SECONDS
		_spawn_absorb_wisps(owner, residue)
		_trigger_gauge_feedback(registry)
		did_absorb = true
		if float(residue.get("remaining_gauge", 0.0)) <= 0.0:
			break
	return did_absorb


func _is_player_in_absorb_range(owner: Object, residue: Dictionary) -> bool:
	if owner == null:
		return false
	var pos: Vector2 = _as_vector2(residue.get("pos", Vector2.ZERO), Vector2.ZERO)
	var player_rect := _get_player_rect(owner)
	var closest := Vector2(
		clampf(pos.x, player_rect.position.x, player_rect.position.x + player_rect.size.x),
		clampf(pos.y, player_rect.position.y, player_rect.position.y + player_rect.size.y)
	)
	var radius: float = maxf(1.0, float(residue.get("absorb_radius", DEFAULT_ABSORB_RADIUS)))
	return closest.distance_to(pos) <= radius


func _get_player_rect(owner: Object) -> Rect2:
	var player_size := Vector2(
		maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", 155.0))),
		maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", 50.0)))
	)
	var fallback_pos := Vector2(FIELD_WIDTH * 0.5 - player_size.x * 0.5, FIELD_HEIGHT - player_size.y)
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", fallback_pos)
	return Rect2(player_pos, player_size)


# --- Particle simulation ------------------------------------------------------

func _spawn_burst(origin: Vector2, floor_pos: Vector2) -> void:
	# Bottle-shatter crown: liquid bursts up-and-out then rains back via gravity.
	for i in range(BURST_CROWN_COUNT):
		var crown_angle: float = -PI * 0.5 + (randf() - 0.5) * PI * 1.32
		var crown_speed: float = randf_range(150.0, 350.0)
		_add_particle(
			origin + Vector2(randf_range(-7.0, 7.0), randf_range(-4.0, 4.0)),
			Vector2(cos(crown_angle), sin(crown_angle)) * crown_speed,
			randf_range(0.30, 0.58),
			randf_range(3.2, 6.8),
			KIND_BURST
		)
	# Low gush: fast, near-horizontal spray that slaps outward along the floor.
	for j in range(BURST_GUSH_COUNT):
		var side: float = -1.0 if (j % 2 == 0) else 1.0
		var tilt_down: float = randf_range(0.0, 0.34)  # small downward lean (y is down)
		var gush_speed: float = randf_range(170.0, 280.0)
		_add_particle(
			origin + Vector2(randf_range(-5.0, 5.0), randf_range(0.0, 8.0)),
			Vector2(side * cos(tilt_down) * gush_speed, sin(tilt_down) * gush_speed * 0.6),
			randf_range(0.26, 0.46),
			randf_range(2.6, 5.0),
			KIND_BURST
		)
	# A few bright, larger shards to sell the shatter snap.
	for k in range(BURST_SHARD_COUNT):
		var shard_angle: float = -PI * 0.5 + (randf() - 0.5) * PI * 0.9
		_add_particle(
			origin,
			Vector2(cos(shard_angle), sin(shard_angle)) * randf_range(260.0, 400.0),
			randf_range(0.22, 0.36),
			randf_range(5.0, 8.0),
			KIND_BURST
		)
	# Seed a couple of motes at the floor pool so it reads as filling instantly.
	for _m in range(2):
		_add_particle(
			floor_pos + Vector2(randf_range(-12.0, 12.0), randf_range(-3.0, 3.0)),
			Vector2(randf_range(-10.0, 10.0), randf_range(-22.0, -8.0)),
			randf_range(0.4, 0.7),
			randf_range(2.4, 3.8),
			KIND_AMBIENT
		)


func _spawn_absorb_wisps(owner: Object, residue: Dictionary) -> void:
	var pool: Vector2 = _as_vector2(residue.get("pos", Vector2.ZERO), Vector2.ZERO)
	var target: Vector2 = _get_player_rect(owner).get_center()
	for _i in range(ABSORB_WISP_COUNT):
		var spawn := pool + Vector2(randf_range(-22.0, 22.0), randf_range(-6.0, 6.0))
		var to_target: Vector2 = (target - spawn)
		var dir: Vector2 = to_target.normalized() if to_target.length_squared() > 0.01 else Vector2(0.0, 1.0)
		_add_particle(
			spawn,
			dir * randf_range(120.0, 200.0) + Vector2(randf_range(-26.0, 26.0), 0.0),
			randf_range(0.22, 0.40),
			randf_range(2.6, 4.6),
			KIND_WISP,
			target
		)


func _add_particle(pos: Vector2, vel: Vector2, life: float, size: float, kind: int, target: Vector2 = Vector2.ZERO) -> void:
	if _particles.size() >= PARTICLE_MAX:
		return
	_particles.append({
		"pos": pos,
		"vel": vel,
		"life": life,
		"max_life": maxf(0.01, life),
		"size": size,
		"kind": kind,
		"target": target,
	})


func _update_particles(delta: float) -> void:
	if delta <= 0.0 or _particles.is_empty():
		return
	for index in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[index]
		var life: float = float(particle["life"]) - delta
		if life <= 0.0:
			_particles.remove_at(index)
			continue
		var vel: Vector2 = particle["vel"]
		var kind: int = int(particle["kind"])
		if kind == KIND_BURST:
			vel.y += PARTICLE_GRAVITY * delta
		elif kind == KIND_AMBIENT:
			vel.y -= 24.0 * delta
			vel *= 0.90
		else:
			var target: Vector2 = particle["target"]
			var to_target: Vector2 = target - (particle["pos"] as Vector2)
			if to_target.length_squared() > 1.0:
				vel += to_target.normalized() * 1500.0 * delta
			vel *= 0.86
			if to_target.length() <= 16.0:
				life = minf(life, 0.05)
		particle["vel"] = vel
		particle["pos"] = (particle["pos"] as Vector2) + vel * delta
		particle["life"] = life
		_particles[index] = particle


func _emit_ambient(delta: float) -> void:
	if _residues.is_empty() or delta <= 0.0:
		return
	_ambient_timer -= delta
	if _ambient_timer > 0.0:
		return
	_ambient_timer = AMBIENT_INTERVAL
	var residue: Dictionary = _residues[_residues.size() - 1]
	if float(residue.get("age", 0.0)) < BURST_SECONDS:
		return
	var pool: Vector2 = _as_vector2(residue.get("pos", Vector2.ZERO), Vector2.ZERO)
	var radius: float = maxf(8.0, float(residue.get("absorb_radius", DEFAULT_ABSORB_RADIUS))) * 0.6
	_add_particle(
		pool + Vector2(randf_range(-radius, radius), randf_range(-radius * 0.4, radius * 0.4)),
		Vector2(randf_range(-12.0, 12.0), randf_range(-26.0, -12.0)),
		randf_range(0.45, 0.85),
		randf_range(2.2, 3.6),
		KIND_AMBIENT
	)


# --- Drawing ------------------------------------------------------------------

func _draw_residue(canvas: CanvasItem, residue: Dictionary, shake_offset: Vector2, now_msec: int) -> void:
	var pool: Vector2 = _as_vector2(residue.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var origin: Vector2 = _as_vector2(residue.get("origin", residue.get("pos", Vector2.ZERO)), pool) + shake_offset
	var duration: float = maxf(0.01, float(residue.get("duration", DEFAULT_DURATION_SECONDS)))
	var timer: float = clampf(float(residue.get("timer", 0.0)), 0.0, duration)
	var age: float = float(residue.get("age", 0.0))
	var life_ratio: float = clampf(timer / duration, 0.0, 1.0)
	var seep_ratio: float = clampf(timer / SEEP_FADE_SECONDS, 0.0, 1.0)
	var remaining_ratio: float = clampf(float(residue.get("remaining_gauge", 0.0)) / maxf(0.01, float(residue.get("total_gauge", 1.0))), 0.0, 1.0)
	var alpha: float = minf(life_ratio, seep_ratio) * (0.42 + 0.58 * remaining_ratio)
	if alpha <= 0.01:
		return

	var time_seconds: float = float(now_msec) / 1000.0
	var phase_seed: float = float(residue.get("seed", 0.0))
	var absorb_ratio: float = clampf(float(residue.get("absorb_flash", 0.0)) / ABSORB_FLASH_SECONDS, 0.0, 1.0)
	var appear: float = clampf(age / POOL_APPEAR_SECONDS, 0.0, 1.0)
	var spread: float = 0.5 + 0.5 * _ease_out_back(clampf(age / SPREAD_SECONDS, 0.0, 1.0))
	var breathe: float = 0.94 + 0.06 * sin(time_seconds * 2.4 + phase_seed)

	var radius: float = maxf(8.0, float(residue.get("absorb_radius", DEFAULT_ABSORB_RADIUS)))
	var rx: float = radius * 0.80 * spread * breathe
	var ry: float = rx * 0.34  # flat, ground-hugging puddle (not a round disc)
	var pool_a: float = alpha * appear

	# 1) Liquid column pouring down from the burst point into the floor pool.
	_draw_pour(canvas, residue, origin, pool, age, alpha, time_seconds)

	# 2) Ambient bloom halo (the "발광" luminance bed under the fluid).
	_blit(canvas, AfterglowFluidTextureCache.get_glow_texture(), pool, rx * 1.55, ry * 2.6, COLOR_GLOW, pool_a * (0.30 + 0.14 * absorb_ratio))

	# 3) Creeping tongues so the fluid spreads/flows sideways along the floor
	#    instead of reading as one clean disc.
	_draw_tongues(canvas, pool, rx, ry, spread, phase_seed, time_seconds, pool_a)

	# 4) FILLED luminous body. The glow profile fills the whole ellipse so the
	#    pool reads as a solid pour of light, NOT a hollow ring.
	_blit(canvas, AfterglowFluidTextureCache.get_glow_texture(), pool, rx, ry, COLOR_BODY, pool_a * 0.64)
	_blit(canvas, AfterglowFluidTextureCache.get_body_texture(), pool, rx * 0.92, ry * 0.92, COLOR_BODY, pool_a * 0.5)
	_blit(canvas, AfterglowFluidTextureCache.get_body_texture(), pool, rx * 0.46, ry * 0.52, COLOR_CORE, pool_a * (0.44 + 0.18 * absorb_ratio))

	# 5) Flowing caustic veins (two opposite scrolls -> moving, living light).
	var caustic_breathe: float = 1.0 + 0.08 * sin(time_seconds * 1.5 + phase_seed)
	_blit(canvas, AfterglowFluidTextureCache.get_caustic_texture(), pool + Vector2(sin(time_seconds * 1.1 + phase_seed) * 4.0, 0.0), rx * 0.9 * caustic_breathe, ry * 0.9 * caustic_breathe, COLOR_CAUSTIC, pool_a * 0.52)
	_blit(canvas, AfterglowFluidTextureCache.get_caustic_texture(), pool + Vector2(-sin(time_seconds * 0.8 + phase_seed) * 4.0, 0.0), rx * 0.64, ry * 0.64, Color(0.95, 1.0, 0.88), pool_a * 0.36)

	# 6) Subtle bright front lip only (a flat highlight, never a full rim ring).
	_blit(canvas, AfterglowFluidTextureCache.get_body_texture(), pool + Vector2(0.0, ry * 0.46), rx * 0.72, ry * 0.30, COLOR_RIM, pool_a * 0.30)

	# 7) Early burst flash crown at the origin (bottle shatter snap).
	if age < BURST_SECONDS:
		var burst_t: float = 1.0 - clampf(age / BURST_SECONDS, 0.0, 1.0)
		var burst_r: float = lerpf(14.0, 54.0, 1.0 - burst_t)
		_blit(canvas, AfterglowFluidTextureCache.get_glow_texture(), origin, burst_r, burst_r, COLOR_DROPLET_HOT, 0.5 * burst_t)
		canvas.draw_arc(origin, burst_r * 0.7, 0.0, TAU, 30, Color(0.92, 1.0, 0.76, 0.6 * burst_t), 2.0, true)


func _draw_pour(canvas: CanvasItem, residue: Dictionary, origin: Vector2, pool: Vector2, age: float, alpha: float, time_seconds: float) -> void:
	var span: float = pool.y - origin.y
	if span <= 4.0:
		return
	var pour_t: float = clampf(age / POUR_SECONDS, 0.0, 1.0)
	var residue_seed: float = float(residue.get("seed", 0.0))
	var y_top: float = origin.y
	var y_bot: float = lerpf(origin.y, pool.y, _ease_out_quad(pour_t)) if pour_t < 1.0 else pool.y
	if y_bot - y_top <= 3.0:
		return
	# After the head lands the column thins into a faint sustained trickle.
	var sustain: float = lerpf(1.0, 0.34, pour_t)
	var w_top: float = lerpf(4.0, 2.0, pour_t)
	var w_bot: float = lerpf(8.0, 3.0, pour_t)

	# Soft luminous glow behind the falling sheet.
	var streak: Texture2D = AfterglowFluidTextureCache.get_streak_texture()
	if streak != null:
		var gw: float = maxf(w_bot, w_top) + 5.0
		var gx: float = lerpf(origin.x, pool.x, 0.5)
		canvas.draw_texture_rect(
			streak,
			Rect2(Vector2(gx - gw, y_top), Vector2(gw * 2.0, y_bot - y_top)),
			false,
			Color(COLOR_BODY.r, COLOR_BODY.g, COLOR_BODY.b, alpha * 0.46 * sustain)
		)

	# Wobbling, tapered liquid ribbon (a coherent stream, not thin hairs).
	var seg: int = 6
	var left_edge: PackedVector2Array = PackedVector2Array()
	var right_edge: PackedVector2Array = PackedVector2Array()
	for s in range(seg + 1):
		var t: float = float(s) / float(seg)
		var y: float = lerpf(y_top, y_bot, t)
		var cx: float = lerpf(origin.x, pool.x, t) + sin(time_seconds * 5.0 + residue_seed + t * 6.0) * 2.6 * (1.0 - t)
		var w: float = lerpf(w_top, w_bot, t)
		left_edge.append(Vector2(cx - w, y))
		right_edge.append(Vector2(cx + w, y))
	var ribbon: PackedVector2Array = PackedVector2Array()
	for p in left_edge:
		ribbon.append(p)
	for s in range(right_edge.size() - 1, -1, -1):
		ribbon.append(right_edge[s])
	canvas.draw_colored_polygon(ribbon, Color(COLOR_CORE.r, COLOR_CORE.g, COLOR_CORE.b, alpha * 0.78 * sustain))

	# Bright falling head bead while still pouring.
	if pour_t < 1.0:
		var head: Vector2 = Vector2(pool.x, y_bot)
		_blit(canvas, AfterglowFluidTextureCache.get_droplet_texture(), head, w_bot + 3.0, w_bot + 3.0, COLOR_DROPLET_HOT, alpha * 0.95)


func _draw_tongues(canvas: CanvasItem, pool: Vector2, rx: float, ry: float, spread: float, residue_seed: float, time_seconds: float, pool_a: float) -> void:
	if pool_a <= 0.02:
		return
	var body: Texture2D = AfterglowFluidTextureCache.get_body_texture()
	if body == null:
		return
	# Two long side tongues + two shorter offset lobes, all flat (no rotation),
	# wobbling and growing with the spread so the puddle creeps outward.
	for k in range(4):
		var side: float = -1.0 if (k % 2 == 0) else 1.0
		var lane: float = 1.0 if k < 2 else 0.55
		var wob: float = 0.7 + 0.3 * sin(time_seconds * 1.6 + residue_seed + float(k) * 1.3)
		var reach: float = rx * (0.55 + 0.7 * spread) * lane * wob
		if reach <= 2.0:
			continue
		var lobe_cx: float = pool.x + side * reach * 0.6
		var lobe_y: float = pool.y + ry * (0.1 + 0.16 * sin(time_seconds * 1.2 + residue_seed + float(k) * 2.0))
		var lobe_w: float = reach * 0.62
		var lobe_h: float = ry * (0.62 if k < 2 else 0.5)
		_blit(canvas, body, Vector2(lobe_cx, lobe_y), lobe_w, lobe_h, COLOR_BODY, pool_a * 0.34)


func _draw_particles(canvas: CanvasItem, shake_offset: Vector2) -> void:
	if _particles.is_empty():
		return
	var tex: Texture2D = AfterglowFluidTextureCache.get_droplet_texture()
	if tex == null:
		return
	for particle in _particles:
		var max_life: float = maxf(0.01, float(particle["max_life"]))
		var life_t: float = clampf(float(particle["life"]) / max_life, 0.0, 1.0)
		var kind: int = int(particle["kind"])
		var alpha: float = clampf(life_t * 1.4, 0.0, 1.0) if kind == KIND_BURST else life_t
		if alpha <= 0.02:
			continue
		var size: float = float(particle["size"]) * (0.65 + 0.35 * life_t)
		var pos: Vector2 = (particle["pos"] as Vector2) + shake_offset
		var color: Color
		if kind == KIND_BURST:
			color = Color(COLOR_DROPLET_HOT.r, COLOR_DROPLET_HOT.g, COLOR_DROPLET_HOT.b, alpha * 0.92)
		elif kind == KIND_WISP:
			color = Color(0.78, 1.0, 0.72, alpha * 0.9)
		else:
			color = Color(COLOR_DROPLET_COOL.r, COLOR_DROPLET_COOL.g, COLOR_DROPLET_COOL.b, alpha * 0.55)
		canvas.draw_texture_rect(tex, Rect2(pos - Vector2(size, size), Vector2(size * 2.0, size * 2.0)), false, color)


func _blit(canvas: CanvasItem, tex: Texture2D, center: Vector2, rx: float, ry: float, color: Color, blit_alpha: float) -> void:
	if tex == null or rx <= 0.5 or ry <= 0.5 or blit_alpha <= 0.0:
		return
	canvas.draw_texture_rect(
		tex,
		Rect2(center - Vector2(rx, ry), Vector2(rx * 2.0, ry * 2.0)),
		false,
		Color(color.r, color.g, color.b, clampf(blit_alpha, 0.0, 1.0))
	)


func _ease_out_back(x: float) -> float:
	var clamped: float = clampf(x, 0.0, 1.0)
	var s := 1.70158
	var u: float = clamped - 1.0
	return 1.0 + (s + 1.0) * pow(u, 3.0) + s * pow(u, 2.0)


func _ease_out_quad(x: float) -> float:
	var clamped: float = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - clamped) * (1.0 - clamped)


func _ensure_prewarmed() -> void:
	if _prewarmed:
		return
	AfterglowFluidTextureCache.prewarm()
	_prewarmed = true


func _get_floor_pos(contact_pos: Vector2) -> Vector2:
	var x: float = clampf(contact_pos.x, 22.0, FIELD_WIDTH - 22.0)
	var y: float = clampf(contact_pos.y + 24.0, 80.0, FIELD_HEIGHT - 34.0)
	return Vector2(x, y)


func _stable_seed(pos: Vector2) -> float:
	return fmod(absf(pos.x * 0.071 + pos.y * 0.037), TAU)


func _is_enabled(passive_skill: Dictionary, companion_active: bool) -> bool:
	return companion_active and str(passive_skill.get("id", "")) == PASSIVE_ID


func _trigger_gauge_feedback(registry: Object) -> void:
	var feedback: Object = _get_registry_instance(registry, "battle_feedback_state")
	if feedback != null and feedback.has_method("trigger_gauge_flash"):
		feedback.trigger_gauge_flash()
	var orb_hud_state: Object = _get_registry_instance(registry, "orb_hud_state")
	if orb_hud_state != null and orb_hud_state.has_method("trigger_gauge_spin"):
		orb_hud_state.trigger_gauge_spin(Time.get_ticks_msec())


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


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value as Vector2
	return fallback
