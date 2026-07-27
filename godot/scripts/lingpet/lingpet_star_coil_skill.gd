extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const LingpetStarCoilRenderer := preload("res://scripts/lingpet/lingpet_star_coil_renderer.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const DEFAULT_BOSS_PADDLE_WIDTH := 100.0
const DEFAULT_BOSS_HITBOX_HEIGHT := 40.0
const PHASE_IDLE := "idle"
const PHASE_ROLL_TO_WALL := "roll_to_wall"
const PHASE_CLIMB := "climb"
const PHASE_LUNGE := "lunge"
const PHASE_BIND := "bind"
const PHASE_CROSS := "cross"
const PHASE_DESCEND := "descend"
const BODY_SIZE := 26.0
const WALL_OFFSET := 18.0
const ROLL_SPEED_PER_FRAME := 11.0
const CLIMB_SPEED_PER_FRAME := 8.4
const LUNGE_SPEED_PER_FRAME := 10.5
const CROSS_SPEED_PER_FRAME := 12.0
const DESCEND_SPEED_PER_FRAME := 8.6
const LUNGE_TIMEOUT_FRAMES := 90.0
# Fallback only; catalog slow_duration_by_level is authoritative at launch time.
const SLOW_DURATION_BY_LEVEL := [1.5, 2.0, 2.5, 3.0, 3.5]
const DEFAULT_SLOW_MULTIPLIER := 0.4
const BIND_DASH_BLOCK_MIN_LEVEL := 3
const BIND_SKILL_CD_FREEZE_MIN_LEVEL := 5
const SLOW_ACTIVE_KEY := "lingpet_star_coil_boss_slow_active"
const SLOW_MULTIPLIER_KEY := "lingpet_star_coil_boss_slow_multiplier"
const DASH_BLOCK_KEY := "lingpet_star_coil_block_boss_dash"
const SKILL_CD_FREEZE_KEY := "lingpet_star_coil_freeze_boss_skill_cd"
const TRAIL_MAX_POINTS := 14
const SPARK_MAX := 56
# Colorful stars sprayed off the rolling Orosha body. ROLL_STAR_RATE is per-second
# (framerate-normalized via an accumulator); gravity + drag give a "fling then arc"
# feel so the stars spit off the body and fall away instead of drifting flat.
const ROLL_STAR_RATE := 48.0
const SPARK_GRAVITY := 130.0
const SPARK_DRAG := 0.90
# Pretty multi-hue palette. Violet + gold carry the Orosha constellation identity;
# the rest add the "색깔이 이쁜" candy-star variety the request asks for.
const STAR_COLORS: Array[Color] = [
	Color(1.00, 0.84, 0.36),  # gold
	Color(1.00, 0.58, 0.86),  # candy pink
	Color(0.46, 0.90, 1.00),  # cyan
	Color(0.74, 0.62, 1.00),  # violet (identity)
	Color(0.62, 1.00, 0.78),  # mint
	Color(1.00, 0.72, 0.46),  # peach
	Color(0.86, 0.93, 1.00),  # ice white
]

const BIND_SHEET_FRAME_COUNT := 16
const BIND_SHEET_FPS := 14.0

var _phase := PHASE_IDLE
var _pos := Vector2.ZERO
var _origin := Vector2.ZERO
var _ground_y := FIELD_HEIGHT - BODY_SIZE
var _wall_x := BODY_SIZE * 0.5 + WALL_OFFSET
var _opposite_wall_x := FIELD_WIDTH - (BODY_SIZE * 0.5 + WALL_OFFSET)
var _corner_y := 54.0
var _bind_anchor := Vector2.ZERO
var _bind_timer := 0.0
var _bind_duration := SLOW_DURATION_BY_LEVEL[0]
var _bind_elapsed := 0.0
var _active_skill_level := 1
var _slow_multiplier := DEFAULT_SLOW_MULTIPLIER
var _lunge_frames := 0.0
var _elapsed := 0.0
var _trail: Array[Vector2] = []
var _sparks: Array[Dictionary] = []
var _spark_emit_accum := 0.0
var _spark_seed := 0.0
var _last_can_arm_reason := "idle"
var _last_wall_side := ""
var _last_opposite_wall_side := ""
var _last_boss_center := Vector2.ZERO
var _last_slow_active_written := false
var _needs_owner_slow_sync := false
# True while the BIND constrict squish SFX is playing. Drives a one-shot play on bind
# start and a single stop on every bind-exit path (release / retire / cancel) so the
# ~6.5s wet squish does not trail past the 1.5~3.5s bind into the roll-away.
var _bind_audio_active := false
# True while the starmoving loop SFX is playing. One-shot start when Orosha enters a
# moving phase (roll/climb/lunge/cross/descend) and a single stop on every exit path
# (bind / idle / retire / cancel) so the loop never trails past the journey.
var _move_audio_active := false
var _renderer: Object = LingpetStarCoilRenderer.new()


func prewarm() -> void:
	_renderer.prewarm()


func reset() -> void:
	if _last_slow_active_written:
		_needs_owner_slow_sync = true
	_phase = PHASE_IDLE
	_pos = Vector2.ZERO
	_origin = Vector2.ZERO
	_ground_y = FIELD_HEIGHT - BODY_SIZE
	_wall_x = BODY_SIZE * 0.5 + WALL_OFFSET
	_opposite_wall_x = FIELD_WIDTH - (BODY_SIZE * 0.5 + WALL_OFFSET)
	_corner_y = 54.0
	_bind_anchor = Vector2.ZERO
	_bind_timer = 0.0
	_bind_duration = _get_slow_duration_for_level(_active_skill_level)
	_bind_elapsed = 0.0
	_lunge_frames = 0.0
	_elapsed = 0.0
	_trail.clear()
	_sparks.clear()
	_spark_emit_accum = 0.0
	_spark_seed = 0.0
	_bind_audio_active = false
	_move_audio_active = false


func cancel(owner: Object = null, registry: Object = null) -> void:
	_stop_bind_audio(registry)
	_stop_move_audio(registry)
	reset()
	if owner != null:
		_sync_owner_slow(owner, false)


func can_arm(params: Dictionary) -> bool:
	if is_active():
		_last_can_arm_reason = "already_active"
		return false
	if not bool(params.get("ball_active", false)):
		_last_can_arm_reason = "ball_inactive"
		return false
	if not bool(params.get("companion_visible", false)):
		_last_can_arm_reason = "companion_hidden"
		return false
	var companion_pos := _as_vector2(params.get("companion_pos", Vector2.ZERO), Vector2.ZERO)
	if companion_pos == Vector2.ZERO:
		_last_can_arm_reason = "missing_companion_pos"
		return false
	_last_can_arm_reason = "ready"
	return true


func launch(origin: Vector2, owner: Object = null, launch_context: Dictionary = {}) -> bool:
	reset()
	_active_skill_level = clampi(int(launch_context.get("active_skill_level", launch_context.get("skill_level", 1))), 1, 5)
	_bind_duration = _get_context_positive_float(
		launch_context,
		"slow_duration",
		_get_slow_duration_for_level(_active_skill_level)
	)
	_slow_multiplier = clampf(
		_get_context_positive_float(launch_context, "slow_multiplier", DEFAULT_SLOW_MULTIPLIER),
		0.05,
		1.0
	)
	_origin = _clamp_to_field(_as_vector2(launch_context.get("companion_pos", origin), origin))
	_ground_y = clampf(_origin.y, 96.0, FIELD_HEIGHT - BODY_SIZE)
	_pos = _origin
	var boss_rect := _get_boss_rect(owner, launch_context)
	_last_boss_center = boss_rect.get_center()
	_corner_y = _get_corner_y(boss_rect)
	_select_launch_walls(_last_boss_center.x)
	_phase = PHASE_ROLL_TO_WALL
	_trail.append(_pos)
	_spawn_sparks(_pos, 12, 0.32)
	return true


func update(delta: float, owner: Object, registry: Object = null, launch_context: Dictionary = {}) -> void:
	var safe_delta := maxf(0.0, delta)
	_elapsed += safe_delta
	_update_sparks(safe_delta)
	if _phase == PHASE_IDLE:
		_stop_move_audio(registry)
		_sync_owner_slow_if_needed(owner)
		return
	if not _is_ball_active(owner, launch_context):
		_retire(owner, registry)
		return

	var fps_scale := safe_delta * 60.0
	var pre_move_pos := _pos
	match _phase:
		PHASE_ROLL_TO_WALL:
			_step_move(Vector2(_wall_x, _ground_y), ROLL_SPEED_PER_FRAME, fps_scale, PHASE_CLIMB)
		PHASE_CLIMB:
			_step_move(Vector2(_wall_x, _corner_y), CLIMB_SPEED_PER_FRAME, fps_scale, PHASE_LUNGE)
		PHASE_LUNGE:
			_update_lunge(fps_scale, owner, launch_context, registry)
		PHASE_BIND:
			_update_bind(safe_delta, owner, launch_context, registry)
		PHASE_CROSS:
			_step_move(Vector2(_opposite_wall_x, _corner_y), CROSS_SPEED_PER_FRAME, fps_scale, PHASE_DESCEND)
		PHASE_DESCEND:
			if _move_body_towards(Vector2(_opposite_wall_x, _ground_y), DESCEND_SPEED_PER_FRAME * fps_scale):
				_phase = PHASE_IDLE
				_spawn_sparks(_pos, 16, 0.42)
				_sync_owner_slow_if_needed(owner)
		_:
			_phase = PHASE_IDLE
			_sync_owner_slow_if_needed(owner)

	# While Orosha is rolling/climbing/lunging/crossing/descending, keep spraying
	# colorful stars off the body AND loop the starmoving SFX. Bind has its own
	# constrict sheet + squish SFX, so skip both there.
	if _is_rolling_phase(_phase):
		_emit_roll_stars(safe_delta, _pos - pre_move_pos)
		_start_move_audio(registry)
	else:
		_stop_move_audio(registry)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	# BIND body art remains with the companion renderer. This facade forwards only
	# the procedural trail visibility and borrowed live visual collections.
	_renderer.draw_star_coil(
		canvas,
		shake_offset,
		_phase != PHASE_IDLE and _phase != PHASE_BIND,
		_trail,
		_sparks
	)


func is_active() -> bool:
	return _phase != PHASE_IDLE or _needs_owner_slow_sync


func is_projectile_active() -> bool:
	return false


func has_companion_position_override() -> bool:
	return _phase != PHASE_IDLE


func get_companion_position_override(fallback: Vector2) -> Vector2:
	return _pos if has_companion_position_override() else fallback


func has_visible_effects() -> bool:
	return _phase != PHASE_IDLE or not _sparks.is_empty() or _needs_owner_slow_sync


func get_snapshot() -> Dictionary:
	return {
		"star_coil_active": is_active(),
		"star_coil_visible": _phase != PHASE_IDLE or not _sparks.is_empty(),
		"star_coil_companion_override_active": has_companion_position_override(),
		"star_coil_phase": _phase,
		"star_coil_pos": _pos,
		"star_coil_body_pos": _pos,
		"star_coil_origin": _origin,
		"star_coil_wall_x": _wall_x,
		"star_coil_opposite_wall_x": _opposite_wall_x,
		"star_coil_wall_side": _last_wall_side,
		"star_coil_opposite_wall_side": _last_opposite_wall_side,
		"star_coil_corner_y": _corner_y,
		"star_coil_bind_active": _phase == PHASE_BIND and _bind_timer > 0.0,
		"star_coil_bind_frame": _get_bind_sheet_frame(),
		"star_coil_bind_timer": _bind_timer,
		"star_coil_bind_duration": _bind_duration,
		"star_coil_bind_timer_frames": _bind_timer * 60.0,
		"star_coil_slow_multiplier": _slow_multiplier,
		"star_coil_active_skill_level": _active_skill_level,
		"star_coil_block_boss_dash": _is_bind_cc_active() and _active_skill_level >= BIND_DASH_BLOCK_MIN_LEVEL,
		"star_coil_freeze_boss_skill_cd": _is_bind_cc_active() and _active_skill_level >= BIND_SKILL_CD_FREEZE_MIN_LEVEL,
		"star_coil_lunge_frames": _lunge_frames,
		"star_coil_last_boss_center": _last_boss_center,
		"star_coil_last_can_arm_reason": _last_can_arm_reason,
		"star_coil_pending_slow_sync": _needs_owner_slow_sync,
		"star_coil_trail_count": _trail.size(),
		"star_coil_spark_count": _sparks.size(),
	}


func force_phase_for_tests(phase: String, pos: Vector2 = Vector2.ZERO) -> void:
	_phase = phase
	if pos != Vector2.ZERO:
		_pos = pos


func force_bind_for_tests(owner: Object = null, bind_seconds: float = -1.0) -> void:
	_phase = PHASE_BIND
	_bind_duration = bind_seconds if bind_seconds > 0.0 else _get_slow_duration_for_level(_active_skill_level)
	_bind_timer = _bind_duration
	_bind_elapsed = 0.0
	_bind_anchor = _get_boss_rect(owner, {}).get_center()
	_pos = _bind_anchor
	if owner != null:
		_sync_owner_slow(owner, true)


func get_phase_for_tests() -> String:
	return _phase


func _get_bind_sheet_frame() -> int:
	if _phase != PHASE_BIND:
		return 0
	return int(_bind_elapsed * BIND_SHEET_FPS) % BIND_SHEET_FRAME_COUNT


func _step_move(target: Vector2, speed_per_frame: float, fps_scale: float, next_phase: String) -> void:
	if _move_body_towards(target, speed_per_frame * fps_scale):
		_phase = next_phase


func _update_lunge(fps_scale: float, owner: Object, launch_context: Dictionary, registry: Object = null) -> void:
	var boss_rect := _get_boss_rect(owner, launch_context)
	_last_boss_center = boss_rect.get_center()
	if _body_overlaps_boss(boss_rect):
		_begin_bind(owner, boss_rect, registry)
		return
	var target := Vector2(clampf(_last_boss_center.x, BODY_SIZE, FIELD_WIDTH - BODY_SIZE), _corner_y)
	_move_body_towards(target, LUNGE_SPEED_PER_FRAME * fps_scale)
	_lunge_frames += fps_scale
	if _body_overlaps_boss(boss_rect) or _lunge_frames >= LUNGE_TIMEOUT_FRAMES:
		_begin_bind(owner, boss_rect, registry)


func _update_bind(delta: float, owner: Object, launch_context: Dictionary, registry: Object = null) -> void:
	var boss_rect := _get_boss_rect(owner, launch_context)
	_last_boss_center = boss_rect.get_center()
	_bind_anchor = _last_boss_center
	_pos = _bind_anchor
	if _active_skill_level < BIND_DASH_BLOCK_MIN_LEVEL and _is_boss_dashing(registry):
		_bind_timer = 0.0
	else:
		_bind_timer = maxf(0.0, _bind_timer - delta)
	_bind_elapsed += delta
	if _bind_timer > 0.0:
		_sync_owner_slow(owner, true)
		if int(_bind_elapsed * 20.0) % 5 == 0:
			_spawn_sparks(_bind_anchor, 1, 0.24)
		return
	_stop_bind_audio(registry)
	_sync_owner_slow(owner, false)
	_phase = PHASE_CROSS
	_pos = Vector2(_bind_anchor.x, _corner_y)
	_spawn_sparks(_bind_anchor, 12, 0.36)


func _begin_bind(owner: Object, boss_rect: Rect2, registry: Object = null) -> void:
	_phase = PHASE_BIND
	_lunge_frames = 0.0
	_bind_timer = _bind_duration
	_bind_elapsed = 0.0
	_bind_anchor = boss_rect.get_center()
	_pos = _bind_anchor
	_last_boss_center = _bind_anchor
	_spawn_sparks(_bind_anchor, 18, 0.42)
	_sync_owner_slow(owner, true)
	_start_bind_audio(registry)


func _retire(owner: Object, registry: Object = null) -> void:
	_stop_bind_audio(registry)
	_stop_move_audio(registry)
	_bind_timer = 0.0
	_bind_elapsed = 0.0
	_phase = PHASE_IDLE
	_sync_owner_slow(owner, false)


func _move_body_towards(target: Vector2, max_distance: float) -> bool:
	_pos = _pos.move_toward(target, maxf(0.0, max_distance))
	_record_trail(_pos)
	return _pos.distance_squared_to(target) <= 0.01


func _record_trail(pos: Vector2) -> void:
	_trail.append(pos)
	while _trail.size() > TRAIL_MAX_POINTS:
		_trail.pop_front()


func _select_launch_walls(boss_center_x: float) -> void:
	var inset := BODY_SIZE * 0.5 + WALL_OFFSET
	var left_x := inset
	var right_x := FIELD_WIDTH - inset
	if absf(boss_center_x - left_x) <= absf(right_x - boss_center_x):
		_wall_x = left_x
		_opposite_wall_x = right_x
		_last_wall_side = "left"
		_last_opposite_wall_side = "right"
	else:
		_wall_x = right_x
		_opposite_wall_x = left_x
		_last_wall_side = "right"
		_last_opposite_wall_side = "left"


func _get_corner_y(boss_rect: Rect2) -> float:
	var raw_y := boss_rect.position.y + BODY_SIZE * 0.5 + 12.0
	return clampf(raw_y, 44.0, FIELD_HEIGHT * 0.36)


func _get_boss_rect(owner: Object, context: Dictionary) -> Rect2:
	var boss_pos := _get_context_or_owner_vector2(context, owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - DEFAULT_BOSS_PADDLE_WIDTH * 0.5, 25.0))
	var boss_w := maxf(1.0, float(_get_context_or_owner_value(context, owner, "boss_paddle_width", DEFAULT_BOSS_PADDLE_WIDTH)))
	var boss_h := maxf(1.0, float(_get_context_or_owner_value(context, owner, "boss_hitbox_height", DEFAULT_BOSS_HITBOX_HEIGHT)))
	return Rect2(boss_pos, Vector2(boss_w, boss_h))


