extends RefCounted

const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")
const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")


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
	stage3_boss_defeat_click_transition_base_frame: int,
	stage4_ponk_boss_defeat_live2d_sheet: Texture2D = null,
	stage4_ponk_boss_defeat_click_reaction_sheet: Texture2D = null,
	stage4_ponk_boss_defeat_click_reaction_timer: float = StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
	stage4_ponk_boss_defeat_click_transition_base_frame: int = 0,
	stage6_boss_defeat_sheet: Texture2D = null,
	stage6_boss_defeat_click_reaction_timer: float = StageClearResultActorDrawHelper.STAGE6_TETRISER_CLICK_TOTAL_DURATION,
	stage6_boss_defeat_click_transition_base_frame: int = 0,
	stage5_hongryun_result_sheet: Texture2D = null,
	stage5_hongryun_result_click_reaction_timer: float = StageClearResultActorDrawHelper.STAGE5_HONGRYUN_CLICK_TOTAL_DURATION,
	stage5_hongryun_result_click_transition_base_frame: int = 0,
	stage7_boss_defeat_sheet: Texture2D = null,
	stage7_boss_defeat_click_reaction_timer: float = StageClearResultActorDrawHelper.STAGE7_AKAMU_CLICK_TOTAL_DURATION,
	stage7_boss_defeat_click_transition_base_frame: int = 0
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
		"stage4_ponk_boss_defeat_live2d_sheet": stage4_ponk_boss_defeat_live2d_sheet,
		"stage4_ponk_boss_defeat_click_reaction_sheet": stage4_ponk_boss_defeat_click_reaction_sheet,
		"stage4_ponk_boss_defeat_click_reaction_timer": stage4_ponk_boss_defeat_click_reaction_timer,
		"stage4_ponk_boss_defeat_click_transition_base_frame": stage4_ponk_boss_defeat_click_transition_base_frame,
		"stage6_boss_defeat_sheet": stage6_boss_defeat_sheet,
		"stage6_boss_defeat_click_reaction_timer": stage6_boss_defeat_click_reaction_timer,
		"stage6_boss_defeat_click_transition_base_frame": stage6_boss_defeat_click_transition_base_frame,
		"stage5_hongryun_result_sheet": stage5_hongryun_result_sheet,
		"stage5_hongryun_result_click_reaction_timer": stage5_hongryun_result_click_reaction_timer,
		"stage5_hongryun_result_click_transition_base_frame": stage5_hongryun_result_click_transition_base_frame,
		"stage7_boss_defeat_sheet": stage7_boss_defeat_sheet,
		"stage7_boss_defeat_click_reaction_timer": stage7_boss_defeat_click_reaction_timer,
		"stage7_boss_defeat_click_transition_base_frame": stage7_boss_defeat_click_transition_base_frame,
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
	if current_stage == 4:
		var stage4_sheet: Texture2D = draw_context.get("stage4_ponk_boss_defeat_live2d_sheet", null) as Texture2D
		if stage4_sheet != null:
			StageClearResultActorDrawHelper.draw_stage4_ponk_defeated(
				canvas,
				stage4_sheet,
				draw_context.get("stage4_ponk_boss_defeat_click_reaction_sheet", null) as Texture2D,
				StageClearResultActorDrawHelper.get_boss_defeat_reaction_state(
					float(draw_context.get("timer", 0.0)),
					float(draw_context.get("stage4_ponk_boss_defeat_click_reaction_timer", StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION)),
					int(draw_context.get("stage4_ponk_boss_defeat_click_transition_base_frame", 0))
				),
				view_size,
				draw_scale,
				StageClearResultActorDrawHelper.BOSS_DEFEAT_LIVE2D_GRID_COLS,
				StageClearResultActorDrawHelper.BOSS_DEFEAT_LIVE2D_CELL_SIZE,
				0.98
			)
		return {}
	var result_fallback_config: Dictionary = _get_stage_result_fallback_config(current_stage)
	if not result_fallback_config.is_empty():
		return _draw_stage_result_fallback_actor(canvas, draw_context, view_size, draw_scale, result_fallback_config)

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


