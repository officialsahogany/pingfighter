extends Control

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const CharacterSelectPrewarm := preload("res://scripts/ui/character_select_prewarm.gd")
const MainMenuStartTransitionState := preload(
	"res://scripts/ui/main_menu_start_transition_state.gd"
)
const MainMenuGateTransitionProjection := preload(
	"res://scripts/ui/main_menu_gate_transition_projection.gd"
)
const MainMenuTouchStartPrompt := preload(
	"res://scripts/ui/main_menu_touch_start_prompt.gd"
)
const MainMenuSettingsRegistry := preload("res://scripts/ui/main_menu_settings_registry.gd")
const MainMenuAudioController := preload(
	"res://scripts/audio/main_menu_audio_controller.gd"
)
const PauseMenuOverlay := preload("res://scripts/hud/pause_menu_overlay.gd")
const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const DEFAULT_CHARACTER_SELECT_SCENE_PATH := "res://scenes/character_select.tscn"
const ONLINE_LOBBY_SCENE_PATH := "res://scenes/online_lobby.tscn"
const MAIN_MENU_BACKGROUND_PATH := "res://assets/ui/main_menu/lingpia_main_menu_bg_logo.png"
const BGM_TOGGLE_KEY := KEY_B
const ONLINE_SHORTCUT_KEY := KEY_O
const START_TRANSITION_DURATION_SEC := 1.0
const START_TRANSITION_BUTTON_FADE_SEC := 0.18
const START_TRANSITION_BGM_DUCK_DB := 7.0
const START_TRANSITION_BGM_DUCK_SEC := 0.28
const START_TRANSITION_BEAM_STRIP_MAX := 96

@export_file("*.tscn") var character_select_scene_path: String = DEFAULT_CHARACTER_SELECT_SCENE_PATH

@onready var background_rect: TextureRect = $Background
@onready var button_stack: VBoxContainer = $ButtonStack
@onready var start_button: Button = $ButtonStack/StartButton
@onready var settings_button: Button = $ButtonStack/SettingsButton
@onready var quit_button: Button = $ButtonStack/QuitButton
@onready var online_button: Button = $OnlineButton
@onready var quit_confirm_overlay: Control = $QuitConfirmOverlay
@onready var quit_confirm_prompt_label: Label = $QuitConfirmOverlay/DialogPanel/DialogMargin/DialogVBox/PromptLabel
@onready var quit_confirm_yes_button: Button = $QuitConfirmOverlay/DialogPanel/DialogMargin/DialogVBox/ButtonRow/YesButton
@onready var quit_confirm_no_button: Button = $QuitConfirmOverlay/DialogPanel/DialogMargin/DialogVBox/ButtonRow/NoButton
@onready var ambient_layer: Control = $AmbientLayer
@onready var reveal_layer: Control = $RevealLayer

var transitioning: bool = false
var main_menu_audio_controller: MainMenuAudioController = MainMenuAudioController.new()
var start_transition_state: MainMenuStartTransitionState = MainMenuStartTransitionState.new(
	START_TRANSITION_DURATION_SEC
)
var touch_start_prompt: MainMenuTouchStartPrompt = null
var main_menu_settings_overlay: Object = null
var main_menu_settings_registry: MainMenuSettingsRegistry = null
var main_menu_settings_layer: Control = null
var start_transition_layer: Control = null
var settings_overlay_was_active := false
var intro_reveal_active: bool = false
var application_quit_callback: Callable = Callable()
var character_select_prewarm: CharacterSelectPrewarm = null
var character_select_prewarm_finished: bool = false
var _start_transition_tweens: Array[Tween] = []


func _get(property: StringName) -> Variant:
	match str(property):
		"main_menu_bgm_player":
			return main_menu_audio_controller.bgm_player
		"start_transition_sfx_player":
			return main_menu_audio_controller.start_sfx_player
		"main_menu_bgm_muted":
			return main_menu_audio_controller.muted
		"start_transition_active":
			return start_transition_state.active
		"start_transition_elapsed":
			return start_transition_state.elapsed_sec
		"start_prompt_elapsed":
			return touch_start_prompt.elapsed_sec if touch_start_prompt != null else 0.0
		"start_prompt_ribbon":
			return touch_start_prompt
		"start_prompt_label":
			return touch_start_prompt.prompt_label if touch_start_prompt != null else null
	return null


