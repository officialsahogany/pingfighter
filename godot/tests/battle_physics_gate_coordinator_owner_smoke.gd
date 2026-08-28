extends SceneTree

const BattlePhysicsGateCoordinator := preload(
	"res://scripts/core/battle_physics_gate_coordinator.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class FakeReadiness:
	extends RefCounted

	var logo_active := false
	var warmup_finished := true
	var landing_active := false
	var ball_spawn_active := false

	func is_logo_intro_active(_module_getter: Callable) -> bool:
		return logo_active

	func is_boot_warmup_finished(_module_getter: Callable) -> bool:
		return warmup_finished

	func is_stage_landing_intro_active(_module_getter: Callable) -> bool:
		return landing_active

	func is_ball_spawn_intro_active(_module_getter: Callable) -> bool:
		return ball_spawn_active


class FakeTransition:
	extends RefCounted

	var active := false

	func is_stage_transition_loading_active() -> bool:
		return active


class FakeScreen:
	extends RefCounted

	var active := false
	var blocks := true

	func is_active() -> bool:
		return active

	func blocks_battle_physics() -> bool:
		return active and blocks


class FakeGripOverlay:
	extends RefCounted

	var active := false
	var update_calls := 0
	var last_delta := -1.0

	func update(
		delta: float,
		_owner: Object,
		_registry: Object,
		_module_getter: Callable
	) -> bool:
		update_calls += 1
		last_delta = delta
		return active

	func is_active() -> bool:
		return active


class FakeModalGate:
	extends RefCounted

	var blocked := false

	func should_block_battle_physics_with_perf(
		_module_getter: Callable,
		_perf_logger: Object
	) -> bool:
		return blocked


class FakeModalPauseState:
	extends RefCounted

	var enter_calls := 0
	var leave_calls := 0

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
		leave_calls += 1


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}
	var reads: Array[String] = []

	func get_module(key: String) -> Variant:
		reads.append(key)
		return modules.get(key, null)


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return 1

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


func _init() -> void:
	_verify_transition_precedes_terminal_screens()
	_verify_grip_precedes_modal_gate()
	_verify_modal_pause_enter_leave_symmetry()
	_verify_source_ownership()

	if _failures.is_empty():
		print("battle_physics_gate_coordinator_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_transition_precedes_terminal_screens() -> void:
	var fixture := _build_fixture()
	var transition: FakeTransition = fixture.holder.modules["battle_scene_match_event_driver"]
	transition.active = true
	var result: FakeScreen = fixture.holder.modules["stage_clear_result_screen"]
	result.active = true

	var blocked := bool(BattlePhysicsGateCoordinator.new().should_block(
		1.0 / 60.0,
		fixture.owner,
		fixture.registry,
		Callable(fixture.holder, "get_module"),
		_callbacks(),
		fixture.modal_pause,
		fixture.perf_logger
	))
	_expect(blocked, "stage transition must block physics")
	_expect(not fixture.holder.reads.has("stage_clear_result_screen"), "stage transition must win before result-screen lookup")
	_expect(fixture.perf_logger.labels.has("physics.frame.gate.stage_transition_loading"), "transition gate must keep its BattlePerf label")
	_expect(fixture.modal_pause.enter_calls == 0 and fixture.modal_pause.leave_calls == 0, "early transition gate must not touch modal pause state")


func _verify_grip_precedes_modal_gate() -> void:
	var fixture := _build_fixture()
	var grip: FakeGripOverlay = fixture.holder.modules["grip_style_selection_overlay"]
	grip.active = true
	var modal_gate: FakeModalGate = fixture.holder.modules["battle_scene_modal_gate_controller"]
	modal_gate.blocked = true

	var blocked := bool(BattlePhysicsGateCoordinator.new().should_block(
		0.5,
		fixture.owner,
		fixture.registry,
		Callable(fixture.holder, "get_module"),
		_callbacks(),
		fixture.modal_pause,
		fixture.perf_logger
	))
	_expect(blocked, "active grip selection must block physics")
	_expect(grip.update_calls == 1 and grip.last_delta == 0.0, "grip gate must keep its zero-delta physics probe")
	_expect(fixture.owner.redraw_requests == 1, "grip update must request one coalesced redraw")
	_expect(not fixture.holder.reads.has("battle_scene_modal_gate_controller"), "grip gate must win before modal lookup")
	_expect(fixture.modal_pause.enter_calls == 0, "grip gate must not enter the modal cooldown latch")
	_expect(fixture.perf_logger.labels.has("physics.frame.gate.grip_style_selection"), "grip gate must keep its BattlePerf label")


func _verify_modal_pause_enter_leave_symmetry() -> void:
	var fixture := _build_fixture()
	var modal_gate: FakeModalGate = fixture.holder.modules["battle_scene_modal_gate_controller"]
	var coordinator: Object = BattlePhysicsGateCoordinator.new()
	modal_gate.blocked = true
	_expect(
		bool(coordinator.should_block(
			1.0 / 60.0,
			fixture.owner,
			fixture.registry,
			Callable(fixture.holder, "get_module"),
			_callbacks(),
			fixture.modal_pause,
			fixture.perf_logger
		)),
		"blocking modal gate must stop physics"
	)
	_expect(fixture.modal_pause.enter_calls == 1 and fixture.modal_pause.leave_calls == 0, "blocking modal must enter the pause state exactly once")

	modal_gate.blocked = false
	_expect(
		not bool(coordinator.should_block(
			1.0 / 60.0,
			fixture.owner,
			fixture.registry,
			Callable(fixture.holder, "get_module"),
			_callbacks(),
			fixture.modal_pause,
			fixture.perf_logger
		)),
		"open gate ladder must release normal physics update"
	)
	_expect(fixture.modal_pause.enter_calls == 1 and fixture.modal_pause.leave_calls == 1, "released modal must leave the pause state exactly once")
	_expect(fixture.perf_logger.labels.has("physics.frame.gate.modal_block"), "modal gate must keep its BattlePerf label")


func _verify_source_ownership() -> void:
	var coordinator_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_physics_gate_coordinator.gd"
	)
	var frame_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_frame_controller.gd"
	)
	_expect(coordinator_source.contains("physics.frame.gate.logo_intro"), "coordinator must own the first physics gate")
	_expect(coordinator_source.contains("physics.frame.gate.modal_block"), "coordinator must own the final physics gate")
	_expect(coordinator_source.contains("func process_grip_selection"), "coordinator must expose the legacy grip probe")
	_expect(frame_source.contains("BattlePhysicsGateCoordinator.new()"), "frame controller must compose the physics gate coordinator")
	_expect(frame_source.contains("PHYSICS_GATE_CONTRACT"), "frame controller must retain focused-smoke source compatibility")
	_expect(frame_source.contains("func _process_grip_selection_physics_gate"), "frame controller must retain the direct-test grip facade")
	_expect(not frame_source.contains("_modal_pause_state.enter_modal_block"), "frame controller must not retain modal enter policy")


func _build_fixture() -> Dictionary:
	var holder := ModuleHolder.new()
	holder.modules = {
		"battle_scene_readiness_controller": FakeReadiness.new(),
		"battle_scene_match_event_driver": FakeTransition.new(),
		"stage_clear_result_screen": FakeScreen.new(),
		"defeat_chance_gems_continue_screen": FakeScreen.new(),
		"defeat_settlement_screen": FakeScreen.new(),
		"grip_style_selection_overlay": FakeGripOverlay.new(),
		"battle_scene_modal_gate_controller": FakeModalGate.new(),
	}
	return {
		"holder": holder,
		"owner": FakeOwner.new(),
		"registry": RefCounted.new(),
		"modal_pause": FakeModalPauseState.new(),
		"perf_logger": FakePerfLogger.new(),
	}


func _callbacks() -> Dictionary:
	return {
		"is_battle_initialized": Callable(self, "_true_callback"),
		"is_stage_landing_intro_started": Callable(self, "_true_callback"),
	}


func _true_callback() -> bool:
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
