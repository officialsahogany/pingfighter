extends SceneTree

const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const Stage2QuakeRockDropState := preload("res://scripts/stages/stage2/stage2_quake_rock_drop_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_timed_drop_lands()
	_verify_timed_drop_delay_waits()
	_verify_original_drop_lands()
	_verify_background_delegates_drop_state()

	if _failures.is_empty():
		print("stage2_quake_rock_drop_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_timed_drop_lands() -> void:
	var target_pos := Vector2(100.0, 120.0)
	var rock := {
		"pos": Vector2.ZERO,
		"start_pos": Vector2.ZERO,
		"target_pos": target_pos,
		"falling": true,
		"fall_timer": 0.1,
		"fall_total": 0.1,
		"drop_delay": 0.0,
	}
	var result: Dictionary = Stage2QuakeRockDropState.update_drop(rock, 0.1, target_pos, 0.34, 0.42)
	_expect(bool(result.get("landed", false)), "timed drop should report a landing")
	_expect(rock.get("pos", Vector2.ZERO) == target_pos, "timed drop should finish at target position")
	_expect(not bool(rock.get("falling", true)), "timed drop should stop falling when timer finishes")
	_expect(is_equal_approx(float(rock.get("flash", 0.0)), 0.34), "timed drop should raise land flash")


func _verify_timed_drop_delay_waits() -> void:
	var target_pos := Vector2(10.0, 20.0)
	var rock := {
		"drop_delay": 0.2,
		"falling": true,
	}
	var result: Dictionary = Stage2QuakeRockDropState.update_drop(rock, 0.1, target_pos, 0.34, 0.42)
	_expect(not bool(result.get("landed", true)), "delayed timed drop should not land during delay")
	_expect(is_equal_approx(float(rock.get("drop_delay", 0.0)), 0.1), "timed drop should decrement delay")


func _verify_original_drop_lands() -> void:
	var target_pos := Vector2(50.0, 0.0)
	var rock := {
		"fall_y": -10.0,
		"falling": true,
		"fall_speed": 20.0,
		"gravity": 0.0,
		"max_bounces": 0,
		"target_pos": target_pos,
	}
	var result: Dictionary = Stage2QuakeRockDropState.step_original_drop(rock, target_pos, 1.0, 0.34)
	_expect(bool(result.get("landed", false)), "original drop should report a landing")
	_expect(not bool(rock.get("falling", true)), "original drop should stop falling after final bounce")
	_expect(rock.get("pos", Vector2.ZERO) == target_pos, "original drop should clamp to target position")
	_expect(is_equal_approx(float(rock.get("flash", 0.0)), 0.34), "original drop should raise land flash")


func _verify_background_delegates_drop_state() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(
		source.find("Stage2QuakeRockDropState.update_drop") >= 0,
		"Stage 2 background source should delegate quake rock drop state"
	)
	var target_pos := Vector2(20.0, 30.0)
	var background := Stage2PillarBackground.new()
	var rock := {
		"pos": Vector2.ZERO,
		"start_pos": Vector2.ZERO,
		"target_pos": target_pos,
		"falling": true,
		"fall_timer": 0.1,
		"fall_total": 0.1,
		"drop_delay": 0.0,
	}
	background._update_quake_rock_drop(rock, 0.1)
	_expect(not bool(rock.get("falling", true)), "Stage 2 background should use delegated drop state")
	_expect(rock.get("pos", Vector2.ZERO) == target_pos, "Stage 2 background drop should finish at target")
	_expect(background.leaf_particles.size() > 0, "Stage 2 background should still spawn landing leaves")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
