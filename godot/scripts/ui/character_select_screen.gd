@tool
extends Control

signal character_confirmed(character_id: String, runtime_character_id: String)
signal back_requested

const CharacterSelectData := preload("res://scripts/ui/character_select_data.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ConfirmFlashOverlay := preload("res://scripts/ui/character_select_confirm_flash_overlay.gd")
const MotionConfigBuilder := preload("res://scripts/ui/character_select_motion_config_builder.gd")
const BgmMuteState := preload("res://scripts/audio/bgm_mute_state.gd")
const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const CharacterSelectLayout := preload("res://scripts/ui/character_select_layout.gd")
const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const BattleEntryBackgroundPrewarm := preload("res://scripts/ui/battle_entry_background_prewarm.gd")
const LingpetRingCoreRules := preload("res://scripts/lingpet/lingpet_ring_core_rules.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const PremiumPanelFrame := preload("res://scripts/hud/premium_panel_frame.gd")
const CharacterSelectPreviewVfxHost := preload("res://scripts/ui/character_select_preview_vfx_host.gd")

const CHARACTER_SELECT_BGM_PATH := "res://assets/bgm/character select.wav"
const BGM_BUS_NAME := "BGM"
const BGM_TOGGLE_KEY := KEY_B
const FULL_BODY_LIVE2D_RENA_FLOOR_Y_RATIO := 0.902
const LOCKED_CHARACTER_FEEDBACK_DURATION := 1.4
const DEFAULT_LEAGUE_MODE := "junior"
const LEAGUE_BUTTONS := [
	{"mode": "junior"},
	{"mode": "champion"},
	{"mode": "limit"},
	{"mode": "mythic"},
]
const CHARACTER_SELECT_RING_CORE_TIER := 0

# Slice A editorial chrome (D1): chrome stays neutral dark; character accent
# colors appear only on state elements (selected card, confirm CTA, brackets).
const CHROME_BG_BASE := Color(0.010, 0.011, 0.014, 1.0)
const CHROME_BG_UPPER := Color(0.017, 0.019, 0.025, 0.94)
const CHROME_BG_LOWER := Color(0.008, 0.009, 0.012, 0.97)
const CHROME_GRID := Color(0.44, 0.48, 0.56, 0.040)
const CHROME_SCAN := Color(0.44, 0.48, 0.56, 0.020)
const CHROME_HAIRLINE := Color(0.55, 0.58, 0.66, 0.22)
const CHROME_PANEL_FILL := Color(0.021, 0.023, 0.029, 0.93)
const CHROME_PANEL_BORDER := Color(0.46, 0.50, 0.58, 0.30)
const CHROME_MICROTEXT := Color(0.52, 0.56, 0.64, 0.52)
const CHROME_DIAG_CUT := 16.0

@export var battle_scene_path: String = "res://scenes/main.tscn"
@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/main_menu.tscn"
@export var auto_start_battle: bool = true

var characters: Array = []
var visible_indices: Array = []
var portrait_textures: Dictionary = {}
var selected_index: int = 0
var hovered_index: int = -1
var hovered_skill_index: int = -1
var hover_lifts: Array = []
var hover_scales: Array = []
var card_rects: Dictionary = {}
var skill_icon_rects: Dictionary = {}
var skill_icon_textures: Dictionary = {}
var skill_config_instances: Dictionary = {}
var full_body_live2d_textures: Dictionary = {}
var full_body_live2d_still_textures: Dictionary = {}
var confirm_rect := Rect2()
var back_rect := Rect2()
var junior_rect := Rect2()
var champion_rect := Rect2()
var limit_rect := Rect2()
var mythic_rect := Rect2()
var language_rect := Rect2()
var preview_rect_cache := Rect2()
var animation_time: float = 0.0
var preview: Control = null
var selected_league_mode: String = DEFAULT_LEAGUE_MODE
var _lingpet_ring_core_icon_renderer: Object = RuntimePerkIconRenderer.new()
# Diagonal-cut panel outlines are cached per rect so _draw does not rebuild
# point arrays every frame; the cache resets when the view size changes.
var _diag_panel_point_cache: Dictionary = {}
var _diag_panel_cache_view_size := Vector2.ZERO
# Roster cards use a softer large-radius box than the shared PremiumPanelFrame
# kinds — one mutable instance, reconfigured per draw (same pattern).
var _roster_card_box: StyleBoxFlat = null
# Rail holo-stage intensity envelope anchor (Tween-equivalent on the shared
# animation clock — re-arms on every roster switch).
var _rail_stage_switch_at: float = -10.0

var character_select_bgm_player: AudioStreamPlayer = null
var character_select_bgm_loop_enabled: bool = false
var character_select_bgm_muted: bool = false
var click_motion_voice_player: AudioStreamPlayer = null
var click_motion_voice_pending: bool = false
var click_motion_voice_delay_remaining: float = 0.0

var confirm_intro_voice_player: AudioStreamPlayer = null
var confirm_intro_voice_pending: bool = false
var confirm_intro_voice_delay_remaining: float = 0.0
var confirm_intro_active: bool = false
var confirm_intro_character: Dictionary = {}
var confirm_intro_elapsed: float = 0.0
var confirm_intro_pending_scene_path: String = ""
var confirm_intro_exit_flash_pending: bool = false
var confirm_intro_exit_flash_hold_remaining: float = 0.0
var confirm_intro_exit_flash_started: bool = false
var confirm_intro_exit_flash_overlay: Control = null
var gamepad_menu_horizontal_latch: int = 0
var gamepad_menu_vertical_latch: int = 0
var locked_character_feedback_timer: float = 0.0
var entry_background_prewarm: Object = BattleEntryBackgroundPrewarm.new()
# Slice H: the backdrop VFX host is adopted out of the LivePreview clip and
# runs fullscreen as this screen's own negative-z child.
var _backdrop_host: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_ensure_cache_dictionaries()
	characters = LanguageSettings.localize_character_list(CharacterSelectData.get_characters())
	_refresh_visible_indices()
	_load_selection_state()
	_prepare_hover_state()
	_prewarm_lingpet_ring_core_icons()
	_load_portraits()
	_restore_character_select_bgm_muted()
	preview = get_node_or_null("LivePreview")
	if preview != null:
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var one_shot_callback := Callable(self, "_on_preview_one_shot_finished")
		if preview.has_signal("one_shot_finished") and not preview.is_connected("one_shot_finished", one_shot_callback):
			preview.connect("one_shot_finished", one_shot_callback)
		_adopt_backdrop_host()
	_setup_audio_players()
	_setup_confirm_flash_overlay()
	_sync_preview()
	_update_preview_layout()
	queue_redraw()

func _prewarm_lingpet_ring_core_icons() -> void:
	if Engine.is_editor_hint() or _lingpet_ring_core_icon_renderer == null:
		return
	for tier in range(1, LingpetRingCoreRules.MAX_RING_CORE_TIER + 1):
		_lingpet_ring_core_icon_renderer.has_icon("lingpet_ring_core_upgrade_tier_%d" % tier)


func _exit_tree() -> void:
	set_process(false)
	character_select_bgm_loop_enabled = false
	_stop_click_motion_voice()
	_stop_confirm_intro_voice()
	_dispose_audio_player(
		character_select_bgm_player,
		Callable(self, "_on_character_select_bgm_finished")
	)
	character_select_bgm_player = null
	_dispose_audio_player(click_motion_voice_player)
	click_motion_voice_player = null
	_dispose_audio_player(confirm_intro_voice_player)
	confirm_intro_voice_player = null
	if confirm_intro_exit_flash_overlay != null:
		var flash_finished_callback := Callable(self, "_on_confirm_intro_exit_flash_finished")
		if confirm_intro_exit_flash_overlay.has_signal("finished") and confirm_intro_exit_flash_overlay.is_connected("finished", flash_finished_callback):
			confirm_intro_exit_flash_overlay.disconnect("finished", flash_finished_callback)
		if confirm_intro_exit_flash_overlay.has_method("cancel"):
			confirm_intro_exit_flash_overlay.call("cancel")
		confirm_intro_exit_flash_overlay = null
	if preview != null:
		var one_shot_callback := Callable(self, "_on_preview_one_shot_finished")
		if preview.has_signal("one_shot_finished") and preview.is_connected("one_shot_finished", one_shot_callback):
			preview.disconnect("one_shot_finished", one_shot_callback)
		if preview.has_method("clear_runtime_state"):
			preview.call("clear_runtime_state")
	preview = null
	characters.clear()
	visible_indices.clear()
	hover_lifts.clear()
	hover_scales.clear()
	portrait_textures.clear()
	skill_icon_textures.clear()
	full_body_live2d_textures.clear()
	full_body_live2d_still_textures.clear()
	card_rects.clear()
	skill_icon_rects.clear()
	skill_config_instances.clear()
	confirm_intro_character.clear()
	_lingpet_ring_core_icon_renderer = null
	if entry_background_prewarm != null and entry_background_prewarm.has_method("clear_runtime_state"):
		entry_background_prewarm.clear_runtime_state()
	entry_background_prewarm = null


func _process(delta: float) -> void:
	animation_time += delta
	if locked_character_feedback_timer > 0.0:
		locked_character_feedback_timer = maxf(0.0, locked_character_feedback_timer - delta)
	_update_hover_from_mouse(get_local_mouse_position())
	_update_hover_animation(delta)
	_update_preview_layout()
	_update_click_motion_voice(delta)
	_update_confirm_intro(delta)
	_update_entry_background_prewarm()
	queue_redraw()


# Menu-idle background prewarm: fills the static texture cache with the battle
# entry assets for the selected character + entry stage (battle textures /
# pillar backplates / stage-clear result sheets) so the entry loading screen's
# threaded waits become instant cache hits. Paused during the confirm intro so
# the cinematic and the battle scene change keep the IO worker to themselves.
func _update_entry_background_prewarm() -> void:
	if Engine.is_editor_hint() or confirm_intro_active:
		return
	if entry_background_prewarm == null or not entry_background_prewarm.has_method("update"):
		return
	entry_background_prewarm.update(_selected_character_runtime_type(), _selected_entry_stage_id())


# Mirrors battle_scene_selection_startup_lifecycle.apply_selection_state: the
# battle boot's entry stage comes from GameSelectionState.stage_id, so the
# background prewarm must target the same stage or it warms the wrong assets.
func _selected_entry_stage_id() -> int:
	var state: Node = get_node_or_null("/root/GameSelectionState")
	if state != null and state.has_method("get_selection"):
		var selection: Dictionary = state.get_selection()
		return max(1, int(selection.get("stage_id", 1)))
	return 1


func _selected_character_runtime_type() -> String:
	if selected_index >= 0 and selected_index < characters.size():
		var character_value: Variant = characters[selected_index]
		if character_value is Dictionary:
			var character: Dictionary = character_value
			var runtime_id := str(character.get("runtime_id", ""))
			if runtime_id != "":
				return runtime_id
			var character_id := str(character.get("id", ""))
			if character_id != "":
				return character_id
	return "smasher"


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseMotion:
		_update_hover_from_mouse(event.position)
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var pos := mouse_event.position
	if confirm_intro_active:
		accept_event()
		return
	language_rect = _language_button_rect(_resolved_view_size())
	if language_rect.has_point(pos):
		_cycle_language()
		accept_event()
		return
	if confirm_rect.has_point(pos):
		_confirm_selection()
		accept_event()
		return
	if junior_rect.has_point(pos):
		_select_league_mode("junior")
		accept_event()
		return
	if champion_rect.has_point(pos):
		_select_league_mode("champion")
		accept_event()
		return
	if limit_rect.has_point(pos):
		_select_league_mode("limit")
		accept_event()
		return
	if mythic_rect.has_point(pos):
		_select_league_mode("mythic")
		accept_event()
		return
	if back_rect.has_point(pos):
		_go_back()
		accept_event()
		return
	if preview_rect_cache.has_point(pos) and selected_index >= 0 and selected_index < characters.size():
		_play_preview_click_motion(characters[selected_index])
		accept_event()
		return
	for idx in card_rects.keys():
		var card_rect: Rect2 = card_rects[idx]
		if card_rect.has_point(pos):
			_select_index(int(idx))
			if mouse_event.double_click:
				_confirm_selection()
			accept_event()
			return


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if _handle_bgm_toggle_input(event):
		return
	if GamepadInput.is_gamepad_event(event):
		_handle_gamepad_unhandled_input(event)
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if confirm_intro_active:
		if is_inside_tree() and get_viewport() != null:
			get_viewport().set_input_as_handled()
		return
	match key_event.keycode:
		KEY_LEFT, KEY_A, KEY_UP, KEY_W:
			_move_selection(-1)
			if is_inside_tree() and get_viewport() != null:
				get_viewport().set_input_as_handled()
		KEY_RIGHT, KEY_D, KEY_DOWN, KEY_S:
			_move_selection(1)
			if is_inside_tree() and get_viewport() != null:
				get_viewport().set_input_as_handled()
		KEY_TAB:
			_cycle_league_mode(-1 if key_event.shift_pressed else 1)
			if is_inside_tree() and get_viewport() != null:
				get_viewport().set_input_as_handled()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_confirm_selection()
			if is_inside_tree() and get_viewport() != null:
				get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_go_back()
			if is_inside_tree() and get_viewport() != null:
				get_viewport().set_input_as_handled()


func _handle_gamepad_unhandled_input(event: InputEvent) -> void:
	if GamepadInput.should_suppress_right_stick_event(event):
		if is_inside_tree() and get_viewport() != null:
			get_viewport().set_input_as_handled()
		return
	if confirm_intro_active:
		if is_inside_tree() and get_viewport() != null:
			get_viewport().set_input_as_handled()
		return
	var horizontal_direction: int = GamepadInput.get_menu_horizontal_event(event)
	var vertical_direction: int = GamepadInput.get_menu_vertical_event(event)
	var navigation_direction := _get_gamepad_character_navigation_direction(
		event,
		horizontal_direction,
		vertical_direction
	)
	if navigation_direction != 0:
		_move_selection(navigation_direction)
		if is_inside_tree() and get_viewport() != null:
			get_viewport().set_input_as_handled()
		return
	var league_direction: int = GamepadInput.get_tab_direction_event(event)
	if league_direction != 0:
		_cycle_league_mode(league_direction)
		if is_inside_tree() and get_viewport() != null:
			get_viewport().set_input_as_handled()
		return
	if GamepadInput.is_confirm_event(event):
		_confirm_selection()
		if is_inside_tree() and get_viewport() != null:
			get_viewport().set_input_as_handled()
		return
	if GamepadInput.is_cancel_event(event):
		_go_back()
		if is_inside_tree() and get_viewport() != null:
			get_viewport().set_input_as_handled()


func _get_gamepad_character_navigation_direction(
	event: InputEvent,
	horizontal_direction: int,
	vertical_direction: int
) -> int:
	if event is InputEventJoypadMotion:
		return _consume_gamepad_axis_navigation(event as InputEventJoypadMotion, horizontal_direction, vertical_direction)
	if horizontal_direction != 0:
		return horizontal_direction
	return vertical_direction


func _consume_gamepad_axis_navigation(
	motion_event: InputEventJoypadMotion,
	horizontal_direction: int,
	vertical_direction: int
) -> int:
	if motion_event.axis == JOY_AXIS_LEFT_X:
		return _consume_gamepad_axis_latch(motion_event.axis_value, horizontal_direction, true)
	if motion_event.axis == JOY_AXIS_LEFT_Y:
		return _consume_gamepad_axis_latch(motion_event.axis_value, vertical_direction, false)
	if horizontal_direction != 0:
		return horizontal_direction
	return vertical_direction


func _consume_gamepad_axis_latch(axis_value: float, direction: int, horizontal: bool) -> int:
	if absf(axis_value) <= GamepadInput.MENU_AXIS_RELEASE_THRESHOLD:
		if horizontal:
			gamepad_menu_horizontal_latch = 0
		else:
			gamepad_menu_vertical_latch = 0
		return 0
	if direction == 0:
		return 0
	var current_latch := gamepad_menu_horizontal_latch if horizontal else gamepad_menu_vertical_latch
	if current_latch == direction:
		return 0
	if horizontal:
		gamepad_menu_horizontal_latch = direction
	else:
		gamepad_menu_vertical_latch = direction
	return direction


func _draw() -> void:
	_ensure_cache_dictionaries()
	var view_size := _resolved_view_size()
	var preview_rect_value := _preview_rect(view_size)
	_draw_background(view_size, _backdrop_fullscreen_active())
	_draw_header(view_size)
	var card_column := _card_column_rect(view_size)
	var info_rect := _info_panel_rect(view_size, preview_rect_value)
	_draw_card_column(card_column)
	_draw_preview_frame(preview_rect_value)
	_draw_info_panel(info_rect)
	_draw_full_body_rail(view_size)
	_draw_action_bar(view_size)
	_draw_skill_hover_tooltip(view_size)


func _resolved_view_size() -> Vector2:
	if size.x > 1.0 and size.y > 1.0:
		return size
	if is_inside_tree() and get_viewport() != null:
		return get_viewport_rect().size
	return Vector2(1920.0, 1080.0)


func _backdrop_fullscreen_active() -> bool:
	# Slice H: the adopted fullscreen VFX host renders at negative canvas z
	# (behind this control's own _draw). While it is live the screen must NOT
	# paint any opaque background — a full fill would bury the entire backdrop
	# (§3-1 variant of the hole-punch trap, now fullscreen-shaped).
	return preview != null and preview.has_method("is_backdrop_host_active") and bool(preview.call("is_backdrop_host_active"))


func _refresh_visible_indices() -> void:
	visible_indices.clear()
	for i in range(characters.size()):
		var character_value: Variant = characters[i]
		if character_value is Dictionary:
			visible_indices.append(i)
	if visible_indices.is_empty():
		selected_index = -1
		return
	if not visible_indices.has(selected_index) or not _is_character_unlocked(characters[selected_index]):
		selected_index = _first_unlocked_visible_index()


func _load_selection_state() -> void:
	var state: Node = get_node_or_null("/root/GameSelectionState")
	if state == null or not state.has_method("get_selection"):
		return
	var selection: Dictionary = state.get_selection()
	selected_league_mode = _normalize_league_mode(str(selection.get("league_mode", DEFAULT_LEAGUE_MODE)))
	var desired_id := str(selection.get("character_id", ""))
	var desired_runtime_id := str(selection.get("runtime_character_id", ""))
	for i in range(characters.size()):
		var character: Dictionary = characters[i]
		if str(character.get("id", "")) == desired_id and _is_character_unlocked(character):
			selected_index = i
			return
	for i in range(characters.size()):
		var character: Dictionary = characters[i]
		if str(character.get("runtime_id", "")) == desired_runtime_id and _is_character_unlocked(character):
			selected_index = i
			return


func _first_unlocked_visible_index() -> int:
	for visible_index in visible_indices:
		var index := int(visible_index)
		if index < 0 or index >= characters.size():
			continue
		var character_value: Variant = characters[index]
		if character_value is Dictionary:
			var character: Dictionary = character_value
			if _is_character_unlocked(character):
				return index
	return int(visible_indices[0]) if not visible_indices.is_empty() else -1


func _is_character_unlocked(character: Dictionary) -> bool:
	return bool(character.get("unlocked", false))


func _prepare_hover_state() -> void:
	hover_lifts.resize(characters.size())
	hover_scales.resize(characters.size())
	for i in range(characters.size()):
		hover_lifts[i] = 0.0
		hover_scales[i] = 1.0


func _load_portraits() -> void:
	_ensure_cache_dictionaries()
	portrait_textures.clear()
	full_body_live2d_textures.clear()
	full_body_live2d_still_textures.clear()
	for i in range(characters.size()):
		var character: Dictionary = characters[i]
		var path := str(character.get("portrait_path", ""))
		if path != "":
			var texture := ProjectResourceLoader.load_texture(
				path,
				"Missing character-select portrait: %s",
				"Failed to load character-select portrait: %s"
			)
			if texture != null:
				portrait_textures[i] = texture
		var loaded_icons: Array = []
		var icon_paths_value: Variant = character.get("skill_icon_paths", [])
		if icon_paths_value is Array:
			for icon_path_value in icon_paths_value:
				var icon_path := str(icon_path_value)
				if icon_path == "":
					continue
				var icon_texture := ProjectResourceLoader.load_texture(icon_path)
				if icon_texture != null:
					loaded_icons.append(icon_texture)
		skill_icon_textures[i] = loaded_icons
		var full_body_sheet_path := str(character.get("full_body_live2d_sheet_path", ""))
		if full_body_sheet_path != "":
			var full_body_sheet_texture := ProjectResourceLoader.load_texture(full_body_sheet_path)
			if full_body_sheet_texture != null:
				full_body_live2d_textures[i] = full_body_sheet_texture
		var full_body_still_path := str(character.get("full_body_live2d_path", ""))
		if full_body_still_path != "":
			var full_body_still_texture := ProjectResourceLoader.load_texture(full_body_still_path)
			if full_body_still_texture != null:
				full_body_live2d_still_textures[i] = full_body_still_texture


func _setup_audio_players() -> void:
	if Engine.is_editor_hint():
		return
	character_select_bgm_player = AudioStreamPlayer.new()
	character_select_bgm_player.name = "CharacterSelectBGM"
	character_select_bgm_player.bus = BGM_BUS_NAME
	var bgm_finished_callback := Callable(self, "_on_character_select_bgm_finished")
	if not character_select_bgm_player.is_connected("finished", bgm_finished_callback):
		character_select_bgm_player.connect("finished", bgm_finished_callback)
	character_select_bgm_player.stream = ProjectResourceLoader.load_audio_stream(
		CHARACTER_SELECT_BGM_PATH,
		"Missing character-select BGM: %s",
		"Failed to load character-select BGM: %s"
	)
	add_child(character_select_bgm_player)
	if character_select_bgm_player.stream != null:
		character_select_bgm_loop_enabled = true
		if not character_select_bgm_muted:
			character_select_bgm_player.play()

	click_motion_voice_player = AudioStreamPlayer.new()
	click_motion_voice_player.name = "ClickMotionVoice"
	click_motion_voice_player.bus = "SFX"
	add_child(click_motion_voice_player)

	confirm_intro_voice_player = AudioStreamPlayer.new()
	confirm_intro_voice_player.name = "ConfirmIntroVoice"
	confirm_intro_voice_player.bus = "SFX"
	add_child(confirm_intro_voice_player)


func _setup_confirm_flash_overlay() -> void:
	confirm_intro_exit_flash_overlay = ConfirmFlashOverlay.new()
	confirm_intro_exit_flash_overlay.name = "ConfirmIntroExitFlash"
	confirm_intro_exit_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_intro_exit_flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_intro_exit_flash_overlay.z_index = 1000
	add_child(confirm_intro_exit_flash_overlay)
	var callback := Callable(self, "_on_confirm_intro_exit_flash_finished")
	if confirm_intro_exit_flash_overlay.has_signal("finished") and not confirm_intro_exit_flash_overlay.is_connected("finished", callback):
		confirm_intro_exit_flash_overlay.connect("finished", callback)


func _ensure_cache_dictionaries() -> void:
	if portrait_textures == null:
		portrait_textures = {}
	if card_rects == null:
		card_rects = {}
	if skill_icon_rects == null:
		skill_icon_rects = {}
	if skill_icon_textures == null:
		skill_icon_textures = {}
	if skill_config_instances == null:
		skill_config_instances = {}
	if full_body_live2d_textures == null:
		full_body_live2d_textures = {}
	if full_body_live2d_still_textures == null:
		full_body_live2d_still_textures = {}


func _on_character_select_bgm_finished() -> void:
	if not character_select_bgm_loop_enabled:
		return
	if character_select_bgm_muted:
		return
	if character_select_bgm_player == null or character_select_bgm_player.stream == null:
		return
	if not is_inside_tree():
		return
	character_select_bgm_player.play()


func _handle_bgm_toggle_input(event: InputEvent) -> bool:
	if not _is_key_pressed(event, BGM_TOGGLE_KEY):
		return false
	_toggle_character_select_bgm()
	if is_inside_tree() and get_viewport() != null:
		get_viewport().set_input_as_handled()
	return true


func _toggle_character_select_bgm() -> bool:
	character_select_bgm_muted = BgmMuteState.toggle(get_tree())
	if character_select_bgm_muted:
		if character_select_bgm_player != null and character_select_bgm_player.playing:
			character_select_bgm_player.stop()
		return true
	if character_select_bgm_player != null and character_select_bgm_player.stream != null and not character_select_bgm_player.playing:
		character_select_bgm_player.play()
	return false


func _restore_character_select_bgm_muted() -> void:
	character_select_bgm_muted = BgmMuteState.is_muted(get_tree())


func _is_key_pressed(event: InputEvent, keycode: int) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == keycode or key_event.physical_keycode == keycode


func _update_hover_from_mouse(pos: Vector2) -> void:
	hovered_index = -1
	hovered_skill_index = -1
	for icon_idx in skill_icon_rects.keys():
		var skill_rect: Rect2 = skill_icon_rects[icon_idx]
		if skill_rect.has_point(pos):
			hovered_skill_index = int(icon_idx)
			break
	for idx in card_rects.keys():
		var card_rect: Rect2 = card_rects[idx]
		if card_rect.has_point(pos):
			hovered_index = int(idx)
			return


func _update_hover_animation(delta: float) -> void:
	var t: float = min(1.0, delta * 12.0)
	for i in range(characters.size()):
		var target_lift := 0.0
		var target_scale := 1.0
		if i == selected_index:
			target_lift += 14.0
			target_scale = 1.035
		if i == hovered_index:
			target_lift += 10.0
			target_scale = max(target_scale, 1.045)
		hover_lifts[i] = lerp(float(hover_lifts[i]), target_lift, t)
		hover_scales[i] = lerp(float(hover_scales[i]), target_scale, t)
	if preview != null and preview.has_method("set_interaction_state"):
		var preview_hover := 1.0 if preview_rect_cache.has_point(get_local_mouse_position()) else 0.0
		preview.set_interaction_state(preview_hover, 0.0, preview_hover > 0.0)


func _move_selection(delta: int) -> void:
	if visible_indices.is_empty():
		return
	var current_pos := visible_indices.find(selected_index)
	if current_pos < 0:
		current_pos = 0
	var next_pos := (current_pos + delta + visible_indices.size()) % visible_indices.size()
	_select_index(int(visible_indices[next_pos]))


func _select_index(index: int) -> void:
	if index < 0 or index >= characters.size() or index == selected_index:
		return
	selected_index = index
	hovered_skill_index = -1
	skill_icon_rects.clear()
	_rail_stage_switch_at = animation_time
	locked_character_feedback_timer = 0.0
	_stop_click_motion_voice()
	_sync_preview()
	queue_redraw()


func _sync_preview() -> void:
	if preview == null or selected_index < 0 or selected_index >= characters.size():
		return
	var texture: Texture2D = portrait_textures.get(selected_index, null)
	if preview.has_method("set_character"):
		preview.set_character(characters[selected_index], texture)


func _adopt_backdrop_host() -> void:
	# Slice H: pull the VFX host out of the LivePreview clip so the city
	# backdrop can cover the whole screen. As this screen's own child at
	# negative z it still renders under every screen _draw (cards, buttons)
	# while the LivePreview child (character) stays on top.
	if preview == null:
		return
	preview.set("vfx_host_external_layout", true)
	preview.set("preview_card_frame_enabled", false)
	var host_value: Variant = preview.get("preview_vfx_host")
	var host := host_value as Control
	if host == null or not is_instance_valid(host):
		return
	if host.get_parent() == self:
		_backdrop_host = host
		return
	if host.get_parent() != null:
		host.get_parent().remove_child(host)
	add_child(host)
	move_child(host, 0)
	host.z_index = -20
	_backdrop_host = host
	_layout_backdrop_host()


func _layout_backdrop_host() -> void:
	if _backdrop_host == null or not is_instance_valid(_backdrop_host):
		return
	var view_size := _resolved_view_size()
	_backdrop_host.position = Vector2.ZERO
	_backdrop_host.size = view_size
	if _backdrop_host.has_method("set_stage_rect"):
		_backdrop_host.call("set_stage_rect", _preview_rect(view_size))


func _update_preview_layout() -> void:
	if preview == null:
		return
	var view_size := _resolved_view_size()
	var rect := _preview_rect(view_size)
	preview_rect_cache = rect
	preview.position = rect.position
	preview.size = rect.size
	# The rail's AFFILIATION microstat row owns the affiliation line while the
	# rail is visible; the nameplate falls back to it otherwise (D7 개정).
	preview.set("nameplate_show_affiliation", not _full_body_rail_rect(view_size).has_area())
	_layout_backdrop_host()


func _confirm_selection() -> void:
	if Engine.is_editor_hint() or confirm_intro_active:
		return
	if selected_index < 0 or selected_index >= characters.size():
		return
	var character: Dictionary = characters[selected_index]
	if not _is_character_unlocked(character):
		_show_locked_character_feedback()
		return
	_store_selection(character)
	character_confirmed.emit(str(character.get("id", "")), str(character.get("runtime_id", "")))
	if auto_start_battle and battle_scene_path != "":
		if _try_begin_confirm_intro(character, battle_scene_path):
			return
		_change_to_battle_scene(battle_scene_path)


func _show_locked_character_feedback() -> void:
	locked_character_feedback_timer = LOCKED_CHARACTER_FEEDBACK_DURATION
	queue_redraw()


func _go_back() -> void:
	if confirm_intro_active:
		return
	back_requested.emit()
	if main_menu_scene_path != "":
		call_deferred("_change_to_main_menu")


func _change_to_main_menu() -> void:
	if main_menu_scene_path == "" or not is_inside_tree() or get_tree() == null:
		return
	get_tree().change_scene_to_file(main_menu_scene_path)


func _store_selection(character: Dictionary) -> void:
	var state: Node = get_node_or_null("/root/GameSelectionState")
	if state != null and state.has_method("set_character"):
		state.set_character(character)
	if state != null and state.has_method("set_league_mode"):
		state.set_league_mode(selected_league_mode)


func _select_league_mode(mode: String) -> void:
	selected_league_mode = _normalize_league_mode(mode)
	var state: Node = get_node_or_null("/root/GameSelectionState") if is_inside_tree() else null
	if state != null and state.has_method("set_league_mode"):
		state.set_league_mode(selected_league_mode)
	queue_redraw()


func _cycle_league_mode(direction: int) -> void:
	var modes: Array[String] = []
	for button_value in LEAGUE_BUTTONS:
		if button_value is Dictionary:
			modes.append(str((button_value as Dictionary).get("mode", "")))
	if modes.is_empty():
		return
	var current_index: int = maxi(0, modes.find(selected_league_mode))
	_select_league_mode(modes[wrapi(current_index + direction, 0, modes.size())])


func _cycle_language() -> void:
	var options := LanguageSettings.get_language_options()
	if options.is_empty():
		return
	var current_language := LanguageSettings.get_language()
	var current_index := options.find(current_language)
	var next_index := 0
	if current_index >= 0:
		next_index = (current_index + 1) % options.size()
	_apply_language(str(options[next_index]))


func _apply_language(language: String) -> void:
	var selected_character_id := ""
	var selected_runtime_id := ""
	if selected_index >= 0 and selected_index < characters.size():
		var current_value: Variant = characters[selected_index]
		if current_value is Dictionary:
			var current_character: Dictionary = current_value
			selected_character_id = str(current_character.get("id", ""))
			selected_runtime_id = str(current_character.get("runtime_id", ""))
	LanguageSettings.set_language(language)
	characters = LanguageSettings.localize_character_list(CharacterSelectData.get_characters())
	_refresh_visible_indices()
	var restored_index := _find_character_index(selected_character_id, selected_runtime_id)
	if restored_index >= 0:
		selected_index = restored_index
	_prepare_hover_state()
	hovered_index = -1
	hovered_skill_index = -1
	skill_icon_rects.clear()
	_sync_preview()
	queue_redraw()


func _find_character_index(character_id: String, runtime_character_id: String) -> int:
	for i in range(characters.size()):
		var character_value: Variant = characters[i]
		if not (character_value is Dictionary):
			continue
		var character: Dictionary = character_value
		if character_id != "" and str(character.get("id", "")) == character_id:
			return i
		if runtime_character_id != "" and str(character.get("runtime_id", "")) == runtime_character_id:
			return i
	return -1


func _normalize_league_mode(mode: String) -> String:
	return BattleSceneConfig.normalize_league_mode(mode)


func _try_begin_confirm_intro(character: Dictionary, next_scene_path: String) -> bool:
	if preview == null or not preview.has_method("play_fullframe_one_shot"):
		return false
	var config := MotionConfigBuilder.build_confirm_intro_config(character)
	if config.is_empty():
		return false
	if not bool(preview.call("play_fullframe_one_shot", config)):
		return false
	if preview.has_method("play_confirm_vfx"):
		preview.call("play_confirm_vfx", {
			"character_id": str(character.get("id", "")),
			"amount": 1.0,
		})
	confirm_intro_active = true
	confirm_intro_character = character.duplicate(true)
	confirm_intro_elapsed = 0.0
	confirm_intro_pending_scene_path = next_scene_path
	confirm_intro_exit_flash_pending = false
	confirm_intro_exit_flash_hold_remaining = 0.0
	confirm_intro_exit_flash_started = false
	_prepare_confirm_intro_voice(confirm_intro_character)
	queue_redraw()
	return true


func _play_preview_click_motion(character: Dictionary) -> void:
	_prepare_click_motion_voice(character)
	if preview != null and preview.has_method("set_interaction_state"):
		preview.set_interaction_state(1.0, 1.0, true)
	if preview == null or not preview.has_method("play_fullframe_one_shot"):
		return
	var config := _build_preview_click_motion_config(character)
	if config.is_empty():
		return
	preview.call("play_fullframe_one_shot", config)


func _build_preview_click_motion_config(character: Dictionary) -> Dictionary:
	return MotionConfigBuilder.build_preview_click_motion_config(character)


func _request_confirm_intro_finish() -> void:
	if not confirm_intro_active:
		return
	if bool(confirm_intro_character.get("confirm_intro_exit_flash_enabled", false)):
		confirm_intro_exit_flash_pending = true
		confirm_intro_exit_flash_hold_remaining = max(0.0, float(confirm_intro_character.get("confirm_intro_exit_flash_hold", 0.0)))
		if confirm_intro_exit_flash_hold_remaining <= 0.0:
			_start_confirm_intro_exit_flash()
	else:
		_finish_confirm_intro()


func _update_confirm_intro(delta: float) -> void:
	if not confirm_intro_active:
		return
	confirm_intro_elapsed += delta
	_update_confirm_intro_voice(delta)
	if confirm_intro_exit_flash_pending and not confirm_intro_exit_flash_started:
		confirm_intro_exit_flash_hold_remaining -= delta
		if confirm_intro_exit_flash_hold_remaining <= 0.0:
			_start_confirm_intro_exit_flash()


func _start_confirm_intro_exit_flash() -> void:
	if confirm_intro_exit_flash_overlay == null:
		_finish_confirm_intro()
		return
	confirm_intro_exit_flash_pending = false
	confirm_intro_exit_flash_started = true
	var accent := _character_color(confirm_intro_character, "confirm_intro_exit_flash_color", _character_color(confirm_intro_character, "card_color", Color(0.0, 0.9, 1.0)))
	var glow := _character_color(confirm_intro_character, "confirm_intro_exit_flash_glow_color", _character_color(confirm_intro_character, "glow_color", accent))
	var secondary := _character_color(confirm_intro_character, "confirm_intro_exit_flash_secondary_color", Color.WHITE)
	confirm_intro_exit_flash_overlay.size = _resolved_view_size()
	confirm_intro_exit_flash_overlay.call("play", {
		"duration": float(confirm_intro_character.get("confirm_intro_exit_flash_duration", 0.45)),
		"source_rect": preview_rect_cache,
		"style": str(confirm_intro_character.get("confirm_intro_exit_flash_style", "burst")),
		"accent": accent,
		"glow": glow,
		"secondary": secondary,
		"field_intensity": float(confirm_intro_character.get("confirm_intro_exit_flash_field_intensity", 1.0)),
		"card_intensity": float(confirm_intro_character.get("confirm_intro_exit_flash_card_intensity", 1.0)),
		"white_wash_target": float(confirm_intro_character.get("confirm_intro_exit_flash_white_wash_target", 0.92)),
		"chroma": float(confirm_intro_character.get("confirm_intro_exit_flash_chroma", 0.012)),
		"split_intensity": float(confirm_intro_character.get("confirm_intro_exit_flash_split_intensity", 0.85)),
		"split_count": int(confirm_intro_character.get("confirm_intro_exit_flash_split_count", 10)),
	})


func _finish_confirm_intro() -> void:
	var next_scene_path := confirm_intro_pending_scene_path
	confirm_intro_active = false
	confirm_intro_character.clear()
	confirm_intro_elapsed = 0.0
	confirm_intro_pending_scene_path = ""
	confirm_intro_exit_flash_pending = false
	confirm_intro_exit_flash_hold_remaining = 0.0
	confirm_intro_exit_flash_started = false
	_stop_confirm_intro_voice()
	if confirm_intro_exit_flash_overlay != null and confirm_intro_exit_flash_overlay.has_method("cancel"):
		confirm_intro_exit_flash_overlay.call("cancel")
	if next_scene_path != "":
		_change_to_battle_scene(next_scene_path)


func _on_preview_one_shot_finished() -> void:
	if confirm_intro_active:
		_request_confirm_intro_finish()


func _on_confirm_intro_exit_flash_finished() -> void:
	if confirm_intro_active:
		_finish_confirm_intro()


func _change_to_battle_scene(scene_path: String) -> void:
	if scene_path == "" or not is_inside_tree() or get_tree() == null:
		return
	get_tree().change_scene_to_file(scene_path)


func _prepare_click_motion_voice(character: Dictionary) -> void:
	if click_motion_voice_player == null:
		return
	var path := str(character.get("click_motion_voice_path", ""))
	if path == "":
		path = str(character.get("confirm_intro_voice_path", ""))
	if path == "":
		return
	var stream := ProjectResourceLoader.load_audio_stream(path)
	if stream == null:
		return
	click_motion_voice_player.stop()
	click_motion_voice_player.stream = stream
	var volume_value: Variant = character.get("click_motion_voice_volume_db", character.get("confirm_intro_voice_volume_db", -5.0))
	var delay_value: Variant = character.get("click_motion_voice_delay", character.get("confirm_intro_voice_delay", 0.0))
	click_motion_voice_player.volume_db = float(volume_value)
	click_motion_voice_delay_remaining = max(0.0, float(delay_value))
	click_motion_voice_pending = true
	if click_motion_voice_delay_remaining <= 0.0:
		_update_click_motion_voice(0.0)


func _update_click_motion_voice(delta: float) -> void:
	if not click_motion_voice_pending:
		return
	click_motion_voice_delay_remaining -= delta
	if click_motion_voice_delay_remaining > 0.0:
		return
	click_motion_voice_pending = false
	click_motion_voice_delay_remaining = 0.0
	if click_motion_voice_player != null and click_motion_voice_player.stream != null:
		click_motion_voice_player.play()


func _stop_click_motion_voice() -> void:
	click_motion_voice_pending = false
	click_motion_voice_delay_remaining = 0.0
	if click_motion_voice_player != null:
		click_motion_voice_player.stop()
		click_motion_voice_player.stream = null


func _prepare_confirm_intro_voice(character: Dictionary) -> void:
	if confirm_intro_voice_player == null:
		return
	var path := str(character.get("confirm_intro_voice_path", ""))
	if path == "":
		return
	var stream := ProjectResourceLoader.load_audio_stream(path)
	if stream == null:
		return
	confirm_intro_voice_player.stop()
	confirm_intro_voice_player.stream = stream
	confirm_intro_voice_player.volume_db = float(character.get("confirm_intro_voice_volume_db", -6.0))
	confirm_intro_voice_delay_remaining = max(0.0, float(character.get("confirm_intro_voice_delay", 0.0)))
	confirm_intro_voice_pending = true
	if confirm_intro_voice_delay_remaining <= 0.0:
		_update_confirm_intro_voice(0.0)


func _update_confirm_intro_voice(delta: float) -> void:
	if not confirm_intro_voice_pending:
		return
	confirm_intro_voice_delay_remaining -= delta
	if confirm_intro_voice_delay_remaining > 0.0:
		return
	confirm_intro_voice_pending = false
	confirm_intro_voice_delay_remaining = 0.0
	if confirm_intro_voice_player != null and confirm_intro_voice_player.stream != null:
		confirm_intro_voice_player.play()


func _stop_confirm_intro_voice() -> void:
	confirm_intro_voice_pending = false
	confirm_intro_voice_delay_remaining = 0.0
	if confirm_intro_voice_player != null:
		confirm_intro_voice_player.stop()
		confirm_intro_voice_player.stream = null


func _dispose_audio_player(player: AudioStreamPlayer, finished_callback: Callable = Callable()) -> void:
	if player == null:
		return
	if finished_callback.is_valid() and player.is_connected("finished", finished_callback):
		player.disconnect("finished", finished_callback)
	if player.playing:
		player.stop()
	player.stream = null
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	player.free()


func _draw_background(view_size: Vector2, backdrop_fullscreen: bool = false) -> void:
	if backdrop_fullscreen:
		# Slice H: the fullscreen backdrop host IS the background. Only
		# translucent ambience may draw here — the character-accent wash
		# couples the city mood to the selected character (개방감 패스 ②).
		var selected_character: Dictionary = characters[selected_index] if selected_index >= 0 and selected_index < characters.size() else {}
		var accent := _character_color(selected_character, "card_color", Color(0.0, 0.9, 1.0))
		draw_rect(Rect2(Vector2.ZERO, view_size), Color(accent.r, accent.g, accent.b, 0.05))
	else:
		draw_rect(Rect2(Vector2.ZERO, view_size), CHROME_BG_BASE)
		var upper_h: float = view_size.y * 0.39
		draw_rect(Rect2(0.0, 0.0, view_size.x, upper_h), CHROME_BG_UPPER)
		draw_rect(Rect2(0.0, upper_h, view_size.x, view_size.y - upper_h), CHROME_BG_LOWER)
		draw_line(Vector2(0.0, upper_h), Vector2(view_size.x, upper_h), CHROME_HAIRLINE, 1.0)
	var step: float = max(40.0, view_size.x / 40.0)
	var drift: float = fmod(animation_time * 6.0, step)
	var x: float = -view_size.y * 0.16 + drift
	while x < view_size.x:
		draw_line(Vector2(x, 0.0), Vector2(x + view_size.y * 0.16, view_size.y), CHROME_GRID, 1.0)
		x += step
	var y: float = 0.0
	while y < view_size.y:
		draw_line(Vector2(0.0, y), Vector2(view_size.x, y), CHROME_SCAN, 1.0)
		y += step * 0.55
	_draw_editorial_microtext(view_size)


func _draw_editorial_microtext(view_size: Vector2) -> void:
	# ASCII-only editorial microtext built from live screen state (no fake
	# mockup codes, no Korean glyphs -> no i18n entries required this slice).
	var font := ThemeDB.fallback_font
	var margin := 22.0
	var brand_line := "DISK HEARTS - LINGPIA :: CHARACTER SELECT"
	var brand_size := font.get_string_size(brand_line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9)
	draw_string(font, Vector2(view_size.x - brand_size.x - margin, 30.0), brand_line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, CHROME_MICROTEXT)
	var roster_position := 0
	for pos in range(visible_indices.size()):
		if int(visible_indices[pos]) == selected_index:
			roster_position = pos + 1
			break
	var status_line := "ROSTER %02d/%02d  |  LEAGUE %s  |  LANG %s" % [
		roster_position,
		visible_indices.size(),
		selected_league_mode.to_upper(),
		_language_code_label(LanguageSettings.get_language()),
	]
	draw_string(font, Vector2(margin, view_size.y - 16.0), status_line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, CHROME_MICROTEXT)
	draw_line(Vector2(margin, view_size.y - 34.0), Vector2(view_size.x - margin, view_size.y - 34.0), Color(CHROME_HAIRLINE.r, CHROME_HAIRLINE.g, CHROME_HAIRLINE.b, 0.10), 1.0)


func _diag_panel_geometry(rect: Rect2, cut: float) -> Dictionary:
	var view_size := _resolved_view_size()
	if _diag_panel_cache_view_size != view_size:
		_diag_panel_point_cache.clear()
		_diag_panel_cache_view_size = view_size
	var key := "%.2f_%.2f_%.2f_%.2f_%.2f" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y, cut]
	var cached: Variant = _diag_panel_point_cache.get(key)
	if cached is Dictionary:
		return cached
	if _diag_panel_point_cache.size() >= 64:
		_diag_panel_point_cache.clear()
	var corner: float = clampf(cut, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	# Convex hexagon: top-left and bottom-right corners get the diagonal cut.
	var fill_points := PackedVector2Array([
		rect.position + Vector2(corner, 0.0),
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x, rect.end.y - corner),
		Vector2(rect.end.x - corner, rect.end.y),
		Vector2(rect.position.x, rect.end.y),
		Vector2(rect.position.x, rect.position.y + corner),
	])
	var outline_points := fill_points.duplicate()
	outline_points.append(fill_points[0])
	var geometry := {
		"fill": fill_points,
		"outline": outline_points,
	}
	_diag_panel_point_cache[key] = geometry
	return geometry


func _draw_diag_panel(rect: Rect2, cut: float, fill: Color, border: Color, border_width: float) -> void:
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var geometry := _diag_panel_geometry(rect, cut)
	var fill_points: PackedVector2Array = geometry.get("fill", PackedVector2Array())
	var outline_points: PackedVector2Array = geometry.get("outline", PackedVector2Array())
	if fill.a > 0.0 and fill_points.size() >= 3:
		draw_colored_polygon(fill_points, fill)
	if border.a > 0.0 and border_width > 0.0 and outline_points.size() >= 2:
		draw_polyline(outline_points, border, border_width)


func _draw_header(view_size: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var column := _card_column_rect(view_size)
	var desktop := view_size.x >= 980.0
	var title_pos := Vector2(column.position.x + 12.0, 54.0)
	if not desktop:
		title_pos = Vector2(34.0, 36.0)
	var title_size := 30 if desktop else 24
	draw_rect(Rect2(title_pos + Vector2(-12.0, 5.0), Vector2(3.0, float(title_size) + 5.0)), Color(0.88, 0.91, 0.97, 0.85))
	_draw_text_left(font, LanguageSettings.translate_text("캐릭터 선택"), title_pos, title_size, Color(1.0, 1.0, 1.0, 0.98))
	var subtitle := "SELECT YOUR CHARACTER"
	var subtitle_pos := title_pos + Vector2(0.0, float(title_size) + 8.0)
	_draw_text_left(font, subtitle, subtitle_pos, 11, Color(0.58, 0.63, 0.72, 0.88))
	if desktop:
		var subtitle_size := font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11)
		var rule_y := subtitle_pos.y + 7.0
		var rule_start := subtitle_pos.x + subtitle_size.x + 14.0
		if rule_start < view_size.x * 0.42:
			draw_line(Vector2(rule_start, rule_y), Vector2(view_size.x * 0.42, rule_y), Color(CHROME_HAIRLINE.r, CHROME_HAIRLINE.g, CHROME_HAIRLINE.b, 0.14), 1.0)


func _draw_card_column(rect: Rect2) -> void:
	# v2 G1: no container box — roster cards float on the background like the
	# rest of the unified card language. Mobile keeps a subtle strip.
	if _resolved_view_size().x < 980.0:
		draw_rect(rect, Color(0.014, 0.015, 0.019, 0.42))
		draw_rect(rect, Color(CHROME_PANEL_BORDER.r, CHROME_PANEL_BORDER.g, CHROME_PANEL_BORDER.b, 0.14), false, 1.0)
	card_rects = _layout_cards(_resolved_view_size())
	for idx in visible_indices:
		_draw_character_card(int(idx), card_rects.get(int(idx), Rect2()))
	language_rect = _language_button_rect(_resolved_view_size())
	_draw_language_button(language_rect)


func _draw_character_card(index: int, rect: Rect2) -> void:
	if rect.size.x <= 1.0 or index < 0 or index >= characters.size():
		return
	var character: Dictionary = characters[index]
	var accent := _character_color(character, "card_color", Color(0.0, 0.9, 1.0))
	var glow := _character_color(character, "glow_color", accent)
	var selected := index == selected_index
	var hovered := index == hovered_index
	var unlocked := _is_character_unlocked(character)
	var font := ThemeDB.fallback_font
	if rect.size.x > rect.size.y * 1.5:
		_draw_character_card_horizontal(index, rect, character, accent, glow, selected, hovered, unlocked, font)
		return
	if selected or hovered:
		draw_rect(rect.grow(8.0), Color(glow.r, glow.g, glow.b, 0.14 if selected else 0.07))
	draw_rect(rect, Color(0.006, 0.008, 0.013, 0.98))
	var image_rect := rect.grow(-6.0)
	var texture: Texture2D = portrait_textures.get(index, null)
	if texture != null:
		var source_rect := _character_card_face_source_rect(texture, image_rect, character)
		draw_texture_rect_region(texture, image_rect, source_rect, Color(1.0, 1.0, 1.0, 0.96 if unlocked else 0.36))
	else:
		draw_rect(image_rect, Color(accent.r, accent.g, accent.b, 0.22 if unlocked else 0.08))
	if not unlocked:
		_draw_locked_card_overlay(image_rect, accent)
	var name_band := Rect2(rect.position.x, rect.end.y - 34.0, rect.size.x, 34.0)
	draw_rect(name_band, Color(0.0, 0.0, 0.0, 0.74))
	draw_line(name_band.position, Vector2(name_band.end.x, name_band.position.y), Color(CHROME_HAIRLINE.r, CHROME_HAIRLINE.g, CHROME_HAIRLINE.b, 0.30), 1.0)
	if selected:
		draw_rect(Rect2(name_band.position + Vector2(6.0, 12.0), Vector2(3.0, 10.0)), Color(accent.r, accent.g, accent.b, 0.95))
	var character_name := str(character.get("character_name", character.get("name", "")))
	_draw_text_center(font, character_name, Vector2(rect.get_center().x, rect.end.y - 17.0), 15, Color.WHITE if unlocked else Color(0.78, 0.82, 0.88, 0.90))
	var idle_border := Color(CHROME_PANEL_BORDER.r, CHROME_PANEL_BORDER.g, CHROME_PANEL_BORDER.b, 0.30 if unlocked else 0.18)
	var border_color := Color(accent.r, accent.g, accent.b, 0.92) if selected else (Color(accent.r, accent.g, accent.b, 0.55) if hovered else idle_border)
	draw_rect(rect, border_color, false, 2.0 if selected else 1.0)
	draw_rect(rect.grow(-5.0), Color(1.0, 1.0, 1.0, 0.08 if selected else 0.05), false, 1.0)
	if selected:
		var pulse: float = 0.78 + sin(animation_time * 2.4) * 0.22
		PremiumPanelFrame.draw_corner_brackets(self, rect.grow(6.0), glow, pulse, 0.24, 22.0)


func _draw_character_card_horizontal(index: int, rect: Rect2, character: Dictionary, accent: Color, glow: Color, selected: bool, hovered: bool, unlocked: bool, font: Font) -> void:
	# v2 G1 unified roster card: dark glass rounded panel, portrait thumbnail
	# on the left, name + role tag on the right, accent border when selected.
	var fill := Color(0.030, 0.033, 0.041, 0.94)
	if selected:
		fill = Color(accent.r * 0.10, accent.g * 0.12, accent.b * 0.13, 0.96)
	elif hovered:
		fill = Color(0.040, 0.044, 0.054, 0.95)
	var idle_border := Color(CHROME_PANEL_BORDER.r, CHROME_PANEL_BORDER.g, CHROME_PANEL_BORDER.b, 0.30 if unlocked else 0.18)
	var border := Color(accent.r, accent.g, accent.b, 0.92) if selected else (Color(accent.r, accent.g, accent.b, 0.55) if hovered else idle_border)
	if selected:
		draw_rect(rect.grow(6.0), Color(glow.r, glow.g, glow.b, 0.10))
	# Soft large-radius card: separation comes from shadow + spacing, not a
	# hard 1px box — idle borders are near-invisible (레퍼런스의 "굴곡" 감).
	var card_border := border if (selected or hovered) else Color(border.r, border.g, border.b, border.a * 0.35)
	draw_style_box(_get_roster_card_box(fill, card_border, 2 if selected else 1), rect)
	# Portrait = the cutout PNG itself blending onto the card fill — no crop
	# box, no divider hairline; the silhouette IS the boundary.
	var portrait_rect := Rect2(rect.position + Vector2(4.0, 3.0), Vector2(rect.size.x * 0.56, rect.size.y - 6.0))
	var thumb_side: float = portrait_rect.size.y
	var glow_center := portrait_rect.position + Vector2(portrait_rect.size.x * 0.40, portrait_rect.size.y * 0.48)
	draw_circle(glow_center, rect.size.y * 0.44, Color(accent.r, accent.g, accent.b, 0.10 if unlocked else 0.04))
	draw_circle(glow_center, rect.size.y * 0.26, Color(accent.r, accent.g, accent.b, 0.08 if unlocked else 0.03))
	var texture: Texture2D = portrait_textures.get(index, null)
	if texture != null:
		var source_rect := _character_card_face_source_rect(texture, portrait_rect, character)
		draw_texture_rect_region(texture, portrait_rect, source_rect, Color(1.0, 1.0, 1.0, 0.96 if unlocked else 0.34))
	else:
		draw_circle(glow_center, rect.size.y * 0.30, Color(accent.r, accent.g, accent.b, 0.20 if unlocked else 0.07))
	var text_left: float = rect.position.x + rect.size.x * 0.50
	var character_name := str(character.get("character_name", character.get("name", "")))
	_draw_text_left(font, character_name, Vector2(text_left, rect.get_center().y - 26.0), 18, Color.WHITE if unlocked else Color(0.76, 0.80, 0.86, 0.88))
	var role_text := str(character.get("role", ""))
	if role_text.strip_edges() != "":
		var glyph_center := Vector2(text_left + 5.0, rect.get_center().y + 16.0)
		var glyph := PackedVector2Array([
			glyph_center + Vector2(0.0, -4.5),
			glyph_center + Vector2(4.5, 0.0),
			glyph_center + Vector2(0.0, 4.5),
			glyph_center + Vector2(-4.5, 0.0),
		])
		draw_colored_polygon(glyph, Color(accent.r, accent.g, accent.b, 0.85 if unlocked else 0.40))
		# The selection arrow sits at center.y±6 — no vertical overlap with the
		# tag row, so only a small right margin is reserved (not an arrow zone).
		var tag_spec := _role_tag_draw_spec(role_text, rect.end.x - 8.0 - (text_left + 14.0))
		_draw_text_left(font, str(tag_spec.get("text", role_text)), Vector2(text_left + 14.0, rect.get_center().y + 8.0), int(tag_spec.get("font_size", 10)), Color(0.62, 0.67, 0.75, 0.85 if unlocked else 0.55))
	if not unlocked:
		var badge_rect := Rect2(rect.position + Vector2(10.0, 10.0), Vector2(minf(70.0, thumb_side + 4.0), 18.0))
		draw_rect(badge_rect, Color(0.0, 0.0, 0.0, 0.78))
		draw_rect(badge_rect, Color(accent.r, accent.g, accent.b, 0.55), false, 1.0)
		_draw_text_center(font, LanguageSettings.translate_text("해금 필요"), badge_rect.get_center(), 8, Color(0.92, 0.96, 1.0, 0.96))
	if selected:
		PremiumPanelFrame.draw_corner_brackets(self, rect.grow(-7.0), Color(glow.r, glow.g, glow.b, 0.75), 1.0, 0.20, 15.0)
		var arrow_x: float = rect.end.x - 16.0
		var arrow := PackedVector2Array([
			Vector2(arrow_x, rect.get_center().y - 6.0),
			Vector2(arrow_x + 7.0, rect.get_center().y),
			Vector2(arrow_x, rect.get_center().y + 6.0),
		])
		draw_colored_polygon(arrow, Color(accent.r, accent.g, accent.b, 0.95))


func _get_roster_card_box(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	if _roster_card_box == null:
		_roster_card_box = StyleBoxFlat.new()
		_roster_card_box.anti_aliasing = true
		_roster_card_box.corner_detail = 8
		_roster_card_box.set_corner_radius_all(16)
		_roster_card_box.shadow_size = 10
		_roster_card_box.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
		_roster_card_box.shadow_offset = Vector2(0.0, 4.0)
	_roster_card_box.bg_color = fill
	_roster_card_box.border_color = border
	_roster_card_box.set_border_width_all(border_width)
	return _roster_card_box


func _role_tag_draw_spec(role_text: String, max_width: float) -> Dictionary:
	# Localized role names vary widely in width (Codex G1 review memo) —
	# shrink 10 -> 9px before ellipsizing so the tag never bleeds off-card.
	var font := ThemeDB.fallback_font
	var trimmed := role_text.strip_edges()
	for candidate_size_value in [10, 9]:
		var candidate_size := int(candidate_size_value)
		if font.get_string_size(trimmed, HORIZONTAL_ALIGNMENT_LEFT, -1.0, candidate_size).x <= max_width:
			return {"text": trimmed, "font_size": candidate_size}
	var clipped := trimmed
	while clipped.length() > 1 and font.get_string_size(clipped + "…", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9).x > max_width:
		clipped = clipped.substr(0, clipped.length() - 1)
	return {"text": clipped + "…", "font_size": 9}


func _draw_locked_card_overlay(image_rect: Rect2, accent: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_rect(image_rect, Color(0.0, 0.0, 0.0, 0.46))
	var badge_width: float = min(92.0, max(64.0, image_rect.size.x - 24.0))
	var badge_rect := Rect2(image_rect.position + Vector2(12.0, 12.0), Vector2(badge_width, 25.0))
	draw_rect(badge_rect, Color(0.0, 0.0, 0.0, 0.72))
	draw_rect(badge_rect, Color(accent.r, accent.g, accent.b, 0.72), false, 1.0)
	_draw_text_center(font, LanguageSettings.translate_text("해금 필요"), badge_rect.get_center(), 12, Color(0.92, 0.96, 1.0, 0.96))


func _draw_preview_frame(rect: Rect2) -> void:
	if selected_index < 0 or selected_index >= characters.size():
		return
	var character: Dictionary = characters[selected_index]
	var accent := _character_color(character, "card_color", Color(0.0, 0.9, 1.0))
	# v2 G2: name_latin watermark behind the character — the screen draws
	# UNDER the LivePreview child, so this lands over the city backdrop and
	# behind the hero art. Outline-only chrome: no translucent fill may cover
	# the backdrop hole area (§3-1 hole-punch trap).
	var latin_name := str(character.get("name_latin", "")).strip_edges()
	if latin_name != "" and rect.size.x >= 640.0:
		var watermark_font := ThemeDB.fallback_font
		var watermark_size := 118
		# Reference-style oblique slant via a shear matrix. draw_set_transform
		# trap note (§ godot_runtime_traps): the identity-reset failure mode
		# requires a parent transform set earlier on the same canvas — this
		# screen's _draw sets NO other transform (sealed by the backdrop
		# smoke's source grep), so the default Transform2D() restore IS the
		# exact prior state.
		var watermark_origin := rect.position + Vector2(64.0, 40.0 + float(watermark_size))
		draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.0), Vector2(-0.22, 1.0), watermark_origin))
		draw_string(watermark_font, Vector2.ZERO, latin_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, watermark_size, Color(0.75, 0.88, 0.95, 0.055))
		draw_set_transform_matrix(Transform2D())
	# Slice H: frameless hero — the fullscreen backdrop makes the frame border
	# read as a picture frame; only a short grounding accent bar remains.
	draw_rect(Rect2(rect.position.x + 26.0, rect.end.y + 3.0, 64.0, 2.0), Color(accent.r, accent.g, accent.b, 0.85))


