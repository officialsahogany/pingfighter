extends SceneTree

const PlazaTradeItemPresentation := preload("res://scripts/plaza/plaza_trade_item_presentation.gd")

class FakeCatalog:
	extends RefCounted

	func get_icon_path(item_name: String) -> String:
		return "res://icons/%s.png" % item_name

	func get_icon_sheet_path(item_name: String) -> String:
		return "res://icons/%s_sheet.png" % item_name

var _failures: Array[String] = []


func _init() -> void:
	_expect_eq(PlazaTradeItemPresentation.format_gold_amount(0), "0", "zero gold")
	_expect_eq(PlazaTradeItemPresentation.format_gold_amount(999), "999", "three-digit gold")
	_expect_eq(PlazaTradeItemPresentation.format_gold_amount(1000), "1,000", "four-digit gold")
	_expect_eq(PlazaTradeItemPresentation.format_gold_amount(-1234567), "-1,234,567", "negative grouped gold")

	_expect_eq(PlazaTradeItemPresentation.format_item_name({"qualified_display_name": "전설 배터리", "display_name": "배터리"}), "전설 배터리", "qualified name priority")
	_expect_eq(PlazaTradeItemPresentation.format_item_name({"display_name": "배터리"}), "배터리", "display name fallback")
	_expect_eq(PlazaTradeItemPresentation.format_item_name({}), "아이템", "empty item name fallback")
	_expect_eq(PlazaTradeItemPresentation.format_item_description({"description": " 주 설명 "}), "주 설명", "description priority and trim")
	_expect_eq(PlazaTradeItemPresentation.format_item_description({"desc": "보조 설명"}), "보조 설명", "description alias")
	_expect_eq(
		PlazaTradeItemPresentation.format_item_description({"name": "battery", "display_name": "배터리"}),
		"배터리의 효과를 전투 중에 발동합니다.",
		"named item generated description"
	)
	_expect_eq(PlazaTradeItemPresentation.format_item_description({}), "상세 효과는 장착 후 확인할 수 있습니다.", "anonymous item description fallback")

	var rolls := {
		"rolled_options": [
			{"label": "공격", "display_value": "+10%"},
			{"stat": "속도", "value": 3},
			{"id": "ignored", "value": 99},
		]
	}
	_expect_eq(PlazaTradeItemPresentation.format_item_rolls(rolls), "공격 +10% / 속도 3", "roll summary should cap at two entries")
	_expect_eq(PlazaTradeItemPresentation.format_item_rolls({"roll_options": [{"id": "luck", "value": 5}]}), "luck 5", "roll alias fallback")
	_expect_eq(PlazaTradeItemPresentation.format_item_rolls({"rolled_options": "invalid"}), "", "invalid rolls")

	_expect_eq(PlazaTradeItemPresentation.get_icon_path({"icon_path": "res://a.png", "icon": "res://b.png"}), "res://a.png", "icon_path priority")
	_expect_eq(PlazaTradeItemPresentation.get_icon_path({"icon": "res://b.png"}), "res://b.png", "icon fallback")
	_expect_eq(PlazaTradeItemPresentation.get_icon_path({"texture_path": "res://c.png"}), "res://c.png", "texture path fallback")
	_expect_eq(PlazaTradeItemPresentation.get_icon_path({"icon_path": "C:/unsafe.png"}), "", "non-resource icon path rejection")
	_expect_eq(PlazaTradeItemPresentation.get_item_identity({"name": "speedboots", "effect": "ignored"}), "speedboots", "stable identity priority")
	_expect_eq(PlazaTradeItemPresentation.get_item_identity({"item_id": "battery"}), "battery", "identity alias fallback")
	_expect_eq(PlazaTradeItemPresentation.get_display_name({"qualified_display_name": " 최상급 배터리 ", "name": "battery"}), "최상급 배터리", "display-name priority and trim")
	_verify_inventory_projection()
	_verify_single_owner_contract()

	if _failures.is_empty():
		print("plaza_trade_item_presentation_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
		quit(1)


func _verify_inventory_projection() -> void:
	var source := [
		{"name": "speedboots", "nested": {"roll": 1}},
		{"effect": "battery", "icon_path": "res://accepted.png"},
		"invalid",
	]
	var projected := PlazaTradeItemPresentation.project_inventory(source, FakeCatalog.new(), true)
	_expect_eq(projected.size(), 2, "inventory projection should retain dictionary entries only")
	_expect_eq(projected[0].get("icon_path", ""), "res://icons/speedboots.png", "missing icon should come from catalog")
	_expect_eq(projected[0].get("icon_sheet_path", ""), "res://icons/speedboots_sheet.png", "missing icon sheet should come from catalog")
	_expect_eq(projected[1].get("icon_path", ""), "res://accepted.png", "accepted icon should be preserved")
	_expect(int(projected[0].get("shop_base_price", 0)) > 0, "sell projection should include base price")
	_expect(int(projected[0].get("shop_sell_price", 0)) > 0, "sell projection should include sell price")
	projected[0]["nested"]["roll"] = 99
	_expect_eq(source[0].get("nested", {}).get("roll", 0), 1, "inventory projection should deep-copy input")
	var shop_projection := PlazaTradeItemPresentation.project_inventory([{"name": "speedboots"}], FakeCatalog.new(), false)
	_expect(not shop_projection[0].has("shop_sell_price"), "shop stock projection should not add player sell metadata")
	_expect_eq(PlazaTradeItemPresentation.project_inventory("invalid").size(), 0, "invalid inventory projection")


func _verify_single_owner_contract() -> void:
	var scene_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_scene.gd")
	var inventory_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_shop_inventory_state.gd")
	var summary_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_shop_trade_summary.gd")
	_expect(scene_source.find("func _with_shop_icon_paths") == -1, "scene should delegate inventory presentation")
	_expect(inventory_source.find("func _get_item_identity") == -1, "inventory state should delegate item identity")
	_expect(summary_source.find("static func get_item_identity") == -1, "trade summary should delegate item identity")


func _expect_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
