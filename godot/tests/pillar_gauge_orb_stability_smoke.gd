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
	var liquid_source := FileAccess.get_file_as_string("res://scripts/hud/pillar_liquid_drawer.gd")
	_expect(liquid_source.find("LIQUID_FAST_LOD_SCALE") >= 0, "pillar liquid should expose a fast LOD threshold")
	_expect(liquid_source.find("_draw_fast_lod_liquid") >= 0, "pillar liquid should keep the fast LOD fill path")
	_expect(
		_function_body(liquid_source, "func draw_pillar_liquid_fill(").find("_draw_fast_lod_liquid") >= 0,
		"pillar liquid draw should route low-quality fills through the fast LOD path"
	)

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


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)
