extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")

const PERK_ID := "angel_blessing"
const POLICY_CURRENT_STAGE := "current_stage"
const POLICY_NEXT_VALID_INTRO := "next_valid_intro"

const PHASE_IDLE := "idle"
const PHASE_ROLLING := "rolling"
const PHASE_WAIT_CONFIRM := "wait_confirm"

const MIN_MODAL_DURATION_SECONDS := 3.0
const INPUT_ARM_UPDATE_COUNT := 1
const ABSORB_PARTICLE_DURATION_SECONDS := 1.8
const ABSORB_STAGGER_SECONDS := 0.25
const ABSORB_PLAYER_GLOW_SECONDS := 0.35

var _pending_rolls: Array[Dictionary] = []
var _pending_reveals: Array[Dictionary] = []
var _active_modal: Dictionary = {}
var _modal_phase := PHASE_IDLE
var _modal_elapsed := 0.0
var _input_armed := false
var _input_arm_updates_remaining := 0
var _rt_confirm_latched := false
var _absorb_visual_state: Dictionary = {}
var _sequence := 0


# RuntimePerkState integration contract:
# 1. A successful battle-time acquisition calls queue_current_stage_roll().
# 2. A result-screen acquisition calls queue_next_valid_intro_roll().
# 3. The acquisition-cinematic falling edge calls
#    mark_acquisition_cinematic_finished().
# 4. Once every higher-priority modal is closed, the facade takes a roll with
#    take_ready_roll_for_stage(), resolves the numeric Angel roll, queues that
#    successful result with queue_reveal_from_roll_result(), and opens it with
#    begin_next_pending_reveal().
# 5. update() is pumped from the ungated overlay clock. handle_input() consumes
#    input only while this logical modal is active. The detached overlay host
#    consumes get_snapshot() but never owns or advances this logical state.


func queue_current_stage_roll(
	stage: int,
	reason: String = "",
	wait_for_cinematic: bool = true
) -> Dictionary:
	return queue_pending_roll(stage, POLICY_CURRENT_STAGE, wait_for_cinematic, reason)


func queue_next_valid_intro_roll(
	reason: String = "",
	wait_for_cinematic: bool = false
) -> Dictionary:
	return queue_pending_roll(0, POLICY_NEXT_VALID_INTRO, wait_for_cinematic, reason)


func queue_pending_roll(
	stage: int,
	policy: String,
	wait_for_cinematic: bool = false,
	reason: String = ""
) -> Dictionary:
	var normalized_policy := _normalize_policy(policy)
	if normalized_policy == "":
		return {"accepted": false, "blocked_reason": "invalid_policy"}
	if normalized_policy == POLICY_CURRENT_STAGE and stage < 1:
		return {"accepted": false, "blocked_reason": "invalid_stage"}

	var existing_index := _find_pending_roll_index(stage, normalized_policy)
	if existing_index >= 0:
		var existing: Dictionary = _pending_rolls[existing_index]
		_append_reason(existing, reason)
		# A ready reservation must never be moved back behind a cinematic merely
		# because the same stage was queued by a second integration path.
		if not wait_for_cinematic:
			existing["waiting_for_cinematic"] = false
			existing["ready"] = true
		_pending_rolls[existing_index] = existing
		return {
			"accepted": true,
			"queued": false,
			"deduplicated": true,
			"entry": existing.duplicate(true),
		}

	_sequence += 1
	var entry := {
		"stage": stage if normalized_policy == POLICY_CURRENT_STAGE else 0,
		"policy": normalized_policy,
		"waiting_for_cinematic": wait_for_cinematic,
		"ready": not wait_for_cinematic,
		"reason": reason.strip_edges(),
		"reasons": _build_reason_list(reason),
		"sequence": _sequence,
	}
	_pending_rolls.append(entry)
	return {
		"accepted": true,
		"queued": true,
		"deduplicated": false,
		"entry": entry.duplicate(true),
	}


