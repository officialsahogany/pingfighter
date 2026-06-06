extends RefCounted

const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")


static func get_player_victory_draw_context(
	timer: float,
	player_victory_click_reaction_timer: float,
	player_victory_click_transition_base_frame: int,
	player_victory_sheet: Texture2D,
	player_victory_click_reaction_sheet: Texture2D
) -> Dictionary:
	return {
		"timer": timer,
		"player_victory_click_reaction_timer": player_victory_click_reaction_timer,
		"player_victory_click_transition_base_frame": player_victory_click_transition_base_frame,
		"player_victory_sheet": player_victory_sheet,
		"player_victory_click_reaction_sheet": player_victory_click_reaction_sheet,
	}


static func get_defeated_boss_draw_context(
	current_stage: int,
	timer: float,
	dalji_base_timer: float,
	dalji_click_reaction_timer: float,
	dalji_click_transition_base_frame: int,
	dalji_defeat_sheet: Texture2D,
	dalji_click_reaction_sheet: Texture2D,
	stage2_boss_defeat_live2d_sheet: Texture2D,
	stage2_boss_defeat_click_reaction_sheet: Texture2D,
	stage2_boss_defeat_click_reaction_timer: float,
	stage2_boss_defeat_click_transition_base_frame: int,
	stage3_boss_defeat_live2d_sheet: Texture2D,
	stage3_boss_defeat_click_reaction_sheet: Texture2D,
	stage3_boss_defeat_click_reaction_timer: float,
	stage3_boss_defeat_click_transition_base_frame: int
) -> Dictionary:
	return {
		"current_stage": current_stage,
		"timer": timer,
		"dalji_base_timer": dalji_base_timer,
		"dalji_click_reaction_timer": dalji_click_reaction_timer,
		"dalji_click_transition_base_frame": dalji_click_transition_base_frame,
		"dalji_defeat_sheet": dalji_defeat_sheet,
		"dalji_click_reaction_sheet": dalji_click_reaction_sheet,
		"stage2_boss_defeat_live2d_sheet": stage2_boss_defeat_live2d_sheet,
		"stage2_boss_defeat_click_reaction_sheet": stage2_boss_defeat_click_reaction_sheet,
		"stage2_boss_defeat_click_reaction_timer": stage2_boss_defeat_click_reaction_timer,
		"stage2_boss_defeat_click_transition_base_frame": stage2_boss_defeat_click_transition_base_frame,
		"stage3_boss_defeat_live2d_sheet": stage3_boss_defeat_live2d_sheet,
		"stage3_boss_defeat_click_reaction_sheet": stage3_boss_defeat_click_reaction_sheet,
		"stage3_boss_defeat_click_reaction_timer": stage3_boss_defeat_click_reaction_timer,
		"stage3_boss_defeat_click_transition_base_frame": stage3_boss_defeat_click_transition_base_frame,
	}


static func draw_player_victory_live2d(
	canvas: CanvasItem,
	view_size: Vector2,
	draw_scale: float,
	draw_context: Dictionary
) -> Dictionary:
	return StageClearResultActorDrawHelper.draw_player_victory_live2d(
		canvas,
		draw_context.get("player_victory_sheet", null) as Texture2D,
		draw_context.get("player_victory_click_reaction_sheet", null) as Texture2D,
		StageClearResultActorDrawHelper.get_player_victory_reaction_state(
			float(draw_context.get("timer", 0.0)),
			float(draw_context.get("player_victory_click_reaction_timer", StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_TOTAL_DURATION)),
			int(draw_context.get("player_victory_click_transition_base_frame", 0))
		),
		view_size,
		draw_scale,
		StageClearResultActorDrawHelper.PLAYER_VICTORY_GRID_COLS,
		StageClearResultActorDrawHelper.PLAYER_VICTORY_CELL_SIZE
	)


static func get_player_victory_draw_apply_result(draw_result: Dictionary) -> Dictionary:
	return {
		"player_victory_click_rect": draw_result.get("click_rect", Rect2()),
		"drawn": bool(draw_result.get("drawn", true)),
	}


