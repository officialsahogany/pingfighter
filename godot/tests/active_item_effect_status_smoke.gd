extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectStatus := preload("res://scripts/items/active_item_effect_status.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_status_queries()
	_verify_controller_delegates_status_queries()

	if _failures.is_empty():
		print("active_item_effect_status_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_status_queries() -> void:
	var status: Object = ActiveItemEffectStatus.new()

	_expect(not status.can_store_item("wall", {"aipill_active": true}), "AI Pill active should block storing any active item")
	_expect(not status.can_store_item("long_boost", {"long_boost_active": true}), "matching active duration item should block duplicate storage")
	_expect(status.can_store_item("wall", {"long_boost_active": true}), "unrelated active duration item should not block wall storage")
	_expect(not status.can_store_item("wall", {"brick_wall_installing": true}), "wall installation should block wall storage")
	_expect(status.can_store_item("milk_bottle", {"milk_bottle_active": true}), "milk bottle must stay collectable while active so Milku's stacking production keeps working")

	_expect(not status.has_field_effects({}), "empty effect flags should report no field effects")
	_expect(status.has_field_effects({"has_brick_particles": true}), "effect particles should report field effects")
	_expect(status.has_field_effects({"magnet_field_active": true}), "active field effect should report field effects")

	var speed_multiplier: float = status.get_player_speed_multiplier(true, 20.0, true, 30.0, 2.3)
	_expect(is_equal_approx(speed_multiplier, 3.45), "player speed multiplier should combine Vitamin Pill and Strange Vial")
	_expect(status.is_time_frozen(true, 10.0), "time frozen should require active stopwatch with freeze timer")
	_expect(not status.is_time_frozen(true, 0.0), "empty stopwatch freeze timer should not be frozen")


func _verify_controller_delegates_status_queries() -> void:
	var controller: Object = ActiveItemEffectController.new()

	controller.long_boost_active = true
	_expect(not controller.can_store_item("long_boost"), "controller should delegate active duplicate store gate")
	_expect(controller.can_store_item("wall"), "controller should allow unrelated item storage")

	controller.aipill_active = true
	_expect(not controller.can_store_item("wall"), "controller should delegate AI Pill global store gate")
	_expect(controller.is_aipill_active(), "controller should delegate AI Pill active query")

	controller.aipill_active = false
	controller.vitamin_pill_active = true
	controller.vitamin_pill_timer_frames = 40.0
	controller.strange_vial_active = true
	controller.strange_vial_timer_frames = 40.0
	controller.strange_vial_speed_multiplier = 2.0
	_expect(is_equal_approx(controller.get_player_speed_multiplier(), 3.0), "controller should delegate speed multiplier query")

	controller.pickup_particles.append({"life": 1.0})
	_expect(controller.has_field_effects(), "controller should delegate field effect presence query")

	controller.stopwatch_active = true
	controller.stopwatch_timer_frames = 12.0
	_expect(controller.is_time_frozen(), "controller should delegate time-freeze query")
	_expect(controller.is_stopwatch_active(), "controller should delegate stopwatch active query")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
