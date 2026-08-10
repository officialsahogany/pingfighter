extends SceneTree

const PlazaBackgroundRenderer := preload("res://scripts/plaza/plaza_background_renderer.gd")

const VIEWPORT_SIZE := Vector2i(760, 750)

var _failures: Array[String] = []


class BackgroundProbe:
	extends Node2D

	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		PlazaBackgroundRenderer.draw(
			self,
			{},
			1140.0,
			Rect2(Vector2(1750.0, 596.0), Vector2(120.0, 92.0)),
			Vector2(760.0, 750.0),
			Vector2(760.0, 750.0),
			596.0,
			1.0,
			1234
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var probe := BackgroundProbe.new()
	viewport.add_child(probe)
	probe.queue_redraw()
	for _frame_index in range(4):
		await process_frame

	_expect(probe.draw_count > 0, "background renderer visual probe should receive a live draw callback")
	if _is_pixel_capture_available():
		var image := viewport.get_texture().get_image()
		_expect(image != null and not image.is_empty(), "background renderer should produce a readable viewport image")
		if image != null and not image.is_empty():
			_verify_anchor_pixels(image)
	else:
		_expect(PlazaBackgroundRenderer.supports_texture_key("far_sky"), "headless draw contract should retain the far-sky texture branch")
		_expect(PlazaBackgroundRenderer.supports_texture_key("ground_strip"), "headless draw contract should retain the ground-strip texture branch")

	viewport.queue_free()
	if _failures.is_empty():
		print("plaza_background_renderer_visual_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_anchor_pixels(image: Image) -> void:
	var sky := image.get_pixel(20, 20)
	var wall := image.get_pixel(150, 500)
	var underground := image.get_pixel(300, 720)
	var exit_fill := image.get_pixel(700, 610)
	_expect(sky.a > 0.95 and sky.b > sky.r * 2.0, "background renderer should paint the opaque blue-black sky")
	_expect(wall.a > 0.70, "background renderer should paint the fallback midground wall")
	_expect(underground.a > 0.95, "background renderer should paint the opaque underground field")
	_expect(exit_fill.a > 0.08 and exit_fill.a < 0.40 and exit_fill.g > exit_fill.r * 2.0, "background renderer should paint the translucent cyan exit fill")


func _is_pixel_capture_available() -> bool:
	return DisplayServer.get_name().to_lower() != "headless" and not OS.has_feature("headless")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
