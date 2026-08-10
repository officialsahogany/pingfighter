extends SceneTree

const PlazaInteriorChromeProjection := preload("res://scripts/plaza/plaza_interior_chrome_projection.gd")
const PlazaInteriorChromeRenderer := preload("res://scripts/plaza/plaza_interior_chrome_renderer.gd")

const VIEWPORT_SIZE := Vector2i(760, 750)

var _failures: Array[String] = []


class RenderProbe:
	extends Node2D

	var draw_count := 0
	var npc_texture: GradientTexture2D

	func _init() -> void:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color(0.18, 0.78, 1.0, 1.0), Color(0.96, 0.24, 0.84, 1.0)])
		npc_texture = GradientTexture2D.new()
		npc_texture.gradient = gradient
		npc_texture.width = 100
		npc_texture.height = 200

	func _draw() -> void:
		draw_count += 1
		var font := ThemeDB.fallback_font
		var texture_size := npc_texture.get_size()
		PlazaInteriorChromeRenderer.draw_topview_npc(self, PlazaInteriorChromeProjection.build_topview_npc_snapshot(true, texture_size, 1.0), npc_texture)
		PlazaInteriorChromeRenderer.draw_title(self, font, PlazaInteriorChromeProjection.build_title_snapshot("상점", "좋은 물건", 321, 1.0))
		PlazaInteriorChromeRenderer.draw_npc(self, font, PlazaInteriorChromeProjection.build_npc_snapshot("미카", "어서 와", Color(0.3, 0.7, 1.0), false, Vector2.ZERO, 1.0), null)
		PlazaInteriorChromeRenderer.draw_speech_bubble(self, font, PlazaInteriorChromeProjection.build_speech_bubble_snapshot("골라 봐|좋은 물건이야", 1.0))
		PlazaInteriorChromeRenderer.draw_object_panel(self, font, PlazaInteriorChromeProjection.build_object_panel_snapshot({"label": "합성"}, Color(0.3, 0.7, 1.0), 7, "준비 완료", 1.0), 1.0)


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
	_expect(probe.draw_count > 0, "interior chrome renderer should receive a live draw callback")
	if _is_pixel_capture_available():
		var image := viewport.get_texture().get_image()
		_expect(image != null and not image.is_empty(), "interior chrome renderer should produce a readable viewport image")
		if image != null and not image.is_empty():
			_expect(_count_visible_pixels(image) > 50000, "interior chrome renderer should paint substantial UI surfaces")
	else:
		var snapshot := PlazaInteriorChromeProjection.build_object_panel_snapshot({"label": "합성"}, Color.WHITE, 1, "", 1.0)
		_expect(snapshot.get("rect", Rect2()).has_area(), "headless renderer contract should retain object-panel geometry")
	viewport.queue_free()
	if _failures.is_empty():
		print("plaza_interior_chrome_renderer_visual_smoke: ok")
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
