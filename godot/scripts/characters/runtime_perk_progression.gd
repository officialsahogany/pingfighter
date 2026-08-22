extends RefCounted

## Canonical numeric progression for the 37 five-level Mugong that will move
## to three authored stars. S2 intentionally preserves the existing Lv.1-5
## values and Lv.6+ behavior; S3 will replace only the authored value arrays
## and their cap-relative milestone levels.
##
## Hot-path contract (GRT-032): PROGRESSIONS is a script-load-time static
## index. Runtime reads are O(1), return scalars, and never duplicate nested
## dictionaries or arrays. There is deliberately no applied-key/value cache,
## so progression edits cannot be hidden behind a stale early return (GRT-020).

const POLARITY_HIGHER_IS_BETTER := "higher_is_better"
const POLARITY_LOWER_IS_BETTER := "lower_is_better"
const POLARITY_STRUCTURAL := "structural"

const OVERFLOW_LINEAR := "linear"
const OVERFLOW_HOLD := "hold"
const OVERFLOW_STAIRCASE := "staircase"

const TARGET_PERK_IDS := {
	"dash_acceleration": true,
	"item_luck": true,
	"item_gauge_mastery": true,
	"item_caffeine": true,
	"item_polish": true,
	"item_recycle": true,
	"downtown_treasure_map": true,
	"training_mastery": true,
	"perk_boost_charge": true,
	"perk_laurel_shield": true,
	"dash_spirit": true,
	"extension_gear": true,
	"combo_amplifier_chip": true,
	"jetpack_enhance": true,
	"kick_enhance": true,
	"blade_amp": true,
	"four_poisons": true,
	"pistol_enhance": true,
	"star_detector": true,
	"adversity_armor": true,
	"reinforced_boomerang_gauntlet": true,
	"sensor": true,
	"dowsing_pendulum": true,
	"chargebag": true,
	"battery": true,
	"master": true,
	"gold_digger": true,
	"lucky_coin": true,
	"shrapnel_armor": true,
	"foul_whistle": true,
	"neural_helmet": true,
	"commando_arm": true,
	"rainbow_fur_glove": true,
	"knee_pads": true,
	"soul_burst": true,
	"venom_mist_gauntlet": true,
	"sage_ring": true,
}

# Compatibility aliases consumed by runtime_perk_effective_levels.gd. Values
# live here so the runtime and progression tables cannot drift.
const ITEM_CAFFEINE_DURATION_BONUS_PER_LEVEL := 0.30
const ITEM_POLISH_ROLL_BONUS_PER_LEVEL := 0.12
const PERK_POLISH_AMPLIFY_PER_LEVEL := 0.05
const TRAINING_MASTERY_AMPLIFY_PER_LEVEL := 0.20
const ITEM_RECYCLE_CHANCE_PER_LEVEL := 0.07
const MAX_ITEM_RECYCLE_CHANCE := 0.90
const DASH_ACCELERATION_BONUS_PER_LEVEL := 0.70
const TREASURE_MAP_MYTHIC_BONUS_PER_LEVEL := 1.50
const TREASURE_MAP_VISION_BOX_CHANCE_BONUS_PER_LEVEL := 0.03

# Known S2-preserved discrepancies. Do not collapse these lanes until their
# gameplay design is decided independently of the three-star migration.
# TODO(mugong-kick-lanes): authored tooltip precision/speed use 8%/12% per
# level while live aim/hit-speed consumers use 0.09/0.04 per level.
# TODO(mugong-polish-lanes): general Mugong amplification (5%/level) and
# mythic-item roll amplification (12%/level) are distinct production effects.
static var PROGRESSIONS: Dictionary = {
	"dash_acceleration": {"primary_runtime_lane": "vertical_scale_bonus", "lanes": {
		"vertical_scale_bonus": _lane([0.70, 1.40, 2.10, 2.80, 3.50], 0.70),
		"horizontal_scale_bonus": _lane([0.10, 0.20, 0.30, 0.40, 0.50], 0.10),
	}},
	"item_luck": {"primary_runtime_lane": "spawn_wait_reduction", "lanes": {
		"spawn_wait_reduction": _lane([0.12, 0.24, 0.36, 0.48, 0.60], 0.12),
	}},
	"item_gauge_mastery": {"primary_runtime_lane": "gauge_gain", "lanes": {
		"gauge_gain": _lane([15.0, 30.0, 45.0, 60.0, 75.0], 15.0),
	}},
	"item_caffeine": {"primary_runtime_lane": "duration_bonus", "lanes": {
		"duration_bonus": _lane([0.30, 0.60, 0.90, 1.20, 1.50], ITEM_CAFFEINE_DURATION_BONUS_PER_LEVEL),
	}},
	"item_polish": {"primary_runtime_lane": "mythic_roll_bonus", "lanes": {
		"general_amplify": _lane([0.05, 0.10, 0.15, 0.20, 0.25], PERK_POLISH_AMPLIFY_PER_LEVEL),
		"mythic_roll_bonus": _lane([0.12, 0.24, 0.36, 0.48, 0.60], ITEM_POLISH_ROLL_BONUS_PER_LEVEL),
	}},
	"item_recycle": {"primary_runtime_lane": "retain_chance", "lanes": {
		"retain_chance": _lane([0.07, 0.14, 0.21, 0.28, 0.35], ITEM_RECYCLE_CHANCE_PER_LEVEL, MAX_ITEM_RECYCLE_CHANCE),
	}},
	"downtown_treasure_map": {"primary_runtime_lane": "mythic_offer_bonus", "lanes": {
		"mythic_offer_bonus": _lane([1.50, 3.00, 4.50, 6.00, 7.50], TREASURE_MAP_MYTHIC_BONUS_PER_LEVEL),
		"vision_box_chance_bonus": _lane([0.03, 0.06, 0.09, 0.12, 0.15], TREASURE_MAP_VISION_BOX_CHANCE_BONUS_PER_LEVEL),
	}},
	"training_mastery": {"primary_runtime_lane": "training_amplify", "lanes": {
		"training_amplify": _lane([0.20, 0.40, 0.60, 0.80, 1.00], TRAINING_MASTERY_AMPLIFY_PER_LEVEL),
	}},
	"perk_boost_charge": {"primary_runtime_lane": "trigger_chance_pct", "lanes": {
		"trigger_chance_pct": _lane([7.0, 14.0, 21.0, 28.0, 35.0], 7.0, 100.0),
		"free_dash_count": _hold_lane([1.0, 1.0, 1.0, 1.0, 1.0], POLARITY_STRUCTURAL),
		"recharge_reduction_pct": _hold_lane([90.0, 90.0, 90.0, 90.0, 90.0]),
	}},
	"perk_laurel_shield": {"primary_runtime_lane": "leaf_count", "lanes": {
		"leaf_count": _lane([1.0, 2.0, 3.0, 4.0, 5.0], 1.0, INF, -INF, POLARITY_STRUCTURAL),
	}},
	"dash_spirit": {"primary_runtime_lane": "laser_chance", "lanes": {
		"laser_chance": _lane([0.07, 0.14, 0.21, 0.28, 0.35], 0.07),
	}},
	"extension_gear": {"lanes": {
		"duration_bonus": _lane([0.25, 0.50, 0.75, 1.00, 1.25], 0.25),
	}},
	"combo_amplifier_chip": {"lanes": {
		"drive_speed_bonus": _lane([0.90, 1.80, 2.70, 3.60, 4.50], 0.90),
		"drive_curve_bonus": _hold_lane([0.05, 0.10, 0.15, 0.15, 0.15], POLARITY_HIGHER_IS_BETTER, {"cap_reached": 3}),
		"smash_speed_bonus": _lane([0.45, 0.90, 1.35, 1.80, 2.25], 0.45),
		"initial_boost_decay_reduction": _lane([0.10, 0.20, 0.30, 0.40, 0.50], 0.10, 0.50, -INF, POLARITY_HIGHER_IS_BETTER, {"cap_reached": 5}),
	}},
	"jetpack_enhance": {"lanes": {
		"max_gauge_bonus": _lane([0.20, 0.40, 0.60, 0.80, 1.00], 0.20),
		"airborne_gauge_gain_bonus": _lane([0.0, 0.0, 0.10, 0.20, 0.30], 0.10, INF, -INF, POLARITY_HIGHER_IS_BETTER, {"starts": 3}),
	}},
	"kick_enhance": {"lanes": {
		"authored_precision_pct": _lane([8.0, 16.0, 24.0, 32.0, 40.0], 8.0),
		"authored_speed_pct": _lane([12.0, 24.0, 36.0, 48.0, 60.0], 12.0),
		"runtime_aim_gain": _lane([0.09, 0.18, 0.27, 0.36, 0.45], 0.09, 0.90),
		"runtime_aim_candidate_count": _hold_lane([4.0, 5.0, 6.0, 7.0, 8.0], POLARITY_STRUCTURAL, {}, 3.0),
		"runtime_hit_speed_bonus": _lane([0.04, 0.08, 0.12, 0.16, 0.20], 0.04),
		"prep_reduction": _lane([0.07, 0.14, 0.21, 0.28, 0.35], 0.07, 0.90),
		"furnace_knockback_chance": _lane([0.0, 0.0, 0.10, 0.20, 0.30], 0.10, 1.00, -INF, POLARITY_HIGHER_IS_BETTER, {"starts": 3}),
		"guard_fire_knockback_pct": _hold_lane([0.0, 0.0, 150.0, 150.0, 150.0], POLARITY_STRUCTURAL, {"starts": 3}),
	}},
	"blade_amp": {"lanes": {
		"range_width_bonus": _hold_lane([0.10, 0.20, 0.30, 0.40, 0.50]),
		"projectile_speed_bonus": _lane([0.10, 0.20, 0.30, 0.40, 0.50], 0.10),
		"hit_speed_bonus": _lane([0.15, 0.30, 0.45, 0.60, 0.75], 0.15),
		"gauge_cost_reduction": _lane([10.0, 20.0, 30.0, 40.0, 50.0], 10.0, 100.0),
		"homing_tier": _hold_lane([0.0, 0.0, 1.0, 1.0, 2.0], POLARITY_STRUCTURAL, {"homing": 3, "additional_homing": 5}),
		"followup_chance_pct": _lane([0.0, 0.0, 10.0, 20.0, 30.0], 10.0, 100.0, -INF, POLARITY_HIGHER_IS_BETTER, {"starts": 3}),
	}},
	"four_poisons": {"lanes": {
		"prep_reduction_pct": _lane([8.0, 16.0, 25.0, 33.0, 40.0], 4.0, 70.0),
		"sleep_pct": _lane([5.0, 10.0, 15.0, 20.0, 25.0], 5.0, 50.0),
		"confusion_pct": _lane([12.0, 24.0, 36.0, 48.0, 70.0], 10.0, 150.0),
		"dual_duration_pct": _lane([7.0, 14.0, 20.0, 27.0, 33.0], 5.0, 45.0),
		"cooldown_reduction_pct": _lane([0.0, 0.0, 10.0, 15.0, 20.0], 4.0, 40.0, -INF, POLARITY_HIGHER_IS_BETTER, {"starts": 3}),
		"clone_hp": _staircase_lane([2.0, 2.0, 3.0, 3.0, 4.0], 1.0, 2, 4, 2, 6.0, {"raised": 3, "maximum": 5}, 2.0),
		"superarmor": _hold_lane([0.0, 0.0, 1.0, 1.0, 1.0], POLARITY_STRUCTURAL, {"starts": 3}),
		"clone_replication": _hold_lane([0.0, 0.0, 0.0, 0.0, 1.0], POLARITY_STRUCTURAL, {"starts": 5}),
	}},
	"pistol_enhance": {"lanes": {
		"spread_degrees": _hold_lane([12.0, 9.0, 6.0, 3.0, 1.0], POLARITY_LOWER_IS_BETTER),
		"speed_bonus_pct": _hold_lane([10.0, 20.0, 30.0, 40.0, 50.0]),
		"knockback_bonus_pct": _hold_lane([30.0, 60.0, 90.0, 120.0, 150.0]),
		"magazine_size": _lane([5.0, 5.0, 6.0, 6.0, 7.0], 1.0, INF, -INF, POLARITY_STRUCTURAL, {"first_upgrade": 3, "second_upgrade": 5}),
	}},

	# Converted target Mugong. Their current Lv.6+ rule is the authored-table
	# average step, made explicit here so shrinking the table in S3 cannot
	# silently change overflow. level_zero="first" preserves the existing
	# PerkConversionValues clamp-to-Lv.1 behavior for direct raw queries.
	"star_detector": _converted({"star_bonus_pct": _converted_lane([5.0, 10.0, 15.0, 20.0, 25.0], 5.0)}),
	"adversity_armor": _converted({
		"trigger_chance_pct": _converted_lane([20.0, 25.0, 30.0, 35.0, 40.0], 5.0, 100.0),
		"invincible_duration_sec": _converted_lane([5.0, 8.0, 10.0, 13.0, 15.0], 2.5),
	}),
	"reinforced_boomerang_gauntlet": _converted({
		"boomerang_knockback_pct": _converted_lane([20.0, 28.0, 35.0, 43.0, 50.0], 7.5),
		"boomerang_stun_pct": _converted_lane([20.0, 35.0, 50.0, 65.0, 80.0], 15.0),
		"boomerang_launch_speed_pct": _converted_lane([15.0, 24.0, 33.0, 41.0, 50.0], 8.75),
		"boomerang_homing_pct": _converted_lane([10.0, 20.0, 30.0, 40.0, 50.0], 10.0),
		"boomerang_spawn_bonus_pct": _converted_lane([50.0, 88.0, 125.0, 163.0, 200.0], 37.5),
	}),
	"sensor": _converted({
		"auto_dash_token_count": _converted_lane([1.0, 1.0, 2.0, 2.0, 2.0], 0.25, INF, -INF, POLARITY_STRUCTURAL, false),
		"auto_dash_cooldown_sec": _converted_lane([30.0, 26.0, 23.0, 19.0, 15.0], -3.75, INF, 1.0, POLARITY_LOWER_IS_BETTER),
	}),
	"dowsing_pendulum": _converted({"attraction_range": _converted_lane([120.0, 160.0, 200.0, 240.0, 280.0], 40.0)}),
	"chargebag": _converted({"chargebag_pct": _converted_lane([15.0, 25.0, 35.0, 45.0, 55.0], 10.0)}),
	"battery": _converted({"gauge_preserve_pct": _converted_lane([40.0, 55.0, 70.0, 85.0, 100.0], 15.0, 100.0)}),
	"master": _converted({
		"wall_length_pct": _converted_lane([12.0, 20.0, 29.0, 37.0, 45.0], 8.25),
		"item_cooldown_pct": _converted_lane([3.0, 5.0, 8.0, 10.0, 12.0], 2.25, 95.0),
		"wall_spawn_bonus_pct": _converted_lane([100.0, 158.0, 215.0, 273.0, 330.0], 57.5),
	}),
	"gold_digger": _converted({"gold_bonus_pct": _converted_lane([15.0, 25.0, 35.0, 45.0, 55.0], 10.0)}),
	"lucky_coin": _converted({"double_spawn_pct": _converted_lane([3.0, 7.0, 10.0, 14.0, 17.0], 3.5, 100.0)}),
	"shrapnel_armor": _converted({
		"trigger_chance_pct": _converted_lane([6.0, 9.0, 12.0, 14.0, 17.0], 2.75, 100.0),
		"shard_count": _converted_lane([4.0, 5.0, 6.0, 7.0, 8.0], 1.0, INF, -INF, POLARITY_STRUCTURAL, false),
		"knockback_level": _converted_lane([1.0, 2.0, 3.0, 3.0, 4.0], 0.75, INF, -INF, POLARITY_STRUCTURAL, false),
		"gauge_cost": _converted_lane([50.0, 44.0, 38.0, 31.0, 25.0], -6.25, INF, 0.0, POLARITY_LOWER_IS_BETTER),
	}),
	"foul_whistle": _converted({"negate_chance_pct": _converted_lane([3.0, 5.0, 7.0, 9.0, 11.0], 2.0, 100.0)}),
	"neural_helmet": _converted({
		"aipill_gauge_reduction": _converted_lane([10.0, 15.0, 20.0, 25.0, 30.0], 5.0, 90.0),
		"aipill_ball_speed_bonus_pct": _converted_lane([2.0, 4.0, 6.0, 8.0, 10.0], 2.0),
		"aipill_spawn_bonus_pct": _converted_lane([100.0, 158.0, 215.0, 273.0, 330.0], 57.5),
	}),
	"commando_arm": _converted({
		"throw_speed_pct": _converted_lane([6.0, 11.0, 15.0, 20.0, 24.0], 4.5),
		"explosion_range_pct": _converted_lane([3.0, 7.0, 11.0, 14.0, 18.0], 3.75),
		"smoke_duration_pct": _converted_lane([12.0, 21.0, 30.0, 39.0, 48.0], 9.0),
		"prep_reduction_pct": _converted_lane([12.0, 21.0, 30.0, 39.0, 48.0], 9.0, 95.0),
	}),
	"rainbow_fur_glove": _converted({
		"rainbow_glove_trigger_chance_pct": _converted_lane([3.0, 4.0, 5.0, 6.0, 7.0], 1.0, 100.0),
		"rainbow_glove_cooldown_reduction_pct": _converted_lane([8.0, 11.0, 14.0, 17.0, 20.0], 3.0, 95.0),
	}),
	"knee_pads": _converted({"knee_charge_pct": _converted_lane([20.0, 33.0, 45.0, 58.0, 70.0], 12.5)}),
	"soul_burst": _converted({"soul_burst_gauge_cost": _converted_lane([170.0, 153.0, 135.0, 118.0, 100.0], -17.5, INF, 0.0, POLARITY_LOWER_IS_BETTER)}),
	"venom_mist_gauntlet": _converted({
		"mist_trigger_chance_pct": _converted_lane([20.0, 29.0, 38.0, 46.0, 55.0], 8.75, 100.0),
		"mist_duration_sec": _converted_lane([1.5, 2.5, 3.5, 4.5, 5.5], 1.0),
	}),
	"sage_ring": _converted({
		"trigger_chance_pct": _converted_lane([5.0, 5.0, 5.0, 5.0, 5.0], 0.0),
		"perk_level_bonus": _converted_lane([1.0, 1.0, 2.0, 2.0, 3.0], 0.5, INF, -INF, POLARITY_STRUCTURAL, false),
		"duration_sec": _converted_lane([6.0, 7.0, 8.0, 9.0, 10.0], 1.0),
	}),
}

