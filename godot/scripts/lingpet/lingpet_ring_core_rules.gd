extends RefCounted

const MAX_AFFINITY_LEVEL := 30 # Mirrors LingpetAffinityState.MAX_LEVEL without coupling to runtime state.
const MAX_RING_CORE_TIER := 6


static func get_ring_core_cap_for_tier(tier: int) -> int:
	var clamped_tier := clampi(tier, 0, MAX_RING_CORE_TIER)
	if clamped_tier <= 0:
		return 0
	return clampi(clamped_tier * 5, 0, MAX_AFFINITY_LEVEL)
