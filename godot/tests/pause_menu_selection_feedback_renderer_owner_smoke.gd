extends SceneTree

const PauseMenuOverlay := preload("res://scripts/hud/pause_menu_overlay.gd")
const PauseMenuOverlayLayout := preload("res://scripts/hud/pause_menu_overlay_layout.gd")
const PauseMenuSelectionFeedbackRenderer := preload("res://scripts/hud/pause_menu_selection_feedback_renderer.gd")
const PauseMenuSelectionFeedbackState := preload("res://scripts/hud/pause_menu_selection_feedback_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_geometry_projection()
	_verify_animation_projection()
	_verify_facade_delegation_contract()
	_verify_renderer_ownership_contract()

	if _failures.is_empty():
		print("pause_menu_selection_feedback_renderer_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_geometry_projection() -> void:
	var panel := Rect2(190.0, 110.0, 900.0, 500.0)
	_expect_rect(
		PauseMenuSelectionFeedbackRenderer.get_feedback_rect(panel, "main", 1, 4),
		PauseMenuOverlayLayout.get_main_row_band_rect(panel, 1, 4),
		"main feedback should reuse the shared row band"
	)
	_expect_rect(
		PauseMenuSelectionFeedbackRenderer.get_feedback_rect(panel, "options:sound", 0, 4),
		PauseMenuOverlayLayout.get_slider_hit_rect_from_panel("bgm", panel).grow(3.0),
		"sound feedback should reuse the BGM hit rect"
	)
	_expect_rect(
		PauseMenuSelectionFeedbackRenderer.get_feedback_rect(panel, "options:display", 4, 4),
		PauseMenuOverlayLayout.get_display_auto_refresh_row_rect(panel),
		"display feedback should reuse the auto-refresh row"
	)
	_expect_rect(
		PauseMenuSelectionFeedbackRenderer.get_feedback_rect(panel, "options:controls:joypad", 1, 4),
		PauseMenuOverlayLayout.get_controls_vibration_row_rect(panel),
		"joypad feedback should expose the vibration row"
	)
	_expect_rect(
		PauseMenuSelectionFeedbackRenderer.get_feedback_rect(panel, "options:controls:keyboard_mouse", 1, 4),
		PauseMenuOverlayLayout.get_controls_back_button_rect(panel),
		"keyboard feedback should map focus one to back"
	)
	_expect_rect(
		PauseMenuSelectionFeedbackRenderer.get_feedback_rect(panel, "options:language", 6, 4),
		PauseMenuOverlayLayout.get_language_russian_rect(panel),
		"language feedback should reuse the Russian option rect"
	)
	_expect(
		not PauseMenuSelectionFeedbackRenderer.has_feedback_rect(
			PauseMenuSelectionFeedbackRenderer.get_feedback_rect(panel, "unknown", 0, 4)
		),
		"unknown feedback scopes should stay empty"
	)


func _verify_animation_projection() -> void:
	var panel := Rect2(190.0, 110.0, 900.0, 500.0)
	var state := PauseMenuSelectionFeedbackState.new()
	var renderer := PauseMenuSelectionFeedbackRenderer.new()
	state.begin("options:display", 0, 1)
	_expect_rect(
		renderer.get_animated_rect("options:display", panel, 1, state, 4),
		PauseMenuSelectionFeedbackRenderer.get_feedback_rect(panel, "options:display", 0, 4),
		"a new slide should begin at the previous focus rect"
	)
	state.advance(PauseMenuSelectionFeedbackState.SLIDE_DURATION)
	_expect_rect(
		renderer.get_animated_rect("options:display", panel, 1, state, 4),
		PauseMenuSelectionFeedbackRenderer.get_feedback_rect(panel, "options:display", 1, 4),
		"a completed slide should settle on the current focus rect"
	)


func _verify_facade_delegation_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_overlay.gd")
	_expect(
		source.contains("const PauseMenuSelectionFeedbackRenderer := preload(\"res://scripts/hud/pause_menu_selection_feedback_renderer.gd\")"),
		"the facade should preload the selection feedback renderer"
	)
	_expect(source.contains("var _selection_feedback_renderer := PauseMenuSelectionFeedbackRenderer.new()"), "the facade should keep one feedback renderer instance")
	var delegations := {
		"_draw_selection_feedback": "_selection_feedback_renderer.draw",
		"_get_selection_feedback_rect": "PauseMenuSelectionFeedbackRenderer.get_feedback_rect",
		"_get_sound_focus_rect": "PauseMenuSelectionFeedbackRenderer.get_sound_focus_rect",
		"_get_display_focus_rect": "PauseMenuSelectionFeedbackRenderer.get_display_focus_rect",
		"_get_controls_focus_rect": "PauseMenuSelectionFeedbackRenderer.get_controls_focus_rect",
		"_get_language_focus_rect": "PauseMenuSelectionFeedbackRenderer.get_language_focus_rect",
		"_span_rect": "PauseMenuSelectionFeedbackRenderer.span_rect",
		"_lerp_rect": "PauseMenuSelectionFeedbackRenderer.lerp_rect",
		"_scale_rect_from_center": "PauseMenuSelectionFeedbackRenderer.scale_rect_from_center",
		"_has_feedback_rect": "PauseMenuSelectionFeedbackRenderer.has_feedback_rect",
		"_get_animated_selection_rect": "_selection_feedback_renderer.get_animated_rect",
	}
	for function_name: String in delegations:
		var body := _source_function_body(source, "func %s(" % function_name)
		_expect(
			body.contains(str(delegations[function_name])),
			"%s should delegate feedback projection to the renderer" % function_name
		)


func _verify_renderer_ownership_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_selection_feedback_renderer.gd")
	var draw_body := _source_function_body(source, "func draw(")
	_expect(draw_body.contains("build_pop_projection") and draw_body.contains("PremiumPanelFrame.draw_panel"), "the renderer should own pop and frame projection")
	var animated_body := _source_function_body(source, "func get_animated_rect(")
	_expect(animated_body.contains("build_slide_projection") and animated_body.contains("lerp_rect"), "the renderer should own slide projection")
	_expect(not source.contains("LanguageSettings") and not source.contains("registry"), "feedback rendering should stay independent from localization and registries")


func _source_function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + signature.length())
	if next < 0:
		return source.substr(start)
	return source.substr(start, next - start)


func _expect_rect(actual: Rect2, expected: Rect2, message: String) -> void:
	_expect(actual.is_equal_approx(expected), "%s (expected %s, found %s)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
