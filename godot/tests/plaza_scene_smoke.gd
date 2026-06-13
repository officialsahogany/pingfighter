extends SceneTree

const PlazaScenePacked := preload("res://scenes/plaza.tscn")
const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")
const PlazaPlayerController := preload("res://scripts/plaza/plaza_player_controller.gd")
const PlazaThemeCatalog := preload("res://scripts/plaza/plaza_theme_catalog.gd")

const PIXEL_SAMPLE_PATHS := [
	"res://assets/ui/plaza/plaza_stage1_floor_base_01_cyber_joseon_imagegen_v1.png",
	"res://assets/ui/plaza/plaza_stage1_sidescroll_ground_strip_cyber_joseon_imagegen_v1.png",
	"res://assets/ui/plaza/plaza_stage1_sidescroll_ground_strip_emissive_v1.png",
	"res://assets/ui/plaza/plaza_stage1_sidescroll_midground_wall_cyber_joseon_imagegen_v1.png",
	"res://assets/ui/plaza/plaza_stage1_sidescroll_far_sky_moon_cyber_joseon_imagegen_v1.png",
	"res://assets/ui/plaza/plaza_stage1_sidescroll_accent_neon_cutout_v1.png",
	"res://assets/ui/plaza/plaza_stage1_sidescroll_medallion_cutout_v1.png",
	"res://assets/ui/plaza/buildings/plaza_stage1_cyber_joseon_shop_v2_building_base.png",
]

var _failures: Array[String] = []


