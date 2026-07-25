extends SceneTree

const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const BattleSceneOverlayInputController := preload("res://scripts/core/battle_scene_overlay_input_controller.gd")
const GamepadVibrationSettings := preload("res://scripts/core/gamepad_vibration_settings.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const PauseMenuOverlay := preload("res://scripts/hud/pause_menu_overlay.gd")


class FakeOwner:
	var redraw_count := 0
	var language_refresh_count := 0

	func queue_redraw() -> void:
		redraw_count += 1

	func refresh_language_texts() -> void:
		language_refresh_count += 1

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))


class FakeCharacterInfo:
	var active := false

	func open() -> void:
		active = true

	func close() -> void:
		active = false

	func is_active() -> bool:
		return active

	func handle_input(_event: InputEvent, _owner: Object, _registry: Object, _view_size: Vector2) -> bool:
		return true


class FakeAudio:
	var bgm_volume := 0.4
	var sfx_volume := 0.7
	var ui_move_count := 0
	var ui_confirm_count := 0
	var ui_back_count := 0

	func get_bgm_volume() -> float:
		return bgm_volume

	func set_bgm_volume(value: float) -> float:
		bgm_volume = clampf(value, 0.0, 1.0)
		return bgm_volume

	func get_sfx_volume() -> float:
		return sfx_volume

	func set_sfx_volume(value: float) -> float:
		sfx_volume = clampf(value, 0.0, 1.0)
		return sfx_volume

	func play_ui_move() -> void:
		ui_move_count += 1

	func play_ui_confirm() -> void:
		ui_confirm_count += 1

	func play_ui_back() -> void:
		ui_back_count += 1


class FakeViewLayout:
	var toggle_count := 0
	var display_mode := "windowed"
	var remember_default := false
	var saved_mode := ""
	var saved_remember := false
	var save_display_count := 0
	var apply_count := 0
	var render_fps_cap := 72
	var saved_render_fps_cap := 72
	var apply_render_fps_count := 0
	var vsync_mode := 1
	var saved_vsync_mode := 1
	var apply_vsync_count := 0
	var system_settings_count := 0
	var auto_refresh_rate_60hz := false
	var saved_auto_refresh_rate_60hz := false
	var save_auto_refresh_count := 0

	func toggle_fullscreen(_window: Object) -> void:
		toggle_count += 1
		display_mode = "windowed" if display_mode == "fullscreen" else "fullscreen"

	func get_display_mode(_window: Object) -> String:
		return display_mode

	func get_saved_display_mode() -> String:
		if saved_mode.is_empty():
			return display_mode
		return saved_mode

	func apply_display_mode(_window: Object, mode: String) -> String:
		if mode == "exclusive_fullscreen":
			display_mode = "exclusive_fullscreen"
		elif mode == "fullscreen":
			display_mode = "fullscreen"
		else:
			display_mode = "windowed"
		apply_count += 1
		return display_mode

	func get_remember_display_mode() -> bool:
		return remember_default

	func save_display_mode_default(mode: String, remember: bool) -> bool:
		save_display_count += 1
		saved_mode = mode
		saved_remember = remember
		remember_default = remember
		return true

	func get_render_fps_cap(_window: Object) -> int:
		return render_fps_cap

	func get_saved_render_fps_cap() -> int:
		return saved_render_fps_cap

	func get_render_fps_cap_options() -> Array[int]:
		return [0, 72, -2, -1]

	func apply_render_fps_cap(_window: Object, cap: int, _vsync_mode: int = -1) -> int:
		render_fps_cap = cap
		apply_render_fps_count += 1
		return render_fps_cap

	func save_render_fps_cap_default(cap: int) -> bool:
		saved_render_fps_cap = cap
		return true

	func get_render_fps_cap_label(cap: int, _window: Object = null) -> String:
		if cap == 0:
			return "unlimited"
		if cap == -2:
			return "stable"
		if cap == -1:
			return "monitor"
		return "%d FPS" % cap

	func get_vsync_mode() -> int:
		return vsync_mode

	func get_saved_vsync_mode() -> int:
		return saved_vsync_mode

	func get_vsync_mode_options() -> Array[int]:
		return [1, 3, 0]

	func apply_vsync_mode(mode: int, _window: Object = null) -> int:
		vsync_mode = mode
		apply_vsync_count += 1
		return vsync_mode

	func save_vsync_mode_default(mode: int) -> bool:
		saved_vsync_mode = mode
		return true

	func get_vsync_mode_label(mode: int) -> String:
		if mode == 0:
			return "VSync Off"
		if mode == 3:
			return "Mailbox"
		return "VSync On"

	func get_display_pacing_recommendation(_window: Object, _mode: String, _cap: int, _vsync: int) -> String:
		return "144Hz 모니터 감지: 안정 모니터 페이싱을 사용합니다.\n모니터를 바꾸면 다음 적용 시 안정 상한을 다시 계산합니다."

	func open_system_display_settings() -> int:
		system_settings_count += 1
		return OK

	func get_auto_refresh_rate_enabled() -> bool:
		return saved_auto_refresh_rate_60hz

	func save_auto_refresh_rate_default(enabled: bool, _window: Object = null) -> bool:
		auto_refresh_rate_60hz = enabled
		saved_auto_refresh_rate_60hz = enabled
		save_auto_refresh_count += 1
		return true


class FakeMatchFlowDriver:
	var exit_to_main_menu_calls := 0
	var saw_owner := false

	func exit_to_main_menu(owner: Object) -> void:
		exit_to_main_menu_calls += 1
		saw_owner = owner != null


class FakeRegistry:
	var modal_gate := BattleSceneModalGateController.new()
	var pause_menu := PauseMenuOverlay.new()
	var character_info := FakeCharacterInfo.new()
	var audio := FakeAudio.new()
	var view_layout := FakeViewLayout.new()
	var match_flow_driver := FakeMatchFlowDriver.new()

	func get_instance(key: String) -> Object:
		match key:
			"battle_scene_modal_gate_controller":
				return modal_gate
			"pause_menu_overlay":
				return pause_menu
			"character_info_overlay":
				return character_info
			"game_audio":
				return audio
			"battle_view_layout":
				return view_layout
			"battle_scene_match_flow_driver":
				return match_flow_driver
		return null


var registry := FakeRegistry.new()
var _vibration_settings_snapshot: Dictionary = {}
var _language_settings_snapshot: Dictionary = {}
var _failed := false


