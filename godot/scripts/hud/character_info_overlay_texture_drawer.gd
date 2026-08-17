extends RefCounted

const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const PremiumPanelFrame := preload("res://scripts/hud/premium_panel_frame.gd")

static var _hanji_surface_texture: Texture2D = null
static var _ornate_ledger_frame_texture: Texture2D = null
static var _inkwash_ornament_atlas_texture: Texture2D = null

const ORNAMENT_ATLAS_GRID := Vector2i(2, 2)
const ORNAMENT_PINE_CELL := Vector2i(0, 0)
const ORNAMENT_MOUNTAIN_CELL := Vector2i(1, 0)
const ORNAMENT_CLOUD_CELL := Vector2i(0, 1)
const ORNAMENT_SEAL_CELL := Vector2i(1, 1)

# Character-info material palette. The overlay is immediate-mode rather than a
# Control/Theme tree, so these shared drawing constants are the single style
# source for every section, slot, and guardian-art frame.
const SECTION_SHADOW := Color(0.035, 0.026, 0.017, 0.22)
const SECTION_INK_LINE := Color(0.20, 0.145, 0.082, 0.74)
const SECTION_BRASS_LINE := Color(0.48, 0.35, 0.17, 0.54)
const SLOT_INK_FILL := Color(0.030, 0.040, 0.040, 0.98)
const SLOT_EMPTY_FILL := Color(0.050, 0.045, 0.034, 0.98)
const SLOT_BRASS := Color(0.54, 0.40, 0.19, 0.86)
const SLOT_JADE := Color(0.24, 0.49, 0.43, 0.90)
const GUARDIAN_NAVY := Color(0.018, 0.031, 0.043, 0.99)


static func set_hanji_surface_texture(texture: Texture2D) -> void:
	if texture != null:
		_hanji_surface_texture = texture


static func set_ornate_ledger_frame_texture(texture: Texture2D) -> void:
	if texture != null:
		_ornate_ledger_frame_texture = texture


static func set_inkwash_ornament_atlas_texture(texture: Texture2D) -> void:
	if texture != null:
		_inkwash_ornament_atlas_texture = texture


static func touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_size()


static func draw_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, border_width: float, frame_kind: int = PremiumPanelFrame.KIND_SECTION) -> void:
	PremiumPanelFrame.draw_panel(canvas, rect, frame_kind, fill, border, border_width)


static func draw_main_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, border_width: float) -> void:
	if canvas == null or not rect.has_area():
		return
	canvas.draw_rect(rect.grow(5.0), Color(0.015, 0.012, 0.010, 0.82))
	canvas.draw_rect(rect, fill)
	draw_lacquer_surface(canvas, rect.grow(-2.0), 0.50)
	canvas.draw_rect(rect, Color(0.035, 0.028, 0.021, 0.98), false, maxf(3.0, border_width + 1.0))
	canvas.draw_rect(rect.grow(-5.0), border, false, maxf(1.0, border_width * 0.55))
	canvas.draw_rect(rect.grow(-9.0), Color(0.16, 0.105, 0.055, 0.78), false, 1.0)
	_draw_ledger_corners(canvas, rect.grow(-3.0), border, 30.0, 3.0)


static func draw_section_chrome(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, accent: Color) -> void:
	if canvas == null or not rect.has_area():
		return
	# A section is a sheet mounted inside the outer lacquer ledger, not another
	# full ledger. Keep one thin ink edge and tiny brass corner strokes here; the
	# heavy authored 9-patch belongs only to the outer frame and header plaques.
	canvas.draw_rect(rect.grow(1.5), SECTION_SHADOW)
	canvas.draw_rect(rect, fill)
	draw_hanji_surface(canvas, rect.grow(-1.0), 0.52)
	var tone_phase := fposmod(rect.position.x * 0.013 + rect.position.y * 0.021, 1.0)
	var tone_alpha := lerpf(0.012, 0.032, tone_phase)
	canvas.draw_rect(rect.grow(-2.0), Color(0.50, 0.34, 0.16, tone_alpha))
	canvas.draw_rect(rect, SECTION_INK_LINE if border.a > 0.0 else border, false, 1.5)
	_draw_ledger_corners(canvas, rect.grow(-1.0), SECTION_BRASS_LINE, 13.0, 1.25)
	if rect.size.y < 44.0 or rect.size.x < 72.0:
		return
	var band_height := 34.0
	canvas.draw_rect(Rect2(rect.position + Vector2(3.0, 3.0), Vector2(rect.size.x - 6.0, band_height - 3.0)), Color(0.72, 0.61, 0.43, 0.035))
	canvas.draw_line(
		Vector2(rect.position.x + 12.0, rect.position.y + band_height),
		Vector2(rect.end.x - 12.0, rect.position.y + band_height),
		Color(0.31, 0.235, 0.14, 0.48),
		1.0,
		true
	)
	var brush_end := minf(52.0, rect.size.x * 0.08)
	canvas.draw_line(rect.position + Vector2(14.0, band_height + 3.0), rect.position + Vector2(14.0 + brush_end, band_height + 3.0), Color(accent.r, accent.g, accent.b, 0.18), 1.0, true)


static func draw_hanji_surface(canvas: CanvasItem, rect: Rect2, opacity: float = 0.52) -> void:
	if canvas == null or _hanji_surface_texture == null or not rect.has_area():
		return
	var source_size := _hanji_surface_texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var source_width := source_size.x * 0.56
	var source_height := source_size.y * 0.68
	var source_x := source_size.x * 0.20 + fposmod(rect.position.x * 0.31, source_size.x * 0.06)
	var source_y := source_size.y * 0.05 + fposmod(rect.position.y * 0.19, source_size.y * 0.08)
	var source := Rect2(source_x, source_y, source_width, source_height)
	canvas.draw_texture_rect_region(_hanji_surface_texture, rect, source, Color(0.88, 0.78, 0.61, clampf(opacity, 0.0, 1.0)), false, true)


static func draw_lacquer_surface(canvas: CanvasItem, rect: Rect2, opacity: float = 0.42) -> void:
	if canvas == null or _ornate_ledger_frame_texture == null or not rect.has_area():
		return
	var source_size := _ornate_ledger_frame_texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var source := Rect2(source_size * 0.32, source_size * 0.36)
	canvas.draw_texture_rect_region(_ornate_ledger_frame_texture, rect, source, Color(0.84, 0.76, 0.62, clampf(opacity, 0.0, 1.0)), false, true)


