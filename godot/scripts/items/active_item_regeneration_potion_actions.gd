extends RefCounted

const ActiveItemRegenerationPotionRuntime := preload("res://scripts/items/active_item_regeneration_potion_runtime.gd")

const PLAYER_EFFECT_ANCHOR_HEIGHT_FACTOR := 0.45
const FEEDBACK_SHAKE_AMOUNT := 0.04
const FEEDBACK_SHAKE_DURATION := 1.25

var _runtime: Object = ActiveItemRegenerationPotionRuntime.new()


func apply(
	owner: Object,
	registry: Object,
	particles: Array[Dictionary],
	rings: Array[Dictionary],
	player_center_reader: Object,
	effect: Object,
	effect_feedback: Object
) -> bool:
	_runtime.apply(registry)
	effect_feedback.trigger_registry_feedback(
		registry,
		true,
		true,
		FEEDBACK_SHAKE_AMOUNT,
		FEEDBACK_SHAKE_DURATION
	)

	var center: Vector2 = player_center_reader.get_player_anchor(owner, PLAYER_EFFECT_ANCHOR_HEIGHT_FACTOR)
	effect.spawn_effect(particles, rings, center)

	effect_feedback.play_all_audio(registry, ["play_drink", "play_active_item"])

	return true
