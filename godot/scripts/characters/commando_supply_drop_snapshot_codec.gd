extends RefCounted

const CommandoSupplyDropPayloadResolver := preload("res://scripts/characters/commando_supply_drop_payload_resolver.gd")

const SAVE_SNAPSHOT_VERSION := 1


static func build_save_snapshot(runtime_snapshot: Dictionary) -> Dictionary:
	var snapshot := runtime_snapshot.duplicate(true)
	snapshot["version"] = SAVE_SNAPSHOT_VERSION
	return snapshot


static func normalize_for_restore(
	snapshot: Dictionary,
	defaults: Dictionary,
	minimum_flight_duration: float,
	payload_interval: float
) -> Dictionary:
	if snapshot.is_empty():
		return {}

	var active := bool(snapshot.get("active", false))
	var aircraft_crashing := bool(snapshot.get("aircraft_crashing", false))
	var aircraft_spawned := bool(snapshot.get(
		"aircraft_spawned",
		active and (
			bool(snapshot.get("aircraft_audio_active", false))
			or aircraft_crashing
			or float(snapshot.get("flight_elapsed", 0.0)) > 0.0
		)
	))
	var pending_drops := _duplicate_dictionary_array(snapshot.get("pending_drops", []))
	var pending_drop_delays := _duplicate_float_array(snapshot.get("pending_drop_delays", []))
	while pending_drop_delays.size() < pending_drops.size():
		pending_drop_delays.append(payload_interval)

	return {
		"hold_time": max(0.0, float(snapshot.get("hold_time", 0.0))),
		"pending_hold_time": max(0.0, float(snapshot.get("pending_hold_time", 0.0))),
		"active": active,
		"timer": max(0.0, float(snapshot.get("timer", 0.0))),
		"radio_motion": bool(snapshot.get("radio_motion", false)),
		"radio_timer": max(0.0, float(snapshot.get("radio_timer", 0.0))),
		"radio_duration": max(0.0, float(snapshot.get("radio_duration", defaults.get("radio_duration", 0.0)))),
		"aircraft_spawned": aircraft_spawned,
		"aircraft_arrival_delay": max(0.0, float(snapshot.get("aircraft_arrival_delay", 0.0))),
		"aircraft_direction": "right_to_left" if str(snapshot.get("aircraft_direction", "left_to_right")) == "right_to_left" else "left_to_right",
		"aircraft_pos": _get_vector2(snapshot.get("aircraft_pos", defaults.get("aircraft_pos", Vector2.ZERO)), defaults.get("aircraft_pos", Vector2.ZERO)),
		"aircraft_crashing": aircraft_crashing,
		"aircraft_crash_elapsed": max(0.0, float(snapshot.get("aircraft_crash_elapsed", 0.0))),
		"aircraft_crash_timer": max(0.0, float(snapshot.get("aircraft_crash_timer", 0.0))),
		"aircraft_crash_rotation": float(snapshot.get("aircraft_crash_rotation", 0.0)),
		"aircraft_crash_start_pos": _get_vector2(snapshot.get("aircraft_crash_start_pos", defaults.get("aircraft_pos", Vector2.ZERO)), defaults.get("aircraft_pos", Vector2.ZERO)),
		"aircraft_crash_target_pos": _get_vector2(snapshot.get("aircraft_crash_target_pos", defaults.get("aircraft_crash_target_pos", Vector2.ZERO)), defaults.get("aircraft_crash_target_pos", Vector2.ZERO)),
		"aircraft_exploded": bool(snapshot.get("aircraft_exploded", false)),
		"aircraft_crash_source": str(snapshot.get("aircraft_crash_source", "")),
		"crash_blast_timer": max(0.0, float(snapshot.get("crash_blast_timer", 0.0))),
		"crash_blast_center": _get_vector2(snapshot.get("crash_blast_center", Vector2.ZERO), Vector2.ZERO),
		"crash_blast_player_knocked": bool(snapshot.get("crash_blast_player_knocked", false)),
		"flight_elapsed": max(0.0, float(snapshot.get("flight_elapsed", 0.0))),
		"flight_duration": max(minimum_flight_duration, float(snapshot.get("flight_duration", minimum_flight_duration))),
		"drop_timing_pattern": CommandoSupplyDropPayloadResolver.normalize_drop_timing_pattern(str(snapshot.get("drop_timing_pattern", "normal"))),
		"drop_effects": _duplicate_dictionary_array(snapshot.get("drop_effects", [])),
		"collectible_drops": _duplicate_dictionary_array(snapshot.get("collectible_drops", [])),
		"explosion_effects": _duplicate_dictionary_array(snapshot.get("explosion_effects", [])),
		"pending_drop": _duplicate_dictionary(snapshot.get("pending_drop", {})),
		"pending_drops": pending_drops,
		"pending_drop_delays": pending_drop_delays,
		"aircraft_audio_active": bool(snapshot.get("aircraft_audio_active", false)) and active and aircraft_spawned and not aircraft_crashing,
	}


static func _duplicate_dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _duplicate_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for entry in value:
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
	return result


static func _duplicate_float_array(value: Variant) -> Array[float]:
	var result: Array[float] = []
	if not (value is Array):
		return result
	for entry in value:
		result.append(max(0.0, float(entry)))
	return result


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
