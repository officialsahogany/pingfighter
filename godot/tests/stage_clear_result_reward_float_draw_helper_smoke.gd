extends SceneTree

const StageClearResultRewardFloatDrawHelper := preload("res://scripts/ui/stage_clear_result_reward_float_draw_helper.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_helper_source()
	_verify_scene_delegates_reward_float_draw()

	if _failures.is_empty():
		print("stage_clear_result_reward_float_draw_helper_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_reward_float_draw_helper.gd")
	_expect(source.find("static func draw_reward_label") >= 0, "reward float draw helper should own floating reward label routing")
	_expect(source.find("static func draw_reward_item_icon") >= 0, "reward float draw helper should own floating reward item icon drawing")
	_expect(source.find("static func draw_reward_starpoint") >= 0, "reward float draw helper should own floating starpoint visual-state dispatch")
	_expect(source.find("StageClearResultRewardVisualResolver.get_reward_label_visual_state") >= 0, "floating label drawing should use the visual resolver")
	_expect(source.find("StageClearResultRewardIconResolver.get_reward_icon_texture") >= 0, "floating icon drawing should resolve reward icon textures")
	_expect(source.find("StageClearResultRewardTextResolver.get_reward_type_fallback_label") >= 0, "floating icon drawing should use reward fallback labels")
	_expect(source.find("StageClearResultStarpointDrawHelper.draw_ingame_starpoint_visual") >= 0, "floating starpoint drawing should delegate the primitive star draw")
	_expect(StageClearResultRewardFloatDrawHelper != null, "reward float draw helper preload should resolve")

	StageClearResultRewardFloatDrawHelper.draw_reward_label(
		null,
		{},
		Vector2.ZERO,
		10.0,
		1.0,
		1.0,
		0.0,
		72.0,
		{}
	)


func _verify_scene_delegates_reward_float_draw() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var box_draw_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_draw_helper.gd")
	_expect(box_draw_source.find("StageClearResultRewardFloatDrawHelper.draw_reward_label") >= 0, "box draw helper should delegate floating reward label drawing")
	_expect(source.find("func _draw_reward_label") < 0, "result scene should not keep floating reward label wrappers")
	_expect(source.find("func _draw_reward_item_icon") < 0, "result scene should not keep floating reward icon wrappers")
	_expect(source.find("func _draw_reward_starpoint") < 0, "result scene should not keep floating starpoint routing wrappers")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
