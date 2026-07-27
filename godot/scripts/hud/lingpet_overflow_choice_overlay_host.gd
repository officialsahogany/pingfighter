extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const TITLE_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")

const PANEL_SIZE := Vector2(590.0, 438.0)
const CARD_SIZE := Vector2(156.0, 118.0)
const RELEASE_SIZE := Vector2(150.0, 44.0)
const SELECT_RELEASE := 3

var _selected_index := 0
var _hover_index := -1


func prewarm_assets() -> void:
	pass


func draw(canvas: CanvasItem, runtime: Object, view_size: Vector2) -> void:
	if canvas == null or runtime == null or view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	if not runtime.has_method("is_overflow_choice_active") or not bool(runtime.is_overflow_choice_active()):
		return
	var snapshot := _get_snapshot(runtime)
	var layout := _build_layout(view_size)
	var panel: Rect2 = layout.get("panel", Rect2())
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.02, 0.025, 0.04, 0.72), true)
	canvas.draw_rect(panel, Color(0.07, 0.09, 0.13, 0.98), true)
	canvas.draw_rect(panel, Color(0.45, 0.90, 0.88, 0.82), false, 2.0)

	var title_pos := panel.position + Vector2(28.0, 42.0)
	_draw_text(canvas, title_pos, "수호령 선택", 25, Color(0.82, 1.0, 0.96), true)
	_draw_text(canvas, title_pos + Vector2(0.0, 30.0), "새 수호령", 15, Color(0.72, 0.84, 0.92), false)
	_draw_new_pet(canvas, layout.get("new_rect", Rect2()), snapshot)
	_draw_slots(canvas, layout, snapshot)
	_draw_release(canvas, layout.get("release_rect", Rect2()))


func handle_input(event: InputEvent, runtime: Object, owner: Object, registry: Object, view_size: Vector2) -> bool:
	if runtime == null or not runtime.has_method("is_overflow_choice_active") or not bool(runtime.is_overflow_choice_active()):
		return false
	var layout := _build_layout(view_size)
	if event is InputEventMouseMotion:
		_hover_index = _choice_at_position((event as InputEventMouseMotion).position, layout)
		if _hover_index >= 0:
			_selected_index = _hover_index
		return true
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var choice := _choice_at_position(mouse_event.position, layout)
			if choice == SELECT_RELEASE:
				return bool(runtime.commit_overflow_release(owner, registry))
			if choice >= 0 and choice < 3:
				return bool(runtime.commit_overflow_replace(choice, owner, registry))
		return true
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return true
		if key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE or key_event.keycode == KEY_BACKSPACE or key_event.physical_keycode == KEY_BACKSPACE:
			return bool(runtime.commit_overflow_release(owner, registry))
		var numbered := _number_key_to_slot(key_event)
		if numbered >= 0:
			return bool(runtime.commit_overflow_replace(numbered, owner, registry))
		if key_event.keycode == KEY_LEFT or key_event.physical_keycode == KEY_LEFT:
			_selected_index = posmod(_selected_index - 1, 4)
			return true
		if key_event.keycode == KEY_RIGHT or key_event.physical_keycode == KEY_RIGHT:
			_selected_index = posmod(_selected_index + 1, 4)
			return true
		if key_event.keycode == KEY_ENTER or key_event.physical_keycode == KEY_ENTER or key_event.keycode == KEY_SPACE or key_event.physical_keycode == KEY_SPACE:
			if _selected_index == SELECT_RELEASE:
				return bool(runtime.commit_overflow_release(owner, registry))
			return bool(runtime.commit_overflow_replace(_selected_index, owner, registry))
	if GamepadInput.is_confirm_event(event):
		if _selected_index == SELECT_RELEASE:
			return bool(runtime.commit_overflow_release(owner, registry))
		return bool(runtime.commit_overflow_replace(_selected_index, owner, registry))
	return true


func _draw_new_pet(canvas: CanvasItem, rect: Rect2, snapshot: Dictionary) -> void:
	canvas.draw_rect(rect, Color(0.10, 0.15, 0.18, 0.98), true)
	canvas.draw_rect(rect, Color(1.0, 0.77, 0.30, 0.92), false, 2.0)
	var name := str(snapshot.get("pending_display_name", snapshot.get("pending_pet_id", "")))
	_draw_text(canvas, rect.position + Vector2(20.0, 42.0), name, 24, Color(1.0, 0.91, 0.66), true)
	_draw_text(canvas, rect.position + Vector2(20.0, 76.0), "부화 완료", 15, Color(0.76, 0.91, 0.95), false)


