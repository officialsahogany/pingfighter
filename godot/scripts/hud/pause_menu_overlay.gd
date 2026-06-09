extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const GamepadVibrationSettings := preload("res://scripts/core/gamepad_vibration_settings.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const FONT_BODY: Font = preload("res://assets/fonts/NanumSquareB.ttf")
const FONT_TECH: Font = preload("res://assets/fonts/NeoDunggeunmoPro.ttf")

const MENU_CONTINUE := "continue"
const MENU_CHARACTER_INFO := "character_info"
const MENU_OPTIONS := "options"
const SOUND_SLIDER_BGM := "bgm"
const SOUND_SLIDER_SFX := "sfx"
const OPTIONS_TAB_SOUND := "sound"
const OPTIONS_TAB_DISPLAY := "display"
const OPTIONS_TAB_CONTROLS := "controls"
const OPTIONS_TAB_LANGUAGE := "language"
const CONTROL_DEVICE_KEYBOARD_MOUSE := "keyboard_mouse"
const CONTROL_DEVICE_JOYPAD := "joypad"
const DISPLAY_MODE_FULLSCREEN := "fullscreen"
const DISPLAY_MODE_EXCLUSIVE_FULLSCREEN := "exclusive_fullscreen"
const DISPLAY_MODE_WINDOWED := "windowed"
const RENDER_FPS_CAP_UNLIMITED := 0
const RENDER_FPS_CAP_STABILITY := 48
const RENDER_FPS_CAP_SMOOTH := 60
const RENDER_FPS_CAP_BALANCED := 72
const RENDER_FPS_CAP_MONITOR := -1
const RENDER_FPS_CAP_STABLE_MONITOR := -2
const RENDER_FPS_CAP_DEFAULT := RENDER_FPS_CAP_MONITOR
const VSYNC_MODE_AUTO := -1
const VSYNC_MODE_DISABLED := 0
const VSYNC_MODE_ENABLED := 1
const VSYNC_MODE_MAILBOX := 3

const MAIN_PANEL_SIZE := Vector2(360.0, 320.0)
const OPTIONS_PANEL_SIZE := Vector2(900.0, 500.0)
const BUTTON_SIZE := Vector2(250.0, 48.0)
const BUTTON_GAP := 14.0
const TITLE_HEIGHT := 82.0
const SLIDER_HEIGHT := 10.0
const SLIDER_HIT_HEIGHT := 34.0
const SLIDER_HANDLE_RADIUS := 8.0
const VOLUME_STEP := 0.05
const DEFAULT_BGM_VOLUME := 0.4
const DEFAULT_SFX_VOLUME := 0.7
const SOUND_FOCUS_COUNT := 3
const DISPLAY_FOCUS_COUNT := 9
const CONTROLS_BASE_FOCUS_COUNT := 2
const CONTROLS_JOYPAD_FOCUS_COUNT := 3
const LANGUAGE_FOCUS_COUNT := 8

const PANEL_COLOR := Color(0.04, 0.06, 0.10, 0.92)
const PANEL_BORDER := Color(0.36, 0.78, 0.98, 0.90)
const HEADER_COLOR := Color(0.06, 0.10, 0.16, 0.94)
const SECTION_COLOR := Color(0.02, 0.04, 0.08, 0.55)
const BUTTON_COLOR := Color(0.06, 0.10, 0.16, 0.90)
const BUTTON_HOVER := Color(0.10, 0.18, 0.28, 0.96)
const BUTTON_SELECTED := Color(0.14, 0.24, 0.36, 1.0)
const BUTTON_BORDER := Color(0.36, 0.78, 0.98, 0.55)
const SLIDER_BACK := Color(0.06, 0.10, 0.16, 1.0)
const TEXT_DIM := Color(0.62, 0.72, 0.84)
const ACCENT_BLUE := Color(0.36, 0.78, 0.98)
const ACCENT_GREEN := Color(0.0, 1.0, 0.47)
const ACCENT_GOLD := Color(1.0, 0.80, 0.20)
const NEON_CYAN := Color(0.36, 0.78, 0.98)
const NEON_CYAN_HOT := Color(0.66, 0.92, 1.00)
const RESONANCE_MAG := Color(0.72, 0.50, 1.00)
const NEON_GREEN := Color(0.00, 1.00, 0.47)
const WARM_GOLD := Color(1.00, 0.80, 0.20)
const TEXT_WARM := Color(0.94, 0.99, 1.00)

var active := false
var options_open := false
var animation_time := 0.0
var selected_index := 0
var options_focus := 0
var dragging_slider := ""
var options_tab := OPTIONS_TAB_SOUND
var controls_device_view := CONTROL_DEVICE_KEYBOARD_MOUSE
var display_mode := DISPLAY_MODE_WINDOWED
var remember_display_mode := false
var auto_refresh_rate_60hz := false
var render_fps_cap := RENDER_FPS_CAP_DEFAULT
var vsync_mode := VSYNC_MODE_AUTO
var gamepad_vibration_level := GamepadVibrationSettings.VIBRATION_LEVEL_DEFAULT
var language_code := LanguageSettings.DEFAULT_LANGUAGE
var options_only := false
var _synced_display_mode := DISPLAY_MODE_WINDOWED
var _synced_remember_display_mode := false
var _synced_auto_refresh_rate_60hz := false
var _display_preference_dirty := false


func is_active() -> bool:
	return active


func is_options_open() -> bool:
	return active and options_open


func open() -> void:
	active = true
	options_open = false
	options_only = false
	animation_time = 0.0
	selected_index = 0
	options_focus = 0
	dragging_slider = ""
	options_tab = OPTIONS_TAB_SOUND
	controls_device_view = CONTROL_DEVICE_KEYBOARD_MOUSE


func close() -> void:
	active = false
	options_open = false
	options_only = false
	selected_index = 0
	options_focus = 0
	dragging_slider = ""
	options_tab = OPTIONS_TAB_SOUND
	controls_device_view = CONTROL_DEVICE_KEYBOARD_MOUSE


func toggle() -> void:
	if active:
		close()
	else:
		open()


func open_options(owner: Object, registry: Object, direct_options_only: bool = false) -> void:
	active = true
	options_only = direct_options_only
	animation_time = 0.0
	_open_options(owner, registry)


func update(delta: float) -> void:
	if not active:
		return
	animation_time += delta


func handle_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> Dictionary:
	if not active:
		return {"handled": false}
	if event is InputEventKey:
		return _handle_key_input(event as InputEventKey, owner, registry)
	if GamepadInput.is_gamepad_event(event):
		return _handle_gamepad_input(event, owner, registry)
	if event is InputEventMouseButton:
		return _handle_mouse_button(event as InputEventMouseButton, owner, registry, view_size)
	if event is InputEventMouseMotion:
		return _handle_mouse_motion(event as InputEventMouseMotion, registry, view_size)
	return {"handled": true}


func draw(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2) -> void:
	if not active or canvas == null:
		return
	var font: Font = _get_ui_font()
	if font == null:
		return
	var alpha: float = clamp(animation_time / 0.12, 0.0, 1.0)
	var panel_rect: Rect2 = _get_active_panel_rect(view_size).grow(-8.0 * (1.0 - alpha))
	var mouse_pos: Vector2 = _get_mouse_position(canvas)

	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.58 * alpha))
	_draw_panel(canvas, panel_rect, PANEL_COLOR, PANEL_BORDER, 2.0, true, true)
	if options_open:
		_draw_options_window(canvas, font, panel_rect, mouse_pos, registry, owner)
	else:
		_draw_main_menu(canvas, font, panel_rect, mouse_pos)


func _handle_key_input(key_event: InputEventKey, owner: Object, registry: Object) -> Dictionary:
	if not key_event.pressed or key_event.echo:
		return {"handled": true}
	if options_open:
		return _handle_options_key_input(key_event, owner, registry)
	if _is_key(key_event, KEY_ESCAPE):
		close()
		return {"handled": true, "action": MENU_CONTINUE}
	if _is_key(key_event, KEY_UP):
		_move_selection(-1)
		return {"handled": true}
	if _is_key(key_event, KEY_DOWN):
		_move_selection(1)
		return {"handled": true}
	if _is_key(key_event, KEY_ENTER) or _is_key(key_event, KEY_KP_ENTER) or _is_key(key_event, KEY_SPACE):
		return _activate_selected(owner, registry)
	return {"handled": true}


func _handle_options_key_input(key_event: InputEventKey, owner: Object, registry: Object) -> Dictionary:
	if _is_key(key_event, KEY_ESCAPE):
		return _close_options_page()
	if _is_key(key_event, KEY_TAB):
		_switch_options_tab(1, owner, registry)
		return {"handled": true}
	if options_tab == OPTIONS_TAB_DISPLAY:
		return _handle_display_key_input(key_event, owner, registry)
	if options_tab == OPTIONS_TAB_CONTROLS:
		return _handle_controls_key_input(key_event)
	if options_tab == OPTIONS_TAB_LANGUAGE:
		return _handle_language_key_input(key_event, owner)
	return _handle_sound_key_input(key_event, registry)


func _handle_gamepad_input(event: InputEvent, owner: Object, registry: Object) -> Dictionary:
	if options_open:
		return _handle_options_gamepad_input(event, owner, registry)
	if GamepadInput.is_cancel_event(event) or GamepadInput.is_pause_event(event):
		close()
		return {"handled": true, "action": MENU_CONTINUE}
	var vertical_direction: int = GamepadInput.get_menu_vertical_event(event)
	if vertical_direction != 0:
		_move_selection(vertical_direction)
		return {"handled": true}
	if GamepadInput.is_confirm_event(event):
		return _activate_selected(owner, registry)
	return {"handled": true}


func _handle_options_gamepad_input(event: InputEvent, owner: Object, registry: Object) -> Dictionary:
	if GamepadInput.is_cancel_event(event) or GamepadInput.is_pause_event(event):
		return _close_options_page()
	var tab_direction: int = GamepadInput.get_tab_direction_event(event)
	if tab_direction != 0:
		_switch_options_tab(tab_direction, owner, registry)
		return {"handled": true}
	if options_tab == OPTIONS_TAB_DISPLAY:
		return _handle_display_gamepad_input(event, owner, registry)
	if options_tab == OPTIONS_TAB_CONTROLS:
		return _handle_controls_gamepad_input(event)
	if options_tab == OPTIONS_TAB_LANGUAGE:
		return _handle_language_gamepad_input(event, owner)
	return _handle_sound_gamepad_input(event, registry)


func _handle_sound_key_input(key_event: InputEventKey, registry: Object) -> Dictionary:
	if _is_key(key_event, KEY_UP):
		options_focus = (options_focus + SOUND_FOCUS_COUNT - 1) % SOUND_FOCUS_COUNT
		return {"handled": true}
	if _is_key(key_event, KEY_DOWN):
		options_focus = (options_focus + 1) % SOUND_FOCUS_COUNT
		return {"handled": true}
	if _is_key(key_event, KEY_LEFT):
		_adjust_focused_volume(registry, -VOLUME_STEP)
		return {"handled": true}
	if _is_key(key_event, KEY_RIGHT):
		_adjust_focused_volume(registry, VOLUME_STEP)
		return {"handled": true}
	if _is_key(key_event, KEY_ENTER) or _is_key(key_event, KEY_KP_ENTER) or _is_key(key_event, KEY_SPACE):
		if options_focus == 2:
			return _close_options_page()
		return {"handled": true}
	return {"handled": true}