class CallbackSink:
	extends RefCounted

	var exit_calls := 0

	func exit_plaza() -> void:
		exit_calls += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_theme_fallback()
	_prewarm_stage_one()
	await _verify_plaza_scene_runtime()

	if _failures.is_empty():
		print("plaza_scene_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_theme_fallback() -> void:
	_expect(PlazaThemeCatalog.normalize_stage_id(999) == PlazaThemeCatalog.DEFAULT_STAGE_ID, "unknown plaza stage should fall back to Stage 1")
	var theme: Dictionary = PlazaThemeCatalog.get_theme(999)
	_expect(str(theme.get("id", "")) == "stage1_cyber_joseon", "theme fallback should return the Stage 1 cyber-Joseon theme")


func _prewarm_stage_one() -> void:
	PlazaScene.reset_prewarm_assets_for_test()
	var guard := 0
	while not bool(PlazaScene.prewarm_assets_blocking_step(1)):
		guard += 1
		if guard > 96:
			_expect(false, "plaza asset prewarm should finish within the staged texture budget")
			return
	var status: Dictionary = PlazaScene.get_prewarm_asset_status()
	_expect(bool(status.get("complete", false)), "plaza prewarm should report completion")
	_expect(int(status.get("stage_id", 0)) == 1, "plaza prewarm should remember the normalized stage")


func _verify_plaza_scene_runtime() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 750)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var sink := CallbackSink.new()
	var scene := PlazaScenePacked.instantiate() as Control
	var save_path := "user://plaza_scene_smoke.cfg"
	_cleanup_save(save_path)
	_expect(scene != null, "plaza scene should instantiate")
	if scene == null:
		viewport.queue_free()
		_cleanup_save(save_path)
		return
	viewport.add_child(scene)
	scene.configure({"current_stage": 999, "plaza_save_path": save_path}, Callable(sink, "exit_plaza"), true)
	scene.update_plaza(1.0 / 60.0)

	var status: Dictionary = scene.get_status()
	_expect(int(status.get("current_stage", 0)) == 1, "plaza scene should normalize unknown stages to Stage 1")
	_expect(bool(status.get("side_scroll", false)), "plaza scene should run in the side-scroll street layout")
	_expect(float((status.get("world_size", Vector2.ZERO) as Vector2).x) > 760.0, "side-scroll plaza should expose a wider world than the game canvas")
	_expect(int(status.get("building_count", 0)) == 7, "Stage 1 plaza should load the seven accepted building kits")
	_expect(int(status.get("collision_rect_count", -1)) == 0, "side-scroll plaza should keep buildings as background storefronts without blocking footprints")
	_verify_flicker_samples_are_instance_seeded(scene)
	_verify_building_menu_shells(scene)

	var bank: Dictionary = _find_building(scene.get_building_specs_for_test(), "bank")
	_expect(not bank.is_empty(), "plaza should include the bank building spec")
	if not bank.is_empty():
		var interaction_rect: Rect2 = bank.get("interaction_rect", Rect2())
		scene.set_player_pos_for_test(Vector2(interaction_rect.get_center().x, float(status.get("ground_y", 0.0))))
		_expect(scene.trigger_interaction_for_test(), "player in a building interaction zone should open the menu dialog placeholder")
		status = scene.get_status()
		_expect(bool(status.get("menu_open", false)), "building interaction should open the S5 menu shell")
		_expect(str(status.get("active_menu_type", "")) == "bank", "bank interaction should open the bank menu shell")

		scene.set_player_pos_for_test(Vector2(120.0, float(status.get("ground_y", 0.0)) - 80.0))
		var before_pos: Vector2 = scene.get_status().get("player_pos", Vector2.ZERO)
		var before_camera := float(scene.get_status().get("camera_x", 0.0))
		scene.move_player_for_test(Vector2.RIGHT, 1.0 / 60.0)
		var after_pos: Vector2 = scene.get_status().get("player_pos", Vector2.ZERO)
		_expect(after_pos.is_equal_approx(before_pos), "open building menu should block player walking")
		_expect(is_equal_approx(float(scene.get_status().get("camera_x", 0.0)), before_camera), "open building menu should block camera movement")
		var exit_zone_while_menu: Rect2 = scene.get_status().get("exit_zone", Rect2())
		scene.set_player_pos_for_test(Vector2(exit_zone_while_menu.get_center().x, float(status.get("ground_y", 0.0))))
		_expect(not scene.trigger_interaction_for_test(), "open building menu should block EXIT interaction")
		_expect(sink.exit_calls == 0, "blocked EXIT interaction should not invoke the delayed callback")
		_expect(not scene.trigger_menu_action_for_test(0), "empty bank action should not mutate the S6 bank ledger")
		_send_key(scene, KEY_ESCAPE)
		status = scene.get_status()
		_expect(not bool(status.get("menu_open", true)), "ESC should close the building menu shell")

		scene.set_player_pos_for_test(Vector2(120.0, float(status.get("ground_y", 0.0)) - 80.0))
		before_pos = scene.get_status().get("player_pos", Vector2.ZERO)
		scene.move_player_for_test(Vector2.RIGHT, 1.0 / 60.0)
		after_pos = scene.get_status().get("player_pos", Vector2.ZERO)
		_expect(after_pos.x > before_pos.x, "side-scroll plaza should move the player on the X axis after the menu closes")
		_expect(absf(after_pos.y - float(status.get("ground_y", 0.0))) <= 0.01, "side-scroll plaza should clamp the player to the ground line")

	scene.set_player_pos_for_test(Vector2(1600.0, float(status.get("ground_y", 0.0))))
	status = scene.get_status()
	_expect(float(status.get("camera_x", 0.0)) > 0.0, "side-scroll plaza should advance the camera on the X axis")

	var exit_zone: Rect2 = scene.get_status().get("exit_zone", Rect2())
	scene.set_player_pos_for_test(Vector2(exit_zone.get_center().x, float(status.get("ground_y", 0.0))))
	_expect(scene.trigger_interaction_for_test(), "player in the plaza exit zone should trigger exit")
	_expect(sink.exit_calls == 1, "plaza exit should invoke the delayed stage-transition callback exactly once")

	for _idx in range(4):
		await process_frame
	_verify_nonblank_viewport(viewport)
	viewport.queue_free()
	_cleanup_save(save_path)


func _verify_flicker_samples_are_instance_seeded(scene: Control) -> void:
	var samples: Dictionary = scene.get_flicker_samples_for_test()
	var unique_values := {}
	for value in samples.values():
		unique_values[snappedf(float(value), 0.001)] = true
	_expect(unique_values.size() >= 3, "plaza flicker samples should vary by per-instance seed within the same tick")


