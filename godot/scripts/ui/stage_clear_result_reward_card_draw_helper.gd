extends RefCounted

const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")
const StageClearResultRewardIconResolver := preload("res://scripts/ui/stage_clear_result_reward_icon_resolver.gd")
const StageClearResultSummaryBuilder := preload("res://scripts/ui/stage_clear_result_summary_builder.gd")
const StageClearResultRewardVisualResolver := preload("res://scripts/ui/stage_clear_result_reward_visual_resolver.gd")
const StageClearResultShapeHelper := preload("res://scripts/ui/stage_clear_result_shape_helper.gd")
const StageClearResultTextLayoutHelper := preload("res://scripts/ui/stage_clear_result_text_layout_helper.gd")


static func draw_reward_section_stack(
	canvas: CanvasItem,
	font: Font,
	sections: Array,
	rect: Rect2,
	scale: float,
	alpha: float,
	card_draw_callback: Callable
) -> void:
	if canvas == null or font == null:
		return
	var count: int = sections.size()
	if count <= 0:
		return
	var item_counts: Array = []
	for section_value in sections:
		var rewards_size: int = 0
		if section_value is Dictionary:
			var rewards_value: Variant = (section_value as Dictionary).get("rewards", [])
			if rewards_value is Array:
				rewards_size = (rewards_value as Array).size()
		item_counts.append(rewards_size)

	var layout: Dictionary = StageClearResultLayoutHelper.calculate_reward_band_stack_layout(item_counts, rect, scale)
	var label_col_w: float = float(layout.get("label_col_w", 240.0 * scale))
	var band_gap: float = float(layout.get("band_gap", 10.0 * scale))
	var band_height: float = float(layout.get("band_height", 0.0))
	var card_size: Vector2 = layout.get("card_size", Vector2(148.0, 112.0) * scale)
	var card_scale: float = float(layout.get("card_scale", scale))
	var card_gap: float = float(layout.get("card_gap", 16.0 * scale))
	var columns: int = max(1, int(layout.get("columns", 1)))
	var card_area_x: float = float(layout.get("card_area_x", rect.position.x + label_col_w))
	var start_y: float = float(layout.get("start_y", rect.position.y))

	var title_color := Color(0.05, 0.42, 0.52, alpha)
	var accent_color := Color(0.04, 0.78, 0.94, alpha)
	var divider_color := Color(0.05, 0.66, 0.84, alpha * 0.22)
	var label_font_size: int = max(13, int(round(22.0 * scale)))

	for i in range(count):
		var section_value2: Variant = sections[i]
		var section: Dictionary = section_value2 if section_value2 is Dictionary else {}
		var rewards_value2: Variant = section.get("rewards", [])
		var rewards: Array = rewards_value2 if rewards_value2 is Array else []
		var band_top: float = start_y + float(i) * (band_height + band_gap)
		if i > 0:
			var divider_y: float = band_top - band_gap * 0.5
			canvas.draw_line(
				Vector2(rect.position.x + 16.0 * scale, divider_y),
				Vector2(rect.end.x - 16.0 * scale, divider_y),
				divider_color,
				max(1.0, 1.2 * scale)
			)

		var accent_bar := Rect2(
			Vector2(rect.position.x + 6.0 * scale, band_top + (band_height - 24.0 * scale) * 0.5),
			Vector2(6.0 * scale, 24.0 * scale)
		)
		StageClearResultShapeHelper.draw_panel(canvas, accent_bar, accent_color, Color(0.0, 0.0, 0.0, 0.0), 0.0, 3.0 * scale)
		var label_rect := Rect2(
			Vector2(rect.position.x + 22.0 * scale, band_top),
			Vector2(max(1.0, label_col_w - 30.0 * scale), band_height)
		)
		StageClearResultTextLayoutHelper.draw_centered_text(
			canvas,
			font,
			"%s  %d" % [str(section.get("title", "")), rewards.size()],
			label_rect,
			label_font_size,
			title_color
		)

		var n: int = rewards.size()
		var rows: int = int(ceil(float(max(1, n)) / float(columns)))
		var grid_height: float = float(rows) * card_size.y + float(max(0, rows - 1)) * card_gap
		var grid_top: float = band_top + max(0.0, (band_height - grid_height) * 0.5)
		for j in range(n):
			var reward_value: Variant = rewards[j]
			if not (reward_value is Dictionary):
				continue
			var row: int = int(floor(float(j) / float(columns)))
			var col: int = j % columns
			var card_rect := Rect2(
				Vector2(
					card_area_x + float(col) * (card_size.x + card_gap),
					grid_top + float(row) * (card_size.y + card_gap)
				),
				card_size
			)
			card_draw_callback.call(font, reward_value, card_rect, card_scale, alpha)


