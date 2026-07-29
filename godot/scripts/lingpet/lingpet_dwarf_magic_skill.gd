extends RefCounted

# Serabi (세라비 / orbi) active skill #2 — 난쟁이마술 / Dwarf Magic.
# Ported from the original PingFighter chronos (키르케) DwarfMagic hero skill
# (downtown/hero_skills.py `DwarfMagic`). The original fires a homing purple
# light-dust projectile at the opponent paddle and, on hit, shrinks that paddle
# to 0.5x for 4s (0.3s shrink-in / 0.3s restore) plus a 50% movement penalty.
#
# As a player-side lingpet skill the projectile flies UP at the BOSS paddle and,
# on hit, shrinks the boss paddle (collision + render, centered) AND slows boss
# movement for a level-scaled duration. Higher effective skill level = stronger shrink,
# longer hold, and stronger slow (per the design owner). Strength/duration come
# from the launch context (catalog *_by_level), falling back to the tables below.
#
# Boss effect is published through OWNER FLAGS (same wiring class as Orosha
# star_coil's boss slow and Koyora puppet_grab's boss scripting). Those flags are
# declared in battle_scene_state.DEFAULT_VALUES and normalized every round in
# ball_round_state.build_common_snapshot. We additionally self-heal the flags on
# an owner-less cancel()/reset() (round-end cleanup deps carry no owner), so the
# shrink/slow can never leak into the next round.

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const DEFAULT_BOSS_PADDLE_WIDTH := 100.0
const DEFAULT_BOSS_HITBOX_HEIGHT := 40.0

# Owner flag keys (declared in battle_scene_state.DEFAULT_VALUES + reset in
# ball_round_state.build_common_snapshot). shrink_scale drives BOTH the centered
# collision shrink (ball_update_context → ball_motion_collision_detector) and the
# centered render shrink (battle_draw_playfield_scene_context → battle_draw_actor_context).
const SHRINK_ACTIVE_KEY := "lingpet_dwarf_magic_shrink_active"
const SHRINK_SCALE_KEY := "lingpet_dwarf_magic_shrink_scale"
const SLOW_ACTIVE_KEY := "lingpet_dwarf_magic_boss_slow_active"
const SLOW_MULTIPLIER_KEY := "lingpet_dwarf_magic_boss_slow_multiplier"

# Projectile: original 10 px/frame upward -> 600 px/s. Speed AND homing strength
# now scale by level (faster + harder-to-dodge at higher skill level). The Lv.3
# values match the previous flat constants so mid-level feel is unchanged.
# PROJ_HIT_PAD mirrors the original ±15px paddle overlap window.
const PROJ_SPEED := 528.0          # Lv.3 baseline / fallback
const PROJ_HOMING_LERP := 3.6      # Lv.3 baseline / fallback
const PROJ_RADIUS := 7.0
const PROJ_HIT_PAD := 15.0
const PROJ_MAX_SECONDS := 2.0
# Lv.1..5: projectile flies faster and homes harder as level rises.
const DEFAULT_PROJ_SPEED_BY_LEVEL: Array[float] = [416.0, 472.0, 528.0, 584.0, 640.0]
const DEFAULT_PROJ_HOMING_BY_LEVEL: Array[float] = [2.4, 3.0, 3.6, 4.2, 4.8]

# Shrink envelope. SHRINK_ANIM/RESTORE mirror the original 0.3s ease in/out; the
# per-level hold is the original 4.0s shrink_timer, generalized to scale by level.
const SHRINK_ANIM_SECONDS := 0.3
const RESTORE_ANIM_SECONDS := 0.3

# Lv.1..5 fallback tables (catalog *_by_level are authoritative at launch).
# Higher level = smaller boss (more shrink), longer hold, stronger slow.
const DEFAULT_SHRINK_SCALE_BY_LEVEL: Array[float] = [0.70, 0.65, 0.60, 0.55, 0.50]
const DEFAULT_HOLD_SECONDS_BY_LEVEL: Array[float] = [2.4, 2.8, 3.2, 3.6, 4.0]
const DEFAULT_SLOW_MULTIPLIER_BY_LEVEL: Array[float] = [0.65, 0.60, 0.55, 0.50, 0.45]

const PARTICLE_MAX := 56
const TRAIL_INTERVAL := 0.03
const CORE_COLOR := Color(0.86, 0.70, 1.0, 1.0)       # bright lavender core
const GLOW_COLOR := Color(0.70, 0.39, 0.86, 0.40)     # purple glow (180,100,220)
const DUST_COLORS: Array[Color] = [
	Color(0.70, 0.39, 0.86), Color(0.78, 0.51, 0.94),
	Color(0.86, 0.62, 1.0), Color(0.62, 0.43, 0.90),
]

