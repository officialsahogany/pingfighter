extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const PERK_ID := "yangui_hoechun"
const FIELD_SIZE := Vector2(760.0, 750.0)
const PLAYER_BASE_PADDLE_SIZE := Vector2(155.0, 50.0)
const BALL_RADIUS_FALLBACK := 14.3
const HIT_FLASH_DURATION_SEC := 0.24
const WAVE_START_OFFSET := 48.0
const LINEAR_SPEED_PX_SEC := 130.0
const EASE_IN_DISTANCE_PX := 40.0
const EASE_IN_DURATION_SEC := EASE_IN_DISTANCE_PX * 2.0 / LINEAR_SPEED_PX_SEC
const FADE_IN_DURATION_SEC := 0.12
const WALL_DISSIPATE_DURATION_SEC := 0.25
const CONSUMED_DISSIPATE_DURATION_SEC := 0.40
const CAP_DISSIPATE_DURATION_SEC := 0.40
const MAX_LIFETIME_SEC := 7.0
const MAX_ACTIVE_WAVES := 3
const WAVE_PHASE_SPEED_RAD_SEC := 2.38
const WAVE_HALF_HEIGHT := 92.0
const WAVE_COLLISION_HALF_WIDTH := 20.0
const MIN_REFLECT_VERTICAL_RATIO := 0.55
const REFLECT_OUTWARD_BIAS_RATIO := 0.16
const GAUGE_EPSILON := 0.001

const SIDE_TRAVELING := "traveling"
const SIDE_DISSIPATING := "dissipating"
const SIDE_FINISHED := "finished"

var _waves: Array[Dictionary] = []
var _next_wave_id := 1
var _last_proc_roll := -1.0
var _last_activation_succeeded := false
var _last_reflect_side := 0
var _last_backstop_wave_id := 0
var _test_wall_termination_enabled := true
var _test_proc_rolls: Array[float] = []


func update_runtime(runtime: Object, owner: Object, registry: Object, delta: float) -> void:
	var pending_activations := _consume_pending_chosik_activations(runtime)
	if not is_active(runtime):
		if has_visible_effects():
			clear_runtime()
		return
	for _activation_index in range(pending_activations):
		_try_activate(runtime, owner, registry)
	_advance_effect(runtime, owner, registry, maxf(0.0, delta))


func is_active(runtime: Object) -> bool:
	if not PerkConversionFlags.is_enabled():
		return false
	return _get_converted_perk_level(runtime) > 0


func has_visible_effects() -> bool:
	for wave in _waves:
		if _wave_has_visible_effects(wave):
			return true
	return false


func is_wave_active() -> bool:
	for wave in _waves:
		if _wave_has_live_side(wave):
			return true
	return false


func clear_runtime() -> void:
	_waves.clear()
	_next_wave_id = 1
	_last_proc_roll = -1.0
	_last_activation_succeeded = false
	_last_reflect_side = 0
	_last_backstop_wave_id = 0
	_test_wall_termination_enabled = true


func set_test_proc_rolls(rolls: Array) -> void:
	_test_proc_rolls.clear()
	for roll_value in rolls:
		_test_proc_rolls.append(float(roll_value))


func set_test_wall_termination_enabled(enabled: bool) -> void:
	_test_wall_termination_enabled = enabled


func get_active_wave_count() -> int:
	var count := 0
	for wave in _waves:
		if (
			not bool(wave.get("retired_by_cap", false))
			and not bool(wave.get("gameplay_consumed", false))
			and _wave_has_traveling_side(wave)
		):
			count += 1
	return count


func get_last_backstop_wave_id() -> int:
	return _last_backstop_wave_id


func get_debug_wave_contexts() -> Array[Dictionary]:
	var contexts: Array[Dictionary] = []
	for wave in _waves:
		contexts.append(_build_wave_context(wave))
	return contexts


func get_draw_context() -> Dictionary:
	var wave_contexts: Array[Dictionary] = []
	for wave in _waves:
		var wave_context := _build_wave_context(wave)
		wave_contexts.append(wave_context)
	var result := {
		"visible": has_visible_effects(),
		"wave_active": is_wave_active(),
		"waves": wave_contexts,
		"last_proc_roll": _last_proc_roll,
		"last_activation_succeeded": _last_activation_succeeded,
		"last_reflect_side": _last_reflect_side,
	}
	if wave_contexts.is_empty():
		return result
	var primary: Dictionary = wave_contexts.back()
	for key in [
		"origin",
		"left_front_x",
		"right_front_x",
		"progress",
		"alpha",
		"left_alpha",
		"right_alpha",
		"phase",
		"half_height",
		"hit_flash_ratio",
		"hit_position",
		"gameplay_consumed",
		"wave_id",
	]:
		result[key] = primary.get(key)
	return result


