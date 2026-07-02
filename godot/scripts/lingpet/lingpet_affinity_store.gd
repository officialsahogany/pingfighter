extends RefCounted

const SAVE_PATH := "user://lingpet_affinity.cfg"
const SAVE_SCHEMA_VERSION := 5
const META_SECTION := "meta"
const META_SCHEMA_VERSION_KEY := "schema_version"
const LEGACY_META_VERSION_KEY := "version"

var save_path := SAVE_PATH
var last_load_summary := "not_loaded"
var last_save_summary := "not_saved"
var _loaded := false
var _schema_version := SAVE_SCHEMA_VERSION
var _recovery_blocked := false


func set_save_path(path: String) -> void:
	if path.strip_edges() == "":
		return
	save_path = path
	_loaded = false
	_recovery_blocked = false
	_schema_version = SAVE_SCHEMA_VERSION


func get_backup_path() -> String:
	return save_path.trim_suffix(".cfg") + ".last_good.cfg"


func load() -> bool:
	_schema_version = SAVE_SCHEMA_VERSION
	_loaded = true
	_recovery_blocked = false
	if not FileAccess.file_exists(save_path):
		last_load_summary = "missing"
		return true
	var config := ConfigFile.new()
	var result := _load_config_file(config, save_path)
	if result != OK:
		# v5 has no persisted affinity ledger to restore. Keep a corrupt file
		# failed so the last-good backup cannot resurrect legacy progression.
		if _try_recover_from_backup():
			return true
		# Keep the backup file untouched for inspection while corrupted.
		_recovery_blocked = true
		last_load_summary = "load_error_%d" % result
		return false
	var stored_version := _read_schema_version(config)
	_schema_version = SAVE_SCHEMA_VERSION
	# v5 is meta-only: legacy affinity sections ([best_levels] / [bond_points] /
	# [ring_core] / [resolved_unlock_choices]) are intentionally ignored. Run-state
	# (LingpetAffinityState) owns affinity now, so a file with no residue is the
	# normal v5 shape, not a botched write. Never trigger backup recovery here.
	last_load_summary = "migrated_v%d" % stored_version if stored_version < SAVE_SCHEMA_VERSION else "ok"
	_build_save_config().save(get_backup_path())
	return true


func _try_recover_from_backup() -> bool:
	# v5 is meta-only: there is no persisted affinity residue to recover, and a
	# legacy backup's old sections must never resurrect into run-state.
	return false


func save() -> bool:
	_ensure_loaded()
	var config := _build_save_config()
	var result: int = config.save(save_path)
	last_save_summary = "ok" if result == OK else "save_error_%d" % result
	if result == OK and not _recovery_blocked:
		config.save(get_backup_path())
	return result == OK


func clear() -> bool:
	_schema_version = SAVE_SCHEMA_VERSION
	_loaded = true
	_recovery_blocked = false
	# Remove the backup too, so legacy residue cannot survive manual clearing.
	if FileAccess.file_exists(get_backup_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(get_backup_path()))
	if not FileAccess.file_exists(save_path):
		last_save_summary = "cleared"
		return true
	var result: int = DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	last_save_summary = "cleared" if result == OK else "clear_error_%d" % result
	return result == OK


func get_schema_version() -> int:
	_ensure_loaded()
	return _schema_version


func get_summary() -> Dictionary:
	return {
		"save_path": save_path,
		"load": last_load_summary,
		"save": last_save_summary,
		"schema_version": get_schema_version(),
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
	# v5 is meta-only: legacy affinity sections ([best_levels] / [bond_points] /
	# [ring_core] / [resolved_unlock_choices]) are no longer persisted.
	return config


func _read_schema_version(config: ConfigFile) -> int:
	var raw_version: Variant = config.get_value(
		META_SECTION,
		META_SCHEMA_VERSION_KEY,
		config.get_value(META_SECTION, LEGACY_META_VERSION_KEY, 1)
	)
	return maxi(1, int(raw_version))
