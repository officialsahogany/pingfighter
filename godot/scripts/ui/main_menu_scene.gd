extends Control

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const CharacterSelectPrewarm := preload("res://scripts/ui/character_select_prewarm.gd")
const PauseMenuOverlay := preload("res://scripts/hud/pause_menu_overlay.gd")
const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const BgmMuteState := preload("res://scripts/audio/bgm_mute_state.gd")
const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const DEFAULT_CHARACTER_SELECT_SCENE_PATH := "res://scenes/character_select.tscn"
const MAIN_MENU_BACKGROUND_PATH := "res://assets/ui/main_menu/lingpia_main_menu_bg_logo.png"
const MAIN_MENU_BGM_PATH := "res://assets/bgm/main_menu_moon_crack.wav"
const MAIN_MENU_START_SFX_PATH := "res://assets/sounds/stagestart_godot_short.wav"
const MAIN_MENU_BGM_GAIN := 0.82
const MAIN_MENU_START_SFX_GAIN := 0.78
const DEFAULT_BGM_VOLUME := 0.4
const DEFAULT_SFX_VOLUME := 0.7
const BGM_BUS_NAME := "BGM"
const SFX_BUS_NAME := "SFX"
const BGM_TOGGLE_KEY := KEY_B
const PRELOADED_MAIN_MENU_BGM_PLAYER_NAME := "PreloadedMenuBgmPlayer"
const START_TRANSITION_DURATION_SEC := 1.0
const START_PROMPT_TEXT := "TOUCH TO START"
const START_PROMPT_FONT_SIZE := 40
const START_PROMPT_PULSE_PERIOD_SEC := 2.0
const START_PROMPT_RIBBON_HEIGHT := 40.0
const START_PROMPT_RIBBON_EDGE_FADE_WIDTH := 216.0
const START_TRANSITION_BG_ZOOM := 1.10
const START_TRANSITION_BUTTON_FADE_SEC := 0.18
const START_TRANSITION_BGM_DUCK_DB := 7.0
const START_TRANSITION_BGM_DUCK_SEC := 0.28


class MainMenuAudioSettings:
	extends RefCounted

	const AUDIO_BGM_BUS_NAME := "BGM"
	const AUDIO_SFX_BUS_NAME := "SFX"
	const AUDIO_DEFAULT_BGM_VOLUME := 0.4
	const AUDIO_DEFAULT_SFX_VOLUME := 0.7

	func _init() -> void:
		_ensure_audio_bus(AUDIO_BGM_BUS_NAME, AUDIO_DEFAULT_BGM_VOLUME)
		_ensure_audio_bus(AUDIO_SFX_BUS_NAME, AUDIO_DEFAULT_SFX_VOLUME)

	func get_bgm_volume() -> float:
		return _get_bus_volume(AUDIO_BGM_BUS_NAME, AUDIO_DEFAULT_BGM_VOLUME)

	func set_bgm_volume(value: float) -> float:
		return _set_bus_volume(AUDIO_BGM_BUS_NAME, value, AUDIO_DEFAULT_BGM_VOLUME)

	func get_sfx_volume() -> float:
		return _get_bus_volume(AUDIO_SFX_BUS_NAME, AUDIO_DEFAULT_SFX_VOLUME)

	func set_sfx_volume(value: float) -> float:
		return _set_bus_volume(AUDIO_SFX_BUS_NAME, value, AUDIO_DEFAULT_SFX_VOLUME)

	func _get_bus_volume(bus_name: String, fallback: float) -> float:
		var bus_index: int = _ensure_audio_bus(bus_name, fallback)
		if bus_index < 0:
			return fallback
		var volume_db: float = AudioServer.get_bus_volume_db(bus_index)
		if volume_db <= -79.0:
			return 0.0
		return clampf(db_to_linear(volume_db), 0.0, 1.0)

	func _set_bus_volume(bus_name: String, value: float, fallback: float) -> float:
		var clamped: float = clampf(value, 0.0, 1.0)
		var bus_index: int = _ensure_audio_bus(bus_name, fallback)
		if bus_index >= 0:
			AudioServer.set_bus_volume_db(bus_index, _volume_to_db(clamped))
		return clamped

	func _ensure_audio_bus(bus_name: String, default_volume: float) -> int:
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			return bus_index
		AudioServer.add_bus(AudioServer.get_bus_count())
		bus_index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_index, bus_name)
		AudioServer.set_bus_volume_db(bus_index, _volume_to_db(default_volume))
		return bus_index

	func _volume_to_db(volume: float) -> float:
		var clamped: float = clampf(volume, 0.0, 1.0)
		if clamped <= 0.0:
			return -80.0
		return linear_to_db(clamped)


