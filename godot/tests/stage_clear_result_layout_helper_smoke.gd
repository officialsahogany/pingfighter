extends SceneTree

const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_box_layout()
	_verify_box_frame_policy()
	_verify_box_geometry()
	_verify_actor_and_scroll_rects()
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


func _verify_box_geometry() -> void:
	var box := {
		"base_pos": Vector2(10.0, 20.0),
		"phase": 0.0,
		"amplitude": 4.0,
		"speed": 1.0,
	}
	var resting_center: Vector2 = StageClearResultLayoutHelper.get_box_draw_center(box, 2.0, 0.0, 4.0, 1.0)
	_expect(resting_center == Vector2(20.0, 40.0), "box draw center should scale the base position")
	var lifted_center: Vector2 = StageClearResultLayoutHelper.get_box_draw_center(box, 2.0, PI * 0.5, 4.0, 1.0)
	_expect(lifted_center.is_equal_approx(Vector2(20.0, 48.0)), "box draw center should apply timer-driven bobbing before scaling")
	var aabb: Rect2 = StageClearResultLayoutHelper.get_box_aabb(
		box,
		2.0,
		0.0,
		Vector2(100.0, 80.0),
		1.2,
		4.0,
		1.0
	)
	_expect(aabb.position.is_equal_approx(Vector2(-112.0, -65.6)), "box aabb should use the floated center and hover grow")
	_expect(aabb.size.is_equal_approx(Vector2(264.0, 211.2)), "box aabb should preserve the expanded box footprint")
	var rotated: Vector2 = StageClearResultLayoutHelper.rotate_around(Vector2(2.0, 1.0), Vector2(1.0, 1.0), PI * 0.5)
	_expect(rotated.is_equal_approx(Vector2(1.0, 2.0)), "rotate_around should rotate points around the supplied center")


func _verify_actor_and_scroll_rects() -> void:
	var view_size := Vector2(1920.0, 1080.0)
	var actor_rect: Rect2 = StageClearResultLayoutHelper.get_player_victory_actor_rect(view_size, 1.0)
	_expect(actor_rect.position == Vector2(1270.0, 213.0), "player victory actor rect should preserve the right-side anchor")
	_expect(actor_rect.size == Vector2(760.0, 760.0), "player victory actor rect should preserve source-sized layout")
	var click_rect: Rect2 = StageClearResultLayoutHelper.get_player_victory_click_rect(view_size, 1.0, Vector2(1408.0, 1408.0))
	_expect(click_rect.position.is_equal_approx(Vector2(1399.54541015625, 266.9772644042969)), "player victory click rect should map the source-frame hot zone")
	_expect(click_rect.end.x <= view_size.x, "player victory click rect should clip to the viewport")
	var panel_rect: Rect2 = StageClearResultLayoutHelper.get_player_victory_panel_rect(view_size, 1.0)
	_expect(panel_rect == Rect2(Vector2(1425.0, 190.0), Vector2(410.0, 750.0)), "player victory panel rect should keep its anchor")
	var local_position: Vector2 = StageClearResultLayoutHelper.screen_to_acquisition_cinematic_local(
		Vector2(600.0, 200.0),
		view_size,
		Vector2(760.0, 750.0)
	)
	_expect(local_position == Vector2(20.0, 35.0), "cinematic local conversion should subtract the centered field origin")
	var content_rect: Rect2 = StageClearResultLayoutHelper.get_scroll_content_rect(
		Rect2(Vector2(100.0, 200.0), Vector2(400.0, 300.0)),
		1.0,
		Vector4(70.0, 90.0, 70.0, 76.0)
	)
	_expect(content_rect == Rect2(Vector2(170.0, 290.0), Vector2(260.0, 134.0)), "scroll content rect should apply scaled margins")
	_expect(
		StageClearResultLayoutHelper.get_dalji_draw_rect(view_size, 1.0) == Rect2(Vector2(-16.0, 471.0), Vector2(624.0, 624.0)),
		"Dalji draw rect should use the desktop layout"
	)
	_expect(
		StageClearResultLayoutHelper.get_dalji_draw_rect(Vector2(1200.0, 800.0), 1.0) == Rect2(Vector2(-16.0, 480.0), Vector2(520.0, 520.0)),
		"Dalji draw rect should use the compact layout for narrow views"
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
	scene.timer = 0.0
	var wrapper_box := {"base_pos": Vector2(10.0, 20.0), "phase": 0.0, "amplitude": 4.0, "speed": 1.0}
	_expect(scene._get_box_draw_center(wrapper_box, 2.0) == Vector2(20.0, 40.0), "scene box-center wrapper should delegate")
	_expect(scene._get_box_aabb(wrapper_box, 2.0).has_point(Vector2(20.0, 40.0)), "scene box-aabb wrapper should delegate")
	_expect(scene._rotate_around(Vector2(2.0, 1.0), Vector2(1.0, 1.0), PI * 0.5).is_equal_approx(Vector2(1.0, 2.0)), "scene rotation wrapper should delegate")
	_expect(scene._get_player_victory_actor_rect(Vector2(1920.0, 1080.0), 1.0).position == Vector2(1270.0, 213.0), "scene player-victory actor wrapper should delegate")
	_expect(scene._get_player_victory_panel_rect(Vector2(1920.0, 1080.0), 1.0).size == Vector2(410.0, 750.0), "scene player-victory panel wrapper should delegate")
	_expect(scene._get_scroll_content_rect(Rect2(Vector2(100.0, 200.0), Vector2(400.0, 300.0)), 1.0).position == Vector2(170.0, 290.0), "scene scroll-content wrapper should delegate")
	_expect(scene._get_dalji_draw_rect(Vector2(1920.0, 1080.0), 1.0).size == Vector2(624.0, 624.0), "scene Dalji draw-rect wrapper should delegate")
	_expect(int(scene._calculate_reward_section_layout(7, Rect2(Vector2.ZERO, Vector2(538.0, 276.0)), 1.0).get("rows", 0)) == 2, "scene reward-layout wrapper should delegate")
	_expect(scene._sheet_source_rect(15, 4, Vector2(256.0, 256.0)).position == Vector2(768.0, 768.0), "scene sheet-rect wrapper should delegate")
	scene.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
