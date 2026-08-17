extends RefCounted

const SAVE_PATH := "user://tower_ascent_records.cfg"
const SAVE_SCHEMA_VERSION := 1
const META_SECTION := "meta"
const RECORD_SECTION := "records"
const EVENT_SECTION := "record_events"
const LEAGUE_SECTION := "league_reserved"

const ENDING_STANDARD := "standard_clear"
const ENDING_TRUE := "true_ending"

var save_path := SAVE_PATH
var last_load_summary := "not_loaded"
var last_save_summary := "not_saved"
var _loaded := false
var _load_blocked := false
var _highest_floor := 0
var _clear_count := 0
var _fake_ending_cleared := false
var _true_ending_cleared := false
var _undefeated_true_ending_medal := false
var _record_events: Dictionary = {}
var _league_reserved: Dictionary = {}


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
		last_load_summary = "missing_empty_records"
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
	_highest_floor = maxi(0, int(config.get_value(RECORD_SECTION, "highest_floor", 0)))
	_clear_count = maxi(0, int(config.get_value(RECORD_SECTION, "clear_count", 0)))
	_fake_ending_cleared = bool(config.get_value(RECORD_SECTION, "fake_ending_cleared", false))
	_true_ending_cleared = bool(config.get_value(RECORD_SECTION, "true_ending_cleared", false))
	_undefeated_true_ending_medal = bool(config.get_value(
		RECORD_SECTION,
		"undefeated_true_ending_medal",
		false
	))
	_import_dictionary_section(config, EVENT_SECTION, _record_events)
	_import_dictionary_section(config, LEAGUE_SECTION, _league_reserved)
	last_load_summary = "ok"
	return true


func save() -> bool:
	_ensure_loaded()
	if _load_blocked:
		last_save_summary = "blocked_after_load_error"
		return false
	var config := ConfigFile.new()
	config.set_value(META_SECTION, "version", SAVE_SCHEMA_VERSION)
	config.set_value(RECORD_SECTION, "highest_floor", _highest_floor)
	config.set_value(RECORD_SECTION, "clear_count", _clear_count)
	config.set_value(RECORD_SECTION, "fake_ending_cleared", _fake_ending_cleared)
	config.set_value(RECORD_SECTION, "true_ending_cleared", _true_ending_cleared)
	config.set_value(
		RECORD_SECTION,
		"undefeated_true_ending_medal",
		_undefeated_true_ending_medal
	)
	_write_dictionary_section(config, EVENT_SECTION, _record_events)
	# Reserved only. Phase D deliberately has no league consumer or tuning value.
	_write_dictionary_section(config, LEAGUE_SECTION, _league_reserved)
	_ensure_save_parent_dir()
	var result := config.save(save_path)
	last_save_summary = "ok" if result == OK else "save_error_%d" % result
	return result == OK


func clear() -> bool:
	_reset_runtime_state()
	_loaded = true
	last_load_summary = "cleared_empty_records"
	if not FileAccess.file_exists(save_path):
		last_save_summary = "cleared"
		return true
	var result := DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	last_save_summary = "cleared" if result == OK else "clear_error_%d" % result
	return result == OK


func record_floor_reached(floor: int, event_id: String) -> Dictionary:
	return _commit_event(event_id, {
		"kind": "floor_reached",
		"floor": maxi(0, floor),
	})


func record_clear(
	floor: int,
	ending_kind: String,
	undefeated: bool,
	event_id: String
) -> Dictionary:
	var normalized_kind := ending_kind.strip_edges().to_lower()
	if normalized_kind not in [ENDING_STANDARD, ENDING_TRUE]:
		return _result(false, false, "invalid_ending_kind", event_id)
	return _commit_event(event_id, {
		"kind": "run_clear",
		"floor": maxi(0, floor),
		"ending_kind": normalized_kind,
		"undefeated": undefeated,
	})


func has_fake_ending_clear() -> bool:
	_ensure_loaded()
	return not _load_blocked and _fake_ending_cleared


func has_true_ending_clear() -> bool:
	_ensure_loaded()
	return not _load_blocked and _true_ending_cleared


