extends "res://scripts/characters/smasher_skill_state.gd"

const SAVE_SNAPSHOT_VERSION := 1


func get_save_snapshot() -> Dictionary:
	return {
		"version": SAVE_SNAPSHOT_VERSION,
		"cooldowns": cooldowns.duplicate(true),
		"was_active": was_active.duplicate(true),
		"activation_msec": activation_msec.duplicate(true),
		"cooldown_pause_started_msec": cooldown_pause_started_msec,
	}


func build_save_snapshot() -> Dictionary:
	return get_save_snapshot()


func apply_save_snapshot(snapshot: Dictionary) -> Dictionary:
	reset()
	if snapshot.is_empty():
		return {
			"restored": false,
			"reason": "empty_snapshot",
		}
	cooldowns = _restore_string_keyed_dictionary(snapshot.get("cooldowns", {}))
	was_active = _restore_string_keyed_dictionary(snapshot.get("was_active", {}))
	activation_msec = _restore_string_keyed_dictionary(snapshot.get("activation_msec", {}))
	cooldown_pause_started_msec = int(snapshot.get("cooldown_pause_started_msec", -1))
	return {
		"restored": true,
		"cooldown_count": cooldowns.size(),
	}


func restore_save_snapshot(snapshot: Dictionary) -> Dictionary:
	return apply_save_snapshot(snapshot)


func _restore_string_keyed_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (value is Dictionary):
		return result
	var source: Dictionary = value
	for key in source.keys():
		var string_key := str(key)
		var entry: Variant = source[key]
		if entry is Dictionary:
			result[string_key] = (entry as Dictionary).duplicate(true)
		else:
			result[string_key] = entry
	return result
