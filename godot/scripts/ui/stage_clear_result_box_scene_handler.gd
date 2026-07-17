extends RefCounted

const StageClearResultAudioSceneHandler := preload("res://scripts/ui/stage_clear_result_audio_scene_handler.gd")
const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")
const StageClearResultBoxInputHandler := preload("res://scripts/ui/stage_clear_result_box_input_handler.gd")
const StageClearResultBoxPresenter := preload("res://scripts/ui/stage_clear_result_box_presenter.gd")
const StageClearResultBoxUpdateHandler := preload("res://scripts/ui/stage_clear_result_box_update_handler.gd")
const StageClearResultFieldApplySceneHandler := preload("res://scripts/ui/stage_clear_result_field_apply_scene_handler.gd")
const StageClearResultRuntimeOverlaySceneHandler := preload("res://scripts/ui/stage_clear_result_runtime_overlay_scene_handler.gd")
const StageClearResultViewportSceneHandler := preload("res://scripts/ui/stage_clear_result_viewport_scene_handler.gd")


static func open_next_idle_box(scene: Control) -> bool:
	if scene == null or _is_result_interaction_blocked(scene):
		return false
	return apply_box_open_result(scene, StageClearResultBoxInputHandler.open_next_idle_box(
		_get_scene_array(scene, &"_boxes"),
		_get_scene_callable(scene, &"reward_roll_callback")
	))


static func handle_box_click(scene: Control, mouse_position: Vector2) -> bool:
	if scene == null:
		return false
	var view_size: Vector2 = StageClearResultViewportSceneHandler.get_current_view_size(scene)
	var draw_scale: float = StageClearResultViewportSceneHandler.get_layout_scale(view_size)
	return apply_box_open_result(scene, StageClearResultBoxInputHandler.get_box_click_result(
		_get_scene_array(scene, &"_boxes"),
		mouse_position,
		_get_scene_string(scene, &"_scroll_phase", "hidden"),
		_is_result_interaction_blocked(scene),
		draw_scale,
		float(scene.get("timer")),
		_get_scene_callable(scene, &"reward_roll_callback")
	))


static func apply_box_open_result(scene: Control, result: Dictionary) -> bool:
	if scene == null:
		return false
	var apply_result: Dictionary = StageClearResultBoxInputHandler.get_box_open_apply_result(
		result,
		_get_scene_array(scene, &"_boxes"),
		int(scene.get("_hovered_box_index"))
	)
	apply_result = apply_box_state_result(scene, apply_result)
	return bool(apply_result.get("consumed", false))


static func apply_box_state_result(scene: Control, result: Dictionary) -> Dictionary:
	if scene == null:
		return {}
	var apply_result: Dictionary = StageClearResultBoxInputHandler.get_box_state_scene_apply_result(
		result,
		_get_scene_array(scene, &"_boxes"),
		int(scene.get("_hovered_box_index"))
	)
	StageClearResultFieldApplySceneHandler.apply_scene_apply_result(scene, apply_result)
	if bool(apply_result.get("play_open_audio", false)):
		StageClearResultAudioSceneHandler.play_result_box_open_audio(scene)
	if bool(apply_result.get("redraw", false)):
		scene.queue_redraw()
	return apply_result


static func update_boxes(scene: Control, delta: float) -> void:
	if scene == null:
		return
	var view_size: Vector2 = StageClearResultViewportSceneHandler.get_current_view_size(scene)
	var draw_scale: float = StageClearResultViewportSceneHandler.get_layout_scale(view_size)
	var result: Dictionary = StageClearResultBoxUpdateHandler.update_boxes(
		_get_scene_array(scene, &"_boxes"),
		delta,
		int(scene.get("_lid_open_counter")),
		_get_scene_callable(scene, &"immediate_reward_callback"),
		view_size,
		draw_scale,
		float(scene.get("timer"))
	)
	StageClearResultFieldApplySceneHandler.apply_scene_apply_result(
		scene,
		StageClearResultBoxUpdateHandler.get_box_update_scene_apply_result(
			result,
			_get_scene_array(scene, &"_boxes"),
			int(scene.get("_lid_open_counter"))
		)
	)


static func update_hovered_box(scene: Control, mouse_position: Vector2) -> void:
	if scene == null:
		return
	var view_size: Vector2 = StageClearResultViewportSceneHandler.get_current_view_size(scene)
	var draw_scale: float = StageClearResultViewportSceneHandler.get_layout_scale(view_size)
	var result: Dictionary = StageClearResultBoxInputHandler.get_hovered_box_result(
		_get_scene_array(scene, &"_boxes"),
		mouse_position,
		draw_scale,
		float(scene.get("timer")),
		int(scene.get("_hovered_box_index"))
	)
	apply_box_state_result(scene, StageClearResultBoxInputHandler.get_hovered_box_apply_result(
		result,
		int(scene.get("_hovered_box_index"))
	))


