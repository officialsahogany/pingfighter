extends Control

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")
const StageClearResultActorClickHandler := preload("res://scripts/ui/stage_clear_result_actor_click_handler.gd")
const StageClearResultActorPresenter := preload("res://scripts/ui/stage_clear_result_actor_presenter.gd")
const StageClearResultActorReactionUpdateHandler := preload("res://scripts/ui/stage_clear_result_actor_reaction_update_handler.gd")
const StageClearResultBoxPresenter := preload("res://scripts/ui/stage_clear_result_box_presenter.gd")
const StageClearResultStaticDrawHelper := preload("res://scripts/ui/stage_clear_result_static_draw_helper.gd")
const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")
const StageClearResultStatusBuilder := preload("res://scripts/ui/stage_clear_result_status_builder.gd")
const StageClearResultInteractionState := preload("res://scripts/ui/stage_clear_result_interaction_state.gd")
const StageClearResultScrollInputHandler := preload("res://scripts/ui/stage_clear_result_scroll_input_handler.gd")
const StageClearResultScrollPresenter := preload("res://scripts/ui/stage_clear_result_scroll_presenter.gd")
const StageClearResultScrollUpdateHandler := preload("res://scripts/ui/stage_clear_result_scroll_update_handler.gd")
const StageClearResultAssetApplyHandler := preload("res://scripts/ui/stage_clear_result_asset_apply_handler.gd")
const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")
const StageClearResultAudioApplyHandler := preload("res://scripts/ui/stage_clear_result_audio_apply_handler.gd")
const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")
const StageClearResultBoxInputHandler := preload("res://scripts/ui/stage_clear_result_box_input_handler.gd")
const StageClearResultBoxUpdateHandler := preload("res://scripts/ui/stage_clear_result_box_update_handler.gd")
const StageClearResultCallbackHandler := preload("res://scripts/ui/stage_clear_result_callback_handler.gd")
const StageClearResultCharacterAssetStateHandler := preload("res://scripts/ui/stage_clear_result_character_asset_state_handler.gd")
const StageClearResultConfigDataStateHandler := preload("res://scripts/ui/stage_clear_result_config_data_state_handler.gd")
const StageClearResultConfigResetStateHandler := preload("res://scripts/ui/stage_clear_result_config_reset_state_handler.gd")
const StageClearResultFontCache := preload("res://scripts/ui/stage_clear_result_font_cache.gd")
const StageClearResultFxHostPool := preload("res://scripts/ui/stage_clear_result_fx_host_pool.gd")
const StageClearResultFxHostUpdateHandler := preload("res://scripts/ui/stage_clear_result_fx_host_update_handler.gd")
const StageClearResultInputRouter := preload("res://scripts/ui/stage_clear_result_input_router.gd")
const StageClearResultNavigationActionHandler := preload("res://scripts/ui/stage_clear_result_navigation_action_handler.gd")
const StageClearResultPreviewDefaultsHandler := preload("res://scripts/ui/stage_clear_result_preview_defaults_handler.gd")
const StageClearResultRuntimeOverlayPresenter := preload("res://scripts/ui/stage_clear_result_runtime_overlay_presenter.gd")
const StageClearResultRuntimeObjectStateHandler := preload("res://scripts/ui/stage_clear_result_runtime_object_state_handler.gd")
const StageClearResultSceneFieldApplier := preload("res://scripts/ui/stage_clear_result_scene_field_applier.gd")
const StageClearResultViewportLayout := preload("res://scripts/ui/stage_clear_result_viewport_layout.gd")
const StageClearResultVoicePlayer := preload("res://scripts/ui/stage_clear_result_voice_player.gd")

const DALJI_CLICK_DIALOGUE_DURATION := 1.55
const DALJI_CLICK_DIALOGUE_FADE_DURATION := 0.20
const DALJI_CLICK_DIALOGUE := "건들지마"

var timer: float = 0.0
var player_score: int = 0
var boss_score: int = 0
var current_stage: int = 1
var selected_character_type: String = "smasher"
var reward_plan: Dictionary = {}
var stage_reward_snapshot: Dictionary = {}
var confirmed_callback: Callable = Callable()
var enter_plaza_callback: Callable = Callable()
var exit_to_menu_callback: Callable = Callable()
var reward_roll_callback: Callable = Callable()
var immediate_reward_callback: Callable = Callable()