func mark_acquisition_cinematic_finished(stage_or_perk: Variant = 0, policy: String = "") -> int:
	var stage := 0
	var normalized_policy := ""
	if policy.strip_edges() != "":
		normalized_policy = _normalize_policy(policy)
		if normalized_policy == "":
			return 0
	if stage_or_perk is String:
		if str(stage_or_perk).strip_edges() != PERK_ID:
			return 0
		# The shared completion helper reports the acquired perk id, not the
		# route. Release whichever Angel reservation was waiting; its policy still
		# controls whether it may roll now or only at a future valid intro.
	elif stage_or_perk is int or stage_or_perk is float:
		stage = int(stage_or_perk)
	else:
		return 0
	var released := 0
	for index: int in range(_pending_rolls.size()):
		var entry: Dictionary = _pending_rolls[index]
		if normalized_policy != "" and str(entry.get("policy", "")) != normalized_policy:
			continue
		if stage > 0 and int(entry.get("stage", 0)) not in [0, stage]:
			continue
		if not bool(entry.get("waiting_for_cinematic", false)):
			continue
		entry["waiting_for_cinematic"] = false
		entry["ready"] = true
		_pending_rolls[index] = entry
		released += 1
	return released


func take_ready_roll_for_stage(stage: int, at_valid_intro: bool = false) -> Dictionary:
	if stage < 1:
		return {}
	for index: int in range(_pending_rolls.size()):
		var entry: Dictionary = _pending_rolls[index]
		if bool(entry.get("waiting_for_cinematic", false)) or not bool(entry.get("ready", false)):
			continue
		var policy := str(entry.get("policy", ""))
		if policy == POLICY_CURRENT_STAGE and int(entry.get("stage", 0)) != stage:
			continue
		if policy == POLICY_NEXT_VALID_INTRO and not at_valid_intro:
			continue
		var consumed: Dictionary = entry.duplicate(true)
		consumed["stage"] = stage
		_pending_rolls.remove_at(index)
		return consumed
	return {}


func queue_reveal_from_roll_result(roll_result: Dictionary, reason: String = "") -> Dictionary:
	return queue_pending_reveal(
		int(roll_result.get("active_stage", 0)),
		roll_result,
		reason
	)


func queue_pending_reveal(
	stage: int,
	roll_result: Dictionary,
	reason: String = ""
) -> Dictionary:
	if stage < 1:
		return {"accepted": false, "blocked_reason": "invalid_stage"}
	if roll_result.is_empty() or not bool(roll_result.get("rolled", false)):
		return {"accepted": false, "blocked_reason": "roll_not_successful"}
	var existing_index := _find_pending_reveal_index(stage)
	if existing_index >= 0:
		var existing: Dictionary = _pending_reveals[existing_index]
		_append_reason(existing, reason)
		_pending_reveals[existing_index] = existing
		return {
			"accepted": true,
			"queued": false,
			"deduplicated": true,
			"entry": existing.duplicate(true),
		}

	_sequence += 1
	var entry := {
		"stage": stage,
		"roll_result": roll_result.duplicate(true),
		"reason": reason.strip_edges(),
		"reasons": _build_reason_list(reason),
		"sequence": _sequence,
	}
	_pending_reveals.append(entry)
	return {
		"accepted": true,
		"queued": true,
		"deduplicated": false,
		"entry": entry.duplicate(true),
	}


func begin_next_pending_reveal(stage: int = 0) -> Dictionary:
	if is_modal_active():
		return {"accepted": false, "blocked_reason": "modal_already_active"}
	var reveal_index := _find_next_reveal_index(stage)
	if reveal_index < 0:
		return {"accepted": false, "blocked_reason": "no_pending_reveal"}
	_active_modal = _pending_reveals[reveal_index].duplicate(true)
	_pending_reveals.remove_at(reveal_index)
	_modal_phase = PHASE_ROLLING
	_modal_elapsed = 0.0
	_input_armed = false
	_input_arm_updates_remaining = INPUT_ARM_UPDATE_COUNT
	# The predecessor input is consumed by its owning controller before this
	# modal opens. Start neutral so a genuinely fresh RT press can confirm after
	# three seconds; an RT event observed during the unarmed window still latches
	# and therefore requires a release before the next press.
	_rt_confirm_latched = false
	return {
		"accepted": true,
		"started": true,
		"active_modal": _active_modal.duplicate(true),
	}


