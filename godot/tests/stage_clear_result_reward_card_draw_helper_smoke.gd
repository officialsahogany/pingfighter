extends SceneTree

const StageClearResultRewardCardDrawHelper := preload("res://scripts/ui/stage_clear_result_reward_card_draw_helper.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_helper_source()
	_verify_scene_delegates_reward_card_draw()

	if _failures.is_empty():
		print("stage_clear_result_reward_card_draw_helper_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_reward_card_draw_helper.gd")
	_expect(source.find("static func draw_reward_section_stack") >= 0, "reward card draw helper should own reward section-stack drawing")
	_expect(source.find("StageClearResultLayoutHelper.calculate_reward_band_stack_layout") >= 0, "reward section-stack drawing should use the layout helper")
	_expect(source.find("card_draw_callback.call") >= 0, "reward section-stack drawing should delegate card body drawing through a callback")
	_expect(source.find("static func draw_reward_card_shell") >= 0, "reward card draw helper should own card shell drawing")
	_expect(source.find("static func draw_reward_source_chip") >= 0, "reward card draw helper should own source-chip drawing")
	_expect(source.find("static func draw_reward_card_label") >= 0, "reward card draw helper should own card label drawing")
	_expect(source.find("static func draw_reward_card_icon") >= 0, "reward card draw helper should own card icon drawing")
	_expect(source.find("StageClearResultRewardVisualResolver.get_result_reward_source_label") >= 0, "source-chip drawing should resolve missing source labels")
	_expect(source.find("StageClearResultRewardVisualResolver.get_reward_source_chip_visual_state") >= 0, "source-chip drawing should use the visual resolver")
	_expect(source.find("StageClearResultRewardVisualResolver.get_reward_badge") >= 0, "card shell drawing should use the badge resolver fallback")
	_expect(source.find("StageClearResultRewardIconResolver.get_reward_icon_texture") >= 0, "card icon drawing should use the reward icon resolver")
	_expect(source.find("StageClearResultSummaryBuilder.is_perk_reward") >= 0, "card icon drawing should route perk rewards through the perk icon renderer")
	_expect(source.find("starpoint_draw_callback.call") >= 0, "card icon drawing should delegate starpoint drawing through a callback")
	_expect(source.find("StageClearResultShapeHelper.draw_panel") >= 0, "source-chip drawing should delegate panel drawing")
	_expect(source.find("StageClearResultTextLayoutHelper.draw_centered_text") >= 0, "source-chip drawing should delegate text drawing")
	_expect(source.find("StageClearResultTextLayoutHelper.fit_font_size") >= 0, "card label drawing should fit long reward names")
	_expect(StageClearResultRewardCardDrawHelper != null, "reward card draw helper preload should resolve")


func _verify_scene_delegates_reward_card_draw() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(source.find("StageClearResultRewardCardDrawHelper.draw_reward_section_stack") >= 0, "result scene should delegate reward section-stack drawing")
	_expect(source.find("StageClearResultRewardCardDrawHelper.draw_reward_card_shell") >= 0, "result scene should delegate reward card shell drawing")
	_expect(source.find("StageClearResultRewardCardDrawHelper.draw_reward_source_chip") >= 0, "result scene should delegate reward source-chip drawing")
	_expect(source.find("StageClearResultRewardCardDrawHelper.draw_reward_card_label") >= 0, "result scene should delegate reward card label drawing")
	_expect(source.find("StageClearResultRewardCardDrawHelper.draw_reward_card_icon") >= 0, "result scene should delegate reward card icon drawing")
	_expect(source.find("func _draw_reward_section_stack") < 0, "result scene should not keep reward section-stack drawing wrappers")
	_expect(source.find("func _draw_reward_source_chip") < 0, "result scene should not keep source-chip drawing wrappers")
	_expect(source.find("func _draw_reward_card_icon") < 0, "result scene should not keep reward card icon drawing wrappers")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