var _boxes: Array = []
var _hovered_box_index: int = -1
var _scroll_phase: String = "hidden"
var _scroll_timer: float = 0.0
var _scroll_position_offset: Vector2 = Vector2.ZERO
var _scroll_dragging: bool = false
var _scroll_drag_grab_offset: Vector2 = Vector2.ZERO
var _next_stage_button_rect: Rect2 = Rect2()
var _plaza_button_rect: Rect2 = Rect2()
var _exit_button_rect: Rect2 = Rect2()
var _hovered_button: String = "none"
var _reward_icon_cache: Dictionary = {}
var _scene_field_name_lookup: Dictionary = {}
var _dalji_click_rect: Rect2 = Rect2()
var _player_victory_click_rect: Rect2 = Rect2()
var _background_texture: Texture2D
var _dalji_defeat_sheet: Texture2D
var _dalji_click_reaction_sheet: Texture2D
var _stage2_boss_defeat_live2d_sheet: Texture2D
var _stage2_boss_defeat_click_reaction_sheet: Texture2D
var _stage3_boss_defeat_live2d_sheet: Texture2D
var _stage3_boss_defeat_click_reaction_sheet: Texture2D
var _player_victory_sheet: Texture2D
var _player_victory_click_reaction_sheet: Texture2D
var _player_victory_sheet_loaded_path: String = ""
var _player_victory_click_reaction_sheet_loaded_path: String = ""
var _scroll_texture: Texture2D
var _result_box_sheet_common: Texture2D
var _result_box_sheet_mythic: Texture2D
var _result_box_sheet_guaranteed_mythic: Texture2D
var _dalji_click_voice_stream: AudioStream
var _dalji_click_voice_player: AudioStreamPlayer
var _perk_catalog: Object = RuntimePerkCatalog.new()
var _perk_icon_renderer: Object = RuntimePerkIconRenderer.new()
var _runtime_perk_overlay_renderer: Object = RuntimePerkOverlayRenderer.new()
var _runtime_perk_state: Object
var _runtime_perk_catalog: Object
var _runtime_perk_icon_renderer: Object
var _runtime_perk_owner: Object
var _runtime_perk_registry: Object
var _mythic_item_runtime: Object
var _treasure_hunt_runtime: Object
var _game_audio: Object
var _driven_by_controller: bool = false
var _dalji_base_timer: float = 0.0
var _dalji_click_reaction_timer: float = StageClearResultActorDrawHelper.DALJI_CLICK_TOTAL_DURATION
var _player_victory_click_reaction_timer: float = StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_TOTAL_DURATION
var _stage2_boss_defeat_click_reaction_timer: float = StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION
var _stage3_boss_defeat_click_reaction_timer: float = StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION
var _dalji_dialogue_timer: float = 0.0
var _dalji_click_transition_base_frame: int = 0
var _player_victory_click_transition_base_frame: int = 0
var _stage2_boss_defeat_click_transition_base_frame: int = 0
var _stage3_boss_defeat_click_transition_base_frame: int = 0
var _font_cache := StageClearResultFontCache.new()
var _fx_host_pool := StageClearResultFxHostPool.new()
var _lid_open_counter: int = 0
var _starpoint_choice_gate_active: bool = false
var _starpoint_choice_gate_box_index: int = -1

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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(not _driven_by_controller)
	_apply_standalone_preview_defaults()
	if _boxes.is_empty() and not reward_plan.is_empty():
		_boxes = StageClearResultBoxData.build_boxes_from_plan(reward_plan)
	_sync_viewport_size()
	_load_textures()
	_load_audio()
	grab_focus()


func configure(
	data: Dictionary,
	on_confirmed: Callable,
	on_exit_to_menu: Callable = Callable(),
	on_roll_reward: Callable = Callable(),
	on_immediate_reward: Callable = Callable(),
	on_enter_plaza: Callable = Callable()
) -> void:
	_driven_by_controller = true
	set_process(false)
	var config_data_state: Dictionary = StageClearResultConfigDataStateHandler.get_config_data_state(
		data,
		selected_character_type
	)
	_apply_config_data_state(config_data_state)
	_apply_character_asset_state(StageClearResultCharacterAssetStateHandler.get_character_asset_state(
		selected_character_type,
		str(config_data_state.get("selected_character_type", selected_character_type)),
		_player_victory_sheet,
		_player_victory_click_reaction_sheet,
		_player_victory_sheet_loaded_path,
		_player_victory_click_reaction_sheet_loaded_path
	))
	_apply_runtime_object_state(StageClearResultRuntimeObjectStateHandler.get_runtime_object_state(data))
	_boxes = StageClearResultBoxData.build_boxes_from_plan(reward_plan)
	_apply_config_reset_state(StageClearResultConfigResetStateHandler.get_config_reset_state())
	_fx_host_pool.reset_prewarm()
	_fx_host_pool.deactivate_all()
	_stop_dalji_click_voice()
	confirmed_callback = on_confirmed
	enter_plaza_callback = on_enter_plaza
	exit_to_menu_callback = on_exit_to_menu
	reward_roll_callback = on_roll_reward
	immediate_reward_callback = on_immediate_reward
	_sync_viewport_size()
	_load_textures()
	_load_audio()
	queue_redraw()


func _apply_config_data_state(result: Dictionary) -> void:
	var apply_result: Dictionary = StageClearResultConfigDataStateHandler.get_config_data_scene_apply_result(
		result,
		player_score,
		boss_score,
		current_stage,
		reward_plan,
		stage_reward_snapshot
	)
	_apply_scene_apply_result(apply_result)


func _apply_character_asset_state(result: Dictionary) -> void:
	var apply_result: Dictionary = StageClearResultCharacterAssetStateHandler.get_character_asset_scene_apply_result(
		result,
		selected_character_type,
		_player_victory_sheet,
		_player_victory_click_reaction_sheet,
		_player_victory_sheet_loaded_path,
		_player_victory_click_reaction_sheet_loaded_path
	)
	_apply_scene_apply_result(apply_result)


