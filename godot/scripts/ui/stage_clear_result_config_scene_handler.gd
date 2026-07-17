extends RefCounted

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const StageClearResultAssetApplyHandler := preload("res://scripts/ui/stage_clear_result_asset_apply_handler.gd")
const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")
const StageClearResultAudioSceneHandler := preload("res://scripts/ui/stage_clear_result_audio_scene_handler.gd")
const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")
const StageClearResultCharacterAssetStateHandler := preload("res://scripts/ui/stage_clear_result_character_asset_state_handler.gd")
const StageClearResultConfigDataStateHandler := preload("res://scripts/ui/stage_clear_result_config_data_state_handler.gd")
const StageClearResultConfigResetStateHandler := preload("res://scripts/ui/stage_clear_result_config_reset_state_handler.gd")
const StageClearResultFieldApplySceneHandler := preload("res://scripts/ui/stage_clear_result_field_apply_scene_handler.gd")
const StageClearResultFontCache := preload("res://scripts/ui/stage_clear_result_font_cache.gd")
const StageClearResultFxHostPool := preload("res://scripts/ui/stage_clear_result_fx_host_pool.gd")
const StageClearResultPreviewDefaultsHandler := preload("res://scripts/ui/stage_clear_result_preview_defaults_handler.gd")
const StageClearResultRuntimeObjectStateHandler := preload("res://scripts/ui/stage_clear_result_runtime_object_state_handler.gd")
const StageClearResultViewportSceneHandler := preload("res://scripts/ui/stage_clear_result_viewport_scene_handler.gd")


static func create_default_perk_catalog() -> Object:
	return RuntimePerkCatalog.new()


static func create_default_perk_icon_renderer() -> Object:
	return RuntimePerkIconRenderer.new()


static func create_default_runtime_perk_overlay_renderer() -> Object:
	return RuntimePerkOverlayRenderer.new()


static func create_font_cache() -> Object:
	return StageClearResultFontCache.new()


static func create_fx_host_pool() -> Object:
	return StageClearResultFxHostPool.new()


static func get_default_reaction_timer(apply_key: String) -> float:
	return StageClearResultConfigResetStateHandler.get_reaction_timer_reset_value(apply_key)


static func prewarm_assets_step(character_type: String = "smasher", stage_id: int = 1) -> bool:
	return StageClearResultAssetLoader.prewarm_result_assets_step(
		StageClearResultAssetLoader.get_result_asset_paths(character_type, stage_id),
		StageClearResultAssetLoader.normalize_player_victory_character_type(character_type),
		stage_id
	)


static func prewarm_assets_threaded_step(character_type: String = "smasher", stage_id: int = 1) -> bool:
	return StageClearResultAssetLoader.prewarm_result_assets_step(
		StageClearResultAssetLoader.get_result_asset_paths(character_type, stage_id),
		StageClearResultAssetLoader.normalize_player_victory_character_type(character_type),
		stage_id,
		true
	)


static func reset_prewarm_assets_for_test() -> void:
	StageClearResultAssetLoader.reset_result_prewarm_assets_for_test()


static func get_prewarm_asset_status() -> Dictionary:
	return StageClearResultAssetLoader.get_result_prewarm_asset_status()


static func ready_scene(scene: Control) -> void:
	if scene == null:
		return
	scene.mouse_filter = Control.MOUSE_FILTER_STOP
	scene.focus_mode = Control.FOCUS_ALL
	scene.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	scene.set_process(not bool(scene.get("_driven_by_controller")))
	if not bool(scene.get("_driven_by_controller")):
		apply_standalone_preview_defaults(scene)
	if _get_scene_array(scene, &"_boxes").is_empty() and not _get_scene_dictionary(scene, &"reward_plan").is_empty():
		scene.set("_boxes", StageClearResultBoxData.build_boxes_from_plan(_get_scene_dictionary(scene, &"reward_plan")))
	StageClearResultViewportSceneHandler.sync_control_to_viewport(scene)
	load_textures(scene)
	load_audio(scene)
	scene.grab_focus()


