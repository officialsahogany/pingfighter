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

# TEMP: Phase C validates only the relative price skeleton fixed by the goal
# document. Product balance may replace these values without moving payment,
# stock, or snapshot ownership out of the tower run.
const TEMP_PHASE_C_SHOP_COMMON_ACTIVE_PRICE := 60
const TEMP_PHASE_C_SHOP_LEGENDARY_ACTIVE_PRICE := 180
const TEMP_PHASE_C_SHOP_MYTHIC_ACTIVE_PRICE := 300
const TEMP_PHASE_C_SHOP_CAPSULE_PRICE := 80
const TEMP_PHASE_C_SHOP_CHANCE_GEM_PRICE := 150
const TEMP_PHASE_C_MONK_CHOSIK_ACQUIRE_COST := 8
const TEMP_PHASE_C_MONK_CHOSIK_SWAP_COST := 10
const TEMP_PHASE_C_MONK_CHOSIK_REMOVE_COST := 12
const TEMP_PHASE_C_MONK_ACQUIRE_PER_VISIT := 1
const TEMP_PHASE_C_MONK_SWAP_PER_VISIT := 1
const TEMP_PHASE_C_MONK_REMOVE_PER_VISIT := 1

# TEMP: Unported and shell boss slots reuse existing Godot bosses until their
# content tracks replace the stand-ins. These are compatibility IDs, not new
# player-facing boss names.
const TEMP_BOSS_STANDIN_BY_SLOT := {
	"floor_02_molewang": {"stage": 2, "boss_id": "cheongringwi"},
	"floor_02_arachne": {"stage": 2, "boss_id": "cheongringwi"},
	"floor_03_teddy_bear": {"stage": 3, "boss_id": "yeonmyo"},
	"floor_03_alice": {"stage": 3, "boss_id": "yeonmyo"},
	"floor_04_shell_01": {"stage": 4, "boss_id": "ponk"},
	"floor_04_shell_02": {"stage": 4, "boss_id": "ponk"},
	"floor_05_shell_01": {"stage": 5, "boss_id": "hongryun"},
	"floor_05_shell_02": {"stage": 5, "boss_id": "hongryun"},
	"floor_06_shell_01": {"stage": 6, "boss_id": "tetriser"},
	"floor_06_shell_02": {"stage": 6, "boss_id": "tetriser"},
	"floor_07_shell_01": {"stage": 7, "boss_id": "akamu_rigo"},
	"floor_07_shell_02": {"stage": 7, "boss_id": "akamu_rigo"},
	"floor_08_shell_01": {"stage": 8, "boss_id": "minotaur"},
	"floor_08_shell_02": {"stage": 8, "boss_id": "minotaur"},
	"floor_09_fake_ending": {"stage": 8, "boss_id": "minotaur"},
	"floor_10_shell_01": {"stage": 6, "boss_id": "tetriser"},
	"floor_10_shell_02": {"stage": 7, "boss_id": "akamu_rigo"},
	"floor_10_shell_03": {"stage": 8, "boss_id": "minotaur"},
	"floor_11_king_01": {"stage": 4, "boss_id": "ponk"},
	"floor_11_king_02": {"stage": 5, "boss_id": "hongryun"},
	"floor_11_king_03": {"stage": 6, "boss_id": "tetriser"},
	"floor_11_king_04": {"stage": 7, "boss_id": "akamu_rigo"},
	"floor_12_true_ending": {"stage": 8, "boss_id": "minotaur"},
}

# Canonical §3.5 parity value. League scaling remains a later tuning input;
# the base opportunity roll is 10% and is resolved once during map generation.
const NORMAL_BOSS_ENRAGED_CHANCE := 0.10
