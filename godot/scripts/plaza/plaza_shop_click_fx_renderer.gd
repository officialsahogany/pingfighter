extends RefCounted

const PlazaShopStrewnVisualSpec := preload("res://scripts/plaza/plaza_shop_strewn_visual_spec.gd")


static func get_texture_key(spec: Dictionary) -> String:
	var meta := PlazaShopStrewnVisualSpec.get_animation_meta(str(spec.get("kind", "")))
	return str(meta.get("texture_key", ""))


static func draw(
	canvas: CanvasItem,
	spec: Dictionary,
	rect: Rect2,
	progress: float,
	alpha: float,
	pulse_scale: float,
	time: float,
	scale: float,
	animation_texture: Texture2D
) -> bool:
	if canvas == null or spec.is_empty() or scale <= 0.0:
		return false
	var kind := str(spec.get("kind", ""))
	if kind == "coin_pile":
		return _draw_animation_frame(canvas, kind, rect, progress, alpha, scale, animation_texture)
	var center := rect.get_center() * scale
	var radius := maxf(rect.size.x, rect.size.y) * (0.62 + progress * 1.1) * pulse_scale * scale
	canvas.draw_circle(center, radius, Color(0.0, 0.92, 1.0, 0.08 * alpha))
	canvas.draw_arc(center, radius, time * 2.8, TAU + time * 2.8, 54, Color(0.0, 0.95, 1.0, 0.72 * alpha), maxf(1.0, 2.0 * scale), true)
	canvas.draw_arc(center, radius * 0.68, -time * 3.3, TAU - time * 3.3, 42, Color(1.0, 0.25, 0.92, 0.56 * alpha), maxf(1.0, 1.6 * scale), true)
	var frame_drawn := _draw_animation_frame(canvas, kind, rect, progress, alpha, scale, animation_texture)
	for index in range(6):
		var angle := progress * TAU * 1.5 + float(index) * TAU / 6.0
		var sparkle_position := center + Vector2(cos(angle), sin(angle)) * radius * 0.72
		canvas.draw_circle(sparkle_position, (2.0 + 2.0 * (1.0 - progress)) * scale, Color(1.0, 0.86, 0.38, 0.75 * alpha))
	return frame_drawn


static func _draw_animation_frame(
	canvas: CanvasItem,
	kind: String,
	rect: Rect2,
	progress: float,
	alpha: float,
	scale: float,
	animation_texture: Texture2D
) -> bool:
	var meta := PlazaShopStrewnVisualSpec.get_animation_meta(kind)
	if meta.is_empty() or animation_texture == null:
		return false
	var frame_count := maxi(1, int(meta.get("frames", 1)))
	var columns := maxi(1, int(meta.get("cols", 1)))
	var rows := maxi(1, int(meta.get("rows", 1)))
	var frame_index := clampi(int(floor(progress * float(frame_count))), 0, frame_count - 1)
	var source_rect := PlazaShopStrewnVisualSpec.get_sheet_frame_rect(animation_texture, columns, rows, frame_index)
	var center := rect.get_center()
	var draw_size := PlazaShopStrewnVisualSpec.get_texture_draw_size(kind, rect.size) * (1.36 + sin(progress * PI) * 0.18)
	var draw_rect := Rect2((center - draw_size * 0.5) * scale, draw_size * scale)
	canvas.draw_texture_rect_region(animation_texture, draw_rect, source_rect, Color(1.0, 1.0, 1.0, clampf(alpha + 0.12, 0.0, 1.0)))
	return true