static func configure(
	scene: Control,
	data: Dictionary,
	on_confirmed: Callable,
	on_exit_to_menu: Callable = Callable(),
	on_roll_reward: Callable = Callable(),
	on_immediate_reward: Callable = Callable(),
	on_enter_plaza: Callable = Callable()
) -> void:
	if scene == null:
		return
	scene.set("_driven_by_controller", true)
	scene.set_process(false)
	var config_data_state: Dictionary = StageClearResultConfigDataStateHandler.get_config_data_state(
		data,
		_get_scene_string(scene, &"selected_character_type", "smasher")
	)
	apply_config_data_state(scene, config_data_state)
	apply_character_asset_state(scene, StageClearResultCharacterAssetStateHandler.get_character_asset_state(
		_get_scene_string(scene, &"selected_character_type", "smasher"),
		str(config_data_state.get("selected_character_type", _get_scene_string(scene, &"selected_character_type", "smasher"))),
		_get_scene_texture(scene, &"_player_victory_sheet"),
		_get_scene_texture(scene, &"_player_victory_click_reaction_sheet"),
		_get_scene_string(scene, &"_player_victory_sheet_loaded_path", ""),
		_get_scene_string(scene, &"_player_victory_click_reaction_sheet_loaded_path", "")
	))
	apply_runtime_object_state(scene, StageClearResultRuntimeObjectStateHandler.get_runtime_object_state(data))
	scene.set("_boxes", StageClearResultBoxData.build_boxes_from_plan(_get_scene_dictionary(scene, &"reward_plan")))
	apply_config_reset_state(scene, StageClearResultConfigResetStateHandler.get_config_reset_state())
	_reset_fx_host_pool(scene)
	StageClearResultAudioSceneHandler.stop_dalji_click_voice(scene)
	scene.set("confirmed_callback", on_confirmed)
	scene.set("enter_plaza_callback", on_enter_plaza)
	scene.set("exit_to_menu_callback", on_exit_to_menu)
	scene.set("reward_roll_callback", on_roll_reward)
	scene.set("immediate_reward_callback", on_immediate_reward)
	StageClearResultViewportSceneHandler.sync_control_to_viewport(scene)
	# 융합 보상 카드 아이콘 프리컴포즈(씬 구성 시점 — 드로우 핫패스 밖).
	# 스냅샷·_boxes·뷰포트 크기가 모두 확정된 뒤에 호출해야 실 fitted
	# 크기로 준비된다.
	load("res://scripts/ui/stage_clear_result_scroll_scene_handler.gd").prepare_fusion_reward_icons(scene)
	load_textures(scene)
	load_audio(scene)
	scene.queue_redraw()


static func apply_config_data_state(scene: Object, result: Dictionary) -> void:
	if scene == null:
		return
	_apply_scene_apply_result(scene, StageClearResultConfigDataStateHandler.get_config_data_scene_apply_result(
		result,
		_get_scene_int(scene, &"player_score"),
		_get_scene_int(scene, &"boss_score"),
		_get_scene_int(scene, &"current_stage", 1),
		_get_scene_dictionary(scene, &"reward_plan"),
		_get_scene_dictionary(scene, &"stage_reward_snapshot")
	))


static func apply_character_asset_state(scene: Object, result: Dictionary) -> void:
	if scene == null:
		return
	_apply_scene_apply_result(scene, StageClearResultCharacterAssetStateHandler.get_character_asset_scene_apply_result(
		result,
		_get_scene_string(scene, &"selected_character_type", "smasher"),
		_get_scene_texture(scene, &"_player_victory_sheet"),
		_get_scene_texture(scene, &"_player_victory_click_reaction_sheet"),
		_get_scene_string(scene, &"_player_victory_sheet_loaded_path", ""),
		_get_scene_string(scene, &"_player_victory_click_reaction_sheet_loaded_path", "")
	))


static func apply_runtime_object_state(scene: Object, result: Dictionary) -> void:
	_apply_scene_apply_result(scene, StageClearResultRuntimeObjectStateHandler.get_runtime_object_scene_apply_result(result))


