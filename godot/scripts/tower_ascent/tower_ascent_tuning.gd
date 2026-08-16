extends RefCounted

# TEMP: §6에서 상자 등급 수치가 확정될 때까지 한곳에서만 조정한다.
const CHEST_NORMAL_BASE_WEIGHT := 75.0
const CHEST_SUPREME_ART_BASE_WEIGHT := 20.0
const CHEST_SECRET_CHOSIK_BASE_WEIGHT := 5.0
const CHEST_FLOOR_NORMAL_WEIGHT_REDUCTION := 1.5
const CHEST_FLOOR_SUPREME_WEIGHT_BONUS := 1.0
const CHEST_FLOOR_SECRET_WEIGHT_BONUS := 0.5
const CHEST_RISK_NORMAL_WEIGHT_REDUCTION := 8.0
const CHEST_RISK_SUPREME_WEIGHT_BONUS := 5.0
const CHEST_RISK_SECRET_WEIGHT_BONUS := 3.0

# TEMP: Phase A only establishes the single rarity schema and the ownership of
# the per-match cap. Product tuning may replace these values without moving the
# runtime owners or adding another acquisition-specific rarity field.
const TEMP_FIELD_ACTIVE_RARITIES := ["common"]
const TEMP_NORMAL_CHEST_ACTIVE_RARITIES := ["common", "rare"]
const TEMP_SHOP_REGULAR_ACTIVE_RARITIES := ["common", "rare"]
const TEMP_SHOP_PREMIUM_ACTIVE_RARITIES := ["legendary", "mythic"]
const TEMP_REGULAR_SPAWN_BUDGET_MIN := 0
const TEMP_REGULAR_SPAWN_BUDGET_MAX := 1

# TEMP: Phase B establishes generated floor/row ownership. Product tuning may
# change only these values while the 12-floor, floor-gate, and two-candidate
# contracts remain fixed.
const TEMP_OPTIONAL_ROWS_PER_FLOOR := 1
const TEMP_STANDARD_EXTRA_COMBAT_ROWS_MIN := 1
const TEMP_STANDARD_EXTRA_COMBAT_ROWS_MAX := 3
const TEMP_STANDARD_COMBAT_BUDGET_MIN := 10
const TEMP_STANDARD_COMBAT_BUDGET_MAX := 12
const TEMP_NODE_TYPE_WEIGHTS := {
	"shop": 2,
	"training": 2,
	"fallen_monk": 1,
	"guardian_spring": 1,
	"rest": 2,
}
