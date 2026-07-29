extends SceneTree

const Fixture := preload("res://tests/battle_lingpet_input_production_fixture.gd")

var _failures: Array[String] = []


func _init() -> void:
	var helper := Fixture.new()
	var fixture := helper.build()
	var runtime: Object = fixture.get("runtime")
	var overlay: Object = fixture.get("overlay")
	var terminal: Object = fixture.get("terminal")
	terminal.active = true
	runtime.hatch_break_active = true
	helper.dispatch(fixture, Fixture.key_event(KEY_A))
	_expect(overlay.handle_count == 0, "hatch-break input must be swallowed before overlay input")
	_expect(terminal.handle_count == 0, "hatch-break input must be swallowed before terminal input")
	runtime.hatch_break_active = false
	runtime.acquire_active = true
	helper.dispatch(fixture, Fixture.key_event(KEY_A))
	_expect(overlay.handle_count == 1, "acquisition cut-in input must reach its overlay exactly once")
	_expect(terminal.handle_count == 0, "acquisition cut-in must keep priority over terminal input")
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("battle_lingpet_priority_cutin_preservation_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
