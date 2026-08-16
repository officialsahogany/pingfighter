extends RefCounted

const SAVE_PATH := "user://guardian_codex.cfg"
const SAVE_SCHEMA_VERSION := 1
const META_SECTION := "meta"
const FIRST_SEEN_SECTION := "first_seen_pet_ids"
const DISCOVERY_SECTION := "discovery_events"

var save_path := SAVE_PATH
var last_load_summary := "not_loaded"
var last_save_summary := "not_saved"
var _loaded := false
var _load_blocked := false
var _first_seen_pet_ids: Dictionary = {}
var _discovery_events: Dictionary = {}


func set_save_path(path: String) -> void:
	var normalized := path.strip_edges()
	if normalized.is_empty():
		return
	save_path = normalized
	_reset_runtime_state()


func load() -> bool:
	_reset_runtime_state()
	_loaded = true
	if not FileAccess.file_exists(save_path):
		last_load_summary = "missing_empty_codex"
		return true
	var config := ConfigFile.new()
	var result := config.load(save_path)
	if result != OK:
		_load_blocked = true
		last_load_summary = "load_error_%d" % result
		return false
	var stored_version := int(config.get_value(META_SECTION, "version", 0))
	if stored_version <= 0 or stored_version > SAVE_SCHEMA_VERSION:
		_load_blocked = true
		last_load_summary = "unsupported_schema_%d" % stored_version
		return false
	_import_first_seen(config)
	_import_discovery_events(config)
	last_load_summary = "ok"
	return true


func save() -> bool:
	_ensure_loaded()
	if _load_blocked:
		last_save_summary = "blocked_after_load_error"
		return false
	var config := ConfigFile.new()
	config.set_value(META_SECTION, "version", SAVE_SCHEMA_VERSION)
	for pet_id in _sorted_keys(_first_seen_pet_ids):
		config.set_value(FIRST_SEEN_SECTION, pet_id, true)
	for discovery_id in _sorted_keys(_discovery_events):
		config.set_value(
			DISCOVERY_SECTION,
			discovery_id,
			str(_discovery_events.get(discovery_id, ""))
		)
	_ensure_save_parent_dir()
	var result := config.save(save_path)
	last_save_summary = "ok" if result == OK else "save_error_%d" % result
	return result == OK


func clear() -> bool:
	_reset_runtime_state()
	_loaded = true
	last_load_summary = "cleared_empty_codex"
	if not FileAccess.file_exists(save_path):
		last_save_summary = "cleared"
		return true
	var result := DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	last_save_summary = "cleared" if result == OK else "clear_error_%d" % result
	return result == OK


func record_first_seen(pet_id: String, discovery_id: String) -> Dictionary:
	_ensure_loaded()
	var normalized_pet_id := _normalize_pet_id(pet_id)
	var normalized_discovery_id := discovery_id.strip_edges()
	if _load_blocked:
		return _record_result(false, false, "blocked_after_load_error", normalized_pet_id, normalized_discovery_id)
	if normalized_pet_id.is_empty():
		return _record_result(false, false, "invalid_pet_id", normalized_pet_id, normalized_discovery_id)
	if normalized_discovery_id.is_empty():
		return _record_result(false, false, "invalid_discovery_id", normalized_pet_id, normalized_discovery_id)
	if _discovery_events.has(normalized_discovery_id):
		var committed_pet_id := str(_discovery_events.get(normalized_discovery_id, ""))
		if committed_pet_id != normalized_pet_id:
			return _record_result(false, false, "discovery_id_conflict", normalized_pet_id, normalized_discovery_id)
		return _record_result(true, false, "already_committed", normalized_pet_id, normalized_discovery_id)

	var was_first_seen := _first_seen_pet_ids.has(normalized_pet_id)
	_first_seen_pet_ids[normalized_pet_id] = true
	_discovery_events[normalized_discovery_id] = normalized_pet_id
	if save():
		return _record_result(
			true,
			not was_first_seen,
			"first_seen_committed" if not was_first_seen else "discovery_committed_existing_pet",
			normalized_pet_id,
			normalized_discovery_id
		)
	_discovery_events.erase(normalized_discovery_id)
	if not was_first_seen:
		_first_seen_pet_ids.erase(normalized_pet_id)
	return _record_result(false, false, "save_failed", normalized_pet_id, normalized_discovery_id)


func has_first_seen(pet_id: String) -> bool:
	_ensure_loaded()
	if _load_blocked:
		return false
	return _first_seen_pet_ids.has(_normalize_pet_id(pet_id))


func get_first_seen_pet_ids() -> Array[String]:
	_ensure_loaded()
	if _load_blocked:
		return []
	return _sorted_keys(_first_seen_pet_ids)


func get_summary() -> Dictionary:
	_ensure_loaded()
	return {
		"save_path": save_path,
		"schema_version": SAVE_SCHEMA_VERSION,
		"first_seen_count": _first_seen_pet_ids.size(),
		"discovery_event_count": _discovery_events.size(),
		"load": last_load_summary,
		"save": last_save_summary,
		"load_blocked": _load_blocked,
	}


func _ensure_loaded() -> void:
	if not _loaded:
		self.load()


func _ensure_save_parent_dir() -> void:
	var global_path := ProjectSettings.globalize_path(save_path)
	var parent_dir := global_path.get_base_dir()
	if parent_dir.is_empty() or DirAccess.dir_exists_absolute(parent_dir):
		return
	DirAccess.make_dir_recursive_absolute(parent_dir)


func _reset_runtime_state() -> void:
	last_load_summary = "not_loaded"
	last_save_summary = "not_saved"
	_loaded = false
	_load_blocked = false
	_first_seen_pet_ids.clear()
	_discovery_events.clear()


func _import_first_seen(config: ConfigFile) -> void:
	_first_seen_pet_ids.clear()
	if not config.has_section(FIRST_SEEN_SECTION):
		return
	for key_value in config.get_section_keys(FIRST_SEEN_SECTION):
		var pet_id := _normalize_pet_id(str(key_value))
		if not pet_id.is_empty() and bool(config.get_value(FIRST_SEEN_SECTION, key_value, false)):
			_first_seen_pet_ids[pet_id] = true


func _import_discovery_events(config: ConfigFile) -> void:
	_discovery_events.clear()
	if not config.has_section(DISCOVERY_SECTION):
		return
	for key_value in config.get_section_keys(DISCOVERY_SECTION):
		var discovery_id := str(key_value).strip_edges()
		var pet_id := _normalize_pet_id(str(config.get_value(DISCOVERY_SECTION, key_value, "")))
		if discovery_id.is_empty() or pet_id.is_empty():
			continue
		_discovery_events[discovery_id] = pet_id
		_first_seen_pet_ids[pet_id] = true


func _record_result(
	accepted: bool,
	changed: bool,
	reason: String,
	pet_id: String,
	discovery_id: String
) -> Dictionary:
	return {
		"accepted": accepted,
		"changed": changed,
		"reason": reason,
		"pet_id": pet_id,
		"discovery_id": discovery_id,
	}


func _normalize_pet_id(value: String) -> String:
	return value.strip_edges().to_lower()


func _sorted_keys(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key_value in source.keys():
		result.append(str(key_value))
	result.sort()
	return result
