extends RefCounted

const STANDARD_RING_CORE_TIER := 1
const TUTORIAL_LEAGUE_MODE := "junior"
const TUTORIAL_CHARACTER_TYPE := "smasher"


func grant_standard_ring_core_if_needed(owner: Object, collection_state: Object, affinity_state: Object) -> bool:
	if not is_first_lingpet_egg_eligible(owner, collection_state):
		return false
	if affinity_state == null:
		return false
	if int(affinity_state.get_run_ring_core_tier()) >= STANDARD_RING_CORE_TIER:
		return false
	return bool(affinity_state.upgrade_run_ring_core_tier(STANDARD_RING_CORE_TIER))


func is_first_lingpet_egg_eligible(owner: Object, collection_state: Object) -> bool:
	if owner == null or collection_state == null:
		return false
	var owned_pet_ids: Variant = collection_state.get_owned_pet_ids_from_owner(owner)
	if owned_pet_ids is Array and not (owned_pet_ids as Array).is_empty():
		return false
	var hatch_context: Dictionary = {}
	var raw_context: Variant = collection_state.get_hatch_context(owner)
	if raw_context is Dictionary:
		hatch_context = raw_context
	return (
		str(hatch_context.get("league_mode", "")) == TUTORIAL_LEAGUE_MODE
		and str(hatch_context.get("character_type", "")) == TUTORIAL_CHARACTER_TYPE
	)
