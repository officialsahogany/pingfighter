extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const PERK_ID := "yangui_hoechun"
const FIELD_SIZE := Vector2(760.0, 750.0)
const PLAYER_BASE_PADDLE_SIZE := Vector2(155.0, 50.0)
const BALL_RADIUS_FALLBACK := 14.3
const EFFECT_DURATION_SEC := 1.45
const HIT_FLASH_DURATION_SEC := 0.24
const WAVE_START_OFFSET := 48.0
const WAVE_TRAVEL_DISTANCE := 270.0
const WAVE_HALF_HEIGHT := 92.0
const WAVE_COLLISION_HALF_WIDTH := 20.0
const MIN_REFLECT_VERTICAL_RATIO := 0.55
const REFLECT_OUTWARD_BIAS_RATIO := 0.16
const GAUGE_EPSILON := 0.001

var _effect_timer_sec := 0.0
var _effect_elapsed_sec := 0.0
var _origin := Vector2.ZERO
var _previous_distance := WAVE_START_OFFSET
var _distance := WAVE_START_OFFSET
var _phase := 0.0
var _gameplay_consumed := false
var _hit_flash_timer_sec := 0.0
var _hit_position := Vector2.ZERO
var _last_proc_roll := -1.0
var _last_activation_succeeded := false
var _last_reflect_side := 0
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
	return _effect_timer_sec > 0.0 or _hit_flash_timer_sec > 0.0


func is_wave_active() -> bool:
	return _effect_timer_sec > 0.0


func clear_runtime() -> void:
	_effect_timer_sec = 0.0
	_effect_elapsed_sec = 0.0
	_origin = Vector2.ZERO
	_previous_distance = WAVE_START_OFFSET
	_distance = WAVE_START_OFFSET
	_phase = 0.0
	_gameplay_consumed = false
	_hit_flash_timer_sec = 0.0
	_hit_position = Vector2.ZERO
	_last_proc_roll = -1.0
	_last_activation_succeeded = false
	_last_reflect_side = 0


func set_test_proc_rolls(rolls: Array) -> void:
	_test_proc_rolls.clear()
	for roll_value in rolls:
		_test_proc_rolls.append(float(roll_value))


func get_draw_context() -> Dictionary:
	var duration := maxf(EFFECT_DURATION_SEC, 0.001)
	var progress := clampf(_effect_elapsed_sec / duration, 0.0, 1.0)
	var fade_in := clampf(progress / 0.10, 0.0, 1.0)
	var fade_out := clampf((1.0 - progress) / 0.22, 0.0, 1.0)
	return {
		"visible": has_visible_effects(),
		"wave_active": is_wave_active(),
		"origin": _origin,
		"left_front_x": _origin.x - _distance,
		"right_front_x": _origin.x + _distance,
		"progress": progress,
		"alpha": minf(fade_in, fade_out),
		"phase": _phase,
		"half_height": WAVE_HALF_HEIGHT,
		"hit_flash_ratio": clampf(_hit_flash_timer_sec / HIT_FLASH_DURATION_SEC, 0.0, 1.0),
		"hit_position": _hit_position,
		"gameplay_consumed": _gameplay_consumed,
		"last_proc_roll": _last_proc_roll,
		"last_activation_succeeded": _last_activation_succeeded,
		"last_reflect_side": _last_reflect_side,
	}


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
	_origin = center
	_effect_timer_sec = EFFECT_DURATION_SEC
	_effect_elapsed_sec = 0.0
	_previous_distance = WAVE_START_OFFSET
	_distance = WAVE_START_OFFSET
	_phase = 0.0
	_gameplay_consumed = false
	_hit_flash_timer_sec = 0.0
	_hit_position = Vector2.ZERO
	_last_reflect_side = 0


func _advance_effect(runtime: Object, owner: Object, registry: Object, delta: float) -> void:
	if _hit_flash_timer_sec > 0.0:
		_hit_flash_timer_sec = maxf(0.0, _hit_flash_timer_sec - delta)
	if _effect_timer_sec <= 0.0:
		return
	_previous_distance = _distance
	_effect_elapsed_sec = minf(EFFECT_DURATION_SEC, _effect_elapsed_sec + delta)
	_effect_timer_sec = maxf(0.0, EFFECT_DURATION_SEC - _effect_elapsed_sec)
	_phase = fmod(_phase + delta * 3.4, TAU * 1024.0)
	var progress := clampf(_effect_elapsed_sec / EFFECT_DURATION_SEC, 0.0, 1.0)
	var eased_progress := 1.0 - pow(1.0 - progress, 1.35)
	_distance = WAVE_START_OFFSET + WAVE_TRAVEL_DISTANCE * eased_progress
	if not _gameplay_consumed:
		_try_reflect_ball(runtime, owner, registry)


func _try_reflect_ball(runtime: Object, owner: Object, registry: Object) -> bool:
	if owner == null or not bool(runtime._safe_owner_get(owner, "ball_active", true)):
		return false
	var ball_velocity: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "ball_vel", Vector2.ZERO))
	if ball_velocity.y <= 0.0 or ball_velocity.length_squared() <= 0.001:
		return false
	var ball_position: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "ball_pos", Vector2.ZERO))
	var ball_radius := _resolve_ball_radius(runtime, owner)
	for side in [-1, 1]:
		if not _wave_sweep_contains_ball(ball_position, ball_radius, side):
			continue
		var speed := ball_velocity.length()
		var biased_x := ball_velocity.x + float(side) * speed * REFLECT_OUTWARD_BIAS_RATIO
		var reflected := Vector2(
			biased_x,
			-maxf(absf(ball_velocity.y), speed * MIN_REFLECT_VERTICAL_RATIO)
		).normalized() * speed
		owner.set("ball_vel", reflected)
		_gameplay_consumed = true
		_hit_flash_timer_sec = HIT_FLASH_DURATION_SEC
		_hit_position = ball_position
		_last_reflect_side = side
		runtime.audio_router.play_yangui_hoechun_reflect_audio(runtime, registry, speed)
		return true
	return false


func _wave_sweep_contains_ball(ball_position: Vector2, ball_radius: float, side: int) -> bool:
	var previous_front_x := _origin.x + float(side) * _previous_distance
	var current_front_x := _origin.x + float(side) * _distance
	var min_x := minf(previous_front_x, current_front_x) - WAVE_COLLISION_HALF_WIDTH - ball_radius
	var max_x := maxf(previous_front_x, current_front_x) + WAVE_COLLISION_HALF_WIDTH + ball_radius
	var min_y := _origin.y - WAVE_HALF_HEIGHT - ball_radius
	var max_y := _origin.y + WAVE_HALF_HEIGHT * 0.28 + ball_radius
	return ball_position.x >= min_x and ball_position.x <= max_x and ball_position.y >= min_y and ball_position.y <= max_y


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
