extends RefCounted

const BallRenderInterpolation := preload("res://scripts/ball/ball_render_interpolation.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const GAME_LEFT := 0.0
const GAME_RIGHT := FIELD_WIDTH
const GHOST_WIDTH := 80.0
const GHOST_HEIGHT := 40.0
const EMERGE_DURATION := 0.8
const ACTIVE_DURATION := 5.0
const DEATH_DURATION := 0.6
const EAT_DURATION := 1.5
const EAT_GROW_INTERVAL := 0.1
const EAT_GROW_RATE := 0.03
const TELEPORT_DISAPPEAR_DUR := 0.3
const TELEPORT_APPEAR_DUR := 0.4
const CONSECUTIVE_CATCH_WINDOW := 0.5
const BALL_RADIUS_FALLBACK := 14.3
const PARTICLE_MAX := 96
const RELEASE_MIN_SPEED := 6.0
const RELEASE_MIN_VERTICAL_SPEED := 4.0
const GHOST_Y_POSITIONS := [325.0, 425.0]
const RELEASE_SPEED_MULTIPLIER_BY_LEVEL := [1.0, 1.25, 1.55, 1.9, 2.25]
const TELEPORT_FAR_FROM_BOSS_CHANCE_BY_LEVEL := [0.15, 0.35, 0.55, 0.75, 1.0]
const TELEPORT_FAR_FROM_BOSS_MIN_DISTANCE_BY_LEVEL := [150.0, 180.0, 210.0, 240.0, 260.0]
const TELEPORT_MIN_DISTANCE_FROM_CURRENT := 100.0
const TELEPORT_EDGE_MARGIN := 60.0

const TELEPORT_PHASE_DISAPPEAR := "disappear"
const TELEPORT_PHASE_APPEAR := "appear"
const TELEPORT_PHASE_RELEASE := "release"

# Faithful Banshee ghost visual constants (RGB ported from the original 0-255 palette).
const GHOST_MAX_ALPHA := 0.706                          # original int(180) cap / 255
const GHOST_BODY_RX := 22.0
const GHOST_BODY_RY := 20.0
const GHOST_BODY_COLOR := Color(0.314, 0.706, 0.627)    # (80, 180, 160)
const GHOST_EYE_COLOR := Color(0.549, 1.0, 0.902)       # (140, 255, 230)
const GHOST_EYE_HILITE := Color(0.784, 1.0, 0.961)      # (200, 255, 245)
const GHOST_BULGE_COLOR := Color(0.353, 0.765, 0.686)   # (90, 195, 175)
const GHOST_MOUTH_COLOR := Color(0.157, 0.314, 0.275)   # (40, 80, 70)
const GHOST_EYE_GLOW := Color(0.627, 1.0, 0.922)        # (160, 255, 235)
const GHOST_SHADOW_COLOR := Color(0.039, 0.078, 0.071)  # (10, 20, 18)
const GHOST_FLASH_COLOR := Color(0.235, 0.471, 0.392)   # (60, 120, 100) cast flash
const LAUNCH_FLASH_DURATION := 0.18

var _active := false
var _elapsed := 0.0
var _launch_origin := Vector2.ZERO
var _release_dir := -1.0
var _ghosts: Array[Dictionary] = []
var _dying_ghosts: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _teleport_particles: Array[Dictionary] = []
var _ball_hidden := false
var _hidden_ball_pos := Vector2.ZERO
var _saved_ball_vel := Vector2.ZERO
var _eating_ball := false
var _eating_ghost_id := -1
var _time_since_release := 999.0
var _release_count := 0
var _catch_count := 0
var _last_release_pos := Vector2.ZERO
var _last_release_vel := Vector2.ZERO
var _last_audio_registry: Object = null
var _launch_flash_timer := 0.0
var _active_skill_level := 1


func reset() -> void:
	_active = false
	_elapsed = 0.0
	_launch_origin = Vector2.ZERO
	_release_dir = -1.0
	_active_skill_level = 1
	_ghosts.clear()
	_dying_ghosts.clear()
	_particles.clear()
	_teleport_particles.clear()
	_ball_hidden = false
	_hidden_ball_pos = Vector2.ZERO
	_saved_ball_vel = Vector2.ZERO
	_eating_ball = false
	_eating_ghost_id = -1
	_time_since_release = 999.0
	_last_release_pos = Vector2.ZERO
	_last_release_vel = Vector2.ZERO
	_launch_flash_timer = 0.0
	# Per-cast metrics: reset() runs at every launch(), so these must clear too or the
	# snapshot/debug catch/release counters accumulate across casts.
	_catch_count = 0
	_release_count = 0


func cancel(owner: Object = null, _registry: Object = null) -> void:
	_clear_owner_ball_hold(owner)
	reset()


func prewarm() -> void:
	pass


func launch(origin: Vector2, _owner: Object = null, launch_context: Dictionary = {}) -> bool:
	reset()
	_active = true
	_elapsed = 0.0
	_active_skill_level = _get_active_skill_level(launch_context)
	_launch_origin = Vector2(clampf(origin.x, GAME_LEFT + 20.0, GAME_RIGHT - 20.0), clampf(origin.y, 0.0, FIELD_HEIGHT))
	_release_dir = 1.0 if bool(launch_context.get("caster_is_top", false)) else -1.0
	for idx in range(GHOST_Y_POSITIONS.size()):
		_ghosts.append(_make_ghost(idx, _launch_origin, float(GHOST_Y_POSITIONS[idx])))
	_spawn_launch_particles(_launch_origin)
	_launch_flash_timer = LAUNCH_FLASH_DURATION
	return true


func update(delta: float, owner: Object, registry: Object = null, _launch_context: Dictionary = {}) -> void:
	_last_audio_registry = registry
	var safe_delta: float = maxf(0.0, delta)
	_time_since_release += safe_delta
	_launch_flash_timer = maxf(0.0, _launch_flash_timer - safe_delta)
	if _ball_hidden:
		_hold_owner_ball(owner, _hidden_ball_pos)
	if _active:
		_elapsed += safe_delta
		_update_ghosts(safe_delta, owner, registry)
		if _elapsed >= ACTIVE_DURATION:
			_end_effect(owner, registry)
	_update_lingering(safe_delta)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	_draw_particles(canvas, _particles, shake_offset, 1.0)
	_draw_particles(canvas, _teleport_particles, shake_offset, 1.0)
	if _launch_flash_timer > 0.0:
		_draw_launch_flash(canvas, _launch_origin + shake_offset)
	for dying_value in _dying_ghosts:
		_draw_dying_ghost(canvas, dying_value as Dictionary, shake_offset)
	for ghost_value in _ghosts:
		var ghost := ghost_value as Dictionary
		if bool(ghost.get("teleporting", false)):
			_draw_teleporting_ghost(canvas, ghost, shake_offset)
		elif bool(ghost.get("eating", false)):
			_draw_eating_state(canvas, ghost, shake_offset)
		else:
			_draw_roaming_state(canvas, ghost, shake_offset)


func has_visible_effects() -> bool:
	return _active or not _ghosts.is_empty() or not _dying_ghosts.is_empty() or not _particles.is_empty() or not _teleport_particles.is_empty() or _ball_hidden or _launch_flash_timer > 0.0


func is_active() -> bool:
	return _active or _ball_hidden or not _ghosts.is_empty()


func get_catch_count_for_tests() -> int:
	return _catch_count


func get_release_count_for_tests() -> int:
	return _release_count


func get_snapshot() -> Dictionary:
	return {
		"ghost_summon_active": _active,
		"ghost_summon_elapsed": _elapsed,
		"ghost_summon_launch_origin": _launch_origin,
		"ghost_summon_ghost_count": _ghosts.size(),
		"ghost_summon_ghost_positions": _get_ghost_positions(),
		"ghost_summon_target_positions": _get_ghost_target_positions(),
		"ghost_summon_ball_hidden": _ball_hidden,
		"ghost_summon_hidden_ball_pos": _hidden_ball_pos,
		"ghost_summon_eating_active": _eating_ball,
		"ghost_summon_eating_ghost_id": _eating_ghost_id,
		"ghost_summon_catch_count": _catch_count,
		"ghost_summon_release_count": _release_count,
		"ghost_summon_last_release_pos": _last_release_pos,
		"ghost_summon_last_release_vel": _last_release_vel,
		"ghost_summon_active_skill_level": _active_skill_level,
		"ghost_summon_release_speed_multiplier": _get_release_speed_multiplier(),
		"ghost_summon_far_teleport_chance": _get_far_teleport_chance(),
		"ghost_summon_far_teleport_min_distance": _get_far_teleport_min_distance(),
		"ghost_summon_particle_count": _particles.size() + _teleport_particles.size(),
		"ghost_summon_dying_count": _dying_ghosts.size(),
	}


func _make_ghost(index: int, origin: Vector2, target_y: float) -> Dictionary:
	var target_x := randf_range(GAME_LEFT + 100.0, GAME_RIGHT - 100.0)
	return {
		"id": index,
		"pos": origin,
		"start_pos": origin,
		"target_pos": Vector2(target_x, target_y),
		"spawn_time": 0.0,
		"vx": randf_range(-5.0, 5.0),
		"hit_cooldown": 0.0,
		"eating": false,
		"eat_timer": 0.0,
		"eat_scale": 1.0,
		"eat_grow_acc": 0.0,
		"eat_bulge_phase": randf_range(0.0, TAU),
		"swallow_sound_played": false,
		"teleporting": false,
		"teleport_phase": "",
		"teleport_timer": 0.0,
		"teleport_target_x": target_x,
		"pre_teleport_pos": origin,
		"phase": randf_range(0.0, TAU),
	}


func _update_ghosts(delta: float, owner: Object, registry: Object) -> void:
	if delta <= 0.0:
		return
	for ghost_value in _ghosts:
		var ghost := ghost_value as Dictionary
		ghost["hit_cooldown"] = maxf(0.0, float(ghost.get("hit_cooldown", 0.0)) - delta)
		ghost["phase"] = float(ghost.get("phase", 0.0)) + delta * 4.0
		if bool(ghost.get("teleporting", false)):
			_update_teleporting_ghost(ghost, delta, owner)
		elif bool(ghost.get("eating", false)):
			_update_eating_ghost(ghost, delta, owner, registry)
		else:
			_update_roaming_ghost(ghost, delta, owner, registry)


func _update_roaming_ghost(ghost: Dictionary, delta: float, owner: Object, registry: Object) -> void:
	var spawn_time: float = float(ghost.get("spawn_time", 0.0)) + delta
	ghost["spawn_time"] = spawn_time
	var pos: Vector2 = _get_dict_vector2(ghost, "pos", Vector2.ZERO)
	var target_pos: Vector2 = _get_dict_vector2(ghost, "target_pos", pos)
	if spawn_time < EMERGE_DURATION:
		var emerge_t: float = clampf(spawn_time / EMERGE_DURATION, 0.0, 1.0)
		var ease_t: float = 1.0 - pow(1.0 - emerge_t, 2.5)
		pos = _get_dict_vector2(ghost, "start_pos", pos).lerp(target_pos, ease_t)
		ghost["pos"] = pos
		if randf() < 0.60:
			_add_particle(pos + Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0)), Vector2(randf_range(-10.0, 10.0), randf_range(-80.0, -35.0)), randf_range(0.3, 0.7), randf_range(2.0, 5.0), Color(0.45, 1.0, 0.86, randf_range(0.42, 0.72)))
		return

	var vx: float = float(ghost.get("vx", 0.0))
	if _is_ball_trackable(owner):
		var ball_pos: Vector2 = _get_owner_vector2(owner, "ball_pos", pos)
		var dx: float = ball_pos.x - pos.x
		if absf(dx) > 5.0:
			vx += 0.4 if dx > 0.0 else -0.4
		else:
			vx *= 0.92
	else:
		vx += randf_range(-0.2, 0.2)
	pos.x += vx * delta * 60.0
	if pos.x - GHOST_WIDTH * 0.5 < GAME_LEFT:
		pos.x = GAME_LEFT + GHOST_WIDTH * 0.5
		vx = absf(vx) * 0.5
	elif pos.x + GHOST_WIDTH * 0.5 > GAME_RIGHT:
		pos.x = GAME_RIGHT - GHOST_WIDTH * 0.5
		vx = -absf(vx) * 0.5
	if absf(vx) > 10.0:
		vx = signf(vx) * 10.0
	ghost["vx"] = vx
	ghost["pos"] = pos
	if randf() < 0.15:
		_add_particle(pos + Vector2(randf_range(-30.0, 30.0), randf_range(-10.0, 10.0)), Vector2(randf_range(-12.0, 12.0), randf_range(-70.0, -25.0)), randf_range(0.5, 1.2), randf_range(2.0, 4.0), Color(0.55, 1.0, 0.9, randf_range(0.35, 0.62)))
	_try_catch_ball(ghost, owner, registry)


