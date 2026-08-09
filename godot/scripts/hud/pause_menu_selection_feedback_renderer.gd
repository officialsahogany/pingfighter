extends RefCounted

const PauseMenuOptionsNavigationPolicy := preload("res://scripts/hud/pause_menu_options_navigation_policy.gd")
const PauseMenuOptionsRenderer := preload("res://scripts/hud/pause_menu_options_renderer.gd")
const PauseMenuOverlayLayout := preload("res://scripts/hud/pause_menu_overlay_layout.gd")
const PauseMenuSelectionFeedbackState := preload("res://scripts/hud/pause_menu_selection_feedback_state.gd")
const PremiumPanelFrame := preload("res://scripts/hud/premium_panel_frame.gd")

const SELECTION_SCOPE_MAIN := "main"
const OPTIONS_TAB_SOUND := PauseMenuOptionsNavigationPolicy.TAB_SOUND
const OPTIONS_TAB_DISPLAY := PauseMenuOptionsNavigationPolicy.TAB_DISPLAY
const OPTIONS_TAB_CONTROLS := PauseMenuOptionsNavigationPolicy.TAB_CONTROLS
const OPTIONS_TAB_LANGUAGE := PauseMenuOptionsNavigationPolicy.TAB_LANGUAGE
const CONTROL_DEVICE_KEYBOARD_MOUSE := PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE
const CONTROL_DEVICE_JOYPAD := PauseMenuOptionsNavigationPolicy.DEVICE_JOYPAD
const SELECT_BLUE := PauseMenuOptionsRenderer.SELECT_BLUE

var _options_renderer := PauseMenuOptionsRenderer.new()


func draw(
	canvas: CanvasItem,
	panel_rect: Rect2,
	scope: String,
	current_index: int,
	state: PauseMenuSelectionFeedbackState,
	main_entry_count: int,
	focus_pulse_alpha: float
) -> void:
	if scope == SELECTION_SCOPE_MAIN:
		return
	var draw_rect := get_animated_rect(scope, panel_rect, current_index, state, main_entry_count)
	if not has_feedback_rect(draw_rect):
		return
	var pop_projection := state.build_pop_projection(scope, 0.28)
	var pop_amount := float(pop_projection.get("pop_amount", 0.0))
	var flash_alpha := float(pop_projection.get("flash_alpha", 0.0))
	if pop_amount > 0.0:
		draw_rect = scale_rect_from_center(draw_rect, 1.0 + pop_amount)
	var fill := Color(SELECT_BLUE.r, SELECT_BLUE.g, SELECT_BLUE.b, 0.04 + flash_alpha * 0.42)
	var border := Color(SELECT_BLUE.r, SELECT_BLUE.g, SELECT_BLUE.b, 0.52 + flash_alpha)
	PremiumPanelFrame.draw_panel(canvas, draw_rect, PremiumPanelFrame.KIND_SLOT, fill, border, 1.0)
	_options_renderer.draw_holo_focus_frame(
		canvas,
		draw_rect,
		clampf(focus_pulse_alpha + flash_alpha, 0.0, 1.0)
	)


func get_animated_rect(
	scope: String,
	panel_rect: Rect2,
	current_index: int,
	state: PauseMenuSelectionFeedbackState,
	main_entry_count: int
) -> Rect2:
	var draw_rect := get_feedback_rect(panel_rect, scope, current_index, main_entry_count)
	if not has_feedback_rect(draw_rect):
		return Rect2()
	var slide_projection := state.build_slide_projection(scope)
	if bool(slide_projection.get("active", false)):
		var from_index := int(slide_projection.get("from_index", current_index))
		var to_index := int(slide_projection.get("to_index", current_index))
		var from_rect := get_feedback_rect(panel_rect, scope, from_index, main_entry_count)
		var to_rect := get_feedback_rect(panel_rect, scope, to_index, main_entry_count)
		if has_feedback_rect(from_rect) and has_feedback_rect(to_rect):
			draw_rect = lerp_rect(from_rect, to_rect, float(slide_projection.get("weight", 1.0)))
	return draw_rect


static func get_feedback_rect(panel_rect: Rect2, scope: String, index: int, main_entry_count: int) -> Rect2:
	if scope == SELECTION_SCOPE_MAIN:
		if main_entry_count <= 0:
			return Rect2()
		return PauseMenuOverlayLayout.get_main_row_band_rect(
			panel_rect,
			clampi(index, 0, main_entry_count - 1),
			main_entry_count
		)
	if not scope.begins_with("options:"):
		return Rect2()
	var parts := scope.split(":")
	if parts.size() < 2:
		return Rect2()
	var tab := str(parts[1])
	match tab:
		OPTIONS_TAB_SOUND:
			return get_sound_focus_rect(panel_rect, index)
		OPTIONS_TAB_DISPLAY:
			return get_display_focus_rect(panel_rect, index)
		OPTIONS_TAB_CONTROLS:
			var device := CONTROL_DEVICE_JOYPAD if parts.size() >= 3 and str(parts[2]) == CONTROL_DEVICE_JOYPAD else CONTROL_DEVICE_KEYBOARD_MOUSE
			return get_controls_focus_rect(panel_rect, index, device)
		OPTIONS_TAB_LANGUAGE:
			return get_language_focus_rect(panel_rect, index)
	return Rect2()


