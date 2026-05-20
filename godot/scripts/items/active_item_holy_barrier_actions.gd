extends RefCounted

const ActiveItemDurationBonus := preload("res://scripts/items/active_item_duration_bonus.gd")

const FEEDBACK_SHAKE_AMOUNT := 0.035
const FEEDBACK_SHAKE_DURATION := 1.05

var _duration_bonus: Object = ActiveItemDurationBonus.new()


func activate(
	target: Object,
	registry: Object,
	runtime: Object,
	state_applier: Object,
	effect_feedback: Object
) -> bool:
	state_applier.apply_holy_barrier_state(
		target,
		runtime.start_state(_duration_bonus.get_multiplier(registry))
	)
	effect_feedback.trigger_registry_feedback(
		registry,
		false,
		false,
		FEEDBACK_SHAKE_AMOUNT,
		FEEDBACK_SHAKE_DURATION
	)
	effect_feedback.play_first_audio(registry, ["play_active_item"])

	return true
