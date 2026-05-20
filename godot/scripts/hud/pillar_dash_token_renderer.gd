extends RefCounted

const PillarDashTokenFillRenderer := preload("res://scripts/hud/pillar_dash_token_fill_renderer.gd")
const PillarDashTokenFlashRenderer := preload("res://scripts/hud/pillar_dash_token_flash_renderer.gd")

var fill_renderer: Object = PillarDashTokenFillRenderer.new()
var flash_renderer: Object = PillarDashTokenFlashRenderer.new()


func draw_tokens(
	canvas: CanvasItem,
	pillar_drawer: Object,
	center: Vector2,
	inner_radius: float,
	max_tokens: int,
	available_tokens: int,
	charge_progress: float,
	t: float,
	scale_factor: float,
	divider_anim_progress: float,
	start_angle_offset: float,
	sector_angle: float,
	context: Dictionary
) -> void:
	fill_renderer.draw_tokens(
		canvas,
		pillar_drawer,
		center,
		inner_radius,
		max_tokens,
		available_tokens,
		charge_progress,
		t,
		scale_factor,
		divider_anim_progress,
		start_angle_offset,
		sector_angle,
		context
	)


func draw_flash(canvas: CanvasItem, center: Vector2, radius: float, flash_progress: float, scale_factor: float, context: Dictionary = {}) -> void:
	flash_renderer.draw_flash(canvas, center, radius, flash_progress, scale_factor, float(context.get("hud_lod_scale", 1.0)))