func _draw_full_body_rail(view_size: Vector2) -> void:
	# D7 개정 + Slice H (정보 응집): the right rail hosts the info header
	# (difficulty / signature skills / ring core — or the locked hint) above
	# the full-body Live2D panel, matching the reference right column.
	if selected_index < 0 or selected_index >= characters.size():
		return
	var rail := _full_body_rail_rect(view_size)
	if not rail.has_area():
		if _resolved_view_size().x >= 980.0:
			skill_icon_rects.clear()
		return
	var character: Dictionary = characters[selected_index]
	var accent := _character_color(character, "card_color", Color(0.0, 0.9, 1.0))
	var glow := _character_color(character, "glow_color", accent)
	var unlocked := _is_character_unlocked(character)
	PremiumPanelFrame.draw_panel(self, rail, PremiumPanelFrame.KIND_SECTION, CHROME_PANEL_FILL, CHROME_PANEL_BORDER, 1.0)
	var inner := rail.grow(-8.0)
	var font := ThemeDB.fallback_font
	var header_height := 0.0
	if unlocked:
		var header_left: float = inner.position.x + 10.0
		_draw_difficulty(Vector2(header_left, inner.position.y + 10.0), int(character.get("difficulty_stars", 1)), accent)
		# Labeled sections (reference rhythm): icons without their labels read
		# as floating decorations.
		_draw_text_left(font, LanguageSettings.translate_text("대표 스킬"), Vector2(header_left, inner.position.y + 38.0), 12, Color(0.72, 0.78, 0.86, 0.90))
		_draw_text_left(font, _lingpet_ring_core_label(), Vector2(inner.end.x - 10.0 - 50.0, inner.position.y + 38.0), 12, Color(0.72, 0.78, 0.86, 0.90))
		var icon_row_y: float = inner.position.y + 60.0
		_draw_skill_icons(Rect2(Vector2(header_left, icon_row_y), Vector2(174.0, 50.0)), selected_index, character, accent, glow)
		_draw_lingpet_ring_core_slot(Rect2(Vector2(inner.end.x - 10.0 - 50.0, icon_row_y), Vector2(50.0, 50.0)), accent, glow)
		header_height = 60.0 + 50.0 + 14.0
	else:
		skill_icon_rects.clear()
		_draw_locked_info_status(Rect2(inner.position + Vector2(6.0, 10.0), Vector2(inner.size.x - 12.0, 76.0)), character, accent)
		header_height = 96.0
	# The confirm CTA lives inside the rail bottom on desktop (reference
	# right-column composition) — reserve its band.
	var panel_rect := Rect2(
		inner.position + Vector2(0.0, header_height),
		Vector2(inner.size.x, inner.size.y - header_height - 66.0)
	)
	_draw_full_body_live2d_panel(panel_rect, selected_index, character, accent)


