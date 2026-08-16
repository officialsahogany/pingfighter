extends SceneTree

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


func _init() -> void:
	_verify_canonical_floor_pools_and_standins()
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
