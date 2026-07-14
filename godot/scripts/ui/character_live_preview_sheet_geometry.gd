extends RefCounted

# Pure sheet trim and rectangle geometry for CharacterLivePreview. Texture
# loading, first-use fallback timing, and draw state stay in the @tool Control.


static func parse_rect(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	if value is Dictionary:
		var rect_dict: Dictionary = value
		return Rect2(
			Vector2(float(rect_dict.get("x", 0.0)), float(rect_dict.get("y", 0.0))),
			Vector2(float(rect_dict.get("w", 0.0)), float(rect_dict.get("h", 0.0)))
		)
	if value is Array:
		var rect_array: Array = value
		if rect_array.size() >= 4:
			return Rect2(
				Vector2(float(rect_array[0]), float(rect_array[1])),
				Vector2(float(rect_array[2]), float(rect_array[3]))
			)
	return Rect2()


static func apply_relative_trim(source_rect: Rect2, relative_trim_rect: Rect2) -> Rect2:
	if relative_trim_rect.size.x <= 1.0 or relative_trim_rect.size.y <= 1.0:
		return source_rect
	return Rect2(source_rect.position + relative_trim_rect.position, relative_trim_rect.size)


static func build_alpha_trim_rect(
	image: Image,
	texture_size: Vector2,
	columns: int,
	rows: int,
	frame_count: int,
	sample_frame_limit: int,
	padding_ratio: float
) -> Rect2:
	if image == null or image.get_width() <= 1 or image.get_height() <= 1:
		return Rect2()
	var safe_columns := maxi(1, columns)
	var safe_rows := maxi(1, rows)
	var safe_frame_count := maxi(1, frame_count)
	var cell_w := maxi(1, int(floor(texture_size.x / float(safe_columns))))
	var cell_h := maxi(1, int(floor(texture_size.y / float(safe_rows))))
	var min_x := cell_w
	var min_y := cell_h
	var max_x := 0
	var max_y := 0
	var found := false
	for frame_index in _build_sample_indices(safe_frame_count, sample_frame_limit):
		var col := frame_index % safe_columns
		@warning_ignore("integer_division")
		var row := int(frame_index / safe_columns)
		var origin := Vector2i(col * cell_w, row * cell_h)
		if origin.x >= image.get_width() or origin.y >= image.get_height():
			continue
		var region_size := Vector2i(
			mini(cell_w, image.get_width() - origin.x),
			mini(cell_h, image.get_height() - origin.y)
		)
		if region_size.x <= 1 or region_size.y <= 1:
			continue
		var used := image.get_region(Rect2i(origin, region_size)).get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			continue
		var used_end := used.position + used.size
		min_x = mini(min_x, used.position.x)
		min_y = mini(min_y, used.position.y)
		max_x = maxi(max_x, used_end.x)
		max_y = maxi(max_y, used_end.y)
		found = true
	if not found:
		return Rect2()
	var pad := int(maxf(6.0, float(mini(cell_w, cell_h)) * padding_ratio))
	var x0 := clampi(min_x - pad, 0, maxi(0, cell_w - 1))
	var y0 := clampi(min_y - pad, 0, maxi(0, cell_h - 1))
	var x1 := clampi(max_x + pad, x0 + 1, cell_w)
	var y1 := clampi(max_y + pad, y0 + 1, cell_h)
	return Rect2(Vector2(float(x0), float(y0)), Vector2(float(x1 - x0), float(y1 - y0)))


static func _build_sample_indices(frame_count: int, sample_frame_limit: int) -> Array[int]:
	var sample_limit := clampi(sample_frame_limit, 1, maxi(1, frame_count))
	var indices: Array[int] = []
	if sample_limit >= frame_count:
		for frame_index in range(frame_count):
			indices.append(frame_index)
		return indices
	for sample_index in range(sample_limit):
		var ratio := 0.0 if sample_limit <= 1 else float(sample_index) / float(sample_limit - 1)
		var frame_index := int(round(ratio * float(frame_count - 1)))
		if not indices.has(frame_index):
			indices.append(frame_index)
	return indices


static func normalized_rect_to_source(source: Rect2, normalized_rect: Rect2) -> Rect2:
	return Rect2(
		source.position + source.size * normalized_rect.position,
		source.size * normalized_rect.size
	)


static func source_subrect_to_target(source: Rect2, target: Rect2, source_region: Rect2) -> Rect2:
	var position_ratio := (source_region.position - source.position) / source.size
	var size_ratio := source_region.size / source.size
	return Rect2(target.position + target.size * position_ratio, target.size * size_ratio)


static func fit_region_rect(source_size: Vector2, target: Rect2) -> Rect2:
	if source_size.x <= 1.0 or source_size.y <= 1.0 or target.size.x <= 1.0 or target.size.y <= 1.0:
		return Rect2(target.position, Vector2.ZERO)
	var scale_factor := minf(target.size.x / source_size.x, target.size.y / source_size.y)
	var draw_size := source_size * scale_factor
	return Rect2(target.position + (target.size - draw_size) * 0.5, draw_size)


static func live2d_stage_fit_rect(source_size: Vector2, target: Rect2, stage_y_scale: float) -> Rect2:
	var fit_rect := fit_region_rect(source_size, target)
	var safe_y_scale := maxf(0.50, stage_y_scale)
	if fit_rect.size.y <= 1.0 or absf(safe_y_scale - 1.0) <= 0.001:
		return fit_rect
	var bottom_y := fit_rect.end.y
	fit_rect.size.y *= safe_y_scale
	fit_rect.position.y = bottom_y - fit_rect.size.y
	return fit_rect


static func scale_rect(rect: Rect2, scale_factor: float) -> Rect2:
	var scaled_size := rect.size * scale_factor
	return Rect2(rect.get_center() - scaled_size * 0.5, scaled_size)
