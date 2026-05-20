extends SceneTree

const RESULT_SCENE := preload("res://scenes/stage_clear_result.tscn")
const GameAudio := preload("res://scripts/audio/game_audio.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RESULT_BOX_COMMON_SHEET := "res://assets/sprites/result_boxes/result_box_common_open_16f.png"
const RESULT_BOX_MYTHIC_SHEET := "res://assets/sprites/result_boxes/result_box_mythic_open_16f.png"
const RESULT_BOX_CELL := 256
const RESULT_BOX_GRID_COLS := 4


class FakeResultRoller:
	extends RefCounted

	var calls := 0

	func roll_reward(box_kind: String) -> Dictionary:
		calls += 1
		if box_kind == "mythic":
			return {
				"type": "mythic",
				"label": "스피드부츠",
				"item_name": "speedboots",
				"icon_path": "res://assets/sprites/items/speedboots.png",
				"item_data": {
					"name": "speedboots",
					"display_name": "스피드부츠",
					"icon_path": "res://assets/sprites/items/speedboots.png",
				},
			}
		if calls == 2:
			return {
				"type": "perk",
				"label": "모듈제어",
				"perk_id": "dash_module_control",
			}
		return {
			"type": "starpoint",
			"label": "★ 2",
			"amount": 2,
		}


class FakeGameAudio:
	extends RefCounted

	var result_box_open_calls := 0

	func play_result_box_open() -> void:
		result_box_open_calls += 1


func _init() -> void:
	_verify_result_box_open_audio_asset()
	_verify_result_box_open_audio_route()
	_verify_result_box_sheet_padding()
	_verify_result_box_frame_policy()
	_verify_cyber_scroll_reward_summary()
	_verify_cyber_scroll_reward_source_tags()
	_verify_cyber_scroll_dense_reward_grid_layout()
	var scene: Control = RESULT_SCENE.instantiate() as Control
	if scene == null:
		push_error("stage clear result scene should instantiate")
		quit(1)
		return
	root.add_child(scene)
	if scene.has_method("configure"):
		scene.configure({
			"player_score": 5,
			"boss_score": 0,
			"current_stage": 1,
			"reward_plan": {
				"summary": "확정 신화 아이템 + 일반 아이템 2개",
				"boxes": [
					{"kind": "mythic"},
					{"kind": "normal"},
					{"kind": "normal"},
				],
				"reward_count": 3,
			},
		}, Callable())

	var status: Dictionary = scene.get_interaction_status()
	var click_rect: Rect2 = status.get("dalji_click_rect", Rect2())
	_expect(click_rect.size.x > 0.0 and click_rect.size.y > 0.0, "Dalji click rect should be available")
	_expect(
		load("res://assets/sprites/stage1/dalji/dalji_result_defeat_cutscene_live2d_clean_anchor_pingpong_98f_autosprite_v6_realesrgan_animev3_hq1152_safe.png").get_size() == Vector2(16128.0, 8064.0),
		"Dalji result base Live2D should use the Real-ESRGAN hq1152 sheet"
	)
	_expect(
		load("res://assets/sprites/stage1/dalji/dalji_result_click_cry_dont_talk_live2d_remake_pingpong_98f_autosprite_v6_realesrgan_animev3_hq1152_safe.png").get_size() == Vector2(16128.0, 8064.0),
		"Dalji result click Live2D should use the Real-ESRGAN hq1152 sheet"
	)
	_expect(str(status.get("dalji_click_voice_path", "")).ends_with("voice/dalzidefeat.mp3"), "Dalji click should expose the supplied defeat voice asset")
	_expect(bool(status.get("dalji_click_voice_loaded", false)), "Dalji click crying voice should load")
	_expect(str(status.get("dalji_dialogue", "")) == "건들지마", "Dalji click dialogue should be the requested line")

	_expect(
		load("res://assets/sprites/smasher/smasher_result_victory_base_loop_98f_autosprite_v18_magenta_v2_no_pet_realesrgan_animev3_hq1408.png").get_size() == Vector2(15488.0, 12672.0),
		"Smasher result base Live2D should use the identity-locked Real-ESRGAN hq1408 11x9 98-frame sheet"
	)
	_expect(
		load("res://assets/sprites/smasher/smasher_result_victory_click_reaction_98f_autosprite_v18_magenta_v2_no_pet_realesrgan_animev3_hq1408.png").get_size() == Vector2(15488.0, 12672.0),
		"Smasher result click Live2D should use the identity-locked Real-ESRGAN hq1408 11x9 98-frame sheet"
	)
	_expect(bool(status.get("player_victory_sheet_loaded", false)), "Smasher result base Live2D should load")
	_expect(bool(status.get("player_victory_click_reaction_sheet_loaded", false)), "Smasher result click Live2D should load")
	_expect(int(status.get("player_victory_frame_count", 0)) == 98, "Smasher result Live2D should expose 98 frames")
	_expect(int(status.get("player_victory_grid_cols", 0)) == 11, "Smasher result Live2D should use an 11-column grid")
	_expect(Vector2(status.get("player_victory_cell_size", Vector2.ZERO)) == Vector2(1408.0, 1408.0), "Smasher result Live2D should expose the Real-ESRGAN hq1408 source cell size")
	var player_draw_rect: Rect2 = status.get("player_victory_draw_rect", Rect2())
	_expect(is_equal_approx(player_draw_rect.position.y, 213.0), "Smasher result Live2D should use the Dalji-aligned y offset")
	_expect(is_equal_approx(player_draw_rect.size.y, 760.0), "Smasher result Live2D should use the density-matched right-side draw size")
	var player_click_rect: Rect2 = status.get("player_victory_click_rect", Rect2())
	_expect(player_click_rect.size.x > 0.0 and player_click_rect.size.y > 0.0, "Smasher click rect should be available")

	scene.update_result_scene(1.10)
	status = scene.get_interaction_status()
	var smasher_base_frame_before_click: int = int(status.get("player_victory_base_frame", 0))
	_expect(smasher_base_frame_before_click > 0, "test should click Smasher from a non-neutral base Live2D frame")
	var smasher_click := InputEventMouseButton.new()
	smasher_click.button_index = MOUSE_BUTTON_LEFT
	smasher_click.pressed = true
	smasher_click.position = player_click_rect.get_center()
	_expect(scene.handle_result_input(smasher_click), "Smasher click should be consumed by the result scene")

	status = scene.get_interaction_status()
	_expect(bool(status.get("player_victory_click_reaction_active", false)), "Smasher click should start the reaction sheet")
	_expect(float(status.get("player_victory_click_reaction_duration", 99.0)) < 3.8, "Smasher click reaction should be a short victory beat")
	_expect(int(status.get("player_victory_click_transition_base_frame", -1)) == smasher_base_frame_before_click, "Smasher click should freeze the current base frame for blend-in")
	_expect(is_equal_approx(float(status.get("player_victory_reaction_alpha", -1.0)), 0.0), "Smasher click should begin from the existing base frame before fading into reaction")

	scene.update_result_scene(0.11)
	status = scene.get_interaction_status()
	var smasher_mid_alpha: float = float(status.get("player_victory_reaction_alpha", 0.0))
	_expect(smasher_mid_alpha > 0.05 and smasher_mid_alpha < 0.95, "Smasher click should crossfade into the reaction instead of hard switching")

	var smasher_reaction_timer_now: float = float(status.get("player_victory_click_reaction_timer", 0.0))
	var smasher_reaction_duration: float = float(status.get("player_victory_click_reaction_duration", 0.0))
	var smasher_advance_into_hold: float = max(0.0, smasher_reaction_duration - smasher_reaction_timer_now) + 0.02
	scene.update_result_scene(smasher_advance_into_hold)
	status = scene.get_interaction_status()
	_expect(bool(status.get("player_victory_click_return_blend_active", false)), "Smasher click should enter the return blend hold phase after the 98-frame pass")
	_expect(is_equal_approx(float(status.get("player_victory_reaction_alpha", 0.0)), 1.0), "Smasher click should hold the final reaction frame at full alpha during the settle window")

	scene.update_result_scene(6.0)
	status = scene.get_interaction_status()
	_expect(not bool(status.get("player_victory_click_reaction_active", true)), "Smasher click reaction should return to the base loop")
	_expect(is_equal_approx(float(status.get("player_victory_reaction_alpha", 1.0)), 0.0), "Smasher click should fade fully back to the base loop")

	scene.update_result_scene(1.10)
	status = scene.get_interaction_status()
	var base_frame_before_click: int = int(status.get("dalji_base_frame", 0))
	_expect(base_frame_before_click > 0, "test should click from a non-neutral base Live2D frame")

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = click_rect.get_center()
	_expect(scene.handle_result_input(click), "Dalji click should be consumed by the result scene")

	status = scene.get_interaction_status()
	_expect(bool(status.get("dalji_click_reaction_active", false)), "Dalji click should start the reaction sheet")
	_expect(float(status.get("dalji_click_reaction_duration", 99.0)) < 3.8, "Dalji click reaction should be a short upset beat")
	_expect(int(status.get("dalji_click_transition_base_frame", -1)) == base_frame_before_click, "Dalji click should freeze the current base frame for blend-in")
	_expect(is_equal_approx(float(status.get("dalji_reaction_alpha", -1.0)), 0.0), "Dalji click should begin from the existing base frame before fading into reaction")
	_expect(bool(status.get("dalji_click_voice_player_ready", false)), "Dalji click should create a voice player")
	var dialogue_timer: float = float(status.get("dalji_dialogue_timer", 0.0))
	_expect(dialogue_timer > 0.0 and dialogue_timer <= 1.7, "Dalji click dialogue should be brief")

	scene.update_result_scene(0.11)
	status = scene.get_interaction_status()
	var mid_alpha: float = float(status.get("dalji_reaction_alpha", 0.0))
	_expect(mid_alpha > 0.05 and mid_alpha < 0.95, "Dalji click should crossfade into the reaction instead of hard switching")

	var scene_timer_before_return: float = float(status.get("scene_timer", 0.0))
	var base_timer_before_return: float = float(status.get("dalji_base_timer", 0.0))
	var reaction_timer_now: float = float(status.get("dalji_click_reaction_timer", 0.0))
	var reaction_duration: float = float(status.get("dalji_click_reaction_duration", 0.0))
	var advance_into_hold: float = max(0.0, reaction_duration - reaction_timer_now) + 0.02
	scene.update_result_scene(advance_into_hold)
	status = scene.get_interaction_status()
	_expect(bool(status.get("dalji_click_return_blend_active", false)), "Dalji click should enter the return blend hold phase after the 98-frame pass")
	_expect(is_equal_approx(float(status.get("dalji_reaction_alpha", 0.0)), 1.0), "Dalji click should hold the final reaction frame at full alpha during the settle window before any fade begins, so the player does not see a slow translucent ghost")

	scene.update_result_scene(0.18)
	status = scene.get_interaction_status()
	_expect(bool(status.get("dalji_click_return_blend_active", false)), "Dalji click return blend should still be active inside the brief fade window")
	var fade_alpha: float = float(status.get("dalji_reaction_alpha", 0.0))
	_expect(fade_alpha > 0.0 and fade_alpha < 1.0, "Dalji click should fade smoothly inside the brief fade window so the swap is not a 1-frame hard cut")
	_expect(float(status.get("dalji_base_timer", 0.0)) > base_timer_before_return, "Dalji base loop should keep advancing during the click reaction so the return blend reveals a moving base, not a frozen pose")
	_expect(float(status.get("scene_timer", 0.0)) > scene_timer_before_return, "Dalji click return should not reset the result scene timer")

	var base_timer_at_return: float = float(status.get("dalji_base_timer", 0.0))
	scene.update_result_scene(6.0)
	status = scene.get_interaction_status()
	_expect(not bool(status.get("dalji_click_reaction_active", true)), "Dalji click reaction should return to the base loop after one 98-frame pass")
	_expect(is_equal_approx(float(status.get("dalji_reaction_alpha", 1.0)), 0.0), "Dalji click should fade fully back to the base loop")
	_expect(float(status.get("dalji_base_timer", 0.0)) > base_timer_at_return + 5.0, "Dalji base loop should continue running uninterrupted after the click reaction ends")
	_expect(float(status.get("dalji_dialogue_timer", 1.0)) == 0.0, "Dalji click dialogue should expire")

	scene.free()
	print("stage_clear_result_scene_click_reaction_smoke: ok")
	quit(0)


func _verify_result_box_open_audio_asset() -> void:
	_expect(GameAudio.RESULT_BOX_OPEN_SOUND_PATH == "res://assets/sounds/boxopen.wav", "result box open should use the supplied boxopen.wav asset")
	_expect(FileAccess.file_exists(GameAudio.RESULT_BOX_OPEN_SOUND_PATH), "boxopen.wav should exist in the Godot sound asset tree")
	_expect(ProjectResourceLoader.load_audio_stream(GameAudio.RESULT_BOX_OPEN_SOUND_PATH) != null, "boxopen.wav should load as a Godot audio stream")


func _verify_result_box_open_audio_route() -> void:
	var scene: Control = RESULT_SCENE.instantiate() as Control
	_expect(scene != null, "stage clear result scene should instantiate for box-open audio")
	root.add_child(scene)
	var audio := FakeGameAudio.new()
	scene.configure({
		"player_score": 5,
		"boss_score": 4,
		"current_stage": 1,
		"reward_plan": {
			"summary": "",
			"boxes": [
				{"kind": "normal"},
			],
			"reward_count": 1,
		},
		"game_audio": audio,
	}, Callable())
	var status: Dictionary = scene.get_interaction_status()
	_expect(bool(status.get("box_open_audio_ready", false)), "result scene should expose the routed box-open audio dependency")
	var boxes_value: Variant = scene.get("_boxes")
	var boxes: Array = boxes_value if boxes_value is Array else []
	_expect(boxes.size() == 1, "box-open audio route smoke should build one clickable box")
	if boxes.size() == 1:
		@warning_ignore("shadowed_variable_base_class")
		var scale: float = scene._get_layout_scale(scene.size)
		var box: Dictionary = boxes[0] if boxes[0] is Dictionary else {}
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = scene._get_box_aabb(box, scale).get_center()
		_expect(scene.handle_result_input(click), "box click should be consumed by the result scene")
		_expect(audio.result_box_open_calls == 1, "box click should play the routed result-box open SFX once")
		_expect(scene.handle_result_input(click), "second box click should still be consumed by the result scene")
		_expect(audio.result_box_open_calls == 1, "opening box should not replay the box-open SFX on repeated clicks")
	scene.free()


func _verify_cyber_scroll_reward_summary() -> void:
	var scene: Control = RESULT_SCENE.instantiate() as Control
	_expect(scene != null, "stage clear result scene should instantiate for cyber scroll summary")
	root.add_child(scene)
	var roller := FakeResultRoller.new()
	scene.configure({
		"player_score": 5,
		"boss_score": 0,
		"current_stage": 1,
		"reward_plan": {
			"summary": "확정 신화 아이템 + 일반 아이템 2개",
			"boxes": [
				{"kind": "mythic"},
				{"kind": "normal"},
				{"kind": "normal"},
			],
			"reward_count": 3,
		},
	}, Callable(), Callable(), Callable(roller, "roll_reward"))

	var status: Dictionary = scene.get_interaction_status()
	_expect(bool(status.get("scroll_texture_loaded", false)), "cyber result scroll texture should load before the unfurl animation")
	for _i in range(3):
		_expect(scene.handle_result_input(_make_key_event(KEY_ENTER)), "Enter should open the next reward box")
		scene.update_result_scene(0.70)
	scene.update_result_scene(0.40)
	scene.update_result_scene(1.00)
	status = scene.get_interaction_status()
	_expect(str(status.get("scroll_phase", "")) == "visible", "result scroll should become visible after every box opens")
	_expect(bool(status.get("buttons_clickable", false)), "result scroll buttons should become clickable after unfurling")
	_expect(int(status.get("item_reward_count", 0)) == 1, "summary should count item rewards separately from perks")
	_expect(int(status.get("perk_reward_count", 0)) == 1, "summary should count acquired perk rewards")
	_expect(int(status.get("starpoint_total", 0)) == 2, "summary should preserve acquired starpoint rewards without top-right clutter")
	var perk_info: Dictionary = status.get("perk_info", {}) if status.get("perk_info", {}) is Dictionary else {}
	_expect(str(perk_info.get("kind", "")) == "perk", "result scroll should expose acquired perk info when a perk reward exists")
	_expect(str(perk_info.get("title", "")) == "모듈제어", "result scroll should use the acquired perk name in the info panel")
	_expect(str(perk_info.get("detail", "")) != "", "result scroll should expose acquired perk effect details")
	_expect(roller.calls == 3, "test roller should have supplied one reward per box")
	scene.free()


func _verify_cyber_scroll_reward_source_tags() -> void:
	var scene: Control = RESULT_SCENE.instantiate() as Control
	_expect(scene != null, "stage clear result scene should instantiate for reward source tags")
	root.add_child(scene)
	var roller := FakeResultRoller.new()
	scene.configure({
		"player_score": 5,
		"boss_score": 0,
		"current_stage": 1,
		"stage_reward_snapshot": {
			"active_items": [
				{
					"type": "active",
					"label": "화염병",
					"item_name": "molotov",
					"source": "stage_active",
				},
			],
			"passive_items": [],
			"perks": [
				{
					"type": "perk",
					"label": "킥 강화 Lv.1",
					"perk_id": "kick_enhance",
					"source": "stage_perk",
				},
			],
		},
		"reward_plan": {
			"summary": "상자 아이템 + 상자 퍽",
			"boxes": [
				{"kind": "mythic"},
				{"kind": "normal"},
			],
			"reward_count": 2,
		},
	}, Callable(), Callable(), Callable(roller, "roll_reward"))
	for _i in range(2):
		_expect(scene.handle_result_input(_make_key_event(KEY_ENTER)), "Enter should open the next reward source test box")
		scene.update_result_scene(0.70)
	var status: Dictionary = scene.get_interaction_status()
	var item_sources: Dictionary = status.get("item_reward_source_counts", {}) if status.get("item_reward_source_counts", {}) is Dictionary else {}
	var perk_sources: Dictionary = status.get("perk_reward_source_counts", {}) if status.get("perk_reward_source_counts", {}) is Dictionary else {}
	_expect(int(item_sources.get("stage", 0)) == 1, "result item cards should count in-game acquisitions separately")
	_expect(int(item_sources.get("box", 0)) == 1, "result item cards should count box acquisitions separately")
	_expect(int(perk_sources.get("stage", 0)) == 1, "result perk cards should count in-game acquisitions separately")
	_expect(int(perk_sources.get("box", 0)) == 1, "result perk cards should count box acquisitions separately")
	var items: Array = scene._build_item_summary()
	var perks: Array = scene._build_perk_summary()
	_expect(str((items[0] as Dictionary).get("_result_reward_source_label", "")) == "인게임", "in-game item cards should show the in-game source label")
	_expect(str((items[1] as Dictionary).get("_result_reward_source_label", "")) == "상자", "box item cards should show the box source label")
	_expect(str((perks[0] as Dictionary).get("_result_reward_source_label", "")) == "인게임", "in-game perk cards should show the in-game source label")
	_expect(str((perks[1] as Dictionary).get("_result_reward_source_label", "")) == "상자", "box perk cards should show the box source label")
	scene.free()


func _verify_cyber_scroll_dense_reward_grid_layout() -> void:
	var scene: Control = RESULT_SCENE.instantiate() as Control
	_expect(scene != null, "stage clear result scene should instantiate for dense reward grid layout")
	root.add_child(scene)
	var dense_section_rect := Rect2(Vector2.ZERO, Vector2(538.0, 276.0))
	var layout: Dictionary = scene._calculate_reward_section_layout(7, dense_section_rect, 1.0)
	var card_size: Vector2 = layout.get("card_size", Vector2.ZERO)
	var card_scale: float = float(layout.get("card_scale", 1.0))
	var gap: float = float(layout.get("gap", 0.0))
	var rows: int = int(layout.get("rows", 0))
	_expect(rows == 2, "dense reward grid should stay on two rows in the split result column")
	_expect(card_scale < 1.0, "dense reward grid should shrink card internals with the card body")
	_expect(card_size.y > 0.0, "dense reward grid should expose a card height")
	_expect((84.0 + 22.0) * card_scale <= card_size.y + 0.5, "dense reward labels should remain inside the shrunken cards")
	_expect((30.0 + 54.0) * card_scale <= card_size.y + 0.5, "dense reward icons should remain inside the shrunken cards")
	_expect(card_size.y + gap > 0.0, "dense reward row stride should remain positive")
	scene.free()


func _verify_result_box_sheet_padding() -> void:
	for sheet in [
		{"label": "common", "path": RESULT_BOX_COMMON_SHEET},
		{"label": "mythic", "path": RESULT_BOX_MYTHIC_SHEET},
	]:
		var label: String = str(sheet.get("label", ""))
		var path: String = str(sheet.get("path", ""))
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		_expect(not bytes.is_empty(), "%s result box sheet bytes should be readable" % label)
		if bytes.is_empty():
			continue
		var image := Image.new()
		var err: Error = image.load_png_from_buffer(bytes)
		_expect(err == OK, "%s result box sheet should load" % label)
		if err != OK:
			continue
		_verify_result_box_sheet_image_padding(image, "%s source" % label)
		var texture: Texture2D = load(path) as Texture2D
		_expect(texture != null, "%s result box runtime texture should load" % label)
		if texture != null:
			_verify_result_box_sheet_image_padding(texture.get_image(), "%s runtime texture" % label)


func _verify_result_box_frame_policy() -> void:
	var scene: Control = RESULT_SCENE.instantiate() as Control
	_expect(scene != null, "stage clear result scene should instantiate for result box frame policy")
	root.add_child(scene)
	_expect(int(scene._get_result_box_frame_index("opened", 1.0, false)) == 12, "common result boxes should stop on the last non-truncated open-lid frame")
	_expect(int(scene._get_result_box_frame_index("opening", 0.98, false)) == 12, "common result box opening animation should not show the truncated late lid frames")
	_expect(int(scene._get_result_box_frame_index("opened", 1.0, true)) == 15, "mythic result boxes can keep the full final open frame")
	scene.free()


func _verify_result_box_sheet_image_padding(image: Image, label: String) -> void:
	_expect(image.get_width() == RESULT_BOX_CELL * 4 and image.get_height() == RESULT_BOX_CELL * 4, "%s result box sheet should keep the 4x4 cell layout" % label)
	for frame_index in range(9, 16):
		var col: int = frame_index % RESULT_BOX_GRID_COLS
		@warning_ignore("integer_division")
		var row: int = int(frame_index / RESULT_BOX_GRID_COLS)
		var bbox: Rect2i = _alpha_bbox_region(
			image,
			Vector2i(col * RESULT_BOX_CELL, row * RESULT_BOX_CELL),
			Vector2i(RESULT_BOX_CELL, RESULT_BOX_CELL)
		)
		_expect(bbox.size.x > 0 and bbox.size.y > 0, "%s result box frame %d should not be empty" % [label, frame_index])
		_expect(
			bbox.position.y >= 8 and bbox.end.x <= RESULT_BOX_CELL - 8,
			"%s result box frame %d should keep the opened lid away from the top/right cell crop" % [label, frame_index]
		)


func _alpha_bbox_region(image: Image, origin: Vector2i, size: Vector2i) -> Rect2i:
	var min_x := size.x
	var min_y := size.y
	var max_x := -1
	var max_y := -1
	for y in range(size.y):
		for x in range(size.x):
			if image.get_pixel(origin.x + x, origin.y + y).a <= 0.01:
				continue
			min_x = min(min_x, x)
			min_y = min(min_y, y)
			max_x = max(max_x, x)
			max_y = max(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _make_key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	return event


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
