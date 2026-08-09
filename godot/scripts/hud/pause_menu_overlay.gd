extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PauseMenuAudioController := preload("res://scripts/hud/pause_menu_audio_controller.gd")
const PauseMenuContentCatalog := preload("res://scripts/hud/pause_menu_content_catalog.gd")
const PauseMenuControlsSettingsController := preload("res://scripts/hud/pause_menu_controls_settings_controller.gd")
const PauseMenuDisplaySettingsController := preload("res://scripts/hud/pause_menu_display_settings_controller.gd")
const PauseMenuDisplaySettingsState := preload("res://scripts/hud/pause_menu_display_settings_state.gd")
const PauseMenuInputCommandRouter := preload("res://scripts/hud/pause_menu_input_command_router.gd")
const PauseMenuLanguageSettingsController := preload("res://scripts/hud/pause_menu_language_settings_controller.gd")
const PauseMenuMainRenderer := preload("res://scripts/hud/pause_menu_main_renderer.gd")
const PauseMenuOverlayLayout := preload("res://scripts/hud/pause_menu_overlay_layout.gd")
const PauseMenuOptionsRenderer := preload("res://scripts/hud/pause_menu_options_renderer.gd")
const PauseMenuOptionsNavigationPolicy := preload("res://scripts/hud/pause_menu_options_navigation_policy.gd")
const PauseMenuOptionsNavigationState := preload("res://scripts/hud/pause_menu_options_navigation_state.gd")
const PauseMenuPointerCommandRouter := preload("res://scripts/hud/pause_menu_pointer_command_router.gd")
const PauseMenuSelectionFeedbackRenderer := preload("res://scripts/hud/pause_menu_selection_feedback_renderer.gd")
const PauseMenuSelectionFeedbackState := preload("res://scripts/hud/pause_menu_selection_feedback_state.gd")
const PauseMenuSessionState := preload("res://scripts/hud/pause_menu_session_state.gd")
const PremiumPanelFrame := preload("res://scripts/hud/premium_panel_frame.gd")
const FONT_BODY: Font = preload("res://assets/fonts/NanumSquareB.ttf")
const FONT_TECH: Font = preload("res://assets/fonts/NeoDunggeunmoPro.ttf")

const MENU_CONTINUE := PauseMenuContentCatalog.MENU_CONTINUE
const MENU_CHARACTER_INFO := PauseMenuContentCatalog.MENU_CHARACTER_INFO
const MENU_OPTIONS := PauseMenuContentCatalog.MENU_OPTIONS
const MENU_EXIT_TO_MAIN := PauseMenuContentCatalog.MENU_EXIT_TO_MAIN
const SOUND_SLIDER_BGM := PauseMenuAudioController.SOUND_SLIDER_BGM
const SOUND_SLIDER_SFX := PauseMenuAudioController.SOUND_SLIDER_SFX
const OPTIONS_TAB_SOUND := PauseMenuOptionsNavigationPolicy.TAB_SOUND
const OPTIONS_TAB_DISPLAY := PauseMenuOptionsNavigationPolicy.TAB_DISPLAY
const OPTIONS_TAB_CONTROLS := PauseMenuOptionsNavigationPolicy.TAB_CONTROLS
const OPTIONS_TAB_LANGUAGE := PauseMenuOptionsNavigationPolicy.TAB_LANGUAGE
const CONTROL_DEVICE_KEYBOARD_MOUSE := PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE
const CONTROL_DEVICE_JOYPAD := PauseMenuOptionsNavigationPolicy.DEVICE_JOYPAD
const DISPLAY_MODE_FULLSCREEN := PauseMenuDisplaySettingsState.DISPLAY_MODE_FULLSCREEN
const DISPLAY_MODE_EXCLUSIVE_FULLSCREEN := PauseMenuDisplaySettingsState.DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
const DISPLAY_MODE_WINDOWED := PauseMenuDisplaySettingsState.DISPLAY_MODE_WINDOWED
const RENDER_FPS_CAP_UNLIMITED := PauseMenuDisplaySettingsState.RENDER_FPS_CAP_UNLIMITED
const RENDER_FPS_CAP_STABILITY := PauseMenuDisplaySettingsState.RENDER_FPS_CAP_STABILITY
const RENDER_FPS_CAP_SMOOTH := PauseMenuDisplaySettingsState.RENDER_FPS_CAP_SMOOTH
const RENDER_FPS_CAP_BALANCED := PauseMenuDisplaySettingsState.RENDER_FPS_CAP_BALANCED
const RENDER_FPS_CAP_MONITOR := PauseMenuDisplaySettingsState.RENDER_FPS_CAP_MONITOR
const RENDER_FPS_CAP_STABLE_MONITOR := PauseMenuDisplaySettingsState.RENDER_FPS_CAP_STABLE_MONITOR
const RENDER_FPS_CAP_DEFAULT := PauseMenuDisplaySettingsState.RENDER_FPS_CAP_DEFAULT
const VSYNC_MODE_AUTO := PauseMenuDisplaySettingsState.VSYNC_MODE_AUTO
const VSYNC_MODE_DISABLED := PauseMenuDisplaySettingsState.VSYNC_MODE_DISABLED
const VSYNC_MODE_ENABLED := PauseMenuDisplaySettingsState.VSYNC_MODE_ENABLED
const VSYNC_MODE_MAILBOX := PauseMenuDisplaySettingsState.VSYNC_MODE_MAILBOX
const MAIN_EDITORIAL_BG_PATH := PauseMenuMainRenderer.MAIN_EDITORIAL_BG_PATH

const OPTIONS_PANEL_SIZE := Vector2(900.0, 500.0)
const BUTTON_SIZE := Vector2(250.0, 48.0)
const BUTTON_GAP := 14.0
const TITLE_HEIGHT := 82.0
const MAIN_ROW_PITCH := 96.0
const MAIN_ROW_HEIGHT := 92.0
const MAIN_ROW_START_RATIO := 0.36
const MAIN_ROW_BAR_WIDTH_RATIO := 0.62
const MAIN_LEFT_MARGIN := 92.0
const MAIN_SELECTED_BAR_HEIGHT := 88.0
const MAIN_DIAL_ROTATIONS_PER_SECOND := PauseMenuMainRenderer.MAIN_DIAL_ROTATIONS_PER_SECOND
const MAIN_TITLE_LEFT_MARGIN := 10.0
const MAIN_LIST_ANCHOR_RATIO := 0.25
const OPEN_BG_FADE_SECONDS := PauseMenuMainRenderer.OPEN_BG_FADE_SECONDS
const OPEN_CHROME_FADE_SECONDS := PauseMenuMainRenderer.OPEN_CHROME_FADE_SECONDS
const OPEN_BAR_SWEEP_SECONDS := PauseMenuMainRenderer.OPEN_BAR_SWEEP_SECONDS
const OPEN_TEXT_FADE_DELAY_SECONDS := PauseMenuMainRenderer.OPEN_TEXT_FADE_DELAY_SECONDS
const OPEN_TEXT_FADE_SECONDS := PauseMenuMainRenderer.OPEN_TEXT_FADE_SECONDS
const OPEN_ITEM_STAGGER_SECONDS := PauseMenuMainRenderer.OPEN_ITEM_STAGGER_SECONDS
const OPEN_ITEM_SLIDE_X := PauseMenuMainRenderer.OPEN_ITEM_SLIDE_X
const OPEN_OPTIONS_SECONDS := 0.18
const OPEN_OPTIONS_SLIDE_Y := 14.0
const SLIDER_HEIGHT := 10.0
const SLIDER_HIT_HEIGHT := 34.0
const SLIDER_HANDLE_RADIUS := PauseMenuOptionsRenderer.SLIDER_HANDLE_RADIUS
const VOLUME_STEP := 0.05
const DEFAULT_BGM_VOLUME := PauseMenuAudioController.DEFAULT_BGM_VOLUME
const DEFAULT_SFX_VOLUME := PauseMenuAudioController.DEFAULT_SFX_VOLUME
const SOUND_FOCUS_COUNT := PauseMenuOptionsNavigationPolicy.SOUND_FOCUS_COUNT
const DISPLAY_FOCUS_COUNT := PauseMenuOptionsNavigationPolicy.DISPLAY_FOCUS_COUNT
const CONTROLS_BASE_FOCUS_COUNT := PauseMenuOptionsNavigationPolicy.CONTROLS_BASE_FOCUS_COUNT
const CONTROLS_JOYPAD_FOCUS_COUNT := PauseMenuOptionsNavigationPolicy.CONTROLS_JOYPAD_FOCUS_COUNT
const LANGUAGE_FOCUS_COUNT := PauseMenuOptionsNavigationPolicy.LANGUAGE_FOCUS_COUNT
const SELECTION_SCOPE_MAIN := "main"

