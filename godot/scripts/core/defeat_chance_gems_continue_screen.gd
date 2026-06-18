extends RefCounted

const PANEL_SIZE := Vector2(520.0, 410.0)
const BUTTON_SIZE := Vector2(176.0, 42.0)
const GEM_COUNT := 3

var active: bool = false
var remaining_gems: int = 0
var max_gems: int = GEM_COUNT
var elapsed_sec: float = 0.0
var _pending_continue_callback: Callable = Callable()
var _pending_owner: Object = null
var _pending_registry: Object = null


func show(owner: Object, registry: Object, continue_callback: Callable) -> bool:
	_pending_owner = owner
	_pending_registry = registry
	_pending_continue_callback = continue_callback
	max_gems = _read_int(owner, "chance_gems_max", GEM_COUNT)
	max_gems = clampi(max_gems, 1, GEM_COUNT)
	remaining_gems = clampi(_read_int(owner, "chance_gems_count", max_gems), 0, max_gems)
	elapsed_sec = 0.0
	active = true
	_queue_redraw(owner)
	return true


func is_active() -> bool:
	return active


func reset() -> void:
	active = false
	remaining_gems = 0
	max_gems = GEM_COUNT
	elapsed_sec = 0.0
	_pending_continue_callback = Callable()
	_pending_owner = null
	_pending_registry = null


func update(delta: float) -> void:
	if not active:
		return
	elapsed_sec += max(0.0, delta)


func handle_input(event: InputEvent, owner: Object, _registry: Object, view_size: Vector2) -> bool:
	if not active:
		return false
	if _is_confirm_event(event, view_size):
		_continue(owner)
		return true
	return true


func draw(canvas: CanvasItem, owner: Object, _registry: Object, view_size: Vector2) -> void:
	if canvas == null or not active:
		return
	var ui_font := _get_ui_font()
	var center := view_size * 0.5
	var panel_rect := Rect2(center - PANEL_SIZE * 0.5, PANEL_SIZE)
	var pulse: float = 0.5 + 0.5 * sin(elapsed_sec * TAU * 1.35)
	var accent := Color(0.35, 0.82, 1.0, 0.90)
	var gold := Color(0.92, 0.76, 0.38, 0.92)

	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.66))
	canvas.draw_rect(panel_rect.grow(12.0), Color(0.02, 0.03, 0.055, 0.46))
	canvas.draw_rect(panel_rect, Color(0.028, 0.034, 0.062, 0.96))
	canvas.draw_rect(panel_rect, Color(0.22, 0.55, 0.88, 0.70), false, 2.0)
	canvas.draw_rect(Rect2(panel_rect.position, Vector2(panel_rect.size.x, 4.0)), Color(accent.r, accent.g, accent.b, 0.82))

	_draw_centered_text(canvas, ui_font, "패배", panel_rect.position + Vector2(panel_rect.size.x * 0.5, 54.0), 34, Color(1.0, 1.0, 1.0, 0.98))
	_draw_centered_text(canvas, ui_font, "아직 다음 기회가 남아 있습니다", panel_rect.position + Vector2(panel_rect.size.x * 0.5, 94.0), 17, Color(0.76, 0.88, 1.0, 0.92))

	var stage_text := "스테이지 %d 보스에게 패배했습니다" % max(1, _read_int(owner, "current_stage", 1))
	_draw_centered_text(canvas, ui_font, stage_text, panel_rect.position + Vector2(panel_rect.size.x * 0.5, 126.0), 15, Color(0.78, 0.82, 0.90, 0.88))

	var gem_center_y := panel_rect.position.y + 198.0
	var gem_gap := 74.0
	var first_x := panel_rect.get_center().x - gem_gap
	for i in range(max_gems):
		var gem_center := Vector2(first_x + float(i) * gem_gap, gem_center_y)
		_draw_gem_slot(canvas, gem_center, 26.0, i >= remaining_gems, i == remaining_gems, pulse)

	var body_y := panel_rect.position.y + 254.0
	_draw_centered_text(canvas, ui_font, "기회의 보석 1개가 소모되었습니다.", Vector2(panel_rect.get_center().x, body_y), 16, Color(0.94, 0.97, 1.0, 0.95))
	var guide := "모든 보석이 사라지면 더 이상 이어할 수 없습니다."
	if remaining_gems <= 0:
		guide = "이번이 마지막 기회입니다. 다음 패배 시 게임이 종료됩니다."
	_draw_centered_text(canvas, ui_font, guide, Vector2(panel_rect.get_center().x, body_y + 30.0), 14, gold if remaining_gems <= 0 else Color(0.68, 0.76, 0.88, 0.88))

	var button_rect := _get_button_rect(view_size)
	canvas.draw_rect(button_rect, Color(0.08, 0.23, 0.36, 0.96))
	canvas.draw_rect(button_rect, Color(accent.r, accent.g, accent.b, 0.78 + pulse * 0.18), false, 2.0)
	canvas.draw_rect(button_rect.grow(-4.0), Color(1.0, 1.0, 1.0, 0.06))
	_draw_centered_text(canvas, ui_font, "확인", button_rect.get_center() + Vector2(0.0, 1.0), 17, Color.WHITE)


