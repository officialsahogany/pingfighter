extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_snapshot_facade_keeps_existing_keys()
	_verify_snapshot_inventory_is_deep_copied()

	if _failures.is_empty():
		print("mythic_item_snapshot_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_snapshot_facade_keeps_existing_keys() -> void:
	var runtime: Object = MythicItemRuntime.new()
	runtime.inventory_items.append({"name": "megingjord", "equipped": true})
	runtime.equipped_items["megingjord"] = 0
	runtime.megingjord_extra_pick_count = 2
	runtime.sensor_enabled = false
	runtime.venom_mist_field_active = true
	runtime.venom_mist_center = Vector2(120.0, 340.0)
	runtime.poseidon_capture_active = true
	runtime.poseidon_capture_duration_frames = 40.0
	runtime.poseidon_capture_timer_frames = 10.0

	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(snapshot.get("megingjord_equipped", false)), "snapshot should preserve equipped mythic state")
	_expect(int(snapshot.get("megingjord_extra_pick_count", 0)) == 2, "snapshot should preserve megingjord counters")
	_expect(not bool(snapshot.get("sensor_enabled", true)), "snapshot should preserve sensor enabled flag")
	_expect(bool(snapshot.get("venom_mist_field_active", false)), "snapshot should preserve venom mist field flag")
	_expect(snapshot.get("venom_mist_field_center", Vector2.ZERO) == Vector2(120.0, 340.0), "snapshot should preserve venom mist center")
	_expect(is_equal_approx(float(snapshot.get("poseidon_trident_capture_progress", 0.0)), 0.25), "snapshot should preserve poseidon capture progress math")


func _verify_snapshot_inventory_is_deep_copied() -> void:
	var runtime: Object = MythicItemRuntime.new()
	runtime.inventory_items.append({"name": "heavenly_cape", "rolls": {"cooldown_reduction": 12.0}})

	var snapshot: Dictionary = runtime.get_snapshot()
	var copied_inventory: Array = snapshot.get("inventory_items", [])
	_expect(copied_inventory.size() == 1, "snapshot should expose inventory items")
	copied_inventory[0]["name"] = "changed"
	copied_inventory[0]["rolls"]["cooldown_reduction"] = 1.0

	var original_item: Dictionary = runtime.inventory_items[0]
	_expect(str(original_item.get("name", "")) == "heavenly_cape", "snapshot inventory should be deep copied")
	_expect(is_equal_approx(float(original_item.get("rolls", {}).get("cooldown_reduction", 0.0)), 12.0), "snapshot nested rolls should be deep copied")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
