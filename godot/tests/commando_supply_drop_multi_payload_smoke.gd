extends SceneTree

const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoSupplyDropState := preload("res://scripts/characters/commando_supply_drop_state.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_supply_drop_resolves_multiple_payloads_in_sequence()

	if _failures.is_empty():
		print("commando_supply_drop_multi_payload_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_supply_drop_resolves_multiple_payloads_in_sequence() -> void:
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var weapon_controller: Object = CommandoWeaponController.new()
	var supply_state: Object = CommandoSupplyDropState.new()
	var deps := {
		"commando_weapon_controller": weapon_controller,
		"commando_supply_drop_payload_count": 3,
		"commando_supply_drop_forced_payloads": [
			{"type": "rental_weapon", "weapon_id": "net_gun"},
			{"type": "rental_weapon", "weapon_id": "fire_support"},
			{"type": "rental_weapon", "weapon_id": "bowling_trap"},
		],
		"commando_supply_drop_aircraft_arrival_delay": 0.0,
		"commando_supply_drop_payload_delays": [1.15, 0.28, 0.28],
		"current_stage": 1,
	}

	var activate_result: Dictionary = supply_state.update_input(
		{"down_pressed": true, "action_pressed": true},
		1.0,
		500.0,
		skill_config,
		skill_state,
		deps
	)
	_expect(bool(activate_result.get("activated", false)), "multi payload supply drop should activate")
	var snapshot: Dictionary = supply_state.get_snapshot()
	var pending_drops: Array = _get_array(snapshot.get("pending_drops", []))
	_expect(pending_drops.size() == 3, "multi payload supply drop should queue three payloads")
	_expect(_drop_weapon_id(pending_drops, 0) == "net_gun", "first payload should reserve the first available rental")
	_expect(_drop_weapon_id(pending_drops, 1) == "fire_support", "second payload should reserve the next available rental")
	_expect(_drop_weapon_id(pending_drops, 2) == "bowling_trap", "third payload should reserve a distinct rental")

	var first_result: Dictionary = supply_state.update(4.2, deps)
	_expect(bool(first_result.get("drop_resolved", false)), "first payload should resolve after aircraft delay")
	_expect(_get_array(first_result.get("drops", [])).size() == 1, "first update should resolve one payload")
	_expect(str(first_result.get("drop", {}).get("weapon_id", "")) == "net_gun", "first resolved payload should be net gun")
	_expect(int(first_result.get("pending_payloads", -1)) == 2, "two payloads should remain after the first drop")
	_expect(not weapon_controller.get_weapons().has("net_gun"), "first payload should wait for direct pickup before granting net gun")
	var first_pickup: Dictionary = _collect_first_drop(supply_state, deps)
	_expect(bool(first_pickup.get("pickup_resolved", false)), "first payload should be collectible by the player paddle")
	_expect(weapon_controller.get_weapons().has("net_gun"), "first payload pickup should grant net gun")
	_expect(str(weapon_controller.get_snapshot().get("current_weapon_id", "")) == "net_gun", "first rental pickup should select the granted weapon for the left firearm HUD")
	_expect(bool(weapon_controller.get_hud_highlight_state().get("active", false)), "first rental pickup should flash the left firearm HUD")
	_expect(bool(supply_state.get_snapshot().get("active", false)), "supply drop should stay active while payloads remain")

	var second_result: Dictionary = supply_state.update(0.3, deps)
	_expect(str(second_result.get("drop", {}).get("weapon_id", "")) == "fire_support", "second payload should resolve on the interval")
	_expect(int(second_result.get("pending_payloads", -1)) == 1, "one payload should remain after the second drop")
	_expect(not weapon_controller.get_weapons().has("fire_support"), "second payload should wait for pickup before granting fire support")
	var second_pickup: Dictionary = _collect_first_drop(supply_state, deps)
	_expect(bool(second_pickup.get("pickup_resolved", false)), "second payload should be collectible by the player paddle")
	_expect(weapon_controller.get_weapons().has("fire_support"), "second payload pickup should grant fire support")
	_expect(str(weapon_controller.get_snapshot().get("current_weapon_id", "")) == "fire_support", "second rental pickup should switch the firearm HUD again")

	var third_result: Dictionary = supply_state.update(0.3, deps)
	_expect(str(third_result.get("drop", {}).get("weapon_id", "")) == "bowling_trap", "third payload should resolve last")
	_expect(int(third_result.get("pending_payloads", -1)) == 0, "no payloads should remain after the final drop")
	_expect(not weapon_controller.get_weapons().has("bowling_trap"), "third payload should wait for pickup before granting bowling trap")
	snapshot = supply_state.get_snapshot()
	_expect(bool(snapshot.get("active", false)), "supply aircraft should keep flying at Python speed after all payloads resolve")
	_expect(_get_array(snapshot.get("pending_drops", [])).is_empty(), "pending payload queue should be empty after completion")
	var third_pickup: Dictionary = _collect_first_drop(supply_state, deps)
	_expect(bool(third_pickup.get("pickup_resolved", false)), "third payload should remain collectible after aircraft exits")
	_expect(weapon_controller.get_weapons().has("bowling_trap"), "third payload pickup should grant bowling trap")
	_expect(_get_array(supply_state.get_snapshot().get("collectible_drops", [])).is_empty(), "all collected payloads should clear the collectible list")
	supply_state.update(float(supply_state.get_snapshot().get("flight_duration", 7.8)), deps)
	_expect(not bool(supply_state.get_snapshot().get("active", true)), "supply aircraft should end only after it exits the screen")


func _drop_weapon_id(drops: Array, index: int) -> String:
	if index < 0 or index >= drops.size() or not (drops[index] is Dictionary):
		return ""
	return str((drops[index] as Dictionary).get("weapon_id", ""))


func _get_array(value: Variant) -> Array:
	return value if value is Array else []


func _collect_first_drop(supply_state: Object, deps: Dictionary) -> Dictionary:
	var drops: Array = _get_array(supply_state.get_snapshot().get("collectible_drops", []))
	if drops.is_empty() or not (drops[0] is Dictionary):
		return {}
	var drop: Dictionary = drops[0]
	var pickup_pos: Vector2 = drop.get("pos", drop.get("drop_position", Vector2.ZERO))
	deps["commando_supply_drop_collision_context"] = {
		"player_pos": pickup_pos - Vector2(35.0, 20.0),
		"player_paddle_size": Vector2(70.0, 40.0),
		"hitbox_padding": 0.0,
	}
	var result: Dictionary = supply_state.update(0.01, deps)
	deps.erase("commando_supply_drop_collision_context")
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
