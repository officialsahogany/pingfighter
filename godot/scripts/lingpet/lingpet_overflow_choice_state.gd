extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")

var pending := false
var active := false
var pending_pet_id := ""
var suspended_companion_pet_id := ""
var from_item_egg := false
var absorb_only := false
var compare_only := false


func reset() -> void:
	pending = false
	active = false
	pending_pet_id = ""
	suspended_companion_pet_id = ""
	from_item_egg = false
	absorb_only = false
	compare_only = false


func has_pending_or_active() -> bool:
	return pending or active


func is_active() -> bool:
	return bool(active)


func is_active_with_pending_pet() -> bool:
	return bool(active) and str(pending_pet_id) != ""


func is_item_egg_source() -> bool:
	return bool(from_item_egg)


func is_absorb_only() -> bool:
	return bool(absorb_only)


func get_pending_pet_id() -> String:
	return str(pending_pet_id)


func consume_commit_pet_id() -> String:
	var pet_id := str(pending_pet_id)
	reset()
	return pet_id


func consume_absorb_context() -> Dictionary:
	var context := {
		"pending_pet_id": str(pending_pet_id),
		"suspended_companion_pet_id": str(suspended_companion_pet_id),
		"from_item_egg": bool(from_item_egg),
		"absorb_only": bool(absorb_only),
		"compare_only": bool(compare_only),
	}
	reset()
	return context


func build_snapshot(collection_state: Object) -> Dictionary:
	var active_slot_index := 0
	if collection_state != null and collection_state.has_method("get_active_slot_index"):
		active_slot_index = int(collection_state.get_active_slot_index())
	var slot_entries: Array[Dictionary] = []
	if collection_state != null and collection_state.has_method("get_battle_slots"):
		var raw_slots: Variant = collection_state.get_battle_slots()
		if raw_slots is Array:
			for i in range((raw_slots as Array).size()):
				var slot_pet_id := str((raw_slots as Array)[i])
				slot_entries.append({
					"slot_index": i,
					"pet_id": slot_pet_id,
					"display_name": _get_pet_display_name(collection_state, slot_pet_id),
					"active": i == active_slot_index,
				})
	var pending_id := str(pending_pet_id)
	var preview_loadout := LingpetCatalog.build_default_loadout(pending_id)
	var preview_skill := LingpetCatalog.get_active_skill(
		pending_id,
		str(preview_loadout.get("active_skill_id", "")),
		maxi(1, int(preview_loadout.get("active_skill_level", 1)))
	)
	var pending_stats := {
		"patrol_speed_default": LingpetCatalog.get_stat(pending_id, "patrol_speed_default", 0.0),
		"patrol_speed_min": LingpetCatalog.get_stat(pending_id, "patrol_speed_min", 0.0),
		"patrol_speed_max": LingpetCatalog.get_stat(pending_id, "patrol_speed_max", 0.0),
		"catch_width": LingpetCatalog.get_stat(pending_id, "catch_width", 0.0),
		"catch_height": LingpetCatalog.get_stat(pending_id, "catch_height", 0.0),
		"defense_rate": LingpetCatalog.get_stat(pending_id, "defense_rate", 0.0),
		"appearance_rate": LingpetCatalog.get_stat(pending_id, "appearance_rate", 0.0),
		"hit_gauge_gain": LingpetCatalog.get_stat(pending_id, "hit_gauge_gain", 0.0),
	}
	var replacement_guardian := {
		"pet_id": pending_id,
		"display_name": _get_pet_display_name(collection_state, pending_id),
		"art_path": LingpetCatalog.get_visual_path(pending_id, "cutin_art"),
		"stats": pending_stats.duplicate(true),
		"active_skill_name": str(preview_skill.get("name", "")),
		"active_skill_description": str(preview_skill.get("description", "")),
		"active_skill_cooldown": float(preview_skill.get("cooldown", 0.0)),
		"active_skill_icon_path": str(preview_skill.get("icon_texture_path", "")),
		"active_skill_level": maxi(1, int(preview_loadout.get("active_skill_level", 1))),
		"passive_skill_name": "",
		"passive_skill_description": "",
		"passive_skill_icon_path": "",
		"passive_skill_level": 0,
		"pending_roll": not bool(absorb_only),
	}
	return {
		"active": bool(active),
		"pending_pet_id": pending_id,
		"pending_display_name": _get_pet_display_name(collection_state, pending_id),
		"pending_art_path": LingpetCatalog.get_visual_path(pending_id, "cutin_art"),
		"pending_stats": pending_stats,
		"slots": slot_entries,
		"active_slot_index": active_slot_index,
		"absorb_only": bool(absorb_only),
		"compare_only": bool(compare_only),
		"replacement_skill_name": str(preview_skill.get("name", "")),
		"replacement_skill_description": str(preview_skill.get("description", "")),
		"replacement_skill_cooldown": float(preview_skill.get("cooldown", 0.0)),
		"replacement_skill_icon_path": str(preview_skill.get("icon_texture_path", "")),
		"replacement_guardian": replacement_guardian,
	}


func begin_main_egg(suspended_pet_id: String) -> void:
	reset()
	suspended_companion_pet_id = suspended_pet_id


func begin_main_overflow(
	pet_id: String,
	only_absorb: bool = false,
	start_in_compare: bool = false
) -> void:
	pending = true
	active = false
	pending_pet_id = pet_id
	from_item_egg = false
	absorb_only = only_absorb
	compare_only = start_in_compare


func begin_item_egg_overflow(
	pet_id: String,
	suspended_pet_id: String = "",
	only_absorb: bool = false
) -> void:
	pending = true
	active = true
	pending_pet_id = pet_id
	suspended_companion_pet_id = suspended_pet_id
	from_item_egg = true
	absorb_only = only_absorb


func activate_after_cutin() -> bool:
	if pending and pending_pet_id != "":
		active = true
		return true
	return false


func resolve_after_acquire_cutin(item_egg_lifecycle_state: Object) -> bool:
	if (
		item_egg_lifecycle_state != null
		and item_egg_lifecycle_state.has_method("mark_absorb_ready_if_awaiting")
		and bool(item_egg_lifecycle_state.call("mark_absorb_ready_if_awaiting"))
	):
		return true
	return activate_after_cutin()


func _get_pet_display_name(collection_state: Object, pet_id: String) -> String:
	if collection_state == null or not collection_state.has_method("get_pet_display_name"):
		return pet_id
	return str(collection_state.get_pet_display_name(pet_id))
