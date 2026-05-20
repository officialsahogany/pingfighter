extends RefCounted

var display_gauge := 0.0


func prewarm_assets() -> void:
	pass


func reset() -> void:
	display_gauge = 0.0


func draw(canvas: CanvasItem, context: Dictionary) -> void:
	if canvas == null or not bool(context.get("stage4_ponk_gauge_visible", true)):
		return
	var game_offset: Vector2 = _as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var game_size: Vector2 = _as_vector2(context.get("game_size", Vector2(760.0, 750.0)), Vector2(760.0, 750.0))
	var gauge_max: float = maxf(1.0, float(context.get("stage4_ponk_gauge_max", 500.0)))
	var gauge_value: float = clampf(float(context.get("stage4_ponk_gauge_value", 0.0)), 0.0, gauge_max)
	display_gauge = lerpf(display_gauge, gauge_value, 0.18)
	if abs(display_gauge - gauge_value) < 0.5:
		display_gauge = gauge_value
	var ready: bool = bool(context.get("stage4_ponk_gauge_ready", false))
	var active: bool = bool(context.get("stage4_ponk_gauge_active", false))
	var scale: float = maxf(0.72, game_size.y / 750.0)
	var size := Vector2(22.0, 132.0) * scale
	var pos := game_offset + Vector2(game_size.x - 52.0 * scale, 50.0 * scale)
	var rect := Rect2(pos, size)
	_draw_pagoda_caps(canvas, rect, ready, active)
	_draw_frame(canvas, rect, ready, active)
	_draw_fill(canvas, rect, display_gauge / gauge_max, ready, active)


func _draw_pagoda_caps(canvas: CanvasItem, rect: Rect2, ready: bool, active: bool) -> void:
	var primary: Color = _primary_color(ready, active)
	var secondary: Color = _secondary_color(ready, active)
	var top := PackedVector2Array([
		Vector2(rect.get_center().x, rect.position.y - 14.0),
		Vector2(rect.position.x - 8.0, rect.position.y - 1.0),
		Vector2(rect.position.x - 4.0, rect.position.y + 5.0),
		Vector2(rect.end.x + 4.0, rect.position.y + 5.0),
		Vector2(rect.end.x + 8.0, rect.position.y - 1.0),
	])
	canvas.draw_colored_polygon(top, primary)
	canvas.draw_polyline(top, secondary, 2.0, true)
	var bottom := PackedVector2Array([
		Vector2(rect.position.x - 5.0, rect.end.y - 4.0),
		Vector2(rect.position.x - 8.0, rect.end.y + 3.0),
		Vector2(rect.get_center().x, rect.end.y + 13.0),
		Vector2(rect.end.x + 8.0, rect.end.y + 3.0),
		Vector2(rect.end.x + 5.0, rect.end.y - 4.0),
	])
	canvas.draw_colored_polygon(bottom, primary.darkened(0.10))
	canvas.draw_polyline(bottom, secondary, 2.0, true)


func _draw_frame(canvas: CanvasItem, rect: Rect2, ready: bool, active: bool) -> void:
	var primary: Color = _primary_color(ready, active)
	canvas.draw_rect(rect.grow(4.0), Color(0.03, 0.02, 0.04, 0.78))
	canvas.draw_rect(rect.grow(4.0), primary, false, 3.0, true)
	canvas.draw_rect(rect.grow(1.0), Color(0.92, 0.72, 0.32, 0.62), false, 1.5, true)
	for idx in range(4):
		var y: float = rect.position.y + 22.0 + float(idx) * 28.0
		canvas.draw_line(Vector2(rect.position.x - 8.0, y), Vector2(rect.position.x - 2.0, y - 5.0), primary, 1.3, true)
		canvas.draw_line(Vector2(rect.position.x - 8.0, y), Vector2(rect.position.x - 2.0, y + 5.0), primary, 1.3, true)
		canvas.draw_line(Vector2(rect.end.x + 8.0, y), Vector2(rect.end.x + 2.0, y - 5.0), primary, 1.3, true)
		canvas.draw_line(Vector2(rect.end.x + 8.0, y), Vector2(rect.end.x + 2.0, y + 5.0), primary, 1.3, true)


func _draw_fill(canvas: CanvasItem, rect: Rect2, ratio: float, ready: bool, active: bool) -> void:
	var inner := rect.grow(-4.0)
	canvas.draw_rect(inner, Color(0.02, 0.015, 0.03, 0.95))
	var fill_h: float = inner.size.y * clampf(ratio, 0.0, 1.0)
	if fill_h <= 1.0:
		return
	var fill_rect := Rect2(Vector2(inner.position.x, inner.end.y - fill_h), Vector2(inner.size.x, fill_h))
	var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.006)
	var base := Color(0.30, 0.48, 0.62, 1.0)
	var mid := Color(0.72, 0.84, 0.95, 1.0)
	if ready:
		base = Color(0.78, 0.43, 0.08, 1.0)
		mid = Color(1.0, 0.78 + pulse * 0.12, 0.28, 1.0)
	if active:
		base = Color(0.80, 0.10, 0.08, 1.0)
		mid = Color(1.0, 0.32 + pulse * 0.18, 0.18, 1.0)
	canvas.draw_rect(fill_rect, base)
	canvas.draw_rect(fill_rect.grow(-3.0), mid)
	canvas.draw_line(Vector2(fill_rect.position.x + fill_rect.size.x * 0.5, fill_rect.position.y), Vector2(fill_rect.position.x + fill_rect.size.x * 0.5, fill_rect.end.y), Color(1.0, 1.0, 0.82, 0.38), 2.0, true)


func _primary_color(ready: bool, active: bool) -> Color:
	if active:
		return Color(1.0, 0.23, 0.16, 0.96)
	if ready:
		return Color(1.0, 0.68, 0.18, 0.96)
	return Color(0.66, 0.52, 0.28, 0.88)


func _secondary_color(ready: bool, active: bool) -> Color:
	if active:
		return Color(1.0, 0.70, 0.42, 0.86)
	if ready:
		return Color(1.0, 0.90, 0.48, 0.86)
	return Color(0.90, 0.78, 0.48, 0.70)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
