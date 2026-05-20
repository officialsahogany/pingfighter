extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemEffectRenderer := preload("res://scripts/items/active_item_effect_renderer.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")


class FakeVisuals:
	var calls := 0
	var texture := ImageTexture.create_from_image(Image.create_empty(4, 4, false, Image.FORMAT_RGBA8))

	func get_icon_texture(_item_data: Dictionary) -> Texture2D:
		calls += 1
		return texture


class FakeRegistry:
	var visuals := FakeVisuals.new()

	func get_instance(key: String) -> Object:
		if key == "active_item_hud_visuals":
			return visuals
		return null


var _failures: Array[String] = []


func _init() -> void:
	_verify_pickup_text_prewarm()
	_verify_pickup_icon_cache()
	_verify_pickup_effect_direct_icon()

	if _failures.is_empty():
		print("active_item_effect_renderer_cache_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_pickup_text_prewarm() -> void:
	var renderer := ActiveItemEffectRenderer.new()
	renderer.prewarm_assets()
	_expect(renderer._text_size_cache.size() >= ActiveItemCatalog.FIELD_SPAWN_ORDER.size(), "pickup text prewarm should cache field item display labels")
	_expect(renderer._text_size_cache.has("%d:%s" % [ActiveItemEffectRenderer.PICKUP_NOTICE_FONT_SIZE, ActiveItemEffectRenderer.PICKUP_NOTICE_TEXT]), "pickup text prewarm should cache the notice label")
	var mythic_catalog: Object = MythicItemCatalog.new()
	_expect(_has_cached_pickup_label(renderer, mythic_catalog, "dowsing_pendulum"), "pickup text prewarm should cache passive field item display labels")
	_expect(_has_cached_pickup_label(renderer, mythic_catalog, "megingjord"), "pickup text prewarm should cache mythic field item display labels")
	var font: Font = renderer._get_font()
	var text_size: Vector2 = renderer._get_text_size(font, "banana", ActiveItemEffectRenderer.PICKUP_DISPLAY_FONT_SIZE)
	var cache_size: int = renderer._text_size_cache.size()
	_expect(text_size.x >= 0.0, "pickup text size should be measurable")
	renderer._get_text_size(font, "banana", ActiveItemEffectRenderer.PICKUP_DISPLAY_FONT_SIZE)
	_expect(renderer._text_size_cache.size() == cache_size, "repeated pickup text sizing should reuse cache")


func _verify_pickup_icon_cache() -> void:
	var renderer := ActiveItemEffectRenderer.new()
	var registry := FakeRegistry.new()
	var item_data := {
		"name": "banana",
		"icon_path": "res://assets/sprites/items/banana.png",
	}
	var first_texture: Texture2D = renderer._get_item_icon_texture(item_data, registry)
	var second_texture: Texture2D = renderer._get_item_icon_texture(item_data, registry)
	_expect(first_texture != null and second_texture == first_texture, "pickup icon lookup should return cached texture")
	_expect(registry.visuals.calls == 1, "pickup icon cache should avoid repeated HUD visual lookups")


func _verify_pickup_effect_direct_icon() -> void:
	var renderer := ActiveItemEffectRenderer.new()
	var registry := FakeRegistry.new()
	var texture := ImageTexture.create_from_image(Image.create_empty(4, 4, false, Image.FORMAT_RGBA8))
	var pickup_effect := {
		"icon_texture": texture,
		"item_data": {
			"name": "banana",
			"icon_path": "res://assets/sprites/items/banana.png",
		},
	}
	_expect(renderer._get_pickup_icon_texture(pickup_effect, registry) == texture, "pickup effect should use frozen icon texture before registry lookup")
	_expect(registry.visuals.calls == 0, "direct pickup icon should avoid HUD visual lookup")


func _has_cached_pickup_label(renderer: Object, catalog: Object, item_name: String) -> bool:
	var display_name: String = catalog.get_display_name(item_name)
	var cache_key := "%d:%s" % [ActiveItemEffectRenderer.PICKUP_DISPLAY_FONT_SIZE, display_name]
	return renderer._text_size_cache.has(cache_key)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