func _draw_slots(canvas: CanvasItem, layout: Dictionary, snapshot: Dictionary) -> void:
	var slots: Array = snapshot.get("slots", []) as Array
	var rects: Array = layout.get("slot_rects", []) as Array
	for i in range(mini(rects.size(), 3)):
		var rect: Rect2 = rects[i]
		var slot: Dictionary = slots[i] if i < slots.size() and slots[i] is Dictionary else {}
		var selected := _selected_index == i or _hover_index == i
		var border := Color(0.92, 0.48, 0.88, 0.95) if selected else Color(0.38, 0.55, 0.65, 0.86)
		canvas.draw_rect(rect, Color(0.075, 0.10, 0.15, 0.98), true)
		canvas.draw_rect(rect, border, false, 2.0 if selected else 1.3)
		_draw_text(canvas, rect.position + Vector2(16.0, 26.0), "슬롯 %d" % (i + 1), 14, Color(0.70, 0.82, 0.92), false)
		_draw_text(canvas, rect.position + Vector2(16.0, 58.0), str(slot.get("display_name", slot.get("pet_id", ""))), 19, Color(0.92, 0.98, 1.0), true)
		var tag := "활성" if bool(slot.get("active", false)) else "보유"
		_draw_text(canvas, rect.position + Vector2(16.0, 91.0), tag + " / 교체", 13, Color(0.86, 0.74, 1.0), false)


func _draw_release(canvas: CanvasItem, rect: Rect2) -> void:
	var selected := _selected_index == SELECT_RELEASE or _hover_index == SELECT_RELEASE
	canvas.draw_rect(rect, Color(0.19, 0.08, 0.105, 0.98), true)
	canvas.draw_rect(rect, Color(1.0, 0.42, 0.48, 0.92) if selected else Color(0.75, 0.31, 0.38, 0.86), false, 2.0 if selected else 1.3)
	_draw_text(canvas, rect.position + Vector2(34.0, 29.0), "방생", 18, Color(1.0, 0.84, 0.86), true)


func _build_layout(view_size: Vector2) -> Dictionary:
	var panel_size := Vector2(minf(PANEL_SIZE.x, view_size.x - 36.0), minf(PANEL_SIZE.y, view_size.y - 36.0))
	var panel := Rect2((view_size - panel_size) * 0.5, panel_size)
	var new_rect := Rect2(panel.position + Vector2(28.0, 92.0), Vector2(panel_size.x - 56.0, 104.0))
	var slot_rects: Array[Rect2] = []
	var gap := 18.0
	var total_w := CARD_SIZE.x * 3.0 + gap * 2.0
	var start_x := panel.position.x + (panel_size.x - total_w) * 0.5
	var slot_y := panel.position.y + 228.0
	for i in range(3):
		slot_rects.append(Rect2(Vector2(start_x + (CARD_SIZE.x + gap) * float(i), slot_y), CARD_SIZE))
	var release_rect := Rect2(panel.position + Vector2(panel_size.x - RELEASE_SIZE.x - 28.0, panel_size.y - RELEASE_SIZE.y - 24.0), RELEASE_SIZE)
	return {
		"panel": panel,
		"new_rect": new_rect,
		"slot_rects": slot_rects,
		"release_rect": release_rect,
	}


func _choice_at_position(pos: Vector2, layout: Dictionary) -> int:
	var release_rect: Rect2 = layout.get("release_rect", Rect2())
	if release_rect.has_point(pos):
		return SELECT_RELEASE
	var slot_rects: Array = layout.get("slot_rects", []) as Array
	for i in range(mini(slot_rects.size(), 3)):
		var rect: Rect2 = slot_rects[i]
		if rect.has_point(pos):
			return i
	return -1


func _number_key_to_slot(key_event: InputEventKey) -> int:
	var keycodes := [KEY_1, KEY_2, KEY_3]
	var keypad_codes := [KEY_KP_1, KEY_KP_2, KEY_KP_3]
	for i in range(3):
		if key_event.keycode == keycodes[i] or key_event.physical_keycode == keycodes[i] or key_event.keycode == keypad_codes[i] or key_event.physical_keycode == keypad_codes[i]:
			return i
	return -1


func _get_snapshot(runtime: Object) -> Dictionary:
	if runtime != null and runtime.has_method("get_overflow_choice_snapshot"):
		var value: Variant = runtime.get_overflow_choice_snapshot()
		if value is Dictionary:
			return value as Dictionary
	return {}


func _draw_text(canvas: CanvasItem, pos: Vector2, text: String, size: int, color: Color, shadow: bool) -> void:
	if shadow:
		canvas.draw_string(TITLE_FONT, pos + Vector2(1.4, 1.8), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, Color(0.0, 0.0, 0.0, 0.62))
	canvas.draw_string(TITLE_FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
