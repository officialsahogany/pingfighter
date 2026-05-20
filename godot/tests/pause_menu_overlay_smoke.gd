extends SceneTree

const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const BattleSceneOverlayInputController := preload("res://scripts/core/battle_scene_overlay_input_controller.gd")
const PauseMenuOverlay := preload("res://scripts/hud/pause_menu_overlay.gd")


class FakeOwner:
	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1

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
		return "144Hz 모니터 감지: Windows 60Hz를 권장합니다.\n게임은 독점 전체화면 + 60 FPS + VSync On이 가장 안정적입니다."

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


class FakeRegistry:
	var modal_gate := BattleSceneModalGateController.new()
	var pause_menu := PauseMenuOverlay.new()
	var character_info := FakeCharacterInfo.new()
	var audio := FakeAudio.new()
	var view_layout := FakeViewLayout.new()

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
		return null


var registry := FakeRegistry.new()


func _init() -> void:
	var input := BattleSceneOverlayInputController.new()
	var owner := FakeOwner.new()

	_expect(_press(input, owner, KEY_ESCAPE), "ESC should open the pause menu")
	_expect(registry.pause_menu.is_active(), "pause menu should become active")
	_expect(registry.modal_gate.should_block_battle_physics(Callable(self, "_get_module")), "pause menu should block battle physics")

	_expect(_press(input, owner, KEY_ESCAPE), "ESC should close the active pause menu")
	_expect(not registry.pause_menu.is_active(), "pause menu should close on second ESC")

	_expect(_press(input, owner, KEY_ESCAPE), "ESC should reopen pause menu for button flow")
	_expect(_click(input, owner, Vector2(640.0, 401.0)), "character info button click should be handled")
	_expect(not registry.pause_menu.is_active(), "character info button should close pause menu")
	_expect(registry.character_info.is_active(), "character info button should open character info overlay")
	registry.character_info.close()

	_expect(_press(input, owner, KEY_ESCAPE), "ESC should reopen pause menu for options")
	_expect(_click(input, owner, Vector2(640.0, 463.0)), "options button click should be handled")
	_expect(registry.pause_menu.is_options_open(), "options button should open the pause options page")
	var bgm_slider: Rect2 = registry.pause_menu._get_slider_rect("bgm", owner.get_viewport_rect().size)
	var sfx_slider: Rect2 = registry.pause_menu._get_slider_rect("sfx", owner.get_viewport_rect().size)
	_expect(_click(input, owner, bgm_slider.position + Vector2(bgm_slider.size.x * 0.25, 3.0)), "BGM slider click should be handled")
	_expect(abs(registry.audio.bgm_volume - 0.25) <= 0.01, "BGM slider should set the runtime BGM volume")
	_expect(_click(input, owner, sfx_slider.position + Vector2(sfx_slider.size.x * 0.85, 3.0)), "SFX slider click should be handled")
	_expect(abs(registry.audio.sfx_volume - 0.85) <= 0.01, "SFX slider should set the runtime SFX volume")
	_expect(_press(input, owner, KEY_DOWN), "options focus should move from SFX to back")
	_expect(_press(input, owner, KEY_ENTER), "back button should be handled")
	_expect(registry.pause_menu.is_active() and not registry.pause_menu.is_options_open(), "back should return to the main pause menu")

	_expect(_click(input, owner, Vector2(640.0, 463.0)), "options button should reopen the pause options page")
	var options_panel: Rect2 = registry.pause_menu._get_options_panel_rect(owner.get_viewport_rect().size)
	_expect(_click(input, owner, registry.pause_menu._get_display_tab_rect(options_panel).get_center()), "display tab click should be handled")
	_expect(registry.pause_menu.is_options_open(), "display tab should keep the options page open")
	_expect(_click(input, owner, registry.pause_menu._get_display_fullscreen_rect(options_panel).get_center()), "fullscreen pill should be handled")
	_expect(_click(input, owner, registry.pause_menu._get_display_exclusive_fullscreen_rect(options_panel).get_center()), "exclusive fullscreen pill should be handled")
	_expect(_click(input, owner, registry.pause_menu._get_display_fps_cap_row_rect(options_panel).get_center()), "render FPS cap row should be handled")
	_expect(_click(input, owner, registry.pause_menu._get_display_vsync_row_rect(options_panel).get_center()), "vsync row should be handled")
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
	_expect(recommended_options.render_fps_cap == 60, "recommended settings should select 60 FPS")
	_expect(recommended_options.vsync_mode == 1, "recommended settings should select VSync On")
	_expect(not recommended_options.auto_refresh_rate_60hz, "recommended settings should not silently enable automatic OS refresh switching")
	_expect(registry.view_layout.display_mode == "exclusive_fullscreen", "recommended settings should apply exclusive fullscreen")
	_expect(registry.view_layout.saved_mode == "exclusive_fullscreen" and registry.view_layout.saved_remember, "recommended settings should persist exclusive fullscreen")
	_expect(registry.view_layout.render_fps_cap == 60 and registry.view_layout.saved_render_fps_cap == 60, "recommended settings should apply and persist 60 FPS")
	_expect(registry.view_layout.vsync_mode == 1 and registry.view_layout.saved_vsync_mode == 1, "recommended settings should apply and persist VSync On")

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

	_expect(owner.redraw_count >= 6, "pause menu input should queue redraws")
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


func _get_module(key: String) -> Object:
	return registry.get_instance(key)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
