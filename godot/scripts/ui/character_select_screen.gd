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
const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const BattleEntryBackgroundPrewarm := preload("res://scripts/ui/battle_entry_background_prewarm.gd")
const LingpetAffinityStore := preload("res://scripts/lingpet/lingpet_affinity_store.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")

const CHARACTER_SELECT_BGM_PATH := "res://assets/bgm/character select.wav"
const BGM_BUS_NAME := "BGM"
const BGM_TOGGLE_KEY := KEY_B
const FULL_BODY_LIVE2D_RENA_FLOOR_Y_RATIO := 0.902
const LOCKED_CHARACTER_FEEDBACK_DURATION := 1.4
const DEFAULT_LEAGUE_MODE := "junior"

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
var mythic_rect := Rect2()
var language_rect := Rect2()
var preview_rect_cache := Rect2()
var animation_time: float = 0.0
var preview: Control = null
var selected_league_mode: String = DEFAULT_LEAGUE_MODE
var _lingpet_affinity_store: Object = null
var _cached_lingpet_ring_core_tier: int = 0
var _lingpet_ring_core_icon_renderer: Object = RuntimePerkIconRenderer.new()

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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_ensure_cache_dictionaries()
	characters = LanguageSettings.localize_character_list(CharacterSelectData.get_characters())
	_refresh_visible_indices()
	_load_selection_state()
	_prepare_hover_state()
	_refresh_lingpet_ring_core_cache()
	_prewarm_lingpet_ring_core_icons()
	_load_portraits()
	_restore_character_select_bgm_muted()
	preview = get_node_or_null("LivePreview")
	if preview != null:
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var one_shot_callback := Callable(self, "_on_preview_one_shot_finished")
		if preview.has_signal("one_shot_finished") and not preview.is_connected("one_shot_finished", one_shot_callback):
			preview.connect("one_shot_finished", one_shot_callback)
	_setup_audio_players()
	_setup_confirm_flash_overlay()
	_sync_preview()
	_update_preview_layout()
	queue_redraw()


func _refresh_lingpet_ring_core_cache() -> void:
	_cached_lingpet_ring_core_tier = 0
	if Engine.is_editor_hint():
		return
	if _lingpet_affinity_store == null:
		_lingpet_affinity_store = LingpetAffinityStore.new()
	if _lingpet_affinity_store.has_method("load"):
		_lingpet_affinity_store.load()
	if _lingpet_affinity_store.has_method("get_ring_core_tier"):
		_cached_lingpet_ring_core_tier = clampi(int(_lingpet_affinity_store.get_ring_core_tier()), 0, LingpetAffinityStore.MAX_RING_CORE_TIER)


func _prewarm_lingpet_ring_core_icons() -> void:
	if Engine.is_editor_hint() or _lingpet_ring_core_icon_renderer == null:
		return
	for tier in range(1, LingpetAffinityStore.MAX_RING_CORE_TIER + 1):
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
	_lingpet_affinity_store = null
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
	# The preview VFX host renders at negative canvas z (behind this control's
	# own _draw), so the opaque fullscreen background must leave a hole at the
	# preview rect or the host backdrop is painted over and never visible.
	var backdrop_hole := Rect2()
	if preview != null and preview.has_method("is_backdrop_host_active") and bool(preview.call("is_backdrop_host_active")):
		backdrop_hole = preview_rect_value
	_draw_background(view_size, backdrop_hole)
	_draw_header(view_size)
	var card_column := _card_column_rect(view_size)
	var info_rect := _info_panel_rect(view_size, preview_rect_value)
	_draw_card_column(card_column)
	_draw_preview_frame(preview_rect_value)
	_draw_info_panel(info_rect)
	_draw_action_bar(view_size)
	_draw_skill_hover_tooltip(view_size)


func _resolved_view_size() -> Vector2:
	if size.x > 1.0 and size.y > 1.0:
		return size
	if is_inside_tree() and get_viewport() != null:
		return get_viewport_rect().size
	return Vector2(1920.0, 1080.0)


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


