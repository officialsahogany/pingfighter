extends RefCounted

const StageClearResultScreenStatusScreenData := preload("res://scripts/core/stage_clear_result_screen_status_screen_data.gd")


func build_status(
	active: bool,
	player_score: int,
	boss_score: int,
	current_stage: int,
	reward_plan: Dictionary,
	scene_path: String,
	scene_ready: bool,
	spawn_pending: bool,
	last_plaza_progress_summary: Dictionary,
	stage_start_snapshot: Dictionary,
	stage_reward_snapshot: Dictionary,
	reward_grant_handler: Object,
	starpoint_choice_handler: Object,
	plaza_scene_handler: Object
) -> Dictionary:
	var status := {
		"active": active,
		"player_score": player_score,
		"boss_score": boss_score,
		"current_stage": current_stage,
		"reward_plan": reward_plan.duplicate(true),
		"scene_path": scene_path,
		"scene_ready": scene_ready,
		"spawn_pending": spawn_pending,
		"last_plaza_progress_summary": last_plaza_progress_summary.duplicate(true),
		"stage_start_snapshot": stage_start_snapshot.duplicate(true),
		"stage_reward_snapshot": stage_reward_snapshot.duplicate(true),
	}
	status.merge(_get_handler_status(reward_grant_handler), true)
	status.merge(_get_handler_status(starpoint_choice_handler), true)
	status.merge(_get_handler_status(plaza_scene_handler), true)
	return status


func build_status_from_screen(screen: Object, scene_path: String) -> Dictionary:
	return StageClearResultScreenStatusScreenData.build_status_from_screen(self, screen, scene_path)


func _get_handler_status(handler: Object) -> Dictionary:
	if handler == null or not handler.has_method("get_status"):
		return {}
	var status_value: Variant = handler.get_status()
	return status_value.duplicate(true) if status_value is Dictionary else {}
