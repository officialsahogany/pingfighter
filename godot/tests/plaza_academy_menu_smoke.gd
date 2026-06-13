extends SceneTree

const PlazaScenePacked := preload("res://scenes/plaza.tscn")
const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends Node2D

	var selected_character_type := "smasher"
	var current_stage := 1
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_gold := 0
	var runtime_perk_choice_active := false
	var item_perk_level_bonus := 0
	var viper_ignition_aura_active := false
	var ball_vel := Vector2.ZERO
	var player_collision_cooldown := 0.0


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
	_verify_academy_lesson_opens_runtime_perk_choice()
	_verify_failed_academy_lesson_does_not_spend()

	if _failures.is_empty():
		print("plaza_academy_menu_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_academy_lesson_opens_runtime_perk_choice() -> void:
	var save_path := "user://plaza_academy_menu_smoke.cfg"
	_cleanup(save_path)
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.apply_stage_clear_progress(1, 500, true)
	var owner := FakeOwner.new()
	root.add_child(owner)
	var runtime_state := RuntimePerkState.new()
	var runtime_catalog := RuntimePerkCatalog.new()
	var registry := FakeRegistry.new({
		"runtime_perk_state": runtime_state,
		"runtime_perk_catalog": runtime_catalog,
	})

	var viewport := _build_viewport()
	var scene := _build_scene(viewport, save_path, owner, registry)
	if scene == null:
		viewport.queue_free()
		owner.queue_free()
		_cleanup(save_path)
		return
	_open_building(scene, "academy")
	var status: Dictionary = scene.get_status()
	_expect(str(status.get("active_menu_type", "")) == "academy", "academy interaction should open the academy menu")
	_expect(_string_arrays_equal(status.get("active_menu_actions", []), ["스킬 수업 200G", "스킬 교환"]), "academy menu should expose the live lesson labels")

	_expect(scene.trigger_menu_action_for_test(0), "academy lesson should execute when gold/AP and runtime perk modules exist")
	status = scene.get_status()
	var snapshot: Dictionary = runtime_state.get_snapshot()
	_expect(not bool(status.get("menu_open", true)), "successful academy lesson should close the building menu before opening the perk modal")
	_expect(bool(status.get("runtime_perk_choice_active", false)), "academy lesson should open the runtime perk choice modal")
	_expect(bool(snapshot.get("choice_active", false)), "runtime perk state should mark the academy choice active")
	_expect(int(status.get("runtime_perk_choice_count", 0)) >= 1, "academy lesson should create at least one choice card")
	_expect(int(status.get("plaza_gold", 0)) == 300, "academy lesson should subtract 200G")
	_expect(int(status.get("ap_current", 0)) == 3, "first academy lesson should spend one AP")
	var summary: Dictionary = status.get("last_academy_transaction_summary", {})
	_expect(str(summary.get("reason", "")) == "ok", "academy summary should report ok")
	_expect(bool(summary.get("choice_opened", false)), "academy summary should record that the choice modal opened")

	scene.update_plaza(0.25)
	status = scene.get_status()
	var before_selected := int(status.get("runtime_perk_selected_index", -1))
	scene.handle_plaza_input(_key(KEY_RIGHT))
	status = scene.get_status()
	_expect(int(status.get("runtime_perk_selected_index", -1)) != before_selected, "academy modal input should route navigation to runtime perk state")
	var before_pos: Vector2 = status.get("player_pos", Vector2.ZERO)
	scene.move_player_for_test(Vector2.RIGHT, 1.0 / 60.0)
	var after_pos: Vector2 = scene.get_status().get("player_pos", Vector2.ZERO)
	_expect(after_pos.is_equal_approx(before_pos), "open academy choice modal should block plaza walking")

	viewport.queue_free()
	owner.queue_free()
	_cleanup(save_path)


func _verify_failed_academy_lesson_does_not_spend() -> void:
	var save_path := "user://plaza_academy_menu_smoke_fail.cfg"
	_cleanup(save_path)
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.apply_stage_clear_progress(1, 100, true)
	var owner := FakeOwner.new()
	root.add_child(owner)
	var runtime_state := RuntimePerkState.new()
	var runtime_catalog := RuntimePerkCatalog.new()
	var registry := FakeRegistry.new({
		"runtime_perk_state": runtime_state,
		"runtime_perk_catalog": runtime_catalog,
	})

	var viewport := _build_viewport()
	var scene := _build_scene(viewport, save_path, owner, registry)
	if scene == null:
		viewport.queue_free()
		owner.queue_free()
		_cleanup(save_path)
		return
	_open_building(scene, "academy")
	_expect(not scene.trigger_menu_action_for_test(0), "unaffordable academy lesson should fail")
	var status: Dictionary = scene.get_status()
	_expect(not bool(status.get("runtime_perk_choice_active", false)), "failed academy lesson should not open a perk choice")
	_expect(int(status.get("plaza_gold", 0)) == 100, "failed academy lesson should leave gold unchanged")
	_expect(int(status.get("ap_current", 0)) == 4, "failed academy lesson should not spend AP")
	_expect(not bool(status.get("active_menu_visit_ap_consumed", false)), "failed academy lesson should not mark the AP visit flag")

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
	_expect(scene != null, "plaza scene should instantiate for academy menu smoke")
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


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	return event


func _cleanup(path: String) -> void:
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
