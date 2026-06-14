extends RefCounted

const SAVE_PATH := "user://lingpet_affinity.cfg"
const SAVE_SCHEMA_VERSION := 4
const MAX_BEST_LEVEL := 30 # Mirrors LingpetAffinityState.MAX_LEVEL without coupling the store to runtime state.
const MAX_RING_CORE_TIER := 6
const MISSING_RING_CORE_TIER := -1
const META_SECTION := "meta"
const META_SCHEMA_VERSION_KEY := "schema_version"
const LEGACY_META_VERSION_KEY := "version"
const BEST_LEVELS_SECTION := "best_levels"
const BOND_POINTS_SECTION := "bond_points"
const RING_CORE_SECTION := "ring_core"
const RING_CORE_TIER_KEY := "tier"
const RESOLVED_UNLOCK_CHOICES_SECTION := "resolved_unlock_choices"
const RESOLVED_UNLOCK_CHOICE_KEYS := ["active", "passive", "second_active", "second_passive"]
const RESOLVED_UNLOCK_CHOICE_KEY_SEPARATOR := "."

var save_path := SAVE_PATH
var last_load_summary := "not_loaded"
var last_save_summary := "not_saved"
var _best_levels: Dictionary = {}
var _bond_points: Dictionary = {}
var _ring_core_tier := MISSING_RING_CORE_TIER
var _resolved_unlock_choices: Dictionary = {}
var _loaded := false
var _schema_version := SAVE_SCHEMA_VERSION
var _recovery_blocked := false


func set_save_path(path: String) -> void:
	if path.strip_edges() == "":
		return
	save_path = path
	_loaded = false
	_recovery_blocked = false
	_best_levels.clear()
	_bond_points.clear()
	_ring_core_tier = MISSING_RING_CORE_TIER
	_resolved_unlock_choices.clear()
	_schema_version = SAVE_SCHEMA_VERSION


func get_backup_path() -> String:
	return save_path.trim_suffix(".cfg") + ".last_good.cfg"


func load() -> bool:
	_best_levels.clear()
	_bond_points.clear()
	_ring_core_tier = MISSING_RING_CORE_TIER
	_resolved_unlock_choices.clear()
	_schema_version = SAVE_SCHEMA_VERSION
	_loaded = true
	_recovery_blocked = false
	if not FileAccess.file_exists(save_path):
		last_load_summary = "missing"
		return true
	var config := ConfigFile.new()
	var result := _load_config_file(config, save_path)
	if result != OK:
		# Permanent-ledger recovery: a corrupted main file must repair from
		# the last-good backup instead of silently resetting every pet's
		# affinity residue to defaults.
		if _try_recover_from_backup():
			return true
		# Keep the backup file untouched for inspection while corrupted.
		_recovery_blocked = true
		last_load_summary = "load_error_%d" % result
		return false
	var stored_version := _read_schema_version(config)
	_load_best_levels(config)
	_load_bond_points(config)
	_load_ring_core(config)
	_load_resolved_unlock_choices(config)
	_schema_version = SAVE_SCHEMA_VERSION
	if not _has_any_loaded_residue():
		# An existing file with no residue data is a botched / partial write,
		# not a new player (new players have no file at all). Repair from the
		# backup when it holds data, and never let this empty state clobber
		# the last-good backup below.
		if _try_recover_from_backup():
			return true
		last_load_summary = "ok_empty"
		return true
	last_load_summary = "migrated_v%d" % stored_version if stored_version < SAVE_SCHEMA_VERSION else "ok"
	_build_save_config().save(get_backup_path())
	return true


func _try_recover_from_backup() -> bool:
	if not FileAccess.file_exists(get_backup_path()):
		return false
	var backup := ConfigFile.new()
	if _load_config_file(backup, get_backup_path()) != OK:
		return false
	_load_best_levels(backup)
	_load_bond_points(backup)
	_load_ring_core(backup)
	_load_resolved_unlock_choices(backup)
	if not _has_any_loaded_residue():
		return false
	last_load_summary = "recovered_last_good"
	save()
	return true


func save() -> bool:
	_ensure_loaded()
	var config := _build_save_config()
	var result: int = config.save(save_path)
	last_save_summary = "ok" if result == OK else "save_error_%d" % result
	if result == OK and not _recovery_blocked:
		config.save(get_backup_path())
	return result == OK


