extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const LingpetAfterglowLeakRenderer := preload("res://scripts/lingpet/lingpet_afterglow_leak_renderer.gd")
const LingpetAfterglowLeakPayloadFactory := preload("res://scripts/lingpet/lingpet_afterglow_leak_payload_factory.gd")

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

# --- Noita-style ballistic liquid spray --------------------------------------
const PARTICLE_MAX := 48          # bounded lightweight budget (jets are removed on landing)
const JET_GRAVITY := 950.0       # px/s^2 pulling the spray back to the floor (fast settle)
const JET_EMIT_SECONDS := 0.20   # liquid is emitted as a brief stream, not 1 pop
const JET_EMIT_INTERVAL := 0.012 # one stream droplet every ~12ms while emitting
const JET_INITIAL_BURST := 4
const JET_SPEED_MIN := 360.0
const JET_SPEED_MAX := 500.0
const JET_SPREAD_RAD := 0.28     # half fan-angle around the upward launch dir
const JET_LIFE := 1.8
const SPLASH_GRAVITY := 520.0
const AMBIENT_INTERVAL := 0.22
const ABSORB_WISP_COUNT := 2
const KIND_JET := 0
const KIND_SPLASH := 1
const KIND_AMBIENT := 2
const KIND_WISP := 3

# --- Persistent floor splatter (the landed liquid that stays "뿌려진" on the
#     ground until the residue is absorbed or seeps away) ----------------------
const MAX_SPLATS := 16

# --- "공명 유체" green-gold luminance palette (textures are white-baked) -------

var _residues: Array[Dictionary] = []
var _particles: Array = []
var _next_residue_id := 0
var _ambient_timer := 0.0
var _last_gain := 0.0
var _trigger_count := 0
var _absorb_flash_timer := 0.0
var _last_absorb_pos := Vector2.ZERO
var _renderer: Object = LingpetAfterglowLeakRenderer.new()


func advance(delta: float, owner: Object, registry: Object, passive_skill: Dictionary, companion_active: bool) -> void:
	var safe_delta: float = maxf(0.0, delta)
	_absorb_flash_timer = maxf(0.0, _absorb_flash_timer - safe_delta)
	if not _is_enabled(passive_skill, companion_active):
		reset_round_transients()
		return
	_renderer.prewarm()
	for index in range(_residues.size() - 1, -1, -1):
		var residue: Dictionary = _residues[index]
		var previous_timer: float = maxf(0.0, float(residue.get("timer", 0.0)))
		var active_delta: float = minf(safe_delta, previous_timer)
		residue["timer"] = maxf(0.0, previous_timer - safe_delta)
		residue["age"] = float(residue.get("age", 0.0)) + active_delta
		residue["absorb_flash"] = maxf(0.0, float(residue.get("absorb_flash", 0.0)) - safe_delta)
		_emit_jet(residue, safe_delta)
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
	_renderer.prewarm()
	var tick_count: int = max(1, int(passive_skill.get("afterglow_tick_count", DEFAULT_TICK_COUNT)))
	var duration: float = maxf(0.35, float(passive_skill.get("afterglow_duration_seconds", DEFAULT_DURATION_SECONDS)))
	var floor_pos: Vector2 = _get_floor_pos(contact_pos)
	# The hit point is where the liquid is flung from; the pool collects on the
	# floor below. The spray arcs UP from here then rains back down to floor_pos.
	var origin: Vector2 = Vector2(
		clampf(contact_pos.x, 18.0, FIELD_WIDTH - 18.0),
		clampf(contact_pos.y, 32.0, floor_pos.y)
	)
	var residue := LingpetAfterglowLeakPayloadFactory.build_residue(
		_next_residue_id,
		floor_pos,
		origin,
		duration,
		total_gauge,
		tick_count,
		float(passive_skill.get("afterglow_absorb_radius", DEFAULT_ABSORB_RADIUS)),
		_stable_seed(contact_pos),
		JET_EMIT_SECONDS,
		ABSORB_FLASH_SECONDS
	)
	_next_residue_id += 1
	_residues.append(residue)
	while _residues.size() > MAX_RESIDUES:
		_residues.remove_at(0)
	# An immediate spit of liquid so the spray reads on the very first frame.
	for _i in range(JET_INITIAL_BURST):
		_emit_jet_droplet(residue)
	return true


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	var visual_time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	_renderer.draw_afterglow(
		canvas,
		shake_offset,
		visual_time_seconds,
		_residues,
		_particles,
		_absorb_flash_timer,
		ABSORB_FLASH_SECONDS,
		_last_absorb_pos,
		DEFAULT_DURATION_SECONDS,
		DEFAULT_ABSORB_RADIUS,
		SEEP_FADE_SECONDS
	)


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
	_renderer.prewarm()


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

func _emit_jet(residue: Dictionary, delta: float) -> void:
	var emit_timer: float = float(residue.get("emit_timer", 0.0))
	if emit_timer <= 0.0 or delta <= 0.0:
		return
	residue["emit_timer"] = maxf(0.0, emit_timer - delta)
	var accum: float = float(residue.get("emit_accum", 0.0)) + delta
	while accum >= JET_EMIT_INTERVAL:
		accum -= JET_EMIT_INTERVAL
		_emit_jet_droplet(residue)
	residue["emit_accum"] = accum


