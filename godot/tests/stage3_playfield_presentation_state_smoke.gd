extends SceneTree

const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")
const Stage3PlayfieldPresentationState := preload("res://scripts/stages/stage3/stage3_playfield_presentation_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_deterministic_lifecycle()
	_verify_time_phase_and_particle_updates()
	_verify_playfield_single_owner_contract()
	if _failures.is_empty():
		print("stage3_playfield_presentation_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_deterministic_lifecycle() -> void:
	var first := Stage3PlayfieldPresentationState.new()
	var second := Stage3PlayfieldPresentationState.new()
	first.reset()
	second.reset()
	_expect(is_equal_approx(first.stadium_spark_next_time, second.stadium_spark_next_time), "presentation reset should preserve the seeded spark schedule")
	_expect(first.heart_particles == second.heart_particles, "presentation reset should preserve seeded initial heart particles")
	_expect(first.heart_particles.size() == 4, "presentation reset should create four initial hearts")
	_expect(first.stadium_spark_active_start < 0.0 and first.stadium_spark_cycle_index == 0 and is_equal_approx(first.stadium_spark_direction, 1.0), "presentation reset should settle the spark lifecycle")


func _verify_time_phase_and_particle_updates() -> void:
	var state := Stage3PlayfieldPresentationState.new()
	state.reset()
	_expect(is_equal_approx(state.tick_delta(1000), 1.0 / 60.0), "first tick should preserve the 60 FPS fallback")
	_expect(is_zero_approx(state.time_sec), "first tick should establish the clock without advancing animation time")
	_expect(is_equal_approx(state.tick_delta(1020), 0.02), "subsequent tick should use elapsed milliseconds")
	_expect(is_equal_approx(state.tick_delta(1120), 0.05), "slow tick should retain the 50 ms clamp")
	_expect(is_equal_approx(state.time_sec, 0.07), "animation time should accumulate clamped deltas")
	state.sync_phase({"stage3_emotional_phase": 5})
	_expect(state.emotional_phase == 2, "emotional phase should wrap into the three-phase range")
	var expiring_particles: Array = []
	for _index in range(Stage3PlayfieldPresentationState.HEART_PARTICLE_LIMIT):
		expiring_particles.append({"x": 1.0, "y": 1.0, "vx": 0.0, "vy": 0.0, "life": 0.5, "twinkle": 0.0})
	state.heart_particles = expiring_particles
	state.update_particles(1.0 / 60.0, 760.0, 750.0)
	_expect(state.heart_particles.is_empty(), "particle update should compact expired hearts in place")
	var broken_particle := state.make_heart_particle(760.0, 750.0, false)
	_expect(bool(broken_particle.get("broken", false)), "phase-two heart spawn should always produce a broken heart")
	state.stadium_spark_active_start = -1.0
	state.stadium_spark_next_time = 10.0
	state.time_sec = 9.0
	_expect(not state.advance_stadium_spark(), "spark should remain idle before its scheduled time")
	state.time_sec = 10.0
	_expect(state.advance_stadium_spark(), "spark should activate at its scheduled time")
	_expect(state.stadium_spark_cycle_index == 1 and is_equal_approx(state.stadium_spark_direction, -1.0), "first spark cycle should enter the legacy reverse direction")
	_expect(is_zero_approx(state.get_stadium_spark_burst_time()), "new spark cycle should begin at zero burst time")
	state.time_sec = 10.0 + Stage3PlayfieldPresentationState.STADIUM_SPARK_BURST_SEC + 0.001
	_expect(not state.advance_stadium_spark(), "spark should expire at the burst duration")
	_expect(state.stadium_spark_active_start < 0.0 and state.stadium_spark_next_time > state.time_sec, "spark expiry should schedule the next seeded interval")


func _verify_playfield_single_owner_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_playfield_renderer.gd")
	_expect(source.find("var _presentation_state: Stage3PlayfieldPresentationState") >= 0, "Stage 3 playfield should keep one typed presentation-state owner")
	for mirror in [
		"rng",
		"last_update_msec",
		"time_sec",
		"emotional_phase",
		"heart_particles",
		"stadium_spark_next_time",
		"stadium_spark_active_start",
		"stadium_spark_cycle_index",
		"stadium_spark_direction",
	]:
		_expect(source.find("var %s:" % mirror) >= 0, "%s compatibility property should remain" % mirror)
	_expect(_function_body(source, "func reset(").find("_presentation_state.reset()") >= 0, "playfield reset should delegate to presentation state")
	_expect(_function_body(source, "func _tick_delta(").find("_presentation_state.tick_delta()") >= 0, "tick facade should delegate to presentation state")
	_expect(_function_body(source, "func _update_particles(").find("_presentation_state.update_particles") >= 0, "particle update facade should delegate to presentation state")
	var flow_body := _function_body(source, "func _draw_stadium_electric_flow(")
	_expect(flow_body.find("_presentation_state.advance_stadium_spark()") >= 0, "stadium draw should delegate spark lifecycle mutation to presentation state")
	_expect(flow_body.find("stadium_spark_active_start =") == -1 and flow_body.find("stadium_spark_next_time =") == -1, "stadium draw should not mutate spark lifecycle fields directly")


func _function_body(source: String, signature: String) -> String:
	return SourceContractFunctionBody.extract(source, signature)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
