extends SceneTree

const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const Stage2RustleState := preload("res://scripts/stages/stage2/stage2_rustle_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_side_wall_band()
	_verify_rustle_mutation_helpers()
	_verify_background_delegates_rustle_state()

	if _failures.is_empty():
		print("stage2_rustle_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_side_wall_band() -> void:
	_expect(Stage2RustleState.is_bush_side_wall_hit(80.0, 750.0, 135.0), "rustle state should treat upper side-wall impacts as bush hits")
	_expect(Stage2RustleState.is_bush_side_wall_hit(700.0, 750.0, 135.0), "rustle state should treat lower side-wall impacts as bush hits")
	_expect(not Stage2RustleState.is_bush_side_wall_hit(375.0, 750.0, 135.0), "rustle state should ignore middle side-wall impacts")


func _verify_rustle_mutation_helpers() -> void:
	var bushes := [
		{"area": "player", "pos": Vector2(100.0, 700.0), "amount": 0.1, "angle": 0.0, "phase": 0.0},
		{"area": "boss", "pos": Vector2(100.0, 40.0), "amount": 0.0, "angle": 0.0, "phase": 0.0},
	]
	Stage2RustleState.trigger_bush_rustle(bushes, "player", 110.0, 18.0, true, 150.0, 8.0, 15.0)
	_expect(float((bushes[0] as Dictionary).get("amount", 0.0)) > 0.1, "rustle state should boost nearby matching bushes")
	_expect(_is_close(float((bushes[0] as Dictionary).get("angle", 0.0)), 0.60), "rustle state should set dash bush angle")
	_expect(float((bushes[1] as Dictionary).get("amount", 0.0)) == 0.0, "rustle state should ignore non-matching bush areas")

	var vines := [
		{"x": 100.0, "amount": 0.0, "angle": 1.0, "phase": 3.0},
		{"x": 500.0, "amount": 0.0, "angle": 0.0, "phase": 0.0},
	]
	Stage2RustleState.trigger_vine_rustle(vines, 110.0, -18.0, false, 120.0, 7.0, 12.0)
	_expect(float((vines[0] as Dictionary).get("amount", 0.0)) > 0.0, "rustle state should boost nearby vines")
	_expect(_is_close(float((vines[0] as Dictionary).get("angle", 0.0)), -0.38), "rustle state should set normal vine angle")
	_expect(float((vines[0] as Dictionary).get("phase", 1.0)) == 0.0, "rustle state should reset inactive vine phase on trigger")
	_expect(Stage2RustleState.has_active(bushes, vines), "rustle state should report active bushes or vines")
	Stage2RustleState.decay(bushes, vines, 1.0)
	_expect(not Stage2RustleState.has_active(bushes, vines), "rustle state should decay long-idle bushes and vines")
	_expect(float((bushes[0] as Dictionary).get("angle", 1.0)) == 0.0, "rustle state should clear bush angle after decay threshold")
	_expect(float((vines[0] as Dictionary).get("angle", 1.0)) == 0.0, "rustle state should clear vine angle after decay threshold")


func _verify_background_delegates_rustle_state() -> void:
	var background := Stage2PillarBackground.new()
	_expect(background._is_bush_side_wall_hit(80.0, 750.0), "background side-wall wrapper should delegate to rustle state")
	background.rustle_bushes = [
		{"area": "player", "pos": Vector2(100.0, 700.0), "amount": 0.0, "angle": 0.0, "phase": 0.0},
	]
	background.rustle_vines = [
		{"x": 100.0, "amount": 0.0, "angle": 0.0, "phase": 0.0},
	]
	background._trigger_bush_rustle("player", 110.0, 18.0, true)
	background._trigger_vine_rustle(110.0, 18.0, true)
	_expect(background._has_active_rustle(), "background rustle wrappers should delegate active mutation")
	background._decay_rustle(1.0)
	_expect(not background._has_active_rustle(), "background decay wrapper should delegate rustle decay")


func _is_close(actual: float, expected: float, tolerance: float = 0.001) -> bool:
	return abs(actual - expected) <= tolerance


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