func _init() -> void:
	_vibration_settings_snapshot = _snapshot_settings_file(GamepadVibrationSettings.SETTINGS_PATH)
	_language_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	GamepadVibrationSettings.set_vibration_level(GamepadVibrationSettings.VIBRATION_LEVEL_DEFAULT)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	var input := BattleSceneOverlayInputController.new()
	var owner := FakeOwner.new()

	_expect(_press(input, owner, KEY_ESCAPE), "ESC should open the pause menu")
	_expect(registry.pause_menu.is_active(), "pause menu should become active")
	_expect(registry.modal_gate.should_block_battle_physics(Callable(self, "_get_module")), "pause menu should block battle physics")
	var main_panel_rect: Rect2 = registry.pause_menu._get_main_panel_rect(owner.get_viewport_rect().size)
	_expect(main_panel_rect.position == Vector2.ZERO and main_panel_rect.size == owner.get_viewport_rect().size, "bright pause menu should use the full view as the main surface")
	_expect(registry.pause_menu.PAPER_BG.r < 0.2 and registry.pause_menu.INK.r > 0.7, "cyberpunk pause menu should use dark navy bg and light text tokens")
	_expect(registry.pause_menu.TITLE_ON_GRAPHIC_INK.r > registry.pause_menu.GRAPHIC_INK.r + 0.70, "bright pause SYSTEM title should stay readable on the black editorial wedge")
	_expect(FileAccess.file_exists(registry.pause_menu.MAIN_EDITORIAL_BG_PATH), "D2 pause menu should ship the editorial map background PNG")
	_expect(FileAccess.file_exists(registry.pause_menu.MAIN_EDITORIAL_BG_PATH + ".import"), "D2 pause menu should ship the export-safe editorial map background import file")
	_expect(registry.pause_menu._main_editorial_bg_texture != null, "D2 pause menu should prewarm the editorial background texture when opened")
	var entries: Array = registry.pause_menu._get_main_entries()
	_expect(str(entries[0].get("en", "")) == "RESUME" and str(entries[1].get("en", "")) == "STATUS" and str(entries[2].get("en", "")) == "SETTINGS", "bright pause menu should expose editorial English menu labels")
	_expect(entries.size() == 4 and str(entries[3].get("en", "")) == "EXIT" and str(entries[3].get("action", "")) == "exit_to_main", "pause menu should expose the EXIT entry as the fourth item")
	_verify_pause_description_localization_keys()
	_expect(str(entries[0].get("desc", "")) == "게임으로 돌아가기" and str(entries[1].get("desc", "")) == "캐릭터 정보 확인" and str(entries[2].get("desc", "")) == "게임 설정 변경", "D3 pause menu should use Korean descriptive local labels")
	_expect(str(entries[3].get("label", "")) == "나가기" and str(entries[3].get("desc", "")) == "메인 메뉴로 돌아가기", "EXIT entry should use the Korean label and main-menu description")
	_expect(registry.pause_menu._should_show_main_local_label(), "Korean pause menu should keep the small local label")
	var main_selection_rect: Rect2 = registry.pause_menu._get_selection_feedback_rect(main_panel_rect, "main", 0)
	_expect(main_selection_rect.position.x == 0.0 and main_selection_rect.size.x >= owner.get_viewport_rect().size.x * 0.55, "main selection hit zone should be the left-edge editorial band")
	_expect(registry.pause_menu._get_button_rect(main_panel_rect, 0, entries.size()) == main_selection_rect, "main button hit zone should match the selection feedback band")
	var selected_bar_rect: Rect2 = registry.pause_menu._get_main_selection_bar_rect(main_selection_rect)
	var selected_en_font: Font = registry.pause_menu._get_ui_font(true)
	var selected_en_size: int = registry.pause_menu._get_main_entry_selected_font_size(selected_bar_rect)
	var selected_en_width: float = selected_en_font.get_string_size(str(entries[0].get("en", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, selected_en_size).x
	var selected_local_text := registry.pause_menu._get_main_selected_local_text(entries[0])
	var selected_local_font: Font = registry.pause_menu._get_text_draw_font(selected_en_font, selected_local_text)
	var selected_local_size: int = registry.pause_menu._get_main_entry_local_font_size(selected_bar_rect)
	var selected_local_width: float = selected_local_font.get_string_size(selected_local_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, selected_local_size).x
	var selected_local_x: float = registry.pause_menu._get_main_selected_local_x(selected_bar_rect, selected_local_width)
	var selected_en_x: float = registry.pause_menu._get_main_selected_en_x(selected_bar_rect, selected_en_width, selected_local_x)
	_expect(is_equal_approx(selected_en_x, selected_bar_rect.position.x + registry.pause_menu.MAIN_BAR_EN_LEFT_PAD), "D3 pause menu should anchor selected EN text from the bar left padding")
	_expect(selected_en_x < selected_bar_rect.get_center().x, "D3 pause menu selected EN text should sit left of the bar center")
	_expect(selected_local_text == "게임으로 돌아가기" and selected_local_x > selected_en_x + selected_en_width + 20.0, "D3 pause menu Korean description should draw as the selected bar helper label without overlapping EN")
	registry.pause_menu.animation_time = 0.0
	_expect(is_zero_approx(registry.pause_menu._get_open_bg_alpha()) and is_zero_approx(registry.pause_menu._get_main_open_bar_ratio()), "pause menu opening should start with hidden background and swept-out selection bar")
	_expect(is_zero_approx(registry.pause_menu._get_open_text_alpha()), "pause menu opening should delay selected text until the bar has started sweeping in")
	registry.pause_menu.animation_time = registry.pause_menu.OPEN_TEXT_FADE_DELAY_SECONDS + registry.pause_menu.OPEN_ITEM_STAGGER_SECONDS * 2.0
	_expect(registry.pause_menu._get_main_open_entry_ratio(0) > registry.pause_menu._get_main_open_entry_ratio(1) and registry.pause_menu._get_main_open_entry_ratio(1) > registry.pause_menu._get_main_open_entry_ratio(2), "pause menu opening should cascade unselected entries with a stagger")
	registry.pause_menu.animation_time = 0.30
	_expect(is_equal_approx(registry.pause_menu._get_open_bg_alpha(), 1.0) and is_equal_approx(registry.pause_menu._get_main_open_bar_ratio(), 1.0) and is_equal_approx(registry.pause_menu._get_options_open_ratio(), 1.0), "pause menu opening should settle all intro ratios quickly")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_ENGLISH)
	var english_entries: Array = registry.pause_menu._get_main_entries()
	_expect(str(english_entries[0].get("desc", "")) == "Return to game", "D3 pause menu should keep English desc keys populated for missing-key coverage")
	_expect(not registry.pause_menu._should_show_main_local_label() and registry.pause_menu._get_main_selected_local_text(english_entries[0]).is_empty(), "D3 pause menu should keep helper descriptions hidden in English")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_CHINESE)
	var chinese_entries: Array = registry.pause_menu._get_main_entries()
	_expect(str(chinese_entries[0].get("desc", "")) == "返回游戏" and registry.pause_menu._get_main_selected_local_text(chinese_entries[0]) == "返回游戏", "D3 pause menu should show the desc key for non-English locales")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_expect(registry.pause_menu._get_main_title_left_margin(main_panel_rect) <= 16.0, "bright pause title should sit near the top-left reference edge")
	_expect(registry.pause_menu._get_main_diamond_center_x(main_panel_rect) >= owner.get_viewport_rect().size.x * 0.18, "bright pause menu list spine should live inside the editorial list, not on the old left card margin")
	registry.pause_menu.update(0.20)
	_expect(registry.pause_menu._main_dial_time > 0.0, "bright pause menu dial timer should advance while paused")
	var compact_panel_rect: Rect2 = registry.pause_menu._get_main_panel_rect(Vector2(360.0, 640.0))
	_expect(compact_panel_rect.position == Vector2.ZERO and compact_panel_rect.size == Vector2(360.0, 640.0), "narrow pause menu should stay on the full-view editorial surface")
	var pause_source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_overlay.gd")
	var main_renderer_source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_main_renderer.gd")
	_expect(pause_source.find("const PauseMenuMainRenderer") >= 0 and pause_source.find("_main_renderer.draw_menu(") >= 0, "pause overlay should delegate the editorial main surface to its renderer owner")
	_expect(main_renderer_source.find("draw_set_transform") < 0, "bright pause menu dial should avoid texture-quad transform rotation")
	_expect(pause_source.find("_draw_ringcore_crystal") < 0, "bright pause main should not draw the preserved ringcore crystal asset")
	_expect(main_renderer_source.find("MAIN_SELECTED_BAR_SKEW") >= 0 and main_renderer_source.find("draw_colored_polygon(bar_points") >= 0, "bright pause main should use a skewed editorial selection bar instead of the old rounded button")
	_expect(main_renderer_source.find("OPEN_BAR_SWEEP_SECONDS") >= 0 and main_renderer_source.find("OPEN_ITEM_STAGGER_SECONDS") >= 0, "pause menu should keep explicit opening animation timing constants")
	_expect(main_renderer_source.find("ProjectResourceLoader.load_texture(\n\t\tMAIN_EDITORIAL_BG_PATH") >= 0, "D2 pause renderer should load the editorial background through the project resource loader")
	var background_body := _source_function_body(main_renderer_source, "func draw_editorial_background")
	_expect(background_body.find("draw_editorial_base(canvas, panel_rect, base_alpha)") >= 0, "D2 pause renderer should draw the editorial background art as the first main-menu layer")
	_expect(background_body.find("_draw_main_map_texture") < 0, "D2 pause menu should not draw the old procedural map texture in the normal background path")
	_expect(background_body.find("panel_rect.size.y * 1.06") < 0, "D2 pause menu should remove the duplicate procedural sweeping arc over the background art")
	_expect(main_renderer_source.find("star_blades") >= 0, "bright pause main should keep the solid multi-blade compass-star dial motif")
	var main_menu_body := _source_function_body(main_renderer_source, "func draw_menu")
	_expect(main_menu_body.find("get_main_open_bar_ratio(animation_time)") >= 0 and main_menu_body.find("get_main_open_entry_ratio(animation_time, index)") >= 0, "pause menu opening should feed bar sweep and entry cascade ratios into the main renderer")
	var selected_bar_body := _source_function_body(main_renderer_source, "func draw_selected_bar")
	_expect(selected_bar_body.find("final_bar_rect.size.x * clampf(open_ratio") >= 0 and selected_bar_body.find("_with_alpha(Color.WHITE, draw_text_alpha)") >= 0, "pause menu selected bar should sweep in before fading its text")
	var unselected_entry_body := _source_function_body(main_renderer_source, "func draw_unselected_entry")
	_expect(unselected_entry_body.find("OPEN_ITEM_SLIDE_X") >= 0 and unselected_entry_body.find("_with_alpha(color, open_ratio)") >= 0, "pause menu unselected entries should slide/fade in during opening")
	# --- D-options bright editorial re-skin seals ---
	_expect(registry.pause_menu.OPT_PANEL.r < 0.2 and registry.pause_menu.OPT_CARD.r < 0.25 and registry.pause_menu.OPT_TRACK.r < 0.25, "D-options should use dark cyberpunk surface tokens")
	var draw_body := _source_function_body(pause_source, "func draw(")
	_expect(draw_body.find("_draw_main_editorial_base(canvas, Rect2(Vector2.ZERO, view_size), _get_open_bg_alpha())") >= 0, "D-options should draw the shared bright editorial base instead of the dark dim panel")
	_expect(draw_body.find("0.0, 0.0, 0.0, 0.58") < 0, "D-options should not draw the old black dim behind the options panel")
	_expect(draw_body.find("OPT_PANEL") >= 0, "D-options should draw the light content panel token")
	_expect(draw_body.find("OPEN_OPTIONS_SLIDE_Y") >= 0 and draw_body.find("_get_options_open_ratio()") >= 0, "D-options should share the opening fade/slide timing")
	_expect(draw_body.find("_with_alpha(OPT_PANEL") < 0 and draw_body.find("_with_alpha(OPT_BORDER") < 0, "options panel must slide in solid — alpha-fading only the shell desyncs it from its full-alpha tab/slider content")
	var options_window_body := _source_function_body(pause_source, "func _draw_options_window")
	_expect(options_window_body.find("_draw_scanlines") < 0, "D-options should drop the dark HUD scanlines")
	var opt_button_body := _source_function_body(pause_source, "func _draw_button")
	_expect(opt_button_body.find("OPT_CARD") >= 0 and opt_button_body.find("SELECT_BLUE") >= 0 and opt_button_body.find("BUTTON_COLOR") < 0, "D-options buttons should use bright tokens, not the dark button fill")
	var opt_tab_body := _source_function_body(pause_source, "func _draw_tab(")
	_expect(opt_tab_body.find("SELECT_BLUE") >= 0 and opt_tab_body.find("BUTTON_SELECTED") < 0, "D-options tabs should use the bright blue active token")
	var move_count_before := registry.audio.ui_move_count
	_expect(_press(input, owner, KEY_DOWN), "pause menu down should be handled")
	_expect(registry.pause_menu.selected_index == 1, "pause menu down should move to the character info entry")
	var main_feedback := registry.pause_menu._selection_feedback_state.get_snapshot()
	_expect(str(main_feedback.get("scope", "")) == "main", "main menu movement should use main feedback scope")
	_expect(int(main_feedback.get("from_index", -1)) == 0 and int(main_feedback.get("to_index", -1)) == 1, "main menu movement should record from and to indices")
	_expect(float(main_feedback.get("slide_time", -1.0)) == 0.0 and float(main_feedback.get("pop_time", -1.0)) == 0.0, "main menu movement should reset the selection feedback timers")
	_expect(registry.audio.ui_move_count == move_count_before + 1, "main menu movement should play one UI move sound")
	registry.pause_menu.update(0.05)
	main_feedback = registry.pause_menu._selection_feedback_state.get_snapshot()
	_expect(float(main_feedback.get("slide_time", 0.0)) > 0.0, "selection feedback timer should advance while paused")
	move_count_before = registry.audio.ui_move_count
	_expect(_press(input, owner, KEY_UP), "pause menu up should be handled")
	_expect(registry.pause_menu.selected_index == 0, "pause menu up should return to continue")
	_expect(registry.audio.ui_move_count == move_count_before + 1, "main menu reverse movement should play one UI move sound")

	var back_count_before := registry.audio.ui_back_count
	_expect(_press(input, owner, KEY_ESCAPE), "ESC should close the active pause menu")
	_expect(not registry.pause_menu.is_active(), "pause menu should close on second ESC")
	_expect(registry.audio.ui_back_count == back_count_before + 1, "closing the main pause menu should play one UI back sound")

	_expect(_press(input, owner, KEY_ESCAPE), "ESC should reopen pause menu for button flow")
	_expect(_click(input, owner, _main_button_center(registry.pause_menu, owner, 1)), "character info button click should be handled")
	_expect(not registry.pause_menu.is_active(), "character info button should close pause menu")
	_expect(registry.character_info.is_active(), "character info button should open character info overlay")
	registry.character_info.close()

	_expect(_press(input, owner, KEY_ESCAPE), "ESC should reopen pause menu for the exit flow")
	_expect(registry.match_flow_driver.exit_to_main_menu_calls == 0, "exit-to-main must not fire before the EXIT entry is activated")
	_expect(_click(input, owner, _main_button_center(registry.pause_menu, owner, 3)), "EXIT button click should be handled")
	_expect(not registry.pause_menu.is_active(), "EXIT button should close the pause menu")
	_expect(
		registry.match_flow_driver.exit_to_main_menu_calls == 1 and registry.match_flow_driver.saw_owner,
		"EXIT button should route exactly one exit through the match flow driver (Stage 1 rewind + main menu)"
	)

	registry.pause_menu.clear_runtime_state()
	_expect(registry.pause_menu._main_editorial_bg_texture == null, "clear_runtime_state should drop the cached editorial background texture")
	registry.pause_menu.open_options(owner, registry, true)
	_expect(registry.pause_menu._main_editorial_bg_texture != null, "open_options direct entry should prewarm the editorial background off the first draw frame")
	registry.pause_menu.close()
	_expect(not registry.pause_menu.is_active(), "direct options entry should fully deactivate on close")

	_expect(_press(input, owner, KEY_ESCAPE), "ESC should reopen pause menu for options")
	_expect(_click(input, owner, _main_button_center(registry.pause_menu, owner, 2)), "options button click should be handled")
	_expect(registry.pause_menu.is_options_open(), "options button should open the pause options page")
	var bgm_slider: Rect2 = registry.pause_menu._get_slider_rect("bgm", owner.get_viewport_rect().size)
	var sfx_slider: Rect2 = registry.pause_menu._get_slider_rect("sfx", owner.get_viewport_rect().size)
	_expect(_click(input, owner, bgm_slider.position + Vector2(bgm_slider.size.x * 0.25, 3.0)), "BGM slider click should be handled")
	_expect(abs(registry.audio.bgm_volume - 0.25) <= 0.01, "BGM slider should set the runtime BGM volume")
	_expect(_click(input, owner, sfx_slider.position + Vector2(sfx_slider.size.x * 0.85, 3.0)), "SFX slider click should be handled")
	_expect(abs(registry.audio.sfx_volume - 0.85) <= 0.01, "SFX slider should set the runtime SFX volume")
	move_count_before = registry.audio.ui_move_count
	_expect(_press(input, owner, KEY_DOWN), "options focus should move from SFX to back")
	var options_feedback := registry.pause_menu._selection_feedback_state.get_snapshot()
	_expect(str(options_feedback.get("scope", "")) == "options:sound", "sound options movement should use the sound feedback scope")
	_expect(int(options_feedback.get("from_index", -1)) == 1 and int(options_feedback.get("to_index", -1)) == 2, "sound options movement should record from and to focus indices")
	_expect(registry.audio.ui_move_count == move_count_before + 1, "sound options movement should play one UI move sound")
	back_count_before = registry.audio.ui_back_count
	_expect(_press(input, owner, KEY_ENTER), "back button should be handled")
	_expect(registry.pause_menu.is_active() and not registry.pause_menu.is_options_open(), "back should return to the main pause menu")
	_expect(registry.audio.ui_back_count == back_count_before + 1, "options back should play one UI back sound")

	var no_op_options := PauseMenuOverlay.new()
	no_op_options.open_options(owner, registry, true)
	move_count_before = registry.audio.ui_move_count
	_expect(not no_op_options._move_options_focus(1, 0, registry), "zero-count options focus movement should be a no-op")
	_expect(registry.audio.ui_move_count == move_count_before, "zero-count options focus movement should not play UI move sound")
	var confirm_overlay := PauseMenuOverlay.new()
	confirm_overlay.open()
	var confirm_count_before := registry.audio.ui_confirm_count
	var confirm_result: Dictionary = confirm_overlay._activate_selected(owner, registry)
	_expect(bool(confirm_result.get("handled", false)), "direct confirm action should be handled")
	_expect(registry.audio.ui_confirm_count == confirm_count_before + 1, "main menu confirm should play one UI confirm sound")

	var view_size := owner.get_viewport_rect().size
	var mouse_hover_overlay := PauseMenuOverlay.new()
	mouse_hover_overlay.open()
	var mouse_main_panel: Rect2 = mouse_hover_overlay._get_main_panel_rect(view_size)
	var mouse_character_rect: Rect2 = mouse_hover_overlay._get_button_rect(mouse_main_panel, 1, mouse_hover_overlay._get_main_entries().size())
	move_count_before = registry.audio.ui_move_count
	_expect(_motion_overlay(mouse_hover_overlay, owner, mouse_character_rect.get_center()), "main menu hover should be handled")
	_expect(mouse_hover_overlay.selected_index == 1, "main menu hover should select the hovered entry")
	var hover_feedback := mouse_hover_overlay._selection_feedback_state.get_snapshot()
	_expect(str(hover_feedback.get("scope", "")) == "main", "main menu hover should use main feedback scope")
	_expect(int(hover_feedback.get("from_index", -1)) == 0 and int(hover_feedback.get("to_index", -1)) == 1, "main menu hover should record from and to indices")
	_expect(float(hover_feedback.get("slide_time", -1.0)) == 0.0 and float(hover_feedback.get("pop_time", -1.0)) == 0.0, "main menu hover should reset selection feedback timers")
	_expect(registry.audio.ui_move_count == move_count_before + 1, "main menu hover entry should play one UI move sound")
	move_count_before = registry.audio.ui_move_count
	_expect(_motion_overlay(mouse_hover_overlay, owner, mouse_character_rect.get_center() + Vector2(1.0, 0.0)), "same-entry mouse jitter should be handled")
	_expect(registry.audio.ui_move_count == move_count_before, "same-entry mouse jitter should not replay UI move")
	_expect(mouse_hover_overlay._move_selection(1, registry), "keyboard movement should still work after mouse hover")
	_expect(mouse_hover_overlay.selected_index == 2, "keyboard movement should advance beyond the hovered entry")
	move_count_before = registry.audio.ui_move_count
	_expect(_motion_overlay(mouse_hover_overlay, owner, mouse_character_rect.get_center() + Vector2(2.0, 0.0)), "stationary mouse jitter after keyboard movement should be handled")
	_expect(mouse_hover_overlay.selected_index == 2, "stationary mouse jitter should not steal selection back from keyboard navigation")
	_expect(registry.audio.ui_move_count == move_count_before, "anti-fight mouse jitter should not replay UI move")
	_expect(_motion_overlay(mouse_hover_overlay, owner, Vector2.ZERO), "moving into empty menu space should be handled")
	move_count_before = registry.audio.ui_move_count
	_expect(_motion_overlay(mouse_hover_overlay, owner, mouse_character_rect.get_center()), "re-entering a menu entry should be handled")
	_expect(mouse_hover_overlay.selected_index == 1, "re-entering a menu entry should select it")
	_expect(registry.audio.ui_move_count == move_count_before + 1, "re-entering from empty space should replay UI move once")

	var selected_hover_overlay := PauseMenuOverlay.new()
	selected_hover_overlay.open()
	var selected_main_panel: Rect2 = selected_hover_overlay._get_main_panel_rect(view_size)
	var selected_main_rect: Rect2 = selected_hover_overlay._get_button_rect(selected_main_panel, 0, selected_hover_overlay._get_main_entries().size())
	move_count_before = registry.audio.ui_move_count
	_expect(_motion_overlay(selected_hover_overlay, owner, selected_main_rect.get_center()), "hovering the already selected entry should be handled")
	_expect(registry.audio.ui_move_count == move_count_before, "hovering the already selected entry should not replay UI move")

	var mouse_confirm_overlay := PauseMenuOverlay.new()
	mouse_confirm_overlay.open()
	var mouse_confirm_panel: Rect2 = mouse_confirm_overlay._get_main_panel_rect(view_size)
	confirm_count_before = registry.audio.ui_confirm_count
	_expect(_left_click_overlay(mouse_confirm_overlay, owner, mouse_confirm_overlay._get_button_rect(mouse_confirm_panel, 0, mouse_confirm_overlay._get_main_entries().size()).get_center()), "main menu left click should be handled")
	_expect(not mouse_confirm_overlay.is_active(), "main menu left click should activate and close the continue entry")
	_expect(registry.audio.ui_confirm_count == confirm_count_before + 1, "main menu left click should play one UI confirm sound")

	var mouse_back_overlay := PauseMenuOverlay.new()
	mouse_back_overlay.open()
	back_count_before = registry.audio.ui_back_count
	_expect(_right_click_overlay(mouse_back_overlay, owner, Vector2.ZERO), "main menu right click should be handled")
	_expect(not mouse_back_overlay.is_active(), "main menu right click should close the pause menu")
	_expect(registry.audio.ui_back_count == back_count_before + 1, "main menu right click should play one UI back sound")

	var options_hover_overlay := PauseMenuOverlay.new()
	options_hover_overlay.open_options(owner, registry, true)
	var options_hover_panel: Rect2 = options_hover_overlay._get_options_panel_rect(view_size)
	move_count_before = registry.audio.ui_move_count
	_expect(_motion_overlay(options_hover_overlay, owner, options_hover_overlay._get_back_button_rect(options_hover_panel).get_center()), "options row hover should be handled")
	_expect(options_hover_overlay.options_focus == 2, "options hover should select the hovered back row")
	options_feedback = options_hover_overlay._selection_feedback_state.get_snapshot()
	_expect(str(options_feedback.get("scope", "")) == "options:sound", "options hover should use the active tab feedback scope")
	_expect(registry.audio.ui_move_count == move_count_before + 1, "options hover entry should play one UI move sound")

	var slider_mouse_overlay := PauseMenuOverlay.new()
	slider_mouse_overlay.open_options(owner, registry, true)
	var slider_mouse_rect: Rect2 = slider_mouse_overlay._get_slider_hit_rect("bgm", view_size)
	move_count_before = registry.audio.ui_move_count
	_expect(_left_click_overlay(slider_mouse_overlay, owner, slider_mouse_rect.get_center()), "slider mouse grab should be handled")
	_expect(registry.audio.ui_move_count == move_count_before + 1, "slider mouse grab should play UI move once")
	_expect(_motion_overlay(slider_mouse_overlay, owner, slider_mouse_rect.get_center() + Vector2(12.0, 0.0)), "slider drag motion should be handled")
	_expect(_motion_overlay(slider_mouse_overlay, owner, slider_mouse_rect.get_center() + Vector2(24.0, 0.0)), "continued slider drag motion should be handled")
	_expect(registry.audio.ui_move_count == move_count_before + 1, "slider drag ticks should not replay UI move")

	var options_click_overlay := PauseMenuOverlay.new()
	options_click_overlay.open_options(owner, registry, true)
	var options_click_panel: Rect2 = options_click_overlay._get_options_panel_rect(view_size)
	confirm_count_before = registry.audio.ui_confirm_count
	_expect(_left_click_overlay(options_click_overlay, owner, options_click_overlay._get_reset_button_rect(options_click_panel).get_center()), "options reset click should be handled")
	_expect(registry.audio.ui_confirm_count == confirm_count_before + 1, "options reset click should play one UI confirm sound")
	confirm_count_before = registry.audio.ui_confirm_count
	_expect(_left_click_overlay(options_click_overlay, owner, options_click_overlay._get_display_tab_rect(options_click_panel).get_center()), "options tab click should be handled")
	_expect(options_click_overlay.options_tab == "display", "options tab click should switch tabs")
	_expect(registry.audio.ui_confirm_count == confirm_count_before + 1, "options tab switch should play one UI confirm sound")
	confirm_count_before = registry.audio.ui_confirm_count
	_expect(_left_click_overlay(options_click_overlay, owner, options_click_overlay._get_display_fullscreen_rect(options_click_panel).get_center()), "display value click should be handled")
	_expect(registry.audio.ui_confirm_count == confirm_count_before + 1, "display value click should play one UI confirm sound")
	back_count_before = registry.audio.ui_back_count
	_expect(_left_click_overlay(options_click_overlay, owner, options_click_overlay._get_display_back_button_rect(options_click_panel).get_center()), "options back click should be handled")
	_expect(not options_click_overlay.is_active(), "options-only back click should close the overlay")
	_expect(registry.audio.ui_back_count == back_count_before + 1, "options back click should play one UI back sound")

	var options_right_click_overlay := PauseMenuOverlay.new()
	options_right_click_overlay.open_options(owner, registry, true)
	back_count_before = registry.audio.ui_back_count
	_expect(_right_click_overlay(options_right_click_overlay, owner, Vector2.ZERO), "options right click should be handled")
	_expect(not options_right_click_overlay.is_active(), "options right click should close the options-only overlay")
	_expect(registry.audio.ui_back_count == back_count_before + 1, "options right click should play one UI back sound")

	_expect(_click(input, owner, _main_button_center(registry.pause_menu, owner, 2)), "options button should reopen the pause options page")
	var options_panel: Rect2 = registry.pause_menu._get_options_panel_rect(owner.get_viewport_rect().size)
	_expect(_click(input, owner, registry.pause_menu._get_display_tab_rect(options_panel).get_center()), "display tab click should be handled")
	_expect(registry.pause_menu.is_options_open(), "display tab should keep the options page open")
	_expect(_click(input, owner, registry.pause_menu._get_display_fullscreen_rect(options_panel).get_center()), "fullscreen pill should be handled")
	_expect(_click(input, owner, registry.pause_menu._get_display_exclusive_fullscreen_rect(options_panel).get_center()), "exclusive fullscreen pill should be handled")
	var fps_cap_value_rect: Rect2 = registry.pause_menu._get_display_fps_cap_value_rect(options_panel)
	var vsync_value_rect: Rect2 = registry.pause_menu._get_display_vsync_value_rect(options_panel)
	_expect(_click(input, owner, fps_cap_value_rect.position + Vector2(fps_cap_value_rect.size.x * 0.75, fps_cap_value_rect.size.y * 0.5)), "render FPS cap row should be handled")
	_expect(_click(input, owner, vsync_value_rect.position + Vector2(vsync_value_rect.size.x * 0.75, vsync_value_rect.size.y * 0.5)), "vsync row should be handled")
	_expect(_click(input, owner, registry.pause_menu._get_display_default_row_rect(options_panel).get_center()), "default display checkbox should be handled")
	_expect(_click(input, owner, registry.pause_menu._get_display_auto_refresh_row_rect(options_panel).get_center()), "auto 60Hz row should be handled")
	registry.view_layout.saved_auto_refresh_rate_60hz = false
	_expect(_click(input, owner, registry.pause_menu._get_display_apply_60hz_button_rect(options_panel).get_center()), "apply 60Hz button should be handled")
	_expect(registry.view_layout.saved_auto_refresh_rate_60hz, "apply 60Hz button should opt into automatic refresh switching")
	_expect(registry.view_layout.system_settings_count == 0, "apply 60Hz button should not open Windows settings when automatic switching succeeds")
	_expect(_click(input, owner, registry.pause_menu._get_display_save_button_rect(options_panel).get_center()), "display save button should be handled")
	_expect(registry.view_layout.apply_count == 1, "display save should apply the selected mode")
	_expect(registry.view_layout.display_mode == "exclusive_fullscreen", "display save should apply exclusive fullscreen")
	_expect(registry.view_layout.saved_mode == "exclusive_fullscreen" and registry.view_layout.saved_remember, "display save should persist the default setting when checked")
	_expect(registry.view_layout.render_fps_cap == -2, "display save should apply stable monitor render FPS cap")
	_expect(registry.view_layout.saved_render_fps_cap == -2, "display save should persist render FPS cap")
	_expect(registry.view_layout.vsync_mode == 3, "display save should apply selected vsync mode")
	_expect(registry.view_layout.saved_vsync_mode == 3, "display save should persist vsync mode")
	_expect(registry.view_layout.saved_auto_refresh_rate_60hz, "display save should persist opt-in automatic 60Hz switching")
	_expect(_click(input, owner, registry.pause_menu._get_display_back_button_rect(options_panel).get_center()), "display back button should be handled")
	_expect(registry.pause_menu.is_active() and not registry.pause_menu.is_options_open(), "display back should return to the main pause menu")

	_expect(_click(input, owner, _main_button_center(registry.pause_menu, owner, 2)), "options button should reopen for controls tab")
	options_panel = registry.pause_menu._get_options_panel_rect(owner.get_viewport_rect().size)
	_expect(_click(input, owner, registry.pause_menu._get_controls_tab_rect(options_panel).get_center()), "controls tab click should be handled")
	_expect(registry.pause_menu.options_tab == "controls", "controls tab should become active")
	_expect(registry.pause_menu.controls_device_view == "keyboard_mouse", "controls tab should default to keyboard and mouse")
	_expect(_click(input, owner, registry.pause_menu._get_controls_joypad_rect(options_panel).get_center()), "joypad controls view should be handled")
	_expect(registry.pause_menu.controls_device_view == "joypad", "joypad controls view should become active")
	_expect(str(registry.pause_menu._get_control_mapping_rows()[0].get("value", "")).find("왼스틱") >= 0, "joypad controls view should list left-stick movement")
	_expect(str(registry.pause_menu._get_control_mapping_rows()[1].get("value", "")).find("B") >= 0, "joypad controls view should list B as the dash button")
	_expect(_click(input, owner, registry.pause_menu._get_controls_back_button_rect(options_panel).get_center()), "controls back button should be handled")
	_expect(registry.pause_menu.is_active() and not registry.pause_menu.is_options_open(), "controls back should return to the main pause menu")

	_expect(_click(input, owner, _main_button_center(registry.pause_menu, owner, 2)), "options button should reopen for language tab")
	options_panel = registry.pause_menu._get_options_panel_rect(owner.get_viewport_rect().size)
	_expect(_click(input, owner, registry.pause_menu._get_language_tab_rect(options_panel).get_center()), "language tab click should be handled")
	_expect(registry.pause_menu.options_tab == "language", "language tab should become active")
	_expect(registry.pause_menu.language_code == "ko", "language tab should start from the saved Korean language")
	_expect(_click(input, owner, registry.pause_menu._get_language_english_rect(options_panel).get_center()), "English language option should be handled")
	_expect(LanguageSettings.get_language() == "en", "English option should persist the English language")
	_expect(owner.language_refresh_count >= 1, "English language option should refresh owner language text")
	_expect(str(registry.pause_menu._get_main_entries()[0].get("label", "")) == "Continue", "pause menu labels should switch to English")
	_expect(str(registry.pause_menu._get_control_mapping_rows()[0].get("label", "")) == "Move", "control mapping labels should switch to English")
	_expect(str(registry.pause_menu._get_vibration_level_label(3)).find("Normal") >= 0, "vibration label should switch to English")
	_expect(_click(input, owner, registry.pause_menu._get_language_chinese_rect(options_panel).get_center()), "Chinese language option should be handled")
	_expect(LanguageSettings.get_language() == "zh", "Chinese option should persist the Chinese language")
	_expect(owner.language_refresh_count >= 2, "Chinese language option should refresh owner language text")
	_expect(str(registry.pause_menu._get_main_entries()[0].get("label", "")) == "继续", "pause menu labels should switch to Chinese")
	_expect(str(registry.pause_menu._get_control_mapping_rows()[0].get("label", "")) == "移动", "control mapping labels should switch to Chinese")
	_expect(str(registry.pause_menu._get_vibration_level_label(3)).find("普通") >= 0, "vibration label should switch to Chinese")
	_expect(_click(input, owner, registry.pause_menu._get_language_japanese_rect(options_panel).get_center()), "Japanese language option should be handled")
	_expect(LanguageSettings.get_language() == "ja", "Japanese option should persist the Japanese language")
	_expect(owner.language_refresh_count >= 3, "Japanese language option should refresh owner language text")
	_expect(str(registry.pause_menu._get_main_entries()[0].get("label", "")) == "続ける", "pause menu labels should switch to Japanese")
	_expect(str(registry.pause_menu._get_control_mapping_rows()[0].get("label", "")) == "移動", "control mapping labels should switch to Japanese")
	_expect(str(registry.pause_menu._get_vibration_level_label(3)).find("普通") >= 0, "vibration label should switch to Japanese")
	_expect(_click(input, owner, registry.pause_menu._get_language_spanish_rect(options_panel).get_center()), "Spanish language option should be handled")
	_expect(LanguageSettings.get_language() == "es", "Spanish option should persist the Spanish language")
	_expect(owner.language_refresh_count >= 4, "Spanish language option should refresh owner language text")
	_expect(str(registry.pause_menu._get_main_entries()[0].get("label", "")) == "Continuar", "pause menu labels should switch to Spanish")
	_expect(str(registry.pause_menu._get_control_mapping_rows()[0].get("label", "")) == "Mover", "control mapping labels should switch to Spanish")
	_expect(str(registry.pause_menu._get_vibration_level_label(3)).find("Normal") >= 0, "vibration label should switch to Spanish")
	_expect(_click(input, owner, registry.pause_menu._get_language_portuguese_brazil_rect(options_panel).get_center()), "Brazilian Portuguese language option should be handled")
	_expect(LanguageSettings.get_language() == "pt-BR", "Brazilian Portuguese option should persist the Brazilian Portuguese language")
	_expect(owner.language_refresh_count >= 5, "Brazilian Portuguese language option should refresh owner language text")
	_expect(str(registry.pause_menu._get_main_entries()[0].get("label", "")) == "Continuar", "pause menu labels should switch to Brazilian Portuguese")
	_expect(str(registry.pause_menu._get_control_mapping_rows()[0].get("label", "")) == "Mover", "control mapping labels should switch to Brazilian Portuguese")
	_expect(str(registry.pause_menu._get_vibration_level_label(3)).find("Normal") >= 0, "vibration label should switch to Brazilian Portuguese")
	_expect(_click(input, owner, registry.pause_menu._get_language_russian_rect(options_panel).get_center()), "Russian language option should be handled")
	_expect(LanguageSettings.get_language() == "ru", "Russian option should persist the Russian language")
	_expect(owner.language_refresh_count >= 6, "Russian language option should refresh owner language text")
	_expect(str(registry.pause_menu._get_main_entries()[0].get("label", "")) == "Продолжить", "pause menu labels should switch to Russian")
	_expect(str(registry.pause_menu._get_control_mapping_rows()[0].get("label", "")) == "Движение", "control mapping labels should switch to Russian")
	_expect(str(registry.pause_menu._get_vibration_level_label(3)).find("Обычная") >= 0, "vibration label should switch to Russian")
	_expect(_click(input, owner, registry.pause_menu._get_language_korean_rect(options_panel).get_center()), "Korean language option should be handled")
	_expect(LanguageSettings.get_language() == "ko", "Korean option should persist the Korean language")
	_expect(owner.language_refresh_count >= 7, "Korean language option should refresh owner language text")
	_expect(_click(input, owner, registry.pause_menu._get_language_back_button_rect(options_panel).get_center()), "language back button should be handled")
	_expect(registry.pause_menu.is_active() and not registry.pause_menu.is_options_open(), "language back should return to the main pause menu")

	registry.view_layout.display_mode = "windowed"
	registry.view_layout.saved_mode = "windowed"
	registry.view_layout.remember_default = false
	registry.view_layout.saved_remember = false
	registry.view_layout.render_fps_cap = 72
	registry.view_layout.saved_render_fps_cap = 72
	registry.view_layout.vsync_mode = 0
	registry.view_layout.saved_vsync_mode = 0
	registry.view_layout.auto_refresh_rate_60hz = false
	registry.view_layout.saved_auto_refresh_rate_60hz = false
	var recommended_options := PauseMenuOverlay.new()
	recommended_options.open_options(owner, registry, true)
	var recommended_panel: Rect2 = recommended_options._get_options_panel_rect(owner.get_viewport_rect().size)
	var recommended_result: Dictionary = recommended_options._handle_display_click(
		recommended_options._get_display_recommended_button_rect(recommended_panel).get_center(),
		owner,
		registry,
		recommended_panel
	)
	_expect(bool(recommended_result.get("handled", false)), "recommended display settings button should be handled")
	_expect(recommended_options.display_mode == "exclusive_fullscreen", "recommended settings should select exclusive fullscreen")
	_expect(recommended_options.remember_display_mode, "recommended settings should remember the display mode")
	_expect(recommended_options.render_fps_cap == -2, "recommended settings should select the stable monitor render FPS")
	_expect(recommended_options.vsync_mode == -1, "recommended settings should select automatic VSync")
	_expect(not recommended_options.auto_refresh_rate_60hz, "recommended settings should not silently enable automatic OS refresh switching")
	_expect(registry.view_layout.display_mode == "exclusive_fullscreen", "recommended settings should apply exclusive fullscreen")
	_expect(registry.view_layout.saved_mode == "exclusive_fullscreen" and registry.view_layout.saved_remember, "recommended settings should persist exclusive fullscreen")
	_expect(registry.view_layout.render_fps_cap == -2 and registry.view_layout.saved_render_fps_cap == -2, "recommended settings should apply and persist stable monitor FPS")
	_expect(registry.view_layout.vsync_mode == -1 and registry.view_layout.saved_vsync_mode == -1, "recommended settings should apply and persist automatic VSync")

	var direct_options := PauseMenuOverlay.new()
	direct_options.open_options(owner, registry, true)
	_expect(direct_options.is_options_open(), "direct settings entry should open the options page without the pause panel")
	var direct_escape := InputEventKey.new()
	direct_escape.pressed = true
	@warning_ignore("int_as_enum_without_cast")
	direct_escape.keycode = KEY_ESCAPE
	@warning_ignore("int_as_enum_without_cast")
	direct_escape.physical_keycode = KEY_ESCAPE
	var direct_result: Dictionary = direct_options.handle_input(direct_escape, owner, registry, owner.get_viewport_rect().size)
	_expect(bool(direct_result.get("handled", false)), "direct settings ESC should be handled")
	_expect(not direct_options.is_active(), "direct settings ESC should close the overlay")

	registry.view_layout.display_mode = "windowed"
	registry.view_layout.saved_mode = "exclusive_fullscreen"
	registry.view_layout.remember_default = true
	registry.view_layout.render_fps_cap = 72
	registry.view_layout.saved_render_fps_cap = 48
	registry.view_layout.vsync_mode = 0
	registry.view_layout.saved_vsync_mode = 1
	registry.view_layout.saved_auto_refresh_rate_60hz = true
	var saved_options := PauseMenuOverlay.new()
	saved_options.open_options(owner, registry, true)
	_expect(saved_options.display_mode == "exclusive_fullscreen", "display options should show the remembered display mode instead of overwriting it with the current window mode")
	_expect(saved_options.render_fps_cap == 48, "display options should show the saved render FPS preference")
	_expect(saved_options.vsync_mode == 1, "display options should show the saved VSync preference")
	_expect(saved_options.auto_refresh_rate_60hz, "display options should show the saved automatic 60Hz preference")

	registry.view_layout.display_mode = "windowed"
	registry.view_layout.saved_mode = "exclusive_fullscreen"
	registry.view_layout.remember_default = false
	registry.view_layout.save_display_count = 0
	var fps_only_options := PauseMenuOverlay.new()
	fps_only_options.open_options(owner, registry, true)
	fps_only_options._save_display_options(owner, registry)
	_expect(registry.view_layout.save_display_count == 0, "saving display options without touching display mode should not overwrite a stored display preference with runtime windowed")
	_expect(registry.view_layout.saved_mode == "exclusive_fullscreen", "untouched display save should preserve the stored non-windowed mode")

	var gamepad_options := PauseMenuOverlay.new()
	gamepad_options.open_options(owner, registry, true)
	_expect(bool(gamepad_options.handle_input(_joy_button(JOY_BUTTON_RIGHT_SHOULDER), owner, registry, owner.get_viewport_rect().size).get("handled", false)), "gamepad shoulder should switch settings tabs")
	_expect(gamepad_options.options_tab == "display", "first gamepad tab switch should open display settings")
	_expect(bool(gamepad_options.handle_input(_joy_button(JOY_BUTTON_RIGHT_SHOULDER), owner, registry, owner.get_viewport_rect().size).get("handled", false)), "second gamepad shoulder should switch to controls")
	_expect(gamepad_options.options_tab == "controls", "second gamepad tab switch should open controls settings")
	_expect(bool(gamepad_options.handle_input(_joy_button(JOY_BUTTON_RIGHT_SHOULDER), owner, registry, owner.get_viewport_rect().size).get("handled", false)), "third gamepad shoulder should switch to language")
	_expect(gamepad_options.options_tab == "language", "third gamepad tab switch should open language settings")
	_expect(bool(gamepad_options.handle_input(_joy_button(JOY_BUTTON_RIGHT_SHOULDER), owner, registry, owner.get_viewport_rect().size).get("handled", false)), "fourth gamepad shoulder should wrap to sound")
	_expect(gamepad_options.options_tab == "sound", "fourth gamepad tab switch should wrap to sound settings")
	_expect(bool(gamepad_options.handle_input(_joy_button(JOY_BUTTON_RIGHT_SHOULDER), owner, registry, owner.get_viewport_rect().size).get("handled", false)), "fifth gamepad shoulder should return to display")
	_expect(bool(gamepad_options.handle_input(_joy_button(JOY_BUTTON_RIGHT_SHOULDER), owner, registry, owner.get_viewport_rect().size).get("handled", false)), "sixth gamepad shoulder should return to controls")
	_expect(bool(gamepad_options.handle_input(_joy_button(JOY_BUTTON_A), owner, registry, owner.get_viewport_rect().size).get("handled", false)), "gamepad A should switch controls view")
	_expect(gamepad_options.controls_device_view == "joypad", "gamepad A should select the joypad control map")
	_expect(gamepad_options.gamepad_vibration_level == 3, "joypad settings should treat the current rumble as the middle level")
	gamepad_options.options_focus = 1
	_expect(bool(gamepad_options.handle_input(_joy_button(JOY_BUTTON_DPAD_RIGHT), owner, registry, owner.get_viewport_rect().size).get("handled", false)), "joypad right should raise vibration sensitivity")
	_expect(GamepadVibrationSettings.get_vibration_level() == 4, "joypad right should persist vibration sensitivity level 4")
	_expect(GamepadVibrationSettings.get_vibration_level_label(4).find("4 / 5") >= 0, "vibration label should expose the 5-step scale")
	_expect(bool(gamepad_options.handle_input(_joy_button(JOY_BUTTON_DPAD_LEFT), owner, registry, owner.get_viewport_rect().size).get("handled", false)), "joypad left should lower vibration sensitivity")
	_expect(GamepadVibrationSettings.get_vibration_level() == 3, "joypad left should return vibration sensitivity to the middle level")
	_expect(bool(gamepad_options.handle_input(_joy_button(JOY_BUTTON_B), owner, registry, owner.get_viewport_rect().size).get("handled", false)), "gamepad B should close direct settings")
	_expect(not gamepad_options.is_active(), "gamepad B should close direct settings overlay")

	_expect(owner.redraw_count >= 6, "pause menu input should queue redraws")
	_restore_settings_snapshots()
	if _failed:
		quit(1)
		return
	print("pause_menu_overlay_smoke: ok")
	quit(0)