func _verify_building_menu_shells(scene: Control) -> void:
	var expected_titles := {
		"shop": "상점",
		"bank": "은행",
		"gacha": "가챠샵",
		"lingpet_store": "링펫스토어",
		"blacksmith": "대장간",
		"tavern": "선술집",
		"academy": "아카데미",
	}
	var expected_actions := {
		"shop": ["벽돌 구매 80G", "부메랑 구매 120G", "마지막 아이템 판매"],
		"bank": ["예금 100G", "출금 100G", "이자 정산"],
		"gacha": ["액티브 캡슐 뽑기 150G"],
		"lingpet_store": ["공명 알 뽑기 250G", "링펫 관리"],
		"blacksmith": ["마지막 아이템 강화"],
		"tavern": ["퀘스트 받기"],
		"academy": ["스킬 획득", "스킬 교환"],
	}
	for building_type in expected_titles.keys():
		var spec := _find_building(scene.get_building_specs_for_test(), str(building_type))
		_expect(not spec.is_empty(), "plaza should include %s building spec" % building_type)
		if spec.is_empty():
			continue
		var interaction_rect: Rect2 = spec.get("interaction_rect", Rect2())
		var ground_y := float(scene.get_status().get("ground_y", 0.0))
		scene.set_player_pos_for_test(Vector2(interaction_rect.get_center().x, ground_y))
		_expect(scene.trigger_interaction_for_test(), "%s interaction should open a menu shell" % building_type)
		var status: Dictionary = scene.get_status()
		_expect(bool(status.get("menu_open", false)), "%s menu shell should report open" % building_type)
		_expect(str(status.get("active_menu_type", "")) == str(building_type), "%s menu shell should report the active menu type" % building_type)
		_expect(str(status.get("active_menu_title", "")) == str(expected_titles[building_type]), "%s menu shell should use the expected title" % building_type)
		var expected_action_labels: Array = expected_actions[building_type]
		if str(building_type) == "academy":
			expected_action_labels = ["스킬 수업 200G", "스킬 교환"]
		_expect(_string_arrays_equal(status.get("active_menu_actions", []), expected_action_labels), "%s menu shell should expose the expected action stubs" % building_type)
		scene.close_menu_for_test()


func _verify_nonblank_viewport(viewport: SubViewport) -> void:
	_expect(viewport != null and viewport.size == Vector2i(760, 750), "plaza viewport should keep the 760x750 game canvas contract")
	_verify_nonblank_asset_pixels()


func _verify_nonblank_asset_pixels() -> void:
	for path in PIXEL_SAMPLE_PATHS:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_expect(image != null and image.get_width() > 0 and image.get_height() > 0, "plaza pixel fallback should load %s" % path)
		if image == null:
			continue
		var lit_samples := 0
		var step_y: int = max(1, int(image.get_height() / 16))
		var step_x: int = max(1, int(image.get_width() / 16))
		for y in range(0, image.get_height(), step_y):
			for x in range(0, image.get_width(), step_x):
				var color: Color = image.get_pixel(x, y)
				if color.a > 0.05 and color.r + color.g + color.b > 0.20:
					lit_samples += 1
		_expect(lit_samples >= 8, "plaza pixel fallback should find visible nonblank pixels in %s" % path)


func _find_building(specs: Array, building_type: String) -> Dictionary:
	for spec_value in specs:
		if spec_value is Dictionary and str((spec_value as Dictionary).get("type", "")) == building_type:
			return (spec_value as Dictionary)
	return {}


func _send_key(scene: Control, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	scene.handle_plaza_input(event)


func _cleanup_save(path: String) -> void:
	var backup_path := path.trim_suffix(".cfg") + ".last_good.cfg"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))


func _string_arrays_equal(left_value: Variant, right_value: Variant) -> bool:
	if not (left_value is Array) or not (right_value is Array):
		return false
	var left := left_value as Array
	var right := right_value as Array
	if left.size() != right.size():
		return false
	for idx in range(left.size()):
		if str(left[idx]) != str(right[idx]):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
