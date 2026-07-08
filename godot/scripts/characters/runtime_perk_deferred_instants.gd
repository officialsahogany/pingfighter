extends RefCounted

const DEFER_DIMENSION_GATE_CONTEXT_KEY := "defer_instant_dimension_gate_until_spawn_intro_end"
const DEFER_FULL_GAUGE_CONTEXT_KEY := "defer_instant_full_gauge_until_spawn_intro_end"
const DEFERRED_CHOICE_FEEDBACK_TIMER := 1.2

var dimension_gate_pending := false
var dimension_gate_origin_stage := 0
var dimension_gate_feedback_text := ""
var full_gauge_pending := false
var full_gauge_origin_stage := 0
var full_gauge_feedback_text := ""


func reset() -> void:
	dimension_gate_pending = false
	dimension_gate_origin_stage = 0
	dimension_gate_feedback_text = ""
	full_gauge_pending = false
	full_gauge_origin_stage = 0
	full_gauge_feedback_text = ""


func should_defer_dimension_gate(choice_context: Dictionary) -> bool:
	return bool(choice_context.get(DEFER_DIMENSION_GATE_CONTEXT_KEY, false))


func should_defer_full_gauge(choice_context: Dictionary) -> bool:
	return bool(choice_context.get(DEFER_FULL_GAUGE_CONTEXT_KEY, false))


func queue_dimension_gate(owner: Object, pending_feedback_text: String = "") -> void:
	dimension_gate_pending = true
	dimension_gate_origin_stage = _get_current_stage(owner)
	dimension_gate_feedback_text = pending_feedback_text


func queue_dimension_gate_choice(owner: Object, choice_name: String = "") -> Dictionary:
	queue_dimension_gate(owner, choice_name)
	return _build_queued_choice_result(choice_name)


func queue_full_gauge(owner: Object, pending_feedback_text: String = "") -> void:
	full_gauge_pending = true
	full_gauge_origin_stage = _get_current_stage(owner)
	full_gauge_feedback_text = pending_feedback_text


func queue_full_gauge_choice(owner: Object, choice_name: String = "") -> Dictionary:
	queue_full_gauge(owner, choice_name)
	return _build_queued_choice_result(choice_name)


func has_pending_dimension_gate() -> bool:
	return dimension_gate_pending


func has_pending_full_gauge() -> bool:
	return full_gauge_pending


func get_dimension_gate_origin_stage() -> int:
	return dimension_gate_origin_stage


func get_full_gauge_origin_stage() -> int:
	return full_gauge_origin_stage


func collect_spawn_intro_actions(owner: Object) -> Dictionary:
	var result := {
		"dimension_gate_pending": dimension_gate_pending,
		"dimension_gate_ready": false,
		"dimension_gate_feedback_text": "",
		"full_gauge_pending": full_gauge_pending,
		"full_gauge_ready": false,
		"full_gauge_feedback_text": "",
		"wait_for_stage_advance": false,
	}
	if not dimension_gate_pending and not full_gauge_pending:
		return result
	var current_stage_value: int = _get_current_stage(owner)
	if (
		dimension_gate_pending
		and dimension_gate_origin_stage > 0
		and current_stage_value == dimension_gate_origin_stage
	):
		result["wait_for_stage_advance"] = true
	elif dimension_gate_pending:
		result["dimension_gate_ready"] = true
		result["dimension_gate_feedback_text"] = dimension_gate_feedback_text
		dimension_gate_pending = false
		dimension_gate_origin_stage = 0
		dimension_gate_feedback_text = ""

	if (
		full_gauge_pending
		and full_gauge_origin_stage > 0
		and current_stage_value == full_gauge_origin_stage
	):
		result["wait_for_stage_advance"] = true
	elif full_gauge_pending:
		result["full_gauge_ready"] = true
		result["full_gauge_feedback_text"] = full_gauge_feedback_text
		full_gauge_pending = false
		full_gauge_origin_stage = 0
		full_gauge_feedback_text = ""
	return result


func resolve_spawn_intro_actions(
	actions: Dictionary,
	owner: Object,
	registry: Object,
	apply_dimension_gate: Callable,
	apply_full_gauge: Callable
) -> Dictionary:
	var result := {
		"dimension_gate_pending": bool(actions.get("dimension_gate_pending", false)),
		"dimension_gate_activated": false,
		"dimension_gate_failed": false,
		"full_gauge_pending": bool(actions.get("full_gauge_pending", false)),
		"full_gauge_activated": false,
		"wait_for_stage_advance": bool(actions.get("wait_for_stage_advance", false)),
		"_feedback_text": "",
		"_feedback_timer": 0.0,
		"_sync_owner": false,
	}
	if not bool(result.get("dimension_gate_pending", false)) and not bool(result.get("full_gauge_pending", false)):
		return result
	if bool(actions.get("dimension_gate_ready", false)):
		var dimension_feedback_text := str(actions.get("dimension_gate_feedback_text", ""))
		if apply_dimension_gate.is_valid() and bool(apply_dimension_gate.call(registry)):
			result["dimension_gate_activated"] = true
			result["_feedback_text"] = resolve_feedback_text(dimension_feedback_text, "instant_dimension_gate")
			result["_feedback_timer"] = 1.2
		else:
			result["dimension_gate_failed"] = true
		result["_sync_owner"] = true
	if bool(actions.get("full_gauge_ready", false)):
		var full_gauge_feedback_text := str(actions.get("full_gauge_feedback_text", ""))
		if apply_full_gauge.is_valid():
			apply_full_gauge.call(owner, registry)
		result["full_gauge_activated"] = true
		result["_feedback_text"] = resolve_feedback_text(full_gauge_feedback_text, "instant_gauge_full")
		result["_feedback_timer"] = 1.2
		result["_sync_owner"] = true
	return result


func build_spawn_intro_state_update(result: Dictionary) -> Dictionary:
	var public_result := result.duplicate(true)
	var feedback_text := str(public_result.get("_feedback_text", ""))
	var feedback_timer := float(public_result.get("_feedback_timer", DEFERRED_CHOICE_FEEDBACK_TIMER))
	var sync_owner := bool(public_result.get("_sync_owner", false))
	public_result.erase("_feedback_text")
	public_result.erase("_feedback_timer")
	public_result.erase("_sync_owner")
	return {
		"has_feedback": feedback_text != "",
		"feedback_text": feedback_text,
		"feedback_timer": feedback_timer,
		"sync_owner": sync_owner,
		"public_result": public_result,
	}


func apply_spawn_intro_state_update(
	runtime_state: Object,
	result: Dictionary,
	feedback_apply: Callable,
	fallback_timer: float = DEFERRED_CHOICE_FEEDBACK_TIMER
) -> Dictionary:
	var state_update := build_spawn_intro_state_update(result)
	if bool(state_update.get("has_feedback", false)) and feedback_apply.is_valid():
		feedback_apply.call(runtime_state, state_update, fallback_timer)
	return state_update


func resolve_feedback_text(pending_feedback_text: String, fallback: String) -> String:
	if pending_feedback_text != "":
		return pending_feedback_text
	return fallback


func _build_queued_choice_result(choice_name: String) -> Dictionary:
	return {
		"accepted": true,
		"feedback_text": choice_name,
		"feedback_timer": DEFERRED_CHOICE_FEEDBACK_TIMER,
	}


func _get_current_stage(owner: Object) -> int:
	if owner == null:
		return 0
	var value: Variant = owner.get("current_stage")
	if value == null:
		return 0
	return max(0, int(value))