const PANEL_COLOR := PauseMenuOptionsRenderer.PANEL_COLOR
const PANEL_BORDER := PauseMenuOptionsRenderer.PANEL_BORDER
const HEADER_COLOR := PauseMenuOptionsRenderer.HEADER_COLOR
const SECTION_COLOR := PauseMenuOptionsRenderer.SECTION_COLOR
const BUTTON_COLOR := PauseMenuOptionsRenderer.BUTTON_COLOR
const BUTTON_HOVER := PauseMenuOptionsRenderer.BUTTON_HOVER
const BUTTON_SELECTED := PauseMenuOptionsRenderer.BUTTON_SELECTED
const BUTTON_BORDER := PauseMenuOptionsRenderer.BUTTON_BORDER
const SLIDER_BACK := PauseMenuOptionsRenderer.SLIDER_BACK
const TEXT_DIM := PauseMenuOptionsRenderer.TEXT_DIM
const ACCENT_BLUE := PauseMenuOptionsRenderer.ACCENT_BLUE
const ACCENT_GREEN := PauseMenuOptionsRenderer.ACCENT_GREEN
const ACCENT_GOLD := PauseMenuOptionsRenderer.ACCENT_GOLD
const NEON_CYAN := PauseMenuOptionsRenderer.NEON_CYAN
const NEON_CYAN_HOT := PauseMenuOptionsRenderer.NEON_CYAN_HOT
const RESONANCE_MAG := PauseMenuOptionsRenderer.RESONANCE_MAG
const NEON_GREEN := PauseMenuOptionsRenderer.NEON_GREEN
const WARM_GOLD := PauseMenuOptionsRenderer.WARM_GOLD
const TEXT_WARM := PauseMenuOptionsRenderer.TEXT_WARM
# Editorial pause menu tokens — Hwangyeokjeon ink-and-gilt palette, Slice 1.
# Compatibility names stay in place while the later shape slices land.
const PAPER_BG := PauseMenuMainRenderer.PAPER_BG
const INK := PauseMenuMainRenderer.INK
const INK_DIM := PauseMenuOptionsRenderer.INK_DIM
const SELECT_BLUE := PauseMenuMainRenderer.SELECT_BLUE
const SELECT_SUBINK := PauseMenuMainRenderer.SELECT_SUBINK
const GRAPHIC_INK := PauseMenuMainRenderer.GRAPHIC_INK
const TITLE_ON_GRAPHIC_INK := PauseMenuMainRenderer.TITLE_ON_GRAPHIC_INK
const DIAMOND_GRAY := PauseMenuMainRenderer.DIAMOND_GRAY
const SPINE_LINE := PauseMenuMainRenderer.SPINE_LINE
const SEAL_RED := PauseMenuMainRenderer.SEAL_RED
const SPIRIT_BLUE := PauseMenuMainRenderer.SPIRIT_BLUE
const OPT_SLIDER_BGM_FILL := PauseMenuOptionsRenderer.OPT_SLIDER_BGM_FILL
const OPT_SLIDER_SFX_FILL := PauseMenuOptionsRenderer.OPT_SLIDER_SFX_FILL
const OPT_PANEL := PauseMenuOptionsRenderer.OPT_PANEL
const OPT_HEADER := PauseMenuOptionsRenderer.OPT_HEADER
const OPT_CARD := PauseMenuOptionsRenderer.OPT_CARD
const OPT_CARD_HOVER := PauseMenuOptionsRenderer.OPT_CARD_HOVER
const OPT_BORDER := PauseMenuOptionsRenderer.OPT_BORDER
const OPT_TRACK := PauseMenuOptionsRenderer.OPT_TRACK
const OPT_CHECK_ON := PauseMenuOptionsRenderer.OPT_CHECK_ON

var _audio_controller := PauseMenuAudioController.new()
var _controls_settings_controller := PauseMenuControlsSettingsController.new()
var _display_settings_state := PauseMenuDisplaySettingsState.new()
var _display_settings_controller := PauseMenuDisplaySettingsController.new(_display_settings_state)
var _input_command_router := PauseMenuInputCommandRouter.new()
var _language_settings_controller := PauseMenuLanguageSettingsController.new()
var _main_renderer := PauseMenuMainRenderer.new()
var _options_renderer := PauseMenuOptionsRenderer.new()
var _options_navigation_state := PauseMenuOptionsNavigationState.new()
var _pointer_command_router := PauseMenuPointerCommandRouter.new()
var _selection_feedback_renderer := PauseMenuSelectionFeedbackRenderer.new()
var _selection_feedback_state: PauseMenuSelectionFeedbackState = PauseMenuSelectionFeedbackState.new()
var _session_state := PauseMenuSessionState.new()

var active: bool:
	get: return _session_state.active
	set(value): _session_state.active = value
var options_open: bool:
	get: return _session_state.options_open
	set(value): _session_state.options_open = value
var animation_time: float:
	get: return _session_state.animation_time
	set(value): _session_state.animation_time = value
var selected_index: int:
	get: return _session_state.selected_index
	set(value): _session_state.selected_index = value
var dragging_slider: String:
	get: return _session_state.dragging_slider
	set(value): _session_state.dragging_slider = value
var options_only: bool:
	get: return _session_state.options_only
	set(value): _session_state.options_only = value
var _main_dial_time: float:
	get: return _session_state.main_dial_time
	set(value): _session_state.main_dial_time = value

var options_focus: int:
	get: return _options_navigation_state.options_focus
	set(value): _options_navigation_state.options_focus = value
var options_tab: String:
	get: return _options_navigation_state.options_tab
	set(value): _options_navigation_state.options_tab = value
var controls_device_view: String:
	get: return _options_navigation_state.controls_device_view
	set(value): _options_navigation_state.controls_device_view = value

var display_mode: String:
	get: return _display_settings_state.display_mode
	set(value): _display_settings_state.display_mode = value
var remember_display_mode: bool:
	get: return _display_settings_state.remember_display_mode
	set(value): _display_settings_state.remember_display_mode = value
var auto_refresh_rate_60hz: bool:
	get: return _display_settings_state.auto_refresh_rate_60hz
	set(value): _display_settings_state.auto_refresh_rate_60hz = value
var render_fps_cap: int:
	get: return _display_settings_state.render_fps_cap
	set(value): _display_settings_state.render_fps_cap = value
var vsync_mode: int:
	get: return _display_settings_state.vsync_mode
	set(value): _display_settings_state.vsync_mode = value
var _synced_display_mode: String:
	get: return _display_settings_state._synced_display_mode
	set(value): _display_settings_state._synced_display_mode = value
var _synced_remember_display_mode: bool:
	get: return _display_settings_state._synced_remember_display_mode
	set(value): _display_settings_state._synced_remember_display_mode = value
var _synced_auto_refresh_rate_60hz: bool:
	get: return _display_settings_state._synced_auto_refresh_rate_60hz
	set(value): _display_settings_state._synced_auto_refresh_rate_60hz = value
var _display_preference_dirty: bool:
	get: return _display_settings_state.preference_dirty
	set(value): _display_settings_state.preference_dirty = value
var _main_editorial_bg_texture: Texture2D:
	get: return _main_renderer.background_texture
	set(value): _main_renderer.background_texture = value

var gamepad_vibration_level: int:
	get: return _controls_settings_controller.vibration_level
	set(value): _controls_settings_controller.vibration_level = value
var language_code: String:
	get: return _language_settings_controller.language_code
	set(value): _language_settings_controller.language_code = value


func is_active() -> bool:
	return active


func is_options_open() -> bool:
	return active and options_open


func open() -> void:
	_session_state.open_main()
	_options_navigation_state.reset()
	prewarm_assets()
	_reset_selection_feedback(SELECTION_SCOPE_MAIN, selected_index)
	_reset_hover_tracking()


func prewarm_assets() -> void:
	_main_renderer.prewarm_assets()
	_main_renderer.get_main_brush_font(FONT_BODY)


func close() -> void:
	_session_state.close()
	_options_navigation_state.reset()
	_reset_selection_feedback(SELECTION_SCOPE_MAIN, selected_index)
	_reset_hover_tracking()


func clear_runtime_state() -> void:
	close()
	_main_renderer.clear_assets()


func toggle() -> void:
	if active:
		close()
	else:
		open()


func open_options(owner: Object, registry: Object, direct_options_only: bool = false) -> void:
	_session_state.begin_options(direct_options_only)
	prewarm_assets()
	_open_options(owner, registry)
	_reset_selection_feedback(_get_options_feedback_scope(), options_focus)


func update(delta: float) -> void:
	if not _session_state.advance(delta, 1.0 / maxf(MAIN_DIAL_ROTATIONS_PER_SECOND, 0.001)):
		return
	_selection_feedback_state.advance(delta)


