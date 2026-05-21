extends SceneTree

const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_box_layout()
	_verify_box_frame_policy()
	_verify_reward_section_layout()
	_verify_source_rects()
	_verify_scene_wrappers()

	if _failures.is_empty():
		print("stage_clear_result_layout_helper_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_box_layout() -> void:
	_expect(StageClearResultLayoutHelper.get_box_layout(0).is_empty(), "box layout should ignore unsupported counts")
	var three_box_layout: Array = StageClearResultLayoutHelper.get_box_layout(3)
	_expect(three_box_layout.size() == 3, "box layout should expose three slots")
	_expect(Vector2((three_box_layout[0] as Dictionary).get("pos", Vector2.ZERO)) == Vector2(820.0, 300.0), "three-box layout should preserve the first anchor")


func _verify_box_frame_policy() -> void:
	_expect(
		StageClearResultLayoutHelper.get_result_box_frame_index("idle", 0.5, false, 16, 12, 15) == 0,
		"idle result boxes should use frame 0"
	)
	_expect(
		StageClearResultLayoutHelper.get_result_box_frame_index("opening", 0.98, false, 16, 12, 15) == 12,
		"common result boxes should clamp late opening frames to the safe lid frame"
	)
	_expect(
		StageClearResultLayoutHelper.get_result_box_frame_index("opened", 1.0, true, 16, 12, 15) == 15,
		"mythic result boxes should use the full final frame"
	)


func _verify_reward_section_layout() -> void:
	var dense_section_rect := Rect2(Vector2.ZERO, Vector2(538.0, 276.0))
	var layout: Dictionary = StageClearResultLayoutHelper.calculate_reward_section_layout(7, dense_section_rect, 1.0)
	var card_size: Vector2 = layout.get("card_size", Vector2.ZERO)
	var card_scale: float = float(layout.get("card_scale", 1.0))
	var gap: float = float(layout.get("gap", 0.0))
	var rows: int = int(layout.get("rows", 0))
	_expect(rows == 2, "dense reward grid should stay on two rows")
	_expect(card_scale < 1.0, "dense reward grid should shrink card internals")
	_expect((84.0 + 22.0) * card_scale <= card_size.y + 0.5, "dense reward labels should stay inside cards")
	_expect(card_size.y + gap > 0.0, "dense reward row stride should remain positive")
	_expect(
		StageClearResultLayoutHelper.get_reward_section_columns(538.0, 148.0, 16.0, 4) == 3,
		"reward column calculation should preserve the fitted base count"
	)


func _verify_source_rects() -> void:
	var source: Rect2 = StageClearResultLayoutHelper.sheet_source_rect(15, 4, Vector2(256.0, 256.0))
	_expect(source.position == Vector2(768.0, 768.0), "sheet source rect should resolve frame columns and rows")
	_expect(source.size == Vector2(256.0, 256.0), "sheet source rect should preserve cell size")
	var cover: Rect2 = StageClearResultLayoutHelper.cover_source_rect(Vector2(400.0, 200.0), Vector2(100.0, 100.0))
	_expect(cover.position == Vector2(100.0, 0.0), "cover source rect should crop wide textures horizontally")
	_expect(cover.size == Vector2(200.0, 200.0), "cover source rect should fit the target ratio")


func _verify_scene_wrappers() -> void:
	var scene := StageClearResultScene.new()
	_expect(scene._get_box_layout(2).size() == 2, "scene box-layout wrapper should delegate")
	_expect(scene._get_result_box_frame_index("opened", 1.0, false) == 12, "scene box-frame wrapper should delegate")
	_expect(int(scene._calculate_reward_section_layout(7, Rect2(Vector2.ZERO, Vector2(538.0, 276.0)), 1.0).get("rows", 0)) == 2, "scene reward-layout wrapper should delegate")
	_expect(scene._sheet_source_rect(15, 4, Vector2(256.0, 256.0)).position == Vector2(768.0, 768.0), "scene sheet-rect wrapper should delegate")
	scene.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
