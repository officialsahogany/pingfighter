extends SceneTree

# expect-zero-object-leaks
const BattleLingpetPriorityInputRouter := preload(
	"res://scripts/core/battle_lingpet_priority_input_router.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1


class FakeModalGate:
	extends RefCounted

	var acquire_active := false
	var overflow_active := false

	func is_lingpet_acquire_cutin_active(_module_getter: Callable) -> bool:
		return acquire_active

	func is_lingpet_overflow_choice_active(_module_getter: Callable) -> bool:
		return overflow_active


class FakeLingpetRuntime:
	extends RefCounted

	var awaiting_dismiss := false
	var dismiss_result := true
	var dismiss_count := 0
	var last_registry: Object = null

	func is_acquire_cutin_awaiting_dismiss() -> bool:
		return awaiting_dismiss

	func begin_acquire_cutin_dismiss(registry: Object) -> bool:
		dismiss_count += 1
		last_registry = registry
		return dismiss_result


class FakeOverflowHost:
	extends RefCounted

	var handled_result := true
	var handle_count := 0
	var last_event: InputEvent = null
	var last_runtime: Object = null
	var last_owner: Object = null
	var last_registry: Object = null
	var last_view_size := Vector2.ZERO

	func handle_input(
		event: InputEvent,
		runtime: Object,
		owner: Object,
		registry: Object,
		view_size: Vector2
	) -> bool:
		handle_count += 1
		last_event = event
		last_runtime = runtime
		last_owner = owner
		last_registry = registry
		last_view_size = view_size
		return handled_result


class FakeRegistry:
	extends RefCounted

	var cached_instances: Dictionary = {}
	var instances: Dictionary = {}
	var cached_reads: Array[String] = []
	var instance_reads: Array[String] = []

	func get_cached_instance(key: String) -> Object:
		cached_reads.append(key)
		var value: Variant = cached_instances.get(key, null)
		return value as Object if value is Object else null

	func get_instance(key: String) -> Object:
		instance_reads.append(key)
		var value: Variant = instances.get(key, null)
		return value as Object if value is Object else null


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		return value as Object if value is Object else null


func _init() -> void:
	_verify_acquire_confirm_starts_dismiss()
	_verify_acquire_swallows_before_reveal_finishes()
	_verify_acquire_has_priority_over_overflow()
	_verify_overflow_dispatches_through_registry_fallback()
	_verify_unhandled_overflow_still_consumes_modal_input()
	_verify_inactive_routes_fall_through()
	_verify_source_ownership()
	call_deferred("_finish")


func _finish() -> void:
	if _failures.is_empty():
		print("battle_lingpet_priority_input_router_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_acquire_confirm_starts_dismiss() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var gate: FakeModalGate = fixture["gate"]
	var runtime: FakeLingpetRuntime = fixture["runtime"]
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	gate.acquire_active = true
	runtime.awaiting_dismiss = true
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	var consumed: bool = BattleLingpetPriorityInputRouter.new().handle_input(
		click,
		owner,
		registry,
		Callable(holder, "get_module"),
		Vector2(1280.0, 720.0)
	)
	_expect(consumed, "active acquisition cut-in must consume input")
	_expect(runtime.dismiss_count == 1, "confirm input must start cut-in dismissal once")
	_expect(runtime.last_registry == registry, "dismissal must receive the live registry for click audio")
	_expect(owner.redraw_count == 1, "successful dismissal must request one redraw")
	_clear_fixture(fixture, registry)


func _verify_acquire_swallows_before_reveal_finishes() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var gate: FakeModalGate = fixture["gate"]
	var runtime: FakeLingpetRuntime = fixture["runtime"]
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	gate.acquire_active = true
	runtime.awaiting_dismiss = false
	var consumed: bool = BattleLingpetPriorityInputRouter.new().handle_input(
		InputEventKey.new(),
		owner,
		registry,
		Callable(holder, "get_module"),
		Vector2(760.0, 750.0)
	)
	_expect(consumed, "cut-in must swallow input while reveal animation is still playing")
	_expect(runtime.dismiss_count == 0, "input before dismiss-ready state must not start dismissal")
	_expect(owner.redraw_count == 0, "ignored reveal-phase input must not redraw")
	_clear_fixture(fixture, registry)


func _verify_acquire_has_priority_over_overflow() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var gate: FakeModalGate = fixture["gate"]
	var registry := FakeRegistry.new()
	var overflow_host := FakeOverflowHost.new()
	registry.instances["lingpet_overflow_choice_overlay_host"] = overflow_host
	gate.acquire_active = true
	gate.overflow_active = true
	var consumed: bool = BattleLingpetPriorityInputRouter.new().handle_input(
		InputEventMouseMotion.new(),
		FakeOwner.new(),
		registry,
		Callable(holder, "get_module"),
		Vector2(1280.0, 720.0)
	)
	_expect(consumed, "acquisition cut-in must consume when both lingpet modals report active")
	_expect(overflow_host.handle_count == 0, "acquisition cut-in must outrank overflow-choice input")
	_clear_fixture(fixture, registry)


func _verify_overflow_dispatches_through_registry_fallback() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var gate: FakeModalGate = fixture["gate"]
	var runtime: FakeLingpetRuntime = fixture["runtime"]
	var registry := FakeRegistry.new()
	var overflow_host := FakeOverflowHost.new()
	var owner := FakeOwner.new()
	var event := InputEventMouseMotion.new()
	var view_size := Vector2(1600.0, 900.0)
	registry.instances["lingpet_overflow_choice_overlay_host"] = overflow_host
	gate.overflow_active = true
	var consumed: bool = BattleLingpetPriorityInputRouter.new().handle_input(
		event,
		owner,
		registry,
		Callable(holder, "get_module"),
		view_size
	)
	_expect(consumed, "active overflow choice must consume input")
	_expect(overflow_host.handle_count == 1, "overflow host must receive the event once")
	_expect(overflow_host.last_event == event, "overflow host must receive the original event")
	_expect(overflow_host.last_runtime == runtime, "overflow host must receive lingpet runtime")
	_expect(overflow_host.last_owner == owner, "overflow host must receive battle owner")
	_expect(overflow_host.last_registry == registry, "overflow host must receive registry")
	_expect(overflow_host.last_view_size == view_size, "overflow host must receive current view size")
	_expect(registry.cached_reads == ["lingpet_overflow_choice_overlay_host"], "overflow host lookup must check cache first")
	_expect(registry.instance_reads == ["lingpet_overflow_choice_overlay_host"], "overflow host lookup must fall back to normal registry resolution")
	_expect(owner.redraw_count == 1, "handled overflow input must request one redraw")
	_clear_fixture(fixture, registry)


func _verify_unhandled_overflow_still_consumes_modal_input() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var gate: FakeModalGate = fixture["gate"]
	var registry := FakeRegistry.new()
	var overflow_host := FakeOverflowHost.new()
	var owner := FakeOwner.new()
	overflow_host.handled_result = false
	registry.cached_instances["lingpet_overflow_choice_overlay_host"] = overflow_host
	gate.overflow_active = true
	var consumed: bool = BattleLingpetPriorityInputRouter.new().handle_input(
		InputEventKey.new(),
		owner,
		registry,
		Callable(holder, "get_module"),
		Vector2(760.0, 750.0)
	)
	_expect(consumed, "active overflow modal must swallow unhandled local input")
	_expect(overflow_host.handle_count == 1, "overflow host must still see unhandled input")
	_expect(registry.instance_reads.is_empty(), "valid cached host must avoid fallback lookup")
	_expect(owner.redraw_count == 0, "unhandled overflow input must not redraw")
	_clear_fixture(fixture, registry)


func _verify_inactive_routes_fall_through() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var registry := FakeRegistry.new()
	var consumed: bool = BattleLingpetPriorityInputRouter.new().handle_input(
		InputEventKey.new(),
		FakeOwner.new(),
		registry,
		Callable(holder, "get_module"),
		Vector2(760.0, 750.0)
	)
	_expect(not consumed, "router must fall through when neither priority lingpet modal is active")
	_expect(registry.cached_reads.is_empty(), "inactive routes must not resolve the overflow host")
	_clear_fixture(fixture, registry)


func _verify_source_ownership() -> void:
	var router_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_lingpet_priority_input_router.gd"
	)
	var input_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_overlay_input_controller.gd"
	)
	_expect(router_source.contains("is_acquire_cutin_awaiting_dismiss"), "router must own dismiss-ready gating")
	_expect(router_source.contains("begin_acquire_cutin_dismiss(registry)"), "router must own dismissal dispatch with registry")
	_expect(router_source.contains("lingpet_overflow_choice_overlay_host"), "router must own overflow-host resolution")
	_expect(input_source.contains("BattleLingpetPriorityInputRouter.new()"), "overlay controller must compose the priority router")
	_expect(input_source.contains("_lingpet_priority_input_router.handle_input("), "overlay controller must delegate priority input")
	_expect(not input_source.contains("begin_acquire_cutin_dismiss"), "overlay controller must not retain cut-in dismissal dispatch")
	_expect(not input_source.contains("lingpet_overflow_choice_overlay_host"), "overlay controller must not retain overflow-host dispatch")


func _build_fixture() -> Dictionary:
	var holder := ModuleHolder.new()
	var gate := FakeModalGate.new()
	var runtime := FakeLingpetRuntime.new()
	holder.modules = {
		"battle_scene_modal_gate_controller": gate,
		"lingpet_egg_runtime": runtime,
	}
	return {
		"holder": holder,
		"gate": gate,
		"runtime": runtime,
	}


func _clear_fixture(fixture: Dictionary, registry: FakeRegistry) -> void:
	var holder: ModuleHolder = fixture["holder"]
	holder.modules.clear()
	registry.cached_instances.clear()
	registry.instances.clear()
	fixture.clear()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