func _draw_info_panel(rect: Rect2) -> void:
	if selected_index < 0 or selected_index >= characters.size():
		return
	if rect.size.y < 48.0:
		# Yielded panel (narrow+short stacked layout) — draw nothing and drop
		# the skill icon hitboxes so hover/tooltip cannot fire on ghost rects.
		skill_icon_rects.clear()
		return
	var character: Dictionary = characters[selected_index]
	var accent := _character_color(character, "card_color", Color(0.0, 0.9, 1.0))
	var glow := _character_color(character, "glow_color", accent)
	var font := ThemeDB.fallback_font
	_draw_diag_panel(rect, CHROME_DIAG_CUT, CHROME_PANEL_FILL, CHROME_PANEL_BORDER, 1.2)
	draw_rect(rect.grow(-6.0), Color(1.0, 1.0, 1.0, 0.05), false, 1.0)
	draw_rect(Rect2(rect.position + Vector2(CHROME_DIAG_CUT + 6.0, 0.0), Vector2(56.0, 2.0)), Color(accent.r, accent.g, accent.b, 0.90))
	PremiumPanelFrame.draw_corner_brackets(self, rect.grow(6.0), Color(glow.r, glow.g, glow.b, 0.55), 1.0, 0.06, 26.0)
	var layout := _build_info_panel_layout(rect, character, font)
	var character_class_name := str(character.get("class_name", character.get("name", "")))
	var character_name := str(character.get("character_name", character.get("name", "")))
	var unlocked := _is_character_unlocked(character)
	# Row budget: blocks that would overflow the panel rect are dropped
	# top-down instead of bleeding over the action bar / card column below.
	var blocks := _info_panel_visible_blocks(rect, layout, unlocked)
	_draw_text_line_block(font, _layout_string_lines(layout, "role_lines"), layout.get("role_top_left", rect.position), 14, Color(accent.r, accent.g, accent.b, 0.94), 18.0)
	if bool(blocks.get("name", false)):
		_draw_text_left(font, character_name, layout.get("name_top_left", rect.position), 31, Color.WHITE)
		_draw_badge(layout.get("badge_top_left", rect.position), character_class_name, accent)
	if bool(blocks.get("tagline", false)):
		_draw_text_line_block(font, _layout_string_lines(layout, "tagline_lines"), layout.get("tagline_top_left", rect.position), 17, Color(0.88, 0.92, 0.97, 0.98), 22.0)
	if bool(blocks.get("description", false)):
		_draw_text_line_block(font, _layout_string_lines(layout, "description_lines"), layout.get("description_top_left", rect.position), 14, Color(0.73, 0.82, 0.90, 0.96), 20.0)
	if bool(blocks.get("difficulty", false)):
		_draw_difficulty(layout.get("difficulty_top_left", rect.position), int(character.get("difficulty_stars", 1)), accent)
	if unlocked:
		if bool(blocks.get("skills", false)):
			_draw_text_left(font, LanguageSettings.translate_text("대표 스킬"), layout.get("skills_label_top_left", rect.position), 13, Color(0.82, 0.88, 0.94, 0.92))
			_draw_text_left(font, _lingpet_ring_core_label(), layout.get("ring_core_label_top_left", rect.position), 13, Color(0.82, 0.88, 0.94, 0.92))
			_draw_skill_icons(layout.get("skill_rect", Rect2()), selected_index, character, accent, glow)
			_draw_lingpet_ring_core_slot(layout.get("ring_core_rect", Rect2()), accent, glow)
		else:
			skill_icon_rects.clear()
	else:
		skill_icon_rects.clear()
		if bool(blocks.get("locked", false)):
			_draw_locked_info_status(layout.get("locked_status_rect", Rect2()), character, accent)
	_draw_full_body_live2d_panel(layout.get("full_body_rect", Rect2()), selected_index, character, accent)


