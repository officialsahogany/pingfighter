extends Control

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ResultBoxOpenFxHost := preload("res://scripts/effects/result_box_open_fx_host.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const StageClearResultClickReactionState := preload("res://scripts/ui/stage_clear_result_click_reaction_state.gd")
const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")
const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")
const StageClearResultSummaryBuilder := preload("res://scripts/ui/stage_clear_result_summary_builder.gd")
const StageClearResultRewardVisualResolver := preload("res://scripts/ui/stage_clear_result_reward_visual_resolver.gd")
const StageClearResultRewardTextResolver := preload("res://scripts/ui/stage_clear_result_reward_text_resolver.gd")
const StageClearResultTextLayoutHelper := preload("res://scripts/ui/stage_clear_result_text_layout_helper.gd")

const STAGE1_BACKGROUND_PATH := "res://assets/sprites/stage1/result/stage1_result_background_imagegen_v1.png"
const DALJI_DEFEAT_SHEET_PATH := "res://assets/sprites/stage1/dalji/dalji_result_defeat_cutscene_live2d_clean_anchor_pingpong_98f_autosprite_v6_realesrgan_animev3_hq1152_safe.png"
const DALJI_CLICK_REACTION_SHEET_PATH := "res://assets/sprites/stage1/dalji/dalji_result_click_cry_dont_talk_live2d_remake_pingpong_98f_autosprite_v6_realesrgan_animev3_hq1152_safe.png"
const DALJI_CLICK_VOICE_PATH := "res://voice/dalzidefeat.mp3"
const SMASHER_VICTORY_SHEET_PATH := "res://assets/sprites/smasher/smasher_result_victory_base_loop_98f_autosprite_v18_magenta_v2_no_pet_realesrgan_animev3_hq1408.png"
const SMASHER_CLICK_REACTION_SHEET_PATH := "res://assets/sprites/smasher/smasher_result_victory_click_reaction_98f_autosprite_v18_magenta_v2_no_pet_realesrgan_animev3_hq1408.png"
const RESULT_SCROLL_PANEL_PATH := "res://assets/sprites/result_scroll/stage_clear_cyber_scroll_imagegen_v1_alpha.png"

const DALJI_FRAME_COUNT := 98
const DALJI_GRID_COLS := 14
const DALJI_CELL_SIZE := Vector2(1152.0, 1152.0)
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
const PLAYER_VICTORY_CELL_SIZE := Vector2(1408.0, 1408.0)
const PLAYER_VICTORY_FRAME_INTERVAL := 0.055
const PLAYER_VICTORY_CLICK_FRAME_INTERVAL := 0.036
const PLAYER_VICTORY_CLICK_REACTION_DURATION := PLAYER_VICTORY_FRAME_COUNT * PLAYER_VICTORY_CLICK_FRAME_INTERVAL
const PLAYER_VICTORY_CLICK_TRANSITION_DURATION := 0.16
const PLAYER_VICTORY_CLICK_RETURN_HOLD_DURATION := 0.18
const PLAYER_VICTORY_CLICK_RETURN_FADE_DURATION := 0.05
const PLAYER_VICTORY_CLICK_RETURN_BLEND_DURATION := PLAYER_VICTORY_CLICK_RETURN_HOLD_DURATION + PLAYER_VICTORY_CLICK_RETURN_FADE_DURATION
const PLAYER_VICTORY_CLICK_TOTAL_DURATION := PLAYER_VICTORY_CLICK_REACTION_DURATION + PLAYER_VICTORY_CLICK_RETURN_BLEND_DURATION

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

const SCROLL_DELAY := 0.38
const SCROLL_UNFURL_DURATION := 0.95
const SCROLL_REGION_TOP := 96.0
const SCROLL_REGION_BOTTOM := 850.0
const SCROLL_REGION_LEFT := 340.0
const SCROLL_REGION_RIGHT := 1580.0
const SCROLL_CONTENT_MARGIN := Vector4(70.0, 90.0, 70.0, 76.0)

const PLACEHOLDER_GOLD := 1240
const RESULT_BOX_SHEET_COMMON_PATH := "res://assets/sprites/result_boxes/result_box_common_open_16f.png"
const RESULT_BOX_SHEET_MYTHIC_PATH := "res://assets/sprites/result_boxes/result_box_mythic_open_16f.png"
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
const PREWARM_ASSET_STEP_COUNT := 10

var timer: float = 0.0
var player_score: int = 0
var boss_score: int = 0
var current_stage: int = 1
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
var _next_stage_button_rect: Rect2 = Rect2()
var _exit_button_rect: Rect2 = Rect2()
var _hovered_button: String = "none"
var _reward_icon_cache: Dictionary = {}
var _dalji_click_rect: Rect2 = Rect2()
var _player_victory_click_rect: Rect2 = Rect2()
var _background_texture: Texture2D
var _dalji_defeat_sheet: Texture2D
var _dalji_click_reaction_sheet: Texture2D
var _player_victory_sheet: Texture2D
var _player_victory_click_reaction_sheet: Texture2D
var _scroll_texture: Texture2D
var _result_box_sheet_common: Texture2D
var _result_box_sheet_mythic: Texture2D
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
var _dalji_dialogue_timer: float = 0.0
var _dalji_click_transition_base_frame: int = 0
var _player_victory_click_transition_base_frame: int = 0
var _fx_hosts: Array = []
var _fx_prewarm_next_index: int = 0
var _lid_open_counter: int = 0
var _starpoint_choice_gate_active: bool = false
var _starpoint_choice_gate_box_index: int = -1

static var _prewarm_asset_step_index: int = 0
static var _prewarm_asset_status: Dictionary = {}


static func prewarm_assets() -> Dictionary:
	while not prewarm_assets_step():
		pass
	return _prewarm_asset_status.duplicate()


static func prewarm_assets_step() -> bool:
	match _prewarm_asset_step_index:
		0:
			_prewarm_asset_status["background_texture"] = ProjectResourceLoader.load_texture(STAGE1_BACKGROUND_PATH) != null
		1:
			_prewarm_asset_status["dalji_defeat_sheet"] = ProjectResourceLoader.load_texture(DALJI_DEFEAT_SHEET_PATH) != null
		2:
			_prewarm_asset_status["dalji_click_reaction_sheet"] = ProjectResourceLoader.load_texture(DALJI_CLICK_REACTION_SHEET_PATH) != null
		3:
			_prewarm_asset_status["player_victory_sheet"] = ProjectResourceLoader.load_texture(SMASHER_VICTORY_SHEET_PATH) != null
		4:
			_prewarm_asset_status["player_victory_click_reaction_sheet"] = ProjectResourceLoader.load_texture(SMASHER_CLICK_REACTION_SHEET_PATH) != null
		5:
			_prewarm_asset_status["scroll_texture"] = ProjectResourceLoader.load_texture(RESULT_SCROLL_PANEL_PATH) != null
		6:
			_prewarm_asset_status["result_box_sheet_common"] = ProjectResourceLoader.load_texture(RESULT_BOX_SHEET_COMMON_PATH) != null
		7:
			_prewarm_asset_status["result_box_sheet_mythic"] = ProjectResourceLoader.load_texture(RESULT_BOX_SHEET_MYTHIC_PATH) != null
		8:
			_prewarm_asset_status["dalji_click_voice"] = ProjectResourceLoader.load_audio_stream(DALJI_CLICK_VOICE_PATH) != null
		9:
			ResultBoxOpenFxHost.prewarm_assets()
			_prewarm_asset_status["result_box_fx"] = true
	_prewarm_asset_step_index += 1
	if _prewarm_asset_step_index >= PREWARM_ASSET_STEP_COUNT:
		_prewarm_asset_step_index = 0
		return true
	return false


static func reset_prewarm_assets_for_test() -> void:
	_prewarm_asset_step_index = 0
	_prewarm_asset_status.clear()


static func get_prewarm_asset_status() -> Dictionary:
	return _prewarm_asset_status.duplicate()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(not _driven_by_controller)
	_apply_standalone_preview_defaults()
	if _boxes.is_empty() and not reward_plan.is_empty():
		_boxes = _build_boxes_from_plan(reward_plan)
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
	_boxes = _build_boxes_from_plan(reward_plan)
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
	timer = 0.0
	_dalji_base_timer = 0.0
	_dalji_click_reaction_timer = DALJI_CLICK_TOTAL_DURATION
	_player_victory_click_reaction_timer = PLAYER_VICTORY_CLICK_TOTAL_DURATION
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
	if _is_dalji_click_reaction_active():
		_dalji_click_reaction_timer = min(DALJI_CLICK_TOTAL_DURATION, _dalji_click_reaction_timer + safe_delta)
	if _is_player_victory_click_reaction_active():
		_player_victory_click_reaction_timer = min(
			PLAYER_VICTORY_CLICK_TOTAL_DURATION,
			_player_victory_click_reaction_timer + safe_delta
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
		return _handle_mythic_acquisition_input(event)
	if _is_runtime_perk_choice_active():
		return _handle_runtime_perk_input(event)

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
		if _scroll_phase == "visible":
			_update_hovered_button(mouse_motion.position)
		else:
			_update_hovered_box(mouse_motion.position)
		return true

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if _handle_dalji_click(mouse_event.position):
				pass
			elif _handle_player_victory_click(mouse_event.position):
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


func _handle_advance_input() -> bool:
	if _starpoint_choice_gate_active or _is_runtime_perk_choice_active():
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
	if _starpoint_choice_gate_active or _is_runtime_perk_choice_active():
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
	if _scroll_phase != "visible":
		return false
	if _next_stage_button_rect.size.x > 0.0 and _next_stage_button_rect.has_point(mouse_position):
		_confirm()
		return true
	if _exit_button_rect.size.x > 0.0 and _exit_button_rect.has_point(mouse_position):
		_exit_to_menu()
		return true
	return false


func _update_hovered_button(mouse_position: Vector2) -> void:
	var previous: String = _hovered_button
	if _next_stage_button_rect.size.x > 0.0 and _next_stage_button_rect.has_point(mouse_position):
		_hovered_button = "next_stage"
	elif _exit_button_rect.size.x > 0.0 and _exit_button_rect.has_point(mouse_position):
		_hovered_button = "exit"
	else:
		_hovered_button = "none"
	if previous != _hovered_button:
		queue_redraw()


func get_interaction_status() -> Dictionary:
	var view_size: Vector2 = size
	if view_size == Vector2.ZERO:
		view_size = _get_view_size()
	@warning_ignore("shadowed_variable_base_class")
	var scale: float = _get_layout_scale(view_size)
	var opened_count: int = 0
	var opening_count: int = 0
	for box in _boxes:
		if not (box is Dictionary):
			continue
		var state: String = str(box.get("state", "idle"))
		if state == "opened":
			opened_count += 1
		elif state == "opening":
			opening_count += 1
	return {
		"dalji_click_reaction_active": _is_dalji_click_reaction_active(),
		"dalji_click_return_blend_active": _is_dalji_click_return_blend_active(),
		"dalji_click_reaction_timer": _dalji_click_reaction_timer,
		"dalji_click_reaction_duration": DALJI_CLICK_REACTION_DURATION,
		"dalji_click_total_duration": DALJI_CLICK_TOTAL_DURATION,
		"dalji_click_transition_base_frame": _dalji_click_transition_base_frame,
		"dalji_base_frame": _get_dalji_base_frame(),
		"dalji_base_timer": _dalji_base_timer,
		"dalji_reaction_alpha": _get_dalji_reaction_alpha(),
		"dalji_dialogue_timer": _dalji_dialogue_timer,
		"dalji_click_rect": _get_dalji_draw_rect(view_size, scale),
		"dalji_dialogue": DALJI_CLICK_DIALOGUE,
		"dalji_click_voice_path": DALJI_CLICK_VOICE_PATH,
		"dalji_click_voice_loaded": _dalji_click_voice_stream != null,
		"dalji_click_voice_player_ready": _dalji_click_voice_player != null,
		"dalji_click_voice_playing": _dalji_click_voice_player != null and _dalji_click_voice_player.playing,
		"player_victory_sheet_path": SMASHER_VICTORY_SHEET_PATH,
		"player_victory_click_reaction_sheet_path": SMASHER_CLICK_REACTION_SHEET_PATH,
		"player_victory_sheet_loaded": _player_victory_sheet != null,
		"player_victory_click_reaction_sheet_loaded": _player_victory_click_reaction_sheet != null,
		"player_victory_frame_count": PLAYER_VICTORY_FRAME_COUNT,
		"player_victory_grid_cols": PLAYER_VICTORY_GRID_COLS,
		"player_victory_cell_size": PLAYER_VICTORY_CELL_SIZE,
		"player_victory_base_frame": _get_player_victory_base_frame(),
		"player_victory_click_reaction_active": _is_player_victory_click_reaction_active(),
		"player_victory_click_return_blend_active": _is_player_victory_click_return_blend_active(),
		"player_victory_click_reaction_timer": _player_victory_click_reaction_timer,
		"player_victory_click_reaction_duration": PLAYER_VICTORY_CLICK_REACTION_DURATION,
		"player_victory_click_total_duration": PLAYER_VICTORY_CLICK_TOTAL_DURATION,
		"player_victory_click_transition_base_frame": _player_victory_click_transition_base_frame,
		"player_victory_reaction_alpha": _get_player_victory_reaction_alpha(),
		"player_victory_draw_rect": _get_player_victory_actor_rect(view_size, scale),
		"player_victory_click_rect": _get_player_victory_click_rect(view_size, scale),
		"box_count": _boxes.size(),
		"opened_count": opened_count,
		"opening_count": opening_count,
		"item_reward_count": _build_item_summary().size(),
		"perk_reward_count": _build_perk_summary().size(),
		"stage_active_item_count": _get_stage_summary_array("active_items").size(),
		"stage_passive_item_count": _get_stage_summary_array("passive_items").size(),
		"stage_perk_count": _get_stage_summary_array("perks").size(),
		"item_reward_source_counts": _count_result_reward_sources(_build_item_summary()),
		"perk_reward_source_counts": _count_result_reward_sources(_build_perk_summary()),
		"visible_reward_source_counts": _count_result_reward_sources(_build_visible_reward_summary()),
		"perk_info": _build_perk_info_summary(),
		"starpoint_total": _calculate_starpoint_total(),
		"hovered_box_index": _hovered_box_index,
		"all_boxes_opened": _boxes.size() > 0 and opened_count == _boxes.size(),
		"scroll_phase": _scroll_phase,
		"scroll_unfurl_progress": _get_scroll_unfurl_progress(),
		"scroll_visible": _scroll_phase == "unfurling" or _scroll_phase == "visible",
		"scroll_texture_loaded": _scroll_texture != null,
		"next_stage_button_rect": _next_stage_button_rect,
		"exit_button_rect": _exit_button_rect,
		"buttons_clickable": _scroll_phase == "visible",
		"hovered_button": _hovered_button,
		"scene_timer": timer,
		"exit_callback_bound": exit_to_menu_callback.is_valid(),
		"starpoint_choice_gate_active": _starpoint_choice_gate_active,
		"starpoint_choice_gate_box_index": _starpoint_choice_gate_box_index,
		"runtime_perk_choice_active": _is_runtime_perk_choice_active(),
		"box_open_audio_ready": _game_audio != null and _game_audio.has_method("play_result_box_open"),
	}


func get_resolved_rewards() -> Array:
	var rewards: Array = []
	for box_value in _boxes:
		if not (box_value is Dictionary):
			continue
		var box: Dictionary = box_value
		var reward_value: Variant = box.get("reward", {})
		if not (reward_value is Dictionary):
			continue
		var reward: Dictionary = reward_value
		if reward.is_empty():
			continue
		var reward_copy: Dictionary = reward.duplicate(true)
		reward_copy["box_kind"] = str(box.get("kind", "normal"))
		reward_copy["box_state"] = str(box.get("state", "idle"))
		rewards.append(reward_copy)
	return rewards


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
	var font: Font = ThemeDB.fallback_font

	_draw_background(view_size)
	draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.03, 0.04, 0.10, 0.22))
	_draw_defeated_boss(view_size, scale)
	_draw_floating_boxes(view_size, scale)
	_draw_scroll(view_size, scale, font)
	_draw_player_victory(view_size, scale, font)
	_draw_dalji_click_dialogue(view_size, scale, font)
	_draw_footer(view_size, scale, font)
	_draw_runtime_perk_overlay(view_size)


