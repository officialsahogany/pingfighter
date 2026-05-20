extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	_verify_overlay_perf_segments()
	_verify_overlay_perf_chain()
	_verify_score_panel_led_budget()

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


func _verify_score_panel_led_budget() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/scoreboard_overlay_score_panel_renderer.gd")
	var body := _function_body(source, "func draw(")
	_expect(body != "", "scoreboard score panel draw body should be readable")
	_expect(_count_substr(body, "\n\t\t3\n\t)") >= 2, "score panel LED score digits should use reduced glow stride")
	_expect(_count_substr(body, "\n\t\t2\n\t)") == 0, "score panel LED score digits should not regress to denser glow stride")


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