func _info_panel_visible_blocks(rect: Rect2, layout: Dictionary, unlocked: bool) -> Dictionary:
	var content_bottom: float = rect.end.y - 10.0
	var blocks := {}
	var name_top: Vector2 = layout.get("name_top_left", rect.position)
	blocks["name"] = name_top.y + 37.0 <= content_bottom
	var tagline_top: Vector2 = layout.get("tagline_top_left", rect.position)
	var tagline_lines := _layout_string_lines(layout, "tagline_lines").size()
	blocks["tagline"] = tagline_lines > 0 and tagline_top.y + float(tagline_lines) * 22.0 <= content_bottom
	var description_top: Vector2 = layout.get("description_top_left", rect.position)
	var description_lines := _layout_string_lines(layout, "description_lines").size()
	blocks["description"] = description_lines > 0 and description_top.y + float(description_lines) * 20.0 <= content_bottom
	var difficulty_top: Vector2 = layout.get("difficulty_top_left", rect.position)
	blocks["difficulty"] = difficulty_top.y + 20.0 <= content_bottom
	if unlocked:
		var skill_rect: Rect2 = layout.get("skill_rect", Rect2())
		blocks["skills"] = skill_rect.has_area() and skill_rect.end.y <= content_bottom
	else:
		var locked_rect: Rect2 = layout.get("locked_status_rect", Rect2())
		blocks["locked"] = locked_rect.has_area() and locked_rect.end.y <= content_bottom
	return blocks