func set_starpoint_choice_gate_active(active: bool, box_index: int = -1) -> void:
	_starpoint_choice_gate_active = active
	_starpoint_choice_gate_box_index = box_index if active else -1
	queue_redraw()


func _draw_runtime_perk_overlay(view_size: Vector2) -> void:
	if not _is_runtime_perk_choice_active():
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


func _is_runtime_perk_choice_active() -> bool:
	return (
		_runtime_perk_state != null
		and _runtime_perk_state.has_method("is_choice_active")
		and bool(_runtime_perk_state.is_choice_active())
	)


func _draw_background(view_size: Vector2) -> void:
	if _background_texture == null:
		draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.05, 0.07, 0.12, 1.0))
		return
	var texture_size: Vector2 = _background_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.05, 0.07, 0.12, 1.0))
		return
	var source: Rect2 = _cover_source_rect(texture_size, view_size)
	draw_texture_rect_region(_background_texture, Rect2(Vector2.ZERO, view_size), source, Color.WHITE, false, true)


@warning_ignore("shadowed_variable_base_class")
func _draw_defeated_boss(view_size: Vector2, scale: float) -> void:
	if _dalji_defeat_sheet == null:
		return
	@warning_ignore("shadowed_variable_base_class")
	var draw_rect: Rect2 = _get_dalji_draw_rect(view_size, scale)
	_dalji_click_rect = draw_rect
	if not _is_dalji_click_reaction_active() or _dalji_click_reaction_sheet == null:
		_draw_dalji_sheet_frame(_dalji_defeat_sheet, _get_dalji_base_frame(), draw_rect, 0.98)
		return

	var reaction_alpha: float = _get_dalji_reaction_alpha()
	var base_alpha: float = 1.0 - reaction_alpha
	if base_alpha > 0.001:
		_draw_dalji_sheet_frame(_dalji_defeat_sheet, _get_dalji_transition_base_frame(), draw_rect, 0.98 * base_alpha)
	if reaction_alpha > 0.001:
		_draw_dalji_sheet_frame(_dalji_click_reaction_sheet, _get_dalji_reaction_frame(), draw_rect, 0.98 * reaction_alpha)


@warning_ignore("shadowed_variable_base_class")
func _draw_dalji_click_dialogue(view_size: Vector2, scale: float, font: Font) -> void:
	if _dalji_dialogue_timer <= 0.0:
		return
	var alpha: float = clamp(_dalji_dialogue_timer / DALJI_CLICK_DIALOGUE_FADE_DURATION, 0.0, 1.0)
	var boss_rect: Rect2 = _get_dalji_draw_rect(view_size, scale)
	var bubble_size := Vector2(210.0, 58.0) * scale
	var bubble_position := Vector2(
		max(18.0 * scale, boss_rect.position.x + 132.0 * scale),
		max(52.0 * scale, boss_rect.position.y - 42.0 * scale)
	)
	var bubble := Rect2(bubble_position, bubble_size)
	_draw_panel(bubble, Color(1.0, 0.96, 0.98, 0.90 * alpha), Color(1.0, 0.72, 0.82, 0.95 * alpha), 2.0 * scale, 17.0 * scale)
	var tail := PackedVector2Array([
		Vector2(bubble.position.x + 44.0 * scale, bubble.position.y + bubble.size.y - 2.0 * scale),
		Vector2(bubble.position.x + 72.0 * scale, bubble.position.y + bubble.size.y - 2.0 * scale),
		Vector2(bubble.position.x + 54.0 * scale, bubble.position.y + bubble.size.y + 22.0 * scale),
	])
	draw_colored_polygon(tail, Color(1.0, 0.96, 0.98, 0.90 * alpha))
	_draw_centered_text(font, DALJI_CLICK_DIALOGUE, bubble, int(round(26.0 * scale)), Color(0.34, 0.12, 0.18, 0.98 * alpha))


@warning_ignore("shadowed_variable_base_class")
func _draw_player_victory(view_size: Vector2, scale: float, font: Font) -> void:
	if _draw_player_victory_live2d(view_size, scale):
		return
	var panel: Rect2 = _get_player_victory_panel_rect(view_size, scale)
	_draw_panel(panel, Color(0.03, 0.75, 0.78, 0.74), Color(0.76, 1.0, 1.0, 0.92), 2.0 * scale, 22.0 * scale)

	if _player_victory_sheet != null:
		var frame: int = int(floor(timer / PLAYER_VICTORY_FRAME_INTERVAL)) % PLAYER_VICTORY_FRAME_COUNT
		var source: Rect2 = _sheet_source_rect(frame, PLAYER_VICTORY_GRID_COLS, PLAYER_VICTORY_CELL_SIZE)
		var actor_rect: Rect2 = _get_player_victory_actor_rect(view_size, scale)
		draw_texture_rect_region(_player_victory_sheet, actor_rect, source, Color.WHITE, false, true)

	_draw_text(
		font,
		"플레이어 승리",
		Vector2(panel.position.x + 34.0 * scale, panel.position.y + panel.size.y - 325.0 * scale),
		int(round(25.0 * scale)),
		Color(0.96, 1.0, 1.0, 0.97)
	)
	_draw_text(
		font,
		"Live2D 포즈",
		Vector2(panel.position.x + 34.0 * scale, panel.position.y + panel.size.y - 278.0 * scale),
		int(round(34.0 * scale)),
		Color(1.0, 1.0, 1.0, 0.96)
	)
	_draw_text(
		font,
		"승리 연출 테스트",
		Vector2(panel.position.x + 34.0 * scale, panel.position.y + panel.size.y - 225.0 * scale),
		int(round(23.0 * scale)),
		Color(0.83, 0.98, 1.0, 0.92)
	)


