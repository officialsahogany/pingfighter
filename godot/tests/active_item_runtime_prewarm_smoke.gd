extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const ActiveItemHudVisuals := preload("res://scripts/hud/active_item_hud_visuals.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")

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
	var mythic_catalog: Object = MythicItemCatalog.new()
	_expect(_has_cached_catalog_icon(visuals, mythic_catalog, "dowsing_pendulum"), "active item prewarm should cache passive field item icons")
	_expect(_has_cached_catalog_icon(visuals, mythic_catalog, "megingjord"), "active item prewarm should cache mythic field item icons")
	_expect(runtime.render_facade.field_renderer.portal_sheet_texture != null, "field prewarm should load portal sheet")
	_expect(runtime.render_facade.field_renderer.unknown_item_sheet_texture != null, "field prewarm should load unknown item sheet")
	_expect(runtime.render_facade.throw_renderer.grenade_icon_texture != null, "throw prewarm should load throw icons")
	_expect(runtime.render_facade.effect_renderer.long_boost_icon_texture != null, "effect prewarm should load timer icons")
	_expect(runtime.render_facade.effect_renderer.brick_wall_variant_sheet_texture != null, "effect prewarm should load Brick Wall variant sheet")


func _has_cached_catalog_icon(visuals: Object, catalog: Object, item_name: String) -> bool:
	var item_data: Dictionary = catalog.build_item_by_name(item_name)
	var path: String = str(item_data.get("icon_path", ""))
	return path != "" and visuals.texture_cache.has(path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
