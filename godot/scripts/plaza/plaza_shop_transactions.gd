extends RefCounted

const DEFAULT_SELL_PRICE := 40
const BUY_PRODUCTS := [
	{
		"action": "buy_wall",
		"item_name": "wall",
		"display_name": "벽돌",
		"price": 80,
	},
	{
		"action": "buy_boomerang",
		"item_name": "boomerang",
		"display_name": "부메랑",
		"price": 120,
	},
]
const SELL_LAST_ACTION := "sell_last_active"


static func get_menu_action_labels() -> Array[String]:
	var labels: Array[String] = []
	for product_value in BUY_PRODUCTS:
		var product: Dictionary = product_value
		labels.append("%s 구매 %dG" % [
			str(product.get("display_name", "")),
			int(product.get("price", 0)),
		])
	labels.append("마지막 아이템 판매")
	return labels


func perform_action(
	action_index: int,
	save_store: Object,
	owner: Object,
	registry: Object,
	consume_ap: bool
) -> Dictionary:
	if action_index >= 0 and action_index < BUY_PRODUCTS.size():
		return _purchase_product(BUY_PRODUCTS[action_index], save_store, owner, registry, consume_ap)
	if action_index == BUY_PRODUCTS.size():
		return _sell_last_active_item(save_store, owner, registry, consume_ap)
	return _build_summary("", "", "", 0, 0, false, "unknown_shop_action")


func _purchase_product(
	product: Dictionary,
	save_store: Object,
	owner: Object,
	registry: Object,
	consume_ap: bool
) -> Dictionary:
	var item_name := str(product.get("item_name", ""))
	var display_name := str(product.get("display_name", item_name))
	var price := maxi(1, int(product.get("price", 0)))
	if item_name == "":
		return _build_summary("purchase", item_name, display_name, price, 0, false, "unknown_shop_item")
	if not _has_plaza_gold(save_store, price):
		return _build_summary("purchase", item_name, display_name, price, 0, false, "not_enough_gold")
	if _is_ap_blocked(save_store, consume_ap):
		return _build_summary("purchase", item_name, display_name, price, 0, false, "no_ap")
	var active_item_runtime := _get_active_item_runtime(registry)
	if active_item_runtime == null or not active_item_runtime.has_method("grant_item_to_slot"):
		return _build_summary("purchase", item_name, display_name, price, 0, false, "missing_item_runtime")
	if owner == null:
		return _build_summary("purchase", item_name, display_name, price, 0, false, "missing_owner")
	if not bool(active_item_runtime.grant_item_to_slot(item_name, owner, registry, false)):
		return _build_summary("purchase", item_name, display_name, price, 0, false, "active_slots_full")
	var payment := _perform_wallet_transaction(save_store, "purchase", price, consume_ap)
	if not bool(payment.get("changed", false)):
		_rollback_granted_item(active_item_runtime, item_name, owner, registry)
		return _merge_wallet_summary(
			_build_summary("purchase", item_name, display_name, price, 0, false, str(payment.get("reason", "payment_failed"))),
			payment
		)
	return _merge_wallet_summary(
		_build_summary("purchase", item_name, display_name, price, 0, true, "ok"),
		payment
	)


func _sell_last_active_item(save_store: Object, owner: Object, registry: Object, consume_ap: bool) -> Dictionary:
	if _is_ap_blocked(save_store, consume_ap):
		return _build_summary("sale", "", "", 0, 0, false, "no_ap")
	var active_item_runtime := _get_active_item_runtime(registry)
	if active_item_runtime == null or not active_item_runtime.has_method("debug_remove_item_from_slot"):
		return _build_summary("sale", "", "", 0, 0, false, "missing_item_runtime")
	var item_data := _get_last_active_item(owner)
	var item_name := _get_item_identity(item_data)
	if item_name == "":
		return _build_summary("sale", "", "", 0, 0, false, "no_active_item")
	var display_name := str(item_data.get("display_name", item_name))
	var sell_price := _get_sell_price(item_name)
	if not bool(active_item_runtime.debug_remove_item_from_slot(item_name, owner, registry)):
		return _build_summary("sale", item_name, display_name, 0, sell_price, false, "no_active_item")
	var payment := _perform_wallet_transaction(save_store, "sale", sell_price, consume_ap)
	return _merge_wallet_summary(
		_build_summary("sale", item_name, display_name, 0, sell_price, bool(payment.get("changed", false)), str(payment.get("reason", "ok"))),
		payment
	)


