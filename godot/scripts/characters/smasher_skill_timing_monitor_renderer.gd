extends RefCounted

const DRIVE_MONITOR_COLOR := Color(1.0, 1.0, 0.0)
const POWER_MONITOR_COLOR := Color(1.0, 80.0 / 255.0, 80.0 / 255.0)
const DRIVE_TEXT := "Drive!"
const POWER_TEXT := "SMASHING"
const MONITOR_RADIUS := 30.0
const MONITOR_RADIUS_PULSE := 5.0
const MONITOR_PULSE_RATE := 0.015
const MONITOR_ARC_POINTS := 72
const MONITOR_TEXT_OFFSET_Y := 50.0
const MONITOR_TEXT_SIZE := 24
const DRIVE_INDICATOR_MIN_DISTANCE := 40.0
const DRIVE_INDICATOR_MAX_DISTANCE := 80.0
const DRIVE_INDICATOR_LEAD_SECONDS := 0.2
const INPUT_DISTANCE := 20.0
const DISTANCE_BACK_LIMIT := -10.0
const HORIZONTAL_EXTRA_RANGE := 15.0


func draw(canvas: CanvasItem, font: Font, context: Dictionary) -> void:
	if canvas == null or font == null:
		return
	var monitor_state: Dictionary = _build_monitor_state(context)
	if not bool(monitor_state.get("active", false)):
		return

	var center: Vector2 = _get_vector2(context, "ball_pos", Vector2.ZERO) + _get_vector2(context, "shake_offset", Vector2.ZERO)
	var color: Color = monitor_state.get("color", DRIVE_MONITOR_COLOR)
	var text: String = str(monitor_state.get("text", DRIVE_TEXT))
	var pulse_phase: float = sin(float(Time.get_ticks_msec()) * MONITOR_PULSE_RATE)
	var radius: float = MONITOR_RADIUS + MONITOR_RADIUS_PULSE * pulse_phase
	var alpha_boost: float = 0.85 + 0.15 * max(0.0, pulse_phase)

	canvas.draw_arc(
		center,
		radius + 2.0,
		0.0,
		TAU,
		MONITOR_ARC_POINTS,
		Color(color.r, color.g, color.b, 0.24 * alpha_boost),
		6.0,
		true
	)
	canvas.draw_arc(
		center,
		radius,
		0.0,
		TAU,
		MONITOR_ARC_POINTS,
		Color(color.r, color.g, color.b, 0.98),
		3.0,
		true
	)
	canvas.draw_arc(
		center,
		max(4.0, radius * 0.72),
		0.0,
		TAU,
		MONITOR_ARC_POINTS,
		Color(color.r, color.g, color.b, 0.32),
		1.5,
		true
	)
	_draw_monitor_text(canvas, font, center, text, color)


func _build_monitor_state(context: Dictionary) -> Dictionary:
	if str(context.get("selected_character_type", "smasher")).strip_edges().to_lower() != "smasher":
		return {"active": false}
	if bool(context.get("waiting_for_serve", false)):
		return {"active": false}
	if not bool(context.get("ball_active", false)):
		return {"active": false}
	if bool(context.get("drive_frame_cooldown_blocked", false)):
		return {"active": false}

	var special_gauge: float = float(context.get("special_gauge", 0.0))
	var drive_cost: float = float(context.get("drive_gauge_cost", 150.0))
	var power_cost: float = float(context.get("power_smash_gauge_cost", 300.0))
	var drive_ready: bool = (
		special_gauge >= drive_cost
		and float(context.get("drive_cooldown_remaining", 0.0)) <= 0.0
	)
	var power_ready: bool = (
		special_gauge >= power_cost
		and float(context.get("power_smash_cooldown_remaining", 0.0)) <= 0.0
	)

	var in_input_range: bool = _is_ball_in_monitor_range(context, INPUT_DISTANCE)
	if power_ready:
		return {
			"active": in_input_range,
			"color": POWER_MONITOR_COLOR,
			"text": POWER_TEXT,
		}
	if not drive_ready:
		return {"active": false}

	var velocity: Vector2 = _get_vector2(context, "ball_vel", Vector2.ZERO)
	var indicator_distance: float = clamp(
		velocity.y * DRIVE_INDICATOR_LEAD_SECONDS * 60.0,
		DRIVE_INDICATOR_MIN_DISTANCE,
		DRIVE_INDICATOR_MAX_DISTANCE
	)
	return {
		"active": _is_ball_in_monitor_range(context, indicator_distance),
		"color": DRIVE_MONITOR_COLOR,
		"text": DRIVE_TEXT,
	}


func _is_ball_in_monitor_range(context: Dictionary, distance_limit: float) -> bool:
	var ball_pos: Vector2 = _get_vector2(context, "ball_pos", Vector2.ZERO)
	var ball_vel: Vector2 = _get_vector2(context, "ball_vel", Vector2.ZERO)
	if ball_vel.y <= 0.0:
		return false

	var player_pos: Vector2 = _get_vector2(context, "player_pos", Vector2.ZERO)
	var player_paddle_width: float = float(context.get("player_paddle_width", 155.0))
	var ball_radius: float = float(context.get("ball_render_radius", 26.6175))
	var ball_to_paddle_distance: float = player_pos.y - ball_pos.y
	var player_center_x: float = player_pos.x + player_paddle_width * 0.5
	var horizontal_limit: float = player_paddle_width * 0.5 + ball_radius + HORIZONTAL_EXTRA_RANGE

	return (
		ball_to_paddle_distance <= distance_limit
		and ball_to_paddle_distance > DISTANCE_BACK_LIMIT
		and abs(ball_pos.x - player_center_x) <= horizontal_limit
	)


func _draw_monitor_text(canvas: CanvasItem, font: Font, center: Vector2, text: String, color: Color) -> void:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, MONITOR_TEXT_SIZE)
	var text_pos: Vector2 = Vector2(center.x - text_size.x * 0.5, center.y - MONITOR_TEXT_OFFSET_Y)
	canvas.draw_string(
		font,
		text_pos + Vector2(2.0, 2.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		MONITOR_TEXT_SIZE,
		Color(0.0, 0.0, 0.0, 0.70)
	)
	canvas.draw_string(
		font,
		text_pos,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		MONITOR_TEXT_SIZE,
		color
	)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
