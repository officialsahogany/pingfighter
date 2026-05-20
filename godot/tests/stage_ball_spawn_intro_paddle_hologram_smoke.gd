extends SceneTree

# Validates `get_paddle_hologram_state()` against the Python contract from
# `pingfighter.py §122551` (`get_paddle_hologram_state`):
#   * before the materialize window opens: paddle is fully hidden
#   * during the materialize window (last `PADDLE_HOLOGRAM_DURATION` of the
#     blocking intro): `active = true` and `progress` advances 0 -> 1
#   * outside the intro: paddle renders at full visibility
#
# Also covers the multi-pass plan helper so the cyan / magenta ghosts shut
# off late in the materialize window and noise / edge-glow gates flip in the
# intended order.

const StageBallSpawnIntro := preload("res://scripts/core/stage_ball_spawn_intro.gd")
const PaddleHologramGlitchRenderer := preload("res://scripts/effects/paddle_hologram_glitch_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_inactive_intro_returns_fully_visible()
	_test_pre_window_hides_paddle()
	_test_window_start_marks_active_with_zero_progress()
	_test_window_end_marks_done_with_full_progress()
	_test_pass_plan_alpha_progression()
	_test_pass_plan_ghost_window()
	_test_pass_plan_late_progress_cleanup()
	if _failures.is_empty():
		print("stage_ball_spawn_intro_paddle_hologram_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_inactive_intro_returns_fully_visible() -> void:
	var intro := StageBallSpawnIntro.new()
	# active / overlay_active default false, so the intro reads as inactive.
	var state: Dictionary = intro.get_paddle_hologram_state()
	_expect(bool(state.get("should_draw", false)), true, "inactive: should_draw")
	_expect(float(state.get("progress", 0.0)), 1.0, "inactive: progress")
	_expect(bool(state.get("active", true)), false, "inactive: active")


func _test_pre_window_hides_paddle() -> void:
	var intro := StageBallSpawnIntro.new()
	intro.active = true
	intro.elapsed_sec = 1.5  # Phase 1 still running, well before the window
	var state: Dictionary = intro.get_paddle_hologram_state()
	_expect(bool(state.get("should_draw", true)), false, "pre window: should_draw")
	_expect(bool(state.get("active", true)), false, "pre window: active")
	_expect(float(state.get("progress", 1.0)), 0.0, "pre window: progress")


func _test_window_start_marks_active_with_zero_progress() -> void:
	var intro := StageBallSpawnIntro.new()
	intro.active = true
	# The window opens exactly at BLOCKING_DURATION - PADDLE_HOLOGRAM_DURATION
	# (4.0 - 1.5 = 2.5 s under the current constants).
	intro.elapsed_sec = StageBallSpawnIntro.BLOCKING_DURATION - StageBallSpawnIntro.PADDLE_HOLOGRAM_DURATION
	var state: Dictionary = intro.get_paddle_hologram_state()
	_expect(bool(state.get("should_draw", false)), true, "window start: should_draw")
	_expect(bool(state.get("active", false)), true, "window start: active")
	_expect(float(state.get("progress", -1.0)), 0.0, "window start: progress")


func _test_window_end_marks_done_with_full_progress() -> void:
	var intro := StageBallSpawnIntro.new()
	intro.active = true
	# At the closing edge `progress` should clamp to 1.0 and `active` flip to
	# false so the gameplay-handoff frame never re-enters the materialize
	# branch.
	intro.elapsed_sec = StageBallSpawnIntro.BLOCKING_DURATION
	var state: Dictionary = intro.get_paddle_hologram_state()
	_expect(bool(state.get("should_draw", false)), true, "window end: should_draw")
	_expect(bool(state.get("active", true)), false, "window end: active")
	_expect(float(state.get("progress", 0.0)), 1.0, "window end: progress")


func _test_pass_plan_alpha_progression() -> void:
	var early: Dictionary = PaddleHologramGlitchRenderer.compute_pass_plan(0.0, 0)
	var late: Dictionary = PaddleHologramGlitchRenderer.compute_pass_plan(0.95, 0)
	var early_modulate: Color = early.get("main_modulate", Color.WHITE)
	var late_modulate: Color = late.get("main_modulate", Color.WHITE)
	if not (early_modulate.a < 0.25):
		_failures.append("expected early main alpha < 0.25, got %f" % early_modulate.a)
	if not (late_modulate.a > 0.95):
		_failures.append("expected late main alpha > 0.95, got %f" % late_modulate.a)


func _test_pass_plan_ghost_window() -> void:
	var early: Dictionary = PaddleHologramGlitchRenderer.compute_pass_plan(0.4, 0)
	_expect(bool(early.get("ghosts_active", false)), true, "early ghosts: active")
	if float(early.get("color_shift_x", 0.0)) <= 0.0:
		_failures.append("early ghosts: expected positive color_shift_x")
	var done: Dictionary = PaddleHologramGlitchRenderer.compute_pass_plan(0.95, 0)
	_expect(bool(done.get("ghosts_active", true)), false, "late ghosts: off")


func _test_pass_plan_late_progress_cleanup() -> void:
	# At progress >= 0.9 scanlines and noise should both be off; edge glow
	# should be on; the post-materialize visual should read as a clean sprite
	# with only the edge glow tail.
	var late: Dictionary = PaddleHologramGlitchRenderer.compute_pass_plan(0.95, 0)
	_expect(bool(late.get("scanlines_active", true)), false, "late: scanlines off")
	_expect(bool(late.get("noise_active", true)), false, "late: noise off")
	_expect(bool(late.get("edge_glow_active", false)), true, "late: edge glow on")


func _expect(actual, expected, label: String) -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