func _update_preview_layout() -> void:
	if preview == null:
		return
	var rect := _preview_rect(_resolved_view_size())
	preview_rect_cache = rect
	preview.position = rect.position
	preview.size = rect.size


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
	var state: Node = get_node_or_null("/root/GameSelectionState")
	if state != null and state.has_method("set_league_mode"):
		state.set_league_mode(selected_league_mode)
	queue_redraw()


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


func _draw_background(view_size: Vector2, backdrop_hole: Rect2 = Rect2()) -> void:
	_draw_rect_excluding_hole(Rect2(Vector2.ZERO, view_size), backdrop_hole, Color(0.007, 0.010, 0.016, 1.0))
	var upper_h: float = view_size.y * 0.39
	_draw_rect_excluding_hole(Rect2(0.0, 0.0, view_size.x, upper_h), backdrop_hole, Color(0.013, 0.030, 0.038, 0.94))
	_draw_rect_excluding_hole(Rect2(0.0, upper_h, view_size.x, view_size.y - upper_h), backdrop_hole, Color(0.009, 0.009, 0.014, 0.97))
	var step: float = max(40.0, view_size.x / 40.0)
	var drift: float = fmod(animation_time * 10.0, step)
	var x: float = -view_size.y * 0.16 + drift
	while x < view_size.x:
		draw_line(Vector2(x, 0.0), Vector2(x + view_size.y * 0.16, view_size.y), Color(0.0, 0.92, 1.0, 0.055), 1.0)
		x += step
	var y: float = 0.0
	while y < view_size.y:
		draw_line(Vector2(0.0, y), Vector2(view_size.x, y), Color(0.0, 0.55, 0.64, 0.025), 1.0)
		y += step * 0.55
	var horizon_color := Color(0.0, 0.95, 1.0, 0.22)
	if backdrop_hole.has_area() and upper_h > backdrop_hole.position.y and upper_h < backdrop_hole.end.y:
		if backdrop_hole.position.x > 0.0:
			draw_line(Vector2(0.0, upper_h), Vector2(backdrop_hole.position.x, upper_h), horizon_color, 1.5)
		if backdrop_hole.end.x < view_size.x:
			draw_line(Vector2(backdrop_hole.end.x, upper_h), Vector2(view_size.x, upper_h), horizon_color, 1.5)
	else:
		draw_line(Vector2(0.0, upper_h), Vector2(view_size.x, upper_h), horizon_color, 1.5)


func _draw_rect_excluding_hole(rect: Rect2, hole: Rect2, color: Color) -> void:
	var cut := rect.intersection(hole)
	if not cut.has_area():
		draw_rect(rect, color)
		return
	if cut.position.y > rect.position.y:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, cut.position.y - rect.position.y)), color)
	if rect.end.y > cut.end.y:
		draw_rect(Rect2(Vector2(rect.position.x, cut.end.y), Vector2(rect.size.x, rect.end.y - cut.end.y)), color)
	if cut.position.x > rect.position.x:
		draw_rect(Rect2(Vector2(rect.position.x, cut.position.y), Vector2(cut.position.x - rect.position.x, cut.size.y)), color)
	if rect.end.x > cut.end.x:
		draw_rect(Rect2(Vector2(cut.end.x, cut.position.y), Vector2(rect.end.x - cut.end.x, cut.size.y)), color)