static func get_sound_focus_rect(panel_rect: Rect2, index: int) -> Rect2:
	match index:
		0:
			return PauseMenuOverlayLayout.get_slider_hit_rect_from_panel("bgm", panel_rect).grow(3.0)
		1:
			return PauseMenuOverlayLayout.get_slider_hit_rect_from_panel("sfx", panel_rect).grow(3.0)
		2:
			return PauseMenuOverlayLayout.get_back_button_rect(panel_rect)
	return Rect2()


static func get_display_focus_rect(panel_rect: Rect2, index: int) -> Rect2:
	match index:
		0:
			return span_rect(
				PauseMenuOverlayLayout.get_display_fullscreen_rect(panel_rect),
				PauseMenuOverlayLayout.get_display_windowed_rect(panel_rect)
			)
		1:
			return PauseMenuOverlayLayout.get_display_fps_cap_row_rect(panel_rect)
		2:
			return PauseMenuOverlayLayout.get_display_vsync_row_rect(panel_rect)
		3:
			return PauseMenuOverlayLayout.get_display_default_row_rect(panel_rect)
		4:
			return PauseMenuOverlayLayout.get_display_auto_refresh_row_rect(panel_rect)
		5:
			return PauseMenuOverlayLayout.get_display_recommended_button_rect(panel_rect)
		6:
			return PauseMenuOverlayLayout.get_display_apply_60hz_button_rect(panel_rect)
		7:
			return PauseMenuOverlayLayout.get_display_save_button_rect(panel_rect)
		8:
			return PauseMenuOverlayLayout.get_display_back_button_rect(panel_rect)
	return Rect2()


static func get_controls_focus_rect(panel_rect: Rect2, index: int, device: String) -> Rect2:
	match index:
		0:
			return span_rect(
				PauseMenuOverlayLayout.get_controls_keyboard_mouse_rect(panel_rect),
				PauseMenuOverlayLayout.get_controls_joypad_rect(panel_rect)
			)
		1:
			if device == CONTROL_DEVICE_JOYPAD:
				return PauseMenuOverlayLayout.get_controls_vibration_row_rect(panel_rect)
			return PauseMenuOverlayLayout.get_controls_back_button_rect(panel_rect)
		2:
			if device == CONTROL_DEVICE_JOYPAD:
				return PauseMenuOverlayLayout.get_controls_back_button_rect(panel_rect)
	return Rect2()


static func get_language_focus_rect(panel_rect: Rect2, index: int) -> Rect2:
	match index:
		0:
			return PauseMenuOverlayLayout.get_language_korean_rect(panel_rect)
		1:
			return PauseMenuOverlayLayout.get_language_english_rect(panel_rect)
		2:
			return PauseMenuOverlayLayout.get_language_chinese_rect(panel_rect)
		3:
			return PauseMenuOverlayLayout.get_language_japanese_rect(panel_rect)
		4:
			return PauseMenuOverlayLayout.get_language_spanish_rect(panel_rect)
		5:
			return PauseMenuOverlayLayout.get_language_portuguese_brazil_rect(panel_rect)
		6:
			return PauseMenuOverlayLayout.get_language_russian_rect(panel_rect)
		7:
			return PauseMenuOverlayLayout.get_language_back_button_rect(panel_rect)
	return Rect2()


static func span_rect(first_rect: Rect2, last_rect: Rect2) -> Rect2:
	var start := Vector2(
		minf(first_rect.position.x, last_rect.position.x),
		minf(first_rect.position.y, last_rect.position.y)
	)
	var finish := Vector2(
		maxf(first_rect.end.x, last_rect.end.x),
		maxf(first_rect.end.y, last_rect.end.y)
	)
	return Rect2(start, finish - start)


static func lerp_rect(from_rect: Rect2, to_rect: Rect2, weight: float) -> Rect2:
	return Rect2(
		from_rect.position.lerp(to_rect.position, weight),
		from_rect.size.lerp(to_rect.size, weight)
	)


static func scale_rect_from_center(rect: Rect2, scale: float) -> Rect2:
	var scaled_size := rect.size * scale
	return Rect2(rect.get_center() - scaled_size * 0.5, scaled_size)


static func has_feedback_rect(rect: Rect2) -> bool:
	return rect.size.x > 1.0 and rect.size.y > 1.0