func update(delta: float) -> Dictionary:
	var absorption_update: Dictionary = _update_absorption(delta)
	if not is_modal_active():
		return {
			"active": false,
			"entered_wait_confirm": false,
			"input_armed": false,
			"absorption": absorption_update,
			"visual_active": has_visual_work(),
		}

	if _input_arm_updates_remaining > 0:
		_input_arm_updates_remaining -= 1
		if _input_arm_updates_remaining <= 0:
			_input_armed = true

	_modal_elapsed += maxf(0.0, delta)
	var entered_wait_confirm := false
	if _modal_phase == PHASE_ROLLING and _modal_elapsed >= MIN_MODAL_DURATION_SECONDS:
		_modal_phase = PHASE_WAIT_CONFIRM
		entered_wait_confirm = true
	return {
		"active": true,
		"entered_wait_confirm": entered_wait_confirm,
		"input_armed": _input_armed,
		"modal_phase": _modal_phase,
		"modal_elapsed": _modal_elapsed,
		"absorption": absorption_update,
		"visual_active": true,
	}


func handle_input(event: InputEvent) -> Dictionary:
	if not is_modal_active():
		return {"consumed": false, "confirmed": false}
	if event == null:
		return {"consumed": false, "confirmed": false}

	var requested_confirm := false
	var requested_by_rt := false
	if event is InputEventJoypadMotion:
		var motion_event := event as InputEventJoypadMotion
		if motion_event.axis == JOY_AXIS_TRIGGER_RIGHT:
			if motion_event.axis_value <= GamepadInput.PRIMARY_ACTION_TRIGGER_SUPPRESS_RELEASE_THRESHOLD:
				_rt_confirm_latched = false
				GamepadInput.update_primary_action_trigger_suppression_from_event(event)
				return {"consumed": true, "confirmed": false, "rt_released": true}
			if motion_event.axis_value >= GamepadInput.TRIGGER_DEADZONE:
				if _rt_confirm_latched:
					return {"consumed": true, "confirmed": false, "blocked_reason": "rt_release_required"}
				_rt_confirm_latched = true
				requested_confirm = true
				requested_by_rt = true
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		requested_confirm = (
			key_event.pressed
			and not key_event.echo
			and _is_confirm_key(key_event)
		)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		requested_confirm = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		requested_confirm = touch_event.pressed
	elif GamepadInput.is_confirm_event(event):
		requested_confirm = true

	if not requested_confirm:
		return {"consumed": true, "confirmed": false}
	if not _input_armed:
		return {"consumed": true, "confirmed": false, "blocked_reason": "input_not_armed"}
	if _modal_phase != PHASE_WAIT_CONFIRM or _modal_elapsed < MIN_MODAL_DURATION_SECONDS:
		return {"consumed": true, "confirmed": false, "blocked_reason": "minimum_duration"}
	var dismissed: Dictionary = _active_modal.duplicate(true)
	if requested_by_rt:
		GamepadInput.suppress_primary_action_trigger_until_release()
	var absorption: Dictionary = _begin_absorption_from_modal(dismissed)
	_clear_active_modal()
	return {
		"consumed": true,
		"confirmed": true,
		"dismissed": true,
		"modal": dismissed,
		"absorption": absorption,
	}


func cancel_active_presentation() -> Dictionary:
	var had_active := is_modal_active()
	var canceled: Dictionary = _active_modal.duplicate(true)
	_clear_active_modal()
	return {
		"canceled": had_active,
		"modal": canceled,
	}


# Round boundaries preserve unresolved roll/reveal reservations. The active
# presentation itself cannot survive a forced score/serve boundary; the numeric
# Angel result lives in runtime_perk_angel_blessing_state.gd and is untouched.
# If the predecessor acquisition cinematic was canceled by that boundary, it
# can no longer produce a natural completion edge, so release only the preserved
# current-stage reservation instead of leaving it waiting forever.
func reset_for_round_boundary() -> void:
	cancel_active_presentation()
	_clear_absorption()
	mark_acquisition_cinematic_finished(PERK_ID, POLICY_CURRENT_STAGE)