func _try_activate(runtime: Object, owner: Object, registry: Object) -> bool:
	_last_activation_succeeded = false
	if owner == null:
		return false
	var gauge_cost := get_gauge_cost()
	var current_gauge := maxf(0.0, float(runtime._safe_owner_get(owner, "special_gauge", 0.0)))
	if current_gauge + GAUGE_EPSILON < gauge_cost:
		return false
	_last_proc_roll = _next_proc_roll()
	if _last_proc_roll >= get_trigger_chance():
		return false
	owner.set("special_gauge", maxf(0.0, current_gauge - gauge_cost))
	_start_wave(_resolve_player_center(runtime, owner))
	_last_activation_succeeded = true
	runtime.gauge_feedback.trigger_gauge_flash(runtime, {"owner": owner, "registry": registry})
	runtime.audio_router.play_yangui_hoechun_cast_audio(runtime, registry)
	return true


func _start_wave(center: Vector2) -> void:
	_remove_finished_waves()
	if get_active_wave_count() >= MAX_ACTIVE_WAVES:
		_retire_oldest_active_wave()
	var wave_id := _next_wave_id
	_next_wave_id += 1
	_waves.append({
		"wave_id": wave_id,
		"origin": center,
		"elapsed_sec": 0.0,
		"motion_elapsed_sec": 0.0,
		"phase": 0.0,
		"left_previous_distance": WAVE_START_OFFSET,
		"left_distance": WAVE_START_OFFSET,
		"right_previous_distance": WAVE_START_OFFSET,
		"right_distance": WAVE_START_OFFSET,
		"left_state": SIDE_TRAVELING,
		"right_state": SIDE_TRAVELING,
		"left_dissipate_elapsed_sec": 0.0,
		"right_dissipate_elapsed_sec": 0.0,
		"left_dissipate_duration_sec": WALL_DISSIPATE_DURATION_SEC,
		"right_dissipate_duration_sec": WALL_DISSIPATE_DURATION_SEC,
		"left_dissipate_reason": "",
		"right_dissipate_reason": "",
		"left_reached_wall": false,
		"right_reached_wall": false,
		"left_reached_wall_this_step": false,
		"right_reached_wall_this_step": false,
		"gameplay_consumed": false,
		"retired_by_cap": false,
		"hit_flash_timer_sec": 0.0,
		"hit_position": Vector2.ZERO,
		"last_reflect_side": 0,
	})
	_last_reflect_side = 0


func _advance_effect(runtime: Object, owner: Object, registry: Object, delta: float) -> void:
	if delta <= 0.0:
		return
	for wave_index in range(_waves.size()):
		var wave: Dictionary = _waves[wave_index]
		_advance_wave(wave, runtime, owner, registry, delta)
		_waves[wave_index] = wave
	_remove_finished_waves()


func _advance_wave(wave: Dictionary, runtime: Object, owner: Object, registry: Object, delta: float) -> void:
	wave["elapsed_sec"] = float(wave.get("elapsed_sec", 0.0)) + delta
	wave["phase"] = fmod(float(wave.get("phase", 0.0)) + delta * WAVE_PHASE_SPEED_RAD_SEC, TAU * 1024.0)
	wave["hit_flash_timer_sec"] = maxf(0.0, float(wave.get("hit_flash_timer_sec", 0.0)) - delta)
	_advance_existing_dissipation(wave, "left", delta)
	_advance_existing_dissipation(wave, "right", delta)

	wave["left_reached_wall_this_step"] = false
	wave["right_reached_wall_this_step"] = false
	if _wave_has_traveling_side(wave):
		wave["motion_elapsed_sec"] = float(wave.get("motion_elapsed_sec", 0.0)) + delta
		var next_distance := WAVE_START_OFFSET + _motion_distance_at_time(float(wave["motion_elapsed_sec"]))
		_advance_traveling_side(wave, "left", next_distance)
		_advance_traveling_side(wave, "right", next_distance)

	if _wave_has_live_side(wave) and float(wave["elapsed_sec"]) >= MAX_LIFETIME_SEC:
		_last_backstop_wave_id = int(wave.get("wave_id", 0))
		push_warning("Yangui Hoechun wave %d reached the %.1fs lifetime backstop" % [
			_last_backstop_wave_id,
			MAX_LIFETIME_SEC,
		])
		_finish_side(wave, "left", "backstop")
		_finish_side(wave, "right", "backstop")
		return

	if not bool(wave.get("gameplay_consumed", false)) and not bool(wave.get("retired_by_cap", false)):
		_try_reflect_ball_for_wave(wave, runtime, owner, registry)


