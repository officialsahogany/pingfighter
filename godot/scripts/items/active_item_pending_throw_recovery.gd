extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const THROW_WINDUP_ITEM_NAMES := {
	"grenade": true,
	"flare": true,
	"tear_gas": true,
	"dynamite": true,
	"molotov": true,
	"boomerang": true,
	"banana": true,
	"soap": true,
}

var pending_throw_item_backup: Dictionary = {}


func reset() -> void:
	pending_throw_item_backup.clear()


func restore_on_round_end(owner: Object, registry: Object, slot_controller: Object, throw_controller: Object) -> bool:
	var had_pending_windup: bool = _is_throw_windup_active(throw_controller)
	if throw_controller != null and throw_controller.has_method("cancel_pending_throw_windups"):
		throw_controller.cancel_pending_throw_windups()
	if pending_throw_item_backup.is_empty():
		return had_pending_windup

	var restored_item: Dictionary = _get_dict(pending_throw_item_backup.get("item", {})).duplicate(true)
	var restore_index: int = int(pending_throw_item_backup.get("index", 0))
	var prior_last_item_use_msec: int = int(pending_throw_item_backup.get("last_item_use_msec", -1000000))
	pending_throw_item_backup.clear()
	if owner == null or slot_controller == null or restored_item.is_empty() or not had_pending_windup:
		return had_pending_windup

	restored_item.erase("last_use")
	restored_item.erase("last_use_msec")
	slot_controller.last_item_use_msec = prior_last_item_use_msec
	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	restore_index = clampi(restore_index, 0, active_item_slots.size())
	active_item_slots.insert(restore_index, restored_item)
	owner.set("active_item_slots", active_item_slots)
	_select_slot(registry, restore_index)
	return true


func backup_pending_throw_item(
	item_data: Dictionary,
	slot_index: int,
	_owner: Object,
	_registry: Object,
	slot_controller: Object,
	throw_controller: Object
) -> void:
	var item_name: String = str(item_data.get("name", item_data.get("effect", "")))
	var effect_name: String = str(item_data.get("effect", item_name))
	if not bool(THROW_WINDUP_ITEM_NAMES.get(item_name, THROW_WINDUP_ITEM_NAMES.get(effect_name, false))):
		return
	if not _is_throw_windup_active(throw_controller):
		return
	var backup_item: Dictionary = item_data.duplicate(true)
	backup_item.erase("last_use")
	backup_item.erase("last_use_msec")
	pending_throw_item_backup = {
		"item": backup_item,
		"index": max(0, int(slot_index)),
		"last_item_use_msec": int(slot_controller.last_item_use_msec) if slot_controller != null else -1000000,
	}


func clear_backup_if_released(throw_controller: Object) -> void:
	if pending_throw_item_backup.is_empty():
		return
	if _is_throw_windup_active(throw_controller):
		return
	pending_throw_item_backup.clear()


func has_pending_backup() -> bool:
	return not pending_throw_item_backup.is_empty()


func _is_throw_windup_active(throw_controller: Object) -> bool:
	return throw_controller != null and throw_controller.has_method("is_throw_windup_active") and bool(throw_controller.is_throw_windup_active())


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _select_slot(registry: Object, slot_index: int) -> void:
	var hud_state: Object = _get_instance(registry, "active_item_hud_state")
	if hud_state != null and hud_state.has_method("set_selected_index"):
		hud_state.set_selected_index(slot_index)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
