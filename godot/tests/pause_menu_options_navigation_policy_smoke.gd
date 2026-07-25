extends SceneTree

const NavigationPolicy := preload("res://scripts/hud/pause_menu_options_navigation_policy.gd")

var failure_count := 0


func _init() -> void:
	var tabs := NavigationPolicy.get_tabs()
	_expect(tabs == ["sound", "display", "controls", "language"], "settings tabs should retain their visible navigation order")
	_expect(NavigationPolicy.cycle_tab("sound", 1) == "display", "forward tab navigation should advance once")
	_expect(NavigationPolicy.cycle_tab("sound", -1) == "language", "backward tab navigation should wrap")
	_expect(NavigationPolicy.cycle_tab("language", 1) == "sound", "forward tab navigation should wrap")
	_expect(NavigationPolicy.cycle_tab("invalid", 1) == "display", "unknown tab should preserve the legacy sound-index fallback before stepping")

	_expect(NavigationPolicy.cycle_controls_device("keyboard_mouse", 1) == "joypad", "control device should cycle to joypad")
	_expect(NavigationPolicy.cycle_controls_device("joypad", 1) == "keyboard_mouse", "control device should wrap to keyboard/mouse")
	_expect(NavigationPolicy.cycle_controls_device("joypad", 0) == "joypad", "zero direction should not change control device")
	_expect(NavigationPolicy.get_controls_focus_count("keyboard_mouse") == 2, "keyboard/mouse controls should expose device and back rows")
	_expect(NavigationPolicy.get_controls_focus_count("joypad") == 3, "joypad controls should additionally expose vibration")
	_expect(NavigationPolicy.get_controls_back_focus_index("keyboard_mouse") == 1, "keyboard/mouse back row should be index one")
	_expect(NavigationPolicy.get_controls_back_focus_index("joypad") == 2, "joypad back row should be index two")
	_expect(NavigationPolicy.clamp_controls_focus(2, "keyboard_mouse") == 1, "switching to keyboard/mouse should clamp joypad-only vibration focus")
	_expect(NavigationPolicy.is_controls_vibration_focus("joypad", 1), "joypad focus one should target vibration")
	_expect(not NavigationPolicy.is_controls_vibration_focus("keyboard_mouse", 1), "keyboard/mouse focus one should remain the back row")

	_expect(NavigationPolicy.move_focus(0, -1, 3) == 2, "focus movement should wrap backward")
	_expect(NavigationPolicy.move_focus(2, 1, 3) == 0, "focus movement should wrap forward")
	_expect(NavigationPolicy.move_focus(2, 1, 0) == 2, "zero-count focus movement should remain unchanged")
	_expect(NavigationPolicy.get_feedback_scope("sound", "keyboard_mouse") == "options:sound", "sound feedback scope should omit device")
	_expect(NavigationPolicy.get_feedback_scope("controls", "joypad") == "options:controls:joypad", "controls feedback scope should include device")
	_expect(NavigationPolicy.get_feedback_count("main", 4) == 4, "main feedback count should use the live entry count")
	_expect(NavigationPolicy.get_feedback_count("options:sound", 0) == 3, "sound feedback count should include two sliders and back")
	_expect(NavigationPolicy.get_feedback_count("options:display", 0) == 9, "display feedback count should retain all rows")
	_expect(NavigationPolicy.get_feedback_count("options:controls:keyboard_mouse", 0) == 2, "keyboard controls scope should expose two rows")
	_expect(NavigationPolicy.get_feedback_count("options:controls:joypad", 0) == 3, "joypad controls scope should expose three rows")
	_expect(NavigationPolicy.get_feedback_count("options:language", 0) == 8, "language scope should expose seven locales and back")
	_expect(NavigationPolicy.get_feedback_count("invalid", 4) == 0, "unknown scope should expose no feedback rows")

	if failure_count > 0:
		quit(1)
		return
	print("pause_menu_options_navigation_policy_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