func handle_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> Dictionary:
	if not active:
		return {"handled": false}
	if event is InputEventKey:
		return _handle_key_input(event as InputEventKey, owner, registry)
	if GamepadInput.is_gamepad_event(event):
		return _handle_gamepad_input(event, owner, registry)
	if event is InputEventMouseButton:
		return _handle_mouse_button(event as InputEventMouseButton, owner, registry, view_size)
	if event is InputEventMouseMotion:
		return _handle_mouse_motion(event as InputEventMouseMotion, registry, view_size)
	return {"handled": true}


func draw(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2) -> void:
	if not active or canvas == null:
		return
	var font: Font = _get_ui_font()
	if font == null:
		return
	var mouse_pos: Vector2 = _get_mouse_position(canvas)

	if options_open:
		var options_open_ratio := _get_options_open_ratio()
		var panel_rect: Rect2 = _get_active_panel_rect(view_size).grow(-8.0 * (1.0 - options_open_ratio))
		panel_rect.position.y += (1.0 - options_open_ratio) * OPEN_OPTIONS_SLIDE_Y
		_draw_main_editorial_base(canvas, Rect2(Vector2.ZERO, view_size), _get_open_bg_alpha())
		_draw_panel(canvas, panel_rect, OPT_PANEL, OPT_BORDER, 1.0, false, false, PremiumPanelFrame.KIND_SECTION)
		_draw_options_window(canvas, font, panel_rect, mouse_pos, registry, owner)
	else:
		_draw_main_menu(canvas, font, _get_main_panel_rect(view_size), mouse_pos)


func _handle_key_input(key_event: InputEventKey, owner: Object, registry: Object) -> Dictionary:
	return _execute_input_command(
		_input_command_router.route_key(key_event, options_open, options_tab, options_focus, controls_device_view),
		owner,
		registry
	)


func _handle_options_key_input(key_event: InputEventKey, owner: Object, registry: Object) -> Dictionary:
	return _execute_input_command(
		_input_command_router.route_options_key(key_event, options_tab, options_focus, controls_device_view),
		owner,
		registry
	)


func _handle_gamepad_input(event: InputEvent, owner: Object, registry: Object) -> Dictionary:
	return _execute_input_command(
		_input_command_router.route_gamepad(event, options_open, options_tab, options_focus, controls_device_view),
		owner,
		registry
	)


func _handle_options_gamepad_input(event: InputEvent, owner: Object, registry: Object) -> Dictionary:
	return _execute_input_command(
		_input_command_router.route_options_gamepad(event, options_tab, options_focus, controls_device_view),
		owner,
		registry
	)


func _handle_sound_key_input(key_event: InputEventKey, registry: Object) -> Dictionary:
	return _execute_input_command(_input_command_router.route_sound_key(key_event, options_focus), null, registry)


func _handle_display_key_input(key_event: InputEventKey, owner: Object, registry: Object) -> Dictionary:
	return _execute_input_command(_input_command_router.route_display_key(key_event, options_focus), owner, registry)


func _handle_controls_key_input(key_event: InputEventKey, registry: Object) -> Dictionary:
	return _execute_input_command(_input_command_router.route_controls_key(key_event, controls_device_view), null, registry)


func _handle_language_key_input(key_event: InputEventKey, owner: Object, registry: Object) -> Dictionary:
	return _execute_input_command(_input_command_router.route_language_key(key_event, options_focus), owner, registry)


func _handle_sound_gamepad_input(event: InputEvent, registry: Object) -> Dictionary:
	return _execute_input_command(_input_command_router.route_sound_gamepad(event, options_focus), null, registry)


func _handle_display_gamepad_input(event: InputEvent, owner: Object, registry: Object) -> Dictionary:
	return _execute_input_command(_input_command_router.route_display_gamepad(event), owner, registry)


func _handle_controls_gamepad_input(event: InputEvent, registry: Object) -> Dictionary:
	return _execute_input_command(_input_command_router.route_controls_gamepad(event, controls_device_view), null, registry)


func _handle_language_gamepad_input(event: InputEvent, owner: Object, registry: Object) -> Dictionary:
	return _execute_input_command(_input_command_router.route_language_gamepad(event, options_focus), owner, registry)


func _execute_input_command(command: Dictionary, owner: Object, registry: Object) -> Dictionary:
	var command_name := StringName(command.get("command", PauseMenuInputCommandRouter.COMMAND_NONE))
	var direction := int(command.get("direction", 0))
	if command.has("focus"):
		options_focus = int(command.get("focus", options_focus))
	match command_name:
		PauseMenuInputCommandRouter.COMMAND_CLOSE_MAIN:
			_play_ui_back(registry)
			close()
			return {"handled": true, "action": MENU_CONTINUE}
		PauseMenuInputCommandRouter.COMMAND_MOVE_MAIN:
			_move_selection(direction, registry)
		PauseMenuInputCommandRouter.COMMAND_ACTIVATE_MAIN:
			return _activate_selected(owner, registry)
		PauseMenuInputCommandRouter.COMMAND_CLOSE_OPTIONS:
			_play_ui_back(registry)
			return _close_options_page()
		PauseMenuInputCommandRouter.COMMAND_SWITCH_TAB:
			_switch_options_tab(direction, owner, registry)
			_play_ui_move(registry)
		PauseMenuInputCommandRouter.COMMAND_MOVE_OPTIONS_FOCUS:
			_move_options_focus(direction, int(command.get("focus_count", 0)), registry)
		PauseMenuInputCommandRouter.COMMAND_ADJUST_VOLUME:
			_adjust_focused_volume(registry, float(direction) * VOLUME_STEP)
		PauseMenuInputCommandRouter.COMMAND_CONFIRM:
			_play_ui_confirm(registry)
		PauseMenuInputCommandRouter.COMMAND_ADJUST_DISPLAY:
			if direction != 0:
				_handle_display_focus_delta(direction, owner, registry)
				if str(command.get("feedback", "")) == "confirm":
					_play_ui_confirm(registry)
		PauseMenuInputCommandRouter.COMMAND_ACTIVATE_DISPLAY:
			if options_focus == DISPLAY_FOCUS_COUNT - 1:
				_play_ui_back(registry)
			else:
				_play_ui_confirm(registry)
			return _activate_display_focus(owner, registry)
		PauseMenuInputCommandRouter.COMMAND_ADJUST_CONTROLS:
			if _adjust_controls_focus(direction):
				if str(command.get("feedback", "")) == "confirm":
					_play_ui_confirm(registry)
				else:
					_play_ui_move(registry)
		PauseMenuInputCommandRouter.COMMAND_ACTIVATE_CONTROLS:
			if options_focus == 0:
				_cycle_control_device_view(1)
				_play_ui_confirm(registry)
			elif _is_controls_vibration_focus():
				_adjust_gamepad_vibration_level(1)
				_play_ui_confirm(registry)
			else:
				_play_ui_back(registry)
				return _close_options_page()
		PauseMenuInputCommandRouter.COMMAND_CYCLE_LANGUAGE:
			_cycle_language(direction, owner)
		PauseMenuInputCommandRouter.COMMAND_ACTIVATE_LANGUAGE:
			if options_focus == LANGUAGE_FOCUS_COUNT - 1:
				_play_ui_back(registry)
			else:
				_play_ui_confirm(registry)
			return _activate_language_focus(owner)
		PauseMenuPointerCommandRouter.COMMAND_CLEAR_DRAG:
			dragging_slider = ""
		PauseMenuPointerCommandRouter.COMMAND_ACTIVATE_MAIN_INDEX:
			selected_index = int(command.get("index", selected_index))
			return _activate_selected(owner, registry)
		PauseMenuPointerCommandRouter.COMMAND_RESET_TAB_DEFAULTS:
			_reset_current_tab_to_defaults(owner, registry)
			_play_ui_confirm(registry)
		PauseMenuPointerCommandRouter.COMMAND_SELECT_TAB:
			if _select_options_tab(str(command.get("tab", options_tab)), owner, registry):
				_play_ui_confirm(registry)
		PauseMenuPointerCommandRouter.COMMAND_BEGIN_SLIDER_DRAG:
			dragging_slider = str(command.get("slider", ""))
			_set_volume_from_slider(
				dragging_slider,
				float(command.get("mouse_x", 0.0)),
				registry,
				command.get("view_size", Vector2.ZERO)
			)
			_play_ui_move(registry)
		PauseMenuPointerCommandRouter.COMMAND_DRAG_SLIDER:
			_set_volume_from_slider(
				str(command.get("slider", "")),
				float(command.get("mouse_x", 0.0)),
				registry,
				command.get("view_size", Vector2.ZERO)
			)
		PauseMenuPointerCommandRouter.COMMAND_SET_DISPLAY_MODE:
			_set_display_mode_option(str(command.get("mode", DISPLAY_MODE_WINDOWED)))
			_play_ui_confirm(registry)
		PauseMenuPointerCommandRouter.COMMAND_TOGGLE_DISPLAY_DEFAULT:
			_display_settings_state.toggle_remember_display_mode()
			_play_ui_confirm(registry)
		PauseMenuPointerCommandRouter.COMMAND_TOGGLE_AUTO_REFRESH:
			_display_settings_state.toggle_auto_refresh_rate()
			_play_ui_confirm(registry)
		PauseMenuPointerCommandRouter.COMMAND_APPLY_RECOMMENDED:
			_apply_recommended_display_settings(owner, registry)
			_play_ui_confirm(registry)
		PauseMenuPointerCommandRouter.COMMAND_APPLY_60HZ:
			_apply_60hz_now(owner, registry)
			_play_ui_confirm(registry)
		PauseMenuPointerCommandRouter.COMMAND_SAVE_DISPLAY:
			_save_display_options(owner, registry)
			_play_ui_confirm(registry)
		PauseMenuPointerCommandRouter.COMMAND_SELECT_CONTROL_DEVICE:
			controls_device_view = str(command.get("device", CONTROL_DEVICE_KEYBOARD_MOUSE))
			_play_ui_confirm(registry)
		PauseMenuPointerCommandRouter.COMMAND_SET_LANGUAGE:
			_set_language_option(str(command.get("language", LanguageSettings.DEFAULT_LANGUAGE)), owner)
			_play_ui_confirm(registry)
	return {"handled": true}