static var _DASH_ACCELERATION_LEVEL_BY_BONUS: Dictionary = _build_dash_acceleration_level_index()


static func has_perk(perk_id: String) -> bool:
	return TARGET_PERK_IDS.has(perk_id.strip_edges())


static func is_converted_perk(perk_id: String) -> bool:
	var progression: Dictionary = PROGRESSIONS.get(perk_id.strip_edges(), {})
	return bool(progression.get("converted", false))


static func get_lane_ids(perk_id: String) -> Array:
	var progression: Dictionary = PROGRESSIONS.get(perk_id.strip_edges(), {})
	var lanes: Dictionary = progression.get("lanes", {})
	return lanes.keys()


static func get_authored_values_reference(perk_id: String, lane_id: String) -> Array:
	var progression: Dictionary = PROGRESSIONS.get(perk_id.strip_edges(), {})
	var lanes: Dictionary = progression.get("lanes", {})
	var lane: Dictionary = lanes.get(lane_id.strip_edges(), {})
	return lane.get("values", [])


static func has_lane(perk_id: String, lane_id: String) -> bool:
	var progression: Dictionary = PROGRESSIONS.get(perk_id.strip_edges(), {})
	var lanes: Dictionary = progression.get("lanes", {})
	return lanes.has(lane_id.strip_edges())