func _apply_runtime_object_state(result: Dictionary) -> void:
	_apply_scene_apply_result(StageClearResultRuntimeObjectStateHandler.get_runtime_object_scene_apply_result(result))


func _apply_config_reset_state(result: Dictionary) -> void:
	var apply_result: Dictionary = StageClearResultConfigResetStateHandler.get_config_reset_scene_apply_result(
		result,
		_get_config_reset_current_state()
	)
	_apply_scene_apply_result(apply_result)


func _get_config_reset_current_state() -> Dictionary:
	return {
		"lid_open_counter": _lid_open_counter,
		"starpoint_choice_gate_active": _starpoint_choice_gate_active,
		"starpoint_choice_gate_box_index": _starpoint_choice_gate_box_index,
		"hovered_box_index": _hovered_box_index,
		"hovered_button": _hovered_button,
		"next_stage_button_rect": _next_stage_button_rect,
		"plaza_button_rect": _plaza_button_rect,
		"exit_button_rect": _exit_button_rect,
		"scroll_phase": _scroll_phase,
		"scroll_timer": _scroll_timer,
		"scroll_position_offset": _scroll_position_offset,
		"scroll_dragging": _scroll_dragging,
		"scroll_drag_grab_offset": _scroll_drag_grab_offset,
		"timer": timer,
		"dalji_base_timer": _dalji_base_timer,
		"dalji_click_reaction_timer": _dalji_click_reaction_timer,
		"player_victory_click_reaction_timer": _player_victory_click_reaction_timer,
		"stage2_boss_defeat_click_reaction_timer": _stage2_boss_defeat_click_reaction_timer,
		"stage3_boss_defeat_click_reaction_timer": _stage3_boss_defeat_click_reaction_timer,
		"dalji_dialogue_timer": _dalji_dialogue_timer,
	}


func _process(delta: float) -> void:
	if _driven_by_controller:
		return
	update_result_scene(delta)


func _exit_tree() -> void:
	_fx_host_pool.tear_down()


func update_result_scene(delta: float) -> void:
	var safe_delta: float = max(0.0, delta)
	timer += safe_delta
	_apply_actor_reaction_timer_update(
		StageClearResultActorReactionUpdateHandler.update_actor_reaction_timers(
			_get_actor_reaction_timer_context(),
			safe_delta
		)
	)
	_update_boxes(safe_delta)
	_update_scroll(safe_delta)
	_sync_viewport_size()
	StageClearResultFxHostUpdateHandler.update_fx_hosts(
		_fx_host_pool,
		self,
		_boxes,
		_get_layout_scale(size),
		timer,
		_scroll_phase,
		_scroll_timer
	)
	queue_redraw()


func _get_actor_reaction_timer_context() -> Dictionary:
	return StageClearResultActorReactionUpdateHandler.get_actor_reaction_timer_context(
		_dalji_base_timer,
		_dalji_click_reaction_timer,
		_player_victory_click_reaction_timer,
		_stage2_boss_defeat_click_reaction_timer,
		_stage3_boss_defeat_click_reaction_timer,
		_dalji_dialogue_timer
	)


func _apply_actor_reaction_timer_update(result: Dictionary) -> void:
	var apply_result: Dictionary = StageClearResultActorReactionUpdateHandler.get_actor_reaction_timer_scene_apply_result(
		result,
		_get_actor_reaction_timer_context()
	)
	_apply_scene_apply_result(apply_result)


func handle_result_input(event: InputEvent) -> bool:
	var result: Dictionary = StageClearResultInputRouter.get_result_input_route(event, _get_input_router_context())
	var route: String = str(result.get("route", StageClearResultInputRouter.ROUTE_CONSUME))
	var mouse_position: Vector2 = result.get("mouse_position", Vector2.ZERO)
	match route:
		StageClearResultInputRouter.ROUTE_MYTHIC_ACQUISITION:
			_cancel_scroll_drag()
			return _handle_mythic_acquisition_input(event)
		StageClearResultInputRouter.ROUTE_RUNTIME_PERK:
			_cancel_scroll_drag()
			return _handle_runtime_perk_input(event)
		StageClearResultInputRouter.ROUTE_TREASURE_HUNT:
			_cancel_scroll_drag()
			return true
		StageClearResultInputRouter.ROUTE_ADVANCE:
			return _handle_advance_input()
		StageClearResultInputRouter.ROUTE_ESCAPE:
			return _handle_escape_input()
		StageClearResultInputRouter.ROUTE_MOUSE_DRAG_UPDATE:
			_update_scroll_drag(mouse_position)
			return true
		StageClearResultInputRouter.ROUTE_MOUSE_HOVER_BUTTON:
			_update_hovered_button(mouse_position)
			return true
		StageClearResultInputRouter.ROUTE_MOUSE_HOVER_BOX:
			_update_hovered_box(mouse_position)
			return true
		StageClearResultInputRouter.ROUTE_MOUSE_DRAG_FINISH:
			_finish_scroll_drag(mouse_position)
			return true
		StageClearResultInputRouter.ROUTE_MOUSE_LEFT_PRESS:
			_handle_mouse_left_press(mouse_position)
			return true
	return bool(result.get("consumed", true))


