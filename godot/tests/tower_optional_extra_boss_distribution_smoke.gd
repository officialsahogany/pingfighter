extends SceneTree

const TowerAscentBossRegistry := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_registry.gd"
)
const TowerAscentMapGenerator := preload(
	"res://scripts/tower_ascent/tower_ascent_map_generator.gd"
)
const TowerAscentMapIconography := preload(
	"res://scripts/tower_ascent/tower_ascent_map_iconography.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerAuditionBuildConfig := preload(
	"res://scripts/tower_ascent/tower_audition_build_config.gd"
)

const SAMPLE_SEED_COUNT := 128
const SAMPLE_SEED_START := 9109
const SAMPLE_SEED_STEP := 7919
const SPAWN_RATE_TOLERANCE := 0.10
const EXPECTED_GENERATOR_VERSION := "tower_map_v14_optional_extra_boss"

var _failures: Array[String] = []
var _roll_hits_by_floor: Dictionary = {}
var _spawns_by_floor: Dictionary = {}
var _encounter_histograms_by_floor: Dictionary = {}
var _total_roll_hits := 0
var _total_spawns := 0
var _unique_pool_exhausted_skips := 0
var _no_bypass_candidate_skips := 0
var _maximum_optional_bosses_in_one_floor := 0
var _maximum_boss_ratio := 0.0
var _minimum_npc_per_boss_ratio := INF
var _forced_fixture: Dictionary = {}
var _negative_leg_count := 0


