extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []
	var player_pos: Vector2 = Vector2(310.0, 690.0)
	var boss_pos: Vector2 = Vector2(330.0, 25.0)
	var special_gauge: float = 0.0
	var special_gauge_max: float = 500.0


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


func _init() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	_finish_runtime_initialization(runtime)
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var molotov: Dictionary = runtime.item_catalog.build_item_by_name("molotov")
	owner.active_item_slots = [molotov]

	_expect(runtime.use_slot(0, owner, registry), "molotov should activate from an active slot")
	_expect(owner.active_item_slots.is_empty(), "molotov should be consumed at windup start")
	_expect(runtime.throw_controller.is_throw_windup_active(), "molotov should create a pending throw windup")

	_expect(
		runtime.restore_pending_throw_item_on_round_end(owner, registry),
		"round end should restore a consumed item while windup is still pending"
	)
	_expect(not runtime.throw_controller.is_throw_windup_active(), "round end should cancel the pending windup")
	_expect(owner.active_item_slots.size() == 1, "restored molotov should return to the active slot")
	_expect(str(owner.active_item_slots[0].get("name", "")) == "molotov", "restored item should keep its identity")
	_expect(not bool(owner.active_item_slots[0].has("last_use_msec")), "restored item should not keep the spent-use timestamp")
	_expect(runtime.slot_controller.last_item_use_msec < 0, "round-canceled windup should not keep the global active-item cooldown")

	runtime.throw_controller.update(owner, registry, 1.0)
	_expect(runtime.throw_controller.get_molotovs().is_empty(), "canceled windup should not spawn a late molotov")

	if _failures.is_empty():
		print("active_item_throw_round_end_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish_runtime_initialization(runtime: Object) -> void:
	var guard := 0
	while runtime != null and runtime.has_method("prewarm_initialization_step") and not bool(runtime.prewarm_initialization_step()):
		guard += 1
		if guard > 64:
			_failures.append("active item runtime staged initialization did not finish")
			return
