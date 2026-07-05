extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

# Drawing-based confirm modal for discarding an item from the character-info
# overlay (trash-drop). Mirrors the CharacterInfoOverlayPendulumInterior pattern:
# RefCounted + is_active()/draw()/handle_mouse_button(), with the owning overlay
# intercepting input while it is active. handle_mouse_button returns
# &"confirmed" / &"cancelled" / &"" so the overlay can apply the real discard.

var active := false
var _item_label := ""
var _pending: Dictionary = {}
var _modal_rect := Rect2()
var _confirm_rect := Rect2()
var _cancel_rect := Rect2()


func is_active() -> bool:
	return active


func get_pending() -> Dictionary:
	return _pending


func open(item_label: String, pending: Dictionary) -> bool:
	active = true
	_item_label = item_label
	_pending = pending.duplicate(true)
	return true


func reset() -> void:
	active = false
	_item_label = ""
	_pending = {}
	_modal_rect = Rect2()
	_confirm_rect = Rect2()
	_cancel_rect = Rect2()


func handle_mouse_button(mouse_pos: Vector2, button_index: int) -> StringName:
	if not active or button_index != MOUSE_BUTTON_LEFT:
		return &""
	if _confirm_rect.has_point(mouse_pos):
		return &"confirmed"
	if _cancel_rect.has_point(mouse_pos):
		return &"cancelled"
	if not _modal_rect.has_point(mouse_pos):
		# Clicking outside the modal cancels, matching the original discard flow.
		return &"cancelled"
	return &""


func draw(canvas: CanvasItem, font: Font, panel_rect: Rect2, view_size: Vector2, mouse_pos: Vector2 = Vector2.INF) -> void:
	if not active or canvas == null:
		return
	# Dim the panel behind the modal.
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.52))
	var modal_size := Vector2(360.0, 188.0)
	var modal_pos := panel_rect.position + (panel_rect.size - modal_size) * 0.5
	_modal_rect = Rect2(modal_pos, modal_size)
	canvas.draw_rect(_modal_rect, Color(0.12, 0.10, 0.13, 0.98))
	canvas.draw_rect(_modal_rect, Color(0.85, 0.30, 0.32, 0.95), false, 2.0)

	var title: String = LanguageSettings.translate_text("아이템을 버릴까요?")
	font.draw_string(canvas.get_canvas_item(), modal_pos + Vector2(0.0, 42.0), title, HORIZONTAL_ALIGNMENT_CENTER, modal_size.x, 18, Color(1.0, 0.92, 0.92, 1.0))
	if _item_label != "":
		font.draw_string(canvas.get_canvas_item(), modal_pos + Vector2(0.0, 78.0), _item_label, HORIZONTAL_ALIGNMENT_CENTER, modal_size.x, 15, Color(0.95, 0.85, 0.6, 1.0))

	var button_size := Vector2(132.0, 44.0)
	var button_y := modal_pos.y + modal_size.y - button_size.y - 18.0
	_confirm_rect = Rect2(Vector2(modal_pos.x + 24.0, button_y), button_size)
	_cancel_rect = Rect2(Vector2(modal_pos.x + modal_size.x - button_size.x - 24.0, button_y), button_size)
	_draw_button(canvas, font, _confirm_rect, "버리기", Color(0.62, 0.18, 0.20, 1.0), Color(1.0, 0.9, 0.9, 1.0), mouse_pos)
	_draw_button(canvas, font, _cancel_rect, "취소", Color(0.22, 0.24, 0.30, 1.0), Color(0.9, 0.92, 1.0, 1.0), mouse_pos)


func _draw_button(canvas: CanvasItem, font: Font, rect: Rect2, label: String, fill: Color, text_color: Color, mouse_pos: Vector2) -> void:
	var hovered: bool = rect.has_point(mouse_pos)
	var fill_color := fill.lightened(0.12) if hovered else fill
	canvas.draw_rect(rect, fill_color)
	canvas.draw_rect(rect, Color(1.0, 1.0, 1.0, 0.35), false, 1.5)
	font.draw_string(canvas.get_canvas_item(), rect.position + Vector2(0.0, rect.size.y * 0.62), LanguageSettings.translate_text(label), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 16, text_color)
