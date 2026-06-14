extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")

const SAVE_PATH := "user://lingpet_save.cfg"
const SAVE_SCHEMA_VERSION := 1
const META_SECTION := "meta"
const LINGPET_SECTION := "lingpet"
const SNAPSHOT_KEY := "snapshot"

var save_path := SAVE_PATH
var last_load_summary := "not_loaded"
var last_save_summary := "not_saved"


func set_save_path(path: String) -> void:
	if path.strip_edges() != "":
		save_path = path


func load_snapshot() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		last_load_summary = "missing"
		return {}
	var config := ConfigFile.new()
	var result: int = config.load(save_path)
	if result != OK:
		last_load_summary = "load_error_%d" % result
		return {}
	var value: Variant = config.get_value(LINGPET_SECTION, SNAPSHOT_KEY, {})
	if value is Dictionary:
		last_load_summary = "ok"
		var snapshot: Dictionary = value
		return snapshot.duplicate(true)
	last_load_summary = "invalid_snapshot"
	return {}


func save_snapshot(snapshot: Dictionary) -> bool:
	if _is_volatile_run_snapshot(snapshot):
		return clear_snapshot("cleared_run_state")
	if not _should_save_snapshot(snapshot):
		last_save_summary = "skipped_empty"
		return false
	var config := ConfigFile.new()
	config.set_value(META_SECTION, "version", SAVE_SCHEMA_VERSION)
	config.set_value(LINGPET_SECTION, SNAPSHOT_KEY, snapshot.duplicate(true))
	var result: int = config.save(save_path)
	last_save_summary = "ok" if result == OK else "save_error_%d" % result
	return result == OK


func clear_snapshot(summary: String = "cleared") -> bool:
	if not FileAccess.file_exists(save_path):
		last_save_summary = summary
		return true
	var result: int = DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	last_save_summary = summary if result == OK else "clear_error_%d" % result
	return result == OK


func restore_runtime(owner: Object, registry: Object) -> Dictionary:
	var snapshot: Dictionary = load_snapshot()
	if snapshot.is_empty():
		return {
			"restored": false,
			"reason": last_load_summary,
		}
	var runtime: Object = _get_lingpet_runtime(registry)
	if runtime == null or not runtime.has_method("apply_save_snapshot"):
		return {
			"restored": false,
			"reason": "missing_runtime",
		}
	if _is_volatile_run_snapshot(snapshot):
		clear_snapshot("cleared_run_state_on_entry")
		var reset_result: Dictionary = runtime.apply_save_snapshot({
			"pet_id": LingpetCatalog.get_default_pet_id(),
			"state": "egg",
			"hatch_hits": 0,
			"required_hits": LingpetCatalog.get_required_hits(LingpetCatalog.get_default_pet_id()),
			"owned_pet_ids": [],
			"battle_slot_pet_ids": ["", "", ""],
			"active_slot_index": 0,
		}, owner, registry)
		reset_result["loaded_from_file"] = true
		reset_result["load_summary"] = last_load_summary
		reset_result["reason"] = "run_state_reset_on_entry"
		return reset_result
	var result: Dictionary = runtime.apply_save_snapshot(snapshot, owner, registry)
	result["loaded_from_file"] = true
	result["load_summary"] = last_load_summary
	return result


func save_runtime(_owner: Object, registry: Object) -> bool:
	var runtime: Object = _get_lingpet_runtime(registry)
	if runtime == null or not runtime.has_method("get_save_snapshot"):
		last_save_summary = "missing_runtime"
		return false
	var snapshot: Variant = runtime.get_save_snapshot()
	if snapshot is Dictionary:
		return save_snapshot(snapshot)
	last_save_summary = "invalid_runtime_snapshot"
	return false


func get_summary() -> Dictionary:
	return {
		"save_path": save_path,
		"load": last_load_summary,
		"save": last_save_summary,
	}


func _get_lingpet_runtime(registry: Object) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance("lingpet_egg_runtime")


func _should_save_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	if str(snapshot.get("state", "none")) != "none":
		return true
	if str(snapshot.get("active_pet_id", "")) != "":
		return true
	var owned_ids: Variant = snapshot.get("owned_pet_ids", [])
	if owned_ids is Array and not (owned_ids as Array).is_empty():
		return true
	var slot_ids: Variant = snapshot.get("battle_slot_pet_ids", snapshot.get("lingpet_slots", []))
	return slot_ids is Array and _has_any_slot(slot_ids as Array)


func _is_volatile_run_snapshot(snapshot: Dictionary) -> bool:
	var state: String = str(snapshot.get("state", "none")).strip_edges().to_lower()
	if state == "egg" or state == "hatching" or state == "companion" or state == "active" or state == "owned" or state == "hatched":
		return true
	if str(snapshot.get("active_pet_id", "")) != "":
		return true
	var owned_ids: Variant = snapshot.get("owned_pet_ids", [])
	if owned_ids is Array and not (owned_ids as Array).is_empty():
		return true
	var slot_ids: Variant = snapshot.get("battle_slot_pet_ids", snapshot.get("lingpet_slots", []))
	return slot_ids is Array and _has_any_slot(slot_ids as Array)


func _has_any_slot(slots: Array) -> bool:
	for raw_id in slots:
		if str(raw_id).strip_edges() != "":
			return true
	return false
