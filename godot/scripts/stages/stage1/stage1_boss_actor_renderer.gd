extends RefCounted

const DEFAULT_BOSS_VISUAL_CENTER_Y_OFFSET := 25.0


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_paddle_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(110.0, 18.0)), Vector2(110.0, 18.0))
	var boss_hitbox_height: float = float(context.get("boss_hitbox_height", boss_paddle_size.y))
	var boss_shadow_rect := Rect2(
		boss_pos.x + boss_paddle_size.x * 0.5 - 42.0 + shake_offset.x,
		boss_pos.y + boss_hitbox_height - 6.0 + shake_offset.y,
		84.0,
		12.0
	)
	canvas.draw_rect(boss_shadow_rect, Color(0.0, 0.0, 0.0, 0.16), true)

	var boss_sprite_sheet = context.get("boss_sprite_sheet", null)
	if boss_sprite_sheet is Texture2D:
		var boss_draw_size: Vector2 = _as_vector2(context.get("boss_sprite_draw_size", Vector2(80.0, 160.0)), Vector2(80.0, 160.0))
		var boss_visual_center_y: float = boss_pos.y + boss_hitbox_height * 0.5 + float(context.get("boss_visual_center_y_offset", DEFAULT_BOSS_VISUAL_CENTER_Y_OFFSET))
		var boss_visual_rect := Rect2(
			boss_pos.x + boss_paddle_size.x * 0.5 - boss_draw_size.x * 0.5 + shake_offset.x,
			boss_visual_center_y - boss_draw_size.y * 0.5 + shake_offset.y,
			boss_draw_size.x,
			boss_draw_size.y
		)
		var boss_hit_sprite_sheet = context.get("boss_hit_sprite_sheet", null)
		if bool(context.get("boss_hit_active", false)) and boss_hit_sprite_sheet is Texture2D:
			var boss_hit_texture: Texture2D = boss_hit_sprite_sheet
			canvas.draw_texture_rect_region(boss_hit_texture, boss_visual_rect, _get_boss_hit_sprite_region(context), Color.WHITE, false, true)
		else:
			var boss_walk_texture: Texture2D = boss_sprite_sheet
			canvas.draw_texture_rect_region(boss_walk_texture, boss_visual_rect, _get_boss_sprite_region(context), Color.WHITE, false, true)
	else:
		_draw_boss_fallback(canvas, context, boss_pos, boss_paddle_size, shake_offset)


func _draw_boss_fallback(canvas: CanvasItem, context: Dictionary, boss_pos: Vector2, boss_paddle_size: Vector2, shake_offset: Vector2) -> void:
	var boss_color: Color = _as_color(context.get("boss_color", Color(1.0, 0.25, 0.25)), Color(1.0, 0.25, 0.25))
	var boss_color_light: Color = _as_color(context.get("boss_color_light", Color(1.0, 0.45, 0.35)), Color(1.0, 0.45, 0.35))
	canvas.draw_rect(Rect2(boss_pos + shake_offset, boss_paddle_size), boss_color)
	canvas.draw_rect(
		Rect2(
			boss_pos.x + 2.0 + shake_offset.x,
			boss_pos.y + boss_paddle_size.y - boss_paddle_size.y / 3.0 + shake_offset.y,
			boss_paddle_size.x - 4.0,
			boss_paddle_size.y / 3.0
		),
		boss_color_light
	)


func _get_boss_hit_sprite_region(context: Dictionary) -> Rect2:
	var hit_frame_count: int = max(1, int(context.get("boss_hit_frame_count", 6)))
	var frame_width_float: float = 1024.0 / float(hit_frame_count)
	var frame_center_x: float = floor(frame_width_float * (float(context.get("boss_hit_frame", 0)) + 0.5))
	var frame_x: float = frame_center_x - float(context.get("boss_sprite_frame_width", 162.0)) * 0.5
	var frame_y: float = float(context.get("boss_sprite_frame_height", 512.0)) * float(context.get("boss_hit_row", 0))
	return Rect2(frame_x, frame_y, float(context.get("boss_sprite_frame_width", 162.0)), float(context.get("boss_sprite_frame_height", 512.0)))


func _get_boss_sprite_region(context: Dictionary) -> Rect2:
	var frame_count: int = max(1, int(context.get("boss_sprite_frame_count", 6)))
	var frame_width_float: float = 1024.0 / float(frame_count)
	var frame_center_x: float = floor(frame_width_float * (float(context.get("boss_sprite_frame", 0)) + 0.5))
	var frame_x: float = frame_center_x - float(context.get("boss_sprite_frame_width", 162.0)) * 0.5
	var frame_y: float = float(context.get("boss_sprite_frame_height", 512.0)) * float(context.get("boss_sprite_row", 1))
	return Rect2(frame_x, frame_y, float(context.get("boss_sprite_frame_width", 162.0)), float(context.get("boss_sprite_frame_height", 512.0)))


func _as_vector2(value, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_color(value, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback
