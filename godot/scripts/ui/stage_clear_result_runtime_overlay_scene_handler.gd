extends RefCounted

const StageClearResultRuntimeOverlayPresenter := preload("res://scripts/ui/stage_clear_result_runtime_overlay_presenter.gd")
const StageClearResultViewportSceneHandler := preload("res://scripts/ui/stage_clear_result_viewport_scene_handler.gd")


static func handle_runtime_perk_input(scene: Control, event: InputEvent) -> bool:
	var handled: bool = StageClearResultRuntimeOverlayPresenter.handle_runtime_perk_input(
		event,
		_get_scene_object(scene, &"_runtime_perk_state"),
		_get_scene_object(scene, &"_runtime_perk_owner"),
		_get_scene_object(scene, &"_runtime_perk_registry"),
		StageClearResultViewportSceneHandler.get_current_view_size(scene)
	)
	if scene != null:
		scene.queue_redraw()
	return handled


static func handle_mythic_acquisition_input(scene: Control, event: InputEvent) -> bool:
	var handled: bool = StageClearResultRuntimeOverlayPresenter.handle_mythic_acquisition_input(
		event,
		_get_scene_object(scene, &"_mythic_item_runtime"),
		_get_scene_object(scene, &"_runtime_perk_registry")
	)
	if scene != null:
		scene.queue_redraw()
	return handled


static func is_mythic_acquisition_cinematic_active(scene: Object) -> bool:
	return StageClearResultRuntimeOverlayPresenter.is_mythic_acquisition_cinematic_active(
		_get_scene_object(scene, &"_mythic_item_runtime")
	)


static func is_treasure_hunt_effect_active(scene: Object) -> bool:
	return StageClearResultRuntimeOverlayPresenter.is_treasure_hunt_effect_active(
		_get_scene_object(scene, &"_treasure_hunt_runtime")
	)


static func is_runtime_perk_choice_active(scene: Object) -> bool:
	return StageClearResultRuntimeOverlayPresenter.is_runtime_perk_choice_active(
		_get_scene_object(scene, &"_runtime_perk_state")
	)


static func is_interaction_blocked(scene: Object) -> bool:
	return StageClearResultRuntimeOverlayPresenter.is_interaction_blocked(
		bool(scene.get("_starpoint_choice_gate_active")) if scene != null else false,
		_get_scene_object(scene, &"_runtime_perk_state"),
		_get_scene_object(scene, &"_treasure_hunt_runtime")
	)


static func should_draw_overlay(scene: Object) -> bool:
	return StageClearResultRuntimeOverlayPresenter.should_draw_overlay(
		_get_scene_object(scene, &"_runtime_perk_overlay_renderer"),
		_get_scene_object(scene, &"_runtime_perk_state"),
		_get_scene_object(scene, &"_mythic_item_runtime"),
		_get_scene_object(scene, &"_treasure_hunt_runtime")
	)


static func draw_overlay(scene: CanvasItem, view_size: Vector2) -> bool:
	return StageClearResultRuntimeOverlayPresenter.draw_overlay(
		scene,
		_get_scene_object(scene, &"_runtime_perk_overlay_renderer"),
		_get_scene_object(scene, &"_runtime_perk_state"),
		_get_scene_object(scene, &"_perk_catalog"),
		_get_scene_object(scene, &"_runtime_perk_catalog"),
		_get_scene_object(scene, &"_perk_icon_renderer"),
		_get_scene_object(scene, &"_runtime_perk_icon_renderer"),
		view_size,
		_get_scene_object(scene, &"_mythic_item_runtime"),
		_get_scene_object(scene, &"_treasure_hunt_runtime")
	)


static func set_starpoint_choice_gate_active(scene: Control, active: bool, box_index: int = -1) -> void:
	if scene == null:
		return
	scene.set("_starpoint_choice_gate_active", active)
	scene.set("_starpoint_choice_gate_box_index", box_index if active else -1)
	scene.queue_redraw()


static func _get_scene_object(scene: Object, field_name: StringName) -> Object:
	if scene == null:
		return null
	var value: Variant = scene.get(field_name)
	return value if value is Object else null
