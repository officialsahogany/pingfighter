extends RefCounted

const PlazaInteriorLayout := preload("res://scripts/plaza/plaza_interior_layout.gd")
const PlazaTradeFeedbackState := preload("res://scripts/plaza/plaza_trade_feedback_state.gd")
const PlazaTradeItemPresentation := preload("res://scripts/plaza/plaza_trade_item_presentation.gd")

const PLAYER_PANEL := "player"
const SHOP_PANEL := "shop"
const TOOLTIP_SIZE := Vector2(230.0, 148.0)


static func build_root_snapshot(scale: float) -> Dictionary:
	var modal_rect := _scale_rect(PlazaInteriorLayout.SHOP_TRADE_MODAL_RECT, scale)
	return {
		"backdrop_rect": Rect2(Vector2.ZERO, PlazaInteriorLayout.GAME_SIZE * scale),
		"backdrop_color": Color(0.0, 0.0, 0.0, 0.70),
		"modal_rect": modal_rect,
		"modal_color": Color(22.0 / 255.0, 26.0 / 255.0, 40.0 / 255.0, 0.98),
		"modal_border_color": Color(0.88, 0.20, 1.0, 0.72),
		"modal_border_width": maxf(1.0, 1.4 * scale),
		"title": "아이템 거래",
		"title_position": modal_rect.position + Vector2(24.0, 34.0) * scale,
		"title_font_size": int(20.0 * scale),
		"title_color": Color(0.96, 0.78, 1.0, 1.0),
		"escape_label": "ESC",
		"escape_position": modal_rect.position + Vector2(438.0, 34.0) * scale,
		"escape_font_size": int(13.0 * scale),
		"escape_color": Color(0.78, 0.92, 1.0, 0.78),
	}


static func build_panel_snapshot(
	panel: String,
	items: Array,
	scroll_offset: int,
	hover_panel: String,
	hover_index: int,
	scale: float
) -> Dictionary:
	var panel_rect_game := PlazaInteriorLayout.get_trade_panel_rect(panel)
	if panel_rect_game.size == Vector2.ZERO:
		return {}
	var border_color := _get_panel_border_color(panel)
	var panel_rect := _scale_rect(panel_rect_game, scale)
	var cells: Array[Dictionary] = []
	for visible_index in range(PlazaInteriorLayout.SHOP_TRADE_VISIBLE_CELLS):
		var cell_rect_game := PlazaInteriorLayout.get_visible_trade_cell_rect(panel_rect_game, visible_index)
		var cell_rect := _scale_rect(cell_rect_game, scale)
		var item_index := scroll_offset + visible_index
		var hovered := panel == hover_panel and item_index == hover_index
		var cell := {
			"rect": cell_rect,
			"item_index": item_index,
			"hovered": hovered,
			"background_color": Color(0.05, 0.06, 0.09, 0.88),
			"border_color": Color(border_color.r, border_color.g, border_color.b, 0.48 if hovered else 0.20),
			"border_width": maxf(1.0, (1.8 if hovered else 1.0) * scale),
			"occupied": false,
		}
		if item_index >= 0 and item_index < items.size():
			var item_data := _get_dict(items[item_index])
			var item_color := PlazaTradeItemPresentation.get_color(item_data, border_color)
			var equipped := PlazaTradeItemPresentation.is_equipped(item_data)
			var price := PlazaTradeItemPresentation.get_price_for_panel(panel, item_data)
			cell["occupied"] = true
			cell["item"] = item_data
			cell["item_color"] = item_color
			cell["outer_radius"] = PlazaInteriorLayout.SHOP_TRADE_CELL_SIZE * 0.28 * scale
			cell["outer_color"] = Color(item_color.r, item_color.g, item_color.b, 0.44)
			cell["fallback_radius"] = PlazaInteriorLayout.SHOP_TRADE_CELL_SIZE * 0.17 * scale
			cell["fallback_color"] = Color(item_color.r, item_color.g, item_color.b, 0.76)
			cell["featured"] = bool(item_data.get("shop_featured", false))
			cell["badge_rect"] = Rect2(cell_rect.end - Vector2(14.0, 14.0) * scale, Vector2(10.0, 10.0) * scale)
			cell["badge_color"] = Color(1.0, 0.78, 0.24, 0.92)
			cell["equipped"] = equipped
			cell["equipped_rect"] = Rect2(cell_rect.position + Vector2(3.0, 3.0) * scale, Vector2(13.0, 13.0) * scale)
			cell["equipped_color"] = Color(0.0, 0.92, 1.0, 0.82)
			cell["equipped_border_color"] = Color(0.92, 1.0, 1.0, 0.92)
			cell["equipped_border_width"] = maxf(1.0, 0.8 * scale)
			cell["equipped_label_position"] = cell_rect.position + Vector2(6.0, 13.0) * scale
			cell["equipped_label_font_size"] = int(9.0 * scale)
			cell["equipped_label_color"] = Color(0.02, 0.03, 0.05, 0.95)
			cell["price"] = price
			cell["price_text"] = PlazaTradeItemPresentation.format_gold_amount(price)
			cell["price_position"] = cell_rect.position + Vector2(4.0, 39.0) * scale
		cells.append(cell)
	return {
		"panel": panel,
		"rect": panel_rect,
		"background_color": Color(30.0 / 255.0, 36.0 / 255.0, 54.0 / 255.0, 0.94),
		"border_color": border_color,
		"border_width": maxf(1.0, 1.2 * scale),
		"title": "%s  %d" % [_get_panel_title(panel), items.size()],
		"title_position": panel_rect.position + Vector2(14.0, 24.0) * scale,
		"title_font_size": int(15.0 * scale),
		"title_color": Color(border_color.r, border_color.g, border_color.b, 1.0),
		"cells": cells,
		"scrollbar": _build_scrollbar_snapshot(panel_rect_game, items.size(), scroll_offset, border_color, scale),
	}


