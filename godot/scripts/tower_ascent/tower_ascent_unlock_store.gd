extends RefCounted

const SAVE_PATH := "user://tower_ascent_unlocks.cfg"
const SAVE_SCHEMA_VERSION := 1
const META_SECTION := "meta"
const UNLOCK_SECTION := "unlock"
const DEFAULT_UNLOCKED_KEY := "default_unlocked"
const OVERRIDES_KEY := "overrides"

var save_path := SAVE_PATH
var last_load_summary := "not_loaded"
var last_save_summary := "not_saved"
var _loaded := false
var _load_blocked := false
var _default_unlocked := true
var _overrides: Dictionary = {}


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
		last_load_summary = "missing_default_all_unlocked"
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
	_default_unlocked = bool(config.get_value(
		UNLOCK_SECTION,
		DEFAULT_UNLOCKED_KEY,
		true
	))
	_import_overrides(config.get_value(UNLOCK_SECTION, OVERRIDES_KEY, {}))
	last_load_summary = "ok"
	return true


func save() -> bool:
	_ensure_loaded()
	if _load_blocked:
		last_save_summary = "blocked_after_load_error"
		return false
	var config := ConfigFile.new()
	config.set_value(META_SECTION, "version", SAVE_SCHEMA_VERSION)
	config.set_value(UNLOCK_SECTION, DEFAULT_UNLOCKED_KEY, _default_unlocked)
	config.set_value(UNLOCK_SECTION, OVERRIDES_KEY, _overrides.duplicate(true))
	_ensure_save_parent_dir()
	var result := config.save(save_path)
	last_save_summary = "ok" if result == OK else "save_error_%d" % result
	return result == OK


func clear() -> bool:
	_reset_runtime_state()
	_loaded = true
	last_load_summary = "cleared_default_all_unlocked"
	if not FileAccess.file_exists(save_path):
		last_save_summary = "cleared"
		return true
	var result := DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	last_save_summary = "cleared" if result == OK else "clear_error_%d" % result
	return result == OK


func is_unlocked(content_type: String, content_id: String) -> bool:
	_ensure_loaded()
	if _load_blocked:
		return false
	var key := _make_key(content_type, content_id)
	if key.is_empty():
		return false
	return bool(_overrides.get(key, _default_unlocked))


func set_unlocked(content_type: String, content_id: String, unlocked: bool) -> bool:
	_ensure_loaded()
	if _load_blocked:
		return false
	var key := _make_key(content_type, content_id)
	if key.is_empty():
		return false
	if unlocked == _default_unlocked:
		_overrides.erase(key)
	else:
		_overrides[key] = unlocked
	return save()


func set_default_unlocked(unlocked: bool) -> bool:
	_ensure_loaded()
	if _load_blocked:
		return false
	_default_unlocked = unlocked
	_overrides.clear()
	return save()


func get_summary() -> Dictionary:
	_ensure_loaded()
	return {
		"save_path": save_path,
		"schema_version": SAVE_SCHEMA_VERSION,
		"default_unlocked": _default_unlocked,
		"override_count": _overrides.size(),
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
	_default_unlocked = true
	_overrides.clear()


func _import_overrides(value: Variant) -> void:
	_overrides.clear()
	if not (value is Dictionary):
		return
	for key_value in (value as Dictionary).keys():
		var key := str(key_value).strip_edges()
		if key.is_empty() or key.find("|") <= 0:
			continue
		_overrides[key] = bool((value as Dictionary).get(key_value, false))


func _make_key(content_type: String, content_id: String) -> String:
	var normalized_type := content_type.strip_edges().to_lower()
	var normalized_id := content_id.strip_edges()
	if normalized_type.is_empty() or normalized_id.is_empty():
		return ""
	return "%s|%s" % [normalized_type, normalized_id]
