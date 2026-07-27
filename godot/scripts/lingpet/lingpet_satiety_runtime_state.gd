extends RefCounted

const LingpetAffinityState := preload(
	"res://scripts/lingpet/lingpet_affinity_state.gd"
)

const MAX_DRAIN_REDUCTION_PCT := 60.0
const MIN_DRAIN_MULTIPLIER := 0.4

var _penalty_exempt := false


func reset() -> void:
	_penalty_exempt = false


func advance_inactive() -> void:
	_penalty_exempt = false


func latch_penalty_exempt(owner: Object, collection_state: Object) -> bool:
	_penalty_exempt = is_penalty_exempt(owner, collection_state)
	return _penalty_exempt


func advance_active(
	pet_id: String,
	battle_slots: Array,
	delta: float,
	affinity_state: Object,
	owner: Object,
	collection_state: Object,
	passive_skills: Array,
	exhaustion_telegraph_seconds: float
) -> bool:
	var drain_multiplier := get_satiety_drain_multiplier(passive_skills)
	var active_exhausted := (
		not is_penalty_exempt(owner, collection_state)
		and bool(affinity_state.is_satiety_exhausted(pet_id))
	)
	var satiety_result: Dictionary = affinity_state.advance_satiety(
		pet_id,
		battle_slots,
		delta,
		drain_multiplier,
		1.0,
		active_exhausted
	)
	var exhaustion_result: Dictionary = affinity_state.advance_satiety_exhaustion(
		pet_id,
		delta,
		exhaustion_telegraph_seconds,
		not _penalty_exempt
	)
	return (
		bool(satiety_result.get("changed", false))
		or bool(exhaustion_result.get("changed", false))
	)


func get_active_satiety_pct(
	is_companion: bool,
	pet_id: String,
	affinity_state: Object
) -> int:
	if not is_companion:
		return 0
	return int(affinity_state.get_satiety_pct(pet_id))


func get_speed_scale(
	is_companion: bool,
	pet_id: String,
	affinity_state: Object,
	owner: Object,
	collection_state: Object
) -> float:
	if not is_companion or is_penalty_exempt(owner, collection_state):
		return 1.0
	if bool(affinity_state.is_satiety_exhausted(pet_id)):
		return 0.0
	return float(affinity_state.get_satiety_speed_multiplier(pet_id))


func is_companion_exhausted(
	is_companion: bool,
	pet_id: String,
	affinity_state: Object,
	owner: Object,
	collection_state: Object
) -> bool:
	if not is_companion or is_penalty_exempt(owner, collection_state):
		return false
	return bool(affinity_state.is_satiety_exhausted(pet_id))


func get_exhaustion_ratio(
	is_companion: bool,
	pet_id: String,
	affinity_state: Object,
	owner: Object,
	collection_state: Object,
	exhaustion_telegraph_seconds: float
) -> float:
	if not is_companion or is_penalty_exempt(owner, collection_state):
		return 0.0
	return float(affinity_state.get_satiety_exhaustion_ratio(
		pet_id,
		exhaustion_telegraph_seconds
	))


func is_penalty_exempt(owner: Object, collection_state: Object) -> bool:
	if owner == null:
		return _penalty_exempt
	return bool(collection_state.is_auto_present_league(owner))


func get_satiety_drain_multiplier(passive_skills: Array) -> float:
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
