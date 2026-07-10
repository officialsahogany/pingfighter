extends RefCounted

const MythicPerkGrantHelper := preload("res://scripts/characters/mythic_perk_grant_helper.gd")
const RuntimePerkCallbackMap := preload("res://scripts/characters/runtime_perk_callback_map.gd")
const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

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
		CALLBACK_GET_INSTANCE: RuntimePerkRuntimeStateAccess.build_callable(
			runtime_state,
			"_get_instance"
		),
		CALLBACK_APPLY_CHOICE_OPENING_UPDATE: RuntimePerkRuntimeStateAccess.build_callable(
			runtime_state,
			"_apply_choice_opening_update"
		),
		CALLBACK_TICK_LINGPET_RING_CORE_OFFER_COOLDOWN: RuntimePerkRuntimeStateAccess.build_callable(
			runtime_state,
			"_tick_lingpet_ring_core_offer_cooldown"
		),
		CALLBACK_PAUSE_SKILL_COOLDOWNS_FOR_CHOICE: RuntimePerkRuntimeStateAccess.build_callable(
			runtime_state,
			"_pause_skill_cooldowns_for_choice"
		),
		CALLBACK_BUILD_PARTICLES: RuntimePerkRuntimeStateAccess.build_callable(
			runtime_state,
			"_build_particles"
		),
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
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_active_unlock_flight"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_opening"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_offer_modifiers"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_feedback"),
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
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_active_unlock_flight"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_opening"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_offer_modifiers"),
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
		active_unlock_flight.reset(RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "choice_flight_effect"))
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
			RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "runtime_skill_levels"),
			registry
		)
	# 호출자가 부분 컨텍스트(시네마틱 좌표 등)만 넘겨도 기본 신화 초이스 키가 유지되도록
	# 기본 컨텍스트 위에 병합한다.
	var context: Dictionary = build_mythic_choice_context()
	context.merge(choice_context.duplicate(true), true)
	# 선택 후 획득 시네마틱(runtime_perk_choice_apply_flow)은 좌표를 선택된 카드에서
	# 읽으므로, 컨텍스트로 전달된 상자 좌표를 각 카드에 스탬프한다.
	for card_value in generated_choices:
		if card_value is Dictionary:
			for cinematic_key in ["pickup_position", "target_player_center"]:
				if context.has(cinematic_key):
					(card_value as Dictionary)[cinematic_key] = context[cinematic_key]
	RuntimePerkCallbackMap.call_dict(
		callbacks,
		CALLBACK_APPLY_CHOICE_OPENING_UPDATE,
		[
			{
				"accepted": true,
				"pending_skill_choices": RuntimePerkRuntimeStateAccess.get_int(runtime_state, "pending_skill_choices") + 1,
			}
		]
	)
	RuntimePerkCallbackMap.call_dict(
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
	var ready_result: Dictionary = RuntimePerkCallbackMap.call_dict(
		callbacks,
		CALLBACK_APPLY_CHOICE_OPENING_UPDATE,
		[choice_opening.build_ready_state_update(RuntimePerkRuntimeStateAccess.get_array(runtime_state, "current_choices").size())]
	)
	if bool(ready_result.get("tick_lingpet_ring_core_offer_cooldown", false)):
		RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_TICK_LINGPET_RING_CORE_OFFER_COOLDOWN, [registry])
	if bool(ready_result.get("pause_skill_cooldowns", false)):
		RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_PAUSE_SKILL_COOLDOWNS_FOR_CHOICE, [owner, registry])
	if bool(ready_result.get("build_particles", false)):
		sample_start = _perf_begin(perf_logger)
		RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_BUILD_PARTICLES, [])
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
		active_unlock_flight.reset(RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "choice_flight_effect"))
	if RuntimePerkRuntimeStateAccess.get_int(runtime_state, "pending_skill_choices") <= 0:
		return RuntimePerkCallbackMap.call_dict(
			callbacks,
			CALLBACK_APPLY_CHOICE_OPENING_UPDATE,
			[choice_opening.build_unavailable_state_update(true)]
		)
	if catalog == null or not catalog.has_method("get_choices"):
		return RuntimePerkCallbackMap.call_dict(
			callbacks,
			CALLBACK_APPLY_CHOICE_OPENING_UPDATE,
			[choice_opening.build_unavailable_state_update(false)]
		)

	var sample_start: int = _perf_begin(perf_logger)
	var item_bonus_choice_count: int = choice_offer_modifiers.get_item_perk_choice_count_bonus(
		owner,
		registry,
		RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_GET_INSTANCE)
	)
	_perf_end(perf_logger, "process.runtime_perk.open_next_choice.item_bonus", sample_start)
	var target_choice_count: int = choice_offer_modifiers.build_target_choice_count(
		base_choice_count,
		item_bonus_choice_count
	)
	sample_start = _perf_begin(perf_logger)
	var generated_choices: Array = catalog.get_choices(
		character_type,
		RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "runtime_skill_levels"),
		exclude_instant,
		target_choice_count,
		owner,
		registry
	)
	var generated_slot_status: Dictionary = choice_offer_modifiers.build_perk_slot_status(
		catalog,
		RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "runtime_skill_levels"),
		registry
	)
	RuntimePerkCallbackMap.call_dict(
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
	var current_choices: Array = RuntimePerkRuntimeStateAccess.get_array(runtime_state, "current_choices")
	if current_choices.is_empty():
		var empty_choices_result: Dictionary = RuntimePerkCallbackMap.call_dict(
			callbacks,
			CALLBACK_APPLY_CHOICE_OPENING_UPDATE,
			[choice_opening.build_empty_choices_state_update(RuntimePerkRuntimeStateAccess.get_int(runtime_state, "pending_skill_choices"))]
		)
		if bool(empty_choices_result.get("open_next_choice", false)):
			return open_next_choice(
				character_type,
				catalog,
				exclude_instant,
				owner,
				registry,
				perf_logger,
				RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "current_choice_context"),
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
		RuntimePerkCallbackMap.call_dict(callbacks, CALLBACK_APPLY_CHOICE_OPENING_UPDATE, [bonus_choice_update])
		if choice_feedback != null:
			choice_feedback.apply_dowsing_goggles_bonus_feedback_state_update(
				runtime_state,
				RuntimePerkRuntimeStateAccess.get_float(runtime_state, "feedback_timer")
			)

	var ready_result: Dictionary = RuntimePerkCallbackMap.call_dict(
		callbacks,
		CALLBACK_APPLY_CHOICE_OPENING_UPDATE,
		[choice_opening.build_ready_state_update(RuntimePerkRuntimeStateAccess.get_array(runtime_state, "current_choices").size())]
	)
	if bool(ready_result.get("tick_lingpet_ring_core_offer_cooldown", false)):
		RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_TICK_LINGPET_RING_CORE_OFFER_COOLDOWN, [registry])
	if bool(ready_result.get("pause_skill_cooldowns", false)):
		RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_PAUSE_SKILL_COOLDOWNS_FOR_CHOICE, [owner, registry])
	if bool(ready_result.get("build_particles", false)):
		sample_start = _perf_begin(perf_logger)
		RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_BUILD_PARTICLES, [])
		_perf_end(perf_logger, "process.runtime_perk.open_next_choice.particles", sample_start)
	return ready_result


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
