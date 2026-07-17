extends RefCounted

const StageClearResultScrollInputHandler := preload("res://scripts/ui/stage_clear_result_scroll_input_handler.gd")
const StageClearResultScrollPresenter := preload("res://scripts/ui/stage_clear_result_scroll_presenter.gd")
const StageClearResultScrollUpdateHandler := preload("res://scripts/ui/stage_clear_result_scroll_update_handler.gd")
const StageClearResultFieldApplySceneHandler := preload("res://scripts/ui/stage_clear_result_field_apply_scene_handler.gd")
const StageClearResultRuntimeOverlaySceneHandler := preload("res://scripts/ui/stage_clear_result_runtime_overlay_scene_handler.gd")
const StageClearResultViewportSceneHandler := preload("res://scripts/ui/stage_clear_result_viewport_scene_handler.gd")


# 결과 씬 구성 직후 융합 보상 카드 아이콘을 실 fitted 크기로 프리컴포즈한다
# (드로우 핫패스 합성 금지). 스냅샷 퍽 밴드+결과상자 resolved 보상을 함께
# 순회한다. 반환=준비한 융합 아이콘 수.
static func prepare_fusion_reward_icons(scene: Control) -> int:
	if scene == null:
		return 0
	# 보상 카드 드로우 컨텍스트("perk_icon_renderer")가 소비하는 인스턴스는
	# 씬 로컬 _perk_icon_renderer다 — 배틀 레지스트리 주입본(_runtime_perk_
	# icon_renderer)을 데우면 카드 경로는 빈 캐시를 본다(별개 인스턴스).
	var renderer: Object = scene.get("_perk_icon_renderer")
	if renderer == null or not renderer.has_method("prepare_fusion_pair_icon"):
		renderer = scene.get("_runtime_perk_icon_renderer")
	if renderer == null or not renderer.has_method("prepare_fusion_pair_icon"):
		return 0
	var snapshot: Dictionary = scene.get("stage_reward_snapshot") if scene.get("stage_reward_snapshot") is Dictionary else {}
	var view_size: Vector2 = scene.size
	var layout_scale: float = load("res://scripts/ui/stage_clear_result_viewport_scene_handler.gd").get_layout_scale(view_size)
	var icon_size: Vector2 = load("res://scripts/ui/stage_clear_result_scroll_content_draw_helper.gd").get_fusion_reward_card_icon_size(
		view_size,
		layout_scale,
		snapshot,
		[]
	)
	var prepared := 0
	var pending: Array = []
	var perks_value: Variant = snapshot.get("perks", [])
	if perks_value is Array:
		pending.append_array(perks_value)
	var boxes_value: Variant = scene.get("_boxes")
	if boxes_value is Array:
		for box_value: Variant in boxes_value:
			if not (box_value is Dictionary):
				continue
			var reward_value: Variant = (box_value as Dictionary).get("reward", {})
			if reward_value is Dictionary:
				var resolved_value: Variant = (reward_value as Dictionary).get("resolved_perk_rewards", [])
				if resolved_value is Array:
					pending.append_array(resolved_value)
	for reward_entry_value: Variant in pending:
		if not (reward_entry_value is Dictionary):
			continue
		var draw_id := str((reward_entry_value as Dictionary).get("draw_id", ""))
		if not draw_id.begins_with("perk_fusion_pair:"):
			continue
		if renderer.prepare_fusion_pair_icon(draw_id, icon_size, true):
			prepared += 1
	return prepared


static func update_hovered_button(scene: Control, mouse_position: Vector2) -> void:
	if scene == null:
		return
	var view_size: Vector2 = StageClearResultViewportSceneHandler.get_current_view_size(scene)
	var layout_scale: float = StageClearResultViewportSceneHandler.get_layout_scale(view_size)
	var result: Dictionary = StageClearResultScrollInputHandler.get_hovered_button_result(
		mouse_position,
		_get_scene_string(scene, &"_hovered_button", "none"),
		_get_scene_string(scene, &"_scroll_phase", "hidden"),
		layout_scale,
		_get_scene_vector2(scene, &"_scroll_position_offset")
	)
	var apply_result: Dictionary = StageClearResultScrollInputHandler.get_hovered_button_apply_result(
		result,
		_get_scene_string(scene, &"_hovered_button", "none")
	)
	apply_scroll_state_result(scene, apply_result)
	_queue_redraw_if_requested(scene, apply_result)


