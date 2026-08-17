extends SceneTree

const BallMotionStepper := preload("res://scripts/ball/ball_motion_stepper.gd")
const BattleSceneOwnerReader := preload(
	"res://scripts/core/battle_scene_owner_reader.gd"
)
const BattleSceneShell := preload("res://scripts/core/battle_scene_shell.gd")
const BattleSceneFrameController := preload(
	"res://scripts/core/battle_scene_frame_controller.gd"
)
const BattleScenePlayerControlConfigBuilder := preload(
	"res://scripts/core/battle_scene_player_control_config_builder.gd"
)
const TowerAscentRouteServeRuntime := preload(
	"res://scripts/tower_ascent/tower_ascent_route_serve_runtime.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const PHYSICS_GATE_COORDINATOR_PATH := (
	"res://scripts/core/battle_physics_gate_coordinator.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends Node

	var current_stage := 4
	var selected_character_type := "smasher"
	var player_pos := Vector2(250.0, 700.0)
	var player_speed := 0.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var gameplay_frame_counter := 0
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
	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


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
	var trace: Array[String] = []

	func sync_current_input_state() -> void:
		sync_calls += 1

	func update(
		_delta: float,
		_context: Dictionary,
		_deps: Dictionary,
		callbacks: Dictionary
	) -> void:
		update_calls += 1
		trace.append("serve_trigger")
		var serve_callback: Callable = callbacks.get("serve_ball", Callable())
		if serve_callback.is_valid():
			serve_callback.call()


class FakeBallDriver:
	extends RefCounted

	var round_state: FakeRoundState
	var velocities: Array[Vector2] = []
	var reset_calls := 0
	var serve_calls := 0
	var trace: Array[String] = []

	func _init(state: FakeRoundState) -> void:
		round_state = state

	func reset_ball(owner: Object, _registry: Object) -> void:
		reset_calls += 1
		owner.ball_pos = Vector2(380.0, 665.0)
		owner.ball_vel = Vector2.ZERO
		owner.ball_active = false

	func serve_ball(owner: Object, _registry: Object) -> void:
		serve_calls += 1
		trace.append("serve_ball")
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

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


class FakeInputReader:
	extends RefCounted

	var snapshot := {
		"left_pressed": false,
		"right_pressed": true,
		"direction": 1.0,
		"action_pressed": true,
		"action_just_pressed": true,
	}
	var snapshot_calls := 0
	var trace: Array[String] = []

	func get_snapshot() -> Dictionary:
		snapshot_calls += 1
		trace.append("input_snapshot")
		return snapshot.duplicate(true)


class FakeMovementState:
	extends RefCounted

	var update_calls := 0
	var trace: Array[String] = []

	func update_horizontal(
		delta: float,
		player_pos: Vector2,
		player_speed: float,
		direction: float,
		play_left: float,
		play_right: float,
		paddle_width: float,
		_config: Dictionary = {}
	) -> Dictionary:
		update_calls += 1
		trace.append("player_movement")
		var next_speed := direction * 6.0
		var next_pos := player_pos + Vector2(next_speed * delta * 60.0, 0.0)
		next_pos.x = clampf(next_pos.x, play_left, play_right - paddle_width)
		return {"player_pos": next_pos, "player_speed": next_speed}


class FakePlayerControlContext:
	extends RefCounted

	func build_player_control_config(_character_type: String = "smasher") -> Dictionary:
		return {
			"play_left": 0.0,
			"play_right": 760.0,
			"paddle_width": 155.0,
			"paddle_speed": 6.0,
			"paddle_max_speed": 6.0,
			"paddle_accel": 0.5,
			"paddle_decel": 0.5,
			"paddle_turn_decel": 1.0,
		}


class FakeMotionStepper:
	extends RefCounted

	var inner: Object = BallMotionStepper.new()
	var trace: Array[String] = []

	func step(
		ball_pos: Vector2,
		movement: Vector2,
		ball_vel: Vector2,
		context: Dictionary
	) -> Dictionary:
		trace.append("ball_step")
		return inner.step(ball_pos, movement, ball_vel, context)


class FakeModalRuntime:
	extends RefCounted

	func _capture_resume_pre_choice_velocity(_owner: Object) -> void:
		pass

	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pass

	func _resume_skill_cooldowns_for_choice() -> void:
		pass

	func _try_arm_resume_safety(_owner: Object, _registry: Object) -> void:
		pass


class FakeReadiness:
	extends RefCounted

	func is_logo_intro_active(_module_getter: Callable) -> bool:
		return false

	func is_boot_warmup_finished(_module_getter: Callable) -> bool:
		return true

	func is_stage_landing_intro_active(_module_getter: Callable) -> bool:
		return false

	func is_ball_spawn_intro_active(_module_getter: Callable) -> bool:
		return false


class FakeTransition:
	extends RefCounted

	func is_stage_transition_loading_active() -> bool:
		return false


class FakeScreen:
	extends RefCounted

	func is_active() -> bool:
		return false

	func blocks_battle_physics() -> bool:
		return false


class FakeGrip:
	extends RefCounted

	func update(
		_delta: float,
		_owner: Object,
		_registry: Object,
		_module_getter: Callable
	) -> bool:
		return false

	func is_active() -> bool:
		return false


class FakeModalGate:
	extends RefCounted

	func should_block_battle_physics_with_perf(
		_module_getter: Callable,
		_perf_logger: Object = null
	) -> bool:
		return false


class FakeModalPause:
	extends RefCounted

	var enter_calls := 0

	func enter_modal_block(
		_owner: Object,
		_registry: Object,
		_module_getter: Callable
	) -> void:
		enter_calls += 1

	func leave_modal_block(
		_owner: Object,
		_registry: Object,
		_module_getter: Callable
	) -> void:
		pass


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Variant:
		return modules.get(key, null)


func _init() -> void:
	_verify_live_shell_meta_owner_frame_path()
	_verify_physics_gate_frame_path_moves_serves_and_hits()
	_verify_real_serve_owner_and_unlimited_retry()
	_verify_production_owner_fails_closed_without_serve_dependencies()
	_verify_production_source_uses_serve_contract_without_aim_input()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_route_serve_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_live_shell_meta_owner_frame_path() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var owner: Object = BattleSceneShell.new()
	owner.set("current_stage", 4)
	owner.set("selected_character_type", "smasher")
	owner.set("player_pos", Vector2(250.0, 700.0))
	owner.set("player_speed", 0.0)
	owner.set("player_paddle_width", 155.0)
	owner.set("player_paddle_height", 50.0)
	owner.set("gameplay_frame_counter", 0)
	owner.set("ball_pos", Vector2(380.0, 665.0))
	owner.set("ball_vel", Vector2.ZERO)
	owner.set("ball_active", false)
	owner.set("ball_size", 28.6)
	owner.set("ball_impact_boost", 1.0)

	var property_names: Dictionary = {}
	for property_value in owner.get_property_list():
		if property_value is Dictionary:
			property_names[str((property_value as Dictionary).get("name", ""))] = true
	_expect(
		not property_names.has("player_pos") and not property_names.has("ball_active"),
		"live BattleSceneShell route keys must stay meta-only instead of leaking into the property list"
	)

	var input_reader := FakeInputReader.new()
	var movement_state := FakeMovementState.new()
	var round_state := FakeRoundState.new()
	var serve_flow := FakeServeFlow.new()
	var ball_driver := FakeBallDriver.new(round_state)
	var motion_stepper := FakeMotionStepper.new()
	var flow := TowerAscentFlowOwner.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"tower_ascent_flow_owner": flow,
		"runtime_perk_state": FakeModalRuntime.new(),
		"round_flow_state": round_state,
		"serve_flow_controller": serve_flow,
		"battle_scene_ball_update_driver": ball_driver,
		"ball_motion_stepper": motion_stepper,
		"smasher_input_reader": input_reader,
		"player_movement_state": movement_state,
		"battle_update_context": FakePlayerControlContext.new(),
		"battle_scene_player_control_config_builder": BattleScenePlayerControlConfigBuilder.new(),
	}
	_expect(
		flow.begin_vertical_slice(
			owner,
			Callable(),
			{"registry": registry, "run_id": "live-shell-meta-route"}
		),
		"live BattleSceneShell route fixture must enter ROUTE_AIM"
	)
	var targets: Array[Dictionary] = flow.get_route_aim_targets()
	_expect(targets.size() >= 1, "live shell ROUTE_AIM must expose a physical target")
	if targets.is_empty():
		flow.call("_finish_vertical_slice")
		owner.free()
		return
	var target_position: Vector2 = targets[0].get("position", Vector2.ZERO)
	ball_driver.velocities = [
		(target_position - Vector2(380.0, 665.0)).normalized() * 8.7,
	]
	var holder := ModuleHolder.new()
	holder.modules = {
		"battle_scene_readiness_controller": FakeReadiness.new(),
		"battle_scene_match_event_driver": FakeTransition.new(),
		"stage_clear_result_screen": FakeScreen.new(),
		"defeat_chance_gems_continue_screen": FakeScreen.new(),
		"defeat_settlement_screen": FakeScreen.new(),
		"grip_style_selection_overlay": FakeGrip.new(),
		"battle_scene_modal_gate_controller": FakeModalGate.new(),
	}
	var initial_player_pos := BattleSceneOwnerReader.get_vector2(
		owner,
		"player_pos",
		Vector2.ZERO
	)
	var blocked := _run_physics_gate_frame(
		1.5,
		owner,
		registry,
		holder,
		FakeModalPause.new()
	)
	_expect(blocked, "live shell ROUTE_AIM frame must stay inside the tower physics gate")
	_expect(
		BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2.ZERO).x
			> initial_player_pos.x,
		"live shell meta player_pos must accept the selective movement write"
	)
	_expect(ball_driver.serve_calls == 1, "live shell meta ball_active must preserve the actual serve")
	_expect(
		flow.get_phase_name() == "MAP_TRANSITION",
		"live shell meta ball state must reach the swept target instead of re-serve looping"
	)
	flow.call("_finish_vertical_slice")
	owner.free()


