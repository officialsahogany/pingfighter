extends RefCounted

const StageClearResultRewardVisualResolver := preload("res://scripts/ui/stage_clear_result_reward_visual_resolver.gd")
const StageClearResultShapeHelper := preload("res://scripts/ui/stage_clear_result_shape_helper.gd")
const StageClearResultTextLayoutHelper := preload("res://scripts/ui/stage_clear_result_text_layout_helper.gd")


static func draw_reward_source_chip(
	canvas: CanvasItem,
	font: Font,
	reward: Dictionary,
	rect: Rect2,
	scale: float,
	alpha: float,
	result_reward_source_stage: String,
	result_reward_source_box: String,
	result_reward_source_labels: Dictionary
) -> void:
	if canvas == null or font == null:
		return
	var source_key: String = str(reward.get("_result_reward_source", ""))
	var source_label: String = str(reward.get("_result_reward_source_label", ""))
	if source_label == "":
		source_label = StageClearResultRewardVisualResolver.get_result_reward_source_label(
			source_key,
			result_reward_source_stage,
			result_reward_source_box,
			str(result_reward_source_labels.get(result_reward_source_stage, "")),
			str(result_reward_source_labels.get(result_reward_source_box, ""))
		)
	var visual_state: Dictionary = StageClearResultRewardVisualResolver.get_reward_source_chip_visual_state(
		source_key,
		source_label,
		rect,
		scale,
		alpha,
		result_reward_source_stage,
		result_reward_source_box
	)
	if visual_state.is_empty():
		return
	var chip_rect: Rect2 = visual_state.get("rect", Rect2())
	StageClearResultShapeHelper.draw_panel(
		canvas,
		chip_rect,
		visual_state.get("fill", Color(0.18, 0.24, 0.28, 0.72 * alpha)),
		visual_state.get("border", Color(0.86, 1.0, 1.0, 0.76 * alpha)),
		float(visual_state.get("border_width", max(1.0, 1.0 * scale))),
		float(visual_state.get("corner_radius", 6.0 * scale))
	)
	var font_size: int = StageClearResultTextLayoutHelper.fit_font_size(
		font,
		source_label,
		chip_rect.size.x - 6.0 * scale,
		int(visual_state.get("font_preferred_size", round(10.0 * scale))),
		int(visual_state.get("font_min_size", round(7.0 * scale)))
	)
	StageClearResultTextLayoutHelper.draw_centered_text(
		canvas,
		font,
		source_label,
		chip_rect,
		font_size,
		visual_state.get("text_color", Color(0.92, 1.0, 1.0, alpha)),
		0.0
	)
