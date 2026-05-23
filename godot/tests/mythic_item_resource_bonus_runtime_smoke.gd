extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")


class FakeOwner:
	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var accessory_slot_count := 4
	var special_gauge := 250.0
	var special_gauge_max := 500.0
	var fuel_pouch_equipped := false
	var fuel_pouch_gauge_bonus := 0.0
	var bluetooth_ring_equipped := false
	var bluetooth_ring_active := false
	var bluetooth_ring_gauge_gain_pct := 0.0
	var bluetooth_ring_gauge_multiplier := 1.0
	var star_detector_equipped := false
	var star_detector_active := false
	var star_detector_star_bonus_pct := 0.0
	var star_detector_bonus_chance := 0.0
	var gold_digger_equipped := false
	var gold_digger_count := 0
	var gold_digger_gold_bonus_pct := 0.0
	var gold_digger_multiplier := 1.0
	var lucky_coin_equipped := false
	var lucky_coin_active := false
	var lucky_coin_double_spawn_pct := 0.0
	var lucky_coin_double_spawn_chance := 0.0

	func queue_redraw() -> void:
		pass


func _init() -> void:
	seed(13579)
	var runtime := MythicItemRuntime.new()
	var owner := FakeOwner.new()

	_expect(
		runtime.equip_item("fuel_pouch", owner, null, {"fuel_bonus_flat": 100.0}, false),
		"Fuel Pouch should equip"
	)
	_expect(owner.fuel_pouch_equipped, "owner should expose Fuel Pouch equipped")
	_expect_close(owner.fuel_pouch_gauge_bonus, 100.0, "owner should sync Fuel Pouch gauge bonus")
	_expect_close(runtime.get_effective_special_gauge_max(500.0), 600.0, "Fuel Pouch should raise max gauge by its flat roll")
	_expect_close(owner.special_gauge_max, 600.0, "owner max gauge should sync after Fuel Pouch equip")
	_expect_close(owner.special_gauge, 300.0, "owner gauge should preserve its ratio when max gauge expands")

	_expect(
		runtime.equip_item("bluetooth_ring", owner, null, {"gauge_gain_pct": 25.0}, false),
		"Bluetooth Ring should equip"
	)
	_expect(owner.bluetooth_ring_equipped, "owner should expose Bluetooth Ring equipped")
	_expect(owner.bluetooth_ring_active, "owner should expose Bluetooth Ring active")
	_expect_close(owner.bluetooth_ring_gauge_gain_pct, 25.0, "owner should sync Bluetooth Ring gauge gain")
	_expect_close(owner.bluetooth_ring_gauge_multiplier, 1.25, "owner should sync Bluetooth Ring multiplier")
	_expect_close(runtime.calculate_bluetooth_ring_gauge_charge(40.0), 50.0, "Bluetooth Ring should multiply and floor base gauge gain")

	_expect(
		runtime.equip_item("star_detector", owner, null, {"star_bonus_pct": 100.0}, false),
		"Star Detector should equip"
	)
	_expect(owner.star_detector_equipped, "owner should expose Star Detector equipped")
	_expect(owner.star_detector_active, "owner should expose Star Detector active")
	_expect_close(owner.star_detector_star_bonus_pct, 100.0, "owner should sync Star Detector star bonus pct")
	_expect_close(owner.star_detector_bonus_chance, 1.0, "owner should sync Star Detector bonus chance")
	_expect(runtime.roll_star_detector_bonus_drop_count() == 1, "100% Star Detector chance should force one bonus drop")

	_expect(
		runtime.acquire_item("gold_digger", owner, null, {"gold_bonus_pct": 25.0}, true, false) >= 0,
		"first Gold Digger should acquire and equip"
	)
	_expect(
		runtime.acquire_item("gold_digger", owner, null, {"gold_bonus_pct": 50.0}, true, false) >= 0,
		"second Gold Digger should acquire and equip"
	)
	_expect(owner.gold_digger_equipped, "owner should expose Gold Digger equipped")
	_expect(owner.gold_digger_count == 2, "owner should count both equipped Gold Diggers")
	_expect_close(owner.gold_digger_gold_bonus_pct, 75.0, "owner should sync stacked Gold Digger bonus")
	_expect_close(owner.gold_digger_multiplier, 1.75, "owner should sync stacked Gold Digger multiplier")
	_expect_close(runtime.apply_gold_digger_gauge_bonus(70.0), 122.0, "Gold Digger should multiply and floor gauge gain")
	_expect(runtime.apply_gold_digger_gold_bonus(100) == 175, "Gold Digger should multiply direct gold")

	_expect(
		runtime.equip_item("lucky_coin", owner, null, {"double_spawn_pct": 100.0}, false),
		"Lucky Coin should equip"
	)
	_expect(owner.lucky_coin_equipped, "owner should expose Lucky Coin equipped")
	_expect(owner.lucky_coin_active, "owner should expose Lucky Coin active")
	_expect_close(owner.lucky_coin_double_spawn_pct, 100.0, "owner should sync Lucky Coin double spawn pct")
	_expect_close(owner.lucky_coin_double_spawn_chance, 1.0, "owner should sync Lucky Coin double spawn chance")
	_expect(runtime.should_lucky_coin_double_spawn(), "100% Lucky Coin should force a double spawn roll")

	_expect(runtime.unequip_item("fuel_pouch", owner, null), "Fuel Pouch should unequip")
	_expect_close(runtime.get_effective_special_gauge_max(500.0), 500.0, "Fuel Pouch max gauge bonus should clear after unequip")
	_expect_close(owner.special_gauge_max, 500.0, "owner max gauge should return to base after Fuel Pouch unequip")
	_expect_close(owner.special_gauge, 250.0, "owner gauge should preserve its ratio when max gauge contracts")

	print("mythic_item_resource_bonus_runtime_smoke: ok")
	quit(0)


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