class MainMenuSettingsRegistry:
	extends RefCounted

	var audio_settings: Object = null
	var view_layout: Object = null

	func _init(audio: Object, layout: Object) -> void:
		audio_settings = audio
		view_layout = layout

	func get_instance(key: String) -> Object:
		match key:
			"game_audio":
				return audio_settings
			"battle_view_layout":
				return view_layout
		return null

	func clear_runtime_state() -> void:
		audio_settings = null
		view_layout = null

@export_file("*.tscn") var character_select_scene_path: String = DEFAULT_CHARACTER_SELECT_SCENE_PATH

@onready var background_rect: TextureRect = $Background
@onready var button_stack: VBoxContainer = $ButtonStack
@onready var start_button: Button = $ButtonStack/StartButton
@onready var settings_button: Button = $ButtonStack/SettingsButton
@onready var quit_button: Button = $ButtonStack/QuitButton
@onready var quit_confirm_overlay: Control = $QuitConfirmOverlay
@onready var quit_confirm_prompt_label: Label = $QuitConfirmOverlay/DialogPanel/DialogMargin/DialogVBox/PromptLabel
@onready var quit_confirm_yes_button: Button = $QuitConfirmOverlay/DialogPanel/DialogMargin/DialogVBox/ButtonRow/YesButton
@onready var quit_confirm_no_button: Button = $QuitConfirmOverlay/DialogPanel/DialogMargin/DialogVBox/ButtonRow/NoButton
@onready var ambient_layer: Control = $AmbientLayer
@onready var reveal_layer: Control = $RevealLayer

var transitioning: bool = false
var main_menu_bgm_player: AudioStreamPlayer = null
var start_transition_sfx_player: AudioStreamPlayer = null
var main_menu_bgm_muted: bool = false
var main_menu_settings_overlay: Object = null
var main_menu_settings_registry: Object = null
var main_menu_settings_layer: Control = null
var start_transition_layer: Control = null
var settings_overlay_was_active := false
var intro_reveal_active: bool = false
var start_prompt_elapsed: float = 0.0
var start_transition_active: bool = false
var start_transition_elapsed: float = 0.0
var start_prompt_ribbon: Control = null
var start_prompt_label: Label = null
var application_quit_callback: Callable = Callable()
var character_select_prewarm: Object = null
var character_select_prewarm_finished: bool = false
var _start_transition_tweens: Array[Tween] = []


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
	start_transition_active = false
	_kill_start_transition_tweens()
	application_quit_callback = Callable()
	_clear_settings_overlay_runtime_state()
	main_menu_settings_overlay = null
	main_menu_settings_registry = null
	_stop_main_menu_bgm()
	_stop_start_transition_sfx()


func _process(delta: float) -> void:
	start_prompt_elapsed += delta
	_update_touch_start_prompt_visual()
	_update_character_select_background_prewarm()
	if start_transition_active:
		start_transition_elapsed = minf(
			start_transition_elapsed + delta,
			START_TRANSITION_DURATION_SEC
		)
		if start_transition_layer != null:
			start_transition_layer.queue_redraw()
		if start_transition_elapsed >= START_TRANSITION_DURATION_SEC:
			start_transition_active = false
			call_deferred("_change_to_character_select")
	if _is_settings_overlay_active():
		main_menu_settings_overlay.update(delta)
		if main_menu_settings_layer != null:
			main_menu_settings_layer.queue_redraw()


func _input(event: InputEvent) -> void:
	if _handle_bgm_toggle_input(event):
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


func _change_to_character_select() -> void:
	var tree := get_tree()
	if tree == null:
		transitioning = false
		return
	_stop_start_transition_sfx()
	_stop_main_menu_bgm()
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
	if tree != null:
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
		start_button.text = START_PROMPT_TEXT
		start_button.custom_minimum_size = Vector2(845.0, 61.0)
		start_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		start_button.focus_mode = Control.FOCUS_NONE
		start_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		start_button.add_theme_font_size_override("font_size", START_PROMPT_FONT_SIZE)
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
		_setup_touch_start_ribbon()
	if settings_button != null:
		_setup_utility_button(settings_button, "MENU", 176.0)
	if quit_button != null:
		_setup_utility_button(quit_button, "QUIT", 176.0)
	_update_touch_start_prompt_visual()