static func has_primary_runtime_bonus(perk_id: String) -> bool:
	var progression: Dictionary = PROGRESSIONS.get(perk_id.strip_edges(), {})
	return not str(progression.get("primary_runtime_lane", "")).is_empty()


static func get_primary_runtime_bonus(perk_id: String, level: int) -> float:
	var clean_id := perk_id.strip_edges()
	var progression: Dictionary = PROGRESSIONS.get(clean_id, {})
	var lane_id := str(progression.get("primary_runtime_lane", ""))
	return get_value(clean_id, lane_id, level) if not lane_id.is_empty() else 0.0


static func get_value(perk_id: String, lane_id: String, level: int) -> float:
	return get_value_from_index(PROGRESSIONS, perk_id, lane_id, level)


# Public for the equivalence seal's deliberately corrupted in-memory fixture.
# Runtime callers should use get_value(), which always reads PROGRESSIONS.
static func get_value_from_index(index: Dictionary, perk_id: String, lane_id: String, level: int) -> float:
	var progression_value: Variant = index.get(perk_id.strip_edges(), {})
	if not (progression_value is Dictionary):
		return 0.0
	var lanes_value: Variant = (progression_value as Dictionary).get("lanes", {})
	if not (lanes_value is Dictionary):
		return 0.0
	var lane_value: Variant = (lanes_value as Dictionary).get(lane_id.strip_edges(), {})
	if not (lane_value is Dictionary):
		return 0.0
	return _resolve_lane_value(lane_value as Dictionary, level)