func _handle_display_key_input(key_event: InputEventKey, owner: Object, registry: Object) -> Dictionary:
	if _is_key(key_event, KEY_UP):
		options_focus = (options_focus + DISPLAY_FOCUS_COUNT - 1) % DISPLAY_FOCUS_COUNT
		return {"handled": true}
	if _is_key(key_event, KEY_DOWN):
		options_focus = (options_focus + 1) % DISPLAY_FOCUS_COUNT
		return {"handled": true}
	if _is_key(key_event, KEY_LEFT) or _is_key(key_event, KEY_RIGHT):
		if options_focus == 0:
			_cycle_display_mode(-1 if _is_key(key_event, KEY_LEFT) else 1)
		elif options_focus == 1:
			_cycle_render_fps_cap(-1 if _is_key(key_event, KEY_LEFT) else 1, owner, registry)
		elif options_focus == 2:
			_cycle_vsync_mode(-1 if _is_key(key_event, KEY_LEFT) else 1, owner, registry)
		return {"handled": true}
	if _is_key(key_event, KEY_ENTER) or _is_key(key_event, KEY_KP_ENTER) or _is_key(key_event, KEY_SPACE):
		match options_focus:
			0:
				_cycle_display_mode(1)
			1:
				_cycle_render_fps_cap(1, owner, registry)
			2:
				_cycle_vsync_mode(1, owner, registry)
			3:
				remember_display_mode = not remember_display_mode
				_display_preference_dirty = true
			4:
				auto_refresh_rate_60hz = not auto_refresh_rate_60hz
				_display_preference_dirty = true
			5:
				_apply_recommended_display_settings(owner, registry)
			6:
				_apply_60hz_now(owner, registry)
			7:
				_save_display_options(owner, registry)
			8:
				return _close_options_page()
		return {"handled": true}
	return {"handled": true}


func _handle_controls_key_input(key_event: InputEventKey) -> Dictionary:
	var focus_count := _get_controls_focus_count()
	if _is_key(key_event, KEY_UP):
		options_focus = (options_focus + focus_count - 1) % focus_count
		return {"handled": true}
	if _is_key(key_event, KEY_DOWN):
		options_focus = (options_focus + 1) % focus_count
		return {"handled": true}
	if _is_key(key_event, KEY_LEFT):
		_adjust_controls_focus(-1)
		return {"handled": true}
	if _is_key(key_event, KEY_RIGHT):
		_adjust_controls_focus(1)
		return {"handled": true}
	if _is_key(key_event, KEY_ENTER) or _is_key(key_event, KEY_KP_ENTER) or _is_key(key_event, KEY_SPACE):
		if options_focus == 0:
			_cycle_control_device_view(1)
			return {"handled": true}
		if _is_controls_vibration_focus():
			_adjust_gamepad_vibration_level(1)
			return {"handled": true}
		return _close_options_page()
	return {"handled": true}


func _handle_language_key_input(key_event: InputEventKey, owner: Object) -> Dictionary:
	if _is_key(key_event, KEY_UP):
		options_focus = (options_focus + LANGUAGE_FOCUS_COUNT - 1) % LANGUAGE_FOCUS_COUNT
		return {"handled": true}
	if _is_key(key_event, KEY_DOWN):
		options_focus = (options_focus + 1) % LANGUAGE_FOCUS_COUNT
		return {"handled": true}
	if _is_key(key_event, KEY_LEFT):
		if options_focus < LANGUAGE_FOCUS_COUNT - 1:
			_cycle_language(-1, owner)
		return {"handled": true}
	if _is_key(key_event, KEY_RIGHT):
		if options_focus < LANGUAGE_FOCUS_COUNT - 1:
			_cycle_language(1, owner)
		return {"handled": true}
	if _is_key(key_event, KEY_ENTER) or _is_key(key_event, KEY_KP_ENTER) or _is_key(key_event, KEY_SPACE):
		return _activate_language_focus(owner)
	return {"handled": true}


func _handle_sound_gamepad_input(event: InputEvent, registry: Object) -> Dictionary:
	var vertical_direction: int = GamepadInput.get_menu_vertical_event(event)
	if vertical_direction != 0:
		options_focus = (options_focus + vertical_direction + SOUND_FOCUS_COUNT) % SOUND_FOCUS_COUNT
		return {"handled": true}
	var horizontal_direction: int = GamepadInput.get_menu_horizontal_event(event)
	if horizontal_direction != 0:
		_adjust_focused_volume(registry, float(horizontal_direction) * VOLUME_STEP)
		return {"handled": true}
	if GamepadInput.is_confirm_event(event) and options_focus == 2:
		return _close_options_page()
	return {"handled": true}


func _handle_display_gamepad_input(event: InputEvent, owner: Object, registry: Object) -> Dictionary:
	var vertical_direction: int = GamepadInput.get_menu_vertical_event(event)
	if vertical_direction != 0:
		options_focus = (options_focus + vertical_direction + DISPLAY_FOCUS_COUNT) % DISPLAY_FOCUS_COUNT
		return {"handled": true}
	var horizontal_direction: int = GamepadInput.get_menu_horizontal_event(event)
	if horizontal_direction != 0:
		_handle_display_focus_delta(horizontal_direction, owner, registry)
		return {"handled": true}
	if GamepadInput.is_confirm_event(event):
		return _activate_display_focus(owner, registry)
	return {"handled": true}


func _handle_controls_gamepad_input(event: InputEvent) -> Dictionary:
	var vertical_direction: int = GamepadInput.get_menu_vertical_event(event)
	if vertical_direction != 0:
		var focus_count := _get_controls_focus_count()
		options_focus = (options_focus + vertical_direction + focus_count) % focus_count
		return {"handled": true}
	var horizontal_direction: int = GamepadInput.get_menu_horizontal_event(event)
	if horizontal_direction != 0:
		_adjust_controls_focus(horizontal_direction)
		return {"handled": true}
	if GamepadInput.is_confirm_event(event):
		if options_focus == 0:
			_cycle_control_device_view(1)
			return {"handled": true}
		if _is_controls_vibration_focus():
			_adjust_gamepad_vibration_level(1)
			return {"handled": true}
		return _close_options_page()
	return {"handled": true}


func _handle_language_gamepad_input(event: InputEvent, owner: Object) -> Dictionary:
	var vertical_direction: int = GamepadInput.get_menu_vertical_event(event)
	if vertical_direction != 0:
		options_focus = (options_focus + vertical_direction + LANGUAGE_FOCUS_COUNT) % LANGUAGE_FOCUS_COUNT
		return {"handled": true}
	var horizontal_direction: int = GamepadInput.get_menu_horizontal_event(event)
	if horizontal_direction != 0:
		if options_focus < LANGUAGE_FOCUS_COUNT - 1:
			_cycle_language(horizontal_direction, owner)
		return {"handled": true}
	if GamepadInput.is_confirm_event(event):
		return _activate_language_focus(owner)
	return {"handled": true}


func _handle_mouse_button(mouse_event: InputEventMouseButton, owner: Object, registry: Object, view_size: Vector2) -> Dictionary:
	if not mouse_event.pressed:
		dragging_slider = ""
		return {"handled": true}
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		if options_open:
			return _close_options_page()
		close()
		return {"handled": true, "action": MENU_CONTINUE}
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return {"handled": true}
	if options_open:
		return _handle_options_click(mouse_event.position, owner, registry, view_size)
	var panel_rect: Rect2 = _get_active_panel_rect(view_size)
	var entries: Array = _get_main_entries()
	for index in range(entries.size()):
		var rect: Rect2 = _get_button_rect(panel_rect, index, entries.size())
		if rect.has_point(mouse_event.position):
			selected_index = index
			return _activate_entry(str(entries[index].get("action", "")), owner, registry)
	return {"handled": true}


func _handle_mouse_motion(mouse_event: InputEventMouseMotion, registry: Object, view_size: Vector2) -> Dictionary:
	if options_open and not dragging_slider.is_empty():
		_set_volume_from_slider(dragging_slider, mouse_event.position.x, registry, view_size)
	return {"handled": true}


func _handle_options_click(position: Vector2, owner: Object, registry: Object, view_size: Vector2) -> Dictionary:
	var panel_rect: Rect2 = _get_options_panel_rect(view_size)
	if _get_reset_button_rect(panel_rect).has_point(position):
		_reset_current_tab_to_defaults(owner, registry)
		return {"handled": true}
	if _get_sound_tab_rect(panel_rect).has_point(position):
		options_tab = OPTIONS_TAB_SOUND
		options_focus = 0
		dragging_slider = ""
		return {"handled": true}
	if _get_display_tab_rect(panel_rect).has_point(position):
		options_tab = OPTIONS_TAB_DISPLAY
		options_focus = 0
		dragging_slider = ""
		_sync_display_settings(owner, registry)
		return {"handled": true}
	if _get_controls_tab_rect(panel_rect).has_point(position):
		options_tab = OPTIONS_TAB_CONTROLS
		options_focus = 0
		dragging_slider = ""
		_sync_controls_settings()
		return {"handled": true}
	if _get_language_tab_rect(panel_rect).has_point(position):
		options_tab = OPTIONS_TAB_LANGUAGE
		options_focus = 0
		dragging_slider = ""
		_sync_language_settings()
		return {"handled": true}
	if options_tab == OPTIONS_TAB_DISPLAY:
		return _handle_display_click(position, owner, registry, panel_rect)
	if options_tab == OPTIONS_TAB_CONTROLS:
		return _handle_controls_click(position, panel_rect)
	if options_tab == OPTIONS_TAB_LANGUAGE:
		return _handle_language_click(position, owner, panel_rect)
	return _handle_sound_click(position, registry, view_size, panel_rect)


func _handle_sound_click(position: Vector2, registry: Object, view_size: Vector2, panel_rect: Rect2) -> Dictionary:
	if _get_back_button_rect(panel_rect).has_point(position):
		return _close_options_page()
	if _get_slider_hit_rect(SOUND_SLIDER_BGM, view_size).has_point(position):
		options_focus = 0
		dragging_slider = SOUND_SLIDER_BGM
		_set_volume_from_slider(SOUND_SLIDER_BGM, position.x, registry, view_size)
		return {"handled": true}
	if _get_slider_hit_rect(SOUND_SLIDER_SFX, view_size).has_point(position):
		options_focus = 1
		dragging_slider = SOUND_SLIDER_SFX
		_set_volume_from_slider(SOUND_SLIDER_SFX, position.x, registry, view_size)
		return {"handled": true}
	return {"handled": true}


func _handle_display_click(position: Vector2, owner: Object, registry: Object, panel_rect: Rect2) -> Dictionary:
	if _get_display_fullscreen_rect(panel_rect).has_point(position):
		_set_display_mode_option(DISPLAY_MODE_FULLSCREEN)
		options_focus = 0
		return {"handled": true}
	if _get_display_exclusive_fullscreen_rect(panel_rect).has_point(position):
		_set_display_mode_option(DISPLAY_MODE_EXCLUSIVE_FULLSCREEN)
		options_focus = 0
		return {"handled": true}
	if _get_display_windowed_rect(panel_rect).has_point(position):
		_set_display_mode_option(DISPLAY_MODE_WINDOWED)
		options_focus = 0
		return {"handled": true}
	if _get_display_fps_cap_row_rect(panel_rect).has_point(position):
		options_focus = 1
		var chevrons := _get_select_chevron_rects(_get_display_fps_cap_value_rect(panel_rect))
		var left_rect: Rect2 = chevrons["left"]
		var right_rect: Rect2 = chevrons["right"]
		if left_rect.has_point(position):
			_cycle_render_fps_cap(-1, owner, registry)
		elif right_rect.has_point(position):
			_cycle_render_fps_cap(1, owner, registry)
		return {"handled": true}
	if _get_display_vsync_row_rect(panel_rect).has_point(position):
		options_focus = 2
		var chevrons := _get_select_chevron_rects(_get_display_vsync_value_rect(panel_rect))
		var left_rect: Rect2 = chevrons["left"]
		var right_rect: Rect2 = chevrons["right"]
		if left_rect.has_point(position):
			_cycle_vsync_mode(-1, owner, registry)
		elif right_rect.has_point(position):
			_cycle_vsync_mode(1, owner, registry)
		return {"handled": true}
	if _get_display_default_row_rect(panel_rect).has_point(position):
		remember_display_mode = not remember_display_mode
		_display_preference_dirty = true
		options_focus = 3
		return {"handled": true}
	if _get_display_auto_refresh_row_rect(panel_rect).has_point(position):
		auto_refresh_rate_60hz = not auto_refresh_rate_60hz
		_display_preference_dirty = true
		options_focus = 4
		return {"handled": true}
	if _get_display_recommended_button_rect(panel_rect).has_point(position):
		options_focus = 5
		_apply_recommended_display_settings(owner, registry)
		return {"handled": true}
	if _get_display_apply_60hz_button_rect(panel_rect).has_point(position):
		options_focus = 6
		_apply_60hz_now(owner, registry)
		return {"handled": true}
	if _get_display_save_button_rect(panel_rect).has_point(position):
		options_focus = 7
		_save_display_options(owner, registry)
		return {"handled": true}
	if _get_display_back_button_rect(panel_rect).has_point(position):
		return _close_options_page()
	return {"handled": true}


