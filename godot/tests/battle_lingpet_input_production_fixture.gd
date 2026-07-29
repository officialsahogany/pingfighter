extends RefCounted

const BattleSceneInputController := preload(
	"res://scripts/core/battle_scene_input_controller.gd"
)


class FakeOwner:
	extends RefCounted

	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 900.0))

	func get_viewport() -> Viewport:
		return null


class FakeLingpetRuntime:
	extends RefCounted

	var acquire_active := false
	var hatch_break_active := false
	var click_positions: Array[Vector2] = []

	func is_acquire_cutin_active() -> bool:
		return acquire_active

	func is_hatch_break_active() -> bool:
		return hatch_break_active

	func try_begin_companion_click_reaction(
		playfield_pos: Vector2,
		_registry: Object = null
	) -> bool:
		click_positions.append(playfield_pos)
		return true

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
		return false


class FakeReadiness:
	extends RefCounted

	func is_intro_or_warmup_blocking(
		_module_getter: Callable,
		_battle_initialized: bool,
		_stage_landing_intro_started: bool
	) -> bool:
		return false


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


class FakeTerminalScreen:
	extends RefCounted

	var active := false
	var handle_count := 0

	func is_active() -> bool:
		return active

	func handle_input(
		_event: InputEvent,
		_owner: Object,
		_registry: Object,
		_view_size: Vector2
	) -> bool:
		handle_count += 1
		return true


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


func build() -> Dictionary:
	var owner := FakeOwner.new()
	var runtime := FakeLingpetRuntime.new()
	var overlay := FakeOverlayInput.new()
	var terminal := FakeTerminalScreen.new()
	var holder := ModuleHolder.new()
	var registry := FakeRegistry.new()
	holder.modules = {
		"lingpet_egg_runtime": runtime,
		"battle_scene_overlay_input_controller": overlay,
		"battle_scene_readiness_controller": FakeReadiness.new(),
		"battle_view_layout": FakeViewLayout.new(),
		"defeat_chance_gems_continue_screen": terminal,
	}
	return {
		"controller": BattleSceneInputController.new(),
		"owner": owner,
		"runtime": runtime,
		"overlay": overlay,
		"terminal": terminal,
		"holder": holder,
		"registry": registry,
	}


func dispatch(fixture: Dictionary, event: InputEvent) -> void:
	var controller: Object = fixture.get("controller")
	var holder: ModuleHolder = fixture.get("holder")
	controller.handle_unhandled_input(
		event,
		fixture.get("owner") as Object,
		fixture.get("registry") as Object,
		Callable(holder, "get_module"),
		{
			"battle_initialized": true,
			"stage_landing_intro_started": true,
			"mobile_touch_scene_ready": false,
		}
	)


static func key_event(keycode: Key, shift_pressed: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	event.shift_pressed = shift_pressed
	return event


static func click_event(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	return event
