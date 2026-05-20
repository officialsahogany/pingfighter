extends RefCounted

const ScoreboardTopMiniDeuceEmberRenderer := preload("res://scripts/hud/scoreboard_top_mini_deuce_ember_renderer.gd")

const GLOW_LAYER_COUNT := 2
const GLOW_LAYER_COUNT_LOD := 1
const FIRE_GRADIENT_BANDS := 4
const FIRE_GRADIENT_BANDS_LOD := 2
const FLAME_LAYER_COUNT := 2
const FLAME_LAYER_COUNT_LOD := 1
const FLAME_STEP := 6
const FLAME_STEP_LOD := 10

var ember_renderer: Object = ScoreboardTopMiniDeuceEmberRenderer.new()


func draw(canvas: CanvasItem, rect: Rect2, scale_factor: float, t: float, quality_scale: float = 1.0) -> float:
	var pulse: float = sin(t * 8.0) * 0.3 + 0.7
	var lod_active: bool = quality_scale < 0.85
	_draw_glow(canvas, rect, scale_factor, pulse, lod_active)
	_draw_fire_gradient(canvas, rect, t, lod_active)
	canvas.draw_rect(rect, Color(180.0 / 255.0, 60.0 / 255.0, 20.0 / 255.0), false, max(2.0, 3.0 * scale_factor))
	_draw_flame_tongues(canvas, rect, scale_factor, t, lod_active)
	if not lod_active:
		ember_renderer.draw(canvas, rect, scale_factor, t)
	return pulse


func _draw_glow(canvas: CanvasItem, rect: Rect2, scale_factor: float, pulse: float, lod_active: bool) -> void:
	var glow_layers: int = GLOW_LAYER_COUNT_LOD if lod_active else GLOW_LAYER_COUNT
	for glow_layer in range(glow_layers):
		var glow_margin: float = (20.0 - float(glow_layer) * 3.0) * scale_factor
		var glow_alpha: float = ((40.0 - float(glow_layer) * 7.0) / 255.0) * pulse
		canvas.draw_rect(
			rect.grow(glow_margin),
			Color(1.0, (50.0 + float(glow_layer) * 20.0) / 255.0, 0.0, glow_alpha)
		)


func _draw_fire_gradient(canvas: CanvasItem, rect: Rect2, t: float, lod_active: bool) -> void:
	var band_count: int = FIRE_GRADIENT_BANDS_LOD if lod_active else FIRE_GRADIENT_BANDS
	var band_height: float = rect.size.y / float(band_count)
	for band_idx in range(band_count):
		var ratio: float = (float(band_idx) + 0.5) / float(band_count)
		var combined: float = (
			sin(t * 12.0 + ratio * 8.0) * 0.15
			+ sin(t * 18.0 + ratio * 12.0 + 2.0) * 0.10
			+ sin(t * 25.0 + ratio * 20.0) * 0.08
		)
		var color: Color = _get_fire_gradient_color(ratio, combined)
		var y: float = rect.position.y + float(band_idx) * band_height
		var h: float = rect.end.y - y if band_idx == band_count - 1 else band_height + 0.5
		canvas.draw_rect(Rect2(rect.position.x, y, rect.size.x, h), color)


func _get_fire_gradient_color(ratio: float, wave: float) -> Color:
	var r: float
	var g: float
	var b: float
	if ratio < 0.3:
		r = 255.0
		g = 255.0 - 55.0 * ratio / 0.3
		b = 200.0 - 150.0 * ratio / 0.3
	elif ratio < 0.6:
		r = 255.0
		g = 200.0 - 100.0 * (ratio - 0.3) / 0.3
		b = 50.0 - 30.0 * (ratio - 0.3) / 0.3
	else:
		r = 255.0 - 80.0 * (ratio - 0.6) / 0.4
		g = 100.0 - 70.0 * (ratio - 0.6) / 0.4
		b = 10.0
	r = clamp(r + 60.0 * wave, 0.0, 255.0)
	g = clamp(g + 80.0 * wave, 0.0, 255.0)
	b = clamp(b + 30.0 * wave, 0.0, 255.0)
	return Color(r / 255.0, g / 255.0, b / 255.0, 245.0 / 255.0)


func _draw_flame_tongues(canvas: CanvasItem, rect: Rect2, scale_factor: float, t: float, lod_active: bool) -> void:
	var layer_count: int = FLAME_LAYER_COUNT_LOD if lod_active else FLAME_LAYER_COUNT
	var step_size: int = FLAME_STEP_LOD if lod_active else FLAME_STEP
	for layer in range(layer_count):
		var layer_height: float = (35.0 - float(layer) * 6.0) * scale_factor
		var points := PackedVector2Array()
		points.append(Vector2(rect.position.x - 10.0 * scale_factor, rect.position.y + 7.0 * scale_factor))
		for step in range(0, int(rect.size.x + 20.0 * scale_factor), step_size):
			var fx: float = float(step)
			var h: float = layer_height * 0.4
			h += sin(t * (15.0 + float(layer) * 3.0) + fx * 0.18) * layer_height * 0.3
			h += sin(t * (22.0 + float(layer) * 5.0) + fx * 0.28) * layer_height * 0.2
			h += sin(t * (35.0 + float(layer) * 8.0) + fx * 0.45) * layer_height * 0.15
			points.append(Vector2(rect.position.x - 10.0 * scale_factor + fx, rect.position.y + 7.0 * scale_factor - max(0.0, h)))
		points.append(Vector2(rect.end.x + 10.0 * scale_factor, rect.position.y + 7.0 * scale_factor))
		canvas.draw_colored_polygon(points, _get_flame_layer_color(layer))


func _get_flame_layer_color(layer: int) -> Color:
	if layer == 0:
		return Color(1.0, 1.0, 220.0 / 255.0, 200.0 / 255.0)
	if layer == 1:
		return Color(1.0, 200.0 / 255.0, 80.0 / 255.0, 160.0 / 255.0)
	if layer == 2:
		return Color(1.0, 120.0 / 255.0, 30.0 / 255.0, 120.0 / 255.0)
	return Color(200.0 / 255.0, 60.0 / 255.0, 10.0 / 255.0, 80.0 / 255.0)
