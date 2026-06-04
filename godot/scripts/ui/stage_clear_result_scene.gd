extends Control

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")
const StageClearResultBoxDrawHelper := preload("res://scripts/ui/stage_clear_result_box_draw_helper.gd")
const StageClearResultClickReactionState := preload("res://scripts/ui/stage_clear_result_click_reaction_state.gd")
const StageClearResultStaticDrawHelper := preload("res://scripts/ui/stage_clear_result_static_draw_helper.gd")
const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")
const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")
const StageClearResultSummaryBuilder := preload("res://scripts/ui/stage_clear_result_summary_builder.gd")
const StageClearResultStatusBuilder := preload("res://scripts/ui/stage_clear_result_status_builder.gd")
const StageClearResultScrollContentDrawHelper := preload("res://scripts/ui/stage_clear_result_scroll_content_draw_helper.gd")
const StageClearResultInteractionState := preload("res://scripts/ui/stage_clear_result_interaction_state.gd")
const StageClearResultShapeHelper := preload("res://scripts/ui/stage_clear_result_shape_helper.gd")
const StageClearResultScrollDrawHelper := preload("res://scripts/ui/stage_clear_result_scroll_draw_helper.gd")
const StageClearResultSheetDrawHelper := preload("res://scripts/ui/stage_clear_result_sheet_draw_helper.gd")
const StageClearResultCinematicPositionHelper := preload("res://scripts/ui/stage_clear_result_cinematic_position_helper.gd")
const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")
const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")
const StageClearResultFontCache := preload("res://scripts/ui/stage_clear_result_font_cache.gd")
const StageClearResultFxHostPool := preload("res://scripts/ui/stage_clear_result_fx_host_pool.gd")
const StageClearResultVoicePlayer := preload("res://scripts/ui/stage_clear_result_voice_player.gd")
const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const STAGE1_BACKGROUND_PATH := StageClearResultAssetLoader.STAGE1_BACKGROUND_PATH
const DALJI_DEFEAT_SHEET_PATH := StageClearResultAssetLoader.DALJI_DEFEAT_SHEET_PATH
const DALJI_CLICK_REACTION_SHEET_PATH := StageClearResultAssetLoader.DALJI_CLICK_REACTION_SHEET_PATH
const DALJI_CLICK_VOICE_PATH := StageClearResultAssetLoader.DALJI_CLICK_VOICE_PATH
const STAGE2_BOSS_DEFEAT_LIVE2D_SHEET_PATH := StageClearResultAssetLoader.STAGE2_BOSS_DEFEAT_LIVE2D_SHEET_PATH
const STAGE2_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH := StageClearResultAssetLoader.STAGE2_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH
const STAGE3_BOSS_DEFEAT_LIVE2D_SHEET_PATH := StageClearResultAssetLoader.STAGE3_BOSS_DEFEAT_LIVE2D_SHEET_PATH
const STAGE3_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH := StageClearResultAssetLoader.STAGE3_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH
const SMASHER_VICTORY_SHEET_PATH := StageClearResultAssetLoader.SMASHER_VICTORY_SHEET_PATH
const SMASHER_CLICK_REACTION_SHEET_PATH := StageClearResultAssetLoader.SMASHER_CLICK_REACTION_SHEET_PATH
const COMMANDO_VICTORY_SHEET_PATH := StageClearResultAssetLoader.COMMANDO_VICTORY_SHEET_PATH
const COMMANDO_CLICK_REACTION_SHEET_PATH := StageClearResultAssetLoader.COMMANDO_CLICK_REACTION_SHEET_PATH
const RESULT_SCROLL_PANEL_PATH := StageClearResultAssetLoader.RESULT_SCROLL_PANEL_PATH

const DALJI_FRAME_COUNT := 98
const DALJI_GRID_COLS := 14
# Source sheet stores 1152px cells, but the result screen only displays the
# character at ~760px. The .import caps the imported texture to 896px cells
# (process/size_limit=12544) so the GPU upload is ~3x cheaper with no visible
# change at the display size. This cell size MUST match that imported cell size.
const DALJI_CELL_SIZE := Vector2(896.0, 896.0)
const DALJI_FRAME_INTERVAL := 0.055
const DALJI_CLICK_FRAME_INTERVAL := 0.036
const DALJI_CLICK_REACTION_DURATION := DALJI_FRAME_COUNT * DALJI_CLICK_FRAME_INTERVAL
const DALJI_CLICK_TRANSITION_DURATION := 0.16
const DALJI_CLICK_RETURN_HOLD_DURATION := 0.18
const DALJI_CLICK_RETURN_FADE_DURATION := 0.05
const DALJI_CLICK_RETURN_BLEND_DURATION := DALJI_CLICK_RETURN_HOLD_DURATION + DALJI_CLICK_RETURN_FADE_DURATION
const DALJI_CLICK_TOTAL_DURATION := DALJI_CLICK_REACTION_DURATION + DALJI_CLICK_RETURN_BLEND_DURATION
const DALJI_CLICK_DIALOGUE_DURATION := 1.55
const DALJI_CLICK_DIALOGUE_FADE_DURATION := 0.20
const DALJI_CLICK_DIALOGUE := "건들지마"

const DALJI_CLICK_VOICE_VOLUME_DB := -4.5

const PLAYER_VICTORY_FRAME_COUNT := 98
const PLAYER_VICTORY_GRID_COLS := 11
# Source sheet stores 1408px cells; result screen displays at ~760px. The
# .import caps the imported texture to 896px cells (process/size_limit=9856)
# for a ~6x cheaper GPU upload with no visible change. Must match the imported
# cell size; StageClearResultLayoutHelper keeps the authored 1408px click
# offsets separately so the click region does not drift after downscale.
const PLAYER_VICTORY_CELL_SIZE := Vector2(896.0, 896.0)
const PLAYER_VICTORY_FRAME_INTERVAL := 0.055
const PLAYER_VICTORY_CLICK_FRAME_INTERVAL := 0.036
const PLAYER_VICTORY_CLICK_REACTION_DURATION := PLAYER_VICTORY_FRAME_COUNT * PLAYER_VICTORY_CLICK_FRAME_INTERVAL
const PLAYER_VICTORY_CLICK_TRANSITION_DURATION := 0.16
const PLAYER_VICTORY_CLICK_RETURN_HOLD_DURATION := 0.18
const PLAYER_VICTORY_CLICK_RETURN_FADE_DURATION := 0.05
const PLAYER_VICTORY_CLICK_RETURN_BLEND_DURATION := PLAYER_VICTORY_CLICK_RETURN_HOLD_DURATION + PLAYER_VICTORY_CLICK_RETURN_FADE_DURATION
const PLAYER_VICTORY_CLICK_TOTAL_DURATION := PLAYER_VICTORY_CLICK_REACTION_DURATION + PLAYER_VICTORY_CLICK_RETURN_BLEND_DURATION