func _draw_player_victory_live2d(view_size: Vector2, layout_ratio: float) -> bool:
	if _player_victory_sheet == null:
		_player_victory_click_rect = Rect2()
		return true
	var actor_rect: Rect2 = _get_player_victory_actor_rect(view_size, layout_ratio)
	_player_victory_click_rect = _get_player_victory_click_rect(view_size, layout_ratio)
	if not _is_player_victory_click_reaction_active() or _player_victory_click_reaction_sheet == null:
		_draw_player_victory_sheet_frame(_player_victory_sheet, _get_player_victory_base_frame(), actor_rect, 1.0)
		return true

	var reaction_alpha: float = _get_player_victory_reaction_alpha()
	var base_alpha: float = 1.0 - reaction_alpha
	if base_alpha > 0.001:
		_draw_player_victory_sheet_frame(
			_player_victory_sheet,
			_get_player_victory_transition_base_frame(),
			actor_rect,
			base_alpha
		)
	if reaction_alpha > 0.001:
		_draw_player_victory_sheet_frame(
			_player_victory_click_reaction_sheet,
			_get_player_victory_reaction_frame(),
			actor_rect,
			reaction_alpha
		)
	return true


func _build_boxes_from_plan(plan: Dictionary) -> Array:
	var box_list: Array = []
	var boxes_value: Variant = plan.get("boxes", [])
	var src: Array = boxes_value if boxes_value is Array else []
	if src.is_empty():
		return box_list
	var layout: Array = _get_box_layout(src.size())
	if layout.is_empty():
		return box_list
	var count: int = min(src.size(), layout.size())
	for i in range(count):
		var src_box: Dictionary = src[i] if src[i] is Dictionary else {}
		var slot: Dictionary = layout[i]
		box_list.append({
			"kind": str(src_box.get("kind", "normal")),
			"base_pos": Vector2(slot.get("pos", Vector2.ZERO)),
			"rotation_base": float(slot.get("rot", 0.0)),
			"rotation_jitter": float(slot.get("jitter", 0.05)),
			"phase": float(slot.get("phase", 0.0)),
			"amplitude": float(slot.get("amp", BOX_FLOAT_AMPLITUDE)),
			"speed": float(slot.get("speed", BOX_FLOAT_SPEED)),
			"state": "idle",
			"open_progress": 0.0,
			"reward": {},
			"reward_emerge": 0.0,
		})
	return box_list


func _get_box_layout(count: int) -> Array:
	return StageClearResultLayoutHelper.get_box_layout(count)


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
	var global_alpha: float = _get_box_global_alpha()
	if global_alpha <= 0.02:
		return

	var kind: String = str(box.get("kind", "normal"))
	var is_mythic: bool = kind == "mythic"
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

	var draw_center: Vector2 = _get_box_draw_center(box, scale) + shake_offset

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

	_draw_shadow_ellipse(
		Vector2(draw_center.x, draw_center.y + body_hy + BOX_SHADOW_OFFSET_Y * scale),
		body_hx * 0.95,
		body_hy * 0.20,
		0.40 * global_alpha
	)

	var top_left: Vector2 = _rotate_around(Vector2(-hx, -hy), Vector2.ZERO, box_rotation) + draw_center
	var top_right: Vector2 = _rotate_around(Vector2(hx, -hy), Vector2.ZERO, box_rotation) + draw_center
	var bot_right: Vector2 = _rotate_around(Vector2(hx, hy), Vector2.ZERO, box_rotation) + draw_center
	var bot_left: Vector2 = _rotate_around(Vector2(-hx, hy), Vector2.ZERO, box_rotation) + draw_center

	if hover_active:
		_draw_box_hover_glow(draw_center, body_hx, body_hy, scale, is_mythic, global_alpha, hover_pulse)

	var frame_index: int = _get_result_box_frame_index(state, open_progress, is_mythic)

	var texture: Texture2D = _result_box_sheet_mythic if is_mythic else _result_box_sheet_common
	if texture != null:
		var col: int = frame_index % RESULT_BOX_SHEET_GRID_COLS
		@warning_ignore("integer_division")
		var row: int = int(frame_index / RESULT_BOX_SHEET_GRID_COLS)
		var uv_step_x: float = 1.0 / float(RESULT_BOX_SHEET_GRID_COLS)
		var uv_step_y: float = 1.0 / float(RESULT_BOX_SHEET_GRID_ROWS)
		var uv_left: float = float(col) * uv_step_x
		var uv_top: float = float(row) * uv_step_y
		var uv_array := PackedVector2Array([
			Vector2(uv_left, uv_top),
			Vector2(uv_left + uv_step_x, uv_top),
			Vector2(uv_left + uv_step_x, uv_top + uv_step_y),
			Vector2(uv_left, uv_top + uv_step_y),
		])
		var quad := PackedVector2Array([top_left, top_right, bot_right, bot_left])
		var tint := Color(1.0, 1.0, 1.0, global_alpha)
		draw_polygon(quad, [tint], uv_array, texture)

	if hover_active:
		_draw_box_hover_sparkles(draw_center, body_hx, body_hy, scale, is_mythic, global_alpha, phase)

	if state == "opened":
		_draw_reward_label(box, draw_center, body_hy, scale, global_alpha)


func _get_result_box_frame_index(state: String, open_progress: float, is_mythic: bool) -> int:
	return StageClearResultLayoutHelper.get_result_box_frame_index(
		state,
		open_progress,
		is_mythic,
		RESULT_BOX_SHEET_FRAME_COUNT,
		RESULT_BOX_COMMON_SAFE_LAST_FRAME,
		RESULT_BOX_MYTHIC_SAFE_LAST_FRAME
	)


@warning_ignore("shadowed_variable_base_class")
func _get_box_draw_center(box: Dictionary, scale: float) -> Vector2:
	return StageClearResultLayoutHelper.get_box_draw_center(
		box,
		scale,
		timer,
		BOX_FLOAT_AMPLITUDE,
		BOX_FLOAT_SPEED
	)


@warning_ignore("shadowed_variable_base_class")
func _get_box_aabb(box: Dictionary, scale: float) -> Rect2:
	return StageClearResultLayoutHelper.get_box_aabb(
		box,
		scale,
		timer,
		BOX_BASE_SIZE,
		BOX_HOVER_GROW,
		BOX_FLOAT_AMPLITUDE,
		BOX_FLOAT_SPEED
	)


func _rotate_around(point: Vector2, center: Vector2, angle: float) -> Vector2:
	return StageClearResultLayoutHelper.rotate_around(point, center, angle)


func _draw_shadow_ellipse(center: Vector2, radius_x: float, radius_y: float, alpha: float) -> void:
	var pts := PackedVector2Array()
	var segments: int = 24
	for i in range(segments):
		var angle: float = (float(i) / float(segments)) * TAU
		pts.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_colored_polygon(pts, Color(0.0, 0.0, 0.0, alpha))


@warning_ignore("shadowed_variable_base_class")
func _draw_box_hover_glow(draw_center: Vector2, hx: float, hy: float, scale: float, is_mythic: bool, global_alpha: float, pulse: float) -> void:
	var base_color: Color = Color(1.0, 0.92, 0.50, 1.0) if is_mythic else Color(0.62, 0.92, 1.0, 1.0)
	var layer_count: int = 4
	for i in range(layer_count):
		var t: float = float(i) / float(max(1, layer_count - 1))
		var rx: float = hx * lerp(1.95, 1.18, t)
		var ry: float = hy * lerp(1.80, 1.08, t)
		var alpha: float = lerp(0.055, 0.18, t) * global_alpha
		alpha *= 0.85 + pulse * 0.30
		var c: Color = base_color
		c.a = clamp(alpha, 0.0, 0.22)
		_draw_filled_ellipse(draw_center, rx, ry, c)

	var ring_color: Color = base_color
	ring_color.a = clamp((0.24 + pulse * 0.12) * global_alpha, 0.0, 0.42)
	_draw_ellipse_polyline(
		draw_center,
		hx * 1.28,
		hy * 1.14,
		ring_color,
		max(1.5, 2.2 * scale)
	)