static func get_int_value(perk_id: String, lane_id: String, level: int) -> int:
	return int(round(get_value(perk_id, lane_id, level)))


static func get_milestone_level(perk_id: String, lane_id: String, milestone_id: String) -> int:
	var progression: Dictionary = PROGRESSIONS.get(perk_id.strip_edges(), {})
	var lanes: Dictionary = progression.get("lanes", {})
	var lane: Dictionary = lanes.get(lane_id.strip_edges(), {})
	var milestones: Dictionary = lane.get("milestones", {})
	return int(milestones.get(milestone_id.strip_edges(), 0))


static func get_lane_polarity(perk_id: String, lane_id: String) -> String:
	var progression: Dictionary = PROGRESSIONS.get(perk_id.strip_edges(), {})
	var lanes: Dictionary = progression.get("lanes", {})
	var lane: Dictionary = lanes.get(lane_id.strip_edges(), {})
	return str(lane.get("polarity", POLARITY_HIGHER_IS_BETTER))


static func is_polish_amplifiable_lane(perk_id: String, lane_id: String) -> bool:
	var progression: Dictionary = PROGRESSIONS.get(perk_id.strip_edges(), {})
	var lanes: Dictionary = progression.get("lanes", {})
	var lane: Dictionary = lanes.get(lane_id.strip_edges(), {})
	return bool(lane.get("polish_amplifiable", true))


