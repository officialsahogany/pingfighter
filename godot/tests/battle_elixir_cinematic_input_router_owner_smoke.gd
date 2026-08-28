extends SceneTree

# expect-zero-object-leaks
const BattleElixirCinematicInputRouter := preload(
	"res://scripts/core/battle_elixir_cinematic_input_router.gd"
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

	func is_elixir_cinematic_active(_module_getter: Callable) -> bool:
		return active


class FakeActiveItemRuntime:
	extends RefCounted

	var confirm_result := true
	var confirm_count := 0

	func handle_elixir_confirm() -> bool:
		confirm_count += 1
		return confirm_result


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		return value as Object if value is Object else null


func _init() -> void:
	_verify_inactive_cinematic_falls_through()
	_verify_active_cinematic_swallows_non_confirm_input()
	_verify_keyboard_mouse_and_gamepad_confirm_events()
	_verify_unsuccessful_confirm_does_not_redraw()
	_verify_source_ownership()
	call_deferred("_finish")


func _finish() -> void:
	if _failures.is_empty():
		print("battle_elixir_cinematic_input_router_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_inactive_cinematic_falls_through() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	_expect(
		not BattleElixirCinematicInputRouter.new().handle_input(
			InputEventKey.new(),
			FakeOwner.new(),
			Callable(holder, "get_module")
		),
		"inactive elixir cinematic must fall through"
	)
	_clear_fixture(fixture)


func _verify_active_cinematic_swallows_non_confirm_input() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var gate: FakeModalGate = fixture["gate"]
	var runtime: FakeActiveItemRuntime = fixture["runtime"]
	var owner := FakeOwner.new()
	gate.active = true
	_expect(
		BattleElixirCinematicInputRouter.new().handle_input(
			InputEventMouseMotion.new(),
			owner,
			Callable(holder, "get_module")
		),
		"active elixir cinematic must swallow non-confirm input"
	)
	_expect(runtime.confirm_count == 0, "non-confirm input must not advance elixir cinematic")
	_expect(owner.redraw_count == 0, "non-confirm input must not redraw")
	_clear_fixture(fixture)


func _verify_keyboard_mouse_and_gamepad_confirm_events() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var gate: FakeModalGate = fixture["gate"]
	var runtime: FakeActiveItemRuntime = fixture["runtime"]
	var owner := FakeOwner.new()
	gate.active = true
	var events: Array[InputEvent] = []
	var space_event := InputEventKey.new()
	space_event.pressed = true
	space_event.keycode = KEY_SPACE
	events.append(space_event)
	var enter_event := InputEventKey.new()
	enter_event.pressed = true
	enter_event.physical_keycode = KEY_ENTER
	events.append(enter_event)
	var mouse_event := InputEventMouseButton.new()
	mouse_event.pressed = true
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	events.append(mouse_event)
	var gamepad_event := InputEventJoypadButton.new()
	gamepad_event.pressed = true
	gamepad_event.button_index = JOY_BUTTON_A
	events.append(gamepad_event)
	var router := BattleElixirCinematicInputRouter.new()
	for event in events:
		_expect(
			router.handle_input(event, owner, Callable(holder, "get_module")),
			"active elixir confirm event must be consumed"
		)
	_expect(runtime.confirm_count == events.size(), "all supported confirm inputs must advance the cinematic")
	_expect(owner.redraw_count == events.size(), "successful confirms must redraw once each")
	_clear_fixture(fixture)


func _verify_unsuccessful_confirm_does_not_redraw() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var gate: FakeModalGate = fixture["gate"]
	var runtime: FakeActiveItemRuntime = fixture["runtime"]
	var owner := FakeOwner.new()
	gate.active = true
	runtime.confirm_result = false
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_SPACE
	_expect(
		BattleElixirCinematicInputRouter.new().handle_input(
			event,
			owner,
			Callable(holder, "get_module")
		),
		"active cinematic must consume an unsuccessful confirm"
	)
	_expect(runtime.confirm_count == 1, "unsuccessful confirm must still reach runtime once")
	_expect(owner.redraw_count == 0, "unsuccessful confirm must not redraw")
	_clear_fixture(fixture)


func _verify_source_ownership() -> void:
	var router_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_elixir_cinematic_input_router.gd"
	)
	var input_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_overlay_input_controller.gd"
	)
	_expect(router_source.contains("GamepadInput.is_confirm_event(event)"), "elixir router must own gamepad confirm policy")
	_expect(router_source.contains("handle_elixir_confirm()"), "elixir router must own runtime confirm dispatch")
	_expect(input_source.contains("BattleElixirCinematicInputRouter.new()"), "overlay controller must compose elixir router")
	_expect(input_source.contains("_elixir_cinematic_input_router.handle_input("), "overlay controller must delegate elixir input")
	_expect(not input_source.contains("func _is_elixir_confirm_event"), "overlay controller must not retain elixir event policy")
	_expect(not input_source.contains("handle_elixir_confirm()"), "overlay controller must not retain elixir runtime dispatch")
	_expect(not input_source.contains("func _debug_cycle_weather_event"), "overlay controller must drop uncalled weather compatibility wrapper")


func _build_fixture() -> Dictionary:
	var holder := ModuleHolder.new()
	var gate := FakeModalGate.new()
	var runtime := FakeActiveItemRuntime.new()
	holder.modules = {
		"battle_scene_modal_gate_controller": gate,
		"active_item_runtime": runtime,
	}
	return {
		"holder": holder,
		"gate": gate,
		"runtime": runtime,
	}


func _clear_fixture(fixture: Dictionary) -> void:
	var holder: ModuleHolder = fixture["holder"]
	holder.modules.clear()
	fixture.clear()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