static func draw_reward_card_shell(
	canvas: CanvasItem,
	font: Font,
	reward: Dictionary,
	rect: Rect2,
	scale: float,
	alpha: float,
	visual_state: Dictionary
) -> void:
	if canvas == null or font == null:
		return
	var border_color: Color = visual_state.get("border_color", Color(0.06, 0.84, 0.96, 0.78 * alpha))
	StageClearResultShapeHelper.draw_panel(
		canvas,
		rect,
		visual_state.get("base_color", Color(0.40, 0.32, 0.20, 0.18 * alpha)),
		border_color,
		float(visual_state.get("border_width", max(1.0, 1.6 * scale))),
		float(visual_state.get("corner_radius", 8.0 * scale))
	)
	var badge_rect: Rect2 = visual_state.get("badge_rect", Rect2())
	StageClearResultShapeHelper.draw_panel(
		canvas,
		badge_rect,
		visual_state.get("badge_fill", Color(0.02, 0.08, 0.11, 0.64 * alpha)),
		border_color,
		float(visual_state.get("badge_border_width", max(1.0, 1.0 * scale))),
		float(visual_state.get("badge_corner_radius", 6.0 * scale))
	)
	StageClearResultTextLayoutHelper.draw_centered_text(
		canvas,
		font,
		str(visual_state.get("badge_text", StageClearResultRewardVisualResolver.get_reward_badge(reward))),
		badge_rect,
		int(visual_state.get("badge_font_size", round(10.0 * scale))),
		visual_state.get("badge_text_color", Color(0.86, 1.0, 1.0, alpha))
	)


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


static func draw_reward_card_label(
	canvas: CanvasItem,
	font: Font,
	visual_state: Dictionary,
	reward_text_state: Dictionary,
	scale: float,
	alpha: float
) -> void:
	if canvas == null or font == null:
		return
	var label_rect: Rect2 = visual_state.get("label_rect", Rect2())
	StageClearResultShapeHelper.draw_panel(
		canvas,
		visual_state.get("label_plate_rect", label_rect),
		visual_state.get("label_plate_fill", Color(0.95, 0.99, 0.96, 0.44 * alpha)),
		Color(0.0, 0.0, 0.0, 0.0),
		0.0,
		5.0 * scale
	)
	var label: String = str(reward_text_state.get("title", ""))
	var label_size: int = StageClearResultTextLayoutHelper.fit_font_size(
		font,
		label,
		label_rect.size.x,
		int(visual_state.get("label_font_preferred_size", round(14.0 * scale))),
		int(visual_state.get("label_font_min_size", round(9.0 * scale)))
	)
	StageClearResultTextLayoutHelper.draw_centered_text(
		canvas,
		font,
		label,
		label_rect,
		label_size,
		visual_state.get("label_text_color", Color(0.04, 0.08, 0.10, alpha)),
		0.0
	)


static func draw_reward_card_icon(
	canvas: CanvasItem,
	reward: Dictionary,
	rect: Rect2,
	scale: float,
	alpha: float,
	timer: float,
	perk_icon_renderer: Variant,
	reward_icon_cache: Dictionary,
	starpoint_draw_callback: Callable
) -> void:
	if canvas == null:
		return
	var reward_type: String = str(reward.get("type", ""))
	if reward_type == "starpoint":
		var star_radius: float = max(8.0 * scale, min(rect.size.x, rect.size.y) * 0.22)
		var card_visual_state: Dictionary = StageClearResultRewardVisualResolver.get_reward_starpoint_visual_state(
			int(reward.get("amount", 1)),
			rect.get_center(),
			star_radius / 34.0,
			alpha,
			1.0,
			timer,
			0.0
		)
		card_visual_state["star_center"] = rect.get_center()
		card_visual_state["star_radius"] = star_radius
		card_visual_state["inner_radius"] = star_radius * 0.5
		starpoint_draw_callback.call(card_visual_state, false)
		return
	if StageClearResultSummaryBuilder.is_perk_reward(reward):
		var perk_id: String = StageClearResultSummaryBuilder.get_reward_perk_id(reward)
		if perk_icon_renderer != null and perk_icon_renderer.has_method("draw_icon") and bool(perk_icon_renderer.draw_icon(canvas, perk_id, rect, alpha, true)):
			return
	var texture: Texture2D = StageClearResultRewardIconResolver.get_reward_icon_texture(reward, reward_icon_cache)
	if texture != null:
		StageClearResultShapeHelper.draw_fitted_texture(canvas, texture, rect, alpha)
	else:
		var visual_state: Dictionary = StageClearResultRewardVisualResolver.get_fallback_reward_icon_visual_state(reward_type, rect, alpha)
		StageClearResultShapeHelper.draw_fallback_reward_icon(canvas, visual_state)
