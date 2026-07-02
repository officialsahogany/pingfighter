extends RefCounted

const STATE_EGG := "egg"
const REASON_OK := "ok"
const REASON_MISSING_OWNER := "missing_owner"
const REASON_EGG_ALREADY_ACTIVE := "egg_already_active"
const REASON_NO_HATCH_CANDIDATES := "no_hatch_candidates"


func build_offer(owner: Object, state: String, has_hatch_candidates: bool, hatch_hits: int, required_hits: int) -> Dictionary:
	if owner == null:
		return build_result(false, REASON_MISSING_OWNER, state, hatch_hits, required_hits)
	if state == STATE_EGG:
		return build_result(false, REASON_EGG_ALREADY_ACTIVE, state, hatch_hits, required_hits)
	if not has_hatch_candidates:
		return build_result(false, REASON_NO_HATCH_CANDIDATES, state, hatch_hits, required_hits)
	return build_result(true, REASON_OK, state, hatch_hits, required_hits)


func build_result(can_spawn: bool, reason: String, state: String, hatch_hits: int, required_hits: int) -> Dictionary:
	return {
		"can_spawn": can_spawn,
		"handled": true,
		"changed": can_spawn and reason == REASON_OK,
		"reason": reason,
		"state": state,
		"hatch_hits": hatch_hits,
		"required_hits": required_hits,
	}
