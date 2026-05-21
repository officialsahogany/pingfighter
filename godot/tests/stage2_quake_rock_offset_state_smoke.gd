extends SceneTree

const Stage2QuakeRockOffsetState := preload("res://scripts/stages/stage2/stage2_quake_rock_offset_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_active_quake_offsets_rock()
	_verify_inactive_quake_decays_offset()
	_verify_background_delegates_offset_state()

	if _failures.is_empty():
		print("stage2_quake_rock_offset_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_active_quake_offsets_rock() -> void:
	var rock := {
		"quake_offset": Vector2.ZERO,
		"radius": 44.0,
		"visual_radius": 55.0,
		"phase": 0.35,
		"falling": false,
	}
	Stage2QuakeRockOffsetState.update_offset(rock, 0.016, 0.5, 1.0)
	var offset: Vector2 = rock.get("quake_offset", Vector2.ZERO)
	_expect(offset.length() > 0.1, "active quake should write a visible rock offset")
	_expect(Stage2QuakeRockOffsetState.get_base_intensity(0.1) > Stage2QuakeRockOffsetState.get_base_intensity(0.9), "quake base intensity should fade out")


func _verify_inactive_quake_decays_offset() -> void:
	var rock := {
		"quake_offset": Vector2(0.1, 4.0),
	}
	Stage2QuakeRockOffsetState.update_offset(rock, 0.016, 0.0, 1.0)
	var offset: Vector2 = rock.get("quake_offset", Vector2.ZERO)
	_expect(is_equal_approx(offset.x, 0.0), "inactive quake should clamp tiny x offset to zero")
	_expect(offset.y > 0.0 and offset.y < 4.0, "inactive quake should decay visible y offset")


func _verify_background_delegates_offset_state() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(
		source.find("Stage2QuakeRockOffsetState.update_offset") >= 0,
		"Stage 2 background source should call quake-rock offset state directly"
	)
	_expect(
		source.find("func _update_quake_rock_offset") < 0,
		"Stage 2 background source should not keep the quake-rock offset pass-through wrapper"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
