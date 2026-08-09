extends RefCounted

const SAVE_PATH := "user://story_cinematic_progress.cfg"
const SECTION := "cinematics"
const BACKUP_SUFFIX := ".last_good.cfg"

var save_path := SAVE_PATH
var _loaded := false
var _seen: Dictionary = {}
var _last_load_stripped_bom := false


func set_save_path(path: String) -> void:
	if path.strip_edges() == "":
		return
	save_path = path
	_loaded = false
	_seen.clear()


func has_seen(cinematic_id: String) -> bool:
	_ensure_loaded()
	return bool(_seen.get(_normalize_id(cinematic_id), false))


func mark_seen(cinematic_id: String) -> bool:
	var normalized := _normalize_id(cinematic_id)
	if normalized == "":
		return false
	_ensure_loaded()
	_seen[normalized] = true
	return _save()


func get_seen_ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for key_value in _seen:
		if bool(_seen[key_value]):
			result.append(str(key_value))
	result.sort()
	return result


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_seen.clear()
	if not FileAccess.file_exists(save_path):
		return
	var config := ConfigFile.new()
	_last_load_stripped_bom = false
	if _load_config_file(config, save_path) != OK:
		_try_recover_from_backup()
		return
	_read_config(config)
	if _last_load_stripped_bom:
		_save()
	else:
		_write_backup(config)


func _try_recover_from_backup() -> void:
	var backup_path := _backup_path()
	if not FileAccess.file_exists(backup_path):
		return
	var backup := ConfigFile.new()
	if _load_config_file(backup, backup_path) != OK:
		return
	_read_config(backup)
	_save()


func _load_config_file(config: ConfigFile, path: String) -> int:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF:
		bytes = bytes.slice(3)
		_last_load_stripped_bom = true
	return config.parse(bytes.get_string_from_utf8())


func _read_config(config: ConfigFile) -> void:
	_seen.clear()
	for key_value in config.get_section_keys(SECTION):
		var cinematic_id := _normalize_id(str(key_value))
		if cinematic_id != "" and bool(config.get_value(SECTION, key_value, false)):
			_seen[cinematic_id] = true


func _save() -> bool:
	var config := ConfigFile.new()
	for cinematic_id in get_seen_ids():
		config.set_value(SECTION, cinematic_id, true)
	_ensure_parent_directory(save_path)
	var result := config.save(save_path)
	if result != OK:
		return false
	_write_backup(config)
	return true


func _write_backup(config: ConfigFile) -> void:
	var backup_path := _backup_path()
	_ensure_parent_directory(backup_path)
	config.save(backup_path)


func _backup_path() -> String:
	return save_path.trim_suffix(".cfg") + BACKUP_SUFFIX


func _ensure_parent_directory(path: String) -> void:
	var absolute_parent := ProjectSettings.globalize_path(path).get_base_dir()
	if absolute_parent != "":
		DirAccess.make_dir_recursive_absolute(absolute_parent)


func _normalize_id(value: String) -> String:
	return value.strip_edges().to_lower()