func _ready() -> void:
	LanguageSettings.apply_saved_language()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_main_menu_background()
	_restore_main_menu_bgm_muted()
	_setup_touch_start_prompt()
	_setup_settings_overlay()
	_setup_start_transition_layer()
	_setup_intro_reveal_gate()
	if start_button != null:
		start_button.pressed.connect(_on_start_pressed)
	if settings_button != null:
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button != null:
		quit_button.pressed.connect(_on_quit_pressed)
	if online_button != null:
		online_button.pressed.connect(_on_online_pressed)
	if quit_confirm_yes_button != null:
		quit_confirm_yes_button.pressed.connect(_on_quit_confirmed)
	if quit_confirm_no_button != null:
		quit_confirm_no_button.pressed.connect(_on_quit_canceled)
	refresh_language_texts()
	_start_main_menu_bgm()
	_begin_character_select_background_prewarm()


func _begin_character_select_background_prewarm() -> void:
	# The F10 exhibition reset (and every battle exit) reaches this menu after
	# battle_scene_teardown_lifecycle has wiped the ProjectResourceLoader
	# caches, WITHOUT replaying the boot loading screen that normally
	# re-prewarms the character-select assets. Rebuild that warmth in the
	# background during title idle so the start press does not cold-load the
	# character-select scene on the main thread (multi-second freeze) and the
	# per-character fullframe sheets do not fall back to on-demand streaming
	# ("애니메이션 준비 중" badge). Keep the prewarm object alive for the whole
	# menu lifetime so the later scene change can reuse its PackedScene.
	var scene_path := character_select_scene_path
	if scene_path == "":
		scene_path = DEFAULT_CHARACTER_SELECT_SCENE_PATH
	character_select_prewarm = CharacterSelectPrewarm.new()
	character_select_prewarm.begin(scene_path)
	character_select_prewarm_finished = false
	_update_character_select_background_prewarm()


func _update_character_select_background_prewarm() -> void:
	if character_select_prewarm_finished or character_select_prewarm == null:
		return
	if not character_select_prewarm.has_method("update"):
		character_select_prewarm_finished = true
		return
	character_select_prewarm_finished = bool(character_select_prewarm.update())


func _ensure_main_menu_background() -> void:
	if background_rect == null or background_rect.texture != null:
		return
	var fallback_texture := ProjectResourceLoader.load_texture(
		MAIN_MENU_BACKGROUND_PATH,
		"Missing main-menu background: %s",
		"Failed to load main-menu background: %s"
	)
	if fallback_texture == null:
		return
	if fallback_texture.resource_path == "":
		fallback_texture.resource_path = MAIN_MENU_BACKGROUND_PATH
	background_rect.texture = fallback_texture


func _exit_tree() -> void:
	set_process(false)
	if start_transition_state != null:
		start_transition_state.cancel()
	_kill_start_transition_tweens()
	application_quit_callback = Callable()
	_clear_settings_overlay_runtime_state()
	main_menu_settings_overlay = null
	main_menu_settings_registry = null
	_stop_main_menu_bgm()
	_stop_start_transition_sfx()
	if character_select_prewarm != null:
		character_select_prewarm.cancel_and_drain_current_request()
	character_select_prewarm = null
	touch_start_prompt = null
	start_transition_state = null
	main_menu_audio_controller = null


func _process(delta: float) -> void:
	if touch_start_prompt != null:
		touch_start_prompt.advance(delta, start_transition_state.active)
	_update_character_select_background_prewarm()
	if start_transition_state.active:
		var transition_finished := start_transition_state.advance(delta)
		if start_transition_layer != null:
			start_transition_layer.queue_redraw()
		if transition_finished:
			call_deferred("_change_to_character_select")
	if _is_settings_overlay_active():
		main_menu_settings_overlay.update(delta)
		if main_menu_settings_layer != null:
			main_menu_settings_layer.queue_redraw()


func _input(event: InputEvent) -> void:
	if _handle_bgm_toggle_input(event):
		return
	if _handle_online_shortcut_input(event):
		return
	if _is_settings_overlay_active():
		_handle_settings_overlay_input(event)
		return
	if _handle_main_menu_gamepad_input(event):
		return


