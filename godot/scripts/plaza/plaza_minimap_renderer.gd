extends RefCounted

const PlazaMinimapProjection := preload("res://scripts/plaza/plaza_minimap_projection.gd")

const SUPPORTED_BUILDING_TYPES := [
	"bank",
	"shop",
	"gacha",
	"lingpet_store",
	"blacksmith",
	"tavern",
	"academy",
]


static func draw(canvas: CanvasItem, state: Dictionary, scale: float) -> void:
	if canvas == null:
		return
	var panel_rect: Rect2 = state.get("panel_rect", PlazaMinimapProjection.PANEL_RECT)
	var track_rect: Rect2 = state.get("track_rect", PlazaMinimapProjection.get_track_rect())
	var camera_rect: Rect2 = state.get("camera_rect", Rect2())
	var player_marker: Vector2 = state.get("player_marker", Vector2.ZERO)
	var exit_marker: Vector2 = state.get("exit_marker", Vector2.ZERO)
	var panel_px := Rect2(panel_rect.position * scale, panel_rect.size * scale)
	var track_px := Rect2(track_rect.position * scale, track_rect.size * scale)
	canvas.draw_rect(panel_px, Color(0.006, 0.014, 0.026, 0.82), true)
	canvas.draw_rect(panel_px, Color(0.0, 0.82, 1.0, 0.46), false, max(1.0, 1.0 * scale))
	canvas.draw_line(
		(panel_rect.position + Vector2(10.0, 10.0)) * scale,
		(panel_rect.position + Vector2(panel_rect.size.x - 10.0, 10.0)) * scale,
		Color(0.0, 0.82, 1.0, 0.18),
		max(1.0, 1.0 * scale)
	)
	canvas.draw_rect(track_px, Color(0.025, 0.050, 0.072, 0.92), true)
	canvas.draw_rect(track_px, Color(0.0, 0.86, 1.0, 0.34), false, max(1.0, 1.0 * scale))
	if camera_rect.size.x > 0.0:
		canvas.draw_rect(Rect2(camera_rect.position * scale, camera_rect.size * scale), Color(0.30, 0.78, 1.0, 0.16), true)
	var markers_value: Variant = state.get("building_markers", [])
	if markers_value is Array:
		for marker_value in markers_value:
			if not (marker_value is Dictionary):
				continue
			var marker := marker_value as Dictionary
			var marker_pos: Vector2 = marker.get("position", Vector2.ZERO)
			var icon_pos: Vector2 = marker.get("icon_position", marker_pos + Vector2(0.0, -17.0))
			var marker_color := PlazaMinimapProjection.get_building_color(str(marker.get("type", "")))
			canvas.draw_line(marker_pos * scale, icon_pos * scale, Color(marker_color.r, marker_color.g, marker_color.b, 0.34), max(1.0, 1.0 * scale))
			canvas.draw_rect(Rect2((marker_pos + Vector2(-1.4, -5.0)) * scale, Vector2(2.8, 10.0) * scale), marker_color, true)
			_draw_building_badge(canvas, marker, icon_pos, marker_color, scale)
	canvas.draw_line(
		(exit_marker + Vector2(0.0, -8.0)) * scale,
		(exit_marker + Vector2(0.0, 8.0)) * scale,
		Color(1.0, 0.80, 0.30, 0.94),
		max(1.0, 2.0 * scale)
	)
	canvas.draw_line(
		(exit_marker + Vector2(-5.0, -4.0)) * scale,
		exit_marker * scale,
		Color(1.0, 0.80, 0.30, 0.86),
		max(1.0, 1.5 * scale)
	)
	canvas.draw_line(
		(exit_marker + Vector2(-5.0, 4.0)) * scale,
		exit_marker * scale,
		Color(1.0, 0.80, 0.30, 0.86),
		max(1.0, 1.5 * scale)
	)
	canvas.draw_circle(player_marker * scale, 4.6 * scale, Color(0.0, 0.96, 1.0, 0.96))
	canvas.draw_circle(player_marker * scale, 2.0 * scale, Color(1.0, 1.0, 1.0, 0.92))