# Phases
const PHASE_IDLE := "idle"
const PHASE_FLYING := "flying"
const PHASE_SHRINK_IN := "shrink_in"
const PHASE_HOLD := "hold"
const PHASE_RESTORE := "restore"

var _phase := PHASE_IDLE
var _active_skill_level := 1
var _shrink_target := 0.5
var _hold_seconds := 4.0
var _slow_multiplier := 0.55
var _proj_speed := PROJ_SPEED
var _proj_homing := PROJ_HOMING_LERP
var _phase_timer := 0.0
var _flight_seconds := 0.0
var _proj_pos := Vector2.ZERO
var _proj_vel := Vector2(0.0, -PROJ_SPEED)
var _proj_active := false
var _trail_timer := 0.0
var _aura_pulse := 0.0
var _particles: Array[Dictionary] = []
var _registry: Object = null

# Live owner shrink scale this frame (1.0 = unshrunk). Mirrors the animated
# envelope so the boss eases small/large instead of snapping.
var _current_shrink_scale := 1.0
var _last_owner_active_written := false
var _needs_owner_sync := false

# Test counters / forced inputs.
var _hit_count := 0
var _miss_count := 0
var _force_hit_next := false


func prewarm() -> void:
	pass


func reset() -> void:
	if _last_owner_active_written:
		_needs_owner_sync = true
	_phase = PHASE_IDLE
	_phase_timer = 0.0
	_flight_seconds = 0.0
	_proj_pos = Vector2.ZERO
	_proj_speed = PROJ_SPEED
	_proj_homing = PROJ_HOMING_LERP
	_proj_vel = Vector2(0.0, -PROJ_SPEED)
	_proj_active = false
	_trail_timer = 0.0
	_aura_pulse = 0.0
	_current_shrink_scale = 1.0
	_particles.clear()


func cancel(owner: Object = null, registry: Object = null) -> void:
	if registry != null:
		_registry = registry
	reset()
	if owner != null:
		_sync_owner(owner, false, 1.0)


func can_arm(params: Dictionary) -> bool:
	# Already running (projectile in flight OR boss still shrunk): do not re-cast.
	if _phase != PHASE_IDLE or _needs_owner_sync:
		return false
	if not bool(params.get("ball_active", false)):
		return false
	if not bool(params.get("companion_visible", false)):
		return false
	return true


func launch(origin: Vector2, owner: Object = null, launch_context: Dictionary = {}) -> bool:
	var preserved_force_hit := _force_hit_next
	reset()
	_force_hit_next = preserved_force_hit
	if typeof(launch_context.get("registry", null)) == TYPE_OBJECT and is_instance_valid(launch_context.get("registry")):
		_registry = launch_context.get("registry") as Object
	_active_skill_level = clampi(int(launch_context.get("active_skill_level", launch_context.get("skill_level", 1))), 1, 5)
	_shrink_target = clampf(_resolve_level_float(launch_context, "shrink_scale", DEFAULT_SHRINK_SCALE_BY_LEVEL), 0.2, 1.0)
	_hold_seconds = maxf(0.1, _resolve_level_float(launch_context, "shrink_duration", DEFAULT_HOLD_SECONDS_BY_LEVEL))
	_slow_multiplier = clampf(_resolve_level_float(launch_context, "boss_slow_multiplier", DEFAULT_SLOW_MULTIPLIER_BY_LEVEL), 0.05, 1.0)
	_proj_speed = maxf(60.0, _resolve_level_float(launch_context, "proj_speed", DEFAULT_PROJ_SPEED_BY_LEVEL))
	_proj_homing = maxf(0.1, _resolve_level_float(launch_context, "proj_homing", DEFAULT_PROJ_HOMING_BY_LEVEL))
	var start := origin if origin != Vector2.ZERO else Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - 120.0)
	_proj_pos = start
	_proj_vel = Vector2(0.0, -_proj_speed)
	_proj_active = true
	_phase = PHASE_FLYING
	_flight_seconds = 0.0
	_spawn_dust_burst(_proj_pos, 16, 1.6)
	return true


func update(delta: float, owner: Object, registry: Object = null, _launch_context: Dictionary = {}) -> void:
	if registry != null:
		_registry = registry
	var safe_delta := maxf(0.0, delta)
	_aura_pulse += safe_delta
	if _needs_owner_sync and owner != null:
		_sync_owner(owner, false, 1.0)
	_update_particles(safe_delta)
	match _phase:
		PHASE_FLYING:
			_update_flight(safe_delta, owner)
		PHASE_SHRINK_IN, PHASE_HOLD, PHASE_RESTORE:
			_update_shrink(safe_delta, owner)
		_:
			pass


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	_draw_particles(canvas, shake_offset)
	if _proj_active:
		_draw_projectile(canvas, shake_offset)


