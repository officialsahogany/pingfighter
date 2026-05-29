extends RefCounted

const TREE_LAYER_ALPHA := 184.0 / 255.0
const GAME_FRAME_ALPHA := 232.0 / 255.0


func draw(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	assets: Dictionary
) -> void:
	if canvas == null:
		return
	var base_texture: Texture2D = assets.get("base_texture", null) as Texture2D
	_draw_cover_texture(canvas, base_texture, view_size)
	_draw_imagegen_unified_edge_lines(canvas, view_size, game_offset, game_size)
	_draw_imagegen_tree_layers(canvas, view_size, game_offset, game_size, assets)
	_draw_imagegen_game_frame(canvas, game_offset, game_size, assets)


func draw_background_overlay(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	assets: Dictionary
) -> void:
	if canvas == null:
		return
	var base_texture: Texture2D = assets.get("base_texture", null) as Texture2D
	_draw_cover_texture_regions(canvas, base_texture, view_size, _get_background_overlay_rects(view_size, game_offset, game_size))
	_draw_imagegen_unified_edge_lines(canvas, view_size, game_offset, game_size)
	_draw_imagegen_tree_layers(canvas, view_size, game_offset, game_size, assets)
	_draw_imagegen_game_frame(canvas, game_offset, game_size, assets)


func _draw_cover_texture(canvas: CanvasItem, texture: Texture2D, view_size: Vector2) -> void:
	if texture == null:
		return
	var source_size: Vector2 = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var scale_factor: float = max(view_size.x / source_size.x, view_size.y / source_size.y)
	var target_size: Vector2 = source_size * scale_factor
	var target_pos: Vector2 = (view_size - target_size) * 0.5
	canvas.draw_texture_rect(texture, Rect2(target_pos, target_size), false)


func _draw_cover_texture_regions(canvas: CanvasItem, texture: Texture2D, view_size: Vector2, clip_rects: Array[Rect2]) -> void:
	if texture == null:
		return
	var source_size: Vector2 = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var scale_factor: float = max(view_size.x / source_size.x, view_size.y / source_size.y)
	if scale_factor <= 0.0:
		return
	var target_size: Vector2 = source_size * scale_factor
	var target_pos: Vector2 = (view_size - target_size) * 0.5
	var full_target := Rect2(target_pos, target_size)
	for clip_rect in clip_rects:
		var clipped := clip_rect.intersection(full_target)
		if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
			continue
		var source_rect := Rect2(
			(clipped.position - target_pos) / scale_factor,
			clipped.size / scale_factor
		)
		canvas.draw_texture_rect_region(texture, clipped, source_rect, Color.WHITE, false, true)


