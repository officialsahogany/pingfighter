extends RefCounted

const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")
const StageClearResultActorPresenter := preload("res://scripts/ui/stage_clear_result_actor_presenter.gd")
const StageClearResultFieldApplySceneHandler := preload("res://scripts/ui/stage_clear_result_field_apply_scene_handler.gd")
const StageClearResultStaticDrawHelper := preload("res://scripts/ui/stage_clear_result_static_draw_helper.gd")

const PLAYER_VICTORY_FALLBACK_TITLE := "플레이어 승리"
const PLAYER_VICTORY_FALLBACK_SUBTITLE := "Live2D 포즈"
const PLAYER_VICTORY_FALLBACK_HINT := "승리 연출 테스트"


static func draw_defeated_boss(scene: Control, view_size: Vector2, draw_scale: float) -> void:
	if scene == null:
		return
	var result: Dictionary = StageClearResultActorPresenter.draw_defeated_boss(
		scene,
		view_size,
		draw_scale,
		get_defeated_boss_draw_context(scene)
	)
	_apply_scene_apply_result(scene, StageClearResultActorPresenter.get_defeated_boss_draw_scene_apply_result(
		result,
		_get_scene_rect(scene, &"_dalji_click_rect"),
		_get_scene_rect(scene, &"_stage6_boss_defeat_click_rect"),
		_get_scene_rect(scene, &"_stage4_ponk_boss_defeat_click_rect"),
		_get_scene_rect(scene, &"_stage5_hongryun_result_click_rect"),
		_get_scene_rect(scene, &"_stage7_boss_defeat_click_rect")
	))


static func draw_player_victory(scene: Control, view_size: Vector2, draw_scale: float, font: Font) -> void:
	if scene == null:
		return
	if draw_player_victory_live2d(scene, view_size, draw_scale):
		return
	StageClearResultStaticDrawHelper.draw_player_victory_fallback(
		scene,
		font,
		view_size,
		draw_scale,
		_get_scene_float(scene, &"timer"),
		_get_scene_texture(scene, &"_player_victory_sheet"),
		StageClearResultActorDrawHelper.PLAYER_VICTORY_FRAME_INTERVAL,
		StageClearResultActorDrawHelper.PLAYER_VICTORY_FRAME_COUNT,
		StageClearResultActorDrawHelper.PLAYER_VICTORY_GRID_COLS,
		StageClearResultActorDrawHelper.PLAYER_VICTORY_CELL_SIZE,
		PLAYER_VICTORY_FALLBACK_TITLE,
		PLAYER_VICTORY_FALLBACK_SUBTITLE,
		PLAYER_VICTORY_FALLBACK_HINT
	)


static func draw_player_victory_live2d(scene: Control, view_size: Vector2, draw_scale: float) -> bool:
	if scene == null:
		return false
	var result: Dictionary = StageClearResultActorPresenter.draw_player_victory_live2d(
		scene,
		view_size,
		draw_scale,
		get_player_victory_draw_context(scene)
	)
	var apply_result: Dictionary = StageClearResultActorPresenter.get_player_victory_draw_scene_apply_result(result)
	_apply_scene_apply_result(scene, apply_result)
	return bool(apply_result.get("drawn", true))


