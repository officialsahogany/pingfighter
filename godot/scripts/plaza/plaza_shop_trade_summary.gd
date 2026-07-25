extends RefCounted

const PlazaTradeItemPresentation := preload("res://scripts/plaza/plaza_trade_item_presentation.gd")


static func build_trade(
	action_id: String,
	item_data: Dictionary,
	price: int,
	sell_price: int,
	changed: bool,
	reason: String
) -> Dictionary:
	return {
		"action": action_id,
		"item_name": PlazaTradeItemPresentation.get_item_identity(item_data),
		"display_name": PlazaTradeItemPresentation.get_display_name(item_data),
		"price": price,
		"sell_price": sell_price,
		"handled": _is_handled_action(action_id),
		"changed": changed,
		"reason": reason,
		"delta_gold": 0,
		"ap_spent": 0,
	}


static func build_wallet_fallback(action_id: String, changed: bool, reason: String) -> Dictionary:
	return {
		"action": action_id,
		"handled": _is_handled_action(action_id),
		"changed": changed,
		"reason": reason,
		"delta_gold": 0,
		"ap_spent": 0,
	}


static func merge_wallet(trade_summary: Dictionary, wallet_summary: Dictionary) -> Dictionary:
	var result := trade_summary.duplicate(true)
	result["wallet_summary"] = wallet_summary.duplicate(true)
	result["delta_gold"] = int(wallet_summary.get("delta_gold", result.get("delta_gold", 0)))
	result["ap_spent"] = int(wallet_summary.get("ap_spent", result.get("ap_spent", 0)))
	result["plaza_gold"] = int(wallet_summary.get("plaza_gold", result.get("plaza_gold", 0)))
	result["ap_current"] = int(wallet_summary.get("ap_current", result.get("ap_current", 0)))
	result["reason"] = str(wallet_summary.get("reason", result.get("reason", "")))
	result["changed"] = bool(wallet_summary.get("changed", result.get("changed", false)))
	return result


static func _is_handled_action(action_id: String) -> bool:
	return action_id == "purchase" or action_id == "sale"