func _get_input_router_context() -> Dictionary:
	return StageClearResultInputRouter.get_input_router_context(
		_is_mythic_acquisition_cinematic_active(),
		_is_runtime_perk_choice_active(),
		_is_treasure_hunt_effect_active(),
		_scroll_dragging,
		_scroll_phase
	)


func _handle_mouse_left_press(mouse_position: Vector2) -> void:
	var handled_click: bool = (
		_handle_dalji_click(mouse_position)
		or _handle_stage2_boss_defeat_click(mouse_position)
		or _handle_stage3_boss_defeat_click(mouse_position)
		or _handle_player_victory_click(mouse_position)
		or _start_scroll_drag(mouse_position)
		or _handle_button_click(mouse_position)
		or _handle_box_click(mouse_position)
	)
	if not handled_click:
		_update_hovered_box(mouse_position)


func _handle_runtime_perk_input(event: InputEvent) -> bool:
	var view_size: Vector2 = _get_current_view_size()
	StageClearResultRuntimeOverlayPresenter.handle_runtime_perk_input(
		event,
		_runtime_perk_state,
		_runtime_perk_owner,
		_runtime_perk_registry,
		view_size
	)
	queue_redraw()
	return true


func _handle_mythic_acquisition_input(event: InputEvent) -> bool:
	StageClearResultRuntimeOverlayPresenter.handle_mythic_acquisition_input(
		event,
		_mythic_item_runtime,
		_runtime_perk_registry
	)
	queue_redraw()
	return true


func _is_mythic_acquisition_cinematic_active() -> bool:
	return StageClearResultRuntimeOverlayPresenter.is_mythic_acquisition_cinematic_active(_mythic_item_runtime)


func _is_treasure_hunt_effect_active() -> bool:
	return StageClearResultRuntimeOverlayPresenter.is_treasure_hunt_effect_active(_treasure_hunt_runtime)


func _is_result_interaction_blocked() -> bool:
	return StageClearResultRuntimeOverlayPresenter.is_interaction_blocked(
		_starpoint_choice_gate_active,
		_runtime_perk_state,
		_treasure_hunt_runtime
	)


func _handle_advance_input() -> bool:
	return _apply_navigation_action_result(StageClearResultNavigationActionHandler.get_navigation_action_apply_result(
		StageClearResultNavigationActionHandler.get_advance_action(
			_is_result_interaction_blocked(),
			_scroll_phase
		)
	))


func _handle_escape_input() -> bool:
	return _apply_navigation_action_result(StageClearResultNavigationActionHandler.get_navigation_action_apply_result(
		StageClearResultNavigationActionHandler.get_escape_action(_scroll_phase)
	))


func _open_next_idle_box() -> bool:
	if _is_result_interaction_blocked():
		return false
	return _apply_box_open_result(StageClearResultBoxInputHandler.open_next_idle_box(
		_boxes,
		reward_roll_callback
	))


func _exit_to_menu() -> void:
	_stop_dalji_click_voice()
	StageClearResultCallbackHandler.invoke_exit_to_menu(exit_to_menu_callback, confirmed_callback)


func _enter_plaza() -> void:
	_stop_dalji_click_voice()
	StageClearResultCallbackHandler.invoke_enter_plaza(enter_plaza_callback)


func _handle_button_click(mouse_position: Vector2) -> bool:
	var view_size: Vector2 = _get_current_view_size()
	var layout_scale: float = _get_layout_scale(view_size)
	var result: Dictionary = StageClearResultScrollInputHandler.get_button_click_result(
		mouse_position,
		_scroll_phase,
		layout_scale,
		_scroll_position_offset
	)
	var apply_result: Dictionary = StageClearResultNavigationActionHandler.get_scroll_button_click_apply_result(result)
	_apply_scroll_button_layout(apply_result)
	return _apply_navigation_action_result(apply_result)


func _apply_navigation_action_result(result: Dictionary) -> bool:
	_apply_navigation_action(str(result.get("action", StageClearResultNavigationActionHandler.ACTION_NONE)))
	return bool(result.get("handled", false))


func _apply_navigation_action(action: String) -> void:
	match action:
		StageClearResultNavigationActionHandler.ACTION_OPEN_NEXT_BOX:
			_open_next_idle_box()
		StageClearResultNavigationActionHandler.ACTION_CONFIRM:
			_confirm()
		StageClearResultNavigationActionHandler.ACTION_ENTER_PLAZA:
			_enter_plaza()
		StageClearResultNavigationActionHandler.ACTION_EXIT_TO_MENU:
			_exit_to_menu()


func _update_hovered_button(mouse_position: Vector2) -> void:
	var view_size: Vector2 = _get_current_view_size()
	var layout_scale: float = _get_layout_scale(view_size)
	var result: Dictionary = StageClearResultScrollInputHandler.get_hovered_button_result(
		mouse_position,
		_hovered_button,
		_scroll_phase,
		layout_scale,
		_scroll_position_offset
	)
	var apply_result: Dictionary = StageClearResultScrollInputHandler.get_hovered_button_apply_result(
		result,
		_hovered_button
	)
	_apply_scroll_state_result(apply_result)
	if bool(apply_result.get("redraw", false)):
		queue_redraw()


