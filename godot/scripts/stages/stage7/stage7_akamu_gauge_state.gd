extends RefCounted

const MAX_VALUE := 500.0
const ROUND_CARRY_RATIO := 0.7
const BOSS_HIT_GAIN := 80.0
const AWAKENED_BOSS_HIT_GAIN := 90.0
const SUPERSPEED_BOSS_HIT_GAIN := 20.0
const COMMON_DASH_COST := 50.0

var value := 0.0
var has_score_round_generation := false
var last_score_round_generation := 0


func reset_full() -> void:
	value = 0.0
	has_score_round_generation = false
	last_score_round_generation = 0


func has_runtime_state() -> bool:
	return has_score_round_generation or value > 0.0


func set_raw(new_value: float) -> void:
	# Production integrations historically write this public field directly,
	# including over-cap fixture values. Preserve that compatibility seam.
	value = new_value


func set_clamped(new_value: float) -> void:
	value = clampf(new_value, 0.0, MAX_VALUE)


func apply_score_round_carry(round_generation: int) -> bool:
	if has_score_round_generation and round_generation <= last_score_round_generation:
		return false
	has_score_round_generation = true
	last_score_round_generation = round_generation
	value = float(int(clampf(value, 0.0, MAX_VALUE) * ROUND_CARRY_RATIO))
	return true


func add(amount: float) -> float:
	value = minf(MAX_VALUE, value + maxf(0.0, amount))
	return value


func add_boss_hit(is_awakened: bool, superspeed_active: bool) -> float:
	var gain := BOSS_HIT_GAIN
	if superspeed_active:
		gain = SUPERSPEED_BOSS_HIT_GAIN
	elif is_awakened:
		gain = AWAKENED_BOSS_HIT_GAIN
	add(gain)
	return gain


func drain(amount: float) -> float:
	value = maxf(0.0, value - maxf(0.0, amount))
	return value


func try_commit_common_dash(superspeed_active: bool) -> bool:
	if superspeed_active:
		return true
	if value < COMMON_DASH_COST:
		return false
	value -= COMMON_DASH_COST
	return true


func commit_result(result: Dictionary, key: String = "boss_gauge") -> float:
	value = float(result.get(key, value))
	return value


func get_snapshot() -> Dictionary:
	return {
		"value": value,
		"max_value": MAX_VALUE,
		"has_score_round_generation": has_score_round_generation,
		"last_score_round_generation": last_score_round_generation,
	}
