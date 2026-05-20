extends SceneTree

const BattleSceneBossHealthFlow := preload("res://scripts/core/battle_scene_boss_health_flow.gd")
const BattleSceneBootstrap := preload("res://scripts/core/battle_scene_bootstrap.gd")

var _failures: Array[String] = []
var _score_events: Array[String] = []


class FakeOwner:
	extends RefCounted

	var data: Dictionary = {
		"current_stage": 11,
		"boss_max_health": 0,
		"boss_current_health": 0,
		"boss_health_damage_units": 0,
		"boss_last_damage_source": "",
		"boss_defeated_by_health": false,
	}

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		data[str(property)] = value
		return true


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_stage_health_configuration()
	_verify_non_health_stage_clears_health_state()
	_verify_defeat_score_event_is_consumed_once()
	_verify_bootstrap_includes_stage_health_snapshot()

	if _failures.is_empty():
		print("boss_health_flow_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage_health_configuration() -> void:
	var flow := BattleSceneBossHealthFlow.new()
	var owner := FakeOwner.new()
	owner.set("current_stage", 11)
	owner.set("boss_current_health", 2)
	owner.set("boss_health_damage_units", 13)
	owner.set("boss_last_damage_source", "commando_firearm_bazooka")
	owner.set("boss_defeated_by_health", true)

	flow.reset_round_health(owner)
	_expect(int(owner.data.get("boss_max_health", 0)) == 15, "stage 11 should configure the Python-parity 15 HP boss")
	_expect(int(owner.data.get("boss_current_health", 0)) == 15, "stage 11 round reset should refill boss health")
	_expect(int(owner.data.get("boss_health_damage_units", -1)) == 0, "stage 11 round reset should clear accumulated damage")
	_expect(str(owner.data.get("boss_last_damage_source", "x")) == "", "stage 11 round reset should clear damage source")
	_expect(not bool(owner.data.get("boss_defeated_by_health", true)), "stage 11 round reset should clear pending defeat")


func _verify_non_health_stage_clears_health_state() -> void:
	var flow := BattleSceneBossHealthFlow.new()
	var owner := FakeOwner.new()
	owner.set("current_stage", 1)
	owner.set("boss_max_health", 15)
	owner.set("boss_current_health", 4)
	owner.set("boss_health_damage_units", 11)
	owner.set("boss_defeated_by_health", true)

	flow.reset_round_health(owner)
	_expect(int(owner.data.get("boss_max_health", -1)) == 0, "non-health stage should clear boss max health")
	_expect(int(owner.data.get("boss_current_health", -1)) == 0, "non-health stage should hide boss health")
	_expect(int(owner.data.get("boss_health_damage_units", -1)) == 0, "non-health stage should clear damage units")
	_expect(not bool(owner.data.get("boss_defeated_by_health", true)), "non-health stage should clear pending defeat")


func _verify_defeat_score_event_is_consumed_once() -> void:
	var flow := BattleSceneBossHealthFlow.new()
	var owner := FakeOwner.new()
	owner.set("boss_max_health", 15)
	owner.set("boss_current_health", 0)
	owner.set("boss_defeated_by_health", true)
	_score_events.clear()

	_expect(flow.consume_defeat_score_event(owner, Callable(self, "_record_score_event")), "pending health defeat should score for the player")
	_expect(_score_events == ["player"], "health defeat should emit a player score event")
	_expect(not bool(owner.data.get("boss_defeated_by_health", true)), "health defeat should be consumed after score event")
	_expect(not flow.consume_defeat_score_event(owner, Callable(self, "_record_score_event")), "consumed defeat should not score twice")
	_expect(_score_events.size() == 1, "consumed health defeat should remain one-shot")


func _verify_bootstrap_includes_stage_health_snapshot() -> void:
	var flow := BattleSceneBossHealthFlow.new()
	var bootstrap := BattleSceneBootstrap.new()
	var snapshot: Dictionary = bootstrap.initialize(null, {
		"current_stage": 16,
		"play_stage_bgm_on_initialize": false,
	}, FakeRegistry.new({"battle_scene_boss_health_flow": flow}))
	_expect(int(snapshot.get("boss_max_health", 0)) == 15, "bootstrap should publish health-stage max HP")
	_expect(int(snapshot.get("boss_current_health", 0)) == 15, "bootstrap should publish health-stage current HP")

	var normal_snapshot: Dictionary = bootstrap.initialize(null, {
		"current_stage": 2,
		"play_stage_bgm_on_initialize": false,
	}, FakeRegistry.new({"battle_scene_boss_health_flow": flow}))
	_expect(int(normal_snapshot.get("boss_max_health", -1)) == 0, "bootstrap should clear max HP on normal score stages")
	_expect(int(normal_snapshot.get("boss_current_health", -1)) == 0, "bootstrap should clear current HP on normal score stages")


func _record_score_event(scoring_side: String) -> void:
	_score_events.append(scoring_side)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
