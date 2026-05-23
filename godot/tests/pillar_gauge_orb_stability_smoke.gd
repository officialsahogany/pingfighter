extends SceneTree

const PillarGaugeOrbRenderer := preload("res://scripts/hud/pillar_gauge_orb_renderer.gd")
const PillarLiquidDrawer := preload("res://scripts/hud/pillar_liquid_drawer.gd")

var _failures: Array[String] = []


func _init() -> void:
	var gauge_renderer := PillarGaugeOrbRenderer.new()
	var initial_ratio: float = gauge_renderer._update_display_ratio(0.90, 10.0)
	_expect(is_equal_approx(initial_ratio, 0.90), "gauge display should initialize from the current ratio")

	var full_ratio: float = gauge_renderer._update_display_ratio(1.0, 10.016)
	_expect(is_equal_approx(full_ratio, 1.0), "full gauge display should snap to stable full instead of lingering below max")

	var liquid_drawer := PillarLiquidDrawer.new()
	_expect(liquid_drawer._is_stable_full_fill_ratio(1.0), "full liquid should use the stable non-animated fill")
	_expect(liquid_drawer._is_stable_full_fill_ratio(0.999), "near-full liquid should use the stable non-animated fill")
	_expect(not liquid_drawer._is_stable_full_fill_ratio(0.998), "non-full liquid should keep the normal animated fill")

	if _failures.is_empty():
		print("pillar_gauge_orb_stability_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
