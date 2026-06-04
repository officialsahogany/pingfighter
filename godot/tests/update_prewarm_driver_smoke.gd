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


class FakeStagedCleanseState:
	extends RefCounted

	var prewarm_calls := 0
	var complete_after := 3

	func prewarm_assets_step() -> bool:
		prewarm_calls += 1
		return prewarm_calls >= complete_after


class FakeRegistry:
	extends RefCounted

	var context_builder: Object
	var ball_driver: Object
	var cleanse_state := FakeStagedCleanseState.new()
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
			"smasher_cleanse_state":
				return cleanse_state
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
	_expect(context.match_deps_calls == 0, "prewarm should defer full match flow deps until score or reset flow needs them")
	_expect(registry.requested_keys.has("viper_skill_runtime"), "prewarm should still warm selected Viper match/runtime deps")
	_expect(not registry.requested_keys.has("commando_firearm_runtime"), "prewarm should not warm unselected Commando firearm deps")
	_expect(not registry.requested_keys.has("stage2_pillar_background"), "prewarm should not warm off-stage Stage 2 background deps")
	_expect(registry.requested_keys.has("stage4_ponk_skill_state"), "prewarm should still warm selected Stage 4 deps")

	driver.prewarm_ball_update(owner, registry)
	_expect(ball_driver.prewarm_calls == 1, "ball prewarm should be forwarded to ball update driver")

	var smasher_driver: Object = UpdatePrewarmDriver.new()
	var smasher_owner := FakeOwner.new()
	smasher_owner.current_stage = 1
	smasher_owner.selected_character_type = "smasher"
	var smasher_context := FakeContextBuilder.new()
	var smasher_ball_driver := FakeBallDriver.new()
	var smasher_registry := FakeRegistry.new(smasher_context, smasher_ball_driver)
	smasher_driver.prewarm_update(smasher_owner, smasher_registry)
	_expect(
		smasher_registry.cleanse_state.prewarm_calls >= smasher_registry.cleanse_state.complete_after,
		"prewarm should wait for staged smasher cleanse assets before advancing the dependency key"
	)

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
