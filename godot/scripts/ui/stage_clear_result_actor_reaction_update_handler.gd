extends RefCounted

const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")
const StageClearResultClickReactionState := preload("res://scripts/ui/stage_clear_result_click_reaction_state.gd")


static func get_actor_reaction_timer_context(
	dalji_base_timer: float,
	dalji_click_reaction_timer: float,
	player_victory_click_reaction_timer: float,
	stage2_boss_defeat_click_reaction_timer: float,
	stage3_boss_defeat_click_reaction_timer: float,
	dalji_dialogue_timer: float
) -> Dictionary:
	return {
		"dalji_base_timer": dalji_base_timer,
		"dalji_click_reaction_timer": dalji_click_reaction_timer,
		"player_victory_click_reaction_timer": player_victory_click_reaction_timer,
		"stage2_boss_defeat_click_reaction_timer": stage2_boss_defeat_click_reaction_timer,
		"stage3_boss_defeat_click_reaction_timer": stage3_boss_defeat_click_reaction_timer,
		"dalji_dialogue_timer": dalji_dialogue_timer,
	}


static func update_actor_reaction_timers(current: Dictionary, delta: float) -> Dictionary:
	var safe_delta: float = max(0.0, delta)
	return {
		"dalji_base_timer": float(current.get("dalji_base_timer", 0.0)) + safe_delta,
		"dalji_click_reaction_timer": StageClearResultClickReactionState.advance_reaction_timer(
			float(current.get("dalji_click_reaction_timer", StageClearResultActorDrawHelper.DALJI_CLICK_TOTAL_DURATION)),
			StageClearResultActorDrawHelper.DALJI_CLICK_TOTAL_DURATION,
			safe_delta
		),
		"player_victory_click_reaction_timer": StageClearResultClickReactionState.advance_reaction_timer(
			float(current.get("player_victory_click_reaction_timer", StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_TOTAL_DURATION)),
			StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_TOTAL_DURATION,
			safe_delta
		),
		"stage2_boss_defeat_click_reaction_timer": StageClearResultClickReactionState.advance_reaction_timer(
			float(current.get("stage2_boss_defeat_click_reaction_timer", StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION)),
			StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
			safe_delta
		),
		"stage3_boss_defeat_click_reaction_timer": StageClearResultClickReactionState.advance_reaction_timer(
			float(current.get("stage3_boss_defeat_click_reaction_timer", StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION)),
			StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
			safe_delta
		),
		"dalji_dialogue_timer": max(0.0, float(current.get("dalji_dialogue_timer", 0.0)) - safe_delta),
	}


static func get_actor_reaction_timer_apply_result(update_result: Dictionary, current: Dictionary) -> Dictionary:
	return {
		"dalji_base_timer": float(update_result.get("dalji_base_timer", current.get("dalji_base_timer", 0.0))),
		"dalji_click_reaction_timer": float(update_result.get("dalji_click_reaction_timer", current.get("dalji_click_reaction_timer", StageClearResultActorDrawHelper.DALJI_CLICK_TOTAL_DURATION))),
		"player_victory_click_reaction_timer": float(update_result.get("player_victory_click_reaction_timer", current.get("player_victory_click_reaction_timer", StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_TOTAL_DURATION))),
		"stage2_boss_defeat_click_reaction_timer": float(update_result.get("stage2_boss_defeat_click_reaction_timer", current.get("stage2_boss_defeat_click_reaction_timer", StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION))),
		"stage3_boss_defeat_click_reaction_timer": float(update_result.get("stage3_boss_defeat_click_reaction_timer", current.get("stage3_boss_defeat_click_reaction_timer", StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION))),
		"dalji_dialogue_timer": float(update_result.get("dalji_dialogue_timer", current.get("dalji_dialogue_timer", 0.0))),
	}


static func get_actor_reaction_timer_scene_apply_result(update_result: Dictionary, current: Dictionary) -> Dictionary:
	var apply_result: Dictionary = get_actor_reaction_timer_apply_result(update_result, current)
	return {
		"field_payload": {
			"_dalji_base_timer": float(apply_result.get("dalji_base_timer", current.get("dalji_base_timer", 0.0))),
			"_dalji_click_reaction_timer": float(apply_result.get("dalji_click_reaction_timer", current.get("dalji_click_reaction_timer", StageClearResultActorDrawHelper.DALJI_CLICK_TOTAL_DURATION))),
			"_player_victory_click_reaction_timer": float(apply_result.get("player_victory_click_reaction_timer", current.get("player_victory_click_reaction_timer", StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_TOTAL_DURATION))),
			"_stage2_boss_defeat_click_reaction_timer": float(apply_result.get("stage2_boss_defeat_click_reaction_timer", current.get("stage2_boss_defeat_click_reaction_timer", StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION))),
			"_stage3_boss_defeat_click_reaction_timer": float(apply_result.get("stage3_boss_defeat_click_reaction_timer", current.get("stage3_boss_defeat_click_reaction_timer", StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION))),
			"_dalji_dialogue_timer": float(apply_result.get("dalji_dialogue_timer", current.get("dalji_dialogue_timer", 0.0))),
		},
	}
