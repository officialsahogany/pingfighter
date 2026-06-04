extends RefCounted

const StageClearResultRewardIconResolver := preload("res://scripts/ui/stage_clear_result_reward_icon_resolver.gd")
const StageClearResultRewardTextResolver := preload("res://scripts/ui/stage_clear_result_reward_text_resolver.gd")
const StageClearResultRewardVisualResolver := preload("res://scripts/ui/stage_clear_result_reward_visual_resolver.gd")
const StageClearResultShapeHelper := preload("res://scripts/ui/stage_clear_result_shape_helper.gd")
const StageClearResultStarpointDrawHelper := preload("res://scripts/ui/stage_clear_result_starpoint_draw_helper.gd")
const StageClearResultTextLayoutHelper := preload("res://scripts/ui/stage_clear_result_text_layout_helper.gd")


static func draw_reward_label(
	canvas: CanvasItem,
	box: Dictionary,
	box_draw_center: Vector2,
	box_half_y: float,
	scale: float,
	global_alpha: float,
	timer: float,
	reward_hover_offset: float,
	reward_icon_cache: Dictionary
) -> void:
	if canvas == null:
		return
	var visual_state: Dictionary = StageClearResultRewardVisualResolver.get_reward_label_visual_state(
		box,
		box_draw_center,
		box_half_y,
		scale,
		global_alpha,
		timer,
		reward_hover_offset
	)
	if visual_state.is_empty():
		return
	var reward: Dictionary = visual_state.get("reward", {})
	var reward_type: String = str(visual_state.get("reward_type", ""))
	var anchor: Vector2 = visual_state.get("anchor", box_draw_center)
	var combined_alpha: float = float(visual_state.get("alpha", 0.0))
	var emerge_eased: float = float(visual_state.get("emerge_eased", 0.0))
	var phase: float = float(visual_state.get("phase", 0.0))

	if reward_type == "starpoint":
		draw_reward_starpoint(canvas, reward, anchor, scale, combined_alpha, emerge_eased, phase, timer)
	else:
		draw_reward_item_icon(canvas, reward, anchor, scale, combined_alpha, reward_icon_cache)


static func draw_reward_item_icon(
	canvas: CanvasItem,
	reward: Dictionary,
	anchor: Vector2,
	scale: float,
	alpha: float,
	reward_icon_cache: Dictionary
) -> void:
	if canvas == null:
		return
	var reward_type: String = str(reward.get("type", ""))
	var visual_state: Dictionary = StageClearResultRewardVisualResolver.get_reward_item_icon_visual_state(
		reward_type,
		anchor,
		scale,
		alpha
	)
	var disc_radius: float = float(visual_state.get("disc_radius", 60.0 * scale))
	var glow_color: Color = visual_state.get("glow_color", Color(0.85, 0.85, 0.92, 0.32 * alpha))
	StageClearResultShapeHelper.draw_radial_burst(canvas, anchor, disc_radius * 1.55, glow_color)

	var disc_fill: Color = visual_state.get("disc_fill", Color(0.18, 0.18, 0.24, 0.88 * alpha))
	canvas.draw_circle(anchor, disc_radius, disc_fill)

	canvas.draw_arc(
		anchor,
		disc_radius,
		0.0,
		TAU,
		40,
		visual_state.get("ring_color", Color(0.85, 0.85, 0.92, alpha)),
		float(visual_state.get("ring_width", max(2.0, 2.8 * scale)))
	)

	var texture: Texture2D = StageClearResultRewardIconResolver.get_reward_icon_texture(reward, reward_icon_cache)
	if texture != null:
		canvas.draw_texture_rect(texture, visual_state.get("icon_rect", Rect2()), false, Color(1.0, 1.0, 1.0, alpha))
	else:
		var fallback_label: String = str(reward.get("label", ""))
		if fallback_label == "":
			fallback_label = StageClearResultRewardTextResolver.get_reward_type_fallback_label(reward_type)
		var font: Font = ThemeDB.fallback_font
		var text_rect: Rect2 = visual_state.get("fallback_text_rect", Rect2())
		var font_size: int = StageClearResultTextLayoutHelper.fit_font_size(
			font,
			fallback_label,
			text_rect.size.x,
			int(visual_state.get("fallback_font_preferred_size", round(22.0 * scale))),
			int(visual_state.get("fallback_font_min_size", round(13.0 * scale)))
		)
		StageClearResultTextLayoutHelper.draw_centered_text(
			canvas,
			font,
			fallback_label,
			text_rect,
			font_size,
			visual_state.get("fallback_text_color", Color(1.0, 1.0, 1.0, alpha))
		)


static func draw_reward_starpoint(
	canvas: CanvasItem,
	reward: Dictionary,
	anchor: Vector2,
	scale: float,
	alpha: float,
	emerge_progress: float,
	phase: float,
	timer: float
) -> void:
	if canvas == null:
		return
	var visual_state: Dictionary = StageClearResultRewardVisualResolver.get_reward_starpoint_visual_state(
		int(reward.get("amount", 1)),
		anchor,
		scale,
		alpha,
		emerge_progress,
		timer,
		phase
	)
	StageClearResultStarpointDrawHelper.draw_ingame_starpoint_visual(canvas, visual_state, true)
