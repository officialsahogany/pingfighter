extends RefCounted

const LingpetGuardianEnhanceOfferEngine := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_offer_engine.gd"
)

const RUNTIME_KEY := "lingpet_egg_runtime"


static func begin(choice: Dictionary, owner: Object, registry: Object) -> Dictionary:
	var runtime := _get_runtime(registry)
	if runtime == null or not runtime.has_method("apply_guardian_enhance_random_roll"):
		return {"accepted": false, "blocked_reason": "missing_lingpet_runtime"}
	var raw_candidates: Variant = choice.get("guardian_enhance_candidates", [])
	var candidates: Array = raw_candidates if raw_candidates is Array else []
	var result: Dictionary = runtime.call(
		"apply_guardian_enhance_random_roll",
		candidates,
		owner,
		registry
	)
	result["modal_started"] = false
	return result


static func resolve_random_roll(
	candidates: Array,
	can_apply: Callable,
	apply_candidate: Callable,
	apply_fallback: Callable,
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var remaining: Array[Dictionary] = []
	for source_index in range(candidates.size()):
		var value: Variant = candidates[source_index]
		if value is Dictionary:
			var candidate := (value as Dictionary).duplicate(true)
			if str(candidate.get("type", "")).strip_edges() != "":
				remaining.append({"candidate": candidate, "source_index": source_index})
	var rejected_indices: Array[int] = []
	var roll_order: Array[int] = []
	while not remaining.is_empty():
		var remaining_index := _weighted_index(remaining, rng)
		var entry: Dictionary = remaining[remaining_index]
		remaining.remove_at(remaining_index)
		var candidate: Dictionary = entry.get("candidate", {}) as Dictionary
		var source_index := int(entry.get("source_index", -1))
		roll_order.append(source_index)
		if not can_apply.is_valid() or not bool(can_apply.call(candidate)):
			rejected_indices.append(source_index)
			continue
		var apply_result := _call_result(apply_candidate, [candidate])
		if not bool(apply_result.get("accepted", false)):
			rejected_indices.append(source_index)
			continue
		return {
			"accepted": true,
			"modal_started": false,
			"applied_index": source_index,
			"applied_candidate": candidate.duplicate(true),
			"rerolled": roll_order.size() > 1,
			"fallback_used": false,
			"roll_order": roll_order.duplicate(),
			"rejected_indices": rejected_indices.duplicate(),
			"feedback_text": _build_feedback(candidate, false, apply_result),
			"result_detail": (apply_result.get("result_detail", {}) as Dictionary).duplicate(true),
			"apply_result": apply_result,
		}
	var fallback_result := _call_result(apply_fallback, [])
	return {
		"accepted": bool(fallback_result.get("accepted", false)),
		"modal_started": false,
		"applied_index": -1,
		"applied_candidate": {},
		"rerolled": roll_order.size() > 1,
		"fallback_used": true,
		"roll_order": roll_order.duplicate(),
		"rejected_indices": rejected_indices.duplicate(),
		"feedback_text": _build_feedback({}, true, fallback_result),
		"result_detail": (fallback_result.get("result_detail", {}) as Dictionary).duplicate(true),
		"apply_result": fallback_result,
	}


static func _weighted_index(entries: Array[Dictionary], rng: RandomNumberGenerator) -> int:
	var total_weight := 0.0
	for entry in entries:
		total_weight += _candidate_weight(entry.get("candidate", {}) as Dictionary)
	var roll := (
		rng.randf_range(0.0, total_weight)
		if rng != null
		else randf_range(0.0, total_weight)
	)
	for index in range(entries.size()):
		roll -= _candidate_weight(entries[index].get("candidate", {}) as Dictionary)
		if roll <= 0.0:
			return index
	return maxi(0, entries.size() - 1)


static func _candidate_weight(candidate: Dictionary) -> float:
	return maxf(0.001, float(candidate.get(
		"weight",
		LingpetGuardianEnhanceOfferEngine.DEFAULT_WEIGHT
	)))


static func _build_feedback(
	candidate: Dictionary,
	fallback_used: bool,
	apply_result: Dictionary = {}
) -> String:
	return LingpetGuardianEnhanceOfferEngine.format_result_feedback(
		candidate,
		apply_result.get("result_detail", {}) as Dictionary,
		fallback_used
	)


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
