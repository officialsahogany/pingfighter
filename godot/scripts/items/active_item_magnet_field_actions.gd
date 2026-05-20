extends RefCounted

const ActiveItemDurationBonus := preload("res://scripts/items/active_item_duration_bonus.gd")

const FEEDBACK_SHAKE_AMOUNT := 0.035
const FEEDBACK_SHAKE_DURATION := 1.1

var _duration_bonus: Object = ActiveItemDurationBonus.new()


func activate(
	target: Object,
	owner: Object,
	registry: Object,
	active: bool,
	player_center_reader: Object,
	runtime: Object,
	state_applier: Object,
	effect_feedback: Object
) -> bool:
	if active or owner == null:
		return false

	state_applier.apply_magnet_field_state(
		target,
		runtime.start_state(
			player_center_reader.get_player_center(owner),
			_duration_bonus.get_multiplier(registry)
		)
	)
	effect_feedback.play_first_audio(registry, ["play_active_item"])
	effect_feedback.trigger_registry_feedback(
		registry,
		false,
		false,
		FEEDBACK_SHAKE_AMOUNT,
		FEEDBACK_SHAKE_DURATION
	)

	return true
