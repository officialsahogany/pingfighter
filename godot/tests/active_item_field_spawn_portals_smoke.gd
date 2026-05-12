extends SceneTree

const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const ActiveItemFieldSpawnPortals := preload("res://scripts/items/active_item_field_spawn_portals.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_regular_portal_queue_and_release()
	_verify_dimension_gate_state()
	_verify_field_spawn_controller_delegates_portals()

	if _failures.is_empty():
		print("active_item_field_spawn_portals_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_regular_portal_queue_and_release() -> void:
	var portals: Object = ActiveItemFieldSpawnPortals.new()
	var main_item := {"item_data": {"name": "banana"}}
	var release_msec: int = portals.queue_item_after_portal(main_item, Vector2(120.0, 240.0))
	_expect(portals.get_pending_spawn_items().size() == 1, "regular portal queue should store one pending item")
	_expect(portals.get_item_spawn_portals().size() == 1, "regular portal queue should create one portal")
	_expect(release_msec >= Time.get_ticks_msec(), "regular portal queue should release in the future")

	var bonus_item := {"item_data": {"name": "boomerang"}, "lucky_bonus": true}
	portals.queue_lucky_coin_bonus_after_portal(bonus_item, Vector2(180.0, 280.0), Time.get_ticks_msec())
	_expect(portals.get_pending_spawn_items().size() == 2, "Lucky Coin bonus portal should add a second pending item")
	_expect(portals.get_item_spawn_portals().size() == 2, "Lucky Coin bonus portal should add a second portal")

	var released_items: Array[Dictionary] = portals.release_pending_spawn_items()
	_expect(released_items.size() == 1, "only immediately due pending items should release")
	_expect(bool(released_items[0].get("lucky_bonus", false)), "Lucky Coin bonus pending item should preserve glow marker")

	var live_portals: Array[Dictionary] = portals.get_item_spawn_portals()
	for portal in live_portals:
		portal["start_msec"] = Time.get_ticks_msec() - 2000
	portals.update_item_spawn_portals()
	_expect(portals.get_item_spawn_portals().is_empty(), "expired regular portals should be culled")


func _verify_dimension_gate_state() -> void:
	var portals: Object = ActiveItemFieldSpawnPortals.new()
	_expect(portals.activate_dimension_gate(), "dimension gate should activate")
	_expect(portals.is_dimension_gate_active(), "dimension gate should report active after activation")
	var portal_list: Array[Dictionary] = portals.get_item_spawn_portals()
	_expect(portal_list.size() == 1, "dimension gate should create one sustained portal")
	_expect(bool(portal_list[0].get("dimension_gate", false)), "dimension gate portal should be marked")
	_expect(bool(portal_list[0].get("sustained", false)), "dimension gate portal should be sustained")

	var release_msec: int = portals.queue_dimension_gate_item({"item_data": {"name": "soap"}})
	_expect(release_msec <= Time.get_ticks_msec(), "dimension gate item should release immediately")
	_expect(portals.release_pending_spawn_items().size() == 1, "dimension gate pending item should release immediately")

	_expect(not portals.update_dimension_gate(true), "blocked dimension gate should not request a spawn")
	_expect(not portals.is_dimension_gate_active(), "blocked dimension gate should clear active state")
	_expect(portals.get_item_spawn_portals().is_empty(), "blocked dimension gate should remove its sustained portal")


func _verify_field_spawn_controller_delegates_portals() -> void:
	var controller: Object = ActiveItemFieldSpawnController.new()
	_expect(controller.activate_dimension_gate(), "field spawn controller should delegate dimension activation")
	_expect(controller.is_dimension_gate_active(), "field spawn controller should delegate dimension active state")
	_expect(controller.get_item_spawn_portals().size() == 1, "field spawn controller should expose delegated portal list")
	controller.reset()
	_expect(not controller.is_dimension_gate_active(), "field spawn controller reset should reset delegated dimension state")
	_expect(controller.get_item_spawn_portals().is_empty(), "field spawn controller reset should clear delegated portals")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
