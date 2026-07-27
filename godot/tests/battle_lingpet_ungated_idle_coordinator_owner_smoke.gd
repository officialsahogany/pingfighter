extends SceneTree

const BattleLingpetUngatedIdleCoordinator := preload(
	"res://scripts/core/battle_lingpet_ungated_idle_coordinator.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class FakeRuntime:
	extends RefCounted

	var hatch_active := true
	var acquire_active := true
	var overflow_active := true
	var calls: Array[String] = []
	var last_delta := 0.0
	var last_owner: Object = null
	var last_registry: Object = null

	func is_hatch_break_active() -> bool:
		return hatch_active

	func advance_hatch_break(delta: float, owner: Object, registry: Object) -> void:
		calls.append("hatch")
		last_delta = delta
		last_owner = owner
		last_registry = registry

	func is_acquire_cutin_active() -> bool:
		return acquire_active

	func advance_acquire_cutin(delta: float, registry: Object) -> void:
		calls.append("acquire")
		last_delta = delta
		last_registry = registry

	func is_overflow_choice_active() -> bool:
		return overflow_active


class ModuleHolder:
	extends RefCounted

	var runtime: Object = null

	func get_module(key: String) -> Variant:
		if key == "lingpet_egg_runtime":
			return runtime
		return null


func _init() -> void:
	_verify_priority_advance_and_redraw()
	_verify_source_ownership()

	if _failures.is_empty():
		print("battle_lingpet_ungated_idle_coordinator_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_priority_advance_and_redraw() -> void:
	var coordinator: Object = BattleLingpetUngatedIdleCoordinator.new()
	var owner := FakeOwner.new()
	var registry := RefCounted.new()
	var runtime := FakeRuntime.new()
	var holder := ModuleHolder.new()
	holder.runtime = runtime
	var getter := Callable(holder, "get_module")
	var delta := 0.125

	_expect(
		bool(coordinator.process_ungated(delta, owner, registry, getter)),
		"active hatch break must consume the idle frame"
	)
	_expect(runtime.calls == ["hatch"], "hatch break must keep priority over acquire and overflow")
	_expect(runtime.last_delta == delta and runtime.last_owner == owner and runtime.last_registry == registry, "hatch advance arguments must be preserved")
	_expect(owner.redraw_requests == 1, "hatch advance must request one redraw")

	runtime.hatch_active = false
	_expect(
		bool(coordinator.process_ungated(delta, owner, registry, getter)),
		"active acquire cut-in must consume the idle frame"
	)
	_expect(runtime.calls == ["hatch", "acquire"], "acquire cut-in must advance after hatch break completes")
	_expect(runtime.last_delta == delta and runtime.last_registry == registry, "acquire advance must receive delta and registry")
	_expect(owner.redraw_requests == 2, "acquire advance must request one redraw")

	runtime.acquire_active = false
	_expect(
		bool(coordinator.process_ungated(delta, owner, registry, getter)),
		"active overflow choice must consume the idle frame"
	)
	_expect(runtime.calls == ["hatch", "acquire"], "overflow choice must hold without advancing a clock")
	_expect(owner.redraw_requests == 3, "overflow choice must keep repainting while it waits")

	runtime.overflow_active = false
	_expect(
		not bool(coordinator.process_ungated(delta, owner, registry, getter)),
		"inactive Lingpet modal states must release the idle frame"
	)
	_expect(owner.redraw_requests == 3, "inactive states must not request redraw")

	holder.runtime = null
	_expect(
		not bool(coordinator.process_ungated(delta, owner, registry, getter)),
		"missing Lingpet runtime must be a no-op"
	)


func _verify_source_ownership() -> void:
	var coordinator_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_lingpet_ungated_idle_coordinator.gd"
	)
	var frame_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_frame_controller.gd"
	)
	_expect(coordinator_source.contains("is_hatch_break_active"), "coordinator must own hatch-break priority")
	_expect(coordinator_source.contains("advance_acquire_cutin"), "coordinator must own acquire cut-in advancement")
	_expect(coordinator_source.contains("is_overflow_choice_active"), "coordinator must own overflow hold")
	_expect(frame_source.contains("BattleLingpetUngatedIdleCoordinator.new()"), "frame controller must compose the Lingpet idle coordinator")
	_expect(frame_source.contains("LINGPET_UNGATED_IDLE_METHODS"), "frame controller must retain the dirty-smoke compatibility catalog")
	_expect(not frame_source.contains("var lingpet_acquire_runtime"), "frame controller must not retain Lingpet modal branching")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
