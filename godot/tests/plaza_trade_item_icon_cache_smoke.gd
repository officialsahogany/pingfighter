extends SceneTree

const PlazaTradeItemIconCache := preload("res://scripts/plaza/plaza_trade_item_icon_cache.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


func _init() -> void:
	var cache := PlazaTradeItemIconCache.new()
	var valid_item := {"icon_path": "res://icon.svg"}
	var missing_item := {"icon_path": "res://.tmp/definitely_missing_plaza_trade_icon.png"}
	_expect(cache.get_texture(valid_item) == null, "texture lookup should not load before prewarm")
	cache.prewarm_inventories(
		[valid_item, valid_item.duplicate(true), {"icon_path": "C:/unsafe.png"}, "invalid"],
		[missing_item]
	)
	_expect(cache.has_cached_path("res://icon.svg"), "valid icon should be cached")
	_expect(cache.get_texture(valid_item) != null, "valid cached icon should resolve as Texture2D")
	_expect(cache.has_cached_path("res://.tmp/definitely_missing_plaza_trade_icon.png"), "missing resource path should be negatively cached")
	_expect(cache.get_texture(missing_item) == null, "negative cache should return null")
	_expect(cache.get_cached_count() == 2, "duplicates and non-resource paths should not add cache entries")
	cache.prewarm_inventories([valid_item, missing_item], [])
	_expect(cache.get_cached_count() == 2, "repeat prewarm should reuse success and failure cache entries")
	cache.reset()
	_expect(cache.get_cached_count() == 0, "reset should clear local cache")
	ProjectResourceLoader.clear_caches()

	if _failures.is_empty():
		print("plaza_trade_item_icon_cache_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