func _init() -> void:
	TowerAuditionBuildConfig.debug_set_enabled(false)
	_verify_distribution()
	_verify_forced_passage_negative_leg()
	TowerAuditionBuildConfig.debug_clear_enabled_override()
	if _failures.is_empty():
		print(
			"tower_optional_extra_boss_distribution_smoke: seeds=%d roll_rates=%s spawns=%s encounter_histograms=%s"
			% [
				SAMPLE_SEED_COUNT,
				str(_rate_by_floor(_roll_hits_by_floor)),
				str(_spawns_by_floor),
				str(_encounter_histograms_by_floor),
			]
		)
		print(
			"tower_optional_extra_boss_distribution_smoke: roll_hits=%d spawned=%d unique_pool_exhausted_skips=%d no_bypass_candidate_skips=%d max_per_floor=%d max_boss_ratio=%0.6f min_npc_per_boss=%0.6f negative_legs=%d"
			% [
				_total_roll_hits,
				_total_spawns,
				_unique_pool_exhausted_skips,
				_no_bypass_candidate_skips,
				_maximum_optional_bosses_in_one_floor,
				_maximum_boss_ratio,
				_minimum_npc_per_boss_ratio,
				_negative_leg_count,
			]
		)
		print("tower_optional_extra_boss_distribution_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_distribution() -> void:
	var generator := TowerAscentMapGenerator.new()
	var registry := TowerAscentBossRegistry.new()
	var active_clear_floor := TowerAuditionBuildConfig.get_clear_floor()
	_expect(
		TowerAscentMapGenerator.GENERATOR_VERSION == EXPECTED_GENERATOR_VERSION,
		"generator version must advance to the optional extra-boss contract"
	)
	_expect(
		active_clear_floor == TowerAuditionBuildConfig.STANDARD_CLEAR_FLOOR,
		"distribution seal must run against the standard tower"
	)
	for floor_number in range(
		TowerAscentBossRegistry.TEMP_OPTIONAL_EXTRA_BOSS_FLOOR_MIN,
		active_clear_floor
	):
		_roll_hits_by_floor[floor_number] = 0
		_spawns_by_floor[floor_number] = 0
		_encounter_histograms_by_floor[floor_number] = {1: 0, 2: 0}
	for seed_offset in range(SAMPLE_SEED_COUNT):
		var map_seed := SAMPLE_SEED_START + seed_offset * SAMPLE_SEED_STEP
		var graph: Dictionary = generator.generate_tower(map_seed)
		var repeated: Dictionary = generator.generate_tower(map_seed)
		_expect(not graph.is_empty(), "seed %d must generate a tower" % map_seed)
		if graph.is_empty():
			continue
		_expect(
			generator.encode_graph(graph) == generator.encode_graph(repeated),
			"seed %d must remain byte deterministic" % map_seed
		)
		if _forced_fixture.is_empty():
			_forced_fixture = graph.duplicate(true)
		var distribution_variant: Variant = graph.get(
			TowerAscentBossRegistry.OPTIONAL_EXTRA_BOSS_DISTRIBUTION_KEY,
			{}
		)
		_expect(
			distribution_variant is Dictionary,
			"seed %d must publish optional extra-boss distribution evidence" % map_seed
		)
		if not (distribution_variant is Dictionary):
			continue
		var distribution := distribution_variant as Dictionary
		_expect(
			is_equal_approx(
				float(distribution.get("spawn_chance_per_floor", -1.0)),
				TowerAscentBossRegistry.TEMP_OPTIONAL_EXTRA_BOSS_SPAWN_CHANCE_PER_FLOOR
			),
			"seed %d must report the canonical spawn chance" % map_seed
		)
		_expect(
			int(distribution.get("floor_min", -1))
				== TowerAscentBossRegistry.TEMP_OPTIONAL_EXTRA_BOSS_FLOOR_MIN,
			"seed %d must preserve the floor-2 lower bound" % map_seed
		)
		_expect(
			int(distribution.get("floor_max", -1)) == active_clear_floor - 1,
			"seed %d must derive the upper bound from the terminal floor" % map_seed
		)
		var floor_reports: Dictionary = distribution.get("floor_reports", {})
		var graph_optional_count := 0
		for floor_number in range(
			TowerAscentBossRegistry.TEMP_OPTIONAL_EXTRA_BOSS_FLOOR_MIN,
			active_clear_floor
		):
			var floor_report: Dictionary = floor_reports.get(floor_number, {})
			_expect(
				not floor_report.is_empty(),
				"seed %d floor %d must publish a roll report" % [map_seed, floor_number]
			)
			var roll_hit := bool(floor_report.get("roll_hit", false))
			if roll_hit:
				_roll_hits_by_floor[floor_number] = int(
					_roll_hits_by_floor.get(floor_number, 0)
				) + 1
				_total_roll_hits += 1
			var optional_nodes := _optional_nodes_for_floor(graph, floor_number)
			var optional_count := optional_nodes.size()
			graph_optional_count += optional_count
			_maximum_optional_bosses_in_one_floor = maxi(
				_maximum_optional_bosses_in_one_floor,
				optional_count
			)
			_expect(
				optional_count <= TowerAscentBossRegistry.TEMP_OPTIONAL_EXTRA_BOSS_MAX_PER_FLOOR,
				"seed %d floor %d must add at most one optional boss"
				% [map_seed, floor_number]
			)
			_expect(
				int(floor_report.get("spawned_count", -1)) == optional_count,
				"seed %d floor %d report and graph spawn counts must agree"
				% [map_seed, floor_number]
			)
			_spawns_by_floor[floor_number] = int(
				_spawns_by_floor.get(floor_number, 0)
			) + optional_count
			var encounter_count := 1 + optional_count
			var floor_histogram: Dictionary = _encounter_histograms_by_floor[floor_number]
			floor_histogram[encounter_count] = int(
				floor_histogram.get(encounter_count, 0)
			) + 1
			_encounter_histograms_by_floor[floor_number] = floor_histogram
			for optional_node in optional_nodes:
				_verify_optional_node(map_seed, floor_number, optional_node, registry)
		_total_spawns += graph_optional_count
		_expect(
			_count_optional_nodes_for_floor(graph, 1) == 0,
			"seed %d must leave the entire first-floor structure unchanged" % map_seed
		)
		_expect(
			_count_optional_nodes_for_floor(graph, active_clear_floor) == 0,
			"seed %d must not touch the terminal floor" % map_seed
		)
		_expect(
			_count_floor_one_generated_bosses(graph) == 3,
			"seed %d must retain the full three-boss first-floor roster" % map_seed
		)
		var bypass_report := registry.analyze_optional_extra_boss_bypass(
			graph,
			active_clear_floor
		)
		_expect(
			bool(bypass_report.get("valid", false)),
			"seed %d every optional boss must have an entry-to-terminal bypass: %s"
			% [map_seed, str(bypass_report.get("issues", []))]
		)
		_expect(
			int(bypass_report.get("optional_node_count", -1)) == graph_optional_count,
			"seed %d bypass analyzer must inspect every optional boss" % map_seed
		)
		var uniqueness_report := registry.analyze_visible_boss_contract(
			graph,
			active_clear_floor
		)
		_expect(
			bool(uniqueness_report.get("valid", false)),
			"seed %d canonical encounter keys must remain unique: %s"
			% [map_seed, str(uniqueness_report.get("issues", []))]
		)
		_verify_explicit_canonical_uniqueness(map_seed, graph, registry)
		var integrity := generator.analyze_graph_integrity(graph, true, true)
		_expect(
			bool(integrity.get("valid", false)),
			"seed %d distribution integrity must remain GREEN: %s"
			% [map_seed, str(integrity.get("issues", []))]
		)
		var boss_count := int(integrity.get("combat_node_count", 0))
		var npc_count := int(integrity.get("npc_node_count", 0))
		var boss_ratio := float(integrity.get("boss_ratio", 0.0))
		var npc_per_boss := _safe_ratio(npc_count, boss_count)
		_maximum_boss_ratio = maxf(_maximum_boss_ratio, boss_ratio)
		_minimum_npc_per_boss_ratio = minf(_minimum_npc_per_boss_ratio, npc_per_boss)
		_expect(
			boss_ratio <= TowerAscentTuning.TEMP_GENERATED_BOSS_NODE_MAX_RATIO + 0.000001,
			"seed %d recalibrated boss ratio must remain within its ceiling" % map_seed
		)
		_expect(
			npc_per_boss + 0.000001 >= TowerAscentTuning.TEMP_GENERATED_NPC_PER_BOSS_MIN,
			"seed %d recalibrated NPC:boss ratio must remain within its floor" % map_seed
		)
		_unique_pool_exhausted_skips += int(
			distribution.get("unique_pool_exhausted_skip_count", 0)
		)
		_no_bypass_candidate_skips += int(
			distribution.get("no_bypass_candidate_skip_count", 0)
		)
	_expect(_total_spawns > 0, "128 seeds must exercise optional extra-boss spawns")
	_expect(
		_no_bypass_candidate_skips == 0,
		"all current wide-row candidates must retain a bypass"
	)
	for floor_number in range(
		TowerAscentBossRegistry.TEMP_OPTIONAL_EXTRA_BOSS_FLOOR_MIN,
		active_clear_floor
	):
		var roll_rate := _safe_ratio(
			int(_roll_hits_by_floor.get(floor_number, 0)),
			SAMPLE_SEED_COUNT
		)
		_expect(
			absf(
				roll_rate
				- TowerAscentBossRegistry.TEMP_OPTIONAL_EXTRA_BOSS_SPAWN_CHANCE_PER_FLOOR
			) <= SPAWN_RATE_TOLERANCE + 0.000001,
			"floor %d roll rate %0.4f must remain inside the 0.45 +/- 0.10 band"
			% [floor_number, roll_rate]
		)
		var spawned_count := int(_spawns_by_floor.get(floor_number, 0))
		if floor_number in [2, 3]:
			_expect(
				spawned_count == int(_roll_hits_by_floor.get(floor_number, 0)),
				"floor %d has unused canonical slots and must realize every hit" % floor_number
			)
		else:
			_expect(
				spawned_count == 0,
				"floor %d shell pool is canonically exhausted and must skip safely"
				% floor_number
			)


func _verify_optional_node(
	map_seed: int,
	floor_number: int,
	node: Dictionary,
	registry: RefCounted
) -> void:
	_expect(
		str(node.get("optional_extra_boss_source_kind", ""))
			in TowerAscentBossRegistry.NPC_FILL_KINDS,
		"seed %d floor %d optional boss must come from an NPC node"
		% [map_seed, floor_number]
	)
	_expect(
		not bool(node.get("gatekeeper", false))
			and not bool(node.get("floor_one_boss_choice", false)),
		"seed %d floor %d optional boss must not rewrite a gate or floor-one choice"
		% [map_seed, floor_number]
	)
	var slot_id := str(node.get("boss_slot_id", ""))
	var slot: Dictionary = registry.call("get_slot", slot_id)
	_expect(
		int(slot.get("slot_floor", 0)) == floor_number,
		"seed %d floor %d optional boss must consume that floor's slot pool"
		% [map_seed, floor_number]
	)
	var encounter: Dictionary = registry.call("resolve_battle_encounter", slot_id)
	_expect(
		not encounter.is_empty(),
		"seed %d floor %d optional boss must use existing battle routing"
		% [map_seed, floor_number]
	)
	var iconography := TowerAscentMapIconography.new()
	var boss_icon_id := iconography.resolve_boss_id_for_node(node)
	var icon_path := iconography.resolve_icon_path(str(node.get("kind", "")), boss_icon_id)
	_expect(
		not boss_icon_id.is_empty() and FileAccess.file_exists(icon_path),
		"seed %d floor %d optional boss must resolve an existing map icon"
		% [map_seed, floor_number]
	)


func _verify_explicit_canonical_uniqueness(
	map_seed: int,
	graph: Dictionary,
	registry: RefCounted
) -> void:
	var encountered_by_key: Dictionary = {}
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if (
				str(node.get("content_state", ""))
					!= TowerAscentBossRegistry.CONTENT_GENERATED
				or str(node.get("kind", "")) not in TowerAscentBossRegistry.COMBAT_NODE_KINDS
				or bool(node.get("standin_duplicate_gate", false))
			):
				continue
			var encounter_key := str(node.get("boss_encounter_key", ""))
			if encounter_key.is_empty():
				encounter_key = str(registry.call(
					"canonical_encounter_key",
					node.get("standin", {})
				))
			_expect(
				not encountered_by_key.has(encounter_key),
				"seed %d canonical encounter key %s must not repeat"
				% [map_seed, encounter_key]
			)
			encountered_by_key[encounter_key] = str(node.get("id", ""))


func _verify_forced_passage_negative_leg() -> void:
	_expect(not _forced_fixture.is_empty(), "forced-passage fixture source must exist")
	if _forced_fixture.is_empty():
		return
	var forced_node_id := ""
	for phase_variant in _forced_fixture.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if (
				bool(node.get("gatekeeper", false))
				and int(node.get("segment_floor", 0)) == 2
			):
				node["optional_extra_boss"] = true
				forced_node_id = str(node.get("id", ""))
				break
		if not forced_node_id.is_empty():
			break
	var report := TowerAscentBossRegistry.new().analyze_optional_extra_boss_bypass(
		_forced_fixture,
		TowerAuditionBuildConfig.get_clear_floor()
	)
	_expect(not forced_node_id.is_empty(), "forced-passage fixture must mark a floor-2 gate")
	_expect(
		not bool(report.get("valid", true)),
		"marking a forced gate as optional must be RED"
	)
	_expect(
		_issue_contains(report, "forced_optional_extra_boss=%s" % forced_node_id),
		"forced-passage RED leg must name the unavoidable node"
	)
	_negative_leg_count += 1


func _optional_nodes_for_floor(graph: Dictionary, floor_number: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if (
				bool(node.get("optional_extra_boss", false))
				and int(node.get("segment_floor", 0)) == floor_number
			):
				result.append(node)
	return result


func _count_optional_nodes_for_floor(graph: Dictionary, floor_number: int) -> int:
	return _optional_nodes_for_floor(graph, floor_number).size()


func _count_floor_one_generated_bosses(graph: Dictionary) -> int:
	var result := 0
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if (
				int(node.get("segment_floor", 0)) == 1
				and str(node.get("content_state", ""))
					== TowerAscentBossRegistry.CONTENT_GENERATED
				and str(node.get("kind", "")) in TowerAscentBossRegistry.COMBAT_NODE_KINDS
			):
				result += 1
	return result


func _rate_by_floor(counts: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for floor_variant in counts.keys():
		var floor_number := int(floor_variant)
		result[floor_number] = _safe_ratio(
			int(counts.get(floor_number, 0)),
			SAMPLE_SEED_COUNT
		)
	return result


func _issue_contains(report: Dictionary, fragment: String) -> bool:
	for issue_variant in report.get("issues", []):
		if str(issue_variant).contains(fragment):
			return true
	return false


func _safe_ratio(numerator: int, denominator: int) -> float:
	return 0.0 if denominator <= 0 else float(numerator) / float(denominator)


func _expect(condition: bool, message: String) -> void:
	if not condition and _failures.size() < 32 and not _failures.has(message):
		_failures.append(message)
