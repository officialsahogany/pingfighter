extends SceneTree

const PlazaScenePacked := preload("res://scenes/plaza.tscn")
const SCENE_PATH := "res://scripts/plaza/plaza_scene.gd"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_scene_has_no_legacy_interior_fallback()
	await _verify_missing_interior_owner_is_recovered()
	if _failures.is_empty():
		print("plaza_interior_view_owner_recovery_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_scene_has_no_legacy_interior_fallback() -> void:
	var source := FileAccess.get_file_as_string(SCENE_PATH)
	for removed_method in [
		"_handle_menu_input",
		"_draw_building_menu",
		"_draw_interior_npc_panel",
		"_draw_interior_npc_texture",
		"_draw_interior_npc_placeholder",
		"_draw_interior_speech_panel",
		"_draw_menu_action_row",
		"_draw_text_shadow",
		"_get_menu_action_index_at",
		"_is_executable_menu_type",
	]:
		_expect(not source.contains("func %s(" % removed_method), "plaza scene should not retain legacy interior method %s" % removed_method)
	for removed_constant in [
		"INTERIOR_NPC_RECT",
		"INTERIOR_SPEECH_RECT",
		"MENU_PANEL_RECT",
		"MENU_CLOSE_RECT",
		"MENU_ACTION_ROW_START_Y",
		"MENU_ACTION_ROW_HEIGHT",
		"MENU_ACTION_ROW_STEP",
		"INTERIOR_GREETING_LINES",
	]:
		_expect(not source.contains(removed_constant), "plaza scene should not retain legacy interior constant %s" % removed_constant)
	_expect(source.contains("func _ensure_interior_view() -> bool:"), "plaza scene should expose one interior-owner recovery helper")


func _verify_missing_interior_owner_is_recovered() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 750)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var scene := PlazaScenePacked.instantiate() as Control
	_expect(scene != null, "plaza scene should instantiate")
	if scene == null:
		viewport.queue_free()
		return
	viewport.add_child(scene)
	var save_path := _smoke_save_path()
	_cleanup_save(save_path)
	scene.configure({"current_stage": 1, "plaza_save_path": save_path, "full_layout_for_test": true}, Callable(), true)
	scene.size = Vector2(760.0, 750.0)
	var bank := _find_building(scene.get_building_specs_for_test(), "bank")
	_expect(not bank.is_empty(), "full plaza layout should expose the bank")
	if not bank.is_empty():
		var interaction_rect: Rect2 = bank.get("interaction_rect", Rect2())
		var ground_y := float(scene.get_status().get("ground_y", 0.0))
		scene.set_player_pos_for_test(Vector2(interaction_rect.get_center().x, ground_y))
		_expect(scene.trigger_interaction_for_test(), "bank interaction should open its interior")
		_expect(bool(scene.get_status().get("menu_open", false)), "bank interaction should keep the menu session open")
		_expect(bool(scene.get_status().get("interior_view_active", false)), "bank interaction should create the dedicated interior owner")
		_expect(_count_interior_views(scene) == 1, "open menu should have exactly one interior owner")

		var old_view := scene.get_node_or_null("PlazaInteriorView")
		var old_instance_id := old_view.get_instance_id() if old_view != null else 0
		if old_view != null:
			old_view.free()
		_expect(not bool(scene.get_status().get("interior_view_active", true)), "forced owner loss should be visible before recovery")
		scene.update_plaza(0.0)
		var recovered_view := scene.get_node_or_null("PlazaInteriorView")
		_expect(recovered_view != null, "menu update should recreate a missing interior owner")
		_expect(recovered_view == null or recovered_view.get_instance_id() != old_instance_id, "recovery should create a fresh interior owner")
		_expect(bool(scene.get_status().get("interior_view_active", false)), "recovered interior should be active")
		_expect(_count_interior_views(scene) == 1, "recovery should not duplicate interior owners")

	viewport.queue_free()
	_cleanup_save(save_path)
	await process_frame


func _count_interior_views(scene: Node) -> int:
	var count := 0
	for child in scene.get_children():
		if child.name == &"PlazaInteriorView":
			count += 1
	return count


func _find_building(specs: Array, building_type: String) -> Dictionary:
	for spec_value in specs:
		if spec_value is Dictionary and str((spec_value as Dictionary).get("type", "")) == building_type:
			return spec_value as Dictionary
	return {}


func _smoke_save_path() -> String:
	return "res://.tmp/plaza_interior_view_owner_recovery_smoke_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]


func _cleanup_save(path: String) -> void:
	var backup_path := path.trim_suffix(".cfg") + ".last_good.cfg"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
