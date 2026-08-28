extends SceneTree

const BattleSceneMatchEventDriver := preload("res://scripts/core/battle_scene_match_event_driver.gd")
const BattleSceneMatchFlowDriver := preload("res://scripts/core/battle_scene_match_flow_driver.gd")
const BattleSceneTeardownLifecycle := preload("res://scripts/core/battle_scene_teardown_lifecycle.gd")
const Stage4PonkAwakenAuraFxHost := preload("res://scripts/stages/stage4/stage4_ponk_awaken_aura_fx_host.gd")
const Stage4PonkFxHostCoordinator := preload("res://scripts/stages/stage4/stage4_ponk_fx_host_coordinator.gd")
const Stage4PonkIllusionRippleFxHost := preload("res://scripts/stages/stage4/stage4_ponk_illusion_ripple_fx_host.gd")
const Stage4PonkMagneticFxHost := preload("res://scripts/stages/stage4/stage4_ponk_magnetic_fx_host.gd")
const Stage4PonkMeditationFxHost := preload("res://scripts/stages/stage4/stage4_ponk_meditation_fx_host.gd")

var _failures: Array[String] = []


class FakePonkFxHost:
	extends Node

	var tear_down_calls := 0
	var tear_down_free_self := false
	var accumulated_value := 0.83
	var elapsed_seconds := 7.25
	var warmed_child: Node = null

	func _init() -> void:
		warmed_child = Node.new()
		warmed_child.name = "WarmedRuntimeNodeSentinel"
		add_child(warmed_child)

	func tear_down(free_self: bool = false) -> void:
		tear_down_calls += 1
		tear_down_free_self = free_self
		accumulated_value = 0.0
		elapsed_seconds = 0.0
		if free_self:
			queue_free()


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
	_verify_tower_map_entry_tears_down_all_hosts_once_and_reuses_them()
	_verify_failed_tower_map_entry_preserves_live_hosts()
	_verify_ball_reset_convergence_tears_down_all_hosts_once()
	_verify_scene_exit_tears_down_all_hosts_once_and_frees_them()
	_verify_exact_names_ignore_pso_prewarmer_hosts()
	_verify_real_host_accumulators_reset_without_releasing_prewarm_state()

	if _failures.is_empty():
		print("stage4_ponk_fx_host_lifecycle_smoke: map=4 reset=4 exit=4 actual_accumulators=4 pso=0")
		print("stage4_ponk_fx_host_lifecycle_smoke: ok")
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		quit(1)


func _verify_tower_map_entry_tears_down_all_hosts_once_and_reuses_them() -> void:
	var owner := Node2D.new()
	get_root().add_child(owner)
	var hosts := _attach_fake_hosts(owner)
	var warmed_child_ids: Dictionary = {}
	for host: FakePonkFxHost in hosts:
		warmed_child_ids[host.name] = host.warmed_child.get_instance_id()
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
	_expect_host_calls(hosts, 1, false, "successful clear-to-map transition")
	for host: FakePonkFxHost in hosts:
		_expect(is_equal_approx(host.accumulated_value, 0.0), "%s must reset its accumulated value on map entry" % host.name)
		_expect(is_equal_approx(host.elapsed_seconds, 0.0), "%s must reset its time base on map entry" % host.name)
		_expect(host.get_parent() == owner, "tear_down(false) must retain %s on the battle canvas" % host.name)
		_expect(
			is_instance_valid(host.warmed_child)
			and host.warmed_child.get_instance_id() == int(warmed_child_ids[host.name]),
			"tear_down(false) must preserve %s's warmed runtime node" % host.name
		)
	owner.free()


func _verify_failed_tower_map_entry_preserves_live_hosts() -> void:
	var owner := Node2D.new()
	get_root().add_child(owner)
	var hosts := _attach_fake_hosts(owner)
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
	_expect_host_calls(hosts, 0, false, "rejected clear-to-map transition")
	for host: FakePonkFxHost in hosts:
		_expect(host.accumulated_value > 0.0, "rejected transition must preserve %s's live envelope" % host.name)
	owner.free()