# Stage transitions discard old-stage work but keep a result-screen reservation
# whose policy explicitly targets the next valid stage intro.
func reset_for_stage_boundary() -> void:
	cancel_active_presentation()
	_clear_absorption()
	_pending_reveals.clear()
	for index: int in range(_pending_rolls.size() - 1, -1, -1):
		if str(_pending_rolls[index].get("policy", "")) == POLICY_CURRENT_STAGE:
			_pending_rolls.remove_at(index)
	# A forced transition cancels any still-running result acquisition
	# cinematic. Preserve the next-intro reservation but remove the impossible
	# predecessor wait so the real destination intro can consume it.
	mark_acquisition_cinematic_finished(PERK_ID, POLICY_NEXT_VALID_INTRO)


func reset() -> void:
	_pending_rolls.clear()
	_pending_reveals.clear()
	_clear_active_modal()
	_clear_absorption()
	_sequence = 0


func is_modal_active() -> bool:
	return _modal_phase != PHASE_IDLE and not _active_modal.is_empty()


func has_pending_rolls() -> bool:
	return not _pending_rolls.is_empty()


func has_pending_reveals() -> bool:
	return not _pending_reveals.is_empty()


func has_ready_current_stage_roll() -> bool:
	for entry: Dictionary in _pending_rolls:
		if (
			str(entry.get("policy", "")) == POLICY_CURRENT_STAGE
			and bool(entry.get("ready", false))
			and not bool(entry.get("waiting_for_cinematic", false))
		):
			return true
	return false


func has_work() -> bool:
	return is_modal_active() or has_pending_rolls() or has_pending_reveals() or has_visual_work()


func has_visual_work() -> bool:
	return is_modal_active() or is_absorption_active()


func is_absorption_active() -> bool:
	return bool(_absorb_visual_state.get("active", false))


func get_pending_count() -> int:
	return _pending_rolls.size() + _pending_reveals.size()


func is_waiting_for_confirm() -> bool:
	return _modal_phase == PHASE_WAIT_CONFIRM


func is_input_armed() -> bool:
	return _input_armed


func get_snapshot() -> Dictionary:
	return {
		"pending_stage": _get_pending_stage(),
		"pending_count": get_pending_count(),
		"pending_rolls": _copy_dictionary_array(_pending_rolls),
		"pending_reveals": _copy_dictionary_array(_pending_reveals),
		"modal_active": is_modal_active(),
		"modal_phase": _modal_phase,
		"modal_elapsed": _modal_elapsed,
		"waiting_for_confirm": is_waiting_for_confirm(),
		"input_armed": _input_armed,
		"confirm_armed": _input_armed and is_waiting_for_confirm(),
		"active_modal": _active_modal.duplicate(true),
		"absorption": _absorb_visual_state.duplicate(true),
	}


func _begin_absorption_from_modal(modal: Dictionary) -> Dictionary:
	var roll_result_value: Variant = modal.get("roll_result", {})
	var roll_result: Dictionary = roll_result_value if roll_result_value is Dictionary else {}
	var buff_ids: Array[String] = []
	for value: Variant in roll_result.get("active_buff_ids", []):
		var buff_id := str(value).strip_edges()
		if buff_id != "" and buff_id not in buff_ids:
			buff_ids.append(buff_id)
	var trajectories: Array[Dictionary] = []
	for index: int in range(buff_ids.size()):
		var delay := float(index) * ABSORB_STAGGER_SECONDS
		trajectories.append({
			"index": index,
			"buff_id": buff_ids[index],
			"delay": delay,
			"travel_duration": ABSORB_PARTICLE_DURATION_SECONDS,
			"arrival_time": delay + ABSORB_PARTICLE_DURATION_SECONDS,
		})
	var last_arrival := ABSORB_PARTICLE_DURATION_SECONDS
	if not trajectories.is_empty():
		last_arrival = float(trajectories.back().get("arrival_time", last_arrival))
	_absorb_visual_state = {
		"active": not trajectories.is_empty(),
		"elapsed": 0.0,
		"particle_duration": ABSORB_PARTICLE_DURATION_SECONDS,
		"stagger": ABSORB_STAGGER_SECONDS,
		"glow_duration": ABSORB_PLAYER_GLOW_SECONDS,
		"total_duration": last_arrival + ABSORB_PLAYER_GLOW_SECONDS,
		"cue_cursor": 0,
		"roll_face": int(roll_result.get("roll_face", trajectories.size())),
		"active_buff_ids": buff_ids.duplicate(),
		"trajectories": trajectories,
	}
	return _absorb_visual_state.duplicate(true)


