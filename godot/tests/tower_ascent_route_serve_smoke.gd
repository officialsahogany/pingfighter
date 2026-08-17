extends SceneTree

const BallMotionStepper := preload("res://scripts/ball/ball_motion_stepper.gd")
const TowerAscentRouteServeRuntime := preload(
	"res://scripts/tower_ascent/tower_ascent_route_serve_runtime.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends Node

	var current_stage := 4
	var ball_pos := Vector2(380.0, 665.0)
	var ball_vel := Vector2.ZERO
	var ball_active := false
	var ball_size := 28.6
	var ball_impact_boost := 1.0
	var player_score := 7
	var boss_score := 3
	var boss_ai_ticks := 0
	var combat_rng_state := 44123
	var cooldown_seconds := 2.5


class FakeRoundState:
	extends RefCounted

	var waiting := true
	var player_serves := false
	var reset_calls := 0

	func is_waiting_for_serve() -> bool:
		return waiting

	func set_player_serves(value: bool) -> void:
		player_serves = value

	func reset_round_wait() -> void:
		waiting = true
		reset_calls += 1


class FakeServeFlow:
	extends RefCounted

	var sync_calls := 0
	var update_calls := 0

	func sync_current_input_state() -> void:
		sync_calls += 1

	func update(
		_delta: float,
		_context: Dictionary,
		_deps: Dictionary,
		callbacks: Dictionary
	) -> void:
		update_calls += 1
		var serve_callback: Callable = callbacks.get("serve_ball", Callable())
		if serve_callback.is_valid():
			serve_callback.call()


class FakeBallDriver:
	extends RefCounted

	var round_state: FakeRoundState
	var velocities: Array[Vector2] = []
	var reset_calls := 0
	var serve_calls := 0

	func _init(state: FakeRoundState) -> void:
		round_state = state

	func reset_ball(owner: Object, _registry: Object) -> void:
		reset_calls += 1
		owner.ball_pos = Vector2(380.0, 665.0)
		owner.ball_vel = Vector2.ZERO
		owner.ball_active = false

	func serve_ball(owner: Object, _registry: Object) -> void:
		serve_calls += 1
		round_state.waiting = false
		owner.ball_pos = Vector2(380.0, 665.0)
		owner.ball_vel = velocities.pop_front() if not velocities.is_empty() else Vector2(0.0, -8.7)
		owner.ball_active = true


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var reads: Array[String] = []

	func get_instance(key: String) -> Variant:
		reads.append(key)
		return instances.get(key, null)


func _init() -> void:
	_verify_real_serve_owner_and_unlimited_retry()
	_verify_production_owner_fails_closed_without_serve_dependencies()
	_verify_production_source_uses_serve_contract_without_aim_input()
	if _failures.is_empty():
		print("tower_ascent_route_serve_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_real_serve_owner_and_unlimited_retry() -> void:
	var owner := FakeOwner.new()
	var round_state := FakeRoundState.new()
	var serve_flow := FakeServeFlow.new()
	var ball_driver := FakeBallDriver.new(round_state)
	var left_target := Vector2(220.0, 165.0)
	ball_driver.velocities = [
		Vector2(0.0, -8.7),
		(left_target - Vector2(380.0, 665.0)).normalized() * 8.7,
	]
	var registry := FakeRegistry.new()
	registry.instances = {
		"round_flow_state": round_state,
		"serve_flow_controller": serve_flow,
		"battle_scene_ball_update_driver": ball_driver,
		"ball_motion_stepper": BallMotionStepper.new(),
	}
	var runtime := TowerAscentRouteServeRuntime.new()
	var begin_result: Dictionary = runtime.begin(owner, registry)
	_expect(bool(begin_result.get("accepted", false)), "route serve must acquire the production serve dependencies")
	_expect(round_state.player_serves, "route serve must assign the existing player serve owner")
	_expect(ball_driver.reset_calls == 1 and serve_flow.sync_calls == 1, "route entry must park the live ball and synchronize the existing serve edge")
	var targets: Array[Dictionary] = [
		{"id": "left", "position": left_target, "hit_radius": 49.0},
		{"id": "right", "position": Vector2(540.0, 165.0), "hit_radius": 49.0},
	]
	runtime.update(0.016, targets)
	_expect(ball_driver.serve_calls == 1 and owner.ball_active, "serve flow must launch the live owner ball through the existing ball driver")
	var miss_result: Dictionary = runtime.update(1.5, targets)
	_expect(str(miss_result.get("status", "")) == TowerAscentRouteServeRuntime.STATUS_MISS, "a serve that misses both targets must rearm instead of selecting")
	_expect(round_state.waiting and ball_driver.reset_calls == 2, "a miss must return to unlimited player re-serve")
	runtime.update(0.016, targets)
	var hit_result: Dictionary = runtime.update(1.5, targets)
	_expect(str(hit_result.get("status", "")) == TowerAscentRouteServeRuntime.STATUS_HIT, "the real serve trajectory must resolve a swept target hit")
	_expect(str(hit_result.get("target_id", "")) == "left", "the physical hit, not an aim choice, must select the node")
	_expect(runtime.get_serve_attempt_count() == 2, "miss and retry must count two actual serve launches")
	_expect(not owner.ball_active and owner.ball_vel == Vector2.ZERO, "target resolution must release and hide the route-owned ball")
	_expect(owner.player_score == 7 and owner.boss_score == 3, "route ball ownership must not emit combat score events")
	_expect(owner.boss_ai_ticks == 0 and owner.combat_rng_state == 44123, "route ball ownership must not tick boss AI or combat RNG")
	_expect(is_equal_approx(owner.cooldown_seconds, 2.5), "route ball ownership must not tick combat cooldowns")
	_expect(not registry.reads.has("game_audio") and not registry.reads.has("boss_ai"), "selective route simulation must not acquire loop audio or boss AI")
	owner.free()


func _verify_production_owner_fails_closed_without_serve_dependencies() -> void:
	var owner := FakeOwner.new()
	var runtime := TowerAscentRouteServeRuntime.new()
	var result: Dictionary = runtime.begin(owner, FakeRegistry.new())
	_expect(not bool(result.get("accepted", true)), "a production Node owner must fail closed without the real serve dependency set")
	_expect(not owner.ball_active and owner.ball_vel == Vector2.ZERO, "failed acquisition must not invent or launch a fallback selector ball")
	owner.free()


func _verify_production_source_uses_serve_contract_without_aim_input() -> void:
	var route_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_route_serve_runtime.gd"
	)
	var flow_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_runtime.gd"
	)
	for required_key in [
		"serve_flow_controller",
		"battle_scene_ball_update_driver",
		"ball_motion_stepper",
	]:
		_expect(route_source.find(required_key) >= 0, "route serve must use production dependency: %s" % required_key)
	for retired_aim_input in ["KEY_LEFT", "KEY_RIGHT", "InputEventMouseMotion", "_launch_selector"]:
		_expect(flow_source.find(retired_aim_input) < 0, "ROUTE_AIM must not retain deterministic aim input: %s" % retired_aim_input)
	_expect(route_source.find("RandomNumberGenerator") < 0, "route flow must consume the serve producer's randomness instead of owning another RNG")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
