extends SceneTree

const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const BattleSceneOverlayInputController := preload("res://scripts/core/battle_scene_overlay_input_controller.gd")
const GamepadVibrationSettings := preload("res://scripts/core/gamepad_vibration_settings.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const PauseMenuMainRenderer := preload("res://scripts/hud/pause_menu_main_renderer.gd")
const PauseMenuOverlay := preload("res://scripts/hud/pause_menu_overlay.gd")
const RuntimePerkTraditionalChrome := preload("res://scripts/hud/runtime_perk_traditional_chrome.gd")


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
	_expect(
		registry.pause_menu.PAPER_BG.is_equal_approx(Color(0.055, 0.050, 0.042))
		and registry.pause_menu.INK.is_equal_approx(Color(0.92, 0.89, 0.82))
		and registry.pause_menu.SELECT_BLUE.is_equal_approx(Color(0.62, 0.52, 0.30))
		and registry.pause_menu.SELECT_SUBINK.is_equal_approx(Color(0.14, 0.10, 0.06))
		and registry.pause_menu.GRAPHIC_INK.is_equal_approx(Color(0.03, 0.028, 0.024))
		and registry.pause_menu.TITLE_ON_GRAPHIC_INK.is_equal_approx(Color(0.90, 0.86, 0.78))
		and registry.pause_menu.DIAMOND_GRAY.is_equal_approx(Color(0.72, 0.60, 0.36))
		and registry.pause_menu.SPINE_LINE.is_equal_approx(Color(0.03, 0.028, 0.024, 0.28))
		and registry.pause_menu.SEAL_RED.is_equal_approx(Color(139.0 / 255.0, 44.0 / 255.0, 33.0 / 255.0))
		and registry.pause_menu.SPIRIT_BLUE.is_equal_approx(Color(0.42, 0.66, 0.86)),
		"pause menu should seal the Hwangyeokjeon ink, ivory, and aged-gilt main palette"
	)
	_expect(registry.pause_menu.SEAL_RED.is_equal_approx(RuntimePerkTraditionalChrome.SEAL_RED), "phase 4 pause needle should reuse the canonical Hwangyeokjeon seal red")
	_expect(registry.pause_menu.OPT_SLIDER_BGM_FILL.is_equal_approx(registry.pause_menu.SPIRIT_BLUE), "phase 6 BGM slider should reuse the pause yundo spirit blue")
	_expect(registry.pause_menu.OPT_SLIDER_SFX_FILL.is_equal_approx(RuntimePerkTraditionalChrome.JADE), "phase 6 SFX slider should link directly to the canonical Hwangyeokjeon jade")
	_expect(registry.pause_menu.PAPER_BG.r < 0.2 and registry.pause_menu.INK.r > 0.7, "Hwangyeokjeon pause menu should keep a dark ink ground and light ivory text")
	_expect(registry.pause_menu.TITLE_ON_GRAPHIC_INK.r > registry.pause_menu.GRAPHIC_INK.r + 0.70, "pause title should stay readable on the dark editorial wedge")
	_expect(
		registry.pause_menu.MAIN_EDITORIAL_BG_PATH == "res://assets/ui/pause_menu/pause_system_hwangyeokjeon_map_bg_v1.png",
		"phase 3 pause menu should route the fullscreen plate to the Hwangyeokjeon map asset"
	)
	_expect(FileAccess.file_exists(registry.pause_menu.MAIN_EDITORIAL_BG_PATH), "D2 pause menu should ship the editorial map background PNG")
	_expect(FileAccess.file_exists(registry.pause_menu.MAIN_EDITORIAL_BG_PATH + ".import"), "D2 pause menu should ship the export-safe editorial map background import file")
	_expect(registry.pause_menu._main_editorial_bg_texture != null, "D2 pause menu should prewarm the editorial background texture when opened")
	_expect(
		registry.pause_menu._main_editorial_bg_texture.get_width() == 1920
		and registry.pause_menu._main_editorial_bg_texture.get_height() == 1080,
		"phase 3 Hwangyeokjeon pause background should keep the sealed 1920x1080 fullscreen budget"
	)
	var default_cover_region: Rect2 = registry.pause_menu._get_main_background_cover_region(main_panel_rect)
	var expected_default_cover_width := 1080.0 * main_panel_rect.size.aspect()
	_expect(
		default_cover_region.position.is_equal_approx(Vector2.ZERO)
		and is_equal_approx(default_cover_region.size.x, expected_default_cover_width)
		and is_equal_approx(default_cover_region.size.y, 1080.0),
		"phase 4 default cover-fit should crop only the map plate's right edge and preserve the quiet left text field"
	)
	var ultrawide_panel_rect := Rect2(Vector2.ZERO, Vector2(2560.0, 1080.0))
	var ultrawide_cover_region: Rect2 = registry.pause_menu._get_main_background_cover_region(ultrawide_panel_rect)
	_expect(
		is_equal_approx(ultrawide_cover_region.position.x, 0.0)
		and is_equal_approx(ultrawide_cover_region.position.y, 135.0)
		and ultrawide_cover_region.size.is_equal_approx(Vector2(1920.0, 810.0)),
		"phase 4 21:9 cover-fit should center-crop the plate vertically instead of stretching its mountains"
	)
	var entries: Array = registry.pause_menu._get_main_entries()
	_expect(str(entries[0].get("en", "")) == "RESUME" and str(entries[1].get("en", "")) == "STATUS" and str(entries[2].get("en", "")) == "SETTINGS", "bright pause menu should expose editorial English menu labels")
	_expect(entries.size() == 4 and str(entries[3].get("en", "")) == "EXIT" and str(entries[3].get("action", "")) == "exit_to_main", "pause menu should expose the EXIT entry as the fourth item")
	_verify_pause_description_localization_keys()
	_expect(
		str(entries[0].get("label", "")) == "계속"
		and str(entries[1].get("label", "")) == "캐릭터정보"
		and str(entries[2].get("label", "")) == "옵션"
		and str(entries[3].get("label", "")) == "나가기",
		"phase 2 should promote the existing Korean pause labels without rewriting their approved copy"
	)
	_expect(str(entries[0].get("desc", "")) == "게임으로 돌아가기" and str(entries[1].get("desc", "")) == "캐릭터 정보 확인" and str(entries[2].get("desc", "")) == "게임 설정 변경", "D3 pause menu should use Korean descriptive local labels")
	_expect(str(entries[3].get("label", "")) == "나가기" and str(entries[3].get("desc", "")) == "메인 메뉴로 돌아가기", "EXIT entry should use the Korean label and main-menu description")
	var main_brush_font: Font = registry.pause_menu._get_main_brush_font()
	_expect(main_brush_font is SystemFont, "phase 2 pause main labels should resolve through the shared Gungsuh/GungSeo/Batang SystemFont route")
	_expect(registry.pause_menu._get_main_primary_label_text(entries[0]) == "계속", "phase 2 Korean pause menu should promote the localized label to the primary line")
	_expect(registry.pause_menu._get_main_title_text() == "일시정지", "phase 2 Korean pause title should reuse the existing pause.title copy")
	_expect(registry.pause_menu._get_main_text_draw_font("계속") == main_brush_font, "phase 2 Korean primary label should use the prewarmed brush SystemFont")
	_expect(registry.pause_menu._should_show_main_local_label(), "Korean pause menu should keep the small local label")
	var main_selection_rect: Rect2 = registry.pause_menu._get_selection_feedback_rect(main_panel_rect, "main", 0)
	_expect(main_selection_rect.position.x == 0.0 and main_selection_rect.size.x >= owner.get_viewport_rect().size.x * 0.55, "main selection hit zone should be the left-edge editorial band")
	_expect(registry.pause_menu._get_button_rect(main_panel_rect, 0, entries.size()) == main_selection_rect, "main button hit zone should match the selection feedback band")
	var selected_bar_rect: Rect2 = registry.pause_menu._get_main_selection_bar_rect(main_selection_rect)
	var selected_primary_text: String = registry.pause_menu._get_main_primary_label_text(entries[0])
	var selected_primary_font: Font = registry.pause_menu._get_main_text_draw_font(selected_primary_text)
	var selected_primary_size: int = registry.pause_menu._get_main_entry_selected_font_size(selected_bar_rect)
	var selected_primary_width: float = selected_primary_font.get_string_size(selected_primary_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, selected_primary_size).x
	var selected_local_text := registry.pause_menu._get_main_selected_local_text(entries[0])
	var selected_local_font: Font = registry.pause_menu._get_text_draw_font(registry.pause_menu._get_ui_font(), selected_local_text)
	var selected_local_size: int = registry.pause_menu._get_main_entry_local_font_size(selected_bar_rect)
	var selected_local_width: float = selected_local_font.get_string_size(selected_local_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, selected_local_size).x
	var selected_local_x: float = registry.pause_menu._get_main_selected_local_x(selected_bar_rect, selected_local_width)
	var selected_primary_x: float = registry.pause_menu._get_main_selected_en_x(selected_bar_rect, selected_primary_width, selected_local_x)
	var wider_primary_x: float = registry.pause_menu._get_main_selected_en_x(selected_bar_rect, selected_primary_width * 1.8, selected_local_x)
	_expect(selected_primary_x < selected_bar_rect.position.x + 270.0, "phase 5 scroll should retire the oversized fixed 270px selected-label padding")
	_expect(wider_primary_x < selected_primary_x, "phase 5 scroll should place the selected primary label from its measured width rather than a fixed left pad")
	_expect(selected_primary_x < selected_bar_rect.get_center().x, "phase 2 selected primary label should sit left of the bar center")
	_expect(selected_local_text == "게임으로 돌아가기" and selected_local_x > selected_primary_x + selected_primary_width + 20.0, "phase 2 Korean description should remain the small right-aligned helper without overlapping the primary label")
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
	_expect(registry.pause_menu._get_main_primary_label_text(english_entries[0]) == "RESUME" and registry.pause_menu._get_main_title_text() == "Paused", "phase 2 English pause menu should preserve the editorial EN label while reusing pause.title and hiding the helper")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_CHINESE)
	var chinese_entries: Array = registry.pause_menu._get_main_entries()
	_expect(str(chinese_entries[0].get("desc", "")) == "返回游戏" and registry.pause_menu._get_main_selected_local_text(chinese_entries[0]) == "返回游戏", "D3 pause menu should show the desc key for non-English locales")
	var chinese_primary_text: String = registry.pause_menu._get_main_primary_label_text(chinese_entries[0])
	_expect(chinese_primary_text == "继续" and registry.pause_menu._get_main_title_text() == "暂停", "phase 2 Chinese pause menu should promote the localized label and reuse pause.title")
	_expect(registry.pause_menu._get_main_text_draw_font(chinese_primary_text) != main_brush_font, "phase 2 Chinese primary label should take the production CJK fallback-font route before brush resolution")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_JAPANESE)
	var japanese_entries: Array = registry.pause_menu._get_main_entries()
	var japanese_primary_text: String = registry.pause_menu._get_main_primary_label_text(japanese_entries[0])
	_expect(japanese_primary_text == "続ける" and registry.pause_menu._get_main_title_text() == "一時停止", "phase 2 Japanese pause menu should promote the localized label and reuse pause.title")
	_expect(registry.pause_menu._get_main_text_draw_font(japanese_primary_text) != main_brush_font, "phase 2 Japanese primary label should take the production CJK fallback-font route before brush resolution")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_SPANISH)
	var spanish_entries: Array = registry.pause_menu._get_main_entries()
	_expect(registry.pause_menu._should_show_main_local_label() and registry.pause_menu._get_main_primary_label_text(spanish_entries[0]) == "Continuar" and registry.pause_menu._get_main_title_text() == "Pausa", "phase 2 Spanish pause menu should follow the same non-English label and pause.title contract")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL)
	var portuguese_entries: Array = registry.pause_menu._get_main_entries()
	_expect(registry.pause_menu._should_show_main_local_label() and registry.pause_menu._get_main_primary_label_text(portuguese_entries[0]) == "Continuar" and registry.pause_menu._get_main_title_text() == "Pausa", "phase 2 Brazilian Portuguese pause menu should follow the same non-English label and pause.title contract")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_RUSSIAN)
	var russian_entries: Array = registry.pause_menu._get_main_entries()
	_expect(registry.pause_menu._should_show_main_local_label() and registry.pause_menu._get_main_primary_label_text(russian_entries[0]) == "Продолжить" and registry.pause_menu._get_main_title_text() == "Пауза", "phase 2 Russian pause menu should follow the same non-English label and pause.title contract")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_expect(registry.pause_menu._get_main_title_left_margin(main_panel_rect) <= 16.0, "bright pause title should sit near the top-left reference edge")
	_expect(registry.pause_menu._get_main_diamond_center_x(main_panel_rect) >= owner.get_viewport_rect().size.x * 0.18, "bright pause menu list spine should live inside the editorial list, not on the old left card margin")
	registry.pause_menu.update(0.20)
	_expect(registry.pause_menu._main_dial_time > 0.0, "bright pause menu dial timer should advance while paused")
	_expect(is_equal_approx(registry.pause_menu.MAIN_DIAL_ROTATIONS_PER_SECOND, 0.075), "phase 4 yundo should preserve the approved 0.075 rotations-per-second cadence")
	var compact_panel_rect: Rect2 = registry.pause_menu._get_main_panel_rect(Vector2(360.0, 640.0))
	_expect(compact_panel_rect.position == Vector2.ZERO and compact_panel_rect.size == Vector2(360.0, 640.0), "narrow pause menu should stay on the full-view editorial surface")
	var compact_yundo_center: Vector2 = registry.pause_menu._get_main_yundo_center(compact_panel_rect)
	var compact_yundo_radius: float = registry.pause_menu._get_main_yundo_radius(compact_panel_rect)
	var compact_yundo_outer_radius := compact_yundo_radius * PauseMenuMainRenderer.YUNDO_SPIRIT_ARC_RADIUS_SCALE
	_expect(
		compact_yundo_center.x - compact_yundo_outer_radius >= compact_panel_rect.position.x
		and compact_yundo_center.x + compact_yundo_outer_radius <= compact_panel_rect.end.x
		and compact_yundo_center.y - compact_yundo_outer_radius >= compact_panel_rect.position.y
		and compact_yundo_center.y + compact_yundo_outer_radius <= compact_panel_rect.end.y,
		"phase 5 yundo seal should cover the true outer spirit-arc radius in the 360x640 viewport"
	)
	var compact_entries: Array = registry.pause_menu._get_main_entries()
	var compact_character_selection_rect: Rect2 = registry.pause_menu._get_selection_feedback_rect(compact_panel_rect, "main", 1)
	var compact_character_bar_rect: Rect2 = registry.pause_menu._get_main_selection_bar_rect(compact_character_selection_rect)
	var default_scroll_cap_half_width: float = registry.pause_menu._get_main_scroll_cap_half_width(selected_bar_rect)
	var compact_scroll_cap_half_width: float = registry.pause_menu._get_main_scroll_cap_half_width(compact_character_bar_rect)
	_expect(compact_scroll_cap_half_width < default_scroll_cap_half_width, "phase 5 scroll axis caps should scale down with the 360x640 bar width")
	var compact_character_text: String = registry.pause_menu._get_main_primary_label_text(compact_entries[1])
	var compact_character_font: Font = registry.pause_menu._get_main_text_draw_font(compact_character_text)
	var compact_preferred_character_size: int = registry.pause_menu._get_main_entry_selected_font_size(compact_character_bar_rect)
	var compact_preferred_character_width: float = compact_character_font.get_string_size(compact_character_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, compact_preferred_character_size).x
	var compact_character_size: int = registry.pause_menu._get_main_selected_primary_font_size(compact_character_text, compact_character_bar_rect)
	var compact_character_width: float = compact_character_font.get_string_size(compact_character_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, compact_character_size).x
	var compact_character_helper: String = registry.pause_menu._get_main_selected_local_text(compact_entries[1])
	var compact_helper_font: Font = registry.pause_menu._get_text_draw_font(registry.pause_menu._get_ui_font(), compact_character_helper)
	var compact_helper_size: int = registry.pause_menu._get_main_entry_local_font_size(compact_character_bar_rect)
	var compact_helper_width: float = compact_helper_font.get_string_size(compact_character_helper, HORIZONTAL_ALIGNMENT_LEFT, -1.0, compact_helper_size).x
	var compact_helper_x: float = registry.pause_menu._get_main_selected_local_x(compact_character_bar_rect, compact_helper_width)
	var compact_scroll_side_inset := compact_scroll_cap_half_width * 2.0 + 12.0
	var compact_min_x := compact_character_bar_rect.position.x + minf(compact_scroll_side_inset, maxf(0.0, compact_character_bar_rect.size.x - compact_preferred_character_width))
	var compact_max_x := compact_character_bar_rect.end.x - compact_preferred_character_width - compact_scroll_side_inset
	var compact_preferred_character_x: float = registry.pause_menu._get_main_selected_en_x(compact_character_bar_rect, compact_preferred_character_width, compact_helper_x)
	var compact_character_x: float = registry.pause_menu._get_main_selected_en_x(compact_character_bar_rect, compact_character_width, compact_helper_x)
	_expect(compact_max_x < compact_min_x, "phase 2 360x640 Korean 캐릭터정보 should exercise the selected-text max/min inversion branch")
	_expect(is_equal_approx(compact_preferred_character_x, compact_character_bar_rect.position.x + 8.0), "phase 2 compact unfitted-label fixture should keep the max/min inversion fallback sealed")
	_expect(
		compact_character_x >= compact_character_bar_rect.position.x + compact_scroll_cap_half_width * 2.0 + 12.0,
		"phase 5 fitted compact selected text should clear the scaled scroll axis cap"
	)
	var compact_language_specs := [
		{"language": LanguageSettings.LANGUAGE_KOREAN, "primary": "캐릭터정보"},
		{"language": LanguageSettings.LANGUAGE_ENGLISH, "primary": "STATUS"},
		{"language": LanguageSettings.LANGUAGE_CHINESE, "primary": "角色信息"},
		{"language": LanguageSettings.LANGUAGE_JAPANESE, "primary": "キャラクター情報"},
		{"language": LanguageSettings.LANGUAGE_SPANISH, "primary": "Info de personaje"},
		{"language": LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL, "primary": "Info do personagem"},
		{"language": LanguageSettings.LANGUAGE_RUSSIAN, "primary": "Персонаж"},
	]
	for compact_language_spec in compact_language_specs:
		LanguageSettings.set_language(str(compact_language_spec["language"]))
		var localized_compact_entries: Array = registry.pause_menu._get_main_entries()
		var localized_primary_text: String = registry.pause_menu._get_main_primary_label_text(localized_compact_entries[1])
		_expect(localized_primary_text == str(compact_language_spec["primary"]), "phase 2 compact primary-label fixture should match the active locale")
		var localized_primary_font: Font = registry.pause_menu._get_main_text_draw_font(localized_primary_text)
		var localized_primary_size: int = registry.pause_menu._get_main_selected_primary_font_size(localized_primary_text, compact_character_bar_rect)
		var localized_primary_width: float = localized_primary_font.get_string_size(localized_primary_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, localized_primary_size).x
		_expect(localized_primary_width <= compact_character_bar_rect.size.x - 16.0, "phase 2 compact primary label should fit inside the selected bar for %s" % compact_language_spec["language"])
		var localized_helper_text: String = registry.pause_menu._get_main_selected_local_text(localized_compact_entries[1])
		if not localized_helper_text.is_empty():
			var localized_helper_font: Font = registry.pause_menu._get_text_draw_font(registry.pause_menu._get_ui_font(), localized_helper_text)
			var localized_helper_size: int = registry.pause_menu._get_main_selected_helper_font_size(localized_helper_text, compact_character_bar_rect)
			var localized_helper_width: float = localized_helper_font.get_string_size(localized_helper_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, localized_helper_size).x
			_expect(localized_helper_width <= compact_character_bar_rect.size.x - 16.0, "phase 2 compact helper should fit inside the selected bar for %s" % compact_language_spec["language"])
		var compact_unselected_x: float = registry.pause_menu._get_main_unselected_text_x(compact_panel_rect)
		for localized_entry in localized_compact_entries:
			var localized_unselected_text: String = registry.pause_menu._get_main_primary_label_text(localized_entry)
			var localized_unselected_font: Font = registry.pause_menu._get_main_text_draw_font(localized_unselected_text)
			var localized_unselected_size: int = registry.pause_menu._get_main_unselected_primary_font_size(localized_unselected_text, compact_panel_rect)
			var localized_unselected_width: float = localized_unselected_font.get_string_size(localized_unselected_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, localized_unselected_size).x
			_expect(localized_unselected_width <= compact_panel_rect.end.x - compact_unselected_x - 8.0, "phase 2 compact unselected label should fit inside the view for %s" % compact_language_spec["language"])
	var title_language_specs := [
		LanguageSettings.LANGUAGE_KOREAN,
		LanguageSettings.LANGUAGE_ENGLISH,
		LanguageSettings.LANGUAGE_CHINESE,
		LanguageSettings.LANGUAGE_JAPANESE,
		LanguageSettings.LANGUAGE_SPANISH,
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL,
		LanguageSettings.LANGUAGE_RUSSIAN,
	]
	for title_panel_rect in [main_panel_rect, compact_panel_rect]:
		for title_language in title_language_specs:
			LanguageSettings.set_language(title_language)
			var localized_title: String = registry.pause_menu._get_main_title_text()
			var localized_title_font: Font = registry.pause_menu._get_main_text_draw_font(localized_title)
			var localized_title_size: int = registry.pause_menu._get_main_title_font_size(title_panel_rect)
			var localized_title_width: float = localized_title_font.get_string_size(localized_title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, localized_title_size).x
			_expect(
				localized_title_width <= registry.pause_menu._get_main_title_max_width(title_panel_rect),
				"phase 3 pause title should fit inside the soft ink-wash header for %s at %s" % [title_language, title_panel_rect.size]
			)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	var pause_source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_overlay.gd")
	var main_renderer_source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_main_renderer.gd")
	var options_renderer_source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_options_renderer.gd")
	_expect(pause_source.find("const PauseMenuMainRenderer") >= 0 and pause_source.find("_main_renderer.draw_menu(") >= 0, "pause overlay should delegate the editorial main surface to its renderer owner")
	_expect(main_renderer_source.find("draw_set_transform") < 0, "bright pause menu dial should avoid texture-quad transform rotation")
	_expect(pause_source.find("_draw_ringcore_crystal") < 0, "bright pause main should not draw the preserved ringcore crystal asset")
	_expect(main_renderer_source.find("MAIN_SELECTED_BAR_SKEW") < 0 and main_renderer_source.find("draw_scroll_banner") >= 0, "phase 5 pause main should retire the skewed cyberpunk bar for a procedural scroll banner")
	_expect(main_renderer_source.find("draw_scroll_axis_cap") >= 0 and main_renderer_source.find("draw_hanji_edge") >= 0, "phase 5 scroll should keep scaled axis caps and irregular hanji edges as named shape contracts")
	_expect(main_renderer_source.find("draw_knot_marker") >= 0 and main_renderer_source.find("draw_title_seal") >= 0, "phase 5 pause chrome should replace sparkle diamonds with knots and keep only the approved title seal")
	_expect(main_renderer_source.find("OPEN_BAR_SWEEP_SECONDS") >= 0 and main_renderer_source.find("OPEN_ITEM_STAGGER_SECONDS") >= 0, "pause menu should keep explicit opening animation timing constants")
	_expect(main_renderer_source.find("ProjectResourceLoader.load_texture(\n\t\tMAIN_EDITORIAL_BG_PATH") >= 0, "D2 pause renderer should load the editorial background through the project resource loader")
	var editorial_base_body := _source_function_body(main_renderer_source, "func draw_editorial_base")
	_expect(editorial_base_body.find("draw_texture_rect_region") >= 0 and editorial_base_body.find("draw_texture_rect(background_texture") < 0, "phase 4 pause background should use a source-region cover fit instead of aspect-distorting stretch")
	var cover_region_body := _source_function_body(main_renderer_source, "func get_background_cover_region")
	_expect(cover_region_body.find("destination_aspect > source_aspect") >= 0 and cover_region_body.find("Rect2(0.0, 0.0, cropped_width") >= 0, "phase 4 cover fit should center vertical crops and left-align horizontal crops")
	var background_body := _source_function_body(main_renderer_source, "func draw_editorial_background")
	_expect(background_body.find("draw_editorial_base(canvas, panel_rect, base_alpha)") >= 0, "D2 pause renderer should draw the editorial background art as the first main-menu layer")
	_expect(background_body.find("draw_ink_wash_header(canvas, panel_rect, chrome_alpha)") >= 0, "phase 3 pause chrome should replace the sharp cyberpunk wedge with the ink-wash header")
	_expect(background_body.find("wedge_width") < 0, "phase 3 pause chrome should retire the hard straight-edged wedge")
	_expect(background_body.find("_draw_main_map_texture") < 0, "D2 pause menu should not draw the old procedural map texture in the normal background path")
	_expect(background_body.find("panel_rect.size.y * 1.06") < 0, "D2 pause menu should remove the duplicate procedural sweeping arc over the background art")
	var ink_wash_body := _source_function_body(main_renderer_source, "func draw_ink_wash_header")
	_expect(ink_wash_body.find("ink_wash_curve") >= 0 and ink_wash_body.find("draw_colored_polygon") >= 0, "phase 3 ink-wash header should keep a curved procedural silhouette without adding another texture")
	var editorial_dial_body := _source_function_body(main_renderer_source, "func draw_editorial_dial")
	_expect(main_renderer_source.find("star_blades") < 0, "phase 4 yundo should retire the cyberpunk four-blade compass star")
	_expect(editorial_dial_body.find("yundo_rings") >= 0 and editorial_dial_body.find("needle_blades") >= 0, "phase 4 yundo should draw concentric rings and a two-blade needle procedurally")
	_expect(editorial_dial_body.find("SPIRIT_BLUE") >= 0 and editorial_dial_body.find("SEAL_RED") >= 0, "phase 4 yundo should make the reserved spirit-blue and seal-red tokens visible on the normal draw path")
	_expect(PauseMenuMainRenderer.YUNDO_RING_RADII.size() >= 3 and PauseMenuMainRenderer.YUNDO_RING_RADII.size() <= 4, "phase 4 yundo should keep the approved three-to-four concentric-ring silhouette")
	_expect(PauseMenuMainRenderer.YUNDO_OUTER_TICK_COUNT + PauseMenuMainRenderer.YUNDO_INNER_TICK_COUNT <= 36, "phase 4 yundo should cap its procedural tick budget")
	_expect(is_equal_approx(PauseMenuMainRenderer.SCROLL_SPIRIT_HAIRLINE_ALPHA, 0.58), "phase 5 scroll should keep the selected subtle spirit-blue hairline from the Forward+ A/B review")
	var main_menu_body := _source_function_body(main_renderer_source, "func draw_menu")
	_expect(main_menu_body.find("get_main_open_bar_ratio(animation_time)") >= 0 and main_menu_body.find("get_main_open_entry_ratio(animation_time, index)") >= 0, "pause menu opening should feed bar sweep and entry cascade ratios into the main renderer")
	var selected_bar_body := _source_function_body(main_renderer_source, "func draw_selected_bar")
	_expect(selected_bar_body.find("final_bar_rect.size.x * clampf(open_ratio") >= 0 and selected_bar_body.find("_with_alpha(Color.WHITE, draw_text_alpha)") >= 0, "pause menu selected bar should sweep in before fading its text")
	_expect(selected_bar_body.find("draw_scroll_banner(canvas, bar_rect") >= 0, "phase 5 selected-bar sweep should feed the live swept rect to the scroll and its moving end cap")
	_expect(selected_bar_body.find("final_bar_rect.end.y - STACKED_HELPER_BOTTOM_INSET") >= 0 and main_renderer_source.find("STACKED_HELPER_BOTTOM_INSET := 14.0") >= 0, "phase 5 compact stacked helper should keep 14px clear of the scroll's lower edge")
	var scroll_banner_body := _source_function_body(main_renderer_source, "func draw_scroll_banner")
	_expect(scroll_banner_body.find("left_axis_x := bar_rect.position.x + cap_half_width") >= 0, "phase 5 left scroll axis should stay one cap-half-width inside the unchanged x=0 hit rect")
	_expect(scroll_banner_body.find("right_axis_x := bar_rect.end.x - cap_half_width") >= 0, "phase 5 scroll right axis should follow the live swept bar end")
	_expect(scroll_banner_body.find("SCROLL_SPIRIT_HAIRLINE_ALPHA") >= 0, "phase 5 scroll should keep the reviewed spirit-blue hairline as an explicit A/B decision")
	var hanji_fibers_body := _source_function_body(main_renderer_source, "func draw_hanji_fibers")
	_expect(main_renderer_source.find("HANJI_FIBER_COUNT := 3") >= 0, "phase 5 hanji correction should not increase the existing three-line draw budget")
	_expect(hanji_fibers_body.find("fiber_x") >= 0 and hanji_fibers_body.find("Vector2(fiber_x, fiber_top)") >= 0 and hanji_fibers_body.find("fiber_specs") < 0, "phase 5 hanji fibers should run vertically and evenly across the scroll instead of crossing text baselines")
	_expect(selected_bar_body.find("get_primary_label_text(entry)") >= 0 and selected_bar_body.find("entry.get(\"en\"") < 0, "phase 2 selected bar should draw the locale-aware primary label instead of reading EN directly")
	_expect(selected_bar_body.find("helper_fits_inline") >= 0 and selected_bar_body.find("stacked_helper_pos") >= 0, "phase 2 narrow pause menu should stack the helper inside the selected bar instead of dropping it")
	var primary_label_body := _source_function_body(main_renderer_source, "func get_primary_label_text")
	_expect(primary_label_body.find("should_show_local_label()") >= 0 and primary_label_body.find("LanguageSettings.get_language()") < 0, "phase 2 primary-label routing should reuse the sealed English-vs-all-other-languages predicate")
	var title_text_body := _source_function_body(main_renderer_source, "func get_title_text")
	_expect(title_text_body.find("LanguageSettings.translate(\"pause.title\"") >= 0 and title_text_body.find("match LanguageSettings") < 0, "phase 2 pause title should reuse the complete seven-language pause.title key without a local language list")
	var title_size_body := _source_function_body(main_renderer_source, "func get_title_font_size")
	_expect(title_size_body.find("_get_fitted_font_size") >= 0 and title_size_body.find("get_title_max_width") >= 0, "phase 3 pause title should reuse the fitted-font path instead of crossing the ink-wash edge")
	var text_font_body := _source_function_body(main_renderer_source, "func _get_text_draw_font")
	_expect(text_font_body.find("_needs_cjk_fallback_font(text)") < text_font_body.find("get_main_brush_font(font)"), "phase 2 main text font routing should resolve CJK fallback before selecting the brush SystemFont")
	var unselected_entry_body := _source_function_body(main_renderer_source, "func draw_unselected_entry")
	_expect(unselected_entry_body.find("OPEN_ITEM_SLIDE_X") >= 0 and unselected_entry_body.find("_with_alpha(color, open_ratio)") >= 0, "pause menu unselected entries should slide/fade in during opening")
	_expect(unselected_entry_body.find("get_primary_label_text(entry)") >= 0 and unselected_entry_body.find("entry.get(\"en\"") < 0, "phase 2 unselected entries should draw the locale-aware primary label instead of reading EN directly")
	_expect(selected_bar_body.find("draw_title_seal") < 0 and unselected_entry_body.find("draw_title_seal") < 0, "phase 5 should keep the approved title-only seal instead of stamping every menu item")
	# --- Phase 6 Hwangyeokjeon options surface seals ---
	_expect(registry.pause_menu.PANEL_COLOR.is_equal_approx(Color(0.070, 0.055, 0.045, 0.92)), "phase 6 compatibility panel should use the warm lacquer surface")
	_expect(registry.pause_menu.HEADER_COLOR.is_equal_approx(Color(0.090, 0.070, 0.045, 0.94)), "phase 6 compatibility header should use the warm ink-brown surface")
	_expect(registry.pause_menu.SECTION_COLOR.is_equal_approx(Color(0.045, 0.036, 0.030, 0.55)), "phase 6 compatibility section should use the warm deepest surface")
	_expect(registry.pause_menu.BUTTON_COLOR.is_equal_approx(Color(0.080, 0.062, 0.044, 0.90)), "phase 6 compatibility button should use the warm dark-wood surface")
	_expect(registry.pause_menu.SLIDER_BACK.is_equal_approx(Color(0.055, 0.044, 0.036)), "phase 6 compatibility slider track should use warm near-black ink")
	_expect(registry.pause_menu.OPT_PANEL == registry.pause_menu.PANEL_COLOR, "phase 6 live options panel should link to the warm compatibility panel token")
	_expect(registry.pause_menu.OPT_HEADER == registry.pause_menu.HEADER_COLOR, "phase 6 live options header should link to the warm compatibility header token")
	_expect(registry.pause_menu.OPT_CARD.is_equal_approx(Color(0.082, 0.064, 0.046, 0.95)), "phase 6 option cards should use a warm dark-wood surface")
	_expect(registry.pause_menu.OPT_CARD_HOVER.is_equal_approx(Color(0.100, 0.078, 0.054, 0.98)), "phase 6 hovered option cards should keep a restrained warm lift")
	_expect(registry.pause_menu.OPT_TRACK == registry.pause_menu.SLIDER_BACK, "phase 6 live option track should link to the warm compatibility slider token")
	_expect(registry.pause_menu.OPT_BORDER.is_equal_approx(Color(0.62, 0.52, 0.30, 0.34)), "phase 6 option borders should use the approved translucent aged-gilt token")
	var warm_option_surfaces: Array[Color] = [
		registry.pause_menu.OPT_PANEL,
		registry.pause_menu.OPT_HEADER,
		registry.pause_menu.OPT_CARD,
		registry.pause_menu.OPT_CARD_HOVER,
		registry.pause_menu.OPT_TRACK,
	]
	for warm_surface in warm_option_surfaces:
		_expect(warm_surface.r > warm_surface.b and warm_surface.r <= 0.1001, "phase 6 option surfaces should stay warm and dark instead of returning to navy")
	var draw_body := _source_function_body(pause_source, "func draw(")
	_expect(draw_body.find("_draw_main_editorial_base(canvas, Rect2(Vector2.ZERO, view_size), _get_open_bg_alpha())") >= 0, "D-options should draw the shared bright editorial base instead of the dark dim panel")
	_expect(draw_body.find("0.0, 0.0, 0.0, 0.58") < 0, "D-options should not draw the old black dim behind the options panel")
	_expect(draw_body.find("OPT_PANEL") >= 0, "phase 6 options should draw the warm content panel token")
	_expect(draw_body.find("OPEN_OPTIONS_SLIDE_Y") >= 0 and draw_body.find("_get_options_open_ratio()") >= 0, "D-options should share the opening fade/slide timing")
	_expect(draw_body.find("_with_alpha(OPT_PANEL") < 0 and draw_body.find("_with_alpha(OPT_BORDER") < 0, "options panel must slide in solid — alpha-fading only the shell desyncs it from its full-alpha tab/slider content")
	var options_window_body := _source_function_body(options_renderer_source, "func draw_window")
	_expect(options_window_body.find("_draw_scanlines") < 0, "D-options should drop the dark HUD scanlines")
	_expect(options_window_body.find("OPT_SLIDER_BGM_FILL") >= 0 and options_window_body.find("OPT_SLIDER_SFX_FILL") >= 0, "phase 6 shared options window should route both sound sliders through Hwangyeokjeon fill tokens")
	_expect(options_window_body.find("ACCENT_BLUE") < 0 and options_window_body.find("ACCENT_GREEN") < 0, "phase 6 sound sliders should retire the cyan and fluorescent-green fill routes")
	_expect(options_renderer_source.find("const OPT_SLIDER_BGM_FILL := SPIRIT_BLUE") >= 0 and options_renderer_source.find("const OPT_SLIDER_SFX_FILL := RuntimePerkTraditionalChrome.JADE") >= 0, "phase 6 slider palette should stay linked to the live spirit-blue and canonical jade owners")
	var opt_button_body := _source_function_body(options_renderer_source, "func draw_button")
	_expect(opt_button_body.find("OPT_CARD") >= 0 and opt_button_body.find("SELECT_BLUE") >= 0 and opt_button_body.find("BUTTON_COLOR") < 0, "D-options buttons should use bright tokens, not the dark button fill")
	var opt_tab_body := _source_function_body(options_renderer_source, "func draw_tab(")
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