static func draw_ornate_ledger_frame(canvas: CanvasItem, rect: Rect2, target_corner_size: float = 20.0, target_rail_width: float = 7.0, modulate: Color = Color.WHITE) -> void:
	if canvas == null or _ornate_ledger_frame_texture == null or rect.size.x < 48.0 or rect.size.y < 48.0:
		return
	var source_size := _ornate_ledger_frame_texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var source_corner := minf(source_size.x * 0.18, source_size.y * 0.09)
	var source_rail := minf(source_size.x * 0.052, source_size.y * 0.026)
	var corner := minf(target_corner_size, minf(rect.size.x, rect.size.y) * 0.24)
	var rail := minf(target_rail_width, corner * 0.48)
	var top_left_source := Rect2(Vector2.ZERO, Vector2(source_corner, source_corner))
	var top_right_source := Rect2(Vector2(source_size.x - source_corner, 0.0), Vector2(source_corner, source_corner))
	var bottom_left_source := Rect2(Vector2(0.0, source_size.y - source_corner), Vector2(source_corner, source_corner))
	var bottom_right_source := Rect2(source_size - Vector2(source_corner, source_corner), Vector2(source_corner, source_corner))
	var top_rail_source := Rect2(Vector2(source_corner, 0.0), Vector2(source_size.x - source_corner * 2.0, source_rail))
	var bottom_rail_source := Rect2(Vector2(source_corner, source_size.y - source_rail), Vector2(source_size.x - source_corner * 2.0, source_rail))
	var left_rail_source := Rect2(Vector2(0.0, source_corner), Vector2(source_rail, source_size.y - source_corner * 2.0))
	var right_rail_source := Rect2(Vector2(source_size.x - source_rail, source_corner), Vector2(source_rail, source_size.y - source_corner * 2.0))
	_draw_stretched_region(canvas, _ornate_ledger_frame_texture, Rect2(rect.position + Vector2(corner, 0.0), Vector2(rect.size.x - corner * 2.0, rail)), top_rail_source, modulate)
	_draw_stretched_region(canvas, _ornate_ledger_frame_texture, Rect2(Vector2(rect.position.x + corner, rect.end.y - rail), Vector2(rect.size.x - corner * 2.0, rail)), bottom_rail_source, modulate)
	_draw_stretched_region(canvas, _ornate_ledger_frame_texture, Rect2(rect.position + Vector2(0.0, corner), Vector2(rail, rect.size.y - corner * 2.0)), left_rail_source, modulate)
	_draw_stretched_region(canvas, _ornate_ledger_frame_texture, Rect2(Vector2(rect.end.x - rail, rect.position.y + corner), Vector2(rail, rect.size.y - corner * 2.0)), right_rail_source, modulate)
	_draw_stretched_region(canvas, _ornate_ledger_frame_texture, Rect2(rect.position, Vector2(corner, corner)), top_left_source, modulate)
	_draw_stretched_region(canvas, _ornate_ledger_frame_texture, Rect2(Vector2(rect.end.x - corner, rect.position.y), Vector2(corner, corner)), top_right_source, modulate)
	_draw_stretched_region(canvas, _ornate_ledger_frame_texture, Rect2(Vector2(rect.position.x, rect.end.y - corner), Vector2(corner, corner)), bottom_left_source, modulate)
	_draw_stretched_region(canvas, _ornate_ledger_frame_texture, Rect2(rect.end - Vector2(corner, corner), Vector2(corner, corner)), bottom_right_source, modulate)


static func _draw_stretched_region(canvas: CanvasItem, texture: Texture2D, dest: Rect2, source: Rect2, modulate: Color) -> void:
	if dest.has_area() and source.has_area():
		canvas.draw_texture_rect_region(texture, dest, source, modulate, false, true)


static func _draw_ledger_corners(canvas: CanvasItem, rect: Rect2, color: Color, length: float, weight: float) -> void:
	var l: float = minf(length, minf(rect.size.x, rect.size.y) * 0.22)
	_draw_ledger_corner(canvas, rect.position, Vector2(1.0, 1.0), l, weight, color)
	_draw_ledger_corner(canvas, Vector2(rect.end.x, rect.position.y), Vector2(-1.0, 1.0), l, weight, color)
	_draw_ledger_corner(canvas, Vector2(rect.position.x, rect.end.y), Vector2(1.0, -1.0), l, weight, color)
	_draw_ledger_corner(canvas, rect.end, Vector2(-1.0, -1.0), l, weight, color)


static func _draw_ledger_corner(canvas: CanvasItem, origin: Vector2, direction: Vector2, length: float, weight: float, color: Color) -> void:
	canvas.draw_line(origin, origin + Vector2(direction.x * length, 0.0), color, weight, true)
	canvas.draw_line(origin, origin + Vector2(0.0, direction.y * length), color, weight, true)
	var knot := origin + direction * 5.0
	canvas.draw_rect(Rect2(knot - Vector2(1.75, 1.75), Vector2(3.5, 3.5)), color)


static func _draw_inkwash_ornament_cell(canvas: CanvasItem, dest: Rect2, cell: Vector2i, modulate: Color) -> bool:
	if canvas == null or _inkwash_ornament_atlas_texture == null or not dest.has_area():
		return false
	var atlas_size := _inkwash_ornament_atlas_texture.get_size()
	if atlas_size.x <= 0.0 or atlas_size.y <= 0.0:
		return false
	var cell_size := Vector2(
		atlas_size.x / float(ORNAMENT_ATLAS_GRID.x),
		atlas_size.y / float(ORNAMENT_ATLAS_GRID.y)
	)
	var source := Rect2(Vector2(cell) * cell_size, cell_size)
	canvas.draw_texture_rect_region(_inkwash_ornament_atlas_texture, dest, source, modulate, false, true)
	return true


