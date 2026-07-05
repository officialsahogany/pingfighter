extends RefCounted

const StageClearResultStarpointPerkRewardData := preload("res://scripts/core/stage_clear_result_starpoint_perk_reward_data.gd")


static func can_defer_choice(runtime_perk_state: Object, runtime_perk_catalog: Object) -> bool:
	return (
		runtime_perk_state != null
		and runtime_perk_catalog != null
		and runtime_perk_state.has_method("open_next_choice")
	)


static func open_deferred_starpoint_choice(
	runtime_perk_state: Object,
	runtime_perk_catalog: Object,
	selected_character_type: String,
	owner: Object,
	registry: Object,
	game_audio: Object
) -> Dictionary:
	if not can_defer_choice(runtime_perk_state, runtime_perk_catalog):
		return {"opened": false, "choice_active": false, "last_recorded_perk_choice_sequence": 0}
	var last_recorded_sequence: int = StageClearResultStarpointPerkRewardData.get_runtime_perk_choice_sequence(
		runtime_perk_state
	)
	runtime_perk_state.open_next_choice(
		selected_character_type,
		runtime_perk_catalog,
		false,
		owner,
		registry,
		null,
		build_choice_context()
	)
	var choice_active: bool = is_runtime_perk_choice_active(runtime_perk_state)
	if choice_active:
		play_runtime_perk_choice_open_audio(game_audio)
	return {
		"opened": true,
		"choice_active": choice_active,
		"last_recorded_perk_choice_sequence": last_recorded_sequence,
	}


static func build_choice_context() -> Dictionary:
	return {
		"source": "result_box_starpoint_choice",
		"defer_instant_dimension_gate_until_spawn_intro_end": true,
		"defer_instant_full_gauge_until_spawn_intro_end": true,
	}


static func is_runtime_perk_choice_active(runtime_perk_state: Object) -> bool:
	return (
		runtime_perk_state != null
		and runtime_perk_state.has_method("is_choice_active")
		and bool(runtime_perk_state.is_choice_active())
	)


static func play_runtime_perk_choice_open_audio(game_audio: Object) -> void:
	if game_audio == null:
		return
	if game_audio.has_method("play_runtime_perk_choice_open"):
		game_audio.play_runtime_perk_choice_open()
	elif game_audio.has_method("play_starpoint_collect"):
		game_audio.play_starpoint_collect()
