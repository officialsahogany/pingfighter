extends SceneTree

const PlazaShopTradeSummary := preload("res://scripts/plaza/plaza_shop_trade_summary.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	_verify_trade_shape_and_name_priority()
	_verify_wallet_fallback()
	_verify_wallet_merge_and_copy_policy()
	_verify_scene_single_owner_contract()
	if _failures.is_empty():
		print("plaza_shop_trade_summary_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_trade_shape_and_name_priority() -> void:
	var item := {
		"name": "speedboots",
		"item_name": "ignored_identity",
		"display_name": "속도 장화",
		"qualified_display_name": "최상급 속도 장화",
	}
	var summary := PlazaShopTradeSummary.build_trade("purchase", item, 750, 0, false, "not_enough_gold")
	_expect(str(summary.get("item_name", "")) == "speedboots", "identity should use the stable name priority")
	_expect(str(summary.get("display_name", "")) == "최상급 속도 장화", "display name should prefer the qualified label")
	_expect(int(summary.get("price", 0)) == 750 and int(summary.get("sell_price", -1)) == 0, "trade prices")
	_expect(bool(summary.get("handled", false)), "purchase should be handled")
	_expect(not bool(summary.get("changed", true)) and str(summary.get("reason", "")) == "not_enough_gold", "trade result state")
	_expect(int(summary.get("delta_gold", -1)) == 0 and int(summary.get("ap_spent", -1)) == 0, "trade defaults")
	_expect(not bool(PlazaShopTradeSummary.build_trade("", {}, 0, 0, false, "unknown").get("handled", true)), "unknown action should not be handled")


func _verify_wallet_fallback() -> void:
	var fallback := PlazaShopTradeSummary.build_wallet_fallback("sale", false, "missing_plaza_save_store")
	_expect(bool(fallback.get("handled", false)), "sale wallet fallback should remain handled")
	_expect(not bool(fallback.get("changed", true)), "wallet fallback should preserve changed")
	_expect(str(fallback.get("reason", "")) == "missing_plaza_save_store", "wallet fallback reason")
	_expect(int(fallback.get("delta_gold", -1)) == 0 and int(fallback.get("ap_spent", -1)) == 0, "wallet fallback defaults")


func _verify_wallet_merge_and_copy_policy() -> void:
	var trade := PlazaShopTradeSummary.build_trade("sale", {"effect": "battery"}, 0, 270, false, "pending")
	var wallet := {
		"changed": true,
		"reason": "ok",
		"delta_gold": 270,
		"ap_spent": 1,
		"plaza_gold": 1270,
		"ap_current": 2,
		"nested": {"value": 1},
	}
	var merged := PlazaShopTradeSummary.merge_wallet(trade, wallet)
	_expect(bool(merged.get("changed", false)) and str(merged.get("reason", "")) == "ok", "wallet result should override trade state")
	_expect(int(merged.get("delta_gold", 0)) == 270 and int(merged.get("ap_spent", 0)) == 1, "wallet deltas")
	_expect(int(merged.get("plaza_gold", 0)) == 1270 and int(merged.get("ap_current", 0)) == 2, "wallet snapshot")
	merged["item_name"] = "mutated"
	merged["wallet_summary"]["nested"]["value"] = 99
	_expect(str(trade.get("item_name", "")) == "battery", "merge should not mutate the trade input")
	_expect(int(wallet.get("nested", {}).get("value", 0)) == 1, "merge should deep-copy the wallet input")


func _verify_scene_single_owner_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_scene.gd")
	_expect(source.find("func _build_shop_trade_summary") == -1, "scene should not duplicate the trade-summary builder")
	_expect(source.find("func _merge_shop_trade_wallet_summary") == -1, "scene should not duplicate wallet merge policy")
	_expect(source.find("func _build_shop_wallet_fallback") == -1, "scene should not duplicate wallet fallback policy")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
