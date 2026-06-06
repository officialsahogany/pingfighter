extends RefCounted

const StageClearResultBoxDrawHelper := preload("res://scripts/ui/stage_clear_result_box_draw_helper.gd")
const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")


static func get_floating_box_draw_context(
	timer: float,
	scroll_phase: String,
	scroll_timer: float,
	hovered_box_index: int,
	result_box_sheet_common: Texture2D,
	result_box_sheet_mythic: Texture2D,
	result_box_sheet_guaranteed_mythic: Texture2D,
	reward_icon_cache: Dictionary
) -> Dictionary:
	return {
		"timer": timer,
		"scroll_phase": scroll_phase,
		"scroll_timer": scroll_timer,
		"hovered_box_index": hovered_box_index,
		"result_box_sheet_common": result_box_sheet_common,
		"result_box_sheet_mythic": result_box_sheet_mythic,
		"result_box_sheet_guaranteed_mythic": result_box_sheet_guaranteed_mythic,
		"reward_icon_cache": reward_icon_cache,
	}


static func draw_floating_boxes(
	canvas: CanvasItem,
	boxes: Array,
	draw_scale: float,
	draw_context: Dictionary
) -> void:
	if boxes.is_empty():
		return
	var hovered_box_index: int = int(draw_context.get("hovered_box_index", -1))
	for i in range(boxes.size()):
		var box: Dictionary = boxes[i] if boxes[i] is Dictionary else {}
		StageClearResultBoxDrawHelper.draw_floating_result_box(
			canvas,
			box,
			StageClearResultBoxDrawHelper.build_floating_result_box_draw_context(
				box,
				i == hovered_box_index,
				draw_scale,
				float(draw_context.get("timer", 0.0)),
				str(draw_context.get("scroll_phase", StageClearResultScrollState.PHASE_HIDDEN)),
				float(draw_context.get("scroll_timer", 0.0)),
				StageClearResultScrollState.SCROLL_UNFURL_DURATION,
				draw_context.get("result_box_sheet_common", null) as Texture2D,
				draw_context.get("result_box_sheet_mythic", null) as Texture2D,
				draw_context.get("result_box_sheet_guaranteed_mythic", null) as Texture2D,
				draw_context.get("reward_icon_cache", {})
			)
		)
