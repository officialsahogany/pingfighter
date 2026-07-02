extends RefCounted

const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")

var _last_result: Dictionary = {}


func remember_result(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return _last_result.duplicate(true)


func clear_last_result() -> void:
	_last_result = {}


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func grant(
	pet_id: String,
	source: String,
	tags: Dictionary,
	registry: Object,
	affinity_state: Object,
	income_tracker: Object,
	feedback_state: Object,
	is_current_pet: bool,
	companion_feedback_active: bool,
	on_level_gain: Callable = Callable()
) -> Dictionary:
	var normalized_pet_id := pet_id.strip_edges().to_lower()
	if normalized_pet_id == "" or affinity_state == null:
		return remember_result({})
	var result: Dictionary = affinity_state.add_points(normalized_pet_id, source, tags)
	if income_tracker != null:
		income_tracker.record(normalized_pet_id, source, result, registry)
	if is_current_pet and companion_feedback_active and feedback_state != null:
		feedback_state.trigger_point_gain(float(result.get("granted_points", 0.0)))
	if is_current_pet and int(result.get("levels_gained", 0)) > 0:
		if on_level_gain.is_valid():
			on_level_gain.call(normalized_pet_id, registry)
		var level_after := int(affinity_state.get_level(normalized_pet_id))
		if feedback_state != null:
			feedback_state.trigger_level_up(
				level_after,
				LingpetAffinityState.MAX_LEVEL,
				get_next_reward_label(affinity_state, normalized_pet_id)
			)
		_play_level_up_audio(registry)
	return remember_result(result)


func get_next_reward_label(affinity_state: Object, pet_id: String) -> String:
	if affinity_state == null:
		return ""
	# Single source: cap-aware + graceful-terminal "다음 보상" label lives on
	# LingpetAffinityState so the level-up toast and the TAB panel cannot drift.
	if affinity_state.has_method("get_next_reward_display_label"):
		return str(affinity_state.get_next_reward_display_label(pet_id.strip_edges().to_lower()))
	var next_reward: Dictionary = affinity_state.get_next_reward(pet_id.strip_edges().to_lower())
	if next_reward.has("title"):
		return str(next_reward.get("title", "하트 공명"))
	return str(next_reward.get("label", ""))


func _play_level_up_audio(registry: Object) -> void:
	if registry == null or not registry.has_method("get_instance"):
		return
	var audio: Object = registry.get_instance("game_audio")
	if audio != null and audio.has_method("play_lingpet_affinity_level_up"):
		audio.play_lingpet_affinity_level_up()
