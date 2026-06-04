extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectQuery := preload("res://scripts/items/active_item_effect_query.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_query_facade()
	_verify_controller_delegates_query_facade()

	if _failures.is_empty():
		print("active_item_effect_query_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_query_facade() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var query: Object = ActiveItemEffectQuery.new()

	controller.vitamin_pill_active = true
	controller.vitamin_pill_timer_frames = 40.0
	controller.vitamin_pill_initial_timer_frames = 600.0
	controller.vitamin_pill_player_center = Vector2(320.0, 700.0)
	controller.strange_vial_active = true
	controller.strange_vial_timer_frames = 40.0
	controller.strange_vial_speed_multiplier = 2.0
	controller.doping_potion_active = true
	controller.doping_potion_timer_frames = 240.0
	controller.doping_potion_initial_timer_frames = 480.0
	controller.pickup_effect = {"timer": 1.0}
	controller.pickup_particles.append({"life": 1.0})
	controller.holy_barrier_active = true
	controller.stopwatch_active = true
	controller.stopwatch_timer_frames = 0.0
	controller.stopwatch_recovery_timer_frames = 30.0
	controller.stopwatch_original_ball_vel = Vector2(0.0, -8.0)

	_expect(query.has_pickup_effect(controller), "query should read pickup popup state")
	_expect(query.has_field_effects(controller), "query should read field-effect flags")
	_expect(is_equal_approx(query.get_player_speed_multiplier(controller), 3.0), "query should combine speed multipliers")

	var vitamin: Dictionary = query.get_vitamin_pill_timer_context(controller)
	_expect(vitamin.get("player_center", Vector2.ZERO) == Vector2(320.0, 700.0), "query should build vitamin context")
	var doping: Dictionary = query.get_doping_potion_context(controller)
	_expect(is_equal_approx(float(doping.get("timer_frames", 0.0)), 240.0), "query should build doping context")

	var holy_collision: Dictionary = query.get_holy_barrier_collision_context(controller)
	_expect(bool(holy_collision.get("holy_barrier_active", false)), "query should build holy barrier collision context")

	var stopwatch: Dictionary = query.get_stopwatch_ball_context(controller)
	_expect(bool(stopwatch.get("stopwatch_recovery_active", false)), "query should build stopwatch recovery context")
	_expect(is_equal_approx(float(stopwatch.get("stopwatch_recovery_speed_ratio", 0.0)), 0.5), "query should expose recovery speed ratio")

	var draw_context: Dictionary = query.get_field_effect_draw_context(controller)
	_expect(_array_size(draw_context, "pickup_particles") == 1, "query should bundle pickup particles for rendering")
	_expect(not _get_context_dictionary(draw_context, "vitamin_pill_timer_context").is_empty(), "query should bundle active vitamin context for rendering")
	_expect(not _get_context_dictionary(draw_context, "doping_potion_timer_context").is_empty(), "query should bundle active doping context for rendering")
	_expect(not _get_context_dictionary(draw_context, "holy_barrier_context").is_empty(), "query should bundle active holy barrier context for rendering")
	_expect(not _get_context_dictionary(draw_context, "stopwatch_context").is_empty(), "query should bundle active stopwatch context for rendering")
	_expect(_get_context_dictionary(draw_context, "magnet_field_context").is_empty(), "query should skip inactive magnet render context")


func _verify_controller_delegates_query_facade() -> void:
	var controller: Object = ActiveItemEffectController.new()
	controller.magnet_field_active = true
	controller.magnet_field_timer_frames = 120.0
	controller.magnet_field_initial_timer_frames = 480.0
	controller.magnet_field_player_center = Vector2(160.0, 620.0)

	var magnet: Dictionary = controller.get_magnet_field_context()
	_expect(is_equal_approx(float(magnet.get("remaining_ratio", -1.0)), 0.25), "controller should delegate magnet context through query")
	_expect(controller.is_magnet_field_active(), "controller should delegate active query through query")
	_expect(not controller.can_store_item("magnet_field"), "controller should delegate store gate through query")
	var draw_context: Dictionary = controller.get_field_effect_draw_context()
	_expect(not _get_context_dictionary(draw_context, "magnet_field_context").is_empty(), "controller should delegate render context through query")


func _array_size(context: Dictionary, key: String) -> int:
	var value: Variant = context.get(key, [])
	if value is Array:
		return value.size()
	return 0


func _get_context_dictionary(context: Dictionary, key: String) -> Dictionary:
	var value: Variant = context.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