static func _get_stage_result_fallback_config(current_stage: int) -> Dictionary:
	match current_stage:
		5:
			return {
				"stage": 5,
				"sheet_key": "stage5_hongryun_result_sheet",
				"reaction_timer_key": "stage5_hongryun_result_click_reaction_timer",
				"transition_base_frame_key": "stage5_hongryun_result_click_transition_base_frame",
				"default_reaction_timer": StageClearResultActorDrawHelper.STAGE5_HONGRYUN_CLICK_TOTAL_DURATION,
				"rect_key": "stage5_hongryun_result_rect",
				"click_rect_key": "stage5_hongryun_result_click_rect",
			}
		6:
			return {
				"stage": 6,
				"sheet_key": "stage6_boss_defeat_sheet",
				"reaction_timer_key": "stage6_boss_defeat_click_reaction_timer",
				"transition_base_frame_key": "stage6_boss_defeat_click_transition_base_frame",
				"default_reaction_timer": StageClearResultActorDrawHelper.STAGE6_TETRISER_CLICK_TOTAL_DURATION,
				"rect_key": "stage6_boss_defeat_rect",
				"click_rect_key": "stage6_boss_defeat_click_rect",
			}
		7:
			return {
				"stage": 7,
				"sheet_key": "stage7_boss_defeat_sheet",
				"reaction_timer_key": "stage7_boss_defeat_click_reaction_timer",
				"transition_base_frame_key": "stage7_boss_defeat_click_transition_base_frame",
				"default_reaction_timer": StageClearResultActorDrawHelper.STAGE7_AKAMU_CLICK_TOTAL_DURATION,
				"rect_key": "stage7_boss_defeat_rect",
				"click_rect_key": "stage7_boss_defeat_click_rect",
			}
	return {}


static func _draw_stage_result_fallback_actor(
	canvas: CanvasItem,
	draw_context: Dictionary,
	view_size: Vector2,
	draw_scale: float,
	config: Dictionary
) -> Dictionary:
	var sheet_key: String = String(config.get("sheet_key", ""))
	var sheet: Texture2D = draw_context.get(sheet_key, null) as Texture2D
	if sheet == null:
		# 스테이지 7은 시트 부재가 스폰을 막지 않는다: AutoSprite 결과
		# 시트가 도착하기 전에는 코드 네이티브 아카무 액터가 같은 공유
		# rect에 그려진다(시트가 도착하면 자동 승격). 클릭 반응은 시트
		# 프레임 연출이라 실입력 계약(sheet != null 게이트)과 맞춰 폴백은
		# 클릭 rect를 광고하지 않는다.
		if int(config.get("stage", 0)) == 7:
			var code_native_rect: Rect2 = StageClearResultLayoutHelper.get_stage7_result_draw_rect(view_size, draw_scale)
			StageClearResultActorDrawHelper.draw_stage7_akamu_code_native(
				canvas,
				code_native_rect,
				float(draw_context.get("timer", 0.0))
			)
			return {
				String(config.get("rect_key", "")): code_native_rect,
			}
		return {}

	var timer: float = float(draw_context.get("timer", 0.0))
	var reaction_timer_key: String = String(config.get("reaction_timer_key", ""))
	var transition_base_frame_key: String = String(config.get("transition_base_frame_key", ""))
	var reaction_timer: float = float(draw_context.get(reaction_timer_key, float(config.get("default_reaction_timer", 0.0))))
	var transition_base_frame: int = int(draw_context.get(transition_base_frame_key, 0))
	var draw_rect := Rect2()
	match int(config.get("stage", 0)):
		5:
			draw_rect = StageClearResultActorDrawHelper.draw_stage5_hongryun_result_fallback(
				canvas,
				sheet,
				timer,
				view_size,
				draw_scale,
				0.98,
				reaction_timer,
				transition_base_frame
			)
		6:
			draw_rect = StageClearResultActorDrawHelper.draw_stage6_tetriser_defeated(
				canvas,
				sheet,
				timer,
				view_size,
				draw_scale,
				0.98,
				reaction_timer,
				transition_base_frame
			)
		7:
			draw_rect = StageClearResultActorDrawHelper.draw_stage7_akamu_defeated(
				canvas,
				sheet,
				timer,
				view_size,
				draw_scale,
				0.98,
				reaction_timer,
				transition_base_frame
			)
		_:
			return {}

	return {
		String(config.get("rect_key", "")): draw_rect,
		String(config.get("click_rect_key", "")): draw_rect,
	}


