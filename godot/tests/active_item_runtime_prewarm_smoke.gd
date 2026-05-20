extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const ActiveItemHudVisuals := preload("res://scripts/hud/active_item_hud_visuals.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_runtime_prewarm_loads_item_draw_assets()

	if _failures.is_empty():
		print("active_item_runtime_prewarm_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_runtime_prewarm_loads_item_draw_assets() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	var visuals: Object = ActiveItemHudVisuals.new()

	runtime.prewarm_assets(visuals)
	_expect(visuals.texture_cache.size() >= 7, "active item prewarm should cache installed field item icons")
	_expect(runtime.render_facade.field_renderer.portal_sheet_texture != null, "field prewarm should load portal sheet")
	_expect(runtime.render_facade.field_renderer.unknown_item_sheet_texture != null, "field prewarm should load unknown item sheet")
	_expect(runtime.render_facade.throw_renderer.grenade_icon_texture != null, "throw prewarm should load throw icons")
	_expect(runtime.render_facade.effect_renderer.long_boost_icon_texture != null, "effect prewarm should load timer icons")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
