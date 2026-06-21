extends SceneTree

const DefeatContinueColorRestoreFxHost := preload("res://scripts/effects/defeat_continue_color_restore_fx_host.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_pipeline_contract()
	await _verify_host_lifecycle_and_uniforms()
	_verify_source_contracts()

	if _failures.is_empty():
		print("defeat_continue_color_restore_fx_host_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_pipeline_contract() -> void:
	DefeatContinueColorRestoreFxHost.prewarm_assets()
	var status := DefeatContinueColorRestoreFxHost.build_pipeline_status()
	_expect(bool(status.get("shader_ready", false)), "color restore host should prewarm its screen-read shader")
	_expect(bool(status.get("material_ready", false)), "color restore host should prewarm its shader material")
	_expect(bool(status.get("uses_screen_texture", false)), "color restore host should use hint_screen_texture")
	_expect(bool(status.get("uses_back_buffer_copy", false)), "color restore host should declare BackBufferCopy ownership")
	_expect(int(status.get("z_index", 0)) > 1240, "color restore host should render above the shatter host")


func _verify_host_lifecycle_and_uniforms() -> void:
	var host := DefeatContinueColorRestoreFxHost.new()
	get_root().add_child(host)
	await process_frame
	var status := host.get_debug_status()
	_expect(not bool(status.get("visible", true)), "fresh color restore host should start inactive")
	_expect(bool(status.get("has_back_buffer_copy", false)), "color restore host should own a BackBufferCopy child")
	_expect(bool(status.get("has_color_rect", false)), "color restore host should own a fullscreen ColorRect child")
	_expect(bool(status.get("material_ready", false)), "color restore host should attach the shader material to the ColorRect")
	_expect(int(status.get("z_index", 0)) == DefeatContinueColorRestoreFxHost.Z_INDEX, "color restore host should use its explicit z-index")
	_expect(not bool(status.get("z_as_relative", true)), "color restore host z should be absolute")

	host.sync_state({
		"active": true,
		"view_size_px": Vector2(1280.0, 720.0),
		"center_px": Vector2(640.0, 360.0),
		"restore_radius_px": 0.0,
		"feather_px": 72.0,
		"desaturate_amount": 1.0,
	}, true)
	status = host.get_debug_status()
	_expect(bool(status.get("visible", false)), "active color restore status should show the host")
	_expect(int(status.get("copy_mode", -1)) == BackBufferCopy.COPY_MODE_VIEWPORT, "color restore host should capture the viewport before drawing its ColorRect")
	_expect((status.get("rect_size", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(1280.0, 720.0)), "ColorRect should cover the visible viewport")
	_expect((status.get("center_px", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(640.0, 360.0)), "shader should receive the player-centered restore origin")
	_expect(is_equal_approx(float(status.get("desaturate_amount", 0.0)), 1.0), "shader should receive full desaturation during absorb/victory")

	host.sync_state({
		"active": true,
		"view_size_px": Vector2(1280.0, 720.0),
		"center_px": Vector2(640.0, 360.0),
		"restore_radius_px": 820.0,
		"feather_px": 72.0,
		"desaturate_amount": 1.0,
	}, true)
	status = host.get_debug_status()
	_expect(float(status.get("restore_radius_px", 0.0)) >= 819.0, "shader should receive the expanding color-restore radius")

	host.force_timeout_for_tests()
	_expect(not bool(host.get_debug_status().get("visible", true)), "color restore host should hide itself if owner sync stops")
	host.sync_state({}, false)
	_expect(not bool(host.get_debug_status().get("visible", true)), "disabled sync should keep the color restore host inactive")
	host.queue_free()


func _verify_source_contracts() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/effects/defeat_continue_color_restore_fx_host.gd")
	_expect(source.find("hint_screen_texture") >= 0, "color restore shader must sample the screen texture")
	_expect(source.find("BackBufferCopy") >= 0, "color restore host must insert a BackBufferCopy before the ColorRect")
	_expect(source.find("ColorRect") >= 0, "color restore host must draw through a fullscreen ColorRect")
	_expect(source.find("COPY_MODE_VIEWPORT") >= 0, "color restore host should capture the full viewport")
	_expect(source.find("ACTIVE_SYNC_GRACE_MSEC") >= 0, "color restore host should have a self-timeout cleanup")
	_expect(source.find("set_active(false)") >= 0, "color restore host should have a single cleanup path")
	_expect(source.find("draw_set_transform") < 0, "color restore host must not use transform-reset drawing")
	_expect(source.find("ResourceLoader.load") < 0, "color restore host should not lazy-load resources in the hot path")
	_expect(source.find("ImageTexture.create_from_image") < 0, "color restore host should not build textures in the hot path")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
