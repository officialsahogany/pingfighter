extends RefCounted

const LingpetDurationState := preload("res://scripts/lingpet/lingpet_duration_state.gd")

const MAX_DRAIN_REDUCTION_PCT := 60.0
const MIN_DRAIN_MULTIPLIER := 0.4

var _drain_exempt := false


func reset() -> void:
	_drain_exempt = false


func advance_inactive(affinity_state: Object = null) -> void:
	_drain_exempt = false
	if affinity_state != null and affinity_state.has_method("clear_duration_drain_exempt_latch"):
		affinity_state.clear_duration_drain_exempt_latch()


func latch_drain_exempt(
	owner: Object,
	collection_state: Object,
	affinity_state: Object = null
) -> bool:
	if affinity_state != null and affinity_state.has_method("latch_duration_drain_exempt"):
		_drain_exempt = bool(
			affinity_state.latch_duration_drain_exempt(owner, collection_state)
		)
	else:
		_drain_exempt = is_drain_exempt(owner, collection_state)
	return _drain_exempt


func advance_duration(
	delta: float,
	affinity_state: Object,
	owner: Object,
	collection_state: Object,
	passive_skills: Array,
	summoned: bool
) -> Dictionary:
	var drain_multiplier := get_duration_drain_multiplier(passive_skills)
	var exempt := is_drain_exempt(owner, collection_state, affinity_state)
	var result: Dictionary = affinity_state.advance_duration_pool(
		delta,
		summoned,
		drain_multiplier,
		1.0
	)
	result["drain_exempt"] = exempt
	result["summoned"] = summoned
	return result


func get_active_duration_pct(has_guardian: bool, affinity_state: Object) -> int:
	if not has_guardian or affinity_state == null:
		return 0
	return int(affinity_state.get_duration_pool_pct())


func is_drain_exempt(
	owner: Object,
	collection_state: Object,
	affinity_state: Object = null
) -> bool:
	if affinity_state != null and affinity_state.has_method("is_duration_drain_exempt_latched"):
		if owner == null:
			return bool(affinity_state.is_duration_drain_exempt_latched())
	if owner == null:
		return _drain_exempt
	return (
		collection_state != null
		and collection_state.has_method("is_auto_present_league")
		and bool(collection_state.is_auto_present_league(owner))
	)


func get_duration_drain_multiplier(passive_skills: Array) -> float:
	var reduction_pct := 0.0
	for passive_skill in passive_skills:
		var passive_reduction_pct := 0.0
		if str(passive_skill.get("id", "")).strip_edges() == "lingpet_light_eater":
			passive_reduction_pct = LingpetDurationState.get_drain_reduction_pct_for_level(
				int(passive_skill.get("level", 1))
			)
		else:
			passive_reduction_pct = float(
				passive_skill.get("duration_drain_reduction_pct", 0.0)
			)
		reduction_pct += maxf(0.0, passive_reduction_pct)
	reduction_pct = clampf(reduction_pct, 0.0, MAX_DRAIN_REDUCTION_PCT)
	return clampf(
		1.0 - reduction_pct / 100.0,
		MIN_DRAIN_MULTIPLIER,
		1.0
	)