func _handle_settings_overlay_input(event: InputEvent) -> void:
	var result: Variant = main_menu_settings_overlay.handle_input(
		event,
		self,
		main_menu_settings_registry,
		get_viewport_rect().size
	)
	if _is_overlay_result_handled(result):
		_sync_settings_overlay_layer()
		if main_menu_settings_layer != null:
			main_menu_settings_layer.queue_redraw()
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()


func _handle_main_menu_gamepad_input(event: InputEvent) -> bool:
	if not GamepadInput.is_gamepad_event(event):
		return false
	if GamepadInput.should_suppress_right_stick_event(event):
		_mark_input_as_handled()
		return true
	if transitioning or intro_reveal_active:
		_mark_input_as_handled()
		return true
	if _is_quit_confirmation_open():
		if GamepadInput.is_confirm_event(event):
			_on_quit_confirmed()
			_mark_input_as_handled()
			return true
		if GamepadInput.is_cancel_event(event):
			_on_quit_canceled()
			_mark_input_as_handled()
			return true
		return false
	if GamepadInput.is_confirm_event(event):
		_on_start_pressed()
		_mark_input_as_handled()
		return true
	if GamepadInput.is_cancel_event(event):
		_on_quit_pressed()
		_mark_input_as_handled()
		return true
	return false


func _handle_online_shortcut_input(event: InputEvent) -> bool:
	if transitioning or intro_reveal_active or _is_settings_overlay_active() or _is_quit_confirmation_open():
		return false
	var opens_online := _is_key_pressed(event, ONLINE_SHORTCUT_KEY)
	if event is InputEventJoypadButton:
		var button_event: InputEventJoypadButton = event
		opens_online = opens_online or (
			button_event.pressed
			and button_event.button_index == JOY_BUTTON_Y
		)
	if not opens_online:
		return false
	_on_online_pressed()
	_mark_input_as_handled()
	return true


func _mark_input_as_handled() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if transitioning:
		return
	if intro_reveal_active:
		accept_event()
		return
	if _is_settings_overlay_active():
		accept_event()
		return
	if _is_quit_confirmation_open():
		if GamepadInput.is_confirm_event(event):
			_on_quit_confirmed()
		elif GamepadInput.is_cancel_event(event):
			_on_quit_canceled()
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_on_quit_canceled()
		accept_event()
		return
	if GamepadInput.is_confirm_event(event):
		_on_start_pressed()
		accept_event()
		return
	elif GamepadInput.is_cancel_event(event):
		_on_quit_pressed()
		accept_event()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if not _is_focus_on_menu_button():
					_on_start_pressed()
					accept_event()
			KEY_ESCAPE:
				_on_quit_pressed()
				accept_event()
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_on_start_pressed()
			accept_event()
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			_on_start_pressed()
			accept_event()


func _on_start_pressed() -> void:
	if transitioning:
		return
	if intro_reveal_active:
		return
	if _is_settings_overlay_active():
		return
	transitioning = true
	_start_character_select_entry_transition()


func _on_settings_pressed() -> void:
	if transitioning:
		return
	if intro_reveal_active:
		return
	_open_main_menu_settings()


func _on_online_pressed() -> void:
	if transitioning or intro_reveal_active or _is_settings_overlay_active():
		return
	transitioning = true
	var tree := get_tree()
	if tree == null:
		transitioning = false
		return
	var error := tree.change_scene_to_file(ONLINE_LOBBY_SCENE_PATH)
	if error != OK:
		transitioning = false
		push_warning("Failed to change scene to %s (error %d)" % [ONLINE_LOBBY_SCENE_PATH, error])


