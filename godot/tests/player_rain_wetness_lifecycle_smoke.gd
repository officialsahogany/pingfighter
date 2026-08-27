extends SceneTree

const BattleSceneMatchEventDriver := preload("res://scripts/core/battle_scene_match_event_driver.gd")
const BattleSceneMatchFlowDriver := preload("res://scripts/core/battle_scene_match_flow_driver.gd")
const BattleSceneTeardownLifecycle := preload("res://scripts/core/battle_scene_teardown_lifecycle.gd")
const PlayerRainWetnessLifecycle := preload("res://scripts/effects/player_rain_wetness_lifecycle.gd")

var _failures: Array[String] = []


class FakeWetnessHost:
	extends Node

	var tear_down_calls := 0
	var tear_down_free_self := false
	var wetness := 0.82
	var warmed_child: Node = null

	func _init() -> void:
		warmed_child = Node.new()
		warmed_child.name = "WarmedSpriteAndMaterialSentinel"
		add_child(warmed_child)

	func tear_down(free_self: bool = false) -> void:
		tear_down_calls += 1
		tear_down_free_self = free_self
		wetness = 0.0

	func get_wetness() -> float:
		return wetness


class FakeTowerFlowOwner:
	extends RefCounted

	var begin_calls := 0
	var begin_result := true

	func begin_vertical_slice(
		_owner: Object,
		_finish_callback: Callable,
		_context: Dictionary = {}
	) -> bool:
		begin_calls += 1
		return begin_result


class FakeBallDriver:
	extends RefCounted

	var reset_calls := 0

	func reset_ball(_owner: Object, _registry: Object) -> void:
		reset_calls += 1


class FakeBossHealthFlow:
	extends RefCounted

	var reset_calls := 0

	func reset_round_health(_owner: Object) -> void:
		reset_calls += 1


class FakeWeatherDriver:
	extends RefCounted

	var round_start_calls := 0

	func on_round_start(_owner: Object, _registry: Object) -> void:
		round_start_calls += 1


