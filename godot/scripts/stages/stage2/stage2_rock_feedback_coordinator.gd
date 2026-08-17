extends RefCounted

const Stage2AmbientPayloadFactory := preload("res://scripts/stages/stage2/stage2_ambient_payload_factory.gd")
const Stage2AudioRouter := preload("res://scripts/stages/stage2/stage2_audio_router.gd")
const Stage2RockFragmentPayloadConfigBuilder := preload("res://scripts/stages/stage2/stage2_rock_fragment_payload_config_builder.gd")
const Stage2RockFragmentPayloadFactory := preload("res://scripts/stages/stage2/stage2_rock_fragment_payload_factory.gd")
const Stage2RockVisualFactory := preload("res://scripts/stages/stage2/stage2_rock_visual_factory.gd")

const DEFAULT_LEAF_PARTICLE_LIFE_SEC := 0.95
const DEFAULT_MAX_LEAF_PARTICLES := 120
const DEFAULT_ROCK_FRAGMENT_LIFE_SEC := 45.0 / 60.0
const DEFAULT_MAX_ROCK_FRAGMENTS := 180
const HIT_FLASH_SEC := 0.24
const RICOCHET_FLASH_SEC := 0.16
const HIT_LEAF_STRENGTH := 1.0
const HIT_SHAKE_DURATION_SEC := 0.045
const HIT_SHAKE_STRENGTH := 2.2

var ambient_payload_factory: Object = Stage2AmbientPayloadFactory.new()
var fragment_payload_factory: Object = Stage2RockFragmentPayloadFactory.new()
var fragment_payload_config_builder: Object = Stage2RockFragmentPayloadConfigBuilder.new()
var rock_visual_factory: Object = Stage2RockVisualFactory.new()


func apply_hit(
	index: int,
	rock_state: Object,
	rock_query: Object,
	ambient_state: Object,
	fragment_state: Object,
	random_source: RandomNumberGenerator,
	deps: Dictionary,
	golden_reward_callback: Callable,
	debris_region_count: int,
	config: Dictionary = {}
) -> Dictionary:
	if rock_state == null or index < 0 or index >= rock_state.rocks.size():
		return {"accepted": false, "destroyed": false}
	var rock: Dictionary = rock_state.rocks[index]
	var center: Vector2 = rock_query.get_center(rock)
	rock["hp"] = int(rock.get("hp", 1)) - 1
	rock["flash"] = HIT_FLASH_SEC
	emit_leaf_burst(
		center,
		HIT_LEAF_STRENGTH,
		ambient_state,
		random_source,
		int(config.get("max_leaf_particles", DEFAULT_MAX_LEAF_PARTICLES)),
		float(config.get("leaf_particle_life_sec", DEFAULT_LEAF_PARTICLE_LIFE_SEC))
	)
	_request_hit_shake(deps)
	var destroyed: bool = int(rock.get("hp", 0)) <= 0
	if destroyed:
		emit_fragment_burst(
			rock,
			center,
			fragment_state,
			random_source,
			debris_region_count,
			int(config.get("max_rock_fragments", DEFAULT_MAX_ROCK_FRAGMENTS)),
			float(config.get("rock_fragment_life_sec", DEFAULT_ROCK_FRAGMENT_LIFE_SEC))
		)
		emit_golden_reward(rock, center, golden_reward_callback)
		Stage2AudioRouter.play_rock_break(rock, deps)
		rock_state.remove_at(index)
	else:
		Stage2AudioRouter.play_rock_hit(deps)
		rock_state.replace_at(index, rock)
	return {
		"accepted": true,
		"destroyed": destroyed,
		"rock": rock,
		"center": center,
	}


func mark_ricochet(index: int, rock_state: Object, deps: Dictionary) -> bool:
	if rock_state == null or index < 0 or index >= rock_state.rocks.size():
		return false
	var rock: Dictionary = rock_state.rocks[index]
	rock["flash"] = max(float(rock.get("flash", 0.0)), RICOCHET_FLASH_SEC)
	rock_state.replace_at(index, rock)
	Stage2AudioRouter.play_rock_hit(deps)
	return true


func emit_destruction_feedback(
	rock: Dictionary,
	center: Vector2,
	leaf_strength: float,
	ambient_state: Object,
	fragment_state: Object,
	random_source: RandomNumberGenerator,
	deps: Dictionary,
	golden_reward_callback: Callable,
	debris_region_count: int,
	config: Dictionary = {}
) -> void:
	emit_fragment_burst(
		rock,
		center,
		fragment_state,
		random_source,
		debris_region_count,
		int(config.get("max_rock_fragments", DEFAULT_MAX_ROCK_FRAGMENTS)),
		float(config.get("rock_fragment_life_sec", DEFAULT_ROCK_FRAGMENT_LIFE_SEC))
	)
	emit_leaf_burst(
		center,
		leaf_strength,
		ambient_state,
		random_source,
		int(config.get("max_leaf_particles", DEFAULT_MAX_LEAF_PARTICLES)),
		float(config.get("leaf_particle_life_sec", DEFAULT_LEAF_PARTICLE_LIFE_SEC))
	)
	emit_golden_reward(rock, center, golden_reward_callback)
	Stage2AudioRouter.play_rock_break(rock, deps)


func emit_leaf_burst(
	center: Vector2,
	strength: float,
	ambient_state: Object,
	random_source: RandomNumberGenerator,
	max_particle_count: int = DEFAULT_MAX_LEAF_PARTICLES,
	particle_life_sec: float = DEFAULT_LEAF_PARTICLE_LIFE_SEC
) -> int:
	if ambient_state == null or random_source == null:
		return 0
	var count: int = clampi(int(round(8.0 + strength * 10.0)), 8, 20)
	for _index in range(count):
		var side := "left" if random_source.randf() < 0.5 else "right"
		ambient_state.append_leaf_particle(ambient_payload_factory.build_leaf_particle(
			center,
			side,
			strength,
			random_source,
			particle_life_sec
		), max_particle_count)
	return count


func emit_fragment_burst(
	rock: Dictionary,
	center: Vector2,
	fragment_state: Object,
	random_source: RandomNumberGenerator,
	debris_region_count: int,
	max_fragment_count: int = DEFAULT_MAX_ROCK_FRAGMENTS,
	fragment_life_sec: float = DEFAULT_ROCK_FRAGMENT_LIFE_SEC,
	fragment_config_overrides: Dictionary = {}
) -> int:
	if fragment_state == null or random_source == null:
		return 0
	var colors: Array = rock.get(
		"style_colors",
		rock_visual_factory.get_style_colors(str(rock.get("style_type", "gray_stone")))
	)
	var config: Dictionary = fragment_payload_config_builder.build_config(fragment_life_sec)
	config.merge(fragment_config_overrides, true)
	var fragments: Array = fragment_payload_factory.build_fragments(
		rock,
		center,
		maxi(0, debris_region_count),
		colors,
		random_source,
		config
	)
	fragment_state.append_fragments(fragments, max_fragment_count)
	return fragments.size()


func _request_hit_shake(deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(HIT_SHAKE_DURATION_SEC, HIT_SHAKE_STRENGTH)


func emit_golden_reward(rock: Dictionary, center: Vector2, callback: Callable) -> bool:
	if not bool(rock.get("is_golden", false)) or not callback.is_valid():
		return false
	callback.call(center)
	return true