func _draw_filled_ellipse(center: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	if radius_x <= 0.0 or radius_y <= 0.0 or color.a <= 0.001:
		return
	var pts := PackedVector2Array()
	var segments: int = 40
	for i in range(segments):
		var angle: float = (float(i) / float(segments)) * TAU
		pts.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_colored_polygon(pts, color)


func _draw_ellipse_polyline(center: Vector2, radius_x: float, radius_y: float, color: Color, width: float) -> void:
	if radius_x <= 0.0 or radius_y <= 0.0 or color.a <= 0.001 or width <= 0.0:
		return
	var pts := PackedVector2Array()
	var segments: int = 56
	for i in range(segments + 1):
		var angle: float = (float(i) / float(segments)) * TAU
		pts.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_polyline(pts, color, width, true)


@warning_ignore("shadowed_variable_base_class")
func _draw_box_corner_braces(tl: Vector2, tr: Vector2, br: Vector2, bl: Vector2, scale: float, color: Color, width: float) -> void:
	var brace_len: float = max(8.0, 14.0 * scale)
	var corners: Array = [
		{"corner": tl, "neighbors": [tr, bl]},
		{"corner": tr, "neighbors": [tl, br]},
		{"corner": br, "neighbors": [tr, bl]},
		{"corner": bl, "neighbors": [tl, br]},
	]
	for entry in corners:
		var corner: Vector2 = entry["corner"]
		var neighbors_value: Variant = entry["neighbors"]
		if not (neighbors_value is Array):
			continue
		var neighbors: Array = neighbors_value
		for neighbor_value in neighbors:
			if not (neighbor_value is Vector2):
				continue
			var neighbor: Vector2 = neighbor_value
			var direction: Vector2 = (neighbor - corner)
			if direction.length_squared() <= 0.001:
				continue
			var end: Vector2 = corner + direction.normalized() * brace_len
			draw_line(corner, end, color, width)


@warning_ignore("shadowed_variable_base_class")
func _draw_box_lock(
	draw_center: Vector2,
	lock_offset_y: float,
	box_rotation: float,
	scale: float,
	is_mythic: bool,
	hovered: bool,
	alpha: float,
	trim_color: Color,
	trim_bright: Color,
	box_hy: float = 0.0
) -> void:
	if alpha <= 0.02:
		return
	var lock_size: float
	if box_hy > 0.0:
		lock_size = max(6.0 * scale, box_hy * 0.30)
	else:
		lock_size = 22.0 * scale
	var lock_center: Vector2 = _rotate_around(Vector2(0.0, lock_offset_y), Vector2.ZERO, box_rotation) + draw_center

	draw_circle(lock_center + Vector2(0.0, 2.0 * scale), lock_size * 0.95, Color(0.0, 0.0, 0.0, alpha * 0.45))

	var base_metal: Color = Color(0.45, 0.30, 0.10, alpha)
	draw_circle(lock_center, lock_size * 0.90, base_metal)

	var lock_pts := PackedVector2Array([
		_rotate_around(Vector2(0.0, lock_offset_y - lock_size), Vector2.ZERO, box_rotation) + draw_center,
		_rotate_around(Vector2(lock_size * 0.72, lock_offset_y), Vector2.ZERO, box_rotation) + draw_center,
		_rotate_around(Vector2(0.0, lock_offset_y + lock_size), Vector2.ZERO, box_rotation) + draw_center,
		_rotate_around(Vector2(-lock_size * 0.72, lock_offset_y), Vector2.ZERO, box_rotation) + draw_center,
	])
	var lock_face: Color = trim_color
	lock_face.a = alpha
	draw_colored_polygon(lock_pts, lock_face)

	var lock_outline: Color = Color(0.55, 0.30, 0.06, alpha)
	var closed_lock: PackedVector2Array = lock_pts.duplicate()
	closed_lock.append(lock_pts[0])
	draw_polyline(closed_lock, lock_outline, max(1.0, 1.4 * scale), true)

	if is_mythic:
		_draw_star_polygon(
			lock_center,
			lock_size * 0.58,
			lock_size * 0.24,
			Color(0.96, 0.34, 0.92, alpha),
			Color(0.46, 0.10, 0.42, alpha),
			max(1.0, 1.2 * scale)
		)
		if hovered:
			var sparkle_alpha: float = (sin(timer * 6.0) * 0.5 + 0.5) * alpha
			draw_circle(lock_center + Vector2(-3.0 * scale, -3.0 * scale), 2.4 * scale, Color(1.0, 0.96, 0.86, sparkle_alpha))
	else:
		var keyhole_center: Vector2 = lock_center + Vector2(0.0, scale * 0.5)
		draw_circle(keyhole_center, lock_size * 0.22, Color(0.18, 0.09, 0.02, alpha))
		var slit_top: Vector2 = keyhole_center + Vector2(0.0, lock_size * 0.18)
		var slit_bot: Vector2 = keyhole_center + Vector2(0.0, lock_size * 0.42)
		draw_line(slit_top, slit_bot, Color(0.18, 0.09, 0.02, alpha), max(1.5, 2.0 * scale))
		var keyhole_highlight: Color = trim_bright
		keyhole_highlight.a = alpha * 0.5
		draw_circle(keyhole_center + Vector2(-1.5 * scale, -1.5 * scale), lock_size * 0.06, keyhole_highlight)


@warning_ignore("shadowed_variable_base_class")
func _draw_box_hover_sparkles(draw_center: Vector2, hx: float, hy: float, scale: float, is_mythic: bool, global_alpha: float, phase: float) -> void:
	var base_color: Color = Color(1.0, 0.92, 0.50, 1.0) if is_mythic else Color(0.62, 0.92, 1.0, 1.0)
	var sparkle_count: int = 6
	var orbit_x: float = hx * 1.18
	var orbit_y: float = hy * 0.86
	for i in range(sparkle_count):
		var t: float = float(i) / float(sparkle_count)
		var orbit_angle: float = t * TAU + timer * 0.85 + phase
		var sparkle_pos: Vector2 = draw_center + Vector2(cos(orbit_angle) * orbit_x, sin(orbit_angle) * orbit_y)
		var local_phase: float = timer * 3.0 + t * TAU
		var sparkle_alpha: float = (sin(local_phase) * 0.5 + 0.5) * global_alpha * 0.85
		if sparkle_alpha <= 0.04:
			continue
		var sparkle_size: float = max(2.0, (3.6 + sin(local_phase * 1.3) * 1.2) * scale)
		var dot_color: Color = base_color
		dot_color.a = sparkle_alpha
		draw_circle(sparkle_pos, sparkle_size, dot_color)
		draw_circle(sparkle_pos, sparkle_size * 0.42, Color(1.0, 1.0, 1.0, sparkle_alpha * 0.85))


func _draw_radial_burst(center: Vector2, radius: float, color: Color) -> void:
	if radius <= 0.0 or color.a <= 0.001:
		return
	var segments: int = 28
	var outer_color: Color = color
	outer_color.a = color.a * 0.55
	var outer_pts := PackedVector2Array()
	for i in range(segments):
		var angle: float = (float(i) / float(segments)) * TAU
		outer_pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(outer_pts, outer_color)
	var inner_color: Color = color
	inner_color.a = color.a * 0.92
	var inner_pts := PackedVector2Array()
	var inner_radius: float = radius * 0.55
	for i in range(segments):
		var angle: float = (float(i) / float(segments)) * TAU
		inner_pts.append(center + Vector2(cos(angle), sin(angle)) * inner_radius)
	draw_colored_polygon(inner_pts, inner_color)


@warning_ignore("shadowed_variable_base_class")
func _draw_reward_label(box: Dictionary, box_draw_center: Vector2, hy: float, scale: float, global_alpha: float) -> void:
	var reward: Dictionary = box.get("reward", {}) if box.get("reward", {}) is Dictionary else {}
	if reward.is_empty() or global_alpha <= 0.02:
		return
	var reward_type: String = str(reward.get("type", ""))
	var emerge: float = float(box.get("reward_emerge", 0.0))
	var emerge_eased: float = _smooth01(emerge)
	var combined_alpha: float = emerge_eased * global_alpha
	if combined_alpha <= 0.02:
		return

	var rise: float = lerp(20.0 * scale, BOX_REWARD_HOVER_OFFSET * scale, emerge_eased)
	var bob: float = sin(timer * 2.6 + float(box.get("phase", 0.0))) * 4.0 * scale * emerge_eased
	var anchor: Vector2 = box_draw_center + Vector2(0.0, -hy - rise + bob)

	if reward_type == "starpoint":
		_draw_reward_starpoint(reward, anchor, scale, combined_alpha, emerge_eased, float(box.get("phase", 0.0)))
	else:
		_draw_reward_item_icon(reward, anchor, scale, combined_alpha)


@warning_ignore("shadowed_variable_base_class")
func _draw_reward_item_icon(reward: Dictionary, anchor: Vector2, scale: float, alpha: float) -> void:
	var reward_type: String = str(reward.get("type", ""))
	var icon_size: float = 96.0 * scale
	var disc_radius: float = 60.0 * scale

	var disc_color: Color
	var rim_color: Color
	match reward_type:
		"active":
			disc_color = Color(0.06, 0.20, 0.28, 0.88)
			rim_color = Color(0.55, 0.92, 1.0, 1.0)
		"passive":
			disc_color = Color(0.22, 0.14, 0.04, 0.88)
			rim_color = Color(1.0, 0.84, 0.48, 1.0)
		"mythic":
			disc_color = Color(0.20, 0.06, 0.34, 0.92)
			rim_color = Color(1.0, 0.78, 0.30, 1.0)
		_:
			disc_color = Color(0.18, 0.18, 0.24, 0.88)
			rim_color = Color(0.85, 0.85, 0.92, 1.0)

	var glow_color: Color = rim_color
	glow_color.a = 0.32 * alpha
	_draw_radial_burst(anchor, disc_radius * 1.55, glow_color)

	var disc_fill: Color = disc_color
	disc_fill.a *= alpha
	draw_circle(anchor, disc_radius, disc_fill)

	var ring_color: Color = rim_color
	ring_color.a *= alpha
	draw_arc(anchor, disc_radius, 0.0, TAU, 40, ring_color, max(2.0, 2.8 * scale))

	var texture: Texture2D = _get_reward_icon_texture(reward)
	if texture != null:
		var icon_rect := Rect2(anchor - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
		draw_texture_rect(texture, icon_rect, false, Color(1.0, 1.0, 1.0, alpha))
	else:
		var fallback_label: String = str(reward.get("label", ""))
		if fallback_label == "":
			fallback_label = _reward_type_fallback_label(reward_type)
		var font: Font = ThemeDB.fallback_font
		var text_rect := Rect2(anchor - Vector2(disc_radius * 0.95, 18.0 * scale), Vector2(disc_radius * 1.9, 36.0 * scale))
		var text_color: Color = Color(1.0, 1.0, 1.0, alpha)
		var font_size: int = _fit_font_size(
			font,
			fallback_label,
			text_rect.size.x,
			int(round(22.0 * scale)),
			int(round(13.0 * scale))
		)
		_draw_centered_text(font, fallback_label, text_rect, font_size, text_color)


@warning_ignore("shadowed_variable_base_class")
func _draw_reward_starpoint(
	reward: Dictionary,
	anchor: Vector2,
	scale: float,
	alpha: float,
	emerge_progress: float = 1.0,
	phase: float = 0.0
) -> void:
	var amount: int = max(1, int(reward.get("amount", 1)))
	var disc_radius: float = 60.0 * scale
	var star_radius: float = 42.0 * scale
	var spin_angle: float = timer * 8.7 + phase * 1.9
	var yaw_width: float = lerpf(0.16, 1.0, pow(absf(cos(spin_angle)), 0.62))
	var front_face: bool = cos(spin_angle) >= 0.0
	var star_center: Vector2 = anchor + Vector2(0.0, -10.0 * scale)
	var sparkle_alpha: float = clamp(alpha * emerge_progress, 0.0, 1.0)

	var glow_color: Color = Color(1.0, 0.88, 0.36, 0.36 * alpha)
	_draw_radial_burst(anchor, disc_radius * 1.55, glow_color)

	var disc_fill: Color = Color(0.30, 0.18, 0.04, 0.88 * alpha)
	draw_circle(anchor, disc_radius, disc_fill)
	draw_arc(anchor, disc_radius, 0.0, TAU, 40, Color(1.0, 0.86, 0.32, alpha), max(2.0, 2.8 * scale))

	var orbit_rect := Rect2(
		anchor - Vector2(disc_radius * 0.82, disc_radius * 0.42),
		Vector2(disc_radius * 1.64, disc_radius * 0.84)
	)
	draw_arc(
		orbit_rect.get_center(),
		orbit_rect.size.x * 0.5,
		-PI * 0.05,
		PI * 1.05,
		36,
		Color(1.0, 0.98, 0.68, 0.22 * sparkle_alpha),
		max(1.0, 1.4 * scale)
	)

	var star_fill := Color(1.0, 0.88, 0.36, alpha) if front_face else Color(0.86, 0.48, 0.08, alpha)
	var star_outline := Color(0.55, 0.32, 0.04, alpha)
	_draw_star_polygon_scaled(
		star_center,
		star_radius,
		star_radius * 0.46,
		yaw_width,
		star_fill,
		star_outline,
		max(1.5, 2.0 * scale)
	)
	if yaw_width <= 0.32:
		draw_line(
			star_center + Vector2(0.0, -star_radius * 0.92),
			star_center + Vector2(0.0, star_radius * 0.92),
			Color(1.0, 0.98, 0.68, alpha * 0.88),
			max(2.0, star_radius * 0.13)
		)
	else:
		draw_circle(
			star_center + Vector2(-star_radius * 0.18 * yaw_width, -star_radius * 0.28),
			max(1.4, 3.4 * scale),
			Color(1.0, 1.0, 0.92, alpha * 0.72)
		)

	var font: Font = ThemeDB.fallback_font
	var text_rect := Rect2(anchor + Vector2(-disc_radius, 22.0 * scale), Vector2(disc_radius * 2.0, 30.0 * scale))
	_draw_centered_text(font, "x %d" % amount, text_rect, int(round(22.0 * scale)), Color(1.0, 0.97, 0.70, alpha))


func _draw_star_polygon(center: Vector2, outer_radius: float, inner_radius: float, fill: Color, outline: Color, outline_width: float) -> void:
	_draw_star_polygon_scaled(center, outer_radius, inner_radius, 1.0, fill, outline, outline_width)


func _draw_star_polygon_scaled(
	center: Vector2,
	outer_radius: float,
	inner_radius: float,
	x_scale: float,
	fill: Color,
	outline: Color,
	outline_width: float
) -> void:
	var num_points: int = 5
	var pts := PackedVector2Array()
	var safe_x_scale: float = max(0.04, x_scale)
	for i in range(num_points * 2):
		var angle: float = -PI * 0.5 + float(i) * PI / float(num_points)
		var r: float = outer_radius if i % 2 == 0 else inner_radius
		pts.append(center + Vector2(cos(angle) * r * safe_x_scale, sin(angle) * r))
	draw_colored_polygon(pts, fill)
	if outline.a > 0.001 and outline_width > 0.0:
		var closed: PackedVector2Array = pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, outline, outline_width, true)


func _get_reward_icon_texture(reward: Dictionary) -> Texture2D:
	var item_data_value: Variant = reward.get("item_data", {})
	var item_data: Dictionary = item_data_value if item_data_value is Dictionary else {}

	var pre_texture: Variant = item_data.get("icon_texture", null)
	if pre_texture is Texture2D:
		return pre_texture

	var icon_path: String = str(reward.get("icon_path", ""))
	if icon_path == "":
		icon_path = str(item_data.get("icon_path", ""))
	if icon_path == "":
		var item_name: String = str(reward.get("item_name", ""))
		if item_name == "":
			item_name = str(item_data.get("name", ""))
		if item_name != "":
			icon_path = "res://assets/sprites/items/%s.png" % item_name

	if icon_path == "":
		return null
	if _reward_icon_cache.has(icon_path):
		var cached: Variant = _reward_icon_cache[icon_path]
		return cached if cached is Texture2D else null

	var loaded: Texture2D = ProjectResourceLoader.load_texture(icon_path, "", "")
	_reward_icon_cache[icon_path] = loaded
	return loaded


func _reward_type_fallback_label(reward_type: String) -> String:
	match reward_type:
		"active":
			return "액티브"
		"passive":
			return "패시브"
		"mythic":
			return "신화"
		"starpoint":
			return "스타포인트"
		"perk":
			return "퍽"
	return "보상"


func _handle_box_click(mouse_position: Vector2) -> bool:
	if _boxes.is_empty():
		return false
	if _starpoint_choice_gate_active or _is_runtime_perk_choice_active():
		return true
	if _scroll_phase != "hidden":
		return false
	@warning_ignore("shadowed_variable_base_class")
	var scale: float = _get_layout_scale(size)
	for i in range(_boxes.size() - 1, -1, -1):
		var box: Dictionary = _boxes[i] if _boxes[i] is Dictionary else {}
		if str(box.get("state", "idle")) != "idle":
			continue
		if _get_box_aabb(box, scale).has_point(mouse_position):
			_start_opening_box(i)
			return true
	return false


func _start_opening_box(index: int) -> void:
	if index < 0 or index >= _boxes.size():
		return
	var box: Dictionary = _boxes[index]
	if str(box.get("state", "idle")) != "idle":
		return
	box["state"] = "opening"
	box["open_progress"] = 0.0
	box["reward_emerge"] = 0.0
	box["reward"] = _roll_reward(str(box.get("kind", "normal")))
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
	if kind == "mythic":
		return {"type": "mythic", "label": "신화 아이템"}
	var roll: float = randf()
	if roll < 0.60:
		return {"type": "active", "label": "액티브 아이템"}
	if roll < 0.80:
		return {"type": "passive", "label": "패시브 아이템"}
	var amount: int = randi_range(80, 200)
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
	reward["pickup_position"] = _get_box_cinematic_pickup_position(box)
	reward["target_player_center"] = _get_result_live2d_cinematic_target_position()
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


func _get_box_cinematic_pickup_position(box: Dictionary) -> Vector2:
	@warning_ignore("shadowed_variable_base_class")
	var scale: float = _get_layout_scale(size)
	var draw_center: Vector2 = _get_box_draw_center(box, scale)
	var view_size: Vector2 = size
	if view_size == Vector2.ZERO:
		view_size = _get_view_size()
	var field_size := Vector2(760.0, 750.0)
	var field_origin: Vector2 = (view_size - field_size) * 0.5
	var local_position: Vector2 = draw_center - field_origin
	return Vector2(
		clamp(local_position.x, 0.0, field_size.x),
		clamp(local_position.y, 0.0, field_size.y)
	)


func _get_result_live2d_cinematic_target_position() -> Vector2:
	var view_size: Vector2 = size
	if view_size == Vector2.ZERO:
		view_size = _get_view_size()
	@warning_ignore("shadowed_variable_base_class")
	var scale: float = _get_layout_scale(view_size)
	var actor_rect: Rect2 = _get_player_victory_actor_rect(view_size, scale)
	var screen_position: Vector2 = actor_rect.get_center() + Vector2(0.0, 20.0 * scale)
	return _screen_to_acquisition_cinematic_local(screen_position, view_size)


func _get_player_victory_actor_rect(view_size: Vector2, layout_ratio: float) -> Rect2:
	return StageClearResultLayoutHelper.get_player_victory_actor_rect(view_size, layout_ratio)


func _get_player_victory_click_rect(view_size: Vector2, layout_ratio: float) -> Rect2:
	return StageClearResultLayoutHelper.get_player_victory_click_rect(
		view_size,
		layout_ratio,
		PLAYER_VICTORY_CELL_SIZE
	)


func _get_player_victory_panel_rect(view_size: Vector2, layout_ratio: float) -> Rect2:
	return StageClearResultLayoutHelper.get_player_victory_panel_rect(view_size, layout_ratio)


func _screen_to_acquisition_cinematic_local(screen_position: Vector2, view_size: Vector2) -> Vector2:
	var field_size := Vector2(760.0, 750.0)
	return StageClearResultLayoutHelper.screen_to_acquisition_cinematic_local(screen_position, view_size, field_size)


func _all_boxes_opened() -> bool:
	if _boxes.is_empty():
		return false
	for box in _boxes:
		if not (box is Dictionary):
			continue
		if str(box.get("state", "idle")) != "opened":
			return false
	return true


func _sync_fx_hosts() -> void:
	if _boxes.is_empty():
		_deactivate_all_fx_hosts()
		return
	@warning_ignore("shadowed_variable_base_class")
	var scale: float = _get_layout_scale(size)
	var global_alpha: float = _get_box_global_alpha()
	for i in range(_boxes.size()):
		var box: Dictionary = _boxes[i] if _boxes[i] is Dictionary else {}
		var state: String = str(box.get("state", "idle"))
		if state != "opening" and state != "opened":
			_set_fx_host_active(i, false)
			continue
		var host: Node2D = _ensure_fx_host(i)
		if host == null:
			continue
		var draw_center: Vector2 = _get_box_draw_center(box, scale)
		var open_progress: float = float(box.get("open_progress", 0.0))
		var reward_emerge: float = float(box.get("reward_emerge", 0.0))
		var is_mythic: bool = str(box.get("kind", "normal")) == "mythic"
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
		_starpoint_choice_gate_active or _is_runtime_perk_choice_active(),
		_all_boxes_opened(),
		SCROLL_DELAY,
		SCROLL_UNFURL_DURATION
	)
	_scroll_phase = str(result.get("phase", _scroll_phase))
	_scroll_timer = float(result.get("timer", _scroll_timer))