static func apply_config_reset_state(scene: Object, result: Dictionary) -> void:
	_apply_scene_apply_result(scene, StageClearResultConfigResetStateHandler.get_config_reset_scene_apply_result(
		result,
		get_config_reset_current_state(scene)
	))


static func get_config_reset_current_state(scene: Object) -> Dictionary:
	return {
		"lid_open_counter": _get_scene_int(scene, &"_lid_open_counter"),
		"starpoint_choice_gate_active": _get_scene_bool(scene, &"_starpoint_choice_gate_active"),
		"starpoint_choice_gate_box_index": _get_scene_int(scene, &"_starpoint_choice_gate_box_index", -1),
		"hovered_box_index": _get_scene_int(scene, &"_hovered_box_index", -1),
		"hovered_button": _get_scene_string(scene, &"_hovered_button", "none"),
		"next_stage_button_rect": _get_scene_rect(scene, &"_next_stage_button_rect"),
		"plaza_button_rect": _get_scene_rect(scene, &"_plaza_button_rect"),
		"exit_button_rect": _get_scene_rect(scene, &"_exit_button_rect"),
		"scroll_phase": _get_scene_string(scene, &"_scroll_phase", "hidden"),
		"scroll_timer": _get_scene_float(scene, &"_scroll_timer"),
		"scroll_position_offset": _get_scene_vector2(scene, &"_scroll_position_offset"),
		"scroll_dragging": _get_scene_bool(scene, &"_scroll_dragging"),
		"scroll_drag_grab_offset": _get_scene_vector2(scene, &"_scroll_drag_grab_offset"),
		"timer": _get_scene_float(scene, &"timer"),
		"dalji_base_timer": _get_scene_float(scene, &"_dalji_base_timer"),
		"dalji_click_reaction_timer": _get_scene_float(scene, &"_dalji_click_reaction_timer"),
		"player_victory_click_reaction_timer": _get_scene_float(scene, &"_player_victory_click_reaction_timer"),
		"stage2_boss_defeat_click_reaction_timer": _get_scene_float(scene, &"_stage2_boss_defeat_click_reaction_timer"),
		"stage3_boss_defeat_click_reaction_timer": _get_scene_float(scene, &"_stage3_boss_defeat_click_reaction_timer"),
		"stage4_ponk_boss_defeat_click_reaction_timer": _get_scene_float(scene, &"_stage4_ponk_boss_defeat_click_reaction_timer"),
		"stage5_hongryun_result_click_reaction_timer": _get_scene_float(scene, &"_stage5_hongryun_result_click_reaction_timer"),
		"stage6_boss_defeat_click_reaction_timer": _get_scene_float(scene, &"_stage6_boss_defeat_click_reaction_timer"),
		"stage7_boss_defeat_click_reaction_timer": _get_scene_float(scene, &"_stage7_boss_defeat_click_reaction_timer"),
		"dalji_dialogue_timer": _get_scene_float(scene, &"_dalji_dialogue_timer"),
	}


static func apply_standalone_preview_defaults(scene: Object) -> void:
	if scene == null:
		return
	var defaults: Dictionary = StageClearResultPreviewDefaultsHandler.get_standalone_preview_defaults(
		_get_scene_int(scene, &"player_score"),
		_get_scene_int(scene, &"boss_score"),
		_get_scene_dictionary(scene, &"reward_plan"),
		5
	)
	_apply_scene_apply_result(scene, StageClearResultPreviewDefaultsHandler.get_standalone_preview_scene_apply_result(
		defaults,
		_get_scene_int(scene, &"player_score"),
		_get_scene_int(scene, &"boss_score"),
		_get_scene_int(scene, &"current_stage", 1),
		_get_scene_dictionary(scene, &"reward_plan")
	))


