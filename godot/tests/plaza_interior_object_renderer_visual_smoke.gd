extends SceneTree

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const PlazaInteriorObjectRenderer := preload("res://scripts/plaza/plaza_interior_object_renderer.gd")
const PlazaShopClickFxRenderer := preload("res://scripts/plaza/plaza_shop_click_fx_renderer.gd")

const VIEWPORT_SIZE := Vector2i(760, 750)

var _failures: Array[String] = []


class RenderProbe:
	extends Node2D

	var additive_material := CanvasItemMaterial.new()
	var initial_material := CanvasItemMaterial.new()
	var animation_texture: GradientTexture2D
	var draw_count := 0
	var coin_frame_drawn := false
	var material_restored := false

	func _init() -> void:
		ImpactFlareTextureCache.prewarm()
		ImpactShockwaveTextureCache.prewarm()
		additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color(1.0, 0.72, 0.18, 1.0), Color(1.0, 0.24, 0.82, 1.0)])
		animation_texture = GradientTexture2D.new()
		animation_texture.gradient = gradient
		animation_texture.width = 250
		animation_texture.height = 250

	func _draw() -> void:
		draw_count += 1
		var font := ThemeDB.fallback_font
		PlazaInteriorObjectRenderer.draw_standard_object(self, font, {"kind": "capsule", "label": "훈련", "rect": Rect2(80.0, 190.0, 110.0, 120.0)}, 0.5, 0.3, true, 0.4, Color(0.3, 0.8, 1.0), 1.0, null)
		PlazaInteriorObjectRenderer.draw_featured_object(self, font, {"kind": "crystal", "label": "오늘의\n추천", "rect": Rect2(245.0, 190.0, 110.0, 120.0)}, 0.4, 0.2, 0.4, 1.0, animation_texture)
		PlazaInteriorObjectRenderer.draw_strewn_object(self, font, {"kind": "money_bundle", "label": "돈다발", "rect": Rect2(410.0, 225.0, 90.0, 62.0)}, 0.35, 0.2, 0.4, Color(0.3, 0.8, 1.0), 1.0, null, {}, additive_material, null, null)
		var aura_snapshot := {
			"backplate_rect": Rect2(530.0, 190.0, 130.0, 130.0),
			"backplate_color": Color(1.0, 0.72, 0.20, 0.35),
			"ring_rect": Rect2(542.0, 202.0, 106.0, 106.0),
			"ring_color": Color(1.0, 0.86, 0.36, 0.80),
			"ring_intensity": 0.8,
			"accent_rect": Rect2(552.0, 212.0, 86.0, 86.0),
			"accent_color": Color(1.0, 0.34, 0.82, 0.55),
			"accent_intensity": 0.6,
			"burst_visible": true,
			"burst_rect": Rect2(520.0, 180.0, 150.0, 150.0),
			"burst_color": Color(1.0, 0.82, 0.28, 0.42),
			"burst_ring_rect": Rect2(535.0, 195.0, 120.0, 120.0),
			"burst_ring_color": Color(1.0, 0.52, 0.92, 0.62),
			"burst_ring_intensity": 1.0,
		}
		material = initial_material
		PlazaInteriorObjectRenderer.draw_strewn_object(self, font, {"kind": "coin_pile", "label": "동전 더미", "rect": Rect2(550.0, 225.0, 86.0, 50.0)}, 0.5, 0.4, 0.4, Color(0.3, 0.8, 1.0), 1.0, null, aura_snapshot, additive_material, null, null)
		material_restored = material == initial_material
		PlazaShopClickFxRenderer.draw(self, {"kind": "gear"}, Rect2(190.0, 470.0, 90.0, 70.0), 0.45, 0.8, 1.1, 0.4, 1.0, null)
		coin_frame_drawn = PlazaShopClickFxRenderer.draw(self, {"kind": "coin_pile"}, Rect2(390.0, 450.0, 100.0, 80.0), 0.45, 0.8, 1.1, 0.4, 1.0, animation_texture)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var probe := RenderProbe.new()
	viewport.add_child(probe)
	probe.queue_redraw()
	for _frame_index in range(4):
		await process_frame
	_expect(probe.draw_count > 0, "object renderer should receive a live draw callback")
	_expect(probe.coin_frame_drawn, "coin click FX should draw its animation frame")
	_expect(probe.material_restored, "coin aura renderer should restore the caller's CanvasItem material")
	if _is_pixel_capture_available():
		var image := viewport.get_texture().get_image()
		_expect(image != null and not image.is_empty(), "object renderer should produce a readable viewport image")
		if image != null and not image.is_empty():
			_expect(_count_visible_pixels(image) > 12000, "object renderer should paint substantial object and FX surfaces")
	viewport.queue_free()
	if _failures.is_empty():
		print("plaza_interior_object_renderer_visual_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _is_pixel_capture_available() -> bool:
	return DisplayServer.get_name().to_lower() != "headless" and not OS.has_feature("headless")


func _count_visible_pixels(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.05:
				count += 1
	return count


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
