extends RefCounted

const ScoreboardTopMiniNormalDecorationRenderer := preload("res://scripts/hud/scoreboard_top_mini_normal_decoration_renderer.gd")

var decoration_renderer: Object = ScoreboardTopMiniNormalDecorationRenderer.new()


const GLOW_LAYER_COUNT := 2
const GLOW_LAYER_COUNT_LOD := 1
const BAND_COUNT := 3
const BAND_COUNT_LOD := 1


func draw_background(canvas: Node2D, rect: Rect2, scale_factor: float, sparkle_intensity: float, quality_scale: float = 1.0) -> void:
	var lod_active: bool = quality_scale < 0.85
	var glow_alpha: float = (26.0 + 34.0 * sparkle_intensity) / 255.0
	var glow_layer_count: int = GLOW_LAYER_COUNT_LOD if lod_active else GLOW_LAYER_COUNT
	for layer in range(glow_layer_count):
		var layer_grow: float = max(3.0, 4.0 * scale_factor) + float(layer) * 2.0
		canvas.draw_rect(rect.grow(layer_grow), Color(1.0, 210.0 / 255.0, 90.0 / 255.0, glow_alpha * (0.42 - float(layer) * 0.10)))

	var band_count: int = BAND_COUNT_LOD if lod_active else BAND_COUNT
	var band_height: float = rect.size.y / float(band_count)
	for band_idx in range(band_count):
		var ratio: float = (float(band_idx) + 0.5) / float(band_count)
		var r: float = (24.0 - 8.0 * ratio) / 255.0
		var g: float = (24.0 - 7.0 * ratio) / 255.0
		var b: float = (32.0 - 10.0 * ratio) / 255.0
		if sparkle_intensity > 0.0:
			r = min(1.0, r + (18.0 / 255.0) * sparkle_intensity)
			g = min(1.0, g + (16.0 / 255.0) * sparkle_intensity)
			b = min(1.0, b + (18.0 / 255.0) * sparkle_intensity)
		var y: float = rect.position.y + float(band_idx) * band_height
		var h: float = rect.end.y - y if band_idx == band_count - 1 else band_height + 0.5
		canvas.draw_rect(
			Rect2(rect.position.x, y, rect.size.x, h),
			Color(r, g, b, 238.0 / 255.0)
		)
	canvas.draw_line(
		rect.position + Vector2(4.0 * scale_factor, 2.0 * scale_factor),
		Vector2(rect.end.x - 4.0 * scale_factor, rect.position.y + 2.0 * scale_factor),
		Color(1.0, 1.0, 1.0, (18.0 + 18.0 * sparkle_intensity) / 255.0),
		1.0
	)

	var border_brightness: float = 148.0 + 52.0 * sparkle_intensity
	canvas.draw_rect(rect, Color(border_brightness / 255.0, border_brightness * 0.78 / 255.0, 58.0 / 255.0), false, max(2.0, 2.0 * scale_factor))
	canvas.draw_rect(rect.grow(-3.0 * scale_factor), Color(64.0 / 255.0, 52.0 / 255.0, 30.0 / 255.0, 170.0 / 255.0), false, max(1.0, scale_factor))
	_draw_score_bays(canvas, rect, scale_factor, sparkle_intensity)
	decoration_renderer.draw_score_pips(canvas, rect, scale_factor, sparkle_intensity, quality_scale)


func _draw_score_bays(canvas: Node2D, rect: Rect2, scale_factor: float, sparkle_intensity: float) -> void:
	var side_pad: float = max(8.0, 9.0 * scale_factor)
	var top_pad: float = max(5.0, 5.0 * scale_factor)
	var center_gap: float = max(28.0, 28.0 * scale_factor)
	var score_width: float = (rect.size.x - side_pad * 2.0 - center_gap) * 0.5
	var score_height: float = rect.size.y - top_pad * 2.0
	var player_rect := Rect2(rect.position.x + side_pad, rect.position.y + top_pad, score_width, score_height)
	var boss_rect := Rect2(rect.end.x - side_pad - score_width, rect.position.y + top_pad, score_width, score_height)
	for bay_rect in [player_rect, boss_rect]:
		canvas.draw_rect(bay_rect, Color(4.0 / 255.0, 7.0 / 255.0, 14.0 / 255.0, 190.0 / 255.0))
		canvas.draw_rect(bay_rect, Color(72.0 / 255.0, 64.0 / 255.0, 44.0 / 255.0, 150.0 / 255.0), false, 1.0)
		canvas.draw_line(
			bay_rect.position + Vector2(2.0 * scale_factor, 1.0 * scale_factor),
			Vector2(bay_rect.end.x - 2.0 * scale_factor, bay_rect.position.y + 1.0 * scale_factor),
			Color(1.0, 1.0, 1.0, (20.0 + 22.0 * sparkle_intensity) / 255.0),
			1.0
		)

	var center_x: float = rect.get_center().x
	canvas.draw_line(
		Vector2(center_x, rect.position.y + top_pad),
		Vector2(center_x, rect.end.y - top_pad),
		Color(120.0 / 255.0, 95.0 / 255.0, 45.0 / 255.0, 135.0 / 255.0),
		max(1.0, 1.2 * scale_factor)
	)


func draw_sparkles(
	canvas: Node2D,
	rect: Rect2,
	scale_factor: float,
	sparkle_progress: float,
	sparkle_intensity: float,
	quality_scale: float = 1.0
) -> void:
	decoration_renderer.draw_sparkles(canvas, rect, scale_factor, sparkle_progress, sparkle_intensity, quality_scale)