const STAGE2_BOSS_DEFEAT_LIVE2D_FRAME_COUNT := 98
const STAGE2_BOSS_DEFEAT_LIVE2D_GRID_COLS := 14
# Source sheet stores 1152px cells; capped to 896px cells on import
# (process/size_limit=12544). Must match the imported cell size.
const STAGE2_BOSS_DEFEAT_LIVE2D_CELL_SIZE := Vector2(896.0, 896.0)
const STAGE2_BOSS_DEFEAT_LIVE2D_FRAME_INTERVAL := 0.055
const STAGE2_BOSS_DEFEAT_CLICK_FRAME_INTERVAL := 0.036
const STAGE2_BOSS_DEFEAT_CLICK_REACTION_DURATION := STAGE2_BOSS_DEFEAT_LIVE2D_FRAME_COUNT * STAGE2_BOSS_DEFEAT_CLICK_FRAME_INTERVAL
const STAGE2_BOSS_DEFEAT_CLICK_TRANSITION_DURATION := 0.16
const STAGE2_BOSS_DEFEAT_CLICK_RETURN_HOLD_DURATION := 0.18
const STAGE2_BOSS_DEFEAT_CLICK_RETURN_FADE_DURATION := 0.05
const STAGE2_BOSS_DEFEAT_CLICK_RETURN_BLEND_DURATION := STAGE2_BOSS_DEFEAT_CLICK_RETURN_HOLD_DURATION + STAGE2_BOSS_DEFEAT_CLICK_RETURN_FADE_DURATION
const STAGE2_BOSS_DEFEAT_CLICK_TOTAL_DURATION := STAGE2_BOSS_DEFEAT_CLICK_REACTION_DURATION + STAGE2_BOSS_DEFEAT_CLICK_RETURN_BLEND_DURATION
const STAGE3_BOSS_DEFEAT_LIVE2D_FRAME_COUNT := 98
const STAGE3_BOSS_DEFEAT_LIVE2D_GRID_COLS := 14
# Source sheet stores 1152px cells; capped to 896px cells on import
# (process/size_limit=12544). Must match the imported cell size.
const STAGE3_BOSS_DEFEAT_LIVE2D_CELL_SIZE := Vector2(896.0, 896.0)
const STAGE3_BOSS_DEFEAT_LIVE2D_FRAME_INTERVAL := 0.055
const STAGE3_BOSS_DEFEAT_CLICK_FRAME_INTERVAL := 0.036
const STAGE3_BOSS_DEFEAT_CLICK_REACTION_DURATION := STAGE3_BOSS_DEFEAT_LIVE2D_FRAME_COUNT * STAGE3_BOSS_DEFEAT_CLICK_FRAME_INTERVAL
const STAGE3_BOSS_DEFEAT_CLICK_TRANSITION_DURATION := 0.16
const STAGE3_BOSS_DEFEAT_CLICK_RETURN_HOLD_DURATION := 0.18
const STAGE3_BOSS_DEFEAT_CLICK_RETURN_FADE_DURATION := 0.05
const STAGE3_BOSS_DEFEAT_CLICK_RETURN_BLEND_DURATION := STAGE3_BOSS_DEFEAT_CLICK_RETURN_HOLD_DURATION + STAGE3_BOSS_DEFEAT_CLICK_RETURN_FADE_DURATION
const STAGE3_BOSS_DEFEAT_CLICK_TOTAL_DURATION := STAGE3_BOSS_DEFEAT_CLICK_REACTION_DURATION + STAGE3_BOSS_DEFEAT_CLICK_RETURN_BLEND_DURATION

const BOX_BASE_SIZE := Vector2(65.0, 56.0)
const BOX_FLOAT_AMPLITUDE := 5.0
const BOX_FLOAT_SPEED := 1.4
const BOX_HOVER_GROW := 1.06
const BOX_SHADOW_OFFSET_Y := 9.0
const BOX_OPEN_DURATION := 0.6
const BOX_REWARD_EMERGE_DURATION := 0.45
const BOX_REWARD_HOVER_OFFSET := 70.0
const BOX_REWARD_LABEL_SIZE := Vector2(206.0, 64.0)
const BOX_OPENING_SHAKE_AMPLITUDE := 4.0
const BOX_LID_OPEN_PROGRESS := 0.55

const SCROLL_DELAY := 1.10
const SCROLL_UNFURL_DURATION := 0.95
const SCROLL_REGION_RECT := StageClearResultScrollState.SCROLL_REGION_RECT
const SCROLL_CONTENT_MARGIN := StageClearResultScrollState.SCROLL_CONTENT_MARGIN
const SCROLL_DRAG_VIEW_MARGIN := StageClearResultScrollState.SCROLL_DRAG_VIEW_MARGIN

const PLACEHOLDER_GOLD := 1240
const RESULT_BOX_SHEET_COMMON_PATH := StageClearResultAssetLoader.RESULT_BOX_SHEET_COMMON_PATH
const RESULT_BOX_SHEET_MYTHIC_PATH := StageClearResultAssetLoader.RESULT_BOX_SHEET_MYTHIC_PATH
const RESULT_BOX_SHEET_GUARANTEED_MYTHIC_PATH := StageClearResultAssetLoader.RESULT_BOX_SHEET_GUARANTEED_MYTHIC_PATH
const RESULT_REWARD_SOURCE_STAGE := "stage"
const RESULT_REWARD_SOURCE_BOX := "box"
const BOX_KIND_NORMAL := StageClearResultBoxData.BOX_KIND_NORMAL
const BOX_KIND_ADVANCED := StageClearResultBoxData.BOX_KIND_ADVANCED
const BOX_KIND_GUARANTEED_MYTHIC := StageClearResultBoxData.BOX_KIND_GUARANTEED_MYTHIC
const LEGACY_BOX_KIND_MYTHIC := StageClearResultBoxData.LEGACY_BOX_KIND_MYTHIC
const BOX_LABEL_NORMAL := StageClearResultBoxData.BOX_LABEL_NORMAL
const BOX_LABEL_ADVANCED := StageClearResultBoxData.BOX_LABEL_ADVANCED
const BOX_LABEL_GUARANTEED_MYTHIC := StageClearResultBoxData.BOX_LABEL_GUARANTEED_MYTHIC
const RESULT_REWARD_SOURCE_LABELS := {
	"stage": "인게임",
	"box": "상자 보상",
}
const RESULT_CINEMATIC_FIELD_SIZE := Vector2(760.0, 750.0)
const REWARD_DETAIL_FALLBACK_TEXT := "획득한 퍽 효과를 적용합니다."
const REWARD_STARPOINT_TITLE_PREFIX := "퍽 선택권"
const FALLBACK_STARPOINT_SINGLE_CHANCE := 0.70
const FALLBACK_STARPOINT_SINGLE_AMOUNT := 1
const FALLBACK_STARPOINT_DOUBLE_AMOUNT := 2
const PREWARM_ASSET_STEP_COUNT := StageClearResultAssetLoader.PREWARM_ASSET_STEP_COUNT

var timer: float = 0.0
var player_score: int = 0
var boss_score: int = 0
var current_stage: int = 1
var selected_character_type: String = "smasher"
var reward_plan: Dictionary = {}
var stage_reward_snapshot: Dictionary = {}
var confirmed_callback: Callable = Callable()
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
var _exit_button_rect: Rect2 = Rect2()
var _hovered_button: String = "none"
var _reward_icon_cache: Dictionary = {}
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
var _dalji_click_reaction_timer: float = DALJI_CLICK_TOTAL_DURATION
var _player_victory_click_reaction_timer: float = PLAYER_VICTORY_CLICK_TOTAL_DURATION
var _stage2_boss_defeat_click_reaction_timer: float = STAGE2_BOSS_DEFEAT_CLICK_TOTAL_DURATION
var _stage3_boss_defeat_click_reaction_timer: float = STAGE3_BOSS_DEFEAT_CLICK_TOTAL_DURATION
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

static func prewarm_assets(character_type: String = "smasher", stage_id: int = 1) -> Dictionary:
	return StageClearResultAssetLoader.prewarm_result_assets(
		_result_asset_paths(character_type, stage_id),
		StageClearResultAssetLoader.normalize_player_victory_character_type(character_type),
		stage_id
	)


static func prewarm_assets_step(character_type: String = "smasher", stage_id: int = 1) -> bool:
	return StageClearResultAssetLoader.prewarm_result_assets_step(
		_result_asset_paths(character_type, stage_id),
		StageClearResultAssetLoader.normalize_player_victory_character_type(character_type),
		stage_id
	)


static func prewarm_assets_threaded_step(character_type: String = "smasher", stage_id: int = 1) -> bool:
	return StageClearResultAssetLoader.prewarm_result_assets_step(
		_result_asset_paths(character_type, stage_id),
		StageClearResultAssetLoader.normalize_player_victory_character_type(character_type),
		stage_id,
		true
	)


static func reset_prewarm_assets_for_test() -> void:
	StageClearResultAssetLoader.reset_result_prewarm_assets_for_test()


static func get_prewarm_asset_status() -> Dictionary:
	return StageClearResultAssetLoader.get_result_prewarm_asset_status()


static func _result_asset_paths(character_type: String = "smasher", stage_id: int = 1) -> Dictionary:
	return StageClearResultAssetLoader.get_result_asset_paths(character_type, stage_id)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(not _driven_by_controller)
	_apply_standalone_preview_defaults()
	if _boxes.is_empty() and not reward_plan.is_empty():
		_boxes = StageClearResultBoxData.build_boxes_from_plan(reward_plan, BOX_FLOAT_AMPLITUDE, BOX_FLOAT_SPEED)
	_sync_viewport_size()
	_load_textures()
	_load_audio()
	grab_focus()


