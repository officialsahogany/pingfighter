extends RefCounted

const Stage1FallbackFrameMotifRenderer := preload("res://scripts/stages/stage1/stage1_fallback_frame_motif_renderer.gd")
const Stage1FallbackPanelOrnamentRenderer := preload("res://scripts/stages/stage1/stage1_fallback_panel_ornament_renderer.gd")

const PILLAR_SILK_DARK := Color(0.52, 0.46, 0.38)
const PILLAR_SILK_LIGHT := Color(0.70, 0.64, 0.53)
const PILLAR_GOLD_DARK := Color(0.45, 0.34, 0.16)
const PILLAR_GOLD := Color(0.76, 0.61, 0.31)
const PILLAR_GOLD_BRIGHT := Color(0.92, 0.79, 0.46)
const PILLAR_CREAM := Color(0.96, 0.92, 0.82)

var frame_motif_renderer: Object = Stage1FallbackFrameMotifRenderer.new()
var ornament_renderer: Object = Stage1FallbackPanelOrnamentRenderer.new()


func draw(canvas: CanvasItem, view_size: Vector2, game_offset: Vector2, game_size: Vector2, source_game_height: float, t: float) -> void:
	if canvas == null:
		return

	var left_rect := Rect2(0.0, 0.0, game_offset.x, view_size.y)
	var right_rect := Rect2(game_offset.x + game_size.x, 0.0, max(0.0, view_size.x - (game_offset.x + game_size.x)), view_size.y)
	var top_rect := Rect2(game_offset.x, 0.0, game_size.x, game_offset.y)
	var bottom_rect := Rect2(game_offset.x, game_offset.y + game_size.y, game_size.x, max(0.0, view_size.y - (game_offset.y + game_size.y)))
	var game_rect := Rect2(game_offset, game_size)

	if left_rect.size.x > 0.0:
		_draw_pillar_panel(canvas, left_rect, false, t)
	if right_rect.size.x > 0.0:
		_draw_pillar_panel(canvas, right_rect, true, t)
	if top_rect.size.y > 0.0:
		_draw_border_band(canvas, top_rect, t)
	if bottom_rect.size.y > 0.0:
		_draw_border_band(canvas, bottom_rect, t + PI * 0.5)
	canvas.draw_rect(game_rect, Color(PILLAR_GOLD_DARK.r, PILLAR_GOLD_DARK.g, PILLAR_GOLD_DARK.b, 0.75), false, 2.0)
	canvas.draw_rect(Rect2(game_offset.x - 4.0, game_offset.y - 4.0, game_size.x + 8.0, game_size.y + 8.0), Color(PILLAR_GOLD_BRIGHT.r, PILLAR_GOLD_BRIGHT.g, PILLAR_GOLD_BRIGHT.b, 0.25), false, 1.0)
	frame_motif_renderer.draw_frame_motifs(canvas, game_rect, t, source_game_height)


func _draw_border_band(canvas: CanvasItem, rect: Rect2, t: float) -> void:
	for y in range(0, int(rect.size.y), 4):
		var ratio: float = float(y) / max(1.0, rect.size.y)
		var wave: float = sin(t + ratio * 8.0) * 0.03
		var color_r: float = clamp(PILLAR_SILK_DARK.r + (PILLAR_SILK_LIGHT.r - PILLAR_SILK_DARK.r) * (0.28 + wave), 0.0, 1.0)
		var color_g: float = clamp(PILLAR_SILK_DARK.g + (PILLAR_SILK_LIGHT.g - PILLAR_SILK_DARK.g) * (0.28 + wave), 0.0, 1.0)
		var color_b: float = clamp(PILLAR_SILK_DARK.b + (PILLAR_SILK_LIGHT.b - PILLAR_SILK_DARK.b) * (0.28 + wave), 0.0, 1.0)
		canvas.draw_rect(Rect2(rect.position.x, rect.position.y + float(y), rect.size.x, 4.0), Color(color_r, color_g, color_b, 1.0))
	canvas.draw_rect(rect, Color(PILLAR_GOLD_DARK.r, PILLAR_GOLD_DARK.g, PILLAR_GOLD_DARK.b, 0.95), false, 2.0)
	canvas.draw_rect(rect.grow(-4.0), Color(PILLAR_GOLD.r, PILLAR_GOLD.g, PILLAR_GOLD.b, 0.80), false, 1.0)


func _draw_pillar_panel(canvas: CanvasItem, rect: Rect2, mirrored: bool, t: float) -> void:
	for y in range(0, int(rect.size.y), 6):
		var ratio: float = float(y) / rect.size.y
		var center_bias: float = 1.0 - abs(ratio - 0.5) * 1.3
		var silk_wave: float = sin(ratio * 16.0 + t * 0.7 + (PI if mirrored else 0.0)) * 0.035
		var color_r: float = clamp(PILLAR_SILK_DARK.r + (PILLAR_SILK_LIGHT.r - PILLAR_SILK_DARK.r) * (0.3 + center_bias * 0.4 + silk_wave), 0.0, 1.0)
		var color_g: float = clamp(PILLAR_SILK_DARK.g + (PILLAR_SILK_LIGHT.g - PILLAR_SILK_DARK.g) * (0.3 + center_bias * 0.4 + silk_wave), 0.0, 1.0)
		var color_b: float = clamp(PILLAR_SILK_DARK.b + (PILLAR_SILK_LIGHT.b - PILLAR_SILK_DARK.b) * (0.3 + center_bias * 0.4 + silk_wave), 0.0, 1.0)
		canvas.draw_rect(Rect2(rect.position.x, rect.position.y + float(y), rect.size.x, 6.0), Color(color_r, color_g, color_b, 1.0))

	for x in range(0, int(rect.size.x), 10):
		var stripe_alpha: float = 0.03 + sin(t * 0.9 + float(x) * 0.22) * 0.01
		canvas.draw_rect(
			Rect2(rect.position.x + float(x), rect.position.y, 4.0, rect.size.y),
			Color(PILLAR_CREAM.r, PILLAR_CREAM.g, PILLAR_CREAM.b, stripe_alpha)
		)

	canvas.draw_rect(rect, Color(PILLAR_GOLD_DARK.r, PILLAR_GOLD_DARK.g, PILLAR_GOLD_DARK.b, 0.95), false, 2.0)
	canvas.draw_rect(rect.grow(-4.0), Color(PILLAR_GOLD.r, PILLAR_GOLD.g, PILLAR_GOLD.b, 0.85), false, 2.0)
	canvas.draw_rect(rect.grow(-8.0), Color(PILLAR_GOLD_BRIGHT.r, PILLAR_GOLD_BRIGHT.g, PILLAR_GOLD_BRIGHT.b, 0.55), false, 1.0)

	var seam_x: float = rect.position.x + (6.0 if not mirrored else rect.size.x - 6.0)
	canvas.draw_line(
		Vector2(seam_x, rect.position.y + 10.0),
		Vector2(seam_x, rect.position.y + rect.size.y - 10.0),
		Color(PILLAR_GOLD_BRIGHT.r, PILLAR_GOLD_BRIGHT.g, PILLAR_GOLD_BRIGHT.b, 0.35),
		1.0
	)

	ornament_renderer.draw(canvas, rect, mirrored, t)
