extends SceneTree

const PlazaBackgroundProjection := preload("res://scripts/plaza/plaza_background_projection.gd")
const PlazaBackgroundRenderer := preload("res://scripts/plaza/plaza_background_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_parallax_and_tiles()
	_verify_vr_strata_geometry()
	_verify_pulse_projection()
	_verify_renderer_texture_contract()
	if _failures.is_empty():
		print("plaza_background_projection_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_parallax_and_tiles() -> void:
	_expect_close(PlazaBackgroundProjection.get_far_sky_x(0.0, 1520.0, 760.0), 0.0, "far sky origin")
	_expect_close(PlazaBackgroundProjection.get_far_sky_x(1000.0, 1520.0, 760.0), -40.0, "far sky parallax")
	_expect_close(PlazaBackgroundProjection.get_far_sky_x(30000.0, 1520.0, 760.0), -760.0, "far sky clamp")
	_expect_close(PlazaBackgroundProjection.get_parallax_tile_offset(0.0, 0.16, 420.0), -420.0, "tile origin coverage")
	_expect_close(PlazaBackgroundProjection.get_parallax_tile_offset(100.0, 0.16, 420.0), -16.0, "tile parallax wrap")
	_expect_close(PlazaBackgroundProjection.get_parallax_tile_offset(100.0, 0.16, 0.0), 0.0, "zero-width tile safety")
	_expect_eq(PlazaBackgroundProjection.get_world_tile_start(0.0, 380.0), 0, "world tile origin")
	_expect_eq(PlazaBackgroundProjection.get_world_tile_start(759.0, 380.0), 380, "world tile floor")
	_expect_eq(PlazaBackgroundProjection.get_world_tile_start(1140.0, 380.0), 1140, "world tile boundary")


func _verify_vr_strata_geometry() -> void:
	_expect_rect(
		PlazaBackgroundProjection.get_vr_strata_block_rect(2, 0.0, 760.0, 688.0),
		Rect2(Vector2(310.0, 732.0), Vector2(54.0, 23.0)),
		"VR strata block projection"
	)
	var moved := PlazaBackgroundProjection.get_vr_strata_block_rect(2, 100.0, 760.0, 688.0)
	_expect_close(moved.position.x, 192.0, "VR strata parallax")
	_expect_close(moved.position.y, 732.0, "VR strata vertical stability")


func _verify_pulse_projection() -> void:
	_expect_eq(PlazaBackgroundProjection.get_flicker_tick(0), 0, "flicker tick origin")
	_expect_eq(PlazaBackgroundProjection.get_flicker_tick(1000), 47, "flicker tick cadence")
	var sample_a := PlazaBackgroundProjection.discrete_flicker("ground:0", 1000)
	var sample_b := PlazaBackgroundProjection.discrete_flicker("ground:0", 1000)
	_expect_close(sample_a, sample_b, "flicker should be deterministic for seed and tick")
	_expect(sample_a >= 0.0 and sample_a < 1.0, "flicker should remain normalized")
	_expect_close(PlazaBackgroundProjection.flicker_alpha("ground:0", 1.0, 0.5, 1000), 1.0, "flicker alpha upper clamp")
	_expect_close(PlazaBackgroundProjection.flicker_alpha("ground:0", -1.0, 0.0, 1000), 0.0, "flicker alpha lower clamp")
	_expect_close(PlazaBackgroundProjection.smooth_unit(-1.0), 0.0, "smooth lower clamp")
	_expect_close(PlazaBackgroundProjection.smooth_unit(0.5), 0.5, "smooth midpoint")
	_expect_close(PlazaBackgroundProjection.smooth_unit(2.0), 1.0, "smooth upper clamp")


func _verify_renderer_texture_contract() -> void:
	for texture_key in [
		"far_sky",
		"midground_wall",
		"ground_strip",
		"ground_strip_emissive",
		"base_01",
		"base_02",
		"border",
		"border_emissive",
		"medallion",
		"medallion_emissive",
		"medallion_cutout",
		"medallion_cutout_emissive",
		"accent",
		"accent_emissive",
		"accent_cutout",
		"accent_cutout_emissive",
	]:
		_expect(PlazaBackgroundRenderer.supports_texture_key(texture_key), "renderer should retain the %s background texture branch" % texture_key)
	_expect(not PlazaBackgroundRenderer.supports_texture_key("unknown"), "renderer should reject unknown background texture keys")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _expect_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])


func _expect_close(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s: expected %.4f, got %.4f" % [label, expected, actual])


func _expect_rect(actual: Rect2, expected: Rect2, label: String) -> void:
	if not actual.position.is_equal_approx(expected.position) or not actual.size.is_equal_approx(expected.size):
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])