func _draw_gem_slot(canvas: CanvasItem, center: Vector2, radius: float, broken: bool, breaking: bool, pulse: float) -> void:
	var alpha := 0.92 if not broken else 0.48
	var glow_alpha := (0.25 + pulse * 0.20) if breaking else 0.14
	var fill := Color(0.11, 0.52, 0.95, alpha) if not broken else Color(0.18, 0.25, 0.34, alpha)
	var rim := Color(0.62, 0.92, 1.0, 0.92) if not broken else Color(0.38, 0.46, 0.58, 0.70)
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius * 0.82, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius * 0.82, 0.0),
	])
	canvas.draw_circle(center, radius * 1.36, Color(0.24, 0.72, 1.0, glow_alpha if not broken else 0.04))
	canvas.draw_colored_polygon(points, fill)
	canvas.draw_polyline(points + PackedVector2Array([points[0]]), rim, 2.0)
	canvas.draw_line(center + Vector2(0.0, -radius * 0.68), center + Vector2(radius * 0.36, 0.0), Color(0.86, 0.98, 1.0, alpha * 0.62), 1.0)
	canvas.draw_line(center + Vector2(0.0, -radius * 0.68), center + Vector2(-radius * 0.36, 0.0), Color(0.86, 0.98, 1.0, alpha * 0.44), 1.0)
	if broken:
		var crack := Color(0.02, 0.04, 0.08, 0.86)
		canvas.draw_line(center + Vector2(-radius * 0.32, -radius * 0.58), center + Vector2(radius * 0.05, -radius * 0.10), crack, 2.0)
		canvas.draw_line(center + Vector2(radius * 0.05, -radius * 0.10), center + Vector2(-radius * 0.18, radius * 0.52), crack, 2.0)
		canvas.draw_line(center + Vector2(radius * 0.05, -radius * 0.10), center + Vector2(radius * 0.42, radius * 0.30), crack, 1.6)
		canvas.draw_circle(center + Vector2(radius * 0.84, radius * 0.58), radius * 0.12, Color(0.32, 0.46, 0.58, 0.56))


func _is_confirm_event(event: InputEvent, view_size: Vector2) -> bool:
	if event == null:
		return false
	if event.is_action_pressed("ui_accept"):
		return true
	if event is InputEventKey:
		var key_event: InputEventKey = event
		return key_event.pressed and not key_event.echo and key_event.keycode in [KEY_ENTER, KEY_SPACE]
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		return (
			mouse_event.pressed
			and mouse_event.button_index == MOUSE_BUTTON_LEFT
			and _get_button_rect(view_size).has_point(mouse_event.position)
		)
	return false


func _continue(owner: Object) -> void:
	var callback := _pending_continue_callback
	reset()
	if callback.is_valid():
		callback.call()
	_queue_redraw(owner)


func _get_button_rect(view_size: Vector2) -> Rect2:
	var panel_rect := Rect2(view_size * 0.5 - PANEL_SIZE * 0.5, PANEL_SIZE)
	return Rect2(
		Vector2(panel_rect.get_center().x - BUTTON_SIZE.x * 0.5, panel_rect.end.y - 74.0),
		BUTTON_SIZE
	)


func _draw_centered_text(canvas: CanvasItem, font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
	if font == null or text == "":
		return
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := center - text_size * 0.5 + Vector2(0.0, text_size.y * 0.78)
	canvas.draw_string(font, baseline + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.72))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _get_ui_font() -> Font:
	return ThemeDB.fallback_font


func _read_int(owner: Object, key: String, fallback: int) -> int:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return int(value)


func _queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()