func _change_to_character_select() -> void:
	var tree := get_tree()
	if tree == null:
		transitioning = false
		return
	_stop_start_transition_sfx()
	# 메뉴 BGM(조선의 달북)은 여기서 끊지 않는다 — /root 상주 플레이어로
	# 승격해 캐릭터 선택 → 스테이지 로딩까지 이어지고, 전투 BGM 핸드오프
	# (start_battle_bgm)가 해제한다. _exit_tree의 stop_bgm은 persisted
	# 플래그를 보고 스킵된다.
	main_menu_audio_controller.persist_bgm_for_handoff(tree)
	var next_scene_path := character_select_scene_path
	if next_scene_path == "":
		next_scene_path = DEFAULT_CHARACTER_SELECT_SCENE_PATH
	var prewarmed_scene: PackedScene = null
	if character_select_prewarm != null and character_select_prewarm.has_method("get_loaded_scene"):
		prewarmed_scene = character_select_prewarm.get_loaded_scene() as PackedScene
	var error: int = (
		tree.change_scene_to_packed(prewarmed_scene)
		if prewarmed_scene != null
		else tree.change_scene_to_file(next_scene_path)
	)
	if error != OK:
		transitioning = false
		main_menu_audio_controller.cancel_bgm_handoff()
		push_warning("Failed to change scene to %s (error %d)" % [next_scene_path, error])


func _on_quit_pressed() -> void:
	if transitioning:
		return
	if intro_reveal_active:
		return
	if _is_settings_overlay_active():
		return
	if _is_quit_confirmation_open():
		return
	_open_quit_confirmation()


func _on_quit_confirmed() -> void:
	if transitioning:
		return
	transitioning = true
	if quit_confirm_overlay != null:
		quit_confirm_overlay.visible = false
	if application_quit_callback.is_valid():
		application_quit_callback.call()
		return
	var tree := get_tree()
	if tree == null:
		return
	var quit_coordinator := tree.root.get_node_or_null("ApplicationQuitCoordinator")
	if quit_coordinator != null and quit_coordinator.has_method("request_quit"):
		quit_coordinator.call("request_quit")
		return
	tree.quit()


func _on_quit_canceled() -> void:
	if transitioning:
		return
	if quit_confirm_overlay != null:
		quit_confirm_overlay.visible = false
	if quit_button != null and quit_button.visible:
		quit_button.grab_focus()


func _open_quit_confirmation() -> void:
	if quit_confirm_overlay == null:
		_on_quit_confirmed()
		return
	refresh_language_texts()
	quit_confirm_overlay.visible = true
	if quit_confirm_no_button != null:
		quit_confirm_no_button.grab_focus()


func _is_quit_confirmation_open() -> bool:
	return quit_confirm_overlay != null and quit_confirm_overlay.visible


func _setup_touch_start_prompt() -> void:
	if button_stack != null:
		button_stack.anchor_left = 0.5
		button_stack.anchor_top = 1.0
		button_stack.anchor_right = 0.5
		button_stack.anchor_bottom = 1.0
		button_stack.offset_left = -430.0
		button_stack.offset_top = -124.0
		button_stack.offset_right = 430.0
		button_stack.offset_bottom = -50.0
		button_stack.add_theme_constant_override("separation", 0)
	if start_button != null:
		var localized_start_prompt := LanguageSettings.translate(
			"main_menu.start_prompt",
			MainMenuTouchStartPrompt.PROMPT_TEXT
		)
		start_button.text = localized_start_prompt
		start_button.custom_minimum_size = Vector2(845.0, 61.0)
		start_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		start_button.focus_mode = Control.FOCUS_NONE
		start_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		start_button.add_theme_font_size_override(
			"font_size",
			MainMenuTouchStartPrompt.PROMPT_FONT_SIZE
		)
		start_button.add_theme_constant_override("outline_size", 0)
		start_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.0))
		start_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 0.0))
		start_button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 0.0))
		start_button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 0.0))
		start_button.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 0.0))
		start_button.add_theme_stylebox_override(
			"normal",
			_make_touch_start_clear_style()
		)
		start_button.add_theme_stylebox_override(
			"hover",
			_make_touch_start_clear_style()
		)
		start_button.add_theme_stylebox_override(
			"pressed",
			_make_touch_start_clear_style()
		)
		start_button.add_theme_stylebox_override(
			"focus",
			_make_touch_start_clear_style()
		)
		start_button.add_theme_stylebox_override(
			"disabled",
			_make_touch_start_clear_style()
		)
		_setup_touch_start_ribbon(localized_start_prompt)
	if settings_button != null:
		_setup_utility_button(settings_button, "MENU", 176.0)
	if quit_button != null:
		_setup_utility_button(quit_button, "QUIT", 176.0)
	_update_touch_start_prompt_visual()


