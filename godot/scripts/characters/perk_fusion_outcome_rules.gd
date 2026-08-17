extends RefCounted

const OUTCOME_SUCCESS := "success"
const OUTCOME_SIDE_EFFECT := "side_effect"
const OUTCOME_BYPRODUCT := "byproduct"
const OUTCOME_STABLE := "stable"
const OUTCOME_BYPRODUCT_COUNT_1 := "byproduct_count_1"
const OUTCOME_BYPRODUCT_COUNT_2 := "byproduct_count_2"
const OUTCOME_BYPRODUCT_COUNT_3 := "byproduct_count_3"

const BASE_SUCCESS_PERCENT := 20.0
const BASE_SIDE_EFFECT_PERCENT := 10.0
const BASE_BYPRODUCT_PERCENT := 70.0
const BYPRODUCT_COUNT_1_SHARE := 4.0 / 7.0
const BYPRODUCT_COUNT_2_SHARE := 2.0 / 7.0
const BYPRODUCT_COUNT_3_SHARE := 1.0 / 7.0
const DUAL_CATALYST_BYPRODUCT_BONUS_PERCENT := 15.0
const EMPTY_POOL_SUCCESS_PERCENT := 90.0
const EMPTY_POOL_SIDE_EFFECT_PERCENT := 10.0
const EMPTY_POOL_BYPRODUCT_PERCENT := 0.0

const SIDE_EFFECT_MIN_MAGNITUDE := 0.10
const SIDE_EFFECT_MAX_MAGNITUDE := 0.30


static func build_outcome_weights(
	dual_catalyst_armed: bool = false,
	byproduct_chance_bonus_percent: float = 0.0,
	max_byproduct_count: int = 3
) -> Dictionary:
	var catalyst_bonus: float = DUAL_CATALYST_BYPRODUCT_BONUS_PERCENT if dual_catalyst_armed else 0.0
	var total_byproduct_bonus := clampf(
		catalyst_bonus + maxf(0.0, byproduct_chance_bonus_percent),
		0.0,
		BASE_SUCCESS_PERCENT
	)
	var byproduct_percent := BASE_BYPRODUCT_PERCENT + total_byproduct_bonus
	var weights := {
		OUTCOME_SUCCESS: BASE_SUCCESS_PERCENT - total_byproduct_bonus,
		OUTCOME_SIDE_EFFECT: BASE_SIDE_EFFECT_PERCENT,
		OUTCOME_BYPRODUCT: byproduct_percent,
	}
	weights.merge(build_byproduct_count_weights(byproduct_percent, max_byproduct_count))
	return weights


static func build_final_outcome_weights(
	byproduct_pool_is_empty: bool,
	dual_catalyst_armed: bool = false,
	byproduct_chance_bonus_percent: float = 0.0,
	available_byproduct_count: int = -1
) -> Dictionary:
	if byproduct_pool_is_empty:
		var empty_weights := {
			OUTCOME_SUCCESS: EMPTY_POOL_SUCCESS_PERCENT,
			OUTCOME_SIDE_EFFECT: EMPTY_POOL_SIDE_EFFECT_PERCENT,
			OUTCOME_BYPRODUCT: EMPTY_POOL_BYPRODUCT_PERCENT,
		}
		empty_weights.merge(build_byproduct_count_weights(0.0, 0))
		return empty_weights
	var max_byproduct_count := 3 if available_byproduct_count < 0 else available_byproduct_count
	return build_outcome_weights(
		dual_catalyst_armed,
		byproduct_chance_bonus_percent,
		max_byproduct_count
	)


static func build_byproduct_count_weights(
	byproduct_percent: float,
	max_byproduct_count: int = 3
) -> Dictionary:
	var safe_byproduct_percent := maxf(0.0, byproduct_percent)
	var count_1_percent := safe_byproduct_percent * BYPRODUCT_COUNT_1_SHARE
	var count_2_percent := safe_byproduct_percent * BYPRODUCT_COUNT_2_SHARE
	var count_3_percent := safe_byproduct_percent * BYPRODUCT_COUNT_3_SHARE
	match clampi(max_byproduct_count, 0, 3):
		0:
			count_1_percent = 0.0
			count_2_percent = 0.0
			count_3_percent = 0.0
		1:
			count_1_percent = safe_byproduct_percent
			count_2_percent = 0.0
			count_3_percent = 0.0
		2:
			count_2_percent += count_3_percent
			count_3_percent = 0.0
	return {
		OUTCOME_BYPRODUCT_COUNT_1: count_1_percent,
		OUTCOME_BYPRODUCT_COUNT_2: count_2_percent,
		OUTCOME_BYPRODUCT_COUNT_3: count_3_percent,
	}


static func resolve_byproduct_count(roll_unit: float, weights: Dictionary) -> int:
	var byproduct_percent := maxf(0.0, float(weights.get(OUTCOME_BYPRODUCT, 0.0)))
	if is_zero_approx(byproduct_percent):
		return 1
	var roll_percent := clampf(roll_unit, 0.0, 1.0) * byproduct_percent
	var cumulative_percent := 0.0
	var last_available_count := 1
	for count: int in range(1, 4):
		var count_key := _byproduct_count_key(count)
		var count_percent := maxf(0.0, float(weights.get(count_key, 0.0)))
		if is_zero_approx(count_percent):
			continue
		last_available_count = count
		cumulative_percent += count_percent
		if roll_percent < cumulative_percent:
			return count
	return last_available_count


