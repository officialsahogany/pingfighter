extends SceneTree

const GuardianEnhanceCutinState := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_cutin_state.gd"
)

const TEST_CONTRACT := {
	"visual_key": "companion_click_reaction_anim",
	"idle_fallback": false,
	"cols": 2,
	"rows": 2,
	"frame_count": 4,
	"frame_interval": 0.05,
	"draw_size": 96.0,
}

var _failures: Array[String] = []


func _init() -> void:
	_verify_five_phase_boundaries_and_one_sheet_loop()
	_verify_skip_from_every_phase()
	_verify_asset_gate_and_large_delta_consumption()
	_verify_wall_clock_free_host_contract()

	if _failures.is_empty():
		print("guardian_enhance_cutin_phase_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_five_phase_boundaries_and_one_sheet_loop() -> void:
	var state := _start_state()
	_expect_phase(state, GuardianEnhanceCutinState.PHASE_INTRO, 0.0)
	_expect(not state.advance(0.139, true, TEST_CONTRACT), "INTRO must remain active before 0.14s")
	_expect_phase(state, GuardianEnhanceCutinState.PHASE_INTRO, 0.139)
	_expect(not state.advance(0.001, true, TEST_CONTRACT), "INTRO boundary must enter ROLL without closing")
	_expect_phase(state, GuardianEnhanceCutinState.PHASE_ROLL, 0.0)
	_expect(not state.advance(0.75, true, TEST_CONTRACT), "ROLL boundary must enter STAMP without closing")
	_expect_phase(state, GuardianEnhanceCutinState.PHASE_STAMP, 0.0)
	_expect(int(state.get_snapshot().get("animation_frame", -1)) == 0, "STAMP must hold the reaction sheet on frame zero")
	_expect(not state.advance(0.22, true, TEST_CONTRACT), "STAMP boundary must enter REACTION without closing")
	_expect_phase(state, GuardianEnhanceCutinState.PHASE_REACTION, 0.0)
	_expect(not state.advance(0.19, true, TEST_CONTRACT), "REACTION must remain active before one full sheet loop")
	_expect(int(state.get_snapshot().get("animation_frame", -1)) == 3, "REACTION must clamp to the final authored frame near loop end")
	_expect(not state.advance(0.01, true, TEST_CONTRACT), "one sheet loop must enter OUTRO instead of closing immediately")
	_expect_phase(state, GuardianEnhanceCutinState.PHASE_OUTRO, 0.0)
	_expect(not state.advance(0.159, true, TEST_CONTRACT), "OUTRO must remain active before 0.16s")
	_expect(state.advance(0.001, true, TEST_CONTRACT), "OUTRO boundary must report automatic close")
	_expect(not state.active, "automatic close must reset the cutin state")
	_expect_close(
		GuardianEnhanceCutinState.INTRO_SECONDS
		+ GuardianEnhanceCutinState.ROLL_SECONDS
		+ GuardianEnhanceCutinState.STAMP_SECONDS
		+ 98.0 * 0.036
		+ GuardianEnhanceCutinState.OUTRO_SECONDS,
		4.798,
		"default 98-frame presentation must retain the approved approximately 4.80s total"
	)


func _verify_skip_from_every_phase() -> void:
	for target_phase in [
		GuardianEnhanceCutinState.PHASE_INTRO,
		GuardianEnhanceCutinState.PHASE_ROLL,
		GuardianEnhanceCutinState.PHASE_STAMP,
		GuardianEnhanceCutinState.PHASE_REACTION,
		GuardianEnhanceCutinState.PHASE_OUTRO,
	]:
		var state := _start_state()
		_advance_to_phase(state, target_phase)
		_expect(str(state.get_snapshot().get("phase", "")) == target_phase, "fixture must reach %s before skip" % target_phase)
		_expect(state.cancel_immediate(), "skip must be accepted during %s" % target_phase)
		_expect(not state.active, "skip must clear active state during %s" % target_phase)


func _verify_asset_gate_and_large_delta_consumption() -> void:
	var gated := _start_state()
	gated.advance(GuardianEnhanceCutinState.INTRO_SECONDS, false, TEST_CONTRACT)
	gated.advance(GuardianEnhanceCutinState.ROLL_SECONDS, false, TEST_CONTRACT)
	_expect_phase(gated, GuardianEnhanceCutinState.PHASE_ROLL, GuardianEnhanceCutinState.ROLL_SECONDS)
	_expect(not gated.advance(2.99, false, TEST_CONTRACT), "asset gate must hold ROLL before its bounded timeout")
	_expect_phase(gated, GuardianEnhanceCutinState.PHASE_ROLL, GuardianEnhanceCutinState.ROLL_SECONDS)
	_expect(not gated.advance(0.01, false, TEST_CONTRACT), "asset timeout must fail open into STAMP without closing")
	_expect_phase(gated, GuardianEnhanceCutinState.PHASE_STAMP, 0.0)

	var state := _start_state()
	_expect(
		state.advance(10.0, true, TEST_CONTRACT),
		"one large ungated idle delta must consume every phase and close deterministically"
	)
	_expect(not state.active, "large-delta close must leave no active state")


func _verify_wall_clock_free_host_contract() -> void:
	var host_source := FileAccess.get_file_as_string(
		"res://scripts/hud/lingpet_guardian_enhance_cutin_overlay_host.gd"
	)
	_expect(
		host_source.find("Time.get_ticks_msec()") < 0,
		"Guardian Enhancement draw state must not depend on process wall clock"
	)
	_expect(
		host_source.find("snapshot.get(\"phase_elapsed\"") >= 0,
		"host motion must read deterministic phase elapsed time from the state snapshot"
	)


func _start_state() -> Object:
	var state := GuardianEnhanceCutinState.new()
	_expect(
		state.start("maribo", {"accepted": true, "feedback_text": "강화 획득"}),
		"valid fixture must start the cutin"
	)
	return state


func _advance_to_phase(state: Object, target_phase: String) -> void:
	if target_phase == GuardianEnhanceCutinState.PHASE_INTRO:
		return
	state.advance(GuardianEnhanceCutinState.INTRO_SECONDS, true, TEST_CONTRACT)
	if target_phase == GuardianEnhanceCutinState.PHASE_ROLL:
		return
	state.advance(GuardianEnhanceCutinState.ROLL_SECONDS, true, TEST_CONTRACT)
	if target_phase == GuardianEnhanceCutinState.PHASE_STAMP:
		return
	state.advance(GuardianEnhanceCutinState.STAMP_SECONDS, true, TEST_CONTRACT)
	if target_phase == GuardianEnhanceCutinState.PHASE_REACTION:
		return
	state.advance(0.20, true, TEST_CONTRACT)


func _expect_phase(state: Object, expected_phase: String, expected_elapsed: float) -> void:
	var snapshot: Dictionary = state.get_snapshot()
	_expect(str(snapshot.get("phase", "")) == expected_phase, "expected %s phase" % expected_phase)
	_expect_close(
		float(snapshot.get("phase_elapsed", -1.0)),
		expected_elapsed,
		"%s phase elapsed must land on its exact deterministic boundary" % expected_phase
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.4f, got %.4f)" % [message, expected, actual])
