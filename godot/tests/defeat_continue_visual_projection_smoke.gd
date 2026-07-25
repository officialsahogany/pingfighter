extends SceneTree

const VisualProjection := preload("res://scripts/core/defeat_continue_visual_projection.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_gem_and_timeline_projection()
	_verify_impact_envelopes()
	_verify_sprite_and_view_geometry()
	if _failures.is_empty():
		print("defeat_continue_visual_projection_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_gem_and_timeline_projection() -> void:
	_expect(VisualProjection.get_visual_remaining_gems(false, false, 2, 1) == 2, "present phase should show the current gem count")
	_expect(VisualProjection.get_visual_remaining_gems(true, true, 2, 1) == 1, "shatter phase should preview the consumed gem count")
	_expect(VisualProjection.get_breaking_gem_index(true, false, 3, 2) == 1, "second consumed slot should break left-to-right")
	_expect(VisualProjection.get_breaking_gem_index(true, true, 3, 2) == -1, "completed reset should clear the breaking slot")
	_expect(not VisualProjection.has_shatter_started(true, VisualProjection.CONFIRM_SHATTER_START_SEC - 0.001), "shatter should stay closed before its threshold")
	_expect(VisualProjection.has_shatter_started(true, VisualProjection.CONFIRM_SHATTER_START_SEC), "shatter should start exactly at its threshold")
	_expect(VisualProjection.is_shatter_window_active(true, VisualProjection.CONFIRM_SHATTER_START_SEC), "shatter window should include its start")
	_expect(not VisualProjection.is_shatter_window_active(true, VisualProjection.CONFIRM_SHATTER_START_SEC + VisualProjection.CONFIRM_SHATTER_DURATION_SEC), "shatter window should exclude its end")
	_expect(is_equal_approx(VisualProjection.get_shatter_progress(true, VisualProjection.CONFIRM_SHATTER_START_SEC + VisualProjection.CONFIRM_SHATTER_DURATION_SEC * 0.5), 0.5), "mid-shatter time should project half progress")
	_expect(VisualProjection.get_pre_shatter_charge(true, 1.0) > 0.0, "confirm hold should build pre-shatter charge")
	_expect(VisualProjection.get_pre_shatter_crack(true, 1.0) > 0.0, "late confirm hold should expose crack buildup")


func _verify_impact_envelopes() -> void:
	var impact_start := VisualProjection.CONFIRM_SHATTER_START_SEC
	_expect(is_equal_approx(VisualProjection.get_impact_flash_alpha(true, impact_start), 1.0), "impact flash should peak at shatter start")
	_expect(VisualProjection.get_impact_ring_progress(true, impact_start + 0.2) > 0.0, "impact ring should expand after shatter")
	_expect(VisualProjection.get_impact_ring_alpha(true, impact_start + 0.2) > 0.0, "impact ring should remain visible mid-envelope")
	_expect(VisualProjection.get_light_beam_alpha(true, impact_start + 0.1) > 0.0, "light beams should fade in after impact")
	_expect(VisualProjection.get_chroma_split_strength(true, impact_start + 0.1) > 0.0, "chroma split should be active near impact")
	_expect(VisualProjection.get_impact_shake_offset(true, impact_start + 0.1).length() > 0.0, "impact should project a non-zero shake offset")
	_expect(is_zero_approx(VisualProjection.get_whiteout_alpha(true, VisualProjection.CONFIRM_WHITEOUT_START_SEC)), "whiteout should begin from transparent")
	_expect(is_equal_approx(VisualProjection.get_whiteout_alpha(true, VisualProjection.CONFIRM_RESET_TIME_SEC), 1.0), "whiteout should peak at reset")
	_expect(is_zero_approx(VisualProjection.get_whiteout_alpha(true, VisualProjection.CONFIRM_FADEBACK_END_SEC)), "whiteout should fade out by the handoff end")


func _verify_sprite_and_view_geometry() -> void:
	var stage2_cell := VisualProjection.get_boss_victory_source_rect(Vector2(4096.0, 4096.0), 2, 9)
	_expect(stage2_cell == Rect2(512.0, 512.0, 512.0, 512.0), "Stage 2 victory sheet should use an 8x8 grid")
	var stage6_cell := VisualProjection.get_boss_victory_source_rect(Vector2(1536.0, 768.0), 6, 7)
	_expect(stage6_cell == Rect2(1152.0, 384.0, 384.0, 384.0), "wide modern victory sheets should use a 4x2 grid")
	var single_cell := VisualProjection.get_boss_victory_source_rect(Vector2(768.0, 768.0), 4, 7)
	_expect(single_cell == Rect2(0.0, 0.0, 768.0, 768.0), "square Stage 4+ art should remain a single cell")
	var left_gem := VisualProjection.get_consumed_gem_center(Vector2(1280.0, 720.0), 1, 3)
	var right_gem := VisualProjection.get_consumed_gem_center(Vector2(1280.0, 720.0), 3, 3)
	_expect(left_gem.x < right_gem.x and is_equal_approx(left_gem.y, right_gem.y), "consumed gem centers should advance left-to-right on one rail")
	_expect(VisualProjection.fit_size_rect(Vector2(400.0, 200.0), Vector2(100.0, 100.0), Vector2(100.0, 100.0)) == Rect2(50.0, 75.0, 100.0, 50.0), "fit geometry should preserve aspect ratio")
	_expect(VisualProjection.cover_size_rect(Vector2(400.0, 200.0), Rect2(0.0, 0.0, 100.0, 100.0)) == Rect2(-50.0, 0.0, 200.0, 100.0), "cover geometry should fill the target")
	_expect(VisualProjection.get_button_rect(Vector2(1280.0, 720.0)).has_point(Vector2(640.0, 669.0)), "shipped 1280x720 confirm click should remain inside the button")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
