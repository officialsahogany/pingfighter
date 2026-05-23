extends SceneTree

const MonkeyBlessingDeliveryState := preload("res://scripts/characters/monkey_blessing_delivery_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := MonkeyBlessingDeliveryState.new()
	_expect(state.has_method("prewarm_assets_step"), "Monkey Blessing delivery state should expose staged asset prewarm")
	_expect(not bool(state.prewarm_assets_step()), "Monkey Blessing delivery prewarm should stage the right-facing sheet first")
	_expect(bool(state.prewarm_assets_step()), "Monkey Blessing delivery prewarm should finish with the mirrored sheet")

	var renderer: Object = state.get("renderer")
	_expect(renderer != null, "Monkey Blessing delivery state should own its renderer")
	if renderer != null:
		_expect(bool(renderer.get("load_attempted")), "Monkey Blessing delivery prewarm should satisfy the lazy draw load gate")
		_expect(renderer.get("right_sheet") != null, "Monkey Blessing delivery prewarm should load the right-facing sheet")
		_expect(renderer.get("left_sheet") != null, "Monkey Blessing delivery prewarm should load the mirrored sheet")

	if _failures.is_empty():
		print("monkey_blessing_delivery_prewarm_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
