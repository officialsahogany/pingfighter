extends RefCounted

const BENEFIT_MIN := -3
const BENEFIT_MAX := 3
const BENEFIT_BUCKET_COUNT := BENEFIT_MAX - BENEFIT_MIN + 1

const STAT_PLAYER_SPEED := "player_speed"
const STAT_PADDLE_SIZE := "paddle_size"
const STAT_SKILL_GAUGE := "skill_gauge"
const STAT_DASH_DISTANCE := "dash_distance"
const STAT_DASH_RECOVERY := "dash_recovery"
const STAT_DASH_COOLDOWN := "dash_cooldown"
const STAT_ITEM_COOLDOWN := "item_cooldown"

const STAT_KEYS: Array[String] = [
	STAT_PLAYER_SPEED,
	STAT_PADDLE_SIZE,
	STAT_SKILL_GAUGE,
	STAT_DASH_DISTANCE,
	STAT_DASH_RECOVERY,
	STAT_DASH_COOLDOWN,
	STAT_ITEM_COOLDOWN,
]
const LOWER_IS_BETTER_STAT_KEYS: Array[String] = [
	STAT_DASH_RECOVERY,
	STAT_DASH_COOLDOWN,
	STAT_ITEM_COOLDOWN,
]


func roll(roll_units: Array) -> Dictionary:
	if roll_units.size() != STAT_KEYS.size():
		return {
			"accepted": false,
			"blocked_reason": "requires_seven_roll_units",
		}

	var benefits: Dictionary = {}
	var raw: Dictionary = {}
	for index: int in range(STAT_KEYS.size()):
		var roll_value: Variant = roll_units[index]
		if typeof(roll_value) != TYPE_FLOAT and typeof(roll_value) != TYPE_INT:
			return {
				"accepted": false,
				"blocked_reason": "invalid_roll_unit",
				"invalid_index": index,
			}
		var stat_key: String = STAT_KEYS[index]
		var benefit: int = benefit_from_unit(float(roll_value))
		benefits[stat_key] = benefit
		raw[stat_key] = raw_from_benefit(stat_key, benefit)

	return {
		"accepted": true,
		"benefits": benefits,
		"raw": raw,
	}


func benefit_from_unit(roll_unit: float) -> int:
	var normalized_unit := clampf(roll_unit, 0.0, 1.0)
	var bucket := mini(int(floor(normalized_unit * float(BENEFIT_BUCKET_COUNT))), BENEFIT_BUCKET_COUNT - 1)
	return BENEFIT_MIN + bucket


func raw_from_benefit(stat_key: String, benefit: int) -> int:
	var clamped_benefit := clampi(benefit, BENEFIT_MIN, BENEFIT_MAX)
	if is_lower_is_better(stat_key):
		return -clamped_benefit
	return clamped_benefit


func is_lower_is_better(stat_key: String) -> bool:
	return stat_key.strip_edges() in LOWER_IS_BETTER_STAT_KEYS


func get_allowed_raw_range(stat_key: String) -> Vector2i:
	if is_lower_is_better(stat_key):
		return Vector2i(-BENEFIT_MAX, -BENEFIT_MIN)
	return Vector2i(BENEFIT_MIN, BENEFIT_MAX)


func get_stat_keys() -> Array[String]:
	return STAT_KEYS.duplicate()
