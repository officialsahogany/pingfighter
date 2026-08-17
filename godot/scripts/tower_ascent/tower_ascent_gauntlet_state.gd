extends RefCounted

const TowerAscentGauntletLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_gauntlet_localization.gd"
)

const ENCOUNTER_COUNT := 4
const FINAL_FLOOR := 11

var _state: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	_state = {
		"active": false,
		"node_resolution_id": "",
		"encounter_index": 0,
		"sequence": [],
		"victory_event_ids": [],
		"defeat_event_ids": [],
		"defeat_count": 0,
		"transition_pending": false,
		"completed": false,
	}


func start(node_resolution_id: String, sequence: Array[Dictionary]) -> Dictionary:
	var normalized_id := node_resolution_id.strip_edges()
	if normalized_id.is_empty() or not _valid_sequence(sequence):
		return _result(false, false, "invalid_gauntlet_contract")
	if bool(_state.get("active", false)) or bool(_state.get("completed", false)):
		if str(_state.get("node_resolution_id", "")) == normalized_id:
			return _result(true, false, "already_started")
		return _result(false, false, "gauntlet_already_started")
	_state = {
		"active": true,
		"node_resolution_id": normalized_id,
		"encounter_index": 0,
		"sequence": sequence.duplicate(true),
		"victory_event_ids": [],
		"defeat_event_ids": [],
		"defeat_count": 0,
		"transition_pending": false,
		"completed": false,
	}
	return _result(true, true, "started")


func resolve_victory(event_id: String) -> Dictionary:
	var normalized_event_id := event_id.strip_edges()
	if normalized_event_id.is_empty():
		return _result(false, false, "invalid_event_id")
	var victory_ids: Array = _state.get("victory_event_ids", [])
	if victory_ids.has(normalized_event_id):
		return _result(true, false, "already_committed")
	if not bool(_state.get("active", false)):
		return _result(false, false, "gauntlet_inactive")
	if bool(_state.get("transition_pending", false)):
		return _result(false, false, "transition_pending")
	var encounter_index := int(_state.get("encounter_index", 0))
	victory_ids.append(normalized_event_id)
	_state["victory_event_ids"] = victory_ids
	if encounter_index >= ENCOUNTER_COUNT - 1:
		_state["active"] = false
		_state["completed"] = true
		return _result(true, true, "gauntlet_completed", {
			"final_chest": {
				"reward_count": 1,
				"context": {
					"floor": FINAL_FLOOR,
					"is_elite": true,
					"is_enraged": true,
					"is_gatekeeper": true,
				},
			},
		})
	_state["encounter_index"] = encounter_index + 1
	_state["transition_pending"] = true
	return _result(true, true, "next_encounter", {
		"transition_plan": build_transition_plan(),
	})


func record_defeat(event_id: String) -> Dictionary:
	if not bool(_state.get("active", false)):
		return _result(false, false, "gauntlet_inactive")
	var normalized_event_id := event_id.strip_edges()
	if normalized_event_id.is_empty():
		return _result(false, false, "invalid_event_id")
	var defeat_ids: Array = _state.get("defeat_event_ids", [])
	if defeat_ids.has(normalized_event_id):
		return _result(true, false, "already_committed", {
			"retry_encounter_index": int(_state.get("encounter_index", 0)),
		})
	defeat_ids.append(normalized_event_id)
	_state["defeat_event_ids"] = defeat_ids
	_state["defeat_count"] = int(_state.get("defeat_count", 0)) + 1
	return _result(true, true, "retry_same_encounter", {
		"event_id": normalized_event_id,
		"retry_encounter_index": int(_state.get("encounter_index", 0)),
	})


func acknowledge_transition() -> Dictionary:
	if not bool(_state.get("active", false)) or not bool(_state.get("transition_pending", false)):
		return _result(false, false, "transition_not_pending")
	_state["transition_pending"] = false
	return _result(true, true, "transition_acknowledged", {
		"transition_plan": build_transition_plan(),
	})


