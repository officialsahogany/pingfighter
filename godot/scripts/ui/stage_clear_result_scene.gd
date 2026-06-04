extends Control

const ResultBoxOpenFxHost := preload("res://scripts/effects/result_box_open_fx_host.gd")
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
const StageClearResultRewardCardDrawHelper := preload("res://scripts/ui/stage_clear_result_reward_card_draw_helper.gd")
const StageClearResultRewardFloatDrawHelper := preload("res://scripts/ui/stage_clear_result_reward_float_draw_helper.gd")
const StageClearResultScrollButtonDrawHelper := preload("res://scripts/ui/stage_clear_result_scroll_button_draw_helper.gd")
const StageClearResultRewardTextResolver := preload("res://scripts/ui/stage_clear_result_reward_text_resolver.gd")
const StageClearResultInteractionState := preload("res://scripts/ui/stage_clear_result_interaction_state.gd")
const StageClearResultShapeHelper := preload("res://scripts/ui/stage_clear_result_shape_helper.gd")
const StageClearResultTextLayoutHelper := preload("res://scripts/ui/stage_clear_result_text_layout_helper.gd")
const StageClearResultScrollDrawHelper := preload("res://scripts/ui/stage_clear_result_scroll_draw_helper.gd")
const StageClearResultSheetDrawHelper := preload("res://scripts/ui/stage_clear_result_sheet_draw_helper.gd")
const StageClearResultSummaryDrawHelper := preload("res://scripts/ui/stage_clear_result_summary_draw_helper.gd")
const StageClearResultCinematicPositionHelper := preload("res://scripts/ui/stage_clear_result_cinematic_position_helper.gd")
const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")
const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")
const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const STAGE1_BACKGROUND_PATH := "res://assets/sprites/stage1/result/stage1_result_background_imagegen_v1.png"
const DALJI_DEFEAT_SHEET_PATH := "res://assets/sprites/stage1/dalji/dalji_result_defeat_cutscene_live2d_clean_anchor_pingpong_98f_autosprite_v6_realesrgan_animev3_hq1152_safe.png"
const DALJI_CLICK_REACTION_SHEET_PATH := "res://assets/sprites/stage1/dalji/dalji_result_click_cry_dont_talk_live2d_remake_pingpong_98f_autosprite_v6_realesrgan_animev3_hq1152_safe.png"
const DALJI_CLICK_VOICE_PATH := "res://voice/dalzidefeat.mp3"
const STAGE2_BOSS_DEFEAT_LIVE2D_SHEET_PATH := "res://assets/sprites/stage2/stage2_alligator_general_result_defeat_live2d_pingpong_98f_autosprite_v2_realesrgan_animev3_hq1152.png"
const STAGE2_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH := "res://assets/sprites/stage2/stage2_alligator_general_result_defeat_click_reaction_98f_autosprite_v1_realesrgan_animev3_hq1152.png"
const STAGE3_BOSS_DEFEAT_LIVE2D_SHEET_PATH := "res://assets/sprites/stage3/menhera_result_defeat_live2d_pingpong_98f_autosprite_v1_realesrgan_animev3_hq1152.png"
const STAGE3_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH := "res://assets/sprites/stage3/menhera_result_defeat_click_reaction_98f_autosprite_v1_realesrgan_animev3_hq1152.png"
const SMASHER_VICTORY_SHEET_PATH := "res://assets/sprites/smasher/smasher_result_victory_base_loop_98f_autosprite_v18_magenta_v2_no_pet_realesrgan_animev3_hq1408.png"
const SMASHER_CLICK_REACTION_SHEET_PATH := "res://assets/sprites/smasher/smasher_result_victory_click_reaction_98f_autosprite_v18_magenta_v2_no_pet_realesrgan_animev3_hq1408.png"
const COMMANDO_VICTORY_SHEET_PATH := "res://assets/sprites/characters/commando/commando_result_victory_base_loop_98f_autosprite_v1_realesrgan_animev3_hq1408.png"
const COMMANDO_CLICK_REACTION_SHEET_PATH := "res://assets/sprites/characters/commando/commando_result_victory_click_reaction_98f_autosprite_v1_realesrgan_animev3_hq1408.png"
const RESULT_SCROLL_PANEL_PATH := "res://assets/sprites/result_scroll/stage_clear_cyber_scroll_imagegen_v1_alpha.png"

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
const SCROLL_REGION_TOP := 96.0
# Extended downward (was 850) so the acquired-item list has room for the
# separate active / passive / mythic bands without cramping the cards.
const SCROLL_REGION_BOTTOM := 1000.0
const SCROLL_REGION_LEFT := 340.0
const SCROLL_REGION_RIGHT := 1580.0
const SCROLL_REGION_RECT := Rect2(
	Vector2(SCROLL_REGION_LEFT, SCROLL_REGION_TOP),
	Vector2(SCROLL_REGION_RIGHT - SCROLL_REGION_LEFT, SCROLL_REGION_BOTTOM - SCROLL_REGION_TOP)
)
const SCROLL_CONTENT_MARGIN := Vector4(70.0, 90.0, 70.0, 76.0)
const SCROLL_DRAG_VIEW_MARGIN := 72.0

const PLACEHOLDER_GOLD := 1240
const RESULT_BOX_SHEET_COMMON_PATH := "res://assets/sprites/result_boxes/result_box_common_open_16f.png"
const RESULT_BOX_SHEET_MYTHIC_PATH := "res://assets/sprites/result_boxes/result_box_mythic_open_16f.png"
const RESULT_BOX_SHEET_GUARANTEED_MYTHIC_PATH := "res://assets/sprites/result_boxes/result_box_guaranteed_mythic_open_16f.png"
const RESULT_BOX_SHEET_FRAME_COUNT := 16
const RESULT_BOX_SHEET_GRID_COLS := 4
const RESULT_BOX_SHEET_GRID_ROWS := 4
const RESULT_BOX_SHEET_CELL_SIZE := Vector2(256.0, 256.0)
const RESULT_BOX_COMMON_SAFE_LAST_FRAME := 12
const RESULT_BOX_MYTHIC_SAFE_LAST_FRAME := RESULT_BOX_SHEET_FRAME_COUNT - 1
const RESULT_BOX_FRAME_ASSET_GUARD_SCALE := 0.90
const RESULT_BOX_FRAME_DRAW_SIZE := 100.0 / RESULT_BOX_FRAME_ASSET_GUARD_SCALE
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
var _fx_hosts: Array = []
var _fx_prewarm_next_index: int = 0
var _lid_open_counter: int = 0
var _starpoint_choice_gate_active: bool = false
var _starpoint_choice_gate_box_index: int = -1

