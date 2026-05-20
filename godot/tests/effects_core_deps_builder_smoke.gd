extends SceneTree

const EffectsCoreDepsBuilder := preload("res://scripts/core/battle_update_effects_core_deps_builder.gd")
const EffectsDepsBuilder := preload("res://scripts/core/battle_update_effects_deps_builder.gd")
const BattleUpdateEffectsContext := preload("res://scripts/core/battle_update_effects_context.gd")

var _failures: Array[String] = []


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init() -> void:
		for key in [
			"battle_feedback_state",
			"game_audio",
			"match_score_state",
			"scoreboard_state",
			"orb_hud_state",
			"actor_animation_state",
			"impact_effects",
			"player_movement_state",
			"active_item_runtime",
			"runtime_perk_state",
			"runtime_perk_catalog",
		]:
			instances[key] = RefCounted.new()

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	var registry := FakeRegistry.new()
	var builder: Object = EffectsCoreDepsBuilder.new()

	_verify_core_deps(builder.build_deps(registry), registry, "direct builder")
	_verify_core_deps(EffectsDepsBuilder.new().build_deps(registry, 1), registry, "effects deps builder")
	_verify_core_deps(BattleUpdateEffectsContext.new().build_deps(registry, 1), registry, "effects context facade")

	var null_deps: Dictionary = builder.build_deps(null)
	for key in [
		"feedback",
		"audio",
		"score_state",
		"scoreboard_state",
		"orb_hud_state",
		"animation_state",
		"impact_effects",
		"movement_state",
		"active_item_runtime",
		"runtime_perk_state",
		"runtime_perk_catalog",
	]:
		_expect(null_deps.get(key, RefCounted.new()) == null, "null registry should produce null %s" % key)

	if _failures.is_empty():
		print("effects_core_deps_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_core_deps(deps: Dictionary, registry: FakeRegistry, source: String) -> void:
	var dep_to_registry_key := {
		"feedback": "battle_feedback_state",
		"audio": "game_audio",
		"score_state": "match_score_state",
		"scoreboard_state": "scoreboard_state",
		"orb_hud_state": "orb_hud_state",
		"animation_state": "actor_animation_state",
		"impact_effects": "impact_effects",
		"movement_state": "player_movement_state",
		"active_item_runtime": "active_item_runtime",
		"runtime_perk_state": "runtime_perk_state",
		"runtime_perk_catalog": "runtime_perk_catalog",
	}
	for dep_key in dep_to_registry_key.keys():
		var registry_key: String = str(dep_to_registry_key[dep_key])
		_expect(
			deps.get(dep_key, null) == registry.instances[registry_key],
			"%s should include %s from %s" % [source, dep_key, registry_key]
		)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
