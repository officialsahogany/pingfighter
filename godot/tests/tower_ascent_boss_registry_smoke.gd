extends SceneTree

const BattleSceneSelectionStartupLifecycle := preload(
	"res://scripts/core/battle_scene_selection_startup_lifecycle.gd"
)
const GameSelectionState := preload(
	"res://scripts/core/game_selection_state.gd"
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

var _failures: Array[String] = []


class FakeBattleOwner:
	extends RefCounted
	var selection_state: Object
	var current_stage := 1
	var stage1_boss_variant := "dalji"
	var stage_boss_variant := ""
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var selected_character_id := ""
	var selected_runtime_character_id := ""
	var selected_character_type := ""
	var selected_character_name := ""
	var ai_mode := ""
	var chance_gems_count := 0
	var chance_gems_max := 3

	func _init(value: Object) -> void:
		selection_state = value

	func get_node_or_null(path: NodePath) -> Object:
		return selection_state if str(path) == "/root/GameSelectionState" else null


func _init() -> void:
	_verify_canonical_floor_pools_and_standins()
	_verify_ported_slots_route_into_battle_selection()
	_verify_generated_boss_nodes_are_registry_driven()
	_verify_four_kings_are_locked_metadata_only()
	_verify_flag_off_preserves_legacy()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_boss_registry_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_canonical_floor_pools_and_standins() -> void:
	var registry := TowerAscentBossRegistry.new()
	var expected_counts := [3, 3, 3, 3, 3, 3, 3, 3, 1, 3, 4, 1]
	for floor_number in range(1, 13):
		var slots := registry.get_floor_slots(floor_number)
		_expect(slots.size() == expected_counts[floor_number - 1], "floor %d boss pool must match the canonical roster" % floor_number)
		for slot in slots:
			var slot_id := str(slot.get("slot_id", ""))
			var standin := registry.get_standin(slot_id)
			_expect(not slot_id.is_empty(), "every boss registry entry must own a stable slot id")
			_expect(int(standin.get("stage", 0)) in range(1, 9), "every slot must resolve to an existing Godot stand-in stage")
			_expect(not str(standin.get("boss_id", "")).is_empty(), "every slot must resolve to an existing Godot boss compatibility id")
			if str(slot.get("status", "")) == TowerAscentBossRegistry.STATUS_SHELL:
				_expect(str(slot.get("display_name", "")) == "임시 보스", "shell slots must not invent boss names")


func _verify_ported_slots_route_into_battle_selection() -> void:
	var expected_routes := {
		"floor_02_molewang": {"stage": 2, "boss_id": "cheongringwi", "variant": "molewang"},
		"floor_02_arachne": {"stage": 2, "boss_id": "cheongringwi", "variant": "arachne"},
		"floor_03_teddy_bear": {"stage": 3, "boss_id": "yeonmyo", "variant": "teddy_bear"},
		"floor_03_alice": {"stage": 3, "boss_id": "yeonmyo", "variant": "alice"},
	}
	var registry := TowerAscentBossRegistry.new()
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	for slot_id in expected_routes:
		var expected: Dictionary = expected_routes[slot_id]
		var slot := registry.get_slot(slot_id)
		var route := registry.get_standin(slot_id)
		_expect(str(slot.get("slot_id", "")) == slot_id, "%s must preserve its stable snapshot slot id" % slot_id)
		_expect(str(slot.get("status", "")) == TowerAscentBossRegistry.STATUS_PORTED, "%s must be marked ported" % slot_id)
		_expect(route == expected, "%s must resolve to its shipped battle variant" % slot_id)
		var selection_state: Object = GameSelectionState.new()
		selection_state.set_stage(
			int(route.get("stage", 0)),
			"dalji",
			false,
			str(route.get("variant", ""))
		)
		var owner := FakeBattleOwner.new(selection_state)
		BattleSceneSelectionStartupLifecycle.new().apply_selection_state(owner)
		_expect(owner.current_stage == int(expected.get("stage", 0)), "%s must enter the mapped battle stage with the tower flag ON" % slot_id)
		_expect(owner.stage_boss_variant == str(expected.get("variant", "")), "%s must enter the mapped boss variant with the tower flag ON" % slot_id)
		owner.selection_state = null
		selection_state.free()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()


func _verify_generated_boss_nodes_are_registry_driven() -> void:
	var generator := TowerAscentMapGenerator.new()
	var first: Dictionary = generator.generate_tower(45190)
	var second: Dictionary = generator.generate_tower(45190)
	_expect(var_to_bytes(first) == var_to_bytes(second), "boss slot assignment must remain seed deterministic")
	var phase: Dictionary = first.phases[0]
	for node_variant in phase.nodes:
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		if str(node.get("kind", "")) not in ["boss", "combat", "enraged"]:
			continue
		_expect(not str(node.get("boss_slot_id", "")).is_empty(), "every generated combat node must reference a registry slot")
		if int(node.get("floor", 0)) != 11:
			_expect(not (node.get("standin", {}) as Dictionary).is_empty(), "every generated boss slot must carry its stand-in mapping")


func _verify_four_kings_are_locked_metadata_only() -> void:
	var graph: Dictionary = TowerAscentMapGenerator.new().generate_tower(72)
	var floor_11_node: Dictionary = {}
	for node_variant in graph.phases[0].nodes:
		if node_variant is Dictionary and int((node_variant as Dictionary).get("floor", 0)) == 11 and str((node_variant as Dictionary).get("kind", "")) == "boss":
			floor_11_node = node_variant as Dictionary
			break
	_expect(floor_11_node.get("boss_sequence_slot_ids", []).size() == 4, "11th floor must register four sequential boss slots")
	_expect(floor_11_node.get("standin_sequence", []).size() == 4, "four-kings slots must each carry an existing stand-in")
	_expect(bool(floor_11_node.get("encounter_locked", false)), "11th-floor encounter execution must remain locked until its internal boundary contract exists")
	var source := FileAccess.get_file_as_string("res://scripts/tower_ascent/tower_ascent_boss_registry.gd")
	_expect(source.find("func update") < 0 and source.find("func advance") < 0, "boss registry must not implement a hidden four-fight runtime")


func _verify_flag_off_preserves_legacy() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	_expect(not TowerAscentFlowOwner.new().begin_vertical_slice(null, Callable(), {"run_id": "boss-registry-off"}), "flag OFF must not consume boss registry data")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