func _handle_controls_click(position: Vector2, panel_rect: Rect2) -> Dictionary:
	if _get_controls_keyboard_mouse_rect(panel_rect).has_point(position):
		controls_device_view = CONTROL_DEVICE_KEYBOARD_MOUSE
		options_focus = 0
		return {"handled": true}
	if _get_controls_joypad_rect(panel_rect).has_point(position):
		controls_device_view = CONTROL_DEVICE_JOYPAD
		options_focus = 0
		return {"handled": true}
	if controls_device_view == CONTROL_DEVICE_JOYPAD and _get_controls_vibration_row_rect(panel_rect).has_point(position):
		options_focus = 1
		var chevrons := _get_select_chevron_rects(_get_controls_vibration_value_rect(panel_rect))
		var left_rect: Rect2 = chevrons["left"]
		var right_rect: Rect2 = chevrons["right"]
		if left_rect.has_point(position):
			_adjust_gamepad_vibration_level(-1)
		elif right_rect.has_point(position):
			_adjust_gamepad_vibration_level(1)
		return {"handled": true}
	if _get_controls_back_button_rect(panel_rect).has_point(position):
		return _close_options_page()
	return {"handled": true}


func _handle_language_click(position: Vector2, owner: Object, panel_rect: Rect2) -> Dictionary:
	if _get_language_korean_rect(panel_rect).has_point(position):
		options_focus = 0
		_set_language_option(LanguageSettings.LANGUAGE_KOREAN, owner)
		return {"handled": true}
	if _get_language_english_rect(panel_rect).has_point(position):
		options_focus = 1
		_set_language_option(LanguageSettings.LANGUAGE_ENGLISH, owner)
		return {"handled": true}
	if _get_language_chinese_rect(panel_rect).has_point(position):
		options_focus = 2
		_set_language_option(LanguageSettings.LANGUAGE_CHINESE, owner)
		return {"handled": true}
	if _get_language_japanese_rect(panel_rect).has_point(position):
		options_focus = 3
		_set_language_option(LanguageSettings.LANGUAGE_JAPANESE, owner)
		return {"handled": true}
	if _get_language_spanish_rect(panel_rect).has_point(position):
		options_focus = 4
		_set_language_option(LanguageSettings.LANGUAGE_SPANISH, owner)
		return {"handled": true}
	if _get_language_portuguese_brazil_rect(panel_rect).has_point(position):
		options_focus = 5
		_set_language_option(LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL, owner)
		return {"handled": true}
	if _get_language_russian_rect(panel_rect).has_point(position):
		options_focus = 6
		_set_language_option(LanguageSettings.LANGUAGE_RUSSIAN, owner)
		return {"handled": true}
	if _get_language_back_button_rect(panel_rect).has_point(position):
		return _close_options_page()
	return {"handled": true}


func _move_selection(delta: int) -> void:
	var count := 3
	selected_index = (selected_index + delta + count) % count


func _activate_selected(owner: Object, registry: Object) -> Dictionary:
	var entries: Array = _get_main_entries()
	var index: int = clamp(selected_index, 0, entries.size() - 1)
	selected_index = index
	return _activate_entry(str(entries[index].get("action", "")), owner, registry)


func _activate_entry(action: String, _owner: Object, _registry: Object) -> Dictionary:
	match action:
		MENU_CONTINUE:
			close()
			return {"handled": true, "action": MENU_CONTINUE}
		MENU_CHARACTER_INFO:
			close()
			return {"handled": true, "action": MENU_CHARACTER_INFO}
		MENU_OPTIONS:
			_open_options(_owner, _registry)
			return {"handled": true}
	return {"handled": true}


func _open_options(owner: Object, registry: Object) -> void:
	options_open = true
	selected_index = 0
	options_focus = 0
	dragging_slider = ""
	options_tab = OPTIONS_TAB_SOUND
	controls_device_view = CONTROL_DEVICE_KEYBOARD_MOUSE
	_sync_display_settings(owner, registry)
	_sync_controls_settings()
	_sync_language_settings()


func _close_options_page() -> Dictionary:
	options_open = false
	selected_index = 0
	options_focus = 0
	dragging_slider = ""
	if options_only:
		close()
	return {"handled": true}


func _switch_options_tab(direction: int = 1, owner: Object = null, registry: Object = null) -> void:
	var tabs: Array[String] = [OPTIONS_TAB_SOUND, OPTIONS_TAB_DISPLAY, OPTIONS_TAB_CONTROLS, OPTIONS_TAB_LANGUAGE]
	var index: int = tabs.find(options_tab)
	if index < 0:
		index = 0
	var step: int = 1 if direction >= 0 else -1
	options_tab = tabs[(index + step + tabs.size()) % tabs.size()]
	options_focus = 0
	dragging_slider = ""
	if options_tab == OPTIONS_TAB_DISPLAY:
		_sync_display_settings(owner, registry)
	elif options_tab == OPTIONS_TAB_CONTROLS:
		_sync_controls_settings()
	elif options_tab == OPTIONS_TAB_LANGUAGE:
		_sync_language_settings()


func _cycle_display_mode(direction: int) -> void:
	var options: Array[String] = [
		DISPLAY_MODE_FULLSCREEN,
		DISPLAY_MODE_EXCLUSIVE_FULLSCREEN,
		DISPLAY_MODE_WINDOWED,
	]
	var index: int = options.find(display_mode)
	if index < 0:
		index = 0
	var step: int = 1 if direction >= 0 else -1
	_set_display_mode_option(options[(index + step + options.size()) % options.size()])


func _set_display_mode_option(mode: String) -> void:
	var normalized := _normalize_display_mode(mode)
	if normalized != display_mode:
		display_mode = normalized
		_display_preference_dirty = true


func _handle_display_focus_delta(direction: int, owner: Object, registry: Object) -> void:
	if options_focus == 0:
		_cycle_display_mode(direction)
	elif options_focus == 1:
		_cycle_render_fps_cap(direction, owner, registry)
	elif options_focus == 2:
		_cycle_vsync_mode(direction, owner, registry)


func _activate_display_focus(owner: Object, registry: Object) -> Dictionary:
	match options_focus:
		0:
			_cycle_display_mode(1)
		1:
			_cycle_render_fps_cap(1, owner, registry)
		2:
			_cycle_vsync_mode(1, owner, registry)
		3:
			remember_display_mode = not remember_display_mode
			_display_preference_dirty = true
		4:
			auto_refresh_rate_60hz = not auto_refresh_rate_60hz
			_display_preference_dirty = true
		5:
			_apply_recommended_display_settings(owner, registry)
		6:
			_apply_60hz_now(owner, registry)
		7:
			_save_display_options(owner, registry)
		8:
			return _close_options_page()
	return {"handled": true}


func _cycle_control_device_view(direction: int) -> void:
	if direction == 0:
		return
	var views: Array[String] = [CONTROL_DEVICE_KEYBOARD_MOUSE, CONTROL_DEVICE_JOYPAD]
	var index: int = views.find(controls_device_view)
	if index < 0:
		index = 0
	var step: int = 1 if direction >= 0 else -1
	controls_device_view = views[(index + step + views.size()) % views.size()]
	options_focus = clampi(options_focus, 0, _get_controls_focus_count() - 1)


func _adjust_controls_focus(direction: int) -> void:
	if options_focus == 0:
		_cycle_control_device_view(direction)
	elif _is_controls_vibration_focus():
		_adjust_gamepad_vibration_level(direction)


func _adjust_gamepad_vibration_level(direction: int) -> void:
	if direction == 0:
		return
	gamepad_vibration_level = GamepadVibrationSettings.set_vibration_level(gamepad_vibration_level + direction)


func _is_controls_vibration_focus() -> bool:
	return controls_device_view == CONTROL_DEVICE_JOYPAD and options_focus == 1


func _get_controls_focus_count() -> int:
	return CONTROLS_JOYPAD_FOCUS_COUNT if controls_device_view == CONTROL_DEVICE_JOYPAD else CONTROLS_BASE_FOCUS_COUNT


func _get_controls_back_focus_index() -> int:
	return 2 if controls_device_view == CONTROL_DEVICE_JOYPAD else 1


func _sync_controls_settings() -> void:
	gamepad_vibration_level = GamepadVibrationSettings.get_vibration_level()


func _sync_language_settings() -> void:
	language_code = LanguageSettings.get_language()


func _cycle_language(direction: int, owner: Object) -> void:
	if direction == 0:
		return
	var options: Array[String] = LanguageSettings.get_language_options()
	var index: int = options.find(language_code)
	if index < 0:
		index = 0
	var step: int = 1 if direction >= 0 else -1
	_set_language_option(options[(index + step + options.size()) % options.size()], owner)


func _set_language_option(language: String, owner: Object = null) -> void:
	language_code = LanguageSettings.set_language(language)
	_notify_language_changed(owner)


func _activate_language_focus(owner: Object) -> Dictionary:
	match options_focus:
		0:
			_set_language_option(LanguageSettings.LANGUAGE_KOREAN, owner)
		1:
			_set_language_option(LanguageSettings.LANGUAGE_ENGLISH, owner)
		2:
			_set_language_option(LanguageSettings.LANGUAGE_CHINESE, owner)
		3:
			_set_language_option(LanguageSettings.LANGUAGE_JAPANESE, owner)
		4:
			_set_language_option(LanguageSettings.LANGUAGE_SPANISH, owner)
		5:
			_set_language_option(LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL, owner)
		6:
			_set_language_option(LanguageSettings.LANGUAGE_RUSSIAN, owner)
		7:
			return _close_options_page()
	return {"handled": true}


func _reset_current_tab_to_defaults(owner: Object, registry: Object) -> void:
	match options_tab:
		OPTIONS_TAB_SOUND:
			_set_bgm_volume(registry, DEFAULT_BGM_VOLUME)
			_set_sfx_volume(registry, DEFAULT_SFX_VOLUME)
		OPTIONS_TAB_DISPLAY:
			display_mode = DISPLAY_MODE_WINDOWED
			render_fps_cap = RENDER_FPS_CAP_DEFAULT
			vsync_mode = VSYNC_MODE_AUTO
			remember_display_mode = false
			auto_refresh_rate_60hz = false
			_display_preference_dirty = true
			_save_display_options(owner, registry)
		OPTIONS_TAB_CONTROLS:
			controls_device_view = CONTROL_DEVICE_KEYBOARD_MOUSE
			gamepad_vibration_level = GamepadVibrationSettings.VIBRATION_LEVEL_DEFAULT
			GamepadVibrationSettings.set_vibration_level(gamepad_vibration_level)
			options_focus = clampi(options_focus, 0, _get_controls_focus_count() - 1)
		OPTIONS_TAB_LANGUAGE:
			_set_language_option(LanguageSettings.DEFAULT_LANGUAGE, owner)


