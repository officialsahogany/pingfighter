extends SceneTree

const PlazaInteriorRoomRenderer := preload("res://scripts/plaza/plaza_interior_room_renderer.gd")

const VIEWPORT_SIZE := Vector2i(760, 750)

var _failures: Array[String] = []


class RenderProbe:
	extends Node2D

	var backdrop_texture: GradientTexture2D
	var draw_count := 0
	var last_backdrop_drawn := false
	var use_backdrop := false

	func _init() -> void:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color(0.04, 0.14, 0.32, 1.0), Color(0.48, 0.08, 0.54, 1.0)])
		backdrop_texture = GradientTexture2D.new()
		backdrop_texture.gradient = gradient
		backdrop_texture.width = 1280
		backdrop_texture.height = 720

	func _draw() -> void:
		draw_count += 1
		last_backdrop_drawn = PlazaInteriorRoomRenderer.draw_room(
			self,
			ThemeDB.fallback_font,
			Vector2(VIEWPORT_SIZE),
			1.0,
			0.37,
			"bank",
			Color(0.24, 0.72, 1.0, 1.0),
			backdrop_texture if use_backdrop else null
		)


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
	_expect(probe.draw_count > 0, "room renderer should receive a live procedural draw callback")
	_expect(not probe.last_backdrop_drawn, "missing backdrop should route the procedural room")
	if _is_pixel_capture_available():
		var image := viewport.get_texture().get_image()
		_expect(image != null and not image.is_empty(), "procedural room should produce a readable viewport image")
		if image != null and not image.is_empty():
			_expect(_count_visible_pixels(image) > 400000, "procedural room should cover most of the viewport")
	probe.use_backdrop = true
	probe.queue_redraw()
	for _frame_index in range(4):
		await process_frame
	_expect(probe.last_backdrop_drawn, "valid backdrop should replace the procedural room")
	viewport.queue_free()
	if _failures.is_empty():
		print("plaza_interior_room_renderer_visual_smoke: ok")
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
