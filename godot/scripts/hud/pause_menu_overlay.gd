extends RefCounted

const MENU_CONTINUE := "continue"
const MENU_CHARACTER_INFO := "character_info"
const MENU_OPTIONS := "options"
const SOUND_SLIDER_BGM := "bgm"
const SOUND_SLIDER_SFX := "sfx"
const OPTIONS_TAB_SOUND := "sound"
const OPTIONS_TAB_DISPLAY := "display"
const DISPLAY_MODE_FULLSCREEN := "fullscreen"
const DISPLAY_MODE_WINDOWED := "windowed"

const MAIN_PANEL_SIZE := Vector2(360.0, 320.0)
const OPTIONS_PANEL_SIZE := Vector2(900.0, 360.0)
const BUTTON_SIZE := Vector2(250.0, 48.0)
const BUTTON_GAP := 14.0
const TITLE_HEIGHT := 82.0
const SLIDER_HEIGHT := 10.0
const SLIDER_HIT_HEIGHT := 34.0
const SLIDER_HANDLE_RADIUS := 8.0
const VOLUME_STEP := 0.05
const SOUND_FOCUS_COUNT := 3
const DISPLAY_FOCUS_COUNT := 4

const PANEL_COLOR := Color(16.0 / 255.0, 20.0 / 255.0, 32.0 / 255.0, 0.96)
const PANEL_BORDER := Color(82.0 / 255.0, 165.0 / 255.0, 220.0 / 255.0, 0.86)
const HEADER_COLOR := Color(35.0 / 255.0, 48.0 / 255.0, 70.0 / 255.0, 0.96)
const SECTION_COLOR := Color(23.0 / 255.0, 29.0 / 255.0, 44.0 / 255.0, 0.94)
const BUTTON_COLOR := Color(36.0 / 255.0, 48.0 / 255.0, 70.0 / 255.0, 0.96)
const BUTTON_HOVER := Color(54.0 / 255.0, 82.0 / 255.0, 112.0 / 255.0, 0.98)
const BUTTON_SELECTED := Color(62.0 / 255.0, 96.0 / 255.0, 132.0 / 255.0, 1.0)
const BUTTON_BORDER := Color(112.0 / 255.0, 190.0 / 255.0, 1.0, 0.78)
const SLIDER_BACK := Color(64.0 / 255.0, 68.0 / 255.0, 82.0 / 255.0, 1.0)
const TEXT_DIM := Color(178.0 / 255.0, 188.0 / 255.0, 210.0 / 255.0)
const ACCENT_BLUE := Color(0.0, 200.0 / 255.0, 1.0)
const ACCENT_GREEN := Color(0.0, 1.0, 120.0 / 255.0)
const ACCENT_GOLD := Color(1.0, 215.0 / 255.0, 90.0 / 255.0)

var active := false
var options_open := false
var animation_time := 0.0
var selected_index := 0
var options_focus := 0
var dragging_slider := ""
var options_tab := OPTIONS_TAB_SOUND
var display_mode := DISPLAY_MODE_WINDOWED
var remember_display_mode := false


func is_active() -> bool:
	return active


func is_options_open() -> bool:
	return active and options_open


func open() -> void:
	active = true
	options_open = false
	animation_time = 0.0
	selected_index = 0
	options_focus = 0
	dragging_slider = ""
	options_tab = OPTIONS_TAB_SOUND


func close() -> void:
	active = false
	options_open = false
	selected_index = 0
	options_focus = 0
	dragging_slider = ""
	options_tab = OPTIONS_TAB_SOUND


func toggle() -> void:
	if active:
		close()
	else:
		open()


func update(delta: float) -> void:
	if not active:
		return
	animation_time += delta


func handle_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> Dictionary:
	if not active:
		return {"handled": false}
	if event is InputEventKey:
		return _handle_key_input(event as InputEventKey, owner, registry)
	if event is InputEventMouseButton:
		return _handle_mouse_button(event as InputEventMouseButton, owner, registry, view_size)
	if event is InputEventMouseMotion:
		return _handle_mouse_motion(event as InputEventMouseMotion, registry, view_size)
	return {"handled": true}


