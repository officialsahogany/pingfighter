extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const PlazaScenePacked := preload("res://scenes/plaza.tscn")
const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends Node2D

	var active_item_slots: Array = []


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_run()


func _run() -> void:
	_verify_blacksmith_success_fail_and_maintain()
	_verify_failed_blacksmith_action_does_not_spend_ap()

	if _failures.is_empty():
		print("plaza_blacksmith_menu_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_blacksmith_success_fail_and_maintain() -> void:
	var save_path := "user://plaza_blacksmith_menu_smoke.cfg"
	_cleanup(save_path)
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.apply_stage_clear_progress(1, 500, true)
	var owner := FakeOwner.new()
	root.add_child(owner)
	var active_item_runtime := ActiveItemRuntime.new()
	var registry := FakeRegistry.new({"active_item_runtime": active_item_runtime})
	_expect(active_item_runtime.grant_item_to_slot("wall", owner, registry, false), "fixture should grant a real active item")

	var viewport := _build_viewport()
	var scene := _build_scene(viewport, save_path, owner, registry)
	if scene == null:
		viewport.queue_free()
		owner.queue_free()
		_cleanup(save_path)
		return
	_open_building(scene, "blacksmith")
	var status: Dictionary = scene.get_status()
	_expect(str(status.get("active_menu_type", "")) == "blacksmith", "blacksmith interaction should open the blacksmith menu")
	_expect(int(status.get("plaza_gold", 0)) == 500, "blacksmith menu should read preloaded plaza gold")
	_expect(int(status.get("ap_current", 0)) == 4, "blacksmith menu should read preloaded AP")

	scene.force_blacksmith_roll_for_test(1)
	_expect(scene.trigger_menu_action_for_test(0), "forced success enhancement should execute")
	status = scene.get_status()
	var wall_item: Dictionary = owner.active_item_slots[0]
	_expect(int(wall_item.get("enhancement_level", 0)) == 1, "success should raise the active item enhancement level")
	_expect(int(wall_item.get("enhancement_bonus_pct", 0)) == 10, "success should write the +1 enhancement bonus")
	_expect(int(status.get("plaza_gold", 0)) == 400, "success should charge the +0 enhancement cost")
	_expect(int(status.get("ap_current", 0)) == 3, "first blacksmith attempt should spend one AP")
	_expect(bool(status.get("active_menu_visit_ap_consumed", false)), "blacksmith visit should remember AP was consumed")

	scene.force_blacksmith_roll_for_test(99)
	_expect(scene.trigger_menu_action_for_test(0), "same-visit forced fail should execute")
	status = scene.get_status()
	wall_item = owner.active_item_slots[0]
	_expect(int(wall_item.get("enhancement_level", 0)) == 1, "fail should keep the item and its enhancement level")
	_expect(int(wall_item.get("enhancement_bonus_pct", 0)) == 10, "fail should keep the existing bonus")
	_expect(int(status.get("plaza_gold", 0)) == 250, "fail should still charge the +1 enhancement cost")
	_expect(int(status.get("ap_current", 0)) == 3, "same blacksmith visit should not spend AP twice")
	var fail_summary: Dictionary = status.get("last_blacksmith_transaction_summary", {})
	_expect(str(fail_summary.get("result", "")) == "fail", "forced fail should report a fail result")

	scene.close_menu_for_test()
	_open_building(scene, "blacksmith")
	scene.force_blacksmith_roll_for_test(80)
	_expect(scene.trigger_menu_action_for_test(0), "new-visit forced maintain should execute")
	status = scene.get_status()
	wall_item = owner.active_item_slots[0]
	_expect(int(wall_item.get("enhancement_level", 0)) == 1, "maintain should keep the current enhancement level")
	_expect(int(status.get("plaza_gold", 0)) == 100, "maintain should charge the +1 enhancement cost")
	_expect(int(status.get("ap_current", 0)) == 2, "new blacksmith visit should spend one AP")
	var maintain_summary: Dictionary = status.get("last_blacksmith_transaction_summary", {})
	_expect(str(maintain_summary.get("result", "")) == "maintain", "forced maintain should report a maintain result")

	viewport.queue_free()
	owner.queue_free()
	_cleanup(save_path)


func _verify_failed_blacksmith_action_does_not_spend_ap() -> void:
	var save_path := "user://plaza_blacksmith_menu_smoke_fail.cfg"
	_cleanup(save_path)
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.apply_stage_clear_progress(1, 90, true)
	var owner := FakeOwner.new()
	root.add_child(owner)
	var active_item_runtime := ActiveItemRuntime.new()
	var registry := FakeRegistry.new({"active_item_runtime": active_item_runtime})
	_expect(active_item_runtime.grant_item_to_slot("wall", owner, registry, false), "fixture should grant a real active item for failure checks")

	var viewport := _build_viewport()
	var scene := _build_scene(viewport, save_path, owner, registry)
	if scene == null:
		viewport.queue_free()
		owner.queue_free()
		_cleanup(save_path)
		return
	_open_building(scene, "blacksmith")
	_expect(not scene.trigger_menu_action_for_test(0), "unaffordable enhancement should fail")
	var status: Dictionary = scene.get_status()
	_expect(int(status.get("plaza_gold", 0)) == 90, "failed enhancement should leave gold unchanged")
	_expect(int(status.get("ap_current", 0)) == 4, "failed enhancement should not spend AP")
	_expect(not bool(status.get("active_menu_visit_ap_consumed", false)), "failed enhancement should not mark the AP visit flag")
	_expect(int((owner.active_item_slots[0] as Dictionary).get("enhancement_level", 0)) == 0, "failed enhancement should leave the item unchanged")

	owner.active_item_slots.clear()
	_expect(not scene.trigger_menu_action_for_test(0), "missing target enhancement should fail")
	status = scene.get_status()
	_expect(int(status.get("ap_current", 0)) == 4, "missing target should not spend AP")

	viewport.queue_free()
	owner.queue_free()
	_cleanup(save_path)


func _build_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 750)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func _build_scene(viewport: SubViewport, save_path: String, owner: Object, registry: Object) -> Control:
	var scene := PlazaScenePacked.instantiate() as Control
	_expect(scene != null, "plaza scene should instantiate for blacksmith menu smoke")
	if scene == null:
		return null
	viewport.add_child(scene)
	scene.configure({
		"current_stage": 1,
		"plaza_save_path": save_path,
		"runtime_owner": owner,
		"runtime_registry": registry,
	}, Callable(), true)
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