func _update_absorption(delta: float) -> Dictionary:
	if not is_absorption_active():
		return {"active": false, "arrival_cues": []}
	var previous_elapsed := float(_absorb_visual_state.get("elapsed", 0.0))
	var next_elapsed := previous_elapsed + maxf(0.0, delta)
	var arrival_cues: Array[Dictionary] = []
	var trajectories_value: Variant = _absorb_visual_state.get("trajectories", [])
	var trajectories: Array = trajectories_value if trajectories_value is Array else []
	var cue_cursor := int(_absorb_visual_state.get("cue_cursor", 0))
	while cue_cursor < trajectories.size():
		var trajectory_value: Variant = trajectories[cue_cursor]
		if not (trajectory_value is Dictionary):
			cue_cursor += 1
			continue
		var trajectory: Dictionary = trajectory_value
		var arrival_time := float(trajectory.get("arrival_time", 0.0))
		if arrival_time > next_elapsed:
			break
		if arrival_time > previous_elapsed or is_zero_approx(previous_elapsed):
			arrival_cues.append(trajectory.duplicate(true))
		cue_cursor += 1
	_absorb_visual_state["elapsed"] = next_elapsed
	_absorb_visual_state["cue_cursor"] = cue_cursor
	var completed := next_elapsed >= float(_absorb_visual_state.get("total_duration", 0.0))
	var snapshot: Dictionary = _absorb_visual_state.duplicate(true)
	snapshot["arrival_cues"] = arrival_cues
	snapshot["completed"] = completed
	if completed:
		_clear_absorption()
	return snapshot


func _clear_absorption() -> void:
	_absorb_visual_state.clear()


func _find_pending_roll_index(stage: int, policy: String) -> int:
	for index: int in range(_pending_rolls.size()):
		var entry: Dictionary = _pending_rolls[index]
		if str(entry.get("policy", "")) != policy:
			continue
		if policy == POLICY_NEXT_VALID_INTRO or int(entry.get("stage", 0)) == stage:
			return index
	return -1


func _find_pending_reveal_index(stage: int) -> int:
	for index: int in range(_pending_reveals.size()):
		if int(_pending_reveals[index].get("stage", 0)) == stage:
			return index
	return -1


func _find_next_reveal_index(stage: int) -> int:
	if stage <= 0:
		return 0 if not _pending_reveals.is_empty() else -1
	return _find_pending_reveal_index(stage)


func _get_pending_stage() -> int:
	for entry: Dictionary in _pending_rolls:
		var stage := int(entry.get("stage", 0))
		if stage > 0:
			return stage
	if not _pending_reveals.is_empty():
		return int(_pending_reveals[0].get("stage", 0))
	return 0


func _normalize_policy(policy: String) -> String:
	var normalized := policy.strip_edges().to_lower()
	if normalized in [POLICY_CURRENT_STAGE, POLICY_NEXT_VALID_INTRO]:
		return normalized
	return ""


func _append_reason(entry: Dictionary, reason: String) -> void:
	var clean_reason := reason.strip_edges()
	if clean_reason == "":
		return
	var reasons_value: Variant = entry.get("reasons", [])
	var reasons: Array = reasons_value if reasons_value is Array else []
	if clean_reason not in reasons:
		reasons.append(clean_reason)
	entry["reasons"] = reasons
	if str(entry.get("reason", "")) == "":
		entry["reason"] = clean_reason


func _build_reason_list(reason: String) -> Array[String]:
	var clean_reason := reason.strip_edges()
	var reasons: Array[String] = []
	if clean_reason != "":
		reasons.append(clean_reason)
	return reasons


func _is_confirm_key(event: InputEventKey) -> bool:
	return (
		event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
		or event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
	)


func _copy_dictionary_array(values: Array[Dictionary]) -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	for value: Dictionary in values:
		copied.append(value.duplicate(true))
	return copied


func _clear_active_modal() -> void:
	_active_modal.clear()
	_modal_phase = PHASE_IDLE
	_modal_elapsed = 0.0
	_input_armed = false
	_input_arm_updates_remaining = 0
	_rt_confirm_latched = false