func _handle_mouse_button(mouse_event: InputEventMouseButton, owner: Object, registry: Object, view_size: Vector2) -> Dictionary:
	return _execute_input_command(
		_pointer_command_router.route_button(
			mouse_event,
			options_open,
			options_tab,
			controls_device_view,
			view_size,
			_get_main_entries().size()
		),
		owner,
		registry
	)


func _handle_mouse_motion(mouse_event: InputEventMouseMotion, registry: Object, view_size: Vector2) -> Dictionary:
	var result := _execute_input_command(
		_pointer_command_router.route_motion(options_open, dragging_slider, mouse_event.position.x, view_size),
		null,
		registry
	)
	_update_hover_feedback(mouse_event.position, registry, view_size)
	return result


func _handle_options_click(position: Vector2, owner: Object, registry: Object, view_size: Vector2) -> Dictionary:
	return _execute_input_command(
		_pointer_command_router.route_options_click(position, options_tab, controls_device_view, view_size),
		owner,
		registry
	)


func _handle_sound_click(position: Vector2, registry: Object, view_size: Vector2, panel_rect: Rect2) -> Dictionary:
	return _execute_input_command(
		_pointer_command_router.route_sound_click(position, view_size, panel_rect),
		null,
		registry
	)


func _handle_display_click(position: Vector2, owner: Object, registry: Object, panel_rect: Rect2) -> Dictionary:
	return _execute_input_command(
		_pointer_command_router.route_display_click(position, panel_rect),
		owner,
		registry
	)


func _handle_controls_click(position: Vector2, panel_rect: Rect2, registry: Object = null) -> Dictionary:
	return _execute_input_command(
		_pointer_command_router.route_controls_click(position, panel_rect, controls_device_view),
		null,
		registry
	)


func _handle_language_click(position: Vector2, owner: Object, panel_rect: Rect2, registry: Object = null) -> Dictionary:
	return _execute_input_command(
		_pointer_command_router.route_language_click(position, panel_rect),
		owner,
		registry
	)


func _move_selection(delta: int, registry: Object = null) -> bool:
	var count: int = maxi(1, _get_main_entries().size())
	var previous_index := selected_index
	selected_index = (selected_index + delta + count) % count
	if selected_index == previous_index:
		return false
	_begin_selection_feedback(SELECTION_SCOPE_MAIN, previous_index, selected_index)
	_play_ui_move(registry)
	return true


func _move_options_focus(delta: int, focus_count: int, registry: Object = null) -> bool:
	var previous_focus := options_focus
	if not _options_navigation_state.move_focus(delta, focus_count):
		return false
	_begin_selection_feedback(_get_options_feedback_scope(), previous_focus, options_focus)
	_play_ui_move(registry)
	return true


func _activate_selected(owner: Object, registry: Object) -> Dictionary:
	var entries: Array = _get_main_entries()
	var index: int = clamp(selected_index, 0, entries.size() - 1)
	selected_index = index
	_play_ui_confirm(registry)
	return _activate_entry(str(entries[index].get("action", "")), owner, registry)


func _activate_entry(action: String, _owner: Object, _registry: Object) -> Dictionary:
	match action:
		MENU_CONTINUE:
			close()
			return {"handled": true, "action": MENU_CONTINUE}
		MENU_CHARACTER_INFO:
			close()
			return {"handled": true, "action": MENU_CHARACTER_INFO}
		MENU_OPTIONS:
			_open_options(_owner, _registry)
			return {"handled": true}
		MENU_EXIT_TO_MAIN:
			# The actual scene change + run-selection rewind is owned by the
			# battle-side action consumer (match flow driver) -- the overlay
			# only reports the chosen action, same as character_info.
			close()
			return {"handled": true, "action": MENU_EXIT_TO_MAIN}
	return {"handled": true}


func _open_options(owner: Object, registry: Object) -> void:
	_session_state.open_options_page()
	_options_navigation_state.reset()
	_reset_selection_feedback(_get_options_feedback_scope(), options_focus)
	_reset_hover_tracking()
	_sync_display_settings(owner, registry)
	_sync_controls_settings()
	_sync_language_settings()


func _close_options_page() -> Dictionary:
	_session_state.close_options_page()
	_options_navigation_state.options_focus = 0
	_reset_selection_feedback(SELECTION_SCOPE_MAIN, selected_index)
	_reset_hover_tracking()
	if options_only:
		close()
	return {"handled": true}


func _switch_options_tab(direction: int = 1, owner: Object = null, registry: Object = null) -> void:
	_select_options_tab(PauseMenuOptionsNavigationPolicy.cycle_tab(options_tab, direction), owner, registry)


func _select_options_tab(tab: String, owner: Object = null, registry: Object = null) -> bool:
	var changed := _options_navigation_state.select_tab(tab)
	dragging_slider = ""
	_reset_selection_feedback(_get_options_feedback_scope(), options_focus)
	_reset_hover_tracking()
	if options_tab == OPTIONS_TAB_DISPLAY:
		_sync_display_settings(owner, registry)
	elif options_tab == OPTIONS_TAB_CONTROLS:
		_sync_controls_settings()
	elif options_tab == OPTIONS_TAB_LANGUAGE:
		_sync_language_settings()
	return changed


func _cycle_display_mode(direction: int) -> void:
	_display_settings_state.cycle_display_mode(direction)


func _set_display_mode_option(mode: String) -> void:
	_display_settings_state.select_display_mode(mode)


func _handle_display_focus_delta(direction: int, owner: Object, registry: Object) -> void:
	if options_focus == 0:
		_cycle_display_mode(direction)
	elif options_focus == 1:
		_cycle_render_fps_cap(direction, owner, registry)
	elif options_focus == 2:
		_cycle_vsync_mode(direction, owner, registry)


func _activate_display_focus(owner: Object, registry: Object) -> Dictionary:
	match options_focus:
		0:
			_cycle_display_mode(1)
		1:
			_cycle_render_fps_cap(1, owner, registry)
		2:
			_cycle_vsync_mode(1, owner, registry)
		3:
			_display_settings_state.toggle_remember_display_mode()
		4:
			_display_settings_state.toggle_auto_refresh_rate()
		5:
			_apply_recommended_display_settings(owner, registry)
		6:
			_apply_60hz_now(owner, registry)
		7:
			_save_display_options(owner, registry)
		8:
			return _close_options_page()
	return {"handled": true}


func _cycle_control_device_view(direction: int) -> bool:
	return _options_navigation_state.cycle_controls_device(direction)


func _adjust_controls_focus(direction: int) -> bool:
	if options_focus == 0:
		return _cycle_control_device_view(direction)
	elif _is_controls_vibration_focus():
		var previous_level := gamepad_vibration_level
		_adjust_gamepad_vibration_level(direction)
		return gamepad_vibration_level != previous_level
	return false


func _adjust_gamepad_vibration_level(direction: int) -> void:
	_controls_settings_controller.adjust(direction)


func _is_controls_vibration_focus() -> bool:
	return _options_navigation_state.is_controls_vibration_focus()


func _get_controls_focus_count() -> int:
	return _options_navigation_state.get_controls_focus_count()


func _get_controls_back_focus_index() -> int:
	return _options_navigation_state.get_controls_back_focus_index()


func _sync_controls_settings() -> void:
	_controls_settings_controller.sync()


func _sync_language_settings() -> void:
	_language_settings_controller.sync()


