extends RefCounted

const ANIM_SECONDS := 0.70
const SWING_PREP_SECONDS := 0.50
const SWING_MAIN_SECONDS := 0.50
const RETRACT_HIT_GRACE_SECONDS := 2.0 / 60.0
const HIT_COOLDOWN_MSEC := 90
const DAMAGE_FLASH_SECONDS := 0.18
const HIT_PULSE_SECONDS := 0.22
const MOVE_MULTIPLIER := 0.25
const SHIELD_DURABILITY_MAX := 5
const SHIELD_GAUGE_GAIN := 60.0
const BASE_SHIELD_WIDTH := 220.0
const BASE_SHIELD_HEIGHT := 66.0
const SWING_WIDTH_BONUS := 42.0
const SWING_CENTER_SHIFT := 38.0

var umbrella_open := false
var umbrella_anim_timer := 0.0
var umbrella_retracting := false
var umbrella_gauge := SHIELD_DURABILITY_MAX
var umbrella_damage_flash_timer := 0.0
var umbrella_hit_pulse_timer := 0.0
var umbrella_swing_active := false
var umbrella_swing_timer := 0.0
var umbrella_swing_direction := 0
var _last_hit_msec := -100000
var _last_player_pos := Vector2(302.5, 700.0)
var _last_player_size := Vector2(155.0, 50.0)


func reset() -> void:
	umbrella_open = false
	umbrella_anim_timer = 0.0
	umbrella_retracting = false
	umbrella_gauge = SHIELD_DURABILITY_MAX
	umbrella_damage_flash_timer = 0.0
	umbrella_hit_pulse_timer = 0.0
	umbrella_swing_active = false
	umbrella_swing_timer = 0.0
	umbrella_swing_direction = 0
	_last_hit_msec = -100000


func reset_round(_deps: Dictionary = {}) -> void:
	reset()


