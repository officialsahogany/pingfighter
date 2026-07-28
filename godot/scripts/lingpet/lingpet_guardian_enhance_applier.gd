extends RefCounted

const LingpetGuardianEnhanceOfferEngine := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_offer_engine.gd"
)

const RUNTIME_KEY := "lingpet_egg_runtime"


static func begin(choice: Dictionary, owner: Object, registry: Object) -> Dictionary:
	var runtime := _get_runtime(registry)
	if runtime == null or not runtime.has_method("start_guardian_enhance_choice"):
		return {"accepted": false, "blocked_reason": "missing_lingpet_runtime"}
	var raw_candidates: Variant = choice.get("guardian_enhance_candidates", [])
	var candidates: Array = raw_candidates if raw_candidates is Array else []
	var started := bool(runtime.call("start_guardian_enhance_choice", candidates, owner, registry))
	return {
		"accepted": started,
		"modal_started": started,
		"blocked_reason": "" if started else "choice_modal_rejected",
	}


static func confirm_from_runtime(
	runtime: Object,
	owner: Object,
	registry: Object
) -> Dictionary:
	if runtime == null or not runtime.has_method("get_guardian_enhance_choice_snapshot"):
		return {"accepted": false, "modal_should_close": true, "blocked_reason": "missing_runtime"}
	var snapshot: Dictionary = runtime.call("get_guardian_enhance_choice_snapshot")
	var result := resolve_selection(
		snapshot.get("candidates", []) as Array,
		int(snapshot.get("selected_index", 0)),
		Callable(runtime, "can_apply_guardian_enhancement_candidate"),
		Callable(runtime, "apply_guardian_enhancement_candidate").bind(owner, registry),
		Callable(runtime, "apply_guardian_enhance_duration_fallback").bind(owner, registry)
	)
	if runtime.has_method("complete_guardian_enhance_choice"):
		runtime.call("complete_guardian_enhance_choice", result, registry)
	return result


static func resolve_choice_state(
	choice_state: Object,
	can_apply: Callable,
	apply_candidate: Callable,
	apply_fallback: Callable
) -> Dictionary:
	if choice_state == null or not choice_state.has_method("get_snapshot"):
		return {"accepted": false, "modal_should_close": true, "blocked_reason": "missing_choice_state"}
	var snapshot: Dictionary = choice_state.get_snapshot()
	var result := resolve_selection(
		snapshot.get("candidates", []) as Array,
		int(snapshot.get("selected_index", 0)),
		can_apply,
		apply_candidate,
		apply_fallback
	)
	if choice_state.has_method("close"):
		choice_state.close()
	result["modal_closed"] = not bool(choice_state.get("active"))
	return result


static func resolve_selection(
	candidates: Array,
	selected_index: int,
	can_apply: Callable,
	apply_candidate: Callable,
	apply_fallback: Callable
) -> Dictionary:
	var normalized: Array[Dictionary] = []
	for value in candidates:
		if value is Dictionary:
			normalized.append((value as Dictionary).duplicate(true))
	var selected := clampi(selected_index, 0, maxi(0, normalized.size() - 1))
	var attempt_order: Array[int] = []
	if not normalized.is_empty():
		attempt_order.append(selected)
	for index in range(normalized.size()):
		if index != selected:
			attempt_order.append(index)
	var rejected_indices: Array[int] = []
	for index in attempt_order:
		var candidate := normalized[index]
		if not can_apply.is_valid() or not bool(can_apply.call(candidate)):
			rejected_indices.append(index)
			continue
		var apply_result := _call_result(apply_candidate, [candidate])
		if not bool(apply_result.get("accepted", false)):
			rejected_indices.append(index)
			continue
		var auto_replaced := index != selected
		return {
			"accepted": true,
			"modal_should_close": true,
			"selected_index": selected,
			"applied_index": index,
			"selected_candidate": normalized[selected].duplicate(true),
			"applied_candidate": candidate.duplicate(true),
			"auto_replaced": auto_replaced,
			"fallback_used": false,
			"rejected_indices": rejected_indices.duplicate(),
			"feedback_text": _build_feedback(candidate, auto_replaced, false),
			"apply_result": apply_result,
		}
	var fallback_result := _call_result(apply_fallback, [])
	return {
		"accepted": bool(fallback_result.get("accepted", false)),
		"modal_should_close": true,
		"selected_index": selected,
		"applied_index": -1,
		"selected_candidate": (
			normalized[selected].duplicate(true) if not normalized.is_empty() else {}
		),
		"applied_candidate": {},
		"auto_replaced": false,
		"fallback_used": true,
		"rejected_indices": rejected_indices.duplicate(),
		"feedback_text": _build_feedback({}, false, true),
		"apply_result": fallback_result,
	}


static func _build_feedback(candidate: Dictionary, auto_replaced: bool, fallback_used: bool) -> String:
	if fallback_used:
		return "모든 후보가 무효가 되어 지속시간 현재치 +15초로 대체되었습니다."
	var localized := LingpetGuardianEnhanceOfferEngine.localize_candidate(candidate)
	var label := str(localized.get("label", "수호령강화"))
	if auto_replaced:
		return "선택 후보가 무효가 되어 %s(으)로 자동 대체되었습니다." % label
	return "%s 획득" % label


static func _call_result(callback: Callable, args: Array) -> Dictionary:
	if not callback.is_valid():
		return {"accepted": false, "blocked_reason": "missing_callback"}
	var value: Variant = callback.callv(args)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {"accepted": bool(value)}


static func _get_runtime(registry: Object) -> Object:
	if registry == null:
		return null
	var value: Variant = null
	if registry.has_method("get_cached_instance"):
		value = registry.get_cached_instance(RUNTIME_KEY)
	if (typeof(value) != TYPE_OBJECT or value == null) and registry.has_method("get_instance"):
		value = registry.get_instance(RUNTIME_KEY)
	if typeof(value) == TYPE_OBJECT and value != null and is_instance_valid(value):
		return value as Object
	return null