func _cycle_language(direction: int, owner: Object) -> void:
	_language_settings_controller.cycle(direction, owner)


func _set_language_option(language: String, owner: Object = null) -> void:
	_language_settings_controller.set_language(language, owner)


func _activate_language_focus(owner: Object) -> Dictionary:
	if options_focus == LANGUAGE_FOCUS_COUNT - 1:
		return _close_options_page()
	_language_settings_controller.select_focus(options_focus, owner)
	return {"handled": true}


func _reset_current_tab_to_defaults(owner: Object, registry: Object) -> void:
	match options_tab:
		OPTIONS_TAB_SOUND:
			_set_bgm_volume(registry, DEFAULT_BGM_VOLUME)
			_set_sfx_volume(registry, DEFAULT_SFX_VOLUME)
		OPTIONS_TAB_DISPLAY:
			_display_settings_state.reset_factory()
			_save_display_options(owner, registry)
		OPTIONS_TAB_CONTROLS:
			controls_device_view = CONTROL_DEVICE_KEYBOARD_MOUSE
			_controls_settings_controller.reset()
			_options_navigation_state.clamp_controls_focus()
		OPTIONS_TAB_LANGUAGE:
			_set_language_option(LanguageSettings.DEFAULT_LANGUAGE, owner)


func _notify_language_changed(owner: Object) -> void:
	_language_settings_controller.notify_language_changed(owner)


func _cycle_render_fps_cap(direction: int, owner: Object, registry: Object) -> void:
	_display_settings_controller.cycle_render_fps_cap(direction, owner, registry)


func _cycle_vsync_mode(direction: int, owner: Object, registry: Object) -> void:
	_display_settings_controller.cycle_vsync_mode(direction, owner, registry)


func _sync_display_settings(owner: Object, registry: Object) -> void:
	_display_settings_controller.sync(owner, registry)


func _save_display_options(owner: Object, registry: Object) -> void:
	_display_settings_controller.save(owner, registry)


func _apply_recommended_display_settings(owner: Object, registry: Object) -> void:
	_display_settings_controller.apply_recommended(owner, registry)


func _apply_60hz_now(owner: Object, registry: Object) -> void:
	_display_settings_controller.apply_60hz_now(owner, registry)


func _normalize_display_mode(mode: String) -> String:
	return PauseMenuDisplaySettingsState.normalize_display_mode(mode)


func _get_display_mode_description() -> String:
	return _display_settings_controller.get_display_mode_description()


func _get_render_fps_cap_options(registry: Object) -> Array[int]:
	return _display_settings_controller.get_render_fps_cap_options(registry)


func _get_render_fps_cap_label(registry: Object, owner: Object = null) -> String:
	return _display_settings_controller.get_render_fps_cap_label(registry, owner)


func _get_vsync_mode_options(registry: Object) -> Array[int]:
	return _display_settings_controller.get_vsync_mode_options(registry)


func _get_vsync_mode_label(registry: Object) -> String:
	return _display_settings_controller.get_vsync_mode_label(registry)


func _get_display_pacing_recommendation(registry: Object, owner: Object = null) -> String:
	return _display_settings_controller.get_display_pacing_recommendation(registry, owner)


func _get_monitor_refresh_rate(registry: Object, owner: Object = null) -> int:
	return _display_settings_controller.get_monitor_refresh_rate(registry, owner)


func _text(key: String, fallback: String = "") -> String:
	return PauseMenuContentCatalog.translate(key, fallback)


func _open_system_display_settings(registry: Object) -> void:
	_display_settings_controller.open_system_display_settings(registry)


func _get_owner_window(owner: Object) -> Object:
	return _display_settings_controller.get_owner_window(owner)


func _play_ui_move(registry: Object) -> void:
	_audio_controller.play_move(registry)


func _play_ui_confirm(registry: Object) -> void:
	_audio_controller.play_confirm(registry)


func _play_ui_back(registry: Object) -> void:
	_audio_controller.play_back(registry)


func _play_ui_feedback(registry: Object, method_name: String) -> void:
	_audio_controller.play_feedback(registry, method_name)


func _adjust_focused_volume(registry: Object, delta: float) -> void:
	_audio_controller.adjust_focused_volume(options_focus, registry, delta)


func _set_volume_from_slider(slider_key: String, mouse_x: float, registry: Object, view_size: Vector2) -> void:
	_audio_controller.set_volume_from_slider(slider_key, mouse_x, _get_slider_rect(slider_key, view_size), registry)


func _draw_main_menu(canvas: CanvasItem, font: Font, panel_rect: Rect2, mouse_pos: Vector2) -> void:
	var entries: Array = _get_main_entries()
	if entries.is_empty():
		return
	_main_renderer.draw_menu(
		canvas,
		font,
		font,
		panel_rect,
		mouse_pos,
		entries,
		selected_index,
		_get_animated_selection_rect(SELECTION_SCOPE_MAIN, panel_rect, selected_index),
		animation_time,
		_main_dial_time,
		_get_main_pop_projection()
	)


func _draw_main_editorial_background(canvas: CanvasItem, panel_rect: Rect2, base_alpha: float = 1.0, chrome_alpha: float = 1.0) -> void:
	_main_renderer.draw_editorial_background(canvas, panel_rect, _main_dial_time, base_alpha, chrome_alpha)


func _draw_main_editorial_base(canvas: CanvasItem, panel_rect: Rect2, alpha: float = 1.0) -> void:
	_main_renderer.draw_editorial_base(canvas, panel_rect, alpha)


func _get_main_background_cover_region(panel_rect: Rect2) -> Rect2:
	return _main_renderer.get_background_cover_region(_main_editorial_bg_texture, panel_rect)


func _draw_main_map_texture(canvas: CanvasItem, panel_rect: Rect2, alpha: float = 1.0) -> void:
	_main_renderer.draw_map_texture(canvas, panel_rect, alpha)


func _draw_main_editorial_header(canvas: CanvasItem, font: Font, panel_rect: Rect2, alpha: float = 1.0) -> void:
	_main_renderer.draw_editorial_header(canvas, font, panel_rect, alpha)


func _draw_main_editorial_spine(canvas: CanvasItem, panel_rect: Rect2, alpha: float = 1.0) -> void:
	_main_renderer.draw_editorial_spine(canvas, panel_rect, _get_main_entries().size(), alpha)


func _draw_main_editorial_dial(canvas: CanvasItem, panel_rect: Rect2, alpha: float = 1.0) -> void:
	_main_renderer.draw_editorial_dial(canvas, panel_rect, _main_dial_time, alpha)


func _get_main_yundo_center(panel_rect: Rect2) -> Vector2:
	return _main_renderer.get_yundo_center(panel_rect)


func _get_main_yundo_radius(panel_rect: Rect2) -> float:
	return _main_renderer.get_yundo_radius(panel_rect)


func _draw_main_selected_bar(
	canvas: CanvasItem,
	font: Font,
	_panel_rect: Rect2,
	selection_rect: Rect2,
	entry: Dictionary,
	open_ratio: float = 1.0,
	text_alpha: float = 1.0
) -> void:
	_main_renderer.draw_selected_bar(
		canvas,
		font,
		font,
		selection_rect,
		entry,
		open_ratio,
		text_alpha,
		_get_main_pop_projection()
	)


func _draw_main_unselected_entry(
	canvas: CanvasItem,
	font: Font,
	panel_rect: Rect2,
	entry: Dictionary,
	index: int,
	mouse_pos: Vector2,
	open_ratio: float = 1.0
) -> void:
	_main_renderer.draw_unselected_entry(
		canvas,
		font,
		panel_rect,
		entry,
		index,
		_get_main_entries().size(),
		mouse_pos,
		open_ratio
	)


