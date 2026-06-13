extends SceneTree

const PlazaScenePacked := preload("res://scenes/plaza.tscn")
const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	_verify_bank_menu_transactions()

	if _failures.is_empty():
		print("plaza_bank_menu_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_bank_menu_transactions() -> void:
	var save_path := "user://plaza_bank_menu_smoke.cfg"
	_cleanup(save_path)
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.apply_stage_clear_progress(1, 250, true)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 750)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var scene := PlazaScenePacked.instantiate() as Control
	_expect(scene != null, "plaza scene should instantiate for bank menu smoke")
	if scene == null:
		viewport.queue_free()
		_cleanup(save_path)
		return
	viewport.add_child(scene)
	scene.configure({"current_stage": 1, "plaza_save_path": save_path}, Callable(), true)
	scene.update_plaza(1.0 / 60.0)

	var bank: Dictionary = _find_building(scene.get_building_specs_for_test(), "bank")
	_expect(not bank.is_empty(), "plaza should include a bank building")
	if bank.is_empty():
		viewport.queue_free()
		_cleanup(save_path)
		return
	var interaction_rect: Rect2 = bank.get("interaction_rect", Rect2())
	var ground_y := float(scene.get_status().get("ground_y", 0.0))
	scene.set_player_pos_for_test(Vector2(interaction_rect.get_center().x, ground_y))
	_expect(scene.trigger_interaction_for_test(), "bank interaction should open the bank menu")
	var status: Dictionary = scene.get_status()
	_expect(str(status.get("active_menu_type", "")) == "bank", "bank menu should be active")
	_expect(int(status.get("plaza_gold", 0)) == 250, "bank menu should read preloaded plaza gold")
	_expect(int(status.get("ap_current", 0)) == 4, "bank menu should read preloaded AP")

	_expect(scene.trigger_menu_action_for_test(0), "bank deposit action should execute")
	status = scene.get_status()
	_expect(int(status.get("plaza_gold", 0)) == 150, "bank deposit should subtract wallet gold")
	_expect(int(status.get("bank_deposit_gold", 0)) == 100, "bank deposit should add bank balance")
	_expect(int(status.get("ap_current", 0)) == 3, "first bank action should spend one AP")
	_expect(bool(status.get("active_menu_visit_ap_consumed", false)), "bank visit should remember AP was consumed")

	_expect(scene.trigger_menu_action_for_test(1), "bank withdraw action should execute")
	status = scene.get_status()
	_expect(int(status.get("plaza_gold", 0)) == 250, "same-visit withdraw should return wallet gold")
	_expect(int(status.get("bank_deposit_gold", 0)) == 0, "same-visit withdraw should clear bank balance")
	_expect(int(status.get("ap_current", 0)) == 3, "same menu visit should not spend AP twice")

	scene.close_menu_for_test()
	_expect(scene.trigger_interaction_for_test(), "bank menu should reopen for a new visit")
	_expect(scene.trigger_menu_action_for_test(0), "second bank visit deposit should execute")
	status = scene.get_status()
	_expect(int(status.get("plaza_gold", 0)) == 150, "second deposit should subtract wallet gold")
	_expect(int(status.get("bank_deposit_gold", 0)) == 100, "second deposit should persist bank balance")
	_expect(int(status.get("ap_current", 0)) == 2, "new bank visit should spend another AP once")

	scene.close_menu_for_test()
	_expect(scene.trigger_interaction_for_test(), "bank menu should reopen for interest")
	_expect(scene.trigger_menu_action_for_test(2), "bank interest action should execute")
	status = scene.get_status()
	_expect(int(status.get("plaza_gold", 0)) == 155, "bank interest should pay 5 percent to wallet")
	_expect(int(status.get("bank_deposit_gold", 0)) == 100, "bank interest should leave deposit principal")
	_expect(int(status.get("ap_current", 0)) == 1, "interest visit should spend one AP")
	_expect(not scene.trigger_menu_action_for_test(2), "same-stage interest should not pay twice")
	status = scene.get_status()
	_expect(int(status.get("plaza_gold", 0)) == 155, "repeated interest should leave wallet unchanged")
	_expect(int(status.get("ap_current", 0)) == 1, "repeated interest should not spend AP after the stage guard")

	viewport.queue_free()
	_cleanup(save_path)


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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
