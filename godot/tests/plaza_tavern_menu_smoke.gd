extends SceneTree

const PlazaScenePacked := preload("res://scenes/plaza.tscn")
const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	_verify_tavern_accept_and_report_flow()

	if _failures.is_empty():
		print("plaza_tavern_menu_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_tavern_accept_and_report_flow() -> void:
	var save_path := _smoke_save_path("tavern")
	_cleanup(save_path)
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.apply_stage_clear_progress(1, 0, true)

	var viewport := _build_viewport()
	var scene := _build_scene(viewport, save_path, 1)
	if scene == null:
		viewport.queue_free()
		_cleanup(save_path)
		return
	_open_building(scene, "tavern")
	var status: Dictionary = scene.get_status()
	_expect(str(status.get("active_menu_type", "")) == "tavern", "tavern interaction should open the tavern menu")
	_expect(_string_arrays_equal(status.get("active_menu_actions", []), ["의뢰 받기", "의뢰 보고"]), "tavern menu should expose accept/report actions")
	_expect(int(status.get("ap_current", 0)) == 4, "tavern menu should read preloaded AP")

	_expect(scene.trigger_menu_action_for_test(0), "tavern accept should execute")
	status = scene.get_status()
	_expect(int(status.get("ap_current", 0)) == 3, "first tavern accept should spend one AP")
	_expect(bool(status.get("active_menu_visit_ap_consumed", false)), "tavern visit should remember AP was consumed")
	var active_quest: Dictionary = status.get("tavern_active_quest", {})
	_expect(not active_quest.is_empty(), "tavern accept should expose the active quest in scene status")
	var quest_id := str(active_quest.get("id", ""))
	var quest_reward := int(active_quest.get("reward_gold", 0))
	_expect(quest_id != "", "tavern accepted quest should have a persistent id")
	_expect(quest_reward > 0, "tavern accepted quest should carry a reward")
	var accept_summary: Dictionary = status.get("last_tavern_transaction_summary", {})
	_expect(str(accept_summary.get("reason", "")) == "ok", "tavern accept summary should report ok")

	_expect(not scene.trigger_menu_action_for_test(1), "same-stage tavern report should not complete")
	status = scene.get_status()
	var early_summary: Dictionary = status.get("last_tavern_transaction_summary", {})
	_expect(str(early_summary.get("reason", "")) == "quest_in_progress", "same-stage tavern report should be marked in progress")
	_expect(int(status.get("ap_current", 0)) == 3, "failed same-stage tavern report should not spend AP")

	viewport.queue_free()
	var progress_store := PlazaSaveStore.new()
	progress_store.set_save_path(save_path)
	progress_store.apply_stage_clear_progress(2, 50, true)

	var report_viewport := _build_viewport()
	var report_scene := _build_scene(report_viewport, save_path, 2)
	if report_scene == null:
		report_viewport.queue_free()
		_cleanup(save_path)
		return
	_open_building(report_scene, "tavern")
	status = report_scene.get_status()
	_expect(str((status.get("tavern_active_quest", {}) as Dictionary).get("id", "")) == quest_id, "tavern active quest should survive plaza re-entry")
	_expect(int(status.get("plaza_gold", 0)) == 50, "next stage clear should transfer gold before tavern report")
	_expect(int(status.get("ap_current", 0)) == 4, "next stage clear should grant AP before tavern report")
	_expect(report_scene.trigger_menu_action_for_test(1), "later-stage tavern report should execute")
	status = report_scene.get_status()
	_expect(int(status.get("plaza_gold", 0)) == 50 + quest_reward, "tavern report should add the quest reward to wallet gold")
	_expect(int(status.get("ap_current", 0)) == 3, "first tavern report visit should spend one AP")
	_expect((status.get("tavern_active_quest", {}) as Dictionary).is_empty(), "tavern report should clear the active quest")
	var report_summary: Dictionary = status.get("last_tavern_transaction_summary", {})
	_expect(str(report_summary.get("reason", "")) == "ok", "tavern report summary should report ok")
	_expect(int(report_summary.get("delta_gold", 0)) == quest_reward, "tavern report summary should expose the reward delta")

	report_viewport.queue_free()
	_cleanup(save_path)


func _build_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 750)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func _build_scene(viewport: SubViewport, save_path: String, stage_id: int) -> Control:
	var scene := PlazaScenePacked.instantiate() as Control
	_expect(scene != null, "plaza scene should instantiate for tavern menu smoke")
	if scene == null:
		return null
	viewport.add_child(scene)
	scene.configure({"current_stage": stage_id, "plaza_save_path": save_path, "full_layout_for_test": true}, Callable(), true)
	scene.update_plaza(1.0 / 60.0)
	return scene


func _open_building(scene: Control, building_type: String) -> void:
	var building: Dictionary = _find_building(scene.get_building_specs_for_test(), building_type)
	_expect(not building.is_empty(), "plaza should include a %s building" % building_type)
	if building.is_empty():
		return
	var interaction_rect: Rect2 = building.get("interaction_rect", Rect2())
	var ground_y := float(scene.get_status().get("ground_y", 0.0))
	scene.set_player_pos_for_test(Vector2(interaction_rect.get_center().x, ground_y))
	_expect(scene.trigger_interaction_for_test(), "%s interaction should open the menu" % building_type)


func _find_building(specs: Array[Dictionary], building_type: String) -> Dictionary:
	for spec in specs:
		if str(spec.get("type", "")) == building_type:
			return spec
	return {}


func _cleanup(path: String) -> void:
	var backup_path := path.trim_suffix(".cfg") + ".last_good.cfg"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))


func _smoke_save_path(slug: String) -> String:
	return "res://.tmp/plaza_tavern_menu_smoke_%s_%d_%d.cfg" % [
		slug,
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]


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
