extends RefCounted

const RuntimePerkChoiceDispatch := preload("res://scripts/characters/runtime_perk_choice_dispatch.gd")
const LingpetGuardianEnhanceApplier := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_applier.gd"
)

const CALLBACK_CONVERT_TO_GOLD := "apply_convert_to_gold"
const CALLBACK_FULL_GAUGE_DEFERRED := "queue_full_gauge_deferred"
const CALLBACK_FULL_GAUGE := "apply_full_gauge"
const CALLBACK_DIMENSION_GATE_DEFERRED := "queue_dimension_gate_deferred"
const CALLBACK_DIMENSION_GATE := "apply_dimension_gate"
const CALLBACK_MONKEY_BLESSING := "apply_monkey_blessing"
const CALLBACK_TREASURE_HUNT := "apply_treasure_hunt"
const CALLBACK_LINGPET_AFFINITY_CHIP := "apply_lingpet_affinity_chip"
const CALLBACK_LINGPET_RING_CORE_UPGRADE := "apply_lingpet_ring_core_upgrade"

const TIMER_IMMEDIATE := 1.2
const TIMER_MONKEY_BLESSING := 1.1
const TIMER_TREASURE_HUNT := 1.6
const TIMER_LINGPET := 1.1


func build_state_action_callbacks(state: Object) -> Dictionary:
	if state == null:
		return {}
	return {
		CALLBACK_CONVERT_TO_GOLD: Callable(state, "_apply_convert_to_gold_choice"),
		CALLBACK_FULL_GAUGE_DEFERRED: Callable(state, "_queue_full_gauge_after_spawn_intro_choice"),
		CALLBACK_FULL_GAUGE: Callable(state, "_apply_full_gauge_choice"),
		CALLBACK_DIMENSION_GATE_DEFERRED: Callable(state, "_queue_dimension_gate_after_spawn_intro_choice"),
		CALLBACK_DIMENSION_GATE: Callable(state, "_apply_dimension_gate_choice"),
		CALLBACK_MONKEY_BLESSING: Callable(state, "_apply_monkey_blessing_choice"),
		CALLBACK_TREASURE_HUNT: Callable(state, "_apply_treasure_hunt_choice"),
		CALLBACK_LINGPET_AFFINITY_CHIP: Callable(state, "_apply_lingpet_affinity_chip"),
		CALLBACK_LINGPET_RING_CORE_UPGRADE: Callable(state, "_apply_lingpet_ring_core_upgrade"),
	}


func run_dispatch(dispatch: Dictionary, choice: Dictionary, owner: Object, registry: Object, callbacks: Dictionary) -> Dictionary:
	if not bool(dispatch.get("accepted", false)):
		return {
			"handled": true,
			"accepted": false,
			"uses_feedback": false,
			"blocked_reason": "dispatch_rejected",
		}
	var action: String = str(dispatch.get("action", RuntimePerkChoiceDispatch.ACTION_STANDARD))
	return run(action, choice, owner, registry, callbacks)


