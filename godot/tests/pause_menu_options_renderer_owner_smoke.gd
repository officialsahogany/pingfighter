extends SceneTree

const PauseMenuOverlay := preload("res://scripts/hud/pause_menu_overlay.gd")
const PauseMenuOptionsRenderer := preload("res://scripts/hud/pause_menu_options_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_compatibility_tokens()
	_verify_render_snapshot_contract()
	_verify_facade_delegation_contract()
	_verify_renderer_owns_visual_formulas()

	if _failures.is_empty():
		print("pause_menu_options_renderer_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_compatibility_tokens() -> void:
	_expect(
		PauseMenuOverlay.PANEL_COLOR == PauseMenuOptionsRenderer.PANEL_COLOR,
		"the facade should preserve the renderer-owned panel token"
	)
	_expect(
		PauseMenuOverlay.OPT_CARD == PauseMenuOptionsRenderer.OPT_CARD,
		"the facade should preserve the renderer-owned option-card token"
	)
	_expect(
		PauseMenuOverlay.NEON_CYAN == PauseMenuOptionsRenderer.NEON_CYAN,
		"the facade should preserve the renderer-owned neon-line token"
	)
	var value_rect := Rect2(30.0, 40.0, 120.0, 28.0)
	_expect(
		PauseMenuOverlay.new()._get_select_chevron_rects(value_rect) == PauseMenuOptionsRenderer.get_select_chevron_rects(value_rect),
		"the compatibility chevron helper should preserve renderer geometry"
	)


func _verify_render_snapshot_contract() -> void:
	var overlay := PauseMenuOverlay.new()
	overlay.options_tab = PauseMenuOverlay.OPTIONS_TAB_DISPLAY
	overlay.options_focus = 4
	var snapshot: Dictionary = overlay._build_options_render_snapshot(null)
	_expect(str(snapshot.get("options_tab", "")) == PauseMenuOverlay.OPTIONS_TAB_DISPLAY, "the render snapshot should preserve the active tab")
	_expect(int(snapshot.get("options_focus", -1)) == 4, "the render snapshot should preserve the active focus")
	_expect(snapshot.has("display_mode") and snapshot.has("render_fps_value") and snapshot.has("vsync_value"), "the render snapshot should include resolved display values")
	_expect(snapshot.has("control_mapping_rows") and not Array(snapshot["control_mapping_rows"]).is_empty(), "the render snapshot should include projected control rows")
	_expect(snapshot.has("language_options") and Array(snapshot["language_options"]).size() == 7, "the render snapshot should include all seven language choices")
	_expect(not str(snapshot.get("current_language_label", "")).is_empty(), "the render snapshot should include the resolved current-language label")
	var pulse_alpha := float(snapshot.get("focus_pulse_alpha", -1.0))
	_expect(pulse_alpha >= 0.0 and pulse_alpha <= 1.0, "the render snapshot focus pulse should stay normalized")


func _verify_facade_delegation_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_overlay.gd")
	_expect(
		source.contains("const PauseMenuOptionsRenderer := preload(\"res://scripts/hud/pause_menu_options_renderer.gd\")"),
		"the pause-menu facade should preload the options renderer owner"
	)
	_expect(source.contains("var _options_renderer := PauseMenuOptionsRenderer.new()"), "the facade should keep one options renderer instance")
	_expect(source.contains("func _build_options_render_snapshot("), "the facade should project localized option state into one render snapshot")
	var delegations := {
		"_draw_options_window": "_options_renderer.draw_window",
		"_draw_options_header": "_options_renderer.draw_options_header",
		"_draw_tab": "_options_renderer.draw_tab",
		"_draw_tab_icon": "_options_renderer.draw_tab_icon",
		"_draw_scanlines": "_options_renderer.draw_scanlines",
		"_draw_volume_slider": "_options_renderer.draw_volume_slider",
		"_draw_display_tab": "_options_renderer.draw_display_tab",
		"_draw_controls_tab": "_options_renderer.draw_controls_tab",
		"_draw_language_tab": "_options_renderer.draw_language_tab",
		"_draw_control_mapping_row": "_options_renderer.draw_control_mapping_row",
		"_draw_mode_pill": "_options_renderer.draw_mode_pill",
		"_draw_setting_select_row": "_options_renderer.draw_setting_select_row",
		"_draw_toggle_setting_row": "_options_renderer.draw_toggle_setting_row",
		"_draw_button": "_options_renderer.draw_button",
		"_draw_recommendation_block": "_options_renderer.draw_recommendation_block",
		"_draw_hud_readout_bar": "_options_renderer.draw_hud_readout_bar",
		"_get_select_chevron_rects": "PauseMenuOptionsRenderer.get_select_chevron_rects",
		"_draw_toggle_leader": "_options_renderer.draw_toggle_leader",
		"_draw_panel": "_options_renderer.draw_panel",
		"_draw_neon_line": "_options_renderer.draw_neon_line",
		"_draw_holo_focus_frame": "_options_renderer.draw_holo_focus_frame",
	}
	for function_name: String in delegations:
		var body := _source_function_body(source, "func %s(" % function_name)
		_expect(
			body.contains(str(delegations[function_name])),
			"%s should delegate presentation to the options renderer" % function_name
		)


func _verify_renderer_owns_visual_formulas() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_options_renderer.gd")
	_expect(not source.contains("registry") and not source.contains("LanguageSettings"), "the renderer should depend only on its projected snapshot")
	var button_body := _source_function_body(source, "func draw_button(")
	_expect(button_body.contains("OPT_CARD") and button_body.contains("SELECT_BLUE"), "the renderer should own option-button palette selection")
	var tab_body := _source_function_body(source, "func draw_tab(")
	_expect(tab_body.contains("draw_tab_icon") and tab_body.contains("SELECT_BLUE"), "the renderer should own option-tab composition")
	var select_body := _source_function_body(source, "func draw_setting_select_row(")
	_expect(select_body.contains("get_select_chevron_rects") and select_body.contains("draw_holo_focus_frame"), "the renderer should own select-row composition")
	var panel_body := _source_function_body(source, "func draw_panel(")
	_expect(panel_body.contains("PremiumPanelFrame.draw_panel"), "the renderer should own option frame projection")
	var window_body := _source_function_body(source, "func draw_window(")
	_expect(window_body.contains("draw_display_tab") and window_body.contains("OPT_SLIDER_BGM_FILL"), "the renderer should own high-level option-tab composition")
	var display_body := _source_function_body(source, "func draw_display_tab(")
	_expect(display_body.contains("PauseMenuOverlayLayout.get_display_fps_cap_row_rect") and display_body.contains("draw_toggle_setting_row"), "the renderer should own display-tab composition")
	var controls_body := _source_function_body(source, "func draw_controls_tab(")
	_expect(controls_body.contains("PauseMenuOverlayLayout.get_controls_mapping_row_rect") and controls_body.contains("draw_control_mapping_row"), "the renderer should own controls-tab composition")
	var language_body := _source_function_body(source, "func draw_language_tab(")
	_expect(language_body.contains("PauseMenuOverlayLayout.get_language_korean_rect") and language_body.contains("language_options"), "the renderer should own language-tab composition")


func _source_function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + signature.length())
	if next < 0:
		return source.substr(start)
	return source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