static func start_scroll_drag(scene: Control, mouse_position: Vector2) -> bool:
	if scene == null:
		return false
	var view_size: Vector2 = StageClearResultViewportSceneHandler.get_current_view_size(scene)
	var layout_scale: float = StageClearResultViewportSceneHandler.get_layout_scale(view_size)
	var drag_state: Dictionary = StageClearResultScrollInputHandler.get_drag_start_result(
		mouse_position,
		_get_scene_string(scene, &"_scroll_phase", "hidden"),
		_is_result_interaction_blocked(scene),
		layout_scale,
		_get_scene_vector2(scene, &"_scroll_position_offset")
	)
	var apply_result: Dictionary = StageClearResultScrollInputHandler.get_drag_start_apply_result(
		drag_state,
		bool(scene.get("_scroll_dragging")),
		_get_scene_vector2(scene, &"_scroll_drag_grab_offset"),
		_get_scene_string(scene, &"_hovered_button", "none")
	)
	apply_scroll_state_result(scene, apply_result)
	if not bool(apply_result.get("started", false)):
		return false
	_queue_redraw_if_requested(scene, apply_result)
	return true


static func update_scroll_drag(scene: Control, mouse_position: Vector2) -> void:
	if scene == null:
		return
	var view_size: Vector2 = StageClearResultViewportSceneHandler.get_current_view_size(scene)
	var layout_scale: float = StageClearResultViewportSceneHandler.get_layout_scale(view_size)
	var result: Dictionary = StageClearResultScrollInputHandler.get_drag_update_result(
		mouse_position,
		_get_scene_vector2(scene, &"_scroll_drag_grab_offset"),
		_get_scene_string(scene, &"_scroll_phase", "hidden"),
		layout_scale,
		view_size
	)
	var apply_result: Dictionary = StageClearResultScrollInputHandler.get_drag_update_apply_result(
		result,
		_get_scene_vector2(scene, &"_scroll_position_offset")
	)
	apply_scroll_state_result(scene, apply_result)
	_queue_redraw_if_requested(scene, apply_result)


static func finish_scroll_drag(scene: Control, mouse_position: Vector2) -> void:
	if scene == null:
		return
	var view_size: Vector2 = StageClearResultViewportSceneHandler.get_current_view_size(scene)
	var layout_scale: float = StageClearResultViewportSceneHandler.get_layout_scale(view_size)
	var scroll_phase: String = _get_scene_string(scene, &"_scroll_phase", "hidden")
	var hovered_button: String = _get_scene_string(scene, &"_hovered_button", "none")
	var result: Dictionary = StageClearResultScrollInputHandler.get_drag_finish_result(
		mouse_position,
		_get_scene_vector2(scene, &"_scroll_drag_grab_offset"),
		scroll_phase,
		hovered_button,
		layout_scale,
		view_size
	)
	var apply_result: Dictionary = StageClearResultScrollInputHandler.get_drag_finish_apply_result(
		result,
		scroll_phase,
		_get_scene_vector2(scene, &"_scroll_position_offset"),
		hovered_button
	)
	apply_scroll_state_result(scene, apply_result)
	_queue_redraw_if_requested(scene, apply_result)


static func cancel_scroll_drag(scene: Control) -> void:
	if scene == null:
		return
	var apply_result: Dictionary = StageClearResultScrollInputHandler.get_drag_cancel_apply_result(
		bool(scene.get("_scroll_dragging"))
	)
	apply_scroll_state_result(scene, apply_result)
	_queue_redraw_if_requested(scene, apply_result)


static func refresh_scroll_button_rects(scene: Control) -> void:
	if scene == null:
		return
	var view_size: Vector2 = StageClearResultViewportSceneHandler.get_current_view_size(scene)
	var layout_scale: float = StageClearResultViewportSceneHandler.get_layout_scale(view_size)
	var button_layout: Dictionary = StageClearResultScrollInputHandler.get_button_layout(
		_get_scene_string(scene, &"_scroll_phase", "hidden"),
		layout_scale,
		_get_scene_vector2(scene, &"_scroll_position_offset")
	)
	apply_scroll_button_layout(scene, button_layout)


static func apply_scroll_button_layout(scene: Object, button_layout: Dictionary) -> void:
	apply_scroll_state_result(scene, button_layout)


static func apply_scroll_state_result(scene: Object, result: Dictionary) -> void:
	if scene == null:
		return
	var apply_result: Dictionary = StageClearResultScrollInputHandler.get_scroll_state_scene_apply_result(
		result,
		get_scroll_state_current_state(scene)
	)
	StageClearResultFieldApplySceneHandler.apply_scene_apply_result(scene, apply_result)