func _get_background_overlay_rects(view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> Array[Rect2]:
	var game_rect := Rect2(game_offset, game_size)
	return [
		Rect2(0.0, 0.0, max(0.0, game_rect.position.x), view_size.y),
		Rect2(game_rect.end.x, 0.0, max(0.0, view_size.x - game_rect.end.x), view_size.y),
		Rect2(game_rect.position.x, 0.0, max(0.0, game_rect.size.x), max(0.0, game_rect.position.y)),
		Rect2(game_rect.position.x, game_rect.end.y, max(0.0, game_rect.size.x), max(0.0, view_size.y - game_rect.end.y)),
	]


func _draw_imagegen_unified_edge_lines(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2
) -> void:
	var scale_unit: int = maxi(1, int(round(game_size.x / 1280.0))) if game_size.x > 0.0 else 1
	_draw_edge_rect_line(canvas, view_size, 5.0 * float(scale_unit), _rgba255(188.0, 236.0, 202.0, 62.0), float(maxi(1, scale_unit)))
	_draw_edge_rect_line(canvas, view_size, 10.0 * float(scale_unit), _rgba255(24.0, 246.0, 230.0, 52.0), float(maxi(1, scale_unit)))
	_draw_edge_rect_line(canvas, view_size, 15.0 * float(scale_unit), _rgba255(235.0, 214.0, 170.0, 48.0), float(maxi(1, scale_unit)))

	var game_rect := Rect2(game_offset, game_size)
	if view_size.y > game_rect.end.y:
		var y: float = game_rect.end.y + max(4.0, 5.0 * float(scale_unit))
		canvas.draw_line(
			Vector2(max(0.0, game_rect.position.x - 26.0 * float(scale_unit)), y),
			Vector2(min(view_size.x, game_rect.end.x + 26.0 * float(scale_unit)), y),
			_rgba255(28.0, 220.0, 205.0, 54.0),
			float(maxi(1, scale_unit)),
			true
		)


func _draw_edge_rect_line(canvas: CanvasItem, view_size: Vector2, inset: float, color: Color, width: float) -> void:
	var rect := Rect2(Vector2(inset, inset), view_size - Vector2(inset * 2.0, inset * 2.0))
	if rect.size.x > 0.0 and rect.size.y > 0.0:
		canvas.draw_rect(rect, color, false, width, true)


func _draw_imagegen_tree_layers(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	assets: Dictionary
) -> void:
	var tree_texture: Texture2D = assets.get("tree_texture", null) as Texture2D
	var source_regions: Dictionary = _get_dictionary(assets.get("tree_source_regions", {}))
	if tree_texture == null or source_regions.is_empty():
		return
	var left_w: float = max(0.0, game_offset.x)
	var right_x: float = game_offset.x + game_size.x
	var right_w: float = max(0.0, view_size.x - right_x)
	_draw_imagegen_tree_side(
		canvas,
		tree_texture,
		source_regions,
		"left",
		Rect2(0.0, 0.0, left_w, view_size.y),
		left_w * 0.58,
		view_size.y * 0.62,
		Vector2(left_w * 0.20, view_size.y - 34.0)
	)
	_draw_imagegen_tree_side(
		canvas,
		tree_texture,
		source_regions,
		"right",
		Rect2(right_x, 0.0, right_w, view_size.y),
		right_w * 0.58,
		view_size.y * 0.62,
		Vector2(right_x + right_w * 0.80, view_size.y - 34.0)
	)


func _draw_imagegen_tree_side(
	canvas: CanvasItem,
	tree_texture: Texture2D,
	source_regions: Dictionary,
	side: String,
	clip_rect: Rect2,
	max_w: float,
	max_h: float,
	midbottom: Vector2
) -> void:
	if not source_regions.has(side):
		return
	var source: Rect2 = _get_rect2(source_regions.get(side, Rect2()))
	if clip_rect.size.x <= 2.0 or clip_rect.size.y <= 2.0 or source.size.x <= 0.0 or source.size.y <= 0.0:
		return
	var scale_factor: float = min(max_w / source.size.x, max_h / source.size.y)
	if scale_factor <= 0.0:
		return
	var target_size: Vector2 = source.size * scale_factor
	var target := Rect2(midbottom - Vector2(target_size.x * 0.5, target_size.y), target_size)
	_draw_clipped_texture_region(canvas, tree_texture, target, source, clip_rect, Color(1.0, 1.0, 1.0, TREE_LAYER_ALPHA))


func _draw_imagegen_game_frame(
	canvas: CanvasItem,
	game_offset: Vector2,
	game_size: Vector2,
	assets: Dictionary
) -> void:
	var game_frame_texture: Texture2D = assets.get("game_frame_texture", null) as Texture2D
	if game_frame_texture == null or game_size.x <= 0.0 or game_size.y <= 0.0:
		return
	var scale_factor: float = max(1.0, game_size.x / 1280.0)
	var left_margin: float = max(24.0, floor(36.0 * scale_factor))
	var right_margin: float = left_margin
	var top_margin: float = max(20.0, floor(30.0 * scale_factor))
	var bottom_margin: float = max(28.0, floor(42.0 * scale_factor))
	var outer_rect := Rect2(
		game_offset - Vector2(left_margin, top_margin),
		game_size + Vector2(left_margin + right_margin, top_margin + bottom_margin)
	)
	var inner_rect := Rect2(Vector2(left_margin, top_margin), game_size)
	var source_hole: Rect2 = _get_rect2(assets.get("game_frame_source_hole", Rect2()))
	if source_hole.size.x <= 0.0 or source_hole.size.y <= 0.0:
		canvas.draw_texture_rect(game_frame_texture, outer_rect, false, Color(1.0, 1.0, 1.0, GAME_FRAME_ALPHA))
		return

	var source_size := Vector2(float(game_frame_texture.get_width()), float(game_frame_texture.get_height()))
	var left_w: float = max(1.0, inner_rect.position.x)
	var top_h: float = max(1.0, inner_rect.position.y)
	var right_w: float = max(1.0, outer_rect.size.x - inner_rect.end.x)
	var bottom_h: float = max(1.0, outer_rect.size.y - inner_rect.end.y)
	var hole_right: float = source_hole.end.x
	var hole_bottom: float = source_hole.end.y
	_draw_game_frame_piece(canvas, game_frame_texture, outer_rect, Rect2(0.0, 0.0, source_hole.position.x, source_hole.position.y), Rect2(0.0, 0.0, left_w, top_h))
	_draw_game_frame_piece(canvas, game_frame_texture, outer_rect, Rect2(source_hole.position.x, 0.0, source_hole.size.x, source_hole.position.y), Rect2(left_w, 0.0, inner_rect.size.x, top_h))
	_draw_game_frame_piece(canvas, game_frame_texture, outer_rect, Rect2(hole_right, 0.0, source_size.x - hole_right, source_hole.position.y), Rect2(inner_rect.end.x, 0.0, right_w, top_h))
	_draw_game_frame_piece(canvas, game_frame_texture, outer_rect, Rect2(0.0, source_hole.position.y, source_hole.position.x, source_hole.size.y), Rect2(0.0, top_h, left_w, inner_rect.size.y))
	_draw_game_frame_piece(canvas, game_frame_texture, outer_rect, Rect2(hole_right, source_hole.position.y, source_size.x - hole_right, source_hole.size.y), Rect2(inner_rect.end.x, top_h, right_w, inner_rect.size.y))
	_draw_game_frame_piece(canvas, game_frame_texture, outer_rect, Rect2(0.0, hole_bottom, source_hole.position.x, source_size.y - hole_bottom), Rect2(0.0, inner_rect.end.y, left_w, bottom_h))
	_draw_game_frame_piece(canvas, game_frame_texture, outer_rect, Rect2(source_hole.position.x, hole_bottom, source_hole.size.x, source_size.y - hole_bottom), Rect2(left_w, inner_rect.end.y, inner_rect.size.x, bottom_h))
	_draw_game_frame_piece(canvas, game_frame_texture, outer_rect, Rect2(hole_right, hole_bottom, source_size.x - hole_right, source_size.y - hole_bottom), Rect2(inner_rect.end.x, inner_rect.end.y, right_w, bottom_h))


func _draw_game_frame_piece(
	canvas: CanvasItem,
	game_frame_texture: Texture2D,
	outer_rect: Rect2,
	source_rect: Rect2,
	local_dest: Rect2
) -> void:
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0 or local_dest.size.x <= 0.0 or local_dest.size.y <= 0.0:
		return
	canvas.draw_texture_rect_region(
		game_frame_texture,
		Rect2(outer_rect.position + local_dest.position, local_dest.size),
		source_rect,
		Color(1.0, 1.0, 1.0, GAME_FRAME_ALPHA),
		false,
		true
	)


func _draw_clipped_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	dest: Rect2,
	source: Rect2,
	clip_rect: Rect2,
	modulate: Color
) -> void:
	var clipped_dest: Rect2 = dest.intersection(clip_rect)
	if clipped_dest.size.x <= 0.0 or clipped_dest.size.y <= 0.0 or dest.size.x <= 0.0 or dest.size.y <= 0.0:
		return
	var source_scale := Vector2(source.size.x / dest.size.x, source.size.y / dest.size.y)
	var clipped_source := Rect2(
		source.position + (clipped_dest.position - dest.position) * source_scale,
		clipped_dest.size * source_scale
	)
	canvas.draw_texture_rect_region(texture, clipped_dest, clipped_source, modulate, false, true)


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_rect2(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()


func _rgba255(r: float, g: float, b: float, a: float) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, a / 255.0)