func refresh_language_texts() -> void:
	var localized_start_prompt := LanguageSettings.translate(
		"main_menu.start_prompt",
		MainMenuTouchStartPrompt.PROMPT_TEXT
	)
	if touch_start_prompt != null:
		touch_start_prompt.set_prompt_text(localized_start_prompt)
	elif start_button != null:
		start_button.text = localized_start_prompt
	if quit_confirm_prompt_label != null:
		quit_confirm_prompt_label.text = LanguageSettings.translate("main_menu.quit_prompt")
	if quit_confirm_yes_button != null:
		quit_confirm_yes_button.text = LanguageSettings.translate("main_menu.yes")
	if quit_confirm_no_button != null:
		quit_confirm_no_button.text = LanguageSettings.translate("main_menu.no")


func _make_touch_start_clear_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	return style


func _setup_utility_button(button: Button, label: String, width: float) -> void:
	button.text = label
	button.visible = false
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(width, 34.0)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_constant_override("outline_size", 2)


func _update_touch_start_prompt_visual() -> void:
	if touch_start_prompt != null:
		touch_start_prompt.sync_visual(start_transition_state.active)


func _setup_touch_start_ribbon(localized_text: String) -> void:
	if start_button == null:
		return
	var existing := start_button.get_node_or_null("PromptRibbon")
	if existing != null:
		start_button.remove_child(existing)
		existing.queue_free()
	touch_start_prompt = MainMenuTouchStartPrompt.new()
	start_button.add_child(touch_start_prompt)
	touch_start_prompt.configure(start_button, localized_text)
	_update_touch_start_prompt_visual()


func _setup_start_transition_layer() -> void:
	if start_transition_layer != null:
		return
	start_transition_layer = Control.new()
	start_transition_layer.name = "StartTransitionLayer"
	start_transition_layer.visible = false
	start_transition_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_transition_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_transition_layer.z_index = 50
	start_transition_layer.draw.connect(_draw_start_transition_layer)
	add_child(start_transition_layer)


func _start_character_select_entry_transition() -> void:
	_request_skip_battle_logo_once()
	start_transition_state.begin()
	_set_menu_buttons_disabled(true)
	_kill_start_transition_tweens()
	_start_button_stack_fade_tween()
	_start_ambient_layer_fade_tween()
	_start_bgm_duck_tween()
	if start_transition_layer != null:
		start_transition_layer.visible = true
		start_transition_layer.queue_redraw()
	_play_start_transition_sound()


func _request_skip_battle_logo_once() -> void:
	var state := get_node_or_null("/root/GameSelectionState")
	if state != null and state.has_method("request_skip_battle_logo_once"):
		state.request_skip_battle_logo_once()


func _start_button_stack_fade_tween() -> void:
	if button_stack == null:
		return
	button_stack.modulate = Color(1.0, 1.0, 1.0, button_stack.modulate.a)
	var tween: Tween = create_tween()
	_track_start_transition_tween(tween)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(
		button_stack,
		"modulate:a",
		0.0,
		START_TRANSITION_BUTTON_FADE_SEC
	)


func _start_ambient_layer_fade_tween() -> void:
	if ambient_layer == null:
		return
	var tween: Tween = create_tween()
	_track_start_transition_tween(tween)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(
		ambient_layer,
		"modulate:a",
		0.0,
		START_TRANSITION_BUTTON_FADE_SEC
	)


func _start_bgm_duck_tween() -> void:
	var bgm_player := main_menu_audio_controller.bgm_player
	if bgm_player == null or not bgm_player.playing:
		return
	var current_db: float = bgm_player.volume_db
	var tween: Tween = create_tween()
	_track_start_transition_tween(tween)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(
		bgm_player,
		"volume_db",
		current_db - START_TRANSITION_BGM_DUCK_DB,
		START_TRANSITION_BGM_DUCK_SEC
	)


func _set_menu_buttons_disabled(disabled: bool) -> void:
	if start_button != null:
		start_button.disabled = disabled
	if settings_button != null:
		settings_button.disabled = disabled
	if quit_button != null:
		quit_button.disabled = disabled


