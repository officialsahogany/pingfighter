extends RefCounted


func get_tree_rect(side: String, view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> Rect2:
	var side_rect: Rect2 = get_side_rect(side, view_size, game_offset, game_size)
	if side == "left":
		return Rect2(
			Vector2(side_rect.position.x + side_rect.size.x * 0.02, view_size.y * 0.06),
			Vector2(max(1.0, side_rect.size.x * 0.96), view_size.y * 0.78)
		)
	return Rect2(
		Vector2(side_rect.position.x + side_rect.size.x * 0.02, view_size.y * 0.18),
		Vector2(max(1.0, side_rect.size.x * 0.96), view_size.y * 0.70)
	)


func get_side_rect(side: String, view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> Rect2:
	if side == "left":
		return Rect2(Vector2.ZERO, Vector2(max(0.0, game_offset.x), view_size.y))
	var right_x: float = game_offset.x + game_size.x
	return Rect2(Vector2(right_x, 0.0), Vector2(max(0.0, view_size.x - right_x), view_size.y))


func clip_rect(rect: Rect2, view_size: Vector2) -> Rect2:
	var x1: float = clamp(rect.position.x, 0.0, view_size.x)
	var y1: float = clamp(rect.position.y, 0.0, view_size.y)
	var x2: float = clamp(rect.end.x, 0.0, view_size.x)
	var y2: float = clamp(rect.end.y, 0.0, view_size.y)
	return Rect2(Vector2(x1, y1), Vector2(max(0.0, x2 - x1), max(0.0, y2 - y1)))


func get_sheet_region(texture: Texture2D, cols: int, rows: int, index: int) -> Rect2:
	if texture == null or cols <= 0 or rows <= 0:
		return Rect2()
	var sheet_w: int = texture.get_width()
	var sheet_h: int = texture.get_height()
	var col: int = index % cols
	var row: int = int(index / cols) % rows
	var cell_w: int = int(sheet_w / cols)
	var cell_h: int = int(sheet_h / rows)
	var x: int = col * cell_w
	var y: int = row * cell_h
	var w: int = cell_w if col < cols - 1 else sheet_w - x
	var h: int = cell_h if row < rows - 1 else sheet_h - y
	return Rect2(float(x), float(y), float(w), float(h))


func fit_region_rect(source_region: Rect2, bounds: Rect2, center_ratio: Vector2) -> Rect2:
	if source_region.size.x <= 0.0 or source_region.size.y <= 0.0 or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return Rect2()
	var fit_scale: float = min(bounds.size.x / source_region.size.x, bounds.size.y / source_region.size.y)
	var target_size: Vector2 = source_region.size * fit_scale
	var center: Vector2 = bounds.position + Vector2(bounds.size.x * center_ratio.x, bounds.size.y * center_ratio.y)
	return Rect2(center - target_size * 0.5, target_size)


func draw_texture_region(canvas: CanvasItem, texture: Texture2D, dest: Rect2, source_region: Rect2, alpha: float = 1.0, flip_h: bool = false) -> void:
	if texture == null or dest.size.x <= 0.0 or dest.size.y <= 0.0 or source_region.size.x <= 0.0 or source_region.size.y <= 0.0:
		return
	var modulate := Color(1.0, 1.0, 1.0, clamp(alpha, 0.0, 1.0))
	if flip_h:
		canvas.draw_set_transform(Vector2(dest.position.x + dest.size.x, dest.position.y), 0.0, Vector2(-1.0, 1.0))
		canvas.draw_texture_rect_region(texture, Rect2(Vector2.ZERO, dest.size), source_region, modulate, false, true)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		canvas.draw_texture_rect_region(texture, dest, source_region, modulate, false, true)


func build_ellipse_points(rect: Rect2, segments: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return points
	var center: Vector2 = rect.get_center()
	var rx: float = rect.size.x * 0.5
	var ry: float = rect.size.y * 0.5
	var safe_segments: int = max(8, segments)
	for i in range(safe_segments):
		var angle: float = (float(i) / float(safe_segments)) * TAU
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points