func has_visible_effects() -> bool:
	return _proj_active or not _particles.is_empty() or _shrink_window_active() or _needs_owner_sync


func is_active() -> bool:
	return _phase != PHASE_IDLE or _needs_owner_sync


func is_projectile_active() -> bool:
	return _proj_active


func get_snapshot() -> Dictionary:
	return {
		"dwarf_magic_active": is_active(),
		"dwarf_magic_phase": _phase,
		"dwarf_magic_projectile_active": _proj_active,
		"dwarf_magic_shrink_active": _shrink_window_active(),
		"dwarf_magic_shrink_scale": _current_shrink_scale,
		"dwarf_magic_shrink_target": _shrink_target,
		"dwarf_magic_slow_multiplier": _slow_multiplier,
		"dwarf_magic_hold_seconds": _hold_seconds,
		"dwarf_magic_proj_speed": _proj_speed,
		"dwarf_magic_proj_homing": _proj_homing,
		"dwarf_magic_level": _active_skill_level,
		"dwarf_magic_hit_count": _hit_count,
		"dwarf_magic_miss_count": _miss_count,
		"dwarf_magic_particle_count": _particles.size(),
	}


# ---- test accessors -------------------------------------------------------
func get_hit_count_for_tests() -> int:
	return _hit_count


func get_miss_count_for_tests() -> int:
	return _miss_count


func get_phase_for_tests() -> String:
	return _phase


func get_current_shrink_scale_for_tests() -> float:
	return _current_shrink_scale


func set_force_hit_next_for_tests(value: bool) -> void:
	_force_hit_next = value


# ---- flight ---------------------------------------------------------------
func _update_flight(delta: float, owner: Object) -> void:
	if delta <= 0.0:
		return
	_flight_seconds += delta
	var boss_rect := _get_boss_rect(owner)
	var boss_center := boss_rect.get_center()
	# Home the x toward the boss center (level-scaled homing), keep flying up.
	_proj_pos.x = lerpf(_proj_pos.x, boss_center.x, clampf(_proj_homing * delta, 0.0, 1.0))
	_proj_pos += _proj_vel * delta
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = TRAIL_INTERVAL
		_spawn_dust_burst(_proj_pos, 2, 0.7)
	var hit_rect := boss_rect.grow(PROJ_HIT_PAD + PROJ_RADIUS)
	if _force_hit_next or hit_rect.has_point(_proj_pos):
		_force_hit_next = false
		_begin_shrink(owner)
		return
	if _proj_pos.y <= -PROJ_RADIUS or _flight_seconds >= PROJ_MAX_SECONDS:
		_proj_active = false
		_phase = PHASE_IDLE
		_miss_count += 1


func _begin_shrink(owner: Object) -> void:
	_proj_active = false
	_hit_count += 1
	_phase = PHASE_SHRINK_IN
	_phase_timer = 0.0
	_current_shrink_scale = 1.0
	_spawn_dust_burst(_proj_pos, 26, 4.0)
	_play_hit_feedback()
	_apply_owner_state(owner)