func _update_eating_ghost(ghost: Dictionary, delta: float, owner: Object, registry: Object) -> void:
	var pos: Vector2 = _get_dict_vector2(ghost, "pos", _hidden_ball_pos)
	var eat_timer: float = float(ghost.get("eat_timer", 0.0)) + delta
	var grow_acc: float = float(ghost.get("eat_grow_acc", 0.0)) + delta
	var eat_scale: float = float(ghost.get("eat_scale", 1.0))
	while grow_acc >= EAT_GROW_INTERVAL:
		grow_acc -= EAT_GROW_INTERVAL
		eat_scale += EAT_GROW_RATE
	ghost["eat_timer"] = eat_timer
	ghost["eat_grow_acc"] = grow_acc
	ghost["eat_scale"] = eat_scale
	ghost["eat_bulge_phase"] = float(ghost.get("eat_bulge_phase", 0.0)) + delta * 12.0
	ghost["vx"] = float(ghost.get("vx", 0.0)) * 0.85
	_hidden_ball_pos = pos
	if _ball_hidden:
		_hidden_ball_pos = pos
	if eat_timer >= 0.7 and not bool(ghost.get("swallow_sound_played", false)):
		ghost["swallow_sound_played"] = true
		_play_audio(registry, "play_stage3_kuromi_swallow")
	if randf() < 0.4:
		_add_particle(pos + Vector2(randf_range(-20.0, 20.0), randf_range(-15.0, 15.0)), Vector2(randf_range(-8.0, 8.0), randf_range(-92.0, -35.0)), randf_range(0.3, 0.8), randf_range(2.0, 5.0), Color(0.62, 1.0, 0.9, randf_range(0.48, 0.78)))
	if eat_timer >= EAT_DURATION:
		_begin_ghost_teleport(ghost, owner)