func _body_overlaps_boss(boss_rect: Rect2) -> bool:
	var closest := Vector2(
		clampf(_pos.x, boss_rect.position.x, boss_rect.end.x),
		clampf(_pos.y, boss_rect.position.y, boss_rect.end.y)
	)
	return closest.distance_squared_to(_pos) <= pow(BODY_SIZE * 0.5 + 4.0, 2.0)


func _sync_owner_slow_if_needed(owner: Object) -> void:
	if _last_slow_active_written or _needs_owner_slow_sync:
		_sync_owner_slow(owner, false)


func _sync_owner_slow(owner: Object, active: bool) -> void:
	if owner == null:
		if active or _last_slow_active_written:
			_needs_owner_slow_sync = true
		return
	owner.set(SLOW_ACTIVE_KEY, active)
	owner.set(SLOW_MULTIPLIER_KEY, _slow_multiplier if active else 1.0)
	owner.set(DASH_BLOCK_KEY, active and _active_skill_level >= BIND_DASH_BLOCK_MIN_LEVEL)
	owner.set(SKILL_CD_FREEZE_KEY, active and _active_skill_level >= BIND_SKILL_CD_FREEZE_MIN_LEVEL)
	_last_slow_active_written = active
	_needs_owner_slow_sync = false


func _is_bind_cc_active() -> bool:
	return _phase == PHASE_BIND and _bind_timer > 0.0