static func draw_mountain_watermark(canvas: CanvasItem, rect: Rect2, right_aligned: bool = false, ink: Color = Color(0.13, 0.105, 0.065, 0.105)) -> void:
	if canvas == null or rect.size.x < 150.0 or rect.size.y < 72.0:
		return
	var span := clampf(rect.size.x * 0.34, 126.0, 258.0)
	var height := clampf(rect.size.y * 0.28, 26.0, 72.0)
	var start_x := rect.end.x - span - 12.0 if right_aligned else rect.position.x + 12.0
	var base_y := rect.end.y - 9.0
	var atlas_height := maxf(height * 2.25, 88.0)
	var atlas_dest := Rect2(Vector2(start_x, base_y - atlas_height), Vector2(span, atlas_height))
	if _draw_inkwash_ornament_cell(canvas, atlas_dest, ORNAMENT_MOUNTAIN_CELL, Color(0.74, 0.66, 0.52, clampf(ink.a * 1.45, 0.12, 0.24))):
		return
	var soft_ink := Color(ink.r, ink.g, ink.b, ink.a * 0.58)
	var distant_ridge := PackedVector2Array([
		Vector2(start_x, base_y),
		Vector2(start_x + span * 0.13, base_y - height * 0.16),
		Vector2(start_x + span * 0.25, base_y - height * 0.48),
		Vector2(start_x + span * 0.32, base_y - height * 0.36),
		Vector2(start_x + span * 0.43, base_y - height * 0.12),
		Vector2(start_x + span * 0.52, base_y),
	])
	var foreground_ridge := PackedVector2Array([
		Vector2(start_x + span * 0.18, base_y),
		Vector2(start_x + span * 0.29, base_y - height * 0.20),
		Vector2(start_x + span * 0.40, base_y - height * 0.68),
		Vector2(start_x + span * 0.47, base_y - height * 0.53),
		Vector2(start_x + span * 0.55, base_y - height),
		Vector2(start_x + span * 0.61, base_y - height * 0.72),
		Vector2(start_x + span * 0.69, base_y - height * 0.45),
		Vector2(start_x + span * 0.80, base_y),
	])
	var far_ridge := PackedVector2Array([
		Vector2(start_x + span * 0.62, base_y),
		Vector2(start_x + span * 0.72, base_y - height * 0.24),
		Vector2(start_x + span * 0.81, base_y - height * 0.58),
		Vector2(start_x + span * 0.87, base_y - height * 0.43),
		Vector2(start_x + span, base_y),
	])
	canvas.draw_colored_polygon(PackedVector2Array([distant_ridge[0], distant_ridge[1], distant_ridge[2], distant_ridge[3], distant_ridge[4], distant_ridge[5], Vector2(start_x, base_y)]), Color(ink.r, ink.g, ink.b, ink.a * 0.18))
	canvas.draw_colored_polygon(PackedVector2Array([foreground_ridge[0], foreground_ridge[1], foreground_ridge[2], foreground_ridge[3], foreground_ridge[4], foreground_ridge[5], foreground_ridge[6], foreground_ridge[7], foreground_ridge[0]]), Color(ink.r, ink.g, ink.b, ink.a * 0.25))
	canvas.draw_polyline(distant_ridge, soft_ink, 1.2, true)
	canvas.draw_polyline(foreground_ridge, ink, 1.8, true)
	canvas.draw_polyline(far_ridge, soft_ink, 1.3, true)
	canvas.draw_circle(foreground_ridge[4] + Vector2(-4.0, 5.0), maxf(3.0, height * 0.07), Color(ink.r, ink.g, ink.b, ink.a * 0.18))
	canvas.draw_circle(far_ridge[2] + Vector2(3.0, 4.0), maxf(2.0, height * 0.05), Color(ink.r, ink.g, ink.b, ink.a * 0.14))
	canvas.draw_line(Vector2(start_x + span * 0.18, base_y - height * 0.24), Vector2(start_x + span * 0.66, base_y - height * 0.24), soft_ink, 1.0, true)
	canvas.draw_line(Vector2(start_x + span * 0.43, base_y - height * 0.42), Vector2(start_x + span * 0.90, base_y - height * 0.42), Color(ink.r, ink.g, ink.b, ink.a * 0.38), 1.0, true)
	var sun_x := start_x + span * (0.16 if right_aligned else 0.84)
	canvas.draw_circle(Vector2(sun_x, base_y - height * 0.72), maxf(4.0, height * 0.10), Color(0.48, 0.14, 0.085, ink.a * 0.34))


static func draw_cloud_scroll_watermark(canvas: CanvasItem, rect: Rect2, right_aligned: bool = false, ink: Color = Color(0.15, 0.115, 0.07, 0.10)) -> void:
	if canvas == null or rect.size.x < 110.0 or rect.size.y < 58.0:
		return
	var width := clampf(rect.size.x * 0.26, 92.0, 178.0)
	var scale := clampf(rect.size.y / 190.0, 0.58, 1.0)
	var start_x := rect.end.x - width - 12.0 if right_aligned else rect.position.x + 12.0
	var y := rect.end.y - 14.0
	var atlas_height := clampf(rect.size.y * 0.34, 58.0, 104.0)
	var atlas_dest := Rect2(Vector2(start_x, y - atlas_height * 0.84), Vector2(width, atlas_height))
	if _draw_inkwash_ornament_cell(canvas, atlas_dest, ORNAMENT_CLOUD_CELL, Color(0.72, 0.62, 0.48, clampf(ink.a * 1.55, 0.12, 0.22))):
		return
	var soft_ink := Color(ink.r, ink.g, ink.b, ink.a * 0.58)
	canvas.draw_line(Vector2(start_x, y), Vector2(start_x + width, y), soft_ink, 1.0, true)
	canvas.draw_arc(Vector2(start_x + width * 0.20, y), 14.0 * scale, PI, TAU, 16, ink, 1.4, true)
	canvas.draw_arc(Vector2(start_x + width * 0.40, y), 21.0 * scale, PI, TAU, 20, ink, 1.6, true)
	canvas.draw_arc(Vector2(start_x + width * 0.64, y), 13.0 * scale, PI, TAU, 16, ink, 1.3, true)
	canvas.draw_arc(Vector2(start_x + width * 0.81, y - 2.0 * scale), 8.0 * scale, -PI * 0.55, PI * 1.05, 14, soft_ink, 1.0, true)
	canvas.draw_line(Vector2(start_x + width * 0.07, y + 7.0 * scale), Vector2(start_x + width * 0.58, y + 7.0 * scale), soft_ink, 1.0, true)
	canvas.draw_line(Vector2(start_x + width * 0.43, y + 12.0 * scale), Vector2(start_x + width * 0.92, y + 12.0 * scale), Color(ink.r, ink.g, ink.b, ink.a * 0.40), 1.0, true)


static func draw_seal_stamp(canvas: CanvasItem, center: Vector2, size: float = 15.0, ink: Color = Color(0.55, 0.10, 0.07, 0.50)) -> void:
	if canvas == null or size < 8.0:
		return
	var atlas_size := size * 3.45
	var atlas_dest := Rect2(center - Vector2(atlas_size, atlas_size) * 0.5, Vector2(atlas_size, atlas_size))
	if _draw_inkwash_ornament_cell(canvas, atlas_dest, ORNAMENT_SEAL_CELL, Color(0.90, 0.60, 0.48, clampf(ink.a * 0.82, 0.28, 0.55))):
		return
	var stamp := Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size))
	canvas.draw_rect(stamp, Color(ink.r, ink.g, ink.b, ink.a * 0.10))
	canvas.draw_rect(stamp, ink, false, maxf(1.0, size * 0.10))
	canvas.draw_rect(stamp.grow(-size * 0.18), Color(ink.r, ink.g, ink.b, ink.a * 0.72), false, 1.0)
	var left := stamp.position.x + size * 0.31
	var right := stamp.end.x - size * 0.28
	var top := stamp.position.y + size * 0.28
	var bottom := stamp.end.y - size * 0.28
	canvas.draw_line(Vector2(left, top), Vector2(left, bottom), ink, 1.0, true)
	canvas.draw_line(Vector2(right, top), Vector2(right, bottom), ink, 1.0, true)
	canvas.draw_line(Vector2(left, top + size * 0.20), Vector2(right, top + size * 0.20), ink, 1.0, true)
	canvas.draw_line(Vector2(left, bottom - size * 0.18), Vector2(right, bottom - size * 0.18), ink, 1.0, true)