static func get_player_victory_draw_scene_apply_result(draw_result: Dictionary) -> Dictionary:
	var apply_result: Dictionary = get_player_victory_draw_apply_result(draw_result)
	return {
		"field_payload": {
			"_player_victory_click_rect": apply_result.get("player_victory_click_rect", Rect2()),
		},
		"drawn": bool(apply_result.get("drawn", true)),
	}


static func draw_defeated_boss(
	canvas: CanvasItem,
	view_size: Vector2,
	draw_scale: float,
	draw_context: Dictionary
) -> Dictionary:
	var current_stage: int = int(draw_context.get("current_stage", 1))
	if current_stage == 2:
		var stage2_sheet: Texture2D = draw_context.get("stage2_boss_defeat_live2d_sheet", null) as Texture2D
		if stage2_sheet != null:
			StageClearResultActorDrawHelper.draw_stage2_defeated(
				canvas,
				stage2_sheet,
				draw_context.get("stage2_boss_defeat_click_reaction_sheet", null) as Texture2D,
				StageClearResultActorDrawHelper.get_boss_defeat_reaction_state(
					float(draw_context.get("timer", 0.0)),
					float(draw_context.get("stage2_boss_defeat_click_reaction_timer", StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION)),
					int(draw_context.get("stage2_boss_defeat_click_transition_base_frame", 0))
				),
				view_size,
				draw_scale,
				StageClearResultActorDrawHelper.BOSS_DEFEAT_LIVE2D_GRID_COLS,
				StageClearResultActorDrawHelper.BOSS_DEFEAT_LIVE2D_CELL_SIZE,
				0.98
			)
		return {}
	if current_stage == 3:
		var stage3_sheet: Texture2D = draw_context.get("stage3_boss_defeat_live2d_sheet", null) as Texture2D
		if stage3_sheet != null:
			StageClearResultActorDrawHelper.draw_stage3_defeated(
				canvas,
				stage3_sheet,
				draw_context.get("stage3_boss_defeat_click_reaction_sheet", null) as Texture2D,
				StageClearResultActorDrawHelper.get_boss_defeat_reaction_state(
					float(draw_context.get("timer", 0.0)),
					float(draw_context.get("stage3_boss_defeat_click_reaction_timer", StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION)),
					int(draw_context.get("stage3_boss_defeat_click_transition_base_frame", 0))
				),
				view_size,
				draw_scale,
				StageClearResultActorDrawHelper.BOSS_DEFEAT_LIVE2D_GRID_COLS,
				StageClearResultActorDrawHelper.BOSS_DEFEAT_LIVE2D_CELL_SIZE,
				0.98
			)
		return {}

	var dalji_sheet: Texture2D = draw_context.get("dalji_defeat_sheet", null) as Texture2D
	if dalji_sheet == null:
		return {}
	return {
		"dalji_click_rect": StageClearResultActorDrawHelper.draw_dalji_defeated(
			canvas,
			dalji_sheet,
			draw_context.get("dalji_click_reaction_sheet", null) as Texture2D,
			StageClearResultActorDrawHelper.get_dalji_reaction_state(
				float(draw_context.get("dalji_base_timer", 0.0)),
				float(draw_context.get("dalji_click_reaction_timer", StageClearResultActorDrawHelper.DALJI_CLICK_TOTAL_DURATION)),
				int(draw_context.get("dalji_click_transition_base_frame", 0))
			),
			view_size,
			draw_scale,
			StageClearResultActorDrawHelper.DALJI_GRID_COLS,
			StageClearResultActorDrawHelper.DALJI_CELL_SIZE,
			0.98
		),
	}


static func get_defeated_boss_draw_apply_result(
	draw_result: Dictionary,
	current_dalji_click_rect: Rect2
) -> Dictionary:
	return {
		"dalji_click_rect": draw_result.get("dalji_click_rect", current_dalji_click_rect),
	}


static func get_defeated_boss_draw_scene_apply_result(
	draw_result: Dictionary,
	current_dalji_click_rect: Rect2
) -> Dictionary:
	var apply_result: Dictionary = get_defeated_boss_draw_apply_result(
		draw_result,
		current_dalji_click_rect
	)
	return {
		"field_payload": {
			"_dalji_click_rect": apply_result.get("dalji_click_rect", current_dalji_click_rect),
		},
	}
