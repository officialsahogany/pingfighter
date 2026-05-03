extends RefCounted

const VIEW_WIDTH := 1488.0
const VIEW_HEIGHT := 918.0
const WINDOW_TARGET_HEIGHT_RATIO := 0.865
const WINDOW_TARGET_WIDTH_RATIO := 0.90
const GAME_RENDER_MARGIN_Y_RATIO := 0.065
const GAME_RENDER_MIN_MARGIN_Y := 30.0

var _last_windowed_size := Vector2i.ZERO
var _last_windowed_position := Vector2i.ZERO


func configure_window(window: Window) -> void:
	if window == null:
		return
	if is_fullscreen(window):
		return
	var target_rect := _build_default_window_rect()
	if target_rect.size.x <= 0 or target_rect.size.y <= 0:
		return
	window.size = target_rect.size
	window.position = target_rect.position
	_remember_windowed_geometry(window)


func toggle_fullscreen(window: Window) -> void:
	if window == null:
		return
	if is_fullscreen(window):
		_restore_windowed(window)
		return
	_remember_windowed_geometry(window)
	window.mode = Window.MODE_FULLSCREEN


func is_fullscreen(window: Window) -> bool:
	if window == null:
		return false
	return window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN


func _build_default_window_rect() -> Rect2i:
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect()
	if usable_rect.size.x <= 0 or usable_rect.size.y <= 0:
		return Rect2i()

	var width_scale: float = (float(usable_rect.size.x) * WINDOW_TARGET_WIDTH_RATIO) / VIEW_WIDTH
	var height_scale: float = (float(usable_rect.size.y) * WINDOW_TARGET_HEIGHT_RATIO) / VIEW_HEIGHT
	var target_scale: float = min(width_scale, height_scale)
	if target_scale <= 0.0:
		return Rect2i()

	var target_size := Vector2i(
		int(round(VIEW_WIDTH * target_scale)),
		int(round(VIEW_HEIGHT * target_scale))
	)
	var target_position := usable_rect.position + (usable_rect.size - target_size) / 2
	return Rect2i(target_position, target_size)


func _remember_windowed_geometry(window: Window) -> void:
	if window == null or is_fullscreen(window):
		return
	if window.size.x <= 0 or window.size.y <= 0:
		return
	_last_windowed_size = window.size
	_last_windowed_position = window.position


func _restore_windowed(window: Window) -> void:
	window.mode = Window.MODE_WINDOWED
	if _last_windowed_size.x <= 0 or _last_windowed_size.y <= 0:
		var target_rect := _build_default_window_rect()
		if target_rect.size.x <= 0 or target_rect.size.y <= 0:
			return
		_last_windowed_size = target_rect.size
		_last_windowed_position = target_rect.position
	window.size = _last_windowed_size
	window.position = _last_windowed_position


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
