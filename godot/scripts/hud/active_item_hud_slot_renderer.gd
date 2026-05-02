extends RefCounted

const ActiveItemHudSlotIconRenderer := preload("res://scripts/hud/active_item_hud_slot_icon_renderer.gd")
const ActiveItemHudSlotStatusRenderer := preload("res://scripts/hud/active_item_hud_slot_status_renderer.gd")

var icon_renderer: Object = ActiveItemHudSlotIconRenderer.new()
var status_renderer: Object = ActiveItemHudSlotStatusRenderer.new()


func draw_slot(
	canvas: Node2D,
	slot_rect: Rect2,
	item_data: Dictionary,
	scale_factor: float,
	visuals,
	slot_status: Dictionary,
	selected: bool,
	is_overflow_slot: bool,
	slot_number: String
) -> float:
	_draw_slot_background(canvas, slot_rect, is_overflow_slot)
	if item_data.is_empty():
		canvas.draw_rect(slot_rect, Color(40.0 / 255.0, 40.0 / 255.0, 50.0 / 255.0), false, 1.0)
		return 0.0

	icon_renderer.draw_icon(canvas, slot_rect, item_data, scale_factor, visuals)
	var remaining_ratio: float = status_renderer.draw_status_overlays(canvas, slot_rect, scale_factor, slot_status)
	_draw_slot_border(canvas, slot_rect, selected, is_overflow_slot)
	_draw_slot_number(
		canvas,
		slot_rect,
		slot_number,
		max(10, int(14.0 * scale_factor)),
		scale_factor
	)
	return remaining_ratio


func _draw_slot_background(canvas: Node2D, slot_rect: Rect2, is_overflow_slot: bool) -> void:
	var slot_alpha: float = 60.0 / 255.0 if is_overflow_slot else 120.0 / 255.0
	canvas.draw_rect(slot_rect, Color(0.0, 0.0, 0.0, slot_alpha))


func _draw_slot_border(canvas: Node2D, slot_rect: Rect2, selected: bool, is_overflow_slot: bool) -> void:
	if selected:
		canvas.draw_rect(slot_rect.grow(1.0), Color(1.0, 220.0 / 255.0, 80.0 / 255.0), false, 2.0)
	elif is_overflow_slot:
		canvas.draw_rect(slot_rect, Color(50.0 / 255.0, 50.0 / 255.0, 65.0 / 255.0), false, 1.0)
	else:
		canvas.draw_rect(slot_rect, Color(60.0 / 255.0, 60.0 / 255.0, 80.0 / 255.0), false, 1.0)


func _draw_slot_number(canvas: Node2D, slot_rect: Rect2, text: String, font_size: int, scale_factor: float) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var padding_x: float = max(2.0, floor(3.0 * scale_factor))
	var padding_y: float = max(1.0, floor(1.0 * scale_factor))
	var badge_size := Vector2(
		max(12.0 * scale_factor, text_size.x + padding_x * 2.0),
		max(11.0 * scale_factor, float(font_size) * 0.9 + padding_y * 2.0)
	)
	badge_size.x = min(badge_size.x, slot_rect.size.x - 4.0 * scale_factor)
	badge_size.y = min(badge_size.y, slot_rect.size.y - 4.0 * scale_factor)
	var badge_rect := Rect2(
		slot_rect.position + Vector2(3.0 * scale_factor, 3.0 * scale_factor),
		badge_size
	)
	canvas.draw_rect(badge_rect, Color(0.0, 0.0, 0.0, 0.58))
	canvas.draw_rect(badge_rect, Color(1.0, 1.0, 1.0, 0.22), false, 1.0)

	var text_x: float = badge_rect.position.x + (badge_rect.size.x - text_size.x) * 0.5
	var text_y: float = badge_rect.position.y + (badge_rect.size.y - text_size.y) * 0.5 + font.get_ascent(font_size)
	var pos := Vector2(text_x, text_y)
	for ox in [-1.0, 0.0, 1.0]:
		for oy in [-1.0, 0.0, 1.0]:
			if ox != 0.0 or oy != 0.0:
				canvas.draw_string(font, pos + Vector2(ox, oy), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.BLACK)
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.WHITE)
