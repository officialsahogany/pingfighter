extends SceneTree

const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")

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
	var five_box_layout: Array = StageClearResultLayoutHelper.get_box_layout(5)
	_expect(five_box_layout.size() == 5, "box layout should expose five slots for 5:0 normal rewards")
	_expect(Vector2((five_box_layout[4] as Dictionary).get("pos", Vector2.ZERO)) == Vector2(1130.0, 610.0), "five-box layout should preserve the lower-right anchor")


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
		"advanced result boxes should use the full final frame"
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
	_expect(
		StageClearResultLayoutHelper.get_stage2_boss_result_draw_rect(view_size, 1.0) == Rect2(Vector2(-6.4, 602.8), Vector2(634.8, 469.2)),
		"Stage 2 boss result draw rect should use the widened and shortened desktop layout"
	)
	_expect(
		StageClearResultLayoutHelper.get_stage2_boss_result_draw_rect(Vector2(1200.0, 800.0), 1.0) == Rect2(Vector2(-1.6, 611.2), Vector2(515.2, 380.8)),
		"Stage 2 boss result draw rect should use the widened and shortened compact layout"
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

	# header_reserve = 0 lets the card use the whole band height (left-label bands).
	var no_header_layout: Dictionary = StageClearResultLayoutHelper.calculate_reward_section_layout(
		1, Rect2(Vector2.ZERO, Vector2(760.0, 112.0)), 1.0, 0.0
	)
	var default_header_layout: Dictionary = StageClearResultLayoutHelper.calculate_reward_section_layout(
		1, Rect2(Vector2.ZERO, Vector2(760.0, 112.0)), 1.0
	)
	_expect(
		float(no_header_layout.get("card_scale", 0.0)) > float(default_header_layout.get("card_scale", 0.0)),
		"dropping the header reserve should let the card grow taller in the same rect"
	)

	# Four stacked bands in the result body keep one uniform, readable card size.
	var body_rect := Rect2(Vector2(34.0, 188.0), Vector2(1032.0, 438.0))
	var stack: Dictionary = StageClearResultLayoutHelper.calculate_reward_band_stack_layout([2, 1, 1, 1], body_rect, 1.0)
	_expect(int(stack.get("count", 0)) == 4, "band stack should expose one band per non-empty category")
	var stack_card: Vector2 = stack.get("card_size", Vector2.ZERO)
	_expect(stack_card.y >= 80.0, "four stacked bands should still leave the cards larger than the old top-header grid (~63px)")
	_expect(stack_card.y <= 112.0 + 0.5, "stacked card height should never exceed the full base card size")
	var total_band_span: float = float(stack.get("band_height", 0.0)) * 4.0 + float(stack.get("band_gap", 0.0)) * 3.0
	_expect(total_band_span <= body_rect.size.y + 0.5, "four bands plus gaps must fit inside the result body")
	# A single category keeps full-size cards rather than ballooning.
	var single_stack: Dictionary = StageClearResultLayoutHelper.calculate_reward_band_stack_layout([1], body_rect, 1.0)
	_expect(Vector2(single_stack.get("card_size", Vector2.ZERO)).y <= 112.0 + 0.5, "single-band card should stay at the full base size, not oversize")
	_expect(StageClearResultLayoutHelper.calculate_reward_band_stack_layout([], body_rect, 1.0).get("count", -1) == 0, "empty stack should report zero bands")


func _verify_source_rects() -> void:
	var source: Rect2 = StageClearResultLayoutHelper.sheet_source_rect(15, 4, Vector2(256.0, 256.0))
	_expect(source.position == Vector2(768.0, 768.0), "sheet source rect should resolve frame columns and rows")
	_expect(source.size == Vector2(256.0, 256.0), "sheet source rect should preserve cell size")
	var cover: Rect2 = StageClearResultLayoutHelper.cover_source_rect(Vector2(400.0, 200.0), Vector2(100.0, 100.0))
	_expect(cover.position == Vector2(100.0, 0.0), "cover source rect should crop wide textures horizontally")
	_expect(cover.size == Vector2(200.0, 200.0), "cover source rect should fit the target ratio")


func _verify_scene_wrappers() -> void:
	var wrapper_box := {"base_pos": Vector2(10.0, 20.0), "phase": 0.0, "amplitude": 4.0, "speed": 1.0}
	_expect(StageClearResultLayoutHelper.get_result_box_frame_index("opened", 1.0, false, 16, 12, 15) == 12, "box-frame helper should preserve scene frame policy")
	_expect(StageClearResultLayoutHelper.get_box_draw_center(wrapper_box, 2.0, 0.0, 5.0, 1.4) == Vector2(20.0, 40.0), "box-center helper should preserve scene geometry policy")
	_expect(StageClearResultLayoutHelper.get_box_aabb(wrapper_box, 2.0, 0.0, Vector2(65.0, 56.0), 1.06, 5.0, 1.4).has_point(Vector2(20.0, 40.0)), "box-aabb helper should preserve scene hitbox policy")
	_expect(StageClearResultLayoutHelper.get_player_victory_actor_rect(Vector2(1920.0, 1080.0), 1.0).position == Vector2(1270.0, 213.0), "player-victory actor helper should preserve scene draw rect")
	var scene_click_rect: Rect2 = StageClearResultLayoutHelper.get_player_victory_click_rect(
		Vector2(1920.0, 1080.0),
		1.0,
		Vector2(1408.0, 1408.0)
	)
	_expect(is_equal_approx(scene_click_rect.end.x, 1920.0), "player-victory click helper should clamp to the scene viewport")
	_expect(StageClearResultLayoutHelper.get_player_victory_panel_rect(Vector2(1920.0, 1080.0), 1.0).size == Vector2(410.0, 750.0), "player-victory panel helper should preserve scene panel rect")
	_expect(StageClearResultLayoutHelper.get_scroll_content_rect(Rect2(Vector2(100.0, 200.0), Vector2(400.0, 300.0)), 1.0, Vector4(70.0, 90.0, 70.0, 76.0)).position == Vector2(170.0, 290.0), "scroll-content helper should preserve scene content margins")
	_expect(StageClearResultLayoutHelper.get_dalji_draw_rect(Vector2(1920.0, 1080.0), 1.0).size == Vector2(624.0, 624.0), "Dalji draw-rect helper should preserve scene boss rect")
	_expect(int(StageClearResultLayoutHelper.calculate_reward_section_layout(7, Rect2(Vector2.ZERO, Vector2(538.0, 276.0)), 1.0).get("rows", 0)) == 2, "reward-layout helper should preserve scene dense-grid policy")
	_expect(StageClearResultLayoutHelper.sheet_source_rect(15, 4, Vector2(256.0, 256.0)).position == Vector2(768.0, 768.0), "sheet-rect helper should preserve scene source-frame policy")
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var box_data_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_data.gd")
	var reward_card_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_reward_card_draw_helper.gd")
	var sheet_draw_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_sheet_draw_helper.gd")
	_expect(
		box_data_source.find("StageClearResultLayoutHelper.get_box_layout") >= 0
		and source.find("draw_set_transform(draw_center, box_rotation") >= 0,
		"stage-clear result box data should call the box layout helper and the scene should rotate boxes through the draw transform"
	)
	_expect(
		source.find("func _get_title_text") < 0,
		"stage-clear result scene should not keep unused title text helpers"
	)
	_expect(
		source.find("func _get_box_layout") < 0 and source.find("func _rotate_around") < 0,
		"stage-clear result scene should not keep simple layout pass-through wrappers"
	)
	_expect(
		source.find("StageClearResultLayoutHelper.get_result_box_frame_index") >= 0
		and source.find("StageClearResultLayoutHelper.get_box_draw_center") >= 0
		and source.find("StageClearResultLayoutHelper.get_box_aabb") >= 0,
		"stage-clear result scene should call box layout helpers directly"
	)
	_expect(
		source.find("func _get_result_box_frame_index") < 0
		and source.find("func _get_box_draw_center") < 0
		and source.find("func _get_box_aabb") < 0,
		"stage-clear result scene should not keep box layout pass-through wrappers"
	)
	_expect(
		source.find("StageClearResultLayoutHelper.get_scroll_content_rect") >= 0
		and reward_card_source.find("StageClearResultLayoutHelper.calculate_reward_band_stack_layout") >= 0
		and sheet_draw_source.find("StageClearResultLayoutHelper.sheet_source_rect") >= 0
		and source.find("StageClearResultLayoutHelper.cover_source_rect") >= 0,
		"stage-clear result scene and focused draw helpers should call residual layout helpers"
	)
	_expect(
		source.find("func _get_scroll_content_rect") < 0
		and source.find("func _calculate_reward_section_layout") < 0
		and source.find("func _get_reward_section_columns") < 0
		and source.find("func _sheet_source_rect") < 0
		and source.find("func _cover_source_rect") < 0,
		"stage-clear result scene should not keep residual layout pass-through wrappers"
	)
	_expect(
		source.find("StageClearResultLayoutHelper.get_player_victory_actor_rect") >= 0
		and source.find("StageClearResultLayoutHelper.get_player_victory_click_rect") >= 0
		and source.find("StageClearResultLayoutHelper.get_player_victory_panel_rect") >= 0
		and source.find("StageClearResultLayoutHelper.get_dalji_draw_rect") >= 0,
		"stage-clear result scene should call victory/Dalji layout helpers directly"
	)
	_expect(
		source.find("func _get_player_victory_actor_rect") < 0
		and source.find("func _get_player_victory_click_rect") < 0
		and source.find("func _get_player_victory_panel_rect") < 0
		and source.find("func _screen_to_acquisition_cinematic_local") < 0
		and source.find("func _get_dalji_draw_rect") < 0,
		"stage-clear result scene should not keep victory/Dalji layout pass-through wrappers"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
