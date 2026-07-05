extends RefCounted

const StageClearResultActorClickHandler := preload("res://scripts/ui/stage_clear_result_actor_click_handler.gd")


static func get_boss_result_click_scene_apply_result(
	current_stage: int,
	stage_id: int,
	scene: Object,
	mouse_position: Vector2,
	view_size: Vector2,
	draw_scale: float,
	base_timer: float
) -> Dictionary:
	if current_stage != stage_id:
		return _empty_scene_apply_result()
	var click_config: Dictionary = StageClearResultActorClickHandler.get_boss_result_click_config(stage_id)
	if click_config.is_empty():
		return _empty_scene_apply_result()

	var sheet_property: StringName = click_config.get("sheet_property", &"") as StringName
	var transition_base_frame_property: StringName = click_config.get("transition_base_frame_property", &"") as StringName
	var reaction_timer_property: StringName = click_config.get("reaction_timer_property", &"") as StringName
	var current_reaction_timer: float = float(scene.get(reaction_timer_property))
	var click_result: Dictionary = StageClearResultActorClickHandler.handle_boss_defeat_click(
		stage_id,
		scene.get(sheet_property) != null,
		mouse_position,
		view_size,
		draw_scale,
		current_reaction_timer,
		base_timer
	)
	return StageClearResultActorClickHandler.get_click_reaction_scene_apply_result(
		click_result,
		transition_base_frame_property,
		int(scene.get(transition_base_frame_property)),
		reaction_timer_property,
		current_reaction_timer
	)


static func get_player_victory_click_scene_apply_result(
	scene: Object,
	mouse_position: Vector2,
	view_size: Vector2,
	draw_scale: float,
	base_timer: float
) -> Dictionary:
	var current_reaction_timer: float = float(scene.get("_player_victory_click_reaction_timer"))
	var click_result: Dictionary = StageClearResultActorClickHandler.handle_player_victory_click(
		mouse_position,
		view_size,
		draw_scale,
		current_reaction_timer,
		base_timer
	)
	var reaction_apply_result: Dictionary = StageClearResultActorClickHandler.get_click_reaction_scene_apply_result(
		click_result,
		&"_player_victory_click_transition_base_frame",
		int(scene.get("_player_victory_click_transition_base_frame")),
		&"_player_victory_click_reaction_timer",
		current_reaction_timer
	)
	var apply_results: Array[Dictionary] = [
		StageClearResultActorClickHandler.get_player_victory_click_rect_scene_apply_result(click_result),
		reaction_apply_result,
	]
	return _merge_scene_apply_results(apply_results, reaction_apply_result)


static func get_dalji_click_scene_apply_result(
	current_stage: int,
	scene: Object,
	mouse_position: Vector2,
	view_size: Vector2,
	draw_scale: float,
	base_timer: float,
	dialogue_duration: float
) -> Dictionary:
	var current_reaction_timer: float = float(scene.get("_dalji_click_reaction_timer"))
	var click_result: Dictionary = StageClearResultActorClickHandler.handle_dalji_click(
		current_stage,
		mouse_position,
		view_size,
		draw_scale,
		current_reaction_timer,
		base_timer
	)
	var reaction_apply_result: Dictionary = StageClearResultActorClickHandler.get_click_reaction_scene_apply_result(
		click_result,
		&"_dalji_click_transition_base_frame",
		int(scene.get("_dalji_click_transition_base_frame")),
		&"_dalji_click_reaction_timer",
		current_reaction_timer
	)
	var apply_results: Array[Dictionary] = [
		StageClearResultActorClickHandler.get_dalji_click_rect_scene_apply_result(click_result),
		reaction_apply_result,
	]
	if bool(reaction_apply_result.get("handled", false)):
		apply_results.append(StageClearResultActorClickHandler.get_dalji_click_side_effect_scene_apply_result(
			click_result,
			float(scene.get("_dalji_dialogue_timer")),
			dialogue_duration
		))
	return _merge_scene_apply_results(apply_results, reaction_apply_result)


static func _empty_scene_apply_result() -> Dictionary:
	return {
		"handled": false,
		"started": false,
		"field_payload": {},
		"redraw": false,
		"play_voice": false,
	}


static func _merge_scene_apply_results(apply_results: Array[Dictionary], primary_result: Dictionary) -> Dictionary:
	var field_payload: Dictionary = {}
	var play_voice: bool = false
	for apply_result: Dictionary in apply_results:
		var payload_value: Variant = apply_result.get("field_payload", {})
		if payload_value is Dictionary:
			field_payload.merge(payload_value, true)
		play_voice = play_voice or bool(apply_result.get("play_voice", false))
	return {
		"handled": bool(primary_result.get("handled", false)),
		"started": bool(primary_result.get("started", false)),
		"field_payload": field_payload,
		"redraw": bool(primary_result.get("redraw", false)),
		"play_voice": play_voice,
	}
