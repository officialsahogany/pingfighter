extends RefCounted

const PHASE_INACTIVE := "inactive"
const PHASE_MATERIALS := "materials"
const PHASE_CONFIRM := "confirm"
const PHASE_ANIMATION := "animation"
const PHASE_REVEAL := "reveal"

const DEFAULT_ANIMATION_DURATION := 1.1

var _phase := PHASE_INACTIVE
var _fusion_card: Dictionary = {}
var _origin_choices: Array = []
var _candidate_ids: Array[String] = []
var _selected_source_ids: Array[String] = []
var _highlight_index := 0
var _committed_record: Dictionary = {}
var _animation_remaining := 0.0
var _commit_request_emitted := false
var _finish_request_emitted := false


func start(fusion_card: Dictionary, origin_choices: Array, candidate_ids: Array) -> bool:
	reset()
	var normalized_candidate_ids: Array[String] = _normalize_candidate_ids(candidate_ids)
	if fusion_card.is_empty() or normalized_candidate_ids.size() < 2:
		return false
	_fusion_card = fusion_card.duplicate(true)
	_origin_choices = origin_choices.duplicate(true)
	_candidate_ids = normalized_candidate_ids
	_phase = PHASE_MATERIALS
	return true


func is_active() -> bool:
	return _phase != PHASE_INACTIVE


func get_phase() -> String:
	return _phase


func get_snapshot() -> Dictionary:
	return {
		"phase": _phase,
		"fusion_card": _fusion_card.duplicate(true),
		"origin_choices": _origin_choices.duplicate(true),
		"candidate_ids": _candidate_ids.duplicate(),
		"selected_source_ids": _selected_source_ids.duplicate(),
		"highlight_index": _highlight_index,
		"committed_record": _committed_record.duplicate(true),
		"animation_remaining": _animation_remaining,
		"commit_request_emitted": _commit_request_emitted,
		"finish_request_emitted": _finish_request_emitted,
	}


func move_highlight(direction: int) -> bool:
	if _phase != PHASE_MATERIALS or _candidate_ids.is_empty() or direction == 0:
		return false
	_highlight_index = posmod(_highlight_index + direction, _candidate_ids.size())
	return true


func set_highlight(index: int) -> bool:
	if _phase != PHASE_MATERIALS or index < 0 or index >= _candidate_ids.size():
		return false
	_highlight_index = index
	return true


func toggle_highlighted_source() -> bool:
	if _phase != PHASE_MATERIALS or _candidate_ids.is_empty():
		return false
	return select_source_at(_highlight_index)


func select_source_at(index: int) -> bool:
	if _phase != PHASE_MATERIALS or index < 0 or index >= _candidate_ids.size():
		return false
	_highlight_index = index
	var source_id: String = _candidate_ids[index]
	var selected_index: int = _selected_source_ids.find(source_id)
	if selected_index >= 0:
		_selected_source_ids.remove_at(selected_index)
		return true
	if _selected_source_ids.size() >= 2:
		return false
	_selected_source_ids.append(source_id)
	_selected_source_ids.sort()
	return true


func confirm_current() -> Dictionary:
	match _phase:
		PHASE_MATERIALS:
			if _selected_source_ids.size() != 2:
				return {
					"consumed": true,
					"blocked_reason": "requires_two_sources",
				}
			_phase = PHASE_CONFIRM
			_commit_request_emitted = false
			return {
				"consumed": true,
				"entered_confirm": true,
			}
		PHASE_CONFIRM:
			if _commit_request_emitted:
				return {
					"consumed": true,
					"commit_requested": false,
					"already_requested": true,
				}
			_commit_request_emitted = true
			var sorted_sources: Array[String] = _selected_source_ids.duplicate()
			sorted_sources.sort()
			return {
				"consumed": true,
				"commit_requested": true,
				"source_ids": sorted_sources,
			}
		PHASE_ANIMATION:
			_phase = PHASE_REVEAL
			_animation_remaining = 0.0
			return {
				"consumed": true,
				"entered_reveal": true,
				"skipped_animation": true,
			}
		PHASE_REVEAL:
			if _finish_request_emitted:
				return {
					"consumed": true,
					"finish_requested": false,
					"already_requested": true,
				}
			_finish_request_emitted = true
			return {
				"consumed": true,
				"finish_requested": true,
				"record": _committed_record.duplicate(true),
			}
	return {"consumed": false}


func cancel_current() -> Dictionary:
	match _phase:
		PHASE_MATERIALS:
			var restored_choices: Array = _origin_choices.duplicate(true)
			reset()
			return {
				"consumed": true,
				"cancel_to_choices": true,
				"origin_choices": restored_choices,
			}
		PHASE_CONFIRM:
			_phase = PHASE_MATERIALS
			_commit_request_emitted = false
			return {
				"consumed": true,
				"entered_materials": true,
			}
		PHASE_ANIMATION, PHASE_REVEAL:
			return {"consumed": true}
	return {"consumed": false}


func begin_committed_result(record: Dictionary, duration: float = DEFAULT_ANIMATION_DURATION) -> bool:
	if _phase != PHASE_CONFIRM or record.is_empty():
		return false
	_committed_record = record.duplicate(true)
	_animation_remaining = maxf(duration, 0.0)
	_finish_request_emitted = false
	_phase = PHASE_ANIMATION
	return true


func update(delta_seconds: float) -> Dictionary:
	if _phase != PHASE_ANIMATION:
		return {"entered_reveal": false}
	_animation_remaining = maxf(0.0, _animation_remaining - maxf(delta_seconds, 0.0))
	if _animation_remaining > 0.0:
		return {"entered_reveal": false}
	_phase = PHASE_REVEAL
	return {
		"entered_reveal": true,
		"record": _committed_record.duplicate(true),
	}


func reset() -> void:
	_phase = PHASE_INACTIVE
	_fusion_card.clear()
	_origin_choices.clear()
	_candidate_ids.clear()
	_selected_source_ids.clear()
	_highlight_index = 0
	_committed_record.clear()
	_animation_remaining = 0.0
	_commit_request_emitted = false
	_finish_request_emitted = false


func _normalize_candidate_ids(candidate_ids: Array) -> Array[String]:
	var seen: Dictionary = {}
	for candidate_value in candidate_ids:
		var candidate_id := str(candidate_value).strip_edges()
		if candidate_id.is_empty():
			continue
		seen[candidate_id] = true
	var normalized: Array[String] = []
	for candidate_id_value in seen.keys():
		normalized.append(str(candidate_id_value))
	normalized.sort()
	return normalized