static func get_defeated_boss_draw_apply_result(
	draw_result: Dictionary,
	current_dalji_click_rect: Rect2,
	current_stage6_boss_defeat_click_rect: Rect2 = Rect2(),
	current_stage4_ponk_boss_defeat_click_rect: Rect2 = Rect2(),
	current_stage5_hongryun_result_click_rect: Rect2 = Rect2(),
	current_stage7_boss_defeat_click_rect: Rect2 = Rect2()
) -> Dictionary:
	return _get_click_rect_apply_result(
		draw_result,
		_get_defeated_boss_click_rect_payload_configs(
			current_dalji_click_rect,
			current_stage6_boss_defeat_click_rect,
			current_stage4_ponk_boss_defeat_click_rect,
			current_stage5_hongryun_result_click_rect,
			current_stage7_boss_defeat_click_rect
		)
	)


static func get_defeated_boss_draw_scene_apply_result(
	draw_result: Dictionary,
	current_dalji_click_rect: Rect2,
	current_stage6_boss_defeat_click_rect: Rect2 = Rect2(),
	current_stage4_ponk_boss_defeat_click_rect: Rect2 = Rect2(),
	current_stage5_hongryun_result_click_rect: Rect2 = Rect2(),
	current_stage7_boss_defeat_click_rect: Rect2 = Rect2()
) -> Dictionary:
	var payload_configs: Array[Dictionary] = _get_defeated_boss_click_rect_payload_configs(
		current_dalji_click_rect,
		current_stage6_boss_defeat_click_rect,
		current_stage4_ponk_boss_defeat_click_rect,
		current_stage5_hongryun_result_click_rect,
		current_stage7_boss_defeat_click_rect
	)
	var apply_result: Dictionary = _get_click_rect_apply_result(draw_result, payload_configs)
	return {
		"field_payload": _get_click_rect_field_payload(apply_result, payload_configs),
	}


static func _get_defeated_boss_click_rect_payload_configs(
	current_dalji_click_rect: Rect2,
	current_stage6_boss_defeat_click_rect: Rect2,
	current_stage4_ponk_boss_defeat_click_rect: Rect2,
	current_stage5_hongryun_result_click_rect: Rect2,
	current_stage7_boss_defeat_click_rect: Rect2
) -> Array[Dictionary]:
	return [
		{
			"apply_key": "dalji_click_rect",
			"field_key": "_dalji_click_rect",
			"current_rect": current_dalji_click_rect,
		},
		{
			"apply_key": "stage6_boss_defeat_click_rect",
			"field_key": "_stage6_boss_defeat_click_rect",
			"current_rect": current_stage6_boss_defeat_click_rect,
		},
		{
			"apply_key": "stage4_ponk_boss_defeat_click_rect",
			"field_key": "_stage4_ponk_boss_defeat_click_rect",
			"current_rect": current_stage4_ponk_boss_defeat_click_rect,
		},
		{
			"apply_key": "stage5_hongryun_result_click_rect",
			"field_key": "_stage5_hongryun_result_click_rect",
			"current_rect": current_stage5_hongryun_result_click_rect,
		},
		{
			"apply_key": "stage7_boss_defeat_click_rect",
			"field_key": "_stage7_boss_defeat_click_rect",
			"current_rect": current_stage7_boss_defeat_click_rect,
		},
	]


static func _get_click_rect_apply_result(draw_result: Dictionary, payload_configs: Array[Dictionary]) -> Dictionary:
	var apply_result: Dictionary = {}
	for config: Dictionary in payload_configs:
		var apply_key: String = String(config.get("apply_key", ""))
		var current_rect: Rect2 = config.get("current_rect", Rect2())
		apply_result[apply_key] = draw_result.get(apply_key, current_rect)
	return apply_result


static func _get_click_rect_field_payload(apply_result: Dictionary, payload_configs: Array[Dictionary]) -> Dictionary:
	var field_payload: Dictionary = {}
	for config: Dictionary in payload_configs:
		var apply_key: String = String(config.get("apply_key", ""))
		var field_key: String = String(config.get("field_key", ""))
		var current_rect: Rect2 = config.get("current_rect", Rect2())
		field_payload[field_key] = apply_result.get(apply_key, current_rect)
	return field_payload
