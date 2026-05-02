extends RefCounted

const VIEW_WIDTH := 1488.0
const VIEW_HEIGHT := 918.0
const WINDOW_TARGET_HEIGHT_RATIO := 0.865
const WINDOW_TARGET_WIDTH_RATIO := 0.90
const GAME_RENDER_MARGIN_Y_RATIO := 0.065
const GAME_RENDER_MIN_MARGIN_Y := 30.0


func configure_window(window: Window) -> void:
	if window == null:
		return
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect()
	if usable_rect.size.x <= 0 or usable_rect.size.y <= 0:
		return

	var width_scale: float = (float(usable_rect.size.x) * WINDOW_TARGET_WIDTH_RATIO) / VIEW_WIDTH
	var height_scale: float = (float(usable_rect.size.y) * WINDOW_TARGET_HEIGHT_RATIO) / VIEW_HEIGHT
	var target_scale: float = min(width_scale, height_scale)
	if target_scale <= 0.0:
		return

	var target_size := Vector2i(
		int(round(VIEW_WIDTH * target_scale)),
		int(round(VIEW_HEIGHT * target_scale))
	)
	window.size = target_size
	window.position = usable_rect.position + (usable_rect.size - target_size) / 2


func build_game_layout(view_size: Vector2, game_width: float, game_height: float) -> Dictionary:
	if game_width <= 0.0 or game_height <= 0.0:
		return {
			"view_size": view_size,
			"game_offset": Vector2.ZERO,
			"game_size": Vector2.ZERO,
			"render_scale": 1.0,
		}

	var render_margin_y: float = max(floor(view_size.y * GAME_RENDER_MARGIN_Y_RATIO), GAME_RENDER_MIN_MARGIN_Y)
	var render_scale: float = (view_size.y - render_margin_y * 2.0) / game_height
	var game_size := Vector2(game_width * render_scale, game_height * render_scale)
	var game_offset := Vector2(
		(view_size.x - game_size.x) * 0.5,
		(view_size.y - game_size.y) * 0.5
	)
	return {
		"view_size": view_size,
		"game_offset": game_offset,
		"game_size": game_size,
		"render_scale": render_scale,
	}