func draw(canvas: CanvasItem, _owner: Object, registry: Object, view_size: Vector2) -> void:
	if not active or canvas == null:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var alpha: float = clamp(animation_time / 0.12, 0.0, 1.0)
	var panel_rect: Rect2 = _get_active_panel_rect(view_size).grow(-8.0 * (1.0 - alpha))
	var mouse_pos: Vector2 = _get_mouse_position(canvas)

	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.58 * alpha))
	_draw_panel(canvas, panel_rect, PANEL_COLOR, PANEL_BORDER, 2.0)
	if options_open:
		_draw_options_window(canvas, font, panel_rect, mouse_pos, registry)
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
		options_open = false
		selected_index = 0
		options_focus = 0
		dragging_slider = ""
		return {"handled": true}
	if _is_key(key_event, KEY_TAB):
		_switch_options_tab()
		return {"handled": true}
	if options_tab == OPTIONS_TAB_DISPLAY:
		return _handle_display_key_input(key_event, owner, registry)
	return _handle_sound_key_input(key_event, registry)


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
			options_open = false
			selected_index = 0
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
			_toggle_display_mode()
		return {"handled": true}
	if _is_key(key_event, KEY_ENTER) or _is_key(key_event, KEY_KP_ENTER) or _is_key(key_event, KEY_SPACE):
		match options_focus:
			0:
				_toggle_display_mode()
			1:
				remember_display_mode = not remember_display_mode
			2:
				_save_display_options(owner, registry)
			3:
				options_open = false
				selected_index = 0
		return {"handled": true}
	return {"handled": true}


func _handle_mouse_button(mouse_event: InputEventMouseButton, owner: Object, registry: Object, view_size: Vector2) -> Dictionary:
	if not mouse_event.pressed:
		dragging_slider = ""
		return {"handled": true}
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		if options_open:
			options_open = false
			selected_index = 0
			options_focus = 0
			dragging_slider = ""
			return {"handled": true}
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
	if options_tab == OPTIONS_TAB_DISPLAY:
		return _handle_display_click(position, owner, registry, panel_rect)
	return _handle_sound_click(position, registry, view_size, panel_rect)


func _handle_sound_click(position: Vector2, registry: Object, view_size: Vector2, panel_rect: Rect2) -> Dictionary:
	if _get_back_button_rect(panel_rect).has_point(position):
		options_open = false
		selected_index = 0
		options_focus = 0
		dragging_slider = ""
		return {"handled": true}
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
		display_mode = DISPLAY_MODE_FULLSCREEN
		options_focus = 0
		return {"handled": true}
	if _get_display_windowed_rect(panel_rect).has_point(position):
		display_mode = DISPLAY_MODE_WINDOWED
		options_focus = 0
		return {"handled": true}
	if _get_display_default_row_rect(panel_rect).has_point(position):
		remember_display_mode = not remember_display_mode
		options_focus = 1
		return {"handled": true}
	if _get_display_save_button_rect(panel_rect).has_point(position):
		options_focus = 2
		_save_display_options(owner, registry)
		return {"handled": true}
	if _get_display_back_button_rect(panel_rect).has_point(position):
		options_open = false
		selected_index = 0
		options_focus = 0
		dragging_slider = ""
		return {"handled": true}
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
	_sync_display_settings(owner, registry)


func _switch_options_tab() -> void:
	options_tab = OPTIONS_TAB_DISPLAY if options_tab == OPTIONS_TAB_SOUND else OPTIONS_TAB_SOUND
	options_focus = 0
	dragging_slider = ""


func _toggle_display_mode() -> void:
	display_mode = DISPLAY_MODE_WINDOWED if display_mode == DISPLAY_MODE_FULLSCREEN else DISPLAY_MODE_FULLSCREEN


func _sync_display_settings(owner: Object, registry: Object) -> void:
	var view_layout: Object = _get_instance(registry, "battle_view_layout")
	var window: Object = _get_owner_window(owner)
	if view_layout != null and view_layout.has_method("get_display_mode"):
		display_mode = _normalize_display_mode(str(view_layout.get_display_mode(window)))
	elif view_layout != null and view_layout.has_method("is_fullscreen"):
		display_mode = DISPLAY_MODE_FULLSCREEN if bool(view_layout.is_fullscreen(window)) else DISPLAY_MODE_WINDOWED
	if view_layout != null and view_layout.has_method("get_remember_display_mode"):
		remember_display_mode = bool(view_layout.get_remember_display_mode())


func _save_display_options(owner: Object, registry: Object) -> void:
	display_mode = _normalize_display_mode(display_mode)
	var view_layout: Object = _get_instance(registry, "battle_view_layout")
	var window: Object = _get_owner_window(owner)
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


