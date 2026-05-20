extends SceneTree

const BattleSceneOverlayInputController := preload("res://scripts/core/battle_scene_overlay_input_controller.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const BattleSceneWeatherUpdateDriver := preload("res://scripts/core/battle_scene_weather_update_driver.gd")
const WeatherDebugPicker := preload("res://scripts/core/weather_debug_picker.gd")
const WeatherEventState := preload("res://scripts/stages/common/weather_event_state.gd")


class FakeOwner:
	var current_stage := 1
	var ai_mode := "champion"
	var arena_mode_enabled := false
	var weather_type := ""
	var weather_event_active := false
	var weather_event_context: Dictionary = {}
	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(960.0, 720.0))


class FakeRegistry:
	var modal_gate := BattleSceneModalGateController.new()
	var weather := WeatherEventState.new()
	var weather_driver := BattleSceneWeatherUpdateDriver.new()
	var weather_picker := WeatherDebugPicker.new()

	func get_instance(key: String) -> Object:
		match key:
			"battle_scene_modal_gate_controller":
				return modal_gate
			"weather_event_state":
				return weather
			"battle_scene_weather_update_driver":
				return weather_driver
			"weather_debug_picker":
				return weather_picker
		return null


var registry := FakeRegistry.new()


func _init() -> void:
	var owner := FakeOwner.new()
	var input := BattleSceneOverlayInputController.new()

	_expect(_press_f6(input, owner), "F6 should be handled by the overlay input controller")
	_expect(registry.weather_picker.is_open(), "F6 should open the weather debug picker")
	_expect(str(owner.weather_type) == "", "opening the picker should not immediately change weather")
	_expect(owner.redraw_count == 1, "F6 weather debug should queue one redraw")

	_expect(_click_weather(input, owner, "fire"), "clicking a weather card should be handled")
	_expect(not registry.weather_picker.is_open(), "weather picker should close after applying a weather")
	_expect(str(owner.weather_type) == "fire", "clicking fire should force-start fire weather")
	_expect(bool(owner.weather_event_active), "weather picker selection should mark weather active on the owner")

	_expect(_press_f6(input, owner), "F6 should reopen the weather picker")
	_expect(registry.weather_picker.is_open(), "F6 should open the picker while fire is active")
	_expect(_click_weather(input, owner, ""), "clicking clear should be handled")
	_expect(str(owner.weather_type) == "", "clear weather option should force-end the debug weather")
	_expect(not bool(owner.weather_event_active), "clear weather option should clear the active weather flag")

	var echo_event := _make_f6_event()
	echo_event.echo = true
	_expect(not bool(input.handle_input(echo_event, owner, registry, Callable(self, "_get_module"), {})), "echoed F6 events should not trigger weather debug")

	print("weather_debug_key_smoke: ok")
	quit(0)


func _press_f6(input: Object, owner: Object) -> bool:
	return bool(input.handle_input(_make_f6_event(), owner, registry, Callable(self, "_get_module"), {}))


func _click_weather(input: Object, owner: Object, weather_id: String) -> bool:
	var view_size: Vector2 = owner.get_viewport_rect().size
	var picker: Object = registry.weather_picker
	var index: int = int(picker._get_weather_index(weather_id))
	var panel_rect: Rect2 = picker._get_panel_rect(view_size)
	var card_rect: Rect2 = picker._get_card_rect(index, panel_rect)
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = card_rect.get_center()
	return bool(input.handle_input(event, owner, registry, Callable(self, "_get_module"), {}))


func _make_f6_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_F6
	event.physical_keycode = KEY_F6
	return event


func _get_module(key: String) -> Object:
	return registry.get_instance(key)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
