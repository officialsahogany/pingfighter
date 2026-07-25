extends SceneTree

const PauseMenuSessionState := preload("res://scripts/hud/pause_menu_session_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_overlay_session_owner_contract()
	var state := PauseMenuSessionState.new()
	_expect(not state.active, "session should start inactive")
	_expect(not state.options_open, "options should start closed")

	state.animation_time = 7.0
	state.main_dial_time = 3.0
	state.selected_index = 2
	state.dragging_slider = "bgm"
	state.open_main()
	_expect(state.active, "main open should activate the session")
	_expect(not state.options_open and not state.options_only, "main open should clear option modes")
	_expect(is_zero_approx(state.animation_time) and is_zero_approx(state.main_dial_time), "main open should reset both animation clocks")
	_expect(state.selected_index == 0 and state.dragging_slider.is_empty(), "main open should reset transient input state")

	_expect(state.advance(0.75, 1.0), "active session should advance")
	_expect(is_equal_approx(state.animation_time, 0.75), "advance should update animation time")
	_expect(is_equal_approx(state.main_dial_time, 0.75), "advance should update dial phase")
	_expect(state.advance(0.5, 1.0), "active session should keep advancing")
	_expect(is_equal_approx(state.main_dial_time, 0.25), "dial phase should wrap to its cycle")

	state.begin_options(true)
	_expect(state.active and state.options_only, "direct options open should retain options-only intent")
	_expect(is_zero_approx(state.animation_time), "options open should restart the opening animation")
	_expect(is_equal_approx(state.main_dial_time, 0.25), "options open should preserve the existing dial phase")
	state.selected_index = 3
	state.dragging_slider = "sfx"
	state.open_options_page()
	_expect(state.options_open, "options page should open")
	_expect(state.selected_index == 0 and state.dragging_slider.is_empty(), "options page open should reset transient input state")

	state.selected_index = 2
	state.dragging_slider = "bgm"
	state.close_options_page()
	_expect(not state.options_open, "options page should close")
	_expect(state.options_only, "closing the page should preserve options-only intent for the caller")
	_expect(state.selected_index == 0 and state.dragging_slider.is_empty(), "options page close should reset transient input state")

	state.animation_time = 4.0
	state.close()
	_expect(not state.active and not state.options_open and not state.options_only, "close should clear all activation modes")
	_expect(is_equal_approx(state.animation_time, 4.0), "close should preserve the opening animation clock")
	_expect(is_zero_approx(state.main_dial_time), "close should reset the dial phase")
	_expect(not state.advance(0.5, 1.0), "inactive session should not advance")
	_expect(is_equal_approx(state.animation_time, 4.0), "inactive advance should preserve animation time")

	if _failures.is_empty():
		print("pause_menu_session_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_overlay_session_owner_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_overlay.gd")
	for delegation in [
		"_session_state.open_main()",
		"_session_state.close()",
		"_session_state.begin_options(direct_options_only)",
		"_session_state.open_options_page()",
		"_session_state.close_options_page()",
		"_session_state.advance(delta",
	]:
		_expect(source.find(delegation) >= 0, "overlay should delegate pause-session transition: %s" % delegation)
	_expect(source.find("animation_time += delta") == -1, "overlay should not advance the session clock outside its state owner")
	_expect(source.find("_main_dial_time = fposmod") == -1, "overlay should not advance the dial clock outside its state owner")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