func _notify_language_changed(owner: Object) -> void:
	if owner != null and owner.has_method("refresh_language_texts"):
		owner.refresh_language_texts()


func _cycle_render_fps_cap(direction: int, owner: Object, registry: Object) -> void:
	var options: Array[int] = _get_render_fps_cap_options(registry)
	var index: int = options.find(render_fps_cap)
	if index < 0:
		index = 0
	var step: int = 1 if direction >= 0 else -1
	render_fps_cap = int(options[(index + step + options.size()) % options.size()])
	var view_layout: Object = _get_instance(registry, "battle_view_layout")
	if view_layout != null and view_layout.has_method("apply_render_fps_cap"):
		render_fps_cap = int(view_layout.apply_render_fps_cap(_get_owner_window(owner), render_fps_cap, vsync_mode))
	if vsync_mode == VSYNC_MODE_AUTO and view_layout != null and view_layout.has_method("apply_vsync_mode"):
		vsync_mode = int(view_layout.apply_vsync_mode(vsync_mode, _get_owner_window(owner)))


func _cycle_vsync_mode(direction: int, owner: Object, registry: Object) -> void:
	var options: Array[int] = _get_vsync_mode_options(registry)
	var index: int = options.find(vsync_mode)
	if index < 0:
		index = 0
	var step: int = 1 if direction >= 0 else -1
	vsync_mode = int(options[(index + step + options.size()) % options.size()])
	var view_layout: Object = _get_instance(registry, "battle_view_layout")
	if view_layout != null and view_layout.has_method("apply_vsync_mode"):
		vsync_mode = int(view_layout.apply_vsync_mode(vsync_mode, _get_owner_window(owner)))
	if view_layout != null and view_layout.has_method("apply_render_fps_cap"):
		render_fps_cap = int(view_layout.apply_render_fps_cap(_get_owner_window(owner), render_fps_cap, vsync_mode))


func _sync_display_settings(owner: Object, registry: Object) -> void:
	var view_layout: Object = _get_instance(registry, "battle_view_layout")
	var window: Object = _get_owner_window(owner)
	if view_layout != null and view_layout.has_method("get_remember_display_mode"):
		remember_display_mode = bool(view_layout.get_remember_display_mode())
	if view_layout != null and view_layout.has_method("get_display_mode"):
		if remember_display_mode and view_layout.has_method("get_saved_display_mode"):
			display_mode = _normalize_display_mode(str(view_layout.get_saved_display_mode()))
		else:
			display_mode = _normalize_display_mode(str(view_layout.get_display_mode(window)))
	elif view_layout != null and view_layout.has_method("is_fullscreen"):
		display_mode = DISPLAY_MODE_FULLSCREEN if bool(view_layout.is_fullscreen(window)) else DISPLAY_MODE_WINDOWED
	if view_layout != null and view_layout.has_method("get_saved_render_fps_cap"):
		render_fps_cap = int(view_layout.get_saved_render_fps_cap())
	elif view_layout != null and view_layout.has_method("get_render_fps_cap"):
		render_fps_cap = int(view_layout.get_render_fps_cap(window))
	if view_layout != null and view_layout.has_method("get_saved_vsync_mode"):
		vsync_mode = int(view_layout.get_saved_vsync_mode())
	elif view_layout != null and view_layout.has_method("get_vsync_mode"):
		vsync_mode = int(view_layout.get_vsync_mode())
	if view_layout != null and view_layout.has_method("get_auto_refresh_rate_enabled"):
		auto_refresh_rate_60hz = bool(view_layout.get_auto_refresh_rate_enabled())
	_synced_display_mode = display_mode
	_synced_remember_display_mode = remember_display_mode
	_synced_auto_refresh_rate_60hz = auto_refresh_rate_60hz
	_display_preference_dirty = false


func _save_display_options(owner: Object, registry: Object) -> void:
	display_mode = _normalize_display_mode(display_mode)
	var view_layout: Object = _get_instance(registry, "battle_view_layout")
	var window: Object = _get_owner_window(owner)
	var should_save_display := (
		_display_preference_dirty
		or display_mode != _synced_display_mode
		or remember_display_mode != _synced_remember_display_mode
		or auto_refresh_rate_60hz != _synced_auto_refresh_rate_60hz
		or remember_display_mode
		or display_mode != DISPLAY_MODE_WINDOWED
	)
	if should_save_display:
		if view_layout != null and view_layout.has_method("apply_display_mode"):
			display_mode = _normalize_display_mode(str(view_layout.apply_display_mode(window, display_mode)))
		elif view_layout != null and view_layout.has_method("toggle_fullscreen"):
			var current_mode := DISPLAY_MODE_WINDOWED
			if view_layout.has_method("get_display_mode"):
				current_mode = _normalize_display_mode(str(view_layout.get_display_mode(window)))
			if current_mode != display_mode:
				view_layout.toggle_fullscreen(window)
		if view_layout != null and view_layout.has_method("save_display_mode_default"):
			view_layout.save_display_mode_default(display_mode, remember_display_mode)
		_synced_display_mode = display_mode
		_synced_remember_display_mode = remember_display_mode
		_synced_auto_refresh_rate_60hz = auto_refresh_rate_60hz
		_display_preference_dirty = false
	if view_layout != null and view_layout.has_method("apply_render_fps_cap"):
		render_fps_cap = int(view_layout.apply_render_fps_cap(window, render_fps_cap, vsync_mode))
	if view_layout != null and view_layout.has_method("save_render_fps_cap_default"):
		view_layout.save_render_fps_cap_default(render_fps_cap)
	if view_layout != null and view_layout.has_method("apply_vsync_mode"):
		vsync_mode = int(view_layout.apply_vsync_mode(vsync_mode, window))
	if view_layout != null and view_layout.has_method("save_vsync_mode_default"):
		view_layout.save_vsync_mode_default(vsync_mode)
	if view_layout != null and view_layout.has_method("save_auto_refresh_rate_default"):
		view_layout.save_auto_refresh_rate_default(auto_refresh_rate_60hz, window)
	elif view_layout != null and view_layout.has_method("apply_auto_refresh_rate"):
		view_layout.apply_auto_refresh_rate(window, auto_refresh_rate_60hz)


func _apply_recommended_display_settings(owner: Object, registry: Object) -> void:
	display_mode = DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
	remember_display_mode = true
	render_fps_cap = RENDER_FPS_CAP_MONITOR
	vsync_mode = VSYNC_MODE_AUTO
	auto_refresh_rate_60hz = false
	_display_preference_dirty = true
	_save_display_options(owner, registry)


func _apply_60hz_now(owner: Object, registry: Object) -> void:
	var view_layout: Object = _get_instance(registry, "battle_view_layout")
	var window: Object = _get_owner_window(owner)
	var applied := false
	auto_refresh_rate_60hz = true
	_synced_auto_refresh_rate_60hz = true
	if view_layout != null and view_layout.has_method("save_auto_refresh_rate_default"):
		applied = bool(view_layout.save_auto_refresh_rate_default(true, window))
	elif view_layout != null and view_layout.has_method("apply_auto_refresh_rate"):
		applied = bool(view_layout.apply_auto_refresh_rate(window, true))
	if not applied:
		_open_system_display_settings(registry)


func _normalize_display_mode(mode: String) -> String:
	var normalized := mode.strip_edges().to_lower()
	if normalized == DISPLAY_MODE_EXCLUSIVE_FULLSCREEN or normalized == "exclusive":
		return DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
	if normalized == DISPLAY_MODE_FULLSCREEN:
		return DISPLAY_MODE_FULLSCREEN
	return DISPLAY_MODE_WINDOWED


func _get_display_mode_description() -> String:
	if display_mode == DISPLAY_MODE_EXCLUSIVE_FULLSCREEN:
		return _text("display.desc.exclusive")
	if display_mode == DISPLAY_MODE_FULLSCREEN:
		return _text("display.desc.fullscreen")
	return _text("display.desc.windowed")


func _get_render_fps_cap_options(registry: Object) -> Array[int]:
	var view_layout: Object = _get_instance(registry, "battle_view_layout")
	if view_layout != null and view_layout.has_method("get_render_fps_cap_options"):
		var raw_options: Variant = view_layout.get_render_fps_cap_options()
		if raw_options is Array:
			var options: Array[int] = []
			for raw_value in raw_options:
				options.append(int(raw_value))
			if not options.is_empty():
				return options
	return [
		RENDER_FPS_CAP_UNLIMITED,
		RENDER_FPS_CAP_STABILITY,
		RENDER_FPS_CAP_SMOOTH,
		RENDER_FPS_CAP_BALANCED,
		RENDER_FPS_CAP_STABLE_MONITOR,
		RENDER_FPS_CAP_MONITOR,
	]


func _get_render_fps_cap_label(registry: Object, owner: Object = null) -> String:
	var view_layout: Object = _get_instance(registry, "battle_view_layout")
	if render_fps_cap == RENDER_FPS_CAP_UNLIMITED:
		return _text("display.fps.unlimited")
	if render_fps_cap == RENDER_FPS_CAP_MONITOR:
		return _text("display.fps.monitor") % _get_monitor_refresh_rate(registry, owner)
	if view_layout != null and view_layout.has_method("get_render_fps_cap_label"):
		return str(view_layout.get_render_fps_cap_label(render_fps_cap, _get_owner_window(owner)))
	if render_fps_cap == RENDER_FPS_CAP_STABLE_MONITOR:
		return "Stable 48 FPS"
	return "%d FPS" % render_fps_cap


func _get_vsync_mode_options(registry: Object) -> Array[int]:
	var view_layout: Object = _get_instance(registry, "battle_view_layout")
	if view_layout != null and view_layout.has_method("get_vsync_mode_options"):
		var raw_options: Variant = view_layout.get_vsync_mode_options()
		if raw_options is Array:
			var options: Array[int] = []
			for raw_value in raw_options:
				options.append(int(raw_value))
			if not options.is_empty():
				return options
	return [
		VSYNC_MODE_AUTO,
		VSYNC_MODE_ENABLED,
		VSYNC_MODE_MAILBOX,
		VSYNC_MODE_DISABLED,
	]


func _get_vsync_mode_label(registry: Object) -> String:
	var view_layout: Object = _get_instance(registry, "battle_view_layout")
	if view_layout != null and view_layout.has_method("get_vsync_mode_label"):
		return str(view_layout.get_vsync_mode_label(vsync_mode))
	if vsync_mode == VSYNC_MODE_AUTO:
		return "Auto"
	if vsync_mode == VSYNC_MODE_DISABLED:
		return "VSync Off"
	if vsync_mode == VSYNC_MODE_MAILBOX:
		return "Mailbox"
	return "VSync On"


func _get_display_pacing_recommendation(registry: Object, owner: Object = null) -> String:
	var monitor_rate: int = _get_monitor_refresh_rate(registry, owner)
	if monitor_rate <= 0:
		return _text("display.recommendation.fallback")
	var game_settings_ready := (
		display_mode == DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
		and render_fps_cap == RENDER_FPS_CAP_MONITOR
		and (
			vsync_mode == VSYNC_MODE_AUTO
			or vsync_mode == VSYNC_MODE_ENABLED
		)
	)
	if game_settings_ready:
		return _text("display.recommendation.ready") % monitor_rate
	if render_fps_cap == RENDER_FPS_CAP_MONITOR:
		return _text("display.recommendation.monitor") % monitor_rate
	return _text("display.recommendation.default") % monitor_rate


func _get_monitor_refresh_rate(registry: Object, owner: Object = null) -> int:
	var view_layout: Object = _get_instance(registry, "battle_view_layout")
	if view_layout != null and view_layout.has_method("get_monitor_refresh_rate"):
		return int(view_layout.get_monitor_refresh_rate(_get_owner_window(owner)))
	return 60


func _text(key: String, fallback: String = "") -> String:
	return LanguageSettings.translate(key, fallback)