func _normalize_display_mode(mode: String) -> String:
	return DISPLAY_MODE_FULLSCREEN if mode.strip_edges().to_lower() == DISPLAY_MODE_FULLSCREEN else DISPLAY_MODE_WINDOWED


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
	_draw_text_centered(canvas, font, "일시정지", panel_rect.position + Vector2(panel_rect.size.x * 0.5, 47.0), 28, Color.WHITE)
	_draw_text_centered(canvas, font, "핑파이터 - 링피아", panel_rect.position + Vector2(panel_rect.size.x * 0.5, 72.0), 12, TEXT_DIM)
	var entries: Array = _get_main_entries()
	for index in range(entries.size()):
		_draw_button(canvas, font, _get_button_rect(panel_rect, index, entries.size()), str(entries[index].get("label", "")), index == selected_index, mouse_pos)


func _draw_options_window(canvas: CanvasItem, font: Font, panel_rect: Rect2, mouse_pos: Vector2, registry: Object) -> void:
	var header_rect := Rect2(panel_rect.position, Vector2(panel_rect.size.x, 62.0))
	canvas.draw_rect(header_rect, HEADER_COLOR)
	canvas.draw_line(panel_rect.position + Vector2(14.0, 62.0), Vector2(panel_rect.end.x - 14.0, panel_rect.position.y + 62.0), PANEL_BORDER, 2.0)
	_draw_text(canvas, font, "옵션", panel_rect.position + Vector2(28.0, 40.0), 24, Color.WHITE)
	_draw_tab(canvas, font, _get_sound_tab_rect(panel_rect), "사운드", options_tab == OPTIONS_TAB_SOUND)
	_draw_tab(canvas, font, _get_display_tab_rect(panel_rect), "디스플레이", options_tab == OPTIONS_TAB_DISPLAY)

	var content_rect := Rect2(panel_rect.position + Vector2(28.0, 84.0), Vector2(panel_rect.size.x - 56.0, 178.0))
	_draw_panel(canvas, content_rect, SECTION_COLOR, Color(PANEL_BORDER.r, PANEL_BORDER.g, PANEL_BORDER.b, 0.42), 1.0)
	if options_tab == OPTIONS_TAB_DISPLAY:
		_draw_display_tab(canvas, font, panel_rect, mouse_pos)
	else:
		_draw_volume_slider(canvas, font, SOUND_SLIDER_BGM, "BGM 볼륨", _get_bgm_volume(registry), ACCENT_BLUE, options_focus == 0, mouse_pos, panel_rect)
		_draw_volume_slider(canvas, font, SOUND_SLIDER_SFX, "효과음 볼륨", _get_sfx_volume(registry), ACCENT_GREEN, options_focus == 1, mouse_pos, panel_rect)

	if options_tab == OPTIONS_TAB_SOUND:
		var back_rect: Rect2 = _get_back_button_rect(panel_rect)
		_draw_button(canvas, font, back_rect, "뒤로가기", options_focus == 2, mouse_pos)


func _draw_tab(canvas: CanvasItem, font: Font, rect: Rect2, label: String, active_tab: bool) -> void:
	var fill := Color(70.0 / 255.0, 100.0 / 255.0, 140.0 / 255.0, 0.98) if active_tab else BUTTON_COLOR
	_draw_panel(canvas, rect, fill, BUTTON_BORDER, 1.0)
	_draw_text_in_rect(canvas, font, label, rect, 15, Color.WHITE)


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