func _get_scroll_unfurl_progress() -> float:
	return StageClearResultScrollState.get_unfurl_progress(_scroll_phase, _scroll_timer, SCROLL_UNFURL_DURATION)


func _get_box_global_alpha() -> float:
	return StageClearResultScrollState.get_box_global_alpha(_scroll_phase, _scroll_timer, SCROLL_UNFURL_DURATION)


func _calculate_starpoint_total() -> int:
	return StageClearResultSummaryBuilder.calculate_starpoint_total(_boxes)


func _build_item_summary() -> Array:
	return StageClearResultSummaryBuilder.build_item_summary(
		stage_reward_snapshot,
		_boxes,
		RESULT_REWARD_SOURCE_STAGE,
		RESULT_REWARD_SOURCE_BOX,
		_get_result_reward_source_labels()
	)


func _build_perk_summary() -> Array:
	return StageClearResultSummaryBuilder.build_perk_summary(
		stage_reward_snapshot,
		_boxes,
		RESULT_REWARD_SOURCE_STAGE,
		RESULT_REWARD_SOURCE_BOX,
		_get_result_reward_source_labels()
	)


func _build_visible_reward_summary() -> Array:
	return StageClearResultSummaryBuilder.build_visible_reward_summary(
		stage_reward_snapshot,
		_boxes,
		RESULT_REWARD_SOURCE_STAGE,
		RESULT_REWARD_SOURCE_BOX,
		_get_result_reward_source_labels()
	)


func _with_result_reward_source(reward: Dictionary, result_source: String) -> Dictionary:
	return StageClearResultSummaryBuilder.with_result_reward_source(
		reward,
		result_source,
		_get_result_reward_source_labels()
	)


func _count_result_reward_sources(rewards: Array) -> Dictionary:
	return StageClearResultSummaryBuilder.count_result_reward_sources(
		rewards,
		[RESULT_REWARD_SOURCE_STAGE, RESULT_REWARD_SOURCE_BOX]
	)


func _get_stage_summary_array(key: String) -> Array:
	return StageClearResultSummaryBuilder.get_stage_summary_array(stage_reward_snapshot, key)


func _build_perk_info_summary() -> Dictionary:
	var perks: Array = _build_perk_summary()
	if not perks.is_empty():
		var reward: Dictionary = perks[0] if perks[0] is Dictionary else {}
		var title: String = _get_reward_title(reward)
		if perks.size() > 1:
			title = "%s 외 %d개" % [title, perks.size() - 1]
		return {
			"kind": "perk",
			"eyebrow": "획득 퍽",
			"title": title,
			"detail": _get_reward_detail_text(reward),
		}

	var star_total: int = _calculate_starpoint_total()
	if star_total > 0:
		return {
			"kind": "starpoint",
			"eyebrow": "퍽 선택",
			"title": "퍽 선택권 +%d" % star_total,
			"detail": "다음 진행 시 획득한 수만큼 퍽 선택창이 열립니다.",
		}

	return {
		"kind": "empty",
		"eyebrow": "퍽 정보",
		"title": "획득 퍽 없음",
		"detail": "이번 결과는 아이템 보상만 획득했습니다.",
	}


func _is_perk_reward(reward: Dictionary) -> bool:
	return StageClearResultSummaryBuilder.is_perk_reward(reward)


func _get_reward_perk_id(reward: Dictionary) -> String:
	return StageClearResultSummaryBuilder.get_reward_perk_id(reward)


func _get_reward_color(reward_type: String) -> Color:
	return StageClearResultRewardVisualResolver.get_reward_color(reward_type)


@warning_ignore("shadowed_variable_base_class")
func _draw_scroll(_view_size: Vector2, scale: float, font: Font) -> void:
	if _scroll_phase == "hidden":
		return
	var unfurl: float = _get_scroll_unfurl_progress()
	if unfurl <= 0.0:
		return
	_draw_cyber_scroll(unfurl, scale, font)