# Large Korean pine watermark for the lower item ledger. It is drawn before
# slots, so the ornament can feel printed into the hanji without competing
# with item art or labels.
static func draw_pine_watermark(canvas: CanvasItem, rect: Rect2, ink: Color = Color(0.12, 0.095, 0.055, 0.12)) -> void:
	if canvas == null or rect.size.x < 360.0 or rect.size.y < 130.0:
		return
	var tree_height := clampf(rect.size.y * 0.62, 78.0, 116.0)
	var atlas_width := tree_height * 1.08
	var atlas_dest := Rect2(
		Vector2(rect.position.x + 8.0, rect.end.y - tree_height - 12.0),
		Vector2(atlas_width, tree_height)
	)
	if _draw_inkwash_ornament_cell(canvas, atlas_dest, ORNAMENT_PINE_CELL, Color(0.64, 0.56, 0.43, clampf(ink.a * 1.18, 0.10, 0.18))):
		return
	var scale := tree_height / 142.0
	var root := Vector2(rect.position.x + 72.0 * scale, rect.end.y - 15.0)
	var trunk_a := root + Vector2(17.0, -36.0) * scale
	var trunk_b := root + Vector2(10.0, -76.0) * scale
	var trunk_c := root + Vector2(31.0, -112.0) * scale
	var crown := root + Vector2(24.0, -tree_height)
	canvas.draw_line(root, trunk_a, ink, 5.0 * scale, true)
	canvas.draw_line(trunk_a, trunk_b, ink, 4.2 * scale, true)
	canvas.draw_line(trunk_b, trunk_c, ink, 3.4 * scale, true)
	canvas.draw_line(trunk_c, crown, ink, 2.4 * scale, true)
	canvas.draw_line(root + Vector2(5.0, 1.0), trunk_a + Vector2(3.0, 0.0), Color(ink.r, ink.g, ink.b, ink.a * 0.48), 1.0, true)
	var right_low_end := _draw_pine_bough(canvas, trunk_a + Vector2(2.0, -4.0) * scale, Vector2(1.0, -0.24), 82.0 * scale, 10.0 * scale, ink)
	var left_low_end := _draw_pine_bough(canvas, trunk_a + Vector2(7.0, -18.0) * scale, Vector2(-0.96, -0.22), 54.0 * scale, 9.0 * scale, ink)
	var right_mid_end := _draw_pine_bough(canvas, trunk_b + Vector2(1.0, -7.0) * scale, Vector2(0.92, -0.40), 68.0 * scale, 9.5 * scale, ink)
	var left_mid_end := _draw_pine_bough(canvas, trunk_b + Vector2(4.0, -22.0) * scale, Vector2(-0.82, -0.46), 46.0 * scale, 8.0 * scale, ink)
	var right_top_end := _draw_pine_bough(canvas, trunk_c, Vector2(0.72, -0.69), 44.0 * scale, 7.0 * scale, ink)
	var crown_end := _draw_pine_bough(canvas, crown - Vector2(1.0, 1.0), Vector2(-0.52, -0.85), 25.0 * scale, 5.5 * scale, ink)
	_draw_pine_needle_tuft(canvas, right_low_end, 15.0 * scale, ink)
	_draw_pine_needle_tuft(canvas, left_low_end, 13.0 * scale, ink)
	_draw_pine_needle_tuft(canvas, right_mid_end, 14.0 * scale, ink)
	_draw_pine_needle_tuft(canvas, left_mid_end, 11.0 * scale, ink)
	_draw_pine_needle_tuft(canvas, right_top_end, 10.0 * scale, ink)
	_draw_pine_needle_tuft(canvas, crown_end, 8.0 * scale, ink)
	_draw_pine_needle_tuft(canvas, trunk_a.lerp(right_low_end, 0.58), 12.0 * scale, ink)
	_draw_pine_needle_tuft(canvas, trunk_a.lerp(left_low_end, 0.55), 10.0 * scale, ink)
	_draw_pine_needle_tuft(canvas, trunk_b.lerp(right_mid_end, 0.56), 11.0 * scale, ink)
	_draw_pine_needle_tuft(canvas, trunk_b.lerp(left_mid_end, 0.54), 9.0 * scale, ink)
	_draw_pine_needle_tuft(canvas, trunk_c.lerp(right_top_end, 0.50), 8.0 * scale, ink)
	var ground_y := rect.end.y - 8.0
	canvas.draw_line(Vector2(rect.position.x + 12.0, ground_y), Vector2(rect.position.x + 168.0 * scale, ground_y), Color(ink.r, ink.g, ink.b, ink.a * 0.82), 1.4, true)
	canvas.draw_arc(root + Vector2(-2.0, 1.0), 16.0 * scale, PI, TAU, 18, Color(ink.r, ink.g, ink.b, ink.a * 0.72), 1.2, true)
	canvas.draw_arc(root + Vector2(30.0, 3.0) * scale, 11.0 * scale, PI, TAU, 14, Color(ink.r, ink.g, ink.b, ink.a * 0.56), 1.0, true)


static func _draw_pine_bough(canvas: CanvasItem, start: Vector2, direction: Vector2, length: float, needle_span: float, ink: Color) -> Vector2:
	var tangent := direction.normalized()
	var normal := Vector2(-tangent.y, tangent.x)
	var end := start + tangent * length
	canvas.draw_line(start, end, ink, 1.8, true)
	for needle_index in range(1, 8):
		var t := float(needle_index) / 8.0
		var center := start.lerp(end, t)
		var span := needle_span * (0.62 + sin(t * PI) * 0.38)
		var lean := tangent * span * 0.34
		canvas.draw_line(center - lean, center + normal * span, Color(ink.r, ink.g, ink.b, ink.a * 0.88), 1.0, true)
		canvas.draw_line(center - lean, center - normal * span, Color(ink.r, ink.g, ink.b, ink.a * 0.72), 1.0, true)
	return end


static func _draw_pine_needle_tuft(canvas: CanvasItem, center: Vector2, radius: float, ink: Color) -> void:
	var foliage_soft := Color(ink.r, ink.g, ink.b, ink.a * 0.62)
	var foliage_deep := Color(ink.r, ink.g, ink.b, ink.a * 0.92)
	canvas.draw_circle(center, radius * 0.58, foliage_deep)
	canvas.draw_circle(center + Vector2(-radius * 0.44, radius * 0.12), radius * 0.42, foliage_soft)
	canvas.draw_circle(center + Vector2(radius * 0.42, radius * 0.08), radius * 0.38, foliage_soft)
	canvas.draw_circle(center + Vector2(-radius * 0.10, -radius * 0.38), radius * 0.36, foliage_soft)
	for needle_index in range(14):
		var angle := TAU * float(needle_index) / 14.0
		var direction := Vector2(cos(angle), sin(angle))
		var length_scale := 0.72 + 0.24 * sin(float(needle_index) * 2.31)
		canvas.draw_line(center - direction * radius * 0.12, center + direction * radius * length_scale, Color(ink.r, ink.g, ink.b, ink.a * 0.78), 1.0, true)