static func prewarm_assets(character_type: String = "smasher", stage_id: int = 1) -> Dictionary:
	return StageClearResultAssetLoader.prewarm_result_assets(
		_result_asset_paths(character_type, stage_id),
		_normalize_player_victory_character_type(character_type),
		stage_id
	)


static func prewarm_assets_step(character_type: String = "smasher", stage_id: int = 1) -> bool:
	return StageClearResultAssetLoader.prewarm_result_assets_step(
		_result_asset_paths(character_type, stage_id),
		_normalize_player_victory_character_type(character_type),
		stage_id
	)


static func prewarm_assets_threaded_step(character_type: String = "smasher", stage_id: int = 1) -> bool:
	return StageClearResultAssetLoader.prewarm_result_assets_step(
		_result_asset_paths(character_type, stage_id),
		_normalize_player_victory_character_type(character_type),
		stage_id,
		true
	)


static func reset_prewarm_assets_for_test() -> void:
	StageClearResultAssetLoader.reset_result_prewarm_assets_for_test()


static func get_prewarm_asset_status() -> Dictionary:
	return StageClearResultAssetLoader.get_result_prewarm_asset_status()


static func _result_asset_paths(character_type: String = "smasher", stage_id: int = 1) -> Dictionary:
	var normalized_character: String = _normalize_player_victory_character_type(character_type)
	var normalized_stage_id: int = max(1, stage_id)
	var paths := {
		"background_texture": STAGE1_BACKGROUND_PATH,
		"player_victory_sheet": _get_player_victory_sheet_path_for_character(normalized_character),
		"player_victory_click_reaction_sheet": _get_player_victory_click_reaction_sheet_path_for_character(normalized_character),
		"scroll_texture": RESULT_SCROLL_PANEL_PATH,
		"result_box_sheet_common": RESULT_BOX_SHEET_COMMON_PATH,
		"result_box_sheet_mythic": RESULT_BOX_SHEET_MYTHIC_PATH,
		"result_box_sheet_guaranteed_mythic": RESULT_BOX_SHEET_GUARANTEED_MYTHIC_PATH,
	}
	if normalized_stage_id == 2:
		paths["stage2_boss_defeat_live2d_sheet"] = STAGE2_BOSS_DEFEAT_LIVE2D_SHEET_PATH
		paths["stage2_boss_defeat_click_reaction_sheet"] = STAGE2_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH
	elif normalized_stage_id == 3:
		paths["stage3_boss_defeat_live2d_sheet"] = STAGE3_BOSS_DEFEAT_LIVE2D_SHEET_PATH
		paths["stage3_boss_defeat_click_reaction_sheet"] = STAGE3_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH
	else:
		paths["dalji_defeat_sheet"] = DALJI_DEFEAT_SHEET_PATH
		paths["dalji_click_reaction_sheet"] = DALJI_CLICK_REACTION_SHEET_PATH
		paths["dalji_click_voice"] = DALJI_CLICK_VOICE_PATH
	return paths


static func _normalize_player_victory_character_type(character_type: String) -> String:
	var normalized: String = str(character_type).strip_edges().to_lower()
	if normalized == "soldier" or normalized == "commando":
		return "soldier"
	return "smasher"


static func _get_player_victory_sheet_path_for_character(character_type: String) -> String:
	if _normalize_player_victory_character_type(character_type) == "soldier":
		return COMMANDO_VICTORY_SHEET_PATH
	return SMASHER_VICTORY_SHEET_PATH


static func _get_player_victory_click_reaction_sheet_path_for_character(character_type: String) -> String:
	if _normalize_player_victory_character_type(character_type) == "soldier":
		return COMMANDO_CLICK_REACTION_SHEET_PATH
	return SMASHER_CLICK_REACTION_SHEET_PATH


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
	selected_character_type = _normalize_player_victory_character_type(str(data.get("selected_character_type", selected_character_type)))
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
	_fx_prewarm_next_index = 0
	_lid_open_counter = 0
	set_starpoint_choice_gate_active(false, -1)
	_deactivate_all_fx_hosts()
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
	_tear_down_fx_hosts()


func update_result_scene(delta: float) -> void:
	var safe_delta: float = max(0.0, delta)
	timer += safe_delta
	_dalji_base_timer += safe_delta
	if StageClearResultClickReactionState.is_reaction_active(_dalji_click_reaction_timer, DALJI_CLICK_TOTAL_DURATION):
		_dalji_click_reaction_timer = min(DALJI_CLICK_TOTAL_DURATION, _dalji_click_reaction_timer + safe_delta)
	if StageClearResultClickReactionState.is_reaction_active(
		_player_victory_click_reaction_timer,
		PLAYER_VICTORY_CLICK_TOTAL_DURATION
	):
		_player_victory_click_reaction_timer = min(
			PLAYER_VICTORY_CLICK_TOTAL_DURATION,
			_player_victory_click_reaction_timer + safe_delta
		)
	if StageClearResultClickReactionState.is_reaction_active(
		_stage2_boss_defeat_click_reaction_timer,
		STAGE2_BOSS_DEFEAT_CLICK_TOTAL_DURATION
	):
		_stage2_boss_defeat_click_reaction_timer = min(
			STAGE2_BOSS_DEFEAT_CLICK_TOTAL_DURATION,
			_stage2_boss_defeat_click_reaction_timer + safe_delta
		)
	if StageClearResultClickReactionState.is_reaction_active(
		_stage3_boss_defeat_click_reaction_timer,
		STAGE3_BOSS_DEFEAT_CLICK_TOTAL_DURATION
	):
		_stage3_boss_defeat_click_reaction_timer = min(
			STAGE3_BOSS_DEFEAT_CLICK_TOTAL_DURATION,
			_stage3_boss_defeat_click_reaction_timer + safe_delta
		)
	_dalji_dialogue_timer = max(0.0, _dalji_dialogue_timer - safe_delta)
	_update_boxes(safe_delta)
	_update_scroll(safe_delta)
	_sync_viewport_size()
	_prewarm_fx_hosts_step()
	_sync_fx_hosts()
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
	var scroll_rect: Rect2 = _get_scroll_full_rect(layout_scale)
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
	var base_rect: Rect2 = _get_scroll_base_rect(layout_scale)
	var candidate_offset: Vector2 = mouse_position - _scroll_drag_grab_offset - base_rect.position
	_scroll_position_offset = _clamp_scroll_offset(candidate_offset, layout_scale, view_size)
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
			_get_scroll_full_rect(layout_scale),
			layout_scale,
			SCROLL_CONTENT_MARGIN
		),
		layout_scale
	)
	_next_stage_button_rect = button_layout.get("next_stage_rect", Rect2())
	_exit_button_rect = button_layout.get("exit_rect", Rect2())