func _draw_main_sparkle(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	_main_renderer.draw_knot_marker(canvas, center, radius, color)


func _get_main_pop_projection() -> Dictionary:
	return _selection_feedback_state.build_pop_projection(SELECTION_SCOPE_MAIN, 0.20)


func _build_options_render_snapshot(registry: Object, owner: Object = null) -> Dictionary:
	var current_language_name := _language_settings_controller.get_native_language_name()
	return {
		"options_tab": options_tab,
		"options_focus": options_focus,
		"focus_pulse_alpha": _focus_pulse_alpha(),
		"settings_title": _text("settings.title"),
		"sound_tab_label": _text("settings.tab.sound"),
		"display_tab_label": _text("settings.tab.display"),
		"controls_tab_label": _text("settings.tab.controls"),
		"language_tab_label": _text("settings.tab.language"),
		"reset_label": _text("settings.reset", "초기화"),
		"back_label": _get_options_back_label(),
		"bgm_label": _text("sound.bgm_volume"),
		"bgm_volume": _get_bgm_volume(registry),
		"sfx_label": _text("sound.sfx_volume"),
		"sfx_volume": _get_sfx_volume(registry),
		"display_mode_label": _text("display.mode"),
		"fullscreen_label": _text("display.mode.fullscreen"),
		"exclusive_fullscreen_label": _text("display.mode.exclusive"),
		"windowed_label": _text("display.mode.windowed"),
		"display_mode": display_mode,
		"fullscreen_mode": DISPLAY_MODE_FULLSCREEN,
		"exclusive_fullscreen_mode": DISPLAY_MODE_EXCLUSIVE_FULLSCREEN,
		"windowed_mode": DISPLAY_MODE_WINDOWED,
		"display_mode_description": _get_display_mode_description(),
		"render_fps_label": _text("display.render_fps"),
		"render_fps_value": _get_render_fps_cap_label(registry, owner),
		"vsync_label": "VSync",
		"vsync_value": _get_vsync_mode_label(registry),
		"remember_title": _text("display.remember.title"),
		"remember_subtitle": _text("display.remember.subtitle"),
		"remember_display_mode": remember_display_mode,
		"auto_refresh_title": _text("display.auto60.title"),
		"auto_refresh_subtitle": _text("display.auto60.subtitle"),
		"auto_refresh_rate_60hz": auto_refresh_rate_60hz,
		"pacing_recommendation": _get_display_pacing_recommendation(registry, owner),
		"recommended_label": _text("display.recommend.apply"),
		"apply_60hz_label": _text("display.apply60"),
		"save_label": _text("settings.save"),
		"controls_device_label": _text("controls.device"),
		"keyboard_mouse_label": _text("controls.keyboard_mouse"),
		"joypad_label": _text("controls.joypad"),
		"controls_device_view": controls_device_view,
		"keyboard_mouse_device": CONTROL_DEVICE_KEYBOARD_MOUSE,
		"vibration_label": _text("controls.vibration"),
		"vibration_value": _get_vibration_level_label(gamepad_vibration_level),
		"control_mapping_rows": _get_control_mapping_rows(),
		"controls_back_focus_index": _get_controls_back_focus_index(),
		"language_title": _text("language.title"),
		"language_options": [
			{"label": _text("language.ko"), "selected": language_code == LanguageSettings.LANGUAGE_KOREAN},
			{"label": _text("language.en"), "selected": language_code == LanguageSettings.LANGUAGE_ENGLISH},
			{"label": _text("language.zh"), "selected": language_code == LanguageSettings.LANGUAGE_CHINESE},
			{"label": _text("language.ja"), "selected": language_code == LanguageSettings.LANGUAGE_JAPANESE},
			{"label": _text("language.es"), "selected": language_code == LanguageSettings.LANGUAGE_SPANISH},
			{"label": _text("language.pt_br"), "selected": language_code == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL},
			{"label": _text("language.ru"), "selected": language_code == LanguageSettings.LANGUAGE_RUSSIAN},
		],
		"current_language_label": _text("language.current") % current_language_name,
		"language_subtitle": _text("language.subtitle"),
	}


func _draw_options_window(canvas: CanvasItem, font: Font, panel_rect: Rect2, mouse_pos: Vector2, registry: Object, owner: Object = null) -> void:
	var snapshot := _build_options_render_snapshot(registry, owner)
	_options_renderer.draw_window(canvas, font, panel_rect, mouse_pos, snapshot)
	_draw_selection_feedback(canvas, panel_rect, _get_options_feedback_scope(), options_focus)
	_draw_hud_readout_bar(canvas, font, panel_rect, _get_focused_option_description(options_tab, options_focus))


func _draw_options_header(canvas: CanvasItem, panel_rect: Rect2) -> void:
	_options_renderer.draw_options_header(canvas, panel_rect)


func _draw_tab(canvas: CanvasItem, font: Font, rect: Rect2, label: String, active_tab: bool, icon_kind: String = "") -> void:
	_options_renderer.draw_tab(canvas, font, rect, label, active_tab, icon_kind)


func _draw_tab_icon(canvas: CanvasItem, kind: String, icon_rect: Rect2, color: Color) -> void:
	_options_renderer.draw_tab_icon(canvas, kind, icon_rect, color)


func _draw_scanlines(canvas: CanvasItem, rect: Rect2) -> void:
	_options_renderer.draw_scanlines(canvas, rect)


func _draw_volume_slider(
	canvas: CanvasItem,
	font: Font,
	slider_key: String,
	label: String,
	value: float,
	accent: Color,
	focused: bool,
	mouse_pos: Vector2,
	panel_rect: Rect2
) -> void:
	_options_renderer.draw_volume_slider(
		canvas,
		font,
		slider_key,
		label,
		value,
		accent,
		focused,
		mouse_pos,
		panel_rect
	)


func _draw_display_tab(canvas: CanvasItem, font: Font, panel_rect: Rect2, mouse_pos: Vector2, registry: Object, owner: Object = null) -> void:
	_options_renderer.draw_display_tab(
		canvas,
		font,
		panel_rect,
		mouse_pos,
		_build_options_render_snapshot(registry, owner)
	)


func _draw_controls_tab(canvas: CanvasItem, font: Font, panel_rect: Rect2, mouse_pos: Vector2) -> void:
	_options_renderer.draw_controls_tab(
		canvas,
		font,
		panel_rect,
		mouse_pos,
		_build_options_render_snapshot(null)
	)


func _draw_language_tab(canvas: CanvasItem, font: Font, panel_rect: Rect2, mouse_pos: Vector2) -> void:
	_options_renderer.draw_language_tab(
		canvas,
		font,
		panel_rect,
		mouse_pos,
		_build_options_render_snapshot(null)
	)


func _get_vibration_level_label(level: int = 0) -> String:
	return _controls_settings_controller.get_vibration_level_label(level)


func _draw_control_mapping_row(canvas: CanvasItem, font: Font, rect: Rect2, label: String, value: String) -> void:
	_options_renderer.draw_control_mapping_row(canvas, font, rect, label, value)


func _draw_mode_pill(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	label: String,
	selected: bool,
	focused: bool,
	mouse_pos: Vector2
) -> void:
	_options_renderer.draw_mode_pill(canvas, font, rect, label, selected, focused, mouse_pos)


func _draw_setting_select_row(
	canvas: CanvasItem,
	font: Font,
	row_rect: Rect2,
	value_rect: Rect2,
	label: String,
	value: String,
	focused: bool,
	mouse_pos: Vector2
) -> void:
	_options_renderer.draw_setting_select_row(
		canvas,
		font,
		row_rect,
		value_rect,
		label,
		value,
		focused,
		mouse_pos,
		_focus_pulse_alpha()
	)


func _draw_toggle_setting_row(
	canvas: CanvasItem,
	font: Font,
	row_rect: Rect2,
	checkbox_rect: Rect2,
	title: String,
	subtitle: String,
	enabled: bool,
	focused: bool,
	mouse_pos: Vector2,
	muted: bool = false
) -> void:
	_options_renderer.draw_toggle_setting_row(
		canvas,
		font,
		row_rect,
		checkbox_rect,
		title,
		subtitle,
		enabled,
		focused,
		mouse_pos,
		muted,
		_focus_pulse_alpha()
	)


func _draw_button(canvas: CanvasItem, font: Font, rect: Rect2, text: String, selected: bool, mouse_pos: Vector2) -> void:
	_options_renderer.draw_button(canvas, font, rect, text, selected, mouse_pos)


func _draw_recommendation_block(canvas: CanvasItem, font: Font, rect: Rect2, text: String) -> void:
	_options_renderer.draw_recommendation_block(canvas, font, rect, text)


func _draw_hud_readout_bar(canvas: CanvasItem, font: Font, panel_rect: Rect2, text: String) -> void:
	_options_renderer.draw_hud_readout_bar(canvas, font, panel_rect, text)


func _get_select_chevron_rects(value_rect: Rect2) -> Dictionary:
	return PauseMenuOptionsRenderer.get_select_chevron_rects(value_rect)


func _draw_toggle_leader(canvas: CanvasItem, font: Font, row_rect: Rect2, checkbox_rect: Rect2, title: String) -> void:
	_options_renderer.draw_toggle_leader(canvas, font, row_rect, checkbox_rect, title)


func _draw_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, border_width: float, double_line: bool = false, glow: bool = false, frame_kind: int = PremiumPanelFrame.KIND_SLOT) -> void:
	_options_renderer.draw_panel(canvas, rect, fill, border, border_width, double_line, glow, frame_kind)


func _draw_neon_line(canvas: CanvasItem, start: Vector2, finish: Vector2, color: Color, core_width: float = 1.0) -> void:
	_options_renderer.draw_neon_line(canvas, start, finish, color, core_width)


func _draw_holo_focus_frame(canvas: CanvasItem, rect: Rect2, pulse_alpha: float = 1.0) -> void:
	_options_renderer.draw_holo_focus_frame(canvas, rect, pulse_alpha)


