extends SceneTree

const OverlayRenderer := preload("res://scripts/items/mythic_item_acquisition_overlay_renderer.gd")
const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_overlay_bounds()
	_verify_paddle_geometry()
	_verify_draw_manifest_and_host_order()
	if _failures.is_empty():
		print("mythic_item_acquisition_overlay_renderer_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_overlay_bounds() -> void:
	var field_size := Vector2(760.0, 750.0)
	var overlay_rect := OverlayRenderer.compute_overlay_rect(field_size, 30.0)
	_expect(overlay_rect == Rect2(-38.0, -38.0, 836.0, 826.0), "overlay should overscan the field by shake plus 8px")
	var no_shake_rect := OverlayRenderer.compute_overlay_rect(field_size, -10.0)
	_expect(no_shake_rect == Rect2(-8.0, -8.0, 776.0, 766.0), "negative shake should clamp before the fixed overscan margin")
	var white_out_rect := OverlayRenderer.compute_white_out_rect(field_size)
	_expect(white_out_rect == Rect2(-4620.0, -4625.0, 10000.0, 10000.0), "white-out should retain the monitor-covering 5000px reach")
	_expect(white_out_rect.encloses(overlay_rect), "white-out bounds should enclose the shaken playfield overlay")


func _verify_paddle_geometry() -> void:
	_expect_close(OverlayRenderer.compute_paddle_glow_radius(1.0), 90.0, "full-intensity glow radius")
	_expect_close(OverlayRenderer.compute_paddle_glow_radius(0.5), 117.0, "half-intensity glow radius")
	_expect_close(OverlayRenderer.compute_paddle_glow_radius(-1.0), 144.0, "clamped zero-intensity glow radius")
	_expect_close(OverlayRenderer.compute_paddle_ray_reach(1.0), 325.0, "full-intensity paddle ray reach")
	_expect_close(OverlayRenderer.compute_paddle_ray_reach(0.5), 218.75, "half-intensity paddle ray reach")
	_expect_close(OverlayRenderer.compute_paddle_ray_reach(2.0), 325.0, "paddle ray reach upper clamp")


func _verify_draw_manifest_and_host_order() -> void:
	var renderer_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_acquisition_overlay_renderer.gd")
	var host_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_acquisition_cinematic_v2.gd")
	var impact_body := SourceContractFunctionBody.extract(renderer_source, "func draw_paddle_impact(")
	var rays_body := SourceContractFunctionBody.extract(renderer_source, "func draw_paddle_slam_rays(")
	_expect(impact_body.count("canvas.draw_circle(") == 3, "paddle impact should retain three concentric glow circles")
	_expect(rays_body.count("canvas.draw_line(") == 6, "paddle impact should retain six warm/core/cross ray lines")
	_expect(renderer_source.find("ProjectResourceLoader") < 0 and renderer_source.find("load_texture") < 0, "overlay renderer should not own lazy resource loading")
	var draw_body := SourceContractFunctionBody.extract(host_source, "func _draw() -> void:")
	var vignette_index := draw_body.find("draw_texture_overlay(self, _vignette_texture")
	var beams_index := draw_body.find("_draw_light_beams()")
	var flash_index := draw_body.find("draw_texture_overlay(self, _white_flash_texture")
	var white_out_index := draw_body.find("draw_white_out(self")
	var impact_index := draw_body.find("draw_paddle_impact(self")
	_expect(
		vignette_index >= 0
			and vignette_index < beams_index
			and beams_index < flash_index
			and flash_index < white_out_index
			and white_out_index < impact_index,
		"host should preserve vignette -> beams -> flash -> white-out -> paddle-impact order"
	)
	_expect(draw_body.find("_vignette_texture == null") >= 0 and draw_body.find("_build_soft_vignette_texture()") >= 0, "host should retain lazy vignette loading")
	_expect(draw_body.find("_white_flash_texture == null") >= 0 and draw_body.find("_build_soft_white_flash_texture()") >= 0, "host should retain lazy white-flash loading")
	_expect(host_source.find("white_out_reach") < 0 and host_source.find("var glow_i") < 0, "host should not retain extracted overlay geometry")
	_expect(host_source.find("_overlay_renderer.draw_paddle_slam_rays(self, center, intensity)") >= 0, "legacy paddle-ray wrapper should delegate exact ray geometry")


func _expect_close(actual: float, expected: float, label: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s should remain exact (expected %.6f, found %.6f)" % [label, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