func _get_scroll_base_rect(draw_scale: float) -> Rect2:
	return StageClearResultScrollState.get_base_rect(draw_scale, SCROLL_REGION_RECT)


func _get_scroll_full_rect(draw_scale: float) -> Rect2:
	return StageClearResultScrollState.get_full_rect(draw_scale, _scroll_position_offset, SCROLL_REGION_RECT)


func _clamp_scroll_offset(candidate_offset: Vector2, draw_scale: float, view_size: Vector2) -> Vector2:
	return StageClearResultScrollState.clamp_offset(
		candidate_offset,
		draw_scale,
		view_size,
		SCROLL_DRAG_VIEW_MARGIN,
		SCROLL_REGION_RECT
	)


func _get_current_view_size() -> Vector2:
	var view_size: Vector2 = size
	if view_size == Vector2.ZERO:
		view_size = _get_view_size()
	return view_size


func get_interaction_status() -> Dictionary:
	var view_size: Vector2 = size
	if view_size == Vector2.ZERO:
		view_size = _get_view_size()
	@warning_ignore("shadowed_variable_base_class")
	var scale: float = _get_layout_scale(view_size)
	var box_counts: Dictionary = StageClearResultInteractionState.get_box_state_counts(_boxes)
	var opened_count: int = int(box_counts.get("opened_count", 0))
	var opening_count: int = int(box_counts.get("opening_count", 0))
	var dalji_reaction_state: Dictionary = _dalji_reaction_state()
	var player_victory_reaction_state: Dictionary = _player_victory_reaction_state()
	var stage2_boss_reaction_state: Dictionary = _stage2_boss_defeat_reaction_state()
	var stage3_boss_reaction_state: Dictionary = _stage3_boss_defeat_reaction_state()
	var reward_summary_state: Dictionary = StageClearResultSummaryBuilder.build_result_summary_state(
		stage_reward_snapshot,
		_boxes,
		RESULT_REWARD_SOURCE_STAGE,
		RESULT_REWARD_SOURCE_BOX,
		RESULT_REWARD_SOURCE_LABELS
	)
	return {
		"dalji_click_reaction_active": bool(dalji_reaction_state.get("reaction_active", false)),
		"dalji_click_return_blend_active": bool(dalji_reaction_state.get("return_blend_active", false)),
		"dalji_click_reaction_timer": _dalji_click_reaction_timer,
		"dalji_click_reaction_duration": DALJI_CLICK_REACTION_DURATION,
		"dalji_click_total_duration": DALJI_CLICK_TOTAL_DURATION,
		"dalji_click_transition_base_frame": _dalji_click_transition_base_frame,
		"dalji_base_frame": int(dalji_reaction_state.get("base_frame", 0)),
		"dalji_base_timer": _dalji_base_timer,
		"dalji_reaction_alpha": float(dalji_reaction_state.get("reaction_alpha", 0.0)),
		"dalji_dialogue_timer": _dalji_dialogue_timer,
		"dalji_click_rect": StageClearResultLayoutHelper.get_dalji_draw_rect(view_size, scale),
		"dalji_dialogue": DALJI_CLICK_DIALOGUE,
		"dalji_click_voice_path": DALJI_CLICK_VOICE_PATH,
		"dalji_click_voice_loaded": _dalji_click_voice_stream != null,
		"dalji_click_voice_player_ready": _dalji_click_voice_player != null,
		"dalji_click_voice_playing": _dalji_click_voice_player != null and _dalji_click_voice_player.playing,
		"selected_character_type": selected_character_type,
		"player_victory_sheet_path": _get_player_victory_sheet_path_for_character(selected_character_type),
		"player_victory_click_reaction_sheet_path": _get_player_victory_click_reaction_sheet_path_for_character(selected_character_type),
		"stage2_boss_defeat_live2d_sheet_path": STAGE2_BOSS_DEFEAT_LIVE2D_SHEET_PATH,
		"stage2_boss_defeat_live2d_sheet_loaded": _stage2_boss_defeat_live2d_sheet != null,
		"stage2_boss_defeat_click_reaction_sheet_path": STAGE2_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH,
		"stage2_boss_defeat_click_reaction_sheet_loaded": _stage2_boss_defeat_click_reaction_sheet != null,
		"stage2_boss_defeat_live2d_active": current_stage == 2,
		"stage2_boss_defeat_live2d_frame_count": STAGE2_BOSS_DEFEAT_LIVE2D_FRAME_COUNT,
		"stage2_boss_defeat_live2d_grid_cols": STAGE2_BOSS_DEFEAT_LIVE2D_GRID_COLS,
		"stage2_boss_defeat_live2d_cell_size": STAGE2_BOSS_DEFEAT_LIVE2D_CELL_SIZE,
		"stage2_boss_defeat_live2d_base_frame": int(stage2_boss_reaction_state.get("base_frame", 0)),
		"stage2_boss_defeat_live2d_draw_rect": StageClearResultLayoutHelper.get_stage2_boss_result_draw_rect(view_size, scale),
		"stage2_boss_defeat_click_rect": StageClearResultLayoutHelper.get_stage2_boss_result_draw_rect(view_size, scale),
		"stage2_boss_defeat_click_reaction_active": bool(stage2_boss_reaction_state.get("reaction_active", false)),
		"stage2_boss_defeat_click_return_blend_active": bool(stage2_boss_reaction_state.get("return_blend_active", false)),
		"stage2_boss_defeat_click_reaction_timer": _stage2_boss_defeat_click_reaction_timer,
		"stage2_boss_defeat_click_reaction_duration": STAGE2_BOSS_DEFEAT_CLICK_REACTION_DURATION,
		"stage2_boss_defeat_click_total_duration": STAGE2_BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		"stage2_boss_defeat_click_transition_base_frame": _stage2_boss_defeat_click_transition_base_frame,
		"stage2_boss_defeat_reaction_alpha": float(stage2_boss_reaction_state.get("reaction_alpha", 0.0)),
		"stage3_boss_defeat_live2d_sheet_path": STAGE3_BOSS_DEFEAT_LIVE2D_SHEET_PATH,
		"stage3_boss_defeat_live2d_sheet_loaded": _stage3_boss_defeat_live2d_sheet != null,
		"stage3_boss_defeat_click_reaction_sheet_path": STAGE3_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH,
		"stage3_boss_defeat_click_reaction_sheet_loaded": _stage3_boss_defeat_click_reaction_sheet != null,
		"stage3_boss_defeat_live2d_active": current_stage == 3,
		"stage3_boss_defeat_live2d_frame_count": STAGE3_BOSS_DEFEAT_LIVE2D_FRAME_COUNT,
		"stage3_boss_defeat_live2d_grid_cols": STAGE3_BOSS_DEFEAT_LIVE2D_GRID_COLS,
		"stage3_boss_defeat_live2d_cell_size": STAGE3_BOSS_DEFEAT_LIVE2D_CELL_SIZE,
		"stage3_boss_defeat_live2d_base_frame": int(stage3_boss_reaction_state.get("base_frame", 0)),
		"stage3_boss_defeat_live2d_draw_rect": StageClearResultLayoutHelper.get_stage3_boss_result_draw_rect(view_size, scale),
		"stage3_boss_defeat_click_rect": StageClearResultLayoutHelper.get_stage3_boss_result_draw_rect(view_size, scale),
		"stage3_boss_defeat_click_reaction_active": bool(stage3_boss_reaction_state.get("reaction_active", false)),
		"stage3_boss_defeat_click_return_blend_active": bool(stage3_boss_reaction_state.get("return_blend_active", false)),
		"stage3_boss_defeat_click_reaction_timer": _stage3_boss_defeat_click_reaction_timer,
		"stage3_boss_defeat_click_reaction_duration": STAGE3_BOSS_DEFEAT_CLICK_REACTION_DURATION,
		"stage3_boss_defeat_click_total_duration": STAGE3_BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		"stage3_boss_defeat_click_transition_base_frame": _stage3_boss_defeat_click_transition_base_frame,
		"stage3_boss_defeat_reaction_alpha": float(stage3_boss_reaction_state.get("reaction_alpha", 0.0)),
		"player_victory_sheet_loaded": _player_victory_sheet != null,
		"player_victory_click_reaction_sheet_loaded": _player_victory_click_reaction_sheet != null,
		"player_victory_frame_count": PLAYER_VICTORY_FRAME_COUNT,
		"player_victory_grid_cols": PLAYER_VICTORY_GRID_COLS,
		"player_victory_cell_size": PLAYER_VICTORY_CELL_SIZE,
		"player_victory_base_frame": int(player_victory_reaction_state.get("base_frame", 0)),
		"player_victory_click_reaction_active": bool(player_victory_reaction_state.get("reaction_active", false)),
		"player_victory_click_return_blend_active": bool(player_victory_reaction_state.get("return_blend_active", false)),
		"player_victory_click_reaction_timer": _player_victory_click_reaction_timer,
		"player_victory_click_reaction_duration": PLAYER_VICTORY_CLICK_REACTION_DURATION,
		"player_victory_click_total_duration": PLAYER_VICTORY_CLICK_TOTAL_DURATION,
		"player_victory_click_transition_base_frame": _player_victory_click_transition_base_frame,
		"player_victory_reaction_alpha": float(player_victory_reaction_state.get("reaction_alpha", 0.0)),
		"player_victory_draw_rect": StageClearResultLayoutHelper.get_player_victory_actor_rect(view_size, scale),
		"player_victory_click_rect": StageClearResultLayoutHelper.get_player_victory_click_rect(
			view_size,
			scale,
			PLAYER_VICTORY_CELL_SIZE
		),
		"box_count": _boxes.size(),
		"opened_count": opened_count,
		"opening_count": opening_count,
		"item_reward_count": int(reward_summary_state.get("item_reward_count", 0)),
		"perk_reward_count": int(reward_summary_state.get("perk_reward_count", 0)),
		"stage_active_item_count": int(reward_summary_state.get("stage_active_item_count", 0)),
		"stage_passive_item_count": int(reward_summary_state.get("stage_passive_item_count", 0)),
		"stage_perk_count": int(reward_summary_state.get("stage_perk_count", 0)),
		"item_reward_source_counts": reward_summary_state.get("item_reward_source_counts", {}),
		"perk_reward_source_counts": reward_summary_state.get("perk_reward_source_counts", {}),
		"visible_reward_source_counts": reward_summary_state.get("visible_reward_source_counts", {}),
		"box_display_labels": StageClearResultBoxData.get_box_display_labels(_boxes),
		"perk_info": _build_perk_info_summary(reward_summary_state),
		"starpoint_total": int(reward_summary_state.get("starpoint_total", 0)),
		"hovered_box_index": _hovered_box_index,
		"all_boxes_opened": _boxes.size() > 0 and opened_count == _boxes.size(),
		"scroll_phase": _scroll_phase,
		"scroll_unfurl_progress": StageClearResultScrollState.get_unfurl_progress(_scroll_phase, _scroll_timer, SCROLL_UNFURL_DURATION),
		"scroll_visible": _scroll_phase == "unfurling" or _scroll_phase == "visible",
		"scroll_texture_loaded": _scroll_texture != null,
		"scroll_rect": _get_scroll_full_rect(scale),
		"scroll_position_offset": _scroll_position_offset,
		"scroll_dragging": _scroll_dragging,
		"next_stage_button_rect": _next_stage_button_rect,
		"exit_button_rect": _exit_button_rect,
		"buttons_clickable": _scroll_phase == "visible",
		"hovered_button": _hovered_button,
		"scene_timer": timer,
		"exit_callback_bound": exit_to_menu_callback.is_valid(),
		"starpoint_choice_gate_active": _starpoint_choice_gate_active,
		"starpoint_choice_gate_box_index": _starpoint_choice_gate_box_index,
		"runtime_perk_choice_active": _is_runtime_perk_choice_active(),
		"treasure_hunt_effect_active": _is_treasure_hunt_effect_active(),
		"box_open_audio_ready": _game_audio != null and _game_audio.has_method("play_result_box_open"),
	}


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
	var font: Font = _get_ui_font(scale)

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
	if box_index < 0 or box_index >= _boxes.size() or perk_reward.is_empty():
		return
	var box: Dictionary = _boxes[box_index] if _boxes[box_index] is Dictionary else {}
	var reward: Dictionary = box.get("reward", {}) if box.get("reward", {}) is Dictionary else {}
	if reward.is_empty() or str(reward.get("type", "")) != "starpoint":
		return
	var resolved_value: Variant = reward.get("resolved_perk_rewards", [])
	var resolved: Array = resolved_value if resolved_value is Array else []
	var reward_copy: Dictionary = perk_reward.duplicate(true)
	reward_copy["source"] = "box_starpoint_choice"
	resolved.append(reward_copy)
	reward["resolved_perk_rewards"] = resolved
	reward["resolved_perk_count"] = resolved.size()
	box["reward"] = reward
	_boxes[box_index] = box
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


