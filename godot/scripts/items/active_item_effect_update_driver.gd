extends RefCounted

const IDLE_PADDLE_SYNC_REFRESH_FRAMES := 30

var _state_applier: Object
var _paddle_sync: Object
var _player_center_reader: Object
var _aipill_runtime: Object
var _stopwatch_runtime: Object
var _stopwatch_owner_effects: Object
var _magnet_field_runtime: Object
var _magnet_field_particles: Object
var _timed_paddle_effects: Object
var _holy_barrier_runtime: Object
var _holy_barrier_particles: Object
var _dash_boost_runtime: Object
var _dash_boost_particles: Object
var _brick_wall_installation: Object
var _brick_wall_particles: Object
var _trampoline_runtime: Object
var _transient_effect_updater: Object
var _regeneration_potion_effect: Object
var _pickup_effect_state: Object
var _commando_supply_actions: Object
var _last_paddle_sync_active_item_scale := -1.0
var _last_paddle_sync_frame := -1
var _last_paddle_sync_owner_id := 0


func configure(deps: Dictionary) -> void:
	_state_applier = deps.get("state_applier")
	_paddle_sync = deps.get("paddle_sync")
	_player_center_reader = deps.get("player_center_reader")
	_aipill_runtime = deps.get("aipill_runtime")
	_stopwatch_runtime = deps.get("stopwatch_runtime")
	_stopwatch_owner_effects = deps.get("stopwatch_owner_effects")
	_magnet_field_runtime = deps.get("magnet_field_runtime")
	_magnet_field_particles = deps.get("magnet_field_particles")
	_timed_paddle_effects = deps.get("timed_paddle_effects")
	_holy_barrier_runtime = deps.get("holy_barrier_runtime")
	_holy_barrier_particles = deps.get("holy_barrier_particles")
	_dash_boost_runtime = deps.get("dash_boost_runtime")
	_dash_boost_particles = deps.get("dash_boost_particles")
	_brick_wall_installation = deps.get("brick_wall_installation")
	_brick_wall_particles = deps.get("brick_wall_particles")
	_trampoline_runtime = deps.get("trampoline_runtime")
	_transient_effect_updater = deps.get("transient_effect_updater")
	_regeneration_potion_effect = deps.get("regeneration_potion_effect")
	_pickup_effect_state = deps.get("pickup_effect_state")
	_commando_supply_actions = deps.get("commando_supply_actions")
	_last_paddle_sync_active_item_scale = -1.0
	_last_paddle_sync_frame = -1
	_last_paddle_sync_owner_id = 0