func _is_boss_dashing(registry: Object) -> bool:
	var boss_ai_state := _get_registry_instance(registry, "boss_ai_state")
	return boss_ai_state != null and bool(boss_ai_state.get("boss_dash_active"))


func _start_bind_audio(registry: Object) -> void:
	if _bind_audio_active:
		return
	_bind_audio_active = true
	_play_audio(registry, "play_lingpet_star_coil_bind")


func _stop_bind_audio(registry: Object) -> void:
	if not _bind_audio_active:
		return
	_bind_audio_active = false
	_play_audio(registry, "stop_lingpet_star_coil_bind")


func _start_move_audio(registry: Object) -> void:
	if _move_audio_active:
		return
	_move_audio_active = true
	_play_audio(registry, "play_lingpet_star_coil_move")


func _stop_move_audio(registry: Object) -> void:
	if not _move_audio_active:
		return
	_move_audio_active = false
	_play_audio(registry, "stop_lingpet_star_coil_move")


func _play_audio(registry: Object, method_name: String) -> void:
	var audio := _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method(method_name):
		audio.call(method_name)


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


func _is_ball_active(owner: Object, context: Dictionary) -> bool:
	if context.has("ball_active"):
		return bool(context.get("ball_active", false))
	return bool(BattleSceneOwnerReader.get_value(owner, "ball_active", false))


