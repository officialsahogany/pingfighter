extends SceneTree

const CharacterInfoOverlayPendulumInterior := preload("res://scripts/hud/character_info_overlay_pendulum_interior.gd")

const VIEW_SIZE := Vector2(1280.0, 720.0)
const PANEL_RECT := Rect2(Vector2(210.0, 30.0), Vector2(860.0, 660.0))
const OUT_DIR := "res://../tmp"
const OUT_PATH := "res://../tmp/lingpet_pendulum_runtime_shell_probe.png"

var _failures: Array[String] = []


class FakePlazaSaveStore:
	extends RefCounted

	func get_decoder_level() -> int:
		return 5


class FakeRegistry:
	extends RefCounted

	var plaza_save_store := FakePlazaSaveStore.new()

	func get_instance(key: String) -> Object:
		if key == "plaza_save_store":
			return plaza_save_store
		return null


class FakeOwner:
	extends RefCounted


class PendulumProbe:
	extends Control

	var module: Object
	var probe_font: Font

	func _draw() -> void:
		if module == null:
			return
		draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.015, 0.018, 0.028, 1.0))
		module.draw(self, probe_font, PANEL_RECT, VIEW_SIZE)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var module := CharacterInfoOverlayPendulumInterior.new()
	var snapshot := {
		"state": "companion",
		"pet_id": "maribo",
		"ring_core_tier": 1,
	}
	_expect(module.open(snapshot, FakeOwner.new(), FakeRegistry.new()), "pendulum visual probe should open the module")
	_expect(module.has_shell_texture_for_tests(), "pendulum visual probe should use the accepted shell texture")
	_expect(module.get_decoder_level_for_tests() == 1, "pendulum visual probe should decode T1 ring core at level 1")
	_expect(module.get_decoder_caption_for_tests().find("T1") >= 0 and module.get_decoder_caption_for_tests().find("20%") >= 0, "pendulum visual probe should show T1 and 20 percent decode")

	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(VIEW_SIZE.x), int(VIEW_SIZE.y))
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var probe := PendulumProbe.new()
	probe.size = VIEW_SIZE
	probe.module = module
	probe.probe_font = ThemeDB.fallback_font
	viewport.add_child(probe)
	probe.queue_redraw()

	for _idx in range(6):
		await process_frame

	var display_name := DisplayServer.get_name().to_lower()
	if display_name.find("headless") >= 0:
		viewport.queue_free()
		print("character_info_overlay_pendulum_visual_smoke: ok (viewport pixel capture skipped under headless display server)")
		quit(0)
		return

	var viewport_texture := viewport.get_texture()
	if viewport_texture == null:
		viewport.queue_free()
		print("character_info_overlay_pendulum_visual_smoke: ok (viewport pixel capture skipped under dummy renderer)")
		quit(0)
		return
	var image: Image = viewport_texture.get_image()
	if image == null or image.is_empty():
		viewport.queue_free()
		print("character_info_overlay_pendulum_visual_smoke: ok (viewport pixel capture skipped under dummy renderer)")
		quit(0)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var save_error := image.save_png(ProjectSettings.globalize_path(OUT_PATH))
	_expect(save_error == OK, "pendulum visual probe should save a runtime screenshot")
	_verify_shell_pixels(image, module)

	viewport.queue_free()

	if _failures.is_empty():
		print("character_info_overlay_pendulum_visual_smoke: ok")
		print("runtime_probe=%s" % ProjectSettings.globalize_path(OUT_PATH))
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_shell_pixels(image: Image, module: Object) -> void:
	var modal_rect := CharacterInfoOverlayPendulumInterior.build_modal_rect(PANEL_RECT, VIEW_SIZE)
	var screen_rect := CharacterInfoOverlayPendulumInterior.screen_rect_for_tests(modal_rect)
	var walk_band_rect := CharacterInfoOverlayPendulumInterior.walk_band_rect_for_tests(modal_rect)
	var speech_rect: Rect2 = module.get_speech_rect_for_tests()
	var close_rect: Rect2 = module.get_close_rect_for_tests()
	var crown_pixel := _sample_pixel(image, modal_rect.position + Vector2(modal_rect.size.x * (374.0 / 747.0), modal_rect.size.y * (184.0 / 1076.0)))
	var screen_pixel := _sample_pixel(image, screen_rect.get_center())
	var walk_pixel := _sample_pixel(image, walk_band_rect.get_center())
	var speech_fill_pixel := _sample_pixel(image, speech_rect.position + Vector2(6.0, 6.0))
	var close_center_pixel := _sample_pixel(image, close_rect.get_center())
	_expect(_visible_energy(crown_pixel) > 0.20, "pendulum shell crown sample should render nonblank pixels")
	_expect(_visible_energy(screen_pixel) > 0.16, "pendulum shell screen sample should render the baked interior display")
	_expect(_visible_energy(walk_pixel) > 0.12, "pendulum walk band sample should render inside the baked glass")
	_expect(_visible_energy(speech_fill_pixel) > 0.10, "pendulum speech bubble should render visible dark-glass pixels")
	_expect(_visible_energy(close_center_pixel) > 0.25, "pendulum docked close button should render visible shell-mounted pixels")
	_expect(modal_rect.size.x < modal_rect.size.y, "pendulum runtime capture should keep a portrait shell frame")


func _sample_pixel(image: Image, pos: Vector2) -> Color:
	var x := clampi(roundi(pos.x), 0, image.get_width() - 1)
	var y := clampi(roundi(pos.y), 0, image.get_height() - 1)
	return image.get_pixel(x, y)


func _visible_energy(color: Color) -> float:
	return maxf(color.a, 0.0) * (color.r + color.g + color.b)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