func _start_scroll_drag(mouse_position: Vector2) -> bool:
	var view_size: Vector2 = _get_current_view_size()
	var layout_scale: float = _get_layout_scale(view_size)
	var drag_state: Dictionary = StageClearResultScrollInputHandler.get_drag_start_result(
		mouse_position,
		_scroll_phase,
		_starpoint_choice_gate_active,
		layout_scale,
		_scroll_position_offset
	)
	var apply_result: Dictionary = StageClearResultScrollInputHandler.get_drag_start_apply_result(
		drag_state,
		_scroll_dragging,
		_scroll_drag_grab_offset,
		_hovered_button
	)
	_apply_scroll_state_result(apply_result)
	if not bool(apply_result.get("started", false)):
		return false
	if bool(apply_result.get("redraw", false)):
		queue_redraw()
	return true


func _update_scroll_drag(mouse_position: Vector2) -> void:
	var view_size: Vector2 = _get_current_view_size()
	var layout_scale: float = _get_layout_scale(view_size)
	var result: Dictionary = StageClearResultScrollInputHandler.get_drag_update_result(
		mouse_position,
		_scroll_drag_grab_offset,
		_scroll_phase,
		layout_scale,
		view_size
	)
	var apply_result: Dictionary = StageClearResultScrollInputHandler.get_drag_update_apply_result(
		result,
		_scroll_position_offset
	)
	_apply_scroll_state_result(apply_result)
	if bool(apply_result.get("redraw", false)):
		queue_redraw()


func _finish_scroll_drag(mouse_position: Vector2) -> void:
	var view_size: Vector2 = _get_current_view_size()
	var layout_scale: float = _get_layout_scale(view_size)
	var result: Dictionary = StageClearResultScrollInputHandler.get_drag_finish_result(
		mouse_position,
		_scroll_drag_grab_offset,
		_scroll_phase,
		_hovered_button,
		layout_scale,
		view_size
	)
	var apply_result: Dictionary = StageClearResultScrollInputHandler.get_drag_finish_apply_result(
		result,
		_scroll_phase,
		_scroll_position_offset,
		_hovered_button
	)
	_apply_scroll_state_result(apply_result)
	if bool(apply_result.get("redraw", false)):
		queue_redraw()


func _cancel_scroll_drag() -> void:
	var apply_result: Dictionary = StageClearResultScrollInputHandler.get_drag_cancel_apply_result(
		_scroll_dragging
	)
	_apply_scroll_state_result(apply_result)
	if bool(apply_result.get("redraw", false)):
		queue_redraw()


func _refresh_scroll_button_rects() -> void:
	var view_size: Vector2 = _get_current_view_size()
	var layout_scale: float = _get_layout_scale(view_size)
	var button_layout: Dictionary = StageClearResultScrollInputHandler.get_button_layout(
		_scroll_phase,
		layout_scale,
		_scroll_position_offset
	)
	_apply_scroll_button_layout(button_layout)


func _apply_scroll_button_layout(button_layout: Dictionary) -> void:
	_apply_scroll_state_result(button_layout)


func _apply_scroll_state_result(result: Dictionary) -> void:
	var apply_result: Dictionary = StageClearResultScrollInputHandler.get_scroll_state_scene_apply_result(
		result,
		_get_scroll_state_current_state()
	)
	_apply_scene_apply_result(apply_result)


func _get_scroll_state_current_state() -> Dictionary:
	return {
		"next_stage_rect": _next_stage_button_rect,
		"plaza_rect": _plaza_button_rect,
		"exit_rect": _exit_button_rect,
		"scroll_position_offset": _scroll_position_offset,
		"scroll_dragging": _scroll_dragging,
		"scroll_drag_grab_offset": _scroll_drag_grab_offset,
		"hovered_button": _hovered_button,
	}


func _get_current_view_size() -> Vector2:
	return StageClearResultViewportLayout.get_current_view_size(self)


func get_interaction_status() -> Dictionary:
	return StageClearResultStatusBuilder.build_scene_interaction_status(self, DALJI_CLICK_DIALOGUE)


func get_resolved_rewards() -> Array:
	return StageClearResultBoxData.get_resolved_rewards(_boxes)


func _gui_input(event: InputEvent) -> void:
	if handle_result_input(event):
		accept_event()


func _draw() -> void:
	var view_size: Vector2 = _get_current_view_size()
	if view_size == Vector2.ZERO:
		return

	_load_textures()
	@warning_ignore("shadowed_variable_base_class")
	var scale: float = _get_layout_scale(view_size)
	var font: Font = _font_cache.get_font(scale)

	StageClearResultStaticDrawHelper.draw_background(self, _background_texture, view_size)
	draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.03, 0.04, 0.10, 0.22))
	_draw_defeated_boss(view_size, scale)
	_draw_floating_boxes(view_size, scale)
	_draw_scroll(view_size, scale, font)
	_draw_player_victory(view_size, scale, font)
	StageClearResultStaticDrawHelper.draw_dalji_click_dialogue(self, font, view_size, scale, _dalji_dialogue_timer, DALJI_CLICK_DIALOGUE_FADE_DURATION, DALJI_CLICK_DIALOGUE)
	StageClearResultStaticDrawHelper.draw_footer(self, font, view_size, scale, current_stage)
	_draw_runtime_perk_overlay(view_size)