func refresh_language_texts() -> void:
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
	if start_button == null:
		return
	if start_transition_active:
		return
	var pulse: float = 0.5 + 0.5 * sin(start_prompt_elapsed * TAU / START_PROMPT_PULSE_PERIOD_SEC)
	var alpha: float = lerpf(0.90, 1.0, _smoothstep01(pulse))
	start_button.modulate = Color(1.0, 1.0, 1.0, alpha)
	if start_prompt_ribbon != null:
		start_prompt_ribbon.queue_redraw()
	if start_prompt_label != null:
		var color := Color(0.72, 0.88, 0.98, lerpf(0.92, 1.0, _smoothstep01(pulse)))
		start_prompt_label.add_theme_color_override("font_color", color)


func _setup_touch_start_ribbon() -> void:
	if start_button == null:
		return
	var existing := start_button.get_node_or_null("PromptRibbon")
	if existing != null:
		existing.queue_free()
	start_prompt_label = null
	start_prompt_ribbon = Control.new()
	start_prompt_ribbon.name = "PromptRibbon"
	start_prompt_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_prompt_ribbon.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_prompt_ribbon.draw.connect(_draw_touch_start_ribbon)
	start_button.add_child(start_prompt_ribbon)
	var center := CenterContainer.new()
	center.name = "PromptTextCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_prompt_label = Label.new()
	start_prompt_label.name = "PromptText"
	start_prompt_label.text = START_PROMPT_TEXT
	start_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	start_prompt_label.add_theme_font_size_override("font_size", START_PROMPT_FONT_SIZE)
	start_prompt_label.add_theme_constant_override("outline_size", 4)
	start_prompt_label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.08, 0.72))
	var font: Font = start_button.get_theme_font("font")
	if font != null:
		start_prompt_label.add_theme_font_override("font", font)
	center.add_child(start_prompt_label)
	start_prompt_ribbon.add_child(center)
	_update_touch_start_prompt_visual()


func _draw_touch_start_ribbon() -> void:
	if start_prompt_ribbon == null:
		return
	var rect := Rect2(Vector2.ZERO, start_prompt_ribbon.size)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var pulse: float = _smoothstep01(
		0.5 + 0.5 * sin(start_prompt_elapsed * TAU / START_PROMPT_PULSE_PERIOD_SEC)
	)
	var ribbon_height: float = minf(START_PROMPT_RIBBON_HEIGHT, rect.size.y)
	var y: float = (rect.size.y - ribbon_height) * 0.5
	var fade_width: float = minf(START_PROMPT_RIBBON_EDGE_FADE_WIDTH, rect.size.x * 0.34)
	var base_color := Color(0.62, 0.86, 1.0, 0.23 + pulse * 0.08)
	var glow_color := Color(0.88, 0.98, 1.0, 0.12 + pulse * 0.05)
	_draw_faded_touch_start_band(
		start_prompt_ribbon,
		Rect2(Vector2.ZERO, rect.size),
		y,
		ribbon_height,
		fade_width,
		base_color
	)
	_draw_faded_touch_start_band(
		start_prompt_ribbon,
		Rect2(Vector2.ZERO, rect.size),
		y + ribbon_height * 0.22,
		ribbon_height * 0.48,
		fade_width * 0.86,
		glow_color
	)
	var core_rect := Rect2(Vector2(0.0, y + ribbon_height * 0.46), Vector2(rect.size.x, 1.4))
	_draw_faded_touch_start_band(
		start_prompt_ribbon,
		Rect2(Vector2.ZERO, rect.size),
		core_rect.position.y,
		core_rect.size.y,
		fade_width * 0.72,
		Color(0.92, 0.99, 1.0, 0.35 + pulse * 0.10)
	)