static func supports_building_type(building_type: String) -> bool:
	return SUPPORTED_BUILDING_TYPES.has(building_type)


static func _draw_building_badge(canvas: CanvasItem, marker: Dictionary, icon_pos: Vector2, marker_color: Color, scale: float) -> void:
	var building_type := str(marker.get("type", ""))
	var radius := PlazaMinimapProjection.ICON_SIZE * 0.52
	canvas.draw_circle(icon_pos * scale, (radius + 1.7) * scale, Color(0.0, 0.0, 0.0, 0.42))
	canvas.draw_circle(icon_pos * scale, radius * scale, Color(0.018, 0.032, 0.050, 0.96))
	canvas.draw_circle(icon_pos * scale, (radius - 1.5) * scale, Color(marker_color.r * 0.16, marker_color.g * 0.16, marker_color.b * 0.16, 0.92))
	canvas.draw_arc(icon_pos * scale, radius * scale, 0.0, TAU, 20, marker_color, max(1.0, 1.1 * scale), true)
	match building_type:
		"bank":
			_draw_bank_emblem(canvas, icon_pos, marker_color, scale)
		"shop":
			_draw_shop_emblem(canvas, icon_pos, marker_color, scale)
		"gacha":
			_draw_gacha_emblem(canvas, icon_pos, marker_color, scale)
		"lingpet_store":
			_draw_lingpet_emblem(canvas, icon_pos, marker_color, scale)
		"blacksmith":
			_draw_blacksmith_emblem(canvas, icon_pos, marker_color, scale)
		"tavern":
			_draw_tavern_emblem(canvas, icon_pos, marker_color, scale)
		"academy":
			_draw_academy_emblem(canvas, icon_pos, marker_color, scale)
		_:
			canvas.draw_circle(icon_pos * scale, 2.6 * scale, marker_color)


static func _draw_bank_emblem(canvas: CanvasItem, center: Vector2, color: Color, scale: float) -> void:
	canvas.draw_circle((center + Vector2(-1.5, -0.5)) * scale, 3.4 * scale, Color(1.0, 0.82, 0.34, 0.96))
	canvas.draw_arc((center + Vector2(-1.5, -0.5)) * scale, 3.4 * scale, 0.0, TAU, 12, Color(0.16, 0.08, 0.02, 0.92), max(1.0, 0.9 * scale), true)
	canvas.draw_line((center + Vector2(-1.5, -3.6)) * scale, (center + Vector2(-1.5, 2.8)) * scale, Color(0.16, 0.08, 0.02, 0.82), max(1.0, 0.8 * scale))
	canvas.draw_line((center + Vector2(-4.4, -0.4)) * scale, (center + Vector2(1.4, -0.4)) * scale, Color(0.16, 0.08, 0.02, 0.82), max(1.0, 0.8 * scale))
	canvas.draw_line((center + Vector2(2.8, 3.0)) * scale, (center + Vector2(6.0, 3.0)) * scale, color, max(1.0, 1.2 * scale))
	canvas.draw_line((center + Vector2(3.4, 0.8)) * scale, (center + Vector2(5.6, 0.8)) * scale, color, max(1.0, 1.2 * scale))


static func _draw_shop_emblem(canvas: CanvasItem, center: Vector2, color: Color, scale: float) -> void:
	canvas.draw_circle((center + Vector2(-3.2, -1.8)) * scale, 2.6 * scale, Color(1.0, 0.78, 0.32, 0.96))
	canvas.draw_rect(Rect2((center + Vector2(0.0, -2.8)) * scale, Vector2(5.4, 5.4) * scale), Color(color.r, color.g, color.b, 0.92), false, max(1.0, 1.1 * scale))
	canvas.draw_line((center + Vector2(0.0, -0.2)) * scale, (center + Vector2(5.4, -0.2)) * scale, color, max(1.0, 0.8 * scale))


