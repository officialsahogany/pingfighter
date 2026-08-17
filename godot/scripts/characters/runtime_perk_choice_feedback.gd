extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const APPLY_FAILURE_TEXT := "선택을 적용할 수 없습니다"
const APPLY_FAILURE_TIMER := 1.4
const DOWSING_GOGGLES_BONUS_TEXT := "다우징 고글: 추가 무공 등장!"
const DOWSING_GOGGLES_BONUS_TIMER := 1.25
const MEGINGJORD_EXTRA_PICK_TEXT := "메긴기요르드 발동"
const MEGINGJORD_EXTRA_PICK_TIMER := 1.25


func build_apply_failure_feedback(has_pending_unlock_swap: bool) -> Dictionary:
	if has_pending_unlock_swap:
		return {
			"suppressed": true,
			"feedback_text": "",
			"feedback_timer": 0.0,
		}
	return {
		"suppressed": false,
		"feedback_text": APPLY_FAILURE_TEXT,
		"feedback_timer": APPLY_FAILURE_TIMER,
	}


func apply_failure_feedback_state_update(runtime_state: Object, has_pending_unlock_swap: bool) -> Dictionary:
	return apply_feedback_state_update(
		runtime_state,
		build_apply_failure_feedback(has_pending_unlock_swap)
	)


func apply_failure_feedback_from_runtime_state(runtime_state: Object) -> Dictionary:
	return apply_failure_feedback_state_update(
		runtime_state,
		RuntimePerkRuntimeStateAccess.call_bool(runtime_state, "has_pending_unlock_swap")
	)


func build_dowsing_goggles_bonus_feedback(current_timer: float) -> Dictionary:
	return {
		"feedback_text": DOWSING_GOGGLES_BONUS_TEXT,
		"feedback_timer": maxf(current_timer, DOWSING_GOGGLES_BONUS_TIMER),
	}


func apply_dowsing_goggles_bonus_feedback_state_update(runtime_state: Object, current_timer: float) -> Dictionary:
	return apply_feedback_state_update(
		runtime_state,
		build_dowsing_goggles_bonus_feedback(current_timer),
		current_timer
	)


func build_megingjord_extra_pick_feedback(current_timer: float) -> Dictionary:
	return {
		"feedback_text": MEGINGJORD_EXTRA_PICK_TEXT,
		"feedback_timer": maxf(current_timer, MEGINGJORD_EXTRA_PICK_TIMER),
	}


func has_feedback(current_text: String, current_timer: float) -> bool:
	return current_timer > 0.0 and current_text != ""


func has_feedback_from_runtime_state(runtime_state: Object) -> bool:
	if runtime_state == null:
		return false
	return has_feedback(str(RuntimePerkRuntimeStateAccess.get_string(runtime_state, "feedback_text")), float(RuntimePerkRuntimeStateAccess.get_float(runtime_state, "feedback_timer")))


func build_result_feedback(result: Dictionary, choice: Dictionary, fallback_timer: float) -> Dictionary:
	if not bool(result.get("accepted", false)):
		return {"accepted": false}
	var choice_id := str(choice.get("id", ""))
	return {
		"accepted": true,
		"feedback_text": str(result.get("feedback_text", choice.get("name", choice_id))),
		"feedback_timer": float(result.get("feedback_timer", fallback_timer)),
	}


func apply_result_feedback_state_update(
	runtime_state: Object,
	result: Dictionary,
	choice: Dictionary,
	fallback_timer: float
) -> Dictionary:
	return apply_feedback_state_update(
		runtime_state,
		build_result_feedback(result, choice, fallback_timer),
		fallback_timer
	)


func apply_result_feedback_from_runtime_state(
	runtime_state: Object,
	result: Dictionary,
	choice: Dictionary,
	fallback_timer: float
) -> Dictionary:
	return apply_result_feedback_state_update(runtime_state, result, choice, fallback_timer)


func build_tick_feedback_state_update(current_text: String, current_timer: float, delta: float) -> Dictionary:
	if current_timer <= 0.0:
		return {"accepted": false}
	var next_timer: float = max(0.0, current_timer - delta)
	return {
		"accepted": true,
		"feedback_text": "" if next_timer <= 0.0 else current_text,
		"feedback_timer": next_timer,
	}


func apply_tick_feedback_state_update(
	runtime_state: Object,
	current_text: String,
	current_timer: float,
	delta: float
) -> Dictionary:
	return apply_feedback_state_update(
		runtime_state,
		build_tick_feedback_state_update(current_text, current_timer, delta),
		current_timer
	)


func apply_feedback_state_update(runtime_state: Object, update: Dictionary, fallback_timer: float = 0.0) -> Dictionary:
	if runtime_state == null:
		return {"accepted": false}
	if not bool(update.get("accepted", true)):
		return {"accepted": false}
	runtime_state.set("feedback_text", str(update.get("feedback_text", "")))
	runtime_state.set("feedback_timer", float(update.get("feedback_timer", fallback_timer)))
	return {
		"accepted": true,
		"feedback_text": str(RuntimePerkRuntimeStateAccess.get_string(runtime_state, "feedback_text")),
		"feedback_timer": float(RuntimePerkRuntimeStateAccess.get_float(runtime_state, "feedback_timer")),
	}