@warning_ignore("shadowed_variable_base_class")
func _draw_cyber_scroll(unfurl: float, scale: float, font: Font) -> void:
	var left: float = SCROLL_REGION_LEFT * scale
	var right: float = SCROLL_REGION_RIGHT * scale
	var top: float = SCROLL_REGION_TOP * scale
	var full_height: float = (SCROLL_REGION_BOTTOM - SCROLL_REGION_TOP) * scale
	var current_height: float = full_height * unfurl
	var full_rect := Rect2(Vector2(left, top), Vector2(right - left, full_height))
	var visible_rect := Rect2(full_rect.position, Vector2(full_rect.size.x, current_height))

	_draw_shadow_ellipse(
		Vector2(full_rect.get_center().x, visible_rect.end.y + 22.0 * scale),
		full_rect.size.x * 0.45,
		16.0 * scale,
		0.22 + 0.14 * unfurl
	)

	if _scroll_texture != null:
		var texture_size: Vector2 = _scroll_texture.get_size()
		var source_height: float = max(1.0, texture_size.y * unfurl)
		var source := Rect2(Vector2.ZERO, Vector2(texture_size.x, source_height))
		draw_texture_rect_region(_scroll_texture, visible_rect, source, Color.WHITE, false, true)
	else:
		_draw_cyber_scroll_fallback(visible_rect, scale, unfurl)

	if unfurl <= 0.58:
		_next_stage_button_rect = Rect2()
		_exit_button_rect = Rect2()
		return

	var content_alpha: float = _smooth01((unfurl - 0.58) / 0.42)
	_draw_cyber_scroll_contents(_get_scroll_content_rect(full_rect, scale), scale, font, content_alpha)


@warning_ignore("shadowed_variable_base_class")
func _draw_cyber_scroll_fallback(rect: Rect2, scale: float, alpha: float) -> void:
	var fill := Color(0.86, 0.98, 1.0, 0.76 * alpha)
	var border := Color(0.20, 0.92, 1.0, 0.88 * alpha)
	_draw_panel(rect, fill, border, max(2.0, 2.5 * scale), 18.0 * scale)
	var rod_height: float = 26.0 * scale
	var rod_color := Color(0.04, 0.08, 0.11, 0.94 * alpha)
	_draw_panel(Rect2(rect.position + Vector2(-18.0 * scale, -rod_height * 0.45), Vector2(rect.size.x + 36.0 * scale, rod_height)), rod_color, border, max(1.0, 1.5 * scale), 13.0 * scale)
	_draw_panel(Rect2(Vector2(rect.position.x - 18.0 * scale, rect.end.y - rod_height * 0.55), Vector2(rect.size.x + 36.0 * scale, rod_height)), rod_color, border, max(1.0, 1.5 * scale), 13.0 * scale)


@warning_ignore("shadowed_variable_base_class")
func _get_scroll_content_rect(scroll_rect: Rect2, scale: float) -> Rect2:
	return StageClearResultLayoutHelper.get_scroll_content_rect(scroll_rect, scale, SCROLL_CONTENT_MARGIN)


@warning_ignore("shadowed_variable_base_class")
func _draw_cyber_scroll_contents(rect: Rect2, scale: float, font: Font, alpha: float) -> void:
	if alpha <= 0.02:
		return
	var accent := Color(0.05, 0.54, 0.68, alpha)
	var muted := Color(0.20, 0.36, 0.42, alpha * 0.86)

	var header_rect := Rect2(rect.position, Vector2(rect.size.x, 58.0 * scale))
	_draw_centered_text(font, "스테이지 %d 결과" % current_stage, header_rect, int(round(42.0 * scale)), accent)
	var divider_y: float = rect.position.y + 68.0 * scale
	draw_line(
		Vector2(rect.position.x + 34.0 * scale, divider_y),
		Vector2(rect.position.x + rect.size.x - 34.0 * scale, divider_y),
		Color(0.03, 0.82, 0.96, alpha * 0.46),
		max(1.0, 1.4 * scale)
	)

	var stat_rect := Rect2(rect.position + Vector2(34.0 * scale, 92.0 * scale), Vector2(250.0, 78.0) * scale)
	_draw_metric_tile(font, stat_rect, "획득 골드", "%d G" % PLACEHOLDER_GOLD, muted, accent, alpha)
	var info_width: float = min(430.0 * scale, max(260.0 * scale, rect.size.x - 340.0 * scale))
	var info_rect := Rect2(
		Vector2(rect.end.x - 34.0 * scale - info_width, rect.position.y + 92.0 * scale),
		Vector2(info_width, 96.0 * scale)
	)
	_draw_perk_info_tile(font, info_rect, _build_perk_info_summary(), scale, alpha)

	var perks: Array = _build_perk_summary()
	var rewards: Array = _build_visible_reward_summary()
	var body_top: float = rect.position.y + 198.0 * scale
	var button_top: float = rect.position.y + rect.size.y - 90.0 * scale
	var body_rect := Rect2(
		Vector2(rect.position.x + 34.0 * scale, body_top),
		Vector2(rect.size.x - 68.0 * scale, max(150.0 * scale, button_top - body_top - 24.0 * scale))
	)
	if perks.is_empty() and rewards.is_empty():
		_draw_text(font, "획득 보상 없음", body_rect.position + Vector2(0.0, 30.0 * scale), int(round(20.0 * scale)), muted)
	elif not perks.is_empty() and not rewards.is_empty():
		var column_gap: float = 24.0 * scale
		var column_width: float = (body_rect.size.x - column_gap) * 0.5
		_draw_reward_section(
			font,
			"획득 퍽",
			perks,
			Rect2(body_rect.position, Vector2(column_width, body_rect.size.y)),
			scale,
			alpha
		)
		_draw_reward_section(
			font,
			"획득 보상",
			rewards,
			Rect2(body_rect.position + Vector2(column_width + column_gap, 0.0), Vector2(column_width, body_rect.size.y)),
			scale,
			alpha
		)
	elif not perks.is_empty():
		_draw_reward_section(font, "획득 퍽", perks, body_rect, scale, alpha)
	else:
		_draw_reward_section(font, "획득 보상", rewards, body_rect, scale, alpha)

	_draw_scroll_buttons(rect, scale, font, alpha)


func _draw_metric_tile(font: Font, rect: Rect2, title: String, value: String, title_color: Color, value_color: Color, alpha: float) -> void:
	_draw_panel(rect, Color(0.90, 0.98, 1.0, 0.22 * alpha), Color(0.04, 0.82, 0.96, 0.35 * alpha), 1.2, 10.0)
	_draw_text(font, title, rect.position + Vector2(16.0, 25.0) * (rect.size.y / 78.0), int(round(18.0 * rect.size.y / 78.0)), title_color)
	_draw_text(font, value, rect.position + Vector2(16.0, 61.0) * (rect.size.y / 78.0), int(round(30.0 * rect.size.y / 78.0)), value_color)


func _draw_perk_info_tile(font: Font, rect: Rect2, summary: Dictionary, ui_scale: float, alpha: float) -> void:
	var kind: String = str(summary.get("kind", "empty"))
	var border := Color(0.04, 0.82, 0.96, 0.40 * alpha)
	if kind == "perk":
		border = Color(0.30, 0.58, 1.0, 0.54 * alpha)
	elif kind == "starpoint":
		border = Color(1.0, 0.78, 0.28, 0.54 * alpha)
	_draw_panel(rect, Color(0.92, 0.98, 1.0, 0.24 * alpha), border, 1.2, 10.0 * ui_scale)

	var eyebrow: String = str(summary.get("eyebrow", "퍽 정보"))
	var title: String = str(summary.get("title", "획득 퍽 없음"))
	var detail: String = str(summary.get("detail", ""))
	var label_color := Color(0.16, 0.30, 0.36, alpha * 0.92)
	var title_color := Color(0.04, 0.24, 0.30, alpha)
	if kind == "starpoint":
		title_color = Color(0.42, 0.26, 0.02, alpha)
	elif kind == "perk":
		title_color = Color(0.04, 0.20, 0.44, alpha)

	_draw_text(font, eyebrow, rect.position + Vector2(14.0, 22.0) * ui_scale, int(round(15.0 * ui_scale)), label_color, 0.0)
	_draw_text(font, title, rect.position + Vector2(14.0, 48.0) * ui_scale, _fit_font_size(font, title, rect.size.x - 28.0 * ui_scale, int(round(22.0 * ui_scale)), int(round(13.0 * ui_scale))), title_color, 0.0)
	_draw_wrapped_text(
		font,
		detail,
		rect.position + Vector2(14.0, 72.0) * ui_scale,
		int(round(13.0 * ui_scale)),
		Color(0.18, 0.27, 0.30, alpha * 0.88),
		rect.size.x - 28.0 * ui_scale,
		2,
		15.0 * ui_scale,
		0.0
	)


@warning_ignore("shadowed_variable_base_class")
func _draw_reward_section(font: Font, title: String, rewards: Array, rect: Rect2, scale: float, alpha: float) -> float:
	var title_color := Color(0.20, 0.36, 0.42, alpha * 0.90)
	_draw_text(font, title, rect.position + Vector2(0.0, 24.0 * scale), int(round(22.0 * scale)), title_color)
	var layout: Dictionary = _calculate_reward_section_layout(rewards.size(), rect, scale)
	var gap: float = float(layout.get("gap", 16.0 * scale))
	var card_size: Vector2 = layout.get("card_size", Vector2(148.0, 112.0) * scale)
	var card_scale: float = float(layout.get("card_scale", scale))
	var columns: int = max(1, int(layout.get("columns", 1)))
	var rows: int = max(1, int(layout.get("rows", 1)))
	var cards_top: float = float(layout.get("cards_top", 38.0 * scale))
	for i in range(rewards.size()):
		var row: int = int(floor(float(i) / float(columns)))
		var col: int = i % columns
		var card_rect := Rect2(
			rect.position + Vector2(float(col) * (card_size.x + gap), cards_top + float(row) * (card_size.y + gap)),
			card_size
		)
		var reward: Dictionary = rewards[i] if rewards[i] is Dictionary else {}
		_draw_reward_card(font, reward, card_rect, card_scale, alpha)
	return rect.position.y + cards_top + float(max(1, rows)) * card_size.y + float(max(0, rows - 1)) * gap


func _calculate_reward_section_layout(reward_count: int, rect: Rect2, ui_scale: float) -> Dictionary:
	return StageClearResultLayoutHelper.calculate_reward_section_layout(reward_count, rect, ui_scale)


func _get_reward_section_columns(width: float, card_width: float, gap: float, max_columns: int) -> int:
	return StageClearResultLayoutHelper.get_reward_section_columns(width, card_width, gap, max_columns)


