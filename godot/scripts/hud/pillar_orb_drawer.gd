extends RefCounted

const PillarShapeHelper := preload("res://scripts/hud/pillar_shape_helper.gd")
const PillarOrbChromeDrawer := preload("res://scripts/hud/pillar_orb_chrome_drawer.gd")
const PillarLiquidDrawer := preload("res://scripts/hud/pillar_liquid_drawer.gd")
const PillarStage1VignetteDrawer := preload("res://scripts/hud/pillar_stage1_vignette_drawer.gd")

const STAGE1_PILLAR_SILK_DARK := Color(0.52, 0.46, 0.38)
const STAGE1_PILLAR_GOLD := Color(0.76, 0.61, 0.31)
const STAGE1_PILLAR_GOLD_BRIGHT := Color(0.92, 0.79, 0.46)

var shape_helper: Object = PillarShapeHelper.new()
var chrome_drawer: Object = PillarOrbChromeDrawer.new()
var liquid_drawer: Object = PillarLiquidDrawer.new()
var vignette_drawer: Object = PillarStage1VignetteDrawer.new()


func build_ellipse_points(rect: Rect2, segments: int = 24) -> PackedVector2Array:
	return shape_helper.build_ellipse_points(rect, segments)


func build_sector_points(
	center: Vector2,
	outer_radius: float,
	start_rad: float,
	end_rad: float,
	segments: int = 32,
	inner_radius: float = 0.0
) -> PackedVector2Array:
	return shape_helper.build_sector_points(center, outer_radius, start_rad, end_rad, segments, inner_radius)


func draw_soft_shadow_ellipse(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	shape_helper.draw_soft_shadow_ellipse(canvas, rect, color)


func draw_inner_side_vignette(
	canvas: CanvasItem,
	rect: Rect2,
	mirrored: bool,
	t: float,
	silk_dark: Color = STAGE1_PILLAR_SILK_DARK,
	gold_bright: Color = STAGE1_PILLAR_GOLD_BRIGHT,
	gold: Color = STAGE1_PILLAR_GOLD
) -> void:
	vignette_drawer.draw_inner_side_vignette(canvas, rect, mirrored, t, silk_dark, gold_bright, gold)


func draw_stage1_inner_side_vignettes(canvas: CanvasItem, width: float, height: float, pillar_width: float, t: float) -> void:
	vignette_drawer.draw_stage1_inner_side_vignettes(canvas, width, height, pillar_width, t)


func ease_out_cubic(t: float) -> float:
	return shape_helper.ease_out_cubic(t)


func ease_in_out_sine(t: float) -> float:
	return shape_helper.ease_in_out_sine(t)


func get_orb_frame_draw_size(radius: float) -> float:
	return chrome_drawer.get_orb_frame_draw_size(radius)


# 정적 글래스 레이어 베이크 프리웜 (로딩 스텝에서 호출; true = 완료).
func prewarm_static_layers_step() -> bool:
	return bool(chrome_drawer.prewarm_static_layers_step())


func draw_rotating_orb_frame_texture(
	canvas: CanvasItem,
	texture: Texture2D,
	center: Vector2,
	radius: float,
	spin_angle_degrees: float
) -> bool:
	return chrome_drawer.draw_rotating_orb_frame_texture(canvas, texture, center, radius, spin_angle_degrees)


func draw_pillar_orb_frame(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	frame_width: float,
	metal_dark: Color,
	metal_mid: Color,
	metal_light: Color,
	gem_core: Color,
	gem_highlight: Color
) -> void:
	chrome_drawer.draw_pillar_orb_frame(canvas, center, radius, frame_width, metal_dark, metal_mid, metal_light, gem_core, gem_highlight)


func draw_pillar_orb_glass(canvas: CanvasItem, center: Vector2, radius: float, rim_color: Color) -> void:
	chrome_drawer.draw_pillar_orb_glass(canvas, center, radius, rim_color)


func draw_pillar_orb_glass_lod(canvas: CanvasItem, center: Vector2, radius: float, rim_color: Color) -> void:
	chrome_drawer.draw_pillar_orb_glass_lod(canvas, center, radius, rim_color)


func draw_pillar_text_centered(canvas: CanvasItem, center: Vector2, text: String, font_size: int, color: Color) -> void:
	chrome_drawer.draw_pillar_text_centered(canvas, center, text, font_size, color)


func draw_pillar_text_centered_lod(canvas: CanvasItem, center: Vector2, text: String, font_size: int, color: Color) -> void:
	chrome_drawer.draw_pillar_text_centered_lod(canvas, center, text, font_size, color)


func draw_pillar_liquid_fill(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	fill_ratio: float,
	t: float,
	top_color: Color,
	bottom_color: Color,
	wave_glow: Color,
	quality_scale: float = 1.0
) -> void:
	liquid_drawer.draw_pillar_liquid_fill(canvas, center, radius, fill_ratio, t, top_color, bottom_color, wave_glow, quality_scale)


func draw_dash_sector_liquid(
	canvas: CanvasItem,
	center: Vector2,
	inner_radius: float,
	start_rad: float,
	end_rad: float,
	progress: float,
	t: float,
	scale_factor: float = 1.0,
	quality_scale: float = 1.0
) -> void:
	liquid_drawer.draw_dash_sector_liquid(canvas, center, inner_radius, start_rad, end_rad, progress, t, scale_factor, quality_scale)