func _build_info_panel_layout(rect: Rect2, character: Dictionary, font: Font) -> Dictionary:
	var content_left := rect.position.x + 26.0
	var content_width: float = max(80.0, rect.size.x - 52.0)
	var content_right := content_left + content_width
	var y := rect.position.y + 22.0
	var layout := {
		"role_top_left": Vector2(content_left, y),
	}
	var role_lines := _get_wrapped_text_lines(font, str(character.get("role", "")), content_width, 14, 2)
	layout["role_lines"] = role_lines
	y += max(18.0, float(role_lines.size()) * 18.0)

	var name_top_left := Vector2(content_left, y + 6.0)
	layout["name_top_left"] = name_top_left
	var character_name := str(character.get("character_name", character.get("name", "")))
	var class_label := str(character.get("class_name", character.get("name", "")))
	var name_size := font.get_string_size(character_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 31)
	var badge_size := _badge_size(font, class_label, 14)
	var badge_top_left := Vector2(content_left + name_size.x + 18.0, name_top_left.y + 1.0)
	var name_bottom: float = name_top_left.y + 37.0
	if class_label.strip_edges() != "":
		if badge_top_left.x + badge_size.x > content_right:
			badge_top_left = Vector2(content_left, name_top_left.y + 40.0)
		name_bottom = max(name_bottom, badge_top_left.y + badge_size.y + 6.0)
	layout["badge_top_left"] = badge_top_left
	y = name_bottom

	var tagline_lines := _get_wrapped_text_lines(font, str(character.get("tagline", "")), content_width, 17, 2)
	var tagline_top_left := Vector2(content_left, y)
	layout["tagline_top_left"] = tagline_top_left
	layout["tagline_lines"] = tagline_lines
	if not tagline_lines.is_empty():
		y = tagline_top_left.y + float(tagline_lines.size()) * 22.0
	else:
		y += 4.0

	var description_lines := _get_wrapped_text_lines(font, str(character.get("description", "")), content_width, 14, 3)
	var description_top_left := Vector2(content_left, y + 5.0)
	layout["description_top_left"] = description_top_left
	layout["description_lines"] = description_lines
	if not description_lines.is_empty():
		y = description_top_left.y + float(description_lines.size()) * 20.0
	else:
		y = description_top_left.y

	var difficulty_top_left := Vector2(content_left, y + 6.0)
	layout["difficulty_top_left"] = difficulty_top_left
	y = difficulty_top_left.y + 24.0

	if _is_character_unlocked(character):
		var skills_label_top_left := Vector2(content_left, y + 2.0)
		var ring_core_size := 50.0
		var ring_core_gap := 18.0
		var skill_row_width := maxf(174.0, content_width - ring_core_size - ring_core_gap)
		var skill_rect := Rect2(Vector2(content_left, skills_label_top_left.y + 26.0), Vector2(skill_row_width, 56.0))
		var ring_core_rect := Rect2(Vector2(content_right - ring_core_size, skill_rect.position.y), Vector2(ring_core_size, ring_core_size))
		layout["skills_label_top_left"] = skills_label_top_left
		layout["skill_rect"] = skill_rect
		layout["ring_core_label_top_left"] = Vector2(ring_core_rect.position.x, skills_label_top_left.y)
		layout["ring_core_rect"] = ring_core_rect
		y = skill_rect.end.y
	else:
		var locked_status_rect := Rect2(Vector2(content_left, y + 4.0), Vector2(content_width, 76.0))
		layout["locked_status_rect"] = locked_status_rect
		y = locked_status_rect.end.y

	var full_body_top: float = max(rect.position.y + 252.0, y + 22.0)
	var full_body_height: float = rect.end.y - full_body_top - 20.0
	if full_body_height < 120.0:
		# 행 양보 규칙: 공간이 모자라면 풀바디 패널이 먼저 드랍된다. 음수
		# 여유를 최소 높이로 승격해 패널 밖(카드열 위)으로 탈출시키지 않는다.
		layout["full_body_rect"] = Rect2()
	else:
		layout["full_body_rect"] = Rect2(Vector2(rect.position.x + 22.0, full_body_top), Vector2(max(80.0, rect.size.x - 44.0), full_body_height))
	return layout


func _layout_string_lines(layout: Dictionary, key: String) -> Array[String]:
	var result: Array[String] = []
	var lines_value: Variant = layout.get(key, [])
	if lines_value is Array:
		for line_value in lines_value:
			result.append(str(line_value))
	return result


func _draw_locked_info_status(rect: Rect2, character: Dictionary, accent: Color) -> void:
	var font := ThemeDB.fallback_font
	var hint := str(character.get("unlock_hint", "해금 후 플레이 가능"))
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.30))
	draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.38), false, 1.0)
	_draw_text_left(font, LanguageSettings.translate_text("해금 필요"), rect.position + Vector2(12.0, 10.0), 15, Color(1.0, 0.90, 0.54, 0.98))
	_draw_text_left(font, LanguageSettings.translate_text(hint), rect.position + Vector2(12.0, 38.0), 13, Color(0.82, 0.88, 0.94, 0.90))


func _draw_stats(origin: Vector2, max_width: float, character: Dictionary) -> void:
	var stats_value: Variant = character.get("stats", {})
	if not (stats_value is Dictionary):
		return
	var stats: Dictionary = stats_value
	if stats.is_empty():
		return
	var font := ThemeDB.fallback_font
	var keys := stats.keys()
	var col_count: int = min(3, keys.size())
	var col_w: float = max_width / float(max(1, col_count))
	for i in range(col_count):
		var key := str(keys[i])
		var value := int(stats.get(key, 0))
		var x := origin.x + float(i) * col_w
		_draw_text_left(font, key, Vector2(x, origin.y), 13, Color(0.82, 0.86, 0.90, 0.88))
		var track := Rect2(x, origin.y + 22.0, col_w - 24.0, 8.0)
		draw_rect(track, Color(0.0, 0.0, 0.0, 0.45))
		draw_rect(Rect2(track.position, Vector2(track.size.x * clamp(float(value) / 8.0, 0.0, 1.0), track.size.y)), Color(1.0, 0.76, 0.26, 0.90))
		draw_rect(track, Color(1.0, 1.0, 1.0, 0.18), false, 1.0)


func _action_bar_layout(view_size: Vector2) -> Dictionary:
	return CharacterSelectLayout.action_bar_layout(view_size, LEAGUE_BUTTONS)


func _build_league_button_layout(
	start_x: float,
	row_y: float,
	button_width: float,
	button_height: float,
	gap: float
) -> Dictionary:
	return CharacterSelectLayout.build_league_button_layout(
		LEAGUE_BUTTONS,
		start_x,
		row_y,
		button_width,
		button_height,
		gap
	)


func _draw_action_bar(view_size: Vector2) -> void:
	var character: Dictionary = characters[selected_index] if selected_index >= 0 and selected_index < characters.size() else {}
	var accent := _character_color(character, "card_color", Color(0.0, 0.9, 1.0))
	var glow := _character_color(character, "glow_color", accent)
	var bar_layout := _action_bar_layout(view_size)
	back_rect = bar_layout.get("back", Rect2())
	junior_rect = bar_layout.get("junior", Rect2())
	champion_rect = bar_layout.get("champion", Rect2())
	limit_rect = bar_layout.get("limit", Rect2())
	mythic_rect = bar_layout.get("mythic", Rect2())
	confirm_rect = bar_layout.get("confirm", Rect2())
	_draw_button(back_rect, LanguageSettings.translate_text("뒤로"), Color(0.55, 0.60, 0.68, 0.58), Color(0.08, 0.09, 0.12, 0.88), false)
	_draw_league_button(junior_rect, LanguageSettings.translate_text("테스트"), "junior", Color(0.38, 0.92, 0.45, 1.0))
	_draw_league_button(champion_rect, LanguageSettings.translate_text("실전"), "champion", Color(0.82, 0.30, 1.0, 1.0))
	_draw_league_button(limit_rect, LanguageSettings.translate_text("리미트"), "limit", Color(1.0, 0.36, 0.42, 1.0))
	_draw_league_button(mythic_rect, LanguageSettings.translate_text("오버클럭"), "mythic", Color(1.0, 0.76, 0.26, 1.0))
	var select_name := str(character.get("character_name", character.get("name", "")))
	if not character.is_empty() and not _is_character_unlocked(character):
		var locked_label := "아직 해금되지 않음" if locked_character_feedback_timer > 0.0 else "해금 필요"
		_draw_button(confirm_rect, LanguageSettings.translate_text(locked_label), Color(0.62, 0.66, 0.74, 0.82), Color(0.055, 0.060, 0.072, 0.94), true)
		return
	_draw_button(confirm_rect, LanguageSettings.format_select_label(select_name), glow, Color(accent.r * 0.20, accent.g * 0.24, accent.b * 0.24, 0.94), true)


