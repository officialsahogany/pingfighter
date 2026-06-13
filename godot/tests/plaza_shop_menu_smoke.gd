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
	_verify_shop_buy_sell_transactions()
	_verify_failed_shop_action_does_not_spend_ap()

	if _failures.is_empty():
		print("plaza_shop_menu_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_shop_buy_sell_transactions() -> void:
	var save_path := "user://plaza_shop_menu_smoke.cfg"
	_cleanup(save_path)
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.apply_stage_clear_progress(1, 300, true)
	var owner := FakeOwner.new()
	root.add_child(owner)
	var active_item_runtime := ActiveItemRuntime.new()
	var registry := FakeRegistry.new({"active_item_runtime": active_item_runtime})

	var viewport := _build_viewport()
	var scene := _build_scene(viewport, save_path, owner, registry)
	if scene == null:
		viewport.queue_free()
		owner.queue_free()
		_cleanup(save_path)
		return
	_open_building(scene, "shop")
	var status: Dictionary = scene.get_status()
	_expect(str(status.get("active_menu_type", "")) == "shop", "shop interaction should open the shop menu")
	_expect(int(status.get("plaza_gold", 0)) == 300, "shop menu should read preloaded plaza gold")
	_expect(int(status.get("ap_current", 0)) == 4, "shop menu should read preloaded AP")

	_expect(scene.trigger_menu_action_for_test(0), "shop wall purchase should execute")
	status = scene.get_status()
	_expect(owner.active_item_slots.size() == 1, "wall purchase should append one active item")
	_expect(str((owner.active_item_slots[0] as Dictionary).get("name", "")) == "wall", "wall purchase should grant wall")
	_expect(int(status.get("plaza_gold", 0)) == 220, "wall purchase should subtract 80G")
	_expect(int(status.get("ap_current", 0)) == 3, "first shop transaction should spend one AP")
	_expect(bool(status.get("active_menu_visit_ap_consumed", false)), "shop visit should remember AP was consumed")

	_expect(scene.trigger_menu_action_for_test(1), "same-visit boomerang purchase should execute")
	status = scene.get_status()
	_expect(owner.active_item_slots.size() == 2, "boomerang purchase should append another active item")
	_expect(str((owner.active_item_slots[1] as Dictionary).get("name", "")) == "boomerang", "boomerang purchase should grant boomerang")
	_expect(int(status.get("plaza_gold", 0)) == 100, "boomerang purchase should subtract 120G")
	_expect(int(status.get("ap_current", 0)) == 3, "same shop visit should not spend AP twice")

	scene.close_menu_for_test()
	_open_building(scene, "shop")
	_expect(scene.trigger_menu_action_for_test(2), "shop sale should execute")
	status = scene.get_status()
	_expect(owner.active_item_slots.size() == 1, "shop sale should remove one active item")
	_expect(str((owner.active_item_slots[0] as Dictionary).get("name", "")) == "wall", "shop sale should remove the last active item first")
	_expect(int(status.get("plaza_gold", 0)) == 160, "boomerang sale should add 60G")
	_expect(int(status.get("ap_current", 0)) == 2, "new shop visit sale should spend one AP")

	viewport.queue_free()
	owner.queue_free()
	_cleanup(save_path)


func _verify_failed_shop_action_does_not_spend_ap() -> void:
	var save_path := "user://plaza_shop_menu_smoke_fail.cfg"
	_cleanup(save_path)
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.apply_stage_clear_progress(1, 90, true)
	var owner := FakeOwner.new()
	root.add_child(owner)
	var active_item_runtime := ActiveItemRuntime.new()
	var registry := FakeRegistry.new({"active_item_runtime": active_item_runtime})

	var viewport := _build_viewport()
	var scene := _build_scene(viewport, save_path, owner, registry)
	if scene == null:
		viewport.queue_free()
		owner.queue_free()
		_cleanup(save_path)
		return
	_open_building(scene, "shop")
	_expect(not scene.trigger_menu_action_for_test(1), "unaffordable boomerang purchase should fail")
	var status: Dictionary = scene.get_status()
	_expect(owner.active_item_slots.is_empty(), "failed purchase should not grant an active item")
	_expect(int(status.get("plaza_gold", 0)) == 90, "failed purchase should leave gold unchanged")
	_expect(int(status.get("ap_current", 0)) == 4, "failed purchase should not spend AP")
	_expect(not bool(status.get("active_menu_visit_ap_consumed", false)), "failed purchase should not mark the shop visit AP flag")

	_expect(scene.trigger_menu_action_for_test(0), "first successful transaction after a no-op should execute")
	status = scene.get_status()
	_expect(owner.active_item_slots.size() == 1, "successful wall purchase should grant after failed action")
	_expect(int(status.get("plaza_gold", 0)) == 10, "successful wall purchase should subtract 80G")
	_expect(int(status.get("ap_current", 0)) == 3, "first successful transaction should spend AP after failed action")

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
	_expect(scene != null, "plaza scene should instantiate for shop menu smoke")
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