func configure(
	data: Dictionary,
	on_confirmed: Callable,
	on_exit_to_menu: Callable = Callable(),
	on_roll_reward: Callable = Callable(),
	on_immediate_reward: Callable = Callable()
) -> void:
	_driven_by_controller = true
	set_process(false)
	player_score = int(data.get("player_score", 0))
	boss_score = int(data.get("boss_score", 0))
	current_stage = int(data.get("current_stage", 1))
	var previous_character_type: String = selected_character_type
	selected_character_type = StageClearResultAssetLoader.normalize_player_victory_character_type(str(data.get("selected_character_type", selected_character_type)))
	if selected_character_type != previous_character_type:
		_player_victory_sheet = null
		_player_victory_click_reaction_sheet = null
		_player_victory_sheet_loaded_path = ""
		_player_victory_click_reaction_sheet_loaded_path = ""
	var plan_value: Variant = data.get("reward_plan", {})
	reward_plan = plan_value if plan_value is Dictionary else {}
	var stage_reward_value: Variant = data.get("stage_reward_snapshot", {})
	stage_reward_snapshot = stage_reward_value if stage_reward_value is Dictionary else {}
	_runtime_perk_state = _as_object(data.get("runtime_perk_state", null))
	_runtime_perk_catalog = _as_object(data.get("runtime_perk_catalog", null))
	_runtime_perk_icon_renderer = _as_object(data.get("runtime_perk_icon_renderer", null))
	_runtime_perk_owner = _as_object(data.get("runtime_perk_owner", null))
	_runtime_perk_registry = _as_object(data.get("runtime_perk_registry", null))
	_mythic_item_runtime = _as_object(data.get("mythic_item_runtime", null))
	_treasure_hunt_runtime = _as_object(data.get("treasure_hunt_runtime", null))
	_game_audio = _as_object(data.get("game_audio", null))
	_boxes = StageClearResultBoxData.build_boxes_from_plan(reward_plan, BOX_FLOAT_AMPLITUDE, BOX_FLOAT_SPEED)
	_fx_host_pool.reset_prewarm()
	_lid_open_counter = 0
	set_starpoint_choice_gate_active(false, -1)
	_fx_host_pool.deactivate_all()
	_hovered_box_index = -1
	_hovered_button = "none"
	_next_stage_button_rect = Rect2()
	_exit_button_rect = Rect2()
	_scroll_phase = "hidden"
	_scroll_timer = 0.0
	_scroll_position_offset = Vector2.ZERO
	_cancel_scroll_drag()
	timer = 0.0
	_dalji_base_timer = 0.0
	_dalji_click_reaction_timer = DALJI_CLICK_TOTAL_DURATION
	_player_victory_click_reaction_timer = PLAYER_VICTORY_CLICK_TOTAL_DURATION
	_stage2_boss_defeat_click_reaction_timer = STAGE2_BOSS_DEFEAT_CLICK_TOTAL_DURATION
	_stage3_boss_defeat_click_reaction_timer = STAGE3_BOSS_DEFEAT_CLICK_TOTAL_DURATION
	_dalji_dialogue_timer = 0.0
	_stop_dalji_click_voice()
	confirmed_callback = on_confirmed
	exit_to_menu_callback = on_exit_to_menu
	reward_roll_callback = on_roll_reward
	immediate_reward_callback = on_immediate_reward
	_sync_viewport_size()
	_load_textures()
	_load_audio()
	queue_redraw()


func _process(delta: float) -> void:
	if _driven_by_controller:
		return
	update_result_scene(delta)


func _exit_tree() -> void:
	_fx_host_pool.tear_down()


func update_result_scene(delta: float) -> void:
	var safe_delta: float = max(0.0, delta)
	timer += safe_delta
	_dalji_base_timer += safe_delta
	_dalji_click_reaction_timer = StageClearResultClickReactionState.advance_reaction_timer(_dalji_click_reaction_timer, DALJI_CLICK_TOTAL_DURATION, safe_delta)
	_player_victory_click_reaction_timer = StageClearResultClickReactionState.advance_reaction_timer(_player_victory_click_reaction_timer, PLAYER_VICTORY_CLICK_TOTAL_DURATION, safe_delta)
	_stage2_boss_defeat_click_reaction_timer = StageClearResultClickReactionState.advance_reaction_timer(_stage2_boss_defeat_click_reaction_timer, STAGE2_BOSS_DEFEAT_CLICK_TOTAL_DURATION, safe_delta)
	_stage3_boss_defeat_click_reaction_timer = StageClearResultClickReactionState.advance_reaction_timer(_stage3_boss_defeat_click_reaction_timer, STAGE3_BOSS_DEFEAT_CLICK_TOTAL_DURATION, safe_delta)
	_dalji_dialogue_timer = max(0.0, _dalji_dialogue_timer - safe_delta)
	_update_boxes(safe_delta)
	_update_scroll(safe_delta)
	_sync_viewport_size()
	_fx_host_pool.prewarm_step(self, _boxes)
	_fx_host_pool.sync(
		self,
		_boxes,
		_get_layout_scale(size),
		timer,
		_scroll_phase,
		_scroll_timer,
		SCROLL_UNFURL_DURATION,
		BOX_FLOAT_AMPLITUDE,
		BOX_FLOAT_SPEED
	)
	queue_redraw()


func handle_result_input(event: InputEvent) -> bool:
	if _is_mythic_acquisition_cinematic_active():
		_cancel_scroll_drag()
		return _handle_mythic_acquisition_input(event)
	if _is_runtime_perk_choice_active():
		_cancel_scroll_drag()
		return _handle_runtime_perk_input(event)
	if _is_treasure_hunt_effect_active():
		_cancel_scroll_drag()
		return true

	if GamepadInput.is_gamepad_event(event):
		if GamepadInput.is_confirm_event(event):
			return _handle_advance_input()
		if GamepadInput.is_cancel_event(event):
			return _handle_escape_input()
		return true

	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo:
			match key_event.keycode:
				KEY_ENTER, KEY_SPACE:
					return _handle_advance_input()
				KEY_ESCAPE:
					return _handle_escape_input()
		return false

	if event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event
		if _scroll_dragging:
			_update_scroll_drag(mouse_motion.position)
			return true
		if _scroll_phase == "visible":
			_update_hovered_button(mouse_motion.position)
		else:
			_update_hovered_box(mouse_motion.position)
		return true

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			if _scroll_dragging:
				_finish_scroll_drag(mouse_event.position)
			return true
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if _handle_dalji_click(mouse_event.position):
				pass
			elif _handle_stage2_boss_defeat_click(mouse_event.position):
				pass
			elif _handle_stage3_boss_defeat_click(mouse_event.position):
				pass
			elif _handle_player_victory_click(mouse_event.position):
				pass
			elif _start_scroll_drag(mouse_event.position):
				pass
			elif _handle_button_click(mouse_event.position):
				pass
			elif _handle_box_click(mouse_event.position):
				pass
			else:
				_update_hovered_box(mouse_event.position)
		return true

	return true


func _handle_runtime_perk_input(event: InputEvent) -> bool:
	if _runtime_perk_state == null or not _runtime_perk_state.has_method("handle_input"):
		return true
	var view_size: Vector2 = size
	if view_size == Vector2.ZERO:
		view_size = _get_view_size()
	_runtime_perk_state.handle_input(event, _runtime_perk_owner, _runtime_perk_registry, view_size)
	queue_redraw()
	return true


func _handle_mythic_acquisition_input(event: InputEvent) -> bool:
	if _mythic_item_runtime != null and _mythic_item_runtime.has_method("handle_acquisition_cinematic_input"):
		_mythic_item_runtime.handle_acquisition_cinematic_input(event, _runtime_perk_registry)
	queue_redraw()
	return true


func _is_mythic_acquisition_cinematic_active() -> bool:
	return (
		_mythic_item_runtime != null
		and _mythic_item_runtime.has_method("is_acquisition_cinematic_active")
		and bool(_mythic_item_runtime.is_acquisition_cinematic_active())
	)


