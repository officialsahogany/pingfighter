extends RefCounted

const StageClearResultInteractionState := preload("res://scripts/ui/stage_clear_result_interaction_state.gd")
const StageClearResultShapeHelper := preload("res://scripts/ui/stage_clear_result_shape_helper.gd")
const StageClearResultTextLayoutHelper := preload("res://scripts/ui/stage_clear_result_text_layout_helper.gd")


static func draw_scroll_buttons(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	scale: float,
	alpha: float,
	scroll_phase: String,
	hovered_button: String,
	next_label: String,
	exit_label: String
) -> Dictionary:
	var button_layout: Dictionary = StageClearResultInteractionState.get_scroll_button_layout(rect, scale)
	if canvas == null or font == null:
		return button_layout
	var next_rect: Rect2 = button_layout.get("next_stage_rect", Rect2())
	var exit_rect: Rect2 = button_layout.get("exit_rect", Rect2())
	var clickable: bool = scroll_phase == "visible"

	var next_hovered: bool = clickable and hovered_button == "next_stage"
	var next_fill := Color(0.02, 0.78, 0.88, alpha * 0.86)
	var next_border := Color(0.72, 1.0, 1.0, alpha * 0.95)
	if next_hovered:
		next_fill = next_fill.lerp(Color(1.0, 1.0, 1.0, alpha), 0.20)
		next_border = Color(0.92, 1.0, 1.0, alpha)
	StageClearResultShapeHelper.draw_panel(canvas, next_rect, next_fill, next_border, max(1.5, 2.4 * scale), 14.0 * scale)
	StageClearResultTextLayoutHelper.draw_centered_text(
		canvas,
		font,
		next_label,
		next_rect,
		int(round(26.0 * scale)),
		Color(0.02, 0.06, 0.08, alpha)
	)

	var exit_hovered: bool = clickable and hovered_button == "exit"
	var exit_fill := Color(0.06, 0.07, 0.12, alpha * 0.92)
	var exit_border := Color(0.82, 0.28, 0.86, alpha * 0.82)
	var exit_text_color := Color(0.88, 0.98, 1.0, alpha)
	if exit_hovered:
		exit_fill = exit_fill.lerp(Color(0.22, 0.08, 0.28, alpha), 0.32)
		exit_border = Color(1.0, 0.48, 0.96, alpha)
		exit_text_color = Color(1.0, 0.96, 1.0, alpha)
	StageClearResultShapeHelper.draw_panel(canvas, exit_rect, exit_fill, exit_border, max(1.5, 2.0 * scale), 14.0 * scale)
	StageClearResultTextLayoutHelper.draw_centered_text(
		canvas,
		font,
		exit_label,
		exit_rect,
		int(round(26.0 * scale)),
		exit_text_color
	)
	return button_layout
