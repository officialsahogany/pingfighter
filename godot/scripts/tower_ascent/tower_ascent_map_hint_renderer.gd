extends RefCounted

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentMapOverlayLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_map_overlay_localization.gd"
)

const PANEL_FILL := Color(0.045, 0.028, 0.02, 0.84)
const PANEL_BORDER := Color("bd8c35")
const TEXT_COLOR := Color("f1dfb8")
const MAP_FILL := Color("d8c496")
const MAP_FOLD := Color("8d6b3b")
const MAP_ROUTE := Color("742b2b")
const BASE_HINT_SIZE := Vector2(88.0, 36.0)
const BASE_SIDE_MARGIN := 12.0
const BASE_FONT_SIZE := 18
const PILLAR_Y_RATIO := 0.47


func draw(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	tower_surface_active: bool
) -> void:
	if canvas == null or not is_visible(tower_surface_active):
		return
	var rect := get_hint_rect(view_size, game_offset, game_size)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var scale_factor := rect.size.y / BASE_HINT_SIZE.y
	canvas.draw_rect(rect, PANEL_FILL, true)
	canvas.draw_rect(rect, PANEL_BORDER, false, maxf(1.0, 1.5 * scale_factor))
	var icon_rect := Rect2(
		rect.position + Vector2(8.0, 6.0) * scale_factor,
		Vector2(29.0, 24.0) * scale_factor
	)
	_draw_map_pictogram(canvas, icon_rect, scale_factor)
	var key_rect := Rect2(
		Vector2(icon_rect.end.x + 4.0 * scale_factor, rect.position.y),
		Vector2(rect.end.x - icon_rect.end.x - 8.0 * scale_factor, rect.size.y)
	)
	canvas.draw_string(
		ThemeDB.fallback_font,
		key_rect.position + Vector2(0.0, 24.0 * scale_factor),
		get_key_label(),
		HORIZONTAL_ALIGNMENT_CENTER,
		key_rect.size.x,
		maxi(12, int(round(float(BASE_FONT_SIZE) * scale_factor))),
		TEXT_COLOR
	)


func get_hint_rect(view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> Rect2:
	if view_size.x <= 0.0 or view_size.y <= 0.0 or game_size.y <= 0.0:
		return Rect2()
	var scale_factor := clampf(game_size.y / 750.0, 0.72, 2.5)
	var hint_size := BASE_HINT_SIZE * scale_factor
	var margin := BASE_SIDE_MARGIN * scale_factor
	var left_pillar_width := maxf(0.0, game_offset.x)
	if left_pillar_width + 0.001 < hint_size.x + margin * 2.0:
		return Rect2()
	var x := left_pillar_width - margin - hint_size.x
	var center_y := game_offset.y + game_size.y * PILLAR_Y_RATIO
	var y := clampf(
		center_y - hint_size.y * 0.5,
		margin,
		view_size.y - margin - hint_size.y
	)
	return Rect2(Vector2(x, y), hint_size)


func get_key_label() -> String:
	return "M"


func is_visible(tower_surface_active: bool) -> bool:
	return (
		TowerAscentFeatureFlags.is_vertical_slice_enabled()
		and not tower_surface_active
	)


func get_hint_text() -> String:
	return TowerAscentMapOverlayLocalization.text(
		TowerAscentMapOverlayLocalization.KEY_HUD_HINT
	)


func _draw_map_pictogram(canvas: CanvasItem, rect: Rect2, scale_factor: float) -> void:
	var left_x := rect.position.x
	var fold_a := left_x + rect.size.x * 0.34
	var fold_b := left_x + rect.size.x * 0.68
	var top := rect.position.y
	var bottom := rect.end.y
	var points := PackedVector2Array([
		Vector2(left_x, top + rect.size.y * 0.12),
		Vector2(fold_a, top),
		Vector2(fold_b, top + rect.size.y * 0.14),
		Vector2(rect.end.x, top + rect.size.y * 0.02),
		Vector2(rect.end.x, bottom - rect.size.y * 0.12),
		Vector2(fold_b, bottom),
		Vector2(fold_a, bottom - rect.size.y * 0.14),
		Vector2(left_x, bottom - rect.size.y * 0.02),
	])
	canvas.draw_colored_polygon(points, MAP_FILL)
	var line_width := maxf(1.0, 1.2 * scale_factor)
	canvas.draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[5], points[6], points[7], points[0]]), PANEL_BORDER, line_width, true)
	canvas.draw_line(Vector2(fold_a, top), Vector2(fold_a, bottom - rect.size.y * 0.14), MAP_FOLD, line_width, true)
	canvas.draw_line(Vector2(fold_b, top + rect.size.y * 0.14), Vector2(fold_b, bottom), MAP_FOLD, line_width, true)
	var route := PackedVector2Array([
		Vector2(left_x + rect.size.x * 0.15, bottom - rect.size.y * 0.25),
		Vector2(left_x + rect.size.x * 0.40, top + rect.size.y * 0.40),
		Vector2(left_x + rect.size.x * 0.62, bottom - rect.size.y * 0.32),
		Vector2(left_x + rect.size.x * 0.84, top + rect.size.y * 0.28),
	])
	canvas.draw_polyline(route, MAP_ROUTE, maxf(1.2, 1.8 * scale_factor), true)
	canvas.draw_circle(route[0], maxf(1.5, 2.0 * scale_factor), MAP_ROUTE)
	canvas.draw_circle(route[route.size() - 1], maxf(1.5, 2.0 * scale_factor), MAP_ROUTE)