func get_snapshot() -> Dictionary:
	_ensure_loaded()
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"highest_floor": _highest_floor,
		"clear_count": _clear_count,
		"fake_ending_cleared": _fake_ending_cleared,
		"true_ending_cleared": _true_ending_cleared,
		"undefeated_true_ending_medal": _undefeated_true_ending_medal,
		"record_event_count": _record_events.size(),
		"league_reserved": _league_reserved.duplicate(true),
		"load": last_load_summary,
		"save": last_save_summary,
		"load_blocked": _load_blocked,
	}


func _commit_event(event_id: String, payload: Dictionary) -> Dictionary:
	_ensure_loaded()
	var normalized_event_id := event_id.strip_edges()
	if _load_blocked:
		return _result(false, false, "blocked_after_load_error", normalized_event_id)
	if normalized_event_id.is_empty():
		return _result(false, false, "invalid_event_id", normalized_event_id)
	if int(payload.get("floor", 0)) <= 0:
		return _result(false, false, "invalid_floor", normalized_event_id)
	var normalized_payload := payload.duplicate(true)
	if _record_events.has(normalized_event_id):
		if _record_events.get(normalized_event_id) != normalized_payload:
			return _result(false, false, "event_id_conflict", normalized_event_id)
		return _result(true, false, "already_committed", normalized_event_id)

	var before := _capture_mutable_state()
	_record_events[normalized_event_id] = normalized_payload
	_apply_event(normalized_payload)
	if save():
		return _result(true, true, "committed", normalized_event_id)
	_restore_mutable_state(before)
	return _result(false, false, "save_failed", normalized_event_id)


func _apply_event(payload: Dictionary) -> void:
	_highest_floor = maxi(_highest_floor, int(payload.get("floor", 0)))
	if str(payload.get("kind", "")) != "run_clear":
		return
	_clear_count += 1
	var ending_kind := str(payload.get("ending_kind", ""))
	if ending_kind == ENDING_STANDARD:
		_fake_ending_cleared = true
	elif ending_kind == ENDING_TRUE:
		_true_ending_cleared = true
		if bool(payload.get("undefeated", false)):
			_undefeated_true_ending_medal = true


func _capture_mutable_state() -> Dictionary:
	return {
		"highest_floor": _highest_floor,
		"clear_count": _clear_count,
		"fake_ending_cleared": _fake_ending_cleared,
		"true_ending_cleared": _true_ending_cleared,
		"undefeated_true_ending_medal": _undefeated_true_ending_medal,
		"record_events": _record_events.duplicate(true),
	}


func _restore_mutable_state(state: Dictionary) -> void:
	_highest_floor = int(state.get("highest_floor", 0))
	_clear_count = int(state.get("clear_count", 0))
	_fake_ending_cleared = bool(state.get("fake_ending_cleared", false))
	_true_ending_cleared = bool(state.get("true_ending_cleared", false))
	_undefeated_true_ending_medal = bool(state.get("undefeated_true_ending_medal", false))
	_record_events = (state.get("record_events", {}) as Dictionary).duplicate(true)


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
	_highest_floor = 0
	_clear_count = 0
	_fake_ending_cleared = false
	_true_ending_cleared = false
	_undefeated_true_ending_medal = false
	_record_events.clear()
	_league_reserved.clear()


func _import_dictionary_section(config: ConfigFile, section: String, target: Dictionary) -> void:
	target.clear()
	if not config.has_section(section):
		return
	for key_value in config.get_section_keys(section):
		var key := str(key_value).strip_edges()
		if not key.is_empty():
			target[key] = config.get_value(section, key_value)


func _write_dictionary_section(config: ConfigFile, section: String, source: Dictionary) -> void:
	var keys: Array[String] = []
	for key_value in source.keys():
		keys.append(str(key_value))
	keys.sort()
	for key in keys:
		config.set_value(section, key, source.get(key))


func _result(accepted: bool, changed: bool, reason: String, event_id: String) -> Dictionary:
	return {
		"accepted": accepted,
		"changed": changed,
		"reason": reason,
		"event_id": event_id,
		"records": get_snapshot(),
	}
