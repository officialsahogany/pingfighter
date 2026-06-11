extends RefCounted

const SAVE_PATH := "user://lingpet_affinity.cfg"
const SAVE_SCHEMA_VERSION := 2
const MAX_BEST_LEVEL := 15 # Mirrors LingpetAffinityState.MAX_LEVEL without coupling the store to runtime state.
const META_SECTION := "meta"
const META_SCHEMA_VERSION_KEY := "schema_version"
const LEGACY_META_VERSION_KEY := "version"
const BEST_LEVELS_SECTION := "best_levels"
const BOND_POINTS_SECTION := "bond_points"

var save_path := SAVE_PATH
var last_load_summary := "not_loaded"
var last_save_summary := "not_saved"
var _best_levels: Dictionary = {}
var _bond_points: Dictionary = {}
var _loaded := false
var _schema_version := SAVE_SCHEMA_VERSION


func set_save_path(path: String) -> void:
	if path.strip_edges() == "":
		return
	save_path = path
	_loaded = false
	_best_levels.clear()
	_bond_points.clear()
	_schema_version = SAVE_SCHEMA_VERSION


func load() -> bool:
	_best_levels.clear()
	_bond_points.clear()
	_schema_version = SAVE_SCHEMA_VERSION
	_loaded = true
	if not FileAccess.file_exists(save_path):
		last_load_summary = "missing"
		return true
	var config := ConfigFile.new()
	var result := _load_config_file(config)
	if result != OK:
		last_load_summary = "load_error_%d" % result
		return false
	var stored_version := _read_schema_version(config)
	_load_best_levels(config)
	_load_bond_points(config)
	_schema_version = SAVE_SCHEMA_VERSION
	last_load_summary = "migrated_v%d" % stored_version if stored_version < SAVE_SCHEMA_VERSION else "ok"
	return true


func save() -> bool:
	_ensure_loaded()
	var config := ConfigFile.new()
	config.set_value(META_SECTION, META_SCHEMA_VERSION_KEY, SAVE_SCHEMA_VERSION)
	for raw_pet_id in _best_levels.keys():
		var pet_id := _normalize_pet_id(str(raw_pet_id))
		var best_level := clampi(int(_best_levels.get(raw_pet_id, 0)), 0, MAX_BEST_LEVEL)
		if pet_id != "" and best_level > 0:
			config.set_value(BEST_LEVELS_SECTION, pet_id, best_level)
	for raw_pet_id in _bond_points.keys():
		var pet_id := _normalize_pet_id(str(raw_pet_id))
		var bond_value := _sanitize_bond_points(_bond_points.get(raw_pet_id, 0))
		if pet_id != "" and bond_value > 0:
			config.set_value(BOND_POINTS_SECTION, pet_id, bond_value)
	var result: int = config.save(save_path)
	last_save_summary = "ok" if result == OK else "save_error_%d" % result
	return result == OK


func clear() -> bool:
	_best_levels.clear()
	_bond_points.clear()
	_schema_version = SAVE_SCHEMA_VERSION
	_loaded = true
	if not FileAccess.file_exists(save_path):
		last_save_summary = "cleared"
		return true
	var result: int = DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	last_save_summary = "cleared" if result == OK else "clear_error_%d" % result
	return result == OK


func get_best_level(pet_id: String) -> int:
	_ensure_loaded()
	return int(_best_levels.get(_normalize_pet_id(pet_id), 0))


func get_best_levels() -> Dictionary:
	_ensure_loaded()
	return _best_levels.duplicate(true)


func get_bond_points(pet_id: String) -> int:
	_ensure_loaded()
	return int(_bond_points.get(_normalize_pet_id(pet_id), 0))


func get_bond_points_map() -> Dictionary:
	_ensure_loaded()
	return _bond_points.duplicate(true)


func get_schema_version() -> int:
	_ensure_loaded()
	return _schema_version


func set_best_level(pet_id: String, best_level: int) -> bool:
	_ensure_loaded()
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		last_save_summary = "skipped_missing_pet_id"
		return false
	var clamped_best := clampi(best_level, 0, MAX_BEST_LEVEL)
	var previous_best := int(_best_levels.get(normalized_pet_id, 0))
	if clamped_best <= previous_best:
		last_save_summary = "skipped_not_higher"
		return false
	_best_levels[normalized_pet_id] = clamped_best
	return save()


func add_bond_levels(pet_id: String, amount: int) -> bool:
	_ensure_loaded()
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		last_save_summary = "skipped_missing_pet_id"
		return false
	if amount <= 0:
		last_save_summary = "skipped_non_positive_bond"
		return false
	var previous_points := _sanitize_bond_points(_bond_points.get(normalized_pet_id, 0))
	_bond_points[normalized_pet_id] = previous_points + amount
	return save()


func merge_best_levels(best_levels: Dictionary) -> bool:
	_ensure_loaded()
	var changed := false
	for raw_pet_id in best_levels.keys():
		var pet_id := _normalize_pet_id(str(raw_pet_id))
		if pet_id == "":
			continue
		var best_level := clampi(int(best_levels.get(raw_pet_id, 0)), 0, MAX_BEST_LEVEL)
		if best_level > int(_best_levels.get(pet_id, 0)):
			_best_levels[pet_id] = best_level
			changed = true
	if not changed:
		last_save_summary = "skipped_not_higher"
		return false
	return save()


func get_summary() -> Dictionary:
	return {
		"save_path": save_path,
		"load": last_load_summary,
		"save": last_save_summary,
		"schema_version": get_schema_version(),
		"best_levels": get_best_levels(),
		"bond_points": get_bond_points_map(),
	}


func _ensure_loaded() -> void:
	if _loaded:
		return
	# Bare load() resolves to the GLOBAL load(path) and is a parse error;
	# self. is required to reach this class's own load() method.
	self.load()


func _load_config_file(config: ConfigFile) -> int:
	var bytes := FileAccess.get_file_as_bytes(save_path)
	if bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF:
		bytes = bytes.slice(3)
	return config.parse(bytes.get_string_from_utf8())


func _read_schema_version(config: ConfigFile) -> int:
	var raw_version: Variant = config.get_value(
		META_SECTION,
		META_SCHEMA_VERSION_KEY,
		config.get_value(META_SECTION, LEGACY_META_VERSION_KEY, 1)
	)
	return maxi(1, int(raw_version))


func _load_best_levels(config: ConfigFile) -> void:
	if not config.has_section(BEST_LEVELS_SECTION):
		return
	for raw_key in config.get_section_keys(BEST_LEVELS_SECTION):
		var pet_id := _normalize_pet_id(str(raw_key))
		if pet_id == "":
			continue
		var best_level := clampi(int(config.get_value(BEST_LEVELS_SECTION, raw_key, 0)), 0, MAX_BEST_LEVEL)
		if best_level > 0:
			_best_levels[pet_id] = best_level


func _load_bond_points(config: ConfigFile) -> void:
	if not config.has_section(BOND_POINTS_SECTION):
		return
	for raw_key in config.get_section_keys(BOND_POINTS_SECTION):
		var pet_id := _normalize_pet_id(str(raw_key))
		if pet_id == "":
			continue
		var bond_value := _sanitize_bond_points(config.get_value(BOND_POINTS_SECTION, raw_key, 0))
		if bond_value > 0:
			_bond_points[pet_id] = bond_value


func _sanitize_bond_points(value: Variant) -> int:
	return maxi(0, int(value))


func _normalize_pet_id(value: String) -> String:
	return value.strip_edges().to_lower()