@warning_ignore("shadowed_variable_base_class")
func _draw_reward_card(font: Font, reward: Dictionary, rect: Rect2, scale: float, alpha: float) -> void:
	var reward_type: String = str(reward.get("type", ""))
	var base_color: Color = _get_reward_color(reward_type)
	base_color.a = 0.18 * alpha
	var border_color: Color = _get_reward_color(reward_type).lerp(Color(0.06, 0.84, 0.96, 1.0), 0.34)
	border_color.a = 0.78 * alpha
	_draw_panel(rect, base_color, border_color, max(1.0, 1.6 * scale), 8.0 * scale)
	var badge_rect := Rect2(rect.position + Vector2(8.0, 7.0) * scale, Vector2(58.0, 20.0) * scale)
	_draw_panel(badge_rect, Color(0.02, 0.08, 0.11, 0.64 * alpha), border_color, max(1.0, 1.0 * scale), 6.0 * scale)
	_draw_centered_text(font, _get_reward_badge(reward), badge_rect, int(round(10.0 * scale)), Color(0.86, 1.0, 1.0, alpha))
	_draw_reward_source_chip(font, reward, rect, scale, alpha)
	var icon_rect := Rect2(rect.position + Vector2(42.0, 30.0) * scale, Vector2(64.0, 54.0) * scale)
	_draw_reward_card_icon(reward, icon_rect, scale, alpha)
	var label_rect := Rect2(rect.position + Vector2(8.0, 84.0) * scale, Vector2(rect.size.x - 16.0 * scale, 22.0 * scale))
	var label_plate := label_rect.grow_individual(2.0 * scale, 0.0, 2.0 * scale, 0.0)
	_draw_panel(label_plate, Color(0.95, 0.99, 0.96, 0.44 * alpha), Color(0.0, 0.0, 0.0, 0.0), 0.0, 5.0 * scale)
	var label: String = _get_reward_title(reward)
	var label_size: int = _fit_font_size(font, label, label_rect.size.x, int(round(14.0 * scale)), int(round(9.0 * scale)))
	_draw_centered_text(font, label, label_rect, label_size, Color(0.04, 0.08, 0.10, alpha), 0.0)


@warning_ignore("shadowed_variable_base_class")
func _draw_reward_source_chip(font: Font, reward: Dictionary, rect: Rect2, scale: float, alpha: float) -> void:
	var source_key: String = str(reward.get("_result_reward_source", ""))
	var source_label: String = str(reward.get("_result_reward_source_label", ""))
	if source_label == "":
		source_label = _get_result_reward_source_label(source_key)
	if source_label == "":
		return
	var chip_size := Vector2(48.0, 20.0) * scale
	var chip_rect := Rect2(
		Vector2(rect.end.x - chip_size.x - 8.0 * scale, rect.position.y + 7.0 * scale),
		chip_size
	)
	var chip_color: Color = _get_result_reward_source_color(source_key)
	chip_color.a = 0.72 * alpha
	var chip_border: Color = chip_color.lerp(Color(0.86, 1.0, 1.0, 1.0), 0.46)
	chip_border.a = 0.76 * alpha
	_draw_panel(chip_rect, chip_color, chip_border, max(1.0, 1.0 * scale), 6.0 * scale)
	var font_size: int = _fit_font_size(font, source_label, chip_rect.size.x - 6.0 * scale, int(round(10.0 * scale)), int(round(7.0 * scale)))
	_draw_centered_text(font, source_label, chip_rect, font_size, Color(0.92, 1.0, 1.0, alpha), 0.0)


@warning_ignore("shadowed_variable_base_class")
func _draw_reward_card_icon(reward: Dictionary, rect: Rect2, scale: float, alpha: float) -> void:
	var reward_type: String = str(reward.get("type", ""))
	if reward_type == "starpoint":
		_draw_star_polygon(rect.get_center(), 25.0 * scale, 11.0 * scale, Color(1.0, 0.82, 0.24, alpha), Color(0.50, 0.28, 0.04, alpha), max(1.5, 1.8 * scale))
		return
	if _is_perk_reward(reward):
		var perk_id: String = _get_reward_perk_id(reward)
		if _perk_icon_renderer != null and _perk_icon_renderer.has_method("draw_icon") and bool(_perk_icon_renderer.draw_icon(self, perk_id, rect, alpha, true)):
			return
	var texture: Texture2D = _get_reward_icon_texture(reward)
	if texture != null:
		_draw_texture_fit(texture, rect, alpha)
	else:
		_draw_fallback_reward_icon(reward, rect, alpha)