# Kept as a compatibility setter for older prewarm callers. The hanji redesign
# deliberately does not draw the former cyan machined socket.
static var _empty_slot_socket_texture: Texture2D = null


static func set_empty_slot_socket_texture(texture: Texture2D) -> void:
	if texture != null:
		_empty_slot_socket_texture = texture


static func draw_empty_slot_socket(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color) -> void:
	var cut := clampf(minf(rect.size.x, rect.size.y) * 0.09, 3.0, 8.0)
	var plate := PackedVector2Array([
		rect.position + Vector2(cut, 0.0),
		Vector2(rect.end.x - cut, rect.position.y),
		Vector2(rect.end.x, rect.position.y + cut),
		rect.end - Vector2(0.0, cut),
		rect.end - Vector2(cut, 0.0),
		Vector2(rect.position.x + cut, rect.end.y),
		Vector2(rect.position.x, rect.end.y - cut),
		rect.position + Vector2(0.0, cut),
	])
	canvas.draw_colored_polygon(plate, SLOT_EMPTY_FILL if fill.a > 0.0 else fill)
	var outline := plate.duplicate()
	outline.append(plate[0])
	canvas.draw_polyline(outline, Color(SLOT_BRASS.r, SLOT_BRASS.g, SLOT_BRASS.b, 0.74), 1.5, true)
	canvas.draw_rect(rect.grow(-4.0), Color(border.r, border.g, border.b, 0.24), false, 1.0)
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.27
	canvas.draw_circle(center, radius, Color(0.025, 0.032, 0.030, 0.78))
	canvas.draw_arc(center, radius, 0.0, TAU, 36, Color(0.48, 0.37, 0.20, 0.52), 1.4, true)
	canvas.draw_arc(center, radius * 0.66, 0.0, TAU, 28, Color(0.26, 0.43, 0.36, 0.24), 1.0, true)
	_draw_cardinal_knots(canvas, center, radius + 3.0, Color(0.58, 0.42, 0.20, 0.62), 2.8)
	canvas.draw_line(center + Vector2(-radius * 0.48, -radius * 0.48), center + Vector2(radius * 0.48, radius * 0.48), Color(0.55, 0.42, 0.24, 0.15), 1.0, true)
	canvas.draw_line(center + Vector2(radius * 0.48, -radius * 0.48), center + Vector2(-radius * 0.48, radius * 0.48), Color(0.55, 0.42, 0.24, 0.15), 1.0, true)


static func draw_lacquer_slot(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, selected: bool = false) -> void:
	var dark_fill := SLOT_EMPTY_FILL if not selected else Color(0.030, 0.075, 0.072, 0.98)
	canvas.draw_rect(rect.grow(2.0), Color(0.025, 0.020, 0.015, 0.72))
	canvas.draw_rect(rect, dark_fill if fill.a > 0.0 else fill)
	canvas.draw_rect(rect, SLOT_BRASS if not selected else SLOT_JADE, false, 1.6)
	canvas.draw_rect(rect.grow(-4.0), Color(border.r, border.g, border.b, 0.42), false, 1.0)
	_draw_ledger_corners(canvas, rect.grow(-1.0), Color(0.62, 0.45, 0.23, 0.62), minf(10.0, rect.size.x * 0.16), 1.2)


static func draw_skill_card(canvas: CanvasItem, rect: Rect2, accent: Color, occupied: bool, highlighted: bool = false) -> void:
	canvas.draw_rect(rect.grow(2.0), Color(0.018, 0.015, 0.011, 0.62))
	canvas.draw_rect(rect, SLOT_INK_FILL if occupied else SLOT_EMPTY_FILL)
	draw_lacquer_surface(canvas, rect.grow(-2.0), 0.16)
	var quiet_accent := Color(0.38, 0.40, 0.29, 0.58)
	if occupied:
		quiet_accent = Color(lerpf(accent.r, 0.40, 0.55), lerpf(accent.g, 0.48, 0.55), lerpf(accent.b, 0.38, 0.55), 0.76)
	if highlighted:
		quiet_accent = SLOT_JADE
	canvas.draw_rect(rect, Color(0.24, 0.17, 0.09, 0.94), false, 1.6)
	canvas.draw_rect(rect.grow(-4.0), quiet_accent, false, 1.0)
	_draw_ledger_corners(canvas, rect.grow(-1.0), Color(quiet_accent.r, quiet_accent.g, quiet_accent.b, 0.72), 11.0, 1.15)
	var well_center := Vector2(rect.get_center().x, rect.position.y + rect.size.x * 0.48)
	var well_radius := minf(rect.size.x * 0.31, rect.size.y * 0.28)
	canvas.draw_circle(well_center, well_radius + 4.0, Color(0.015, 0.014, 0.012, 0.94))
	canvas.draw_arc(well_center, well_radius + 4.0, 0.0, TAU, 48, SLOT_BRASS, 1.7, true)
	canvas.draw_arc(well_center, well_radius, 0.0, TAU, 48, Color(quiet_accent.r, quiet_accent.g, quiet_accent.b, 0.54), 1.1, true)
	_draw_cardinal_knots(canvas, well_center, well_radius + 7.0, Color(0.62, 0.46, 0.24, 0.64), 2.8)


static func draw_ink_nameplate(canvas: CanvasItem, rect: Rect2, border: Color, parchment: bool = false) -> void:
	var fill := Color(0.82, 0.74, 0.58, 0.96) if parchment else Color(0.035, 0.030, 0.024, 0.96)
	canvas.draw_rect(rect.grow(1.5), Color(0.02, 0.018, 0.014, 0.60))
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect, Color(border.r, border.g, border.b, 0.78), false, 1.2)
	var notch := 4.0
	canvas.draw_line(rect.position + Vector2(2.0, notch), rect.position + Vector2(notch, 2.0), Color(border.r, border.g, border.b, 0.58), 1.0)
	canvas.draw_line(rect.end - Vector2(2.0, notch), rect.end - Vector2(notch, 2.0), Color(border.r, border.g, border.b, 0.58), 1.0)


