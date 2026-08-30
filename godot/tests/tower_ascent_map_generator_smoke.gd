extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentMapGenerator := preload(
	"res://scripts/tower_ascent/tower_ascent_map_generator.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	_verify_seed_determinism_and_rng_isolation()
	_verify_flow_uses_generated_graph_only_behind_flag()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_map_generator_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_seed_determinism_and_rng_isolation() -> void:
	var generator := TowerAscentMapGenerator.new()
	var blueprint := _blueprint()
	var gameplay_rng := RandomNumberGenerator.new()
	gameplay_rng.seed = 90210
	var control_rng := RandomNumberGenerator.new()
	control_rng.seed = 90210
	var before_state := gameplay_rng.state
	var first: Dictionary = generator.generate(112233, blueprint)
	var second: Dictionary = generator.generate(112233, blueprint)
	var different: Dictionary = generator.generate(112234, blueprint)
	_expect(not first.is_empty(), "valid row blueprints must generate a graph")
	_expect(
		generator.encode_graph(first) == generator.encode_graph(second),
		"same seed and generator version must produce byte-identical graphs"
	)
	_expect(
		generator.encode_graph(first) != generator.encode_graph(different),
		"different map seeds must produce different graph bytes"
	)
	_expect(gameplay_rng.state == before_state, "map generation must not advance gameplay RNG state")
	_expect(gameplay_rng.randi() == control_rng.randi(), "map generation must not perturb the gameplay RNG sequence")
	_expect(
		str(first.get("generator_version", "")) == TowerAscentMapGenerator.GENERATOR_VERSION,
		"generated graphs must carry the generator version"
	)
	_expect(generator.generate(1, []).is_empty(), "empty blueprints must fail closed")


func _verify_flow_uses_generated_graph_only_behind_flag() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	var disabled := TowerAscentFlowOwner.new()
	_expect(
		not disabled.prepare_vertical_slice_combat(null, {"run_id": "off", "map_seed": 44}),
		"flag OFF must preserve the legacy path without generating a tower map"
	)
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var first := TowerAscentFlowOwner.new()
	var second := TowerAscentFlowOwner.new()
	var context := {"run_id": "generated-flow", "map_seed": 44, "current_stage": 4}
	_expect(first.begin_vertical_slice(null, Callable(), context), "flag ON must start from the generated graph")
	_expect(second.begin_vertical_slice(null, Callable(), context), "the same generated flow fixture must start twice")
	var first_snapshot: Dictionary = first.export_snapshot()
	var second_snapshot: Dictionary = second.export_snapshot()
	_expect(first_snapshot.map_generator_version == TowerAscentMapGenerator.GENERATOR_VERSION, "snapshot must pin the generator version")
	_expect(int(first_snapshot.map_seed) == 44, "snapshot must pin the map seed")
	_expect(first_snapshot.map_graph == second_snapshot.map_graph, "same flow seed must preserve the generated graph")
	_expect(first.get_graph_nodes().size() > 4, "the generated tower must replace the former fixed graph")
	var phases := first.get_graph_phases()
	_expect(phases.size() == 2, "tower flow integration must retain both realm phases")
	_expect(phases[0].floors.size() == 9 and phases[1].floors.size() == 3, "tower flow integration must retain all generated floor metadata across the two phases")


func _blueprint() -> Array:
	return [{
		"floor": 1,
		"rows": [
			{
				"candidate_count": 1,
				"node_ids": ["start"],
				"kinds": ["boss"],
				"labels": ["시작"],
				"display_y": 590,
			},
			{
				"candidate_count": 2,
				"node_ids": ["left", "right"],
				"kinds": ["rest", "shop"],
				"labels": ["모닥불", "상점"],
				"display_y": 165,
			},
		],
	}]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