class FakeRegistry:
	extends RefCounted

	var modules: Dictionary = {}
	var clear_all_calls := 0

	func get_instance(key: String) -> Object:
		return modules.get(key, null)

	func get_cached_instance(key: String) -> Object:
		return modules.get(key, null)

	func clear_all() -> void:
		clear_all_calls += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_tower_map_entry_tears_down_exactly_once_and_reuses_host()
	_verify_failed_tower_map_entry_does_not_tear_down()
	_verify_ball_reset_convergence_tears_down_exactly_once()
	_verify_scene_exit_tears_down_exactly_once_and_frees()
	_verify_exact_name_does_not_touch_pso_prewarmer_host()

	if _failures.is_empty():
		print("player_rain_wetness_lifecycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_tower_map_entry_tears_down_exactly_once_and_reuses_host() -> void:
	var owner := Node2D.new()
	get_root().add_child(owner)
	var host := _attach_wetness_host(owner)
	var warmed_child_id := host.warmed_child.get_instance_id()
	var flow_owner := FakeTowerFlowOwner.new()
	var registry := FakeRegistry.new()
	registry.modules["tower_ascent_flow_owner"] = flow_owner

	var started := BattleSceneMatchFlowDriver.new()._try_start_tower_ascent_vertical_slice(
		registry,
		Callable(),
		owner
	)

	_expect(started, "the production Tower map transition should accept the fixture")
	_expect(flow_owner.begin_calls == 1, "the production transition should call begin_vertical_slice once")
	_expect(host.tear_down_calls == 1, "successful clear-to-map transition must call wetness tear_down exactly once")
	_expect(not host.tear_down_free_self, "map entry must retain the warmed wetness host")
	_expect(is_equal_approx(host.get_wetness(), 0.0), "map entry must reset accumulated wetness to zero")
	_expect(host.get_parent() == owner, "tear_down(false) must keep the host attached for the next battle")
	_expect(
		is_instance_valid(host.warmed_child) and host.warmed_child.get_instance_id() == warmed_child_id,
		"tear_down(false) must preserve warmed runtime children/material state"
	)
	owner.free()


func _verify_failed_tower_map_entry_does_not_tear_down() -> void:
	var owner := Node2D.new()
	get_root().add_child(owner)
	var host := _attach_wetness_host(owner)
	var flow_owner := FakeTowerFlowOwner.new()
	flow_owner.begin_result = false
	var registry := FakeRegistry.new()
	registry.modules["tower_ascent_flow_owner"] = flow_owner

	var started := BattleSceneMatchFlowDriver.new()._try_start_tower_ascent_vertical_slice(
		registry,
		Callable(),
		owner
	)

	_expect(not started, "control leg: rejected Tower map transition must stay rejected")
	_expect(host.tear_down_calls == 0, "a rejected map transition must not tear down live battle wetness")
	_expect(host.get_wetness() > 0.0, "a rejected map transition must preserve the live wetness envelope")
	owner.free()


func _verify_ball_reset_convergence_tears_down_exactly_once() -> void:
	var owner := Node2D.new()
	get_root().add_child(owner)
	var host := _attach_wetness_host(owner)
	var registry := FakeRegistry.new()
	var ball_driver := FakeBallDriver.new()
	var health_flow := FakeBossHealthFlow.new()
	var weather_driver := FakeWeatherDriver.new()
	registry.modules["battle_scene_ball_update_driver"] = ball_driver
	registry.modules["battle_scene_boss_health_flow"] = health_flow
	registry.modules["battle_scene_weather_update_driver"] = weather_driver

	BattleSceneMatchEventDriver.new()._reset_ball(owner, registry)

	_expect(host.tear_down_calls == 1, "score/serve/restart/cancel reset funnel must tear down wetness exactly once")
	_expect(not host.tear_down_free_self, "ball reset must retain the warmed host")
	_expect(is_equal_approx(host.get_wetness(), 0.0), "ball reset must start the next entry dry")
	_expect(ball_driver.reset_calls == 1, "wetness cleanup must not skip the production ball reset")
	_expect(health_flow.reset_calls == 1, "wetness cleanup must not skip round-health reset")
	_expect(weather_driver.round_start_calls == 1, "wetness cleanup must not skip the next weather roll")
	owner.free()


func _verify_scene_exit_tears_down_exactly_once_and_frees() -> void:
	var owner := Node2D.new()
	get_root().add_child(owner)
	var host := _attach_wetness_host(owner)
	var registry := FakeRegistry.new()
	var clear_cache_calls := [0]

	BattleSceneTeardownLifecycle.new().exit_tree(
		owner,
		registry,
		Callable(registry, "get_cached_instance"),
		{"clear_module_cache": func() -> void: clear_cache_calls[0] += 1}
	)

	_expect(host.tear_down_calls == 1, "battle scene exit must tear down wetness exactly once")
	_expect(host.tear_down_free_self, "final scene exit must request host self-free")
	_expect(is_equal_approx(host.get_wetness(), 0.0), "scene exit must clear accumulated wetness")
	_expect(registry.clear_all_calls == 1, "wetness cleanup must not skip registry teardown")
	_expect(clear_cache_calls[0] == 1, "wetness cleanup must not skip module-cache teardown")
	owner.free()


func _verify_exact_name_does_not_touch_pso_prewarmer_host() -> void:
	var owner := Node2D.new()
	get_root().add_child(owner)
	var pso_host := FakeWetnessHost.new()
	pso_host.name = "PlayerRainWetnessFxHost_pso"
	owner.add_child(pso_host)

	var handled := PlayerRainWetnessLifecycle.tear_down_from_canvas(owner, false)

	_expect(not handled, "the battle lifecycle must ignore the PSO prewarmer's suffixed host")
	_expect(pso_host.tear_down_calls == 0, "PSO warm host must remain untouched")
	_expect(pso_host.get_wetness() > 0.0, "PSO warm state must not be invalidated")
	owner.free()


func _attach_wetness_host(owner: Node) -> FakeWetnessHost:
	var host := FakeWetnessHost.new()
	host.name = PlayerRainWetnessLifecycle.HOST_NAME
	owner.add_child(host)
	return host


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