# Traditional lacquered name board for the two labels beneath a Chosik orb.
# Cut corners, brass pins, and quiet wood grain keep it in the same material
# family as the outer ledger without thickening the interactive card itself.
static func draw_skill_nameplate(canvas: CanvasItem, rect: Rect2, border: Color) -> void:
	var cut := clampf(rect.size.y * 0.22, 3.0, 6.0)
	var board := PackedVector2Array([
		rect.position + Vector2(cut, 0.0),
		Vector2(rect.end.x - cut, rect.position.y),
		Vector2(rect.end.x, rect.position.y + cut),
		Vector2(rect.end.x, rect.end.y - cut),
		rect.end - Vector2(cut, 0.0),
		Vector2(rect.position.x + cut, rect.end.y),
		Vector2(rect.position.x, rect.end.y - cut),
		rect.position + Vector2(0.0, cut),
	])
	canvas.draw_colored_polygon(board, Color(0.055, 0.038, 0.022, 0.98))
	var outline := board.duplicate()
	outline.append(board[0])
	canvas.draw_polyline(outline, Color(0.48, 0.33, 0.16, 0.96), 1.4, true)
	canvas.draw_line(rect.position + Vector2(cut + 4.0, 4.0), Vector2(rect.end.x - cut - 4.0, rect.position.y + 4.0), Color(border.r, border.g, border.b, 0.30), 1.0, true)
	canvas.draw_line(Vector2(rect.position.x + cut + 4.0, rect.end.y - 4.0), rect.end - Vector2(cut + 4.0, 4.0), Color(0.16, 0.105, 0.055, 0.92), 1.0, true)
	draw_empty_state_diamond(canvas, Vector2(rect.position.x + cut + 2.0, rect.get_center().y), 2.3, Color(0.62, 0.44, 0.20, 0.88))
	draw_empty_state_diamond(canvas, Vector2(rect.end.x - cut - 2.0, rect.get_center().y), 2.3, Color(0.62, 0.44, 0.20, 0.88))


static func draw_guardian_art_frame(canvas: CanvasItem, rect: Rect2, border: Color) -> Rect2:
	canvas.draw_rect(rect.grow(3.0), Color(0.018, 0.014, 0.010, 0.72))
	canvas.draw_rect(rect, Color(0.040, 0.030, 0.020, 0.99))
	canvas.draw_rect(rect, Color(0.42, 0.29, 0.13, 0.96), false, 1.7)
	canvas.draw_rect(rect.grow(-5.0), Color(border.r, border.g, border.b, 0.46), false, 1.0)
	_draw_ledger_corners(canvas, rect.grow(-1.0), Color(0.62, 0.43, 0.20, 0.76), 16.0, 1.4)
	var knot_center := Vector2(rect.get_center().x, rect.end.y)
	draw_empty_state_diamond(canvas, knot_center, 6.0, Color(0.65, 0.44, 0.18, 0.94))
	draw_empty_state_diamond(canvas, knot_center, 3.0, Color(0.08, 0.06, 0.04, 0.96))
	var content_rect := rect.grow(-9.0)
	canvas.draw_rect(content_rect, GUARDIAN_NAVY)
	draw_cloud_scroll_watermark(canvas, content_rect, true, Color(0.22, 0.30, 0.29, 0.08))
	return content_rect


static func draw_guardian_focus_cover(canvas: CanvasItem, texture: Texture2D, rect: Rect2, zoom: float = 1.22, focus: Vector2 = Vector2(0.5, 0.49), modulate: Color = Color.WHITE) -> void:
	if texture == null or not rect.has_area():
		return
	var source_size := texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var target_ratio := rect.size.x / rect.size.y
	var source := Rect2(Vector2.ZERO, source_size)
	if source_size.x / source_size.y > target_ratio:
		source.size.x = source_size.y * target_ratio
	else:
		source.size.y = source_size.x / target_ratio
	var safe_zoom := maxf(1.0, zoom)
	source.size /= safe_zoom
	var focus_point := Vector2(source_size.x * clampf(focus.x, 0.0, 1.0), source_size.y * clampf(focus.y, 0.0, 1.0))
	source.position = focus_point - source.size * 0.5
	source.position.x = clampf(source.position.x, 0.0, source_size.x - source.size.x)
	source.position.y = clampf(source.position.y, 0.0, source_size.y - source.size.y)
	canvas.draw_texture_rect_region(texture, rect, source, modulate, false, true)


static func draw_guardian_aura(canvas: CanvasItem, rect: Rect2) -> void:
	if canvas == null or not rect.has_area():
		return
	var center := Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.46)
	var radius := minf(rect.size.x * 0.34, rect.size.y * 0.22)
	for ring_index in range(4):
		var ring_radius := radius + float(ring_index) * 7.0
		var ring_alpha := 0.10 - float(ring_index) * 0.018
		var ring_color := Color(0.66, 0.49, 0.22, ring_alpha) if ring_index % 2 == 0 else Color(0.20, 0.46, 0.42, ring_alpha * 0.78)
		canvas.draw_arc(center, ring_radius, -PI * 0.88, PI * 0.88, 72, ring_color, 2.0, true)


static func _draw_cardinal_knots(canvas: CanvasItem, center: Vector2, radius: float, color: Color, size: float) -> void:
	for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		draw_empty_state_diamond(canvas, center + direction * radius, size, color)


# Round hanji-seal socket for the Mugong grid. The accepted Mugong art is an
# irregular circular takbon plate, so the frame follows that silhouette instead
# of clipping or visually boxing it inside the retired sci-fi hexagon.
static func draw_mugong_seal_cell(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, border_width: float) -> void:
	var center := rect.get_center()
	var radius: float = maxf(1.0, minf(rect.size.x, rect.size.y) * 0.5 - 1.0)
	canvas.draw_circle(center, radius + 2.5, Color(0.10, 0.070, 0.035, 0.76))
	canvas.draw_circle(center, radius, Color(0.49, 0.39, 0.22, 0.94) if fill.a > 0.0 else fill)
	canvas.draw_circle(center, radius - 4.0, Color(0.76, 0.70, 0.56, 0.94))
	canvas.draw_circle(center + Vector2(-radius * 0.10, -radius * 0.12), radius * 0.74, Color(0.56, 0.47, 0.31, 0.075))
	# Fixed, non-random patina marks make the round socket read as an old bronze
	# mirror even when an icon covers most of its central paper face.
	for patina_index in range(7):
		var patina_angle := float(patina_index) * 2.17 + 0.42
		var patina_radius := radius * (0.35 + 0.075 * float(patina_index % 4))
		var patina_center := center + Vector2(cos(patina_angle), sin(patina_angle)) * patina_radius
		canvas.draw_circle(patina_center, maxf(1.0, radius * (0.018 + 0.006 * float(patina_index % 3))), Color(0.16, 0.34, 0.29, 0.16))
	# A quiet talisman slip beneath the icon gives empty and padded Mugong art a
	# shared paper/ink material without boxing the circular silhouette.
	var talisman_half_w := radius * 0.18
	var talisman_top := center.y - radius * 0.58
	var talisman_bottom := center.y + radius * 0.58
	canvas.draw_rect(Rect2(Vector2(center.x - talisman_half_w, talisman_top), Vector2(talisman_half_w * 2.0, talisman_bottom - talisman_top)), Color(0.88, 0.78, 0.56, 0.13))
	canvas.draw_line(Vector2(center.x, talisman_top + radius * 0.14), Vector2(center.x, talisman_bottom - radius * 0.14), Color(0.32, 0.12, 0.075, 0.18), 1.0, true)
	for seal_bar_index in range(3):
		var bar_y := center.y + (float(seal_bar_index) - 1.0) * radius * 0.22
		canvas.draw_line(Vector2(center.x - talisman_half_w * 0.62, bar_y), Vector2(center.x + talisman_half_w * 0.62, bar_y), Color(0.32, 0.12, 0.075, 0.16), 1.0, true)
	draw_mugong_seal_rim(canvas, rect, border, border_width)
	_draw_cardinal_knots(canvas, center, radius + 1.0, Color(0.49, 0.32, 0.12, 0.74), 3.0)