func _draw_display_tab(canvas: CanvasItem, font: Font, panel_rect: Rect2, mouse_pos: Vector2) -> void:
	var label_pos := panel_rect.position + Vector2(54.0, 137.0)
	_draw_text(canvas, font, "화면 모드", label_pos, 19, Color.WHITE)
	_draw_mode_pill(canvas, font, _get_display_fullscreen_rect(panel_rect), "전체화면", display_mode == DISPLAY_MODE_FULLSCREEN, options_focus == 0, mouse_pos)
	_draw_mode_pill(canvas, font, _get_display_windowed_rect(panel_rect), "창모드", display_mode == DISPLAY_MODE_WINDOWED, options_focus == 0, mouse_pos)

	var desc := "네이티브 해상도 전체화면으로 표시합니다" if display_mode == DISPLAY_MODE_FULLSCREEN else "필러 배경 포함 창모드로 표시합니다"
	_draw_text_centered(canvas, font, desc, panel_rect.position + Vector2(panel_rect.size.x * 0.5, 176.0), 14, TEXT_DIM)

	var checkbox_rect: Rect2 = _get_display_default_checkbox_rect(panel_rect)
	var row_rect: Rect2 = _get_display_default_row_rect(panel_rect)
	var row_hovered: bool = row_rect.has_point(mouse_pos)
	var border := ACCENT_BLUE if options_focus == 1 or row_hovered else Color(150.0 / 255.0, 160.0 / 255.0, 176.0 / 255.0)
	var fill := Color(60.0 / 255.0, 90.0 / 255.0, 130.0 / 255.0, 0.95) if remember_display_mode else Color(45.0 / 255.0, 55.0 / 255.0, 70.0 / 255.0, 0.95)
	_draw_panel(canvas, checkbox_rect, fill, border, 2.0)
	if remember_display_mode:
		var center := checkbox_rect.get_center()
		canvas.draw_line(center + Vector2(-6.0, 0.0), center + Vector2(-2.0, 5.0), ACCENT_BLUE, 3.0)
		canvas.draw_line(center + Vector2(-2.0, 5.0), center + Vector2(8.0, -6.0), ACCENT_BLUE, 3.0)
	_draw_text(canvas, font, "해당 화면설정을 기본으로 저장", Vector2(checkbox_rect.end.x + 14.0, checkbox_rect.position.y + 23.0), 19, Color.WHITE)

	_draw_button(canvas, font, _get_display_save_button_rect(panel_rect), "저장", options_focus == 2, mouse_pos)
	_draw_button(canvas, font, _get_display_back_button_rect(panel_rect), "뒤로가기", options_focus == 3, mouse_pos)


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
	var border := ACCENT_BLUE if selected or focused or hovered else Color(BUTTON_BORDER.r, BUTTON_BORDER.g, BUTTON_BORDER.b, 0.42)
	_draw_panel(canvas, rect, fill, border, 2.0 if selected or focused else 1.0)
	_draw_text_in_rect(canvas, font, label, rect, 17, Color.WHITE)


func _draw_button(canvas: CanvasItem, font: Font, rect: Rect2, text: String, selected: bool, mouse_pos: Vector2) -> void:
	var hovered: bool = rect.has_point(mouse_pos)
	var fill := BUTTON_SELECTED if selected else BUTTON_COLOR
	if hovered:
		fill = BUTTON_HOVER
	_draw_panel(canvas, rect, fill, BUTTON_BORDER if selected or hovered else Color(BUTTON_BORDER.r, BUTTON_BORDER.g, BUTTON_BORDER.b, 0.36), 1.0)
	if selected:
		canvas.draw_rect(Rect2(rect.position + Vector2(8.0, 10.0), Vector2(4.0, rect.size.y - 20.0)), ACCENT_GOLD)
	_draw_text_in_rect(canvas, font, text, rect, 18, Color.WHITE)


func _draw_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, border_width: float) -> void:
	canvas.draw_rect(rect, fill)
	if border_width > 0.0:
		canvas.draw_rect(rect, border, false, border_width)


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
	return Rect2(panel_rect.position + Vector2(100.0, 14.0), Vector2(98.0, 36.0))


func _get_display_tab_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(214.0, 14.0), Vector2(136.0, 36.0))


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
	return Rect2(panel_rect.position + Vector2(250.0, 103.0), Vector2(150.0, 42.0))


func _get_display_windowed_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(424.0, 103.0), Vector2(150.0, 42.0))


func _get_display_default_checkbox_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(250.0, 202.0), Vector2(28.0, 28.0))


func _get_display_default_row_rect(panel_rect: Rect2) -> Rect2:
	var checkbox_rect: Rect2 = _get_display_default_checkbox_rect(panel_rect)
	return Rect2(checkbox_rect.position + Vector2(0.0, -6.0), Vector2(390.0, 40.0))


func _get_display_save_button_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(Vector2(panel_rect.get_center().x - 196.0, panel_rect.end.y - 72.0), Vector2(170.0, 48.0))


func _get_display_back_button_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(Vector2(panel_rect.get_center().x + 26.0, panel_rect.end.y - 72.0), Vector2(170.0, 48.0))


func _get_main_entries() -> Array:
	return [
		{"label": "계속", "action": MENU_CONTINUE},
		{"label": "캐릭터정보", "action": MENU_CHARACTER_INFO},
		{"label": "옵션", "action": MENU_OPTIONS},
	]


func _get_bgm_volume(registry: Object) -> float:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("get_bgm_volume"):
		return clampf(float(audio.get_bgm_volume()), 0.0, 1.0)
	return 0.4


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
	return 0.7


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