func set_starpoint_choice_gate_active(active: bool, box_index: int = -1) -> void:
	_starpoint_choice_gate_active = active
	_starpoint_choice_gate_box_index = box_index if active else -1
	queue_redraw()


func append_box_resolved_perk_reward(box_index: int, perk_reward: Dictionary) -> void:
	var result: Dictionary = StageClearResultBoxData.append_resolved_perk_reward(_boxes, box_index, perk_reward)
	var apply_result: Dictionary = StageClearResultBoxData.get_append_resolved_perk_reward_scene_apply_result(
		result,
		_boxes
	)
	_apply_scene_apply_result(apply_result)
	if bool(apply_result.get("redraw", false)):
		queue_redraw()


func _draw_runtime_perk_overlay(view_size: Vector2) -> void:
	StageClearResultRuntimeOverlayPresenter.draw_overlay(
		self,
		_runtime_perk_overlay_renderer,
		_runtime_perk_state,
		_perk_catalog,
		_runtime_perk_catalog,
		_perk_icon_renderer,
		_runtime_perk_icon_renderer,
		view_size,
		_mythic_item_runtime,
		_treasure_hunt_runtime
	)


func _should_draw_runtime_perk_overlay() -> bool:
	return StageClearResultRuntimeOverlayPresenter.should_draw_overlay(
		_runtime_perk_overlay_renderer,
		_runtime_perk_state,
		_mythic_item_runtime,
		_treasure_hunt_runtime
	)


func _is_runtime_perk_choice_active() -> bool:
	return StageClearResultRuntimeOverlayPresenter.is_runtime_perk_choice_active(_runtime_perk_state)


@warning_ignore("shadowed_variable_base_class")
func _draw_defeated_boss(view_size: Vector2, scale: float) -> void:
	var result: Dictionary = StageClearResultActorPresenter.draw_defeated_boss(
		self,
		view_size,
		scale,
		_get_actor_defeated_draw_context()
	)
	var apply_result: Dictionary = StageClearResultActorPresenter.get_defeated_boss_draw_scene_apply_result(
		result,
		_dalji_click_rect
	)
	_apply_scene_apply_result(apply_result)


func _get_actor_defeated_draw_context() -> Dictionary:
	return StageClearResultActorPresenter.get_defeated_boss_draw_context(
		current_stage,
		timer,
		_dalji_base_timer,
		_dalji_click_reaction_timer,
		_dalji_click_transition_base_frame,
		_dalji_defeat_sheet,
		_dalji_click_reaction_sheet,
		_stage2_boss_defeat_live2d_sheet,
		_stage2_boss_defeat_click_reaction_sheet,
		_stage2_boss_defeat_click_reaction_timer,
		_stage2_boss_defeat_click_transition_base_frame,
		_stage3_boss_defeat_live2d_sheet,
		_stage3_boss_defeat_click_reaction_sheet,
		_stage3_boss_defeat_click_reaction_timer,
		_stage3_boss_defeat_click_transition_base_frame
	)


@warning_ignore("shadowed_variable_base_class")
func _draw_player_victory(view_size: Vector2, scale: float, font: Font) -> void:
	if _draw_player_victory_live2d(view_size, scale):
		return
	StageClearResultStaticDrawHelper.draw_player_victory_fallback(
		self,
		font,
		view_size, scale, timer, _player_victory_sheet,
		StageClearResultActorDrawHelper.PLAYER_VICTORY_FRAME_INTERVAL, StageClearResultActorDrawHelper.PLAYER_VICTORY_FRAME_COUNT, StageClearResultActorDrawHelper.PLAYER_VICTORY_GRID_COLS, StageClearResultActorDrawHelper.PLAYER_VICTORY_CELL_SIZE,
		"플레이어 승리", "Live2D 포즈", "승리 연출 테스트"
	)


func _draw_player_victory_live2d(view_size: Vector2, layout_ratio: float) -> bool:
	var result: Dictionary = StageClearResultActorPresenter.draw_player_victory_live2d(
		self,
		view_size,
		layout_ratio,
		_get_actor_player_victory_draw_context()
	)
	var apply_result: Dictionary = StageClearResultActorPresenter.get_player_victory_draw_scene_apply_result(result)
	_apply_scene_apply_result(apply_result)
	return bool(apply_result.get("drawn", true))


func _get_actor_player_victory_draw_context() -> Dictionary:
	return StageClearResultActorPresenter.get_player_victory_draw_context(
		timer,
		_player_victory_click_reaction_timer,
		_player_victory_click_transition_base_frame,
		_player_victory_sheet,
		_player_victory_click_reaction_sheet
	)


@warning_ignore("shadowed_variable_base_class")
func _draw_floating_boxes(_view_size: Vector2, scale: float) -> void:
	StageClearResultBoxPresenter.draw_floating_boxes(
		self,
		_boxes,
		scale,
		_get_floating_box_draw_context()
	)