func _draw_start_transition_layer() -> void:
	if start_transition_layer == null or not start_transition_layer.visible:
		return
	var view_size: Vector2 = start_transition_layer.size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		view_size = get_viewport_rect().size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	var progress := start_transition_state.get_progress()
	var frame := MainMenuGateTransitionProjection.build_frame(progress, view_size)
	var door_shadow_alpha := float(frame.get("door_shadow_alpha", 0.0))
	var left_panel: Rect2 = frame.get("left_panel_rect", Rect2())
	var right_panel: Rect2 = frame.get("right_panel_rect", Rect2())
	var edge_feather_px := float(frame.get("edge_feather_px", 36.0))
	if left_panel.size.x > 0.0:
		_draw_gate_shadow_panel(
			left_panel,
			Color(0.004, 0.008, 0.018, door_shadow_alpha),
			edge_feather_px,
			true
		)
	if right_panel.size.x > 0.0:
		_draw_gate_shadow_panel(
			right_panel,
			Color(0.004, 0.008, 0.018, door_shadow_alpha),
			edge_feather_px,
			false
		)
	_draw_gate_spirit_light(frame)
	var whitewash_alpha := float(frame.get("whitewash_alpha", 0.0))
	if whitewash_alpha > 0.001:
		start_transition_layer.draw_rect(
			Rect2(Vector2.ZERO, view_size),
			Color(0.90, 0.98, 1.0, whitewash_alpha)
		)


func _draw_gate_spirit_light(frame: Dictionary) -> void:
	var beam_rect: Rect2 = frame.get("beam_rect", Rect2())
	if beam_rect.size.x <= 0.0 or beam_rect.size.y <= 0.0:
		return
	var strip_count := clampi(int(ceil(beam_rect.size.x / 8.0)), 3, START_TRANSITION_BEAM_STRIP_MAX)
	var strip_width := beam_rect.size.x / float(strip_count)
	var start_light_scale := float(frame.get("start_light_scale", 1.0))
	var beam_alpha := clampf(float(frame.get("beam_alpha", 0.0)) * start_light_scale, 0.0, 1.0)
	var edge_feather_px := minf(float(frame.get("edge_feather_px", 36.0)), beam_rect.size.y)
	var light_peak_y := float(frame.get("light_peak_y", beam_rect.get_center().y))
	var light_top_weight := float(frame.get("light_top_weight", 0.28))
	var light_bottom_weight := float(frame.get("light_bottom_weight", 0.55))
	for strip_index in strip_count:
		var normalized := (float(strip_index) + 0.5) / float(strip_count)
		var center_fade := pow(1.0 - absf(normalized * 2.0 - 1.0), 1.55)
		var strip_rect := Rect2(
			Vector2(beam_rect.position.x + float(strip_index) * strip_width, beam_rect.position.y),
			Vector2(strip_width + 1.0, beam_rect.size.y)
		)
		_draw_gate_light_vertical_gradient_rect(
			strip_rect,
			Color(0.22, 0.80, 1.0, beam_alpha * center_fade * 0.76),
			edge_feather_px,
			light_peak_y,
			light_top_weight,
			light_bottom_weight
		)
	var core_width := clampf(beam_rect.size.x * 0.020, 3.0, 14.0)
	var core_rect := Rect2(
		Vector2(beam_rect.get_center().x - core_width * 0.5, beam_rect.position.y),
		Vector2(core_width, beam_rect.size.y)
	)
	_draw_gate_light_vertical_gradient_rect(
		core_rect,
		Color(0.92, 0.99, 1.0, clampf(float(frame.get("core_alpha", 0.0)) * start_light_scale, 0.0, 1.0)),
		edge_feather_px,
		light_peak_y,
		light_top_weight,
		light_bottom_weight
	)


