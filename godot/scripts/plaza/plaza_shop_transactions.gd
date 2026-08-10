extends RefCounted

const PlazaShopPricing := preload("res://scripts/plaza/plaza_shop_pricing.gd")
const PlazaShopTradeSummary := preload("res://scripts/plaza/plaza_shop_trade_summary.gd")
const PlazaTradeItemPresentation := preload("res://scripts/plaza/plaza_trade_item_presentation.gd")


func perform_trade(
	action: Dictionary,
	shop_inventory_state: Object,
	save_store: Object,
	owner: Object,
	registry: Object,
	consume_ap: bool
) -> Dictionary:
	var panel := str(action.get("panel", ""))
	var index := int(action.get("index", -1))
	match panel:
		"shop":
			var stock_id := str(action.get("stock_id", ""))
			if stock_id != "":
				index = _find_shop_stock_index(shop_inventory_state, stock_id)
			return _buy_shop_stock_item(index, shop_inventory_state, save_store, owner, registry, consume_ap)
		"player":
			return _sell_player_passive_item(index, shop_inventory_state, save_store, owner, registry, consume_ap)
	return PlazaShopTradeSummary.build_trade("", {}, 0, 0, false, "unknown_shop_action")


func reorder_trade(
	action: Dictionary,
	shop_inventory_state: Object,
	owner: Object,
	registry: Object
) -> bool:
	var panel := str(action.get("panel", ""))
	var from_index := int(action.get("from_index", -1))
	var to_index := int(action.get("to_index", -1))
	if panel == "shop":
		return (
			shop_inventory_state != null
			and shop_inventory_state.has_method("reorder")
			and bool(shop_inventory_state.reorder(from_index, to_index))
		)
	if panel == "player":
		return _reorder_player_passive_inventory_item(from_index, to_index, owner, registry)
	return false


func _buy_shop_stock_item(
	index: int,
	shop_inventory_state: Object,
	save_store: Object,
	owner: Object,
	registry: Object,
	consume_ap: bool
) -> Dictionary:
	if not _is_valid_shop_index(shop_inventory_state, index):
		return PlazaShopTradeSummary.build_trade("purchase", {}, 0, 0, false, "unknown_shop_item")
	var item_data: Dictionary = shop_inventory_state.get_item(index)
	var item_name := PlazaTradeItemPresentation.get_item_identity(item_data)
	var price := maxi(1, int(item_data.get("shop_price", PlazaShopPricing.get_buy_price(item_data))))
	if item_name == "":
		return PlazaShopTradeSummary.build_trade("purchase", item_data, price, 0, false, "unknown_shop_item")
	if not _has_plaza_gold(save_store, price):
		return PlazaShopTradeSummary.build_trade("purchase", item_data, price, 0, false, "not_enough_gold")
	if _is_ap_blocked(save_store, consume_ap):
		return PlazaShopTradeSummary.build_trade("purchase", item_data, price, 0, false, "no_ap")
	if owner == null:
		return PlazaShopTradeSummary.build_trade("purchase", item_data, price, 0, false, "missing_owner")
	if _is_active_shop_item(item_data):
		return _buy_active_shop_stock_item(index, item_data, item_name, price, shop_inventory_state, save_store, owner, registry, consume_ap)
	var mythic_item_runtime := _get_runtime_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("acquire_item"):
		return PlazaShopTradeSummary.build_trade("purchase", item_data, price, 0, false, "missing_item_runtime")
	var grant_index := int(mythic_item_runtime.acquire_item(item_name, owner, registry, {}, false, false, item_data))
	if grant_index < 0:
		return PlazaShopTradeSummary.build_trade("purchase", item_data, price, 0, false, "inventory_full")
	var payment := _perform_shop_wallet_transaction(save_store, "purchase", price, consume_ap)
	if not bool(payment.get("changed", false)):
		if mythic_item_runtime.has_method("discard_inventory_item"):
			mythic_item_runtime.discard_inventory_item(grant_index, owner, registry)
		return PlazaShopTradeSummary.merge_wallet(
			PlazaShopTradeSummary.build_trade("purchase", item_data, price, 0, false, str(payment.get("reason", "payment_failed"))),
			payment
		)
	shop_inventory_state.remove_at(index)
	return PlazaShopTradeSummary.merge_wallet(
		PlazaShopTradeSummary.build_trade("purchase", item_data, price, 0, true, "ok"),
		payment
	)


func _buy_active_shop_stock_item(
	index: int,
	item_data: Dictionary,
	item_name: String,
	price: int,
	shop_inventory_state: Object,
	save_store: Object,
	owner: Object,
	registry: Object,
	consume_ap: bool
) -> Dictionary:
	var active_item_runtime := _get_runtime_instance(registry, "active_item_runtime")
	if active_item_runtime == null or not active_item_runtime.has_method("grant_item_to_slot"):
		return PlazaShopTradeSummary.build_trade("purchase", item_data, price, 0, false, "missing_item_runtime")
	if not bool(active_item_runtime.grant_item_to_slot(item_name, owner, registry, false)):
		return PlazaShopTradeSummary.build_trade("purchase", item_data, price, 0, false, "active_slots_full")
	var payment := _perform_shop_wallet_transaction(save_store, "purchase", price, consume_ap)
	if not bool(payment.get("changed", false)):
		if active_item_runtime.has_method("debug_remove_item_from_slot"):
			active_item_runtime.debug_remove_item_from_slot(item_name, owner, registry)
		return PlazaShopTradeSummary.merge_wallet(
			PlazaShopTradeSummary.build_trade("purchase", item_data, price, 0, false, str(payment.get("reason", "payment_failed"))),
			payment
		)
	shop_inventory_state.remove_at(index)
	return PlazaShopTradeSummary.merge_wallet(
		PlazaShopTradeSummary.build_trade("purchase", item_data, price, 0, true, "ok"),
		payment
	)


