extends SceneTree

const VisualEnvelope := preload("res://scripts/items/mythic_item_acquisition_visual_envelope.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_exact_phase_projections()
	_verify_clear_contract()
	_verify_allocation_free_source_boundary()
	if _failures.is_empty():
		print("mythic_item_acquisition_visual_envelope_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_exact_phase_projections() -> void:
	var envelope := VisualEnvelope.new()
	envelope.begin()
	_expect(is_equal_approx(envelope.vignette_alpha, 1.0), "begin should enable the cinematic vignette")
	_expect(is_equal_approx(envelope.backplate_scale, 0.6), "begin should restore the initial backplate scale")

	var buildup_progress := 0.5
	var buildup_eased := ease(buildup_progress, 0.4)
	envelope.project_buildup(0.6, 1.2, 0.3)
	_expect_close(envelope.backplate_alpha, buildup_eased, "buildup backplate alpha")
	_expect_close(envelope.backplate_intensity, lerpf(0.4, 1.0, buildup_eased) + 0.3 * 1.3, "buildup intensity plus flash")
	_expect_close(envelope.backplate_scale, lerpf(0.55, 1.0, buildup_eased) + 0.3 * 0.04, "buildup scale plus flash")
	_expect_close(envelope.white_flash_alpha, 0.3, "buildup white flash")

	var ignite_progress := 0.5
	var ignite_eased := ease(ignite_progress, 0.3)
	var ignite_punch := ease(ignite_progress, 0.25)
	envelope.project_ignite(0.2, 0.4, 0.1)
	_expect_close(envelope.backplate_intensity, lerpf(1.9, 1.1, ignite_punch), "ignite intensity")
	_expect_close(envelope.backplate_scale, lerpf(1.30, 1.12, ignite_punch), "ignite overshoot scale")
	_expect_close(envelope.arc_alpha, lerpf(1.0, 0.7, ignite_eased), "ignite arc alpha")
	_expect_close(envelope.arc_extension, ignite_eased, "ignite arc extension")
	_expect_close(envelope.white_flash_alpha, 0.75, "ignite held white flash")

	envelope.project_white_fade(0.25, 0.5)
	_expect_close(envelope.white_flash_alpha, 0.2, "white-fade flash")
	_expect_close(envelope.backplate_intensity, 1.0, "white-fade intensity")
	_expect_close(envelope.arc_alpha, 0.525, "white-fade arc alpha")

	envelope.project_reveal(0.225, 1.0)
	var reveal_eased := ease(0.5, 0.4)
	_expect_close(envelope.icon_alpha, 0.5, "reveal icon alpha")
	_expect_close(envelope.icon_scale, reveal_eased, "reveal icon scale")
	_expect_close(envelope.icon_backdrop_alpha, 0.68 * reveal_eased, "reveal backdrop alpha")
	_expect_close(envelope.icon_float_offset, sin(1.6) * 5.0, "reveal float offset")
	_expect_close(envelope.backplate_intensity, 0.42 + 0.04 * sin(1.3), "reveal breathing intensity")

	var target := Vector2(380.0, 725.0)
	envelope.project_absorb(0.75, 1.5, target)
	var absorb_eased := ease(0.5, 0.6)
	var spiral_angle := absorb_eased * TAU * 1.8
	var spiral_position := Vector2(cos(spiral_angle), sin(spiral_angle)) * ((1.0 - absorb_eased) * 60.0)
	var expected_icon_position := VisualEnvelope.FIELD_CENTER.lerp(target, absorb_eased) + spiral_position
	_expect(envelope.icon_position.is_equal_approx(expected_icon_position), "absorb icon spiral position should remain exact")
	_expect_close(envelope.icon_alpha, lerpf(1.0, 0.4, absorb_eased), "absorb icon alpha")
	_expect_close(envelope.icon_scale, lerpf(1.0, 0.25, absorb_eased), "absorb icon scale")

	envelope.start_impact()
	_expect_close(envelope.paddle_glow_intensity, 1.0, "impact start glow")
	envelope.project_impact(0.25, 0.5)
	_expect_close(envelope.paddle_glow_intensity, 0.5, "impact glow decay")
	_expect_close(envelope.white_flash_alpha, 0.0, "impact flash decay")
	_expect_close(envelope.icon_alpha, 0.0, "impact icon hide")


func _verify_clear_contract() -> void:
	var envelope := VisualEnvelope.new()
	envelope.begin()
	envelope.project_reveal(0.45, 2.0)
	envelope.start_impact()
	envelope.clear()
	_expect_close(envelope.vignette_alpha, 0.0, "clear vignette")
	_expect_close(envelope.backplate_alpha, 0.0, "clear backplate alpha")
	_expect_close(envelope.backplate_scale, 0.6, "clear backplate scale")
	_expect_close(envelope.icon_float_offset, 0.0, "clear icon float")
	_expect(envelope.icon_position == VisualEnvelope.FIELD_CENTER, "clear icon position should return to field center")
	_expect_close(envelope.paddle_glow_intensity, 0.0, "clear paddle glow")


func _verify_allocation_free_source_boundary() -> void:
	var envelope_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_acquisition_visual_envelope.gd")
	var host_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_acquisition_cinematic_v2.gd")
	_expect(envelope_source.find("Dictionary") < 0 and envelope_source.find("return {") < 0, "per-frame envelope projections should not allocate dictionaries")
	_expect(envelope_source.find("func project_buildup(") >= 0 and envelope_source.find("func project_absorb(") >= 0, "envelope should own phase projection formulas")
	_expect(host_source.find("_visual.project_buildup(") >= 0, "host buildup should delegate scalar projection")
	_expect(host_source.find("_visual.project_ignite(") >= 0, "host ignite should delegate scalar projection")
	_expect(host_source.find("_visual.project_white_fade(") >= 0, "host white fade should delegate scalar projection")
	_expect(host_source.find("_visual.project_reveal(") >= 0, "host reveal should delegate scalar projection")
	_expect(host_source.find("_visual.project_absorb(") >= 0, "host absorb should delegate scalar projection")
	_expect(host_source.find("_visual.project_impact(") >= 0, "host impact should delegate scalar projection")
	_expect(host_source.find("lerp(1.9, 1.1") < 0 and host_source.find("spiral_angle") < 0, "host should not retain extracted envelope formulas")


func _expect_close(actual: float, expected: float, label: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s should remain exact (expected %.6f, found %.6f)" % [label, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