func _draw_texture_fit(texture: Texture2D, rect: Rect2, alpha: float) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var scale_ratio: float = min(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
	var draw_size: Vector2 = texture_size * scale_ratio
	var icon_draw_rect := Rect2(rect.get_center() - draw_size * 0.5, draw_size)
	draw_texture_rect(texture, icon_draw_rect, false, Color(1.0, 1.0, 1.0, alpha))


func _draw_fallback_reward_icon(reward: Dictionary, rect: Rect2, alpha: float) -> void:
	var reward_type: String = str(reward.get("type", ""))
	var color: Color = _get_reward_color(reward_type)
	color.a = 0.84 * alpha
	draw_circle(rect.get_center(), min(rect.size.x, rect.size.y) * 0.42, color)
	draw_arc(rect.get_center(), min(rect.size.x, rect.size.y) * 0.42, 0.0, TAU, 28, Color(0.86, 1.0, 1.0, alpha * 0.80), 1.6)


func _get_reward_detail_text(reward: Dictionary) -> String:
	return StageClearResultRewardTextResolver.get_reward_detail_text(
		reward,
		_get_reward_perk_data(reward),
		_get_reward_detail_fallback_text()
	)


func _get_reward_detail_fallback_text() -> String:
	return "획득한 퍽 효과를 적용합니다."


func _get_reward_perk_data(reward: Dictionary) -> Dictionary:
	return StageClearResultRewardTextResolver.get_reward_perk_data(
		reward,
		_perk_catalog,
		_get_reward_perk_id(reward)
	)


func _get_reward_title(reward: Dictionary) -> String:
	var reward_type: String = str(reward.get("type", ""))
	if reward_type == "starpoint":
		return "퍽 선택권 +%d" % int(reward.get("amount", 0))
	return StageClearResultRewardTextResolver.get_reward_title(
		reward,
		_get_reward_perk_data(reward),
		_is_perk_reward(reward),
		_reward_type_fallback_label(reward_type)
	)


func _get_reward_badge(reward: Dictionary) -> String:
	return StageClearResultRewardVisualResolver.get_reward_badge(reward)


func _get_result_reward_source_label(source_key: String) -> String:
	match source_key:
		RESULT_REWARD_SOURCE_STAGE:
			return "인게임"
		RESULT_REWARD_SOURCE_BOX:
			return "상자"
	return ""


func _get_result_reward_source_labels() -> Dictionary:
	return {
		RESULT_REWARD_SOURCE_STAGE: _get_result_reward_source_label(RESULT_REWARD_SOURCE_STAGE),
		RESULT_REWARD_SOURCE_BOX: _get_result_reward_source_label(RESULT_REWARD_SOURCE_BOX),
	}


func _get_result_reward_source_color(source_key: String) -> Color:
	return StageClearResultRewardVisualResolver.get_result_reward_source_color(
		source_key,
		RESULT_REWARD_SOURCE_STAGE,
		RESULT_REWARD_SOURCE_BOX
	)


@warning_ignore("shadowed_variable_base_class")
func _draw_scroll_buttons(rect: Rect2, scale: float, font: Font, alpha: float) -> void:
	var button_size := Vector2(280.0, 64.0) * scale
	var gap: float = 28.0 * scale
	var total_width: float = button_size.x * 2.0 + gap
	var start_x: float = rect.position.x + (rect.size.x - total_width) * 0.5
	var button_y: float = rect.position.y + rect.size.y - 90.0 * scale

	var next_rect := Rect2(Vector2(start_x, button_y), button_size)
	var exit_rect := Rect2(Vector2(start_x + button_size.x + gap, button_y), button_size)
	_next_stage_button_rect = next_rect
	_exit_button_rect = exit_rect

	var clickable: bool = _scroll_phase == "visible"

	var next_hovered: bool = clickable and _hovered_button == "next_stage"
	var next_fill := Color(0.02, 0.78, 0.88, alpha * 0.86)
	var next_border := Color(0.72, 1.0, 1.0, alpha * 0.95)
	if next_hovered:
		next_fill = next_fill.lerp(Color(1.0, 1.0, 1.0, alpha), 0.20)
		next_border = Color(0.92, 1.0, 1.0, alpha)
	_draw_panel(next_rect, next_fill, next_border, max(1.5, 2.4 * scale), 14.0 * scale)
	_draw_centered_text(font, "다음 스테이지", next_rect, int(round(26.0 * scale)), Color(0.02, 0.06, 0.08, alpha))

	var exit_hovered: bool = clickable and _hovered_button == "exit"
	var exit_fill := Color(0.06, 0.07, 0.12, alpha * 0.92)
	var exit_border := Color(0.82, 0.28, 0.86, alpha * 0.82)
	var exit_text_color := Color(0.88, 0.98, 1.0, alpha)
	if exit_hovered:
		exit_fill = exit_fill.lerp(Color(0.22, 0.08, 0.28, alpha), 0.32)
		exit_border = Color(1.0, 0.48, 0.96, alpha)
		exit_text_color = Color(1.0, 0.96, 1.0, alpha)
	_draw_panel(exit_rect, exit_fill, exit_border, max(1.5, 2.0 * scale), 14.0 * scale)
	_draw_centered_text(font, "나가기", exit_rect, int(round(26.0 * scale)), exit_text_color)


@warning_ignore("shadowed_variable_base_class")
func _draw_footer(view_size: Vector2, scale: float, font: Font) -> void:
	_draw_text(
		font,
		"스테이지 %d 결과 화면" % current_stage,
		Vector2(34.0, view_size.y - 26.0 * scale),
		int(round(24.0 * scale)),
		Color(0.86, 0.88, 1.0, 0.82)
	)


func _get_title_text() -> String:
	if boss_score == 0:
		return "%d:%d 완승" % [player_score, boss_score]
	if boss_score <= 1:
		return "%d:%d 압도 승리" % [player_score, boss_score]
	return "%d:%d 승리" % [player_score, boss_score]


func _update_hovered_box(mouse_position: Vector2) -> void:
	if _boxes.is_empty():
		_hovered_box_index = -1
		return
	@warning_ignore("shadowed_variable_base_class")
	var scale: float = _get_layout_scale(size)
	var previous: int = _hovered_box_index
	var found: int = -1
	for i in range(_boxes.size() - 1, -1, -1):
		var box: Dictionary = _boxes[i] if _boxes[i] is Dictionary else {}
		if _get_box_aabb(box, scale).has_point(mouse_position):
			found = i
			break
	_hovered_box_index = found
	if previous != _hovered_box_index:
		queue_redraw()


func _handle_player_victory_click(mouse_position: Vector2) -> bool:
	var view_size: Vector2 = size
	if view_size == Vector2.ZERO:
		view_size = _get_view_size()
	@warning_ignore("shadowed_variable_base_class")
	var scale: float = _get_layout_scale(view_size)
	var click_rect: Rect2 = _get_player_victory_click_rect(view_size, scale)
	_player_victory_click_rect = click_rect
	if not click_rect.has_point(mouse_position):
		return false
	if _is_player_victory_click_reaction_active():
		queue_redraw()
		return true
	_player_victory_click_transition_base_frame = _get_player_victory_base_frame()
	_player_victory_click_reaction_timer = 0.0
	queue_redraw()
	return true


func _handle_dalji_click(mouse_position: Vector2) -> bool:
	var view_size: Vector2 = size
	if view_size == Vector2.ZERO:
		view_size = _get_view_size()
	@warning_ignore("shadowed_variable_base_class")
	var scale: float = _get_layout_scale(view_size)
	var click_rect: Rect2 = _get_dalji_draw_rect(view_size, scale)
	_dalji_click_rect = click_rect
	if not click_rect.has_point(mouse_position):
		return false
	if _is_dalji_click_reaction_active():
		_dalji_dialogue_timer = DALJI_CLICK_DIALOGUE_DURATION
		_play_dalji_click_voice()
		queue_redraw()
		return true
	_dalji_click_transition_base_frame = _get_dalji_base_frame()
	_dalji_click_reaction_timer = 0.0
	_dalji_dialogue_timer = DALJI_CLICK_DIALOGUE_DURATION
	_play_dalji_click_voice()
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


func _draw_player_victory_sheet_frame(sheet: Texture2D, frame: int, rect: Rect2, alpha: float) -> void:
	if sheet == null or alpha <= 0.001:
		return
	var source: Rect2 = _sheet_source_rect(frame, PLAYER_VICTORY_GRID_COLS, PLAYER_VICTORY_CELL_SIZE)
	draw_texture_rect_region(sheet, rect, source, Color(1.0, 1.0, 1.0, alpha), false, true)


func _get_player_victory_base_frame() -> int:
	return StageClearResultClickReactionState.get_base_frame(
		timer,
		PLAYER_VICTORY_FRAME_INTERVAL,
		PLAYER_VICTORY_FRAME_COUNT
	)


func _get_player_victory_reaction_frame() -> int:
	return StageClearResultClickReactionState.get_reaction_frame(
		_player_victory_click_reaction_timer,
		PLAYER_VICTORY_CLICK_REACTION_DURATION,
		PLAYER_VICTORY_CLICK_FRAME_INTERVAL,
		PLAYER_VICTORY_FRAME_COUNT
	)


func _get_player_victory_transition_base_frame() -> int:
	return StageClearResultClickReactionState.get_transition_base_frame(
		_player_victory_click_reaction_timer,
		PLAYER_VICTORY_CLICK_TRANSITION_DURATION,
		_player_victory_click_transition_base_frame,
		_get_player_victory_base_frame()
	)


func _get_player_victory_reaction_alpha() -> float:
	return StageClearResultClickReactionState.get_reaction_alpha(
		_player_victory_click_reaction_timer,
		PLAYER_VICTORY_CLICK_REACTION_DURATION,
		PLAYER_VICTORY_CLICK_TRANSITION_DURATION,
		PLAYER_VICTORY_CLICK_RETURN_HOLD_DURATION,
		PLAYER_VICTORY_CLICK_RETURN_FADE_DURATION,
		PLAYER_VICTORY_CLICK_TOTAL_DURATION
	)


func _is_player_victory_click_reaction_active() -> bool:
	return StageClearResultClickReactionState.is_reaction_active(
		_player_victory_click_reaction_timer,
		PLAYER_VICTORY_CLICK_TOTAL_DURATION
	)


func _is_player_victory_click_return_blend_active() -> bool:
	return StageClearResultClickReactionState.is_return_blend_active(
		_player_victory_click_reaction_timer,
		PLAYER_VICTORY_CLICK_REACTION_DURATION,
		PLAYER_VICTORY_CLICK_TOTAL_DURATION
	)


func _draw_dalji_sheet_frame(sheet: Texture2D, frame: int, rect: Rect2, alpha: float) -> void:
	if sheet == null or alpha <= 0.001:
		return
	var source: Rect2 = _sheet_source_rect(frame, DALJI_GRID_COLS, DALJI_CELL_SIZE)
	draw_texture_rect_region(sheet, rect, source, Color(1.0, 1.0, 1.0, alpha), false, true)


func _get_dalji_base_frame() -> int:
	return StageClearResultClickReactionState.get_base_frame(
		_dalji_base_timer,
		DALJI_FRAME_INTERVAL,
		DALJI_FRAME_COUNT
	)


func _get_dalji_reaction_frame() -> int:
	return StageClearResultClickReactionState.get_reaction_frame(
		_dalji_click_reaction_timer,
		DALJI_CLICK_REACTION_DURATION,
		DALJI_CLICK_FRAME_INTERVAL,
		DALJI_FRAME_COUNT
	)


func _get_dalji_transition_base_frame() -> int:
	return StageClearResultClickReactionState.get_transition_base_frame(
		_dalji_click_reaction_timer,
		DALJI_CLICK_TRANSITION_DURATION,
		_dalji_click_transition_base_frame,
		_get_dalji_base_frame()
	)


func _get_dalji_reaction_alpha() -> float:
	return StageClearResultClickReactionState.get_reaction_alpha(
		_dalji_click_reaction_timer,
		DALJI_CLICK_REACTION_DURATION,
		DALJI_CLICK_TRANSITION_DURATION,
		DALJI_CLICK_RETURN_HOLD_DURATION,
		DALJI_CLICK_RETURN_FADE_DURATION,
		DALJI_CLICK_TOTAL_DURATION
	)


func _is_dalji_click_reaction_active() -> bool:
	return StageClearResultClickReactionState.is_reaction_active(
		_dalji_click_reaction_timer,
		DALJI_CLICK_TOTAL_DURATION
	)


func _is_dalji_click_return_blend_active() -> bool:
	return StageClearResultClickReactionState.is_return_blend_active(
		_dalji_click_reaction_timer,
		DALJI_CLICK_REACTION_DURATION,
		DALJI_CLICK_TOTAL_DURATION
	)


func _smooth01(value: float) -> float:
	var t: float = clamp(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


@warning_ignore("shadowed_variable_base_class")
func _get_dalji_draw_rect(view_size: Vector2, scale: float) -> Rect2:
	return StageClearResultLayoutHelper.get_dalji_draw_rect(view_size, scale)


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
		"summary": "확정 신화 아이템 + 일반 아이템 2개",
		"boxes": [
			{"kind": "mythic"},
			{"kind": "normal"},
			{"kind": "normal"},
		],
		"reward_count": 3,
	}


func _sheet_source_rect(frame: int, grid_cols: int, cell_size: Vector2) -> Rect2:
	return StageClearResultLayoutHelper.sheet_source_rect(frame, grid_cols, cell_size)


func _cover_source_rect(texture_size: Vector2, target_size: Vector2) -> Rect2:
	return StageClearResultLayoutHelper.cover_source_rect(texture_size, target_size)


func _draw_panel(rect: Rect2, fill_color: Color, border_color: Color, border_width: float, corner_radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	var width: int = max(0, int(round(border_width)))
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.border_color = border_color
	var radius: int = max(0, int(round(corner_radius)))
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	draw_style_box(style, rect)


func _draw_text(font: Font, text: String, baseline: Vector2, font_size: int, color: Color, shadow_alpha: float = 0.62) -> void:
	if shadow_alpha > 0.001:
		draw_string(font, baseline + Vector2(2.0, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * shadow_alpha))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_centered_text(font: Font, text: String, rect: Rect2, font_size: int, color: Color, shadow_alpha: float = 0.62) -> void:
	_draw_text(
		font,
		text,
		StageClearResultTextLayoutHelper.get_centered_baseline(font, text, rect, font_size),
		font_size,
		color,
		shadow_alpha
	)


func _draw_wrapped_text(
	font: Font,
	text: String,
	baseline: Vector2,
	font_size: int,
	color: Color,
	max_width: float,
	max_lines: int,
	line_height: float,
	shadow_alpha: float = 0.62
) -> void:
	if text == "" or max_width <= 0.0 or max_lines <= 0:
		return
	var lines: Array[String] = _wrap_words_to_width(font, text, font_size, max_width, max_lines)
	for i in range(lines.size()):
		var line: String = str(lines[i])
		var fitted_size: int = _fit_font_size(font, line, max_width, font_size, max(9, int(round(font_size * 0.76))))
		_draw_text(font, line, baseline + Vector2(0.0, float(i) * line_height), fitted_size, color, shadow_alpha)


func _wrap_words_to_width(font: Font, text: String, font_size: int, max_width: float, max_lines: int) -> Array[String]:
	return StageClearResultTextLayoutHelper.wrap_words_to_width(font, text, font_size, max_width, max_lines)


func _fit_font_size(font: Font, text: String, max_width: float, preferred_size: int, min_size: int) -> int:
	return StageClearResultTextLayoutHelper.fit_font_size(font, text, max_width, preferred_size, min_size)


func _load_textures() -> void:
	if _background_texture == null:
		_background_texture = ProjectResourceLoader.load_texture(
			STAGE1_BACKGROUND_PATH,
			"Missing Stage 1 result background at %s",
			"Failed to load Stage 1 result background at %s"
		)
	if _dalji_defeat_sheet == null:
		_dalji_defeat_sheet = ProjectResourceLoader.load_texture(
			DALJI_DEFEAT_SHEET_PATH,
			"Missing Dalji result defeat sheet at %s",
			"Failed to load Dalji result defeat sheet at %s"
		)
	if _dalji_click_reaction_sheet == null:
		_dalji_click_reaction_sheet = ProjectResourceLoader.load_texture(
			DALJI_CLICK_REACTION_SHEET_PATH,
			"Missing Dalji result click reaction sheet at %s",
			"Failed to load Dalji result click reaction sheet at %s"
		)
	if _player_victory_sheet == null:
		_player_victory_sheet = ProjectResourceLoader.load_texture(
			SMASHER_VICTORY_SHEET_PATH,
			"Missing player victory sheet at %s",
			"Failed to load player victory sheet at %s"
		)
	if _player_victory_click_reaction_sheet == null:
		_player_victory_click_reaction_sheet = ProjectResourceLoader.load_texture(
			SMASHER_CLICK_REACTION_SHEET_PATH,
			"Missing player victory click reaction sheet at %s",
			"Failed to load player victory click reaction sheet at %s"
		)
	if _scroll_texture == null:
		_scroll_texture = ProjectResourceLoader.load_texture(
			RESULT_SCROLL_PANEL_PATH,
			"Missing stage clear cyber scroll panel at %s",
			"Failed to load stage clear cyber scroll panel at %s"
		)
	if _result_box_sheet_common == null:
		_result_box_sheet_common = ProjectResourceLoader.load_texture(
			RESULT_BOX_SHEET_COMMON_PATH,
			"Missing result box common sheet at %s",
			"Failed to load result box common sheet at %s"
		)
	if _result_box_sheet_mythic == null:
		_result_box_sheet_mythic = ProjectResourceLoader.load_texture(
			RESULT_BOX_SHEET_MYTHIC_PATH,
			"Missing result box mythic sheet at %s",
			"Failed to load result box mythic sheet at %s"
		)


func _load_audio() -> void:
	if _dalji_click_voice_stream != null:
		return
	_dalji_click_voice_stream = ProjectResourceLoader.load_audio_stream(
		DALJI_CLICK_VOICE_PATH,
		"Missing Dalji result click cry voice at %s",
		"Failed to load Dalji result click cry voice at %s"
	)


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
