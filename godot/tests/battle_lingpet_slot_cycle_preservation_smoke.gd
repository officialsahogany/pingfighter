extends SceneTree

const Fixture := preload("res://tests/battle_lingpet_input_production_fixture.gd")

var _failures: Array[String] = []


func _init() -> void:
	var helper := Fixture.new()
	var fixture := helper.build()
	var runtime: Object = fixture.get("runtime")
	helper.dispatch(fixture, Fixture.key_event(KEY_L))
	helper.dispatch(fixture, Fixture.key_event(KEY_L, true))
	_expect(
		runtime.cycle_directions == [1, -1],
		"production input must preserve L forward and Shift+L backward cycling"
	)
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("battle_lingpet_slot_cycle_preservation_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