static func get_defeated_boss_draw_context(scene: Object) -> Dictionary:
	return StageClearResultActorPresenter.get_defeated_boss_draw_context(
		_get_scene_int(scene, &"current_stage", 1),
		_get_scene_float(scene, &"timer"),
		_get_scene_float(scene, &"_dalji_base_timer"),
		_get_scene_float(scene, &"_dalji_click_reaction_timer", StageClearResultActorDrawHelper.DALJI_CLICK_TOTAL_DURATION),
		_get_scene_int(scene, &"_dalji_click_transition_base_frame"),
		_get_scene_texture(scene, &"_dalji_defeat_sheet"),
		_get_scene_texture(scene, &"_dalji_click_reaction_sheet"),
		_get_scene_texture(scene, &"_stage2_boss_defeat_live2d_sheet"),
		_get_scene_texture(scene, &"_stage2_boss_defeat_click_reaction_sheet"),
		_get_scene_float(scene, &"_stage2_boss_defeat_click_reaction_timer", StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION),
		_get_scene_int(scene, &"_stage2_boss_defeat_click_transition_base_frame"),
		_get_scene_texture(scene, &"_stage3_boss_defeat_live2d_sheet"),
		_get_scene_texture(scene, &"_stage3_boss_defeat_click_reaction_sheet"),
		_get_scene_float(scene, &"_stage3_boss_defeat_click_reaction_timer", StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION),
		_get_scene_int(scene, &"_stage3_boss_defeat_click_transition_base_frame"),
		_get_scene_texture(scene, &"_stage4_ponk_boss_defeat_live2d_sheet"),
		_get_scene_texture(scene, &"_stage4_ponk_boss_defeat_click_reaction_sheet"),
		_get_scene_float(scene, &"_stage4_ponk_boss_defeat_click_reaction_timer", StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION),
		_get_scene_int(scene, &"_stage4_ponk_boss_defeat_click_transition_base_frame"),
		_get_scene_texture(scene, &"_stage6_boss_defeat_sheet"),
		_get_scene_float(scene, &"_stage6_boss_defeat_click_reaction_timer", StageClearResultActorDrawHelper.STAGE6_TETRISER_CLICK_TOTAL_DURATION),
		_get_scene_int(scene, &"_stage6_boss_defeat_click_transition_base_frame"),
		_get_scene_texture(scene, &"_stage5_hongryun_result_sheet"),
		_get_scene_float(scene, &"_stage5_hongryun_result_click_reaction_timer", StageClearResultActorDrawHelper.STAGE5_HONGRYUN_CLICK_TOTAL_DURATION),
		_get_scene_int(scene, &"_stage5_hongryun_result_click_transition_base_frame"),
		_get_scene_texture(scene, &"_stage7_boss_defeat_sheet"),
		_get_scene_float(scene, &"_stage7_boss_defeat_click_reaction_timer", StageClearResultActorDrawHelper.STAGE7_AKAMU_CLICK_TOTAL_DURATION),
		_get_scene_int(scene, &"_stage7_boss_defeat_click_transition_base_frame")
	)


static func get_player_victory_draw_context(scene: Object) -> Dictionary:
	return StageClearResultActorPresenter.get_player_victory_draw_context(
		_get_scene_float(scene, &"timer"),
		_get_scene_float(scene, &"_player_victory_click_reaction_timer", StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_TOTAL_DURATION),
		_get_scene_int(scene, &"_player_victory_click_transition_base_frame"),
		_get_scene_texture(scene, &"_player_victory_sheet"),
		_get_scene_texture(scene, &"_player_victory_click_reaction_sheet")
	)


static func _apply_scene_apply_result(scene: Object, apply_result: Dictionary) -> void:
	StageClearResultFieldApplySceneHandler.apply_scene_apply_result(scene, apply_result)


static func _get_scene_float(scene: Object, field_name: StringName, fallback: float = 0.0) -> float:
	if scene == null:
		return fallback
	var value: Variant = scene.get(field_name)
	return fallback if value == null else float(value)


static func _get_scene_int(scene: Object, field_name: StringName, fallback: int = 0) -> int:
	if scene == null:
		return fallback
	var value: Variant = scene.get(field_name)
	return fallback if value == null else int(value)


static func _get_scene_rect(scene: Object, field_name: StringName) -> Rect2:
	if scene == null:
		return Rect2()
	var value: Variant = scene.get(field_name)
	return value if value is Rect2 else Rect2()


static func _get_scene_texture(scene: Object, field_name: StringName) -> Texture2D:
	if scene == null:
		return null
	var value: Variant = scene.get(field_name)
	return value if value is Texture2D else null
