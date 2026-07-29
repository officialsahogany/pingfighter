extends SceneTree

# expect-zero-object-leaks
const BattleLingpetInteractionInputRouter := preload(
	"res://scripts/core/battle_lingpet_interaction_input_router.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 900.0))


class FakeLingpetRuntime:
	extends RefCounted

	var acquire_active := false
	var hatch_break_active := false
	var click_accept := true
	var cycle_accept := true
	var click_positions: Array[Vector2] = []
	var cycle_directions: Array[int] = []

	func is_acquire_cutin_active() -> bool:
		return acquire_active

	func is_hatch_break_active() -> bool:
		return hatch_break_active

	func try_begin_companion_click_reaction(
		playfield_pos: Vector2,
		_registry: Object = null
	) -> bool:
		click_positions.append(playfield_pos)
		return click_accept

	func cycle_lingpet_slot(
		direction: int,
		_owner: Object,
		_registry: Object
	) -> bool:
		cycle_directions.append(direction)
		return cycle_accept


class FakeOverlayInput:
	extends RefCounted

	var handle_count := 0

	func handle_input(
		_event: InputEvent,
		_owner: Object,
		_registry: Object,
		_module_getter: Callable,
		_context: Dictionary
	) -> bool:
		handle_count += 1
		return true


class FakeViewLayout:
	extends RefCounted

	func build_game_layout(
		view_size: Vector2,
		_game_width: float,
		_game_height: float
	) -> Dictionary:
		return {
			"view_size": view_size,
			"game_offset": Vector2(260.0, 75.0),
			"game_size": Vector2(760.0, 750.0),
			"render_scale": 1.0,
		}


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		return value as Object if value is Object else null


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if value is Object else null


func _init() -> void:
	_verify_hatch_break_and_acquire_priority()
	_verify_companion_click_coordinates_and_priority()
	_verify_slot_cycle_directions()
	_verify_source_ownership()
	call_deferred("_finish")


func _finish() -> void:
	if _failures.is_empty():
		print("battle_lingpet_interaction_input_router_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_hatch_break_and_acquire_priority() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var registry: FakeRegistry = fixture["registry"]
	var runtime: FakeLingpetRuntime = fixture["runtime"]
	var overlay: FakeOverlayInput = fixture["overlay"]
	var owner := FakeOwner.new()
	var router := BattleLingpetInteractionInputRouter.new()
	runtime.hatch_break_active = true
	_expect(
		router.handle_priority_cutin_input(
			InputEventKey.new(),
			owner,
			registry,
			Callable(holder, "get_module")
		),
		"hatch-break beat must swallow input"
	)
	_expect(overlay.handle_count == 0, "hatch break must not forward to overlay input")
	runtime.hatch_break_active = false
	runtime.acquire_active = true
	_expect(
		router.handle_priority_cutin_input(
			InputEventKey.new(),
			owner,
			registry,
			Callable(holder, "get_module")
		),
		"active acquisition cut-in must consume input"
	)
	_expect(overlay.handle_count == 1, "active acquisition cut-in must forward to overlay input once")
	runtime.acquire_active = false
	_expect(
		not router.handle_priority_cutin_input(
			InputEventKey.new(),
			owner,
			registry,
			Callable(holder, "get_module")
		),
		"inactive acquisition cut-in must fall through"
	)
	_clear_fixture(fixture)


func _verify_companion_click_coordinates_and_priority() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var registry: FakeRegistry = fixture["registry"]
	var runtime: FakeLingpetRuntime = fixture["runtime"]
	var owner := FakeOwner.new()
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(510.0, 320.0)
	_expect(
		BattleLingpetInteractionInputRouter.new().handle_companion_input(
			event,
			owner,
			registry,
			Callable(holder, "get_module")
		),
		"accepted companion click must be consumed"
	)
	_expect(runtime.click_positions == [Vector2(250.0, 245.0)], "screen click must convert to playfield coordinates")
	_expect(runtime.cycle_directions.is_empty(), "mouse click must not enter slot cycling")
	_expect(owner.redraw_count == 1, "accepted companion click must redraw once")
	_clear_fixture(fixture)


func _verify_slot_cycle_directions() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var registry: FakeRegistry = fixture["registry"]
	var runtime: FakeLingpetRuntime = fixture["runtime"]
	var owner := FakeOwner.new()
	var router := BattleLingpetInteractionInputRouter.new()
	_expect(router.handle_companion_input(_key_event(KEY_L), owner, registry, Callable(holder, "get_module")), "L must cycle forward")
	_expect(router.handle_companion_input(_key_event(KEY_L, true), owner, registry, Callable(holder, "get_module")), "Shift+L must cycle backward")
	_expect(runtime.cycle_directions == [1, -1], "slot cycle directions must preserve L/Shift+L policy")
	_clear_fixture(fixture)


func _verify_source_ownership() -> void:
	var router_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_lingpet_interaction_input_router.gd"
	)
	var input_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_input_controller.gd"
	)
	var retired_interact_constant := "LINGPET_" + "INTERACT"
	var retired_runtime_handoff := "try_begin_companion_" + "interact_reaction"
	_expect(router_source.contains("try_begin_companion_click_reaction(playfield_pos, registry)"), "lingpet router must own click coordinate handoff")
	_expect(router_source.contains("cycle_lingpet_slot(cycle_direction, owner, registry)"), "lingpet router must own slot cycling")
	_expect(not router_source.contains(retired_interact_constant), "retired E/RT interact constants must not remain in the lingpet router")
	_expect(not router_source.contains(retired_runtime_handoff), "retired E/RT runtime handoff must not remain in the lingpet router")
	_expect(input_source.contains("BattleLingpetInteractionInputRouter.new()"), "scene input controller must compose lingpet router")
	_expect(input_source.contains("_lingpet_input_router.handle_priority_cutin_input("), "scene input controller must delegate priority cut-in input")
	_expect(input_source.contains("_lingpet_input_router.handle_companion_input("), "scene input controller must delegate companion input")
	_expect(input_source.find("_lingpet_input_router.handle_priority_cutin_input(") < input_source.find("_terminal_input_router.handle_input("), "acquisition cut-in must stay before defeat overlays")
	_expect(input_source.find("_handle_active_item_hud_input(") < input_source.find("_lingpet_input_router.handle_companion_input("), "companion input must stay after active-item HUD input")
	_expect(not input_source.contains("func _get_lingpet_cycle_direction"), "scene input controller must not retain slot-cycle policy")
	_expect(not input_source.contains(retired_interact_constant), "scene input controller must not re-expose retired E/RT constants")


func _build_fixture() -> Dictionary:
	var holder := ModuleHolder.new()
	var registry := FakeRegistry.new()
	var runtime := FakeLingpetRuntime.new()
	var overlay := FakeOverlayInput.new()
	holder.modules = {
		"lingpet_egg_runtime": runtime,
		"battle_scene_overlay_input_controller": overlay,
		"battle_view_layout": FakeViewLayout.new(),
	}
	return {
		"holder": holder,
		"registry": registry,
		"runtime": runtime,
		"overlay": overlay,
	}


func _clear_fixture(fixture: Dictionary) -> void:
	var holder: ModuleHolder = fixture["holder"]
	holder.modules.clear()
	var registry: FakeRegistry = fixture["registry"]
	registry.instances.clear()
	fixture.clear()


func _key_event(keycode: Key, shift_pressed: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	event.shift_pressed = shift_pressed
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
