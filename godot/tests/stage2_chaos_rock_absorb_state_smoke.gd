extends SceneTree

const Stage2ChaosRockAbsorbState := preload("res://scripts/stages/stage2/stage2_chaos_rock_absorb_state.gd")
const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_absorb_step_moves_rock()
	_verify_absorb_step_marks_destroyed()
	_verify_background_delegates_chaos_absorb_step()

	if _failures.is_empty():
		print("stage2_chaos_rock_absorb_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_absorb_step_moves_rock() -> void:
	var rock := {
		"chaos_spin_dir": 1.0,
		"rotation": 0.0,
		"phase": 0.0,
	}
	var result: Dictionary = Stage2ChaosRockAbsorbState.step_absorbing_rock(
		rock,
		Vector2(100.0, 0.0),
		Vector2.ZERO,
		1.0,
		14.0,
		0.22,
		8.0,
		4.0,
		22.0,
		460.0,
		1.8
	)
	_expect(not bool(result.get("destroyed", true)), "chaos rock absorb state should keep distant rocks alive")
	_expect(bool(result.get("moved", false)), "chaos rock absorb state should report movement")
	_expect(Vector2(result.get("center", Vector2.ZERO)).length() < 100.0, "chaos rock absorb state should pull rock inward")
	_expect(float(rock.get("rotation", 0.0)) > 0.0, "chaos rock absorb state should advance rotation")
	_expect(float(rock.get("phase", 0.0)) > 0.0, "chaos rock absorb state should advance phase")


func _verify_absorb_step_marks_destroyed() -> void:
	var rock := {
		"chaos_spin_dir": 1.0,
	}
	var result: Dictionary = Stage2ChaosRockAbsorbState.step_absorbing_rock(
		rock,
		Vector2(5.0, 0.0),
		Vector2.ZERO,
		1.0,
		14.0,
		0.22,
		8.0,
		4.0,
		22.0,
		460.0,
		1.8
	)
	_expect(bool(result.get("destroyed", false)), "chaos rock absorb state should destroy rocks inside threshold")
	_expect(not bool(result.get("moved", true)), "chaos rock absorb state should not move already-destroyed rocks")
	_expect(Vector2(result.get("center", Vector2.ZERO)) == Vector2(5.0, 0.0), "chaos rock absorb state should report destroy center")


func _verify_background_delegates_chaos_absorb_step() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(
		source.find("Stage2ChaosRockAbsorbState.step_absorbing_rock") >= 0,
		"Stage 2 background source should delegate chaos rock absorb motion"
	)
	var background := Stage2PillarBackground.new()
	var rock := {
		"id": 1,
		"pos": Vector2(100.0, 0.0),
		"target_pos": Vector2(100.0, 0.0),
		"radius": 20.0,
		"falling": false,
		"chaos_spin_dir": 1.0,
	}
	var destroyed := background._step_chaos_absorbing_rock(rock, Vector2.ZERO, 1.0, {}, {})
	_expect(not destroyed, "Stage 2 background should keep distant chaos-absorbing rock alive")
	_expect(Vector2(rock.get("target_pos", Vector2.ZERO)).length() < 100.0, "Stage 2 background should apply delegated chaos pull")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
