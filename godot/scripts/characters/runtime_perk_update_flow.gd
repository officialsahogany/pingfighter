extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const RuntimePerkCallbackMap := preload("res://scripts/characters/runtime_perk_callback_map.gd")

const CALLBACK_IS_CHOICE_FLIGHT_ACTIVE := "is_choice_flight_active"
const CALLBACK_UPDATE_CHOICE_FLIGHT_EFFECT := "update_choice_flight_effect"
const CALLBACK_IS_UNLOCK_SHOWCASE_ACTIVE := "is_unlock_showcase_active"
const CALLBACK_UPDATE_UNLOCK_SHOWCASE := "update_unlock_showcase"
const CALLBACK_IS_STARPOINT_ABSORPTION_ACTIVE := "is_starpoint_absorption_active"
const CALLBACK_UPDATE_STARPOINT_ABSORPTION_EFFECT := "update_starpoint_absorption_effect"
const CALLBACK_APPLY_CHOICE_OPENING_UPDATE := "apply_choice_opening_update"
const DEFAULT_PARTICLE_LIFE := 1.45


func build_state_callbacks(runtime_state: Object) -> Dictionary:
	if runtime_state == null:
		return {}
	return {
		CALLBACK_IS_CHOICE_FLIGHT_ACTIVE: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "is_choice_flight_active"),
		CALLBACK_UPDATE_CHOICE_FLIGHT_EFFECT: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_update_choice_flight_effect"),
		CALLBACK_IS_UNLOCK_SHOWCASE_ACTIVE: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "is_unlock_showcase_active"),
		CALLBACK_UPDATE_UNLOCK_SHOWCASE: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_update_unlock_showcase"),
		CALLBACK_IS_STARPOINT_ABSORPTION_ACTIVE: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "is_starpoint_absorption_active"),
		CALLBACK_UPDATE_STARPOINT_ABSORPTION_EFFECT: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_update_starpoint_absorption_effect"),
		CALLBACK_APPLY_CHOICE_OPENING_UPDATE: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_apply_choice_opening_update"),
	}


func update_internal_from_runtime_state(
	delta: float,
	view_size: Vector2,
	owner: Object,
	registry: Object,
	runtime_state: Object,
	perf_logger: Object = null
) -> Dictionary:
	return update_internal(
		delta,
		view_size,
		owner,
		registry,
		runtime_state,
		build_update_context(
			RuntimePerkRuntimeStateAccess.get_string(runtime_state, "feedback_text"),
			RuntimePerkRuntimeStateAccess.get_float(runtime_state, "feedback_timer"),
			DEFAULT_PARTICLE_LIFE
		),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_feedback"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_opening"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_layout"),
		build_state_callbacks(runtime_state),
		perf_logger
	)


func build_update_context(
	feedback_text: String,
	feedback_timer: float,
	particle_life: float
) -> Dictionary:
	return {
		"feedback_text": feedback_text,
		"feedback_timer": feedback_timer,
		"particle_life": particle_life,
	}


func update_internal(
	delta: float,
	view_size: Vector2,
	owner: Object,
	registry: Object,
	runtime_state: Object,
	update_context: Dictionary,
	choice_feedback: Object,
	choice_opening: Object,
	choice_layout: Object,
	callbacks: Dictionary,
	perf_logger: Object = null
) -> Dictionary:
	if runtime_state == null or choice_feedback == null or choice_opening == null or choice_layout == null:
		return {"accepted": false, "blocked_reason": "missing_update_flow_deps"}
	var sample_start: int = _perf_begin(perf_logger)
	choice_feedback.apply_tick_feedback_state_update(
		runtime_state,
		str(update_context.get("feedback_text", "")),
		float(update_context.get("feedback_timer", 0.0)),
		delta
	)
	_perf_end(perf_logger, "process.runtime_perk.feedback", sample_start)
	sample_start = _perf_begin(perf_logger)
	if RuntimePerkCallbackMap.call_bool(callbacks, CALLBACK_IS_CHOICE_FLIGHT_ACTIVE, [], false):
		RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_UPDATE_CHOICE_FLIGHT_EFFECT, [delta, owner, registry, perf_logger])
	_perf_end(perf_logger, "process.runtime_perk.flight", sample_start)
	sample_start = _perf_begin(perf_logger)
	if RuntimePerkCallbackMap.call_bool(callbacks, CALLBACK_IS_UNLOCK_SHOWCASE_ACTIVE, [], false):
		RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_UPDATE_UNLOCK_SHOWCASE, [delta, owner, registry, perf_logger])
	_perf_end(perf_logger, "process.runtime_perk.unlock_showcase", sample_start)
	sample_start = _perf_begin(perf_logger)
	if RuntimePerkCallbackMap.call_bool(callbacks, CALLBACK_IS_STARPOINT_ABSORPTION_ACTIVE, [], false):
		RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_UPDATE_STARPOINT_ABSORPTION_EFFECT, [delta, view_size, owner, registry])
	_perf_end(perf_logger, "process.runtime_perk.starpoint_absorption", sample_start)
	sample_start = _perf_begin(perf_logger)
	var active_animation_time := RuntimePerkRuntimeStateAccess.get_float(runtime_state, "animation_time")
	var active_choice_active := RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "choice_active")
	var active_tick_result: Dictionary = RuntimePerkCallbackMap.call_dict(
		callbacks,
		CALLBACK_APPLY_CHOICE_OPENING_UPDATE,
		[
			choice_opening.build_active_tick_state_update(
				active_animation_time,
				delta,
				active_choice_active
			)
		]
	)
	if not bool(active_tick_result.get("accepted", false)):
		_perf_end(perf_logger, "process.runtime_perk.active_gate", sample_start)
		return active_tick_result
	_perf_end(perf_logger, "process.runtime_perk.active_gate", sample_start)
	sample_start = _perf_begin(perf_logger)
	if bool(active_tick_result.get("update_particles", false)):
		choice_layout.update_particles(
			RuntimePerkRuntimeStateAccess.get_array(runtime_state, "particles"),
			delta,
			view_size,
			float(update_context.get("particle_life", 0.0))
		)
	_perf_end(perf_logger, "process.runtime_perk.particles", sample_start)
	return {
		"accepted": true,
		"updated_particles": bool(active_tick_result.get("update_particles", false)),
	}


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
