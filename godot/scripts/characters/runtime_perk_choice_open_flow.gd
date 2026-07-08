extends RefCounted

const MythicPerkGrantHelper := preload("res://scripts/characters/mythic_perk_grant_helper.gd")

const CALLBACK_GET_INSTANCE := "get_instance"
const CALLBACK_APPLY_CHOICE_OPENING_UPDATE := "apply_choice_opening_update"
const CALLBACK_TICK_LINGPET_RING_CORE_OFFER_COOLDOWN := "tick_lingpet_ring_core_offer_cooldown"
const CALLBACK_PAUSE_SKILL_COOLDOWNS_FOR_CHOICE := "pause_skill_cooldowns_for_choice"
const CALLBACK_BUILD_PARTICLES := "build_particles"
const DEFAULT_BASE_PERK_CHOICE_COUNT := 3


func build_state_callbacks(runtime_state: Object) -> Dictionary:
	if runtime_state == null:
		return {}
	return {
		CALLBACK_GET_INSTANCE: Callable(runtime_state, "_get_instance"),
		CALLBACK_APPLY_CHOICE_OPENING_UPDATE: Callable(runtime_state, "_apply_choice_opening_update"),
		CALLBACK_TICK_LINGPET_RING_CORE_OFFER_COOLDOWN: Callable(runtime_state, "_tick_lingpet_ring_core_offer_cooldown"),
		CALLBACK_PAUSE_SKILL_COOLDOWNS_FOR_CHOICE: Callable(runtime_state, "_pause_skill_cooldowns_for_choice"),
		CALLBACK_BUILD_PARTICLES: Callable(runtime_state, "_build_particles"),
	}


func open_next_choice_from_runtime_state(
	runtime_state: Object,
	character_type: String,
	catalog: Object,
	exclude_instant: bool = false,
	owner: Object = null,
	registry: Object = null,
	perf_logger: Object = null,
	choice_context: Dictionary = {}
) -> Dictionary:
	return open_next_choice(
		character_type,
		catalog,
		exclude_instant,
		owner,
		registry,
		perf_logger,
		choice_context,
		runtime_state,
		_get_runtime_state_object(runtime_state, "_active_unlock_flight"),
		_get_runtime_state_object(runtime_state, "_choice_opening"),
		_get_runtime_state_object(runtime_state, "_choice_offer_modifiers"),
		_get_runtime_state_object(runtime_state, "_choice_feedback"),
		build_state_callbacks(runtime_state),
		DEFAULT_BASE_PERK_CHOICE_COUNT
	)


func open_mythic_perk_choice_from_runtime_state(
	runtime_state: Object,
	count: int,
	owner: Object,
	registry: Object,
	catalog: Object = null,
	perf_logger: Object = null,
	choice_context: Dictionary = {}
) -> Dictionary:
	return open_mythic_perk_choice(
		count,
		owner,
		registry,
		catalog,
		perf_logger,
		choice_context,
		runtime_state,
		_get_runtime_state_object(runtime_state, "_active_unlock_flight"),
		_get_runtime_state_object(runtime_state, "_choice_opening"),
		_get_runtime_state_object(runtime_state, "_choice_offer_modifiers"),
		build_state_callbacks(runtime_state)
	)


