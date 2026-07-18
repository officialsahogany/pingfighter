extends RefCounted

const PerkFusionColdBootTimelineState := preload("res://scripts/characters/perk_fusion_cold_boot_timeline_state.gd")

const PHASE_INACTIVE := "inactive"
const PHASE_MATERIALS := "materials"
const PHASE_CONFIRM := "confirm"
const PHASE_ANIMATION := "animation"
const PHASE_REVEAL := "reveal"

# 콜드부트 타임라인(B0~B4 합)이 애니메이션 길이의 단일 권위 — 렌더러의
# 같은 이름 상수도 같은 파생을 읽는다(이중 duration 상수 트랩 봉인).
const DEFAULT_ANIMATION_DURATION := PerkFusionColdBootTimelineState.TOTAL_ANIMATION_DURATION

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
var _cold_boot_timeline: Object = PerkFusionColdBootTimelineState.new()
# 콜드부트 1회성 전이 이벤트 큐(CHNK/THUNK 등 CB3 소비자용): advance/스킵이
# 낳는 ordered 이벤트를 누적하고, consume_cold_boot_events()가 정확히 1회
# 드레인한다 — 저프레임 다중 경계 관통도 소실 없이 전달된다.
var _pending_cold_boot_events: Array[String] = []


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
		"cold_boot": _cold_boot_timeline.get_snapshot(),
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
			# 스킵은 어느 비트에서든 확정 코어 리빌(SETTLE)로 점프한다.
			_pending_cold_boot_events.append_array(_cold_boot_timeline.skip_to_settle())
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


# duration 인자 없음(의도적): 애니메이션 길이는 콜드부트 타임라인 TOTAL이
# 단일 권위 — 호출자별 주입 우회를 시그니처 차원에서 막는다.
func begin_committed_result(record: Dictionary) -> bool:
	if _phase != PHASE_CONFIRM or record.is_empty():
		return false
	_committed_record = record.duplicate(true)
	_animation_remaining = DEFAULT_ANIMATION_DURATION
	_finish_request_emitted = false
	_phase = PHASE_ANIMATION
	_cold_boot_timeline.begin(_committed_record)
	return true


func update(delta_seconds: float) -> Dictionary:
	if _phase != PHASE_ANIMATION:
		return {"entered_reveal": false}
	_pending_cold_boot_events.append_array(_cold_boot_timeline.advance(delta_seconds))
	_animation_remaining = maxf(0.0, _animation_remaining - maxf(delta_seconds, 0.0))
	if _animation_remaining > 0.0:
		return {"entered_reveal": false}
	_phase = PHASE_REVEAL
	# 자연 완주도 SETTLE로 수렴 — float 드리프트로 마지막 비트에 걸쳐 있어도
	# reveal 전이와 함께 홀드 상태로 정렬한다(advance가 이미 settle을 냈다면
	# skip은 빈 배열이라 중복 이벤트 없음).
	_pending_cold_boot_events.append_array(_cold_boot_timeline.skip_to_settle())
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
	_cold_boot_timeline.reset()
	_pending_cold_boot_events.clear()


# 1회성 전이 이벤트 드레인: 호출 시점까지 누적된 이벤트를 순서대로
# 반환하고 비운다. 두 번째 호출은 빈 배열(정확히-한-번 소비 계약).
func consume_cold_boot_events() -> Array[String]:
	var events: Array[String] = _pending_cold_boot_events.duplicate()
	_pending_cold_boot_events.clear()
	return events


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
