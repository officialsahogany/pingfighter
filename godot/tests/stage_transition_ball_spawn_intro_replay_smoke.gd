extends SceneTree

const MatchEventDriver := preload("res://scripts/core/battle_scene_match_event_driver.gd")
const BattleSceneFlowController := preload("res://scripts/core/battle_scene_flow_controller.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var data: Dictionary = {"current_stage": 2}

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		data[str(property)] = value
		return true

	func queue_redraw() -> void:
		pass


class FakeStageIntroFlowLifecycle:
	extends RefCounted

	var ball_calls := 0
	var last_flow: Object = null

	func begin_stage_landing_intro(
		_flow: Object,
		_owner: Object,
		_registry: Object,
		_module_getter: Callable,
		_cached_module_getter: Callable
	) -> void:
		pass

	func begin_ball_spawn_intro(flow: Object, _owner: Object, _registry: Object, _module_getter: Callable) -> void:
		ball_calls += 1
		last_flow = flow

	func start_battle_bgm(_flow: Object, _owner: Object, _module_getter: Callable) -> void:
		pass


class FakeLoadingRenderer:
	extends RefCounted

	var hide_calls := 0

	func hide_loading() -> void:
		hide_calls += 1


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_finish_stage_transition_loading_replays_ball_spawn_intro()
	_verify_finish_stage_transition_loading_skips_when_flow_missing()

	if _failures.is_empty():
		print("stage_transition_ball_spawn_intro_replay_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_finish_stage_transition_loading_replays_ball_spawn_intro() -> void:
	var flow: Object = BattleSceneFlowController.new()
	var fake_lifecycle := FakeStageIntroFlowLifecycle.new()
	flow.stage_intro_flow_lifecycle = fake_lifecycle
	flow.set("_battle_initialized", true)
	flow.set("_stage_landing_intro_started", true)
	flow.set("_ball_spawn_intro_started", true)

	var loading_renderer := FakeLoadingRenderer.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"battle_scene_flow_controller": flow,
		"battle_loading_screen_renderer": loading_renderer,
	})
	var driver: Object = MatchEventDriver.new()

	driver._finish_stage_transition_loading(owner, registry)

	_expect(loading_renderer.hide_calls == 1, "finish should hide the loading screen")
	_expect(
		not bool(flow.get("_ball_spawn_intro_started")),
		"finish should reset _ball_spawn_intro_started so the next begin call proceeds"
	)
	_expect(fake_lifecycle.ball_calls == 1, "finish should re-trigger begin_ball_spawn_intro after stage transition")
	_expect(
		fake_lifecycle.last_flow == flow,
		"begin_ball_spawn_intro should be invoked through the live flow controller"
	)

	fake_lifecycle.last_flow = null
	flow.stage_intro_flow_lifecycle = null


func _verify_finish_stage_transition_loading_skips_when_flow_missing() -> void:
	var loading_renderer := FakeLoadingRenderer.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"battle_loading_screen_renderer": loading_renderer,
	})
	var driver: Object = MatchEventDriver.new()

	driver._finish_stage_transition_loading(owner, registry)

	_expect(loading_renderer.hide_calls == 1, "finish should still hide the loading screen even if flow is missing")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
