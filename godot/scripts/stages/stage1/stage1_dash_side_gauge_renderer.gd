extends RefCounted

const BAR_HEIGHT := 40.0
const BAR_WIDTH := 3.0
const BAR_X_OFFSET := -8.0


func draw(
	canvas: CanvasItem,
	context: Dictionary,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2
) -> void:
	if canvas == null:
		return
	if str(context.get("selected_character_type", "")) == "optimus":
		return

	var max_tokens: int = max(1, int(context.get("dash_max_tokens", 1)))
	var current_tokens: int = clamp(int(context.get("dash_tokens", 0)), 0, max_tokens)
	var charge_timer: float = max(0.0, float(context.get("dash_charge_timer", 0.0)))
	var recharge_frames: float = max(1.0, float(context.get("dash_recharge_frames", 300.0)))
	if charge_timer <= 0.0 or current_tokens >= max_tokens:
		return

	var fill_ratio: float = clamp(1.0 - charge_timer / recharge_frames, 0.0, 1.0)
	# Pygame `_draw_low_dash_token_side_gauge`: when the Viper jetpack hold bar
	# is also visible, shift the dash gauge an extra 6 px left so the two bars
	# sit side by side at PLAYER.left - 8 / PLAYER.left - 14 instead of
	# overlapping at the same X.
	var bar_x_offset: float = BAR_X_OFFSET
	var jetpack_hold_ratio: float = clamp(float(context.get("viper_jetpack_hold_ratio", 0.0)), 0.0, 1.0)
	var jetpack_overheat: bool = bool(context.get("viper_jetpack_overheat", false))
	if str(context.get("selected_character_type", "")) == "viper" and (jetpack_hold_ratio > 0.01 or jetpack_overheat):
		bar_x_offset -= 6.0
	var bar_x: float = player_pos.x + bar_x_offset + shake_offset.x
	var bar_y: float = player_pos.y + paddle_size.y * 0.5 - BAR_HEIGHT * 0.5 + shake_offset.y

	var bg_rect := Rect2(bar_x - 1.0, bar_y - 1.0, BAR_WIDTH + 2.0, BAR_HEIGHT + 2.0)
	canvas.draw_rect(bg_rect, Color(0.0, 0.0, 0.0, 80.0 / 255.0), true)

	if fill_ratio <= 0.0:
		var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 90.0)
		canvas.draw_rect(
			bg_rect,
			Color(1.0, 50.0 / 255.0, 45.0 / 255.0, (45.0 + 45.0 * pulse) / 255.0),
			false,
			1.0
		)
		return

	var fill_h: int = max(1, int(round(BAR_HEIGHT * fill_ratio)))
	var low_pulse: float = 0.6 + 0.4 * sin(float(Time.get_ticks_msec()) / 80.0)
	for i in range(fill_h):
		var pct: float = float(i) / max(1.0, BAR_HEIGHT)
		var color: Color
		if current_tokens > 0:
			color = Color(
				(210.0 + 35.0 * pct) / 255.0,
				(40.0 + 70.0 * pct) / 255.0,
				(45.0 + 35.0 * pct) / 255.0,
				1.0
			)
		elif fill_ratio > 0.33:
			color = Color(
				(180.0 + 60.0 * pct) / 255.0,
				(40.0 + 85.0 * pct) / 255.0,
				(35.0 + 45.0 * pct) / 255.0,
				1.0
			)
		else:
			color = Color(
				low_pulse,
				(55.0 * min(1.0, fill_ratio / 0.33)) / 255.0,
				20.0 / 255.0,
				1.0
			)
		var y: float = bar_y + BAR_HEIGHT - 1.0 - float(i)
		canvas.draw_line(Vector2(bar_x, y), Vector2(bar_x + BAR_WIDTH, y), color, 1.0)