func _get_sell_price(item_name: String) -> int:
	for product_value in BUY_PRODUCTS:
		var product: Dictionary = product_value
		if str(product.get("item_name", "")) == item_name:
			return maxi(1, int(floor(float(int(product.get("price", 0))) * 0.5)))
	return DEFAULT_SELL_PRICE


func _get_last_active_item(owner: Object) -> Dictionary:
	if owner == null:
		return {}
	var value: Variant = owner.get("active_item_slots")
	if not (value is Array):
		return {}
	var active_item_slots: Array = value
	for index in range(active_item_slots.size() - 1, -1, -1):
		var item_value: Variant = active_item_slots[index]
		if not (item_value is Dictionary):
			continue
		var item_data: Dictionary = item_value
		if _get_item_identity(item_data) != "":
			return item_data.duplicate(true)
	return {}


func _get_item_identity(item_data: Dictionary) -> String:
	for key in ["name", "effect", "item_name", "item_id"]:
		var value := str(item_data.get(str(key), ""))
		if value != "":
			return value
	return ""


func _has_plaza_gold(save_store: Object, amount: int) -> bool:
	return save_store != null and save_store.has_method("get_plaza_gold") and int(save_store.get_plaza_gold()) >= amount


func _is_ap_blocked(save_store: Object, consume_ap: bool) -> bool:
	return consume_ap and (save_store == null or not save_store.has_method("get_ap_current") or int(save_store.get_ap_current()) <= 0)


func _perform_wallet_transaction(save_store: Object, action_id: String, amount: int, consume_ap: bool) -> Dictionary:
	if save_store == null or not save_store.has_method("perform_shop_wallet_transaction"):
		return _build_wallet_summary(action_id, 0, false, "missing_plaza_save_store")
	var result: Variant = save_store.perform_shop_wallet_transaction(action_id, amount, consume_ap)
	if result is Dictionary:
		return result
	return _build_wallet_summary(action_id, 0, false, "invalid_wallet_result")


func _get_active_item_runtime(registry: Object) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance("active_item_runtime")


func _rollback_granted_item(active_item_runtime: Object, item_name: String, owner: Object, registry: Object) -> void:
	if active_item_runtime != null and active_item_runtime.has_method("debug_remove_item_from_slot"):
		active_item_runtime.debug_remove_item_from_slot(item_name, owner, registry)


func _merge_wallet_summary(summary: Dictionary, wallet_summary: Dictionary) -> Dictionary:
	summary["wallet_summary"] = wallet_summary.duplicate(true)
	summary["delta_gold"] = int(wallet_summary.get("delta_gold", summary.get("delta_gold", 0)))
	summary["ap_spent"] = int(wallet_summary.get("ap_spent", summary.get("ap_spent", 0)))
	summary["plaza_gold"] = int(wallet_summary.get("plaza_gold", summary.get("plaza_gold", 0)))
	summary["ap_current"] = int(wallet_summary.get("ap_current", summary.get("ap_current", 0)))
	summary["reason"] = str(wallet_summary.get("reason", summary.get("reason", "")))
	summary["changed"] = bool(wallet_summary.get("changed", summary.get("changed", false)))
	return summary


func _build_wallet_summary(action_id: String, delta_gold: int, changed: bool, reason: String) -> Dictionary:
	return {
		"action": action_id,
		"handled": ["purchase", "sale"].has(action_id),
		"changed": changed,
		"reason": reason,
		"delta_gold": delta_gold,
		"ap_spent": 0,
	}


func _build_summary(
	action_id: String,
	item_name: String,
	display_name: String,
	price: int,
	sell_price: int,
	changed: bool,
	reason: String
) -> Dictionary:
	return {
		"action": action_id,
		"item_name": item_name,
		"display_name": display_name,
		"price": price,
		"sell_price": sell_price,
		"handled": ["purchase", "sale"].has(action_id),
		"changed": changed,
		"reason": reason,
		"delta_gold": 0,
		"ap_spent": 0,
	}