func open_mythic_perk_choice(
	count: int,
	owner: Object,
	registry: Object,
	catalog: Object,
	perf_logger: Object,
	choice_context: Dictionary,
	runtime_state: Object,
	active_unlock_flight: Object,
	choice_opening: Object,
	choice_offer_modifiers: Object,
	callbacks: Dictionary
) -> Dictionary:
	if runtime_state == null or choice_opening == null:
		return {"accepted": false, "blocked_reason": "missing_mythic_open_flow_deps"}
	if active_unlock_flight != null and active_unlock_flight.has_method("reset"):
		active_unlock_flight.reset(_get_dict(runtime_state.get("choice_flight_effect")))
	var sample_start: int = _perf_begin(perf_logger)
	var generated_choices: Array = MythicPerkGrantHelper.build_mythic_choice_cards(
		max(1, count),
		owner,
		registry,
		catalog
	)
	_perf_end(perf_logger, "process.runtime_perk.open_mythic_choice.catalog", sample_start)
	if generated_choices.is_empty():
		return {"accepted": false, "blocked_reason": "empty_mythic_choices"}
	var generated_slot_status: Dictionary = {}
	if choice_offer_modifiers != null and choice_offer_modifiers.has_method("build_perk_slot_status"):
		generated_slot_status = choice_offer_modifiers.build_perk_slot_status(
			catalog,
			_get_dict(runtime_state.get("runtime_skill_levels")),
			registry
		)
	var context: Dictionary = choice_context.duplicate(true)
	if context.is_empty():
		context = build_mythic_choice_context()
	_call_dict(
		callbacks,
		CALLBACK_APPLY_CHOICE_OPENING_UPDATE,
		[
			{
				"accepted": true,
				"pending_skill_choices": int(runtime_state.get("pending_skill_choices")) + 1,
			}
		]
	)
	_call_dict(
		callbacks,
		CALLBACK_APPLY_CHOICE_OPENING_UPDATE,
		[
			choice_opening.build_generated_choices_state_update(
				context,
				generated_choices,
				generated_slot_status
			)
		]
	)
	var ready_result: Dictionary = _call_dict(
		callbacks,
		CALLBACK_APPLY_CHOICE_OPENING_UPDATE,
		[choice_opening.build_ready_state_update(_get_array(runtime_state.get("current_choices")).size())]
	)
	if bool(ready_result.get("tick_lingpet_ring_core_offer_cooldown", false)):
		_call_optional(callbacks, CALLBACK_TICK_LINGPET_RING_CORE_OFFER_COOLDOWN, [registry])
	if bool(ready_result.get("pause_skill_cooldowns", false)):
		_call_optional(callbacks, CALLBACK_PAUSE_SKILL_COOLDOWNS_FOR_CHOICE, [owner, registry])
	if bool(ready_result.get("build_particles", false)):
		sample_start = _perf_begin(perf_logger)
		_call_optional(callbacks, CALLBACK_BUILD_PARTICLES, [])
		_perf_end(perf_logger, "process.runtime_perk.open_mythic_choice.particles", sample_start)
	ready_result["choice_count"] = generated_choices.size()
	return ready_result


func build_mythic_choice_context() -> Dictionary:
	return {
		"source": "result_box_mythic_choice",
		"mythic_box_choice": true,
	}