func clear() -> bool:
	_best_levels.clear()
	_bond_points.clear()
	_ring_core_tier = MISSING_RING_CORE_TIER
	_resolved_unlock_choices.clear()
	_schema_version = SAVE_SCHEMA_VERSION
	_loaded = true
	_recovery_blocked = false
	# Remove the backup too, or cleared residue resurrects through the
	# corruption-recovery path on a later bad load.
	if FileAccess.file_exists(get_backup_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(get_backup_path()))
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


func get_resolved_unlock_choices(pet_id: String) -> Dictionary:
	_ensure_loaded()
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return {}
	var choices: Dictionary = _resolved_unlock_choices.get(normalized_pet_id, {}) as Dictionary
	return choices.duplicate(true)


func get_all_resolved_unlock_choices() -> Dictionary:
	_ensure_loaded()
	return _resolved_unlock_choices.duplicate(true)


func set_resolved_unlock_choice(pet_id: String, choice_key: String, selected_id: String) -> bool:
	_ensure_loaded()
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		last_save_summary = "skipped_missing_pet_id"
		return false
	var normalized_choice_key := _normalize_choice_key(choice_key)
	if normalized_choice_key == "":
		last_save_summary = "skipped_invalid_choice_key"
		return false
	var normalized_selected_id := _normalize_selected_skill_id(selected_id)
	if normalized_selected_id == "":
		return clear_resolved_unlock_choice(normalized_pet_id, normalized_choice_key)
	var choices: Dictionary = _resolved_unlock_choices.get(normalized_pet_id, {}) as Dictionary
	if str(choices.get(normalized_choice_key, "")) == normalized_selected_id:
		last_save_summary = "skipped_same_resolved_unlock_choice"
		return false
	choices[normalized_choice_key] = normalized_selected_id
	_resolved_unlock_choices[normalized_pet_id] = choices
	return save()


func clear_resolved_unlock_choice(pet_id: String, choice_key: String) -> bool:
	_ensure_loaded()
	var normalized_pet_id := _normalize_pet_id(pet_id)
	var normalized_choice_key := _normalize_choice_key(choice_key)
	if normalized_pet_id == "" or normalized_choice_key == "":
		last_save_summary = "skipped_invalid_resolved_unlock_choice_clear"
		return false
	if not _resolved_unlock_choices.has(normalized_pet_id):
		last_save_summary = "skipped_missing_resolved_unlock_choice"
		return false
	var choices: Dictionary = _resolved_unlock_choices.get(normalized_pet_id, {}) as Dictionary
	if not choices.has(normalized_choice_key):
		last_save_summary = "skipped_missing_resolved_unlock_choice"
		return false
	choices.erase(normalized_choice_key)
	if choices.is_empty():
		_resolved_unlock_choices.erase(normalized_pet_id)
	else:
		_resolved_unlock_choices[normalized_pet_id] = choices
	return save()


func get_schema_version() -> int:
	_ensure_loaded()
	return _schema_version


func has_ring_core_tier() -> bool:
	_ensure_loaded()
	return _has_loaded_ring_core_tier()


func get_ring_core_tier() -> int:
	_ensure_loaded()
	return clampi(_ring_core_tier, 0, MAX_RING_CORE_TIER) if _has_loaded_ring_core_tier() else 0


func get_ring_core_cap() -> int:
	_ensure_loaded()
	if not _has_loaded_ring_core_tier():
		return MAX_BEST_LEVEL
	return get_ring_core_cap_for_tier(_ring_core_tier)


static func get_ring_core_cap_for_tier(tier: int) -> int:
	var clamped_tier := clampi(tier, 0, MAX_RING_CORE_TIER)
	if clamped_tier <= 0:
		return 0
	return clampi(clamped_tier * 5, 0, MAX_BEST_LEVEL)


func set_ring_core_tier(tier: int) -> bool:
	_ensure_loaded()
	var clamped_tier := clampi(tier, 0, MAX_RING_CORE_TIER)
	if _has_loaded_ring_core_tier() and _ring_core_tier == clamped_tier:
		last_save_summary = "skipped_same_ring_core_tier"
		return false
	_ring_core_tier = clamped_tier
	return save()


