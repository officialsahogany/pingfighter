extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")


func apply_full_gauge(
	instant_rewards: Object,
	character_context: Object,
	owner: Object,
	registry: Object,
	special_gauge_max: float,
	get_instance: Callable
) -> void:
	if instant_rewards == null or not instant_rewards.has_method("apply_owner_full_gauge"):
		return
	instant_rewards.apply_owner_full_gauge(
		owner,
		registry,
		character_context,
		special_gauge_max,
		get_instance
	)


func apply_full_gauge_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	special_gauge_max: float
) -> void:
	apply_full_gauge(
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_instant_rewards"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_character_context"),
		owner,
		registry,
		special_gauge_max,
		RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_get_instance")
	)


func apply_full_gauge_choice(
	instant_rewards: Object,
	character_context: Object,
	owner: Object,
	registry: Object,
	special_gauge_max: float,
	get_instance: Callable
) -> Dictionary:
	if instant_rewards == null or not instant_rewards.has_method("apply_owner_full_gauge_choice"):
		return {"accepted": false}
	return instant_rewards.apply_owner_full_gauge_choice(
		owner,
		registry,
		character_context,
		special_gauge_max,
		get_instance
	)


func apply_full_gauge_choice_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	special_gauge_max: float
) -> Dictionary:
	return apply_full_gauge_choice(
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_instant_rewards"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_character_context"),
		owner,
		registry,
		special_gauge_max,
		RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_get_instance")
	)


func apply_dimension_gate(instant_rewards: Object, registry: Object, get_instance: Callable) -> bool:
	if instant_rewards == null or not instant_rewards.has_method("apply_dimension_gate"):
		return false
	return bool(instant_rewards.apply_dimension_gate(registry, get_instance))


func apply_dimension_gate_from_runtime_state(runtime_state: Object, registry: Object) -> bool:
	return apply_dimension_gate(
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_instant_rewards"),
		registry,
		RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_get_instance")
	)


func apply_dimension_gate_choice(instant_rewards: Object, registry: Object, get_instance: Callable) -> Dictionary:
	if instant_rewards == null or not instant_rewards.has_method("apply_dimension_gate_choice"):
		return {"accepted": false}
	return instant_rewards.apply_dimension_gate_choice(registry, get_instance)


func apply_dimension_gate_choice_from_runtime_state(runtime_state: Object, registry: Object) -> Dictionary:
	return apply_dimension_gate_choice(
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_instant_rewards"),
		registry,
		RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_get_instance")
	)


func should_defer_dimension_gate(deferred_instants: Object, choice_context: Dictionary) -> bool:
	if deferred_instants == null or not deferred_instants.has_method("should_defer_dimension_gate"):
		return false
	return bool(deferred_instants.should_defer_dimension_gate(choice_context))


func should_defer_dimension_gate_from_runtime_state(runtime_state: Object) -> bool:
	return should_defer_dimension_gate(
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_deferred_instants"),
		RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "current_choice_context")
	)


func should_defer_full_gauge(deferred_instants: Object, choice_context: Dictionary) -> bool:
	if deferred_instants == null or not deferred_instants.has_method("should_defer_full_gauge"):
		return false
	return bool(deferred_instants.should_defer_full_gauge(choice_context))


func should_defer_full_gauge_from_runtime_state(runtime_state: Object) -> bool:
	return should_defer_full_gauge(
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_deferred_instants"),
		RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "current_choice_context")
	)


func queue_dimension_gate(deferred_instants: Object, owner: Object, pending_feedback_text: String = "") -> void:
	if deferred_instants != null and deferred_instants.has_method("queue_dimension_gate"):
		deferred_instants.queue_dimension_gate(owner, pending_feedback_text)


func queue_dimension_gate_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	pending_feedback_text: String = ""
) -> void:
	queue_dimension_gate(
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_deferred_instants"),
		owner,
		pending_feedback_text
	)


func queue_dimension_gate_choice(deferred_instants: Object, owner: Object, choice_name: String = "") -> Dictionary:
	if deferred_instants == null or not deferred_instants.has_method("queue_dimension_gate_choice"):
		return {"accepted": false}
	return deferred_instants.queue_dimension_gate_choice(owner, choice_name)