func _get_floating_box_draw_context() -> Dictionary:
	return StageClearResultBoxPresenter.get_floating_box_draw_context(
		timer,
		_scroll_phase,
		_scroll_timer,
		_hovered_box_index,
		_result_box_sheet_common,
		_result_box_sheet_mythic,
		_result_box_sheet_guaranteed_mythic,
		_reward_icon_cache
	)


func _handle_box_click(mouse_position: Vector2) -> bool:
	var view_size: Vector2 = _get_current_view_size()
	var draw_scale: float = _get_layout_scale(view_size)
	return _apply_box_open_result(StageClearResultBoxInputHandler.get_box_click_result(
		_boxes,
		mouse_position,
		_scroll_phase,
		_is_result_interaction_blocked(),
		draw_scale,
		timer,
		reward_roll_callback
	))


func _apply_box_open_result(result: Dictionary) -> bool:
	var apply_result: Dictionary = StageClearResultBoxInputHandler.get_box_open_apply_result(
		result,
		_boxes,
		_hovered_box_index
	)
	apply_result = _apply_box_state_result(apply_result)
	return bool(apply_result.get("consumed", false))


func _apply_box_state_result(result: Dictionary) -> Dictionary:
	var apply_result: Dictionary = StageClearResultBoxInputHandler.get_box_state_scene_apply_result(
		result,
		_boxes,
		_hovered_box_index
	)
	_apply_scene_apply_result(apply_result)
	if bool(apply_result.get("play_open_audio", false)):
		_play_result_box_open_audio()
	if bool(apply_result.get("redraw", false)):
		queue_redraw()
	return apply_result


func _play_result_box_open_audio() -> void:
	StageClearResultAudioApplyHandler.play_result_box_open_audio(_game_audio)


func _update_boxes(delta: float) -> void:
	var view_size: Vector2 = _get_current_view_size()
	@warning_ignore("shadowed_variable_base_class")
	var scale: float = _get_layout_scale(view_size)
	var result: Dictionary = StageClearResultBoxUpdateHandler.update_boxes(
		_boxes,
		delta,
		_lid_open_counter,
		immediate_reward_callback,
		view_size,
		scale,
		timer
	)
	_apply_scene_apply_result(StageClearResultBoxUpdateHandler.get_box_update_scene_apply_result(
		result,
		_boxes,
		_lid_open_counter
	))


func _update_scroll(delta: float) -> void:
	var result: Dictionary = StageClearResultScrollUpdateHandler.update_scroll(
		_scroll_phase,
		_scroll_timer,
		delta,
		_boxes,
		_is_result_interaction_blocked(),
	)
	_apply_scene_apply_result(StageClearResultScrollUpdateHandler.get_scroll_update_scene_apply_result(
		result,
		_scroll_phase,
		_scroll_timer
	))


func _apply_scene_apply_result(apply_result: Dictionary) -> void:
	StageClearResultSceneFieldApplier.apply_from_result(
		self,
		apply_result,
		_scene_field_name_lookup,
		"StageClearResultScene"
	)


@warning_ignore("shadowed_variable_base_class")
func _draw_scroll(view_size: Vector2, scale: float, font: Font) -> void:
	var result: Dictionary = StageClearResultScrollPresenter.draw_scroll(
		self,
		font,
		view_size,
		scale,
		_scroll_texture,
		_get_scroll_draw_context()
	)
	_apply_scroll_state_result(StageClearResultScrollPresenter.get_scroll_draw_apply_result(
		result,
		_scroll_position_offset
	))


func _get_scroll_draw_context() -> Dictionary:
	return StageClearResultScrollPresenter.get_scroll_draw_context(
		current_stage,
		stage_reward_snapshot,
		_boxes,
		_runtime_perk_state,
		player_score,
		boss_score,
		timer,
		_perk_catalog,
		_perk_icon_renderer,
		_reward_icon_cache,
		_scroll_phase,
		_scroll_timer,
		_scroll_position_offset,
		_hovered_button
	)


func _update_hovered_box(mouse_position: Vector2) -> void:
	var view_size: Vector2 = _get_current_view_size()
	var draw_scale: float = _get_layout_scale(view_size)
	var result: Dictionary = StageClearResultBoxInputHandler.get_hovered_box_result(
		_boxes,
		mouse_position,
		draw_scale,
		timer,
		_hovered_box_index
	)
	var apply_result: Dictionary = StageClearResultBoxInputHandler.get_hovered_box_apply_result(
		result,
		_hovered_box_index
	)
	_apply_box_state_result(apply_result)


func _handle_player_victory_click(mouse_position: Vector2) -> bool:
	var view_size: Vector2 = _get_current_view_size()
	var draw_scale: float = _get_layout_scale(view_size)
	var result: Dictionary = StageClearResultActorClickHandler.handle_player_victory_click(
		mouse_position,
		view_size,
		draw_scale,
		_player_victory_click_reaction_timer,
		timer
	)
	_apply_scene_apply_result(StageClearResultActorClickHandler.get_player_victory_click_rect_scene_apply_result(result))
	return _apply_click_reaction_result(
		result,
		&"_player_victory_click_transition_base_frame",
		&"_player_victory_click_reaction_timer"
	)


