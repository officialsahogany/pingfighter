extends SceneTree

const BattleTerminalOverlayIdleCoordinator := preload(
	"res://scripts/core/battle_terminal_overlay_idle_coordinator.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class FakeScreen:
	extends RefCounted

	var route_name := ""
	var active := false
	var blocks := true
	var update_calls := 0
	var events: Array[String] = []

	func _init(name: String, event_log: Array[String]) -> void:
		route_name = name
		events = event_log

	func is_active() -> bool:
		return active

	func blocks_battle_physics() -> bool:
		return blocks

	func update(_delta: float) -> void:
		update_calls += 1
		events.append(route_name)


class FakeOverlayFrame:
	extends RefCounted

	var calls := 0
	var events: Array[String] = []

	func _init(event_log: Array[String]) -> void:
		events = event_log

	func process_idle(
		_delta: float,
		_owner: Object,
		_registry: Object,
		_module_getter: Callable
	) -> bool:
		calls += 1
		events.append("runtime_perk")
		return true


class FakeModalGate:
	extends RefCounted

	var runtime_perk_active := false

	func is_runtime_perk_choice_active(_module_getter: Callable) -> bool:
		return runtime_perk_active


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
	_verify_result_priority_and_runtime_perk_single_tick()
	_verify_nonblocking_continue_flows_into_settlement()
	_verify_blocking_continue_suppresses_settlement()
	_verify_source_ownership()

	if _failures.is_empty():
		print("battle_terminal_overlay_idle_coordinator_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_result_priority_and_runtime_perk_single_tick() -> void:
	var events: Array[String] = []
	var result := FakeScreen.new("result", events)
	result.active = true
	var continue_screen := FakeScreen.new("continue", events)
	continue_screen.active = true
	var settlement := FakeScreen.new("settlement", events)
	settlement.active = true
	var overlay := FakeOverlayFrame.new(events)
	var modal_gate := FakeModalGate.new()
	modal_gate.runtime_perk_active = true
	var holder := ModuleHolder.new()
	holder.modules = {
		"stage_clear_result_screen": result,
		"defeat_chance_gems_continue_screen": continue_screen,
		"defeat_settlement_screen": settlement,
		"battle_scene_overlay_frame_controller": overlay,
		"battle_scene_modal_gate_controller": modal_gate,
	}
	var owner := FakeOwner.new()
	var perf_logger := FakePerfLogger.new()

	var consumed := bool(BattleTerminalOverlayIdleCoordinator.new().process_idle(
		0.25,
		owner,
		RefCounted.new(),
		Callable(holder, "get_module"),
		perf_logger
	))
	_expect(consumed, "active result screen must consume the idle frame")
	_expect(events == ["result", "runtime_perk"], "result update and its runtime-perk tick must run before all defeat routes")
	_expect(not holder.reads.has("defeat_chance_gems_continue_screen"), "result priority must avoid resolving the continue screen")
	_expect(not holder.reads.has("defeat_settlement_screen"), "result priority must avoid resolving settlement")
	_expect(owner.redraw_requests == 1, "result frame must request exactly one redraw")
	_expect(perf_logger.labels.has("process.frame.result_screen"), "result update must keep its BattlePerf label")
	_expect(perf_logger.labels.has("process.frame.runtime_perk_overlay"), "result-owned perk tick must keep its BattlePerf label")


func _verify_nonblocking_continue_flows_into_settlement() -> void:
	var events: Array[String] = []
	var result := FakeScreen.new("result", events)
	var continue_screen := FakeScreen.new("continue", events)
	continue_screen.active = true
	continue_screen.blocks = false
	var settlement := FakeScreen.new("settlement", events)
	settlement.active = true
	var holder := ModuleHolder.new()
	holder.modules = {
		"stage_clear_result_screen": result,
		"defeat_chance_gems_continue_screen": continue_screen,
		"defeat_settlement_screen": settlement,
	}
	var owner := FakeOwner.new()
	var perf_logger := FakePerfLogger.new()

	var consumed := bool(BattleTerminalOverlayIdleCoordinator.new().process_idle(
		0.25,
		owner,
		RefCounted.new(),
		Callable(holder, "get_module"),
		perf_logger
	))
	_expect(consumed, "active settlement after nonblocking continue must consume the frame")
	_expect(events == ["continue", "settlement"], "nonblocking continue must flow into settlement in the same idle frame")
	_expect(owner.redraw_requests == 2, "both visible terminal screens must request redraw")
	_expect(perf_logger.labels.has("process.frame.defeat_chance_gems_continue"), "continue update must keep its BattlePerf label")
	_expect(perf_logger.labels.has("process.frame.defeat_settlement"), "settlement update must keep its BattlePerf label")


func _verify_blocking_continue_suppresses_settlement() -> void:
	var events: Array[String] = []
	var result := FakeScreen.new("result", events)
	var continue_screen := FakeScreen.new("continue", events)
	continue_screen.active = true
	continue_screen.blocks = true
	var settlement := FakeScreen.new("settlement", events)
	settlement.active = true
	var holder := ModuleHolder.new()
	holder.modules = {
		"stage_clear_result_screen": result,
		"defeat_chance_gems_continue_screen": continue_screen,
		"defeat_settlement_screen": settlement,
	}
	var owner := FakeOwner.new()

	var consumed := bool(BattleTerminalOverlayIdleCoordinator.new().process_idle(
		0.25,
		owner,
		RefCounted.new(),
		Callable(holder, "get_module")
	))
	_expect(consumed, "blocking continue screen must consume the frame")
	_expect(events == ["continue"], "blocking continue screen must suppress settlement update")
	_expect(not holder.reads.has("defeat_settlement_screen"), "blocked settlement must not be resolved")
	_expect(owner.redraw_requests == 1, "blocking continue must request one redraw")


func _verify_source_ownership() -> void:
	var coordinator_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_terminal_overlay_idle_coordinator.gd"
	)
	var frame_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_frame_controller.gd"
	)
	_expect(coordinator_source.contains("process.frame.result_screen"), "coordinator must own result performance policy")
	_expect(coordinator_source.contains("process.frame.defeat_settlement"), "coordinator must own final settlement policy")
	_expect(frame_source.contains("BattleTerminalOverlayIdleCoordinator.new()"), "frame controller must compose the terminal overlay coordinator")
	_expect(frame_source.contains("TERMINAL_OVERLAY_IDLE_CONTRACT"), "frame controller must retain dirty-smoke source compatibility")
	_expect(frame_source.contains("_terminal_overlay_idle_coordinator.process_idle"), "frame controller must keep one ordered delegation point")
	_expect(not frame_source.contains("result_screen.update(delta)"), "frame controller must not retain result update dispatch")
	_expect(not frame_source.contains("defeat_settlement_screen.update(delta)"), "frame controller must not retain settlement update dispatch")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