func _press(input: Object, owner: Object, keycode: int) -> bool:
	var event := InputEventKey.new()
	event.pressed = true
	@warning_ignore("int_as_enum_without_cast")
	event.keycode = keycode
	@warning_ignore("int_as_enum_without_cast")
	event.physical_keycode = keycode
	return bool(input.handle_input(event, owner, registry, Callable(self, "_get_module"), {}))


func _click(input: Object, owner: Object, position: Vector2) -> bool:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	return bool(input.handle_input(event, owner, registry, Callable(self, "_get_module"), {}))


func _main_button_center(overlay: Object, owner: Object, index: int) -> Vector2:
	var panel_rect: Rect2 = overlay._get_main_panel_rect(owner.get_viewport_rect().size)
	var entry_count: int = overlay._get_main_entries().size()
	return overlay._get_button_rect(panel_rect, index, entry_count).get_center()


func _motion_overlay(overlay: Object, owner: Object, position: Vector2) -> bool:
	var event := InputEventMouseMotion.new()
	event.position = position
	var result: Dictionary = overlay.handle_input(event, owner, registry, owner.get_viewport_rect().size)
	return bool(result.get("handled", false))


func _left_click_overlay(overlay: Object, owner: Object, position: Vector2) -> bool:
	return _mouse_button_overlay(overlay, owner, position, MOUSE_BUTTON_LEFT)