func apply_update(
	target: Object,
	owner: Object,
	delta: float,
	warp_gate_state: Object = null,
	mythic_item_runtime: Object = null,
	perf_logger: Object = null
) -> void:
	var detail_perf_logger: Object = _detail_perf_logger(perf_logger, "active_item.effects.update")
	var sample_start := 0
	if _should_update_aipill(target):
		sample_start = _perf_begin(detail_perf_logger)
		_update_aipill(target, owner, delta, mythic_item_runtime)
		_perf_end(detail_perf_logger, "physics.callback.active_items.aipill", sample_start)
	if _should_update_stopwatch(target):
		sample_start = _perf_begin(detail_perf_logger)
		_update_stopwatch(target, owner, delta)
		_perf_end(detail_perf_logger, "physics.callback.active_items.stopwatch", sample_start)
	if _should_update_magnet_field(target):
		sample_start = _perf_begin(detail_perf_logger)
		_update_magnet_field(target, owner, delta)
		_perf_end(detail_perf_logger, "physics.callback.active_items.magnet_field", sample_start)
	if _should_update_long_boost(target):
		sample_start = _perf_begin(detail_perf_logger)
		_update_long_boost(target, delta)
		_perf_end(detail_perf_logger, "physics.callback.active_items.long_boost", sample_start)
	if _should_update_vitamin_pill(target):
		sample_start = _perf_begin(detail_perf_logger)
		_update_vitamin_pill(target, owner, delta)
		_perf_end(detail_perf_logger, "physics.callback.active_items.vitamin_pill", sample_start)
	if _should_update_strange_vial(target):
		sample_start = _perf_begin(detail_perf_logger)
		_update_strange_vial(target, owner, delta)
		_perf_end(detail_perf_logger, "physics.callback.active_items.strange_vial", sample_start)
	if _should_update_doping_potion(target):
		sample_start = _perf_begin(detail_perf_logger)
		_update_doping_potion(target, owner, delta)
		_perf_end(detail_perf_logger, "physics.callback.active_items.doping_potion", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_sync_paddle_owner_state(target, owner, warp_gate_state, mythic_item_runtime)
	_perf_end(detail_perf_logger, "physics.callback.active_items.paddle_sync", sample_start)
	if _should_update_holy_barrier(target):
		sample_start = _perf_begin(detail_perf_logger)
		_update_holy_barrier(target, delta)
		_perf_end(detail_perf_logger, "physics.callback.active_items.holy_barrier", sample_start)
	if _should_update_dash_boost(target):
		sample_start = _perf_begin(detail_perf_logger)
		_update_dash_boost(target, owner, delta)
		_perf_end(detail_perf_logger, "physics.callback.active_items.dash_boost", sample_start)
	if _should_update_brick_wall(target):
		sample_start = _perf_begin(detail_perf_logger)
		_update_brick_wall_installation(target, delta)
		_perf_end(detail_perf_logger, "physics.callback.active_items.brick_wall", sample_start)
	if _should_update_trampolines(target):
		sample_start = _perf_begin(detail_perf_logger)
		_update_trampolines(target, delta)
		_perf_end(detail_perf_logger, "physics.callback.active_items.trampoline", sample_start)
	if _should_update_transient_effects(target):
		sample_start = _perf_begin(detail_perf_logger)
		_update_transient_effects(target, delta)
		_perf_end(detail_perf_logger, "physics.callback.active_items.transient_effects", sample_start)


func _update_aipill(
	target: Object,
	owner: Object,
	delta: float,
	mythic_item_runtime: Object = null
) -> void:
	if (
		target.has_method("cancel_aipill_if_neural_helmet_direction_pressed")
		and bool(target.cancel_aipill_if_neural_helmet_direction_pressed(mythic_item_runtime, _is_direction_input_pressed()))
	):
		return
	_aipill_runtime.apply_update(
		target,
		owner,
		_get_bool_property(target, "aipill_active"),
		_get_float_property(target, "aipill_phase", 0.0),
		_get_float_property(target, "aipill_flash_timer_frames", 0.0),
		delta,
		_state_applier
	)


func _is_direction_input_pressed() -> bool:
	return (
		Input.is_action_pressed("ui_left")
		or Input.is_action_pressed("ui_right")
		or Input.is_action_pressed("ui_up")
		or Input.is_action_pressed("ui_down")
		or Input.is_key_pressed(KEY_A)
		or Input.is_key_pressed(KEY_D)
		or Input.is_key_pressed(KEY_W)
		or Input.is_key_pressed(KEY_S)
		or Input.is_key_pressed(KEY_LEFT)
		or Input.is_key_pressed(KEY_RIGHT)
		or Input.is_key_pressed(KEY_UP)
		or Input.is_key_pressed(KEY_DOWN)
	)


func _update_stopwatch(target: Object, owner: Object, delta: float) -> void:
	_stopwatch_runtime.apply_update(
		target,
		owner,
		_get_bool_property(target, "stopwatch_active"),
		_get_float_property(target, "stopwatch_timer_frames", 0.0),
		_get_float_property(target, "stopwatch_initial_timer_frames", 0.0),
		_get_float_property(target, "stopwatch_recovery_timer_frames", 0.0),
		_get_float_property(target, "stopwatch_post_recovery_grace_frames", 0.0),
		_get_vector2_property(target, "stopwatch_original_ball_vel"),
		_get_float_property(target, "stopwatch_flash_timer_frames", 0.0),
		_get_float_property(target, "stopwatch_clock_angle", 0.0),
		delta,
		_state_applier,
		_stopwatch_owner_effects
	)


func _update_magnet_field(target: Object, owner: Object, delta: float) -> void:
	_magnet_field_runtime.apply_update(
		target,
		target.get("magnet_field_particles"),
		_get_bool_property(target, "magnet_field_active"),
		_get_float_property(target, "magnet_field_timer_frames", 0.0),
		_get_float_property(target, "magnet_field_initial_timer_frames", 0.0),
		_get_float_property(target, "magnet_field_phase", 0.0),
		_read_player_center(owner, _get_vector2_property(target, "magnet_field_player_center")),
		_get_float_property(target, "magnet_field_particle_accumulator_frames", 0.0),
		owner != null,
		delta,
		_state_applier,
		_magnet_field_particles
	)


func _update_long_boost(target: Object, delta: float) -> void:
	_timed_paddle_effects.apply_update_long_boost(
		target,
		_get_bool_property(target, "long_boost_active"),
		_get_float_property(target, "long_boost_timer_frames", 0.0),
		_get_float_property(target, "long_boost_initial_timer_frames", 0.0),
		delta,
		_state_applier
	)


func _update_vitamin_pill(target: Object, owner: Object, delta: float) -> void:
	_timed_paddle_effects.apply_update_vitamin_pill(
		target,
		_get_bool_property(target, "vitamin_pill_active"),
		_get_float_property(target, "vitamin_pill_timer_frames", 0.0),
		_get_float_property(target, "vitamin_pill_initial_timer_frames", 0.0),
		_get_float_property(target, "vitamin_pill_phase", 0.0),
		_get_float_property(target, "vitamin_pill_flash_timer_frames", 0.0),
		_read_player_center(owner, _get_vector2_property(target, "vitamin_pill_player_center")),
		delta,
		_state_applier
	)


func _update_strange_vial(target: Object, owner: Object, delta: float) -> void:
	_timed_paddle_effects.apply_update_strange_vial(
		target,
		_get_bool_property(target, "strange_vial_active"),
		_get_float_property(target, "strange_vial_timer_frames", 0.0),
		_get_float_property(target, "strange_vial_initial_timer_frames", 0.0),
		str(target.get("strange_vial_effect_type")),
		_get_float_property(target, "strange_vial_target_scale", 1.0),
		_get_float_property(target, "strange_vial_target_speed_multiplier", 1.0),
		_get_float_property(target, "strange_vial_phase", 0.0),
		_get_float_property(target, "strange_vial_flash_timer_frames", 0.0),
		_read_player_center(owner, _get_vector2_property(target, "strange_vial_player_center")),
		delta,
		_state_applier
	)


func _update_doping_potion(target: Object, owner: Object, delta: float) -> void:
	_commando_supply_actions.apply_update_doping_potion(
		target,
		_get_bool_property(target, "doping_potion_active"),
		_get_float_property(target, "doping_potion_timer_frames", 0.0),
		_get_float_property(target, "doping_potion_initial_timer_frames", 0.0),
		_get_float_property(target, "doping_potion_phase", 0.0),
		_get_float_property(target, "doping_potion_flash_timer_frames", 0.0),
		_read_player_center(owner, _get_vector2_property(target, "doping_potion_player_center")),
		delta,
		_state_applier
	)


func _sync_paddle_owner_state(
	target: Object,
	owner: Object,
	warp_gate_state: Object,
	mythic_item_runtime: Object
) -> void:
	if _paddle_sync == null:
		return
	var active_item_scale: float = _paddle_sync.get_player_paddle_scale(
		_get_float_property(target, "long_boost_scale", 1.0) * _get_float_property(target, "milk_bottle_scale", 1.0),
		_get_float_property(target, "strange_vial_scale", 1.0)
	)
	if not _should_sync_paddle_owner_state(target, owner, active_item_scale):
		return
	_paddle_sync.sync_owner_state(owner, active_item_scale, warp_gate_state, mythic_item_runtime)
	_last_paddle_sync_active_item_scale = active_item_scale
	_last_paddle_sync_frame = int(Engine.get_physics_frames())
	_last_paddle_sync_owner_id = owner.get_instance_id() if owner != null else 0


func _should_sync_paddle_owner_state(target: Object, owner: Object, active_item_scale: float) -> bool:
	if _has_paddle_scale_runtime_work(target):
		return true
	var owner_id := owner.get_instance_id() if owner != null else 0
	if owner_id != _last_paddle_sync_owner_id:
		return true
	if _last_paddle_sync_frame < 0:
		return true
	if not is_equal_approx(active_item_scale, _last_paddle_sync_active_item_scale):
		return true
	var frame_key := int(Engine.get_physics_frames())
	return frame_key - _last_paddle_sync_frame >= IDLE_PADDLE_SYNC_REFRESH_FRAMES


func _has_paddle_scale_runtime_work(target: Object) -> bool:
	return (
		_get_bool_property(target, "long_boost_active")
		or _get_float_property(target, "long_boost_timer_frames", 0.0) > 0.0
		or not is_equal_approx(_get_float_property(target, "long_boost_scale", 1.0), 1.0)
		or _get_bool_property(target, "milk_bottle_active")
		or not is_equal_approx(_get_float_property(target, "milk_bottle_scale", 1.0), 1.0)
		or _get_bool_property(target, "strange_vial_active")
		or _get_float_property(target, "strange_vial_timer_frames", 0.0) > 0.0
		or not is_equal_approx(_get_float_property(target, "strange_vial_scale", 1.0), 1.0)
	)


func _update_holy_barrier(target: Object, delta: float) -> void:
	_holy_barrier_runtime.apply_update(
		target,
		target.get("holy_barrier_particles"),
		_get_bool_property(target, "holy_barrier_active"),
		_get_float_property(target, "holy_barrier_timer_frames", 0.0),
		_get_float_property(target, "holy_barrier_initial_timer_frames", 0.0),
		_get_float_property(target, "holy_barrier_glow_phase", 0.0),
		_get_float_property(target, "holy_barrier_particle_accumulator_frames", 0.0),
		delta,
		_state_applier,
		_holy_barrier_particles
	)


func _update_dash_boost(target: Object, owner: Object, delta: float) -> void:
	_dash_boost_runtime.apply_update(
		target,
		target.get("dash_boost_particles"),
		_get_bool_property(target, "dash_boost_active"),
		_get_float_property(target, "dash_boost_timer_frames", 0.0),
		_get_float_property(target, "dash_boost_initial_timer_frames", 0.0),
		_get_float_property(target, "dash_boost_glow_phase", 0.0),
		_get_float_property(target, "dash_boost_particle_accumulator_frames", 0.0),
		_read_player_center(owner, _get_vector2_property(target, "dash_boost_player_center")),
		delta,
		_state_applier,
		_dash_boost_particles
	)


func _update_brick_wall_installation(target: Object, delta: float) -> void:
	_brick_wall_installation.apply_update(
		target,
		_get_bool_property(target, "brick_wall_installing"),
		_get_float_property(target, "brick_wall_install_timer_frames", 0.0),
		_get_float_property(target, "brick_wall_install_initial_frames", 0.0),
		_get_dictionary_property(target, "pending_brick_wall"),
		target.get("brick_walls"),
		target.get("brick_particles"),
		delta,
		_state_applier,
		_brick_wall_particles
	)


func _update_trampolines(target: Object, delta: float) -> void:
	if _trampoline_runtime == null:
		return
	_trampoline_runtime.update_animations(
		target.get("trampolines"),
		target.get("trampoline_particles"),
		delta
	)


func _update_transient_effects(target: Object, delta: float) -> void:
	_transient_effect_updater.apply_update(
		target.get("brick_particles"),
		target.get("regeneration_potion_particles"),
		target.get("regeneration_potion_rings"),
		target.get("pickup_particles"),
		_get_dictionary_property(target, "pickup_effect"),
		delta,
		_brick_wall_particles,
		_regeneration_potion_effect,
		_pickup_effect_state
	)


func _read_player_center(owner: Object, fallback: Vector2) -> Vector2:
	if owner == null:
		return fallback
	return _player_center_reader.get_player_center(owner)


func _get_dictionary_property(target: Object, key: String) -> Dictionary:
	var value: Variant = target.get(key)
	if value is Dictionary:
		return value
	return {}


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


func _get_bool_property(target: Object, key: String, fallback := false) -> bool:
	var value: Variant = target.get(key)
	if value == null:
		return fallback
	return bool(value)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _detail_perf_logger(perf_logger: Object, label: String) -> Object:
	if perf_logger == null:
		return null
	if perf_logger.has_method("should_sample_detail"):
		return perf_logger if bool(perf_logger.should_sample_detail(label)) else null
	return perf_logger


func _should_update_aipill(target: Object) -> bool:
	return _get_bool_property(target, "aipill_active") or _get_float_property(target, "aipill_flash_timer_frames", 0.0) > 0.0


func _should_update_stopwatch(target: Object) -> bool:
	return (
		_get_bool_property(target, "stopwatch_active")
		or _get_float_property(target, "stopwatch_timer_frames", 0.0) > 0.0
		or _get_float_property(target, "stopwatch_recovery_timer_frames", 0.0) > 0.0
		or _get_float_property(target, "stopwatch_post_recovery_grace_frames", 0.0) > 0.0
		or _get_float_property(target, "stopwatch_flash_timer_frames", 0.0) > 0.0
	)


func _should_update_magnet_field(target: Object) -> bool:
	return (
		_get_bool_property(target, "magnet_field_active")
		or _get_float_property(target, "magnet_field_timer_frames", 0.0) > 0.0
		or _has_array_items(target.get("magnet_field_particles"))
	)


func _should_update_long_boost(target: Object) -> bool:
	return (
		_get_bool_property(target, "long_boost_active")
		or _get_float_property(target, "long_boost_timer_frames", 0.0) > 0.0
		or not is_equal_approx(_get_float_property(target, "long_boost_scale", 1.0), 1.0)
	)


func _should_update_vitamin_pill(target: Object) -> bool:
	return (
		_get_bool_property(target, "vitamin_pill_active")
		or _get_float_property(target, "vitamin_pill_timer_frames", 0.0) > 0.0
		or _get_float_property(target, "vitamin_pill_flash_timer_frames", 0.0) > 0.0
	)


func _should_update_strange_vial(target: Object) -> bool:
	return (
		_get_bool_property(target, "strange_vial_active")
		or _get_float_property(target, "strange_vial_timer_frames", 0.0) > 0.0
		or _get_float_property(target, "strange_vial_flash_timer_frames", 0.0) > 0.0
		or not is_equal_approx(_get_float_property(target, "strange_vial_scale", 1.0), 1.0)
		or not is_equal_approx(_get_float_property(target, "strange_vial_speed_multiplier", 1.0), 1.0)
	)


func _should_update_doping_potion(target: Object) -> bool:
	return (
		_get_bool_property(target, "doping_potion_active")
		or _get_float_property(target, "doping_potion_timer_frames", 0.0) > 0.0
		or _get_float_property(target, "doping_potion_flash_timer_frames", 0.0) > 0.0
	)


func _should_update_holy_barrier(target: Object) -> bool:
	return (
		_get_bool_property(target, "holy_barrier_active")
		or _get_float_property(target, "holy_barrier_timer_frames", 0.0) > 0.0
		or _has_array_items(target.get("holy_barrier_particles"))
	)


func _should_update_dash_boost(target: Object) -> bool:
	return (
		_get_bool_property(target, "dash_boost_active")
		or _get_float_property(target, "dash_boost_timer_frames", 0.0) > 0.0
		or _has_array_items(target.get("dash_boost_particles"))
	)


func _should_update_brick_wall(target: Object) -> bool:
	return (
		_get_bool_property(target, "brick_wall_installing")
		or _get_float_property(target, "brick_wall_install_timer_frames", 0.0) > 0.0
		or not _get_dictionary_property(target, "pending_brick_wall").is_empty()
	)


func _should_update_trampolines(target: Object) -> bool:
	return (
		_has_array_items(target.get("trampolines"))
		or _has_array_items(target.get("trampoline_particles"))
	)


func _should_update_transient_effects(target: Object) -> bool:
	return (
		_has_array_items(target.get("brick_particles"))
		or _has_array_items(target.get("regeneration_potion_particles"))
		or _has_array_items(target.get("regeneration_potion_rings"))
		or _has_array_items(target.get("pickup_particles"))
		or not _get_dictionary_property(target, "pickup_effect").is_empty()
	)


func _has_array_items(value: Variant) -> bool:
	if not (value is Array):
		return false
	return not (value as Array).is_empty()
