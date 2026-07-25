extends SceneTree

const PlazaInteriorObjectHoverState := preload("res://scripts/plaza/plaza_interior_object_hover_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	var state := PlazaInteriorObjectHoverState.new()
	var specs: Array[Dictionary] = [
		{"id": "bank_deposit"},
		{"id": "shop_strewn_coin_pile"},
		{"label": "missing id"},
	]
	state.ensure_specs(specs)
	_expect(state.get_tracked_count() == 2, "ensure_specs should register nonblank ids once")
	state.ensure_specs(specs)
	_expect(state.get_tracked_count() == 2, "ensure_specs should ignore duplicates")
	_expect_close(state.get_amount("unknown"), 0.0, "unknown amount")

	_expect(state.set_hovered("bank_deposit"), "new hover target should report a change")
	_expect(not state.set_hovered("bank_deposit"), "same hover target should not report a change")
	_expect(state.advance(specs, 0.05, 10.0), "hover amount should advance")
	_expect_close(state.get_amount("bank_deposit"), 0.5, "half hover amount")
	_expect(state.is_visible("bank_deposit"), "advanced hover should be visible")
	_expect(state.advance(specs, 1.0, 10.0), "hover amount should reach its target")
	_expect_close(state.get_amount("bank_deposit"), 1.0, "clamped hover amount")
	_expect(not state.advance(specs, 1.0, 10.0), "settled hover should not report a change")

	_expect(state.set_hovered("shop_strewn_coin_pile"), "cross-object hover should report a change")
	_expect(state.advance(specs, 0.025, 10.0), "cross-object amounts should animate")
	_expect_close(state.get_amount("bank_deposit"), 0.75, "previous hover decay")
	_expect_close(state.get_amount("shop_strewn_coin_pile"), 0.25, "next hover rise")

	state.reset()
	_expect(state.hovered_object_id == "", "reset should clear target")
	_expect(state.get_tracked_count() == 0, "reset should clear amounts")

	if _failures.is_empty():
		print("plaza_interior_object_hover_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _expect_close(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s: expected %.4f, got %.4f" % [label, expected, actual])
