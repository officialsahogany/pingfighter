extends SceneTree

const TowerAscentBossRegistry := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_registry.gd"
)
const TowerAuditionBuildConfig := preload(
	"res://scripts/tower_ascent/tower_audition_build_config.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentMapGenerator := preload(
	"res://scripts/tower_ascent/tower_ascent_map_generator.gd"
)

var _failures: Array[String] = []
var _positive_configuration_count := 0
var _rendered_phase_count := 0
var _negative_leg_count := 0
var _configuration_summaries: Array[String] = []


func _init() -> void:
	_verify_configuration(false, 45190)
	_verify_configuration(true, 83521)
	_verify_render_band_floor_authority()
	_verify_modulo_reuse_negative_leg()
	_verify_segment_floor_mismatch_negative_leg()
	_verify_unlock_to_floor_twelve_negative_leg()
	TowerAuditionBuildConfig.debug_clear_enabled_override()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print(
			"tower_ascent_boss_floor_contract_smoke: configurations=%d rendered_phases=%d negative_legs=%d summaries=%s"
			% [
				_positive_configuration_count,
				_rendered_phase_count,
				_negative_leg_count,
				str(_configuration_summaries),
			]
		)
		print("tower_ascent_boss_floor_contract_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_configuration(audition_enabled: bool, map_seed: int) -> void:
	TowerAuditionBuildConfig.debug_set_enabled(audition_enabled)
	var generator := TowerAscentMapGenerator.new()
	var first := generator.generate_tower(map_seed)
	var repeated := generator.generate_tower(map_seed)
	var mode_name := "audition" if audition_enabled else "standard"
	_expect(not first.is_empty(), "%s configuration must generate a graph" % mode_name)
	if first.is_empty():
		return
	_expect(
		generator.encode_graph(first) == generator.encode_graph(repeated),
		"%s boss normalization must remain byte deterministic" % mode_name
	)
	var active_clear_floor := TowerAuditionBuildConfig.get_clear_floor()
	var registry := TowerAscentBossRegistry.new()
	var contract := registry.analyze_visible_boss_contract(first)
	_expect(bool(contract.get("valid", false)), "%s visible boss contract must be GREEN: %s" % [mode_name, str(contract.get("issues", []))])
	_expect(
		int(contract.get("active_clear_floor", 0)) == active_clear_floor,
		"%s seal must derive active_clear_floor from graph metadata" % mode_name
	)
	var terminal_boss_count := 0
	var terminal_slot_id := ""
	var npc_fill_count := 0
	for phase_variant in first.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		var phase := phase_variant as Dictionary
		var node_by_id := _node_index(phase.get("nodes", []))
		for floor_variant in phase.get("floors", []):
			if not (floor_variant is Dictionary):
				continue
			for row_variant in (floor_variant as Dictionary).get("rows", []):
				if not (row_variant is Dictionary):
					continue
				var row := row_variant as Dictionary
				var row_segment_floor := int(row.get("segment_floor", 0))
				_expect(row_segment_floor > 0, "%s rows must declare segment_floor" % mode_name)
				for node_id_variant in row.get("node_ids", []):
					var node: Dictionary = node_by_id.get(str(node_id_variant), {})
					_expect(
						int(node.get("segment_floor", 0)) == row_segment_floor,
						"%s row and node must share segment_floor: %s" % [mode_name, str(node_id_variant)]
					)
		for node_variant in phase.get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			var segment_floor := int(node.get("segment_floor", 0))
			var content_state := str(node.get("content_state", ""))
			if content_state == TowerAscentBossRegistry.CONTENT_REGISTRY_ONLY:
				_expect(segment_floor > active_clear_floor, "%s registry_only nodes must stay above active_clear_floor" % mode_name)
			if str(node.get("boss_assignment_state", "")) == "npc_fill":
				npc_fill_count += 1
				_expect(str(node.get("kind", "")) in TowerAscentMapGenerator.NONCOMBAT_NODE_KINDS, "%s exhausted boss lanes must normalize to NPCs" % mode_name)
				_expect(str(node.get("boss_slot_id", "")).is_empty(), "%s NPC fills must not retain a boss slot" % mode_name)
			if (
				content_state == TowerAscentBossRegistry.CONTENT_GENERATED
				and segment_floor == 1
				and str(node.get("kind", "")) in TowerAscentBossRegistry.COMBAT_NODE_KINDS
			):
				var standin: Dictionary = node.get("standin", {})
				_expect(int(standin.get("stage", 0)) == 1, "%s floor-1 combat may only use Dalji, Gaksital, or Podo" % mode_name)
			if (
				content_state == TowerAscentBossRegistry.CONTENT_GENERATED
				and segment_floor == active_clear_floor
				and bool(node.get("floor_boundary", false))
			):
				_expect(str(node.get("kind", "")) == "boss", "%s reachable terminal must never be replaced by an NPC" % mode_name)
				terminal_boss_count += 1
				terminal_slot_id = str(node.get("boss_slot_id", ""))
	_expect(terminal_boss_count == 1, "%s must retain exactly one reachable terminal boss" % mode_name)
	_expect(npc_fill_count > 0, "%s must exercise deterministic NPC normalization" % mode_name)
	if audition_enabled:
		var human_phase := first.get("phases", [])[0] as Dictionary
		for floor_number in range(4, active_clear_floor + 1):
			_expect(registry.get_generation_slots(floor_number).size() == 1, "audition floor %d generation pool must contain only its ported boss" % floor_number)
			var floor_data := _find_floor(human_phase.get("floors", []), floor_number)
			var gate_row: Dictionary = (floor_data.get("rows", []) as Array)[-1]
			var gate_width := (gate_row.get("node_ids", []) as Array).size()
			_expect(
				gate_width == 1 if floor_number == active_clear_floor else gate_width >= 2,
				"audition floor %d lane width must be topology-owned despite its one-slot boss pool" % floor_number
			)
	_configuration_summaries.append(
		"%s:clear=%d:visible=%d:unique=%d:npc_fill=%d:terminal=%s"
		% [
			mode_name,
			active_clear_floor,
			int(contract.get("visible_encounter_count", 0)),
			int(contract.get("unique_encounter_count", 0)),
			npc_fill_count,
			terminal_slot_id,
		]
	)
	_positive_configuration_count += 1


func _verify_render_band_floor_authority() -> void:
	TowerAuditionBuildConfig.debug_set_enabled(false)
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {"run_id": "boss-floor-band", "map_seed": 45190}), "production flow must begin for floor-band verification")
	if not flow.is_active():
		return
	var renderer := TowerAscentFlowRenderer.new()
	for phase_index in range(2):
		if phase_index > 0:
			_expect(bool(flow.call("_activate_graph_phase", phase_index)), "floor-band fixture must activate phase %d" % phase_index)
		var model := renderer.build_fullscreen_map_model(
			flow,
			Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
		)
		var floor_bands: Array = model.get("floor_bands", [])
		_expect(not floor_bands.is_empty(), "phase %d must expose rendered floor bands" % phase_index)
		var tile_floors: Dictionary = {}
		for tile_variant in (model.get("scroll_background", {}) as Dictionary).get("tiles", []):
			if tile_variant is Dictionary:
				tile_floors[int((tile_variant as Dictionary).get("floor", 0))] = true
		for node_variant in model.get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			var expected_floor := int(node.get("segment_floor", 0))
			var world_position: Vector2 = node.get("world_position", Vector2.ZERO)
			var rendered_floor := renderer.resolve_segment_floor_for_world_y(
				floor_bands,
				world_position.y
			)
			_expect(rendered_floor == expected_floor, "node y band and segment_floor must agree: %s expected=%d rendered=%d" % [str(node.get("id", "")), expected_floor, rendered_floor])
			_expect(tile_floors.has(rendered_floor), "node segment floor must own a rendered background tile: %s" % str(node.get("id", "")))
			var slot_id := str(node.get("boss_slot_id", ""))
			if slot_id.is_empty() or slot_id == TowerAscentBossRegistry.FOUR_KINGS_GROUP_SLOT_ID:
				continue
			var slot := TowerAscentBossRegistry.new().get_slot(slot_id)
			_expect(int(slot.get("slot_floor", 0)) == rendered_floor, "boss slot floor must equal the node's rendered band: %s" % str(node.get("id", "")))
		_rendered_phase_count += 1