func _open_system_display_settings(registry: Object) -> void:
	var view_layout: Object = _get_instance(registry, "battle_view_layout")
	if view_layout != null and view_layout.has_method("open_system_display_settings"):
		view_layout.open_system_display_settings()
		return
	if OS.get_name() == "Windows":
		OS.shell_open("ms-settings:display")


func _get_owner_window(owner: Object) -> Object:
	if owner != null and owner.has_method("get_window"):
		var window: Variant = owner.get_window()
		if typeof(window) == TYPE_OBJECT and is_instance_valid(window):
			return window as Object
	return null


func _adjust_focused_volume(registry: Object, delta: float) -> void:
	if options_focus == 0:
		_set_bgm_volume(registry, _get_bgm_volume(registry) + delta)
	elif options_focus == 1:
		_set_sfx_volume(registry, _get_sfx_volume(registry) + delta)


func _set_volume_from_slider(slider_key: String, mouse_x: float, registry: Object, view_size: Vector2) -> void:
	var slider_rect: Rect2 = _get_slider_rect(slider_key, view_size)
	var value: float = 0.0
	if slider_rect.size.x > 0.0:
		value = clampf((mouse_x - slider_rect.position.x) / slider_rect.size.x, 0.0, 1.0)
	if slider_key == SOUND_SLIDER_BGM:
		_set_bgm_volume(registry, value)
	elif slider_key == SOUND_SLIDER_SFX:
		_set_sfx_volume(registry, value)


func _draw_main_menu(canvas: CanvasItem, font: Font, panel_rect: Rect2, mouse_pos: Vector2) -> void:
	_draw_text_centered(canvas, font, _text("pause.title"), panel_rect.position + Vector2(panel_rect.size.x * 0.5, 47.0), 28, Color.WHITE)
	_draw_text_centered(canvas, font, _text("app.title"), panel_rect.position + Vector2(panel_rect.size.x * 0.5, 72.0), 12, TEXT_DIM)
	var entries: Array = _get_main_entries()
	for index in range(entries.size()):
		_draw_button(canvas, font, _get_button_rect(panel_rect, index, entries.size()), str(entries[index].get("label", "")), index == selected_index, mouse_pos)


func _draw_options_window(canvas: CanvasItem, font: Font, panel_rect: Rect2, mouse_pos: Vector2, registry: Object, owner: Object = null) -> void:
	var header_rect := Rect2(panel_rect.position, Vector2(panel_rect.size.x, 62.0))
	canvas.draw_rect(header_rect, HEADER_COLOR)
	_draw_neon_line(canvas, panel_rect.position + Vector2(14.0, 62.0), Vector2(panel_rect.end.x - 14.0, panel_rect.position.y + 62.0), NEON_CYAN, 1.5)
	_draw_text(canvas, font, _text("settings.title"), panel_rect.position + Vector2(28.0, 40.0), 24, Color.WHITE)
	_draw_tab(canvas, font, _get_sound_tab_rect(panel_rect), _text("settings.tab.sound"), options_tab == OPTIONS_TAB_SOUND, "sound")
	_draw_tab(canvas, font, _get_display_tab_rect(panel_rect), _text("settings.tab.display"), options_tab == OPTIONS_TAB_DISPLAY, "display")
	_draw_tab(canvas, font, _get_controls_tab_rect(panel_rect), _text("settings.tab.controls"), options_tab == OPTIONS_TAB_CONTROLS, "controls")
	_draw_tab(canvas, font, _get_language_tab_rect(panel_rect), _text("settings.tab.language"), options_tab == OPTIONS_TAB_LANGUAGE, "language")
	_draw_button(canvas, font, _get_reset_button_rect(panel_rect), _text("settings.reset", "초기화"), false, mouse_pos)

	var content_rect := Rect2(panel_rect.position + Vector2(28.0, 84.0), Vector2(panel_rect.size.x - 56.0, panel_rect.size.y - 166.0))
	_draw_panel(canvas, content_rect, SECTION_COLOR, Color(PANEL_BORDER.r, PANEL_BORDER.g, PANEL_BORDER.b, 0.42), 1.0)
	_draw_scanlines(canvas, content_rect)
	if options_tab == OPTIONS_TAB_DISPLAY:
		_draw_display_tab(canvas, font, panel_rect, mouse_pos, registry, owner)
	elif options_tab == OPTIONS_TAB_CONTROLS:
		_draw_controls_tab(canvas, font, panel_rect, mouse_pos)
	elif options_tab == OPTIONS_TAB_LANGUAGE:
		_draw_language_tab(canvas, font, panel_rect, mouse_pos)
	else:
		_draw_volume_slider(canvas, font, SOUND_SLIDER_BGM, _text("sound.bgm_volume"), _get_bgm_volume(registry), ACCENT_BLUE, options_focus == 0, mouse_pos, panel_rect)
		_draw_volume_slider(canvas, font, SOUND_SLIDER_SFX, _text("sound.sfx_volume"), _get_sfx_volume(registry), ACCENT_GREEN, options_focus == 1, mouse_pos, panel_rect)

	if options_tab == OPTIONS_TAB_SOUND:
		var back_rect: Rect2 = _get_back_button_rect(panel_rect)
		_draw_button(canvas, font, back_rect, _get_options_back_label(), options_focus == 2, mouse_pos)
	_draw_hud_readout_bar(canvas, font, panel_rect, _get_focused_option_description(options_tab, options_focus))


func _draw_tab(canvas: CanvasItem, font: Font, rect: Rect2, label: String, active_tab: bool, icon_kind: String = "") -> void:
	var draw_rect := rect
	if active_tab:
		draw_rect.position.y -= 2.0
	var fill := BUTTON_SELECTED if active_tab else BUTTON_COLOR
	var border := NEON_CYAN_HOT if active_tab else BUTTON_BORDER
	_draw_panel(canvas, draw_rect, fill, border, 1.0)
	if active_tab:
		_draw_neon_line(canvas, Vector2(draw_rect.position.x + 4.0, draw_rect.end.y), Vector2(draw_rect.end.x - 4.0, draw_rect.end.y), NEON_CYAN, 1.2)
		canvas.draw_line(draw_rect.position + Vector2(4.0, 1.0), Vector2(draw_rect.end.x - 4.0, draw_rect.position.y + 1.0), RESONANCE_MAG, 1.0)
	var label_rect := draw_rect
	if not icon_kind.is_empty():
		var icon_rect := Rect2(draw_rect.position + Vector2(10.0, (draw_rect.size.y - 18.0) * 0.5), Vector2(18.0, 18.0))
		var icon_color := NEON_CYAN_HOT if active_tab else Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.60)
		_draw_tab_icon(canvas, icon_kind, icon_rect, icon_color)
		label_rect = Rect2(draw_rect.position + Vector2(29.0, 0.0), Vector2(maxf(0.0, draw_rect.size.x - 31.0), draw_rect.size.y))
	_draw_text_in_rect(canvas, font, label, label_rect, 15, Color.WHITE)


func _draw_tab_icon(canvas: CanvasItem, kind: String, icon_rect: Rect2, color: Color) -> void:
	var center := icon_rect.get_center()
	match kind:
		"sound":
			canvas.draw_colored_polygon(
				PackedVector2Array([
					icon_rect.position + Vector2(2.0, 7.0),
					icon_rect.position + Vector2(6.0, 7.0),
					icon_rect.position + Vector2(11.0, 3.0),
					icon_rect.position + Vector2(11.0, 15.0),
					icon_rect.position + Vector2(6.0, 11.0),
					icon_rect.position + Vector2(2.0, 11.0),
				]),
				color
			)
			canvas.draw_arc(center + Vector2(3.0, 0.0), 5.0, -0.8, 0.8, 12, color, 1.2)
			canvas.draw_arc(center + Vector2(3.0, 0.0), 8.0, -0.7, 0.7, 12, Color(color.r, color.g, color.b, color.a * 0.70), 1.0)
		"display":
			var screen := Rect2(icon_rect.position + Vector2(2.0, 3.0), Vector2(14.0, 10.0))
			canvas.draw_rect(screen, color, false, 1.2)
			canvas.draw_line(Vector2(center.x, screen.end.y), Vector2(center.x, screen.end.y + 3.0), color, 1.2)
			canvas.draw_line(Vector2(center.x - 5.0, screen.end.y + 3.0), Vector2(center.x + 5.0, screen.end.y + 3.0), color, 1.2)
		"controls":
			var body := Rect2(icon_rect.position + Vector2(1.5, 5.0), Vector2(15.0, 9.0))
			var radius := body.size.y * 0.5
			var left_center := body.position + Vector2(radius, radius)
			var right_center := Vector2(body.end.x - radius, body.position.y + radius)
			canvas.draw_arc(left_center, radius, PI * 0.5, PI * 1.5, 10, color, 1.2)
			canvas.draw_arc(right_center, radius, -PI * 0.5, PI * 0.5, 10, color, 1.2)
			canvas.draw_line(Vector2(left_center.x, body.position.y), Vector2(right_center.x, body.position.y), color, 1.2)
			canvas.draw_line(Vector2(left_center.x, body.end.y), Vector2(right_center.x, body.end.y), color, 1.2)
			var dpad_center := body.position + Vector2(4.5, 4.5)
			canvas.draw_line(dpad_center + Vector2(-2.5, 0.0), dpad_center + Vector2(2.5, 0.0), color, 1.1)
			canvas.draw_line(dpad_center + Vector2(0.0, -2.5), dpad_center + Vector2(0.0, 2.5), color, 1.1)
			canvas.draw_circle(body.position + Vector2(10.5, 3.2), 1.2, color)
			canvas.draw_circle(body.position + Vector2(13.0, 5.8), 1.2, color)
		"language":
			canvas.draw_arc(center, 7.0, 0.0, TAU, 24, color, 1.2)
			canvas.draw_arc(center, 3.5, -PI * 0.5, PI * 0.5, 16, color, 1.0)
			canvas.draw_arc(center, 3.5, PI * 0.5, PI * 1.5, 16, color, 1.0)
			canvas.draw_line(center + Vector2(-6.0, -2.5), center + Vector2(6.0, -2.5), Color(color.r, color.g, color.b, color.a * 0.72), 1.0)
			canvas.draw_line(center + Vector2(-6.0, 2.5), center + Vector2(6.0, 2.5), Color(color.r, color.g, color.b, color.a * 0.72), 1.0)


func _draw_scanlines(canvas: CanvasItem, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var color := Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.04)
	var start_y := int(rect.position.y) + 2
	var end_y := int(rect.end.y)
	for y in range(start_y, end_y, 3):
		canvas.draw_line(Vector2(rect.position.x, float(y)), Vector2(rect.end.x, float(y)), color, 1.0)


func _draw_volume_slider(
	canvas: CanvasItem,
	font: Font,
	slider_key: String,
	label: String,
	value: float,
	accent: Color,
	focused: bool,
	mouse_pos: Vector2,
	panel_rect: Rect2
) -> void:
	var slider_rect: Rect2 = _get_slider_rect_from_panel(slider_key, panel_rect)
	var row_center_y: float = slider_rect.get_center().y
	_draw_text(canvas, font, label, Vector2(panel_rect.position.x + 54.0, row_center_y + 7.0), 18, Color.WHITE)
	canvas.draw_rect(slider_rect, SLIDER_BACK)
	var fill_rect := Rect2(slider_rect.position, Vector2(slider_rect.size.x * clampf(value, 0.0, 1.0), slider_rect.size.y))
	canvas.draw_rect(fill_rect, accent)
	var handle_x: float = slider_rect.position.x + slider_rect.size.x * clampf(value, 0.0, 1.0)
	var handle_color := Color.WHITE if focused or _get_slider_hit_rect_from_panel(slider_key, panel_rect).has_point(mouse_pos) else Color(215.0 / 255.0, 220.0 / 255.0, 230.0 / 255.0)
	canvas.draw_circle(Vector2(handle_x, row_center_y), SLIDER_HANDLE_RADIUS + (2.0 if focused else 0.0), handle_color)
	var percent := "%d%%" % int(round(value * 100.0))
	_draw_text(canvas, font, percent, Vector2(slider_rect.end.x + 18.0, row_center_y + 6.0), 15, accent)