static func has_polish_amplifiable_lane(perk_id: String) -> bool:
	var progression: Dictionary = PROGRESSIONS.get(perk_id.strip_edges(), {})
	return bool(progression.get("has_polish_amplifiable_lane", false))


static func get_authored_level_count(perk_id: String, lane_id: String) -> int:
	var progression: Dictionary = PROGRESSIONS.get(perk_id.strip_edges(), {})
	var lanes: Dictionary = progression.get("lanes", {})
	var lane: Dictionary = lanes.get(lane_id.strip_edges(), {})
	var values: Array = lane.get("values", [])
	return values.size()


static func get_authored_max_level(perk_id: String) -> int:
	var lane_ids := get_lane_ids(perk_id)
	if lane_ids.is_empty():
		return 0
	return get_authored_level_count(perk_id, str(lane_ids[0]))


static func get_dash_acceleration_level_for_bonus(bonus: float) -> int:
	return int(_DASH_ACCELERATION_LEVEL_BY_BONUS.get(_float_index_key(bonus), 0))


static func _resolve_lane_value(lane: Dictionary, level: int) -> float:
	var values: Array = lane.get("values", [])
	if values.is_empty():
		return 0.0
	var safe_level := int(level)
	if safe_level <= 0:
		return float(values[0]) if bool(lane.get("level_zero_first", false)) else float(lane.get("zero_value", 0.0))
	if safe_level <= values.size():
		return float(values[safe_level - 1])
	var overflow: Dictionary = lane.get("overflow", {})
	var mode := str(overflow.get("mode", OVERFLOW_HOLD))
	var value := float(values[values.size() - 1])
	match mode:
		OVERFLOW_LINEAR:
			value += float(overflow.get("step", 0.0)) * float(safe_level - values.size())
		OVERFLOW_STAIRCASE:
			var every := maxi(1, int(overflow.get("every", 1)))
			var origin := int(overflow.get("origin", values.size()))
			var steps := maxi(0, int(floor(float(safe_level - origin) / float(every))))
			var max_steps := int(overflow.get("max_steps", -1))
			if max_steps >= 0:
				steps = mini(steps, max_steps)
			value += float(overflow.get("step", 0.0)) * float(steps)
	if lane.has("min"):
		value = maxf(value, float(lane["min"]))
	if lane.has("max"):
		value = minf(value, float(lane["max"]))
	return value


