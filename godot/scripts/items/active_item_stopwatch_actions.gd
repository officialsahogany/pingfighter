extends RefCounted

const FEEDBACK_SHAKE_AMOUNT := 0.04
const FEEDBACK_SHAKE_DURATION := 1.25


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
	if active:
		return false

	var activation_state: Dictionary = runtime.build_activation_state(
		owner,
		registry,
		_read_player_center(owner, player_center_reader)
	)
	if not bool(activation_state.get("activated", false)):
		return false

	state_applier.apply_stopwatch_state(target, activation_state)
	effect_feedback.play_all_audio(registry, ["play_timewatch", "play_active_item"])
	effect_feedback.trigger_registry_feedback(
		registry,
		false,
		false,
		FEEDBACK_SHAKE_AMOUNT,
		FEEDBACK_SHAKE_DURATION
	)

	return true


func _read_player_center(owner: Object, player_center_reader: Object) -> Vector2:
	if owner == null:
		return Vector2.ZERO
	return player_center_reader.get_player_center(owner)
