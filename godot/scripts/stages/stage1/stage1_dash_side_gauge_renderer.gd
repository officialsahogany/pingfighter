extends RefCounted

const BAR_HEIGHT := 40.0
const BAR_WIDTH := 3.0
# Distance (game px, at sprite scale 1.0) from the paddle CENTER to the bar.
# The player sprite is centered on the paddle center and scales with
# player_paddle_scale, so anchoring the bar a scale-proportional distance from
# that center keeps it hugging the character body at any paddle size; unlike
# the old paddle-left-edge anchor, whose absolute distance from the body grew
# as the hitbox widened. 62 clears the widest idle/walk body by ~16px while
# sitting ~24px closer than the old left-edge anchor.
const BAR_BODY_CENTER_OFFSET := 62.0
# When the viper jetpack hold bar shares the screen, the dash gauge slides one
# bar-width + gap further left so the two read as a side-by-side pair (the hold
# bar keeps the inner slot nearest the body).
const VIPER_JETPACK_PAIR_SHIFT := -6.0


# Visibility gate for the dash-token side gauge. Pure decision (no drawing) so
# it can be unit-tested directly. The gauge only surfaces when the player has
# NO dash tokens left (0 of max) AND a token is actively recharging. As long as
# at least one token remains the player can still dash, so the recharge-progress
# bar stays hidden even while a token refills in the background. Optimus uses a
# separate cooldown model and never shows this gauge.
func is_gauge_visible(context: Dictionary) -> bool:
	if str(context.get("selected_character_type", "")) == "optimus":
		return false
	var max_tokens: int = max(1, int(context.get("dash_max_tokens", 1)))
	var current_tokens: int = clamp(int(context.get("dash_tokens", 0)), 0, max_tokens)
	if current_tokens > 0:
		return false
	var charge_timer: float = max(0.0, float(context.get("dash_charge_timer", 0.0)))
	if charge_timer <= 0.0:
		return false
	return true


# Primary side-bar anchor x: paddle-center-relative and scaled by the sprite's
# visual paddle scale so the bar hugs the character body at any paddle size.
# Shared by the dash gauge AND the viper jetpack hold bar so the two read as one
# coherent stack near the body. The scale expression mirrors the caller's sprite
# scale (stage1_player_actor_renderer.gd: player_draw_size *= player_paddle_scale)
# exactly: outer max(0.1) so it tracks paddle SHRINK (strange_vial 0.5x), and
# reads player_paddle_scale from context so it follows junior-league / celestial
# visual-only overrides identically to the sprite.
func get_primary_bar_anchor_x(
	context: Dictionary,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2
) -> float:
	var paddle_scale: float = max(0.1, float(context.get("player_paddle_scale", max(1.0, paddle_size.x / 155.0))))
	var paddle_center_x: float = player_pos.x + paddle_size.x * 0.5
	return paddle_center_x - BAR_BODY_CENTER_OFFSET * paddle_scale + shake_offset.x


# Dash gauge anchor x: the primary anchor, slid left by one bar-width + gap when
# the viper jetpack hold bar is also on screen so the two sit side by side.
func get_bar_anchor_x(
	context: Dictionary,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2
) -> float:
	var bar_x: float = get_primary_bar_anchor_x(context, player_pos, paddle_size, shake_offset)
	if str(context.get("selected_character_type", "")) == "viper":
		var jetpack_hold_ratio: float = clamp(float(context.get("viper_jetpack_hold_ratio", 0.0)), 0.0, 1.0)
		var jetpack_overheat: bool = bool(context.get("viper_jetpack_overheat", false))
		if jetpack_hold_ratio > 0.01 or jetpack_overheat:
			bar_x += VIPER_JETPACK_PAIR_SHIFT
	return bar_x


func draw(
	canvas: CanvasItem,
	context: Dictionary,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2
) -> void:
	if canvas == null:
		return
	if not is_gauge_visible(context):
		return

	var charge_timer: float = max(0.0, float(context.get("dash_charge_timer", 0.0)))
	var recharge_frames: float = max(1.0, float(context.get("dash_recharge_frames", 300.0)))
	var fill_ratio: float = clamp(1.0 - charge_timer / recharge_frames, 0.0, 1.0)
	var bar_x: float = get_bar_anchor_x(context, player_pos, paddle_size, shake_offset)
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
		# current_tokens is always 0 here (the gate above returns when any token
		# remains), so the gauge only ever shows the recharge-progress colors.
		if fill_ratio > 0.33:
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