func _draw_gate_shadow_panel(rect: Rect2, color: Color, feather_px: float, fade_at_right: bool) -> void:
	var fade_width := clampf(feather_px, 1.0, rect.size.x)
	var transparent := Color(color.r, color.g, color.b, 0.0)
	if fade_at_right:
		var fade_start_x := rect.end.x - fade_width
		if fade_start_x > rect.position.x:
			start_transition_layer.draw_rect(
				Rect2(rect.position, Vector2(fade_start_x - rect.position.x, rect.size.y)),
				color
			)
		start_transition_layer.draw_polygon(
			PackedVector2Array([
				Vector2(fade_start_x, rect.position.y),
				Vector2(rect.end.x, rect.position.y),
				Vector2(rect.end.x, rect.end.y),
				Vector2(fade_start_x, rect.end.y),
			]),
			PackedColorArray([color, transparent, transparent, color])
		)
		return
	var fade_end_x := rect.position.x + fade_width
	start_transition_layer.draw_polygon(
		PackedVector2Array([
			rect.position,
			Vector2(fade_end_x, rect.position.y),
			Vector2(fade_end_x, rect.end.y),
			Vector2(rect.position.x, rect.end.y),
		]),
		PackedColorArray([transparent, color, color, transparent])
	)
	if fade_end_x < rect.end.x:
		start_transition_layer.draw_rect(
			Rect2(Vector2(fade_end_x, rect.position.y), Vector2(rect.end.x - fade_end_x, rect.size.y)),
			color
		)


func _draw_gate_light_vertical_gradient_rect(
	rect: Rect2,
	color: Color,
	feather_px: float,
	peak_y: float,
	top_weight: float,
	bottom_weight: float
) -> void:
	var fade_height := clampf(feather_px, 1.0, rect.size.y)
	var fade_end_y := minf(rect.position.y + fade_height, rect.end.y)
	var clamped_peak_y := clampf(peak_y, fade_end_y, rect.end.y)
	var transparent := Color(color.r, color.g, color.b, 0.0)
	var top_color := Color(color.r, color.g, color.b, color.a * clampf(top_weight, 0.0, 1.0))
	var bottom_color := Color(color.r, color.g, color.b, color.a * clampf(bottom_weight, 0.0, 1.0))
	start_transition_layer.draw_polygon(
		PackedVector2Array([
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			Vector2(rect.end.x, fade_end_y),
			Vector2(rect.position.x, fade_end_y),
		]),
		PackedColorArray([transparent, transparent, top_color, top_color])
	)
	if clamped_peak_y > fade_end_y:
		start_transition_layer.draw_polygon(
			PackedVector2Array([
				Vector2(rect.position.x, fade_end_y),
				Vector2(rect.end.x, fade_end_y),
				Vector2(rect.end.x, clamped_peak_y),
				Vector2(rect.position.x, clamped_peak_y),
			]),
			PackedColorArray([top_color, top_color, color, color])
		)
	if rect.end.y > clamped_peak_y:
		start_transition_layer.draw_polygon(
			PackedVector2Array([
				Vector2(rect.position.x, clamped_peak_y),
				Vector2(rect.end.x, clamped_peak_y),
				rect.end,
				Vector2(rect.position.x, rect.end.y),
			]),
			PackedColorArray([color, color, bottom_color, bottom_color])
		)


func _setup_intro_reveal_gate() -> void:
	intro_reveal_active = _is_intro_reveal_layer_active()
	_sync_ambient_intro_gate()
	if reveal_layer != null and reveal_layer.has_signal("reveal_finished"):
		var callback := Callable(self, "_on_intro_reveal_finished")
		if not reveal_layer.is_connected("reveal_finished", callback):
			reveal_layer.connect("reveal_finished", callback)


func _on_intro_reveal_finished() -> void:
	intro_reveal_active = false
	_sync_ambient_intro_gate()


func _is_intro_reveal_layer_active() -> bool:
	if reveal_layer == null:
		return false
	if reveal_layer.has_method("is_reveal_active"):
		return bool(reveal_layer.call("is_reveal_active"))
	return reveal_layer.visible


func _sync_ambient_intro_gate() -> void:
	if ambient_layer == null or not ambient_layer.has_method("set_intro_reveal_active"):
		return
	ambient_layer.call("set_intro_reveal_active", intro_reveal_active)