func _draw_display_tab(canvas: CanvasItem, font: Font, panel_rect: Rect2, mouse_pos: Vector2, registry: Object, owner: Object = null) -> void:
	var label_pos := panel_rect.position + Vector2(54.0, 137.0)
	_draw_text(canvas, font, _text("display.mode"), label_pos, 19, Color.WHITE)
	_draw_mode_pill(canvas, font, _get_display_fullscreen_rect(panel_rect), _text("display.mode.fullscreen"), display_mode == DISPLAY_MODE_FULLSCREEN, options_focus == 0, mouse_pos)
	_draw_mode_pill(canvas, font, _get_display_exclusive_fullscreen_rect(panel_rect), _text("display.mode.exclusive"), display_mode == DISPLAY_MODE_EXCLUSIVE_FULLSCREEN, options_focus == 0, mouse_pos)
	_draw_mode_pill(canvas, font, _get_display_windowed_rect(panel_rect), _text("display.mode.windowed"), display_mode == DISPLAY_MODE_WINDOWED, options_focus == 0, mouse_pos)

	var desc := _get_display_mode_description()
	_draw_text(canvas, font, desc, panel_rect.position + Vector2(280.0, 162.0), 13, TEXT_DIM)

	var fps_row_rect: Rect2 = _get_display_fps_cap_row_rect(panel_rect)
	var fps_value_rect: Rect2 = _get_display_fps_cap_value_rect(panel_rect)
	_draw_setting_select_row(
		canvas,
		font,
		fps_row_rect,
		fps_value_rect,
		_text("display.render_fps"),
		_get_render_fps_cap_label(registry, owner),
		options_focus == 1,
		mouse_pos
	)

	var vsync_row_rect: Rect2 = _get_display_vsync_row_rect(panel_rect)
	var vsync_value_rect: Rect2 = _get_display_vsync_value_rect(panel_rect)
	_draw_setting_select_row(
		canvas,
		font,
		vsync_row_rect,
		vsync_value_rect,
		"VSync",
		_get_vsync_mode_label(registry),
		options_focus == 2,
		mouse_pos
	)

	var checkbox_rect: Rect2 = _get_display_default_checkbox_rect(panel_rect)
	var row_rect: Rect2 = _get_display_default_row_rect(panel_rect)
	_draw_toggle_setting_row(
		canvas,
		font,
		row_rect,
		checkbox_rect,
		_text("display.remember.title"),
		_text("display.remember.subtitle"),
		remember_display_mode,
		options_focus == 3,
		mouse_pos
	)

	var auto_checkbox_rect: Rect2 = _get_display_auto_refresh_checkbox_rect(panel_rect)
	var auto_row_rect: Rect2 = _get_display_auto_refresh_row_rect(panel_rect)
	_draw_toggle_setting_row(
		canvas,
		font,
		auto_row_rect,
		auto_checkbox_rect,
		_text("display.auto60.title"),
		_text("display.auto60.subtitle"),
		auto_refresh_rate_60hz,
		options_focus == 4,
		mouse_pos,
		true
	)

	_draw_recommendation_block(canvas, font, _get_display_pacing_recommendation_rect(panel_rect), _get_display_pacing_recommendation(registry, owner))
	_draw_button(canvas, font, _get_display_recommended_button_rect(panel_rect), _text("display.recommend.apply"), options_focus == 5, mouse_pos)
	_draw_button(canvas, font, _get_display_apply_60hz_button_rect(panel_rect), _text("display.apply60"), options_focus == 6, mouse_pos)
	_draw_button(canvas, font, _get_display_save_button_rect(panel_rect), _text("settings.save"), options_focus == 7, mouse_pos)
	_draw_button(canvas, font, _get_display_back_button_rect(panel_rect), _get_options_back_label(), options_focus == 8, mouse_pos)


func _draw_controls_tab(canvas: CanvasItem, font: Font, panel_rect: Rect2, mouse_pos: Vector2) -> void:
	_draw_text(canvas, font, _text("controls.device"), panel_rect.position + Vector2(54.0, 137.0), 19, Color.WHITE)
	_draw_mode_pill(
		canvas,
		font,
		_get_controls_keyboard_mouse_rect(panel_rect),
		_text("controls.keyboard_mouse"),
		controls_device_view == CONTROL_DEVICE_KEYBOARD_MOUSE,
		options_focus == 0,
		mouse_pos
	)
	_draw_mode_pill(
		canvas,
		font,
		_get_controls_joypad_rect(panel_rect),
		_text("controls.joypad"),
		controls_device_view == CONTROL_DEVICE_JOYPAD,
		options_focus == 0,
		mouse_pos
	)
	if controls_device_view == CONTROL_DEVICE_JOYPAD:
		var vibration_row_rect: Rect2 = _get_controls_vibration_row_rect(panel_rect)
		_draw_setting_select_row(
			canvas,
			font,
			vibration_row_rect,
			_get_controls_vibration_value_rect(panel_rect),
			_text("controls.vibration"),
			_get_vibration_level_label(gamepad_vibration_level),
			options_focus == 1,
			mouse_pos
		)
	var rows: Array = _get_control_mapping_rows()
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		_draw_control_mapping_row(
			canvas,
			font,
			_get_controls_mapping_row_rect(panel_rect, index),
			str(row.get("label", "")),
			str(row.get("value", ""))
		)
	_draw_button(canvas, font, _get_controls_back_button_rect(panel_rect), _get_options_back_label(), options_focus == _get_controls_back_focus_index(), mouse_pos)


func _draw_language_tab(canvas: CanvasItem, font: Font, panel_rect: Rect2, mouse_pos: Vector2) -> void:
	_draw_text(canvas, font, _text("language.title"), panel_rect.position + Vector2(54.0, 137.0), 19, Color.WHITE)
	_draw_mode_pill(
		canvas,
		font,
		_get_language_korean_rect(panel_rect),
		_text("language.ko"),
		language_code == LanguageSettings.LANGUAGE_KOREAN,
		options_focus == 0,
		mouse_pos
	)
	_draw_mode_pill(
		canvas,
		font,
		_get_language_english_rect(panel_rect),
		_text("language.en"),
		language_code == LanguageSettings.LANGUAGE_ENGLISH,
		options_focus == 1,
		mouse_pos
	)
	_draw_mode_pill(
		canvas,
		font,
		_get_language_chinese_rect(panel_rect),
		_text("language.zh"),
		language_code == LanguageSettings.LANGUAGE_CHINESE,
		options_focus == 2,
		mouse_pos
	)
	_draw_mode_pill(
		canvas,
		font,
		_get_language_japanese_rect(panel_rect),
		_text("language.ja"),
		language_code == LanguageSettings.LANGUAGE_JAPANESE,
		options_focus == 3,
		mouse_pos
	)
	_draw_mode_pill(
		canvas,
		font,
		_get_language_spanish_rect(panel_rect),
		_text("language.es"),
		language_code == LanguageSettings.LANGUAGE_SPANISH,
		options_focus == 4,
		mouse_pos
	)
	_draw_mode_pill(
		canvas,
		font,
		_get_language_portuguese_brazil_rect(panel_rect),
		_text("language.pt_br"),
		language_code == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL,
		options_focus == 5,
		mouse_pos
	)
	_draw_mode_pill(
		canvas,
		font,
		_get_language_russian_rect(panel_rect),
		_text("language.ru"),
		language_code == LanguageSettings.LANGUAGE_RUSSIAN,
		options_focus == 6,
		mouse_pos
	)
	var current_name := LanguageSettings.get_native_language_name(language_code)
	_draw_text(canvas, font, _text("language.current") % current_name, panel_rect.position + Vector2(96.0, 260.0), 18, Color.WHITE)
	_draw_recommendation_block(canvas, font, _get_language_note_rect(panel_rect), _text("language.subtitle"))
	_draw_button(canvas, font, _get_language_back_button_rect(panel_rect), _get_options_back_label(), options_focus == 7, mouse_pos)


func _get_vibration_level_label(level: int = 0) -> String:
	var normalized: int = GamepadVibrationSettings.get_vibration_level() if level < GamepadVibrationSettings.VIBRATION_LEVEL_MIN else GamepadVibrationSettings.normalize_vibration_level(level)
	var name := _text("vibration.%d" % normalized)
	return "%d / %d %s" % [normalized, GamepadVibrationSettings.VIBRATION_LEVEL_MAX, name]


func _draw_control_mapping_row(canvas: CanvasItem, font: Font, rect: Rect2, label: String, value: String) -> void:
	_draw_panel(canvas, rect, Color(26.0 / 255.0, 34.0 / 255.0, 50.0 / 255.0, 0.88), Color(BUTTON_BORDER.r, BUTTON_BORDER.g, BUTTON_BORDER.b, 0.28), 1.0)
	var label_size: int = 16 if rect.size.y >= 34.0 else 14
	var value_size: int = 15 if rect.size.y >= 34.0 else 13
	var baseline_y: float = minf(27.0, rect.size.y - 8.0)
	_draw_text(canvas, font, label, rect.position + Vector2(18.0, baseline_y), label_size, Color.WHITE)
	_draw_text(canvas, font, value, rect.position + Vector2(220.0, baseline_y), value_size, Color(218.0 / 255.0, 230.0 / 255.0, 244.0 / 255.0))


func _draw_mode_pill(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	label: String,
	selected: bool,
	focused: bool,
	mouse_pos: Vector2
) -> void:
	var hovered: bool = rect.has_point(mouse_pos)
	var fill := BUTTON_SELECTED if selected else BUTTON_COLOR
	if hovered:
		fill = BUTTON_HOVER
	var border := NEON_CYAN_HOT if hovered else (ACCENT_BLUE if selected or focused else Color(BUTTON_BORDER.r, BUTTON_BORDER.g, BUTTON_BORDER.b, 0.42))
	_draw_panel(canvas, rect, fill, border, 2.0 if selected or focused else 1.0)
	_draw_text_in_rect(canvas, font, label, rect, 17, Color.WHITE)


func _draw_setting_select_row(
	canvas: CanvasItem,
	font: Font,
	row_rect: Rect2,
	value_rect: Rect2,
	label: String,
	value: String,
	focused: bool,
	mouse_pos: Vector2
) -> void:
	var hovered: bool = row_rect.has_point(mouse_pos)
	var fill := Color(25.0 / 255.0, 33.0 / 255.0, 50.0 / 255.0, 0.94)
	if hovered or focused:
		fill = Color(31.0 / 255.0, 43.0 / 255.0, 64.0 / 255.0, 0.98)
	var border := NEON_CYAN_HOT if hovered else (ACCENT_BLUE if focused else Color(BUTTON_BORDER.r, BUTTON_BORDER.g, BUTTON_BORDER.b, 0.24))
	_draw_panel(canvas, row_rect, fill, border, 1.0)
	_draw_text(canvas, font, label, row_rect.position + Vector2(18.0, 29.0), 16, Color.WHITE)
	_draw_panel(canvas, value_rect, BUTTON_COLOR, Color(BUTTON_BORDER.r, BUTTON_BORDER.g, BUTTON_BORDER.b, 0.48), 1.0)
	var chevrons := _get_select_chevron_rects(value_rect)
	var left_rect: Rect2 = chevrons["left"]
	var right_rect: Rect2 = chevrons["right"]
	var left_color := NEON_CYAN_HOT if left_rect.has_point(mouse_pos) else NEON_CYAN
	var right_color := NEON_CYAN_HOT if right_rect.has_point(mouse_pos) else NEON_CYAN
	var left_center := Vector2(value_rect.position.x + 14.0, value_rect.get_center().y)
	var right_center := Vector2(value_rect.end.x - 14.0, value_rect.get_center().y)
	canvas.draw_colored_polygon(
		PackedVector2Array([
			left_center + Vector2(4.0, -7.0),
			left_center + Vector2(-5.0, 0.0),
			left_center + Vector2(4.0, 7.0),
		]),
		left_color
	)
	canvas.draw_colored_polygon(
		PackedVector2Array([
			right_center + Vector2(-4.0, -7.0),
			right_center + Vector2(5.0, 0.0),
			right_center + Vector2(-4.0, 7.0),
		]),
		right_color
	)
	_draw_text_in_rect(canvas, font, value, value_rect, 15, Color.WHITE)
	if focused:
		_draw_holo_focus_frame(canvas, row_rect, _focus_pulse_alpha())