func build_transition_plan() -> Dictionary:
	return {
		"reset_scope": "tower_node_match",
		"reset_active_item_cooldowns": true,
		"increment_mythic_stage_progress": false,
		"preserve": ["field_items", "mugong", "chosik", "fx"],
		"recover_between_encounters": false,
		"intermediate_chest_count": 0,
		"encounter_index": int(_state.get("encounter_index", 0)),
		"opponent": get_current_opponent(),
	}


func get_current_opponent() -> Dictionary:
	var sequence: Array = _state.get("sequence", [])
	var index := int(_state.get("encounter_index", 0))
	if index < 0 or index >= sequence.size() or not (sequence[index] is Dictionary):
		return {}
	return (sequence[index] as Dictionary).duplicate(true)


func is_active() -> bool:
	return bool(_state.get("active", false))


func is_transition_pending() -> bool:
	return bool(_state.get("transition_pending", false))


func export_state() -> Dictionary:
	return _state.duplicate(true)


func restore_state(value: Variant) -> bool:
	reset()
	if not (value is Dictionary):
		return false
	var source := value as Dictionary
	var sequence := _dictionary_array(source.get("sequence", []))
	var encounter_index := int(source.get("encounter_index", -1))
	if (
		str(source.get("node_resolution_id", "")).is_empty()
		or not _valid_sequence(sequence)
		or encounter_index < 0
		or encounter_index >= ENCOUNTER_COUNT
	):
		return false
	_state = {
		"active": bool(source.get("active", false)),
		"node_resolution_id": str(source.get("node_resolution_id", "")),
		"encounter_index": encounter_index,
		"sequence": sequence,
		"victory_event_ids": _string_array(source.get("victory_event_ids", [])),
		"defeat_event_ids": _string_array(source.get("defeat_event_ids", [])),
		"defeat_count": maxi(0, int(source.get("defeat_count", 0))),
		"transition_pending": bool(source.get("transition_pending", false)),
		"completed": bool(source.get("completed", false)),
	}
	if bool(_state.get("completed", false)):
		return not bool(_state.get("active", true)) and not bool(_state.get("transition_pending", true))
	return bool(_state.get("active", false))


func build_transition_view_model() -> Dictionary:
	var next_number := int(_state.get("encounter_index", 0)) + 1
	return {
		"title": TowerAscentGauntletLocalization.text(TowerAscentGauntletLocalization.KEY_TITLE),
		"body": TowerAscentGauntletLocalization.text(
			TowerAscentGauntletLocalization.KEY_BODY,
			{"completed": next_number - 1, "next": next_number}
		),
		"preserve": TowerAscentGauntletLocalization.text(TowerAscentGauntletLocalization.KEY_PRESERVE),
		"prompt": TowerAscentGauntletLocalization.text(TowerAscentGauntletLocalization.KEY_PROMPT),
		"encounter_index": int(_state.get("encounter_index", 0)),
		"opponent": get_current_opponent(),
	}


func _valid_sequence(sequence: Array[Dictionary]) -> bool:
	if sequence.size() != ENCOUNTER_COUNT:
		return false
	var slot_ids: Array[String] = []
	for encounter in sequence:
		var slot_id := str(encounter.get("slot_id", "")).strip_edges()
		var standin: Variant = encounter.get("standin", {})
		if slot_id.is_empty() or slot_ids.has(slot_id) or not (standin is Dictionary) or (standin as Dictionary).is_empty():
			return false
		slot_ids.append(slot_id)
	return true


func _result(
	accepted: bool,
	changed: bool,
	reason: String,
	extra: Dictionary = {}
) -> Dictionary:
	var result := {
		"accepted": accepted,
		"changed": changed,
		"reason": reason,
		"state": export_state(),
	}
	result.merge(extra, true)
	return result


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry in value as Array:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
	return result


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value as Array:
			result.append(str(entry))
	return result