static func update_scroll(scene: Control, delta: float) -> void:
	if scene == null:
		return
	var result: Dictionary = StageClearResultScrollUpdateHandler.update_scroll(
		_get_scene_string(scene, &"_scroll_phase", "hidden"),
		_get_scene_float(scene, &"_scroll_timer"),
		delta,
		_get_scene_array(scene, &"_boxes"),
		_is_result_interaction_blocked(scene)
	)
	StageClearResultFieldApplySceneHandler.apply_scene_apply_result(
		scene,
		StageClearResultScrollUpdateHandler.get_scroll_update_scene_apply_result(
			result,
			_get_scene_string(scene, &"_scroll_phase", "hidden"),
			_get_scene_float(scene, &"_scroll_timer")
		)
	)


static func draw_scroll(scene: Control, font: Font, view_size: Vector2, draw_scale: float) -> void:
	if scene == null:
		return
	var result: Dictionary = StageClearResultScrollPresenter.draw_scroll(
		scene,
		font,
		view_size,
		draw_scale,
		_get_scene_texture(scene, &"_scroll_texture"),
		get_scroll_draw_context(scene)
	)
	apply_scroll_state_result(scene, StageClearResultScrollPresenter.get_scroll_draw_apply_result(
		result,
		_get_scene_vector2(scene, &"_scroll_position_offset")
	))


static func get_scroll_draw_context(scene: Object) -> Dictionary:
	return StageClearResultScrollPresenter.get_scroll_draw_context(
		_get_scene_int(scene, &"current_stage", 1),
		_get_scene_dictionary(scene, &"stage_reward_snapshot"),
		_get_scene_array(scene, &"_boxes"),
		_get_scene_object(scene, &"_runtime_perk_state"),
		_get_scene_int(scene, &"player_score"),
		_get_scene_int(scene, &"boss_score"),
		_get_scene_float(scene, &"timer"),
		_get_scene_object(scene, &"_perk_catalog"),
		_get_scene_object(scene, &"_perk_icon_renderer"),
		_get_scene_dictionary(scene, &"_reward_icon_cache"),
		_get_scene_string(scene, &"_scroll_phase", "hidden"),
		_get_scene_float(scene, &"_scroll_timer"),
		_get_scene_vector2(scene, &"_scroll_position_offset"),
		_get_scene_string(scene, &"_hovered_button", "none")
	)


static func get_scroll_state_current_state(scene: Object) -> Dictionary:
	return {
		"next_stage_rect": _get_scene_rect2(scene, &"_next_stage_button_rect"),
		"plaza_rect": _get_scene_rect2(scene, &"_plaza_button_rect"),
		"exit_rect": _get_scene_rect2(scene, &"_exit_button_rect"),
		"scroll_position_offset": _get_scene_vector2(scene, &"_scroll_position_offset"),
		"scroll_dragging": bool(scene.get("_scroll_dragging")) if scene != null else false,
		"scroll_drag_grab_offset": _get_scene_vector2(scene, &"_scroll_drag_grab_offset"),
		"hovered_button": _get_scene_string(scene, &"_hovered_button", "none"),
	}


static func _queue_redraw_if_requested(scene: Control, apply_result: Dictionary) -> void:
	if bool(apply_result.get("redraw", false)):
		scene.queue_redraw()


static func _is_result_interaction_blocked(scene: Object) -> bool:
	return StageClearResultRuntimeOverlaySceneHandler.is_interaction_blocked(scene)


static func _get_scene_rect2(scene: Object, field_name: StringName) -> Rect2:
	if scene == null:
		return Rect2()
	var value: Variant = scene.get(field_name)
	return value if value is Rect2 else Rect2()


static func _get_scene_vector2(scene: Object, field_name: StringName) -> Vector2:
	if scene == null:
		return Vector2.ZERO
	var value: Variant = scene.get(field_name)
	return value if value is Vector2 else Vector2.ZERO


static func _get_scene_string(scene: Object, field_name: StringName, fallback: String) -> String:
	if scene == null:
		return fallback
	var value: Variant = scene.get(field_name)
	return fallback if value == null else str(value)


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


static func _get_scene_array(scene: Object, field_name: StringName) -> Array:
	if scene == null:
		return []
	var value: Variant = scene.get(field_name)
	return value if value is Array else []


static func _get_scene_dictionary(scene: Object, field_name: StringName) -> Dictionary:
	if scene == null:
		return {}
	var value: Variant = scene.get(field_name)
	return value if value is Dictionary else {}


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