func _get_slow_duration_for_level(level: int) -> float:
	var index := clampi(level, 1, SLOW_DURATION_BY_LEVEL.size()) - 1
	return float(SLOW_DURATION_BY_LEVEL[index])


func _get_context_positive_float(source: Dictionary, key: String, fallback: float) -> float:
	var value := float(source.get(key, -1.0))
	return value if value > 0.0 else fallback


func _get_context_or_owner_value(context: Dictionary, owner: Object, key: String, fallback: Variant) -> Variant:
	if context.has(key):
		return context.get(key, fallback)
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _get_context_or_owner_vector2(context: Dictionary, owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_context_or_owner_value(context, owner, key, fallback)
	return value if value is Vector2 else fallback


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback


func _clamp_to_field(pos: Vector2) -> Vector2:
	return Vector2(clampf(pos.x, BODY_SIZE, FIELD_WIDTH - BODY_SIZE), clampf(pos.y, BODY_SIZE, FIELD_HEIGHT - BODY_SIZE))


func _is_rolling_phase(phase: String) -> bool:
	return (
		phase == PHASE_ROLL_TO_WALL
		or phase == PHASE_CLIMB
		or phase == PHASE_LUNGE
		or phase == PHASE_CROSS
		or phase == PHASE_DESCEND
	)


# Radial burst of stars at a moment of impact (launch / bind start / release / land).
func _spawn_sparks(center: Vector2, count: int, _life_hint: float) -> void:
	for index in range(count):
		var angle := _elapsed * 3.7 + float(index) * TAU / float(maxi(1, count))
		_spawn_star(center, Vector2(cos(angle), sin(angle)))


# Steady stream of stars flung off the rolling body. `moved` is this frame's body
# displacement; stars trail opposite the travel direction with a slight upward fling.
func _emit_roll_stars(delta: float, moved: Vector2) -> void:
	_spark_emit_accum += ROLL_STAR_RATE * delta
	var count := int(_spark_emit_accum)
	if count <= 0:
		return
	_spark_emit_accum -= float(count)
	var move_len := moved.length()
	var trail_dir := (moved / move_len) * -1.0 if move_len > 0.001 else Vector2.ZERO
	for _index in range(count):
		_spawn_star(_pos, trail_dir)


# Spawn one star. `bias_dir` skews the fling direction (radial for bursts, trailing
# for the rolling stream); a gentle upward bias makes the spray read as "튀기는".
func _spawn_star(center: Vector2, bias_dir: Vector2) -> void:
	if _sparks.size() >= SPARK_MAX:
		_sparks.pop_front()
	_spark_seed += 1.0
	var s := _spark_seed
	var angle := _seeded_unit(_elapsed * 53.0 + center.x, s) * TAU
	var dir := Vector2(cos(angle), sin(angle))
	var fling := dir + bias_dir * 0.7 + Vector2(0.0, -0.4)
	if fling.length() < 0.01:
		fling = dir
	fling = fling.normalized()
	var speed := lerpf(38.0, 150.0, _seeded_unit(center.y + s, s + 11.0))
	var life := lerpf(0.34, 0.74, _seeded_unit(center.x + s, s + 3.0))
	# Square the size roll so most stars stay small and a few read clearly "큰".
	var big := _seeded_unit(center.y - s, s + 7.0)
	var size := lerpf(1.6, 6.8, big * big)
	_sparks.append({
		"pos": center + dir * lerpf(1.0, 7.0, _seeded_unit(center.x - s, s + 5.0)),
		"vel": fling * speed,
		"life": life,
		"max_life": life,
		"size": size,
		"color": _pick_star_color(s),
		"rotation": _seeded_unit(center.x + center.y, s + 13.0) * TAU,
		"spin": lerpf(-8.0, 8.0, _seeded_unit(center.y, s + 17.0)),
		"points": 4 if size < 2.8 else 5,
	})


func _pick_star_color(seed_value: float) -> Color:
	var n := STAR_COLORS.size()
	var idx := int(_seeded_unit(seed_value, 23.0) * float(n))
	return STAR_COLORS[clampi(idx, 0, n - 1)]


func _update_sparks(delta: float) -> void:
	if _sparks.is_empty():
		return
	var drag := pow(SPARK_DRAG, delta * 60.0)
	var write_index := 0
	for spark in _sparks:
		var life := float(spark.get("life", 0.0)) - delta
		if life <= 0.0:
			continue
		var pos: Vector2 = spark.get("pos", Vector2.ZERO)
		var vel: Vector2 = spark.get("vel", Vector2.ZERO)
		pos += vel * delta
		vel.y += SPARK_GRAVITY * delta
		vel *= drag
		spark["life"] = life
		spark["pos"] = pos
		spark["vel"] = vel
		spark["rotation"] = float(spark.get("rotation", 0.0)) + float(spark.get("spin", 0.0)) * delta
		_sparks[write_index] = spark
		write_index += 1
	if write_index < _sparks.size():
		_sparks.resize(write_index)


func _seeded_unit(seed_value: float, salt: float) -> float:
	var hashed := sin(seed_value * 9283.33 + salt * 47.77) * 43758.5453
	return hashed - floor(hashed)
