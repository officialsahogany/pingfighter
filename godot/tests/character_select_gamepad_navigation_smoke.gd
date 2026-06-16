extends SceneTree

const CharacterSelectScreen := preload("res://scripts/ui/character_select_screen.gd")
const GameSelectionState := preload("res://scripts/core/game_selection_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	var selection_state: Node = GameSelectionState.new()
	_expect(
		str(selection_state.get_selection().get("league_mode", "")) == "junior",
		"GameSelectionState should default new character-select sessions to Junior League"
	)
	selection_state.free()

	var screen: Control = CharacterSelectScreen.new()
	_expect(screen.selected_league_mode == "junior", "character select should default to Junior League")
	screen.characters = [
		{"id": "smasher", "unlocked": true},
		{"id": "soldier", "unlocked": true},
		{"id": "viper", "unlocked": true},
	]
	screen.visible_indices = [0, 1, 2]
	screen.selected_index = 0

	screen._handle_gamepad_unhandled_input(_axis(JOY_AXIS_LEFT_X, 0.65))
	_expect(screen.selected_index == 0, "small left-stick tilt should not move character selection")

	screen._handle_gamepad_unhandled_input(_axis(JOY_AXIS_LEFT_X, 0.86))
	_expect(screen.selected_index == 1, "firm left-stick tilt should move character selection once")

	screen._handle_gamepad_unhandled_input(_axis(JOY_AXIS_LEFT_X, 0.88))
	_expect(screen.selected_index == 1, "held left-stick tilt should not repeat character selection")

	screen._handle_gamepad_unhandled_input(_axis(JOY_AXIS_LEFT_X, 0.0))
	screen._handle_gamepad_unhandled_input(_axis(JOY_AXIS_LEFT_X, 0.86))
	_expect(screen.selected_index == 2, "left-stick selection should move again after returning to neutral")

	screen.selected_index = 0
	screen.gamepad_menu_horizontal_latch = 0
	screen.gamepad_menu_vertical_latch = 0
	screen._handle_gamepad_unhandled_input(_axis(JOY_AXIS_LEFT_Y, -0.86))
	_expect(screen.selected_index == 2, "vertical left-stick navigation should wrap backward once")

	screen._handle_gamepad_unhandled_input(_axis(JOY_AXIS_LEFT_Y, -0.88))
	_expect(screen.selected_index == 2, "held vertical left-stick tilt should not repeat character selection")
	screen.free()
	_verify_ring_core_display_source_contract()

	if _failures.is_empty():
		print("character_select_gamepad_navigation_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _verify_ring_core_display_source_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/character_select_screen.gd")
	_expect(source.find("const LingpetAffinityStore") >= 0, "character select should own a one-shot lingpet affinity store cache for ring-core display")
	_expect(source.find("_refresh_lingpet_ring_core_cache()") >= 0, "character select should refresh ring-core tier from _ready")
	_expect(source.find("lingpet_ring_core_upgrade_tier_%d") >= 0, "character select should reuse the shared ring-core tier icon family")
	_expect(source.find("func _lingpet_ring_core_label") >= 0 and source.find("Ring Core") >= 0, "character select ring-core label should have a non-Korean fallback")
	var process_start := source.find("func _process")
	var process_end := source.find("func _update_entry_background_prewarm")
	var draw_start := source.find("func _draw_info_panel")
	var layout_start := source.find("func _build_info_panel_layout")
	var process_block := source.substr(process_start, process_end - process_start) if process_start >= 0 and process_end > process_start else ""
	var draw_block := source.substr(draw_start, layout_start - draw_start) if draw_start >= 0 and layout_start > draw_start else ""
	_expect(process_block.find("LingpetAffinityStore") < 0 and process_block.find(".load()") < 0, "character select should not load the affinity store from _process")
	_expect(draw_block.find("LingpetAffinityStore") < 0 and draw_block.find(".load()") < 0, "character select should not load the affinity store from _draw_info_panel")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
