extends SceneTree

const ActiveItemPendingThrowRecovery := preload("res://scripts/items/active_item_pending_throw_recovery.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")

var _failures: Array[String] = []
var _catalog: Object = ActiveItemCatalog.new()


class FakeHudState:
	extends RefCounted

	var selected_index := -1

	func set_selected_index(index: int) -> void:
		selected_index = index


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []
	var player_pos: Vector2 = Vector2(310.0, 690.0)
	var boss_pos: Vector2 = Vector2(330.0, 25.0)
	var special_gauge: float = 0.0
	var special_gauge_max: float = 500.0


class FakeRegistry:
	extends RefCounted

	var hud_state := FakeHudState.new()

	func get_instance(key: String) -> Object:
		if key == "active_item_hud_state":
			return hud_state
		return null


class FakeSlotController:
	extends RefCounted

	var last_item_use_msec := -1000000


class FakeThrowController:
	extends RefCounted

	var windup_active := false

	func is_throw_windup_active() -> bool:
		return windup_active

	func cancel_pending_throw_windups() -> void:
		windup_active = false


func _init() -> void:
	_verify_direct_pending_throw_restore()
	_verify_backup_clears_after_release()
	_verify_non_throw_items_do_not_back_up()

	if _failures.is_empty():
		print("active_item_pending_throw_recovery_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_pending_throw_restore() -> void:
	var helper: Object = ActiveItemPendingThrowRecovery.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var slot_controller := FakeSlotController.new()
	var throw_controller := FakeThrowController.new()
	var molotov: Dictionary = _catalog.build_item_by_name("molotov")
	molotov["last_use_msec"] = 9999
	slot_controller.last_item_use_msec = 1234
	throw_controller.windup_active = true

	helper.backup_pending_throw_item(molotov, 0, owner, registry, slot_controller, throw_controller)
	_expect(helper.has_pending_backup(), "pending throw helper should store a windup backup")

	_expect(helper.restore_on_round_end(owner, registry, slot_controller, throw_controller), "pending throw helper should restore during an active windup")
	_expect(not throw_controller.is_throw_windup_active(), "pending throw helper should cancel the windup on restore")
	_expect(owner.active_item_slots.size() == 1, "pending throw helper should insert restored item")
	_expect(str(owner.active_item_slots[0].get("name", "")) == "molotov", "pending throw helper should preserve item identity")
	_expect(not owner.active_item_slots[0].has("last_use_msec"), "pending throw helper should strip spent-use timestamp")
	_expect(slot_controller.last_item_use_msec == 1234, "pending throw helper should restore prior global cooldown timestamp")
	_expect(registry.hud_state.selected_index == 0, "pending throw helper should select the restored slot")


func _verify_backup_clears_after_release() -> void:
	var helper: Object = ActiveItemPendingThrowRecovery.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var slot_controller := FakeSlotController.new()
	var throw_controller := FakeThrowController.new()
	var molotov: Dictionary = _catalog.build_item_by_name("molotov")
	throw_controller.windup_active = true

	helper.backup_pending_throw_item(molotov, 0, owner, registry, slot_controller, throw_controller)
	_expect(helper.has_pending_backup(), "pending throw helper should have a backup before release")
	throw_controller.cancel_pending_throw_windups()
	helper.clear_backup_if_released(throw_controller)
	_expect(not helper.has_pending_backup(), "pending throw helper should clear backup after windup release/cancel")


func _verify_non_throw_items_do_not_back_up() -> void:
	var helper: Object = ActiveItemPendingThrowRecovery.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var slot_controller := FakeSlotController.new()
	var throw_controller := FakeThrowController.new()
	var life_elixir: Dictionary = _catalog.build_item_by_name("life_elixir")
	throw_controller.windup_active = true

	helper.backup_pending_throw_item(life_elixir, 0, owner, registry, slot_controller, throw_controller)
	_expect(not helper.has_pending_backup(), "pending throw helper should ignore non-throw items")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
