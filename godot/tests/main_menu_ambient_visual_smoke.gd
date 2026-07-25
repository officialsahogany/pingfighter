extends SceneTree

const MainMenuAmbient := preload("res://scripts/ui/main_menu_ambient.gd")

const VIEW_SIZE := Vector2i(760, 426)
const OUT_DIR := "res://../tmp"
const OUT_PATH := "res://../tmp/main_menu_ambient_probe.png"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var ambient := MainMenuAmbient.new()
	ambient.size = Vector2(VIEW_SIZE)
	viewport.add_child(ambient)
	await process_frame
	ambient.set_intro_reveal_active(false)
	ambient.elapsed_time = MainMenuAmbient.GLINT_INITIAL_PHASE_SEC
	ambient.set_process(false)
	ambient.queue_redraw()
	for _index in range(6):
		await process_frame

	_expect(ambient.particles.size() == MainMenuAmbient.PARTICLE_COUNT, "ambient should seed the fixed dust-mote budget")
	_expect(ambient.sky_lights.size() == MainMenuAmbient.SKY_LIGHT_COUNT, "ambient should seed the fixed sky-light budget")
	_expect(ambient.vignette_texture != null, "ambient should prebuild its vignette before drawing")
	_expect(not ambient.logo_letter_mask.is_empty(), "ambient should prebuild the logo-letter glint mask")
	_expect(not ambient.logo_orb_effect_mask.is_empty(), "ambient should prebuild the logo-orb effect mask")

	var display_name := DisplayServer.get_name().to_lower()
	if display_name.find("headless") >= 0:
		viewport.queue_free()
		_finish("main_menu_ambient_visual_smoke: ok (viewport pixel capture skipped under headless display server)")
		return
	var viewport_texture := viewport.get_texture()
	if viewport_texture == null:
		viewport.queue_free()
		_finish("main_menu_ambient_visual_smoke: ok (viewport texture unavailable)")
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		viewport.queue_free()
		_finish("main_menu_ambient_visual_smoke: ok (viewport image unavailable)")
		return
	_expect(_count_visible_samples(image) > 20, "ambient runtime probe should contain visible effect pixels")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_expect(image.save_png(ProjectSettings.globalize_path(OUT_PATH)) == OK, "ambient runtime probe should save")
	viewport.queue_free()
	_finish("main_menu_ambient_visual_smoke: ok\nruntime_probe=%s" % ProjectSettings.globalize_path(OUT_PATH))


func _count_visible_samples(image: Image) -> int:
	var visible := 0
	for y in range(0, image.get_height(), 24):
		for x in range(0, image.get_width(), 24):
			if image.get_pixel(x, y).a > 0.01:
				visible += 1
	return visible


func _finish(message: String) -> void:
	if _failures.is_empty():
		print(message)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