func _get_result_box_sheet_texture(kind: String) -> Texture2D:
	if StageClearResultBoxData.is_guaranteed_mythic_box_kind(kind):
		return _result_box_sheet_guaranteed_mythic
	if StageClearResultBoxData.is_advanced_box_kind(kind):
		return _result_box_sheet_mythic
	return _result_box_sheet_common


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
	var global_alpha: float = StageClearResultScrollState.get_box_global_alpha(_scroll_phase, _scroll_timer, SCROLL_UNFURL_DURATION)
	if global_alpha <= 0.02:
		return

	var kind: String = str(box.get("kind", StageClearResultBoxData.BOX_KIND_NORMAL))
	var is_mythic: bool = StageClearResultBoxData.is_mythic_visual_box_kind(kind)
	var state: String = str(box.get("state", "idle"))
	var open_progress: float = float(box.get("open_progress", 0.0))

	var rotation_base: float = float(box.get("rotation_base", 0.0))
	var rotation_jitter: float = float(box.get("rotation_jitter", 0.05))
	var phase: float = float(box.get("phase", 0.0))
	var box_rotation: float = rotation_base + sin(timer * 0.9 + phase * 0.7) * rotation_jitter

	var shake_offset := Vector2.ZERO
	if state == "opening" and open_progress < 0.55:
		var shake_intensity: float = 1.0 - open_progress / 0.55
		var shake_t: float = timer * 30.0
		shake_offset = Vector2(
			sin(shake_t) * BOX_OPENING_SHAKE_AMPLITUDE * shake_intensity * scale,
			cos(shake_t * 1.3) * 1.2 * shake_intensity * scale
		)

	var draw_center: Vector2 = StageClearResultLayoutHelper.get_box_draw_center(
		box,
		scale,
		timer,
		BOX_FLOAT_AMPLITUDE,
		BOX_FLOAT_SPEED
	) + shake_offset

	var hover_active: bool = hovered and state == "idle"
	var hover_pulse: float = 0.0
	if hover_active:
		hover_pulse = sin(timer * 4.0 + phase) * 0.5 + 0.5

	var grow: float = 1.0
	if hover_active:
		grow = BOX_HOVER_GROW + hover_pulse * 0.022

	var body_hx: float = BOX_BASE_SIZE.x * scale * grow * 0.5
	var body_hy: float = BOX_BASE_SIZE.y * scale * grow * 0.5

	var frame_draw_size: float = RESULT_BOX_FRAME_DRAW_SIZE * scale * grow
	var hx: float = frame_draw_size * 0.5
	var hy: float = frame_draw_size * 0.5

	StageClearResultShapeHelper.draw_filled_ellipse(
		self,
		Vector2(draw_center.x, draw_center.y + body_hy + BOX_SHADOW_OFFSET_Y * scale),
		body_hx * 0.95,
		body_hy * 0.20,
		Color(0.0, 0.0, 0.0, 0.40 * global_alpha),
		24
	)

	if hover_active:
		StageClearResultShapeHelper.draw_box_hover_glow(self, draw_center, body_hx, body_hy, scale, is_mythic, global_alpha, hover_pulse)

	var frame_index: int = StageClearResultLayoutHelper.get_result_box_frame_index(
		state,
		open_progress,
		is_mythic,
		RESULT_BOX_SHEET_FRAME_COUNT,
		RESULT_BOX_COMMON_SAFE_LAST_FRAME,
		RESULT_BOX_MYTHIC_SAFE_LAST_FRAME
	)

	var texture: Texture2D = _get_result_box_sheet_texture(kind)
	if not StageClearResultBoxDrawHelper.draw_result_box_sheet_frame(
		self,
		texture,
		draw_center,
		frame_index,
		RESULT_BOX_SHEET_GRID_COLS,
		RESULT_BOX_SHEET_CELL_SIZE,
		frame_draw_size,
		box_rotation,
		global_alpha
	):
		StageClearResultBoxDrawHelper.draw_result_box_fallback(self, draw_center, hx, hy, box_rotation, scale, is_mythic, global_alpha, state, open_progress)

	if hover_active:
		StageClearResultShapeHelper.draw_box_hover_sparkles(self, draw_center, body_hx, body_hy, scale, is_mythic, global_alpha, phase, timer)

	if state == "opened":
		StageClearResultRewardFloatDrawHelper.draw_reward_label(
			self,
			box,
			draw_center,
			body_hy,
			scale,
			global_alpha,
			timer,
			BOX_REWARD_HOVER_OFFSET,
			_reward_icon_cache
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
	if index < 0 or index >= _boxes.size():
		return
	var box: Dictionary = _boxes[index]
	if str(box.get("state", "idle")) != "idle":
		return
	box["state"] = "opening"
	box["open_progress"] = 0.0
	box["reward_emerge"] = 0.0
	box["reward"] = _roll_reward(str(box.get("roll_kind", box.get("kind", StageClearResultBoxData.BOX_KIND_NORMAL))))
	box["lid_open_fired"] = false
	box["lid_open_id"] = -1
	_boxes[index] = box
	_play_result_box_open_audio()
	if _hovered_box_index == index:
		_hovered_box_index = -1
	queue_redraw()


func _play_result_box_open_audio() -> void:
	if _game_audio != null and _game_audio.has_method("play_result_box_open"):
		_game_audio.play_result_box_open()


func _roll_reward(kind: String) -> Dictionary:
	if reward_roll_callback.is_valid():
		var rolled_value: Variant = reward_roll_callback.call(kind)
		if rolled_value is Dictionary:
			var rolled: Dictionary = rolled_value
			if not rolled.is_empty():
				return rolled
	if StageClearResultBoxData.is_guaranteed_mythic_box_kind(kind) or StageClearResultBoxData.is_advanced_box_kind(kind):
		return {"type": "mythic", "label": LanguageSettings.translate_text("신화 아이템")}
	var roll: float = randf()
	if roll < 0.60:
		return {"type": "active", "label": LanguageSettings.translate_text("액티브 아이템")}
	if roll < 0.80:
		return {"type": "passive", "label": LanguageSettings.translate_text("패시브 아이템")}
	var amount: int = (
		FALLBACK_STARPOINT_SINGLE_AMOUNT
		if randf() < FALLBACK_STARPOINT_SINGLE_CHANCE
		else FALLBACK_STARPOINT_DOUBLE_AMOUNT
	)
	return {"type": "starpoint", "label": "★ %d" % amount, "amount": amount}


func _update_boxes(delta: float) -> void:
	if _boxes.is_empty() or delta <= 0.0:
		return
	for i in range(_boxes.size()):
		var box: Dictionary = _boxes[i] if _boxes[i] is Dictionary else {}
		var state: String = str(box.get("state", "idle"))
		if state == "opening":
			var dur: float = max(0.0001, BOX_OPEN_DURATION)
			var p: float = float(box.get("open_progress", 0.0)) + delta / dur
			if p >= 1.0:
				p = 1.0
				box["state"] = "opened"
				box["reward_emerge"] = 0.0
				_try_grant_immediate_reward(i, box)
			box["open_progress"] = p
			if not bool(box.get("lid_open_fired", false)) and p >= BOX_LID_OPEN_PROGRESS:
				_lid_open_counter += 1
				box["lid_open_fired"] = true
				box["lid_open_id"] = _lid_open_counter
			_boxes[i] = box
		elif state == "opened":
			var emerge_dur: float = max(0.0001, BOX_REWARD_EMERGE_DURATION)
			var ep: float = float(box.get("reward_emerge", 0.0)) + delta / emerge_dur
			box["reward_emerge"] = clamp(ep, 0.0, 1.0)
			_boxes[i] = box


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


func _sync_fx_hosts() -> void:
	if _boxes.is_empty():
		_deactivate_all_fx_hosts()
		return
	@warning_ignore("shadowed_variable_base_class")
	var scale: float = _get_layout_scale(size)
	var global_alpha: float = StageClearResultScrollState.get_box_global_alpha(_scroll_phase, _scroll_timer, SCROLL_UNFURL_DURATION)
	for i in range(_boxes.size()):
		var box: Dictionary = _boxes[i] if _boxes[i] is Dictionary else {}
		var state: String = str(box.get("state", "idle"))
		if state != "opening" and state != "opened":
			_set_fx_host_active(i, false)
			continue
		var host: Node2D = _ensure_fx_host(i)
		if host == null:
			continue
		var draw_center: Vector2 = StageClearResultLayoutHelper.get_box_draw_center(
			box,
			scale,
			timer,
			BOX_FLOAT_AMPLITUDE,
			BOX_FLOAT_SPEED
		)
		var open_progress: float = float(box.get("open_progress", 0.0))
		var reward_emerge: float = float(box.get("reward_emerge", 0.0))
		var is_mythic: bool = StageClearResultBoxData.is_mythic_visual_box_kind(str(box.get("kind", StageClearResultBoxData.BOX_KIND_NORMAL)))
		var lid_open_id: int = int(box.get("lid_open_id", -1))
		var fx_state := {
			"position": draw_center,
			"scale": scale,
			"phase": state,
			"open_progress": open_progress,
			"reward_emerge": reward_emerge,
			"alpha": global_alpha,
			"is_mythic": is_mythic,
			"lid_open_id": lid_open_id,
		}
		host.sync_state(fx_state, global_alpha > 0.02)


func _prewarm_fx_hosts_step() -> void:
	if _fx_prewarm_next_index < 0 or _fx_prewarm_next_index >= _boxes.size():
		return
	var host: Node2D = _ensure_fx_host(_fx_prewarm_next_index)
	if host != null:
		_set_fx_host_active(_fx_prewarm_next_index, false)
	_fx_prewarm_next_index += 1


func _ensure_fx_host(index: int) -> Node2D:
	if index < 0:
		return null
	while _fx_hosts.size() <= index:
		_fx_hosts.append(null)
	var existing: Variant = _fx_hosts[index]
	if existing is Node2D and is_instance_valid(existing):
		return existing
	var host: Node2D = ResultBoxOpenFxHost.new()
	host.name = "ResultBoxOpenFxHost_%d" % index
	host.visible = false
	add_child(host)
	_fx_hosts[index] = host
	return host


func _set_fx_host_active(index: int, active: bool) -> void:
	if index < 0 or index >= _fx_hosts.size():
		return
	var host: Variant = _fx_hosts[index]
	if host == null or not (host is Node) or not is_instance_valid(host):
		return
	if host.has_method("set_active"):
		host.set_active(active)


func _deactivate_all_fx_hosts() -> void:
	for i in range(_fx_hosts.size()):
		_set_fx_host_active(i, false)


func _tear_down_fx_hosts() -> void:
	for host_variant in _fx_hosts:
		if host_variant is Node and is_instance_valid(host_variant):
			if host_variant.has_method("tear_down"):
				host_variant.tear_down(true)
			else:
				host_variant.queue_free()
	_fx_hosts.clear()
	_fx_prewarm_next_index = 0


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


func _build_perk_info_summary(reward_summary_state: Dictionary) -> Dictionary:
	var perks_value: Variant = reward_summary_state.get("perk_rewards", [])
	var perks: Array = perks_value if perks_value is Array else []
	var first_perk_title: String = ""
	var first_perk_detail: String = ""
	if not perks.is_empty():
		var first_perk: Dictionary = perks[0] if perks[0] is Dictionary else {}
		var first_perk_text_state: Dictionary = StageClearResultRewardTextResolver.get_reward_text_state(
			first_perk,
			_perk_catalog,
			StageClearResultSummaryBuilder.get_reward_perk_id(first_perk),
			StageClearResultSummaryBuilder.is_perk_reward(first_perk),
			StageClearResultRewardTextResolver.get_reward_type_fallback_label(str(first_perk.get("type", ""))),
			REWARD_DETAIL_FALLBACK_TEXT,
			REWARD_STARPOINT_TITLE_PREFIX
		)
		first_perk_title = str(first_perk_text_state.get("title", ""))
		first_perk_detail = str(first_perk_text_state.get("detail", ""))
	return StageClearResultSummaryBuilder.build_perk_info_summary(
		perks,
		int(reward_summary_state.get("starpoint_total", 0)),
		first_perk_title,
		first_perk_detail
	)


@warning_ignore("shadowed_variable_base_class")
func _draw_scroll(view_size: Vector2, scale: float, font: Font) -> void:
	if _scroll_phase == "hidden":
		return
	_scroll_position_offset = _clamp_scroll_offset(_scroll_position_offset, scale, view_size)
	var unfurl: float = StageClearResultScrollState.get_unfurl_progress(_scroll_phase, _scroll_timer, SCROLL_UNFURL_DURATION)
	if unfurl <= 0.0:
		return
	_draw_cyber_scroll(unfurl, scale, font)


@warning_ignore("shadowed_variable_base_class")
func _draw_cyber_scroll(unfurl: float, scale: float, font: Font) -> void:
	var full_rect: Rect2 = _get_scroll_full_rect(scale)
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
	if alpha <= 0.02:
		return
	var accent := Color(0.05, 0.54, 0.68, alpha)
	var muted := Color(0.20, 0.36, 0.42, alpha * 0.86)

	var header_rect := Rect2(rect.position, Vector2(rect.size.x, 58.0 * scale))
	StageClearResultTextLayoutHelper.draw_centered_text(self, font, LanguageSettings.format_stage_result_label(current_stage), header_rect, int(round(42.0 * scale)), accent)
	var divider_y: float = rect.position.y + 68.0 * scale
	draw_line(
		Vector2(rect.position.x + 34.0 * scale, divider_y),
		Vector2(rect.position.x + rect.size.x - 34.0 * scale, divider_y),
		Color(0.03, 0.82, 0.96, alpha * 0.46),
		max(1.0, 1.4 * scale)
	)

	var reward_summary_state: Dictionary = StageClearResultSummaryBuilder.build_result_summary_state(
		stage_reward_snapshot,
		_boxes,
		RESULT_REWARD_SOURCE_STAGE,
		RESULT_REWARD_SOURCE_BOX,
		RESULT_REWARD_SOURCE_LABELS
	)

	var strip_rect := Rect2(
		rect.position + Vector2(34.0 * scale, 86.0 * scale),
		Vector2(rect.size.x - 68.0 * scale, 80.0 * scale)
	)
	var display_gold: int = StageClearResultSummaryBuilder.resolve_display_gold(_runtime_perk_state, PLACEHOLDER_GOLD)
	var rating: int = StageClearResultSummaryBuilder.calculate_score_rating(player_score, boss_score)
	StageClearResultSummaryDrawHelper.draw_result_summary_strip(
		self,
		font,
		strip_rect,
		scale,
		alpha,
		display_gold,
		player_score,
		boss_score,
		rating,
		LanguageSettings.translate_text("획득 골드"),
		LanguageSettings.translate_text("최종 스코어"),
		LanguageSettings.translate_text("평가")
	)

	var perks_value: Variant = reward_summary_state.get("perk_rewards", [])
	var item_rewards_value: Variant = reward_summary_state.get("item_rewards", [])
	var perks: Array = perks_value if perks_value is Array else []
	var item_rewards: Array = item_rewards_value if item_rewards_value is Array else []

	# Split acquired items by type so the scroll lists active / passive / mythic
	# under their own labelled bands instead of one mixed "획득 아이템" grid.
	var active_items: Array = []
	var passive_items: Array = []
	var mythic_items: Array = []
	for item_value in item_rewards:
		if not (item_value is Dictionary):
			continue
		var item_dict: Dictionary = item_value
		match str(item_dict.get("type", "")):
			"active":
				active_items.append(item_dict)
			"mythic":
				mythic_items.append(item_dict)
			_:
				passive_items.append(item_dict)

	var sections: Array = []
	if not perks.is_empty():
		sections.append({"title": LanguageSettings.translate_text("획득 퍽"), "rewards": perks})
	if not active_items.is_empty():
		sections.append({"title": LanguageSettings.translate_text("액티브 아이템"), "rewards": active_items})
	if not passive_items.is_empty():
		sections.append({"title": LanguageSettings.translate_text("패시브 아이템"), "rewards": passive_items})
	if not mythic_items.is_empty():
		sections.append({"title": LanguageSettings.translate_text("신화 아이템"), "rewards": mythic_items})

	var section_top: float = rect.position.y + 188.0 * scale
	var button_top: float = rect.position.y + rect.size.y - 90.0 * scale
	var section_bottom: float = button_top - 22.0 * scale
	var body_rect := Rect2(
		Vector2(rect.position.x + 34.0 * scale, section_top),
		Vector2(rect.size.x - 68.0 * scale, max(150.0 * scale, section_bottom - section_top))
	)
	StageClearResultScrollDrawHelper.draw_section_group_panel(self, body_rect, scale, alpha)
	if sections.is_empty():
		StageClearResultTextLayoutHelper.draw_centered_text(self, font, LanguageSettings.translate_text("획득 보상 없음"), body_rect, int(round(22.0 * scale)), muted)
	else:
		var card_draw_context := {
			"timer": timer,
			"perk_catalog": _perk_catalog,
			"perk_icon_renderer": _perk_icon_renderer,
			"reward_icon_cache": _reward_icon_cache,
			"result_reward_source_stage": RESULT_REWARD_SOURCE_STAGE,
			"result_reward_source_box": RESULT_REWARD_SOURCE_BOX,
			"result_reward_source_labels": RESULT_REWARD_SOURCE_LABELS,
			"reward_detail_fallback_text": REWARD_DETAIL_FALLBACK_TEXT,
			"reward_starpoint_title_prefix": REWARD_STARPOINT_TITLE_PREFIX,
		}
		StageClearResultRewardCardDrawHelper.draw_reward_section_stack(self, font, sections, body_rect, scale, alpha, Callable(), card_draw_context)

	var button_layout: Dictionary = StageClearResultScrollButtonDrawHelper.draw_scroll_buttons(
		self,
		font,
		rect,
		scale,
		alpha,
		_scroll_phase,
		_hovered_button,
		LanguageSettings.translate_text("다음 스테이지"),
		LanguageSettings.translate_text("나가기")
	)
	_next_stage_button_rect = button_layout.get("next_stage_rect", Rect2())
	_exit_button_rect = button_layout.get("exit_rect", Rect2())


# The project fallback font packs Korean syllable blocks tightly, so at the
# small label sizes used on this scroll (header / metric-tile / chip text) the
# glyphs read as touching/overlapping. Wrap it in a FontVariation that adds a
# small per-glyph spacing (scaled with the layout) to separate the syllables.
# Rebuilt only when the base font or spacing actually changes.
var _ui_font: FontVariation = null
var _ui_font_base: Font = null
var _ui_font_spacing: int = -1


@warning_ignore("shadowed_variable_base_class")
func _get_ui_font(draw_scale: float) -> Font:
	var base: Font = ThemeDB.fallback_font
	if base == null:
		return base
	var spacing: int = max(1, int(round(2.0 * draw_scale)))
	if _ui_font == null or _ui_font_base != base or _ui_font_spacing != spacing:
		var variation := FontVariation.new()
		variation.base_font = base
		variation.set_spacing(TextServer.SPACING_GLYPH, spacing)
		_ui_font = variation
		_ui_font_base = base
		_ui_font_spacing = spacing
	return _ui_font


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
	if not click_rect.has_point(mouse_position):
		return false
	if StageClearResultClickReactionState.is_reaction_active(
		_player_victory_click_reaction_timer,
		PLAYER_VICTORY_CLICK_TOTAL_DURATION
	):
		queue_redraw()
		return true
	_player_victory_click_transition_base_frame = StageClearResultClickReactionState.get_base_frame(
		timer,
		PLAYER_VICTORY_FRAME_INTERVAL,
		PLAYER_VICTORY_FRAME_COUNT
	)
	_player_victory_click_reaction_timer = 0.0
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
	if not click_rect.has_point(mouse_position):
		return false
	if StageClearResultClickReactionState.is_reaction_active(_dalji_click_reaction_timer, DALJI_CLICK_TOTAL_DURATION):
		_dalji_dialogue_timer = DALJI_CLICK_DIALOGUE_DURATION
		_play_dalji_click_voice()
		queue_redraw()
		return true
	_dalji_click_transition_base_frame = StageClearResultClickReactionState.get_base_frame(
		_dalji_base_timer,
		DALJI_FRAME_INTERVAL,
		DALJI_FRAME_COUNT
	)
	_dalji_click_reaction_timer = 0.0
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
	if not click_rect.has_point(mouse_position):
		return false
	if StageClearResultClickReactionState.is_reaction_active(
		_stage2_boss_defeat_click_reaction_timer,
		STAGE2_BOSS_DEFEAT_CLICK_TOTAL_DURATION
	):
		queue_redraw()
		return true
	_stage2_boss_defeat_click_transition_base_frame = StageClearResultClickReactionState.get_base_frame(
		timer,
		STAGE2_BOSS_DEFEAT_LIVE2D_FRAME_INTERVAL,
		STAGE2_BOSS_DEFEAT_LIVE2D_FRAME_COUNT
	)
	_stage2_boss_defeat_click_reaction_timer = 0.0
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
	if not click_rect.has_point(mouse_position):
		return false
	if StageClearResultClickReactionState.is_reaction_active(
		_stage3_boss_defeat_click_reaction_timer,
		STAGE3_BOSS_DEFEAT_CLICK_TOTAL_DURATION
	):
		queue_redraw()
		return true
	_stage3_boss_defeat_click_transition_base_frame = StageClearResultClickReactionState.get_base_frame(
		timer,
		STAGE3_BOSS_DEFEAT_LIVE2D_FRAME_INTERVAL,
		STAGE3_BOSS_DEFEAT_LIVE2D_FRAME_COUNT
	)
	_stage3_boss_defeat_click_reaction_timer = 0.0
	queue_redraw()
	return true


func _play_dalji_click_voice() -> void:
	_load_audio()
	if _dalji_click_voice_stream == null:
		return
	if _dalji_click_voice_player == null:
		_dalji_click_voice_player = AudioStreamPlayer.new()
		_dalji_click_voice_player.name = "DaljiClickCryVoice"
		add_child(_dalji_click_voice_player)
	_dalji_click_voice_player.stream = _dalji_click_voice_stream
	_dalji_click_voice_player.volume_db = DALJI_CLICK_VOICE_VOLUME_DB
	_dalji_click_voice_player.stop()
	if not is_inside_tree() or not _dalji_click_voice_player.is_inside_tree():
		call_deferred("_play_dalji_click_voice_deferred")
		return
	_dalji_click_voice_player.play()


func _play_dalji_click_voice_deferred() -> void:
	if _dalji_click_voice_player == null or _dalji_click_voice_player.stream == null:
		return
	if not _dalji_click_voice_player.is_inside_tree():
		return
	_dalji_click_voice_player.stop()
	_dalji_click_voice_player.play()


func _stop_dalji_click_voice() -> void:
	if _dalji_click_voice_player != null and _dalji_click_voice_player.playing:
		_dalji_click_voice_player.stop()


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