func update_input(
	delta: float,
	input_snapshot: Dictionary,
	current_msec: int,
	special_gauge: float,
	player_pos: Vector2,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	_last_player_pos = player_pos
	_last_player_size = Vector2(
		max(1.0, float(config.get("paddle_width", _last_player_size.x))),
		max(1.0, float(config.get("paddle_height", _last_player_size.y)))
	)
	var input_locked: bool = bool(config.get("player_skill_input_locked", false))
	if input_locked:
		_tick_timers(delta)
		return _build_owner_snapshot(special_gauge)

	if bool(input_snapshot.get("up_just_pressed", false)):
		if umbrella_open or umbrella_retracting:
			_start_close()
		else:
			_start_open()

	_tick_timers(delta)
	var swing_direction: int = int(input_snapshot.get("blacksmith_swing_direction", 0))
	if (
		is_guard_ready()
		and swing_direction != 0
		and bool(input_snapshot.get("action_just_pressed", false))
	):
		_start_swing(swing_direction, current_msec, deps)
	return _build_owner_snapshot(special_gauge)


func update_effects(fps_scale: float, context: Dictionary = {}, _deps: Dictionary = {}) -> Dictionary:
	_last_player_pos = _get_vector2(context, "player_pos", _last_player_pos)
	_last_player_size = _get_vector2(context, "player_paddle_size", _last_player_size)
	_tick_timers(max(0.0, fps_scale) / 60.0)
	return _build_owner_snapshot(float(context.get("special_gauge", 0.0)))


func needs_effect_update() -> bool:
	return has_visible_effects() or umbrella_damage_flash_timer > 0.0 or umbrella_hit_pulse_timer > 0.0


func has_visible_effects() -> bool:
	return get_open_ratio() > 0.01 or umbrella_swing_active or umbrella_hit_pulse_timer > 0.0


func is_guard_active() -> bool:
	return (
		umbrella_open
		or (umbrella_retracting and umbrella_anim_timer > 0.0)
	)


func is_guard_ready() -> bool:
	return umbrella_open and not umbrella_retracting and umbrella_anim_timer <= 0.0


func get_player_speed_multiplier() -> float:
	return MOVE_MULTIPLIER if is_guard_active() else 1.0


func get_ball_collision_context(context: Dictionary = {}) -> Dictionary:
	if not context.is_empty():
		_last_player_pos = _get_vector2(context, "player_pos", _last_player_pos)
		_last_player_size = _get_vector2(context, "player_paddle_size", _last_player_size)
	if not is_guard_active():
		return {}
	var rect: Rect2 = _get_shield_rect()
	return {
		"blacksmith_thor_shield_active": true,
		"blacksmith_thor_shield_rect": rect,
		"blacksmith_thor_shield_paddle_w": rect.size.x,
		"blacksmith_umbrella_open": umbrella_open,
		"blacksmith_umbrella_anim_timer": umbrella_anim_timer,
		"blacksmith_umbrella_retracting": umbrella_retracting,
		"blacksmith_umbrella_swing_active": umbrella_swing_active,
		"blacksmith_umbrella_gauge": umbrella_gauge,
		"blacksmith_umbrella_gauge_gain": SHIELD_GAUGE_GAIN,
	}


func notify_ball_hit(
	ball_pos: Vector2,
	ball_vel: Vector2,
	gauge_before_player_hit: float,
	gauge_after_player_hit: float,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var current_msec: int = int(context.get("current_msec", Time.get_ticks_msec()))
	if current_msec - _last_hit_msec < HIT_COOLDOWN_MSEC:
		return {}
	_last_hit_msec = current_msec
	umbrella_damage_flash_timer = DAMAGE_FLASH_SECONDS
	umbrella_hit_pulse_timer = HIT_PULSE_SECONDS
	umbrella_gauge = max(0, umbrella_gauge - 1)
	if umbrella_gauge <= 0:
		_start_close()
	var gauge_max: float = max(1.0, float(context.get("gauge_max", context.get("special_gauge_max", 500.0))))
	var next_special_gauge: float = max(
		gauge_after_player_hit,
		min(gauge_max, gauge_before_player_hit + _get_effective_gauge_gain(context))
	)
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_wall_hit"):
		audio.play_wall_hit(max(8.0, abs(ball_vel.y)))
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(0.018, 0.55)
	var result: Dictionary = _build_owner_snapshot(next_special_gauge)
	result["blacksmith_thor_shield_hit"] = true
	result["blacksmith_thor_shield_hit_pos"] = ball_pos
	result["suppress_paddle_hit_knockback"] = true
	result["paddle_hit_pulse_kind"] = "blacksmith_thor_shield"
	result["paddle_hit_pulse_intensity"] = 0.74
	return result


func draw(canvas: CanvasItem, shake_offset: Vector2) -> void:
	if canvas == null or not has_visible_effects():
		return
	var ratio: float = get_open_ratio()
	var center: Vector2 = _last_player_pos + Vector2(_last_player_size.x * 0.5, 8.0) + shake_offset
	var swing_ratio: float = get_swing_ratio()
	var swing_side: float = float(umbrella_swing_direction)
	var width: float = (BASE_SHIELD_WIDTH + _last_player_size.x * 0.24) * ratio
	var height: float = BASE_SHIELD_HEIGHT * ratio
	if umbrella_swing_active:
		width += SWING_WIDTH_BONUS * sin(swing_ratio * PI)
		center.x += swing_side * SWING_CENTER_SHIFT * sin(swing_ratio * PI)
	var flash: float = clamp(umbrella_damage_flash_timer / DAMAGE_FLASH_SECONDS, 0.0, 1.0)
	var pulse: float = clamp(umbrella_hit_pulse_timer / HIT_PULSE_SECONDS, 0.0, 1.0)
	var core_color := Color(0.78, 0.88, 0.98, 0.36 + 0.18 * pulse).lerp(Color(1.0, 0.58, 0.38, 0.72), flash)
	var rim_color := Color(0.97, 0.78, 0.28, 0.82 + 0.14 * pulse).lerp(Color(1.0, 0.96, 0.82, 0.96), flash)
	var inner_color := Color(0.28, 0.62, 0.94, 0.34)
	_draw_ellipse_arc(canvas, center, Vector2(width * 0.5, height), PI, TAU, rim_color, 5.0)
	_draw_ellipse_arc(canvas, center + Vector2(0.0, 3.0), Vector2(width * 0.43, height * 0.73), PI, TAU, inner_color, 2.0)
	for marker in [-0.5, 0.0, 0.5]:
		var start := center + Vector2(width * marker * 0.5, 0.0)
		var top := center + Vector2(width * marker * 0.23, -height * 0.82)
		canvas.draw_line(start, top, Color(0.98, 0.84, 0.42, 0.48), 1.4, true)
	if ratio > 0.12:
		var panel_rect := Rect2(center + Vector2(-width * 0.42, -height * 0.55), Vector2(width * 0.84, height * 0.55))
		canvas.draw_rect(panel_rect, core_color)
	if umbrella_swing_active:
		var slash_center := center + Vector2(swing_side * width * 0.34, -height * 0.36)
		var slash_radius := Vector2(width * 0.42, height * 0.82)
		_draw_ellipse_arc(canvas, slash_center, slash_radius, PI * 1.05, PI * 1.95, Color(1.0, 0.88, 0.40, 0.58), 4.0)
		_draw_ellipse_arc(canvas, slash_center, slash_radius * 0.72, PI * 1.08, PI * 1.92, Color(0.58, 0.86, 1.0, 0.28), 2.0)


func get_open_ratio() -> float:
	if umbrella_open:
		if umbrella_anim_timer <= 0.0:
			return 1.0
		return clamp(1.0 - umbrella_anim_timer / ANIM_SECONDS, 0.0, 1.0)
	if umbrella_retracting:
		return clamp(umbrella_anim_timer / ANIM_SECONDS, 0.0, 1.0)
	return 0.0


func get_swing_ratio() -> float:
	if not umbrella_swing_active:
		return 0.0
	var total: float = SWING_PREP_SECONDS + SWING_MAIN_SECONDS
	return clamp(1.0 - umbrella_swing_timer / total, 0.0, 1.0)


func get_snapshot() -> Dictionary:
	return _build_owner_snapshot(0.0)


func _tick_timers(delta: float) -> void:
	if umbrella_anim_timer > 0.0:
		umbrella_anim_timer = max(0.0, umbrella_anim_timer - delta)
		if umbrella_anim_timer <= 0.0 and umbrella_retracting:
			umbrella_retracting = false
	if umbrella_swing_active:
		umbrella_swing_timer = max(0.0, umbrella_swing_timer - delta)
		if umbrella_swing_timer <= 0.0:
			umbrella_swing_active = false
			umbrella_swing_direction = 0
	if umbrella_damage_flash_timer > 0.0:
		umbrella_damage_flash_timer = max(0.0, umbrella_damage_flash_timer - delta)
	if umbrella_hit_pulse_timer > 0.0:
		umbrella_hit_pulse_timer = max(0.0, umbrella_hit_pulse_timer - delta)


func _start_open() -> void:
	umbrella_open = true
	umbrella_retracting = false
	umbrella_anim_timer = ANIM_SECONDS
	if umbrella_gauge <= 0:
		umbrella_gauge = SHIELD_DURABILITY_MAX


func _start_close() -> void:
	umbrella_open = false
	umbrella_retracting = true
	umbrella_anim_timer = max(ANIM_SECONDS, RETRACT_HIT_GRACE_SECONDS)
	umbrella_swing_active = false
	umbrella_swing_timer = 0.0
	umbrella_swing_direction = 0


func _start_swing(direction: int, _current_msec: int, _deps: Dictionary) -> void:
	umbrella_swing_active = true
	umbrella_swing_timer = SWING_PREP_SECONDS + SWING_MAIN_SECONDS
	umbrella_swing_direction = direction


func _get_shield_rect() -> Rect2:
	var ratio: float = max(0.18, get_open_ratio())
	var swing_ratio: float = sin(get_swing_ratio() * PI) if umbrella_swing_active else 0.0
	var width: float = (BASE_SHIELD_WIDTH + _last_player_size.x * 0.24) * ratio + SWING_WIDTH_BONUS * swing_ratio
	var height: float = max(18.0, BASE_SHIELD_HEIGHT * ratio)
	var center_x: float = _last_player_pos.x + _last_player_size.x * 0.5 + float(umbrella_swing_direction) * SWING_CENTER_SHIFT * swing_ratio
	var bottom_y: float = _last_player_pos.y + 8.0
	return Rect2(center_x - width * 0.5, bottom_y - height, width, height + 16.0)


func _get_effective_gauge_gain(context: Dictionary) -> float:
	return max(0.0, float(context.get("blacksmith_umbrella_gauge_gain", SHIELD_GAUGE_GAIN)))


func _build_owner_snapshot(special_gauge: float) -> Dictionary:
	return {
		"special_gauge": special_gauge,
		"blacksmith_umbrella_open": umbrella_open,
		"blacksmith_umbrella_anim_timer": umbrella_anim_timer,
		"blacksmith_umbrella_retracting": umbrella_retracting,
		"blacksmith_umbrella_swing_active": umbrella_swing_active,
		"blacksmith_umbrella_swing_direction": umbrella_swing_direction,
		"blacksmith_umbrella_swing_timer": umbrella_swing_timer,
		"blacksmith_umbrella_gauge": umbrella_gauge,
		"blacksmith_umbrella_gauge_max": SHIELD_DURABILITY_MAX,
		"blacksmith_umbrella_gauge_gain": SHIELD_GAUGE_GAIN,
		"blacksmith_umbrella_damage_flash_timer": umbrella_damage_flash_timer,
		"blacksmith_umbrella_hit_pulse_timer": umbrella_hit_pulse_timer,
	}


func _draw_ellipse_arc(
	canvas: CanvasItem,
	center: Vector2,
	radius: Vector2,
	start_angle: float,
	end_angle: float,
	color: Color,
	width: float
) -> void:
	var points := PackedVector2Array()
	var segments := 36
	for index in range(segments + 1):
		var t: float = float(index) / float(segments)
		var angle: float = lerp(start_angle, end_angle, t)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	canvas.draw_polyline(points, color, width, true)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