func _setup_settings_overlay() -> void:
	if main_menu_settings_overlay != null:
		return
	main_menu_settings_overlay = PauseMenuOverlay.new()
	main_menu_settings_registry = MainMenuSettingsRegistry.new(
		main_menu_audio_controller.get_audio_settings(),
		BattleViewLayout.new()
	)
	main_menu_settings_layer = Control.new()
	main_menu_settings_layer.name = "SettingsOverlayLayer"
	main_menu_settings_layer.visible = false
	main_menu_settings_layer.focus_mode = Control.FOCUS_ALL
	main_menu_settings_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_menu_settings_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_menu_settings_layer.draw.connect(_draw_settings_overlay)
	add_child(main_menu_settings_layer)


func _clear_settings_overlay_runtime_state() -> void:
	if main_menu_settings_overlay != null:
		if main_menu_settings_overlay.has_method("clear_runtime_state"):
			main_menu_settings_overlay.clear_runtime_state()
		elif main_menu_settings_overlay.has_method("close"):
			main_menu_settings_overlay.close()
	if main_menu_settings_registry != null:
		if main_menu_settings_registry.has_method("clear_runtime_state"):
			main_menu_settings_registry.clear_runtime_state()


func _open_main_menu_settings() -> void:
	if main_menu_settings_overlay == null:
		_setup_settings_overlay()
	if main_menu_settings_overlay == null or main_menu_settings_registry == null:
		return
	main_menu_settings_overlay.open_options(self, main_menu_settings_registry, true)
	_sync_settings_overlay_layer()
	if main_menu_settings_layer != null:
		main_menu_settings_layer.queue_redraw()


func _draw_settings_overlay() -> void:
	if not _is_settings_overlay_active() or main_menu_settings_layer == null:
		return
	main_menu_settings_overlay.draw(
		main_menu_settings_layer,
		self,
		main_menu_settings_registry,
		get_viewport_rect().size
	)


func _sync_settings_overlay_layer() -> void:
	var overlay_active := _is_settings_overlay_active()
	if main_menu_settings_layer != null:
		main_menu_settings_layer.visible = overlay_active
		main_menu_settings_layer.mouse_filter = Control.MOUSE_FILTER_STOP if overlay_active else Control.MOUSE_FILTER_IGNORE
		if overlay_active and not settings_overlay_was_active:
			main_menu_settings_layer.grab_focus()
	if (
		not overlay_active
		and settings_overlay_was_active
		and settings_button != null
		and settings_button.visible
		and not transitioning
	):
		settings_button.grab_focus()
	settings_overlay_was_active = overlay_active


func _is_settings_overlay_active() -> bool:
	return (
		main_menu_settings_overlay != null
		and main_menu_settings_overlay.has_method("is_active")
		and bool(main_menu_settings_overlay.is_active())
	)


func _is_overlay_result_handled(result: Variant) -> bool:
	if result is Dictionary:
		return bool((result as Dictionary).get("handled", false))
	return bool(result)


func _is_focus_on_menu_button() -> bool:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return false
	var focused: Control = viewport.gui_get_focus_owner()
	return (
		focused == start_button
		or focused == settings_button
		or focused == quit_button
		or focused == online_button
	)


func _start_main_menu_bgm() -> void:
	main_menu_audio_controller.start_bgm(self, get_tree())


func _play_start_transition_sound() -> void:
	main_menu_audio_controller.play_start_sfx(self)


func _track_start_transition_tween(tween: Tween) -> void:
	if tween == null:
		return
	_start_transition_tweens.append(tween)


func _kill_start_transition_tweens() -> void:
	for tween in _start_transition_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_start_transition_tweens.clear()


func _stop_main_menu_bgm() -> void:
	main_menu_audio_controller.stop_bgm(get_tree())


func _stop_start_transition_sfx() -> void:
	main_menu_audio_controller.stop_start_sfx()


func _handle_bgm_toggle_input(event: InputEvent) -> bool:
	if not _is_key_pressed(event, BGM_TOGGLE_KEY):
		return false
	_toggle_main_menu_bgm()
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	return true


func _toggle_main_menu_bgm() -> bool:
	return main_menu_audio_controller.toggle_bgm(self, get_tree())


func _restore_main_menu_bgm_muted() -> void:
	main_menu_audio_controller.restore_muted(get_tree())


func _is_key_pressed(event: InputEvent, keycode: int) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == keycode or key_event.physical_keycode == keycode


func _smoothstep01(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _hash01(value: float) -> float:
	return fposmod(sin(value) * 43758.5453, 1.0)
