extends RefCounted


func add_enhancement_chip(affinity_state: Object, max_chips: int) -> Dictionary:
	if affinity_state == null:
		return {
			"accepted": false,
			"chip_count": 0,
			"max_chips": max_chips,
			"multiplier": 1.0,
			"blocked_reason": "missing_affinity_state",
		}
	var before: int = int(affinity_state.get_enhancement_chips())
	var after: int = int(affinity_state.add_enhancement_chip())
	return {
		"accepted": after > before,
		"chip_count": after,
		"max_chips": max_chips,
		"multiplier": float(affinity_state.get_enhancement_chip_multiplier()),
		"blocked_reason": "" if after > before else "max_chips",
	}


func upgrade_run_ring_core_tier(affinity_state: Object, target_tier: int, max_tier: int) -> Dictionary:
	if affinity_state == null:
		return {
			"accepted": false,
			"new_tier": 0,
			"new_cap": 0,
			"max_tier": max_tier,
			"blocked_reason": "missing_affinity_state",
		}
	var accepted: bool = bool(affinity_state.upgrade_run_ring_core_tier(target_tier))
	return {
		"accepted": accepted,
		"new_tier": int(affinity_state.get_run_ring_core_tier()),
		"new_cap": int(affinity_state.get_run_ring_core_cap()),
		"max_tier": max_tier,
		"blocked_reason": "" if accepted else "ring_core_upgrade_failed",
	}
