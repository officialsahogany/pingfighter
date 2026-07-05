extends RefCounted

const StageClearResultActorDrawSceneHandler := preload("res://scripts/ui/stage_clear_result_actor_draw_scene_handler.gd")
const StageClearResultBoxSceneHandler := preload("res://scripts/ui/stage_clear_result_box_scene_handler.gd")
const StageClearResultConfigSceneHandler := preload("res://scripts/ui/stage_clear_result_config_scene_handler.gd")
const StageClearResultRuntimeOverlaySceneHandler := preload("res://scripts/ui/stage_clear_result_runtime_overlay_scene_handler.gd")
const StageClearResultScrollSceneHandler := preload("res://scripts/ui/stage_clear_result_scroll_scene_handler.gd")
const StageClearResultStaticDrawHelper := preload("res://scripts/ui/stage_clear_result_static_draw_helper.gd")
const StageClearResultViewportSceneHandler := preload("res://scripts/ui/stage_clear_result_viewport_scene_handler.gd")


static func draw_result_scene(
	scene: Control,
	dalji_click_dialogue: String,
	dalji_click_dialogue_fade_duration: float
) -> void:
	if scene == null:
		return
	var view_size: Vector2 = StageClearResultViewportSceneHandler.get_current_view_size(scene)
	if view_size == Vector2.ZERO:
		return

	StageClearResultConfigSceneHandler.load_textures(scene)
	var layout_scale: float = StageClearResultViewportSceneHandler.get_layout_scale(view_size)
	var font: Font = _get_scene_font(scene, layout_scale)

	StageClearResultStaticDrawHelper.draw_background(scene, _get_scene_texture(scene, &"_background_texture"), view_size)
	scene.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.03, 0.04, 0.10, 0.22))
	StageClearResultActorDrawSceneHandler.draw_defeated_boss(scene, view_size, layout_scale)
	StageClearResultBoxSceneHandler.draw_floating_boxes(scene, layout_scale)
	StageClearResultScrollSceneHandler.draw_scroll(scene, font, view_size, layout_scale)
	StageClearResultActorDrawSceneHandler.draw_player_victory(scene, view_size, layout_scale, font)
	StageClearResultStaticDrawHelper.draw_dalji_click_dialogue(
		scene,
		font,
		view_size,
		layout_scale,
		_get_scene_float(scene, &"_dalji_dialogue_timer"),
		dalji_click_dialogue_fade_duration,
		dalji_click_dialogue
	)
	StageClearResultStaticDrawHelper.draw_plaza_notice(
		scene,
		font,
		layout_scale,
		_get_scene_rect(scene, &"_plaza_button_rect"),
		_get_scene_float(scene, &"_plaza_notice_until") - _get_scene_float(scene, &"timer")
	)
	StageClearResultStaticDrawHelper.draw_footer(
		scene,
		font,
		view_size,
		layout_scale,
		_get_scene_int(scene, &"current_stage", 1)
	)
	StageClearResultRuntimeOverlaySceneHandler.draw_overlay(scene, view_size)


static func _get_scene_font(scene: Object, layout_scale: float) -> Font:
	var font_cache: Object = _get_scene_object(scene, &"_font_cache")
	if font_cache == null or not font_cache.has_method("get_font"):
		return null
	var value: Variant = font_cache.call("get_font", layout_scale)
	return value if value is Font else null


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


static func _get_scene_object(scene: Object, field_name: StringName) -> Object:
	if scene == null:
		return null
	var value: Variant = scene.get(field_name)
	return value if value is Object else null


static func _get_scene_texture(scene: Object, field_name: StringName) -> Texture2D:
	if scene == null:
		return null
	var value: Variant = scene.get(field_name)
	return value if value is Texture2D else null


static func _get_scene_rect(scene: Object, field_name: StringName) -> Rect2:
	if scene == null:
		return Rect2()
	var value: Variant = scene.get(field_name)
	return value if value is Rect2 else Rect2()