func _advance_existing_dissipation(wave: Dictionary, side_name: String, delta: float) -> void:
	if str(wave.get(side_name + "_state", SIDE_FINISHED)) != SIDE_DISSIPATING:
		return
	var elapsed_key := side_name + "_dissipate_elapsed_sec"
	var duration_key := side_name + "_dissipate_duration_sec"
	wave[elapsed_key] = float(wave.get(elapsed_key, 0.0)) + delta
	if float(wave[elapsed_key]) >= maxf(0.001, float(wave.get(duration_key, WALL_DISSIPATE_DURATION_SEC))):
		_finish_side(wave, side_name, str(wave.get(side_name + "_dissipate_reason", "dissipated")))


func _advance_traveling_side(wave: Dictionary, side_name: String, next_distance: float) -> void:
	var distance_key := side_name + "_distance"
	var previous_key := side_name + "_previous_distance"
	wave[previous_key] = float(wave.get(distance_key, WAVE_START_OFFSET))
	if str(wave.get(side_name + "_state", SIDE_FINISHED)) != SIDE_TRAVELING:
		return
	if not _test_wall_termination_enabled:
		wave[distance_key] = next_distance
		return
	var origin: Vector2 = _as_vector2(wave.get("origin", Vector2.ZERO))
	var wall_distance := origin.x if side_name == "left" else FIELD_SIZE.x - origin.x
	wave[distance_key] = minf(next_distance, maxf(0.0, wall_distance))
	if next_distance + 0.0001 < wall_distance:
		return
	wave[side_name + "_reached_wall"] = true
	wave[side_name + "_reached_wall_this_step"] = true
	_begin_side_dissipate(wave, side_name, WALL_DISSIPATE_DURATION_SEC, "wall")


func _motion_distance_at_time(elapsed_sec: float) -> float:
	var clamped_elapsed := maxf(0.0, elapsed_sec)
	if clamped_elapsed < EASE_IN_DURATION_SEC:
		var acceleration := LINEAR_SPEED_PX_SEC / EASE_IN_DURATION_SEC
		return 0.5 * acceleration * clamped_elapsed * clamped_elapsed
	return EASE_IN_DISTANCE_PX + LINEAR_SPEED_PX_SEC * (clamped_elapsed - EASE_IN_DURATION_SEC)


func _try_reflect_ball_for_wave(wave: Dictionary, runtime: Object, owner: Object, registry: Object) -> bool:
	if owner == null or not bool(runtime._safe_owner_get(owner, "ball_active", true)):
		return false
	var ball_velocity: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "ball_vel", Vector2.ZERO))
	if ball_velocity.y <= 0.0 or ball_velocity.length_squared() <= 0.001:
		return false
	var ball_position: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "ball_pos", Vector2.ZERO))
	var ball_radius := _resolve_ball_radius(runtime, owner)
	for side in [-1, 1]:
		if not _wave_side_can_reflect(wave, side):
			continue
		if not _wave_sweep_contains_ball(wave, ball_position, ball_radius, side):
			continue
		var speed := ball_velocity.length()
		var biased_x := ball_velocity.x + float(side) * speed * REFLECT_OUTWARD_BIAS_RATIO
		var reflected := Vector2(
			biased_x,
			-maxf(absf(ball_velocity.y), speed * MIN_REFLECT_VERTICAL_RATIO)
		).normalized() * speed
		owner.set("ball_vel", reflected)
		wave["gameplay_consumed"] = true
		wave["hit_flash_timer_sec"] = HIT_FLASH_DURATION_SEC
		wave["hit_position"] = ball_position
		wave["last_reflect_side"] = side
		_last_reflect_side = side
		_begin_pair_dissipate(wave, CONSUMED_DISSIPATE_DURATION_SEC, "consumed")
		runtime.audio_router.play_yangui_hoechun_reflect_audio(runtime, registry, speed)
		return true
	return false


func _wave_side_can_reflect(wave: Dictionary, side: int) -> bool:
	var side_name := "left" if side < 0 else "right"
	return (
		str(wave.get(side_name + "_state", SIDE_FINISHED)) == SIDE_TRAVELING
		or bool(wave.get(side_name + "_reached_wall_this_step", false))
	)