static func build_tooltip_snapshot(
	panel: String,
	item_data: Dictionary,
	mouse_game_position: Vector2,
	game_size: Vector2,
	scale: float
) -> Dictionary:
	if item_data.is_empty() or not [PLAYER_PANEL, SHOP_PANEL].has(panel):
		return {}
	var tooltip_position := mouse_game_position + Vector2(18.0, 14.0)
	if tooltip_position.x + TOOLTIP_SIZE.x > game_size.x - 12.0:
		tooltip_position.x = mouse_game_position.x - TOOLTIP_SIZE.x - 18.0
	if tooltip_position.y + TOOLTIP_SIZE.y > game_size.y - 12.0:
		tooltip_position.y = game_size.y - TOOLTIP_SIZE.y - 12.0
	tooltip_position.x = clampf(tooltip_position.x, 12.0, game_size.x - TOOLTIP_SIZE.x - 12.0)
	tooltip_position.y = clampf(tooltip_position.y, 12.0, game_size.y - TOOLTIP_SIZE.y - 12.0)
	var rect := _scale_rect(Rect2(tooltip_position, TOOLTIP_SIZE), scale)
	var price := PlazaTradeItemPresentation.get_price_for_panel(panel, item_data)
	var price_label := "판매가" if panel == PLAYER_PANEL else "구매가"
	return {
		"rect": rect,
		"background_color": Color(0.018, 0.021, 0.033, 0.96),
		"border_color": Color(0.0, 0.88, 1.0, 0.82) if panel == PLAYER_PANEL else Color(1.0, 0.78, 0.24, 0.86),
		"border_width": maxf(1.0, 1.0 * scale),
		"name": PlazaTradeItemPresentation.format_item_name(item_data),
		"name_color": PlazaTradeItemPresentation.get_color(item_data, Color(0.94, 0.98, 1.0, 1.0)),
		"price_text": "%s %sG" % [price_label, PlazaTradeItemPresentation.format_gold_amount(price)] if price > 0 else "%s -" % price_label,
		"featured": bool(item_data.get("shop_featured", false)),
		"description": PlazaTradeItemPresentation.format_item_description(item_data),
		"roll_text": PlazaTradeItemPresentation.format_item_rolls(item_data),
	}


static func build_drag_ghost_snapshot(item_data: Dictionary, local_position: Vector2, scale: float) -> Dictionary:
	if item_data.is_empty():
		return {}
	var item_color := PlazaTradeItemPresentation.get_color(item_data, Color(0.9, 0.8, 1.0, 1.0))
	return {
		"position": local_position,
		"outer_radius": 26.0 * scale,
		"outer_color": Color(item_color.r, item_color.g, item_color.b, 0.22),
		"icon_rect": Rect2(local_position - Vector2(18.0, 18.0) * scale, Vector2(36.0, 36.0) * scale),
		"fallback_radius": 15.0 * scale,
		"fallback_color": Color(item_color.r, item_color.g, item_color.b, 0.74),
		"name": PlazaTradeItemPresentation.format_item_name(item_data),
		"name_position": local_position + Vector2(18.0, -10.0) * scale,
		"name_font_size": int(10.0 * scale),
		"name_color": Color(0.96, 0.98, 1.0, 0.92),
	}