func queue_dimension_gate_choice_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	choice_name: String = ""
) -> Dictionary:
	return queue_dimension_gate_choice(
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_deferred_instants"),
		owner,
		choice_name
	)


func has_pending_dimension_gate(deferred_instants: Object) -> bool:
	if deferred_instants == null or not deferred_instants.has_method("has_pending_dimension_gate"):
		return false
	return bool(deferred_instants.has_pending_dimension_gate())


func has_pending_dimension_gate_from_runtime_state(runtime_state: Object) -> bool:
	return has_pending_dimension_gate(RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_deferred_instants"))


func queue_full_gauge(deferred_instants: Object, owner: Object, pending_feedback_text: String = "") -> void:
	if deferred_instants != null and deferred_instants.has_method("queue_full_gauge"):
		deferred_instants.queue_full_gauge(owner, pending_feedback_text)


func queue_full_gauge_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	pending_feedback_text: String = ""
) -> void:
	queue_full_gauge(
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_deferred_instants"),
		owner,
		pending_feedback_text
	)


func queue_full_gauge_choice(deferred_instants: Object, owner: Object, choice_name: String = "") -> Dictionary:
	if deferred_instants == null or not deferred_instants.has_method("queue_full_gauge_choice"):
		return {"accepted": false}
	return deferred_instants.queue_full_gauge_choice(owner, choice_name)


func queue_full_gauge_choice_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	choice_name: String = ""
) -> Dictionary:
	return queue_full_gauge_choice(
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_deferred_instants"),
		owner,
		choice_name
	)


func has_pending_full_gauge(deferred_instants: Object) -> bool:
	if deferred_instants == null or not deferred_instants.has_method("has_pending_full_gauge"):
		return false
	return bool(deferred_instants.has_pending_full_gauge())


func has_pending_full_gauge_from_runtime_state(runtime_state: Object) -> bool:
	return has_pending_full_gauge(RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_deferred_instants"))


func on_ball_spawn_intro_finished(
	deferred_instants: Object,
	runtime_state: Object,
	owner: Object,
	registry: Object,
	choice_feedback: Object,
	apply_dimension_gate: Callable,
	apply_full_gauge: Callable,
	sync_owner: Callable
) -> Dictionary:
	if deferred_instants == null:
		return {}
	var actions: Dictionary = deferred_instants.collect_spawn_intro_actions(owner)
	var result: Dictionary = deferred_instants.resolve_spawn_intro_actions(
		actions,
		owner,
		registry,
		apply_dimension_gate,
		apply_full_gauge
	)
	var state_update: Dictionary = deferred_instants.apply_spawn_intro_state_update(
		runtime_state,
		result,
		_build_feedback_apply(choice_feedback)
	)
	if bool(state_update.get("sync_owner", false)) and sync_owner.is_valid():
		sync_owner.call(owner)
	var public_result: Variant = state_update.get("public_result", {})
	if public_result is Dictionary:
		return public_result
	return {}


func on_ball_spawn_intro_finished_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object
) -> Dictionary:
	return on_ball_spawn_intro_finished(
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_deferred_instants"),
		runtime_state,
		owner,
		registry,
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_feedback"),
		RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_apply_dimension_gate"),
		RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_apply_full_gauge"),
		RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_sync_owner")
	)


func apply_monkey_blessing_choice(
	instant_rewards: Object,
	owner: Object,
	registry: Object,
	get_instance: Callable,
	choice_name: String = ""
) -> Dictionary:
	if instant_rewards == null or not instant_rewards.has_method("apply_monkey_blessing_choice"):
		return {"accepted": false}
	return instant_rewards.apply_monkey_blessing_choice(owner, registry, get_instance, choice_name)


func apply_monkey_blessing_choice_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	choice_name: String = ""
) -> Dictionary:
	var get_instance := RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_get_instance")
	if not get_instance.is_valid():
		return {"accepted": false, "blocked_reason": "missing_get_instance_callback"}
	return apply_monkey_blessing_choice(
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_instant_rewards"),
		owner,
		registry,
		get_instance,
		choice_name
	)


func _build_feedback_apply(choice_feedback: Object) -> Callable:
	if choice_feedback != null and choice_feedback.has_method("apply_feedback_state_update"):
		return Callable(choice_feedback, "apply_feedback_state_update")
	return Callable()