func _get_ui_font(tech: bool = false) -> Font:
	return FONT_TECH if tech else FONT_BODY


func _get_text_draw_font(font: Font, text: String) -> Font:
	if font != null and not _needs_cjk_fallback_font(text):
		return font
	return ThemeDB.fallback_font if ThemeDB.fallback_font != null else font


func _needs_cjk_fallback_font(text: String) -> bool:
	for index in range(text.length()):
		var codepoint := text.unicode_at(index)
		if (
			(codepoint >= 0x3000 and codepoint <= 0x30FF)
			or (codepoint >= 0x3400 and codepoint <= 0x9FFF)
			or (codepoint >= 0xF900 and codepoint <= 0xFAFF)
			or (codepoint >= 0xFF66 and codepoint <= 0xFF9F)
		):
			return true
	return false


func _focus_pulse_alpha() -> float:
	return 0.55 + 0.45 * sin(animation_time * TAU / 2.85)


func _with_alpha(color: Color, alpha_scale: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * clampf(alpha_scale, 0.0, 1.0))


func _get_open_ratio(duration: float, delay: float = 0.0) -> float:
	return clampf((animation_time - delay) / maxf(duration, 0.001), 0.0, 1.0)


func _get_open_bg_alpha() -> float:
	return PauseMenuMainRenderer.get_open_bg_alpha(animation_time)


func _get_open_chrome_alpha() -> float:
	return PauseMenuMainRenderer.get_open_chrome_alpha(animation_time)


func _get_open_text_alpha() -> float:
	return PauseMenuMainRenderer.get_open_text_alpha(animation_time)


func _get_main_open_bar_ratio() -> float:
	return PauseMenuMainRenderer.get_main_open_bar_ratio(animation_time)


func _get_main_open_entry_ratio(index: int) -> float:
	return PauseMenuMainRenderer.get_main_open_entry_ratio(animation_time, index)


func _get_options_open_ratio() -> float:
	return _ease_out_cubic(_get_open_ratio(OPEN_OPTIONS_SECONDS))


func _begin_selection_feedback(scope: String, from_index: int, to_index: int) -> void:
	_selection_feedback_state.begin(scope, from_index, to_index)


func _reset_selection_feedback(scope: String, index: int) -> void:
	_selection_feedback_state.reset(scope, index)


func _reset_hover_tracking() -> void:
	_selection_feedback_state.reset_hover_tracking()


func _update_hover_feedback(position: Vector2, registry: Object, view_size: Vector2) -> void:
	var scope := _get_options_feedback_scope() if options_open else SELECTION_SCOPE_MAIN
	var panel_rect := _get_options_panel_rect(view_size) if options_open else _get_active_panel_rect(view_size)
	var hovered_index := _hovered_index_at(panel_rect, scope, position)
	if not _selection_feedback_state.consume_hover_change(scope, hovered_index):
		return
	if hovered_index < 0:
		return
	var current_index := options_focus if options_open else selected_index
	if hovered_index == current_index:
		return
	if options_open:
		options_focus = hovered_index
	else:
		selected_index = hovered_index
	_begin_selection_feedback(scope, current_index, hovered_index)
	_play_ui_move(registry)


func _hovered_index_at(panel_rect: Rect2, scope: String, position: Vector2) -> int:
	var focus_count := _get_selection_feedback_count(scope)
	for index in range(focus_count):
		if _get_selection_feedback_rect(panel_rect, scope, index).has_point(position):
			return index
	return -1


func _get_selection_feedback_count(scope: String) -> int:
	return PauseMenuOptionsNavigationPolicy.get_feedback_count(scope, _get_main_entries().size())


func _get_options_feedback_scope() -> String:
	return _options_navigation_state.get_feedback_scope()


func _draw_selection_feedback(canvas: CanvasItem, panel_rect: Rect2, scope: String, current_index: int) -> void:
	_selection_feedback_renderer.draw(
		canvas,
		panel_rect,
		scope,
		current_index,
		_selection_feedback_state,
		_get_main_entries().size(),
		_focus_pulse_alpha()
	)


func _get_selection_feedback_rect(panel_rect: Rect2, scope: String, index: int) -> Rect2:
	return PauseMenuSelectionFeedbackRenderer.get_feedback_rect(
		panel_rect,
		scope,
		index,
		_get_main_entries().size()
	)


func _get_sound_focus_rect(panel_rect: Rect2, index: int) -> Rect2:
	return PauseMenuSelectionFeedbackRenderer.get_sound_focus_rect(panel_rect, index)


func _get_display_focus_rect(panel_rect: Rect2, index: int) -> Rect2:
	return PauseMenuSelectionFeedbackRenderer.get_display_focus_rect(panel_rect, index)


func _get_controls_focus_rect(panel_rect: Rect2, index: int, device: String) -> Rect2:
	return PauseMenuSelectionFeedbackRenderer.get_controls_focus_rect(panel_rect, index, device)


func _get_language_focus_rect(panel_rect: Rect2, index: int) -> Rect2:
	return PauseMenuSelectionFeedbackRenderer.get_language_focus_rect(panel_rect, index)


func _span_rect(first_rect: Rect2, last_rect: Rect2) -> Rect2:
	return PauseMenuSelectionFeedbackRenderer.span_rect(first_rect, last_rect)


func _lerp_rect(from_rect: Rect2, to_rect: Rect2, weight: float) -> Rect2:
	return PauseMenuSelectionFeedbackRenderer.lerp_rect(from_rect, to_rect, weight)


func _scale_rect_from_center(rect: Rect2, scale: float) -> Rect2:
	return PauseMenuSelectionFeedbackRenderer.scale_rect_from_center(rect, scale)


func _ease_out_cubic(value: float) -> float:
	var clamped_value := clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped_value, 3.0)


func _has_feedback_rect(rect: Rect2) -> bool:
	return PauseMenuSelectionFeedbackRenderer.has_feedback_rect(rect)


func _get_focused_option_description(tab: String, focus: int) -> String:
	return PauseMenuContentCatalog.get_focused_option_description(tab, focus, controls_device_view)


