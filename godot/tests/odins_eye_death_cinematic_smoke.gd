extends SceneTree

const OdinsEyeState := preload("res://scripts/items/odins_eye_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_death_cinematic_state_contract()

	if _failures.is_empty():
		print("odins_eye_death_cinematic_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_death_cinematic_state_contract() -> void:
	var state: Object = OdinsEyeState.new()
	state.set_equipped(true)
	state.revival_used = true
	state.penalty_active = true
	state.begin_death_sequence("round")

	_expect(str(state.get_death_phase()) == "pre_explosion", "death should begin in pre-explosion")
	_expect_close(float(state.get_death_overall_progress()), 0.0, "death progress should begin at zero")
	_expect_close(float(state.get_death_phase_progress()), 0.0, "death phase progress should begin at zero")
	_expect_close(float(state.get_death_energy_buildup()), 0.0, "death buildup should begin at zero")
	_expect(not state.consume_death_explosion_edge(), "explosion edge should not be armed at death start")
	_expect(not state.consume_disintegration_edge(), "disintegration edge should not be armed at death start")
	_expect(not state.should_hide_player_paddle(), "paddle should remain visible at death start")

	state.update(0.99)
	_expect(str(state.get_death_phase()) == "pre_explosion", "death should stay in pre-explosion before 0.40")
	_expect(float(state.get_death_overall_progress()) < 0.40, "death should not cross explosion before 0.40")
	_expect(not state.consume_death_explosion_edge(), "explosion edge should not fire before 0.40")
	var previous_progress: float = float(state.get_death_overall_progress())

	state.update(0.02)
	_expect(str(state.get_death_phase()) == "explosion", "death should enter explosion at 0.40")
	_expect(float(state.get_death_overall_progress()) > previous_progress, "death progress should be monotonic")
	_expect(state.consume_death_explosion_edge(), "explosion edge should fire exactly once at 0.40")
	_expect(not state.consume_death_explosion_edge(), "explosion edge should be one-shot")
	_expect(not state.consume_disintegration_edge(), "disintegration edge should not fire at explosion start")
	_expect_close(float(state.get_death_energy_buildup()), 1.0, "buildup should stay full after pre-explosion")
	_expect(float(state.get_death_shake_intensity()) > 0.0, "explosion should expose shake intensity")

	state.update(0.68)
	_expect(str(state.get_death_phase()) == "explosion", "death should stay in explosion before 0.68")
	_expect(float(state.get_death_overall_progress()) < 0.68, "death should not cross disintegration before 0.68")
	_expect(not state.consume_disintegration_edge(), "disintegration edge should not fire before 0.68")

	state.update(0.03)
	_expect(str(state.get_death_phase()) == "disintegrate", "death should enter disintegration at 0.68")
	_expect(state.consume_disintegration_edge(), "disintegration edge should fire exactly once at 0.68")
	_expect(not state.consume_disintegration_edge(), "disintegration edge should be one-shot")
	_expect(float(state.get_death_disintegrate_progress()) > 0.0, "disintegration progress should start after 0.68")
	_expect(not state.should_hide_player_paddle(), "early disintegration should not hide the paddle")

	state.update(0.48)
	var context: Dictionary = state.get_context()
	_expect(str(context.get("death_phase", "")) == "disintegrate", "context should expose death phase")
	_expect(float(context.get("death_disintegrate_progress", 0.0)) > 0.6, "context should expose disintegration progress")
	_expect(bool(context.get("hide_player_paddle", false)), "late disintegration should request paddle hide")
	_expect(state.should_hide_player_paddle(), "late disintegration should keep paddle hide latched")

	state.update(0.29)
	_expect(not state.consume_death_finalize_ready(), "death should not finalize before 2.5s")
	_expect(state.is_death_animation_active(), "death should remain active before 2.5s")

	state.update(0.02)
	_expect_close(float(state.get_death_overall_progress()), 1.0, "death progress should report complete at finalize")
	_expect(state.consume_death_finalize_ready(), "death finalize edge should fire at 2.5s")
	_expect(not state.consume_death_finalize_ready(), "death finalize edge should be one-shot")
	_expect(not state.is_death_animation_active(), "death animation should stop after finalize")
	_expect(not bool(state.penalty_active), "death finalize should clear penalty without clearing used state")

	state.clear_after_death()
	_expect_close(float(state.get_death_overall_progress()), 0.0, "death clear should reset progress")
	_expect(str(state.get_death_phase()) == "", "death clear should reset phase")
	_expect(not state.should_hide_player_paddle(), "death clear should reset paddle hide latch")


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	_expect(abs(actual - expected) <= tolerance, "%s (got %.4f, expected %.4f)" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