static func draw_traditional_plus(canvas: CanvasItem, center: Vector2, half_extent: float, color: Color, line_width: float = 1.6) -> void:
	var extent := maxf(3.0, half_extent)
	canvas.draw_line(center - Vector2(extent, 0.0), center + Vector2(extent, 0.0), color, line_width, true)
	canvas.draw_line(center - Vector2(0.0, extent), center + Vector2(0.0, extent), color, line_width, true)
	draw_empty_state_diamond(canvas, center, maxf(1.5, line_width * 1.15), Color(color.r, color.g, color.b, color.a * 0.86))


# Foreground pass for full-size Mugong art. Repeating only the arcs keeps a
# texture's glow or opaque edge from erasing the shared slot silhouette.
static func draw_mugong_seal_rim(canvas: CanvasItem, rect: Rect2, border: Color, border_width: float) -> void:
	var center := rect.get_center()
	var radius: float = maxf(1.0, minf(rect.size.x, rect.size.y) * 0.5 - 1.0)
	var inner_radius: float = maxf(1.0, radius - maxf(3.0, rect.size.x * 0.055))
	canvas.draw_arc(center, radius, 0.0, TAU, 64, border, border_width, true)
	canvas.draw_arc(
		center,
		inner_radius,
		0.0,
		TAU,
		64,
		Color(border.r, border.g, border.b, border.a * 0.42),
		maxf(0.75, border_width * 0.55),
		true
	)
	for etch_index in range(12):
		var angle := TAU * float(etch_index) / 12.0
		var direction := Vector2(cos(angle), sin(angle))
		canvas.draw_line(center + direction * (radius - 1.0), center + direction * (radius - 5.0), Color(0.62, 0.44, 0.22, 0.55), 1.0, true)


# Tiny procedural line glyphs for section titles and stat rows. Kept as code
# (not bitmaps): at 10-14px they stay crisp, tintable, and font-independent
# (decorative unicode would render as tofu on the Korean font stack).
static func draw_ui_glyph(canvas: CanvasItem, center: Vector2, size: float, kind: String, color: Color) -> void:
	var s := size * 0.5
	match kind:
		"sword":
			canvas.draw_line(center + Vector2(-s * 0.7, s * 0.7), center + Vector2(s * 0.62, -s * 0.62), color, 1.8, true)
			canvas.draw_line(center + Vector2(-s * 0.16, -s * 0.6), center + Vector2(s * 0.6, s * 0.16), color, 1.4, true)
			canvas.draw_line(center + Vector2(-s * 0.72, s * 0.4), center + Vector2(-s * 0.4, s * 0.72), color, 1.6, true)
		"seal":
			canvas.draw_arc(center, s * 0.92, 0.0, TAU, 24, color, 1.4, true)
			canvas.draw_arc(center, s * 0.58, 0.0, TAU, 20, Color(color.r, color.g, color.b, color.a * 0.62), 1.0, true)
			canvas.draw_circle(center, s * 0.18, color)
		"star":
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -s), center + Vector2(s * 0.32, -s * 0.32),
				center + Vector2(s, 0.0), center + Vector2(s * 0.32, s * 0.32),
				center + Vector2(0.0, s), center + Vector2(-s * 0.32, s * 0.32),
				center + Vector2(-s, 0.0), center + Vector2(-s * 0.32, -s * 0.32),
			]), color)
		"flask":
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.22, -s), Vector2(s * 0.44, s * 0.5)), color)
			canvas.draw_circle(center + Vector2(0.0, s * 0.28), s * 0.66, color)
		"chart":
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.9, s * 0.1), Vector2(s * 0.44, s * 0.8)), color)
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.22, -s * 0.3), Vector2(s * 0.44, s * 1.2)), color)
			canvas.draw_rect(Rect2(center + Vector2(s * 0.46, -s * 0.9), Vector2(s * 0.44, s * 1.8)), color)
		"chest":
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.9, -s * 0.55), Vector2(s * 1.8, s * 1.3)), color, false, 1.4)
			canvas.draw_line(center + Vector2(-s * 0.9, -s * 0.1), center + Vector2(s * 0.9, -s * 0.1), color, 1.4, true)
			canvas.draw_circle(center + Vector2(0.0, s * 0.28), s * 0.2, color)
		"speed":
			canvas.draw_line(center + Vector2(-s * 0.8, -s * 0.7), center + Vector2(-s * 0.1, 0.0), color, 1.6, true)
			canvas.draw_line(center + Vector2(-s * 0.1, 0.0), center + Vector2(-s * 0.8, s * 0.7), color, 1.6, true)
			canvas.draw_line(center + Vector2(0.0, -s * 0.7), center + Vector2(s * 0.7, 0.0), color, 1.6, true)
			canvas.draw_line(center + Vector2(s * 0.7, 0.0), center + Vector2(0.0, s * 0.7), color, 1.6, true)
		"size":
			canvas.draw_line(center + Vector2(-s * 0.9, 0.0), center + Vector2(s * 0.9, 0.0), color, 1.4, true)
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-s, 0.0), center + Vector2(-s * 0.45, -s * 0.4), center + Vector2(-s * 0.45, s * 0.4)]), color)
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(s, 0.0), center + Vector2(s * 0.45, -s * 0.4), center + Vector2(s * 0.45, s * 0.4)]), color)
		"gauge_gain":
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -s), center + Vector2(s * 0.6, s * 0.2),
				center + Vector2(0.0, s * 0.75), center + Vector2(-s * 0.6, s * 0.2),
			]), color)
		"gauge_max":
			canvas.draw_arc(center + Vector2(0.0, s * 0.3), s * 0.85, PI, TAU, 12, color, 1.6, true)
			canvas.draw_line(center + Vector2(0.0, s * 0.3), center + Vector2(s * 0.5, -s * 0.35), color, 1.5, true)
		"dash_range":
			canvas.draw_line(center + Vector2(-s * 0.95, 0.0), center + Vector2(-s * 0.45, 0.0), color, 1.5, true)
			canvas.draw_line(center + Vector2(-s * 0.2, 0.0), center + Vector2(s * 0.3, 0.0), color, 1.5, true)
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(s, 0.0), center + Vector2(s * 0.4, -s * 0.45), center + Vector2(s * 0.4, s * 0.45)]), color)
		"delay":
			canvas.draw_arc(center, s * 0.85, 0.0, TAU, 14, color, 1.4, true)
			canvas.draw_line(center, center + Vector2(0.0, -s * 0.55), color, 1.4, true)
			canvas.draw_line(center, center + Vector2(s * 0.4, s * 0.15), color, 1.4, true)
		"recharge":
			canvas.draw_arc(center, s * 0.75, -PI * 0.35, PI * 1.05, 12, color, 1.6, true)
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(s * 0.95, -s * 0.5), center + Vector2(s * 0.3, -s * 0.55), center + Vector2(s * 0.75, s * 0.05),
			]), color)
		"posture":
			canvas.draw_arc(center + Vector2(0.0, -s * 0.15), s * 0.34, PI, TAU, 10, color, 1.5, true)
			canvas.draw_line(center + Vector2(0.0, -s * 0.48), center + Vector2(0.0, s * 0.72), color, 1.6, true)
			canvas.draw_line(center + Vector2(-s * 0.72, -s * 0.02), center + Vector2(0.0, s * 0.18), color, 1.5, true)
			canvas.draw_line(center + Vector2(s * 0.72, -s * 0.02), center + Vector2(0.0, s * 0.18), color, 1.5, true)
		"slots":
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.9, -s * 0.9), Vector2(s * 0.75, s * 0.75)), color, false, 1.3)
			canvas.draw_rect(Rect2(center + Vector2(s * 0.15, -s * 0.9), Vector2(s * 0.75, s * 0.75)), color, false, 1.3)
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.9, s * 0.15), Vector2(s * 0.75, s * 0.75)), color, false, 1.3)
			canvas.draw_rect(Rect2(center + Vector2(s * 0.15, s * 0.15), Vector2(s * 0.75, s * 0.75)), color, false, 1.3)


