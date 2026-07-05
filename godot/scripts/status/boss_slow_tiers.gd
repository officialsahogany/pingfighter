extends RefCounted

const TIER_NONE := 0
const TIER_WEAK := 1
const TIER_MEDIUM := 2
const TIER_STRONG := 3

const NO_SLOW := 1.0
const WEAK := 0.70
const MEDIUM := 0.55
const STRONG := 0.40

const BY_TIER := [NO_SLOW, WEAK, MEDIUM, STRONG]


static func normalize_tier(tier: int) -> int:
	return clampi(tier, TIER_WEAK, TIER_STRONG)


static func multiplier_for_tier(tier: int) -> float:
	return float(BY_TIER[normalize_tier(tier)])


static func slow_pct_for_tier(tier: int) -> float:
	return clampf(1.0 - multiplier_for_tier(tier), 0.0, 1.0)
