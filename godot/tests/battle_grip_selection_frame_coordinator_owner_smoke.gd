extends SceneTree

const BattleGripSelectionFrameCoordinator := preload(
	"res://scripts/core/battle_grip_selection_frame_coordinator.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class FakeGripOverlay:
	extends RefCounted

	var active := true
	var redraw := true
	var update_calls := 0
	var draw_calls := 0
	var last_delta := 0.0
	var last_owner: Object = null
	var last_registry: Object = null
	var last_module_getter := Callable()
	var last_canvas: CanvasItem = null
	var last_view_size := Vector2.ZERO
	var events: Array[String] = []

	func update(
		delta: float,
		owner: Object,
		registry: Object,
		module_getter: Callable
	) -> bool:
		update_calls += 1
		last_delta = delta
		last_owner = owner
		last_registry = registry
		last_module_getter = module_getter
		events.append("update")
		return redraw

	func is_active() -> bool:
		events.append("active")
		return active

	func draw(canvas: CanvasItem, owner: Object, view_size: Vector2) -> void:
		draw_calls += 1
		last_canvas = canvas
		last_owner = owner
		last_view_size = view_size
		events.append("draw")


class FakeActiveOnlyOverlay:
	extends RefCounted

	func is_active() -> bool:
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
	_verify_idle_update_redraw_and_active_gate()
	_verify_inactive_idle_falls_through()
	_verify_active_draw_consumes_frame()
	_verify_missing_update_and_draw_compatibility()
	_verify_source_ownership()

	if _failures.is_empty():
		print("battle_grip_selection_frame_coordinator_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_idle_update_redraw_and_active_gate() -> void:
	var overlay := FakeGripOverlay.new()
	var holder := ModuleHolder.new()
	holder.modules["grip_style_selection_overlay"] = overlay
	var owner := FakeOwner.new()
	var registry := RefCounted.new()
	var perf_logger := FakePerfLogger.new()
	var module_getter := Callable(holder, "get_module")

	var consumed := bool(BattleGripSelectionFrameCoordinator.new().process_idle(
		0.125,
		owner,
		registry,
		module_getter,
		perf_logger
	))
	_expect(consumed, "active grip selection must consume the idle frame")
	_expect(overlay.events == ["update", "active"], "idle must update before checking active state")
	_expect(overlay.update_calls == 1, "idle must update the grip overlay exactly once")
	_expect(is_equal_approx(overlay.last_delta, 0.125), "idle must forward delta")
	_expect(overlay.last_owner == owner, "idle must forward the owner")
	_expect(overlay.last_registry == registry, "idle must forward the registry")
	_expect(overlay.last_module_getter == module_getter, "idle must forward the module getter")
	_expect(owner.redraw_requests == 1, "a redraw request from the overlay must be coalesced through the owner")
	_expect(perf_logger.labels.has("process.frame.grip_style_selection"), "idle must keep its BattlePerf label")


func _verify_inactive_idle_falls_through() -> void:
	var overlay := FakeGripOverlay.new()
	overlay.active = false
	overlay.redraw = false
	var holder := ModuleHolder.new()
	holder.modules["grip_style_selection_overlay"] = overlay
	var owner := FakeOwner.new()

	var consumed := bool(BattleGripSelectionFrameCoordinator.new().process_idle(
		0.016,
		owner,
		RefCounted.new(),
		Callable(holder, "get_module")
	))
	_expect(not consumed, "inactive grip selection must let the idle frame continue")
	_expect(overlay.events == ["update", "active"], "inactive grip selection must still receive its idle update")
	_expect(owner.redraw_requests == 0, "false update result must not request redraw")


func _verify_active_draw_consumes_frame() -> void:
	var overlay := FakeGripOverlay.new()
	var holder := ModuleHolder.new()
	holder.modules["grip_style_selection_overlay"] = overlay
	var owner := FakeOwner.new()
	var canvas := Node2D.new()
	var perf_logger := FakePerfLogger.new()
	var view_size := Vector2(1280.0, 720.0)

	var consumed := bool(BattleGripSelectionFrameCoordinator.new().draw_if_active(
		canvas,
		owner,
		Callable(holder, "get_module"),
		view_size,
		perf_logger
	))
	_expect(consumed, "active grip selection must consume the draw frame")
	_expect(overlay.events == ["active", "draw"], "draw must check active state before dispatch")
	_expect(overlay.draw_calls == 1, "active grip selection must draw exactly once")
	_expect(overlay.last_canvas == canvas, "draw must forward the canvas")
	_expect(overlay.last_owner == owner, "draw must forward the owner")
	_expect(overlay.last_view_size == view_size, "draw must forward the viewport size")
	_expect(perf_logger.labels.has("draw.frame.grip_style_selection"), "draw must keep its BattlePerf label")
	canvas.free()


func _verify_missing_update_and_draw_compatibility() -> void:
	var overlay := FakeActiveOnlyOverlay.new()
	var holder := ModuleHolder.new()
	holder.modules["grip_style_selection_overlay"] = overlay
	var coordinator: Object = BattleGripSelectionFrameCoordinator.new()
	var module_getter := Callable(holder, "get_module")
	var canvas := Node2D.new()
	var perf_logger := FakePerfLogger.new()

	_expect(
		not bool(coordinator.process_idle(0.016, FakeOwner.new(), null, module_getter)),
		"overlay without update must preserve the existing idle fallthrough"
	)
	_expect(
		bool(coordinator.draw_if_active(canvas, FakeOwner.new(), module_getter, Vector2.ONE, perf_logger)),
		"active overlay without draw must still preserve modal draw consumption"
	)
	_expect(perf_logger.labels.has("draw.frame.grip_style_selection"), "active draw gate must close its sample even without a draw method")
	canvas.free()


func _verify_source_ownership() -> void:
	var coordinator_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_grip_selection_frame_coordinator.gd"
	)
	var frame_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_frame_controller.gd"
	)
	_expect(coordinator_source.contains("process.frame.grip_style_selection"), "coordinator must own idle performance policy")
	_expect(coordinator_source.contains("draw.frame.grip_style_selection"), "coordinator must own draw performance policy")
	_expect(coordinator_source.contains("request_battle_redraw"), "coordinator must own redraw routing")
	_expect(frame_source.contains("BattleGripSelectionFrameCoordinator.new()"), "frame controller must compose the grip frame coordinator")
	_expect(frame_source.contains("_grip_selection_frame_coordinator.process_idle"), "frame controller must keep the ordered idle delegation")
	_expect(frame_source.contains("_grip_selection_frame_coordinator.draw_if_active"), "frame controller must keep the ordered draw delegation")
	_expect(not frame_source.contains("grip_overlay.update(delta"), "frame controller must not retain grip idle dispatch")
	_expect(not frame_source.contains("grip_overlay.draw(canvas"), "frame controller must not retain grip draw dispatch")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