func _update_teleporting_ghost(ghost: Dictionary, delta: float, owner: Object) -> void:
	var phase_name := str(ghost.get("teleport_phase", ""))
	var timer: float = float(ghost.get("teleport_timer", 0.0)) + delta
	ghost["teleport_timer"] = timer
	var pos: Vector2 = _get_dict_vector2(ghost, "pos", _hidden_ball_pos)
	if phase_name == TELEPORT_PHASE_DISAPPEAR:
		var disappear_t: float = clampf(timer / TELEPORT_DISAPPEAR_DUR, 0.0, 1.0)
		if randf() < 0.8:
			_spawn_teleport_particle(_get_dict_vector2(ghost, "pre_teleport_pos", pos), 1.0 - disappear_t, true)
		if timer >= TELEPORT_DISAPPEAR_DUR:
			ghost["teleport_phase"] = TELEPORT_PHASE_APPEAR
			ghost["teleport_timer"] = 0.0
			pos.x = float(ghost.get("teleport_target_x", pos.x))
			pos.y = _get_dict_vector2(ghost, "target_pos", pos).y
			ghost["pos"] = pos
			_hidden_ball_pos = pos
	elif phase_name == TELEPORT_PHASE_APPEAR:
		var appear_t: float = clampf(timer / TELEPORT_APPEAR_DUR, 0.0, 1.0)
		if randf() < 0.8:
			_spawn_teleport_particle(pos, appear_t, false)
		if timer >= TELEPORT_APPEAR_DUR:
			ghost["teleport_phase"] = TELEPORT_PHASE_RELEASE
			ghost["teleport_timer"] = 0.0
	elif phase_name == TELEPORT_PHASE_RELEASE:
		_release_ball_from_ghost(ghost, owner)
		ghost["teleporting"] = false
		ghost["teleport_phase"] = ""
		ghost["eating"] = false
		ghost["eat_scale"] = 1.0
		ghost["eat_timer"] = 0.0
		ghost["hit_cooldown"] = 0.5
		_eating_ball = false
		_eating_ghost_id = -1