func _verify_ball_reset_convergence_tears_down_all_hosts_once() -> void:
	var owner := Node2D.new()
	get_root().add_child(owner)
	var hosts := _attach_fake_hosts(owner)
	var registry := FakeRegistry.new()
	var ball_driver := FakeBallDriver.new()
	var health_flow := FakeBossHealthFlow.new()
	var weather_driver := FakeWeatherDriver.new()
	registry.modules["battle_scene_ball_update_driver"] = ball_driver
	registry.modules["battle_scene_boss_health_flow"] = health_flow
	registry.modules["battle_scene_weather_update_driver"] = weather_driver

	BattleSceneMatchEventDriver.new()._reset_ball(owner, registry)

	_expect_host_calls(hosts, 1, false, "score/serve/restart/cancel reset funnel")
	for host: FakePonkFxHost in hosts:
		_expect(is_equal_approx(host.accumulated_value, 0.0), "%s must reset its accumulated value on ball reset" % host.name)
		_expect(is_equal_approx(host.elapsed_seconds, 0.0), "%s must reset its time base on ball reset" % host.name)
	_expect(ball_driver.reset_calls == 1, "Ponk cleanup must not skip the production ball reset")
	_expect(health_flow.reset_calls == 1, "Ponk cleanup must not skip round-health reset")
	_expect(weather_driver.round_start_calls == 1, "Ponk cleanup must not skip the next weather roll")
	owner.free()


func _verify_scene_exit_tears_down_all_hosts_once_and_frees_them() -> void:
	var owner := Node2D.new()
	get_root().add_child(owner)
	var hosts := _attach_fake_hosts(owner)
	var registry := FakeRegistry.new()
	var clear_cache_calls := [0]

	BattleSceneTeardownLifecycle.new().exit_tree(
		owner,
		registry,
		Callable(registry, "get_cached_instance"),
		{"clear_module_cache": func() -> void: clear_cache_calls[0] += 1}
	)

	_expect_host_calls(hosts, 1, true, "final battle scene exit")
	for host: FakePonkFxHost in hosts:
		_expect(host.is_queued_for_deletion(), "final scene exit must queue %s for deletion" % host.name)
		_expect(is_equal_approx(host.accumulated_value, 0.0), "scene exit must clear %s's accumulated value" % host.name)
	_expect(registry.clear_all_calls == 1, "Ponk cleanup must not skip registry teardown")
	_expect(clear_cache_calls[0] == 1, "Ponk cleanup must not skip module-cache teardown")
	owner.free()


func _verify_exact_names_ignore_pso_prewarmer_hosts() -> void:
	var owner := Node2D.new()
	get_root().add_child(owner)
	var pso_hosts: Array[FakePonkFxHost] = []
	for host_name: String in Stage4PonkFxHostCoordinator.HOST_NAMES:
		var host := FakePonkFxHost.new()
		host.name = "%s_pso" % host_name
		owner.add_child(host)
		pso_hosts.append(host)

	var handled_count := Stage4PonkFxHostCoordinator.tear_down_from_canvas(owner, false)

	_expect(handled_count == 0, "the coordinator lifecycle bridge must ignore suffixed PSO hosts")
	_expect_host_calls(pso_hosts, 0, false, "PSO prewarmer exact-name control")
	for host: FakePonkFxHost in pso_hosts:
		_expect(host.accumulated_value > 0.0, "%s warm state must remain untouched" % host.name)
	owner.free()


