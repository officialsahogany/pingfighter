extends RefCounted

# Transitional runtime facade for the run-shared guardian duration pool. The
# filename stays stable for §9-2 ownership compatibility; satiety-only policy is
# removed in §9-4 after all consumers speak duration terminology.
const LingpetAffinityState := preload(
	"res://scripts/lingpet/lingpet_affinity_state.gd"
)

const MAX_DRAIN_REDUCTION_PCT := 60.0
const MIN_DRAIN_MULTIPLIER := 0.4

var _penalty_exempt := false


func reset() -> void:
	_penalty_exempt = false


func advance_inactive(affinity_state: Object = null) -> void:
	_penalty_exempt = false
	if affinity_state != null and affinity_state.has_method("clear_duration_drain_exempt_latch"):
		affinity_state.clear_duration_drain_exempt_latch()


func latch_penalty_exempt(
	owner: Object,
	collection_state: Object,
	affinity_state: Object = null
) -> bool:
	if affinity_state != null and affinity_state.has_method("latch_duration_drain_exempt"):
		_penalty_exempt = bool(
			affinity_state.latch_duration_drain_exempt(owner, collection_state)
		)
	else:
		_penalty_exempt = is_penalty_exempt(owner, collection_state)
	return _penalty_exempt


func advance_duration(
	pet_id: String,
	battle_slots: Array,
	delta: float,
	affinity_state: Object,
	owner: Object,
	collection_state: Object,
	passive_skills: Array,
	summoned: bool
) -> Dictionary:
	var drain_multiplier := get_satiety_drain_multiplier(passive_skills)
	var exempt := is_penalty_exempt(owner, collection_state, affinity_state)
	var result: Dictionary = affinity_state.advance_satiety(
		pet_id,
		battle_slots,
		delta,
		drain_multiplier,
		1.0,
		not summoned
	)
	result["drain_exempt"] = exempt
	result["summoned"] = summoned
	return result


func advance_active(
	pet_id: String,
	battle_slots: Array,
	delta: float,
	affinity_state: Object,
	owner: Object,
	collection_state: Object,
	passive_skills: Array,
	_exhaustion_telegraph_seconds: float,
	summoned: bool = true
) -> bool:
	return bool(advance_duration(
		pet_id,
		battle_slots,
		delta,
		affinity_state,
		owner,
		collection_state,
		passive_skills,
		summoned
	).get("changed", false))


func get_active_satiety_pct(
	has_guardian: bool,
	_pet_id: String,
	affinity_state: Object
) -> int:
	if not has_guardian or affinity_state == null:
		return 0
	return int(affinity_state.get_duration_pool_pct())


func get_speed_scale(
	_companion_active: bool,
	_pet_id: String,
	_affinity_state: Object,
	_owner: Object,
	_collection_state: Object
) -> float:
	# Duration scarcity no longer slows movement. Reaching the lower rail folds
	# companion_active false through the stow contract instead.
	return 1.0


func is_companion_exhausted(
	_has_guardian: bool,
	_pet_id: String,
	affinity_state: Object,
	owner: Object,
	collection_state: Object
) -> bool:
	if affinity_state == null or is_penalty_exempt(owner, collection_state, affinity_state):
		return false
	return bool(affinity_state.is_duration_resummon_locked())


func get_exhaustion_ratio(
	_has_guardian: bool,
	_pet_id: String,
	affinity_state: Object,
	owner: Object,
	collection_state: Object,
	_exhaustion_telegraph_seconds: float
) -> float:
	if affinity_state == null or is_penalty_exempt(owner, collection_state, affinity_state):
		return 0.0
	return float(affinity_state.get_satiety_exhaustion_ratio(
		"",
		_exhaustion_telegraph_seconds
	))


func is_penalty_exempt(
	owner: Object,
	collection_state: Object,
	affinity_state: Object = null
) -> bool:
	if affinity_state != null and affinity_state.has_method("is_duration_drain_exempt_latched"):
		if owner == null:
			return bool(affinity_state.is_duration_drain_exempt_latched())
	if owner == null:
		return _penalty_exempt
	return (
		collection_state != null
		and collection_state.has_method("is_auto_present_league")
		and bool(collection_state.is_auto_present_league(owner))
	)


func get_satiety_drain_multiplier(passive_skills: Array) -> float:
	# The existing light-eater modifier remains live through Slice 3. Slice 1
	# only moves its owner from a per-pet rail to the shared duration drain.
	var reduction_pct := 0.0
	for passive_skill in passive_skills:
		var passive_reduction_pct := 0.0
		if str(passive_skill.get("id", "")).strip_edges() == "lingpet_light_eater":
			passive_reduction_pct = LingpetAffinityState.get_satiety_drain_reduction_pct_for_level(
				int(passive_skill.get("level", 1))
			)
		else:
			passive_reduction_pct = float(
				passive_skill.get("satiety_drain_reduction_pct", 0.0)
			)
		reduction_pct += maxf(0.0, passive_reduction_pct)
	reduction_pct = clampf(reduction_pct, 0.0, MAX_DRAIN_REDUCTION_PCT)
	return clampf(
		1.0 - reduction_pct / 100.0,
		MIN_DRAIN_MULTIPLIER,
		1.0
	)