func _try_catch_ball(ghost: Dictionary, owner: Object, registry: Object) -> void:
	if owner == null or _ball_hidden or _eating_ball:
		return
	if not bool(owner.get("ball_active")):
		return
	if float(ghost.get("hit_cooldown", 0.0)) > 0.0:
		return
	var ghost_rect: Rect2 = _get_ghost_rect(ghost)
	var ball_size: float = maxf(1.0, float(owner.get("ball_size")) if owner.get("ball_size") != null else BALL_RADIUS_FALLBACK * 2.0)
	var ball_pos: Vector2 = _get_owner_vector2(owner, "ball_pos", Vector2.ZERO)
	var ball_rect := Rect2(ball_pos - Vector2(ball_size * 0.5, ball_size * 0.5), Vector2(ball_size, ball_size))
	if not ghost_rect.intersects(ball_rect):
		return
	var consecutive: bool = _time_since_release < CONSECUTIVE_CATCH_WINDOW
	_saved_ball_vel = _get_owner_vector2(owner, "ball_vel", Vector2.ZERO)
	_hidden_ball_pos = _get_dict_vector2(ghost, "pos", ball_pos)
	_ball_hidden = true
	_eating_ball = true
	_eating_ghost_id = int(ghost.get("id", -1))
	_catch_count += 1
	ghost["eating"] = true
	ghost["eat_timer"] = 0.0
	ghost["eat_scale"] = 1.0
	ghost["eat_grow_acc"] = 0.0
	ghost["eat_bulge_phase"] = 0.0
	ghost["hit_cooldown"] = 99.0
	ghost["swallow_sound_played"] = false
	_hold_owner_ball(owner, _hidden_ball_pos)
	if consecutive:
		_begin_ghost_teleport(ghost, owner)
	_play_audio(registry, "play_stage3_kuromi_tongue")


func _begin_ghost_teleport(ghost: Dictionary, owner: Object) -> void:
	var pos: Vector2 = _get_dict_vector2(ghost, "pos", _hidden_ball_pos)
	ghost["teleporting"] = true
	ghost["teleport_phase"] = TELEPORT_PHASE_DISAPPEAR
	ghost["teleport_timer"] = 0.0
	ghost["pre_teleport_pos"] = pos
	ghost["teleport_target_x"] = _pick_teleport_target_x(pos.x, owner)


func _release_ball_from_ghost(ghost: Dictionary, owner: Object) -> void:
	var release_pos: Vector2 = _get_dict_vector2(ghost, "pos", _hidden_ball_pos)
	_release_owner_ball(owner, release_pos, _get_saved_release_velocity())


func _get_saved_release_velocity() -> Vector2:
	var release_vel := Vector2(0.0, maxf(RELEASE_MIN_SPEED, RELEASE_MIN_VERTICAL_SPEED) * _release_dir)
	if _saved_ball_vel.length_squared() > 0.0001:
		release_vel = _saved_ball_vel
		release_vel.y = maxf(absf(release_vel.y), RELEASE_MIN_VERTICAL_SPEED) * _release_dir
		if release_vel.length() < RELEASE_MIN_SPEED:
			release_vel.y = maxf(absf(release_vel.y), RELEASE_MIN_SPEED) * _release_dir
	return release_vel * _get_release_speed_multiplier()


func _pick_teleport_target_x(current_x: float, owner: Object) -> float:
	var min_x := GAME_LEFT + TELEPORT_EDGE_MARGIN
	var max_x := GAME_RIGHT - TELEPORT_EDGE_MARGIN
	var use_far_from_boss := randf() < _get_far_teleport_chance()
	var ranges: Array[Vector2] = []
	if use_far_from_boss:
		ranges = _get_far_teleport_ranges(owner, min_x, max_x)
	if ranges.is_empty():
		ranges.append(Vector2(min_x, max_x))
	for _attempt in range(32):
		var new_x := _sample_x_from_ranges(ranges)
		if absf(new_x - current_x) >= TELEPORT_MIN_DISTANCE_FROM_CURRENT:
			return new_x
	return _pick_farthest_range_edge(ranges, current_x)