func _is_treasure_hunt_effect_active() -> bool:
	return (
		_treasure_hunt_runtime != null
		and _treasure_hunt_runtime.has_method("is_effect_active")
		and bool(_treasure_hunt_runtime.is_effect_active())
	)


func _handle_advance_input() -> bool:
	if _starpoint_choice_gate_active or _is_runtime_perk_choice_active() or _is_treasure_hunt_effect_active():
		return true
	match _scroll_phase:
		"hidden":
			_open_next_idle_box()
			return true
		"visible":
			_confirm()
			return true
	return true


func _handle_escape_input() -> bool:
	if _scroll_phase == "visible":
		_exit_to_menu()
	return true


func _open_next_idle_box() -> bool:
	if _starpoint_choice_gate_active or _is_runtime_perk_choice_active() or _is_treasure_hunt_effect_active():
		return false
	for i in range(_boxes.size()):
		var box: Dictionary = _boxes[i] if _boxes[i] is Dictionary else {}
		if str(box.get("state", "idle")) == "idle":
			_start_opening_box(i)
			return true
	return false


func _exit_to_menu() -> void:
	_stop_dalji_click_voice()
	if exit_to_menu_callback.is_valid():
		exit_to_menu_callback.call()
	elif confirmed_callback.is_valid():
		confirmed_callback.call()


func _handle_button_click(mouse_position: Vector2) -> bool:
	_refresh_scroll_button_rects()
	var clicked_button: String = StageClearResultInteractionState.get_clicked_button(
		mouse_position,
		_next_stage_button_rect,
		_exit_button_rect,
		_scroll_phase
	)
	if clicked_button == StageClearResultInteractionState.BUTTON_NEXT_STAGE:
		_confirm()
		return true
	if clicked_button == StageClearResultInteractionState.BUTTON_EXIT:
		_exit_to_menu()
		return true
	return false


func _update_hovered_button(mouse_position: Vector2) -> void:
	_refresh_scroll_button_rects()
	var previous: String = _hovered_button
	_hovered_button = StageClearResultInteractionState.get_hovered_button(
		mouse_position,
		_next_stage_button_rect,
		_exit_button_rect
	)
	if previous != _hovered_button:
		queue_redraw()


func _start_scroll_drag(mouse_position: Vector2) -> bool:
	if _scroll_phase != "visible" or _starpoint_choice_gate_active:
		return false
	var view_size: Vector2 = _get_current_view_size()
	var layout_scale: float = _get_layout_scale(view_size)
	var scroll_rect: Rect2 = StageClearResultScrollState.get_region_full_rect(layout_scale, _scroll_position_offset)
	if not scroll_rect.has_point(mouse_position):
		return false
	_refresh_scroll_button_rects()
	if StageClearResultInteractionState.get_hovered_button(
		mouse_position,
		_next_stage_button_rect,
		_exit_button_rect
	) != StageClearResultInteractionState.BUTTON_NONE:
		return false
	_scroll_dragging = true
	_scroll_drag_grab_offset = mouse_position - scroll_rect.position
	_hovered_button = StageClearResultInteractionState.BUTTON_NONE
	queue_redraw()
	return true


func _update_scroll_drag(mouse_position: Vector2) -> void:
	var view_size: Vector2 = _get_current_view_size()
	var layout_scale: float = _get_layout_scale(view_size)
	_scroll_position_offset = StageClearResultScrollState.get_region_drag_offset(
		mouse_position,
		_scroll_drag_grab_offset,
		layout_scale,
		view_size
	)
	_refresh_scroll_button_rects()
	queue_redraw()


func _finish_scroll_drag(mouse_position: Vector2) -> void:
	_update_scroll_drag(mouse_position)
	_scroll_dragging = false
	if _scroll_phase == "visible":
		_update_hovered_button(mouse_position)
	else:
		queue_redraw()


func _cancel_scroll_drag() -> void:
	if not _scroll_dragging:
		return
	_scroll_dragging = false
	queue_redraw()


func _refresh_scroll_button_rects() -> void:
	if _scroll_phase != "visible":
		_next_stage_button_rect = Rect2()
		_exit_button_rect = Rect2()
		return
	var view_size: Vector2 = _get_current_view_size()
	var layout_scale: float = _get_layout_scale(view_size)
	var button_layout: Dictionary = StageClearResultInteractionState.get_scroll_button_layout(
		StageClearResultLayoutHelper.get_scroll_content_rect(
			StageClearResultScrollState.get_region_full_rect(layout_scale, _scroll_position_offset),
			layout_scale,
			SCROLL_CONTENT_MARGIN
		),
		layout_scale
	)
	_next_stage_button_rect = button_layout.get("next_stage_rect", Rect2())
	_exit_button_rect = button_layout.get("exit_rect", Rect2())


func _get_current_view_size() -> Vector2:
	var view_size: Vector2 = size
	if view_size == Vector2.ZERO:
		view_size = _get_view_size()
	return view_size


