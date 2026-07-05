extends SceneTree

const UpdatePrewarmDriver := preload("res://scripts/core/battle_scene_update_prewarm_driver.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 4
	var selected_character_type := "viper"


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return Time.get_ticks_usec()

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)

	func has_label_containing(fragment: String) -> bool:
		for label in labels:
			if label.find(fragment) >= 0:
				return true
		return false


class FakeContextBuilder:
	extends RefCounted

	var player_config_character := ""
	var player_deps_character := ""
	var boss_context_calls := 0
	var effects_context_calls := 0
	var effects_context_stage := 4
	var effects_context_character := "viper"
	var effects_context_stage1_boss_variant := "dalji"
	var effects_deps_calls := 0
	var effects_deps_stage := 0
	var effects_deps_character := ""
	var effects_deps_stage1_boss_variant := ""
	var match_deps_calls := 0
	var match_deps_stage := 0
	var match_deps_include_all_stage_deps := true
	var match_deps_has_perf_logger := false
	var match_deps_label_prefix := ""
	var match_deps_character := ""

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
			"current_stage": effects_context_stage,
			"selected_character_type": effects_context_character,
			"stage1_boss_variant": effects_context_stage1_boss_variant,
		}

	func build_effects_deps(
		_registry: Object,
		current_stage: int = 1,
		character_type: String = "",
		stage1_boss_variant: String = "dalji"
	) -> Dictionary:
		effects_deps_calls += 1
		effects_deps_stage = current_stage
		effects_deps_character = character_type
		effects_deps_stage1_boss_variant = stage1_boss_variant
		return {}

	func build_match_flow_deps(
		_registry: Object,
		_current_stage: int = 1,
		_perf_logger: Object = null,
		_perf_label_prefix: String = "",
		_include_all_stage_deps: bool = true,
		_character_type: String = ""
	) -> Dictionary:
		match_deps_calls += 1
		match_deps_stage = _current_stage
		match_deps_include_all_stage_deps = _include_all_stage_deps
		match_deps_has_perf_logger = _perf_logger != null
		match_deps_label_prefix = _perf_label_prefix
		match_deps_character = _character_type
		_registry.get_instance("match_score_state")
		if _character_type == "viper":
			_registry.get_instance("viper_skill_runtime")
		elif _character_type == "soldier":
			_registry.get_instance("commando_firearm_runtime")
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
	var battle_perf_logger := FakePerfLogger.new()
	var requested_keys: Array[String] = []

	func _init(context: Object, ball: Object) -> void:
		context_builder = context
		ball_driver = ball

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		match key:
			"battle_perf_logger":
				return battle_perf_logger
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
	_expect(context.match_deps_calls == 1, "prewarm should finalize match flow deps before the first score event")
	_expect(context.match_deps_stage == 4, "prewarm should finalize match flow deps for selected stage")
	_expect(not context.match_deps_include_all_stage_deps, "prewarm should use current-stage score-event deps")
	_expect(context.match_deps_has_perf_logger, "prewarm should pass the perf logger into match flow deps")
	_expect(
		context.match_deps_label_prefix == "process.frame.update_prewarm.match_deps.finalize",
		"prewarm should label match flow finalize detail samples"
	)
	_expect(context.match_deps_character == "viper", "prewarm should finalize match flow deps for selected character")
	_expect(
		registry.battle_perf_logger.has_label_containing("process.frame.update_prewarm.match_deps.finalize.lookup.00_match_score_state"),
		"prewarm should report match flow registry lookup timing"
	)
	_expect(
		registry.battle_perf_logger.has_label_containing("process.frame.update_prewarm.match_deps.finalize.total"),
		"prewarm should report match flow finalize total timing"
	)
	_expect(registry.requested_keys.has("viper_skill_runtime"), "prewarm should still warm selected Viper match/runtime deps")
	_expect(not registry.requested_keys.has("commando_firearm_runtime"), "prewarm should not warm unselected Commando firearm deps")
	_expect(not registry.requested_keys.has("stage2_pillar_background"), "prewarm should not warm off-stage deps during score-event prewarm")
	_expect(registry.requested_keys.has("stage4_ponk_skill_state"), "prewarm should still warm selected Stage 4 deps")

	driver.prewarm_ball_update(owner, registry)
	_expect(ball_driver.prewarm_calls == 1, "ball prewarm should be forwarded to ball update driver")

	var smasher_driver: Object = UpdatePrewarmDriver.new()
	var smasher_owner := FakeOwner.new()
	smasher_owner.current_stage = 1
	smasher_owner.selected_character_type = "smasher"
	var smasher_context := FakeContextBuilder.new()
	smasher_context.effects_context_stage = 1
	smasher_context.effects_context_character = "smasher"
	smasher_context.effects_context_stage1_boss_variant = "gaksi"
	var smasher_ball_driver := FakeBallDriver.new()
	var smasher_registry := FakeRegistry.new(smasher_context, smasher_ball_driver)
	smasher_driver.prewarm_update(smasher_owner, smasher_registry)
	_expect(
		smasher_registry.cleanse_state.prewarm_calls >= smasher_registry.cleanse_state.complete_after,
		"prewarm should wait for staged smasher cleanse assets before advancing the dependency key"
	)
	_expect(smasher_context.match_deps_character == "smasher", "Smasher prewarm should finalize match flow deps for Smasher")
	_expect(smasher_context.effects_deps_stage1_boss_variant == "gaksi", "Stage 1 Gaksital prewarm should pass the boss variant into effects deps")
	_expect(not smasher_registry.requested_keys.has("viper_skill_runtime"), "Smasher prewarm should not wake Viper match runtime")
	_expect(not smasher_registry.requested_keys.has("commando_firearm_runtime"), "Smasher prewarm should not wake Commando match runtime")
	for smasher_controller_key in [
		"smasher_drive_bounce_state",
		"smasher_drive_counter_state",
		"smasher_drive_activation_controller",
		"smasher_power_smash_activation_controller",
		"smasher_power_smash_motion_controller",
	]:
		_expect(
			smasher_registry.requested_keys.has(smasher_controller_key),
			"Smasher update prewarm should request %s before selected-character runtime prewarm" % smasher_controller_key
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