static func _draw_gacha_emblem(canvas: CanvasItem, center: Vector2, color: Color, scale: float) -> void:
	canvas.draw_circle(center * scale, 4.0 * scale, Color(1.0, 1.0, 1.0, 0.16))
	canvas.draw_arc(center * scale, 4.0 * scale, -0.15, TAU * 0.72, 16, color, max(1.0, 1.1 * scale), true)
	canvas.draw_line((center + Vector2(2.8, -3.4)) * scale, (center + Vector2(5.3, -1.3)) * scale, color, max(1.0, 1.0 * scale))
	canvas.draw_line((center + Vector2(-4.0, 0.0)) * scale, (center + Vector2(4.0, 0.0)) * scale, color, max(1.0, 1.0 * scale))


static func _draw_lingpet_emblem(canvas: CanvasItem, center: Vector2, color: Color, scale: float) -> void:
	canvas.draw_circle((center + Vector2(0.0, 0.8)) * scale, 3.4 * scale, Color(0.92, 1.0, 0.88, 0.94))
	canvas.draw_circle((center + Vector2(0.0, -2.6)) * scale, 2.4 * scale, Color(0.92, 1.0, 0.88, 0.94))
	canvas.draw_arc(center * scale, 5.0 * scale, -0.55, 2.55, 18, color, max(1.0, 1.0 * scale), true)
	canvas.draw_arc(center * scale, 5.0 * scale, 2.9, 5.55, 18, color, max(1.0, 1.0 * scale), true)


static func _draw_blacksmith_emblem(canvas: CanvasItem, center: Vector2, color: Color, scale: float) -> void:
	canvas.draw_line((center + Vector2(-4.8, -4.0)) * scale, (center + Vector2(1.6, 2.4)) * scale, color, max(1.0, 1.8 * scale))
	canvas.draw_rect(Rect2((center + Vector2(-6.0, -5.8)) * scale, Vector2(4.6, 3.0) * scale), Color(1.0, 0.80, 0.42, 0.96), true)
	canvas.draw_line((center + Vector2(-3.8, 4.6)) * scale, (center + Vector2(5.2, 4.6)) * scale, color, max(1.0, 1.5 * scale))
	canvas.draw_line((center + Vector2(-1.4, 2.4)) * scale, (center + Vector2(2.8, 2.4)) * scale, color, max(1.0, 1.2 * scale))


static func _draw_tavern_emblem(canvas: CanvasItem, center: Vector2, color: Color, scale: float) -> void:
	canvas.draw_rect(Rect2((center + Vector2(-4.4, -3.8)) * scale, Vector2(6.2, 7.0) * scale), Color(0.96, 0.84, 0.62, 0.92), true)
	canvas.draw_line((center + Vector2(-3.2, -1.6)) * scale, (center + Vector2(0.6, -1.6)) * scale, Color(0.18, 0.10, 0.04, 0.86), max(1.0, 0.8 * scale))
	canvas.draw_circle((center + Vector2(4.0, 1.8)) * scale, 2.3 * scale, color)
	canvas.draw_line((center + Vector2(4.0, 4.0)) * scale, (center + Vector2(4.0, 5.8)) * scale, color, max(1.0, 0.9 * scale))


static func _draw_academy_emblem(canvas: CanvasItem, center: Vector2, color: Color, scale: float) -> void:
	canvas.draw_rect(Rect2((center + Vector2(-5.6, -3.2)) * scale, Vector2(5.0, 6.0) * scale), Color(0.82, 0.86, 1.0, 0.88), false, max(1.0, 1.0 * scale))
	canvas.draw_rect(Rect2((center + Vector2(0.6, -3.2)) * scale, Vector2(5.0, 6.0) * scale), Color(0.82, 0.86, 1.0, 0.88), false, max(1.0, 1.0 * scale))
	canvas.draw_line(center * scale, (center + Vector2(0.0, 3.4)) * scale, color, max(1.0, 0.8 * scale))
	canvas.draw_circle((center + Vector2(0.0, -5.0)) * scale, 2.1 * scale, color)
