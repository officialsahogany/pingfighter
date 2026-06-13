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
	_verify_gacha_pull_transactions()
	_verify_failed_gacha_actions_do_not_spend_ap()

	if _failures.is_empty():
		print("plaza_gacha_menu_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_gacha_pull_transactions() -> void:
	var save_path := "user://plaza_gacha_menu_smoke.cfg"
	_cleanup(save_path)
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.apply_stage_clear_progress(1, 400, true)
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
	_open_building(scene, "gacha")
	var status: Dictionary = scene.get_status()
	_expect(str(status.get("active_menu_type", "")) == "gacha", "gacha interaction should open the gacha menu")
	_expect(int(status.get("plaza_gold", 0)) == 400, "gacha menu should read preloaded plaza gold")
	_expect(int(status.get("ap_current", 0)) == 4, "gacha menu should read preloaded AP")

	scene.force_gacha_item_for_test("banana")
	_expect(scene.trigger_menu_action_for_test(0), "forced banana gacha pull should execute")
	status = scene.get_status()
	_expect(owner.active_item_slots.size() == 1, "gacha pull should append one active item")
	_expect(str((owner.active_item_slots[0] as Dictionary).get("name", "")) == "banana", "gacha pull should grant the forced item")
	_expect(int(status.get("plaza_gold", 0)) == 250, "gacha pull should subtract 150G")
	_expect(int(status.get("ap_current", 0)) == 3, "first gacha pull should spend one AP")
	_expect(bool(status.get("active_menu_visit_ap_consumed", false)), "gacha visit should remember AP was consumed")
	var first_summary: Dictionary = status.get("last_gacha_transaction_summary", {})
	_expect(str(first_summary.get("item_name", "")) == "banana", "gacha summary should record the pulled item")

	scene.force_gacha_item_for_test("wall")
	_expect(scene.trigger_menu_action_for_test(0), "same-visit wall gacha pull should execute")
	status = scene.get_status()
	_expect(owner.active_item_slots.size() == 2, "same-visit gacha pull should append another item")
	_expect(str((owner.active_item_slots[1] as Dictionary).get("name", "")) == "wall", "same-visit gacha pull should grant the next forced item")
	_expect(int(status.get("plaza_gold", 0)) == 100, "same-visit gacha pull should subtract another 150G")
	_expect(int(status.get("ap_current", 0)) == 3, "same gacha visit should not spend AP twice")

	viewport.queue_free()
	owner.queue_free()
	_cleanup(save_path)


func _verify_failed_gacha_actions_do_not_spend_ap() -> void:
	var save_path := "user://plaza_gacha_menu_smoke_fail.cfg"
	_cleanup(save_path)
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.apply_stage_clear_progress(1, 100, true)
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
	_open_building(scene, "gacha")
	scene.force_gacha_item_for_test("boomerang")
	_expect(not scene.trigger_menu_action_for_test(0), "unaffordable gacha pull should fail")
	var status: Dictionary = scene.get_status()
	_expect(owner.active_item_slots.is_empty(), "failed gacha pull should not grant an active item")
	_expect(int(status.get("plaza_gold", 0)) == 100, "failed gacha pull should leave gold unchanged")
	_expect(int(status.get("ap_current", 0)) == 4, "failed gacha pull should not spend AP")
	_expect(not bool(status.get("active_menu_visit_ap_consumed", false)), "failed gacha pull should not mark the AP visit flag")

	viewport.queue_free()
	owner.queue_free()
	_cleanup(save_path)

	var full_path := "user://plaza_gacha_menu_smoke_full.cfg"
	_cleanup(full_path)
	var full_store := PlazaSaveStore.new()
	full_store.set_save_path(full_path)
	full_store.apply_stage_clear_progress(1, 400, true)
	var full_owner := FakeOwner.new()
	root.add_child(full_owner)
	var full_runtime := ActiveItemRuntime.new()
	var full_registry := FakeRegistry.new({"active_item_runtime": full_runtime})
	_expect(full_runtime.grant_item_to_slot("banana", full_owner, full_registry, false), "fixture should grant first active item")
	_expect(full_runtime.grant_item_to_slot("wall", full_owner, full_registry, false), "fixture should grant second active item")
	_expect(full_runtime.grant_item_to_slot("boomerang", full_owner, full_registry, false), "fixture should grant third active item")

	var full_viewport := _build_viewport()
	var full_scene := _build_scene(full_viewport, full_path, full_owner, full_registry)
	if full_scene == null:
		full_viewport.queue_free()
		full_owner.queue_free()
		_cleanup(full_path)
		return
	_open_building(full_scene, "gacha")
	full_scene.force_gacha_item_for_test("soap")
	_expect(not full_scene.trigger_menu_action_for_test(0), "full-slot gacha pull should fail before payment")
	status = full_scene.get_status()
	_expect(full_owner.active_item_slots.size() == 3, "full-slot gacha failure should keep existing items")
	_expect(int(status.get("plaza_gold", 0)) == 400, "full-slot gacha failure should leave gold unchanged")
	_expect(int(status.get("ap_current", 0)) == 4, "full-slot gacha failure should not spend AP")

	full_viewport.queue_free()
	full_owner.queue_free()
	_cleanup(full_path)


func _build_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 750)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func _build_scene(viewport: SubViewport, save_path: String, owner: Object, registry: Object) -> Control:
	var scene := PlazaScenePacked.instantiate() as Control
	_expect(scene != null, "plaza scene should instantiate for gacha menu smoke")
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
