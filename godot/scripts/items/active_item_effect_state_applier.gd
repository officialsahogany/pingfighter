extends RefCounted


func apply_aipill_state(target: Object, state: Dictionary) -> void:
	target.set("aipill_active", bool(state.get("active", false)))
	target.set("aipill_phase", float(state.get("phase", 0.0)))
	target.set("aipill_flash_timer_frames", float(state.get("flash_timer_frames", 0.0)))


func apply_long_boost_state(target: Object, state: Dictionary) -> void:
	target.set("long_boost_active", bool(state.get("active", false)))
	target.set("long_boost_timer_frames", float(state.get("timer_frames", 0.0)))
	target.set("long_boost_initial_timer_frames", float(state.get("initial_timer_frames", 0.0)))
	target.set("long_boost_scale", float(state.get("scale", 1.0)))


func apply_vitamin_pill_state(target: Object, state: Dictionary) -> void:
	target.set("vitamin_pill_active", bool(state.get("active", false)))
	target.set("vitamin_pill_timer_frames", float(state.get("timer_frames", 0.0)))
	target.set("vitamin_pill_initial_timer_frames", float(state.get("initial_timer_frames", 0.0)))
	target.set("vitamin_pill_phase", float(state.get("phase", 0.0)))
	target.set("vitamin_pill_flash_timer_frames", float(state.get("flash_timer_frames", 0.0)))
	target.set("vitamin_pill_player_center", _get_vector2(state, "player_center", _get_vector2_property(target, "vitamin_pill_player_center")))


func apply_strange_vial_state(target: Object, state: Dictionary) -> void:
	target.set("strange_vial_active", bool(state.get("active", false)))
	target.set("strange_vial_timer_frames", float(state.get("timer_frames", 0.0)))
	target.set("strange_vial_initial_timer_frames", float(state.get("initial_timer_frames", 0.0)))
	target.set("strange_vial_effect_type", str(state.get("effect_type", "")))
	target.set("strange_vial_scale", float(state.get("scale", 1.0)))
	target.set("strange_vial_target_scale", float(state.get("target_scale", 1.0)))
	target.set("strange_vial_speed_multiplier", float(state.get("speed_multiplier", 1.0)))
	target.set("strange_vial_target_speed_multiplier", float(state.get("target_speed_multiplier", 1.0)))
	target.set("strange_vial_phase", float(state.get("phase", 0.0)))
	target.set("strange_vial_flash_timer_frames", float(state.get("flash_timer_frames", 0.0)))
	target.set("strange_vial_player_center", _get_vector2(state, "player_center", _get_vector2_property(target, "strange_vial_player_center")))


func apply_doping_potion_state(target: Object, state: Dictionary) -> void:
	target.set("doping_potion_active", bool(state.get("active", false)))
	target.set("doping_potion_timer_frames", float(state.get("timer_frames", 0.0)))
	target.set("doping_potion_initial_timer_frames", float(state.get("initial_timer_frames", 0.0)))
	target.set("doping_potion_phase", float(state.get("phase", 0.0)))
	target.set("doping_potion_flash_timer_frames", float(state.get("flash_timer_frames", 0.0)))
	target.set("doping_potion_player_center", _get_vector2(state, "player_center", _get_vector2_property(target, "doping_potion_player_center")))
	target.set("doping_potion_use_count", max(0, int(state.get("use_count", 0))))


func apply_stopwatch_state(target: Object, state: Dictionary) -> void:
	target.set("stopwatch_active", bool(state.get("active", false)))
	target.set("stopwatch_timer_frames", float(state.get("timer_frames", 0.0)))
	target.set("stopwatch_initial_timer_frames", float(state.get("initial_timer_frames", 0.0)))
	target.set("stopwatch_recovery_timer_frames", float(state.get("recovery_timer_frames", 0.0)))
	target.set("stopwatch_post_recovery_grace_frames", float(state.get("post_recovery_grace_frames", 0.0)))
	target.set("stopwatch_original_ball_vel", _get_vector2(state, "original_ball_vel", Vector2.ZERO))
	target.set("stopwatch_flash_timer_frames", float(state.get("flash_timer_frames", 0.0)))
	target.set("stopwatch_clock_angle", float(state.get("clock_angle", 0.0)))


func apply_magnet_field_state(target: Object, state: Dictionary) -> void:
	target.set("magnet_field_active", bool(state.get("active", false)))
	target.set("magnet_field_timer_frames", float(state.get("timer_frames", 0.0)))
	target.set("magnet_field_initial_timer_frames", float(state.get("initial_timer_frames", 0.0)))
	target.set("magnet_field_phase", float(state.get("phase", 0.0)))
	target.set("magnet_field_player_center", _get_vector2(state, "player_center", _get_vector2_property(target, "magnet_field_player_center")))
	target.set("magnet_field_particle_accumulator_frames", float(state.get("particle_accumulator_frames", 0.0)))
	if bool(state.get("clear_particles", false)):
		_clear_array_property(target, "magnet_field_particles")


func apply_holy_barrier_state(target: Object, state: Dictionary) -> void:
	target.set("holy_barrier_active", bool(state.get("active", false)))
	target.set("holy_barrier_timer_frames", float(state.get("timer_frames", 0.0)))
	target.set("holy_barrier_initial_timer_frames", float(state.get("initial_timer_frames", 0.0)))
	target.set("holy_barrier_glow_phase", float(state.get("glow_phase", 0.0)))
	target.set("holy_barrier_particle_accumulator_frames", float(state.get("particle_accumulator_frames", 0.0)))
	if bool(state.get("clear_particles", false)):
		_clear_array_property(target, "holy_barrier_particles")


func apply_dash_boost_state(target: Object, state: Dictionary) -> void:
	target.set("dash_boost_active", bool(state.get("active", false)))
	target.set("dash_boost_timer_frames", float(state.get("timer_frames", 0.0)))
	target.set("dash_boost_initial_timer_frames", float(state.get("initial_timer_frames", 0.0)))
	target.set("dash_boost_glow_phase", float(state.get("glow_phase", 0.0)))
	target.set("dash_boost_particle_accumulator_frames", float(state.get("particle_accumulator_frames", 0.0)))
	target.set("dash_boost_player_center", _get_vector2(state, "player_center", _get_vector2_property(target, "dash_boost_player_center")))
	if bool(state.get("clear_particles", false)):
		_clear_array_property(target, "dash_boost_particles")


func apply_brick_wall_installation_state(target: Object, state: Dictionary) -> void:
	target.set("brick_wall_installing", bool(state.get("installing", false)))
	target.set("brick_wall_install_timer_frames", float(state.get("timer_frames", 0.0)))
	target.set("brick_wall_install_initial_frames", float(state.get("initial_frames", 0.0)))
	target.set("pending_brick_wall", _get_dictionary(state, "pending_wall"))


func _clear_array_property(target: Object, key: String) -> void:
	var value: Variant = target.get(key)
	if value is Array:
		value.clear()


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_vector2_property(target: Object, key: String) -> Vector2:
	var value: Variant = target.get(key)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_float_property(target: Object, key: String, fallback: float) -> float:
	var value: Variant = target.get(key)
	if value == null:
		return fallback
	return float(value)