func _draw_header(view_size: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var column := _card_column_rect(view_size)
	var title_pos := Vector2(column.position.x + 12.0, 54.0)
	if view_size.x < 980.0:
		title_pos = Vector2(34.0, 36.0)
	_draw_text_left(font, LanguageSettings.translate_text("캐릭터 선택"), title_pos, 30 if view_size.x >= 980.0 else 24, Color(1.0, 1.0, 1.0, 0.98))
	_draw_text_left(font, "SELECT YOUR CHARACTER", title_pos + Vector2(0.0, 34.0), 12, Color(0.0, 0.86, 1.0, 0.88))


func _draw_card_column(rect: Rect2) -> void:
	var selected_character: Dictionary = characters[selected_index] if selected_index >= 0 and selected_index < characters.size() else {}
	var accent := _character_color(selected_character, "card_color", Color(0.0, 0.9, 1.0))
	draw_rect(rect, Color(0.025, 0.080, 0.095, 0.28))
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, rect.size.y), Color(accent.r, accent.g, accent.b, 0.10))
	card_rects = _layout_cards(_resolved_view_size())
	for idx in visible_indices:
		_draw_character_card(int(idx), card_rects.get(int(idx), Rect2()))
	language_rect = _language_button_rect(_resolved_view_size())
	_draw_language_button(language_rect, accent)


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
	if selected or hovered:
		draw_rect(rect.grow(8.0), Color(glow.r, glow.g, glow.b, 0.16 if selected else 0.08))
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
	draw_rect(Rect2(rect.position.x, rect.end.y - 34.0, rect.size.x, 34.0), Color(0.0, 0.0, 0.0, 0.72))
	var character_name := str(character.get("character_name", character.get("name", "")))
	_draw_text_center(font, character_name, Vector2(rect.get_center().x, rect.end.y - 17.0), 15, Color.WHITE if unlocked else Color(0.78, 0.82, 0.88, 0.90))
	draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.92 if selected else (0.24 if unlocked else 0.16)), false, 2.0 if selected else 1.0)
	draw_rect(rect.grow(-5.0), Color(1.0, 1.0, 1.0, 0.10 if selected else 0.06), false, 1.0)
	if selected:
		_draw_corner_ticks(rect.grow(6.0), glow, 22.0)


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
	var glow := _character_color(character, "glow_color", accent)
	draw_rect(rect.grow(10.0), Color(glow.r, glow.g, glow.b, 0.09 + sin(animation_time * 2.0) * 0.02))
	draw_rect(rect.grow(6.0), Color(accent.r, accent.g, accent.b, 0.80), false, 2.0)
	draw_rect(rect.grow(0.0), Color(0.0, 0.0, 0.0, 0.22), false, 1.0)
	_draw_corner_ticks(rect.grow(10.0), glow, 40.0)


func _draw_info_panel(rect: Rect2) -> void:
	if selected_index < 0 or selected_index >= characters.size():
		return
	var character: Dictionary = characters[selected_index]
	var accent := _character_color(character, "card_color", Color(0.0, 0.9, 1.0))
	var glow := _character_color(character, "glow_color", accent)
	var font := ThemeDB.fallback_font
	draw_rect(rect.grow(8.0), Color(glow.r, glow.g, glow.b, 0.075))
	draw_rect(rect, Color(0.016, 0.020, 0.031, 0.96))
	draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.76), false, 2.0)
	draw_rect(rect.grow(-6.0), Color(1.0, 1.0, 1.0, 0.075), false, 1.0)
	var layout := _build_info_panel_layout(rect, character, font)
	var character_class_name := str(character.get("class_name", character.get("name", "")))
	var character_name := str(character.get("character_name", character.get("name", "")))
	var unlocked := _is_character_unlocked(character)
	_draw_text_line_block(font, _layout_string_lines(layout, "role_lines"), layout.get("role_top_left", rect.position), 14, Color(accent.r, accent.g, accent.b, 0.94), 18.0)
	_draw_text_left(font, character_name, layout.get("name_top_left", rect.position), 31, Color.WHITE)
	_draw_badge(layout.get("badge_top_left", rect.position), character_class_name, accent)
	_draw_text_line_block(font, _layout_string_lines(layout, "tagline_lines"), layout.get("tagline_top_left", rect.position), 17, Color(0.88, 0.92, 0.97, 0.98), 22.0)
	_draw_text_line_block(font, _layout_string_lines(layout, "description_lines"), layout.get("description_top_left", rect.position), 14, Color(0.73, 0.82, 0.90, 0.96), 20.0)
	_draw_difficulty(layout.get("difficulty_top_left", rect.position), int(character.get("difficulty_stars", 1)), accent)
	if unlocked:
		_draw_text_left(font, LanguageSettings.translate_text("대표 스킬"), layout.get("skills_label_top_left", rect.position), 13, Color(0.82, 0.88, 0.94, 0.92))
		_draw_text_left(font, _lingpet_ring_core_label(), layout.get("ring_core_label_top_left", rect.position), 13, Color(0.82, 0.88, 0.94, 0.92))
		_draw_skill_icons(layout.get("skill_rect", Rect2()), selected_index, character, accent, glow)
		_draw_lingpet_ring_core_slot(layout.get("ring_core_rect", Rect2()), accent, glow)
	else:
		skill_icon_rects.clear()
		_draw_locked_info_status(layout.get("locked_status_rect", Rect2()), character, accent)
	_draw_full_body_live2d_panel(layout.get("full_body_rect", Rect2()), selected_index, character, accent)


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
	var full_body_size := Vector2(max(80.0, rect.size.x - 44.0), max(180.0, rect.end.y - full_body_top - 20.0))
	layout["full_body_rect"] = Rect2(Vector2(rect.position.x + 22.0, full_body_top), full_body_size)
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


