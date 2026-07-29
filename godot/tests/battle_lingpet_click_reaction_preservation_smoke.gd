extends SceneTree

const Fixture := preload("res://tests/battle_lingpet_input_production_fixture.gd")

var _failures: Array[String] = []


func _init() -> void:
	var helper := Fixture.new()
	var fixture := helper.build()
	var runtime: Object = fixture.get("runtime")
	var owner: Object = fixture.get("owner")
	helper.dispatch(fixture, Fixture.click_event(Vector2(510.0, 320.0)))
	_expect(
		runtime.click_positions == [Vector2(250.0, 245.0)],
		"production input must convert the click and start one guardian reaction"
	)
	_expect(runtime.cycle_directions.is_empty(), "guardian click must not enter slot cycling")
	_expect(owner.redraw_count == 1, "accepted guardian click must request one redraw")
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("battle_lingpet_click_reaction_preservation_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