func _verify_modulo_reuse_negative_leg() -> void:
	var registry := TowerAscentBossRegistry.new()
	var standin := registry.get_standin("floor_01_dalji")
	var fixture := {
		"phases": [{
			"standard_clear_floor": 1,
			"nodes": [
				{
					"id": "modulo_lane_1",
					"floor": 1,
					"segment_floor": 1,
					"kind": "boss",
					"content_state": "generated",
					"boss_slot_id": "floor_01_dalji",
					"standin": standin,
				},
				{
					"id": "modulo_lane_2",
					"floor": 1,
					"segment_floor": 1,
					"kind": "boss",
					"content_state": "generated",
					"boss_slot_id": "floor_01_dalji",
					"standin": standin,
				},
			],
		}],
	}
	var report := registry.analyze_visible_boss_contract(fixture)
	_expect(not bool(report.get("valid", true)), "restored modulo slot reuse fixture must be RED")
	_expect(_has_issue(report, "duplicate_encounter_key="), "modulo negative leg must identify the duplicate encounter key")
	_negative_leg_count += 1


func _verify_segment_floor_mismatch_negative_leg() -> void:
	TowerAuditionBuildConfig.debug_set_enabled(false)
	var fixture := TowerAscentMapGenerator.new().generate_tower(45190).duplicate(true)
	var mutated := false
	for phase_variant in fixture.get("phases", []):
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			var node := node_variant as Dictionary
			if (
				str(node.get("content_state", "")) == "generated"
				and str(node.get("boss_slot_id", "")).begins_with("floor_01_")
			):
				node["segment_floor"] = 2
				mutated = true
				break
		if mutated:
			break
	var report := TowerAscentBossRegistry.new().analyze_visible_boss_contract(fixture)
	_expect(mutated and not bool(report.get("valid", true)), "wrong segment_floor fixture must be RED")
	_expect(_has_issue(report, "slot_floor_mismatch="), "floor mismatch negative leg must identify slot and segment disagreement")
	_negative_leg_count += 1


