extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	_verify_overlay_perf_segments()
	_verify_overlay_perf_chain()
	_verify_result_screen_gate()
	_verify_score_panel_led_budget()
	_verify_led_digit_layer_budget()

	if _failures.is_empty():
		print("scoreboard_overlay_renderer_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_overlay_perf_segments() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/scoreboard_overlay_renderer.gd")
	for label in [
		"scoreboard.overlay.shadow",
		"scoreboard.overlay.light",
		"scoreboard.overlay.frame",
		"scoreboard.overlay.header",
		"scoreboard.overlay.score_panel",
		"scoreboard.overlay.footer",
	]:
		_expect(source.find(label) >= 0, "scoreboard overlay should keep perf label %s" % label)
	_expect(source.find("func _perf_begin") >= 0, "scoreboard overlay should expose local perf begin helper")
	_expect(source.find("func _perf_end") >= 0, "scoreboard overlay should expose local perf end helper")


func _verify_overlay_perf_chain() -> void:
	var overlay_drawer_source := FileAccess.get_file_as_string("res://scripts/core/battle_playfield_overlay_drawer.gd")
	var scoreboard_renderer_source := FileAccess.get_file_as_string("res://scripts/hud/scoreboard_renderer.gd")
	_expect(overlay_drawer_source.find("perf_logger: Object = null") >= 0, "overlay drawer should accept perf logger")
	_expect(overlay_drawer_source.find("draw_context,\n\t\tperf_logger") >= 0, "overlay drawer should forward perf logger")
	_expect(scoreboard_renderer_source.find("perf_logger: Object = null") >= 0, "scoreboard renderer should accept perf logger")
	_expect(scoreboard_renderer_source.find("draw_context,\n\t\tperf_logger") >= 0, "scoreboard renderer should forward perf logger")


func _verify_result_screen_gate() -> void:
	var overlay_drawer_source := FileAccess.get_file_as_string("res://scripts/core/battle_playfield_overlay_drawer.gd")
	var playfield_drawer_source := FileAccess.get_file_as_string("res://scripts/core/battle_playfield_scene_drawer.gd")
	var stage2_pillar_source := FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_scene_drawer.gd")
	_expect(overlay_drawer_source.find("_is_stage_clear_result_active(registry)") >= 0, "scoreboard overlay should skip while the result screen is active")
	_expect(playfield_drawer_source.find("\"stage_clear_result_screen\"") >= 0, "playfield scoreboard LOD should ignore the overlay during result screens")
	_expect(stage2_pillar_source.find("\"stage_clear_result_screen\"") >= 0, "stage2 pillar LOD should ignore the overlay during result screens")


func _verify_score_panel_led_budget() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/scoreboard_overlay_score_panel_renderer.gd")
	var body := _function_body(source, "func draw(")
	_expect(body != "", "scoreboard score panel draw body should be readable")
	_expect(source.find("SCORE_PANEL_GLOW_STRIDE := 4") >= 0, "score panel LED glow stride should stay on the cheaper result-overlay budget")
	_expect(_count_substr(body, "SCORE_PANEL_GLOW_STRIDE") >= 2, "score panel LED score digits should use the shared reduced glow stride")
	_expect(source.find("SCORE_PANEL_DRAW_INACTIVE_SOCKETS := false") >= 0, "score panel LED should skip inactive sockets on the fast overlay path")
	_expect(source.find("SCORE_PANEL_DRAW_LED_HIGHLIGHT := false") >= 0, "score panel LED should skip highlight dots on the fast overlay path")
	_expect(_count_substr(body, "SCORE_PANEL_DRAW_INACTIVE_SOCKETS") >= 2, "score panel LED digits should pass the inactive-socket fast flag")
	_expect(_count_substr(body, "SCORE_PANEL_DRAW_LED_HIGHLIGHT") >= 2, "score panel LED digits should pass the highlight fast flag")
	_expect(_count_substr(body, "\n\t\t2\n\t)") == 0, "score panel LED score digits should not regress to denser glow stride")


func _verify_led_digit_layer_budget() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/scoreboard_led_digits.gd")
	_expect(source.find("LIT_GLOW_LAYER_COUNT := 1") >= 0, "scoreboard LED digits should keep one glow layer")
	_expect(source.find("draw_inactive_sockets: bool = true") >= 0, "scoreboard LED digits should keep inactive sockets enabled by default")
	_expect(source.find("draw_highlight: bool = true") >= 0, "scoreboard LED digits should keep highlights enabled by default")
	_expect(source.find("reflection_offset") < 0, "inactive LED sockets should stay single-draw for the overlay budget")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _count_substr(source: String, needle: String) -> int:
	var count := 0
	var offset := 0
	while true:
		var index := source.find(needle, offset)
		if index < 0:
			return count
		count += 1
		offset = index + needle.length()
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