func _draw_faded_touch_start_band(
	canvas: Control,
	bounds: Rect2,
	y: float,
	height: float,
	fade_width: float,
	color: Color
) -> void:
	if canvas == null:
		return
	if bounds.size.x <= 1.0 or height <= 0.0:
		return
	var left: float = bounds.position.x
	var right: float = bounds.end.x
	var top: float = y
	var bottom: float = y + height
	var clamped_fade: float = clampf(fade_width, 1.0, bounds.size.x * 0.5)
	var inner_left: float = left + clamped_fade
	var inner_right: float = right - clamped_fade
	var transparent := Color(color.r, color.g, color.b, 0.0)
	if inner_right > inner_left:
		canvas.draw_polygon(
			PackedVector2Array([
				Vector2(inner_left, top),
				Vector2(inner_right, top),
				Vector2(inner_right, bottom),
				Vector2(inner_left, bottom),
			]),
			PackedColorArray([color, color, color, color])
		)
	canvas.draw_polygon(
		PackedVector2Array([
			Vector2(left, top),
			Vector2(inner_left, top),
			Vector2(inner_left, bottom),
			Vector2(left, bottom),
		]),
		PackedColorArray([transparent, color, color, transparent])
	)
	canvas.draw_polygon(
		PackedVector2Array([
			Vector2(inner_right, top),
			Vector2(right, top),
			Vector2(right, bottom),
			Vector2(inner_right, bottom),
		]),
		PackedColorArray([color, transparent, transparent, color])
	)


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
	start_transition_active = true
	start_transition_elapsed = 0.0
	_set_menu_buttons_disabled(true)
	_kill_start_transition_tweens()
	_start_background_zoom_tween()
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


