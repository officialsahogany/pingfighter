extends SceneTree

# expect-zero-object-leaks
const BattleRuntimePerkInputRouter := preload(
	"res://scripts/core/battle_runtime_perk_input_router.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1


class FakeModalGate:
	extends RefCounted

	var active := false

	func is_runtime_perk_choice_active(_module_getter: Callable) -> bool:
		return active


class FakeRuntimePerkState:
	extends RefCounted

	var handle_result := false
	var handle_count := 0
	var last_event: InputEvent = null
	var last_owner: Object = null
	var last_registry: Object = null
	var last_view_size := Vector2.ZERO

	func handle_input(
		event: InputEvent,
		owner: Object,
		registry: Object,
		view_size: Vector2
	) -> bool:
		handle_count += 1
		last_event = event
		last_owner = owner
		last_registry = registry
		last_view_size = view_size
		return handle_result


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		return value as Object if value is Object else null


class CallbackProbe:
	extends RefCounted

	var call_count := 0

	func collect_star_point() -> void:
		call_count += 1


func _init() -> void:
	_verify_active_choice_forwards_and_redraws()
	_verify_active_choice_swallows_locally_unhandled_input()
	_verify_inactive_choice_falls_through()
	_verify_f8_debug_grant_and_key_edges()
	_verify_source_ownership()
	call_deferred("_finish")


func _finish() -> void:
	if _failures.is_empty():
		print("battle_runtime_perk_input_router_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_active_choice_forwards_and_redraws() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var gate: FakeModalGate = fixture["gate"]
	var state: FakeRuntimePerkState = fixture["state"]
	var owner := FakeOwner.new()
	var registry := RefCounted.new()
	var event := InputEventMouseButton.new()
	gate.active = true
	state.handle_result = true
	var consumed: bool = BattleRuntimePerkInputRouter.new().handle_active_choice_input(
		event,
		owner,
		registry,
		Callable(holder, "get_module"),
		Vector2(1280.0, 720.0)
	)
	_expect(consumed, "active runtime perk choice must consume input")
	_expect(state.handle_count == 1, "active runtime perk state must receive input once")
	_expect(state.last_event == event, "runtime perk state must receive original event")
	_expect(state.last_owner == owner, "runtime perk state must receive battle owner")
	_expect(state.last_registry == registry, "runtime perk state must receive registry")
	_expect(state.last_view_size == Vector2(1280.0, 720.0), "runtime perk state must receive live view size")
	_expect(owner.redraw_count == 1, "handled runtime perk input must redraw once")
	_clear_fixture(fixture)


func _verify_active_choice_swallows_locally_unhandled_input() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var gate: FakeModalGate = fixture["gate"]
	var state: FakeRuntimePerkState = fixture["state"]
	var owner := FakeOwner.new()
	gate.active = true
	state.handle_result = false
	_expect(
		BattleRuntimePerkInputRouter.new().handle_active_choice_input(
			InputEventMouseMotion.new(),
			owner,
			holder,
			Callable(holder, "get_module"),
			Vector2(760.0, 750.0)
		),
		"active runtime perk choice must swallow locally unhandled input"
	)
	_expect(state.handle_count == 1, "locally unhandled input must still reach runtime state")
	_expect(owner.redraw_count == 0, "locally unhandled runtime perk input must not redraw")
	_clear_fixture(fixture)


func _verify_inactive_choice_falls_through() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	_expect(
		not BattleRuntimePerkInputRouter.new().handle_active_choice_input(
			InputEventKey.new(),
			FakeOwner.new(),
			holder,
			Callable(holder, "get_module"),
			Vector2(760.0, 750.0)
		),
		"inactive runtime perk choice must fall through"
	)
	_clear_fixture(fixture)


func _verify_f8_debug_grant_and_key_edges() -> void:
	var router := BattleRuntimePerkInputRouter.new()
	var owner := FakeOwner.new()
	var probe := CallbackProbe.new()
	var context := {"collect_star_point": Callable(probe, "collect_star_point")}
	var f8_event := InputEventKey.new()
	f8_event.pressed = true
	f8_event.physical_keycode = KEY_F8
	_expect(router.handle_debug_grant_input(f8_event, owner, context), "physical F8 must be consumed")
	_expect(probe.call_count == 1, "F8 must invoke starpoint callback once")
	_expect(owner.redraw_count == 1, "F8 grant must redraw once")
	var echo_event := InputEventKey.new()
	echo_event.pressed = true
	echo_event.echo = true
	echo_event.keycode = KEY_F8
	_expect(not router.handle_debug_grant_input(echo_event, owner, context), "echoed F8 must fall through")
	var f9_event := InputEventKey.new()
	f9_event.pressed = true
	f9_event.keycode = KEY_F9
	_expect(not router.handle_debug_grant_input(f9_event, owner, context), "non-F8 keys must fall through")


func _verify_source_ownership() -> void:
	var router_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_runtime_perk_input_router.gd"
	)
	var input_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_overlay_input_controller.gd"
	)
	_expect(router_source.contains("is_runtime_perk_choice_active"), "runtime perk router must own modal gating")
	_expect(router_source.contains("collect_star_point"), "runtime perk router must own F8 callback dispatch")
	_expect(input_source.contains("BattleRuntimePerkInputRouter.new()"), "overlay controller must compose runtime perk router")
	_expect(input_source.contains("_runtime_perk_input_router.handle_active_choice_input("), "overlay controller must delegate active choice input")
	_expect(input_source.contains("_runtime_perk_input_router.handle_debug_grant_input("), "overlay controller must delegate F8 input")
	_expect(not input_source.contains("runtime_perk_state.handle_input"), "overlay controller must not retain choice dispatch")
	_expect(not input_source.contains("_call_context(context, \"collect_star_point\")"), "overlay controller must not retain F8 callback dispatch")


func _build_fixture() -> Dictionary:
	var holder := ModuleHolder.new()
	var gate := FakeModalGate.new()
	var state := FakeRuntimePerkState.new()
	holder.modules = {
		"battle_scene_modal_gate_controller": gate,
		"runtime_perk_state": state,
	}
	return {
		"holder": holder,
		"gate": gate,
		"state": state,
	}


func _clear_fixture(fixture: Dictionary) -> void:
	var holder: ModuleHolder = fixture["holder"]
	holder.modules.clear()
	fixture.clear()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
