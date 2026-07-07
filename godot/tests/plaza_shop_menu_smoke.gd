extends SceneTree

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PlazaScenePacked := preload("res://scenes/plaza.tscn")
const PlazaShopPricing := preload("res://scripts/plaza/plaza_shop_pricing.gd")
const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends Node2D

	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var accessory_slot_count := 2


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeAudio:
	extends RefCounted

	var trade_calls := 0
	var item_get_calls := 0
	var lucky_coin_spawn_calls := 0

	func play_trade() -> void:
		trade_calls += 1

	func play_item_get() -> void:
		item_get_calls += 1

	func play_lucky_coin_spawn() -> void:
		lucky_coin_spawn_calls += 1


func _init() -> void:
	_run()


func _run() -> void:
	_verify_passive_trade_ui_buy_sell()
	_verify_passive_trade_reorder()
	_verify_topview_shop_uses_strewn_trade_entry()
	_verify_shop_tab_opens_character_info_overlay()
	_verify_retired_shop_menu_action_is_noop()

	if _failures.is_empty():
		print("plaza_shop_menu_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_passive_trade_ui_buy_sell() -> void:
	var save_path := _smoke_save_path("passive_trade")
	_cleanup(save_path)
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.apply_stage_clear_progress(1, 8000, true)
	var owner := FakeOwner.new()
	root.add_child(owner)
	var mythic_item_runtime := MythicItemRuntime.new()
	var mythic_item_catalog := MythicItemCatalog.new()
	var fake_audio := FakeAudio.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": mythic_item_runtime,
		"mythic_item_catalog": mythic_item_catalog,
		"game_audio": fake_audio,
	})

	var viewport := _build_viewport()
	var scene := _build_scene(viewport, save_path, owner, registry)
	if scene == null:
		viewport.queue_free()
		owner.queue_free()
		_cleanup(save_path)
		return
	_open_building(scene, "shop")
	var status: Dictionary = scene.get_status()
	var initial_stock_count := int(status.get("shop_inventory_count", 0))
	var initial_gold := int(status.get("plaza_gold", 0))
	_expect(initial_stock_count >= 5, "passive shop should roll stock before trade")
	var stock_index := _find_legacy_shop_stock_index(scene)
	_expect(stock_index >= 0, "passive shop should expose at least one passive/legendary stock entry")

	scene.click_interior_object_for_test("shop_strewn_coin_pile")
	scene.advance_interior_view_for_test(0.75)
	status = scene.trade_interior_item_for_test("shop", stock_index)
	_expect(owner.passive_item_inventory.size() == 1, "passive shop purchase should add one passive inventory item")
	_expect(int(status.get("shop_inventory_count", 0)) == initial_stock_count - 1, "passive shop purchase should remove the bought stock entry")
	_expect(int(status.get("plaza_gold", 0)) < initial_gold, "passive shop purchase should debit plaza gold")
	_expect(int(status.get("ap_current", 0)) == 3, "first passive shop trade should spend one AP")
	_expect(bool(status.get("active_menu_visit_ap_consumed", false)), "passive shop trade should mark the visit AP gate")
	_expect(fake_audio.trade_calls == 1, "passive shop purchase should play the legacy trade sound")
	_expect(fake_audio.item_get_calls == 0, "passive shop purchase should not use item-get audio")
	_expect(fake_audio.lucky_coin_spawn_calls == 0, "passive shop purchase should not use coin-spawn audio")

	var after_purchase_gold := int(status.get("plaza_gold", 0))
	var bought_item: Dictionary = mythic_item_runtime.get_inventory_item(0)
	var expected_sell_price: int = PlazaShopPricing.get_sell_price(bought_item)
	var displayed_sell_price: int = scene.get_interior_trade_item_price_for_test("player", 0)
	_expect(expected_sell_price > 0, "passive shop purchase should produce a positive sell price")
	_expect(displayed_sell_price == expected_sell_price, "player trade panel should display the real passive sell price")
	status = scene.trade_interior_item_for_test("player", 0)
	_expect(owner.passive_item_inventory.is_empty(), "passive shop sale should remove the sold passive inventory item")
	_expect(int(status.get("shop_inventory_count", 0)) == initial_stock_count, "passive shop sale should relist the sold item")
	_expect(int(status.get("plaza_gold", 0)) == after_purchase_gold + expected_sell_price, "passive shop sale should credit the displayed sell price")
	_expect(int(status.get("ap_current", 0)) == 3, "same passive shop visit should not spend AP twice")
	_expect(fake_audio.trade_calls == 2, "passive shop sale should play the same legacy trade sound")
	_expect(fake_audio.item_get_calls == 0, "passive shop sale should not use item-get audio")
	_expect(fake_audio.lucky_coin_spawn_calls == 0, "passive shop sale should not use coin-spawn audio")

	viewport.queue_free()
	owner.queue_free()
	_cleanup(save_path)


