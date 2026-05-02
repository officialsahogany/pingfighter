extends RefCounted

const Stage1ContextReader := preload("res://scripts/stages/stage1/stage1_context_reader.gd")


func draw(
	canvas: CanvasItem,
	context: Dictionary,
	player_visual_rect: Rect2,
	player_move_active: bool,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2
) -> void:
	if bool(context.get("player_hit_active", false)):
		var hit_texture = context.get("player_hit_left_strip_texture", null) if int(context.get("player_hit_side", 1)) < 0 else context.get("player_hit_right_strip_texture", null)
		if hit_texture is Texture2D:
			var hit_strip_texture: Texture2D = hit_texture
			canvas.draw_texture_rect_region(hit_strip_texture, player_visual_rect, _get_player_hit_sprite_region(context), Color.WHITE, false, true)
			return
		var hit_pose_texture = context.get("player_hit_sprite_texture", null)
		if hit_pose_texture is Texture2D:
			var hit_pose_texture_typed: Texture2D = hit_pose_texture
			canvas.draw_texture_rect(hit_pose_texture_typed, player_visual_rect, false)
			return

	var idle_texture = context.get("player_idle_sprite_texture", null)
	if not player_move_active and idle_texture is Texture2D:
		var idle_texture_typed: Texture2D = idle_texture
		canvas.draw_texture_rect_region(idle_texture_typed, player_visual_rect, _get_player_idle_sprite_region(context), Color.WHITE, false, true)
		return

	var sprite_texture = context.get("player_sprite_texture", null)
	if sprite_texture is Texture2D:
		var walk_texture_typed: Texture2D = sprite_texture
		canvas.draw_texture_rect_region(walk_texture_typed, player_visual_rect, _get_player_sprite_region(context), Color.WHITE, false, true)
		return

	draw_fallback(canvas, context, player_pos, paddle_size, shake_offset)


func draw_fallback(
	canvas: CanvasItem,
	context: Dictionary,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2
) -> void:
	var player_color: Color = _as_color(context.get("player_color", Color(0.25, 0.45, 1.0)), Color(0.25, 0.45, 1.0))
	var player_color_light: Color = _as_color(context.get("player_color_light", Color(0.40, 0.60, 1.0)), Color(0.40, 0.60, 1.0))
	canvas.draw_rect(Rect2(player_pos + shake_offset, paddle_size), player_color)
	canvas.draw_rect(
		Rect2(player_pos.x + 2.0 + shake_offset.x, player_pos.y + 2.0 + shake_offset.y, paddle_size.x - 4.0, paddle_size.y / 3.0),
		player_color_light
	)


func _get_player_idle_sprite_region(context: Dictionary) -> Rect2:
	var frame_x: float = float(context.get("player_sprite_frame_width", 250.0)) * float(context.get("player_idle_frame", 0))
	return Rect2(frame_x, 0.0, float(context.get("player_sprite_frame_width", 250.0)), float(context.get("player_sprite_frame_height", 120.0)))


func _get_player_hit_sprite_region(context: Dictionary) -> Rect2:
	var frame_x: float = float(context.get("player_hit_frame_width", 250.0)) * float(context.get("player_hit_frame", 0))
	return Rect2(frame_x, 0.0, float(context.get("player_hit_frame_width", 250.0)), float(context.get("player_hit_frame_height", 120.0)))


func _get_player_sprite_region(context: Dictionary) -> Rect2:
	var frame_x: float = float(context.get("player_sprite_frame_width", 250.0)) * float(context.get("player_sprite_frame", 0))
	return Rect2(frame_x, 0.0, float(context.get("player_sprite_frame_width", 250.0)), float(context.get("player_sprite_frame_height", 120.0)))


func _as_color(value, fallback: Color) -> Color:
	return Stage1ContextReader.as_color(value, fallback)
