extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemHudVisuals := preload("res://scripts/hud/active_item_hud_visuals.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_staged_catalog_icon_prewarm()
	_verify_monolithic_catalog_icon_prewarm()

	if _failures.is_empty():
		print("active_item_hud_visuals_prewarm_step_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_staged_catalog_icon_prewarm() -> void:
	var visuals := ActiveItemHudVisuals.new()
	var complete_first_step: bool = bool(visuals.prewarm_catalog_icons_step())
	_expect(not complete_first_step, "active item HUD icon prewarm should expose a staged first step")
	_expect(visuals.texture_cache.size() <= ActiveItemHudVisuals.CATALOG_ICON_PREWARM_BATCH_SIZE, "first staged icon prewarm step should not load the whole catalog")

	var guard := 0
	while not bool(visuals.prewarm_catalog_icons_step()) and guard < 80:
		guard += 1
	_expect(guard < 80, "active item HUD staged icon prewarm should finish within a bounded number of steps")
	_expect(visuals.get("_active_catalog_prewarm") == null, "active item HUD prewarm should release the active catalog after completion")
	_expect(visuals.get("_mythic_catalog_prewarm") == null, "active item HUD prewarm should release the mythic catalog after completion")
	_expect(_has_cached_catalog_icon(visuals, ActiveItemCatalog.new(), "grenade"), "staged prewarm should cache active field item icons")
	_expect(_has_cached_catalog_icon(visuals, ActiveItemCatalog.new(), "ammo_box"), "staged prewarm should cache extra active item icons")
	_expect(_has_cached_catalog_icon(visuals, MythicItemCatalog.new(), "dowsing_pendulum"), "staged prewarm should cache passive field item icons")
	_expect(_has_cached_catalog_icon(visuals, MythicItemCatalog.new(), "megingjord"), "staged prewarm should cache mythic field item icons")


func _verify_monolithic_catalog_icon_prewarm() -> void:
	var visuals := ActiveItemHudVisuals.new()
	visuals.prewarm_catalog_icons()
	_expect(_has_cached_catalog_icon(visuals, ActiveItemCatalog.new(), "grenade"), "monolithic prewarm should still cache active field item icons")
	_expect(_has_cached_catalog_icon(visuals, MythicItemCatalog.new(), "megingjord"), "monolithic prewarm should still cache mythic field item icons")


func _has_cached_catalog_icon(visuals: Object, catalog: Object, item_name: String) -> bool:
	var item_data: Dictionary = catalog.build_item_by_name(item_name)
	var path: String = str(item_data.get("icon_path", ""))
	return path != "" and visuals.texture_cache.has(path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
