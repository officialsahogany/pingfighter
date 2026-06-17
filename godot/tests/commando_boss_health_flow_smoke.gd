extends SceneTree

const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleDrawPlayfieldSceneContext := preload("res://scripts/core/battle_draw_playfield_scene_context.gd")
const BattleSceneBossHealthFlow := preload("res://scripts/core/battle_scene_boss_health_flow.gd")
const BattleSceneMatchEventDriver := preload("res://scripts/core/battle_scene_match_event_driver.gd")
const BattleSceneUpdateCallbacks := preload("res://scripts/core/battle_scene_update_callbacks.gd")

var _failures: Array[String] = []
var _direct_score_calls: Array[String] = []


class FakeOwner:
	extends RefCounted

	var data: Dictionary = {
		"current_stage": 1,
		"selected_character_type": "soldier",
		"boss_max_health": 5,
		"boss_current_health": 5,
		"boss_health_damage_units": 0,
		"boss_last_damage_source": "",
		"boss_defeated_by_health": false,
		"player_pos": Vector2(302.0, 654.0),
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"player_paddle_scale": 1.0,
		"boss_pos": Vector2(330.0, 25.0),
		"ball_pos": Vector2(380.0, 350.0),
		"ball_vel": Vector2.ZERO,
		"battle_textures": {},
	}

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		data[str(property)] = value
		return true


class FakeEffectsDriver:
	extends RefCounted

	var trigger_once := true

	func update_effects(owner: Object, _registry: Object, _delta: float) -> void:
		if not trigger_once:
			return
		trigger_once = false
		owner.set("boss_current_health", 0)
		owner.set("boss_defeated_by_health", true)


class FakeMatchEventDriver:
	extends RefCounted

	var score_calls: Array[String] = []

	func handle_score_event(scoring_side: String, _owner: Object, _registry: Object) -> void:
		score_calls.append(scoring_side)


class FakeBallDriver:
	extends RefCounted

	var reset_calls := 0

	func reset_ball(_owner: Object, _registry: Object) -> void:
		reset_calls += 1


class FakeMatchFlowDriver:
	extends RefCounted

	var score_calls: Array[String] = []

	func handle_score_event(_registry: Object, scoring_side: String, reset_ball_callback: Callable, _current_stage: int = 1) -> void:
		score_calls.append(scoring_side)
		reset_ball_callback.call()


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_direct_health_flow_consumes_once()
	_verify_update_callbacks_route_health_defeat_to_score()
	_verify_score_reset_restores_round_health()
	_verify_health_context_reaches_actor_draw()

	if _failures.is_empty():
		print("commando_boss_health_flow_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_health_flow_consumes_once() -> void:
	var owner := FakeOwner.new()
	owner.data["boss_current_health"] = 0
	owner.data["boss_defeated_by_health"] = true
	var flow := BattleSceneBossHealthFlow.new()
	_expect(flow.consume_defeat_score_event(owner, Callable(self, "_record_direct_score")), "health defeat should be consumed as a score event")
	_expect(_direct_score_calls == ["player"], "health defeat should score for the player")
	_expect(not bool(owner.data.get("boss_defeated_by_health", true)), "health defeat flag should clear after score consumption")
	_expect(not flow.consume_defeat_score_event(owner, Callable(self, "_record_direct_score")), "cleared health defeat should not score twice")


func _verify_update_callbacks_route_health_defeat_to_score() -> void:
	var owner := FakeOwner.new()
	var effects := FakeEffectsDriver.new()
	var match_event := FakeMatchEventDriver.new()
	var registry := FakeRegistry.new({
		"battle_scene_effects_update_driver": effects,
		"battle_scene_match_event_driver": match_event,
	})
	var callbacks := BattleSceneUpdateCallbacks.new()
	callbacks._update_effects(1.0 / 60.0, owner, registry)
	callbacks._update_effects(1.0 / 60.0, owner, registry)
	_expect(match_event.score_calls == ["player"], "effects update should route one health defeat into match scoring")
	_expect(not bool(owner.data.get("boss_defeated_by_health", true)), "effects update should clear pending health defeat after routing")


func _verify_score_reset_restores_round_health() -> void:
	var owner := FakeOwner.new()
	owner.data["selected_character_type"] = " Commando "
	owner.data["boss_current_health"] = 0
	owner.data["boss_health_damage_units"] = 5
	owner.data["boss_last_damage_source"] = "commando_firearm_bazooka"
	owner.data["boss_defeated_by_health"] = true
	var ball_driver := FakeBallDriver.new()
	var match_flow := FakeMatchFlowDriver.new()
	var registry := FakeRegistry.new({
		"battle_scene_ball_update_driver": ball_driver,
		"battle_scene_match_flow_driver": match_flow,
	})
	BattleSceneMatchEventDriver.new().handle_score_event("player", owner, registry)
	_expect(match_flow.score_calls == ["player"], "match event driver should forward health score side")
	_expect(ball_driver.reset_calls == 1, "score reset callback should reset the ball")
	_expect(int(owner.data.get("boss_current_health", -1)) == 5, "score reset should restore configured boss health for Commando aliases")
	_expect(int(owner.data.get("boss_health_damage_units", -1)) == 0, "score reset should clear boss health damage counter")
	_expect(str(owner.data.get("boss_last_damage_source", "x")) == "", "score reset should clear last boss damage source")
	_expect(not bool(owner.data.get("boss_defeated_by_health", true)), "score reset should clear health defeat flag")


func _verify_health_context_reaches_actor_draw() -> void:
	var owner := FakeOwner.new()
	owner.data["boss_current_health"] = 3
	owner.data["boss_health_damage_units"] = 2
	var registry := FakeRegistry.new()
	var scene_context: Dictionary = BattleDrawPlayfieldSceneContext.new().build(owner, Vector2.ZERO, registry)
	_expect(int(scene_context.get("boss_max_health", 0)) == 5, "playfield draw context should include boss max health")
	_expect(int(scene_context.get("boss_current_health", 0)) == 3, "playfield draw context should include boss current health")
	var actor_context: Dictionary = BattleDrawActorContext.new().build(scene_context, {})
	_expect(bool(actor_context.get("boss_health_visible", false)), "actor draw context should expose visible boss health")
	_expect(is_equal_approx(float(actor_context.get("boss_health_ratio", 0.0)), 0.6), "actor draw context should compute boss health ratio")
	_expect(int(actor_context.get("boss_health_damage_units", 0)) == 2, "actor draw context should preserve health damage counter")


func _record_direct_score(scoring_side: String) -> void:
	_direct_score_calls.append(scoring_side)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