func _start_background_zoom_tween() -> void:
	if background_rect == null:
		return
	var bg_size: Vector2 = background_rect.size
	if bg_size.x <= 1.0 or bg_size.y <= 1.0:
		bg_size = get_viewport_rect().size
	background_rect.pivot_offset = bg_size * 0.5
	var tween: Tween = create_tween()
	_track_start_transition_tween(tween)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(
		background_rect,
		"scale",
		Vector2(START_TRANSITION_BG_ZOOM, START_TRANSITION_BG_ZOOM),
		START_TRANSITION_DURATION_SEC
	)


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
	if main_menu_bgm_player == null or not main_menu_bgm_player.playing:
		return
	var current_db: float = main_menu_bgm_player.volume_db
	var tween: Tween = create_tween()
	_track_start_transition_tween(tween)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(
		main_menu_bgm_player,
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
	var progress: float = clampf(start_transition_elapsed / START_TRANSITION_DURATION_SEC, 0.0, 1.0)
	var transition_ease: float = 1.0 - pow(1.0 - progress, 3.0)
	var dark_alpha: float = lerpf(0.12, 0.62, transition_ease)
	start_transition_layer.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.01, 0.015, 0.035, dark_alpha))
	var flash: float = sin(clampf((progress - 0.68) / 0.32, 0.0, 1.0) * PI)
	var whitewash: float = _smoothstep01(clampf((progress - 0.86) / 0.14, 0.0, 1.0))
	var combined_white: float = clampf(flash * 0.34 + whitewash * 0.78, 0.0, 1.0)
	if combined_white > 0.001:
		start_transition_layer.draw_rect(
			Rect2(Vector2.ZERO, view_size),
			Color(1.0, 0.98, 0.94, combined_white)
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
		MainMenuAudioSettings.new(),
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
	return focused == start_button or focused == settings_button or focused == quit_button


func _start_main_menu_bgm() -> void:
	if Engine.is_editor_hint():
		return
	if main_menu_bgm_player != null and main_menu_bgm_player.playing:
		return
	# Adopt the player the boot flow may have preloaded near the end of
	# the loading screen so the BGM is already playing as the menu opens.
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null:
		var preloaded: Node = tree.root.get_node_or_null(PRELOADED_MAIN_MENU_BGM_PLAYER_NAME)
		var preloaded_player: AudioStreamPlayer = preloaded as AudioStreamPlayer
		if preloaded_player != null:
			main_menu_bgm_player = preloaded_player
			if main_menu_bgm_muted:
				if main_menu_bgm_player.playing:
					main_menu_bgm_player.stop()
			elif not main_menu_bgm_player.playing:
				main_menu_bgm_player.play()
			return
	var stream := ProjectResourceLoader.load_audio_stream(
		MAIN_MENU_BGM_PATH,
		"Missing main-menu BGM: %s",
		"Failed to load main-menu BGM: %s"
	)
	if stream == null:
		return
	_enable_audio_loop(stream)
	_ensure_bgm_bus()
	if main_menu_bgm_player == null:
		main_menu_bgm_player = AudioStreamPlayer.new()
		main_menu_bgm_player.name = "MainMenuBgm"
		add_child(main_menu_bgm_player)
	main_menu_bgm_player.bus = BGM_BUS_NAME
	main_menu_bgm_player.stream = stream
	main_menu_bgm_player.volume_db = _volume_to_db(MAIN_MENU_BGM_GAIN)
	main_menu_bgm_player.pitch_scale = 1.0
	if not main_menu_bgm_muted:
		main_menu_bgm_player.play()


func _play_start_transition_sound() -> void:
	if Engine.is_editor_hint():
		return
	var stream := ProjectResourceLoader.load_audio_stream(
		MAIN_MENU_START_SFX_PATH,
		"Missing main-menu start transition sound: %s",
		"Failed to load main-menu start transition sound: %s"
	)
	if stream == null:
		return
	if start_transition_sfx_player == null:
		start_transition_sfx_player = AudioStreamPlayer.new()
		start_transition_sfx_player.name = "StartTransitionSfx"
		add_child(start_transition_sfx_player)
	_ensure_sfx_bus()
	start_transition_sfx_player.bus = SFX_BUS_NAME
	start_transition_sfx_player.stream = stream
	start_transition_sfx_player.volume_db = _volume_to_db(MAIN_MENU_START_SFX_GAIN)
	start_transition_sfx_player.pitch_scale = 1.0
	start_transition_sfx_player.play()


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
	if main_menu_bgm_player == null:
		return
	if main_menu_bgm_player.playing:
		main_menu_bgm_player.stop()
	main_menu_bgm_player.stream = null
	# If this player was the boot-flow preload (parented to the SceneTree
	# root rather than the menu), free it so it does not linger.
	var tree: SceneTree = get_tree()
	if tree != null and main_menu_bgm_player.get_parent() == tree.root:
		main_menu_bgm_player.queue_free()
	main_menu_bgm_player = null


func _stop_start_transition_sfx() -> void:
	if start_transition_sfx_player == null:
		return
	if start_transition_sfx_player.playing:
		start_transition_sfx_player.stop()
	start_transition_sfx_player.stream = null
	start_transition_sfx_player = null


func _handle_bgm_toggle_input(event: InputEvent) -> bool:
	if not _is_key_pressed(event, BGM_TOGGLE_KEY):
		return false
	_toggle_main_menu_bgm()
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	return true


func _toggle_main_menu_bgm() -> bool:
	main_menu_bgm_muted = BgmMuteState.toggle(get_tree())
	if main_menu_bgm_muted:
		if main_menu_bgm_player != null and main_menu_bgm_player.playing:
			main_menu_bgm_player.stop()
		return true
	if main_menu_bgm_player == null or main_menu_bgm_player.stream == null:
		_start_main_menu_bgm()
	elif not main_menu_bgm_player.playing:
		main_menu_bgm_player.play()
	return false


func _restore_main_menu_bgm_muted() -> void:
	main_menu_bgm_muted = BgmMuteState.is_muted(get_tree())


func _is_key_pressed(event: InputEvent, keycode: int) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == keycode or key_event.physical_keycode == keycode


func _ensure_bgm_bus() -> int:
	var bus_index: int = AudioServer.get_bus_index(BGM_BUS_NAME)
	if bus_index >= 0:
		return bus_index
	AudioServer.add_bus(AudioServer.get_bus_count())
	bus_index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, BGM_BUS_NAME)
	AudioServer.set_bus_volume_db(bus_index, _volume_to_db(DEFAULT_BGM_VOLUME))
	return bus_index


func _ensure_sfx_bus() -> int:
	var bus_index: int = AudioServer.get_bus_index(SFX_BUS_NAME)
	if bus_index >= 0:
		return bus_index
	AudioServer.add_bus(AudioServer.get_bus_count())
	bus_index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, SFX_BUS_NAME)
	AudioServer.set_bus_volume_db(bus_index, _volume_to_db(DEFAULT_SFX_VOLUME))
	return bus_index


func _volume_to_db(volume: float) -> float:
	var clamped: float = clampf(volume, 0.0, 1.0)
	if clamped <= 0.0:
		return -80.0
	return linear_to_db(clamped)


func _enable_audio_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav_stream: AudioStreamWAV = stream
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav_stream.loop_begin = 0
		wav_stream.loop_end = max(0, int(round(wav_stream.get_length() * float(wav_stream.mix_rate))))
	elif stream is AudioStreamMP3:
		var mp3_stream: AudioStreamMP3 = stream
		mp3_stream.loop = true
	elif stream is AudioStreamOggVorbis:
		var ogg_stream: AudioStreamOggVorbis = stream
		ogg_stream.loop = true


func _smoothstep01(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _hash01(value: float) -> float:
	return fposmod(sin(value) * 43758.5453, 1.0)