func _verify_unlock_to_floor_twelve_negative_leg() -> void:
	TowerAuditionBuildConfig.debug_set_enabled(false)
	var fixture := TowerAscentMapGenerator.new().generate_tower(45190).duplicate(true)
	for phase_variant in fixture.get("phases", []):
		var phase := phase_variant as Dictionary
		phase["standard_clear_floor"] = 12
		for node_variant in phase.get("nodes", []):
			var node := node_variant as Dictionary
			node["content_state"] = "generated"
			node["route_locked"] = false
	var report := TowerAscentBossRegistry.new().analyze_visible_boss_contract(fixture)
	_expect(int(report.get("active_clear_floor", 0)) == 12, "unlock fixture must drive the seal from active_clear_floor metadata")
	_expect(not bool(report.get("valid", true)), "unlocking the current floor-11/12 stand-ins must be RED")
	_expect(_has_issue(report, "duplicate_encounter_key="), "unlock negative leg must warn that real new boss content is required")
	_negative_leg_count += 1


func _node_index(nodes: Array) -> Dictionary:
	var result: Dictionary = {}
	for node_variant in nodes:
		if node_variant is Dictionary:
			result[str((node_variant as Dictionary).get("id", ""))] = node_variant
	return result


func _find_floor(floors: Array, floor_number: int) -> Dictionary:
	for floor_variant in floors:
		if floor_variant is Dictionary and int((floor_variant as Dictionary).get("floor", 0)) == floor_number:
			return floor_variant as Dictionary
	return {}


func _has_issue(report: Dictionary, prefix: String) -> bool:
	for issue_variant in report.get("issues", []):
		if str(issue_variant).begins_with(prefix):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