func _get_far_teleport_ranges(owner: Object, min_x: float, max_x: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var boss_center_x := _get_boss_center_x(owner)
	var min_distance := _get_far_teleport_min_distance()
	var left_max := minf(max_x, boss_center_x - min_distance)
	if left_max >= min_x:
		result.append(Vector2(min_x, left_max))
	var right_min := maxf(min_x, boss_center_x + min_distance)
	if right_min <= max_x:
		result.append(Vector2(right_min, max_x))
	return result


func _sample_x_from_ranges(ranges: Array[Vector2]) -> float:
	if ranges.is_empty():
		return randf_range(GAME_LEFT + TELEPORT_EDGE_MARGIN, GAME_RIGHT - TELEPORT_EDGE_MARGIN)
	var range_value: Vector2 = ranges[randi() % ranges.size()]
	return randf_range(range_value.x, range_value.y)


func _pick_farthest_range_edge(ranges: Array[Vector2], current_x: float) -> float:
	if ranges.is_empty():
		return clampf(current_x, GAME_LEFT + TELEPORT_EDGE_MARGIN, GAME_RIGHT - TELEPORT_EDGE_MARGIN)
	var best_x := ranges[0].x
	var best_distance := -1.0
	for range_value in ranges:
		for candidate_x in [range_value.x, range_value.y]:
			var distance := absf(float(candidate_x) - current_x)
			if distance > best_distance:
				best_distance = distance
				best_x = float(candidate_x)
	return best_x


func _get_boss_center_x(owner: Object) -> float:
	var boss_pos: Vector2 = _get_owner_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	var boss_width := _get_owner_float(owner, "boss_paddle_width", 100.0)
	return boss_pos.x + boss_width * 0.5


func _get_release_speed_multiplier() -> float:
	return _get_level_array_value(RELEASE_SPEED_MULTIPLIER_BY_LEVEL, 1.0)


func _get_far_teleport_chance() -> float:
	return clampf(_get_level_array_value(TELEPORT_FAR_FROM_BOSS_CHANCE_BY_LEVEL, 0.15), 0.0, 1.0)


func _get_far_teleport_min_distance() -> float:
	return _get_level_array_value(TELEPORT_FAR_FROM_BOSS_MIN_DISTANCE_BY_LEVEL, 150.0)


func _get_level_array_value(values: Array, fallback: float) -> float:
	if values.is_empty():
		return fallback
	var index := clampi(_active_skill_level, 1, values.size()) - 1
	return float(values[index])


func _get_active_skill_level(launch_context: Dictionary) -> int:
	return clampi(int(launch_context.get("active_skill_level", launch_context.get("skill_level", 1))), 1, 5)


func _release_owner_ball(owner: Object, release_pos: Vector2, release_vel: Vector2) -> void:
	_ball_hidden = false
	_hidden_ball_pos = release_pos
	_time_since_release = 0.0
	_release_count += 1
	_last_release_pos = release_pos
	_last_release_vel = release_vel
	if owner == null:
		return
	owner.set("ball_pos", release_pos)
	owner.set("ball_vel", release_vel)
	owner.set("skip_ball_motion_step", false)
	owner.set("stage3_kuromi_ball_hidden", false)
	BallRenderInterpolation.reset_ball_interpolation_on_owner(owner)


func _end_effect(owner: Object, registry: Object) -> void:
	if not _active:
		return
	_active = false
	if _ball_hidden:
		var release_pos := _hidden_ball_pos
		for ghost_value in _ghosts:
			var ghost := ghost_value as Dictionary
			if int(ghost.get("id", -1)) == _eating_ghost_id:
				release_pos = _get_dict_vector2(ghost, "pos", release_pos)
				break
		_release_owner_ball(owner, release_pos, _get_saved_release_velocity())
	_eating_ball = false
	_eating_ghost_id = -1
	for ghost_value in _ghosts:
		var ghost := ghost_value as Dictionary
		_dying_ghosts.append({
			"pos": _get_dict_vector2(ghost, "pos", Vector2.ZERO),
			"death_timer": 0.0,
			"phase": float(ghost.get("phase", 0.0)),
		})
	_ghosts.clear()
	_play_audio(registry, "play_lingpet_ghost_summon_out")


func _update_lingering(delta: float) -> void:
	if not _dying_ghosts.is_empty():
		var kept_dying: Array[Dictionary] = []
		for dying_value in _dying_ghosts:
			var dying := dying_value as Dictionary
			var timer: float = float(dying.get("death_timer", 0.0)) + delta
			dying["death_timer"] = timer
			if timer <= DEATH_DURATION:
				var pos: Vector2 = _get_dict_vector2(dying, "pos", Vector2.ZERO)
				if randf() < 0.70:
					_add_particle(pos + Vector2(randf_range(-28.0, 28.0), randf_range(-18.0, 18.0)), Vector2(randf_range(-40.0, 40.0), randf_range(-110.0, -25.0)), randf_range(0.25, 0.55), randf_range(2.0, 5.0), Color(0.50, 0.98, 0.86, randf_range(0.35, 0.70)))
				kept_dying.append(dying)
		_dying_ghosts = kept_dying
	_update_particles_array(_particles, delta)
	_update_particles_array(_teleport_particles, delta)


func _hold_owner_ball(owner: Object, hold_pos: Vector2) -> void:
	if owner == null:
		return
	owner.set("ball_pos", hold_pos)
	owner.set("ball_vel", Vector2.ZERO)
	owner.set("skip_ball_motion_step", true)
	owner.set("stage3_kuromi_ball_hidden", true)


func _clear_owner_ball_hold(owner: Object) -> void:
	if owner == null:
		return
	owner.set("skip_ball_motion_step", false)
	owner.set("stage3_kuromi_ball_hidden", false)
	BallRenderInterpolation.reset_ball_interpolation_on_owner(owner)


func _is_ball_trackable(owner: Object) -> bool:
	if owner == null or _ball_hidden:
		return false
	return bool(owner.get("ball_active"))


func _get_ghost_rect(ghost: Dictionary) -> Rect2:
	var pos: Vector2 = _get_dict_vector2(ghost, "pos", Vector2.ZERO)
	var scale_value: float = maxf(0.2, float(ghost.get("eat_scale", 1.0)))
	var size := Vector2(GHOST_WIDTH, GHOST_HEIGHT) * scale_value
	return Rect2(pos - size * 0.5, size)


func _draw_roaming_state(canvas: CanvasItem, ghost: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = _get_dict_vector2(ghost, "pos", Vector2.ZERO) + shake_offset
	var spawn_time: float = float(ghost.get("spawn_time", 0.0))
	var ghost_id: float = float(ghost.get("id", 0))
	var phase: float = float(ghost.get("phase", 0.0))
	var alpha: float = GHOST_MAX_ALPHA * clampf(spawn_time / EMERGE_DURATION, 0.0, 1.0)
	if alpha <= 0.01:
		return
	# Original 둥실둥실 hover: large primary bob + secondary jitter, per-ghost phase offset.
	var hover_main: float = 14.0 * sin(spawn_time * 2.2 + ghost_id * PI)
	var hover: float = hover_main + 5.0 * sin(spawn_time * 3.8 + ghost_id * 2.1)
	_draw_ground_shadow(canvas, pos, 1.0, alpha, hover_main)
	_draw_fallback_ghost(canvas, pos + Vector2(0.0, hover), 1.0, alpha, phase)


func _draw_eating_state(canvas: CanvasItem, ghost: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = _get_dict_vector2(ghost, "pos", Vector2.ZERO) + shake_offset
	var spawn_time: float = float(ghost.get("spawn_time", 0.0))
	var phase: float = float(ghost.get("phase", 0.0))
	var eat_scale: float = float(ghost.get("eat_scale", 1.0))
	var bulge_phase: float = float(ghost.get("eat_bulge_phase", 0.0))
	var eat_timer: float = float(ghost.get("eat_timer", 0.0))
	var alpha: float = GHOST_MAX_ALPHA * clampf(spawn_time / EMERGE_DURATION, 0.0, 1.0)
	if alpha <= 0.01:
		return
	# Asymmetric bulge scale + digestion shake (ball squirming in the belly).
	var sx: float = eat_scale * (1.0 + 0.06 * sin(bulge_phase))
	var sy: float = eat_scale * (1.0 + 0.06 * sin(bulge_phase + 1.5))
	var shake := Vector2(2.0 * sin(bulge_phase * 3.7), 1.5 * cos(bulge_phase * 2.9))
	_draw_ground_shadow(canvas, pos, eat_scale, alpha, 0.0)
	_draw_ghost_glyph(canvas, pos + shake, sx, sy, alpha, phase, true, eat_timer)


func _draw_teleporting_ghost(canvas: CanvasItem, ghost: Dictionary, shake_offset: Vector2) -> void:
	var phase_name := str(ghost.get("teleport_phase", ""))
	var timer: float = float(ghost.get("teleport_timer", 0.0))
	var phase: float = float(ghost.get("phase", 0.0))
	var eat_scale: float = float(ghost.get("eat_scale", 1.0))
	if phase_name == TELEPORT_PHASE_DISAPPEAR:
		var t: float = clampf(timer / TELEPORT_DISAPPEAR_DUR, 0.0, 1.0)
		var alpha: float = GHOST_MAX_ALPHA * (1.0 - t)
		if alpha <= 0.04:
			return
		# Shrink the grown ghost while it swirls inward, then vanishes.
		var shrink: float = eat_scale * (1.0 - t * 0.8)
		var swirl := Vector2(8.0 * sin(timer * 25.0) * (1.0 - t), 8.0 * cos(timer * 25.0) * (1.0 - t))
		var pre_pos: Vector2 = _get_dict_vector2(ghost, "pre_teleport_pos", _get_dict_vector2(ghost, "pos", Vector2.ZERO))
		_draw_fallback_ghost(canvas, pre_pos + swirl + shake_offset, shrink, alpha, phase)
	elif phase_name == TELEPORT_PHASE_APPEAR:
		var t2: float = clampf(timer / TELEPORT_APPEAR_DUR, 0.0, 1.0)
		# Elastic bounce-in: square-root ramp, then a slight overshoot past full size.
		var ease_t: float
		if t2 < 0.6:
			ease_t = sqrt(t2 / 0.6)
		else:
			ease_t = 1.0 + 0.15 * sin((t2 - 0.6) / 0.4 * PI)
		var alpha2: float = GHOST_MAX_ALPHA * minf(1.0, t2 * 1.5)
		var appear_scale: float = 0.2 + 0.8 * ease_t
		var pos: Vector2 = _get_dict_vector2(ghost, "pos", Vector2.ZERO) + shake_offset
		_draw_fallback_ghost(canvas, pos, appear_scale, alpha2, phase)
	else:
		_draw_roaming_state(canvas, ghost, shake_offset)


func _draw_dying_ghost(canvas: CanvasItem, dying: Dictionary, shake_offset: Vector2) -> void:
	var progress: float = clampf(float(dying.get("death_timer", 0.0)) / DEATH_DURATION, 0.0, 1.0)
	var alpha: float = GHOST_MAX_ALPHA * (1.0 - progress)
	if alpha <= 0.04:
		return
	var pos: Vector2 = _get_dict_vector2(dying, "pos", Vector2.ZERO) + shake_offset
	pos.y -= 40.0 * progress  # rise upward as it fades
	var phase: float = float(dying.get("phase", 0.0))
	# Upward scatter sparkle (intentionally shimmery over the brief 0.6s dissolve).
	var count: int = int(8.0 * progress)
	for _i in range(count):
		var spark := Vector2(pos.x + randf_range(-30.0, 30.0), pos.y - 30.0 * progress + randf_range(-15.0, 15.0))
		var spark_alpha: float = alpha * 0.5 * randf_range(0.3, 1.0)
		if spark_alpha > 0.04:
			canvas.draw_circle(spark, randf_range(2.0, 5.0), Color(0.35, 0.82, 0.71, spark_alpha))
	_draw_fallback_ghost(canvas, pos, 1.0, alpha, phase)


func _draw_launch_flash(canvas: CanvasItem, origin: Vector2) -> void:
	var t: float = clampf(_launch_flash_timer / LAUNCH_FLASH_DURATION, 0.0, 1.0)
	var radius: float = 36.0 + (1.0 - t) * 110.0
	var disc := GHOST_FLASH_COLOR
	disc.a = 0.34 * t
	_fill_ellipse(canvas, origin, radius, radius, disc, 28)
	canvas.draw_arc(origin, radius, 0.0, TAU, 36, Color(0.55, 1.0, 0.86, 0.7 * t), 2.5, true)


func _draw_fallback_ghost(canvas: CanvasItem, center: Vector2, scale_value: float, alpha: float, phase: float) -> void:
	if alpha <= 0.01 or scale_value <= 0.05:
		return
	_draw_ghost_glyph(canvas, center, scale_value, scale_value, alpha, phase, false, 0.0)


func _draw_ghost_glyph(canvas: CanvasItem, center: Vector2, sx: float, sy: float, alpha: float, phase: float, eating: bool, eat_timer: float) -> void:
	var body_color := GHOST_BODY_COLOR
	body_color.a = alpha
	var body_center := center + Vector2(0.0, -6.0 * sy)
	# Rounded dome body.
	_fill_ellipse(canvas, body_center, GHOST_BODY_RX * sx, GHOST_BODY_RY * sy, body_color, 28)
	# Belly bulge (the swallowed ball shifting inside) while eating.
	if eating:
		var bulge_off := Vector2(8.0 * sin(eat_timer * 6.0), 5.0 * cos(eat_timer * 4.5))
		var bulge_color := GHOST_BULGE_COLOR
		bulge_color.a = minf(1.0, alpha * 1.1)
		canvas.draw_circle(body_center + bulge_off, 8.0 * minf(sx, sy), bulge_color)
	# Tattered bottom wave tendrils (classic ghost skirt).
	var body_bottom: float = body_center.y + GHOST_BODY_RY * sy
	var wave_offsets := [-16.5, -5.5, 5.5, 16.5]
	var wave_amp: float = 4.0 if eating else 2.5
	var wave_speed: float = (8.0 + eat_timer * 4.0) if eating else 1.5
	for i in range(wave_offsets.size()):
		var wx: float = float(wave_offsets[i]) * sx
		var wave_ry: float = (8.0 + wave_amp * sin(phase * wave_speed + float(i) * 0.9)) * sy
		_fill_ellipse(canvas, Vector2(center.x + wx, body_bottom + wave_ry * 0.5 - 2.0 * sy), 6.0 * sx, wave_ry, body_color, 12)
	# Eyes.
	var eye_y: float = body_center.y - 4.0 * sy
	var left_eye := Vector2(center.x - 7.0 * sx, eye_y)
	var right_eye := Vector2(center.x + 7.0 * sx, eye_y)
	var eye_r: float = maxf(2.0, 3.2 * minf(sx, sy))
	var eye_color := GHOST_EYE_COLOR
	eye_color.a = alpha
	if eating:
		# Crescent happy eyes: cyan disc with a body-color disc covering the lower half.
		canvas.draw_circle(left_eye, eye_r, eye_color)
		canvas.draw_circle(right_eye, eye_r, eye_color)
		canvas.draw_circle(left_eye + Vector2(0.0, 2.0 * sy), eye_r, body_color)
		canvas.draw_circle(right_eye + Vector2(0.0, 2.0 * sy), eye_r, body_color)
		var glow := GHOST_EYE_GLOW
		glow.a = minf(1.0, alpha * 1.3)
		canvas.draw_circle(left_eye + Vector2(0.0, -1.0), maxf(1.0, eye_r - 1.0), glow)
		canvas.draw_circle(right_eye + Vector2(0.0, -1.0), maxf(1.0, eye_r - 1.0), glow)
		# Open chewing mouth, oscillating with the swallow rhythm.
		var chew: float = sin(eat_timer * 8.0)
		var mouth_h: float = maxf(2.0, (4.0 + 3.0 * absf(chew)) * minf(sx, sy))
		var mouth_w: float = maxf(3.0, (6.0 + 2.0 * chew) * minf(sx, sy))
		var mouth_color := GHOST_MOUTH_COLOR
		mouth_color.a = minf(1.0, alpha * 1.2)
		_fill_ellipse(canvas, Vector2(center.x, body_center.y + 8.0 * sy), mouth_w * 0.5, mouth_h * 0.5, mouth_color, 14)
	else:
		canvas.draw_circle(left_eye, eye_r, eye_color)
		canvas.draw_circle(right_eye, eye_r, eye_color)
		var hilite := GHOST_EYE_HILITE
		hilite.a = alpha
		canvas.draw_circle(left_eye + Vector2(-1.0 * sx, -1.0 * sy), maxf(1.0, eye_r * 0.4), hilite)
		canvas.draw_circle(right_eye + Vector2(-1.0 * sx, -1.0 * sy), maxf(1.0, eye_r * 0.4), hilite)


func _draw_ground_shadow(canvas: CanvasItem, pos: Vector2, scale_value: float, alpha: float, hover_main: float) -> void:
	var shadow_scale: float = clampf(1.0 - absf(hover_main) / 25.0, 0.35, 1.0)
	var color := GHOST_SHADOW_COLOR
	color.a = alpha * 0.35 * shadow_scale
	_fill_ellipse(canvas, pos + Vector2(0.0, 24.0 * scale_value), GHOST_BODY_RX * scale_value * shadow_scale, 4.0 * scale_value, color, 16)


func _fill_ellipse(canvas: CanvasItem, center: Vector2, rx: float, ry: float, color: Color, segments: int) -> void:
	if rx <= 0.5 or ry <= 0.5 or color.a <= 0.0:
		return
	var points := PackedVector2Array()
	var count: int = maxi(6, segments)
	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	canvas.draw_colored_polygon(points, color)


func _draw_particles(canvas: CanvasItem, particles: Array[Dictionary], shake_offset: Vector2, alpha_scale: float) -> void:
	for particle_value in particles:
		var particle := particle_value as Dictionary
		var age: float = float(particle.get("age", 0.0))
		var life: float = maxf(0.001, float(particle.get("life", 0.001)))
		var ratio: float = clampf(1.0 - age / life, 0.0, 1.0)
		var color_value: Color = particle.get("color", Color(0.55, 1.0, 0.9, 0.5))
		color_value.a *= ratio * alpha_scale
		var pos: Vector2 = _get_dict_vector2(particle, "pos", Vector2.ZERO) + shake_offset
		canvas.draw_circle(pos, maxf(0.5, float(particle.get("size", 2.0))) * (0.6 + ratio * 0.8), color_value)


func _spawn_launch_particles(origin: Vector2) -> void:
	for _idx in range(22):
		var angle := randf_range(0.0, TAU)
		var speed := randf_range(40.0, 170.0)
		_add_particle(origin, Vector2(cos(angle), sin(angle)) * speed, randf_range(0.35, 0.9), randf_range(2.0, 6.0), Color(0.50, 1.0, 0.86, randf_range(0.38, 0.72)))


func _spawn_teleport_particle(origin: Vector2, ratio: float, inward: bool) -> void:
	var angle := randf_range(0.0, TAU)
	var dist := randf_range(0.0, 40.0) * clampf(ratio, 0.0, 1.0)
	var pos := origin + Vector2(cos(angle), sin(angle)) * dist
	var dir := Vector2(cos(angle), sin(angle))
	var velocity := dir * (-120.0 if inward else 150.0) + Vector2(0.0, -60.0)
	var color_options := [
		Color(0.36, 0.92, 0.82, 0.68),
		Color(0.55, 1.0, 0.90, 0.74),
		Color(0.25, 0.72, 0.62, 0.62),
	]
	var particle := {
		"pos": pos,
		"vel": velocity,
		"life": randf_range(0.3, 0.8),
		"age": 0.0,
		"size": randf_range(3.0, 8.0),
		"color": color_options[randi() % color_options.size()],
	}
	_teleport_particles.append(particle)
	while _teleport_particles.size() > PARTICLE_MAX:
		_teleport_particles.remove_at(0)


func _add_particle(pos: Vector2, vel: Vector2, life: float, size: float, color_value: Color) -> void:
	_particles.append({
		"pos": pos,
		"vel": vel,
		"life": maxf(0.05, life),
		"age": 0.0,
		"size": size,
		"color": color_value,
	})
	while _particles.size() > PARTICLE_MAX:
		_particles.remove_at(0)


func _update_particles_array(particles: Array[Dictionary], delta: float) -> void:
	var kept: Array[Dictionary] = []
	for particle_value in particles:
		var particle := particle_value as Dictionary
		var age: float = float(particle.get("age", 0.0)) + delta
		var life: float = float(particle.get("life", 0.0))
		if age >= life:
			continue
		var pos: Vector2 = _get_dict_vector2(particle, "pos", Vector2.ZERO)
		var vel: Vector2 = _get_dict_vector2(particle, "vel", Vector2.ZERO)
		vel.y += 48.0 * delta
		pos += vel * delta
		particle["age"] = age
		particle["pos"] = pos
		particle["vel"] = vel
		kept.append(particle)
	particles.assign(kept)


func _get_ghost_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for ghost_value in _ghosts:
		var ghost := ghost_value as Dictionary
		result.append(_get_dict_vector2(ghost, "pos", Vector2.ZERO))
	return result


func _get_ghost_target_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for ghost_value in _ghosts:
		var ghost := ghost_value as Dictionary
		result.append(_get_dict_vector2(ghost, "target_pos", Vector2.ZERO))
	return result


func _play_audio(registry: Object, method_name: String) -> void:
	var resolved_registry: Object = registry if registry != null else _last_audio_registry
	if resolved_registry == null:
		return
	var audio := _get_registry_instance(resolved_registry, "game_audio")
	if audio != null and audio.has_method(method_name):
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


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value is Vector2:
		return value
	return fallback


func _get_owner_float(owner: Object, key: String, fallback: float) -> float:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return float(value)


func _get_dict_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