static func _build_dash_acceleration_level_index() -> Dictionary:
	var index: Dictionary = {}
	# Current/approved sources top out below this; building once keeps the rare
	# compatibility fallback O(1) without assuming linear authored values.
	for level in range(0, 33):
		index[_float_index_key(get_value("dash_acceleration", "vertical_scale_bonus", level))] = level
	return index


static func _float_index_key(value: float) -> int:
	return int(round(value * 1000000.0))


static func _lane(
	values: Array,
	overflow_step: float,
	value_max: float = INF,
	value_min: float = -INF,
	polarity: String = POLARITY_HIGHER_IS_BETTER,
	milestones: Dictionary = {}
) -> Dictionary:
	var lane := {
		"values": values,
		"overflow": {"mode": OVERFLOW_LINEAR, "step": overflow_step},
		"polarity": polarity,
		"milestones": milestones,
	}
	if is_finite(value_max):
		lane["max"] = value_max
	if is_finite(value_min):
		lane["min"] = value_min
	return lane


static func _hold_lane(
	values: Array,
	polarity: String = POLARITY_HIGHER_IS_BETTER,
	milestones: Dictionary = {},
	zero_value: float = 0.0
) -> Dictionary:
	return {
		"values": values,
		"overflow": {"mode": OVERFLOW_HOLD},
		"polarity": polarity,
		"milestones": milestones,
		"zero_value": zero_value,
	}


static func _staircase_lane(
	values: Array,
	step: float,
	every: int,
	origin: int,
	max_steps: int,
	value_max: float,
	milestones: Dictionary = {},
	zero_value: float = 0.0
) -> Dictionary:
	return {
		"values": values,
		"overflow": {
			"mode": OVERFLOW_STAIRCASE,
			"step": step,
			"every": every,
			"origin": origin,
			"max_steps": max_steps,
		},
		"max": value_max,
		"polarity": POLARITY_STRUCTURAL,
		"milestones": milestones,
		"zero_value": zero_value,
	}


static func _converted(lanes: Dictionary) -> Dictionary:
	var has_amplifiable := false
	for lane_value: Variant in lanes.values():
		if lane_value is Dictionary and bool((lane_value as Dictionary).get("polish_amplifiable", true)):
			has_amplifiable = true
			break
	return {
		"converted": true,
		"has_polish_amplifiable_lane": has_amplifiable,
		"lanes": lanes,
	}


static func _converted_lane(
	values: Array,
	overflow_step: float,
	value_max: float = INF,
	value_min: float = -INF,
	polarity: String = POLARITY_HIGHER_IS_BETTER,
	polish_amplifiable: bool = true
) -> Dictionary:
	var lane := _lane(values, overflow_step, value_max, value_min, polarity)
	lane["level_zero_first"] = true
	lane["polish_amplifiable"] = polish_amplifiable
	return lane
