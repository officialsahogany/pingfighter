extends SceneTree

const UpdatePrewarmDriver := preload("res://scripts/core/battle_scene_update_prewarm_driver.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 4
	var selected_character_type := "viper"


class FakeContextBuilder:
	extends RefCounted

	var player_config_character := ""
	var player_deps_character := ""
	var boss_context_calls := 0
	var effects_context_calls := 0
	var effects_deps_calls := 0
	var effects_deps_stage := 0
	var effects_deps_character := ""
	var match_deps_calls := 0

	func build_player_control_config(character_type: String = "smasher") -> Dictionary:
		player_config_character = character_type
		return {}

	func build_player_control_deps(_registry: Object, character_type: String = "smasher") -> Dictionary:
		player_deps_character = character_type
		return {}

	func build_boss_ai_context(_owner: Object, _registry: Object) -> Dictionary:
		boss_context_calls += 1
		return {}

	func build_effects_context(_owner: Object, _registry: Object) -> Dictionary:
		effects_context_calls += 1
		return {
			"current_stage": 4,
			"selected_character_type": "viper",
		}

	func build_effects_deps(_registry: Object, current_stage: int = 1, character_type: String = "") -> Dictionary:
		effects_deps_calls += 1
		effects_deps_stage = current_stage
		effects_deps_character = character_type
		return {}

	func build_match_flow_deps(_registry: Object, _current_stage: int = 1) -> Dictionary:
		match_deps_calls += 1
		return {}


class FakeBallDriver:
	extends RefCounted

	var prewarm_calls := 0

	func prewarm_update(_owner: Object, _registry: Object) -> void:
		prewarm_calls += 1


class FakeRegistry:
	extends RefCounted

	var context_builder: Object
	var ball_driver: Object
	var requested_keys: Array[String] = []

	func _init(context: Object, ball: Object) -> void:
		context_builder = context
		ball_driver = ball

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		match key:
			"battle_update_context":
				return context_builder
			"battle_scene_ball_update_driver":
				return ball_driver
			_:
				return RefCounted.new()


func _init() -> void:
	var driver: Object = UpdatePrewarmDriver.new()
	var owner := FakeOwner.new()
	var context := FakeContextBuilder.new()
	var ball_driver := FakeBallDriver.new()
	var registry := FakeRegistry.new(context, ball_driver)

	driver.prewarm_update(owner, registry)
	_expect(registry.requested_keys.has("battle_frame_flow_controller"), "prewarm should request frame flow controller")
	_expect(registry.requested_keys.has("battle_scene_scoreboard_update_driver"), "prewarm should request scoreboard update driver")
	_expect(registry.requested_keys.has("battle_scene_match_event_driver"), "prewarm should request match event driver")
	_expect(registry.requested_keys.has("battle_scene_boss_health_flow"), "prewarm should request boss health flow")
	_expect(registry.requested_keys.has("battle_scene_effects_update_result_applier"), "prewarm should request effects update result applier")
	_expect(registry.requested_keys.has("battle_scene_actor_update_result_applier"), "prewarm should request actor update result applier")
	_expect(registry.requested_keys.has("battle_scene_player_control_config_builder"), "prewarm should request player control config builder")
	_expect(registry.requested_keys.has("battle_scene_match_reset_result_applier"), "prewarm should request match reset result applier")
	_expect(registry.requested_keys.has("match_score_event_controller"), "prewarm should request match score event controller")
	_expect(registry.requested_keys.has("match_scoreboard_flow_controller"), "prewarm should request match scoreboard flow controller")
	_expect(registry.requested_keys.has("match_round_restart_controller"), "prewarm should request match round restart controller")
	_expect(registry.requested_keys.has("match_reset_controller"), "prewarm should request match reset controller")
	_expect(registry.requested_keys.has("skill_orb_tooltip_hover_state"), "prewarm should request skill tooltip hover state")
	_expect(context.player_config_character == "viper", "prewarm should prime player config for selected character")
	_expect(context.player_deps_character == "viper", "prewarm should prime player deps for selected character")
	_expect(context.boss_context_calls == 1, "prewarm should prime boss AI context")
	_expect(context.effects_context_calls == 1, "prewarm should prime effects context")
	_expect(context.effects_deps_calls == 1, "prewarm should prime effects deps")
	_expect(context.effects_deps_stage == 4, "prewarm should prime effects deps for selected stage")
	_expect(context.effects_deps_character == "viper", "prewarm should prime effects deps for selected character")
	_expect(context.match_deps_calls == 1, "prewarm should prime match flow deps")

	driver.prewarm_ball_update(owner, registry)
	_expect(ball_driver.prewarm_calls == 1, "ball prewarm should be forwarded to ball update driver")

	if _failures.is_empty():
		print("update_prewarm_driver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
