extends SceneTree

# expect-zero-object-leaks
const BattleSystemShortcutInputRouter := preload(
	"res://scripts/core/battle_system_shortcut_input_router.gd"
)

var _failures: Array[String] = []


class FakeWindow:
	extends RefCounted


class FakeOwner:
	extends RefCounted

	var redraw_count := 0
	var window := FakeWindow.new()

	func queue_redraw() -> void:
		redraw_count += 1

	func get_window() -> Object:
		return window


class FakeViewLayout:
	extends RefCounted

	var toggle_count := 0
	var windows: Array[Object] = []

	func toggle_fullscreen(window: Object) -> void:
		toggle_count += 1
		windows.append(window)


class FakeAudio:
	extends RefCounted

	var toggle_count := 0

	func toggle_bgm() -> void:
		toggle_count += 1


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		return value as Object if value is Object else null


func _init() -> void:
	_verify_fullscreen_shortcut()
	_verify_bgm_shortcut()
	_verify_right_stick_wheel_suppression_window()
	_verify_inactive_shortcuts_fall_through()
	_verify_source_ownership_and_order()
	call_deferred("_finish")


func _finish() -> void:
	if _failures.is_empty():
		print("battle_system_shortcut_input_router_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_fullscreen_shortcut() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var view_layout: FakeViewLayout = fixture["view_layout"]
	var audio: FakeAudio = fixture["audio"]
	var owner := FakeOwner.new()
	_expect(
		BattleSystemShortcutInputRouter.new().handle_input(
			_key_event(KEY_UNKNOWN, KEY_F11), owner, Callable(holder, "get_module")
		),
		"physical F11 must toggle fullscreen"
	)
	_expect(view_layout.toggle_count == 1, "F11 must call view-layout fullscreen toggle once")
	_expect(view_layout.windows == [owner.window], "fullscreen toggle must receive the owner's live window")
	_expect(audio.toggle_count == 0, "F11 must not enter BGM routing")
	_expect(owner.redraw_count == 1, "fullscreen toggle must request one redraw")
	_clear_fixture(fixture)


func _verify_bgm_shortcut() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var view_layout: FakeViewLayout = fixture["view_layout"]
	var audio: FakeAudio = fixture["audio"]
	var owner := FakeOwner.new()
	_expect(
		BattleSystemShortcutInputRouter.new().handle_input(
			_key_event(KEY_B, KEY_UNKNOWN), owner, Callable(holder, "get_module")
		),
		"logical B must toggle battle BGM"
	)
	_expect(audio.toggle_count == 1, "B must call game-audio toggle once")
	_expect(view_layout.toggle_count == 0, "B must not enter fullscreen routing")
	_expect(owner.redraw_count == 0, "BGM toggle must preserve the no-shell-redraw policy")
	_clear_fixture(fixture)


func _verify_right_stick_wheel_suppression_window() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var owner := FakeOwner.new()
	var router := BattleSystemShortcutInputRouter.new()
	_expect(
		router.handle_input(
			_axis_event(JOY_AXIS_RIGHT_X, 0.85), owner, Callable(holder, "get_module")
		),
		"right-stick motion must be consumed"
	)
	_expect(
		router.handle_input(
			_wheel_event(MOUSE_BUTTON_WHEEL_DOWN), owner, Callable(holder, "get_module")
		),
		"wheel event immediately after right-stick motion must be suppressed"
	)
	_expect(
		not BattleSystemShortcutInputRouter.new().handle_input(
			_wheel_event(MOUSE_BUTTON_WHEEL_DOWN), owner, Callable(holder, "get_module")
		),
		"fresh router must not suppress an unrelated mouse-wheel event"
	)
	_clear_fixture(fixture)


func _verify_inactive_shortcuts_fall_through() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var owner := FakeOwner.new()
	_expect(
		not BattleSystemShortcutInputRouter.new().handle_input(
			_key_event(KEY_A, KEY_A), owner, Callable(holder, "get_module")
		),
		"ordinary key input must fall through system shortcuts"
	)
	_expect(owner.redraw_count == 0, "fallthrough input must not redraw")
	_clear_fixture(fixture)


func _verify_source_ownership_and_order() -> void:
	var router_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_system_shortcut_input_router.gd"
	)
	var input_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_input_controller.gd"
	)
	_expect(router_source.find("_handle_window_shortcut") < router_source.find("_handle_bgm_shortcut"), "fullscreen shortcut must precede BGM shortcut")
	_expect(router_source.find("_handle_bgm_shortcut") < router_source.find("_handle_right_stick_suppression"), "BGM shortcut must precede right-stick suppression")
	_expect(router_source.contains("RIGHT_STICK_MOUSE_WHEEL_SUPPRESS_MSEC := 450"), "system router must retain the 450ms wheel suppression window")
	_expect(router_source.contains("_right_stick_mouse_wheel_suppress_until_msec"), "system router must own wheel suppression state")
	_expect(input_source.contains("BattleSystemShortcutInputRouter.new()"), "scene input controller must compose system shortcut router")
	_expect(input_source.contains("_system_shortcut_input_router.handle_input("), "scene input controller must delegate system shortcuts once")
	_expect(input_source.find("_system_shortcut_input_router.handle_input(") < input_source.find("_is_stage_transition_loading_active("), "system shortcuts must stay above transition-loading blocking")
	_expect(not input_source.contains("func _handle_window_shortcut"), "scene input controller must not retain fullscreen policy")
	_expect(not input_source.contains("func _handle_bgm_shortcut"), "scene input controller must not retain BGM policy")
	_expect(not input_source.contains("func _handle_right_stick_suppression"), "scene input controller must not retain right-stick suppression policy")
	_expect(not input_source.contains("_right_stick_mouse_wheel_suppress_until_msec"), "scene input controller must not retain wheel suppression state")


func _build_fixture() -> Dictionary:
	var holder := ModuleHolder.new()
	var view_layout := FakeViewLayout.new()
	var audio := FakeAudio.new()
	holder.modules = {
		"battle_view_layout": view_layout,
		"game_audio": audio,
	}
	return {
		"holder": holder,
		"view_layout": view_layout,
		"audio": audio,
	}


func _clear_fixture(fixture: Dictionary) -> void:
	var holder: ModuleHolder = fixture["holder"]
	holder.modules.clear()
	fixture.clear()


func _key_event(keycode: Key, physical_keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = physical_keycode
	return event


func _axis_event(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _wheel_event(button_index: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = button_index
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