func upgrade_ring_core_tier(tier: int) -> bool:
	_ensure_loaded()
	var clamped_tier := clampi(tier, 0, MAX_RING_CORE_TIER)
	var previous_tier := get_ring_core_tier() if _has_loaded_ring_core_tier() else 0
	if clamped_tier <= previous_tier:
		last_save_summary = "skipped_not_higher_ring_core_tier"
		return false
	_ring_core_tier = clamped_tier
	return save()


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
		"has_ring_core_tier": has_ring_core_tier(),
		"ring_core_tier": get_ring_core_tier(),
		"ring_core_cap": get_ring_core_cap(),
		"resolved_unlock_choices": get_all_resolved_unlock_choices(),
	}


func _ensure_loaded() -> void:
	if _loaded:
		return
	# Bare load() resolves to the GLOBAL load(path) and is a parse error;
	# self. is required to reach this class's own load() method.
	self.load()


func _load_config_file(config: ConfigFile, path: String) -> int:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF:
		bytes = bytes.slice(3)
	return config.parse(bytes.get_string_from_utf8())


func _build_save_config() -> ConfigFile:
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
	if _has_loaded_ring_core_tier():
		config.set_value(RING_CORE_SECTION, RING_CORE_TIER_KEY, clampi(_ring_core_tier, 0, MAX_RING_CORE_TIER))
	for raw_pet_id in _resolved_unlock_choices.keys():
		var pet_id := _normalize_pet_id(str(raw_pet_id))
		if pet_id == "":
			continue
		var choices: Dictionary = _resolved_unlock_choices.get(raw_pet_id, {}) as Dictionary
		for choice_key in RESOLVED_UNLOCK_CHOICE_KEYS:
			var selected_id := _normalize_selected_skill_id(choices.get(choice_key, ""))
			if selected_id != "":
				config.set_value(RESOLVED_UNLOCK_CHOICES_SECTION, "%s%s%s" % [pet_id, RESOLVED_UNLOCK_CHOICE_KEY_SEPARATOR, choice_key], selected_id)
	return config


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


func _load_ring_core(config: ConfigFile) -> void:
	_ring_core_tier = MISSING_RING_CORE_TIER
	if not config.has_section_key(RING_CORE_SECTION, RING_CORE_TIER_KEY):
		return
	_ring_core_tier = clampi(int(config.get_value(RING_CORE_SECTION, RING_CORE_TIER_KEY, 0)), 0, MAX_RING_CORE_TIER)


func _load_resolved_unlock_choices(config: ConfigFile) -> void:
	_resolved_unlock_choices.clear()
	if not config.has_section(RESOLVED_UNLOCK_CHOICES_SECTION):
		return
	for raw_key in config.get_section_keys(RESOLVED_UNLOCK_CHOICES_SECTION):
		var storage_key := str(raw_key).strip_edges()
		var separator_index := storage_key.find(RESOLVED_UNLOCK_CHOICE_KEY_SEPARATOR)
		if separator_index <= 0:
			continue
		var pet_id := _normalize_pet_id(storage_key.substr(0, separator_index))
		var choice_key := _normalize_choice_key(storage_key.substr(separator_index + 1))
		var selected_id := _normalize_selected_skill_id(config.get_value(RESOLVED_UNLOCK_CHOICES_SECTION, raw_key, ""))
		if pet_id == "" or choice_key == "" or selected_id == "":
			continue
		var choices: Dictionary = _resolved_unlock_choices.get(pet_id, {}) as Dictionary
		choices[choice_key] = selected_id
		_resolved_unlock_choices[pet_id] = choices


func _has_loaded_ring_core_tier() -> bool:
	return _ring_core_tier >= 0


func _has_any_loaded_residue() -> bool:
	return (
		not _best_levels.is_empty()
		or not _bond_points.is_empty()
		or _has_loaded_ring_core_tier()
		or not _resolved_unlock_choices.is_empty()
	)


func _sanitize_bond_points(value: Variant) -> int:
	return maxi(0, int(value))


func _normalize_pet_id(value: String) -> String:
	return value.strip_edges().to_lower()


func _normalize_choice_key(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	return normalized if RESOLVED_UNLOCK_CHOICE_KEYS.has(normalized) else ""


func _normalize_selected_skill_id(value: Variant) -> String:
	return str(value).strip_edges().to_lower()
