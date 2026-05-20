extends SceneTree

const StageBallSpawnIntro := preload("res://scripts/core/stage_ball_spawn_intro.gd")
const StageBallSpawnIntroFxLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_fx_lifecycle.gd")

var _failures: Array[String] = []


class FakeFxHost:
	extends Node

	var begin_args: Array = []
	var state_args: Array = []
	var layout_args: Array = []
	var tear_down_calls := 0
	var tear_down_free_self := false

	func begin_fx(
		start_pos: Vector2,
		target_pos: Vector2,
		ball_render_radius: float,
		phase_1_duration: float,
		phase_2_duration: float,
		phase_3_duration: float,
		player_serves: bool
	) -> void:
		begin_args = [
			start_pos,
			target_pos,
			ball_render_radius,
			phase_1_duration,
			phase_2_duration,
			phase_3_duration,
			player_serves,
		]

	func sync_state(ball_state: Dictionary, current_phase: int, elapsed_sec: float) -> void:
		state_args = [ball_state, current_phase, elapsed_sec]

	func sync_layout(layout: Dictionary) -> void:
		layout_args = [layout]

	func tear_down(free_self: bool = false) -> void:
		tear_down_calls += 1
		tear_down_free_self = free_self


class FakeFxLifecycle:
	extends RefCounted

	var begin_calls := 0
	var state_calls := 0
	var layout_calls := 0
	var tear_down_calls := 0

	func begin_fx_host(
		_owner: Object,
		_current_host: Node,
		_start_pos: Vector2,
		_target_pos: Vector2,
		_ball_render_radius: float,
		_phase_1_duration: float,
		_phase_2_duration: float,
		_phase_3_duration: float,
		_player_serves: bool
	) -> Node:
		begin_calls += 1
		return FakeFxHost.new()

	func sync_state(host: Node, _ball_state: Dictionary, _current_phase: int, _elapsed_sec: float) -> Node:
		state_calls += 1
		return host

	func sync_layout(host: Node, _layout: Dictionary) -> Node:
		layout_calls += 1
		return host

	func tear_down(host: Node) -> Node:
		tear_down_calls += 1
		if host != null and is_instance_valid(host):
			host.free()
		return null


func _init() -> void:
	_verify_fx_lifecycle_owns_host_node_lifecycle()
	_verify_intro_delegates_fx_host_lifecycle_surface()

	if _failures.is_empty():
		print("stage_ball_spawn_intro_fx_lifecycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_fx_lifecycle_owns_host_node_lifecycle() -> void:
	var lifecycle: Object = StageBallSpawnIntroFxLifecycle.new()
	lifecycle.host_factory = FakeFxHost
	var owner := Node.new()
	get_root().add_child(owner)

	var host: Node = lifecycle.begin_fx_host(
		owner,
		null,
		Vector2(10.0, 20.0),
		Vector2(30.0, 40.0),
		26.5,
		2.0,
		0.75,
		1.25,
		true
	)

	_expect(host != null, "fx lifecycle should create a host")
	_expect(owner.get_child_count() == 1, "fx lifecycle should attach the host to the owner")
	_expect(host.name == "StageBallSpawnIntroFxHost", "fx lifecycle should preserve the host node name")
	var fake_host: FakeFxHost = host as FakeFxHost
	_expect(fake_host.begin_args.size() == 7, "fx lifecycle should call begin_fx")
	_expect(fake_host.begin_args[0] == Vector2(10.0, 20.0), "fx lifecycle should pass start position")
	_expect(fake_host.begin_args[1] == Vector2(30.0, 40.0), "fx lifecycle should pass target position")
	_expect(is_equal_approx(float(fake_host.begin_args[2]), 26.5), "fx lifecycle should pass ball radius")

	host = lifecycle.sync_state(host, {"phase_progress": 0.5}, 3, 1.5)
	_expect(fake_host.state_args.size() == 3, "fx lifecycle should sync host state")
	_expect(int(fake_host.state_args[1]) == 3, "fx lifecycle should pass current phase")
	_expect(is_equal_approx(float(fake_host.state_args[2]), 1.5), "fx lifecycle should pass elapsed time")

	host = lifecycle.sync_layout(host, {"render_scale": 2.0})
	_expect(fake_host.layout_args.size() == 1, "fx lifecycle should sync host layout")
	_expect(is_equal_approx(float(fake_host.layout_args[0].get("render_scale", 0.0)), 2.0), "fx lifecycle should pass layout data")

	host = lifecycle.tear_down(host)
	_expect(host == null, "fx lifecycle tear_down should clear the host reference")
	_expect(fake_host.tear_down_calls == 1, "fx lifecycle should tear down the host")
	_expect(fake_host.tear_down_free_self, "fx lifecycle should request host self cleanup")
	owner.free()


func _verify_intro_delegates_fx_host_lifecycle_surface() -> void:
	var intro: Object = StageBallSpawnIntro.new()
	var lifecycle := FakeFxLifecycle.new()
	intro.fx_lifecycle = lifecycle
	intro.start_pos = Vector2(1.0, 2.0)
	intro.target_pos = Vector2(3.0, 4.0)
	intro.elapsed_sec = 0.5

	var owner := Node.new()
	intro._begin_fx_host(owner)
	_expect(lifecycle.begin_calls == 1, "intro should delegate FX host begin")
	_expect(intro.fx_host != null, "intro should keep the delegated host reference")

	intro._sync_fx_host_state({"visible": true, "phase_progress": 0.25})
	intro._sync_fx_host_layout({"render_scale": 1.5})
	intro._tear_down_fx_host()

	_expect(lifecycle.state_calls == 1, "intro should delegate FX host state sync")
	_expect(lifecycle.layout_calls == 1, "intro should delegate FX host layout sync")
	_expect(lifecycle.tear_down_calls == 1, "intro should delegate FX host tear down")
	_expect(intro.fx_host == null, "intro should clear the host reference after tear down")
	owner.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