func _draw_text(canvas: CanvasItem, font: Font, text: String, pos: Vector2, size: int, color: Color) -> void:
	var draw_font := _get_text_draw_font(font, text)
	canvas.draw_string(draw_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _draw_text_centered(canvas: CanvasItem, font: Font, text: String, center: Vector2, size: int, color: Color) -> void:
	var draw_font := _get_text_draw_font(font, text)
	var text_size: Vector2 = draw_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
	canvas.draw_string(draw_font, center - Vector2(text_size.x * 0.5, text_size.y * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _draw_text_in_rect(canvas: CanvasItem, font: Font, text: String, rect: Rect2, size: int, color: Color) -> void:
	var draw_font := _get_text_draw_font(font, text)
	var text_size: Vector2 = draw_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
	var ascent: float = draw_font.get_ascent(size)
	var pos := Vector2(
		rect.position.x + (rect.size.x - text_size.x) * 0.5,
		rect.position.y + (rect.size.y - text_size.y) * 0.5 + ascent
	)
	canvas.draw_string(draw_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _get_active_panel_rect(view_size: Vector2) -> Rect2:
	return _get_options_panel_rect(view_size) if options_open else _get_main_panel_rect(view_size)


func _get_main_panel_rect(view_size: Vector2) -> Rect2:
	return PauseMenuOverlayLayout.get_main_panel_rect(view_size)


func _get_animated_selection_rect(scope: String, panel_rect: Rect2, current_index: int) -> Rect2:
	return _selection_feedback_renderer.get_animated_rect(
		scope,
		panel_rect,
		current_index,
		_selection_feedback_state,
		_get_main_entries().size()
	)


func _get_main_row_pitch(panel_rect: Rect2) -> float:
	return PauseMenuOverlayLayout.get_main_row_pitch(panel_rect)


func _get_main_row_height(panel_rect: Rect2) -> float:
	return PauseMenuOverlayLayout.get_main_row_height(panel_rect)


func _get_main_row_start_y(panel_rect: Rect2) -> float:
	return PauseMenuOverlayLayout.get_main_row_start_y(panel_rect, _get_main_entries().size())


func _get_main_bar_width(panel_rect: Rect2) -> float:
	return PauseMenuOverlayLayout.get_main_bar_width(panel_rect)


func _get_main_row_band_rect(panel_rect: Rect2, index: int) -> Rect2:
	return PauseMenuOverlayLayout.get_main_row_band_rect(
		panel_rect,
		index,
		_get_main_entries().size()
	)


func _get_main_selection_bar_rect(selection_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_main_selection_bar_rect(selection_rect)


func _get_main_left_margin(panel_rect: Rect2) -> float:
	return PauseMenuOverlayLayout.get_main_left_margin(panel_rect)


func _get_main_title_left_margin(panel_rect: Rect2) -> float:
	return PauseMenuOverlayLayout.get_main_title_left_margin(panel_rect)


func _get_main_list_anchor_x(panel_rect: Rect2) -> float:
	return PauseMenuOverlayLayout.get_main_list_anchor_x(panel_rect)


func _get_main_diamond_center_x(panel_rect: Rect2) -> float:
	return PauseMenuOverlayLayout.get_main_diamond_center_x(panel_rect)


func _get_main_unselected_text_x(panel_rect: Rect2) -> float:
	return PauseMenuOverlayLayout.get_main_unselected_text_x(panel_rect)


func _get_main_selected_en_x(bar_rect: Rect2, text_width: float, local_left_x: float = -1.0) -> float:
	return PauseMenuOverlayLayout.get_main_selected_en_x(bar_rect, text_width, local_left_x)


func _get_main_scroll_cap_half_width(bar_rect: Rect2) -> float:
	return PauseMenuOverlayLayout.get_main_scroll_cap_half_width(bar_rect)


func _get_main_selected_local_x(bar_rect: Rect2, text_width: float) -> float:
	return PauseMenuOverlayLayout.get_main_selected_local_x(bar_rect, text_width)


func _get_main_title_font_size(panel_rect: Rect2) -> int:
	return _main_renderer.get_title_font_size(FONT_BODY, _get_main_title_text(), panel_rect)


func _get_main_title_max_width(panel_rect: Rect2) -> float:
	return _main_renderer.get_title_max_width(panel_rect)


func _get_main_subtitle_font_size(panel_rect: Rect2) -> int:
	return PauseMenuOverlayLayout.get_main_subtitle_font_size(panel_rect)


func _get_main_entry_selected_font_size(rect: Rect2) -> int:
	return PauseMenuOverlayLayout.get_main_entry_selected_font_size(rect)


func _get_main_entry_local_font_size(rect: Rect2) -> int:
	return PauseMenuOverlayLayout.get_main_entry_local_font_size(rect)


func _get_main_entry_idle_font_size(panel_rect: Rect2) -> int:
	return PauseMenuOverlayLayout.get_main_entry_idle_font_size(panel_rect)


func _should_show_main_local_label() -> bool:
	return _main_renderer.should_show_local_label()


func _get_main_brush_font() -> Font:
	return _main_renderer.get_main_brush_font(FONT_BODY)


func _get_main_primary_label_text(entry: Dictionary) -> String:
	return _main_renderer.get_primary_label_text(entry)


func _get_main_text_draw_font(text: String) -> Font:
	return _main_renderer.get_main_text_draw_font(FONT_BODY, text)


func _get_main_selected_primary_font_size(text: String, bar_rect: Rect2) -> int:
	return _main_renderer.get_selected_primary_font_size(FONT_BODY, text, bar_rect)


func _get_main_selected_helper_font_size(text: String, bar_rect: Rect2) -> int:
	var draw_font := _get_text_draw_font(FONT_BODY, text)
	return _main_renderer.get_selected_helper_font_size(draw_font, text, bar_rect)


func _get_main_unselected_primary_font_size(text: String, panel_rect: Rect2) -> int:
	return _main_renderer.get_unselected_primary_font_size(FONT_BODY, text, panel_rect)


func _get_main_title_text() -> String:
	return _main_renderer.get_title_text()


func _get_main_selected_local_text(entry: Dictionary) -> String:
	return _main_renderer.get_selected_local_text(entry)


func _get_options_panel_rect(view_size: Vector2) -> Rect2:
	return PauseMenuOverlayLayout.get_options_panel_rect(view_size)


func _get_sound_tab_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_sound_tab_rect(panel_rect)


func _get_display_tab_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_display_tab_rect(panel_rect)


func _get_controls_tab_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_controls_tab_rect(panel_rect)


func _get_language_tab_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_language_tab_rect(panel_rect)


func _get_reset_button_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_reset_button_rect(panel_rect)


func _get_button_rect(panel_rect: Rect2, index: int, count: int) -> Rect2:
	return PauseMenuOverlayLayout.get_button_rect(
		panel_rect,
		index,
		count,
		_get_main_entries().size()
	)


func _get_slider_rect(slider_key: String, view_size: Vector2) -> Rect2:
	return PauseMenuOverlayLayout.get_slider_rect(slider_key, view_size)


func _get_slider_rect_from_panel(slider_key: String, panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_slider_rect_from_panel(slider_key, panel_rect)


func _get_slider_hit_rect(slider_key: String, view_size: Vector2) -> Rect2:
	return PauseMenuOverlayLayout.get_slider_hit_rect(slider_key, view_size)


func _get_slider_hit_rect_from_panel(slider_key: String, panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_slider_hit_rect_from_panel(slider_key, panel_rect)


func _get_back_button_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_back_button_rect(panel_rect)


func _get_display_fullscreen_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_display_fullscreen_rect(panel_rect)


func _get_display_exclusive_fullscreen_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_display_exclusive_fullscreen_rect(panel_rect)


func _get_display_windowed_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_display_windowed_rect(panel_rect)


func _get_display_fps_cap_row_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_display_fps_cap_row_rect(panel_rect)


func _get_display_fps_cap_value_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_display_fps_cap_value_rect(panel_rect)


func _get_display_vsync_row_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_display_vsync_row_rect(panel_rect)


func _get_display_vsync_value_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_display_vsync_value_rect(panel_rect)


func _get_display_default_checkbox_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_display_default_checkbox_rect(panel_rect)


func _get_display_default_row_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_display_default_row_rect(panel_rect)


func _get_display_auto_refresh_checkbox_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_display_auto_refresh_checkbox_rect(panel_rect)


func _get_display_auto_refresh_row_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_display_auto_refresh_row_rect(panel_rect)


func _get_display_pacing_recommendation_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_display_pacing_recommendation_rect(panel_rect)


func _get_display_recommended_button_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_display_recommended_button_rect(panel_rect)


func _get_display_apply_60hz_button_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_display_apply_60hz_button_rect(panel_rect)


func _get_display_save_button_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_display_save_button_rect(panel_rect)


func _get_display_back_button_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_display_back_button_rect(panel_rect)


func _get_controls_keyboard_mouse_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_controls_keyboard_mouse_rect(panel_rect)


func _get_controls_joypad_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_controls_joypad_rect(panel_rect)


func _get_controls_vibration_row_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_controls_vibration_row_rect(panel_rect)


func _get_controls_vibration_value_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_controls_vibration_value_rect(panel_rect)


func _get_controls_mapping_row_rect(panel_rect: Rect2, index: int) -> Rect2:
	return PauseMenuOverlayLayout.get_controls_mapping_row_rect(
		panel_rect,
		index,
		controls_device_view
	)


func _get_controls_back_button_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_controls_back_button_rect(panel_rect)


func _get_language_korean_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_language_korean_rect(panel_rect)


func _get_language_english_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_language_english_rect(panel_rect)


func _get_language_chinese_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_language_chinese_rect(panel_rect)


func _get_language_japanese_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_language_japanese_rect(panel_rect)


func _get_language_spanish_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_language_spanish_rect(panel_rect)


func _get_language_portuguese_brazil_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_language_portuguese_brazil_rect(panel_rect)


func _get_language_russian_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_language_russian_rect(panel_rect)


func _get_language_note_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_language_note_rect(panel_rect)


func _get_language_back_button_rect(panel_rect: Rect2) -> Rect2:
	return PauseMenuOverlayLayout.get_language_back_button_rect(panel_rect)


func _get_options_back_label() -> String:
	return PauseMenuContentCatalog.get_options_back_label(options_only)


func _get_control_mapping_rows() -> Array:
	return _controls_settings_controller.get_control_mapping_rows(controls_device_view)


func _get_main_entries() -> Array:
	return PauseMenuContentCatalog.get_main_entries()


func _get_bgm_volume(registry: Object) -> float:
	return _audio_controller.get_bgm_volume(registry)


func _set_bgm_volume(registry: Object, value: float) -> float:
	return _audio_controller.set_bgm_volume(registry, value)


func _get_sfx_volume(registry: Object) -> float:
	return _audio_controller.get_sfx_volume(registry)


func _set_sfx_volume(registry: Object, value: float) -> float:
	return _audio_controller.set_sfx_volume(registry, value)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.get_instance(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _is_key(key_event: InputEventKey, keycode: int) -> bool:
	return key_event.keycode == keycode or key_event.physical_keycode == keycode


func _get_mouse_position(canvas: CanvasItem) -> Vector2:
	if canvas != null and canvas.has_method("get_viewport") and canvas.get_viewport() != null:
		return canvas.get_viewport().get_mouse_position()
	return Vector2(-10000.0, -10000.0)