func _verify_real_host_accumulators_reset_without_releasing_prewarm_state() -> void:
	var awaken := Stage4PonkAwakenAuraFxHost.new()
	awaken.open_value = 0.9
	awaken.elapsed_sec = 8.5
	awaken.set("_state", {"intensity": 1.0})
	awaken.set("_active", true)
	awaken.tear_down(false)
	_expect(is_equal_approx(awaken.open_value, 0.0), "awaken aura open envelope must reset")
	_expect(is_equal_approx(awaken.elapsed_sec, 0.0), "awaken aura time base must reset")
	_expect((awaken.get("_state") as Dictionary).is_empty(), "awaken aura cached state must clear")
	_expect(not awaken.is_queued_for_deletion(), "awaken aura tear_down(false) must retain the host")
	awaken.free()

	var magnetic := Stage4PonkMagneticFxHost.new()
	magnetic.open_value = 0.8
	magnetic.elapsed_sec = 6.5
	magnetic.set("_state", {"field_active": true})
	magnetic.set("_charge_glyph_preset_name", "stale")
	magnetic.set("_lattice_preset_name", "stale")
	magnetic.set("_active", true)
	magnetic.tear_down(false)
	_expect(is_equal_approx(magnetic.open_value, 0.0), "magnetic open envelope must reset")
	_expect(is_equal_approx(magnetic.elapsed_sec, 0.0), "magnetic time base must reset")
	_expect((magnetic.get("_state") as Dictionary).is_empty(), "magnetic cached state must clear")
	_expect(str(magnetic.get("_charge_glyph_preset_name")).is_empty(), "magnetic charge preset latch must reset")
	_expect(str(magnetic.get("_lattice_preset_name")).is_empty(), "magnetic lattice preset latch must reset")
	_expect(not magnetic.is_queued_for_deletion(), "magnetic tear_down(false) must retain the host")
	magnetic.free()

	var meditation := Stage4PonkMeditationFxHost.new()
	meditation.pulse_value = 0.7
	meditation.breath_value = 0.6
	meditation.open_value = 0.9
	meditation.release_flash = 0.8
	meditation.elapsed_sec = 12.5
	meditation.set("_state", {"meditation_active": true})
	meditation.set("_last_release_id", 42)
	meditation.set("_active", true)
	meditation.tear_down(false)
	_expect(is_equal_approx(meditation.pulse_value, 0.0), "meditation pulse envelope must reset")
	_expect(is_equal_approx(meditation.breath_value, 0.0), "meditation breath envelope must reset")
	_expect(is_equal_approx(meditation.open_value, 0.0), "meditation open envelope must reset")
	_expect(is_equal_approx(meditation.release_flash, 0.0), "meditation release flash must reset")
	_expect(is_equal_approx(meditation.elapsed_sec, 0.0), "meditation time base must reset")
	_expect((meditation.get("_state") as Dictionary).is_empty(), "meditation cached state must clear")
	_expect(int(meditation.get("_last_release_id")) == -1, "meditation release id latch must reset")
	_expect(not meditation.is_queued_for_deletion(), "meditation tear_down(false) must retain the host")
	meditation.free()

	var illusion := Stage4PonkIllusionRippleFxHost.new()
	illusion.visible = true
	illusion.set("_last_active_sync_msec", 999)
	illusion.tear_down(false)
	_expect(not illusion.visible, "illusion ripple must hide during teardown")
	_expect(int(illusion.get("_last_active_sync_msec")) == 0, "illusion ripple active-sync clock must reset")
	_expect(not illusion.is_queued_for_deletion(), "illusion ripple tear_down(false) must retain the host")
	illusion.free()


func _attach_fake_hosts(owner: Node) -> Array[FakePonkFxHost]:
	var hosts: Array[FakePonkFxHost] = []
	for host_name: String in Stage4PonkFxHostCoordinator.HOST_NAMES:
		var host := FakePonkFxHost.new()
		host.name = host_name
		owner.add_child(host)
		hosts.append(host)
	return hosts


func _expect_host_calls(
	hosts: Array[FakePonkFxHost],
	expected_calls: int,
	expected_free_self: bool,
	boundary: String
) -> void:
	for host: FakePonkFxHost in hosts:
		_expect(
			host.tear_down_calls == expected_calls,
			"%s must call %s tear_down exactly %d time(s), got %d" % [
				boundary,
				host.name,
				expected_calls,
				host.tear_down_calls,
			]
		)
		if expected_calls > 0:
			_expect(
				host.tear_down_free_self == expected_free_self,
				"%s must pass free_self=%s to %s" % [boundary, expected_free_self, host.name]
			)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
