extends SceneTree

const TowerAuditionBuildConfig := preload(
	"res://scripts/tower_ascent/tower_audition_build_config.gd"
)
const TowerAscentBossRegistry := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_registry.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentMapGenerator := preload(
	"res://scripts/tower_ascent/tower_ascent_map_generator.gd"
)
const BattleSceneSelectionStartupLifecycle := preload(
	"res://scripts/core/battle_scene_selection_startup_lifecycle.gd"
)
const GameSelectionState := preload(
	"res://scripts/core/game_selection_state.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	_verify_export_default_gate()
	_verify_audition_graph_and_linear_floors()
	_verify_floor_one_choice_row_and_derived_routes()
	_verify_seeded_ported_boss_pools_and_startup()
	_verify_selection_state_owns_the_run_seed()
	_verify_standard_reverse_leg()
	_verify_standard_clear_reuses_existing_owner()
	TowerAuditionBuildConfig.debug_clear_enabled_override()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_audition_build_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_export_default_gate() -> void:
	TowerAuditionBuildConfig.debug_clear_enabled_override()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	var had_environment_value := OS.has_environment(
		TowerAscentFeatureFlags.VERTICAL_SLICE_ENV_KEY
	)
	var previous_environment_value := OS.get_environment(
		TowerAscentFeatureFlags.VERTICAL_SLICE_ENV_KEY
	)
	OS.unset_environment(TowerAscentFeatureFlags.VERTICAL_SLICE_ENV_KEY)
	_expect(
		TowerAscentFeatureFlags.is_vertical_slice_enabled(),
		"the production flag path must enable tower mode without a launcher environment"
	)
	OS.set_environment(TowerAscentFeatureFlags.VERTICAL_SLICE_ENV_KEY, "0")
	_expect(
		not TowerAscentFeatureFlags.is_vertical_slice_enabled(),
		"the production flag path must retain an explicit legacy-campaign OFF route"
	)
	if had_environment_value:
		OS.set_environment(
			TowerAscentFeatureFlags.VERTICAL_SLICE_ENV_KEY,
			previous_environment_value
		)
	else:
		OS.unset_environment(TowerAscentFeatureFlags.VERTICAL_SLICE_ENV_KEY)
	_expect(
		TowerAscentFeatureFlags.resolve_vertical_slice_enabled("", true),
		"audition-tagged export must default to tower mode"
	)
	_expect(
		TowerAscentFeatureFlags.resolve_vertical_slice_enabled("", false),
		"main Godot development execution must default to tower mode"
	)
	_expect(
		not TowerAscentFeatureFlags.resolve_vertical_slice_enabled("0", true),
		"explicit environment OFF must override the audition export default"
	)
	_expect(
		not TowerAscentFeatureFlags.resolve_vertical_slice_enabled("off", false),
		"explicit environment OFF must retain the legacy-campaign QA route"
	)
	_expect(
		TowerAscentFeatureFlags.resolve_vertical_slice_enabled("1", false),
		"explicit environment ON must remain available"
	)


func _verify_audition_graph_and_linear_floors() -> void:
	TowerAuditionBuildConfig.debug_set_enabled(true)
	var graph := TowerAscentMapGenerator.new().generate_tower(45190)
	_expect(graph.phases.size() == 2, "audition graph must retain a locked second phase")
	if graph.phases.size() != 2:
		return
	var active_phase: Dictionary = graph.phases[0]
	var locked_phase: Dictionary = graph.phases[1]
	_expect(active_phase.floors.size() == 7, "audition active map must stop at floor 7")
	_expect(locked_phase.floors.size() == 5, "floors 8-12 must remain locked metadata")
	_expect(active_phase.get("locked_phase_hints", []).is_empty(), "audition map must not advertise unfinished upper content")
	for node_variant in active_phase.nodes:
		var node := node_variant as Dictionary
		_expect(int(node.get("floor", 0)) <= 7, "active audition map must not expose floor 8+")
		var floor_number := int(node.get("floor", 0))
		if floor_number not in TowerAuditionBuildConfig.TEMP_AUDITION_LINEAR_FLOORS:
			continue
		if str(node.get("kind", "")) in TowerAscentMapGenerator.COMBAT_NODE_KINDS:
			_expect(
				str(node.get("boss_port_status", "")) == TowerAscentBossRegistry.STATUS_PORTED,
				"audition floor %d combat must use only its ported boss" % floor_number
			)
			_expect(not bool(node.get("standin", {}).is_empty()), "linear-floor combat must retain a routable encounter")
		else:
			_expect(
				str(node.get("kind", "")) in TowerAscentMapGenerator.NONCOMBAT_NODE_KINDS,
				"linear-floor optional rows must be noncombat"
			)
	for node_variant in locked_phase.nodes:
		var node := node_variant as Dictionary
		_expect(int(node.get("floor", 0)) >= 8, "locked phase must begin at floor 8")
		_expect(bool(node.get("route_locked", false)), "every floor 8+ node must be route locked")


func _verify_floor_one_choice_row_and_derived_routes() -> void:
	TowerAuditionBuildConfig.debug_set_enabled(true)
	var graph := TowerAscentMapGenerator.new().generate_tower(45190)
	var phase: Dictionary = graph.phases[0]
	var floor_one: Dictionary = phase.floors[0]
	var rows: Array = floor_one.get("rows", [])
	_expect(rows.size() == 2, "audition floor 1 must contain its gatekeeper and one optional choice row")
	if rows.size() != 2:
		return
	var gate_row := rows[0] as Dictionary
	var choice_row := rows[1] as Dictionary
	var entry_id := str(phase.get("entry_node_id", ""))
	var candidates: Array = phase.get("initial_route_candidate_ids", [])
	_expect(bool(gate_row.get("gatekeeper", false)), "floor 1 must still enter through the actual opening boss")
	_expect(entry_id == str(gate_row.get("node_ids", [""])[0]), "entry id must be derived from the generated first row")
	_expect(candidates == choice_row.get("node_ids", []), "first route candidates must be the generated floor-1 choice row")
	_expect(candidates.size() == 2, "floor-1 choice row must retain the standard two candidates")
	for candidate_variant in candidates:
		_expect(
			_has_edge(phase, entry_id, str(candidate_variant)),
			"every advertised floor-1 candidate must be connected to the entry boss"
		)


func _verify_seeded_ported_boss_pools_and_startup() -> void:
	TowerAuditionBuildConfig.debug_set_enabled(true)
	var registry := TowerAscentBossRegistry.new()
	var generator := TowerAscentMapGenerator.new()
	var lifecycle := BattleSceneSelectionStartupLifecycle.new()
	var expected_by_floor := {
		1: ["floor_01_dalji", "floor_01_gaksital", "floor_01_podo"],
		2: ["floor_02_cheongringwi", "floor_02_molewang", "floor_02_arachne"],
		3: ["floor_03_yeonmyo", "floor_03_teddy_bear", "floor_03_alice"],
	}
	var seen_by_floor := {1: {}, 2: {}, 3: {}}
	var seed_by_stage_one_variant: Dictionary = {}
	for map_seed in range(1, 513):
		var graph := generator.generate_tower(map_seed)
		var phase: Dictionary = graph.phases[0]
		var node_by_id := _node_by_id(phase)
		for floor_number in range(1, 4):
			var gate_id := "floor_%02d_gatekeeper" % floor_number
			var gate: Dictionary = node_by_id.get(gate_id, {})
			var slot_id := str(gate.get("boss_slot_id", ""))
			seen_by_floor[floor_number][slot_id] = true
			_expect(
				str(gate.get("boss_port_status", "")) == TowerAscentBossRegistry.STATUS_PORTED,
				"audition floor %d gatekeeper must never resolve a shell" % floor_number
			)
			_expect(
				_sorted_strings(gate.get("boss_pool_slot_ids", [])) == _sorted_strings(expected_by_floor[floor_number]),
				"audition floor %d must expose its complete three-boss ported pool" % floor_number
			)
		var seeded_floor_one := registry.get_seeded_floor_slots(1, map_seed)
		if not seeded_floor_one.is_empty():
			var variant := str(seeded_floor_one[0].get("variant", "dalji"))
			seed_by_stage_one_variant[variant] = map_seed
			_expect(
				str(node_by_id.get(str(phase.get("entry_node_id", "")), {}).get("boss_slot_id", ""))
				== str(seeded_floor_one[0].get("slot_id", "")),
				"opening battle and generated entry node must share the map-seeded slot"
			)
		if seed_by_stage_one_variant.size() == 3 and _all_expected_slots_seen(seen_by_floor, expected_by_floor):
			break
	for floor_number in range(1, 4):
		_expect(
			_sorted_strings(seen_by_floor[floor_number].keys()) == _sorted_strings(expected_by_floor[floor_number]),
			"seed sweep must make all three floor-%d bosses appear" % floor_number
		)
	for variant in ["dalji", "gaksi", "podo"]:
		_expect(seed_by_stage_one_variant.has(variant), "three-seed audition proof must include %s" % variant)
		if seed_by_stage_one_variant.has(variant):
			var resolved := lifecycle.resolve_stage1_boss_variant({
				"tower_map_seed": int(seed_by_stage_one_variant[variant]),
				"stage1_boss_variant_explicit": false,
			}, 1)
			_expect(resolved == variant, "startup lifecycle must reproduce seeded opening variant %s" % variant)


func _verify_selection_state_owns_the_run_seed() -> void:
	TowerAuditionBuildConfig.debug_set_enabled(true)
	var selection := GameSelectionState.new()
	selection.request_tower_start_card_entry()
	_expect(int(selection.get_selection().get("tower_map_seed", 0)) > 0, "tower entry request must create the authoritative run seed before battle startup")
	selection.debug_set_tower_map_seed(730031)
	_expect(int(selection.get_selection().get("tower_map_seed", 0)) == 730031, "selection snapshot must carry the exact tower run seed")
	selection.free()


func _verify_standard_reverse_leg() -> void:
	TowerAuditionBuildConfig.debug_set_enabled(false)
	var graph := TowerAscentMapGenerator.new().generate_tower(45190)
	_expect(graph.phases[0].floors.size() == 9, "master gate OFF must restore the 9-floor standard phase")
	_expect(graph.phases[1].floors.size() == 3, "master gate OFF must restore the 10-12 locked phase")
	_expect(graph.phases[0].get("locked_phase_hints", []).size() == 1, "master gate OFF must restore the standard locked hint")
	_expect(graph.phases[0].floors[0].rows.size() == 1, "master gate OFF must remove the temporary floor-1 choice row")
	_expect(
		graph.phases[0].initial_route_candidate_ids == graph.phases[0].floors[1].rows[0].node_ids,
		"master gate OFF must derive and restore the floor-2 opening choices"
	)
	var registry := TowerAscentBossRegistry.new()
	for floor_number in TowerAuditionBuildConfig.TEMP_AUDITION_LINEAR_FLOORS:
		_expect(registry.get_floor_slots(floor_number).size() == 3, "master gate OFF must preserve every canonical floor pool")


func _verify_standard_clear_reuses_existing_owner() -> void:
	TowerAuditionBuildConfig.debug_set_enabled(true)
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var save_path := "user://tower_audition_build_smoke_%d.cfg" % Time.get_ticks_usec()
	var flow := TowerAscentFlowOwner.new()
	flow.set_record_store_path_for_tests(save_path)
	_expect(flow.begin_vertical_slice(null, Callable(), {"run_id": "audition-clear", "map_seed": 45190}), "audition flow must start")
	var result: Dictionary = flow.begin_floor_nine_resolution("audition-clear:terminal")
	_expect(bool(result.get("accepted", false)), "audition clear must enter the existing standard-clear judgment owner")
	_expect(int(flow.get_ending_state_snapshot().get("clear_floor", 0)) == 7, "standard-clear state must record floor 7 under the audition gate")
	_expect(int(flow.get_record_snapshot().get("highest_floor", 0)) == 7, "existing record store must commit the audition clear floor")
	var source := FileAccess.get_file_as_string("res://scripts/tower_ascent/tower_ascent_flow_runtime.gd")
	_expect(source.find("begin_floor_nine_resolution") >= 0, "live terminal branch must reuse the existing judgment path")
	_expect(source.find("begin_run_settlement") < 0, "live terminal branch must not invent a direct settlement path")
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _has_edge(phase: Dictionary, from_id: String, to_id: String) -> bool:
	for edge_variant in phase.get("edges", []):
		if not (edge_variant is Dictionary):
			continue
		var edge := edge_variant as Dictionary
		if str(edge.get("from", "")) == from_id and str(edge.get("to", "")) == to_id:
			return true
	return false


func _node_by_id(phase: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for node_variant in phase.get("nodes", []):
		if node_variant is Dictionary:
			var node := node_variant as Dictionary
			result[str(node.get("id", ""))] = node
	return result


func _sorted_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	result.sort()
	return result


func _all_expected_slots_seen(seen_by_floor: Dictionary, expected_by_floor: Dictionary) -> bool:
	for floor_number in range(1, 4):
		if _sorted_strings(seen_by_floor[floor_number].keys()) != _sorted_strings(expected_by_floor[floor_number]):
			return false
	return true