func get_interaction_status() -> Dictionary:
	var view_size: Vector2 = size
	if view_size == Vector2.ZERO:
		view_size = _get_view_size()
	var layout_scale: float = _get_layout_scale(view_size)
	var box_counts: Dictionary = StageClearResultInteractionState.get_box_state_counts(_boxes)
	var reward_summary_state: Dictionary = StageClearResultSummaryBuilder.build_result_summary_state(
		stage_reward_snapshot,
		_boxes,
		RESULT_REWARD_SOURCE_STAGE,
		RESULT_REWARD_SOURCE_BOX,
		RESULT_REWARD_SOURCE_LABELS
	)
	return StageClearResultStatusBuilder.build_interaction_status({
		"view_size": view_size,
		"layout_scale": layout_scale,
		"boxes": _boxes,
		"box_counts": box_counts,
		"reward_summary_state": reward_summary_state,
		"perk_info": StageClearResultSummaryBuilder.build_perk_info_summary_from_reward_state(
			reward_summary_state,
			_perk_catalog,
			REWARD_DETAIL_FALLBACK_TEXT,
			REWARD_STARPOINT_TITLE_PREFIX
		),
		"dalji_reaction_state": _dalji_reaction_state(),
		"player_victory_reaction_state": _player_victory_reaction_state(),
		"stage2_boss_reaction_state": _stage2_boss_defeat_reaction_state(),
		"stage3_boss_reaction_state": _stage3_boss_defeat_reaction_state(),
		"dalji_click_reaction_timer": _dalji_click_reaction_timer,
		"dalji_click_reaction_duration": DALJI_CLICK_REACTION_DURATION,
		"dalji_click_total_duration": DALJI_CLICK_TOTAL_DURATION,
		"dalji_click_transition_base_frame": _dalji_click_transition_base_frame,
		"dalji_base_timer": _dalji_base_timer,
		"dalji_dialogue_timer": _dalji_dialogue_timer,
		"dalji_dialogue": DALJI_CLICK_DIALOGUE,
		"dalji_click_voice_path": DALJI_CLICK_VOICE_PATH,
		"dalji_click_voice_loaded": _dalji_click_voice_stream != null,
		"dalji_click_voice_player_ready": _dalji_click_voice_player != null,
		"dalji_click_voice_playing": _dalji_click_voice_player != null and _dalji_click_voice_player.playing,
		"selected_character_type": selected_character_type,
		"player_victory_sheet_path": StageClearResultAssetLoader.get_player_victory_sheet_path_for_character(selected_character_type),
		"player_victory_click_reaction_sheet_path": StageClearResultAssetLoader.get_player_victory_click_reaction_sheet_path_for_character(selected_character_type),
		"player_victory_sheet_loaded": _player_victory_sheet != null,
		"player_victory_click_reaction_sheet_loaded": _player_victory_click_reaction_sheet != null,
		"player_victory_frame_count": PLAYER_VICTORY_FRAME_COUNT,
		"player_victory_grid_cols": PLAYER_VICTORY_GRID_COLS,
		"player_victory_cell_size": PLAYER_VICTORY_CELL_SIZE,
		"player_victory_click_reaction_timer": _player_victory_click_reaction_timer,
		"player_victory_click_reaction_duration": PLAYER_VICTORY_CLICK_REACTION_DURATION,
		"player_victory_click_total_duration": PLAYER_VICTORY_CLICK_TOTAL_DURATION,
		"player_victory_click_transition_base_frame": _player_victory_click_transition_base_frame,
		"stage2_boss_defeat_live2d_sheet_path": STAGE2_BOSS_DEFEAT_LIVE2D_SHEET_PATH,
		"stage2_boss_defeat_live2d_sheet_loaded": _stage2_boss_defeat_live2d_sheet != null,
		"stage2_boss_defeat_click_reaction_sheet_path": STAGE2_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH,
		"stage2_boss_defeat_click_reaction_sheet_loaded": _stage2_boss_defeat_click_reaction_sheet != null,
		"stage2_boss_defeat_live2d_frame_count": STAGE2_BOSS_DEFEAT_LIVE2D_FRAME_COUNT,
		"stage2_boss_defeat_live2d_grid_cols": STAGE2_BOSS_DEFEAT_LIVE2D_GRID_COLS,
		"stage2_boss_defeat_live2d_cell_size": STAGE2_BOSS_DEFEAT_LIVE2D_CELL_SIZE,
		"stage2_boss_defeat_click_reaction_timer": _stage2_boss_defeat_click_reaction_timer,
		"stage2_boss_defeat_click_reaction_duration": STAGE2_BOSS_DEFEAT_CLICK_REACTION_DURATION,
		"stage2_boss_defeat_click_total_duration": STAGE2_BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		"stage2_boss_defeat_click_transition_base_frame": _stage2_boss_defeat_click_transition_base_frame,
		"stage3_boss_defeat_live2d_sheet_path": STAGE3_BOSS_DEFEAT_LIVE2D_SHEET_PATH,
		"stage3_boss_defeat_live2d_sheet_loaded": _stage3_boss_defeat_live2d_sheet != null,
		"stage3_boss_defeat_click_reaction_sheet_path": STAGE3_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH,
		"stage3_boss_defeat_click_reaction_sheet_loaded": _stage3_boss_defeat_click_reaction_sheet != null,
		"stage3_boss_defeat_live2d_frame_count": STAGE3_BOSS_DEFEAT_LIVE2D_FRAME_COUNT,
		"stage3_boss_defeat_live2d_grid_cols": STAGE3_BOSS_DEFEAT_LIVE2D_GRID_COLS,
		"stage3_boss_defeat_live2d_cell_size": STAGE3_BOSS_DEFEAT_LIVE2D_CELL_SIZE,
		"stage3_boss_defeat_click_reaction_timer": _stage3_boss_defeat_click_reaction_timer,
		"stage3_boss_defeat_click_reaction_duration": STAGE3_BOSS_DEFEAT_CLICK_REACTION_DURATION,
		"stage3_boss_defeat_click_total_duration": STAGE3_BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		"stage3_boss_defeat_click_transition_base_frame": _stage3_boss_defeat_click_transition_base_frame,
		"current_stage": current_stage,
		"hovered_box_index": _hovered_box_index,
		"scroll_phase": _scroll_phase,
		"scroll_timer": _scroll_timer,
		"scroll_unfurl_duration": SCROLL_UNFURL_DURATION,
		"scroll_texture_loaded": _scroll_texture != null,
		"scroll_rect": StageClearResultScrollState.get_region_full_rect(layout_scale, _scroll_position_offset),
		"scroll_position_offset": _scroll_position_offset,
		"scroll_dragging": _scroll_dragging,
		"next_stage_button_rect": _next_stage_button_rect,
		"exit_button_rect": _exit_button_rect,
		"hovered_button": _hovered_button,
		"scene_timer": timer,
		"exit_callback_bound": exit_to_menu_callback.is_valid(),
		"starpoint_choice_gate_active": _starpoint_choice_gate_active,
		"starpoint_choice_gate_box_index": _starpoint_choice_gate_box_index,
		"runtime_perk_choice_active": _is_runtime_perk_choice_active(),
		"treasure_hunt_effect_active": _is_treasure_hunt_effect_active(),
		"box_open_audio_ready": _game_audio != null and _game_audio.has_method("play_result_box_open"),
	})


func get_resolved_rewards() -> Array:
	return StageClearResultBoxData.get_resolved_rewards(_boxes)


func _gui_input(event: InputEvent) -> void:
	if handle_result_input(event):
		accept_event()


func _draw() -> void:
	var view_size: Vector2 = size
	if view_size == Vector2.ZERO:
		view_size = _get_view_size()
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
	if not bool(result.get("updated", false)):
		return
	_boxes = result.get("boxes", _boxes)
	queue_redraw()


func _draw_runtime_perk_overlay(view_size: Vector2) -> void:
	if not _should_draw_runtime_perk_overlay():
		return
	var overlay_renderer: Object = _runtime_perk_overlay_renderer
	if overlay_renderer == null or not overlay_renderer.has_method("draw"):
		return
	var catalog: Object = _runtime_perk_catalog if _runtime_perk_catalog != null else _perk_catalog
	var icon_renderer: Object = _runtime_perk_icon_renderer if _runtime_perk_icon_renderer != null else _perk_icon_renderer
	overlay_renderer.draw(
		self,
		_runtime_perk_state,
		catalog,
		view_size,
		icon_renderer,
		_mythic_item_runtime,
		_treasure_hunt_runtime
	)


func _should_draw_runtime_perk_overlay() -> bool:
	if _is_runtime_perk_choice_active() or _is_treasure_hunt_effect_active():
		return true
	if _runtime_perk_overlay_renderer != null and _runtime_perk_overlay_renderer.has_method("has_visible_effects"):
		return bool(_runtime_perk_overlay_renderer.has_visible_effects(
			_runtime_perk_state,
			_mythic_item_runtime,
			_treasure_hunt_runtime
		))
	return false


func _is_runtime_perk_choice_active() -> bool:
	return (
		_runtime_perk_state != null
		and _runtime_perk_state.has_method("is_choice_active")
		and bool(_runtime_perk_state.is_choice_active())
	)


@warning_ignore("shadowed_variable_base_class")
func _draw_defeated_boss(view_size: Vector2, scale: float) -> void:
	if current_stage == 2:
		if _stage2_boss_defeat_live2d_sheet != null:
			StageClearResultActorDrawHelper.draw_stage2_defeated(self, _stage2_boss_defeat_live2d_sheet, _stage2_boss_defeat_click_reaction_sheet, _stage2_boss_defeat_reaction_state(), view_size, scale, STAGE2_BOSS_DEFEAT_LIVE2D_GRID_COLS, STAGE2_BOSS_DEFEAT_LIVE2D_CELL_SIZE, 0.98)
		return
	if current_stage == 3:
		if _stage3_boss_defeat_live2d_sheet != null:
			StageClearResultActorDrawHelper.draw_stage3_defeated(self, _stage3_boss_defeat_live2d_sheet, _stage3_boss_defeat_click_reaction_sheet, _stage3_boss_defeat_reaction_state(), view_size, scale, STAGE3_BOSS_DEFEAT_LIVE2D_GRID_COLS, STAGE3_BOSS_DEFEAT_LIVE2D_CELL_SIZE, 0.98)
		return
	if _dalji_defeat_sheet == null:
		return
	_dalji_click_rect = StageClearResultActorDrawHelper.draw_dalji_defeated(self, _dalji_defeat_sheet, _dalji_click_reaction_sheet, _dalji_reaction_state(), view_size, scale, DALJI_GRID_COLS, DALJI_CELL_SIZE, 0.98)


@warning_ignore("shadowed_variable_base_class")
func _draw_player_victory(view_size: Vector2, scale: float, font: Font) -> void:
	if _draw_player_victory_live2d(view_size, scale):
		return
	StageClearResultStaticDrawHelper.draw_player_victory_fallback(
		self,
		font,
		view_size, scale, timer, _player_victory_sheet,
		PLAYER_VICTORY_FRAME_INTERVAL, PLAYER_VICTORY_FRAME_COUNT, PLAYER_VICTORY_GRID_COLS, PLAYER_VICTORY_CELL_SIZE,
		"플레이어 승리", "Live2D 포즈", "승리 연출 테스트"
	)


