extends SceneTree

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PaddleBounceEventRouter := preload("res://scripts/ball/paddle_bounce_event_router.gd")
const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var bluetooth_ring_equipped := false
	var bluetooth_ring_active := false
	var bluetooth_ring_gauge_gain_pct := 0.0
	var bluetooth_ring_gauge_multiplier := 1.0

	func queue_redraw() -> void:
		pass


class FakeFeedback:
	var gauge_flash_count := 0

	func trigger_gauge_flash() -> void:
		gauge_flash_count += 1


func _init() -> void:
	var catalog: Object = MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("bluetooth_ring")
	_expect(not item_data.is_empty(), "Bluetooth Ring should build from catalog")
	_expect(str(item_data.get("slot", "")) == "accessory", "Bluetooth Ring should use accessory slots")
	_expect(str(item_data.get("display_name", "")) == "블루투스링", "Bluetooth Ring should keep Korean display name")
	_expect(ProjectResourceLoader.load_texture(str(item_data.get("icon_path", ""))) != null, "Bluetooth Ring icon should load")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "bluetooth_ring"), "Bluetooth Ring should be in passive field-spawn list")

	var roll_options: Array = catalog.get_roll_options("bluetooth_ring")
	_expect(roll_options.size() == 1, "Bluetooth Ring should have one roll option")
	var option: Dictionary = roll_options[0]
	_expect(str(option.get("key", "")) == "gauge_gain_pct", "Bluetooth Ring roll key should match Python reference")
	_expect(is_equal_approx(float(option.get("min", 0.0)), 10.0), "Bluetooth Ring roll min should be 10%")
	_expect(is_equal_approx(float(option.get("max", 0.0)), 20.0), "Bluetooth Ring roll max should be 20%")
	_expect(is_equal_approx(float(option.get("default", 0.0)), 15.0), "Bluetooth Ring default roll should be 15%")
	_expect(is_equal_approx(catalog.get_default_roll_value("bluetooth_ring", "gauge_gain_pct"), 15.0), "catalog default roll should be 15%")

	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	_expect(runtime.equip_item("bluetooth_ring", owner, null, {"gauge_gain_pct": 20.0}, false), "Bluetooth Ring should equip")
	_expect(owner.equipment_slots.has("accessory1"), "Bluetooth Ring should resolve into the first accessory slot")
	_expect(str(owner.equipment_slots["accessory1"].get("name", "")) == "bluetooth_ring", "Bluetooth Ring should occupy accessory1")
	_expect(owner.bluetooth_ring_equipped, "owner should expose Bluetooth Ring equipped")
	_expect(owner.bluetooth_ring_active, "owner should expose Bluetooth Ring active")
	_expect(is_equal_approx(owner.bluetooth_ring_gauge_gain_pct, 20.0), "owner should sync Bluetooth Ring gauge bonus")
	_expect(is_equal_approx(owner.bluetooth_ring_gauge_multiplier, 1.2), "owner should sync Bluetooth Ring multiplier")
	_expect(is_equal_approx(runtime.calculate_bluetooth_ring_gauge_charge(50.0), 60.0), "20% Bluetooth Ring should turn 50 gauge into 60")

	var feedback := FakeFeedback.new()
	var router: Object = PaddleBounceEventRouter.new()
	var gauge_after_hit: float = router.register_player_hit(
		Vector2(320.0, 680.0),
		0.0,
		false,
		false,
		100.0,
		{
			"selected_character_type": "soldier",
			"gauge_charge_per_hit": 50.0,
			"gauge_max": 500.0,
		},
		{
			"mythic_item_runtime": runtime,
			"feedback": feedback,
		}
	)
	_expect(is_equal_approx(gauge_after_hit, 160.0), "normal paddle hit should apply Bluetooth Ring gauge bonus")
	_expect(feedback.gauge_flash_count == 1, "Bluetooth Ring boosted gauge gain should still trigger gauge feedback")

	_expect(runtime.unequip_item("bluetooth_ring", owner, null), "Bluetooth Ring should unequip")
	_expect(is_equal_approx(runtime.calculate_bluetooth_ring_gauge_charge(50.0), 50.0), "Bluetooth Ring bonus should clear after unequip")

	var field_spawn_controller: Object = ActiveItemFieldSpawnController.new()
	var candidate_names: Dictionary = field_spawn_controller.get_field_spawn_candidate_names()
	_expect(candidate_names.has("bluetooth_ring"), "field spawn candidates should include Bluetooth Ring")

	print("bluetooth_ring_port_smoke: ok")
	quit(0)


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		var item: Dictionary = item_value if item_value is Dictionary else {}
		if str(item.get("name", "")) == item_name:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