# Original parity: smallboyhit.wav on the boss hit (downtown/hero_skills.py).
func _play_hit_feedback() -> void:
	var audio: Object = _get_registry_instance(_registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_lingpet_dwarf_magic_hit"):
		audio.play_lingpet_dwarf_magic_hit()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


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


# ---- shrink envelope ------------------------------------------------------
func _update_shrink(delta: float, owner: Object) -> void:
	if delta > 0.0:
		_phase_timer += delta
	match _phase:
		PHASE_SHRINK_IN:
			var t := clampf(_phase_timer / SHRINK_ANIM_SECONDS, 0.0, 1.0)
			var ease_out := 1.0 - (1.0 - t) * (1.0 - t)
			_current_shrink_scale = lerpf(1.0, _shrink_target, ease_out)
			if t >= 1.0:
				_current_shrink_scale = _shrink_target
				_phase = PHASE_HOLD
				_phase_timer = 0.0
		PHASE_HOLD:
			_current_shrink_scale = _shrink_target
			if _phase_timer >= _hold_seconds:
				_phase = PHASE_RESTORE
				_phase_timer = 0.0
		PHASE_RESTORE:
			var rt := clampf(_phase_timer / RESTORE_ANIM_SECONDS, 0.0, 1.0)
			var ease_in := rt * rt
			_current_shrink_scale = lerpf(_shrink_target, 1.0, ease_in)
			if rt >= 1.0:
				_current_shrink_scale = 1.0
				_phase = PHASE_IDLE
				_phase_timer = 0.0
	_apply_owner_state(owner)


func _shrink_window_active() -> bool:
	return _phase == PHASE_SHRINK_IN or _phase == PHASE_HOLD or _phase == PHASE_RESTORE


# ---- owner sync (self-healing) -------------------------------------------
func _apply_owner_state(owner: Object) -> void:
	var active := _shrink_window_active()
	_sync_owner(owner, active, _current_shrink_scale if active else 1.0)


func _sync_owner(owner: Object, active: bool, shrink_scale: float) -> void:
	if owner == null:
		if active or _last_owner_active_written:
			_needs_owner_sync = true
		return
	owner.set(SHRINK_ACTIVE_KEY, active)
	owner.set(SHRINK_SCALE_KEY, shrink_scale if active else 1.0)
	owner.set(SLOW_ACTIVE_KEY, active)
	owner.set(SLOW_MULTIPLIER_KEY, _slow_multiplier if active else 1.0)
	_last_owner_active_written = active
	_needs_owner_sync = false


# ---- geometry -------------------------------------------------------------
func _get_boss_rect(owner: Object) -> Rect2:
	if owner == null:
		return Rect2(Vector2(FIELD_WIDTH * 0.5 - DEFAULT_BOSS_PADDLE_WIDTH * 0.5, 25.0), Vector2(DEFAULT_BOSS_PADDLE_WIDTH, DEFAULT_BOSS_HITBOX_HEIGHT))
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - DEFAULT_BOSS_PADDLE_WIDTH * 0.5, 25.0))
	var boss_w := maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "boss_paddle_width", DEFAULT_BOSS_PADDLE_WIDTH)))
	var boss_h := maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "boss_hitbox_height", DEFAULT_BOSS_HITBOX_HEIGHT)))
	return Rect2(boss_pos, Vector2(boss_w, boss_h))


func _resolve_level_float(launch_context: Dictionary, key: String, fallback_by_level: Array[float]) -> float:
	var supplied := float(launch_context.get(key, -1.0))
	if supplied > 0.0:
		return supplied
	var index := clampi(_active_skill_level - 1, 0, fallback_by_level.size() - 1)
	return fallback_by_level[index]


# ---- particles + draw -----------------------------------------------------
func _spawn_dust_burst(center: Vector2, count: int, spread: float) -> void:
	for i in range(count):
		if _particles.size() >= PARTICLE_MAX:
			_particles.pop_front()
		var angle := randf() * TAU
		var speed := randf_range(40.0, 150.0) * spread
		_particles.append({
			"pos": center + Vector2(cos(angle), sin(angle)) * randf_range(2.0, 12.0),
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": randf_range(0.3, 0.85),
			"max_life": 0.85,
			"size": randf_range(2.0, 6.0),
			"color": DUST_COLORS[i % DUST_COLORS.size()],
		})


func _update_particles(delta: float) -> void:
	if _particles.is_empty() or delta <= 0.0:
		return
	var write_index := 0
	for particle in _particles:
		var life := float(particle.get("life", 0.0)) - delta
		if life <= 0.0:
			continue
		var pos: Vector2 = particle.get("pos", Vector2.ZERO)
		var vel: Vector2 = particle.get("vel", Vector2.ZERO)
		pos += vel * delta
		vel *= 0.92
		particle["life"] = life
		particle["pos"] = pos
		particle["vel"] = vel
		_particles[write_index] = particle
		write_index += 1
	if write_index < _particles.size():
		_particles.resize(write_index)


func _draw_particles(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for particle in _particles:
		var max_life := maxf(0.01, float(particle.get("max_life", 0.85)))
		var life_t := clampf(float(particle.get("life", 0.0)) / max_life, 0.0, 1.0)
		var alpha := clampf(life_t * 1.2, 0.0, 1.0)
		if alpha <= 0.02:
			continue
		var pos: Vector2 = (particle.get("pos", Vector2.ZERO) as Vector2) + shake_offset
		var size := maxf(1.0, float(particle.get("size", 3.0)) * (0.6 + 0.4 * life_t))
		var color: Color = particle.get("color", DUST_COLORS[0])
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, 0.7 * alpha))
		canvas.draw_circle(pos, maxf(1.0, size * 0.45), Color(1.0, 0.95, 1.0, 0.6 * alpha))


func _draw_projectile(canvas: CanvasItem, shake_offset: Vector2) -> void:
	var pos := _proj_pos + shake_offset
	for ring in range(3, 0, -1):
		var r := PROJ_RADIUS + float(ring) * 4.0
		canvas.draw_circle(pos, r, Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, GLOW_COLOR.a / float(ring)))
	canvas.draw_circle(pos, PROJ_RADIUS, Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, 0.9))
	canvas.draw_circle(pos, maxf(1.0, PROJ_RADIUS * 0.5), Color(1.0, 0.96, 1.0, 0.95))