func _verify_physics_gate_frame_path_moves_serves_and_hits() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var owner := FakeOwner.new()
	var frame_trace: Array[String] = []
	var input_reader := FakeInputReader.new()
	var movement_state := FakeMovementState.new()
	var round_state := FakeRoundState.new()
	var serve_flow := FakeServeFlow.new()
	var ball_driver := FakeBallDriver.new(round_state)
	var motion_stepper := FakeMotionStepper.new()
	input_reader.trace = frame_trace
	movement_state.trace = frame_trace
	serve_flow.trace = frame_trace
	ball_driver.trace = frame_trace
	motion_stepper.trace = frame_trace
	var flow := TowerAscentFlowOwner.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"tower_ascent_flow_owner": flow,
		"runtime_perk_state": FakeModalRuntime.new(),
		"round_flow_state": round_state,
		"serve_flow_controller": serve_flow,
		"battle_scene_ball_update_driver": ball_driver,
		"ball_motion_stepper": motion_stepper,
		"smasher_input_reader": input_reader,
		"player_movement_state": movement_state,
		"battle_update_context": FakePlayerControlContext.new(),
		"battle_scene_player_control_config_builder": BattleScenePlayerControlConfigBuilder.new(),
	}
	_expect(
		flow.begin_vertical_slice(owner, Callable(), {"registry": registry, "run_id": "gate-frame-route"}),
		"production route fixture must enter ROUTE_AIM"
	)
	var targets: Array[Dictionary] = flow.get_route_aim_targets()
	_expect(targets.size() >= 1, "generated ROUTE_AIM must expose a physical target")
	if targets.is_empty():
		flow.call("_finish_vertical_slice")
		owner.free()
		return
	var target_position: Vector2 = targets[0].get("position", Vector2.ZERO)
	ball_driver.velocities = [
		(target_position - Vector2(380.0, 665.0)).normalized() * 8.7,
	]
	var holder := ModuleHolder.new()
	holder.modules = {
		"battle_scene_readiness_controller": FakeReadiness.new(),
		"battle_scene_match_event_driver": FakeTransition.new(),
		"stage_clear_result_screen": FakeScreen.new(),
		"defeat_chance_gems_continue_screen": FakeScreen.new(),
		"defeat_settlement_screen": FakeScreen.new(),
		"grip_style_selection_overlay": FakeGrip.new(),
		"battle_scene_modal_gate_controller": FakeModalGate.new(),
	}
	var pause := FakeModalPause.new()
	var initial_player_pos := owner.player_pos
	var initial_scores := Vector2i(owner.player_score, owner.boss_score)
	var initial_cooldown := owner.cooldown_seconds
	var uses_extracted_gate := ResourceLoader.exists(PHYSICS_GATE_COORDINATOR_PATH)
	var blocked := _run_physics_gate_frame(
		1.5,
		owner,
		registry,
		holder,
		pause
	)
	_expect(blocked, "ROUTE_AIM frame must stay inside the tower physics gate")
	_expect(owner.player_pos.x > initial_player_pos.x, "the coordinator frame path must tick player movement")
	_expect(input_reader.snapshot_calls == 1, "one ROUTE_AIM frame must acquire one idempotent input snapshot")
	_expect(movement_state.update_calls == 1, "one ROUTE_AIM frame must tick player movement once")
	_expect(ball_driver.serve_calls == 1, "the same coordinator frame must trigger the existing serve producer")
	_expect(frame_trace.count("ball_step") == 1, "the same coordinator frame must step the served ball once")
	_expect(flow.get_phase_name() == "MAP_TRANSITION", "the same coordinator frame must resolve the swept target hit")
	_expect(
		frame_trace == ["input_snapshot", "player_movement", "serve_trigger", "serve_ball", "ball_step"],
		"ROUTE_AIM selective order must be snapshot -> movement -> serve -> ball step before hit transition"
	)
	_expect(
		Vector2i(owner.player_score, owner.boss_score) == initial_scores,
		"the selective frame must keep combat score processing frozen"
	)
	_expect(is_equal_approx(owner.cooldown_seconds, initial_cooldown), "the selective frame must keep combat cooldowns frozen")
	if uses_extracted_gate:
		_expect(pause.enter_calls == 1, "the extracted physics gate must retain the modal pause fanout")
	flow.call("_finish_vertical_slice")
	owner.free()


