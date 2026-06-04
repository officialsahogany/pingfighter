extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const StageClearResultRewardCardDrawHelper := preload("res://scripts/ui/stage_clear_result_reward_card_draw_helper.gd")
const StageClearResultScrollButtonDrawHelper := preload("res://scripts/ui/stage_clear_result_scroll_button_draw_helper.gd")
const StageClearResultScrollDrawHelper := preload("res://scripts/ui/stage_clear_result_scroll_draw_helper.gd")
const StageClearResultSummaryBuilder := preload("res://scripts/ui/stage_clear_result_summary_builder.gd")
const StageClearResultSummaryDrawHelper := preload("res://scripts/ui/stage_clear_result_summary_draw_helper.gd")
const StageClearResultTextLayoutHelper := preload("res://scripts/ui/stage_clear_result_text_layout_helper.gd")


static func draw_scroll_contents(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	scale: float,
	alpha: float,
	draw_context: Dictionary
) -> Dictionary:
	if canvas == null or alpha <= 0.02:
		return {}
	var accent := Color(0.05, 0.54, 0.68, alpha)
	var muted := Color(0.20, 0.36, 0.42, alpha * 0.86)
	var current_stage: int = int(draw_context.get("current_stage", 1))

	var header_rect := Rect2(rect.position, Vector2(rect.size.x, 58.0 * scale))
	StageClearResultTextLayoutHelper.draw_centered_text(
		canvas,
		font,
		LanguageSettings.format_stage_result_label(current_stage),
		header_rect,
		int(round(42.0 * scale)),
		accent
	)
	var divider_y: float = rect.position.y + 68.0 * scale
	canvas.draw_line(
		Vector2(rect.position.x + 34.0 * scale, divider_y),
		Vector2(rect.position.x + rect.size.x - 34.0 * scale, divider_y),
		Color(0.03, 0.82, 0.96, alpha * 0.46),
		max(1.0, 1.4 * scale)
	)

	var reward_summary_state: Dictionary = StageClearResultSummaryBuilder.build_result_summary_state(
		_get_dictionary(draw_context, "stage_reward_snapshot"),
		_get_array(draw_context, "boxes"),
		str(draw_context.get("result_reward_source_stage", "")),
		str(draw_context.get("result_reward_source_box", "")),
		_get_dictionary(draw_context, "result_reward_source_labels")
	)

	var strip_rect := Rect2(
		rect.position + Vector2(34.0 * scale, 86.0 * scale),
		Vector2(rect.size.x - 68.0 * scale, 80.0 * scale)
	)
	var runtime_perk_state: Object = draw_context.get("runtime_perk_state", null) as Object
	var display_gold: int = StageClearResultSummaryBuilder.resolve_display_gold(
		runtime_perk_state,
		int(draw_context.get("placeholder_gold", 0))
	)
	var player_score: int = int(draw_context.get("player_score", 0))
	var boss_score: int = int(draw_context.get("boss_score", 0))
	var rating: int = StageClearResultSummaryBuilder.calculate_score_rating(player_score, boss_score)
	StageClearResultSummaryDrawHelper.draw_result_summary_strip(
		canvas,
		font,
		strip_rect,
		scale,
		alpha,
		display_gold,
		player_score,
		boss_score,
		rating,
		LanguageSettings.translate_text("획득 골드"),
		LanguageSettings.translate_text("최종 스코어"),
		LanguageSettings.translate_text("평가")
	)

	var perks: Array = _get_summary_array(reward_summary_state, "perk_rewards")
	var item_rewards: Array = _get_summary_array(reward_summary_state, "item_rewards")
	var sections: Array = _build_reward_sections(perks, item_rewards)

	var section_top: float = rect.position.y + 188.0 * scale
	var button_top: float = rect.position.y + rect.size.y - 90.0 * scale
	var section_bottom: float = button_top - 22.0 * scale
	var body_rect := Rect2(
		Vector2(rect.position.x + 34.0 * scale, section_top),
		Vector2(rect.size.x - 68.0 * scale, max(150.0 * scale, section_bottom - section_top))
	)
	StageClearResultScrollDrawHelper.draw_section_group_panel(canvas, body_rect, scale, alpha)
	if sections.is_empty():
		StageClearResultTextLayoutHelper.draw_centered_text(
			canvas,
			font,
			LanguageSettings.translate_text("획득 보상 없음"),
			body_rect,
			int(round(22.0 * scale)),
			muted
		)
	else:
		StageClearResultRewardCardDrawHelper.draw_reward_section_stack(
			canvas,
			font,
			sections,
			body_rect,
			scale,
			alpha,
			Callable(),
			{
				"timer": float(draw_context.get("timer", 0.0)),
				"perk_catalog": draw_context.get("perk_catalog", null),
				"perk_icon_renderer": draw_context.get("perk_icon_renderer", null),
				"reward_icon_cache": _get_dictionary(draw_context, "reward_icon_cache"),
				"result_reward_source_stage": str(draw_context.get("result_reward_source_stage", "")),
				"result_reward_source_box": str(draw_context.get("result_reward_source_box", "")),
				"result_reward_source_labels": _get_dictionary(draw_context, "result_reward_source_labels"),
				"reward_detail_fallback_text": str(draw_context.get("reward_detail_fallback_text", "")),
				"reward_starpoint_title_prefix": str(draw_context.get("reward_starpoint_title_prefix", "")),
			}
		)

	return StageClearResultScrollButtonDrawHelper.draw_scroll_buttons(
		canvas,
		font,
		rect,
		scale,
		alpha,
		str(draw_context.get("scroll_phase", "")),
		str(draw_context.get("hovered_button", "")),
		LanguageSettings.translate_text("다음 스테이지"),
		LanguageSettings.translate_text("나가기")
	)


static func _build_reward_sections(perks: Array, item_rewards: Array) -> Array:
	var item_groups: Dictionary = StageClearResultSummaryBuilder.split_item_rewards_by_type(item_rewards)
	var active_items: Array = _get_summary_array(item_groups, "active_items")
	var passive_items: Array = _get_summary_array(item_groups, "passive_items")
	var mythic_items: Array = _get_summary_array(item_groups, "mythic_items")
	var sections: Array = []
	if not perks.is_empty():
		sections.append({"title": LanguageSettings.translate_text("획득 퍽"), "rewards": perks})
	if not active_items.is_empty():
		sections.append({"title": LanguageSettings.translate_text("액티브 아이템"), "rewards": active_items})
	if not passive_items.is_empty():
		sections.append({"title": LanguageSettings.translate_text("패시브 아이템"), "rewards": passive_items})
	if not mythic_items.is_empty():
		sections.append({"title": LanguageSettings.translate_text("신화 아이템"), "rewards": mythic_items})
	return sections


static func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


static func _get_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	if value is Array:
		return value
	return []


static func _get_summary_array(summary_state: Dictionary, key: String) -> Array:
	var value: Variant = summary_state.get(key, [])
	if value is Array:
		return value
	return []