static func draw_floating_boxes(scene: Control, draw_scale: float) -> void:
	if scene == null:
		return
	StageClearResultBoxPresenter.draw_floating_boxes(
		scene,
		_get_scene_array(scene, &"_boxes"),
		draw_scale,
		get_floating_box_draw_context(scene)
	)


static func get_floating_box_draw_context(scene: Object) -> Dictionary:
	return StageClearResultBoxPresenter.get_floating_box_draw_context(
		_get_scene_float(scene, &"timer"),
		_get_scene_string(scene, &"_scroll_phase", "hidden"),
		_get_scene_float(scene, &"_scroll_timer"),
		_get_scene_int(scene, &"_hovered_box_index", -1),
		_get_scene_texture(scene, &"_result_box_sheet_common"),
		_get_scene_texture(scene, &"_result_box_sheet_mythic"),
		_get_scene_texture(scene, &"_result_box_sheet_guaranteed_mythic"),
		_get_scene_dictionary(scene, &"_reward_icon_cache")
	)


static func get_resolved_rewards(scene: Object) -> Array:
	return StageClearResultBoxData.get_resolved_rewards(_get_scene_array(scene, &"_boxes"))


static func append_box_resolved_perk_reward(scene: Control, box_index: int, perk_reward: Dictionary) -> void:
	if scene == null:
		return
	# 늦게 도착한 융합 보상은 stale base-size 프리웜에 기대지 말고 같은
	# fitted 크기로 즉시 프리컴포즈한다 — 대상은 카드 드로우 컨텍스트가
	# 소비하는 씬 로컬 _perk_icon_renderer(레지스트리 주입본은 별개 인스턴스).
	if str(perk_reward.get("draw_id", "")).begins_with("perk_fusion_pair:"):
		var renderer: Object = scene.get("_perk_icon_renderer")
		if renderer == null or not renderer.has_method("prepare_fusion_pair_icon"):
			renderer = scene.get("_runtime_perk_icon_renderer")
		if renderer != null and renderer.has_method("prepare_fusion_pair_icon"):
			var view_size: Vector2 = scene.size
			var layout_scale: float = load("res://scripts/ui/stage_clear_result_viewport_scene_handler.gd").get_layout_scale(view_size)
			var snapshot: Dictionary = scene.get("stage_reward_snapshot") if scene.get("stage_reward_snapshot") is Dictionary else {}
			var icon_size: Vector2 = load("res://scripts/ui/stage_clear_result_scroll_content_draw_helper.gd").get_fusion_reward_card_icon_size(
				view_size,
				layout_scale,
				snapshot,
				[]
			)
			renderer.prepare_fusion_pair_icon(str(perk_reward.get("draw_id", "")), icon_size, true)
	var current_boxes: Array = _get_scene_array(scene, &"_boxes")
	var result: Dictionary = StageClearResultBoxData.append_resolved_perk_reward(
		current_boxes,
		box_index,
		perk_reward
	)
	var apply_result: Dictionary = StageClearResultBoxData.get_append_resolved_perk_reward_scene_apply_result(
		result,
		current_boxes
	)
	StageClearResultFieldApplySceneHandler.apply_scene_apply_result(scene, apply_result)
	if bool(apply_result.get("redraw", false)):
		scene.queue_redraw()


static func _is_result_interaction_blocked(scene: Object) -> bool:
	return StageClearResultRuntimeOverlaySceneHandler.is_interaction_blocked(scene)


static func _get_scene_array(scene: Object, field_name: StringName) -> Array:
	if scene == null:
		return []
	var value: Variant = scene.get(field_name)
	return value if value is Array else []


static func _get_scene_callable(scene: Object, field_name: StringName) -> Callable:
	if scene == null:
		return Callable()
	var value: Variant = scene.get(field_name)
	return value if value is Callable else Callable()


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


static func _get_scene_dictionary(scene: Object, field_name: StringName) -> Dictionary:
	if scene == null:
		return {}
	var value: Variant = scene.get(field_name)
	return value if value is Dictionary else {}


static func _get_scene_texture(scene: Object, field_name: StringName) -> Texture2D:
	if scene == null:
		return null
	var value: Variant = scene.get(field_name)
	return value if value is Texture2D else null
