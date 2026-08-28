extends SceneTree

# expect-zero-object-leaks
const BattleGuidedOverlayInputRouter := preload(
	"res://scripts/core/battle_guided_overlay_input_router.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1


class FakeModalGate:
	extends RefCounted

	var grip_active := false
	var tutorial_active := false

	func is_grip_style_selection_active(_module_getter: Callable) -> bool:
		return grip_active

	func is_skill_orb_tooltip_tutorial_active(_module_getter: Callable) -> bool:
		return tutorial_active


class FakeOverlay:
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


func _init() -> void:
	_verify_grip_outranks_tutorial()
	_verify_tutorial_consumes_even_when_locally_unhandled()
	_verify_inactive_overlays_fall_through()
	_verify_source_ownership()
	call_deferred("_finish")


func _finish() -> void:
	if _failures.is_empty():
		print("battle_guided_overlay_input_router_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_grip_outranks_tutorial() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var gate: FakeModalGate = fixture["gate"]
	var grip: FakeOverlay = fixture["grip"]
	var tutorial: FakeOverlay = fixture["tutorial"]
	var owner := FakeOwner.new()
	var registry := RefCounted.new()
	var event := InputEventMouseButton.new()
	gate.grip_active = true
	gate.tutorial_active = true
	grip.handle_result = true
	var consumed: bool = BattleGuidedOverlayInputRouter.new().handle_input(
		event,
		owner,
		registry,
		Callable(holder, "get_module"),
		Vector2(1280.0, 720.0)
	)
	_expect(consumed, "active grip selection must consume input")
	_expect(grip.handle_count == 1, "grip selection must receive input once")
	_expect(tutorial.handle_count == 0, "grip selection must outrank skill tutorial")
	_expect(grip.last_event == event, "grip selection must receive original event")
	_expect(grip.last_owner == owner, "grip selection must receive battle owner")
	_expect(grip.last_registry == registry, "grip selection must receive registry")
	_expect(grip.last_view_size == Vector2(1280.0, 720.0), "grip selection must receive live view size")
	_expect(owner.redraw_count == 1, "handled grip input must redraw once")
	_clear_fixture(fixture)


func _verify_tutorial_consumes_even_when_locally_unhandled() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var gate: FakeModalGate = fixture["gate"]
	var tutorial: FakeOverlay = fixture["tutorial"]
	var owner := FakeOwner.new()
	gate.tutorial_active = true
	tutorial.handle_result = false
	var consumed: bool = BattleGuidedOverlayInputRouter.new().handle_input(
		InputEventMouseMotion.new(),
		owner,
		holder,
		Callable(holder, "get_module"),
		Vector2(760.0, 750.0)
	)
	_expect(consumed, "active tutorial must swallow locally unhandled input")
	_expect(tutorial.handle_count == 1, "active tutorial must receive input once")
	_expect(owner.redraw_count == 0, "locally unhandled tutorial input must not redraw")
	_clear_fixture(fixture)


func _verify_inactive_overlays_fall_through() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	_expect(
		not BattleGuidedOverlayInputRouter.new().handle_input(
			InputEventKey.new(),
			FakeOwner.new(),
			holder,
			Callable(holder, "get_module"),
			Vector2(760.0, 750.0)
		),
		"inactive guided overlays must fall through"
	)
	_clear_fixture(fixture)


func _verify_source_ownership() -> void:
	var router_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_guided_overlay_input_router.gd"
	)
	var input_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_overlay_input_controller.gd"
	)
	_expect(router_source.contains("is_grip_style_selection_active"), "guided router must own grip modal gating")
	_expect(router_source.contains("is_skill_orb_tooltip_tutorial_active"), "guided router must own tutorial modal gating")
	_expect(router_source.find("grip_style_selection_overlay") < router_source.find("skill_orb_tooltip_tutorial_hint"), "guided router must preserve grip-before-tutorial priority")
	_expect(input_source.contains("BattleGuidedOverlayInputRouter.new()"), "overlay controller must compose guided router")
	_expect(input_source.contains("_guided_overlay_input_router.handle_input("), "overlay controller must delegate guided modal input")
	_expect(not input_source.contains("handled_grip"), "overlay controller must not retain grip dispatch")
	_expect(not input_source.contains("handled_skill_tutorial"), "overlay controller must not retain tutorial dispatch")


func _build_fixture() -> Dictionary:
	var holder := ModuleHolder.new()
	var gate := FakeModalGate.new()
	var grip := FakeOverlay.new()
	var tutorial := FakeOverlay.new()
	holder.modules = {
		"battle_scene_modal_gate_controller": gate,
		"grip_style_selection_overlay": grip,
		"skill_orb_tooltip_tutorial_hint": tutorial,
	}
	return {
		"holder": holder,
		"gate": gate,
		"grip": grip,
		"tutorial": tutorial,
	}


func _clear_fixture(fixture: Dictionary) -> void:
	var holder: ModuleHolder = fixture["holder"]
	holder.modules.clear()
	fixture.clear()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
