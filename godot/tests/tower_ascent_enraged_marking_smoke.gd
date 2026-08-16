extends SceneTree

const TowerAscentChestContextBuilder := preload(
	"res://scripts/tower_ascent/tower_ascent_chest_context_builder.gd"
)
const TowerAscentChestContract := preload(
	"res://scripts/tower_ascent/tower_ascent_chest_contract.gd"
)
const TowerAscentEnragedPolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_enraged_policy.gd"
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


class FakeOwner:
	extends RefCounted

	var tower_floor := 6
	var tower_node_is_elite := true
	var tower_node_is_enraged := true
	var tower_node_is_gatekeeper := false


class FakeRegistry:
	extends RefCounted

	var flow_owner: Object

	func _init(new_flow_owner: Object = null) -> void:
		flow_owner = new_flow_owner

	func get_instance(key: String) -> Variant:
		return flow_owner if key == "tower_ascent_flow_owner" else null

	func get_cached_instance(key: String) -> Variant:
		return get_instance(key)


func _init() -> void:
	_verify_generation_marks_each_opportunity_once()
	_verify_fixed_nodes_and_forced_probability_legs()
	_verify_chest_context_uses_generated_risk()
	_verify_flag_off_preserves_owner_fallback()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_enraged_marking_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_generation_marks_each_opportunity_once() -> void:
	var generator := TowerAscentMapGenerator.new()
	var first: Dictionary = generator.generate_tower(80155)
	var second: Dictionary = generator.generate_tower(80155)
	_expect(var_to_bytes(first) == var_to_bytes(second), "enraged marking must remain map-seed deterministic")
	for node_variant in first.phases[0].nodes:
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		var node_kind := str(node.get("kind", ""))
		if node_kind not in TowerAscentEnragedPolicy.COMBAT_NODE_KINDS:
			continue
		if node_kind == "enraged":
			_expect(bool(node.get("enraged", false)), "fixed enraged nodes must always be marked")
			_expect(int(node.get("enraged_roll_count", -1)) == 0, "fixed enraged nodes must not consume the normal boss opportunity roll")
		else:
			_expect(int(node.get("enraged_roll_count", 0)) == 1, "each normal boss node must roll exactly once during generation")
			_expect(float(node.get("enraged_roll", -1.0)) >= 0.0 and float(node.get("enraged_roll", 2.0)) < 1.0, "normal boss roll evidence must be retained")


func _verify_fixed_nodes_and_forced_probability_legs() -> void:
	var base: Dictionary = TowerAscentMapGenerator.new().generate_tower(901)
	var policy := TowerAscentEnragedPolicy.new()
	var zero: Dictionary = policy.decorate_graph(base, 901, 0.0)
	var full: Dictionary = policy.decorate_graph(base, 901, 1.0)
	for node_variant in zero.phases[0].nodes:
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		if str(node.get("kind", "")) in ["boss", "combat"]:
			_expect(not bool(node.get("enraged", false)), "0% must keep normal boss nodes unmarked")
		elif str(node.get("kind", "")) == "enraged":
			_expect(bool(node.get("enraged", false)), "fixed enraged nodes must survive the 0% normal-boss leg")
	for node_variant in full.phases[0].nodes:
		if node_variant is Dictionary and str((node_variant as Dictionary).get("kind", "")) in TowerAscentEnragedPolicy.COMBAT_NODE_KINDS:
			_expect(bool((node_variant as Dictionary).get("enraged", false)), "100% must mark every combat opportunity")


func _verify_chest_context_uses_generated_risk() -> void:
	var generator := TowerAscentMapGenerator.new()
	var enraged_seed := _find_entry_seed(generator, true)
	var normal_seed := _find_entry_seed(generator, false)
	_expect(enraged_seed >= 0 and normal_seed >= 0, "risk integration fixture must find enraged and normal entry bosses")
	if enraged_seed < 0 or normal_seed < 0:
		return
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var enraged_flow := TowerAscentFlowOwner.new()
	var normal_flow := TowerAscentFlowOwner.new()
	_expect(enraged_flow.prepare_vertical_slice_combat(null, {"run_id": "enraged-risk", "map_seed": enraged_seed}), "enraged risk flow must prepare before victory loot")
	_expect(normal_flow.prepare_vertical_slice_combat(null, {"run_id": "normal-risk", "map_seed": normal_seed}), "normal risk flow must prepare before victory loot")
	var builder := TowerAscentChestContextBuilder.new()
	var enraged_context := builder.build(FakeOwner.new(), FakeRegistry.new(enraged_flow), 1)
	var normal_context := builder.build(FakeOwner.new(), FakeRegistry.new(normal_flow), 1)
	_expect(bool(enraged_context.is_enraged), "generated enraged marker must reach the Phase A chest context")
	_expect(not bool(normal_context.is_enraged), "unmarked generated boss must remain normal in chest context")
	_expect(bool(enraged_context.is_gatekeeper) and int(enraged_context.floor) == 1, "generated floor-boundary risk must reach chest context")
	var contract := TowerAscentChestContract.new()
	var enraged_weights := contract.get_chest_weights(enraged_context)
	var normal_weights := contract.get_chest_weights(normal_context)
	_expect(float(enraged_weights[TowerAscentChestContract.CHEST_NORMAL]) < float(normal_weights[TowerAscentChestContract.CHEST_NORMAL]), "enraged risk must shift chest weight rather than quantity")


func _verify_flag_off_preserves_owner_fallback() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	var context := TowerAscentChestContextBuilder.new().build(FakeOwner.new(), FakeRegistry.new(), 1)
	_expect(int(context.floor) == 6 and bool(context.is_elite) and bool(context.is_enraged), "flag OFF must preserve the existing owner-property chest context")


func _find_entry_seed(generator: Object, enraged: bool) -> int:
	for map_seed in range(0, 4096):
		var graph: Dictionary = generator.generate_tower(map_seed)
		var phase: Dictionary = graph.phases[0]
		var entry_node := _find_node(phase.nodes, str(phase.entry_node_id))
		if bool(entry_node.get("enraged", false)) == enraged:
			return map_seed
	return -1


func _find_node(nodes: Array, node_id: String) -> Dictionary:
	for node_variant in nodes:
		if node_variant is Dictionary and str((node_variant as Dictionary).get("id", "")) == node_id:
			return node_variant as Dictionary
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
