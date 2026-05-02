extends RefCounted

const Stage1PillarUiLayout := preload("res://scripts/hud/stage1_pillar_ui_layout.gd")
const Stage1PillarStatusOrbContextBuilder := preload("res://scripts/hud/stage1_pillar_status_orb_context_builder.gd")

var layout_helper: Object = Stage1PillarUiLayout.new()
var status_context_builder: Object = Stage1PillarStatusOrbContextBuilder.new()


func draw(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2, time_seconds: float, context: Dictionary) -> void:
	if canvas == null:
		return

	var layout: Dictionary = layout_helper.build_layout(game_offset, game_size, context)
	var scale_factor: float = float(layout["scale_factor"])
	var left_center: Vector2 = layout["left_center"]
	var right_center: Vector2 = layout["right_center"]
	var orb_radius: float = float(layout["orb_radius"])
	var orb_drawer: Object = context.get("pillar_drawer", null)
	var skill_orb_renderer: Object = context.get("skill_orb_renderer", null)
	var status_orb_renderer: Object = context.get("status_orb_renderer", null)
	var combo_renderer: Object = context.get("combo_renderer", null)

	var skill_orb_context: Dictionary = layout_helper.build_skill_orb_context(context, orb_drawer)
	if skill_orb_renderer != null:
		skill_orb_renderer.draw_underlay(canvas, left_center, orb_radius, scale_factor, skill_orb_context)

	if status_orb_renderer != null:
		status_orb_renderer.draw_gauge_orb(
			canvas,
			left_center,
			orb_radius,
			time_seconds,
			scale_factor,
			status_context_builder.build_gauge_orb_context(context, orb_drawer)
		)

	if skill_orb_renderer != null:
		skill_orb_renderer.draw_orbs(canvas, left_center, orb_radius, time_seconds, scale_factor, skill_orb_context)

	if status_orb_renderer != null:
		status_orb_renderer.draw_dash_orb(
			canvas,
			right_center,
			orb_radius,
			time_seconds,
			scale_factor,
			status_context_builder.build_dash_orb_context(context, orb_drawer)
		)

	if combo_renderer != null:
		var combo_rect: Rect2 = layout_helper.build_combo_rect(game_offset, left_center, scale_factor)
		combo_renderer.draw_hud(canvas, context.get("combo_state", null), combo_rect, scale_factor)
