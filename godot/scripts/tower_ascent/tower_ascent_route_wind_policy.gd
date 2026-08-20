extends RefCounted

const CALM_PROBABILITY := 0.60
const WIND_PROBABILITY := 0.40
const DIRECTION_LEFT := -1
const DIRECTION_CALM := 0
const DIRECTION_RIGHT := 1
const STRENGTH_MIN := 1
const STRENGTH_MAX := 3
const WIND_STRENGTH_TABLE := [
	{"level": 1, "key": "weak", "bias_degrees": 6.0, "bar_ratio": 0.34},
	{"level": 2, "key": "steady", "bias_degrees": 12.0, "bar_ratio": 0.67},
	{"level": 3, "key": "strong", "bias_degrees": 18.0, "bar_ratio": 1.0},
]


static func roll_from_gameplay_state(gameplay_rng_state: Dictionary) -> Dictionary:
	var seed_value := int(gameplay_rng_state.get("seed", 140913))
	if seed_value == 0:
		seed_value = 140913
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var state_value := int(gameplay_rng_state.get("state", seed_value))
	if state_value != 0:
		rng.state = state_value
	var wind_model := calm_model()
	if not is_calm_roll(rng.randf()):
		var direction := DIRECTION_LEFT if rng.randf() < 0.5 else DIRECTION_RIGHT
		wind_model = build_model(direction, rng.randi_range(STRENGTH_MIN, STRENGTH_MAX))
	return {
		"wind": wind_model,
		"gameplay_rng_state": {
			"seed": int(rng.seed),
			"state": int(rng.state),
		},
	}


static func is_calm_roll(value: float) -> bool:
	return clampf(value, 0.0, 1.0) < CALM_PROBABILITY


static func calm_model() -> Dictionary:
	return {
		"is_windy": false,
		"direction": DIRECTION_CALM,
		"direction_key": "calm",
		"strength_level": 0,
		"strength_key": "calm",
		"strength_ratio": 0.0,
		"bias_degrees": 0.0,
	}


static func build_model(direction: int, strength_level: int) -> Dictionary:
	var normalized_direction := DIRECTION_LEFT if direction < 0 else DIRECTION_RIGHT
	var strength := _strength_step(strength_level)
	return {
		"is_windy": true,
		"direction": normalized_direction,
		"direction_key": "left" if normalized_direction < 0 else "right",
		"strength_level": int(strength.get("level", STRENGTH_MIN)),
		"strength_key": str(strength.get("key", "weak")),
		"strength_ratio": float(strength.get("bar_ratio", 0.34)),
		"bias_degrees": float(strength.get("bias_degrees", 6.0)) * normalized_direction,
	}


static func normalize_model(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return calm_model()
	var model := value as Dictionary
	if not bool(model.get("is_windy", false)):
		return calm_model()
	return build_model(
		int(model.get("direction", DIRECTION_CALM)),
		int(model.get("strength_level", STRENGTH_MIN))
	)


static func get_strength_table() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for step_variant in WIND_STRENGTH_TABLE:
		result.append((step_variant as Dictionary).duplicate(true))
	return result


static func _strength_step(strength_level: int) -> Dictionary:
	var normalized_level := clampi(strength_level, STRENGTH_MIN, STRENGTH_MAX)
	for step_variant in WIND_STRENGTH_TABLE:
		var step := step_variant as Dictionary
		if int(step.get("level", 0)) == normalized_level:
			return step
	return WIND_STRENGTH_TABLE[0]