func _wave_sweep_contains_ball(wave: Dictionary, ball_position: Vector2, ball_radius: float, side: int) -> bool:
	var side_name := "left" if side < 0 else "right"
	var origin: Vector2 = _as_vector2(wave.get("origin", Vector2.ZERO))
	var previous_distance := float(wave.get(side_name + "_previous_distance", WAVE_START_OFFSET))
	var current_distance := float(wave.get(side_name + "_distance", WAVE_START_OFFSET))
	var previous_front_x := origin.x + float(side) * previous_distance
	var current_front_x := origin.x + float(side) * current_distance
	var min_x := minf(previous_front_x, current_front_x) - WAVE_COLLISION_HALF_WIDTH - ball_radius
	var max_x := maxf(previous_front_x, current_front_x) + WAVE_COLLISION_HALF_WIDTH + ball_radius
	var min_y := origin.y - WAVE_HALF_HEIGHT - ball_radius
	var max_y := origin.y + WAVE_HALF_HEIGHT * 0.28 + ball_radius
	return ball_position.x >= min_x and ball_position.x <= max_x and ball_position.y >= min_y and ball_position.y <= max_y


func _begin_pair_dissipate(wave: Dictionary, duration_sec: float, reason: String) -> void:
	_begin_side_dissipate(wave, "left", duration_sec, reason)
	_begin_side_dissipate(wave, "right", duration_sec, reason)


func _begin_side_dissipate(wave: Dictionary, side_name: String, duration_sec: float, reason: String) -> void:
	if str(wave.get(side_name + "_state", SIDE_FINISHED)) != SIDE_TRAVELING:
		return
	wave[side_name + "_state"] = SIDE_DISSIPATING
	wave[side_name + "_dissipate_elapsed_sec"] = 0.0
	wave[side_name + "_dissipate_duration_sec"] = maxf(0.001, duration_sec)
	wave[side_name + "_dissipate_reason"] = reason


func _finish_side(wave: Dictionary, side_name: String, reason: String) -> void:
	wave[side_name + "_state"] = SIDE_FINISHED
	wave[side_name + "_dissipate_reason"] = reason


func _retire_oldest_active_wave() -> void:
	for wave_index in range(_waves.size()):
		var wave: Dictionary = _waves[wave_index]
		if (
			bool(wave.get("retired_by_cap", false))
			or bool(wave.get("gameplay_consumed", false))
			or not _wave_has_traveling_side(wave)
		):
			continue
		wave["retired_by_cap"] = true
		_begin_pair_dissipate(wave, CAP_DISSIPATE_DURATION_SEC, "capacity")
		_waves[wave_index] = wave
		return

func _remove_finished_waves() -> void:
	for wave_index in range(_waves.size() - 1, -1, -1):
		var wave: Dictionary = _waves[wave_index]
		if _wave_has_live_side(wave) or float(wave.get("hit_flash_timer_sec", 0.0)) > 0.0:
			continue
		_waves.remove_at(wave_index)


func _wave_has_live_side(wave: Dictionary) -> bool:
	return (
		str(wave.get("left_state", SIDE_FINISHED)) != SIDE_FINISHED
		or str(wave.get("right_state", SIDE_FINISHED)) != SIDE_FINISHED
	)


func _wave_has_traveling_side(wave: Dictionary) -> bool:
	return (
		str(wave.get("left_state", SIDE_FINISHED)) == SIDE_TRAVELING
		or str(wave.get("right_state", SIDE_FINISHED)) == SIDE_TRAVELING
	)


func _wave_has_visible_effects(wave: Dictionary) -> bool:
	return _wave_has_live_side(wave) or float(wave.get("hit_flash_timer_sec", 0.0)) > 0.0