func _verify_passive_trade_reorder() -> void:
	var save_path := _smoke_save_path("passive_reorder")
	_cleanup(save_path)
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.apply_stage_clear_progress(1, 8000, true)
	var owner := FakeOwner.new()
	root.add_child(owner)
	var mythic_item_runtime := MythicItemRuntime.new()
	var mythic_item_catalog := MythicItemCatalog.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": mythic_item_runtime,
		"mythic_item_catalog": mythic_item_catalog,
	})

	var viewport := _build_viewport()
	var scene := _build_scene(viewport, save_path, owner, registry)
	if scene == null:
		viewport.queue_free()
		owner.queue_free()
		_cleanup(save_path)
		return
	_open_building(scene, "shop")
	var status: Dictionary = scene.get_status()
	var initial_stock_count := int(status.get("shop_inventory_count", 0))
	_expect(initial_stock_count >= 5, "passive shop reorder should start with rolled stock")
	var first_stock_index := _find_legacy_shop_stock_index(scene)
	_expect(first_stock_index >= 0, "passive reorder should expose a first passive/legendary stock entry")

	scene.trade_interior_item_for_test("shop", first_stock_index)
	var second_stock_index := _find_legacy_shop_stock_index(scene)
	_expect(second_stock_index >= 0, "passive reorder should expose a second passive/legendary stock entry")
	if second_stock_index >= 0:
		scene.trade_interior_item_for_test("shop", second_stock_index)
	_expect(owner.passive_item_inventory.size() == 2, "passive reorder setup should buy two inventory items")
	if owner.passive_item_inventory.size() >= 2:
		var first_id := int((owner.passive_item_inventory[0] as Dictionary).get("_inventory_id", -1))
		var second_id := int((owner.passive_item_inventory[1] as Dictionary).get("_inventory_id", -1))
		status = scene.reorder_interior_trade_item_for_test("player", 0, 1)
		_expect(int(status.get("shop_inventory_count", 0)) == initial_stock_count - 2, "passive reorder should not change shop stock count")
		_expect(int((owner.passive_item_inventory[0] as Dictionary).get("_inventory_id", -2)) == second_id, "passive reorder should move the second item into the first slot")
		_expect(int((owner.passive_item_inventory[1] as Dictionary).get("_inventory_id", -2)) == first_id, "passive reorder should move the first item into the second slot")

	viewport.queue_free()
	owner.queue_free()
	_cleanup(save_path)


func _verify_topview_shop_uses_strewn_trade_entry() -> void:
	var save_path := _smoke_save_path("strewn_entry")
	_cleanup(save_path)
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.apply_stage_clear_progress(1, 8000, true)
	var owner := FakeOwner.new()
	root.add_child(owner)
	var mythic_item_runtime := MythicItemRuntime.new()
	var mythic_item_catalog := MythicItemCatalog.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": mythic_item_runtime,
		"mythic_item_catalog": mythic_item_catalog,
	})

	var viewport := _build_viewport()
	var scene := _build_scene(viewport, save_path, owner, registry)
	if scene == null:
		viewport.queue_free()
		owner.queue_free()
		_cleanup(save_path)
		return
	_open_building(scene, "shop")
	var status: Dictionary = scene.get_status()
	var initial_stock_count := int(status.get("shop_inventory_count", 0))
	_expect(initial_stock_count >= 5, "top-view shop should start with rolled shop stock")
	var interior_status: Dictionary = status.get("interior_view_status", {})
	_expect(int(interior_status.get("object_count", 0)) == 1, "top-view shop should expose only the coin pile trade entry")

	status = scene.click_interior_object_for_test("shop_action_0")
	_expect(not bool(status.get("interior_shop_click_animation_active", false)), "top-view shop should not expose separate featured-item pedestal objects")
	status = scene.click_interior_object_for_test("shop_strewn_money_bundle")
	_expect(not bool(status.get("interior_shop_click_animation_active", false)), "top-view shop should not expose extra strewn trade props")
	status = scene.click_interior_object_for_test("shop_strewn_coin_pile")
	_expect(bool(status.get("interior_shop_click_animation_active", false)), "coin pile should animate as the shop trade entry")
	status = scene.advance_interior_view_for_test(0.75)
	_expect(bool(status.get("trade_ui_open", false)), "coin pile animation should open the full trade UI")
	status = scene.get_status()
	_expect(owner.passive_item_inventory.is_empty(), "opening the trade UI should not quick-buy a passive inventory item")
	_expect(int(status.get("shop_inventory_count", 0)) == initial_stock_count, "opening the trade UI should leave shop stock unchanged")
	_expect(int(status.get("ap_current", 0)) == 4, "opening the trade UI should not spend AP")

	viewport.queue_free()
	owner.queue_free()
	_cleanup(save_path)