func run(action: String, choice: Dictionary, owner: Object, registry: Object, callbacks: Dictionary) -> Dictionary:
	var choice_id: String = str(choice.get("id", "")).strip_edges()
	var choice_name: String = str(choice.get("name", choice_id))
	match action:
		RuntimePerkChoiceDispatch.ACTION_CONVERT_TO_GOLD:
			return _call_bool(callbacks, CALLBACK_CONVERT_TO_GOLD, [choice, owner, registry])
		RuntimePerkChoiceDispatch.ACTION_FULL_GAUGE_DEFERRED:
			return _call_feedback(callbacks, CALLBACK_FULL_GAUGE_DEFERRED, [owner, choice_name], TIMER_IMMEDIATE)
		RuntimePerkChoiceDispatch.ACTION_FULL_GAUGE:
			return _call_feedback(callbacks, CALLBACK_FULL_GAUGE, [owner, registry], TIMER_IMMEDIATE)
		RuntimePerkChoiceDispatch.ACTION_DIMENSION_GATE_DEFERRED:
			return _call_feedback(callbacks, CALLBACK_DIMENSION_GATE_DEFERRED, [owner, choice_name], TIMER_IMMEDIATE)
		RuntimePerkChoiceDispatch.ACTION_DIMENSION_GATE:
			return _call_feedback(callbacks, CALLBACK_DIMENSION_GATE, [registry], TIMER_IMMEDIATE)
		RuntimePerkChoiceDispatch.ACTION_MONKEY_BLESSING:
			return _call_feedback(callbacks, CALLBACK_MONKEY_BLESSING, [owner, registry, choice_name], TIMER_MONKEY_BLESSING)
		RuntimePerkChoiceDispatch.ACTION_TREASURE_HUNT:
			return _call_feedback(callbacks, CALLBACK_TREASURE_HUNT, [owner, registry], TIMER_TREASURE_HUNT)
		RuntimePerkChoiceDispatch.ACTION_LINGPET_AFFINITY_CHIP:
			return _call_feedback(callbacks, CALLBACK_LINGPET_AFFINITY_CHIP, [owner, registry, choice_name], TIMER_LINGPET)
		RuntimePerkChoiceDispatch.ACTION_LINGPET_RING_CORE_UPGRADE:
			return _call_feedback(
				callbacks,
				CALLBACK_LINGPET_RING_CORE_UPGRADE,
				[owner, registry, int(choice.get("next_tier", 0)), choice_name],
				TIMER_LINGPET
			)
		RuntimePerkChoiceDispatch.ACTION_LINGPET_GUARDIAN_ENHANCE:
			var begin_result := LingpetGuardianEnhanceApplier.begin(choice, owner, registry)
			return {
				"handled": true,
				"accepted": bool(begin_result.get("accepted", false)),
				"uses_feedback": false,
				"begin_result": begin_result,
			}
	return {"handled": false}


func apply_handled_result(
	action_result: Dictionary,
	choice: Dictionary,
	apply_choice_feedback_result: Callable
) -> Dictionary:
	if not bool(action_result.get("handled", false)):
		return {"handled": false, "accepted": false}
	if bool(action_result.get("uses_feedback", false)):
		if not apply_choice_feedback_result.is_valid():
			return {
				"handled": true,
				"accepted": false,
				"blocked_reason": "missing_feedback_callback",
			}
		return {
			"handled": true,
			"accepted": bool(apply_choice_feedback_result.call(
				_get_dict(action_result.get("feedback_result", {})),
				choice,
				float(action_result.get("fallback_timer", 1.0))
			)),
		}
	return {
		"handled": true,
		"accepted": bool(action_result.get("accepted", false)),
	}


func _call_bool(callbacks: Dictionary, key: String, args: Array) -> Dictionary:
	var callback := _get_callback(callbacks, key)
	if not callback.is_valid():
		return {"handled": true, "accepted": false}
	return {
		"handled": true,
		"accepted": bool(callback.callv(args)),
		"uses_feedback": false,
	}


func _call_feedback(callbacks: Dictionary, key: String, args: Array, fallback_timer: float) -> Dictionary:
	var callback := _get_callback(callbacks, key)
	if not callback.is_valid():
		return {
			"handled": true,
			"accepted": false,
			"uses_feedback": true,
			"feedback_result": {"accepted": false},
			"fallback_timer": fallback_timer,
		}
	var result: Variant = callback.callv(args)
	var feedback_result: Dictionary = result if result is Dictionary else {"accepted": false}
	return {
		"handled": true,
		"accepted": bool(feedback_result.get("accepted", false)),
		"uses_feedback": true,
		"feedback_result": feedback_result,
		"fallback_timer": fallback_timer,
	}


func _get_callback(callbacks: Dictionary, key: String) -> Callable:
	var value: Variant = callbacks.get(key, Callable())
	if value is Callable:
		return value
	return Callable()


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
