extends SceneTree

const PlazaShopInventoryState := preload("res://scripts/plaza/plaza_shop_inventory_state.gd")
const PlazaShopPricing := preload("res://scripts/plaza/plaza_shop_pricing.gd")
const PlazaShopTransactions := preload("res://scripts/plaza/plaza_shop_transactions.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeSaveStore:
	extends RefCounted

	var plaza_gold := 500
	var ap_current := 3
	var fail_next := false
	var calls: Array[Dictionary] = []

	func get_plaza_gold() -> int:
		return plaza_gold

	func get_ap_current() -> int:
		return ap_current

	func perform_shop_wallet_transaction(action_id: String, amount: int, consume_ap: bool) -> Dictionary:
		calls.append({"action": action_id, "amount": amount, "consume_ap": consume_ap})
		if fail_next:
			fail_next = false
			return _summary(action_id, 0, 0, false, "payment_failed")
		var delta_gold := amount if action_id == "sale" else -amount
		var ap_spent := 1 if consume_ap else 0
		plaza_gold += delta_gold
		ap_current -= ap_spent
		return _summary(action_id, delta_gold, ap_spent, true, "ok")

	func _summary(action_id: String, delta_gold: int, ap_spent: int, changed: bool, reason: String) -> Dictionary:
		return {
			"action": action_id,
			"handled": true,
			"changed": changed,
			"reason": reason,
			"delta_gold": delta_gold,
			"ap_spent": ap_spent,
			"plaza_gold": plaza_gold,
			"ap_current": ap_current,
		}


class FakePassiveRuntime:
	extends RefCounted

	var inventory_items: Array = []
	var fail_acquire := false
	var discard_calls := 0
	var sync_calls := 0

	func acquire_item(
		item_name: String,
		_owner: Object,
		_registry: Object,
		_roll_overrides: Dictionary,
		_auto_equip: bool,
		_play_pickup_sound: bool,
		acquired_item_data: Dictionary
	) -> int:
		if fail_acquire:
			return -1
		var item := acquired_item_data.duplicate(true)
		item["name"] = item_name
		inventory_items.append(item)
		return inventory_items.size() - 1

	func discard_inventory_item(index: int, _owner: Object, _registry: Object) -> bool:
		if index < 0 or index >= inventory_items.size():
			return false
		discard_calls += 1
		inventory_items.remove_at(index)
		return true

	func get_inventory_item(index: int) -> Dictionary:
		if index < 0 or index >= inventory_items.size():
			return {}
		return (inventory_items[index] as Dictionary).duplicate(true)

	func _sync_owner(_owner: Object, _registry: Object) -> void:
		sync_calls += 1


class FakeActiveRuntime:
	extends RefCounted

	var slots: Array[String] = []
	var fail_grant := false
	var rollback_calls := 0

	func grant_item_to_slot(item_name: String, _owner: Object, _registry: Object, _allow_overflow: bool) -> bool:
		if fail_grant:
			return false
		slots.append(item_name)
		return true

	func debug_remove_item_from_slot(item_name: String, _owner: Object, _registry: Object) -> bool:
		var index := slots.find(item_name)
		if index < 0:
			return false
		rollback_calls += 1
		slots.remove_at(index)
		return true


func _init() -> void:
	_verify_passive_purchase_and_payment_rollback()
	_verify_active_purchase_and_payment_rollback()
	_verify_sale_relist_and_visit_ap_policy()
	_verify_shop_and_player_reorder()
	_verify_scene_delegates_transaction_policy()
	if _failures.is_empty():
		print("plaza_shop_transactions_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_passive_purchase_and_payment_rollback() -> void:
	var transactions := PlazaShopTransactions.new()
	var stock := PlazaShopInventoryState.new()
	stock.replace([_passive_stock("stock_passive")])
	var store := FakeSaveStore.new()
	var passive_runtime := FakePassiveRuntime.new()
	var registry := FakeRegistry.new({"mythic_item_runtime": passive_runtime})
	var owner := FakeOwner.new()

	var summary: Dictionary = transactions.perform_trade(
		{"panel": "shop", "index": 99, "stock_id": "stock_passive"},
		stock,
		store,
		owner,
		registry,
		true
	)
	_expect(bool(summary.get("changed", false)), "passive purchase should succeed through stock-id lookup")
	_expect(passive_runtime.inventory_items.size() == 1, "passive purchase should grant before commit")
	_expect(stock.size() == 0, "successful passive purchase should remove stock")
	_expect(store.plaza_gold == 380 and store.ap_current == 2, "passive purchase should debit gold and one visit AP")

	stock.replace([_passive_stock("stock_rollback")])
	passive_runtime.inventory_items.clear()
	store.fail_next = true
	summary = transactions.perform_trade({"panel": "shop", "index": 0}, stock, store, owner, registry, false)
	_expect(not bool(summary.get("changed", true)), "failed passive payment should stay unchanged")
	_expect(str(summary.get("reason", "")) == "payment_failed", "failed passive payment should preserve wallet reason")
	_expect(passive_runtime.inventory_items.is_empty(), "failed passive payment should roll back the granted item")
	_expect(passive_runtime.discard_calls == 1, "failed passive payment should invoke grant rollback once")
	_expect(stock.size() == 1, "failed passive payment should retain shop stock")


func _verify_active_purchase_and_payment_rollback() -> void:
	var transactions := PlazaShopTransactions.new()
	var stock := PlazaShopInventoryState.new()
	stock.replace([_active_stock("active_success")])
	var store := FakeSaveStore.new()
	var active_runtime := FakeActiveRuntime.new()
	var registry := FakeRegistry.new({"active_item_runtime": active_runtime})
	var owner := FakeOwner.new()

	var summary: Dictionary = transactions.perform_trade({"panel": "shop", "index": 0}, stock, store, owner, registry, true)
	_expect(bool(summary.get("changed", false)), "active purchase should succeed")
	_expect(active_runtime.slots == ["gauge_charge"], "active purchase should grant into an active slot")
	_expect(stock.size() == 0, "successful active purchase should remove stock")

	stock.replace([_active_stock("active_rollback")])
	active_runtime.slots.clear()
	store.fail_next = true
	summary = transactions.perform_trade({"panel": "shop", "index": 0}, stock, store, owner, registry, false)
	_expect(not bool(summary.get("changed", true)), "failed active payment should stay unchanged")
	_expect(active_runtime.slots.is_empty(), "failed active payment should remove the granted slot item")
	_expect(active_runtime.rollback_calls == 1, "failed active payment should invoke active-slot rollback once")
	_expect(stock.size() == 1, "failed active payment should retain shop stock")


func _verify_sale_relist_and_visit_ap_policy() -> void:
	var transactions := PlazaShopTransactions.new()
	var stock := PlazaShopInventoryState.new()
	var store := FakeSaveStore.new()
	store.ap_current = 0
	var passive_runtime := FakePassiveRuntime.new()
	var sold_item := _passive_stock("owned_item")
	passive_runtime.inventory_items = [sold_item]
	var registry := FakeRegistry.new({"mythic_item_runtime": passive_runtime})
	var owner := FakeOwner.new()
	var expected_sell_price := PlazaShopPricing.get_sell_price(sold_item)

	var summary: Dictionary = transactions.perform_trade({"panel": "player", "index": 0}, stock, store, owner, registry, false)
	_expect(bool(summary.get("changed", false)), "sale should succeed after the visit AP was already consumed")
	_expect(passive_runtime.inventory_items.is_empty(), "sale should remove the passive inventory item")
	_expect(stock.size() == 1, "successful sale should relist the sold item")
	_expect(store.plaza_gold == 500 + expected_sell_price, "sale should credit the computed sell price")
	_expect(store.ap_current == 0, "same-visit sale should not spend another AP")
	_expect(str(stock.get_item(0).get("shop_stock_id", "")).begins_with("shop_resale_"), "relisted sale should receive a resale stock id")

	passive_runtime.inventory_items = [sold_item]
	summary = transactions.perform_trade({"panel": "player", "index": 0}, stock, store, owner, registry, true)
	_expect(str(summary.get("reason", "")) == "no_ap", "fresh-visit sale should fail closed without AP")
	_expect(passive_runtime.inventory_items.size() == 1, "AP rejection should not remove the player item")


func _verify_shop_and_player_reorder() -> void:
	var transactions := PlazaShopTransactions.new()
	var stock := PlazaShopInventoryState.new()
	stock.replace([_passive_stock("first"), _passive_stock("second")])
	var passive_runtime := FakePassiveRuntime.new()
	passive_runtime.inventory_items = [{"name": "speedboots"}, {"name": "battery"}]
	var registry := FakeRegistry.new({"mythic_item_runtime": passive_runtime})
	var owner := FakeOwner.new()

	_expect(transactions.reorder_trade({"panel": "shop", "from_index": 0, "to_index": 1}, stock, owner, registry), "shop stock reorder should succeed")
	_expect(str(stock.get_item(0).get("shop_stock_id", "")) == "second", "shop stock reorder should mutate the stock owner")
	_expect(transactions.reorder_trade({"panel": "player", "from_index": 0, "to_index": 1}, stock, owner, registry), "player inventory reorder should succeed")
	_expect(str((passive_runtime.inventory_items[0] as Dictionary).get("name", "")) == "battery", "player reorder should move the live runtime item")
	_expect(passive_runtime.sync_calls == 1, "player reorder should sync the runtime owner once")


func _verify_scene_delegates_transaction_policy() -> void:
	var scene_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_scene.gd")
	_expect(scene_source.contains("var _plaza_shop_transactions: Object = PlazaShopTransactions.new()"), "scene should own one shop transaction service")
	_expect(scene_source.contains("_plaza_shop_transactions.perform_trade("), "scene should delegate purchase and sale execution")
	_expect(scene_source.contains("_plaza_shop_transactions.reorder_trade("), "scene should delegate shop reorder execution")
	_expect(not scene_source.contains("func _buy_shop_stock_item("), "scene should not retain passive purchase policy")
	_expect(not scene_source.contains("func _buy_active_shop_stock_item("), "scene should not retain active purchase policy")
	_expect(not scene_source.contains("func _sell_player_passive_item("), "scene should not retain sale policy")


func _passive_stock(stock_id: String) -> Dictionary:
	return {
		"name": "speedboots",
		"display_name": "Speed Boots",
		"type": "passive",
		"quality_tier": "low",
		"shop_stock_id": stock_id,
		"shop_price": 120,
	}


func _active_stock(stock_id: String) -> Dictionary:
	return {
		"name": "gauge_charge",
		"display_name": "Herbal Decoction",
		"type": "active",
		"shop_stock_id": stock_id,
		"shop_price": 60,
	}


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
