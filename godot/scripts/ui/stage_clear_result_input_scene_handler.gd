extends RefCounted

const StageClearResultActorClickSceneHandler := preload("res://scripts/ui/stage_clear_result_actor_click_scene_handler.gd")
const StageClearResultBoxSceneHandler := preload("res://scripts/ui/stage_clear_result_box_scene_handler.gd")
const StageClearResultInputRouter := preload("res://scripts/ui/stage_clear_result_input_router.gd")
const StageClearResultNavigationSceneHandler := preload("res://scripts/ui/stage_clear_result_navigation_scene_handler.gd")
const StageClearResultRuntimeOverlaySceneHandler := preload("res://scripts/ui/stage_clear_result_runtime_overlay_scene_handler.gd")
const StageClearResultScrollSceneHandler := preload("res://scripts/ui/stage_clear_result_scroll_scene_handler.gd")


static func handle_result_input(scene: Control, event: InputEvent, dalji_click_dialogue_duration: float) -> bool:
	if scene == null:
		return false
	var result: Dictionary = StageClearResultInputRouter.get_result_input_route(
		event,
		get_input_router_context(scene)
	)
	var route: String = str(result.get("route", StageClearResultInputRouter.ROUTE_CONSUME))
	var mouse_position: Vector2 = result.get("mouse_position", Vector2.ZERO)
	match route:
		StageClearResultInputRouter.ROUTE_MYTHIC_ACQUISITION:
			StageClearResultScrollSceneHandler.cancel_scroll_drag(scene)
			return StageClearResultRuntimeOverlaySceneHandler.handle_mythic_acquisition_input(scene, event)
		StageClearResultInputRouter.ROUTE_RUNTIME_PERK:
			StageClearResultScrollSceneHandler.cancel_scroll_drag(scene)
			return StageClearResultRuntimeOverlaySceneHandler.handle_runtime_perk_input(scene, event)
		StageClearResultInputRouter.ROUTE_TREASURE_HUNT:
			StageClearResultScrollSceneHandler.cancel_scroll_drag(scene)
			return true
		StageClearResultInputRouter.ROUTE_ADVANCE:
			return StageClearResultNavigationSceneHandler.handle_advance_input(scene)
		StageClearResultInputRouter.ROUTE_ESCAPE:
			return StageClearResultNavigationSceneHandler.handle_escape_input(scene)
		StageClearResultInputRouter.ROUTE_MOUSE_DRAG_UPDATE:
			StageClearResultScrollSceneHandler.update_scroll_drag(scene, mouse_position)
			return true
		StageClearResultInputRouter.ROUTE_MOUSE_HOVER_BUTTON:
			StageClearResultScrollSceneHandler.update_hovered_button(scene, mouse_position)
			return true
		StageClearResultInputRouter.ROUTE_MOUSE_HOVER_BOX:
			StageClearResultBoxSceneHandler.update_hovered_box(scene, mouse_position)
			return true
		StageClearResultInputRouter.ROUTE_MOUSE_DRAG_FINISH:
			StageClearResultScrollSceneHandler.finish_scroll_drag(scene, mouse_position)
			return true
		StageClearResultInputRouter.ROUTE_MOUSE_LEFT_PRESS:
			handle_mouse_left_press(scene, mouse_position, dalji_click_dialogue_duration)
			return true
	return bool(result.get("consumed", true))


static func get_input_router_context(scene: Object) -> Dictionary:
	return StageClearResultInputRouter.get_input_router_context(
		StageClearResultRuntimeOverlaySceneHandler.is_mythic_acquisition_cinematic_active(scene),
		StageClearResultRuntimeOverlaySceneHandler.is_runtime_perk_choice_active(scene),
		StageClearResultRuntimeOverlaySceneHandler.is_treasure_hunt_effect_active(scene),
		bool(scene.get("_scroll_dragging")) if scene != null else false,
		_get_scene_string(scene, &"_scroll_phase", "hidden")
	)


static func handle_mouse_left_press(scene: Control, mouse_position: Vector2, dalji_click_dialogue_duration: float) -> void:
	if scene == null:
		return
	var handled_click: bool = (
		StageClearResultActorClickSceneHandler.handle_dalji_click(scene, mouse_position, dalji_click_dialogue_duration)
		or StageClearResultActorClickSceneHandler.handle_current_boss_result_click(scene, mouse_position)
		or StageClearResultActorClickSceneHandler.handle_player_victory_click(scene, mouse_position)
		or StageClearResultScrollSceneHandler.start_scroll_drag(scene, mouse_position)
		or StageClearResultNavigationSceneHandler.handle_button_click(scene, mouse_position)
		or StageClearResultBoxSceneHandler.handle_box_click(scene, mouse_position)
	)
	if not handled_click:
		StageClearResultBoxSceneHandler.update_hovered_box(scene, mouse_position)


static func _get_scene_string(scene: Object, field_name: StringName, fallback: String) -> String:
	if scene == null:
		return fallback
	var value: Variant = scene.get(field_name)
	return fallback if value == null else str(value)