func _draw_player_victory_live2d(view_size: Vector2, layout_ratio: float) -> bool:
	var result: Dictionary = StageClearResultActorDrawHelper.draw_player_victory_live2d(self, _player_victory_sheet, _player_victory_click_reaction_sheet, _player_victory_reaction_state(), view_size, layout_ratio, PLAYER_VICTORY_GRID_COLS, PLAYER_VICTORY_CELL_SIZE)
	_player_victory_click_rect = result.get("click_rect", Rect2())
	return bool(result.get("drawn", true))


@warning_ignore("shadowed_variable_base_class")
func _draw_floating_boxes(_view_size: Vector2, scale: float) -> void:
	if _boxes.is_empty():
		return
	for i in range(_boxes.size()):
		var box: Dictionary = _boxes[i] if _boxes[i] is Dictionary else {}
		var hovered: bool = i == _hovered_box_index
		_draw_floating_box(box, scale, hovered)


@warning_ignore("shadowed_variable_base_class")
func _draw_floating_box(box: Dictionary, scale: float, hovered: bool) -> void:
	StageClearResultBoxDrawHelper.draw_floating_result_box(
		self,
		box,
		StageClearResultBoxDrawHelper.build_floating_result_box_draw_context(
			box,
			hovered,
			scale,
			timer,
			_scroll_phase,
			_scroll_timer,
			SCROLL_UNFURL_DURATION,
			BOX_FLOAT_AMPLITUDE,
			BOX_FLOAT_SPEED,
			BOX_OPENING_SHAKE_AMPLITUDE,
			BOX_SHADOW_OFFSET_Y,
			BOX_HOVER_GROW,
			BOX_BASE_SIZE,
			BOX_REWARD_HOVER_OFFSET,
			_result_box_sheet_common,
			_result_box_sheet_mythic,
			_result_box_sheet_guaranteed_mythic,
			_reward_icon_cache
		)
	)


func _handle_box_click(mouse_position: Vector2) -> bool:
	if _boxes.is_empty():
		return false
	if _starpoint_choice_gate_active or _is_runtime_perk_choice_active() or _is_treasure_hunt_effect_active():
		return true
	if _scroll_phase != "hidden":
		return false
	@warning_ignore("shadowed_variable_base_class")
	var scale: float = _get_layout_scale(size)
	var clicked_index: int = StageClearResultInteractionState.get_clicked_idle_box_index(_boxes, mouse_position, scale, timer, BOX_BASE_SIZE, BOX_HOVER_GROW, BOX_FLOAT_AMPLITUDE, BOX_FLOAT_SPEED)
	if clicked_index < 0:
		return false
	_start_opening_box(clicked_index)
	return true


func _start_opening_box(index: int) -> void:
	var box: Dictionary = _boxes[index] if index >= 0 and index < _boxes.size() and _boxes[index] is Dictionary else {}
	var result: Dictionary = StageClearResultBoxData.start_opening_box(
		_boxes,
		index,
		StageClearResultBoxData.roll_reward(
			str(box.get("roll_kind", box.get("kind", StageClearResultBoxData.BOX_KIND_NORMAL))),
			reward_roll_callback,
			FALLBACK_STARPOINT_SINGLE_CHANCE,
			FALLBACK_STARPOINT_SINGLE_AMOUNT,
			FALLBACK_STARPOINT_DOUBLE_AMOUNT
		)
	)
	if not bool(result.get("started", false)):
		return
	_boxes = result.get("boxes", _boxes)
	_play_result_box_open_audio()
	if _hovered_box_index == index:
		_hovered_box_index = -1
	queue_redraw()


func _play_result_box_open_audio() -> void:
	if _game_audio != null and _game_audio.has_method("play_result_box_open"):
		_game_audio.play_result_box_open()


func _update_boxes(delta: float) -> void:
	var result: Dictionary = StageClearResultBoxData.update_box_opening_state(
		_boxes,
		delta,
		BOX_OPEN_DURATION,
		BOX_REWARD_EMERGE_DURATION,
		BOX_LID_OPEN_PROGRESS,
		_lid_open_counter
	)
	_boxes = result.get("boxes", _boxes)
	_lid_open_counter = int(result.get("lid_open_counter", _lid_open_counter))
	var opened_indices: Array = result.get("opened_indices", [])
	if opened_indices.is_empty():
		return
	for index_value in opened_indices:
		var index: int = int(index_value)
		if index >= 0 and index < _boxes.size() and _boxes[index] is Dictionary:
			_try_grant_immediate_reward(index, _boxes[index])


func _try_grant_immediate_reward(index: int, box: Dictionary) -> void:
	if bool(box.get("reward_immediate_granted", false)):
		return
	if not immediate_reward_callback.is_valid():
		return
	var reward_value: Variant = box.get("reward", {})
	if not (reward_value is Dictionary):
		return
	var reward: Dictionary = (reward_value as Dictionary).duplicate(true)
	if reward.is_empty():
		return
	reward["box_kind"] = str(box.get("kind", "normal"))
	reward["box_state"] = str(box.get("state", "opened"))
	var view_size: Vector2 = size
	if view_size == Vector2.ZERO:
		view_size = _get_view_size()
	@warning_ignore("shadowed_variable_base_class")
	var scale: float = _get_layout_scale(view_size)
	var cinematic_positions: Dictionary = StageClearResultCinematicPositionHelper.get_reward_cinematic_positions(
		box,
		view_size,
		scale,
		timer,
		RESULT_CINEMATIC_FIELD_SIZE,
		BOX_FLOAT_AMPLITUDE,
		BOX_FLOAT_SPEED
	)
	reward["pickup_position"] = cinematic_positions.get("pickup_position", Vector2.ZERO)
	reward["target_player_center"] = cinematic_positions.get("target_player_center", Vector2.ZERO)
	var granted: bool = bool(immediate_reward_callback.call(reward, index))
	if not granted:
		return
	box["reward_immediate_granted"] = true
	reward_value = box.get("reward", {})
	if reward_value is Dictionary:
		var stored_reward: Dictionary = reward_value
		stored_reward["immediate_granted"] = true
		box["reward"] = stored_reward
	_boxes[index] = box


func _update_scroll(delta: float) -> void:
	var result: Dictionary = StageClearResultScrollState.update_phase(
		_scroll_phase,
		_scroll_timer,
		delta,
		_starpoint_choice_gate_active or _is_runtime_perk_choice_active() or _is_treasure_hunt_effect_active(),
		StageClearResultInteractionState.all_boxes_opened(_boxes),
		SCROLL_DELAY,
		SCROLL_UNFURL_DURATION
	)
	_scroll_phase = str(result.get("phase", _scroll_phase))
	_scroll_timer = float(result.get("timer", _scroll_timer))


@warning_ignore("shadowed_variable_base_class")
func _draw_scroll(view_size: Vector2, scale: float, font: Font) -> void:
	if _scroll_phase == "hidden":
		return
	_scroll_position_offset = StageClearResultScrollState.clamp_region_offset(_scroll_position_offset, scale, view_size)
	var unfurl: float = StageClearResultScrollState.get_unfurl_progress(_scroll_phase, _scroll_timer, SCROLL_UNFURL_DURATION)
	if unfurl <= 0.0:
		return
	_draw_cyber_scroll(unfurl, scale, font)


@warning_ignore("shadowed_variable_base_class")
func _draw_cyber_scroll(unfurl: float, scale: float, font: Font) -> void:
	var full_rect: Rect2 = StageClearResultScrollState.get_region_full_rect(scale, _scroll_position_offset)
	var current_height: float = full_rect.size.y * unfurl
	var visible_rect := Rect2(full_rect.position, Vector2(full_rect.size.x, current_height))

	StageClearResultShapeHelper.draw_filled_ellipse(
		self,
		Vector2(full_rect.get_center().x, visible_rect.end.y + 22.0 * scale),
		full_rect.size.x * 0.45,
		16.0 * scale,
		Color(0.0, 0.0, 0.0, 0.22 + 0.14 * unfurl),
		24
	)

	if not StageClearResultScrollDrawHelper.draw_cyber_scroll_texture(self, _scroll_texture, visible_rect, unfurl):
		StageClearResultScrollDrawHelper.draw_cyber_scroll_fallback(self, visible_rect, scale, unfurl)

	if unfurl <= 0.58:
		_next_stage_button_rect = Rect2()
		_exit_button_rect = Rect2()
		return

	var content_alpha: float = StageClearResultClickReactionState.smooth01((unfurl - 0.58) / 0.42)
	_draw_cyber_scroll_contents(StageClearResultLayoutHelper.get_scroll_content_rect(full_rect, scale, SCROLL_CONTENT_MARGIN), scale, font, content_alpha)