func _draw_texture_cover(texture: Texture2D, target: Rect2, texture_modulate: Color = Color.WHITE) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 1.0 or texture_size.y <= 1.0 or target.size.x <= 1.0 or target.size.y <= 1.0:
		return
	var source := Rect2(Vector2.ZERO, texture_size)
	var texture_aspect: float = texture_size.x / max(1.0, texture_size.y)
	var target_aspect: float = target.size.x / max(1.0, target.size.y)
	if texture_aspect > target_aspect:
		source.size.x = texture_size.y * target_aspect
		source.position.x = (texture_size.x - source.size.x) * 0.5
	else:
		source.size.y = texture_size.x / max(0.01, target_aspect)
		source.position.y = (texture_size.y - source.size.y) * 0.5
	draw_texture_rect_region(texture, target, source, texture_modulate)


func _draw_badge(top_left: Vector2, label: String, accent: Color) -> void:
	if label.strip_edges() == "":
		return
	var font := ThemeDB.fallback_font
	var badge_rect := Rect2(top_left, _badge_size(font, label, 14))
	draw_rect(badge_rect, Color(accent.r, accent.g, accent.b, 0.16))
	draw_rect(badge_rect, Color(accent.r, accent.g, accent.b, 0.86), false, 1.0)
	_draw_text_center(font, label, badge_rect.get_center() + Vector2(0.0, -1.0), 13, Color(0.88, 1.0, 1.0, 0.96))


func _badge_size(font: Font, label: String, font_size: int) -> Vector2:
	if label.strip_edges() == "":
		return Vector2.ZERO
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	return Vector2(text_size.x + 22.0, 25.0)


func _draw_difficulty(top_left: Vector2, stars: int, accent: Color) -> void:
	var font := ThemeDB.fallback_font
	_draw_text_left(font, LanguageSettings.translate_text("난이도"), top_left, 13, Color(0.82, 0.88, 0.94, 0.90))
	var star_x := top_left.x + 52.0
	for star_index in range(3):
		var filled: bool = star_index < int(clamp(stars, 0, 3))
		var star_color := Color(accent.r, accent.g, accent.b, 0.96) if filled else Color(0.50, 0.58, 0.66, 0.55)
		_draw_text_left(font, "★", Vector2(star_x + float(star_index) * 21.0, top_left.y - 1.0), 18, star_color)


func _draw_skill_icons(rect: Rect2, character_index: int, character: Dictionary, accent: Color, glow: Color) -> void:
	_ensure_cache_dictionaries()
	var icon_size := 50.0
	var gap := 12.0
	var icons_value: Variant = skill_icon_textures.get(character_index, [])
	var icons: Array = icons_value if icons_value is Array else []
	var skill_ids := _get_character_skill_preview_ids(character)
	skill_icon_rects.clear()
	for icon_index in range(3):
		var icon_rect := Rect2(rect.position + Vector2(float(icon_index) * (icon_size + gap), 0.0), Vector2(icon_size, icon_size))
		var has_skill_data := icon_index < skill_ids.size() and str(skill_ids[icon_index]).strip_edges() != ""
		if has_skill_data:
			skill_icon_rects[icon_index] = icon_rect
		var hovered := has_skill_data and icon_index == hovered_skill_index
		draw_rect(icon_rect.grow(5.0 if hovered else 4.0), Color(glow.r, glow.g, glow.b, 0.22 if hovered else 0.12))
		draw_rect(icon_rect, Color(0.008, 0.010, 0.016, 0.95))
		if icon_index < icons.size() and icons[icon_index] is Texture2D:
			_draw_texture_cover(icons[icon_index], icon_rect.grow(-4.0), Color.WHITE)
		else:
			draw_circle(icon_rect.get_center(), 14.0, Color(accent.r, accent.g, accent.b, 0.22))
			draw_circle(icon_rect.get_center(), 6.0, Color(accent.r, accent.g, accent.b, 0.75))
		draw_rect(icon_rect, Color(accent.r, accent.g, accent.b, 0.96 if hovered else 0.86), false, 2.0 if hovered else 1.0)


func _draw_lingpet_ring_core_slot(rect: Rect2, accent: Color, glow: Color) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var tier := clampi(CHARACTER_SELECT_RING_CORE_TIER, 0, LingpetRingCoreRules.MAX_RING_CORE_TIER)
	draw_rect(rect.grow(4.0), Color(glow.r, glow.g, glow.b, 0.12 if tier > 0 else 0.06))
	draw_rect(rect, Color(0.008, 0.010, 0.016, 0.95))
	if tier > 0 and _lingpet_ring_core_icon_renderer != null:
		var icon_id := "lingpet_ring_core_upgrade_tier_%d" % tier
		if not bool(_lingpet_ring_core_icon_renderer.draw_icon(self, icon_id, rect.grow(-4.0), 1.0, true)):
			_draw_lingpet_ring_core_fallback(rect.grow(-7.0), accent)
	else:
		_draw_empty_lingpet_ring_core_slot(rect.grow(-7.0), accent)
	var border_alpha := 0.94 if tier > 0 else 0.42
	draw_rect(rect, Color(accent.r, accent.g, accent.b, border_alpha), false, 2.0 if tier > 0 else 1.0)
	var badge_rect := Rect2(rect.position + Vector2(4.0, rect.size.y - 17.0), Vector2(30.0, 13.0))
	draw_rect(badge_rect, Color(0.0, 0.0, 0.0, 0.58))
	var badge_text := "T%d" % tier if tier > 0 else "T-"
	_draw_text_center(ThemeDB.fallback_font, badge_text, badge_rect.get_center() + Vector2(0.0, 1.0), 8, Color.WHITE if tier > 0 else Color(0.72, 0.78, 0.84, 0.88))


func _draw_lingpet_ring_core_fallback(rect: Rect2, accent: Color) -> void:
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.32
	draw_circle(center, radius + 7.0, Color(accent.r, accent.g, accent.b, 0.10))
	draw_circle(center, radius, Color(accent.r, accent.g, accent.b, 0.24))
	draw_arc(center, radius, 0.0, TAU, 32, Color(accent.r, accent.g, accent.b, 0.90), 2.0)
	draw_circle(center, radius * 0.40, Color(1.0, 0.78, 0.34, 0.82))


func _draw_empty_lingpet_ring_core_slot(rect: Rect2, accent: Color) -> void:
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.34
	draw_circle(center, radius, Color(accent.r, accent.g, accent.b, 0.08))
	draw_arc(center, radius, 0.0, TAU, 32, Color(accent.r, accent.g, accent.b, 0.34), 1.4)
	draw_line(center + Vector2(-radius * 0.58, radius * 0.58), center + Vector2(radius * 0.58, -radius * 0.58), Color(0.70, 0.76, 0.82, 0.48), 1.6)


func _lingpet_ring_core_label() -> String:
	return "링코어" if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_KOREAN else "Ring Core"


func _draw_skill_hover_tooltip(view_size: Vector2) -> void:
	if hovered_skill_index < 0:
		return
	if selected_index < 0 or selected_index >= characters.size():
		return
	if not skill_icon_rects.has(hovered_skill_index):
		return
	var character: Dictionary = characters[selected_index]
	var skill_data: Dictionary = _get_skill_preview_data(character, hovered_skill_index)
	if skill_data.is_empty():
		return
	var anchor_rect: Rect2 = skill_icon_rects[hovered_skill_index]
	var accent := _character_color(character, "card_color", Color(0.0, 0.9, 1.0))
	var skill_color := _skill_data_color(skill_data, accent)
	var font := ThemeDB.fallback_font
	var width: float = min(342.0, max(268.0, view_size.x - 48.0))
	if view_size.x < 980.0:
		width = min(326.0, max(236.0, view_size.x - 48.0))
	var text_width: float = width - 24.0
	var title := str(skill_data.get("korean", skill_data.get("name", ""))).strip_edges()
	var meta := _format_skill_meta(skill_data)
	var use_text := str(skill_data.get("how_to_use", "")).strip_edges()
	var description := str(skill_data.get("description", "")).strip_edges()
	var title_lines: Array[String] = _get_wrapped_text_lines(font, title, text_width, 17, 2)
	var meta_lines: Array[String] = _get_wrapped_text_lines(font, meta, text_width, 12, 1)
	var use_lines: Array[String] = _get_wrapped_text_lines(font, use_text, text_width, 12, 2)
	var desc_lines: Array[String] = _get_wrapped_text_lines(font, description, text_width, 13, 5)
	var height := 22.0 + float(title_lines.size()) * 21.0
	if not meta_lines.is_empty():
		height += float(meta_lines.size()) * 16.0 + 2.0
	if not use_lines.is_empty():
		height += float(use_lines.size()) * 16.0 + 4.0
	if not desc_lines.is_empty():
		height += 8.0 + float(desc_lines.size()) * 18.0
	height += 10.0
	var pos := Vector2(anchor_rect.end.x + 14.0, anchor_rect.position.y - 12.0)
	if pos.x + width > view_size.x - 18.0:
		pos.x = anchor_rect.position.x - width - 14.0
	pos.x = clamp(pos.x, 18.0, max(18.0, view_size.x - width - 18.0))
	pos.y = clamp(pos.y, 18.0, max(18.0, view_size.y - height - 18.0))
	var tooltip_rect := Rect2(pos, Vector2(width, height))
	draw_rect(tooltip_rect.grow(7.0), Color(skill_color.r, skill_color.g, skill_color.b, 0.10))
	draw_rect(tooltip_rect, Color(0.006, 0.009, 0.015, 0.97))
	draw_rect(tooltip_rect, Color(skill_color.r, skill_color.g, skill_color.b, 0.86), false, 1.5)
	draw_rect(tooltip_rect.grow(-5.0), Color(1.0, 1.0, 1.0, 0.07), false, 1.0)
	var y: float = tooltip_rect.position.y + 12.0
	y = _draw_text_line_block(font, title_lines, Vector2(tooltip_rect.position.x + 12.0, y), 17, Color.WHITE, 21.0)
	if not meta_lines.is_empty():
		y += 2.0
		y = _draw_text_line_block(font, meta_lines, Vector2(tooltip_rect.position.x + 12.0, y), 12, Color(skill_color.r, skill_color.g, skill_color.b, 0.94), 16.0)
	if not use_lines.is_empty():
		y += 4.0
		y = _draw_text_line_block(font, use_lines, Vector2(tooltip_rect.position.x + 12.0, y), 12, Color(0.83, 0.91, 1.0, 0.92), 16.0)
	if not desc_lines.is_empty():
		y += 7.0
		draw_line(Vector2(tooltip_rect.position.x + 12.0, y), Vector2(tooltip_rect.end.x - 12.0, y), Color(skill_color.r, skill_color.g, skill_color.b, 0.26), 1.0)
		y += 6.0
		_draw_text_line_block(font, desc_lines, Vector2(tooltip_rect.position.x + 12.0, y), 13, Color(0.84, 0.89, 0.95, 0.96), 18.0)


func _get_skill_preview_data(character: Dictionary, icon_index: int) -> Dictionary:
	var skill_ids := _get_character_skill_preview_ids(character)
	if icon_index < 0 or icon_index >= skill_ids.size():
		return {}
	var skill_id := str(skill_ids[icon_index]).strip_edges()
	if skill_id == "":
		return {}
	var skill_config := _get_skill_config_for_character(character)
	if skill_config == null or not skill_config.has_method("get_skill_data"):
		return {}
	var data_value: Variant = skill_config.get_skill_data(skill_id)
	if data_value is Dictionary:
		var skill_data: Dictionary = data_value
		if not skill_data.is_empty():
			return skill_data
	return {}


