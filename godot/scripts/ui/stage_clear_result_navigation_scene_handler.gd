extends RefCounted

const StageClearResultBoxSceneHandler := preload("res://scripts/ui/stage_clear_result_box_scene_handler.gd")
const StageClearResultCallbackSceneHandler := preload("res://scripts/ui/stage_clear_result_callback_scene_handler.gd")
const StageClearResultNavigationActionHandler := preload("res://scripts/ui/stage_clear_result_navigation_action_handler.gd")
const StageClearResultRuntimeOverlaySceneHandler := preload("res://scripts/ui/stage_clear_result_runtime_overlay_scene_handler.gd")
const StageClearResultScrollInputHandler := preload("res://scripts/ui/stage_clear_result_scroll_input_handler.gd")
const StageClearResultScrollSceneHandler := preload("res://scripts/ui/stage_clear_result_scroll_scene_handler.gd")
const StageClearResultViewportSceneHandler := preload("res://scripts/ui/stage_clear_result_viewport_scene_handler.gd")

const PLAZA_NOTICE_DURATION := 1.6


static func handle_advance_input(scene: Object) -> bool:
	return apply_navigation_action_result(scene, StageClearResultNavigationActionHandler.get_navigation_action_apply_result(
		StageClearResultNavigationActionHandler.get_advance_action(
			_is_result_interaction_blocked(scene),
			_get_scene_string(scene, &"_scroll_phase", "hidden")
		)
	))


static func handle_escape_input(scene: Object) -> bool:
	return apply_navigation_action_result(scene, StageClearResultNavigationActionHandler.get_navigation_action_apply_result(
		StageClearResultNavigationActionHandler.get_escape_action(_get_scene_string(scene, &"_scroll_phase", "hidden"))
	))


static func handle_button_click(scene: Control, mouse_position: Vector2) -> bool:
	if scene == null:
		return false
	var view_size: Vector2 = StageClearResultViewportSceneHandler.get_current_view_size(scene)
	var layout_scale: float = StageClearResultViewportSceneHandler.get_layout_scale(view_size)
	var result: Dictionary = StageClearResultScrollInputHandler.get_button_click_result(
		mouse_position,
		_get_scene_string(scene, &"_scroll_phase", "hidden"),
		layout_scale,
		_get_scene_vector2(scene, &"_scroll_position_offset")
	)
	var apply_result: Dictionary = StageClearResultNavigationActionHandler.get_scroll_button_click_apply_result(result)
	StageClearResultScrollSceneHandler.apply_scroll_button_layout(scene, apply_result)
	return apply_navigation_action_result(scene, apply_result)


static func apply_navigation_action_result(scene: Object, result: Dictionary) -> bool:
	apply_navigation_action(scene, str(result.get("action", StageClearResultNavigationActionHandler.ACTION_NONE)))
	return bool(result.get("handled", false))


static func apply_navigation_action(scene: Object, action: String) -> void:
	if scene == null:
		return
	match action:
		StageClearResultNavigationActionHandler.ACTION_OPEN_NEXT_BOX:
			var control: Control = scene as Control
			if control != null:
				StageClearResultBoxSceneHandler.open_next_idle_box(control)
		StageClearResultNavigationActionHandler.ACTION_CONFIRM:
			StageClearResultCallbackSceneHandler.confirm(scene)
		StageClearResultNavigationActionHandler.ACTION_ENTER_PLAZA:
			StageClearResultCallbackSceneHandler.enter_plaza(scene)
		StageClearResultNavigationActionHandler.ACTION_PLAZA_NOTICE:
			_trigger_plaza_notice(scene)
		StageClearResultNavigationActionHandler.ACTION_EXIT_TO_MENU:
			StageClearResultCallbackSceneHandler.exit_to_menu(scene)


static func _trigger_plaza_notice(scene: Object) -> void:
	if scene == null:
		return
	# 단조 증가하는 scene.timer 기준 만료 시각을 심어두면 draw에서 남은 시간으로 페이드를 계산한다.
	scene.set(&"_plaza_notice_until", _get_scene_float(scene, &"timer") + PLAZA_NOTICE_DURATION)


static func _is_result_interaction_blocked(scene: Object) -> bool:
	return StageClearResultRuntimeOverlaySceneHandler.is_interaction_blocked(scene)


static func _get_scene_float(scene: Object, field_name: StringName, fallback: float = 0.0) -> float:
	if scene == null:
		return fallback
	var value: Variant = scene.get(field_name)
	return fallback if value == null else float(value)


static func _get_scene_string(scene: Object, field_name: StringName, fallback: String) -> String:
	if scene == null:
		return fallback
	return str(scene.get(field_name))


static func _get_scene_vector2(scene: Object, field_name: StringName) -> Vector2:
	if scene == null:
		return Vector2.ZERO
	var value: Variant = scene.get(field_name)
	return value if value is Vector2 else Vector2.ZERO
