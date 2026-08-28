extends SceneTree

# expect-zero-object-leaks
const BattlePauseMenuInputRouter := preload(
	"res://scripts/core/battle_pause_menu_input_router.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_count := 0
	var lingpet_slots: Array = ["maribo"]

	func queue_redraw() -> void:
		redraw_count += 1


class FakeModalGate:
	extends RefCounted

	var pause_active := false

	func is_pause_menu_active(_module_getter: Callable) -> bool:
		return pause_active


class FakePauseMenu:
	extends RefCounted

	var handle_result: Variant = {"handled": true, "action": ""}
	var handle_count := 0
	var open_count := 0
	var last_event: InputEvent = null
	var last_owner: Object = null
	var last_registry: Object = null
	var last_view_size := Vector2.ZERO

	func handle_input(
		event: InputEvent,
		owner: Object,
		registry: Object,
		view_size: Vector2
	) -> Variant:
		handle_count += 1
		last_event = event
		last_owner = owner
		last_registry = registry
		last_view_size = view_size
		return handle_result

	func open() -> void:
		open_count += 1


class FakeCharacterInfo:
	extends RefCounted

	var prewarm_count := 0
	var open_count := 0
	var last_owner: Object = null
	var last_registry: Object = null
	var last_lingpet_ids: Array[String] = []

	func prewarm_assets(
		owner: Object,
		registry: Object,
		_module_getter: Callable,
		_force: bool,
		_view_size: Vector2,
		lingpet_ids: Array
	) -> void:
		prewarm_count += 1
		last_owner = owner
		last_registry = registry
		last_lingpet_ids.assign(lingpet_ids)

	func open(owner: Object, registry: Object) -> void:
		open_count += 1
		last_owner = owner
		last_registry = registry


class FakeMatchFlowDriver:
	extends RefCounted

	var exit_count := 0
	var last_owner: Object = null

	func exit_to_main_menu(owner: Object) -> void:
		exit_count += 1
		last_owner = owner


class FakeDebugPicker:
	extends RefCounted

	var close_count := 0

	func close() -> void:
		close_count += 1


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		return value as Object if value is Object else null


func _init() -> void:
	_verify_active_character_info_action_reuses_open_policy()
	_verify_unhandled_active_menu_still_consumes()
	_verify_boolean_handled_result_redraws_once()
	_verify_exit_action_routes_to_match_flow()
	_verify_escape_open_closes_debug_menus()
	_verify_gamepad_pause_opens_menu()
	_verify_inactive_non_shortcut_falls_through()
	_verify_source_ownership()
	call_deferred("_finish")


func _finish() -> void:
	if _failures.is_empty():
		print("battle_pause_menu_input_router_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_active_character_info_action_reuses_open_policy() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var gate: FakeModalGate = fixture["gate"]
	var pause_menu: FakePauseMenu = fixture["pause_menu"]
	var character_info: FakeCharacterInfo = fixture["character_info"]
	var owner := FakeOwner.new()
	var registry := RefCounted.new()
	var event := InputEventKey.new()
	gate.pause_active = true
	pause_menu.handle_result = {"handled": true, "action": "character_info"}
	var consumed: bool = BattlePauseMenuInputRouter.new().handle_active_input(
		event,
		owner,
		registry,
		Callable(holder, "get_module"),
		Vector2(1280.0, 720.0)
	)
	_expect(consumed, "active pause menu must consume input")
	_expect(pause_menu.handle_count == 1, "active pause menu must receive input once")
	_expect(pause_menu.last_event == event, "pause menu must receive original event")
	_expect(pause_menu.last_owner == owner, "pause menu must receive battle owner")
	_expect(pause_menu.last_registry == registry, "pause menu must receive registry")
	_expect(pause_menu.last_view_size == Vector2(1280.0, 720.0), "pause menu must receive current view size")
	_expect(character_info.prewarm_count == 1, "character-info action must prewarm once")
	_expect(character_info.open_count == 1, "character-info action must open once")
	_expect(character_info.last_lingpet_ids == ["maribo"], "pause action must reuse equipped-slot Guardian Spirit prewarm")
	_expect(owner.redraw_count == 2, "non-empty handled action must preserve action plus handler redraws")
	_clear_fixture(fixture)


func _verify_unhandled_active_menu_still_consumes() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var gate: FakeModalGate = fixture["gate"]
	var pause_menu: FakePauseMenu = fixture["pause_menu"]
	var owner := FakeOwner.new()
	gate.pause_active = true
	pause_menu.handle_result = {"handled": false, "action": "exit_to_main"}
	var consumed: bool = BattlePauseMenuInputRouter.new().handle_active_input(
		InputEventMouseMotion.new(),
		owner,
		holder,
		Callable(holder, "get_module"),
		Vector2(760.0, 750.0)
	)
	_expect(consumed, "active pause menu must swallow locally unhandled input")
	_expect(owner.redraw_count == 0, "locally unhandled input must not redraw")
	_expect((fixture["match_flow"] as FakeMatchFlowDriver).exit_count == 0, "unhandled result action must not dispatch")
	_clear_fixture(fixture)


func _verify_boolean_handled_result_redraws_once() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var gate: FakeModalGate = fixture["gate"]
	var pause_menu: FakePauseMenu = fixture["pause_menu"]
	var owner := FakeOwner.new()
	gate.pause_active = true
	pause_menu.handle_result = true
	var consumed: bool = BattlePauseMenuInputRouter.new().handle_active_input(
		InputEventKey.new(),
		owner,
		holder,
		Callable(holder, "get_module"),
		Vector2(760.0, 750.0)
	)
	_expect(consumed, "boolean handled pause result must be consumed")
	_expect(owner.redraw_count == 1, "handled result without action must redraw once")
	_clear_fixture(fixture)


func _verify_exit_action_routes_to_match_flow() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var gate: FakeModalGate = fixture["gate"]
	var pause_menu: FakePauseMenu = fixture["pause_menu"]
	var match_flow: FakeMatchFlowDriver = fixture["match_flow"]
	var owner := FakeOwner.new()
	gate.pause_active = true
	pause_menu.handle_result = {"handled": true, "action": "exit_to_main"}
	var consumed: bool = BattlePauseMenuInputRouter.new().handle_active_input(
		InputEventKey.new(),
		owner,
		holder,
		Callable(holder, "get_module"),
		Vector2(760.0, 750.0)
	)
	_expect(consumed, "exit action must be consumed")
	_expect(match_flow.exit_count == 1, "exit action must route through match flow once")
	_expect(match_flow.last_owner == owner, "exit action must forward battle owner")
	_expect(owner.redraw_count == 2, "exit action must preserve action plus handler redraws")
	_clear_fixture(fixture)


func _verify_escape_open_closes_debug_menus() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var pause_menu: FakePauseMenu = fixture["pause_menu"]
	var weather_picker: FakeDebugPicker = fixture["weather_picker"]
	var owner := FakeOwner.new()
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	var consumed: bool = BattlePauseMenuInputRouter.new().handle_open_shortcut(
		event,
		owner,
		Callable(holder, "get_module")
	)
	_expect(consumed, "ESC shortcut must be consumed")
	_expect(weather_picker.close_count == 1, "pause open must close active debug surfaces")
	_expect(pause_menu.open_count == 1, "ESC shortcut must open pause menu once")
	_expect(owner.redraw_count == 1, "pause open must request one redraw")
	_clear_fixture(fixture)


func _verify_gamepad_pause_opens_menu() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var pause_menu: FakePauseMenu = fixture["pause_menu"]
	var event := InputEventJoypadButton.new()
	event.pressed = true
	event.button_index = JOY_BUTTON_START
	var consumed: bool = BattlePauseMenuInputRouter.new().handle_open_shortcut(
		event,
		FakeOwner.new(),
		Callable(holder, "get_module")
	)
	_expect(consumed, "gamepad pause shortcut must be consumed")
	_expect(pause_menu.open_count == 1, "gamepad pause shortcut must open menu")
	_clear_fixture(fixture)


func _verify_inactive_non_shortcut_falls_through() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var router := BattlePauseMenuInputRouter.new()
	_expect(
		not router.handle_active_input(
			InputEventKey.new(),
			FakeOwner.new(),
			holder,
			Callable(holder, "get_module"),
			Vector2(760.0, 750.0)
		),
		"inactive pause menu must fall through active route"
	)
	_expect(
		not router.handle_open_shortcut(
			InputEventKey.new(),
			FakeOwner.new(),
			Callable(holder, "get_module")
		),
		"non-pause shortcut must fall through"
	)
	_clear_fixture(fixture)


func _verify_source_ownership() -> void:
	var router_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_pause_menu_input_router.gd"
	)
	var input_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_overlay_input_controller.gd"
	)
	_expect(router_source.contains("BattleDebugMenuSwitcher.new()"), "pause router must own debug-menu cleanup composition")
	_expect(router_source.contains("_debug_menu_switcher.close_all(module_getter)"), "pause router must close debug menus before opening")
	_expect(router_source.contains("_character_info_input_router.open_from_pause("), "pause router must reuse character-info open policy")
	_expect(router_source.contains("exit_to_main_menu(owner)"), "pause router must own match-flow exit dispatch")
	_expect(input_source.contains("BattlePauseMenuInputRouter.new()"), "overlay controller must compose pause router")
	_expect(input_source.contains("_pause_menu_input_router.handle_active_input("), "overlay controller must delegate active pause input")
	_expect(input_source.contains("_pause_menu_input_router.handle_open_shortcut("), "overlay controller must delegate pause opening")
	_expect(not input_source.contains("func _handle_pause_menu_action"), "overlay controller must not retain pause action policy")
	_expect(not input_source.contains("_debug_menu_switcher.close_all"), "overlay controller must not retain pause-open debug cleanup")


func _build_fixture() -> Dictionary:
	var holder := ModuleHolder.new()
	var gate := FakeModalGate.new()
	var pause_menu := FakePauseMenu.new()
	var character_info := FakeCharacterInfo.new()
	var match_flow := FakeMatchFlowDriver.new()
	var weather_picker := FakeDebugPicker.new()
	holder.modules = {
		"battle_scene_modal_gate_controller": gate,
		"pause_menu_overlay": pause_menu,
		"character_info_overlay": character_info,
		"battle_scene_match_flow_driver": match_flow,
		"weather_debug_picker": weather_picker,
	}
	return {
		"holder": holder,
		"gate": gate,
		"pause_menu": pause_menu,
		"character_info": character_info,
		"match_flow": match_flow,
		"weather_picker": weather_picker,
	}


func _clear_fixture(fixture: Dictionary) -> void:
	var holder: ModuleHolder = fixture["holder"]
	holder.modules.clear()
	fixture.clear()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