func _get_character_skill_preview_ids(character: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var configured_ids_value: Variant = character.get("skill_preview_ids", [])
	if configured_ids_value is Array:
		for id_value in configured_ids_value:
			result.append(str(id_value))
	if not result.is_empty():
		return result
	var icon_paths_value: Variant = character.get("skill_icon_paths", [])
	if icon_paths_value is Array:
		for path_value in icon_paths_value:
			result.append(_infer_skill_id_from_icon_path(str(path_value), character))
	return result


func _infer_skill_id_from_icon_path(path: String, character: Dictionary) -> String:
	var file_name := path
	var slash_index: int = max(path.rfind("/"), path.rfind("\\"))
	if slash_index >= 0:
		file_name = path.substr(slash_index + 1)
	if file_name.ends_with(".png"):
		file_name = file_name.substr(0, file_name.length() - 4)
	if file_name.ends_with("_skill_orb"):
		file_name = file_name.substr(0, file_name.length() - "_skill_orb".length())
	var runtime_id := str(character.get("runtime_id", character.get("id", ""))).strip_edges().to_lower()
	var prefix := "commando" if runtime_id == "soldier" else runtime_id
	if prefix == "commando" and file_name == "commando_pistol":
		return "commando_pistol"
	if prefix != "" and file_name.begins_with("%s_" % prefix):
		return file_name.substr(prefix.length() + 1)
	return file_name


func _get_skill_config_for_character(character: Dictionary) -> Object:
	var runtime_id := str(character.get("runtime_id", character.get("id", ""))).strip_edges().to_lower()
	if runtime_id == "soldier":
		runtime_id = "commando"
	match runtime_id:
		"smasher":
			if not skill_config_instances.has("smasher"):
				skill_config_instances["smasher"] = SmasherSkillConfig.new()
			return skill_config_instances["smasher"]
		"commando":
			if not skill_config_instances.has("commando"):
				skill_config_instances["commando"] = CommandoSkillConfig.new()
			return skill_config_instances["commando"]
		"viper":
			if not skill_config_instances.has("viper"):
				skill_config_instances["viper"] = ViperSkillConfig.new()
			return skill_config_instances["viper"]
	return null


func _skill_data_color(skill_data: Dictionary, fallback: Color) -> Color:
	var value: Variant = skill_data.get("color", fallback)
	return value if value is Color else fallback


func _format_skill_meta(skill_data: Dictionary) -> String:
	var cost: float = float(skill_data.get("cost", 0.0))
	var cooldown: float = float(skill_data.get("cooldown", 0.0))
	if cost > 0.0 and cooldown > 0.0:
		return LanguageSettings.translate_text("비용 %s  쿨타임 %s초" % [_format_number(cost), _format_number(cooldown)])
	if cooldown > 0.0:
		return LanguageSettings.translate_text("쿨타임 %s초" % _format_number(cooldown))
	if cost > 0.0:
		return "비용 %s" % _format_number(cost)
	return ""


func _format_number(value: float) -> String:
	var rounded: float = round(value)
	if is_equal_approx(value, rounded):
		return str(int(rounded))
	var text := "%.1f" % value
	if text.ends_with(".0"):
		text = text.substr(0, text.length() - 2)
	return text


func _get_wrapped_text_lines(font: Font, source_text: String, max_width: float, font_size: int, max_lines: int) -> Array[String]:
	var result: Array[String] = []
	if source_text.strip_edges() == "" or max_lines <= 0:
		return result
	var paragraphs := source_text.split("\n", false)
	for paragraph_value in paragraphs:
		var paragraph := str(paragraph_value).strip_edges()
		if paragraph == "":
			continue
		var words := paragraph.split(" ", false)
		var current_line := ""
		for word_value in words:
			var word := str(word_value)
			var candidate := word if current_line == "" else "%s %s" % [current_line, word]
			if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width or current_line == "":
				current_line = candidate
			else:
				result.append(current_line)
				if result.size() >= max_lines:
					return result
				current_line = word
		if current_line != "":
			result.append(current_line)
			if result.size() >= max_lines:
				return result
	return result


func _draw_text_line_block(font: Font, lines: Array[String], top_left: Vector2, font_size: int, color: Color, line_step: float) -> float:
	var y := top_left.y
	for line in lines:
		_draw_text_left(font, line, Vector2(top_left.x, y), font_size, color)
		y += line_step
	return y


func _draw_full_body_live2d_panel(rect: Rect2, character_index: int, character: Dictionary, accent: Color) -> void:
	_ensure_cache_dictionaries()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	# Section labels + lore rows + status strip draw BEFORE the texture
	# branches below (they early-return), and the art rect shrinks to reserve
	# every band — appending after the branches never renders for characters
	# WITH art.
	var font := ThemeDB.fallback_font
	var label_band := 24.0
	_draw_section_label(rect.position + Vector2(10.0, 6.0), "LIVE 2D VIEW", accent)
	draw_line(rect.position + Vector2(10.0, label_band), Vector2(rect.end.x - 10.0, rect.position.y + label_band), Color(CHROME_HAIRLINE.r, CHROME_HAIRLINE.g, CHROME_HAIRLINE.b, 0.18), 1.0)

	# INFORMATION section is measured first (two-column rows with a stacked
	# fallback for long localized affiliations) so the art card can size to
	# the true remaining space.
	var rows := _full_body_microstat_rows(character)
	var value_left: float = rect.position.x + 88.0
	var value_column_width: float = rect.end.x - 10.0 - value_left
	var row_specs: Array = []
	var rows_band := 0.0
	if not rows.is_empty():
		rows_band = 34.0
		for row_value in rows:
			var row: Dictionary = row_value
			var value_text := str(row.get("value", ""))
			var single_line: bool = font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11).x <= value_column_width
			var row_height := 20.0 if single_line else 34.0
			row_specs.append({"row": row, "single": single_line, "height": row_height})
			rows_band += row_height
	var strip_band := 26.0
	var art_card := Rect2(
		rect.position + Vector2(4.0, label_band + 4.0),
		Vector2(rect.size.x - 8.0, rect.size.y - label_band - 4.0 - strip_band - rows_band - 10.0)
	)
	if art_card.size.y < 40.0:
		return

	if not row_specs.is_empty():
		var info_top: float = rect.end.y - rows_band
		_draw_section_label(Vector2(rect.position.x + 10.0, info_top), "INFORMATION", accent)
		draw_line(Vector2(rect.position.x + 10.0, info_top + 20.0), Vector2(rect.end.x - 10.0, info_top + 20.0), Color(CHROME_HAIRLINE.r, CHROME_HAIRLINE.g, CHROME_HAIRLINE.b, 0.18), 1.0)
		var row_y: float = info_top + 28.0
		for spec_value in row_specs:
			var spec: Dictionary = spec_value
			var row: Dictionary = spec.get("row", {})
			draw_string(font, Vector2(rect.position.x + 10.0, row_y + 9.0), str(row.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, CHROME_MICROTEXT)
			if bool(spec.get("single", true)):
				draw_string(font, Vector2(value_left, row_y + 10.0), str(row.get("value", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.88, 0.92, 0.97, 0.95))
			else:
				draw_string(font, Vector2(rect.position.x + 10.0, row_y + 24.0), str(row.get("value", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.88, 0.92, 0.97, 0.95))
			row_y += float(spec.get("height", 20.0))

	# Status strip (reference "device UI"): truthful telemetry only — frame
	# phase dots driven by the real sheet clock + a LIVE 2D ON/OFF state pill.
	var sheet_texture: Texture2D = full_body_live2d_textures.get(character_index, null)
	var strip_center_y: float = rect.end.y - rows_band - strip_band * 0.5
	var frame_count: int = max(1, int(character.get("full_body_live2d_count", 1)))
	var frame_interval: float = max(0.01, float(character.get("full_body_live2d_interval", 0.033)))
	var current_frame: int = int(animation_time / frame_interval) % frame_count
	var active_dot: int = int(float(current_frame) * 5.0 / float(frame_count)) % 5
	for dot_index in range(5):
		var dot_active: bool = sheet_texture != null and dot_index == active_dot
		draw_circle(
			Vector2(rect.position.x + 16.0 + float(dot_index) * 12.0, strip_center_y),
			2.6 if dot_active else 1.7,
			Color(accent.r, accent.g, accent.b, 0.95 if dot_active else 0.28)
		)
	var pill_rect := Rect2(Vector2(rect.end.x - 10.0 - 34.0, strip_center_y - 8.0), Vector2(34.0, 16.0))
	var live_on := sheet_texture != null
	draw_rect(pill_rect, Color(accent.r, accent.g, accent.b, 0.85) if live_on else Color(0.28, 0.31, 0.36, 0.80))
	_draw_text_center(font, "ON" if live_on else "OFF", pill_rect.get_center(), 9, Color(0.02, 0.05, 0.08, 0.95) if live_on else Color(0.75, 0.80, 0.86, 0.92))
	var live_label := "LIVE 2D"
	var live_label_size := font.get_string_size(live_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9)
	draw_string(font, Vector2(pill_rect.position.x - 8.0 - live_label_size.x, strip_center_y + 3.0), live_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, CHROME_MICROTEXT)

	# Art sub-card: holo-stage layering via painted 3-piece stills (절차 도형
	# 제거 교훈) — neutral-luminance pieces tinted by the character accent,
	# breathing on the shared clock, switch-envelope on roster change.
	draw_style_box(_get_roster_card_box(Color(0.036, 0.042, 0.055, 0.92), Color(accent.r, accent.g, accent.b, 0.22), 1), art_card)
	var envelope: float = clampf((animation_time - _rail_stage_switch_at) / 0.45, 0.0, 1.0)
	envelope = envelope * envelope * (3.0 - 2.0 * envelope)
	# Ambient atmosphere wash (reference parity: the card interior reads as a
	# lit chamber, not near-black) — bottom-lit vertical gradient.
	var wash := art_card.grow(-3.0)
	draw_polygon(
		PackedVector2Array([wash.position, Vector2(wash.end.x, wash.position.y), wash.end, Vector2(wash.position.x, wash.end.y)]),
		PackedColorArray([
			Color(accent.r, accent.g, accent.b, 0.030 * envelope),
			Color(accent.r, accent.g, accent.b, 0.030 * envelope),
			Color(accent.r, accent.g, accent.b, 0.105 * envelope),
			Color(accent.r, accent.g, accent.b, 0.105 * envelope),
		])
	)
	# Rising wrap energy (사용자 디렉션: 정적 원형 장식 제거 → 에너지가
	# 아래에서 위로 몸을 감아 도는 흐름). Deterministic hash streams spiral
	# around the body axis — cos(θ) depth splits them into a BEHIND pass here
	# and a FRONT pass after the art draw, so the energy truly wraps the body.
	_draw_rail_energy_pass(art_card, accent, envelope, false)
	PremiumPanelFrame.draw_corner_brackets(self, art_card.grow(-7.0), Color(accent.r, accent.g, accent.b, 0.50), 1.0, 0.08, 14.0)
	for deco in [
		Vector2(art_card.position.x + 18.0, art_card.position.y + 22.0),
		Vector2(art_card.end.x - 20.0, art_card.position.y + 46.0),
		Vector2(art_card.position.x + 24.0, art_card.end.y - 40.0),
	]:
		var deco_center: Vector2 = deco
		draw_colored_polygon(PackedVector2Array([
			deco_center + Vector2(0.0, -4.0),
			deco_center + Vector2(4.0, 0.0),
			deco_center + Vector2(0.0, 4.0),
			deco_center + Vector2(-4.0, 0.0),
		]), Color(accent.r, accent.g, accent.b, 0.22))
	var inner_rect := art_card.grow(-8.0)
	if sheet_texture != null:
		_draw_full_body_live2d_sheet(sheet_texture, inner_rect, character)
	else:
		var still_texture: Texture2D = full_body_live2d_still_textures.get(character_index, null)
		if still_texture != null:
			_draw_texture_contain(still_texture, inner_rect, Color.WHITE)
		else:
			_draw_text_center(font, LanguageSettings.translate_text("전신 LIVE2D"), inner_rect.get_center() + Vector2(0.0, -12.0), 13, Color(0.72, 0.78, 0.86, 0.86))
			_draw_text_center(font, LanguageSettings.translate_text("준비중"), inner_rect.get_center() + Vector2(0.0, 12.0), 13, Color(0.72, 0.78, 0.86, 0.86))
	# Front half of the wrap energy — drawn over the art so streams pass in
	# front of the body on the cos(θ) >= 0 side of the spiral.
	_draw_rail_energy_pass(art_card, accent, envelope, true)


func _draw_rail_energy_pass(art_card: Rect2, accent: Color, envelope: float, front: bool) -> void:
	if envelope <= 0.01:
		return
	var center_x: float = art_card.get_center().x
	var bottom_y: float = art_card.end.y - art_card.size.y * 0.06
	var top_y: float = art_card.position.y + art_card.size.y * 0.10
	var travel: float = bottom_y - top_y
	for stream_index in range(22):
		var stream_seed := float(stream_index)
		var speed: float = 0.085 + _rail_energy_hash(stream_seed, 1.7) * 0.095
		var phase: float = fposmod(animation_time * speed + _rail_energy_hash(stream_seed, 4.3), 1.0)
		# Body-hugging radius profile: narrow at the feet and head, widest at
		# the torso, so the spiral reads as wrapping the silhouette.
		var profile: float = sin(phase * PI)
		var radius: float = art_card.size.x * (0.15 + 0.23 * profile)
		var wrap_theta: float = phase * TAU * (1.6 + _rail_energy_hash(stream_seed, 2.9) * 0.8) + _rail_energy_hash(stream_seed, 7.1) * TAU
		var depth: float = cos(wrap_theta)
		if (depth >= 0.0) != front:
			continue
		var spark_pos := Vector2(center_x + sin(wrap_theta) * radius, bottom_y - travel * phase)
		var fade: float = sin(phase * PI)
		var alpha: float = fade * (0.24 + 0.34 * absf(depth)) * envelope
		var spark_size: float = 1.1 + _rail_energy_hash(stream_seed, 5.5) * 1.9 + absf(depth) * 0.8
		draw_circle(spark_pos, spark_size + 2.4, Color(accent.r, accent.g, accent.b, alpha * 0.24))
		draw_circle(spark_pos, spark_size, Color(accent.r, accent.g, accent.b, alpha))
		draw_line(
			spark_pos,
			spark_pos + Vector2(-sin(wrap_theta) * 2.2, 7.0 + fade * 6.0),
			Color(accent.r, accent.g, accent.b, alpha * 0.42),
			1.0
		)


func _rail_energy_hash(a: float, b: float) -> float:
	return fposmod(sin(a * 127.1 + b * 311.7) * 43758.5453, 1.0)


func _draw_section_label(top_left: Vector2, text: String, accent: Color) -> void:
	var glyph_center := top_left + Vector2(4.0, 7.0)
	draw_colored_polygon(PackedVector2Array([
		glyph_center + Vector2(0.0, -3.5),
		glyph_center + Vector2(3.5, 0.0),
		glyph_center + Vector2(0.0, 3.5),
		glyph_center + Vector2(-3.5, 0.0),
	]), Color(accent.r, accent.g, accent.b, 0.90))
	draw_string(ThemeDB.fallback_font, top_left + Vector2(13.0, 11.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(accent.r, accent.g, accent.b, 0.85))


func _full_body_microstat_rows(character: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var entries := [
		{"label": "HEIGHT", "key": "lore_height"},
		{"label": "WEIGHT", "key": "lore_weight"},
		{"label": "AFFILIATION", "key": "lore_affiliation"},
	]
	for entry_value in entries:
		var entry: Dictionary = entry_value
		var value := str(character.get(str(entry.get("key", "")), "")).strip_edges()
		if value == "":
			continue
		rows.append({"label": str(entry.get("label", "")), "value": value})
	return rows


func _draw_full_body_live2d_sheet(texture: Texture2D, target: Rect2, character: Dictionary) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 1.0 or texture_size.y <= 1.0:
		return
	var cols: int = max(1, int(character.get("full_body_live2d_cols", 1)))
	var rows: int = max(1, int(character.get("full_body_live2d_rows", 1)))
	var frame_count: int = clamp(int(character.get("full_body_live2d_count", cols * rows)), 1, cols * rows)
	var interval: float = max(0.016, float(character.get("full_body_live2d_interval", 0.033)))
	var frame_index: int = int(floor(animation_time / interval)) % frame_count
	var col: int = frame_index % cols
	var row: int = int(floor(float(frame_index) / float(cols)))
	var cell_size := Vector2(texture_size.x / float(cols), texture_size.y / float(rows))
	var source_rect := Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)
	var trim_value: Variant = character.get("full_body_live2d_trim_rect", Rect2())
	if trim_value is Rect2:
		var trim_rect: Rect2 = trim_value
		if trim_rect.size.x > 1.0 and trim_rect.size.y > 1.0:
			source_rect = Rect2(source_rect.position + trim_rect.position, trim_rect.size)
	var fit_rect := _build_full_body_live2d_fit_rect(source_rect.size, target, character)
	draw_texture_rect_region(texture, fit_rect, source_rect, Color.WHITE)


func _build_full_body_live2d_fit_rect(source_size: Vector2, target: Rect2, character: Dictionary) -> Rect2:
	var fit_rect := _fit_region_rect(source_size, target)
	var stage_scale: float = max(0.40, float(character.get("full_body_live2d_stage_scale", 1.0)))
	fit_rect = _scale_rect(fit_rect, stage_scale)
	var stage_x_scale: float = max(0.40, float(character.get("full_body_live2d_stage_x_scale", 1.0)))
	var stage_y_scale: float = max(0.40, float(character.get("full_body_live2d_stage_y_scale", 1.0)))
	if abs(stage_x_scale - 1.0) > 0.001 or abs(stage_y_scale - 1.0) > 0.001:
		fit_rect = _scale_rect_nonuniform(fit_rect, stage_x_scale, stage_y_scale)
	fit_rect.position += Vector2(
		target.size.x * float(character.get("full_body_live2d_stage_x_offset_ratio", 0.0)),
		target.size.y * float(character.get("full_body_live2d_stage_y_offset_ratio", 0.0))
	)
	return _align_full_body_live2d_to_floor(fit_rect, target, character)


func _align_full_body_live2d_to_floor(rect: Rect2, target: Rect2, character: Dictionary) -> Rect2:
	if not bool(character.get("full_body_live2d_align_bottom_to_rena_floor", true)):
		return rect
	var floor_ratio: float = clamp(
		float(character.get("full_body_live2d_floor_y_ratio", FULL_BODY_LIVE2D_RENA_FLOOR_Y_RATIO)),
		0.58,
		1.05
	)
	var floor_offset_ratio: float = float(character.get("full_body_live2d_floor_y_offset_ratio", 0.0))
	var floor_y: float = target.position.y + target.size.y * (floor_ratio + floor_offset_ratio)
	rect.position.y += floor_y - rect.end.y
	if bool(character.get("full_body_live2d_fit_within_floor_panel", true)):
		rect = _fit_full_body_live2d_within_floor_panel(rect, target, floor_y)
	return rect


func _fit_full_body_live2d_within_floor_panel(rect: Rect2, target: Rect2, floor_y: float) -> Rect2:
	var available_height: float = max(1.0, floor_y - target.position.y)
	if rect.position.y >= target.position.y or rect.size.y <= available_height:
		return rect
	var scale_factor: float = available_height / rect.size.y
	var center_x: float = rect.get_center().x
	var scaled_size := rect.size * scale_factor
	return Rect2(Vector2(center_x - scaled_size.x * 0.5, floor_y - scaled_size.y), scaled_size)


func _draw_texture_contain(texture: Texture2D, target: Rect2, texture_modulate: Color = Color.WHITE) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 1.0 or texture_size.y <= 1.0:
		return
	var fit_rect := _fit_region_rect(texture_size, target)
	draw_texture_rect(texture, fit_rect, false, texture_modulate)


func _fit_region_rect(content_size: Vector2, target: Rect2) -> Rect2:
	if content_size.x <= 1.0 or content_size.y <= 1.0 or target.size.x <= 1.0 or target.size.y <= 1.0:
		return target
	var scale_factor: float = min(target.size.x / content_size.x, target.size.y / content_size.y)
	var fitted_size := content_size * scale_factor
	return Rect2(target.position + (target.size - fitted_size) * 0.5, fitted_size)


func _scale_rect(rect: Rect2, scale_factor: float) -> Rect2:
	var center := rect.get_center()
	var scaled_size := rect.size * scale_factor
	return Rect2(center - scaled_size * 0.5, scaled_size)


func _scale_rect_nonuniform(rect: Rect2, x_scale: float, y_scale: float) -> Rect2:
	var center_x: float = rect.get_center().x
	var bottom_y: float = rect.end.y
	var scaled_size := Vector2(rect.size.x * x_scale, rect.size.y * y_scale)
	return Rect2(Vector2(center_x - scaled_size.x * 0.5, bottom_y - scaled_size.y), scaled_size)


func _draw_button(rect: Rect2, label: String, border: Color, fill: Color, prominent: bool) -> void:
	# v2 G1 unified round token: CTA uses the KIND_MAIN halo panel, secondary
	# buttons use the slot panel — same premium language as in-battle panels.
	var font := ThemeDB.fallback_font
	if prominent:
		PremiumPanelFrame.draw_panel(self, rect, PremiumPanelFrame.KIND_MAIN, fill, Color(border.r, border.g, border.b, 0.92))
	else:
		PremiumPanelFrame.draw_panel(self, rect, PremiumPanelFrame.KIND_SLOT, fill, Color(border.r, border.g, border.b, 0.72), 1.0)
	_draw_text_center(font, label, rect.get_center(), 20 if prominent else 15, Color.WHITE)


func _draw_league_button(rect: Rect2, label: String, mode: String, border_color: Color) -> void:
	var selected := selected_league_mode == mode
	# Skewed neon plate (2026-07-04 레퍼런스): vertex-computed parallelogram +
	# layered glow outline — no transforms (the watermark shear pair stays the
	# only draw_set_transform in this screen, sealed by the backdrop smoke).
	var skew := 11.0
	var plate := PackedVector2Array([
		Vector2(rect.position.x + skew, rect.position.y),
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x - skew, rect.end.y),
		Vector2(rect.position.x, rect.end.y),
	])
	var outline := plate.duplicate()
	outline.append(plate[0])
	draw_colored_polygon(plate, Color(0.016, 0.020, 0.028, 0.92))
	draw_colored_polygon(plate, Color(border_color.r, border_color.g, border_color.b, 0.26 if selected else 0.05))
	if selected:
		draw_polyline(outline, Color(border_color.r, border_color.g, border_color.b, 0.14), 7.0)
		draw_polyline(outline, Color(border_color.r, border_color.g, border_color.b, 0.32), 3.6)
	draw_polyline(outline, Color(border_color.r, border_color.g, border_color.b, 0.95 if selected else 0.40), 1.6)
	var inner := PackedVector2Array([
		plate[0] + Vector2(1.5, 3.0),
		plate[1] + Vector2(-3.0, 3.0),
		plate[2] + Vector2(-1.5, -3.0),
		plate[3] + Vector2(3.0, -3.0),
	])
	inner.append(inner[0])
	draw_polyline(inner, Color(1.0, 1.0, 1.0, 0.10 if selected else 0.04), 1.0)
	var arrow_x: float = rect.end.x - 17.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(arrow_x, rect.get_center().y - 4.0),
		Vector2(arrow_x + 5.0, rect.get_center().y),
		Vector2(arrow_x, rect.get_center().y + 4.0),
	]), Color(border_color.r, border_color.g, border_color.b, 0.95 if selected else 0.42))
	_draw_text_center(ThemeDB.fallback_font, label, rect.get_center() + Vector2(-3.0, 0.0), 16, Color(1.0, 1.0, 1.0, 0.98 if selected else 0.70))