func _draw_action_bar(view_size: Vector2) -> void:
	var character: Dictionary = characters[selected_index] if selected_index >= 0 and selected_index < characters.size() else {}
	var accent := _character_color(character, "card_color", Color(0.0, 0.9, 1.0))
	var glow := _character_color(character, "glow_color", accent)
	var bottom_y: float = view_size.y - 98.0
	back_rect = Rect2(_card_column_rect(view_size).position.x + 14.0, bottom_y + 2.0, 106.0, 34.0)
	var center_x: float = view_size.x * 0.5
	junior_rect = Rect2(center_x - 184.0, bottom_y + 2.0, 118.0, 34.0)
	champion_rect = Rect2(center_x - 59.0, bottom_y + 2.0, 118.0, 34.0)
	mythic_rect = Rect2(center_x + 66.0, bottom_y + 2.0, 118.0, 34.0)
	confirm_rect = Rect2(view_size.x - view_size.x * 0.09 - 214.0, bottom_y - 8.0, 214.0, 50.0)
	_draw_button(back_rect, LanguageSettings.translate_text("뒤로"), Color(0.55, 0.60, 0.68, 0.58), Color(0.08, 0.09, 0.12, 0.88), false)
	_draw_league_button(junior_rect, LanguageSettings.translate_text("주니어리그"), "junior", Color(0.38, 0.92, 0.45, 1.0))
	_draw_league_button(champion_rect, LanguageSettings.translate_text("챔피언리그"), "champion", Color(0.82, 0.30, 1.0, 1.0))
	_draw_league_button(mythic_rect, LanguageSettings.translate_text("신화리그"), "mythic", Color(1.0, 0.76, 0.26, 1.0))
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


func _draw_corner_ticks(rect: Rect2, color: Color, length: float) -> void:
	var tick_len: float = min(length, min(rect.size.x, rect.size.y) * 0.35)
	var thickness := 1.8
	var tick_color := Color(color.r, color.g, color.b, 0.88)
	var dim_color := Color(color.r, color.g, color.b, 0.30)
	draw_line(rect.position, rect.position + Vector2(tick_len, 0.0), tick_color, thickness)
	draw_line(rect.position, rect.position + Vector2(0.0, tick_len), tick_color, thickness)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - tick_len, rect.position.y), tick_color, thickness)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + tick_len), tick_color, thickness)
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + tick_len, rect.end.y), tick_color, thickness)
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.end.y - tick_len), tick_color, thickness)
	draw_line(rect.end, rect.end - Vector2(tick_len, 0.0), tick_color, thickness)
	draw_line(rect.end, rect.end - Vector2(0.0, tick_len), tick_color, thickness)
	draw_rect(rect.grow(-5.0), dim_color, false, 1.0)


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
	var tier := clampi(_cached_lingpet_ring_core_tier, 0, LingpetAffinityStore.MAX_RING_CORE_TIER)
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
	draw_rect(rect, Color(0.006, 0.009, 0.014, 0.88))
	var hatch_gap := 14.0
	var hatch_x: float = rect.position.x - rect.size.y
	while hatch_x < rect.end.x:
		draw_line(Vector2(hatch_x, rect.position.y), Vector2(hatch_x + rect.size.y, rect.end.y), Color(accent.r, accent.g, accent.b, 0.055), 1.0)
		hatch_x += hatch_gap
	draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.36), false, 1.0)
	var inner_rect := rect.grow(-10.0)
	var sheet_texture: Texture2D = full_body_live2d_textures.get(character_index, null)
	if sheet_texture != null:
		_draw_full_body_live2d_sheet(sheet_texture, inner_rect, character)
		return
	var still_texture: Texture2D = full_body_live2d_still_textures.get(character_index, null)
	if still_texture != null:
		_draw_texture_contain(still_texture, inner_rect, Color.WHITE)
		return
	var font := ThemeDB.fallback_font
	_draw_text_center(font, LanguageSettings.translate_text("전신 LIVE2D"), rect.get_center() + Vector2(0.0, -14.0), 13, Color(0.72, 0.78, 0.86, 0.86))
	_draw_text_center(font, LanguageSettings.translate_text("준비중"), rect.get_center() + Vector2(0.0, 10.0), 13, Color(0.72, 0.78, 0.86, 0.86))


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
	var font := ThemeDB.fallback_font
	draw_rect(rect.grow(5.0), Color(border.r, border.g, border.b, 0.10 if prominent else 0.04))
	draw_rect(rect, fill)
	draw_rect(rect, Color(border.r, border.g, border.b, 0.92), false, 2.0 if prominent else 1.0)
	draw_rect(rect.grow(-5.0), Color(1.0, 1.0, 1.0, 0.08), false, 1.0)
	_draw_text_center(font, label, rect.get_center(), 20 if prominent else 15, Color.WHITE)


