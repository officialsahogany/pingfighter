extends RefCounted

const Stage2AudioRouter := preload("res://scripts/stages/stage2/stage2_audio_router.gd")
const Stage2WaterCannonPayloadConfigBuilder := preload("res://scripts/stages/stage2/stage2_water_cannon_payload_config_builder.gd")
const Stage2WaterCannonPayloadFactory := preload("res://scripts/stages/stage2/stage2_water_cannon_payload_factory.gd")

const WATER_ROCK_FRAGMENT_MIN_COUNT := 20
const WATER_ROCK_FRAGMENT_MAX_COUNT := 25
const WATER_SPLASH_MIN_COUNT := 15
const WATER_SPLASH_MAX_COUNT := 20
const WATER_ROCK_FRAGMENT_LIFE_SEC := 100.0 / 60.0
const WATER_SPLASH_LIFE_SEC := 60.0 / 60.0
const WATER_ROCK_FRAGMENT_GRAVITY := 0.5 * 60.0 * 60.0
const WATER_SPLASH_GRAVITY := 0.3 * 60.0 * 60.0
const MAX_WATER_PAYLOADS := 64
const NORMAL_ROCK_FRAGMENT_LIFE_SEC := 45.0 / 60.0
const MAX_NORMAL_ROCK_FRAGMENTS := 180
const LEAF_PARTICLE_LIFE_SEC := 0.95
const MAX_LEAF_PARTICLES := 120
const IMPACT_LEAF_STRENGTH := 1.20
const IMPACT_SHAKE_DURATION_SEC := 0.060
const IMPACT_SHAKE_STRENGTH := 3.0
const FRAGMENT_WARNING_DURATION_SEC := 0.90

var payload_factory: Object = Stage2WaterCannonPayloadFactory.new()
var payload_config_builder: Object = Stage2WaterCannonPayloadConfigBuilder.new()


func finish_impact(
	rock_state: Object,
	rock_query: Object,
	water_cannon_state: Object,
	water_visual_state: Object,
	rock_feedback_coordinator: Object,
	ambient_state: Object,
	rock_fragment_state: Object,
	random_source: RandomNumberGenerator,
	skill_warning_state: Object,
	deps: Dictionary,
	golden_reward_callback: Callable,
	debris_region_count: int
) -> Dictionary:
	if rock_state == null or rock_query == null or water_cannon_state == null:
		return {"accepted": false}
	var target_index: int = rock_query.get_index_by_id(
		rock_state.rocks,
		int(water_cannon_state.target_id)
	)
	if target_index < 0:
		water_cannon_state.cancel()
		return {"accepted": false}

	var target_rock: Dictionary = rock_state.rocks[target_index]
	var center: Vector2 = rock_query.get_center(target_rock)
	rock_state.remove_at(target_index)
	var water_payload_count := _emit_water_payloads(
		target_rock,
		center,
		water_visual_state,
		random_source,
		debris_region_count
	)
	var fragment_count: int = rock_feedback_coordinator.emit_fragment_burst(
		target_rock,
		center,
		rock_fragment_state,
		random_source,
		debris_region_count,
		MAX_NORMAL_ROCK_FRAGMENTS,
		NORMAL_ROCK_FRAGMENT_LIFE_SEC
	)
	var leaf_count: int = rock_feedback_coordinator.emit_leaf_burst(
		center,
		IMPACT_LEAF_STRENGTH,
		ambient_state,
		random_source,
		MAX_LEAF_PARTICLES,
		LEAF_PARTICLE_LIFE_SEC
	)
	var rewarded: bool = rock_feedback_coordinator.emit_golden_reward(
		target_rock,
		center,
		golden_reward_callback
	)
	_request_impact_shake(deps)
	Stage2AudioRouter.play_rock_break(target_rock, deps)
	if skill_warning_state != null:
		skill_warning_state.trigger("fragment", "파편 주의!", FRAGMENT_WARNING_DURATION_SEC)
	water_cannon_state.cancel()
	return {
		"accepted": true,
		"rock": target_rock,
		"center": center,
		"water_payload_count": water_payload_count,
		"fragment_count": fragment_count,
		"leaf_count": leaf_count,
		"rewarded": rewarded,
	}


func _emit_water_payloads(
	rock: Dictionary,
	center: Vector2,
	water_visual_state: Object,
	random_source: RandomNumberGenerator,
	debris_region_count: int
) -> int:
	if water_visual_state == null or random_source == null:
		return 0
	var payload_config: Dictionary = payload_config_builder.build_config(
		WATER_ROCK_FRAGMENT_MIN_COUNT,
		WATER_ROCK_FRAGMENT_MAX_COUNT,
		WATER_SPLASH_MIN_COUNT,
		WATER_SPLASH_MAX_COUNT,
		WATER_ROCK_FRAGMENT_LIFE_SEC,
		WATER_SPLASH_LIFE_SEC,
		WATER_ROCK_FRAGMENT_GRAVITY,
		WATER_SPLASH_GRAVITY
	)
	var payloads: Array = payload_factory.build_payloads(
		rock,
		center,
		maxi(0, debris_region_count),
		random_source,
		payload_config
	)
	water_visual_state.append_splashes(payloads, MAX_WATER_PAYLOADS)
	return payloads.size()


func _request_impact_shake(deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(IMPACT_SHAKE_DURATION_SEC, IMPACT_SHAKE_STRENGTH)