func _draw_toggle_setting_row(
	canvas: CanvasItem,
	font: Font,
	row_rect: Rect2,
	checkbox_rect: Rect2,
	title: String,
	subtitle: String,
	enabled: bool,
	focused: bool,
	mouse_pos: Vector2,
	muted: bool = false
) -> void:
	var hovered: bool = row_rect.has_point(mouse_pos)
	var fill := Color(24.0 / 255.0, 31.0 / 255.0, 46.0 / 255.0, 0.90)
	if hovered or focused:
		fill = Color(30.0 / 255.0, 42.0 / 255.0, 62.0 / 255.0, 0.96)
	var border := ACCENT_BLUE if hovered or focused else Color(BUTTON_BORDER.r, BUTTON_BORDER.g, BUTTON_BORDER.b, 0.20)
	_draw_panel(canvas, row_rect, fill, border, 1.0)
	var checkbox_fill := Color(0.0, 0.24, 0.14, 0.95) if enabled else Color(0.02, 0.05, 0.08, 0.95)
	var checkbox_border := NEON_GREEN if enabled else Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.72)
	_draw_panel(canvas, checkbox_rect, checkbox_fill, checkbox_border, 1.0)
	if enabled:
		var center := checkbox_rect.get_center()
		canvas.draw_line(center + Vector2(-5.0, 0.0), center + Vector2(-1.5, 4.0), NEON_CYAN_HOT, 2.5)
		canvas.draw_line(center + Vector2(-1.5, 4.0), center + Vector2(6.0, -5.0), NEON_CYAN_HOT, 2.5)
	var title_color := Color(1.0, 1.0, 1.0, 0.88) if muted and not enabled else Color.WHITE
	_draw_text(canvas, font, title, row_rect.position + Vector2(58.0, 24.0), 15, title_color)
	_draw_toggle_leader(canvas, font, row_rect, checkbox_rect, title)
	_draw_text(canvas, font, subtitle, row_rect.position + Vector2(58.0, 42.0), 11, TEXT_DIM)
	if focused:
		_draw_holo_focus_frame(canvas, row_rect, _focus_pulse_alpha())


func _draw_button(canvas: CanvasItem, font: Font, rect: Rect2, text: String, selected: bool, mouse_pos: Vector2) -> void:
	var hovered: bool = rect.has_point(mouse_pos)
	var fill := BUTTON_SELECTED if selected else BUTTON_COLOR
	if hovered:
		fill = BUTTON_HOVER
	var border := NEON_CYAN_HOT if selected else (BUTTON_BORDER if hovered else Color(BUTTON_BORDER.r, BUTTON_BORDER.g, BUTTON_BORDER.b, 0.36))
	_draw_panel(canvas, rect, fill, border, 1.0)
	if selected:
		canvas.draw_rect(Rect2(rect.position + Vector2(8.0, 10.0), Vector2(4.0, rect.size.y - 20.0)), RESONANCE_MAG)
	_draw_text_in_rect(canvas, font, text, rect, 18, Color.WHITE)


func _draw_recommendation_block(canvas: CanvasItem, font: Font, rect: Rect2, text: String) -> void:
	_draw_panel(canvas, rect, Color(18.0 / 255.0, 25.0 / 255.0, 38.0 / 255.0, 0.90), Color(ACCENT_GOLD.r, ACCENT_GOLD.g, ACCENT_GOLD.b, 0.34), 1.0)
	var lines := text.split("\n", false)
	for index in range(min(lines.size(), 2)):
		_draw_text(canvas, font, str(lines[index]), rect.position + Vector2(14.0, 19.0 + float(index) * 18.0), 12, Color(224.0 / 255.0, 232.0 / 255.0, 244.0 / 255.0))


func _draw_hud_readout_bar(canvas: CanvasItem, font: Font, panel_rect: Rect2, text: String) -> void:
	if text.is_empty():
		return
	var bar := Rect2(panel_rect.position + Vector2(28.0, panel_rect.size.y - 22.0), Vector2(panel_rect.size.x - 56.0, 16.0))
	var marker_center := Vector2(bar.position.x, bar.get_center().y)
	canvas.draw_colored_polygon(
		PackedVector2Array([
			marker_center + Vector2(0.0, -3.0),
			marker_center + Vector2(6.0, 0.0),
			marker_center + Vector2(0.0, 3.0),
		]),
		Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.88)
	)
	canvas.draw_string(font, Vector2(bar.position.x + 13.0, bar.get_center().y + 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, maxf(0.0, bar.size.x - 13.0), 12, TEXT_DIM)


func _get_select_chevron_rects(value_rect: Rect2) -> Dictionary:
	var half_width := value_rect.size.x * 0.5
	return {
		"left": Rect2(value_rect.position, Vector2(half_width, value_rect.size.y)),
		"right": Rect2(value_rect.position + Vector2(half_width, 0.0), Vector2(value_rect.size.x - half_width, value_rect.size.y)),
	}


func _draw_toggle_leader(canvas: CanvasItem, font: Font, row_rect: Rect2, checkbox_rect: Rect2, title: String) -> void:
	var title_start_x := row_rect.position.x + 58.0
	var title_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15).x
	var title_end_x := title_start_x + title_width
	var leader_y := row_rect.position.y + 20.0
	var leader_x0 := title_end_x + 10.0
	var leader_x1 := checkbox_rect.position.x - 10.0
	if checkbox_rect.position.x <= title_end_x:
		leader_x1 = row_rect.end.x - 18.0
	if leader_x1 > leader_x0 + 6.0:
		canvas.draw_dashed_line(
			Vector2(leader_x0, leader_y),
			Vector2(leader_x1, leader_y),
			Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.30),
			1.0,
			4.0
		)


func _draw_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, border_width: float, double_line: bool = false, glow: bool = false) -> void:
	canvas.draw_rect(rect, fill)
	if border_width > 0.0:
		if glow:
			canvas.draw_rect(rect, Color(border.r, border.g, border.b, border.a * 0.18), false, border_width * 3.0)
			canvas.draw_rect(rect, Color(border.r, border.g, border.b, border.a * 0.35), false, border_width * 2.0)
		canvas.draw_rect(rect, border, false, border_width)
		if double_line and rect.size.x > 6.0 and rect.size.y > 6.0:
			canvas.draw_rect(rect.grow(-3.0), Color(border.r, border.g, border.b, border.a * 0.45), false, 1.0)


func _draw_neon_line(canvas: CanvasItem, start: Vector2, finish: Vector2, color: Color, core_width: float = 1.0) -> void:
	var halo := Color(color.r, color.g, color.b, color.a * 0.18)
	var mid := Color(color.r, color.g, color.b, color.a * 0.35)
	canvas.draw_line(start, finish, halo, core_width * 3.0)
	canvas.draw_line(start, finish, mid, core_width * 2.0)
	canvas.draw_line(start, finish, color, core_width)


func _draw_holo_focus_frame(canvas: CanvasItem, rect: Rect2, pulse_alpha: float = 1.0) -> void:
	if rect.size.x <= 8.0 or rect.size.y <= 8.0:
		return
	var inner_rect := rect.grow(-3.0)
	canvas.draw_rect(inner_rect, Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.50), false, 1.0)

	var alpha := clampf(pulse_alpha, 0.0, 1.0)
	var magenta := Color(RESONANCE_MAG.r, RESONANCE_MAG.g, RESONANCE_MAG.b, alpha)
	var frame_rect := rect.grow(-1.0)
	var arm: float = minf(14.0, minf(frame_rect.size.x, frame_rect.size.y) * 0.45)
	var width := 2.0
	var top_left := frame_rect.position
	var top_right := Vector2(frame_rect.end.x, frame_rect.position.y)
	var bottom_left := Vector2(frame_rect.position.x, frame_rect.end.y)
	var bottom_right := frame_rect.end
	canvas.draw_line(top_left, top_left + Vector2(arm, 0.0), magenta, width)
	canvas.draw_line(top_left, top_left + Vector2(0.0, arm), magenta, width)
	canvas.draw_line(top_right, top_right + Vector2(-arm, 0.0), magenta, width)
	canvas.draw_line(top_right, top_right + Vector2(0.0, arm), magenta, width)
	canvas.draw_line(bottom_left, bottom_left + Vector2(arm, 0.0), magenta, width)
	canvas.draw_line(bottom_left, bottom_left + Vector2(0.0, -arm), magenta, width)
	canvas.draw_line(bottom_right, bottom_right + Vector2(-arm, 0.0), magenta, width)
	canvas.draw_line(bottom_right, bottom_right + Vector2(0.0, -arm), magenta, width)


func _get_ui_font(tech: bool = false) -> Font:
	return FONT_TECH if tech else FONT_BODY


func _focus_pulse_alpha() -> float:
	return 0.55 + 0.45 * sin(animation_time * TAU / 2.85)


func _get_focused_option_description(tab: String, focus: int) -> String:
	if tab == OPTIONS_TAB_SOUND:
		match focus:
			0:
				return _text("settings.desc.bgm", "배경음 음량을 조절합니다.")
			1:
				return _text("settings.desc.sfx", "효과음 음량을 조절합니다.")
			2:
				return _text("settings.desc.sound_back", "이전 화면으로 돌아갑니다.")
	elif tab == OPTIONS_TAB_DISPLAY:
		match focus:
			0:
				return _text("settings.desc.display_mode", "화면 표시 방식을 선택합니다.")
			1:
				return _text("settings.desc.render_fps", "렌더링 최대 프레임을 설정합니다.")
			2:
				return _text("settings.desc.vsync", "수직 동기화 방식을 설정합니다.")
			3:
				return _text("settings.desc.remember_display", "표시 모드를 다음 실행에도 유지합니다.")
			4:
				return _text("settings.desc.auto_refresh", "60Hz를 자동으로 적용합니다.")
			5:
				return _text("settings.desc.recommend_apply", "권장 설정을 한 번에 적용합니다.")
			6:
				return _text("settings.desc.apply_60hz", "지금 60Hz 설정을 적용합니다.")
			7:
				return _text("settings.desc.save", "현재 디스플레이 설정을 저장합니다.")
			8:
				return _text("settings.desc.display_back", "이전 화면으로 돌아갑니다.")
	elif tab == OPTIONS_TAB_CONTROLS:
		if focus == 0:
			return _text("settings.desc.controls_device", "입력 장치를 선택합니다.")
		if controls_device_view == CONTROL_DEVICE_JOYPAD and focus == 1:
			return _text("settings.desc.controls_vibration", "조이패드 진동 세기를 조절합니다.")
		if focus == _get_controls_back_focus_index():
			return _text("settings.desc.controls_back", "이전 화면으로 돌아갑니다.")
	elif tab == OPTIONS_TAB_LANGUAGE:
		if focus == LANGUAGE_FOCUS_COUNT - 1:
			return _text("settings.desc.language_back", "이전 화면으로 돌아갑니다.")
		if focus >= 0 and focus < LANGUAGE_FOCUS_COUNT - 1:
			return _text("settings.desc.language", "게임 언어를 선택합니다.")
	return ""


