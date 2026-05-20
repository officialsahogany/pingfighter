extends SceneTree

const MatchItemRuntimeDepsBuilder := preload("res://scripts/core/battle_update_match_item_runtime_deps_builder.gd")
const BattleUpdateMatchFlowContext := preload("res://scripts/core/battle_update_match_flow_context.gd")
const BattleUpdateMatchFlowDepsGroups := preload("res://scripts/core/battle_update_match_flow_deps_groups.gd")

var _failures: Array[String] = []


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init() -> void:
		for key in [
			"orb_hud_state",
			"active_item_hud_state",
			"active_item_runtime",
			"mythic_item_runtime",
			"treasure_hunt_runtime",
		]:
			instances[key] = RefCounted.new()

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	var registry := FakeRegistry.new()
	var builder: Object = MatchItemRuntimeDepsBuilder.new()

	_verify_item_deps(builder.build_deps(registry), registry, "direct builder")
	_verify_item_deps(BattleUpdateMatchFlowDepsGroups.new().build_item_runtime_deps(registry), registry, "deps groups facade")

	var match_flow_deps: Dictionary = BattleUpdateMatchFlowContext.new().build_deps(registry)
	_verify_item_deps(match_flow_deps, registry, "match flow context facade")

	var null_deps: Dictionary = builder.build_deps(null)
	for key in [
		"orb_hud_state",
		"active_hud_state",
		"active_item_runtime",
		"mythic_item_runtime",
		"treasure_hunt_runtime",
	]:
		_expect(null_deps.get(key, RefCounted.new()) == null, "null registry should produce null %s" % key)

	if _failures.is_empty():
		print("match_item_runtime_deps_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_item_deps(deps: Dictionary, registry: FakeRegistry, source: String) -> void:
	_expect(deps.get("orb_hud_state", null) == registry.instances["orb_hud_state"], "%s should include orb HUD state" % source)
	_expect(deps.get("active_hud_state", null) == registry.instances["active_item_hud_state"], "%s should include active-item HUD state" % source)
	_expect(deps.get("active_item_runtime", null) == registry.instances["active_item_runtime"], "%s should include active item runtime" % source)
	_expect(deps.get("mythic_item_runtime", null) == registry.instances["mythic_item_runtime"], "%s should include mythic item runtime" % source)
	_expect(deps.get("treasure_hunt_runtime", null) == registry.instances["treasure_hunt_runtime"], "%s should include treasure-hunt runtime" % source)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
