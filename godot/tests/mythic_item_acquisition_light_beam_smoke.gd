extends SceneTree

const LightBeamState := preload("res://scripts/items/mythic_item_acquisition_light_beam_state.gd")
const LightBeamRenderer := preload("res://scripts/items/mythic_item_acquisition_light_beam_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_seeded_spawn_and_ranges()
	_verify_lifetime_compaction()
	_verify_exact_draw_geometry()
	_verify_source_ownership_and_continuity()
	if _failures.is_empty():
		print("mythic_item_acquisition_light_beam_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_seeded_spawn_and_ranges() -> void:
	var first_rng := RandomNumberGenerator.new()
	var second_rng := RandomNumberGenerator.new()
	first_rng.seed = 20260713
	second_rng.seed = 20260713
	var first := LightBeamState.new()
	var second := LightBeamState.new()
	first.begin(first_rng)
	second.begin(second_rng)
	first.spawn_tick(0, first_rng)
	second.spawn_tick(0, second_rng)
	_expect(first.beams.size() >= 2 and first.beams.size() <= 4, "tick zero should preserve the 2..4 beam count")
	_expect(first.beams.size() == second.beams.size(), "equal seeds should produce equal beam counts")
	for index in range(first.beams.size()):
		var beam: Dictionary = first.beams[index]
		var peer: Dictionary = second.beams[index]
		for key in ["angle", "age", "life", "extend_time", "max_len", "width", "color"]:
			_expect(beam.get(key) == peer.get(key), "equal seeds should preserve %s for beam %d" % [str(key), index])
		_expect(float(beam.get("life", 0.0)) >= 0.7 and float(beam.get("life", 0.0)) <= 1.2, "beam lifetime should stay in the original range")
		_expect(float(beam.get("extend_time", 0.0)) >= 0.07 and float(beam.get("extend_time", 0.0)) <= 0.12, "beam extension time should stay in the original range")
		_expect(float(beam.get("max_len", 0.0)) >= 900.0 and float(beam.get("max_len", 0.0)) <= 1460.0, "beam reach should stay in the original range")
		_expect(LightBeamState.PALETTE.has(beam.get("color")), "beam color should stay in the fixed mythic palette")


func _verify_lifetime_compaction() -> void:
	var state := LightBeamState.new()
	state.beams.append({"age": 0.0, "life": 0.2})
	state.beams.append({"age": 0.0, "life": 1.0})
	state.update(-1.0)
	_expect(is_zero_approx(float(state.beams[0].get("age", -1.0))), "negative delta should not rewind beam age")
	state.update(0.25)
	_expect(state.beams.size() == 1, "expired beam should compact out while the live beam remains")
	if state.beams.size() == 1:
		_expect(is_equal_approx(float(state.beams[0].get("age", 0.0)), 0.25), "surviving beam age should advance exactly once")
	state.update(0.75)
	_expect(state.beams.is_empty(), "beam should expire exactly at its lifetime")
	state.clear()
	_expect(state.beams.is_empty() and is_zero_approx(state.angle_cursor), "clear should reset beams and angle cursor")


func _verify_exact_draw_geometry() -> void:
	var renderer := LightBeamRenderer.new()
	var beam := {
		"angle": 0.0,
		"age": 0.035,
		"life": 1.0,
		"extend_time": 0.1,
		"max_len": 100.0,
		"width": 10.0,
		"color": Color(1.0, 0.8, 0.4),
	}
	var center := Vector2(380.0, 375.0)
	_expect(renderer.project(beam, center), "visible fixture beam should project draw geometry")
	var extension_eased := 1.0 - pow(1.0 - 0.35, 3.0)
	_expect(renderer.start.is_equal_approx(center + Vector2(16.0, 0.0)), "beam should preserve the 16px inner gap")
	_expect(renderer.end.is_equal_approx(center + Vector2(100.0 * extension_eased, 0.0)), "beam head extension should preserve cubic easing")
	_expect_close(renderer.alpha, 0.5, "beam fade-in alpha")
	_expect_close(renderer.width, 10.0, "beam glow width")
	_expect_close(renderer.core_width, 3.2, "beam core width")
	_expect_close(renderer.head_radius, 6.0, "beam head radius")
	_expect_close(renderer.glow_color.a, 0.225, "beam glow alpha")
	_expect_close(renderer.core_color.a, 0.45, "beam core alpha")
	_expect_close(renderer.head_color.a, 0.425, "beam head alpha")
	beam["age"] = 1.0
	_expect(not renderer.project(beam, center), "expired beam should not produce draw geometry")
	_expect_close(renderer.alpha, 0.0, "invalid projection should clear reusable alpha")


func _verify_source_ownership_and_continuity() -> void:
	var host_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_acquisition_cinematic_v2.gd")
	var state_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_acquisition_light_beam_state.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_acquisition_light_beam_renderer.gd")
	_expect(host_source.find("_light_beam_state.spawn_tick(") >= 0, "host should delegate randomized beam spawn")
	_expect(host_source.find("_light_beam_state.update(") >= 0, "host should delegate beam lifetime")
	_expect(host_source.find("_light_beam_renderer.draw(") >= 0, "host should delegate beam geometry and draw")
	_expect(host_source.find("beam.get(\"extend_time\"") < 0 and host_source.find("_beam_angle_cursor") < 0, "host should not retain extracted beam formulas")
	_expect(state_source.find("draw_line") < 0 and state_source.find("draw_circle") < 0, "beam state should not own rendering")
	_expect(renderer_source.find("randi") < 0 and renderer_source.find("remove_at") < 0, "beam renderer should not own randomness or lifetime")
	_expect(renderer_source.find("stride") < 0 and renderer_source.find("% stride") < 0, "beam renderer should draw the full sparse set without index stride")
	_expect(renderer_source.find("for beam: Dictionary in beams") >= 0, "beam renderer should visit every live beam")


func _expect_close(actual: float, expected: float, label: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s should remain exact (expected %.6f, found %.6f)" % [label, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