func _verify_shop_tab_opens_character_info_overlay() -> void:
	var save_path := _smoke_save_path("character_info_tab")
	_cleanup(save_path)
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.apply_stage_clear_progress(1, 8000, true)
	var owner := FakeOwner.new()
	root.add_child(owner)
	var mythic_item_runtime := MythicItemRuntime.new()
	var mythic_item_catalog := MythicItemCatalog.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": mythic_item_runtime,
		"mythic_item_catalog": mythic_item_catalog,
	})

	var viewport := _build_viewport()
	var scene := _build_scene(viewport, save_path, owner, registry)
	if scene == null:
		viewport.queue_free()
		owner.queue_free()
		_cleanup(save_path)
		return
	_open_building(scene, "shop")
	var status: Dictionary = scene.get_status()
	_expect(bool(status.get("menu_open", false)), "shop should be open before Tab opens character info")
	_expect(bool(status.get("interior_view_active", false)), "shop interior should be active before Tab opens character info")

	var tab_event := InputEventKey.new()
	tab_event.pressed = true
	tab_event.keycode = KEY_TAB
	tab_event.physical_keycode = KEY_TAB
	_expect(scene.handle_plaza_input(tab_event), "shop interior Tab should be handled")
	status = scene.get_status()
	_expect(bool(status.get("character_info_overlay_active", false)), "shop interior Tab should open character info overlay")
	_expect(bool(status.get("character_info_overlay_visible", false)), "shop interior character info overlay should be visible")

	_expect(scene.handle_plaza_input(tab_event), "active character info Tab should be handled")
	status = scene.get_status()
	_expect(not bool(status.get("character_info_overlay_active", true)), "second Tab should close the character info overlay")

	viewport.queue_free()
	owner.queue_free()
	_cleanup(save_path)


func _verify_retired_shop_menu_action_is_noop() -> void:
	var save_path := _smoke_save_path("retired_action")
	_cleanup(save_path)
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.apply_stage_clear_progress(1, 90, true)
	var owner := FakeOwner.new()
	root.add_child(owner)
	var mythic_item_runtime := MythicItemRuntime.new()
	var mythic_item_catalog := MythicItemCatalog.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": mythic_item_runtime,
		"mythic_item_catalog": mythic_item_catalog,
	})

	var viewport := _build_viewport()
	var scene := _build_scene(viewport, save_path, owner, registry)
	if scene == null:
		viewport.queue_free()
		owner.queue_free()
		_cleanup(save_path)
		return
	_open_building(scene, "shop")
	var status: Dictionary = scene.get_status()
	var actions: Array = status.get("active_menu_actions", [])
	_expect(actions.is_empty(), "top-view shop should not expose retired active-item action rows")
	_expect(not scene.trigger_menu_action_for_test(0), "retired shop menu action should be a no-op")
	status = scene.get_status()
	_expect(mythic_item_runtime.inventory_items.is_empty(), "retired shop action should not grant a passive/legendary item")
	_expect(int(status.get("plaza_gold", 0)) == 90, "retired shop action should leave gold unchanged")
	_expect(int(status.get("ap_current", 0)) == 4, "retired shop action should not spend AP")
	_expect(not bool(status.get("active_menu_visit_ap_consumed", false)), "retired shop action should not mark the shop visit AP flag")

	viewport.queue_free()
	owner.queue_free()
	_cleanup(save_path)


func _build_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 750)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func _build_scene(viewport: SubViewport, save_path: String, owner: Object, registry: Object) -> Control:
	var scene := PlazaScenePacked.instantiate() as Control
	_expect(scene != null, "plaza scene should instantiate for shop menu smoke")
	if scene == null:
		return null
	viewport.add_child(scene)
	scene.configure({
		"current_stage": 1,
		"plaza_save_path": save_path,
		"full_layout_for_test": true,
		"runtime_owner": owner,
		"runtime_registry": registry,
	}, Callable(), true)
	scene.update_plaza(1.0 / 60.0)
	return scene


func _open_building(scene: Control, building_type: String) -> void:
	var building: Dictionary = _find_building(scene.get_building_specs_for_test(), building_type)
	_expect(not building.is_empty(), "plaza should include a %s building" % building_type)
	if building.is_empty():
		return
	var interaction_rect: Rect2 = building.get("interaction_rect", Rect2())
	var ground_y := float(scene.get_status().get("ground_y", 0.0))
	scene.set_player_pos_for_test(Vector2(interaction_rect.get_center().x, ground_y))
	_expect(scene.trigger_interaction_for_test(), "%s interaction should open the menu" % building_type)


func _find_building(specs: Array[Dictionary], building_type: String) -> Dictionary:
	for spec in specs:
		if str(spec.get("type", "")) == building_type:
			return spec
	return {}


func _find_legacy_shop_stock_index(scene: Control) -> int:
	var stock: Array = _get_array(scene.get("_shop_inventory"))
	for index in range(stock.size()):
		var item_data := _get_dict(stock[index])
		var item_name := str(item_data.get("name", ""))
		if item_name != "" and not PlazaShopPricing.ACTIVE_BASE_PRICES.has(item_name):
			return index
	return -1


func _cleanup(path: String) -> void:
	var backup_path := path.trim_suffix(".cfg") + ".last_good.cfg"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))


func _smoke_save_path(slug: String) -> String:
	return "res://.tmp/plaza_shop_menu_smoke_%s_%d_%d.cfg" % [
		slug,
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
