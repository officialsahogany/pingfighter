extends SceneTree

const PlazaShopInventoryState := preload("res://scripts/plaza/plaza_shop_inventory_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	_verify_scene_single_owner_contract()
	var state := PlazaShopInventoryState.new()
	var source := [
		{"name": "speedboots", "shop_stock_id": "stock_a", "nested": {"roll": 1}},
		{"name": "battery", "shop_stock_id": "stock_b"},
		{"name": "master", "shop_stock_id": "stock_c"},
	]
	state.replace(source)
	source[0]["nested"]["roll"] = 99
	_expect(state.size() == 3, "replace should own a copied stock list")
	_expect(int(state.get_item(0).get("nested", {}).get("roll", 0)) == 1, "replace should deep-copy stock entries")

	var snapshot := state.snapshot()
	snapshot[0]["name"] = "mutated"
	_expect(str(state.get_item(0).get("name", "")) == "speedboots", "snapshot should not expose mutable owner state")
	_expect(state.find_stock_index("stock_b") == 1, "stable stock id lookup")
	_expect(state.find_stock_index("") == -1 and state.find_stock_index("missing") == -1, "invalid stock id lookup")

	_expect(state.reorder(0, 2), "valid reorder")
	_expect(str(state.get_item(2).get("shop_stock_id", "")) == "stock_a", "reorder should move the requested stock entry")
	_expect(not state.reorder(2, 2), "same-index reorder should be ignored")
	_expect(not state.remove_at(-1), "invalid removal should be ignored")
	_expect(state.remove_at(1) and state.size() == 2, "valid removal")

	_expect(state.relist({"name": "speedboots", "quality_tier": "low"}), "named sold item should relist")
	var relisted := state.get_item(state.size() - 1)
	_expect(str(relisted.get("shop_stock_id", "")).begins_with("shop_resale_"), "relisted item should receive a stable resale id")
	_expect(int(relisted.get("shop_price", 0)) > 0 and int(relisted.get("shop_sell_price", 0)) > 0, "relisted item should receive buy and sell prices")
	_expect(not bool(relisted.get("shop_featured", true)), "relisted item should not retain featured pricing")
	_expect(not state.relist({"quality_tier": "low"}), "identity-less item should not relist")

	state.replace("invalid")
	_expect(state.size() == 0, "invalid replacement should clear stock")
	state.replace([{"name": "battery"}])
	state.clear()
	_expect(state.size() == 0, "clear should empty stock")

	if _failures.is_empty():
		print("plaza_shop_inventory_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_scene_single_owner_contract() -> void:
	var scene_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_scene.gd")
	_expect(scene_source.find("var _shop_inventory: Array") == -1, "scene should not retain a mutable stock mirror")
	_expect(scene_source.find("var _shop_inventory_state: PlazaShopInventoryState") >= 0, "scene should use the typed stock owner")
	_expect(scene_source.find("_shop_inventory.remove_at") == -1, "scene should delegate stock removal")
	_expect(scene_source.find("_shop_inventory.append") == -1, "scene should delegate sold-item relisting")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
