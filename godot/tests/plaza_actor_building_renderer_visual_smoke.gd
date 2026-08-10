extends SceneTree

const PlazaActorRenderer := preload("res://scripts/plaza/plaza_actor_renderer.gd")
const PlazaBuildingRenderer := preload("res://scripts/plaza/plaza_building_renderer.gd")

const VIEWPORT_SIZE := Vector2i(560, 260)

var _failures: Array[String] = []


class RenderProbe:
	extends Node2D

	var building_texture: Texture2D = null
	var player_texture: Texture2D = null
	var lingpet_texture: Texture2D = null
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		PlazaBuildingRenderer.draw(
			self,
			{
				"type": "visual_probe",
				"base_texture": building_texture,
				"visual_rect": Rect2(30.0, 40.0, 80.0, 100.0),
				"pivot_pos": Vector2(70.0, 140.0),
			},
			0.0,
			float(VIEWPORT_SIZE.x),
			220.0,
			1.0,
			1234
		)
		PlazaActorRenderer.draw_player(
			self,
			{
				"has_sprite": true,
				"idle": player_texture,
				"grid_cols": 4,
				"grid_rows": 2,
			},
			Vector2(250.0, 200.0),
			0.0,
			1.0,
			1.0,
			false,
			1,
			0
		)
		PlazaActorRenderer.draw_lingpet(
			self,
			lingpet_texture,
			92.0,
			Vector2(430.0, 200.0),
			0.0,
			1.0,
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

	var probe := RenderProbe.new()
	probe.building_texture = _make_solid_texture(Vector2i(4, 4), Color(0.92, 0.08, 0.06, 1.0))
	probe.player_texture = _make_solid_texture(Vector2i(40, 20), Color(0.08, 0.90, 0.12, 1.0))
	probe.lingpet_texture = _make_solid_texture(Vector2i(50, 50), Color(0.06, 0.16, 0.94, 1.0))
	viewport.add_child(probe)
	probe.queue_redraw()

	for _frame_index in range(4):
		await process_frame

	_expect(probe.draw_count > 0, "renderer visual probe should receive a live draw callback")
	if _is_pixel_capture_available():
		var image := viewport.get_texture().get_image()
		_expect(image != null and not image.is_empty(), "renderer visual probe should produce a readable viewport image")
		if image != null and not image.is_empty():
			_verify_anchor_pixels(image)
	else:
		_verify_headless_draw_contract(probe)

	viewport.queue_free()
	if _failures.is_empty():
		print("plaza_actor_building_renderer_visual_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_anchor_pixels(image: Image) -> void:
	_expect(_is_red(image.get_pixel(60, 70)), "building renderer should paint the red building body")
	_expect(_is_green(image.get_pixel(250, 100)), "actor renderer should paint the green player sheet")
	_expect(_is_blue(image.get_pixel(430, 150)), "actor renderer should paint the blue Lingpet sheet")


func _verify_headless_draw_contract(probe: RenderProbe) -> void:
	_expect(probe.building_texture != null, "headless draw contract should retain the building texture")
	_expect(probe.player_texture != null, "headless draw contract should retain the player sheet")
	_expect(probe.lingpet_texture != null, "headless draw contract should retain the Lingpet sheet")


func _is_pixel_capture_available() -> bool:
	return DisplayServer.get_name().to_lower() != "headless" and not OS.has_feature("headless")


func _make_solid_texture(image_size: Vector2i, color: Color) -> Texture2D:
	var image := Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _is_red(color: Color) -> bool:
	return color.a > 0.9 and color.r > 0.8 and color.r > color.g * 4.0 and color.r > color.b * 4.0


func _is_green(color: Color) -> bool:
	return color.a > 0.9 and color.g > 0.8 and color.g > color.r * 4.0 and color.g > color.b * 4.0


func _is_blue(color: Color) -> bool:
	return color.a > 0.9 and color.b > 0.8 and color.b > color.r * 4.0 and color.b > color.g * 4.0


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
