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
			_draw_texture_region(canvas, hit_strip_texture, player_visual_rect, _get_player_hit_sprite_region(context), context)
			return
		var hit_pose_texture = context.get("player_hit_sprite_texture", null)
		if hit_pose_texture is Texture2D:
			var hit_pose_texture_typed: Texture2D = hit_pose_texture
			_draw_texture_region(canvas, hit_pose_texture_typed, player_visual_rect, Rect2(Vector2.ZERO, hit_pose_texture_typed.get_size()), context)
			return

	var idle_texture = context.get("player_idle_sprite_texture", null)
	if not player_move_active and idle_texture is Texture2D:
		var idle_texture_typed: Texture2D = idle_texture
		_draw_texture_region(canvas, idle_texture_typed, player_visual_rect, _get_player_idle_sprite_region(context), context)
		return

	var sprite_texture = context.get("player_sprite_texture", null)
	if sprite_texture is Texture2D:
		var walk_texture_typed: Texture2D = sprite_texture
		_draw_texture_region(canvas, walk_texture_typed, player_visual_rect, _get_player_sprite_region(context), context)
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
	if bool(context.get("dash_recovering", false)):
		var stun_tint: Color = _get_dash_recovery_modulate()
		player_color = _multiply_rgb(player_color, stun_tint)
		player_color_light = _multiply_rgb(player_color_light, stun_tint)
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


func _draw_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	dest_rect: Rect2,
	source_rect: Rect2,
	context: Dictionary
) -> void:
	var sprite_modulate: Color = _get_player_sprite_modulate(context)
	var angle_degrees: float = float(context.get("player_sprite_rotation_degrees", 0.0))
	if abs(angle_degrees) <= 0.01:
		canvas.draw_texture_rect_region(texture, dest_rect, source_rect, sprite_modulate, false, true)
		return
	_draw_rotated_texture_region(canvas, texture, source_rect, dest_rect.get_center(), dest_rect.size, angle_degrees, sprite_modulate)


func _draw_rotated_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	center: Vector2,
	draw_size: Vector2,
	angle_degrees: float,
	sprite_modulate: Color
) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var half_size: Vector2 = draw_size * 0.5
	var radians: float = deg_to_rad(angle_degrees)
	var cos_a: float = cos(radians)
	var sin_a: float = sin(radians)
	var offsets := [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	]
	var points := PackedVector2Array()
	for offset in offsets:
		points.append(center + Vector2(
			offset.x * cos_a - offset.y * sin_a,
			offset.x * sin_a + offset.y * cos_a
		))

	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_max.x, uv_max.y),
		Vector2(uv_min.x, uv_max.y),
	])
	var colors := PackedColorArray([sprite_modulate, sprite_modulate, sprite_modulate, sprite_modulate])
	canvas.draw_polygon(points, colors, uvs, texture)


func _as_color(value, fallback: Color) -> Color:
	return Stage1ContextReader.as_color(value, fallback)


func _get_player_sprite_modulate(context: Dictionary) -> Color:
	if not bool(context.get("dash_recovering", false)):
		return Color.WHITE
	return _get_dash_recovery_modulate()


func _get_dash_recovery_modulate() -> Color:
	var pulse: float = 0.6 + 0.4 * sin(float(Time.get_ticks_msec()) * 0.02)
	return Color(
		(180.0 * pulse) / 255.0,
		(120.0 * pulse) / 255.0,
		(200.0 * pulse) / 255.0,
		1.0
	)


func _multiply_rgb(color: Color, modulate: Color) -> Color:
	return Color(color.r * modulate.r, color.g * modulate.g, color.b * modulate.b, color.a)