static func load_textures(scene: Object) -> void:
	if scene == null:
		return
	_apply_scene_apply_result(scene, StageClearResultAssetApplyHandler.load_texture_fields(
		scene,
		_get_scene_string(scene, &"selected_character_type", "smasher"),
		_get_scene_int(scene, &"current_stage", 1),
		_get_scene_string(scene, &"_player_victory_sheet_loaded_path", ""),
		_get_scene_string(scene, &"_player_victory_click_reaction_sheet_loaded_path", "")
	))


static func load_audio(scene: Object) -> void:
	StageClearResultAudioSceneHandler.load_audio(scene)


static func clear_runtime_references(scene: Control) -> void:
	if scene == null:
		return
	scene.set_process(false)
	StageClearResultAudioSceneHandler.stop_dalji_click_voice(scene)
	var fx_host_pool: Object = _get_scene_object(scene, &"_fx_host_pool")
	if fx_host_pool != null and fx_host_pool.has_method("tear_down"):
		fx_host_pool.call("tear_down")
	scene.set("confirmed_callback", Callable())
	scene.set("exit_to_menu_callback", Callable())
	scene.set("reward_roll_callback", Callable())
	scene.set("immediate_reward_callback", Callable())
	scene.set("enter_plaza_callback", Callable())
	scene.set("_runtime_perk_state", null)
	scene.set("_runtime_perk_catalog", null)
	scene.set("_runtime_perk_icon_renderer", null)
	scene.set("_runtime_perk_owner", null)
	scene.set("_runtime_perk_registry", null)
	scene.set("_mythic_item_runtime", null)
	scene.set("_treasure_hunt_runtime", null)
	scene.set("_game_audio", null)
	scene.set("_dalji_click_voice_stream", null)


static func exit_tree(scene: Control) -> void:
	if scene == null:
		return
	clear_runtime_references(scene)
	scene.set("_perk_catalog", null)
	scene.set("_perk_icon_renderer", null)
	scene.set("_runtime_perk_overlay_renderer", null)
	scene.set("_font_cache", null)
	scene.set("_fx_host_pool", null)


static func _apply_scene_apply_result(scene: Object, apply_result: Dictionary) -> void:
	StageClearResultFieldApplySceneHandler.apply_scene_apply_result(scene, apply_result)


static func _reset_fx_host_pool(scene: Object) -> void:
	var fx_host_pool: Object = _get_scene_object(scene, &"_fx_host_pool")
	if fx_host_pool == null:
		return
	if fx_host_pool.has_method("reset_prewarm"):
		fx_host_pool.call("reset_prewarm")
	if fx_host_pool.has_method("deactivate_all"):
		fx_host_pool.call("deactivate_all")


static func _get_scene_array(scene: Object, field_name: StringName) -> Array:
	if scene == null:
		return []
	var value: Variant = scene.get(field_name)
	return value if value is Array else []


static func _get_scene_bool(scene: Object, field_name: StringName, fallback: bool = false) -> bool:
	if scene == null:
		return fallback
	var value: Variant = scene.get(field_name)
	return fallback if value == null else bool(value)


static func _get_scene_dictionary(scene: Object, field_name: StringName) -> Dictionary:
	if scene == null:
		return {}
	var value: Variant = scene.get(field_name)
	return value if value is Dictionary else {}


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


static func _get_scene_rect(scene: Object, field_name: StringName) -> Rect2:
	if scene == null:
		return Rect2()
	var value: Variant = scene.get(field_name)
	return value if value is Rect2 else Rect2()


static func _get_scene_string(scene: Object, field_name: StringName, fallback: String) -> String:
	if scene == null:
		return fallback
	var value: Variant = scene.get(field_name)
	return fallback if value == null else str(value)


static func _get_scene_texture(scene: Object, field_name: StringName) -> Texture2D:
	if scene == null:
		return null
	var value: Variant = scene.get(field_name)
	return value if value is Texture2D else null


static func _get_scene_vector2(scene: Object, field_name: StringName) -> Vector2:
	if scene == null:
		return Vector2.ZERO
	var value: Variant = scene.get(field_name)
	return value if value is Vector2 else Vector2.ZERO