func _right_click_overlay(overlay: Object, owner: Object, position: Vector2) -> bool:
	return _mouse_button_overlay(overlay, owner, position, MOUSE_BUTTON_RIGHT)


func _mouse_button_overlay(overlay: Object, owner: Object, position: Vector2, button_index: MouseButton) -> bool:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = button_index
	event.position = position
	var result: Dictionary = overlay.handle_input(event, owner, registry, owner.get_viewport_rect().size)
	return bool(result.get("handled", false))


func _joy_button(button_index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.pressed = true
	event.button_index = button_index
	return event


func _get_module(key: String) -> Object:
	return registry.get_instance(key)


func _snapshot_settings_file(path: String) -> Dictionary:
	var had_original := FileAccess.file_exists(path)
	var original_bytes := PackedByteArray()
	if had_original:
		original_bytes = FileAccess.get_file_as_bytes(path)
	return {
		"had": had_original,
		"bytes": original_bytes,
	}


func _restore_vibration_settings_snapshot() -> void:
	if _vibration_settings_snapshot.is_empty():
		return
	_restore_settings_file(
		GamepadVibrationSettings.SETTINGS_PATH,
		bool(_vibration_settings_snapshot.get("had", false)),
		_vibration_settings_snapshot.get("bytes", PackedByteArray())
	)


func _restore_language_settings_snapshot() -> void:
	if _language_settings_snapshot.is_empty():
		return
	_restore_settings_file(
		LanguageSettings.SETTINGS_PATH,
		bool(_language_settings_snapshot.get("had", false)),
		_language_settings_snapshot.get("bytes", PackedByteArray())
	)
	LanguageSettings.reset_cache_for_tests()
	LanguageSettings.apply_saved_language()


func _restore_settings_snapshots() -> void:
	_restore_vibration_settings_snapshot()
	_restore_language_settings_snapshot()


func _restore_settings_file(path: String, had_file: bool, file_bytes: PackedByteArray) -> void:
	if had_file:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(file_bytes)
			file.close()
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _verify_pause_description_localization_keys() -> void:
	var expected := {
		LanguageSettings.LANGUAGE_KOREAN: {
			"pause.desc.continue": "게임으로 돌아가기",
			"pause.desc.character_info": "캐릭터 정보 확인",
			"pause.desc.options": "게임 설정 변경",
			"pause.exit_to_main": "나가기",
			"pause.desc.exit_to_main": "메인 메뉴로 돌아가기",
		},
		LanguageSettings.LANGUAGE_ENGLISH: {
			"pause.desc.continue": "Return to game",
			"pause.desc.character_info": "View character info",
			"pause.desc.options": "Game settings",
			"pause.exit_to_main": "Exit",
			"pause.desc.exit_to_main": "Return to main menu",
		},
		LanguageSettings.LANGUAGE_CHINESE: {
			"pause.desc.continue": "返回游戏",
			"pause.desc.character_info": "查看角色信息",
			"pause.desc.options": "游戏设置",
			"pause.exit_to_main": "退出",
			"pause.desc.exit_to_main": "返回主菜单",
		},
		LanguageSettings.LANGUAGE_JAPANESE: {
			"pause.desc.continue": "ゲームに戻る",
			"pause.desc.character_info": "キャラクター情報を確認",
			"pause.desc.options": "ゲーム設定",
			"pause.exit_to_main": "やめる",
			"pause.desc.exit_to_main": "メインメニューに戻る",
		},
		LanguageSettings.LANGUAGE_SPANISH: {
			"pause.desc.continue": "Volver al juego",
			"pause.desc.character_info": "Ver info del personaje",
			"pause.desc.options": "Ajustes del juego",
			"pause.exit_to_main": "Salir",
			"pause.desc.exit_to_main": "Volver al menú principal",
		},
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL: {
			"pause.desc.continue": "Voltar ao jogo",
			"pause.desc.character_info": "Ver info do personagem",
			"pause.desc.options": "Configurações do jogo",
			"pause.exit_to_main": "Sair",
			"pause.desc.exit_to_main": "Voltar ao menu principal",
		},
		LanguageSettings.LANGUAGE_RUSSIAN: {
			"pause.desc.continue": "Вернуться в игру",
			"pause.desc.character_info": "Информация о персонаже",
			"pause.desc.options": "Настройки игры",
			"pause.exit_to_main": "Выйти",
			"pause.desc.exit_to_main": "Вернуться в главное меню",
		},
	}
	for language in expected.keys():
		var table: Dictionary = LanguageSettingsData.TEXT.get(language, {})
		_expect(not table.is_empty(), "D3 pause desc language table should exist for %s" % language)
		var language_expected: Dictionary = expected[language]
		for key in language_expected.keys():
			_expect(table.has(key), "D3 pause desc key should exist: %s/%s" % [language, key])
			var value := str(table.get(key, ""))
			_expect(not value.strip_edges().is_empty(), "D3 pause desc key should be non-empty: %s/%s" % [language, key])
			_expect(value == str(language_expected[key]), "D3 pause desc key should match the approved copy: %s/%s" % [language, key])


func _source_function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + signature.length())
	if next < 0:
		return source.substr(start)
	return source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	_restore_settings_snapshots()
	push_error(message)
	quit(1)
