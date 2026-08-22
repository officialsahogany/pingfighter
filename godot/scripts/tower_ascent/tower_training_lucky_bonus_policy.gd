extends RefCounted

const CHANCE := 0.20
const EFFECT_MULTIPLIER := 1.5
const STORAGE_TRAINING_ID := "physique_storage"


static func is_lucky_eligible(training_id: String) -> bool:
	return training_id.strip_edges() != STORAGE_TRAINING_ID


# GRT-011: one call consumes exactly one authoritative sample. Animation frames
# and presentation RNG never enter this policy.
static func roll_from_gameplay_state(gameplay_rng_state: Dictionary) -> Dictionary:
	var seed_value := int(gameplay_rng_state.get("seed", 140913))
	if seed_value == 0:
		seed_value = 140913
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var state_value := int(gameplay_rng_state.get("state", seed_value))
	if state_value != 0:
		rng.state = state_value
	var sample := rng.randf()
	return {
		"triggered": sample < CHANCE,
		"sample": sample,
		"roll_count": 1,
		"gameplay_rng_state": {
			"seed": int(rng.seed),
			"state": int(rng.state),
		},
	}