func _emit_jet_droplet(residue: Dictionary) -> void:
	var origin: Vector2 = _as_vector2(residue.get("origin", Vector2.ZERO), Vector2.ZERO)
	var floor_y: float = _as_vector2(residue.get("pos", Vector2.ZERO), Vector2.ZERO).y
	var lean: float = float(residue.get("lean", 0.0))
	var theta: float = lean + randf_range(-JET_SPREAD_RAD, JET_SPREAD_RAD)
	var speed: float = randf_range(JET_SPEED_MIN, JET_SPEED_MAX)
	# Launch UP (y is down), fanned by theta -> a fountain arc that gravity pulls
	# back down to the floor pool.
	var vel := Vector2(sin(theta) * speed, -cos(theta) * speed)
	_add_particle(
		origin + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)),
		vel,
		JET_LIFE,
		randf_range(2.6, 4.4),
		KIND_JET,
		{
			"floor_y": floor_y,
			"pool_id": int(residue.get("id", -1)),
		}
	)


func _spawn_landing_splash(at: Vector2) -> void:
	for _i in range(2):
		_add_particle(
			at + Vector2(randf_range(-3.0, 3.0), 0.0),
			Vector2(randf_range(-34.0, 34.0), randf_range(-78.0, -34.0)),
			randf_range(0.16, 0.32),
			randf_range(1.8, 3.0),
			KIND_SPLASH
		)


func _deposit_splat(pool_id: int, landing_x: float, floor_y: float) -> void:
	if pool_id < 0:
		return
	for residue in _residues:
		if int(residue.get("id", -1)) != pool_id:
			continue
		var splats: Array = residue.get("splats", [])
		var born: float = float(residue.get("age", 0.0))
		# Merge into a nearby existing splat once the band is full so the floor
		# keeps reading as accumulating liquid rather than spawning forever.
		if splats.size() >= MAX_SPLATS:
			var nearest_index: int = -1
			var nearest_dist: float = 1.0e9
			for i in range(splats.size()):
				var d: float = absf(float(splats[i].get("x", 0.0)) - landing_x)
				if d < nearest_dist:
					nearest_dist = d
					nearest_index = i
			if nearest_index >= 0:
				var grown: Dictionary = splats[nearest_index]
				grown["size"] = minf(18.0, float(grown.get("size", 6.0)) + 1.4)
				grown["x"] = lerpf(float(grown.get("x", landing_x)), landing_x, 0.3)
				splats[nearest_index] = grown
			return
		splats.append(LingpetAfterglowLeakPayloadFactory.build_splat(landing_x, floor_y, born))
		residue["splats"] = splats
		return


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
			{"target": target}
		)


func _add_particle(pos: Vector2, vel: Vector2, life: float, size: float, kind: int, params: Dictionary = {}) -> void:
	if _particles.size() >= PARTICLE_MAX:
		return
	_particles.append(LingpetAfterglowLeakPayloadFactory.build_particle(pos, vel, life, size, kind, params))


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
		if kind == KIND_JET:
			vel.y += JET_GRAVITY * delta
			var next_pos: Vector2 = (particle["pos"] as Vector2) + vel * delta
			var floor_y: float = float(particle["floor_y"])
			if vel.y > 0.0 and next_pos.y >= floor_y:
				# The sprayed liquid reaches the floor: splash, then deposit a
				# persistent splat that stays "뿌려진" on the ground.
				_spawn_landing_splash(Vector2(next_pos.x, floor_y))
				_deposit_splat(int(particle["pool_id"]), next_pos.x, floor_y)
				_particles.remove_at(index)
				continue
			particle["vel"] = vel
			particle["pos"] = next_pos
			particle["life"] = life
			_particles[index] = particle
			continue
		if kind == KIND_SPLASH:
			vel.y += SPLASH_GRAVITY * delta
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
	if float(residue.get("age", 0.0)) < 0.12:
		return
	var pool: Vector2 = _as_vector2(residue.get("pos", Vector2.ZERO), Vector2.ZERO)
	var radius: float = maxf(8.0, float(residue.get("absorb_radius", DEFAULT_ABSORB_RADIUS))) * 0.6
	_add_particle(
		pool + Vector2(randf_range(-radius, radius), randf_range(-radius * 0.35, radius * 0.35)),
		Vector2(randf_range(-12.0, 12.0), randf_range(-26.0, -12.0)),
		randf_range(0.45, 0.85),
		randf_range(2.2, 3.6),
		KIND_AMBIENT
	)


# --- Drawing ------------------------------------------------------------------

func _get_floor_pos(contact_pos: Vector2) -> Vector2:
	# The pool collects on the floor band near the player/companion lane, not at
	# the mid-air hit point, so the sprayed liquid always falls down to the ground.
	var ground_y: float = FIELD_HEIGHT - 38.0
	var x: float = clampf(contact_pos.x, 22.0, FIELD_WIDTH - 22.0)
	var y: float = clampf(maxf(contact_pos.y + 16.0, ground_y), 80.0, FIELD_HEIGHT - 26.0)
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
