extends RefCounted

const StageClearResultClickReactionState := preload("res://scripts/ui/stage_clear_result_click_reaction_state.gd")
const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")
const StageClearResultScrollContentDrawHelper := preload("res://scripts/ui/stage_clear_result_scroll_content_draw_helper.gd")
const StageClearResultScrollDrawHelper := preload("res://scripts/ui/stage_clear_result_scroll_draw_helper.gd")
const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")

const CONTENT_REVEAL_START := 0.58
const CONTENT_REVEAL_RANGE := 0.42


static func get_scroll_draw_context(
	current_stage: int,
	stage_reward_snapshot: Dictionary,
	boxes: Array,
	runtime_perk_state: Object,
	player_score: int,
	boss_score: int,
	timer: float,
	perk_catalog: Object,
	perk_icon_renderer: Object,
	reward_icon_cache: Dictionary,
	scroll_phase: String,
	scroll_timer: float,
	scroll_position_offset: Vector2,
	hovered_button: String
) -> Dictionary:
	return {
		"current_stage": current_stage,
		"stage_reward_snapshot": stage_reward_snapshot,
		"boxes": boxes,
		"runtime_perk_state": runtime_perk_state,
		"player_score": player_score,
		"boss_score": boss_score,
		"timer": timer,
		"perk_catalog": perk_catalog,
		"perk_icon_renderer": perk_icon_renderer,
		"reward_icon_cache": reward_icon_cache,
		"scroll_phase": scroll_phase,
		"scroll_timer": scroll_timer,
		"scroll_position_offset": scroll_position_offset,
		"hovered_button": hovered_button,
	}


static func draw_scroll(
	canvas: CanvasItem,
	font: Font,
	view_size: Vector2,
	draw_scale: float,
	scroll_texture: Texture2D,
	draw_context: Dictionary
) -> Dictionary:
	var scroll_phase: String = str(draw_context.get("scroll_phase", "hidden"))
	var position_offset: Vector2 = draw_context.get("scroll_position_offset", Vector2.ZERO)
	var result: Dictionary = _empty_result(position_offset)
	if scroll_phase == StageClearResultScrollState.PHASE_HIDDEN:
		return result

	position_offset = StageClearResultScrollState.clamp_region_offset(position_offset, draw_scale, view_size)
	result["scroll_position_offset"] = position_offset
	var scroll_timer: float = float(draw_context.get("scroll_timer", 0.0))
	var unfurl: float = StageClearResultScrollState.get_unfurl_progress(
		scroll_phase,
		scroll_timer,
		StageClearResultScrollState.SCROLL_UNFURL_DURATION
	)
	result["unfurl"] = unfurl
	if unfurl <= 0.0:
		return result

	var full_rect: Rect2 = StageClearResultScrollState.get_region_full_rect(draw_scale, position_offset)
	var visible_rect := Rect2(full_rect.position, Vector2(full_rect.size.x, full_rect.size.y * unfurl))
	result["drawn"] = true
	result["full_rect"] = full_rect
	result["visible_rect"] = visible_rect
	StageClearResultScrollDrawHelper.draw_cyber_scroll_frame(
		canvas,
		scroll_texture,
		full_rect,
		visible_rect,
		draw_scale,
		unfurl
	)
	if unfurl <= CONTENT_REVEAL_START:
		return result

	var content_alpha: float = StageClearResultClickReactionState.smooth01((unfurl - CONTENT_REVEAL_START) / CONTENT_REVEAL_RANGE)
	var content_rect: Rect2 = StageClearResultLayoutHelper.get_scroll_content_rect(
		full_rect,
		draw_scale,
		StageClearResultScrollState.SCROLL_CONTENT_MARGIN
	)
	result["content_alpha"] = content_alpha
	result["content_rect"] = content_rect
	var button_layout: Dictionary = StageClearResultScrollContentDrawHelper.draw_scroll_contents(
		canvas,
		font,
		content_rect,
		draw_scale,
		content_alpha,
		draw_context
	)
	if button_layout.is_empty():
		return result
	result["next_stage_rect"] = button_layout.get("next_stage_rect", Rect2())
	result["exit_rect"] = button_layout.get("exit_rect", Rect2())
	result["content_drawn"] = true
	return result


static func get_scroll_draw_apply_result(
	draw_result: Dictionary,
	current_position_offset: Vector2
) -> Dictionary:
	return {
		"scroll_position_offset": draw_result.get("scroll_position_offset", current_position_offset),
		"next_stage_rect": draw_result.get("next_stage_rect", Rect2()),
		"exit_rect": draw_result.get("exit_rect", Rect2()),
	}


static func _empty_result(position_offset: Vector2) -> Dictionary:
	return {
		"drawn": false,
		"content_drawn": false,
		"scroll_position_offset": position_offset,
		"next_stage_rect": Rect2(),
		"exit_rect": Rect2(),
		"unfurl": 0.0,
	}
