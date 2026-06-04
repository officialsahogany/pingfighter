extends RefCounted


static func update_frame_layout(target: Object, view_size: Vector2, current_view_size: Vector2, current_panel_rect: Rect2) -> void:
	if current_panel_rect.size != Vector2.ZERO and current_view_size.is_equal_approx(view_size):
		return
	target.set("_layout_view_size", view_size)
	var panel_size := Vector2(min(1280.0, max(520.0, view_size.x - 8.0)), min(980.0, max(440.0, view_size.y - 4.0)))
	var panel_rect := Rect2((view_size - panel_size) * 0.5, panel_size)
	target.set("_layout_panel_rect", panel_rect)
	var inner_margin := 18.0
	var content_top := panel_rect.position.y + 66.0
	var content_bottom := panel_rect.end.y - 12.0
	var content_height: float = max(300.0, content_bottom - content_top)
	var column_gap := 18.0
	var inventory_height: float = clamp(content_height * 0.18, 86.0, 150.0)
	if content_height < 520.0:
		inventory_height = 82.0
	var main_bottom: float = content_bottom - inventory_height - 10.0
	var main_height: float = max(230.0, main_bottom - content_top)
	var left_w: float = min(470.0, (panel_rect.size.x - inner_margin * 2.0 - column_gap) * 0.45)
	var right_w: float = panel_rect.size.x - inner_margin * 2.0 - column_gap - left_w
	var left_rect := Rect2(panel_rect.position.x + inner_margin, content_top, left_w, main_height)
	var right_rect := Rect2(left_rect.end.x + column_gap, content_top, right_w, main_height)
	target.set("_layout_inventory_rect", Rect2(panel_rect.position.x + inner_margin, main_bottom + 14.0, panel_rect.size.x - inner_margin * 2.0, max(90.0, content_bottom - main_bottom - 14.0)))
	target.set("_layout_equipment_rect", section_rect(left_rect, 0.0, 0.58))
	target.set("_layout_skill_rect", section_rect(left_rect, 0.60, 0.19))
	target.set("_layout_active_items_rect", section_rect(left_rect, 0.80, 0.20))
	var right_top_rect := section_rect(right_rect, 0.0, 0.58)
	var right_top_gap := 12.0
	if right_top_rect.size.x >= 560.0:
		var lingpet_w: float = clamp(right_top_rect.size.x * 0.34, 230.0, 320.0)
		var perk_rect := Rect2(right_top_rect.position, Vector2(right_top_rect.size.x - lingpet_w - right_top_gap, right_top_rect.size.y))
		target.set("_layout_perk_rect", perk_rect)
		target.set("_layout_lingpet_rect", Rect2(perk_rect.end.x + right_top_gap, right_top_rect.position.y, lingpet_w, right_top_rect.size.y))
	else:
		var perk_h: float = max(64.0, right_top_rect.size.y * 0.54 - right_top_gap * 0.5)
		var perk_rect := Rect2(right_top_rect.position, Vector2(right_top_rect.size.x, perk_h))
		target.set("_layout_perk_rect", perk_rect)
		target.set("_layout_lingpet_rect", Rect2(right_top_rect.position.x, perk_rect.end.y + right_top_gap, right_top_rect.size.x, max(64.0, right_top_rect.end.y - perk_rect.end.y - right_top_gap)))
	target.set("_layout_stats_rect", section_rect(right_rect, 0.60, 0.40))


static func section_rect(column_rect: Rect2, start_ratio: float, height_ratio: float) -> Rect2:
	var gap := 10.0
	var y: float = column_rect.position.y + column_rect.size.y * start_ratio
	var height: float = column_rect.size.y * height_ratio - gap
	return Rect2(column_rect.position.x, y, column_rect.size.x, max(64.0, height))