func open_next_choice(
	character_type: String,
	catalog: Object,
	exclude_instant: bool,
	owner: Object,
	registry: Object,
	perf_logger: Object,
	choice_context: Dictionary,
	runtime_state: Object,
	active_unlock_flight: Object,
	choice_opening: Object,
	choice_offer_modifiers: Object,
	choice_feedback: Object,
	callbacks: Dictionary,
	base_choice_count: int
) -> Dictionary:
	if runtime_state == null or choice_opening == null or choice_offer_modifiers == null:
		return {"accepted": false, "blocked_reason": "missing_open_flow_deps"}
	if active_unlock_flight != null and active_unlock_flight.has_method("reset"):
		active_unlock_flight.reset(_get_dict(runtime_state.get("choice_flight_effect")))
	if int(runtime_state.get("pending_skill_choices")) <= 0:
		return _call_dict(
			callbacks,
			CALLBACK_APPLY_CHOICE_OPENING_UPDATE,
			[choice_opening.build_unavailable_state_update(true)]
		)
	if catalog == null or not catalog.has_method("get_choices"):
		return _call_dict(
			callbacks,
			CALLBACK_APPLY_CHOICE_OPENING_UPDATE,
			[choice_opening.build_unavailable_state_update(false)]
		)

	var sample_start: int = _perf_begin(perf_logger)
	var item_bonus_choice_count: int = choice_offer_modifiers.get_item_perk_choice_count_bonus(
		owner,
		registry,
		_get_callback(callbacks, CALLBACK_GET_INSTANCE)
	)
	_perf_end(perf_logger, "process.runtime_perk.open_next_choice.item_bonus", sample_start)
	var target_choice_count: int = choice_offer_modifiers.build_target_choice_count(
		base_choice_count,
		item_bonus_choice_count
	)
	sample_start = _perf_begin(perf_logger)
	var generated_choices: Array = catalog.get_choices(
		character_type,
		_get_dict(runtime_state.get("runtime_skill_levels")),
		exclude_instant,
		target_choice_count,
		owner,
		registry
	)
	var generated_slot_status: Dictionary = choice_offer_modifiers.build_perk_slot_status(
		catalog,
		_get_dict(runtime_state.get("runtime_skill_levels")),
		registry
	)
	_call_dict(
		callbacks,
		CALLBACK_APPLY_CHOICE_OPENING_UPDATE,
		[
			choice_opening.build_generated_choices_state_update(
				choice_context,
				generated_choices,
				generated_slot_status
			)
		]
	)
	_perf_end(perf_logger, "process.runtime_perk.open_next_choice.catalog", sample_start)
	var current_choices: Array = _get_array(runtime_state.get("current_choices"))
	if current_choices.is_empty():
		var empty_choices_result: Dictionary = _call_dict(
			callbacks,
			CALLBACK_APPLY_CHOICE_OPENING_UPDATE,
			[choice_opening.build_empty_choices_state_update(int(runtime_state.get("pending_skill_choices")))]
		)
		if bool(empty_choices_result.get("open_next_choice", false)):
			return open_next_choice(
				character_type,
				catalog,
				exclude_instant,
				owner,
				registry,
				perf_logger,
				_get_dict(runtime_state.get("current_choice_context")),
				runtime_state,
				active_unlock_flight,
				choice_opening,
				choice_offer_modifiers,
				choice_feedback,
				callbacks,
				base_choice_count
			)
		return empty_choices_result
	var bonus_choice_update: Dictionary = choice_offer_modifiers.build_dowsing_bonus_state_update(
		current_choices,
		item_bonus_choice_count,
		target_choice_count
	)
	if bool(bonus_choice_update.get("accepted", false)):
		_call_dict(callbacks, CALLBACK_APPLY_CHOICE_OPENING_UPDATE, [bonus_choice_update])
		if choice_feedback != null:
			choice_feedback.apply_dowsing_goggles_bonus_feedback_state_update(
				runtime_state,
				float(runtime_state.get("feedback_timer"))
			)

	var ready_result: Dictionary = _call_dict(
		callbacks,
		CALLBACK_APPLY_CHOICE_OPENING_UPDATE,
		[choice_opening.build_ready_state_update(_get_array(runtime_state.get("current_choices")).size())]
	)
	if bool(ready_result.get("tick_lingpet_ring_core_offer_cooldown", false)):
		_call_optional(callbacks, CALLBACK_TICK_LINGPET_RING_CORE_OFFER_COOLDOWN, [registry])
	if bool(ready_result.get("pause_skill_cooldowns", false)):
		_call_optional(callbacks, CALLBACK_PAUSE_SKILL_COOLDOWNS_FOR_CHOICE, [owner, registry])
	if bool(ready_result.get("build_particles", false)):
		sample_start = _perf_begin(perf_logger)
		_call_optional(callbacks, CALLBACK_BUILD_PARTICLES, [])
		_perf_end(perf_logger, "process.runtime_perk.open_next_choice.particles", sample_start)
	return ready_result


func _call_optional(callbacks: Dictionary, key: String, args: Array) -> Dictionary:
	var callback := _get_callback(callbacks, key)
	if not callback.is_valid():
		return {"accepted": false, "blocked_reason": "missing_%s" % key}
	var result: Variant = callback.callv(args)
	if result is Dictionary:
		if result.has("accepted"):
			return result
		result["accepted"] = true
		return result
	return {"accepted": true}


func _call_dict(callbacks: Dictionary, key: String, args: Array) -> Dictionary:
	var callback := _get_callback(callbacks, key)
	if not callback.is_valid():
		return {"accepted": false, "blocked_reason": "missing_%s" % key}
	var result: Variant = callback.callv(args)
	if result is Dictionary:
		return result
	return {"accepted": false, "blocked_reason": "invalid_%s" % key}


func _get_callback(callbacks: Dictionary, key: String) -> Callable:
	var value: Variant = callbacks.get(key, Callable())
	if value is Callable:
		return value
	return Callable()


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_runtime_state_object(runtime_state: Object, key: String) -> Object:
	if runtime_state == null:
		return null
	var value: Variant = runtime_state.get(key)
	if value is Object:
		return value
	return null