static func build_feedback_snapshots(feedbacks: Array, scale: float) -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for index in range(feedbacks.size()):
		var feedback := _get_dict(feedbacks[index])
		var duration := maxf(0.001, float(feedback.get("duration", PlazaTradeFeedbackState.DEFAULT_DURATION)))
		var progress := clampf(float(feedback.get("age", 0.0)) / duration, 0.0, 1.0)
		var alpha := 1.0 - _smooth_unit(progress)
		var action := str(feedback.get("action", ""))
		snapshots.append({
			"text": str(feedback.get("text", "")),
			"position": (PlazaInteriorLayout.SHOP_TRADE_MODAL_RECT.position + Vector2(310.0, 82.0 - progress * 36.0 - float(index) * 18.0)) * scale,
			"font_size": int(16.0 * scale),
			"color": Color(0.58, 1.0, 0.72, alpha) if action == "sale" else Color(1.0, 0.78, 0.32, alpha),
		})
	return snapshots


static func build_sell_confirm_snapshot(item_data: Dictionary, scale: float) -> Dictionary:
	if item_data.is_empty():
		return {}
	return {
		"rect": _scale_rect(PlazaInteriorLayout.SHOP_TRADE_CONFIRM_RECT, scale),
		"background_color": Color(0.006, 0.008, 0.014, 0.96),
		"border_color": Color(0.0, 0.88, 1.0, 0.76),
		"border_width": maxf(1.0, 1.2 * scale),
		"title": "장착 중인 아이템입니다",
		"question": "%s을(를) 판매할까요?" % PlazaTradeItemPresentation.format_item_name(item_data),
		"sell_button": {
			"rect": PlazaInteriorLayout.SHOP_TRADE_CONFIRM_SELL_RECT,
			"label": "판매",
			"color": Color(1.0, 0.68, 0.28, 0.88),
		},
		"cancel_button": {
			"rect": PlazaInteriorLayout.SHOP_TRADE_CONFIRM_CANCEL_RECT,
			"label": "취소",
			"color": Color(0.0, 0.84, 1.0, 0.78),
		},
	}


static func _build_scrollbar_snapshot(
	panel_rect: Rect2,
	item_count: int,
	scroll_offset: int,
	border_color: Color,
	scale: float
) -> Dictionary:
	if item_count <= PlazaInteriorLayout.SHOP_TRADE_VISIBLE_CELLS:
		return {}
	var track := Rect2(
		(panel_rect.position + Vector2(panel_rect.size.x - 12.0, 48.0)) * scale,
		Vector2(4.0, 260.0) * scale
	)
	var max_offset := maxi(1, item_count - PlazaInteriorLayout.SHOP_TRADE_VISIBLE_CELLS)
	var visible_ratio := clampf(float(PlazaInteriorLayout.SHOP_TRADE_VISIBLE_CELLS) / float(item_count), 0.12, 1.0)
	var handle_height := maxf(24.0 * scale, track.size.y * visible_ratio)
	var travel := maxf(1.0, track.size.y - handle_height)
	var handle_y := track.position.y + travel * float(scroll_offset) / float(max_offset)
	return {
		"track_rect": track,
		"track_color": Color(0.0, 0.0, 0.0, 0.38),
		"handle_rect": Rect2(Vector2(track.position.x, handle_y), Vector2(track.size.x, handle_height)),
		"handle_color": Color(border_color.r, border_color.g, border_color.b, 0.78),
	}


static func _get_panel_title(panel: String) -> String:
	return "내 인벤토리 (판매)" if panel == PLAYER_PANEL else "상점 물품 (구매)"


static func _get_panel_border_color(panel: String) -> Color:
	return Color(0.0, 0.88, 1.0, 0.82) if panel == PLAYER_PANEL else Color(1.0, 0.78, 0.24, 0.82)


static func _smooth_unit(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


static func _scale_rect(rect: Rect2, scale: float) -> Rect2:
	return Rect2(rect.position * scale, rect.size * scale)


static func _get_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