func _sell_player_passive_item(
	index: int,
	shop_inventory_state: Object,
	save_store: Object,
	owner: Object,
	registry: Object,
	consume_ap: bool
) -> Dictionary:
	if _is_ap_blocked(save_store, consume_ap):
		return PlazaShopTradeSummary.build_trade("sale", {}, 0, 0, false, "no_ap")
	var mythic_item_runtime := _get_runtime_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("discard_inventory_item"):
		return PlazaShopTradeSummary.build_trade("sale", {}, 0, 0, false, "missing_item_runtime")
	if owner == null:
		return PlazaShopTradeSummary.build_trade("sale", {}, 0, 0, false, "missing_owner")
	var item_data := _get_passive_inventory_item(index, registry)
	if item_data.is_empty():
		return PlazaShopTradeSummary.build_trade("sale", {}, 0, 0, false, "no_passive_item")
	var sell_price := PlazaShopPricing.get_sell_price(item_data)
	if not bool(mythic_item_runtime.discard_inventory_item(index, owner, registry)):
		return PlazaShopTradeSummary.build_trade("sale", item_data, 0, sell_price, false, "no_passive_item")
	var payment := _perform_shop_wallet_transaction(save_store, "sale", sell_price, consume_ap)
	if bool(payment.get("changed", false)) and shop_inventory_state != null and shop_inventory_state.has_method("relist"):
		shop_inventory_state.relist(item_data)
	return PlazaShopTradeSummary.merge_wallet(
		PlazaShopTradeSummary.build_trade("sale", item_data, 0, sell_price, bool(payment.get("changed", false)), str(payment.get("reason", "ok"))),
		payment
	)


func _reorder_player_passive_inventory_item(from_index: int, to_index: int, owner: Object, registry: Object) -> bool:
	var mythic_item_runtime := _get_runtime_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime == null:
		return false
	var items_value: Variant = mythic_item_runtime.get("inventory_items")
	if not (items_value is Array):
		return false
	var items: Array = items_value
	if not _move_array_item(items, from_index, to_index):
		return false
	if mythic_item_runtime.has_method("_sync_owner"):
		mythic_item_runtime.call("_sync_owner", owner, registry)
	return true


func _get_passive_inventory_item(index: int, registry: Object) -> Dictionary:
	var mythic_item_runtime := _get_runtime_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_inventory_item"):
		var value: Variant = mythic_item_runtime.get_inventory_item(index)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	if mythic_item_runtime == null:
		return {}
	var items_value: Variant = mythic_item_runtime.get("inventory_items")
	if not (items_value is Array) and mythic_item_runtime.has_method("get_snapshot"):
		var snapshot_value: Variant = mythic_item_runtime.get_snapshot()
		if snapshot_value is Dictionary:
			items_value = (snapshot_value as Dictionary).get("inventory_items", [])
	var catalog := _get_runtime_instance(registry, "mythic_item_catalog")
	var snapshot := PlazaTradeItemPresentation.project_inventory(items_value, catalog, true)
	if index >= 0 and index < snapshot.size():
		var item_value: Variant = snapshot[index]
		if item_value is Dictionary:
			return (item_value as Dictionary).duplicate(true)
	return {}


func _find_shop_stock_index(shop_inventory_state: Object, stock_id: String) -> int:
	if shop_inventory_state == null or not shop_inventory_state.has_method("find_stock_index"):
		return -1
	return int(shop_inventory_state.find_stock_index(stock_id))


func _is_valid_shop_index(shop_inventory_state: Object, index: int) -> bool:
	return (
		shop_inventory_state != null
		and shop_inventory_state.has_method("size")
		and shop_inventory_state.has_method("get_item")
		and shop_inventory_state.has_method("remove_at")
		and index >= 0
		and index < int(shop_inventory_state.size())
	)


func _perform_shop_wallet_transaction(save_store: Object, action_id: String, amount: int, consume_ap: bool) -> Dictionary:
	if save_store == null or not save_store.has_method("perform_shop_wallet_transaction"):
		return PlazaShopTradeSummary.build_wallet_fallback(action_id, false, "missing_plaza_save_store")
	var result: Variant = save_store.perform_shop_wallet_transaction(action_id, amount, consume_ap)
	if result is Dictionary:
		return (result as Dictionary).duplicate(true)
	return PlazaShopTradeSummary.build_wallet_fallback(action_id, false, "invalid_wallet_result")


func _has_plaza_gold(save_store: Object, amount: int) -> bool:
	return save_store != null and save_store.has_method("get_plaza_gold") and int(save_store.get_plaza_gold()) >= amount


func _is_ap_blocked(save_store: Object, consume_ap: bool) -> bool:
	return consume_ap and (save_store == null or not save_store.has_method("get_ap_current") or int(save_store.get_ap_current()) <= 0)


func _get_runtime_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _is_active_shop_item(item_data: Dictionary) -> bool:
	return str(item_data.get("type", "")).to_lower() == "active"


func _move_array_item(items: Array, from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= items.size() or items.is_empty():
		return false
	var insert_index := clampi(to_index, 0, items.size() - 1)
	if from_index == insert_index:
		return false
	var item: Variant = items[from_index]
	items.remove_at(from_index)
	insert_index = clampi(insert_index, 0, items.size())
	items.insert(insert_index, item)
	return true