@warning_ignore("shadowed_variable_base_class")
func _draw_cyber_scroll_contents(rect: Rect2, scale: float, font: Font, alpha: float) -> void:
	var button_layout: Dictionary = StageClearResultScrollContentDrawHelper.draw_scroll_contents(
		self,
		font,
		rect,
		scale,
		alpha,
		{
			"current_stage": current_stage,
			"stage_reward_snapshot": stage_reward_snapshot,
			"boxes": _boxes,
			"runtime_perk_state": _runtime_perk_state,
			"placeholder_gold": PLACEHOLDER_GOLD,
			"player_score": player_score,
			"boss_score": boss_score,
			"timer": timer,
			"perk_catalog": _perk_catalog,
			"perk_icon_renderer": _perk_icon_renderer,
			"reward_icon_cache": _reward_icon_cache,
			"result_reward_source_stage": RESULT_REWARD_SOURCE_STAGE,
			"result_reward_source_box": RESULT_REWARD_SOURCE_BOX,
			"result_reward_source_labels": RESULT_REWARD_SOURCE_LABELS,
			"reward_detail_fallback_text": REWARD_DETAIL_FALLBACK_TEXT,
			"reward_starpoint_title_prefix": REWARD_STARPOINT_TITLE_PREFIX,
			"scroll_phase": _scroll_phase,
			"hovered_button": _hovered_button,
		}
	)
	if button_layout.is_empty():
		return
	_next_stage_button_rect = button_layout.get("next_stage_rect", Rect2())
	_exit_button_rect = button_layout.get("exit_rect", Rect2())


func _update_hovered_box(mouse_position: Vector2) -> void:
	if _boxes.is_empty():
		_hovered_box_index = -1
		return
	@warning_ignore("shadowed_variable_base_class")
	var scale: float = _get_layout_scale(size)
	var previous: int = _hovered_box_index
	_hovered_box_index = StageClearResultInteractionState.get_hovered_box_index(_boxes, mouse_position, scale, timer, BOX_BASE_SIZE, BOX_HOVER_GROW, BOX_FLOAT_AMPLITUDE, BOX_FLOAT_SPEED)
	if previous != _hovered_box_index:
		queue_redraw()


func _handle_player_victory_click(mouse_position: Vector2) -> bool:
	var view_size: Vector2 = size
	if view_size == Vector2.ZERO:
		view_size = _get_view_size()
	@warning_ignore("shadowed_variable_base_class")
	var scale: float = _get_layout_scale(view_size)
	var click_rect: Rect2 = StageClearResultLayoutHelper.get_player_victory_click_rect(
		view_size,
		scale,
		PLAYER_VICTORY_CELL_SIZE
	)
	_player_victory_click_rect = click_rect
	var attempt: Dictionary = StageClearResultClickReactionState.get_click_reaction_attempt(
		mouse_position,
		click_rect,
		_player_victory_click_reaction_timer,
		PLAYER_VICTORY_CLICK_TOTAL_DURATION,
		timer,
		PLAYER_VICTORY_FRAME_INTERVAL,
		PLAYER_VICTORY_FRAME_COUNT
	)
	if not bool(attempt.get("handled", false)):
		return false
	if bool(attempt.get("started", false)):
		_player_victory_click_transition_base_frame = int(attempt.get("transition_base_frame", 0))
		_player_victory_click_reaction_timer = float(attempt.get("reaction_timer", 0.0))
	queue_redraw()
	return true


func _handle_dalji_click(mouse_position: Vector2) -> bool:
	if current_stage != 1:
		return false
	var view_size: Vector2 = size
	if view_size == Vector2.ZERO:
		view_size = _get_view_size()
	@warning_ignore("shadowed_variable_base_class")
	var scale: float = _get_layout_scale(view_size)
	var click_rect: Rect2 = StageClearResultLayoutHelper.get_dalji_draw_rect(view_size, scale)
	_dalji_click_rect = click_rect
	var attempt: Dictionary = StageClearResultClickReactionState.get_click_reaction_attempt(
		mouse_position,
		click_rect,
		_dalji_click_reaction_timer,
		DALJI_CLICK_TOTAL_DURATION,
		_dalji_base_timer,
		DALJI_FRAME_INTERVAL,
		DALJI_FRAME_COUNT
	)
	if not bool(attempt.get("handled", false)):
		return false
	if bool(attempt.get("started", false)):
		_dalji_click_transition_base_frame = int(attempt.get("transition_base_frame", 0))
		_dalji_click_reaction_timer = float(attempt.get("reaction_timer", 0.0))
	_dalji_dialogue_timer = DALJI_CLICK_DIALOGUE_DURATION
	_play_dalji_click_voice()
	queue_redraw()
	return true


func _handle_stage2_boss_defeat_click(mouse_position: Vector2) -> bool:
	if current_stage != 2 or _stage2_boss_defeat_click_reaction_sheet == null:
		return false
	var view_size: Vector2 = size
	if view_size == Vector2.ZERO:
		view_size = _get_view_size()
	@warning_ignore("shadowed_variable_base_class")
	var scale: float = _get_layout_scale(view_size)
	var click_rect: Rect2 = StageClearResultLayoutHelper.get_stage2_boss_result_draw_rect(view_size, scale)
	var attempt: Dictionary = StageClearResultClickReactionState.get_click_reaction_attempt(
		mouse_position,
		click_rect,
		_stage2_boss_defeat_click_reaction_timer,
		STAGE2_BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		timer,
		STAGE2_BOSS_DEFEAT_LIVE2D_FRAME_INTERVAL,
		STAGE2_BOSS_DEFEAT_LIVE2D_FRAME_COUNT
	)
	if not bool(attempt.get("handled", false)):
		return false
	if bool(attempt.get("started", false)):
		_stage2_boss_defeat_click_transition_base_frame = int(attempt.get("transition_base_frame", 0))
		_stage2_boss_defeat_click_reaction_timer = float(attempt.get("reaction_timer", 0.0))
	queue_redraw()
	return true


func _handle_stage3_boss_defeat_click(mouse_position: Vector2) -> bool:
	if current_stage != 3 or _stage3_boss_defeat_click_reaction_sheet == null:
		return false
	var view_size: Vector2 = size
	if view_size == Vector2.ZERO:
		view_size = _get_view_size()
	@warning_ignore("shadowed_variable_base_class")
	var scale: float = _get_layout_scale(view_size)
	var click_rect: Rect2 = StageClearResultLayoutHelper.get_stage3_boss_result_draw_rect(view_size, scale)
	var attempt: Dictionary = StageClearResultClickReactionState.get_click_reaction_attempt(
		mouse_position,
		click_rect,
		_stage3_boss_defeat_click_reaction_timer,
		STAGE3_BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		timer,
		STAGE3_BOSS_DEFEAT_LIVE2D_FRAME_INTERVAL,
		STAGE3_BOSS_DEFEAT_LIVE2D_FRAME_COUNT
	)
	if not bool(attempt.get("handled", false)):
		return false
	if bool(attempt.get("started", false)):
		_stage3_boss_defeat_click_transition_base_frame = int(attempt.get("transition_base_frame", 0))
		_stage3_boss_defeat_click_reaction_timer = float(attempt.get("reaction_timer", 0.0))
	queue_redraw()
	return true


func _play_dalji_click_voice() -> void:
	_load_audio()
	_dalji_click_voice_player = StageClearResultVoicePlayer.play_voice(
		self,
		_dalji_click_voice_player,
		_dalji_click_voice_stream,
		DALJI_CLICK_VOICE_VOLUME_DB,
		"DaljiClickCryVoice",
		&"_play_dalji_click_voice_deferred"
	)


func _play_dalji_click_voice_deferred() -> void:
	StageClearResultVoicePlayer.play_deferred(_dalji_click_voice_player)


