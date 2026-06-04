extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoSupplyDropState := preload("res://scripts/characters/commando_supply_drop_state.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")

const RENTAL_CANDIDATES := [
	"net_gun",
	"fire_support",
	"bowling_trap",
	"suicide_drone",
	"bazooka",
	"ak47",
]

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


func _init() -> void:
	_verify_supply_drop_routes_field_item_pickup_through_active_item_runtime()
	_verify_supply_drop_keeps_field_item_when_pickup_rejects()

	if _failures.is_empty():
		print("commando_supply_drop_field_item_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_supply_drop_routes_field_item_pickup_through_active_item_runtime() -> void:
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var weapon_controller: Object = CommandoWeaponController.new()
	var supply_state: Object = CommandoSupplyDropState.new()
	var active_item_runtime: Object = ActiveItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()

	for weapon_id in RENTAL_CANDIDATES:
		_expect(bool(weapon_controller.unlock_permanent_weapon(str(weapon_id), false)), "test setup should mark %s owned" % str(weapon_id))

	var deps := {
		"commando_weapon_controller": weapon_controller,
		"active_item_runtime": active_item_runtime,
		"owner": owner,
		"registry": registry,
		"commando_supply_drop_forced_payloads": [
			{"type": "field_item", "item_id": "grenade"},
		],
		"commando_supply_drop_payload_count": 1,
		"commando_supply_drop_aircraft_arrival_delay": 0.0,
		"commando_supply_drop_payload_delays": [1.15],
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
	_expect(bool(activate_result.get("activated", false)), "holding down plus action should activate supply drop")
	var pending: Dictionary = supply_state.get_snapshot().get("pending_drop", {})
	_expect(str(pending.get("type", "")) == "field_item", "supply drop should fall back to a field item when no rentals are eligible")
	_expect(str(pending.get("item_id", "")) == "grenade", "field item fallback should use the configured field item id")

	var resolve_result: Dictionary = supply_state.update(4.2, deps)
	_expect(bool(resolve_result.get("drop_resolved", false)), "field item supply drop should resolve after delay")
	var drop: Dictionary = resolve_result.get("drop", {})
	_expect(str(drop.get("type", "")) == "field_item", "resolved drop should keep field item type")
	_expect(bool(drop.get("collectible_pending", false)), "field item drop should become a collectible parachute box")
	_expect(weapon_controller.get_weapons() == ["pistol"], "field item fallback should not grant a rental weapon")
	var drop_position: Vector2 = drop.get("drop_position", Vector2.ZERO)
	_expect(drop_position.x >= 15.0 and drop_position.x <= 745.0, "field item drop position should stay inside the playfield")
	_expect(drop_position.y >= 15.0 and drop_position.y <= 735.0, "field item drop position should stay inside the playfield")
	_expect(owner.active_item_slots.is_empty(), "field item should not be stored before the parachute box is picked up")
	_expect(active_item_runtime.get_field_spawned_items().is_empty(), "direct supply collectible should not spawn a separate field item before pickup")

	var collectible: Dictionary = _get_first_collectible(supply_state)
	_expect(not collectible.is_empty(), "field item drop should be present in the collectible list")
	var pickup_pos: Vector2 = collectible.get("pos", drop_position)
	deps["commando_supply_drop_collision_context"] = {
		"player_pos": pickup_pos - Vector2(35.0, 20.0),
		"player_paddle_size": Vector2(70.0, 40.0),
		"hitbox_padding": 0.0,
	}
	var pickup_result: Dictionary = supply_state.update(0.01, deps)
	_expect(bool(pickup_result.get("pickup_resolved", false)), "player paddle should collect the supply parachute box")
	var picked_drop: Dictionary = pickup_result.get("picked_drop", {})
	_expect(str(picked_drop.get("type", "")) == "field_item", "picked drop should keep field item type")
	_expect(bool(picked_drop.get("field_item_collected", false)), "picked field item should store through active item runtime")
	_expect(owner.active_item_slots.size() == 1, "picked field item should write owner active slots")
	_expect(str(owner.active_item_slots[0].get("name", "")) == "grenade", "stored field item should use the catalog item data")
	_expect(_get_array(supply_state.get_snapshot().get("collectible_drops", [])).is_empty(), "collected field item should leave no parachute boxes")
	_expect(active_item_runtime.get_field_spawned_items().is_empty(), "direct pickup should not leave a spawned field item behind")


func _verify_supply_drop_keeps_field_item_when_pickup_rejects() -> void:
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var weapon_controller: Object = CommandoWeaponController.new()
	var supply_state: Object = CommandoSupplyDropState.new()
	var active_item_runtime: Object = ActiveItemRuntime.new()
	var owner := FakeOwner.new()
	owner.active_item_slots = [{"name": "banana"}, {"name": "soap"}, {"name": "flare"}]
	var registry := FakeRegistry.new()
	for weapon_id in RENTAL_CANDIDATES:
		weapon_controller.unlock_permanent_weapon(str(weapon_id), false)
	var deps := {
		"commando_weapon_controller": weapon_controller,
		"active_item_runtime": active_item_runtime,
		"owner": owner,
		"registry": registry,
		"commando_supply_drop_forced_payloads": [
			{"type": "field_item", "item_id": "grenade"},
		],
		"commando_supply_drop_payload_count": 1,
		"commando_supply_drop_aircraft_arrival_delay": 0.0,
		"commando_supply_drop_payload_delays": [1.15],
		"current_stage": 1,
	}
	supply_state.update_input(
		{"down_pressed": true, "action_pressed": true},
		1.0,
		500.0,
		skill_config,
		skill_state,
		deps
	)
	supply_state.update(4.2, deps)
	var collectible: Dictionary = _get_first_collectible(supply_state)
	var pickup_pos: Vector2 = collectible.get("pos", collectible.get("drop_position", Vector2.ZERO))
	deps["commando_supply_drop_collision_context"] = {
		"player_pos": pickup_pos - Vector2(35.0, 20.0),
		"player_paddle_size": Vector2(70.0, 40.0),
		"hitbox_padding": 0.0,
	}
	var pickup_result: Dictionary = supply_state.update(0.01, deps)
	_expect(bool(pickup_result.get("pickup_rejected", false)), "full active slots should reject supply field item pickup")
	_expect(owner.active_item_slots.size() == 3, "rejected supply pickup should not alter full active slots")
	_expect(_get_array(supply_state.get_snapshot().get("collectible_drops", [])).size() == 1, "rejected supply pickup should keep the parachute box")


func _get_first_collectible(supply_state: Object) -> Dictionary:
	var drops: Array = _get_array(supply_state.get_snapshot().get("collectible_drops", []))
	if drops.is_empty() or not (drops[0] is Dictionary):
		return {}
	return drops[0]


func _get_array(value: Variant) -> Array:
	return value if value is Array else []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
