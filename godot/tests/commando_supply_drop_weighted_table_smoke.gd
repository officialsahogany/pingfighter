extends SceneTree

const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoSupplyDropState := preload("res://scripts/characters/commando_supply_drop_state.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_default_field_table_matches_python_supply_pool()
	_verify_python_drop_timing_patterns()
	_verify_weighted_table_can_pick_field_item_with_rentals_available()
	_verify_weighted_table_reserves_distinct_rentals()

	if _failures.is_empty():
		print("commando_supply_drop_weighted_table_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_default_field_table_matches_python_supply_pool() -> void:
	var field_ids: Array[String] = []
	for candidate_value in CommandoSupplyDropState.DEFAULT_FIELD_ITEM_DROP_CANDIDATES:
		var candidate: Dictionary = candidate_value if candidate_value is Dictionary else {}
		var item_id: String = str(candidate.get("item_id", ""))
		if item_id != "":
			field_ids.append(item_id)
	_expect(field_ids == ["grenade", "molotov", "flare", "spider_mine", "dynamite", "ammo_box", "doping_potion"], "default field supply table should match the Python source pool")
	_expect(not field_ids.has("gauge_charge"), "default field supply table should not include gauge_charge")
	_expect(CommandoSupplyDropState.DEFAULT_FIELD_ITEM_ID == "grenade", "empty-candidate fallback should stay in the Python supply pool")
	_expect(is_equal_approx(_get_field_item_weight("ammo_box"), 1.0), "ammo_box weight should keep supply-use drop chance near 20 percent")


func _verify_python_drop_timing_patterns() -> void:
	var burst_state: Object = CommandoSupplyDropState.new()
	_activate_supply(burst_state, {
		"commando_weapon_controller": CommandoWeaponController.new(),
		"commando_supply_drop_payload_count": 3,
		"commando_supply_drop_timing_pattern": "burst",
	})
	var burst_delays: Array = _get_array(burst_state.get_snapshot().get("pending_drop_delays", []))
	_expect(burst_delays.size() == 3, "burst timing should build one delay per payload")
	_expect(is_equal_approx(float(burst_delays[0]), 10.0 / 60.0), "burst first drop should use the Python 10-frame burst interval after the Godot center-entry gate")
	_expect(is_equal_approx(float(burst_delays[1]), 10.0 / 60.0), "burst second drop should use the Python 10-frame burst interval")
	_expect(_is_between(float(burst_delays[2]), 90.0 / 60.0, 180.0 / 60.0), "burst cooldown should use Python 90-180 frame range")

	var delayed_state: Object = CommandoSupplyDropState.new()
	_activate_supply(delayed_state, {
		"commando_weapon_controller": CommandoWeaponController.new(),
		"commando_supply_drop_payload_count": 2,
		"commando_supply_drop_timing_pattern": "delayed",
	})
	var delayed_delays: Array = _get_array(delayed_state.get_snapshot().get("pending_drop_delays", []))
	_expect(delayed_delays.size() == 2, "delayed timing should build one delay per payload")
	_expect(_is_between(float(delayed_delays[0]), 12.0 / 60.0, 150.0 / 60.0), "delayed first drop should use the initial 12-150 frame wait after the Godot center-entry gate")
	_expect(_is_between(float(delayed_delays[1]), 120.0 / 60.0, 210.0 / 60.0), "delayed follow-up drop should use Python 120-210 frame range")


func _verify_weighted_table_can_pick_field_item_with_rentals_available() -> void:
	var supply_state: Object = CommandoSupplyDropState.new()
	var deps := {
		"commando_weapon_controller": CommandoWeaponController.new(),
		"commando_supply_drop_payload_count": 1,
		"commando_supply_drop_payload_rolls": [0.0],
	}
	_activate_supply(supply_state, deps)
	var pending: Dictionary = supply_state.get_snapshot().get("pending_drop", {})
	_expect(str(pending.get("type", "")) == "field_item", "low roll should select an ordinary field-item payload")
	_expect(str(pending.get("item_id", "")) == "grenade", "first weighted field item should be grenade")


func _verify_weighted_table_reserves_distinct_rentals() -> void:
	var supply_state: Object = CommandoSupplyDropState.new()
	var deps := {
		"commando_weapon_controller": CommandoWeaponController.new(),
		"commando_supply_drop_payload_count": 3,
		"commando_supply_drop_payload_rolls": [0.999, 0.999, 0.999],
	}
	_activate_supply(supply_state, deps)
	var pending_drops: Array = _get_array(supply_state.get_snapshot().get("pending_drops", []))
	_expect(pending_drops.size() == 3, "weighted table should build all requested payloads")
	var seen := {}
	for drop_value in pending_drops:
		var drop: Dictionary = drop_value if drop_value is Dictionary else {}
		_expect(str(drop.get("type", "")) == "rental_weapon", "high rolls should select rental payloads while rentals remain")
		var weapon_id: String = str(drop.get("weapon_id", ""))
		_expect(weapon_id != "", "rental payload should keep a weapon id")
		_expect(not seen.has(weapon_id), "weighted rental payloads should not duplicate reserved rentals")
		seen[weapon_id] = true


func _activate_supply(supply_state: Object, deps: Dictionary) -> void:
	var result: Dictionary = supply_state.update_input(
		{"down_pressed": true, "action_pressed": false},
		1.0,
		500.0,
		CommandoSkillConfig.new(),
		CommandoSkillState.new(),
		deps
	)
	_expect(bool(result.get("activated", false)), "supply drop should activate for weighted table smoke")


func _get_array(value: Variant) -> Array:
	return value if value is Array else []


func _get_field_item_weight(item_id: String) -> float:
	for candidate_value in CommandoSupplyDropState.DEFAULT_FIELD_ITEM_DROP_CANDIDATES:
		var candidate: Dictionary = candidate_value if candidate_value is Dictionary else {}
		if str(candidate.get("item_id", "")) == item_id:
			return float(candidate.get("weight", 0.0))
	return 0.0


func _is_between(value: float, min_value: float, max_value: float) -> bool:
	return value >= min_value and value <= max_value


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