static func draw_empty_state_diamond(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius * 0.56, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius * 0.56, 0.0),
		]),
		color
	)


static func draw_slot_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, border_width: float) -> void:
	PremiumPanelFrame.draw_panel(canvas, rect, PremiumPanelFrame.KIND_SLOT, fill, border, border_width)


static func draw_cell_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, border_width: float) -> void:
	PremiumPanelFrame.draw_panel(canvas, rect, PremiumPanelFrame.KIND_CELL, fill, border, border_width)


static func draw_scrollbar(canvas: CanvasItem, track_rect: Rect2, thumb_rect: Rect2, track_color: Color, thumb_color: Color) -> void:
	canvas.draw_rect(track_rect, track_color)
	canvas.draw_rect(thumb_rect, thumb_color)


static func draw_fallback_symbol(canvas: CanvasItem, rect: Rect2, color: Color, id_text: String, letter_cache: Dictionary, letter_cache_limit: int, ring_segments: int, draw_text_centered_xy_callable: Callable) -> void:
	var center := rect.get_center()
	var radius: float = min(rect.size.x, rect.size.y) * 0.38
	canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, 0.32))
	canvas.draw_arc(center, radius, 0.0, TAU, ring_segments, color, 2.0)
	var letter: String = CharacterInfoOverlayValueUtils.fallback_symbol_letter(id_text, letter_cache, letter_cache_limit)
	draw_text_centered_xy_callable.call(canvas, ThemeDB.fallback_font, letter, center.x, center.y + 3.0, int(radius * 1.2), Color.WHITE)


static func collect_visible_item_icon_items(slot_keys: Array, slot_state: Dictionary, active_slots: Array, passive_items: Array, get_equipment_item_callable: Callable) -> Array:
	var items: Array = []
	for slot_key in slot_keys:
		var item_value: Variant = get_equipment_item_callable.call(slot_state, str(slot_key))
		var item_data: Dictionary = item_value if item_value is Dictionary else {}
		if not item_data.is_empty():
			items.append(item_data)
	for active_value in active_slots:
		if active_value is Dictionary:
			items.append(active_value)
	items.append_array(passive_items)
	return items


static func prewarm_item_icon_textures(items: Array, visuals: Object, icon_renderer: Object, get_dict_callable: Callable) -> void:
	if icon_renderer != null and icon_renderer.has_method("prewarm_item_icons"):
		icon_renderer.prewarm_item_icons(items, visuals)
		return
	if visuals == null or not visuals.has_method("get_icon_texture"):
		return
	for item_value in items:
		var item_data_value: Variant = get_dict_callable.call(item_value)
		var item_data: Dictionary = item_data_value if item_data_value is Dictionary else {}
		if item_data.is_empty():
			continue
		var texture: Variant = visuals.get_icon_texture(item_data)
		if texture is Texture2D:
			touch_texture(texture as Texture2D)


static func draw_contained(canvas: CanvasItem, texture: Texture2D, rect: Rect2, modulate: Color = Color.WHITE) -> void:
	if texture == null:
		return
	var source_size: Vector2 = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var scale: float = min(rect.size.x / source_size.x, rect.size.y / source_size.y)
	var dest_size: Vector2 = source_size * scale
	var dest := Rect2(rect.get_center() - dest_size * 0.5, dest_size)
	canvas.draw_texture_rect(texture, dest, false, modulate)


static func draw_contained_region(canvas: CanvasItem, texture: Texture2D, rect: Rect2, source: Rect2, modulate: Color = Color.WHITE) -> void:
	if texture == null:
		return
	if source.size.x <= 0.0 or source.size.y <= 0.0:
		return
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var scale: float = min(rect.size.x / source.size.x, rect.size.y / source.size.y)
	var dest_size: Vector2 = source.size * scale
	var dest := Rect2(rect.get_center() - dest_size * 0.5, dest_size)
	canvas.draw_texture_rect_region(texture, dest, source, modulate, false, true)


static func draw_cover(canvas: CanvasItem, texture: Texture2D, rect: Rect2, modulate: Color = Color.WHITE) -> void:
	if texture == null:
		return
	var source_size: Vector2 = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var source := Rect2(Vector2.ZERO, source_size)
	var target_ratio: float = rect.size.x / rect.size.y
	var source_ratio: float = source_size.x / source_size.y
	if source_ratio > target_ratio:
		source.size.x = source_size.y * target_ratio
		source.position.x = (source_size.x - source.size.x) * 0.5
	else:
		source.size.y = source_size.x / target_ratio
		source.position.y = (source_size.y - source.size.y) * 0.5
	canvas.draw_texture_rect_region(texture, rect, source, modulate, false, true)