func _draw_text(canvas: CanvasItem, font: Font, text: String, pos: Vector2, size: int, color: Color) -> void:
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _draw_text_centered(canvas: CanvasItem, font: Font, text: String, center: Vector2, size: int, color: Color) -> void:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
	canvas.draw_string(font, center - Vector2(text_size.x * 0.5, text_size.y * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _draw_text_in_rect(canvas: CanvasItem, font: Font, text: String, rect: Rect2, size: int, color: Color) -> void:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
	var ascent: float = font.get_ascent(size)
	var pos := Vector2(
		rect.position.x + (rect.size.x - text_size.x) * 0.5,
		rect.position.y + (rect.size.y - text_size.y) * 0.5 + ascent
	)
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _get_active_panel_rect(view_size: Vector2) -> Rect2:
	return _get_options_panel_rect(view_size) if options_open else _get_main_panel_rect(view_size)


func _get_main_panel_rect(view_size: Vector2) -> Rect2:
	var size := Vector2(min(MAIN_PANEL_SIZE.x, max(280.0, view_size.x - 28.0)), min(MAIN_PANEL_SIZE.y, max(260.0, view_size.y - 28.0)))
	return Rect2((view_size - size) * 0.5, size)


func _get_options_panel_rect(view_size: Vector2) -> Rect2:
	var size := Vector2(min(OPTIONS_PANEL_SIZE.x, max(560.0, view_size.x - 28.0)), min(OPTIONS_PANEL_SIZE.y, max(300.0, view_size.y - 28.0)))
	return Rect2((view_size - size) * 0.5, size)


func _get_sound_tab_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(92.0, 14.0), Vector2(106.0, 36.0))


func _get_display_tab_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(208.0, 14.0), Vector2(138.0, 36.0))


func _get_controls_tab_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(356.0, 14.0), Vector2(112.0, 36.0))


func _get_language_tab_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(478.0, 14.0), Vector2(122.0, 36.0))


func _get_reset_button_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(panel_rect.size.x - 142.0, 14.0), Vector2(124.0, 34.0))


func _get_button_rect(panel_rect: Rect2, index: int, count: int) -> Rect2:
	var total_height: float = BUTTON_SIZE.y * float(count) + BUTTON_GAP * float(max(0, count - 1))
	var start_y: float = panel_rect.position.y + TITLE_HEIGHT + (panel_rect.size.y - TITLE_HEIGHT - total_height) * 0.5
	return Rect2(
		Vector2(panel_rect.get_center().x - BUTTON_SIZE.x * 0.5, start_y + float(index) * (BUTTON_SIZE.y + BUTTON_GAP)),
		BUTTON_SIZE
	)


func _get_slider_rect(slider_key: String, view_size: Vector2) -> Rect2:
	return _get_slider_rect_from_panel(slider_key, _get_options_panel_rect(view_size))


func _get_slider_rect_from_panel(slider_key: String, panel_rect: Rect2) -> Rect2:
	var y: float = panel_rect.position.y + (128.0 if slider_key == SOUND_SLIDER_BGM else 202.0)
	var slider_x: float = panel_rect.position.x + 250.0
	var slider_width: float = max(300.0, panel_rect.size.x - 388.0)
	return Rect2(Vector2(slider_x, y), Vector2(slider_width, SLIDER_HEIGHT))


func _get_slider_hit_rect(slider_key: String, view_size: Vector2) -> Rect2:
	return _get_slider_hit_rect_from_panel(slider_key, _get_options_panel_rect(view_size))


func _get_slider_hit_rect_from_panel(slider_key: String, panel_rect: Rect2) -> Rect2:
	var slider_rect: Rect2 = _get_slider_rect_from_panel(slider_key, panel_rect)
	return Rect2(Vector2(slider_rect.position.x, slider_rect.get_center().y - SLIDER_HIT_HEIGHT * 0.5), Vector2(slider_rect.size.x, SLIDER_HIT_HEIGHT))


func _get_back_button_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(Vector2(panel_rect.get_center().x - 72.0, panel_rect.end.y - 70.0), Vector2(144.0, 45.0))


func _get_display_fullscreen_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(280.0, 104.0), Vector2(124.0, 38.0))


func _get_display_exclusive_fullscreen_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(418.0, 104.0), Vector2(124.0, 38.0))


func _get_display_windowed_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(556.0, 104.0), Vector2(124.0, 38.0))


func _get_display_fps_cap_row_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(96.0, 188.0), Vector2(panel_rect.size.x - 192.0, 42.0))


func _get_display_fps_cap_value_rect(panel_rect: Rect2) -> Rect2:
	var row_rect: Rect2 = _get_display_fps_cap_row_rect(panel_rect)
	return Rect2(row_rect.end - Vector2(212.0, 37.0), Vector2(190.0, 32.0))


func _get_display_vsync_row_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(96.0, 237.0), Vector2(panel_rect.size.x - 192.0, 42.0))


func _get_display_vsync_value_rect(panel_rect: Rect2) -> Rect2:
	var row_rect: Rect2 = _get_display_vsync_row_rect(panel_rect)
	return Rect2(row_rect.end - Vector2(212.0, 37.0), Vector2(190.0, 32.0))


func _get_display_default_checkbox_rect(panel_rect: Rect2) -> Rect2:
	var row_rect: Rect2 = _get_display_default_row_rect(panel_rect)
	return Rect2(row_rect.position + Vector2(18.0, 9.0), Vector2(22.0, 22.0))


func _get_display_default_row_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(96.0, 286.0), Vector2(panel_rect.size.x - 192.0, 40.0))


func _get_display_auto_refresh_checkbox_rect(panel_rect: Rect2) -> Rect2:
	var row_rect: Rect2 = _get_display_auto_refresh_row_rect(panel_rect)
	return Rect2(row_rect.position + Vector2(18.0, 9.0), Vector2(22.0, 22.0))


func _get_display_auto_refresh_row_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(96.0, 330.0), Vector2(panel_rect.size.x - 192.0, 40.0))


func _get_display_pacing_recommendation_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(96.0, 378.0), Vector2(panel_rect.size.x - 192.0, 40.0))


func _get_display_recommended_button_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(Vector2(panel_rect.get_center().x - 376.0, panel_rect.end.y - 72.0), Vector2(170.0, 48.0))


func _get_display_apply_60hz_button_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(Vector2(panel_rect.get_center().x - 188.0, panel_rect.end.y - 72.0), Vector2(170.0, 48.0))


func _get_display_save_button_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(Vector2(panel_rect.get_center().x, panel_rect.end.y - 72.0), Vector2(170.0, 48.0))


func _get_display_back_button_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(Vector2(panel_rect.get_center().x + 188.0, panel_rect.end.y - 72.0), Vector2(170.0, 48.0))


func _get_controls_keyboard_mouse_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(214.0, 103.0), Vector2(178.0, 42.0))


func _get_controls_joypad_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(408.0, 103.0), Vector2(138.0, 42.0))


func _get_controls_vibration_row_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(96.0, 154.0), Vector2(panel_rect.size.x - 192.0, 42.0))


func _get_controls_vibration_value_rect(panel_rect: Rect2) -> Rect2:
	var row_rect: Rect2 = _get_controls_vibration_row_rect(panel_rect)
	return Rect2(row_rect.end - Vector2(212.0, 37.0), Vector2(190.0, 32.0))


func _get_controls_mapping_row_rect(panel_rect: Rect2, index: int) -> Rect2:
	if controls_device_view == CONTROL_DEVICE_JOYPAD:
		return Rect2(panel_rect.position + Vector2(96.0, 209.0 + float(index) * 32.0), Vector2(panel_rect.size.x - 192.0, 28.0))
	return Rect2(panel_rect.position + Vector2(96.0, 166.0 + float(index) * 43.0), Vector2(panel_rect.size.x - 192.0, 35.0))


func _get_controls_back_button_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(Vector2(panel_rect.get_center().x - 85.0, panel_rect.end.y - 72.0), Vector2(170.0, 48.0))


func _get_language_korean_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(116.0, 154.0), Vector2(130.0, 44.0))


func _get_language_english_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(264.0, 154.0), Vector2(130.0, 44.0))


func _get_language_chinese_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(412.0, 154.0), Vector2(130.0, 44.0))


func _get_language_japanese_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(560.0, 154.0), Vector2(130.0, 44.0))


func _get_language_spanish_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(116.0, 208.0), Vector2(130.0, 44.0))


func _get_language_portuguese_brazil_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(264.0, 208.0), Vector2(166.0, 44.0))


func _get_language_russian_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(448.0, 208.0), Vector2(130.0, 44.0))


func _get_language_note_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(96.0, 292.0), Vector2(panel_rect.size.x - 192.0, 40.0))


func _get_language_back_button_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(Vector2(panel_rect.get_center().x - 85.0, panel_rect.end.y - 72.0), Vector2(170.0, 48.0))


func _get_options_back_label() -> String:
	return _text("settings.close") if options_only else _text("settings.back")


func _get_control_mapping_rows() -> Array:
	if controls_device_view == CONTROL_DEVICE_JOYPAD:
		return [
			{"label": _text("controls.map.move"), "value": _text("controls.value.joypad.move")},
			{"label": _text("controls.map.dash_skill"), "value": _text("controls.value.joypad.dash_skill")},
			{"label": _text("controls.map.active_item"), "value": _text("controls.value.joypad.active_item")},
			{"label": _text("controls.map.supply_hold"), "value": _text("controls.value.joypad.supply_hold")},
			{"label": _text("controls.map.weapon_switch"), "value": _text("controls.value.joypad.weapon_switch")},
			{"label": _text("controls.map.confirm_cancel_pause"), "value": _text("controls.value.joypad.confirm_cancel_pause")},
		]
	return [
		{"label": _text("controls.map.move"), "value": _text("controls.value.keyboard.move")},
		{"label": _text("controls.map.dash_skill"), "value": _text("controls.value.keyboard.dash_skill")},
		{"label": _text("controls.map.active_item"), "value": _text("controls.value.keyboard.active_item")},
		{"label": _text("controls.map.supply_hold"), "value": _text("controls.value.keyboard.supply_hold")},
		{"label": _text("controls.map.weapon_switch"), "value": _text("controls.value.keyboard.weapon_switch")},
		{"label": _text("controls.map.confirm_cancel_pause"), "value": _text("controls.value.keyboard.confirm_cancel_pause")},
	]


func _get_main_entries() -> Array:
	return [
		{"label": _text("pause.continue"), "action": MENU_CONTINUE},
		{"label": _text("pause.character_info"), "action": MENU_CHARACTER_INFO},
		{"label": _text("pause.options"), "action": MENU_OPTIONS},
	]


func _get_bgm_volume(registry: Object) -> float:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("get_bgm_volume"):
		return clampf(float(audio.get_bgm_volume()), 0.0, 1.0)
	return DEFAULT_BGM_VOLUME


func _set_bgm_volume(registry: Object, value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("set_bgm_volume"):
		return clampf(float(audio.set_bgm_volume(clamped)), 0.0, 1.0)
	return clamped


func _get_sfx_volume(registry: Object) -> float:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("get_sfx_volume"):
		return clampf(float(audio.get_sfx_volume()), 0.0, 1.0)
	return DEFAULT_SFX_VOLUME


func _set_sfx_volume(registry: Object, value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("set_sfx_volume"):
		return clampf(float(audio.set_sfx_volume(clamped)), 0.0, 1.0)
	return clamped


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.get_instance(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _is_key(key_event: InputEventKey, keycode: int) -> bool:
	return key_event.keycode == keycode or key_event.physical_keycode == keycode


func _get_mouse_position(canvas: CanvasItem) -> Vector2:
	if canvas != null and canvas.has_method("get_viewport") and canvas.get_viewport() != null:
		return canvas.get_viewport().get_mouse_position()
	return Vector2(-10000.0, -10000.0)
