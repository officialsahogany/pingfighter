extends RefCounted

const Stage1ContextReader := preload("res://scripts/stages/stage1/stage1_context_reader.gd")

const DASH_AFTERIMAGE_MAX_COUNT := 5
const DASH_AFTERIMAGE_SPAWN_INTERVAL_MSEC := 16
const DASH_AFTERIMAGE_LIFETIME_MSEC := 170.0
const DASH_AFTERIMAGE_MAX_ALPHA := 180.0 / 255.0

var dash_afterimages: Array = []
var dash_afterimage_last_spawn_msec: int = -100000


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var width: float = float(context.get("width", 760.0))
	var height: float = float(context.get("height", 750.0))
	var play_left: float = float(context.get("play_left", 0.0))
	var play_right: float = float(context.get("play_right", width))
	var bg_color: Color = _as_color(context.get("bg_color", Color(0.03, 0.03, 0.08)), Color(0.03, 0.03, 0.08))
	var line_color: Color = _as_color(context.get("line_color", Color(1.0, 1.0, 1.0, 0.10)), Color(1.0, 1.0, 1.0, 0.10))

	canvas.draw_rect(Rect2(0.0, 0.0, width, height), bg_color)

	canvas.draw_line(Vector2(play_left, height * 0.5) + shake_offset, Vector2(play_right, height * 0.5) + shake_offset, line_color, 1.0)
	canvas.draw_line(Vector2(play_left, 120.0) + shake_offset, Vector2(play_right, 120.0) + shake_offset, line_color, 1.0)
	canvas.draw_line(Vector2(play_left, 630.0) + shake_offset, Vector2(play_right, 630.0) + shake_offset, line_color, 1.0)


func draw_dash_trail(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if canvas == null:
		return

	var now_msec: int = Time.get_ticks_msec()
	if bool(context.get("dash_active", false)):
		_capture_dash_afterimage(context, now_msec)
	if dash_afterimages.is_empty():
		return
	_draw_dash_afterimages(canvas, shake_offset, now_msec)


func _capture_dash_afterimage(context: Dictionary, now_msec: int) -> void:
	if now_msec - dash_afterimage_last_spawn_msec < DASH_AFTERIMAGE_SPAWN_INTERVAL_MSEC and not dash_afterimages.is_empty():
		return
	var sprite_texture = context.get("player_sprite_texture", null)
	if not (sprite_texture is Texture2D):
		return
	var dash_timer: float = max(0.0, float(context.get("dash_timer", 0.0)))
	if dash_timer <= 0.0:
		return
	var base_alpha: float = min(DASH_AFTERIMAGE_MAX_ALPHA, DASH_AFTERIMAGE_MAX_ALPHA * (dash_timer / 15.0))
	dash_afterimages.append({
		"texture": sprite_texture,
		"source_rect": _get_player_sprite_region(context),
		"draw_rect": _get_player_afterimage_rect(context),
		"base_alpha": base_alpha,
		"spawn_msec": now_msec,
	})
	while dash_afterimages.size() > DASH_AFTERIMAGE_MAX_COUNT:
		dash_afterimages.pop_front()
	dash_afterimage_last_spawn_msec = now_msec


func _draw_dash_afterimages(canvas: CanvasItem, shake_offset: Vector2, now_msec: int) -> void:
	var live_afterimages: Array = []
	for afterimage in dash_afterimages:
		var spawn_msec: int = int(afterimage.get("spawn_msec", now_msec))
		var age_msec: float = float(now_msec - spawn_msec)
		var life_ratio: float = clamp(1.0 - age_msec / DASH_AFTERIMAGE_LIFETIME_MSEC, 0.0, 1.0)
		if life_ratio <= 0.0:
			continue
		var texture = afterimage.get("texture", null)
		if not (texture is Texture2D):
			continue
		var texture_typed: Texture2D = texture
		var draw_rect: Rect2 = _as_rect2(afterimage.get("draw_rect", Rect2()), Rect2())
		if draw_rect.size.x <= 0.0 or draw_rect.size.y <= 0.0:
			continue
		draw_rect.position += shake_offset
		var alpha: float = clamp(float(afterimage.get("base_alpha", DASH_AFTERIMAGE_MAX_ALPHA)) * life_ratio, 0.0, 1.0)
		canvas.draw_texture_rect_region(
			texture_typed,
			draw_rect,
			_as_rect2(afterimage.get("source_rect", Rect2()), Rect2(Vector2.ZERO, texture_typed.get_size())),
			Color(1.0, 1.0, 1.0, alpha),
			false,
			true
		)
		live_afterimages.append(afterimage)
	dash_afterimages = live_afterimages


func _get_player_afterimage_rect(context: Dictionary) -> Rect2:
	var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var paddle_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2(84.0, 16.0)), Vector2(84.0, 16.0))
	var player_anim_clock: float = float(context.get("player_anim_clock", 0.0))
	var hover_amplitude: float = float(context.get("player_hover_amplitude", 7.0))
	var hover_wave: float = sin(player_anim_clock * float(context.get("player_hover_speed", 4.5)))
	var hover_offset: float = hover_wave * hover_amplitude
	var move_bob: float = abs(sin(player_anim_clock * 10.0)) * float(context.get("player_move_bob_amplitude", 5.0))
	var player_draw_size: Vector2 = _as_vector2(context.get("player_sprite_draw_size", Vector2(250.0, 120.0)), Vector2(250.0, 120.0))
	var player_paddle_scale: float = max(0.1, float(context.get("player_paddle_scale", max(1.0, paddle_size.x / 155.0))))
	player_draw_size *= player_paddle_scale
	var player_visual_y_offset: float = -hover_offset - move_bob
	return Rect2(
		player_pos.x + paddle_size.x * 0.5 - player_draw_size.x * 0.5,
		player_pos.y + paddle_size.y - player_draw_size.y + 12.0 + player_visual_y_offset,
		player_draw_size.x,
		player_draw_size.y
	)


func _get_player_sprite_region(context: Dictionary) -> Rect2:
	var frame_x: float = float(context.get("player_sprite_frame_width", 250.0)) * float(context.get("player_sprite_frame", 0))
	return Rect2(frame_x, 0.0, float(context.get("player_sprite_frame_width", 250.0)), float(context.get("player_sprite_frame_height", 120.0)))


func _as_vector2(value, fallback: Vector2) -> Vector2:
	return Stage1ContextReader.as_vector2(value, fallback)


func _as_color(value, fallback: Color) -> Color:
	return Stage1ContextReader.as_color(value, fallback)


func _as_rect2(value, fallback: Rect2) -> Rect2:
	if value is Rect2:
		return value
	return fallback