func _stop_dalji_click_voice() -> void:
	StageClearResultVoicePlayer.stop_voice(_dalji_click_voice_player)


func _player_victory_reaction_state() -> Dictionary:
	return StageClearResultClickReactionState.get_reaction_state(
		timer,
		PLAYER_VICTORY_FRAME_INTERVAL,
		PLAYER_VICTORY_FRAME_COUNT,
		_player_victory_click_reaction_timer,
		PLAYER_VICTORY_CLICK_REACTION_DURATION,
		PLAYER_VICTORY_CLICK_FRAME_INTERVAL,
		PLAYER_VICTORY_CLICK_TRANSITION_DURATION,
		_player_victory_click_transition_base_frame,
		PLAYER_VICTORY_CLICK_RETURN_HOLD_DURATION,
		PLAYER_VICTORY_CLICK_RETURN_FADE_DURATION,
		PLAYER_VICTORY_CLICK_TOTAL_DURATION
	)


func _stage2_boss_defeat_reaction_state() -> Dictionary:
	return StageClearResultClickReactionState.get_reaction_state(
		timer,
		STAGE2_BOSS_DEFEAT_LIVE2D_FRAME_INTERVAL,
		STAGE2_BOSS_DEFEAT_LIVE2D_FRAME_COUNT,
		_stage2_boss_defeat_click_reaction_timer,
		STAGE2_BOSS_DEFEAT_CLICK_REACTION_DURATION,
		STAGE2_BOSS_DEFEAT_CLICK_FRAME_INTERVAL,
		STAGE2_BOSS_DEFEAT_CLICK_TRANSITION_DURATION,
		_stage2_boss_defeat_click_transition_base_frame,
		STAGE2_BOSS_DEFEAT_CLICK_RETURN_HOLD_DURATION,
		STAGE2_BOSS_DEFEAT_CLICK_RETURN_FADE_DURATION,
		STAGE2_BOSS_DEFEAT_CLICK_TOTAL_DURATION
	)


func _stage3_boss_defeat_reaction_state() -> Dictionary:
	return StageClearResultClickReactionState.get_reaction_state(
		timer,
		STAGE3_BOSS_DEFEAT_LIVE2D_FRAME_INTERVAL,
		STAGE3_BOSS_DEFEAT_LIVE2D_FRAME_COUNT,
		_stage3_boss_defeat_click_reaction_timer,
		STAGE3_BOSS_DEFEAT_CLICK_REACTION_DURATION,
		STAGE3_BOSS_DEFEAT_CLICK_FRAME_INTERVAL,
		STAGE3_BOSS_DEFEAT_CLICK_TRANSITION_DURATION,
		_stage3_boss_defeat_click_transition_base_frame,
		STAGE3_BOSS_DEFEAT_CLICK_RETURN_HOLD_DURATION,
		STAGE3_BOSS_DEFEAT_CLICK_RETURN_FADE_DURATION,
		STAGE3_BOSS_DEFEAT_CLICK_TOTAL_DURATION
	)


func _dalji_reaction_state() -> Dictionary:
	return StageClearResultClickReactionState.get_reaction_state(
		_dalji_base_timer,
		DALJI_FRAME_INTERVAL,
		DALJI_FRAME_COUNT,
		_dalji_click_reaction_timer,
		DALJI_CLICK_REACTION_DURATION,
		DALJI_CLICK_FRAME_INTERVAL,
		DALJI_CLICK_TRANSITION_DURATION,
		_dalji_click_transition_base_frame,
		DALJI_CLICK_RETURN_HOLD_DURATION,
		DALJI_CLICK_RETURN_FADE_DURATION,
		DALJI_CLICK_TOTAL_DURATION
	)


func _confirm() -> void:
	_stop_dalji_click_voice()
	if confirmed_callback.is_valid():
		confirmed_callback.call()


func _apply_standalone_preview_defaults() -> void:
	if player_score != 0 or boss_score != 0 or not reward_plan.is_empty():
		return
	player_score = 5
	boss_score = 0
	current_stage = 1
	reward_plan = {
		"summary": LanguageSettings.format_item_box_summary(5),
		"boxes": [
			{"kind": "normal"},
			{"kind": "normal"},
			{"kind": "normal"},
			{"kind": "normal"},
			{"kind": "normal"},
		],
		"reward_count": 5,
	}


func _load_textures() -> void:
	var paths: Dictionary = _result_asset_paths(selected_character_type, current_stage)
	var player_victory_path: String = str(paths.get("player_victory_sheet", ""))
	var player_victory_click_path: String = str(paths.get("player_victory_click_reaction_sheet", ""))
	var loaded: Dictionary = StageClearResultAssetLoader.load_textures(
		{
			"background_texture": _background_texture,
			"dalji_defeat_sheet": _dalji_defeat_sheet,
			"dalji_click_reaction_sheet": _dalji_click_reaction_sheet,
			"stage2_boss_defeat_live2d_sheet": _stage2_boss_defeat_live2d_sheet,
			"stage2_boss_defeat_click_reaction_sheet": _stage2_boss_defeat_click_reaction_sheet,
			"stage3_boss_defeat_live2d_sheet": _stage3_boss_defeat_live2d_sheet,
			"stage3_boss_defeat_click_reaction_sheet": _stage3_boss_defeat_click_reaction_sheet,
			"player_victory_sheet": _player_victory_sheet if _player_victory_sheet_loaded_path == player_victory_path else null,
			"player_victory_click_reaction_sheet": (
				_player_victory_click_reaction_sheet
				if _player_victory_click_reaction_sheet_loaded_path == player_victory_click_path
				else null
			),
			"scroll_texture": _scroll_texture,
			"result_box_sheet_common": _result_box_sheet_common,
			"result_box_sheet_mythic": _result_box_sheet_mythic,
			"result_box_sheet_guaranteed_mythic": _result_box_sheet_guaranteed_mythic,
		},
		paths
	)
	_background_texture = loaded.get("background_texture") as Texture2D
	_dalji_defeat_sheet = loaded.get("dalji_defeat_sheet") as Texture2D
	_dalji_click_reaction_sheet = loaded.get("dalji_click_reaction_sheet") as Texture2D
	_stage2_boss_defeat_live2d_sheet = loaded.get("stage2_boss_defeat_live2d_sheet") as Texture2D
	_stage2_boss_defeat_click_reaction_sheet = loaded.get("stage2_boss_defeat_click_reaction_sheet") as Texture2D
	_stage3_boss_defeat_live2d_sheet = loaded.get("stage3_boss_defeat_live2d_sheet") as Texture2D
	_stage3_boss_defeat_click_reaction_sheet = loaded.get("stage3_boss_defeat_click_reaction_sheet") as Texture2D
	_player_victory_sheet = loaded.get("player_victory_sheet") as Texture2D
	_player_victory_click_reaction_sheet = loaded.get("player_victory_click_reaction_sheet") as Texture2D
	_player_victory_sheet_loaded_path = player_victory_path if _player_victory_sheet != null else ""
	_player_victory_click_reaction_sheet_loaded_path = player_victory_click_path if _player_victory_click_reaction_sheet != null else ""
	_scroll_texture = loaded.get("scroll_texture") as Texture2D
	_result_box_sheet_common = loaded.get("result_box_sheet_common") as Texture2D
	_result_box_sheet_mythic = loaded.get("result_box_sheet_mythic") as Texture2D
	_result_box_sheet_guaranteed_mythic = loaded.get("result_box_sheet_guaranteed_mythic") as Texture2D


func _load_audio() -> void:
	if current_stage != 1:
		_dalji_click_voice_stream = null
		return
	_dalji_click_voice_stream = StageClearResultAssetLoader.load_dalji_click_voice(_dalji_click_voice_stream, DALJI_CLICK_VOICE_PATH)


func _as_object(value: Variant) -> Object:
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _sync_viewport_size() -> void:
	var view_size: Vector2 = _get_view_size()
	if view_size == Vector2.ZERO:
		return
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	position = Vector2.ZERO
	size = view_size


func _get_layout_scale(view_size: Vector2) -> float:
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return 1.0
	return min(view_size.x / 1920.0, view_size.y / 1080.0)


func _get_view_size() -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport != null:
		return viewport.get_visible_rect().size
	return Vector2(1920.0, 1080.0)