func _handle_dalji_click(mouse_position: Vector2) -> bool:
	var view_size: Vector2 = _get_current_view_size()
	var draw_scale: float = _get_layout_scale(view_size)
	var result: Dictionary = StageClearResultActorClickHandler.handle_dalji_click(
		current_stage,
		mouse_position,
		view_size,
		draw_scale,
		_dalji_click_reaction_timer,
		_dalji_base_timer
	)
	_apply_scene_apply_result(StageClearResultActorClickHandler.get_dalji_click_rect_scene_apply_result(result))
	if not _apply_click_reaction_result(
		result,
		&"_dalji_click_transition_base_frame",
		&"_dalji_click_reaction_timer"
	):
		return false
	var side_effect_result: Dictionary = StageClearResultActorClickHandler.get_dalji_click_side_effect_scene_apply_result(
		result,
		_dalji_dialogue_timer,
		DALJI_CLICK_DIALOGUE_DURATION
	)
	_apply_scene_apply_result(side_effect_result)
	if bool(side_effect_result.get("play_voice", false)):
		_play_dalji_click_voice()
	return true


func _handle_stage2_boss_defeat_click(mouse_position: Vector2) -> bool:
	return _handle_boss_defeat_click(
		2,
		_stage2_boss_defeat_click_reaction_sheet != null,
		mouse_position,
		_stage2_boss_defeat_click_reaction_timer,
		&"_stage2_boss_defeat_click_transition_base_frame",
		&"_stage2_boss_defeat_click_reaction_timer"
	)


func _handle_stage3_boss_defeat_click(mouse_position: Vector2) -> bool:
	return _handle_boss_defeat_click(
		3,
		_stage3_boss_defeat_click_reaction_sheet != null,
		mouse_position,
		_stage3_boss_defeat_click_reaction_timer,
		&"_stage3_boss_defeat_click_transition_base_frame",
		&"_stage3_boss_defeat_click_reaction_timer"
	)


func _handle_boss_defeat_click(
	stage_id: int,
	has_reaction_sheet: bool,
	mouse_position: Vector2,
	reaction_timer: float,
	transition_base_frame_property: StringName,
	reaction_timer_property: StringName
) -> bool:
	if current_stage != stage_id:
		return false
	var view_size: Vector2 = _get_current_view_size()
	var draw_scale: float = _get_layout_scale(view_size)
	var result: Dictionary = StageClearResultActorClickHandler.handle_boss_defeat_click(
		stage_id,
		has_reaction_sheet,
		mouse_position,
		view_size,
		draw_scale,
		reaction_timer,
		timer
	)
	return _apply_click_reaction_result(
		result,
		transition_base_frame_property,
		reaction_timer_property
	)


func _apply_click_reaction_result(
	result: Dictionary,
	transition_base_frame_property: StringName,
	reaction_timer_property: StringName
) -> bool:
	var apply_result: Dictionary = StageClearResultActorClickHandler.get_click_reaction_scene_apply_result(
		result,
		transition_base_frame_property,
		int(get(transition_base_frame_property)),
		reaction_timer_property,
		float(get(reaction_timer_property))
	)
	if not bool(apply_result.get("handled", false)):
		return false
	_apply_scene_apply_result(apply_result)
	if bool(apply_result.get("redraw", false)):
		queue_redraw()
	return true


func _play_dalji_click_voice() -> void:
	_load_audio()
	_dalji_click_voice_player = StageClearResultVoicePlayer.play_voice(
		self,
		_dalji_click_voice_player,
		_dalji_click_voice_stream
	)


func _play_dalji_click_voice_deferred() -> void:
	StageClearResultVoicePlayer.play_deferred(_dalji_click_voice_player)


func _stop_dalji_click_voice() -> void:
	StageClearResultVoicePlayer.stop_voice(_dalji_click_voice_player)


func _confirm() -> void:
	_stop_dalji_click_voice()
	StageClearResultCallbackHandler.invoke_confirm(confirmed_callback)


func _apply_standalone_preview_defaults() -> void:
	var defaults: Dictionary = StageClearResultPreviewDefaultsHandler.get_standalone_preview_defaults(
		player_score,
		boss_score,
		reward_plan,
		5
	)
	var apply_result: Dictionary = StageClearResultPreviewDefaultsHandler.get_standalone_preview_scene_apply_result(
		defaults,
		player_score,
		boss_score,
		current_stage,
		reward_plan
	)
	_apply_scene_apply_result(apply_result)


func _load_textures() -> void:
	_apply_scene_apply_result(StageClearResultAssetApplyHandler.load_texture_fields(
		self,
		selected_character_type,
		current_stage,
		_player_victory_sheet_loaded_path,
		_player_victory_click_reaction_sheet_loaded_path
	))


func _load_audio() -> void:
	_dalji_click_voice_stream = StageClearResultAudioApplyHandler.load_dalji_click_voice_stream(
		current_stage,
		_dalji_click_voice_stream
	)


func _sync_viewport_size() -> void:
	StageClearResultViewportLayout.sync_control_to_viewport(self)


func _get_layout_scale(view_size: Vector2) -> float:
	return StageClearResultViewportLayout.get_layout_scale(view_size)


func _get_view_size() -> Vector2:
	return StageClearResultViewportLayout.get_view_size(self)
