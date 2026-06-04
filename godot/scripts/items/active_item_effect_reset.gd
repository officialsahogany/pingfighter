extends RefCounted


func apply(
	target: Object,
	state_applier: Object,
	aipill_runtime: Object,
	timed_paddle_effects: Object,
	stopwatch_runtime: Object,
	magnet_field_runtime: Object,
	holy_barrier_runtime: Object,
	dash_boost_runtime: Object,
	brick_wall_installation: Object,
	commando_supply_actions: Object
) -> void:
	_clear_array(target, "regeneration_potion_particles")
	_clear_array(target, "regeneration_potion_rings")
	_clear_array(target, "holy_barrier_particles")
	_clear_array(target, "dash_boost_particles")
	_clear_array(target, "pickup_particles")
	_clear_dictionary(target, "pickup_effect")

	state_applier.apply_aipill_state(target, aipill_runtime.clear_state())
	state_applier.apply_long_boost_state(target, timed_paddle_effects.clear_long_boost())
	target.set("milk_bottle_active", false)
	target.set("milk_bottle_scale", 1.0)
	state_applier.apply_vitamin_pill_state(target, timed_paddle_effects.clear_vitamin_pill())
	state_applier.apply_strange_vial_state(target, timed_paddle_effects.clear_strange_vial())
	state_applier.apply_doping_potion_state(target, commando_supply_actions.clear_doping_potion(
		timed_paddle_effects.get_default_player_center(),
		int(target.get("doping_potion_use_count"))
	))
	state_applier.apply_stopwatch_state(target, stopwatch_runtime.clear_state(float(target.get("stopwatch_clock_angle"))))
	target.set("stopwatch_clock_angle", 0.0)
	state_applier.apply_magnet_field_state(target, magnet_field_runtime.clear_state(timed_paddle_effects.get_default_player_center()))
	state_applier.apply_holy_barrier_state(target, holy_barrier_runtime.clear_state())
	state_applier.apply_dash_boost_state(target, dash_boost_runtime.clear_state())
	_clear_array(target, "brick_walls")
	state_applier.apply_brick_wall_installation_state(target, brick_wall_installation.clear_installation())
	_clear_array(target, "brick_particles")


func _clear_array(target: Object, key: String) -> void:
	var value: Variant = target.get(key)
	if value is Array:
		value.clear()


func _clear_dictionary(target: Object, key: String) -> void:
	var value: Variant = target.get(key)
	if value is Dictionary:
		value.clear()
