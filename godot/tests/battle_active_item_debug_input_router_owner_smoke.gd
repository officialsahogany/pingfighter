extends SceneTree

# expect-zero-object-leaks
const BattleActiveItemDebugInputRouter := preload(
	"res://scripts/core/battle_active_item_debug_input_router.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1


class FakeModernRuntime:
	extends RefCounted

	var handled_result := true
	var handle_count := 0
	var last_event: InputEvent = null
	var last_view_size := Vector2.ZERO
	var last_owner: Object = null
	var last_registry: Object = null

	func handle_debug_spawn_menu_input(
		event: InputEvent,
		view_size: Vector2,
		owner: Object,
		registry: Object
	) -> bool:
		handle_count += 1
		last_event = event
		last_view_size = view_size
		last_owner = owner
		last_registry = registry
		return handled_result


class FakeLegacyRuntime:
	extends RefCounted

	var handled_result := true
	var click_count := 0
	var last_position := Vector2.ZERO
	var last_view_size := Vector2.ZERO
	var last_owner: Object = null
	var last_registry: Object = null

	func handle_debug_spawn_menu_click(
		position: Vector2,
		view_size: Vector2,
		owner: Object,
		registry: Object
	) -> bool:
		click_count += 1
		last_position = position
		last_view_size = view_size
		last_owner = owner
		last_registry = registry
		return handled_result


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		return value as Object if value is Object else null


func _init() -> void:
	_verify_modern_input_forwards_full_context()
	_verify_unhandled_modern_input_falls_through()
	_verify_legacy_left_click_fallback()
	_verify_legacy_non_click_falls_through()
	_verify_missing_runtime_falls_through()
	_verify_source_ownership()
	call_deferred("_finish")


func _finish() -> void:
	if _failures.is_empty():
		print("battle_active_item_debug_input_router_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_modern_input_forwards_full_context() -> void:
	var holder := ModuleHolder.new()
	var runtime := FakeModernRuntime.new()
	var owner := FakeOwner.new()
	var registry := RefCounted.new()
	var event := InputEventMouseButton.new()
	var view_size := Vector2(1600.0, 900.0)
	holder.modules["active_item_runtime"] = runtime
	var handled: bool = BattleActiveItemDebugInputRouter.new().handle_input(
		event,
		owner,
		registry,
		Callable(holder, "get_module"),
		view_size
	)
	_expect(handled, "modern active-item debug input must return its handler result")
	_expect(runtime.handle_count == 1, "modern input handler must run once")
	_expect(runtime.last_event == event, "modern input handler must receive the original event")
	_expect(runtime.last_view_size == view_size, "modern input handler must receive current view size")
	_expect(runtime.last_owner == owner, "modern input handler must receive battle owner")
	_expect(runtime.last_registry == registry, "modern input handler must receive registry")
	_expect(owner.redraw_count == 1, "handled modern input must request one redraw")
	holder.modules.clear()


func _verify_unhandled_modern_input_falls_through() -> void:
	var holder := ModuleHolder.new()
	var runtime := FakeModernRuntime.new()
	var owner := FakeOwner.new()
	runtime.handled_result = false
	holder.modules["active_item_runtime"] = runtime
	var handled: bool = BattleActiveItemDebugInputRouter.new().handle_input(
		InputEventKey.new(),
		owner,
		holder,
		Callable(holder, "get_module"),
		Vector2(760.0, 750.0)
	)
	_expect(not handled, "unhandled modern debug input must fall through")
	_expect(runtime.handle_count == 1, "modern handler must still inspect the event")
	_expect(owner.redraw_count == 0, "unhandled modern input must not redraw")
	holder.modules.clear()


func _verify_legacy_left_click_fallback() -> void:
	var holder := ModuleHolder.new()
	var runtime := FakeLegacyRuntime.new()
	var owner := FakeOwner.new()
	var registry := RefCounted.new()
	var click := InputEventMouseButton.new()
	var view_size := Vector2(1280.0, 720.0)
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(420.0, 315.0)
	holder.modules["active_item_runtime"] = runtime
	var handled: bool = BattleActiveItemDebugInputRouter.new().handle_input(
		click,
		owner,
		registry,
		Callable(holder, "get_module"),
		view_size
	)
	_expect(handled, "legacy left-click handler must remain supported")
	_expect(runtime.click_count == 1, "legacy click handler must run once")
	_expect(runtime.last_position == click.position, "legacy click handler must receive click position")
	_expect(runtime.last_view_size == view_size, "legacy click handler must receive current view size")
	_expect(runtime.last_owner == owner, "legacy click handler must receive battle owner")
	_expect(runtime.last_registry == registry, "legacy click handler must receive registry")
	_expect(owner.redraw_count == 1, "handled legacy click must request one redraw")
	holder.modules.clear()


func _verify_legacy_non_click_falls_through() -> void:
	var holder := ModuleHolder.new()
	var runtime := FakeLegacyRuntime.new()
	var owner := FakeOwner.new()
	holder.modules["active_item_runtime"] = runtime
	var right_click := InputEventMouseButton.new()
	right_click.pressed = true
	right_click.button_index = MOUSE_BUTTON_RIGHT
	var handled: bool = BattleActiveItemDebugInputRouter.new().handle_input(
		right_click,
		owner,
		holder,
		Callable(holder, "get_module"),
		Vector2(760.0, 750.0)
	)
	_expect(not handled, "legacy fallback must ignore non-left clicks")
	_expect(runtime.click_count == 0, "ignored legacy input must not call click handler")
	_expect(owner.redraw_count == 0, "ignored legacy input must not redraw")
	holder.modules.clear()


func _verify_missing_runtime_falls_through() -> void:
	var holder := ModuleHolder.new()
	var handled: bool = BattleActiveItemDebugInputRouter.new().handle_input(
		InputEventKey.new(),
		FakeOwner.new(),
		holder,
		Callable(holder, "get_module"),
		Vector2(760.0, 750.0)
	)
	_expect(not handled, "missing active-item runtime must fall through")


func _verify_source_ownership() -> void:
	var router_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_active_item_debug_input_router.gd"
	)
	var input_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_overlay_input_controller.gd"
	)
	_expect(router_source.contains("handle_debug_spawn_menu_input"), "router must own modern F2 input dispatch")
	_expect(router_source.contains("handle_debug_spawn_menu_click"), "router must own legacy click fallback")
	_expect(input_source.contains("BattleActiveItemDebugInputRouter.new()"), "overlay controller must compose the F2 router")
	_expect(input_source.contains("_active_item_debug_input_router.handle_input("), "overlay controller must delegate F2 input")
	_expect(not input_source.contains("func _handle_active_item_debug_input"), "overlay controller must not retain F2 dispatch policy")
	_expect(not input_source.contains("handle_debug_spawn_menu_click"), "overlay controller must not retain legacy click fallback")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
