extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")


func apply_debug_spawn_menu_result(
	result: Dictionary,
	owner: Object,
	registry: Object,
	item_catalog: Object,
	slot_controller: Object,
	effect_controller: Object
) -> bool:
	var item_name: String = str(result.get("item_name", ""))
	var delta: int = int(result.get("delta", 0))
	if item_name != "":
		adjust_debug_item_quantity(item_name, delta, owner, registry, item_catalog, slot_controller, effect_controller)
	return bool(result.get("handled", false))


func debug_add_item_to_slot(
	item_name: String,
	owner: Object,
	registry: Object,
	item_catalog: Object,
	slot_controller: Object,
	effect_controller: Object
) -> bool:
	return grant_item_to_slot(item_name, owner, registry, item_catalog, slot_controller, effect_controller, false)


func debug_remove_item_from_slot(item_name: String, owner: Object, registry: Object) -> bool:
	if owner == null or item_name == "":
		return false
	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	for i in range(active_item_slots.size() - 1, -1, -1):
		var item_value: Variant = active_item_slots[i]
		if not item_value_matches_name(item_value, item_name):
			continue
		active_item_slots.remove_at(i)
		owner.set("active_item_slots", active_item_slots)
		_select_slot(registry, max(0, min(i, active_item_slots.size() - 1)))
		return true
	return false


func adjust_debug_item_quantity(
	item_name: String,
	delta: int,
	owner: Object,
	registry: Object,
	item_catalog: Object,
	slot_controller: Object,
	effect_controller: Object
) -> int:
	var changed := 0
	if delta > 0:
		for _i in range(delta):
			if not debug_add_item_to_slot(item_name, owner, registry, item_catalog, slot_controller, effect_controller):
				break
			changed += 1
	elif delta < 0:
		for _i in range(abs(delta)):
			if not debug_remove_item_from_slot(item_name, owner, registry):
				break
			changed -= 1
	return changed


func get_debug_item_counts(owner: Object) -> Dictionary:
	var counts: Dictionary = {}
	if owner == null:
		return counts
	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	for item_value in active_item_slots:
		if not (item_value is Dictionary):
			continue
		var item_data: Dictionary = item_value
		var item_name: String = str(item_data.get("name", ""))
		var effect_name: String = str(item_data.get("effect", ""))
		if item_name != "":
			counts[item_name] = int(counts.get(item_name, 0)) + 1
		if effect_name != "" and effect_name != item_name:
			counts[effect_name] = int(counts.get(effect_name, 0)) + 1
	return counts


func item_value_matches_name(item_value: Variant, item_name: String) -> bool:
	if not (item_value is Dictionary):
		return false
	var item_data: Dictionary = item_value
	return str(item_data.get("name", "")) == item_name or str(item_data.get("effect", "")) == item_name


func grant_item_to_slot(
	item_name: String,
	owner: Object,
	registry: Object,
	item_catalog: Object,
	slot_controller: Object,
	effect_controller: Object,
	allow_overflow: bool = false
) -> bool:
	if owner == null or item_catalog == null or slot_controller == null:
		return false
	var item_data: Dictionary = item_catalog.build_item_by_name(item_name)
	if item_data.is_empty():
		return false
	return bool(slot_controller.append_item_data(
		owner,
		item_data,
		registry,
		allow_overflow,
		_build_can_store_callback(effect_controller)
	))


func fill_empty_slots_with_item(
	item_name: String,
	owner: Object,
	registry: Object,
	item_catalog: Object,
	slot_controller: Object,
	effect_controller: Object,
	fill_limit: int = 9
) -> int:
	if owner == null:
		return 0
	var added := 0
	for _i in range(max(0, fill_limit)):
		if not debug_add_item_to_slot(item_name, owner, registry, item_catalog, slot_controller, effect_controller):
			break
		added += 1
	return added


func _build_can_store_callback(effect_controller: Object) -> Callable:
	if effect_controller != null and effect_controller.has_method("can_store_item"):
		return Callable(effect_controller, "can_store_item")
	return Callable()


func _select_slot(registry: Object, slot_index: int) -> void:
	var hud_state: Object = _get_instance(registry, "active_item_hud_state")
	if hud_state != null and hud_state.has_method("set_selected_index"):
		hud_state.set_selected_index(slot_index)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
