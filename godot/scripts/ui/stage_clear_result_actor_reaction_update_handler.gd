extends RefCounted

const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")
const StageClearResultClickReactionState := preload("res://scripts/ui/stage_clear_result_click_reaction_state.gd")


static func get_actor_reaction_timer_context(
	dalji_base_timer: float,
	dalji_click_reaction_timer: float,
	player_victory_click_reaction_timer: float,
	stage2_boss_defeat_click_reaction_timer: float,
	stage3_boss_defeat_click_reaction_timer: float,
	dalji_dialogue_timer: float,
	stage6_boss_defeat_click_reaction_timer: float = StageClearResultActorDrawHelper.STAGE6_TETRISER_CLICK_TOTAL_DURATION,
	stage4_ponk_boss_defeat_click_reaction_timer: float = StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
	stage5_hongryun_result_click_reaction_timer: float = StageClearResultActorDrawHelper.STAGE5_HONGRYUN_CLICK_TOTAL_DURATION
) -> Dictionary:
	return {
		"dalji_base_timer": dalji_base_timer,
		"dalji_click_reaction_timer": dalji_click_reaction_timer,
		"player_victory_click_reaction_timer": player_victory_click_reaction_timer,
		"stage2_boss_defeat_click_reaction_timer": stage2_boss_defeat_click_reaction_timer,
		"stage3_boss_defeat_click_reaction_timer": stage3_boss_defeat_click_reaction_timer,
		"stage6_boss_defeat_click_reaction_timer": stage6_boss_defeat_click_reaction_timer,
		"stage4_ponk_boss_defeat_click_reaction_timer": stage4_ponk_boss_defeat_click_reaction_timer,
		"stage5_hongryun_result_click_reaction_timer": stage5_hongryun_result_click_reaction_timer,
		"dalji_dialogue_timer": dalji_dialogue_timer,
	}


static func update_actor_reaction_timers(current: Dictionary, delta: float) -> Dictionary:
	var safe_delta: float = max(0.0, delta)
	var result: Dictionary = {
		"dalji_base_timer": float(current.get("dalji_base_timer", 0.0)) + safe_delta,
		"dalji_dialogue_timer": max(0.0, float(current.get("dalji_dialogue_timer", 0.0)) - safe_delta),
	}
	for config: Dictionary in _get_reaction_timer_payload_configs():
		var apply_key: String = String(config.get("apply_key", ""))
		var total_duration: float = float(config.get("total_duration", 0.0))
		result[apply_key] = StageClearResultClickReactionState.advance_reaction_timer(
			float(current.get(apply_key, total_duration)),
			total_duration,
			safe_delta
		)
	return result


static func get_actor_reaction_timer_apply_result(update_result: Dictionary, current: Dictionary) -> Dictionary:
	var apply_result: Dictionary = {
		"dalji_base_timer": float(update_result.get("dalji_base_timer", current.get("dalji_base_timer", 0.0))),
		"dalji_dialogue_timer": float(update_result.get("dalji_dialogue_timer", current.get("dalji_dialogue_timer", 0.0))),
	}
	for config: Dictionary in _get_reaction_timer_payload_configs():
		var apply_key: String = String(config.get("apply_key", ""))
		var total_duration: float = float(config.get("total_duration", 0.0))
		apply_result[apply_key] = float(update_result.get(apply_key, current.get(apply_key, total_duration)))
	return apply_result


static func get_actor_reaction_timer_scene_apply_result(update_result: Dictionary, current: Dictionary) -> Dictionary:
	var apply_result: Dictionary = get_actor_reaction_timer_apply_result(update_result, current)
	var field_payload: Dictionary = {
		"_dalji_base_timer": float(apply_result.get("dalji_base_timer", current.get("dalji_base_timer", 0.0))),
		"_dalji_dialogue_timer": float(apply_result.get("dalji_dialogue_timer", current.get("dalji_dialogue_timer", 0.0))),
	}
	for config: Dictionary in _get_reaction_timer_payload_configs():
		var apply_key: String = String(config.get("apply_key", ""))
		var field_key: String = String(config.get("field_key", ""))
		var total_duration: float = float(config.get("total_duration", 0.0))
		field_payload[field_key] = float(apply_result.get(apply_key, current.get(apply_key, total_duration)))
	return {
		"field_payload": field_payload,
	}


static func _get_reaction_timer_payload_configs() -> Array[Dictionary]:
	return [
		{
			"apply_key": "dalji_click_reaction_timer",
			"field_key": "_dalji_click_reaction_timer",
			"total_duration": StageClearResultActorDrawHelper.DALJI_CLICK_TOTAL_DURATION,
		},
		{
			"apply_key": "player_victory_click_reaction_timer",
			"field_key": "_player_victory_click_reaction_timer",
			"total_duration": StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_TOTAL_DURATION,
		},
		{
			"apply_key": "stage2_boss_defeat_click_reaction_timer",
			"field_key": "_stage2_boss_defeat_click_reaction_timer",
			"total_duration": StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		},
		{
			"apply_key": "stage3_boss_defeat_click_reaction_timer",
			"field_key": "_stage3_boss_defeat_click_reaction_timer",
			"total_duration": StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		},
		{
			"apply_key": "stage4_ponk_boss_defeat_click_reaction_timer",
			"field_key": "_stage4_ponk_boss_defeat_click_reaction_timer",
			"total_duration": StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		},
		{
			"apply_key": "stage5_hongryun_result_click_reaction_timer",
			"field_key": "_stage5_hongryun_result_click_reaction_timer",
			"total_duration": StageClearResultActorDrawHelper.STAGE5_HONGRYUN_CLICK_TOTAL_DURATION,
		},
		{
			"apply_key": "stage6_boss_defeat_click_reaction_timer",
			"field_key": "_stage6_boss_defeat_click_reaction_timer",
			"total_duration": StageClearResultActorDrawHelper.STAGE6_TETRISER_CLICK_TOTAL_DURATION,
		},
	]