func _draw_language_button(rect: Rect2) -> void:
	var hovered := rect.has_point(get_local_mouse_position())
	var border := Color(0.60, 0.64, 0.72, 0.82 if hovered else 0.42)
	var fill := Color(0.030, 0.033, 0.040, 0.94 if hovered else 0.88)
	_draw_button(rect, "LANGUAGE  %s" % _language_code_label(LanguageSettings.get_language()), border, fill, false)


func _language_code_label(language: String) -> String:
	match LanguageSettings.normalize_language(language):
		LanguageSettings.LANGUAGE_KOREAN:
			return "KO"
		LanguageSettings.LANGUAGE_ENGLISH:
			return "EN"
		LanguageSettings.LANGUAGE_CHINESE:
			return "ZH"
		LanguageSettings.LANGUAGE_JAPANESE:
			return "JA"
		LanguageSettings.LANGUAGE_SPANISH:
			return "ES"
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
			return "PT-BR"
		LanguageSettings.LANGUAGE_RUSSIAN:
			return "RU"
	return language.strip_edges().to_upper()


func _draw_wrapped_text(font: Font, source_text: String, top_left: Vector2, max_width: float, font_size: int, color: Color, line_step: float, max_lines: int) -> void:
	var words := source_text.replace("\n", " ").split(" ", false)
	var lines: Array[String] = []
	var current_line := ""
	for word in words:
		var candidate := word if current_line == "" else "%s %s" % [current_line, word]
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width or current_line == "":
			current_line = candidate
		else:
			lines.append(current_line)
			current_line = word
		if lines.size() >= max_lines:
			break
	if current_line != "" and lines.size() < max_lines:
		lines.append(current_line)
	for line_index in range(lines.size()):
		_draw_text_left(font, lines[line_index], top_left + Vector2(0.0, float(line_index) * line_step), font_size, color)


func _layout_cards(view_size: Vector2) -> Dictionary:
	var rects: Dictionary = {}
	var count: int = visible_indices.size()
	if count <= 0:
		return rects
	var column := _card_column_rect(view_size)
	if view_size.x < 980.0:
		var mobile_card_w: float = min(172.0, (column.size.x - 18.0) / float(count))
		var mobile_card_h: float = column.size.y - 26.0
		var step_x: float = (column.size.x - mobile_card_w) / float(max(1, count - 1))
		for pos in range(count):
			var index := int(visible_indices[pos])
			var scale_factor := float(hover_scales[index])
			var card_size := Vector2(mobile_card_w, mobile_card_h) * scale_factor
			var center := Vector2(column.position.x + mobile_card_w * 0.5 + float(pos) * step_x, column.position.y + column.size.y * 0.54 - float(hover_lifts[index]))
			rects[index] = Rect2(center - card_size * 0.5, card_size)
		return rects
	var padding := 8.0
	var top_pad := 96.0
	var gap := 10.0
	var card_w: float = column.size.x - padding * 2.0
	var available_h: float = column.size.y - top_pad - 92.0 - gap * float(max(0, count - 1))
	# v2 G1 (Slice H 개정): taller roster cards — the portrait fills the left
	# half at full card height so the face reads large (reference parity).
	var card_h: float = min(126.0, available_h / float(count))
	for pos in range(count):
		var index := int(visible_indices[pos])
		var scale_factor := float(hover_scales[index])
		var card_size := Vector2(card_w, card_h) * scale_factor
		var x := column.position.x + padding
		var y := column.position.y + top_pad + float(pos) * (card_h + gap) - float(hover_lifts[index]) * 0.35
		var center := Vector2(x + card_w * 0.5, y + card_h * 0.5)
		rects[index] = Rect2(center - card_size * 0.5, card_size)
	return rects


func _card_column_rect(view_size: Vector2) -> Rect2:
	if view_size.x < 980.0:
		return Rect2(24.0, view_size.y - 248.0, view_size.x - 48.0, 172.0)
	var top := 106.0
	var left: float = clamp(view_size.x * 0.085, 86.0, 150.0)
	# v2 G1: wider column hosts horizontal roster cards (portrait + name + tag).
	var width: float = clamp(view_size.x * 0.152, 246.0, 292.0)
	return Rect2(left, top, width, view_size.y - top - 84.0)


func _language_button_rect(view_size: Vector2) -> Rect2:
	if view_size.x < 980.0:
		var mobile_width: float = min(156.0, max(132.0, view_size.x - 68.0))
		return Rect2(view_size.x - mobile_width - 34.0, 34.0, mobile_width, 32.0)
	var column := _card_column_rect(view_size)
	return Rect2(column.position.x + 14.0, column.end.y - 72.0, column.size.x - 28.0, 34.0)


func _mobile_action_bar_bottom_y(view_size: Vector2) -> float:
	return _card_column_rect(view_size).position.y - 46.0


func _mobile_action_band_top(view_size: Vector2) -> float:
	# Top edge of the whole action band. Below 640px the confirm CTA moves to
	# its own row above the tab row (single-row fixed widths overlap the
	# mythic tab under ~566px — Codex Slice B review P3).
	var bottom_y := _mobile_action_bar_bottom_y(view_size)
	if view_size.x < 640.0:
		return bottom_y - 58.0
	return bottom_y - 8.0


func _preview_rect(view_size: Vector2) -> Rect2:
	if view_size.x < 980.0:
		# Stacked layout budget: preview may not push info/action-bar into the
		# bottom card column (Slice A pixel-QA finding (b)).
		var top := 108.0
		# Narrow+short guard (Codex Slice C review P2): fixed minimum heights
		# must never push the stack past the action band. Reserve info-panel
		# space only when the budget can actually hold it — otherwise the info
		# panel yields entirely (0 height) instead of overlapping the CTA.
		var total_budget: float = _mobile_action_band_top(view_size) - 12.0 - top
		var info_reserve := 0.0
		if total_budget >= 176.0:
			info_reserve = 96.0 + 16.0
		var preview_height: float = clampf(view_size.y * 0.44, 64.0, maxf(64.0, total_budget - info_reserve))
		return Rect2(34.0, top, view_size.x - 68.0, preview_height)
	var card_column := _card_column_rect(view_size)
	var x := card_column.end.x + 24.0
	# v2 G2 (D7 개정): the hero absorbs the old info-panel space, minus the
	# restored full-body rail on the right (user feedback — the hero preview
	# is bust-up art, so the rail is the only full-body read).
	var rail := _full_body_rail_rect(view_size)
	var right_edge: float = (rail.position.x - 24.0) if rail.has_area() else (view_size.x - _layout_right_margin(view_size))
	var width: float = clamp(right_edge - x, 560.0, 1560.0)
	return Rect2(x, 116.0, width, max(360.0, view_size.y - 238.0))


func _full_body_rail_rect(view_size: Vector2) -> Rect2:
	if view_size.x < 980.0:
		return Rect2()
	var column := _card_column_rect(view_size)
	var x := column.end.x + 24.0
	var right_margin := _layout_right_margin(view_size)
	var rail_width: float = clamp(view_size.x * 0.155, 264.0, 300.0)
	# Narrow desktop: the hero keeps its 560px minimum and the rail yields.
	if view_size.x - right_margin - x < 560.0 + 24.0 + rail_width:
		return Rect2()
	return Rect2(view_size.x - right_margin - rail_width, 116.0, rail_width, max(360.0, view_size.y - 238.0))


func _info_panel_rect(view_size: Vector2, preview_rect_value: Rect2) -> Rect2:
	if view_size.x < 980.0:
		var info_top := preview_rect_value.end.y + 16.0
		var info_bottom: float = _mobile_action_band_top(view_size) - 12.0
		# No minimum-height promotion: a floor here overlaps the action band on
		# narrow+short windows. A fully empty Rect2 (not a zero-height rect at
		# a live position) signals the yielded panel — degenerate rects still
		# report intersects() when their position sits inside another rect.
		var info_height: float = min(250.0, info_bottom - info_top)
		if info_height < 1.0:
			return Rect2()
		return Rect2(34.0, info_top, view_size.x - 68.0, info_height)
	# v2 G2 (D7): the desktop info panel is retired — difficulty / skills /
	# ring core live in the hero info overlay, lore stays in the title block.
	return Rect2()


func _layout_right_margin(view_size: Vector2) -> float:
	return clamp(view_size.x * 0.080, 84.0, 156.0)


func _info_panel_width(view_size: Vector2) -> float:
	return clamp(view_size.x * 0.245, 390.0, 500.0)


func _detail_rect(view_size: Vector2, preview_rect_value: Rect2) -> Rect2:
	return _info_panel_rect(view_size, preview_rect_value)


func _character_card_face_source_rect(texture: Texture2D, target: Rect2, character: Dictionary) -> Rect2:
	var texture_size := texture.get_size()
	if texture_size.x <= 1.0 or texture_size.y <= 1.0:
		return Rect2(Vector2.ZERO, texture_size)
	var target_aspect: float = target.size.x / max(1.0, target.size.y)
	var focus_value: Variant = character.get("card_face_focus", Vector2(0.5, 0.28))
	var focus: Vector2 = focus_value if focus_value is Vector2 else Vector2(0.5, 0.28)
	var height_ratio: float = clamp(float(character.get("card_face_source_height_ratio", 0.38)), 0.24, 0.46)
	var source_h: float = texture_size.y * height_ratio
	var source_w: float = source_h * target_aspect
	if source_w > texture_size.x:
		source_w = texture_size.x
		source_h = source_w / max(0.01, target_aspect)
	var center := Vector2(texture_size.x * clamp(focus.x, 0.0, 1.0), texture_size.y * clamp(focus.y, 0.0, 1.0))
	var max_y: float = max(0.0, texture_size.y * 0.66 - source_h)
	var pos := Vector2(
		clamp(center.x - source_w * 0.5, 0.0, max(0.0, texture_size.x - source_w)),
		clamp(center.y - source_h * 0.5, 0.0, max_y)
	)
	return Rect2(pos, Vector2(source_w, source_h))


func _draw_emblem(center: Vector2, accent: Color, glow: Color) -> void:
	var pulse := 1.0 + sin(animation_time * 3.0) * 0.08
	draw_circle(center, 29.0 * pulse, Color(glow.r, glow.g, glow.b, 0.18))
	draw_circle(center, 22.0 * pulse, Color(0.03, 0.04, 0.07, 0.94))
	var pts := PackedVector2Array([
		center + Vector2(0.0, -15.0 * pulse),
		center + Vector2(13.0 * pulse, 0.0),
		center + Vector2(0.0, 15.0 * pulse),
		center + Vector2(-13.0 * pulse, 0.0),
	])
	draw_colored_polygon(pts, Color(accent.r, accent.g, accent.b, 0.92))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color.WHITE, 1.4)


func _character_color(character: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = character.get(key, fallback)
	return value if value is Color else fallback


func _draw_text_left(font: Font, text: String, top_left: Vector2, font_size: int, color: Color) -> void:
	var baseline := top_left + Vector2(0.0, float(font_size))
	draw_string(font, baseline + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.72))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_text_center(font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	draw_string(font, baseline + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.70))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
