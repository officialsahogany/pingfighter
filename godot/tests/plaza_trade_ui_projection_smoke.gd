extends SceneTree

const PlazaInteriorLayout := preload("res://scripts/plaza/plaza_interior_layout.gd")
const PlazaTradeUiProjection := preload("res://scripts/plaza/plaza_trade_ui_projection.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_root_projection()
	_verify_panel_projection()
	_verify_tooltip_projection()
	_verify_drag_feedback_and_confirm_projection()
	if _failures.is_empty():
		print("plaza_trade_ui_projection_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_root_projection() -> void:
	var snapshot := PlazaTradeUiProjection.build_root_snapshot(2.0)
	_expect(snapshot.get("backdrop_rect", Rect2()) == Rect2(Vector2.ZERO, PlazaInteriorLayout.GAME_SIZE * 2.0), "scaled root backdrop")
	_expect(snapshot.get("modal_rect", Rect2()) == Rect2(PlazaInteriorLayout.SHOP_TRADE_MODAL_RECT.position * 2.0, PlazaInteriorLayout.SHOP_TRADE_MODAL_RECT.size * 2.0), "scaled modal rect")
	_expect(str(snapshot.get("title", "")) == "아이템 거래", "root title")


func _verify_panel_projection() -> void:
	var items: Array = []
	for index in range(35):
		items.append({
			"name": "item_%02d" % index,
			"display_name": "아이템 %02d" % index,
			"shop_price": 1000 + index,
			"shop_featured": index == 8,
			"equipped": index == 8,
		})
	var snapshot := PlazaTradeUiProjection.build_panel_snapshot("shop", items, 5, "shop", 8, 1.0)
	_expect(str(snapshot.get("title", "")) == "상점 물품 (구매)  35", "shop panel title and count")
	var cells: Array = snapshot.get("cells", [])
	_expect(cells.size() == PlazaInteriorLayout.SHOP_TRADE_VISIBLE_CELLS, "visible cell projection count")
	if cells.size() > 3:
		var first: Dictionary = cells[0]
		var hovered: Dictionary = cells[3]
		_expect(int(first.get("item_index", -1)) == 5, "scroll offset should project first visible item")
		_expect(int(hovered.get("item_index", -1)) == 8, "hovered absolute item index")
		_expect(bool(hovered.get("hovered", false)), "hovered cell state")
		_expect(bool(hovered.get("featured", false)), "featured badge state")
		_expect(bool(hovered.get("equipped", false)), "equipped badge state")
		_expect(str(hovered.get("price_text", "")) == "1,008", "formatted cell price")
	_expect(not _get_dict(snapshot.get("scrollbar", {})).is_empty(), "overflow panel should project scrollbar")
	var short_snapshot := PlazaTradeUiProjection.build_panel_snapshot("player", items.slice(0, 3), 0, "", -1, 1.0)
	_expect(_get_dict(short_snapshot.get("scrollbar", {})).is_empty(), "short panel should omit scrollbar")


func _verify_tooltip_projection() -> void:
	var item := {
		"display_name": "전설 배터리",
		"description": "상세 설명",
		"shop_sell_price": 1234,
		"shop_featured": true,
		"rolled_options": [{"label": "속도", "display_value": "+10%"}],
	}
	var snapshot := PlazaTradeUiProjection.build_tooltip_snapshot("player", item, Vector2(750.0, 740.0), PlazaInteriorLayout.GAME_SIZE, 1.0)
	_expect(snapshot.get("rect", Rect2()).position == Vector2(502.0, 590.0), "tooltip should flip and clamp at the lower-right edge")
	_expect(str(snapshot.get("name", "")) == "전설 배터리", "tooltip item name")
	_expect(str(snapshot.get("price_text", "")) == "판매가 1,234G", "tooltip sell-price text")
	_expect(bool(snapshot.get("featured", false)), "tooltip featured state")
	_expect(str(snapshot.get("description", "")) == "상세 설명", "tooltip description")
	_expect(str(snapshot.get("roll_text", "")) == "속도 +10%", "tooltip roll text")
	_expect(PlazaTradeUiProjection.build_tooltip_snapshot("invalid", item, Vector2.ZERO, PlazaInteriorLayout.GAME_SIZE, 1.0).is_empty(), "invalid tooltip panel")


func _verify_drag_feedback_and_confirm_projection() -> void:
	var item := {"display_name": "장착 배터리", "quality_color": Color(0.4, 0.8, 1.0, 1.0)}
	var ghost := PlazaTradeUiProjection.build_drag_ghost_snapshot(item, Vector2(120.0, 90.0), 2.0)
	_expect(snapshot_vector(ghost, "position") == Vector2(120.0, 90.0), "drag ghost position")
	_expect(is_equal_approx(float(ghost.get("outer_radius", 0.0)), 52.0), "drag ghost scaled radius")
	_expect(str(ghost.get("name", "")) == "장착 배터리", "drag ghost name")

	var feedbacks := [
		{"action": "sale", "text": "+100G", "age": 0.46, "duration": 0.92},
		{"action": "purchase", "text": "-50G", "age": 0.0, "duration": 0.92},
	]
	var projected_feedbacks := PlazaTradeUiProjection.build_feedback_snapshots(feedbacks, 1.0)
	_expect(projected_feedbacks.size() == 2, "feedback projection count")
	if projected_feedbacks.size() == 2:
		var sale: Dictionary = projected_feedbacks[0]
		var purchase: Dictionary = projected_feedbacks[1]
		var sale_color: Color = sale.get("color", Color.TRANSPARENT)
		var purchase_color: Color = purchase.get("color", Color.TRANSPARENT)
		_expect(sale_color.g > sale_color.r, "sale feedback should be green")
		_expect(purchase_color.r > purchase_color.g, "purchase feedback should be gold")

	var confirm := PlazaTradeUiProjection.build_sell_confirm_snapshot(item, 1.0)
	_expect(str(confirm.get("title", "")) == "장착 중인 아이템입니다", "sell confirmation title")
	_expect(str(confirm.get("question", "")) == "장착 배터리을(를) 판매할까요?", "sell confirmation item question")
	_expect(str(_get_dict(confirm.get("sell_button", {})).get("label", "")) == "판매", "sell button label")
	_expect(str(_get_dict(confirm.get("cancel_button", {})).get("label", "")) == "취소", "cancel button label")


func snapshot_vector(snapshot: Dictionary, key: String) -> Vector2:
	var value: Variant = snapshot.get(key, Vector2.ZERO)
	return value if value is Vector2 else Vector2.ZERO


func _get_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
