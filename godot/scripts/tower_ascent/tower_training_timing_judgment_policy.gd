extends RefCounted

const JUDGMENT_CRITICAL := "critical"
const JUDGMENT_GREAT := "great"
const JUDGMENT_BASE := "base"

const BASE_LUCK_PERCENT := 3.0
const MIN_LUCK_PERCENT := 1.0
const MAX_LUCK_PERCENT := 8.0
const BASE_GREAT_WIDTH_PERCENT := 2.0
# GRT-054: the great-band ratio derives from the approved base widths. Keep
# the 2% band in lockstep with the 3% critical cell instead of freezing the
# rounded 0.667 ratio as a second tuning literal.
const GREAT_CELL_MULTIPLIER := BASE_GREAT_WIDTH_PERCENT / BASE_LUCK_PERCENT
const JUDGMENT_BOUNDARY_EPSILON := 0.000001
const CRITICAL_MULTIPLIER := 1.5
const GREAT_MULTIPLIER := 1.3
const BASE_MULTIPLIER := 1.0
const STORAGE_TRAINING_ID := "physique_storage"
const TARGET_RNG_VERSION := "training_timing_target_v1"


static func cell_width_ratio(luck_percent: float) -> float:
	# 피드백5 1항: the base critical cell is 3% of the track and each
	# great band is 2%. Luck still maps one-to-one to a 1..8% critical width;
	# GREAT_CELL_MULTIPLIER preserves the approved 2:3 band proportion.
	return clampf(luck_percent, MIN_LUCK_PERCENT, MAX_LUCK_PERCENT) / 100.0


static func target_center_bounds(luck_percent: float) -> Vector2:
	var cell_width := cell_width_ratio(luck_percent)
	var outer_half_width := cell_width * (0.5 + GREAT_CELL_MULTIPLIER)
	return Vector2(outer_half_width, 1.0 - outer_half_width)


static func roll_target(
	map_seed: int,
	node_id: String,
	action_id: String,
	roll_index: int,
	luck_percent: float = BASE_LUCK_PERCENT
) -> Dictionary:
	# Training offers use a stable map/node-derived RNG instead of Tower's route
	# and battle streams. Target placement follows that ownership policy and adds
	# a persisted roll index so ESC cannot reroll a target for free after reload.
	var seed_value := absi(hash("%d:%s:%s:%d:%s" % [
		map_seed,
		node_id.strip_edges(),
		action_id.strip_edges(),
		maxi(0, roll_index),
		TARGET_RNG_VERSION,
	]))
	if seed_value == 0:
		seed_value = 140913
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sample := rng.randf()
	var bounds := target_center_bounds(luck_percent)
	return {
		"target_position": lerpf(bounds.x, bounds.y, sample),
		"sample": sample,
		"seed": int(rng.seed),
		"roll_index": maxi(0, roll_index),
		"roll_count": 1,
		"luck_percent": clampf(luck_percent, MIN_LUCK_PERCENT, MAX_LUCK_PERCENT),
		"cell_width_ratio": cell_width_ratio(luck_percent),
	}


static func judge_position(
	pendulum_position: float,
	target_position: float,
	luck_percent: float = BASE_LUCK_PERCENT
) -> Dictionary:
	var cell_width := cell_width_ratio(luck_percent)
	var distance := absf(
		clampf(pendulum_position, 0.0, 1.0)
		- clampf(target_position, 0.0, 1.0)
	)
	var critical_half_width := cell_width * 0.5
	var great_outer_half_width := cell_width * (0.5 + GREAT_CELL_MULTIPLIER)
	# Boundary pixels must attribute inclusively even when a ratio like 147/300
	# is not binary-exact; the epsilon sits far below one pixel on any track.
	var judgment_kind := JUDGMENT_BASE
	if distance <= critical_half_width + JUDGMENT_BOUNDARY_EPSILON:
		judgment_kind = JUDGMENT_CRITICAL
	elif distance <= great_outer_half_width + JUDGMENT_BOUNDARY_EPSILON:
		judgment_kind = JUDGMENT_GREAT
	return {
		"judgment_kind": judgment_kind,
		"effect_multiplier": multiplier_for_judgment(judgment_kind),
		"distance_ratio": distance,
		"critical_half_width_ratio": critical_half_width,
		"great_outer_half_width_ratio": great_outer_half_width,
		"cell_width_ratio": cell_width,
		"luck_percent": clampf(luck_percent, MIN_LUCK_PERCENT, MAX_LUCK_PERCENT),
	}


static func multiplier_for_judgment(judgment_kind: String) -> float:
	match judgment_kind:
		JUDGMENT_CRITICAL:
			return CRITICAL_MULTIPLIER
		JUDGMENT_GREAT:
			return GREAT_MULTIPLIER
		_:
			return BASE_MULTIPLIER


static func applied_multiplier(training_id: String, judgment_kind: String) -> float:
	# physique_storage changes an integer structural slot count. There is no
	# meaningful 1.5-slot or 1.3-slot result, and rounding would award +2 slots,
	# breaking both timing multipliers. It therefore remains exactly +1 slot.
	if training_id.strip_edges() == STORAGE_TRAINING_ID:
		return BASE_MULTIPLIER
	return multiplier_for_judgment(judgment_kind)
