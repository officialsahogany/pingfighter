extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const TITLE_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")

const PANEL_WIDTH_RATIO := 0.78
const PANEL_HEIGHT_RATIO := 0.48
const CARD_GAP := 18.0
const CONFIRM_HEIGHT := 52.0


func prewarm_assets() -> void:
	# Font is preloaded at parse time; the hook exists for registry warmup parity.
	pass


func prewarm_runtime_nodes(_owner: Object = null) -> void:
	prewarm_assets()


func draw(canvas: CanvasItem, runtime: Object, view_size: Vector2) -> void:
	if canvas == null or runtime == null or not runtime.has_method("is_guardian_enhance_choice_active"):
		return
	if not bool(runtime.is_guardian_enhance_choice_active()) or view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	var snapshot: Dictionary = runtime.get_guardian_enhance_choice_snapshot()
	var candidates: Array = snapshot.get("candidates", []) as Array
	var selected := int(snapshot.get("selected_index", 0))
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.015, 0.03, 0.055, 0.78))
	var panel := get_panel_rect(view_size)
	canvas.draw_style_box(_panel_style(), panel)
	_draw_centered_text(canvas, "수호령강화", panel.position + Vector2(0.0, 42.0), panel.size.x, 32, Color(0.76, 1.0, 0.90))
	_draw_centered_text(canvas, "적용할 강화를 하나 선택하세요", panel.position + Vector2(0.0, 82.0), panel.size.x, 18, Color(0.78, 0.86, 0.90))
	var card_rects := get_card_rects(view_size, candidates.size())
	for index in range(card_rects.size()):
		var rect: Rect2 = card_rects[index]
		var is_selected := index == selected
		canvas.draw_style_box(_card_style(is_selected), rect)
		var candidate: Dictionary = candidates[index] if candidates[index] is Dictionary else {}
		_draw_centered_text(
			canvas,
			str(candidate.get("label", "강화")),
			rect.position + Vector2(8.0, rect.size.y * 0.42),
			rect.size.x - 16.0,
			20,
			Color(0.92, 1.0, 0.96) if is_selected else Color(0.76, 0.82, 0.84)
		)
	var confirm_rect := get_confirm_rect(view_size)
	canvas.draw_style_box(_confirm_style(bool(snapshot.get("can_confirm", false))), confirm_rect)
	_draw_centered_text(canvas, "강화 확정", confirm_rect.position + Vector2.ZERO, confirm_rect.size.x, 20, Color.WHITE, confirm_rect.size.y)


func handle_input(
	event: InputEvent,
	runtime: Object,
	owner: Object,
	registry: Object,
	view_size: Vector2
) -> bool:
	if runtime == null or not runtime.has_method("is_guardian_enhance_choice_active"):
		return false
	if not bool(runtime.is_guardian_enhance_choice_active()):
		return false
	var snapshot: Dictionary = runtime.get_guardian_enhance_choice_snapshot()
	var candidates: Array = snapshot.get("candidates", []) as Array
	if event is InputEventMouseMotion:
		var hover := _index_at((event as InputEventMouseMotion).position, get_card_rects(view_size, candidates.size()))
		if hover >= 0 and runtime.has_method("select_guardian_enhance_choice_index"):
			runtime.select_guardian_enhance_choice_index(hover)
		return hover >= 0
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
			return false
		var index := _index_at(mouse.position, get_card_rects(view_size, candidates.size()))
		if index >= 0 and runtime.has_method("select_guardian_enhance_choice_index"):
			runtime.select_guardian_enhance_choice_index(index)
			return true
		if get_confirm_rect(view_size).has_point(mouse.position):
			return _confirm(runtime, owner, registry)
		return true
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return false
		if key.keycode in [KEY_LEFT, KEY_A] or key.physical_keycode in [KEY_LEFT, KEY_A]:
			return _move(runtime, -1)
		if key.keycode in [KEY_RIGHT, KEY_D] or key.physical_keycode in [KEY_RIGHT, KEY_D]:
			return _move(runtime, 1)
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_LEFT_X and absf(motion.axis_value) >= 0.72:
			return _move(runtime, -1 if motion.axis_value < 0.0 else 1)
	if GamepadInput.is_confirm_event(event) or _is_keyboard_confirm(event):
		return _confirm(runtime, owner, registry)
	return false


func get_panel_rect(view_size: Vector2) -> Rect2:
	var size := Vector2(view_size.x * PANEL_WIDTH_RATIO, view_size.y * PANEL_HEIGHT_RATIO)
	return Rect2((view_size - size) * 0.5, size)


func get_card_rects(view_size: Vector2, candidate_count: int) -> Array[Rect2]:
	var panel := get_panel_rect(view_size)
	var count := clampi(candidate_count, 2, 3)
	var side_margin := 34.0
	var total_gap := CARD_GAP * float(count - 1)
	var width := (panel.size.x - side_margin * 2.0 - total_gap) / float(count)
	var y := panel.position.y + 118.0
	var height := maxf(110.0, panel.size.y - 216.0)
	var rects: Array[Rect2] = []
	for index in range(count):
		rects.append(Rect2(panel.position.x + side_margin + float(index) * (width + CARD_GAP), y, width, height))
	return rects


func get_confirm_rect(view_size: Vector2) -> Rect2:
	var panel := get_panel_rect(view_size)
	var width := minf(240.0, panel.size.x * 0.42)
	return Rect2(panel.position.x + (panel.size.x - width) * 0.5, panel.end.y - 74.0, width, CONFIRM_HEIGHT)


func _move(runtime: Object, delta_index: int) -> bool:
	if runtime.has_method("move_guardian_enhance_choice_selection"):
		runtime.move_guardian_enhance_choice_selection(delta_index)
		return true
	return false


func _confirm(runtime: Object, owner: Object, registry: Object) -> bool:
	if runtime.has_method("confirm_guardian_enhance_choice"):
		return bool(runtime.confirm_guardian_enhance_choice(owner, registry))
	return false


func _index_at(position: Vector2, rects: Array[Rect2]) -> int:
	for index in range(rects.size()):
		if rects[index].has_point(position):
			return index
	return -1


func _is_keyboard_confirm(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	return key.pressed and not key.echo and (
		key.keycode in [KEY_ENTER, KEY_SPACE]
		or key.physical_keycode in [KEY_ENTER, KEY_SPACE]
	)


func _draw_centered_text(
	canvas: CanvasItem,
	text: String,
	position: Vector2,
	width: float,
	font_size: int,
	color: Color,
	line_height: float = 28.0
) -> void:
	var text_width := TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	canvas.draw_string(TITLE_FONT, position + Vector2((width - text_width) * 0.5, line_height * 0.72), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.11, 0.97)
	style.border_color = Color(0.34, 0.86, 0.68, 0.86)
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	return style


func _card_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.19, 0.17, 0.98) if selected else Color(0.055, 0.09, 0.105, 0.96)
	style.border_color = Color(0.58, 1.0, 0.80, 1.0) if selected else Color(0.22, 0.38, 0.36, 0.9)
	style.set_border_width_all(3 if selected else 2)
	style.set_corner_radius_all(14)
	return style


func _confirm_style(enabled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.20, 0.68, 0.48, 1.0) if enabled else Color(0.18, 0.24, 0.24, 0.95)
	style.border_color = Color(0.72, 1.0, 0.86, 1.0) if enabled else Color(0.34, 0.42, 0.42, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	return style