func _draw_league_button(rect: Rect2, label: String, mode: String, border_color: Color) -> void:
	var selected := selected_league_mode == mode
	var fill_alpha := 0.27 if selected else 0.09
	var border_alpha := 0.95 if selected else 0.45
	draw_rect(rect, Color(border_color.r, border_color.g, border_color.b, fill_alpha))
	draw_rect(rect, Color(border_color.r, border_color.g, border_color.b, border_alpha), false, 1.5 if selected else 1.0)
	_draw_text_center(ThemeDB.fallback_font, label, rect.get_center(), 14, Color(1.0, 1.0, 1.0, 0.96 if selected else 0.70))


func _draw_language_button(rect: Rect2, accent: Color) -> void:
	var hovered := rect.has_point(get_local_mouse_position())
	var border := Color(accent.r, accent.g, accent.b, 0.88 if hovered else 0.64)
	var fill := Color(accent.r * 0.16, accent.g * 0.18, accent.b * 0.20, 0.94 if hovered else 0.86)
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
	var gap := 12.0
	var card_w: float = column.size.x - padding * 2.0
	var available_h: float = column.size.y - top_pad - 92.0 - gap * float(max(0, count - 1))
	var card_h: float = min(118.0, available_h / float(count))
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
	var width: float = clamp(view_size.x * 0.114, 178.0, 206.0)
	return Rect2(left, top, width, view_size.y - top - 84.0)


func _language_button_rect(view_size: Vector2) -> Rect2:
	if view_size.x < 980.0:
		var mobile_width: float = min(156.0, max(132.0, view_size.x - 68.0))
		return Rect2(view_size.x - mobile_width - 34.0, 34.0, mobile_width, 32.0)
	var column := _card_column_rect(view_size)
	return Rect2(column.position.x + 14.0, column.end.y - 72.0, column.size.x - 28.0, 34.0)


func _preview_rect(view_size: Vector2) -> Rect2:
	if view_size.x < 980.0:
		return Rect2(34.0, 108.0, view_size.x - 68.0, max(260.0, view_size.y * 0.44))
	var card_column := _card_column_rect(view_size)
	var x := card_column.end.x + 18.0
	var info_x: float = view_size.x - _layout_right_margin(view_size) - _info_panel_width(view_size)
	var width: float = clamp(info_x - x - 22.0, 560.0, 1120.0)
	return Rect2(x, 116.0, width, max(360.0, view_size.y - 238.0))


func _info_panel_rect(view_size: Vector2, preview_rect_value: Rect2) -> Rect2:
	if view_size.x < 980.0:
		return Rect2(34.0, preview_rect_value.end.y + 16.0, view_size.x - 68.0, min(250.0, view_size.y - preview_rect_value.end.y - 96.0))
	var width := _info_panel_width(view_size)
	var x := view_size.x - _layout_right_margin(view_size) - width
	return Rect2(x, 112.0, width, max(360.0, view_size.y - 234.0))


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