static func resolve_side_effect_magnitude(roll_unit: float) -> float:
	return lerpf(
		SIDE_EFFECT_MIN_MAGNITUDE,
		SIDE_EFFECT_MAX_MAGNITUDE,
		_normalize_unit_roll(roll_unit)
	)


static func apply_forward_penalty(value: float, magnitude: float) -> float:
	return value * (1.0 - _normalize_side_effect_magnitude(magnitude))


static func apply_reverse_penalty(value: float, magnitude: float) -> float:
	return value * (1.0 + _normalize_side_effect_magnitude(magnitude))


static func apply_forward_integer_penalty(
	value: int,
	magnitude: float,
	is_boolean_lane: bool = false
) -> Dictionary:
	if is_boolean_lane:
		return _build_boolean_lane_exclusion(value)
	var normalized_magnitude := _normalize_side_effect_magnitude(magnitude)
	var raw_value := apply_forward_penalty(float(value), normalized_magnitude)
	var quantized_value := _find_forward_integer_candidate(value, normalized_magnitude)
	if quantized_value == value:
		return _build_integer_lane_exclusion(value, raw_value)
	return _build_integer_penalty_result(value, raw_value, quantized_value)


static func apply_reverse_integer_penalty(
	value: int,
	magnitude: float,
	is_boolean_lane: bool = false
) -> Dictionary:
	if is_boolean_lane:
		return _build_boolean_lane_exclusion(value)
	var normalized_magnitude := _normalize_side_effect_magnitude(magnitude)
	var raw_value := apply_reverse_penalty(float(value), normalized_magnitude)
	var quantized_value := _find_reverse_integer_candidate(value, normalized_magnitude)
	if quantized_value == value:
		return _build_integer_lane_exclusion(value, raw_value)
	return _build_integer_penalty_result(value, raw_value, quantized_value)


static func is_limit_break_eligible(perk_data: Dictionary) -> bool:
	return bool(get_limit_break_eligibility(perk_data).get("eligible", false))


static func get_limit_break_eligibility(perk_data: Dictionary) -> Dictionary:
	if perk_data.is_empty():
		return {"eligible": false, "reason": "missing_data"}
	if bool(perk_data.get("effective_level_exempt", false)):
		return {"eligible": false, "reason": "effective_level_exempt"}
	var max_level := int(perk_data.get("max_level", 1))
	if max_level <= 1:
		return {"eligible": false, "reason": "non_scaling_level"}
	return {"eligible": true, "reason": ""}


static func _normalize_unit_roll(roll_unit: float) -> float:
	return clampf(roll_unit, 0.0, 1.0)


static func _normalize_side_effect_magnitude(magnitude: float) -> float:
	return clampf(magnitude, SIDE_EFFECT_MIN_MAGNITUDE, SIDE_EFFECT_MAX_MAGNITUDE)


static func _byproduct_count_key(count: int) -> String:
	match count:
		1:
			return OUTCOME_BYPRODUCT_COUNT_1
		2:
			return OUTCOME_BYPRODUCT_COUNT_2
		_:
			return OUTCOME_BYPRODUCT_COUNT_3


static func _build_boolean_lane_exclusion(value: int) -> Dictionary:
	return {
		"applied": false,
		"excluded": true,
		"excluded_reason": "boolean_lane",
		"original_value": value,
		"raw_value": float(value),
		"value": value,
		"delta": 0,
	}


static func _build_integer_lane_exclusion(value: int, raw_value: float) -> Dictionary:
	return {
		"applied": false,
		"excluded": true,
		"excluded_reason": "unrepresentable_integer_lane",
		"original_value": value,
		"raw_value": raw_value,
		"value": value,
		"delta": 0,
	}


static func _find_forward_integer_candidate(value: int, target_magnitude: float) -> int:
	if value <= 0:
		return value
	var best_value := value
	var best_distance := INF
	var best_realized := INF
	for candidate in range(value - 1, -1, -1):
		var realized := float(value - candidate) / float(value)
		if realized < SIDE_EFFECT_MIN_MAGNITUDE or realized > SIDE_EFFECT_MAX_MAGNITUDE:
			continue
		var distance := absf(realized - target_magnitude)
		if distance < best_distance or (is_equal_approx(distance, best_distance) and realized < best_realized):
			best_value = candidate
			best_distance = distance
			best_realized = realized
	return best_value


static func _find_reverse_integer_candidate(value: int, target_magnitude: float) -> int:
	if value <= 0:
		return value
	var best_value := value
	var best_distance := INF
	var best_realized := INF
	var max_candidate := value + int(ceil(float(value) * SIDE_EFFECT_MAX_MAGNITUDE))
	for candidate in range(value + 1, max_candidate + 1):
		var realized := float(candidate - value) / float(value)
		if realized < SIDE_EFFECT_MIN_MAGNITUDE or realized > SIDE_EFFECT_MAX_MAGNITUDE:
			continue
		var distance := absf(realized - target_magnitude)
		if distance < best_distance or (is_equal_approx(distance, best_distance) and realized < best_realized):
			best_value = candidate
			best_distance = distance
			best_realized = realized
	return best_value


static func _build_integer_penalty_result(
	original_value: int,
	raw_value: float,
	quantized_value: int
) -> Dictionary:
	return {
		"applied": true,
		"excluded": false,
		"excluded_reason": "",
		"original_value": original_value,
		"raw_value": raw_value,
		"value": quantized_value,
		"delta": quantized_value - original_value,
	}
