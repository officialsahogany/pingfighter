extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemBrickWallEffectRenderer := preload("res://scripts/items/active_item_brick_wall_effect_renderer.gd")
const ActiveItemEffectRenderer := preload("res://scripts/items/active_item_effect_renderer.gd")
const ActiveItemTimerGaugeRenderer := preload("res://scripts/items/active_item_timer_gauge_renderer.gd")
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
	_verify_brick_wall_variant_sheet()
	_verify_brick_wall_renderer_split()
	_verify_timer_gauge_renderer_split()

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


func _verify_brick_wall_variant_sheet() -> void:
	var renderer := ActiveItemEffectRenderer.new()
	var brick_renderer := ActiveItemBrickWallEffectRenderer.new()
	var texture: Texture2D = renderer._get_brick_wall_variant_sheet_texture()
	var brick_texture: Texture2D = brick_renderer.get_brick_wall_variant_sheet_texture()
	_expect(texture != null, "brick wall variant sheet should load")
	_expect(brick_texture != null, "focused Brick Wall renderer should load the variant sheet")
	if texture == null:
		return
	_expect(texture.get_width() == 1024, "brick wall variant sheet width should match normalized 4x2 sheet")
	_expect(texture.get_height() == 128, "brick wall variant sheet height should match normalized 4x2 sheet")
	_expect(renderer._get_brick_wall_variant_index(Rect2(Vector2(12.0, 20.0), Vector2(80.0, 20.0)), 7) == 7, "brick wall visual variant should use stored variant")
	_expect(renderer._get_brick_wall_variant_source_rect(texture, 7) == Rect2(Vector2(768.0, 64.0), Vector2(256.0, 64.0)), "brick wall variant source rect should address the final cell")


func _verify_brick_wall_renderer_split() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/items/active_item_effect_renderer.gd")
	var brick_source := FileAccess.get_file_as_string("res://scripts/items/active_item_brick_wall_effect_renderer.gd")
	_expect(source.find("_brick_wall_renderer.draw_brick_wall_effect") >= 0, "effect renderer should delegate Brick Wall drawing to the focused renderer")
	_expect(source.find("func _draw_brick_wall(") < 0, "effect renderer should not keep inline Brick Wall wall drawing")
	_expect(brick_source.find("func draw_brick_wall_effect") >= 0, "Brick Wall renderer should own the field draw entry point")
	_expect(brick_source.find("func _draw_brick_cracks") >= 0, "Brick Wall renderer should own crack drawing")
	_expect(brick_source.find("func _draw_brick_install_gauge") >= 0, "Brick Wall renderer should own install gauge drawing")


func _verify_timer_gauge_renderer_split() -> void:
	var renderer := ActiveItemEffectRenderer.new()
	var timer_renderer := ActiveItemTimerGaugeRenderer.new()
	var source := FileAccess.get_file_as_string("res://scripts/items/active_item_effect_renderer.gd")
	var timer_source := FileAccess.get_file_as_string("res://scripts/items/active_item_timer_gauge_renderer.gd")
	_expect(source.find("_timer_gauge_renderer.draw_magnet_field_timer_gauge") >= 0, "effect renderer should delegate Magnet Field timer gauge")
	_expect(source.find("func _draw_magnet_field_timer_gauge") < 0, "effect renderer should not keep inline Magnet Field timer gauge")
	_expect(source.find("func _draw_long_boost_timer_gauge") < 0, "effect renderer should not keep inline Long Boost timer gauge")
	_expect(source.find("func _get_timer_bar_position") < 0, "effect renderer should not own timer stack positioning")
	_expect(timer_source.find("func draw_magnet_field_timer_gauge") >= 0, "timer gauge renderer should own Magnet Field gauge")
	_expect(timer_source.find("func draw_holy_barrier_timer_gauge") >= 0, "timer gauge renderer should own Holy Barrier gauge")
	_expect(timer_source.find("func draw_dash_boost_timer_gauge") >= 0, "timer gauge renderer should own Dash Boost gauge")
	_expect(timer_source.find("func draw_vitamin_pill_timer_gauge") >= 0, "timer gauge renderer should own Vitamin Pill gauge")
	_expect(timer_source.find("func draw_strange_vial_timer_gauge") >= 0, "timer gauge renderer should own Strange Vial gauge")
	_expect(timer_source.find("func draw_long_boost_timer_gauge") >= 0, "timer gauge renderer should own Long Boost gauge")
	_expect(timer_source.find("func _get_timer_bar_position") >= 0, "timer gauge renderer should own timer stack positioning")
	_expect(timer_renderer.get_long_boost_icon_texture() != null, "focused timer gauge renderer should load long boost icon")
	_expect(renderer._get_long_boost_icon_texture() != null, "effect renderer compatibility wrapper should load long boost icon")


func _has_cached_pickup_label(renderer: Object, catalog: Object, item_name: String) -> bool:
	var display_name: String = catalog.get_display_name(item_name)
	var cache_key := "%d:%s" % [ActiveItemEffectRenderer.PICKUP_DISPLAY_FONT_SIZE, display_name]
	return renderer._text_size_cache.has(cache_key)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
