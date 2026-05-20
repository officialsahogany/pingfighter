extends RefCounted

const ActiveItemDurationBonus := preload("res://scripts/items/active_item_duration_bonus.gd")

const FEEDBACK_SHAKE_AMOUNT := 0.05
const FEEDBACK_SHAKE_DURATION := 1.05

var _duration_bonus: Object = ActiveItemDurationBonus.new()


func activate(
	target: Object,
	registry: Object,
	runtime: Object,
	player_center: Vector2,
	state_applier: Object,
	effect_feedback: Object
) -> bool:
	var state: Dictionary = runtime.start_state(_duration_bonus.get_multiplier(registry))
	state["player_center"] = player_center
	state_applier.apply_dash_boost_state(target, state)
	effect_feedback.trigger_registry_feedback(
		registry,
		false,
		false,
		FEEDBACK_SHAKE_AMOUNT,
		FEEDBACK_SHAKE_DURATION
	)
	effect_feedback.play_first_audio(registry, ["play_active_item"])

	return true