func _build_wave_context(wave: Dictionary) -> Dictionary:
	var origin: Vector2 = _as_vector2(wave.get("origin", Vector2.ZERO))
	var left_alpha := _resolve_side_alpha(wave, "left")
	var right_alpha := _resolve_side_alpha(wave, "right")
	var hit_flash_ratio := clampf(
		float(wave.get("hit_flash_timer_sec", 0.0)) / HIT_FLASH_DURATION_SEC,
		0.0,
		1.0
	)
	return {
		"visible": maxf(left_alpha, right_alpha) > 0.001 or hit_flash_ratio > 0.001,
		"wave_active": _wave_has_live_side(wave),
		"wave_id": int(wave.get("wave_id", 0)),
		"origin": origin,
		"left_front_x": origin.x - float(wave.get("left_distance", WAVE_START_OFFSET)),
		"right_front_x": origin.x + float(wave.get("right_distance", WAVE_START_OFFSET)),
		"left_alpha": left_alpha,
		"right_alpha": right_alpha,
		"alpha": maxf(left_alpha, right_alpha),
		"progress": clampf(float(wave.get("elapsed_sec", 0.0)) / MAX_LIFETIME_SEC, 0.0, 1.0),
		"age_sec": float(wave.get("elapsed_sec", 0.0)),
		"phase": float(wave.get("phase", 0.0)),
		"half_height": WAVE_HALF_HEIGHT,
		"hit_flash_ratio": hit_flash_ratio,
		"hit_position": _as_vector2(wave.get("hit_position", Vector2.ZERO)),
		"gameplay_consumed": bool(wave.get("gameplay_consumed", false)),
		"retired_by_cap": bool(wave.get("retired_by_cap", false)),
		"left_state": str(wave.get("left_state", SIDE_FINISHED)),
		"right_state": str(wave.get("right_state", SIDE_FINISHED)),
		"left_reached_wall": bool(wave.get("left_reached_wall", false)),
		"right_reached_wall": bool(wave.get("right_reached_wall", false)),
		"left_dissipate_reason": str(wave.get("left_dissipate_reason", "")),
		"right_dissipate_reason": str(wave.get("right_dissipate_reason", "")),
		"last_reflect_side": int(wave.get("last_reflect_side", 0)),
	}


func _resolve_side_alpha(wave: Dictionary, side_name: String) -> float:
	var fade_in := clampf(float(wave.get("elapsed_sec", 0.0)) / FADE_IN_DURATION_SEC, 0.0, 1.0)
	var state := str(wave.get(side_name + "_state", SIDE_FINISHED))
	if state == SIDE_TRAVELING:
		return fade_in
	if state != SIDE_DISSIPATING:
		return 0.0
	var elapsed := float(wave.get(side_name + "_dissipate_elapsed_sec", 0.0))
	var duration := maxf(0.001, float(wave.get(side_name + "_dissipate_duration_sec", WALL_DISSIPATE_DURATION_SEC)))
	return fade_in * clampf(1.0 - elapsed / duration, 0.0, 1.0)


func _consume_pending_chosik_activations(runtime: Object) -> int:
	var perk_state: Object = runtime.runtime_perk_state_ref
	if perk_state == null or not is_instance_valid(perk_state):
		return 0
	if not perk_state.has_method("consume_pending_chosik_activations"):
		return 0
	return maxi(0, int(perk_state.consume_pending_chosik_activations()))


func _resolve_player_center(runtime: Object, owner: Object) -> Vector2:
	var position: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "player_pos", Vector2.ZERO))
	var size := Vector2(
		maxf(1.0, float(runtime._safe_owner_get(owner, "player_paddle_width", PLAYER_BASE_PADDLE_SIZE.x))),
		maxf(1.0, float(runtime._safe_owner_get(owner, "player_paddle_height", PLAYER_BASE_PADDLE_SIZE.y)))
	)
	if position == Vector2.ZERO:
		return Vector2(FIELD_SIZE.x * 0.5, FIELD_SIZE.y - size.y * 0.5)
	return position + size * 0.5


func _resolve_ball_radius(runtime: Object, owner: Object) -> float:
	var radius := float(runtime._safe_owner_get(owner, "ball_radius", 0.0))
	if radius > 0.0:
		return radius
	return maxf(1.0, float(runtime._safe_owner_get(owner, "ball_size", BALL_RADIUS_FALLBACK * 2.0)) * 0.5)


func _next_proc_roll() -> float:
	if not _test_proc_rolls.is_empty():
		return clampf(_test_proc_rolls.pop_front(), 0.0, 1.0)
	return randf()


func get_trigger_chance() -> float:
	return clampf(PerkConversionValues.get_mythic_value(PERK_ID, "trigger_chance") / 100.0, 0.0, 1.0)


func get_gauge_cost() -> float:
	return maxf(0.0, PerkConversionValues.get_mythic_value(PERK_ID, "gauge_cost"))


func _get_converted_perk_level(runtime: Object) -> int:
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		return maxi(0, int(runtime.get_converted_perk_effect_level(PERK_ID)))
	return 0


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO
