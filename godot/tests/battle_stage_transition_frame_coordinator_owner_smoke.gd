extends SceneTree

const BattleStageTransitionFrameCoordinator := preload(
	"res://scripts/core/battle_stage_transition_frame_coordinator.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class FakeTransitionDriver:
	extends RefCounted

	var active := true
	var draw_result := true
	var update_calls := 0
	var draw_calls := 0
	var last_delta := 0.0
	var last_owner: Object = null
	var last_registry: Object = null
	var last_canvas: CanvasItem = null
	var last_module_getter := Callable()
	var last_view_size := Vector2.ZERO
	var events: Array[String] = []

	func is_stage_transition_loading_active() -> bool:
		events.append("active")
		return active

	func update_stage_transition_loading(
		delta: float,
		owner: Object,
		registry: Object
	) -> void:
		update_calls += 1
		last_delta = delta
		last_owner = owner
		last_registry = registry
		events.append("update")

	func draw_stage_transition_loading(
		canvas: CanvasItem,
		owner: Object,
		registry: Object,
		module_getter: Callable,
		view_size: Vector2
	) -> bool:
		draw_calls += 1
		last_canvas = canvas
		last_owner = owner
		last_registry = registry
		last_module_getter = module_getter
		last_view_size = view_size
		events.append("draw")
		return draw_result


class FakeActiveOnlyDriver:
	extends RefCounted

	func is_stage_transition_loading_active() -> bool:
		return true


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
	_verify_active_idle_updates_redraws_and_consumes()
	_verify_inactive_idle_falls_through()
	_verify_successful_draw_preempts_without_black_fallback()
	_verify_failed_or_missing_draw_uses_black_fallback()
	_verify_source_ownership()

	if _failures.is_empty():
		print("battle_stage_transition_frame_coordinator_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_active_idle_updates_redraws_and_consumes() -> void:
	var driver := FakeTransitionDriver.new()
	var holder := ModuleHolder.new()
	holder.modules["battle_scene_match_event_driver"] = driver
	var owner := FakeOwner.new()
	var registry := RefCounted.new()
	var perf_logger := FakePerfLogger.new()

	var consumed := bool(BattleStageTransitionFrameCoordinator.new().process_idle(
		0.125,
		owner,
		registry,
		Callable(holder, "get_module"),
		perf_logger
	))
	_expect(consumed, "active transition must consume the idle frame")
	_expect(driver.events == ["active", "update"], "idle must check active state before updating")
	_expect(driver.update_calls == 1, "active transition must update exactly once")
	_expect(is_equal_approx(driver.last_delta, 0.125), "idle must forward delta")
	_expect(driver.last_owner == owner, "idle must forward owner")
	_expect(driver.last_registry == registry, "idle must forward registry")
	_expect(owner.redraw_requests == 1, "active transition must request one coalesced redraw")
	_expect(perf_logger.labels.has("process.frame.stage_transition_loading"), "idle must keep its BattlePerf label")


func _verify_inactive_idle_falls_through() -> void:
	var driver := FakeTransitionDriver.new()
	driver.active = false
	var holder := ModuleHolder.new()
	holder.modules["battle_scene_match_event_driver"] = driver
	var owner := FakeOwner.new()

	var consumed := bool(BattleStageTransitionFrameCoordinator.new().process_idle(
		0.016,
		owner,
		null,
		Callable(holder, "get_module")
	))
	_expect(not consumed, "inactive transition must let idle continue")
	_expect(driver.events == ["active"], "inactive transition must not update")
	_expect(owner.redraw_requests == 0, "inactive transition must not request redraw")


func _verify_successful_draw_preempts_without_black_fallback() -> void:
	var driver := FakeTransitionDriver.new()
	var holder := ModuleHolder.new()
	holder.modules["battle_scene_match_event_driver"] = driver
	var owner := FakeOwner.new()
	var registry := RefCounted.new()
	var canvas := Node2D.new()
	var perf_logger := FakePerfLogger.new()
	var module_getter := Callable(holder, "get_module")
	var view_size := Vector2(1280.0, 720.0)

	var consumed := bool(BattleStageTransitionFrameCoordinator.new().draw_if_active(
		canvas,
		owner,
		registry,
		module_getter,
		view_size,
		perf_logger
	))
	_expect(consumed, "active transition draw must consume the frame")
	_expect(driver.events == ["active", "draw"], "draw must check active state before dispatch")
	_expect(driver.draw_calls == 1, "active transition must draw exactly once")
	_expect(driver.last_canvas == canvas, "draw must forward canvas")
	_expect(driver.last_owner == owner, "draw must forward owner")
	_expect(driver.last_registry == registry, "draw must forward registry")
	_expect(driver.last_module_getter == module_getter, "draw must forward module getter")
	_expect(driver.last_view_size == view_size, "draw must forward viewport size")
	_expect(perf_logger.labels.has("draw.frame.stage_transition_loading"), "draw must keep its BattlePerf label")
	_expect(not perf_logger.labels.has("draw.frame.black"), "successful transition draw must skip black fallback")
	canvas.free()


func _verify_failed_or_missing_draw_uses_black_fallback() -> void:
	var driver := FakeTransitionDriver.new()
	driver.draw_result = false
	var holder := ModuleHolder.new()
	holder.modules["battle_scene_match_event_driver"] = driver
	var perf_logger := FakePerfLogger.new()
	var coordinator: Object = BattleStageTransitionFrameCoordinator.new()

	var consumed := bool(coordinator.draw_if_active(
		null,
		FakeOwner.new(),
		null,
		Callable(holder, "get_module"),
		Vector2.ONE,
		perf_logger
	))
	_expect(consumed, "failed transition draw must still consume via black fallback")
	_expect(driver.events == ["active", "draw"], "failed transition draw must attempt renderer before fallback")
	_expect(perf_logger.labels.has("draw.frame.stage_transition_loading"), "failed renderer attempt must close its sample")
	_expect(perf_logger.labels.has("draw.frame.black"), "failed renderer attempt must sample black fallback")

	var active_only := FakeActiveOnlyDriver.new()
	holder.modules["battle_scene_match_event_driver"] = active_only
	perf_logger.labels.clear()
	_expect(
		bool(coordinator.draw_if_active(
			null,
			FakeOwner.new(),
			null,
			Callable(holder, "get_module"),
			Vector2.ONE,
			perf_logger
		)),
		"active driver without draw method must use black fallback"
	)
	_expect(not perf_logger.labels.has("draw.frame.stage_transition_loading"), "missing draw method must not create a renderer sample")
	_expect(perf_logger.labels.has("draw.frame.black"), "missing draw method must sample black fallback")


func _verify_source_ownership() -> void:
	var coordinator_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_stage_transition_frame_coordinator.gd"
	)
	var frame_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_frame_controller.gd"
	)
	_expect(coordinator_source.contains("battle_scene_match_event_driver"), "coordinator must own transition-driver lookup")
	_expect(coordinator_source.contains("process.frame.stage_transition_loading"), "coordinator must own idle performance policy")
	_expect(coordinator_source.contains("draw.frame.stage_transition_loading"), "coordinator must own transition draw policy")
	_expect(coordinator_source.contains("draw.frame.black"), "coordinator must own transition fallback policy")
	_expect(frame_source.contains("BattleStageTransitionFrameCoordinator.new()"), "frame controller must compose the transition coordinator")
	_expect(frame_source.contains("_stage_transition_frame_coordinator.process_idle"), "frame controller must keep the first idle delegation")
	_expect(frame_source.contains("_stage_transition_frame_coordinator.draw_if_active"), "frame controller must keep the first draw delegation")
	_expect(not frame_source.contains("match_event_driver.update_stage_transition_loading"), "frame controller must not retain transition update dispatch")
	_expect(not frame_source.contains("match_event_driver.draw_stage_transition_loading"), "frame controller must not retain transition draw dispatch")
	_expect(not frame_source.contains("func _get_match_event_driver"), "frame controller must not retain transition lookup policy")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