func _run_physics_gate_frame(
	delta: float,
	owner: Object,
	registry: Object,
	holder: ModuleHolder,
	pause: FakeModalPause
) -> bool:
	if ResourceLoader.exists(PHYSICS_GATE_COORDINATOR_PATH):
		var gate_script := load(PHYSICS_GATE_COORDINATOR_PATH) as Script
		return bool(gate_script.new().should_block(
			delta,
			owner,
			registry,
			Callable(holder, "get_module"),
			{
				"is_battle_initialized": Callable(self, "_true_callback"),
				"is_stage_landing_intro_started": Callable(self, "_true_callback"),
			},
			pause
		))
	return bool(BattleSceneFrameController.new().call(
		"_process_tower_ascent_flow",
		delta,
		owner,
		registry
	))


func _true_callback() -> bool:
	return true


func _verify_real_serve_owner_and_unlimited_retry() -> void:
	var owner := FakeOwner.new()
	var round_state := FakeRoundState.new()
	var serve_flow := FakeServeFlow.new()
	var ball_driver := FakeBallDriver.new(round_state)
	var left_target := Vector2(
		TowerAscentTuning.TEMP_ROUTE_TARGET_LEFT_X,
		TowerAscentTuning.TEMP_ROUTE_TARGET_Y
	)
	ball_driver.velocities = [
		Vector2(0.0, -8.7),
		(left_target - Vector2(380.0, 665.0)).normalized() * 8.7,
	]
	var registry := FakeRegistry.new()
	var input_reader := FakeInputReader.new()
	input_reader.snapshot["direction"] = 0.0
	registry.instances = {
		"round_flow_state": round_state,
		"serve_flow_controller": serve_flow,
		"battle_scene_ball_update_driver": ball_driver,
		"ball_motion_stepper": BallMotionStepper.new(),
		"smasher_input_reader": input_reader,
		"player_movement_state": FakeMovementState.new(),
		"battle_update_context": FakePlayerControlContext.new(),
		"battle_scene_player_control_config_builder": BattleScenePlayerControlConfigBuilder.new(),
	}
	var runtime := TowerAscentRouteServeRuntime.new()
	var begin_result: Dictionary = runtime.begin(owner, registry)
	_expect(bool(begin_result.get("accepted", false)), "route serve must acquire the production serve dependencies")
	_expect(round_state.player_serves, "route serve must assign the existing player serve owner")
	_expect(ball_driver.reset_calls == 1 and serve_flow.sync_calls == 1, "route entry must park the live ball and synchronize the existing serve edge")
	var targets: Array[Dictionary] = [
		{"id": "left", "position": left_target, "hit_radius": TowerAscentTuning.TEMP_ROUTE_TARGET_HIT_RADIUS},
		{"id": "right", "position": Vector2(TowerAscentTuning.TEMP_ROUTE_TARGET_RIGHT_X, TowerAscentTuning.TEMP_ROUTE_TARGET_Y), "hit_radius": TowerAscentTuning.TEMP_ROUTE_TARGET_HIT_RADIUS},
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
	runtime.cancel()
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
		"get_input_reader_key",
		"player_movement_state",
		"battle_update_context",
		"battle_scene_player_control_config_builder",
	]:
		_expect(route_source.find(required_key) >= 0, "route serve must use production dependency: %s" % required_key)
	for retired_aim_input in ["KEY_LEFT", "KEY_RIGHT", "InputEventMouseMotion", "_launch_selector"]:
		_expect(flow_source.find(retired_aim_input) < 0, "ROUTE_AIM must not retain deterministic aim input: %s" % retired_aim_input)
	_expect(route_source.find("RandomNumberGenerator") < 0, "route flow must consume the serve producer's randomness instead of owning another RNG")
	_expect(
		route_source.find("BattleSceneOwnerReader.get_value") >= 0,
		"route serve must read meta-backed BattleSceneShell keys through the shared owner reader"
	)
	_expect(
		route_source.find("_collect_property_names") < 0,
		"route serve must not reintroduce a property-list gate for meta-backed owner keys"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
