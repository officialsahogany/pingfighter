extends SceneTree

const TowerAscentMapGenerator := preload(
	"res://scripts/tower_ascent/tower_ascent_map_generator.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const SAMPLE_SEED_COUNT := 128

var _failures: Array[String] = []
var _sampled_graph_count := 0
var _generated_node_count := 0
var _combat_node_count := 0
var _npc_node_count := 0
var _branch_eligible_node_count := 0
var _degree_one_node_count := 0
var _degree_two_node_count := 0
var _raw_outgoing_node_count := 0


func _init() -> void:
	_verify_many_seed_distribution()
	_verify_boss_adjacency_negative_leg()
	_verify_low_branching_negative_leg()
	if _failures.is_empty():
		print(
			"tower_ascent_map_distribution_contract_smoke: seeds=%d generated=%d boss=%d npc=%d boss_ratio=%0.4f degree1=%d degree2=%d degree2_ratio=%0.4f raw_degree2_ratio=%0.4f negative_legs=2"
			% [
				_sampled_graph_count,
				_generated_node_count,
				_combat_node_count,
				_npc_node_count,
				_safe_ratio(_combat_node_count, _generated_node_count),
				_degree_one_node_count,
				_degree_two_node_count,
				_safe_ratio(_degree_two_node_count, _branch_eligible_node_count),
				_safe_ratio(_degree_two_node_count, _raw_outgoing_node_count),
			]
		)
		print("tower_ascent_map_distribution_contract_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_many_seed_distribution() -> void:
	var generator := TowerAscentMapGenerator.new()
	for seed_offset in range(SAMPLE_SEED_COUNT):
		var map_seed := 4001 + seed_offset * 7919
		var graph: Dictionary = generator.generate_tower(map_seed)
		var repeated: Dictionary = generator.generate_tower(map_seed)
		_expect(not graph.is_empty(), "seed %d must generate a normalized graph" % map_seed)
		if graph.is_empty():
			continue
		_expect(
			generator.encode_graph(graph) == generator.encode_graph(repeated),
			"seed %d must remain byte deterministic" % map_seed
		)
		var report: Dictionary = generator.analyze_graph_integrity(graph, true, true)
		_expect(
			bool(report.get("valid", false)),
			"seed %d must satisfy distribution integrity: %s"
			% [map_seed, str(report.get("issues", []))]
		)
		var boss_count := int(report.get("combat_node_count", 0))
		var npc_count := int(report.get("npc_node_count", 0))
		var generated_count := int(report.get("generated_node_count", 0))
		var boss_ratio := float(report.get("boss_ratio", 1.0))
		var degree_two_ratio := float(report.get("degree_two_ratio", 0.0))
		_expect(
			boss_ratio <= TowerAscentTuning.TEMP_GENERATED_BOSS_NODE_MAX_RATIO + 0.000001,
			"seed %d boss density must not exceed twenty percent" % map_seed
		)
		_expect(
			npc_count >= boss_count * TowerAscentTuning.TEMP_GENERATED_NPC_PER_BOSS_MIN,
			"seed %d boss to NPC ratio must be at least one to four" % map_seed
		)
		_expect(
			int(report.get("boss_adjacency_count", -1)) == 0,
			"seed %d must forbid boss-to-boss edges" % map_seed
		)
		_expect(
			int(report.get("boss_spacing_violation_count", -1)) == 0,
			"seed %d boss rows must have a complete NPC row between them" % map_seed
		)
		_expect(
			degree_two_ratio + 0.000001 >= TowerAscentTuning.TEMP_MAP_DEGREE_TWO_MIN_RATIO,
			"seed %d choice-capable degree-two ratio must be at least seventy percent" % map_seed
		)
		_expect(
			int(report.get("consecutive_single_transition_count", -1)) == 0,
			"seed %d must not contain consecutive single-choice transitions" % map_seed
		)
		_sampled_graph_count += 1
		_generated_node_count += generated_count
		_combat_node_count += boss_count
		_npc_node_count += npc_count
		_branch_eligible_node_count += int(report.get("branch_eligible_node_count", 0))
		_degree_one_node_count += int(report.get("degree_one_node_count", 0))
		_degree_two_node_count += int(report.get("degree_two_node_count", 0))
		_raw_outgoing_node_count += int(report.get("raw_outgoing_node_count", 0))
	_expect(
		_sampled_graph_count == SAMPLE_SEED_COUNT,
		"all 128 authoritative seeds must be analyzed"
	)


func _verify_boss_adjacency_negative_leg() -> void:
	var generator := TowerAscentMapGenerator.new()
	var fixture := _low_branch_fixture()
	var phase: Dictionary = fixture.phases[0]
	for node_variant in phase.nodes:
		if node_variant is Dictionary and str((node_variant as Dictionary).get("id", "")) == "choice_c":
			(node_variant as Dictionary)["kind"] = "boss"
			(node_variant as Dictionary)["label"] = "adjacent fixture boss"
			break
	var report := generator.analyze_graph_integrity(fixture, true, true)
	_expect(not bool(report.get("valid", true)), "boss adjacency fixture must be RED")
	_expect(
		_issue_contains(report, "boss_adjacencies="),
		"boss adjacency fixture must identify the direct boss edge"
	)


func _verify_low_branching_negative_leg() -> void:
	var report := TowerAscentMapGenerator.new().analyze_graph_integrity(
		_low_branch_fixture(),
		true,
		true
	)
	_expect(not bool(report.get("valid", true)), "low branching fixture must be RED")
	_expect(
		_issue_contains(report, "degree_two_ratio="),
		"low branching fixture must identify the ratio failure"
	)


func _low_branch_fixture() -> Dictionary:
	var nodes: Array[Dictionary] = [
		_node("entry", 0, 0, "rest", 1, false),
		_node("choice_a", 1, 0, "shop", 2, false),
		_node("choice_b", 1, 1, "training", 2, false),
		_node("choice_c", 2, 0, "fallen_monk", 8, false),
		_node("choice_d", 2, 1, "guardian_spring", 8, false),
		_node("terminal", 3, 0, "boss", 9, true),
	]
	var rows: Array[Dictionary] = [
		{"id": "entry_row", "node_ids": ["entry"], "segment_floor": 1},
		{"id": "choice_row_1", "node_ids": ["choice_a", "choice_b"], "segment_floor": 1},
		{"id": "choice_row_2", "node_ids": ["choice_c", "choice_d"], "segment_floor": 8},
		{"id": "terminal_row", "node_ids": ["terminal"], "segment_floor": 9, "gatekeeper": true},
	]
	return {
		"phases": [{
			"id": TowerAscentMapGenerator.HUMAN_REALM_PHASE_ID,
			"realm_kind": "human_realm",
			"standard_clear_floor": 9,
			"entry_node_id": "entry",
			"floors": [{"floor": 1, "rows": rows}],
			"nodes": nodes,
			"edges": [
				{"from": "entry", "to": "choice_a"},
				{"from": "entry", "to": "choice_b"},
				{"from": "choice_a", "to": "choice_c"},
				{"from": "choice_b", "to": "choice_d"},
				{"from": "choice_c", "to": "terminal"},
				{"from": "choice_d", "to": "terminal"},
			],
		}],
	}


func _node(
	node_id: String,
	global_row: int,
	lane: int,
	kind: String,
	segment_floor: int,
	gatekeeper: bool
) -> Dictionary:
	return {
		"id": node_id,
		"floor": segment_floor,
		"segment_floor": segment_floor,
		"global_row": global_row,
		"lane": lane,
		"kind": kind,
		"content_state": "generated",
		"gatekeeper": gatekeeper,
		"floor_boundary": gatekeeper,
	}


func _issue_contains(report: Dictionary, fragment: String) -> bool:
	for issue_variant in report.get("issues", []):
		if str(issue_variant).contains(fragment):
			return true
	return false


func _safe_ratio(numerator: int, denominator: int) -> float:
	return 0.0 if denominator <= 0 else float(numerator) / float(denominator)


func _expect(condition: bool, message: String) -> void:
	if not condition and _failures.size() < 24 and not _failures.has(message):
		_failures.append(message)
