extends RefCounted

const PillarShapeHelper := preload("res://scripts/hud/pillar_shape_helper.gd")

const STAGE1_PILLAR_SILK_DARK := Color(0.52, 0.46, 0.38)
const STAGE1_PILLAR_GOLD := Color(0.76, 0.61, 0.31)
const STAGE1_PILLAR_GOLD_BRIGHT := Color(0.92, 0.79, 0.46)

var shape_helper: Object = PillarShapeHelper.new()


func draw_inner_side_vignette(
	canvas: CanvasItem,
	rect: Rect2,
	mirrored: bool,
	t: float,
	silk_dark: Color = STAGE1_PILLAR_SILK_DARK,
	gold_bright: Color = STAGE1_PILLAR_GOLD_BRIGHT,
	gold: Color = STAGE1_PILLAR_GOLD
) -> void:
	if canvas == null:
		return

	var band_width: int = int(max(1.0, rect.size.x))
	for x in range(0, band_width, 2):
		var ratio: float = float(x) / max(1.0, float(band_width - 1))
		var outer_weight: float = ratio if mirrored else (1.0 - ratio)
		var pulse: float = 0.92 + sin(t * 1.2 + ratio * 5.0) * 0.04
		var alpha: float = pow(outer_weight, 1.85) * 0.18 * pulse
		var col := Color(
			silk_dark.r * 0.65,
			silk_dark.g * 0.65,
			silk_dark.b * 0.78,
			alpha
		)
		canvas.draw_rect(Rect2(rect.position.x + float(x), rect.position.y, 2.0, rect.size.y), col)

	var seam_x: float = rect.end.x if not mirrored else rect.position.x
	var seam_alpha: float = 0.12 + 0.03 * sin(t * 2.0)
	canvas.draw_line(
		Vector2(seam_x, rect.position.y),
		Vector2(seam_x, rect.end.y),
		Color(gold_bright.r, gold_bright.g, gold_bright.b, seam_alpha),
		1.0
	)

	var glow_rect := rect
	glow_rect.size.x = min(rect.size.x, 26.0)
	if mirrored:
		glow_rect.position.x = rect.end.x - glow_rect.size.x
	var glow_alpha: float = 0.05 + 0.02 * sin(t * 1.6)
	canvas.draw_colored_polygon(
		shape_helper.build_ellipse_points(Rect2(
			glow_rect.position.x - 10.0,
			rect.position.y + 140.0,
			glow_rect.size.x + 20.0,
			rect.size.y - 280.0
		), 32),
		Color(gold.r, gold.g, gold.b, glow_alpha)
	)


func draw_stage1_inner_side_vignettes(
	canvas: CanvasItem,
	width: float,
	height: float,
	pillar_width: float,
	t: float
) -> void:
	draw_inner_side_vignette(canvas, Rect2(0.0, 0.0, pillar_width, height), false, t)
	draw_inner_side_vignette(canvas, Rect2(width - pillar_width, 0.0, pillar_width, height), true, t)
