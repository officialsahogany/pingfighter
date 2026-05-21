extends SceneTree

const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const Stage2RockFragmentMotionState := preload("res://scripts/stages/stage2/stage2_rock_fragment_motion_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_fragment_motion_updates_payload()
	_verify_fragment_bounces_at_floor()
	_verify_fragment_array_compaction()
	_verify_background_delegates_fragment_motion()

	if _failures.is_empty():
		print("stage2_rock_fragment_motion_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_fragment_motion_updates_payload() -> void:
	var fragment := {
		"life": 2.0,
		"pos": Vector2(10.0, 20.0),
		"vel": Vector2(30.0, 40.0),
		"gravity": 180.0,
		"rotation": 0.25,
		"spin": 1.5,
	}
	var alive := Stage2RockFragmentMotionState.update_fragment(fragment, 0.5, 700.0)
	_expect(alive, "rock fragment motion should keep live fragments")
	_expect(Vector2(fragment.get("pos", Vector2.ZERO)).y > 20.0, "rock fragment motion should advance y position")
	_expect(Vector2(fragment.get("vel", Vector2.ZERO)).y > 40.0, "rock fragment motion should apply gravity")
	_expect(is_equal_approx(float(fragment.get("life", 0.0)), 1.5), "rock fragment motion should decrement life")
	_expect(is_equal_approx(float(fragment.get("rotation", 0.0)), 1.0), "rock fragment motion should advance rotation")


func _verify_fragment_bounces_at_floor() -> void:
	var fragment := {
		"life": 2.0,
		"pos": Vector2(100.0, 695.0),
		"vel": Vector2(10.0, 40.0),
		"gravity": 0.0,
		"bounce": 0.5,
	}
	var alive := Stage2RockFragmentMotionState.update_fragment(fragment, 0.5, 700.0)
	_expect(alive, "rock fragment motion should keep bounced fragments")
	_expect(is_equal_approx(Vector2(fragment.get("pos", Vector2.ZERO)).y, 700.0), "rock fragment motion should clamp floor y")
	_expect(Vector2(fragment.get("vel", Vector2.ZERO)).y < 0.0, "rock fragment motion should bounce y velocity")
	_expect(is_equal_approx(Vector2(fragment.get("vel", Vector2.ZERO)).x, 8.0), "rock fragment motion should damp x velocity")


func _verify_fragment_array_compaction() -> void:
	var fragments := [
		{"life": 2.0, "pos": Vector2.ZERO, "vel": Vector2.ZERO},
		{"life": 0.2, "pos": Vector2.ZERO, "vel": Vector2.ZERO},
	]
	Stage2RockFragmentMotionState.update_fragments(fragments, 0.5)
	_expect(fragments.size() == 1, "rock fragment motion should compact expired fragments")
	_expect(is_equal_approx(float((fragments[0] as Dictionary).get("life", 0.0)), 1.5), "rock fragment motion should keep updated survivors")


func _verify_background_delegates_fragment_motion() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(
		source.find("Stage2RockFragmentMotionState.update_fragments") >= 0,
		"Stage 2 background source should delegate rock fragment motion"
	)
	var background := Stage2PillarBackground.new()
	background.rock_fragments = [
		{"life": 2.0, "pos": Vector2(10.0, 20.0), "vel": Vector2(30.0, 40.0), "gravity": 180.0},
		{"life": 0.2, "pos": Vector2.ZERO, "vel": Vector2.ZERO},
	]
	background._update_rock_fragments(0.5)
	_expect(background.rock_fragments.size() == 1, "Stage 2 background should compact delegated fragments")
	_expect(
		Vector2((background.rock_fragments[0] as Dictionary).get("pos", Vector2.ZERO)).y > 20.0,
		"Stage 2 background should use delegated rock fragment motion"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
