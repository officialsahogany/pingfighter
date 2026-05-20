extends SceneTree

const BattleScenePlayerControlConfigBuilder := preload("res://scripts/core/battle_scene_player_control_config_builder.gd")
const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var player_pos := Vector2(300.0, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_speed_multiplier := 1.0
	var gold_bar_equipped := false
	var gold_bar_owned := false
	var gold_bar_active := false
	var gold_bar_count := 0
	var gold_bar_sell_price := 0
	var gold_bar_total_sell_price := 0
	var gold_bar_speed_penalty_pct := 0.0
	var gold_bar_speed_multiplier := 1.0
	var speedboots_equipped := false
	var speedboots_speed_bonus_pct := 0.0

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var mythic_item_runtime: Object

	func _init(runtime: Object) -> void:
		mythic_item_runtime = runtime

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return mythic_item_runtime
		return null


class FakeControlContextBuilder:
	func build_player_control_config(_character_type: String) -> Dictionary:
		return {
			"paddle_speed": 10.0,
			"paddle_max_speed": 20.0,
			"paddle_accel": 1.0,
			"paddle_decel": 2.0,
			"paddle_turn_decel": 3.0,
			"paddle_width": 155.0,
		}


func _init() -> void:
	var catalog: Object = MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("gold_bar")
	_expect(not item_data.is_empty(), "Gold Bar should build from catalog")
	_expect(str(item_data.get("display_name", "")) == "금괴", "Gold Bar should keep Korean display name")
	_expect(str(item_data.get("slot", "")) == "accessory", "Gold Bar should use the accessory slot")
	_expect(str(item_data.get("type", "")) == "passive", "Gold Bar should be a passive item")
	_expect_close(float(item_data.get("chance", 0.0)), 0.001, "Gold Bar field chance should match Python")
	_expect(int(item_data.get("sell_price", 0)) == 2000, "Gold Bar should expose its 2000 gold sell price")
	_expect(catalog.get_roll_options("gold_bar").is_empty(), "Gold Bar should not expose random roll options")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "gold_bar"), "Gold Bar should be in the field spawn pool")
	_expect(_array_has_item(catalog.get_debug_items(), "gold_bar"), "Gold Bar should be in the debug item list")
	_expect_icon_asset(item_data)

	var field_runtime: Object = MythicItemRuntime.new()
	var field_owner := FakeOwner.new()
	var field_registry := FakeRegistry.new(field_runtime)
	var active_runtime: Object = ActiveItemRuntime.new()
	var active_slots: Array = []
	_expect(
		active_runtime._store_active_item({"item_data": item_data}, active_slots, field_registry, field_owner),
		"field Gold Bar pickup should route into passive inventory"
	)
	_expect(active_slots.is_empty(), "field Gold Bar pickup should not occupy an active item slot")
	_expect(field_owner.gold_bar_active, "field Gold Bar pickup should activate the carried speed penalty")
	_expect_close(field_runtime.get_player_speed_multiplier(), 0.7, "field Gold Bar pickup should apply the movement penalty")

	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime)
	var index: int = int(runtime.acquire_item("gold_bar", owner, registry, {}, false, false))
	_expect(index >= 0, "Gold Bar should be acquired into passive inventory")
	_expect(not owner.gold_bar_equipped, "non-equipped Gold Bar should not claim an equipment slot")
	_expect(owner.gold_bar_owned, "Gold Bar should be owned after acquisition")
	_expect(owner.gold_bar_active, "Gold Bar penalty should be active while carried")
	_expect(owner.gold_bar_count == 1, "one carried Gold Bar should sync count 1")
	_expect(owner.gold_bar_sell_price == 2000, "active Gold Bar should expose per-item sell price")
	_expect(owner.gold_bar_total_sell_price == 2000, "one Gold Bar should total 2000 gold")
	_expect_close(owner.gold_bar_speed_penalty_pct, 30.0, "Gold Bar should sync a 30 percent speed penalty")
	_expect_close(owner.gold_bar_speed_multiplier, 0.7, "Gold Bar speed multiplier should be 0.7")
	_expect_close(runtime.get_player_speed_multiplier(), 0.7, "player speed multiplier should include carried Gold Bar")

	var config_builder: Object = BattleScenePlayerControlConfigBuilder.new()
	var config: Dictionary = config_builder.build_config(owner, registry, "smasher", FakeControlContextBuilder.new())
	_expect_close(float(config.get("paddle_speed", 0.0)), 7.0, "control config should receive Gold Bar speed penalty")
	_expect_close(float(config.get("paddle_max_speed", 0.0)), 14.0, "control max speed should receive Gold Bar speed penalty")

	_expect(runtime.equip_item("speedboots", owner, registry, {"speed_bonus_pct": 10.0}, false), "Speedboots should equip beside carried Gold Bar")
	_expect_close(runtime.get_player_speed_multiplier(), 0.77, "Speedboots and Gold Bar multipliers should stack")
	config = config_builder.build_config(owner, registry, "smasher", FakeControlContextBuilder.new())
	_expect_close(float(config.get("paddle_speed", 0.0)), 7.7, "control speed should include stacked Speedboots and Gold Bar")

	_expect(runtime.acquire_item("gold_bar", owner, registry, {}, false, false) >= 0, "Gold Bar should allow duplicate farming")
	_expect(owner.gold_bar_count == 2, "two carried Gold Bars should sync count 2")
	_expect(owner.gold_bar_total_sell_price == 4000, "two Gold Bars should total 4000 gold")
	_expect_close(runtime.get_gold_bar_speed_multiplier(), 0.7, "duplicate Gold Bars should not double the movement penalty")

	_expect(runtime.discard_inventory_item(_find_inventory_index(runtime, "gold_bar"), owner, registry), "discarding one Gold Bar should succeed")
	_expect(owner.gold_bar_count == 1, "one Gold Bar should remain after first discard")
	_expect_close(runtime.get_gold_bar_speed_multiplier(), 0.7, "remaining Gold Bar should keep the movement penalty")
	_expect(runtime.discard_inventory_item(_find_inventory_index(runtime, "gold_bar"), owner, registry), "discarding the final Gold Bar should succeed")
	_expect(owner.gold_bar_count == 0, "Gold Bar count should clear after final discard")
	_expect(not owner.gold_bar_active, "Gold Bar penalty should clear when no Gold Bar is owned")
	_expect_close(runtime.get_player_speed_multiplier(), 1.1, "Speedboots speed should remain after selling/removing Gold Bars")

	print("gold_bar_port_smoke: ok")
	quit(0)


func _expect_icon_asset(item_data: Dictionary) -> void:
	var icon: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_path", "")))
	_expect(icon != null, "Gold Bar icon should load")
	if icon != null:
		_expect(icon.get_width() == 32 and icon.get_height() == 32, "Gold Bar icon should be the original 32px render")


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		var field_item: Dictionary = item_value if item_value is Dictionary else {}
		if str(field_item.get("name", "")) == item_name:
			return true
	return false


func _find_inventory_index(runtime: Object, item_name: String) -> int:
	var snapshot: Dictionary = runtime.get_snapshot()
	var inventory: Array = snapshot.get("inventory_items", [])
	for i in range(inventory.size()):
		var item_data: Dictionary = inventory[i] if inventory[i] is Dictionary else {}
		if str(item_data.get("name", "")) == item_name:
			return i
	return -1


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
