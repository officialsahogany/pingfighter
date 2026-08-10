extends SceneTree

const SCENE_PATH := "res://scripts/plaza/plaza_scene.gd"

var _failures: Array[String] = []


func _init() -> void:
	var source := FileAccess.get_file_as_string(SCENE_PATH)
	_expect(source.contains("const PlazaBackgroundProjection := preload"), "plaza scene should preload the background projection")
	_expect(source.contains("const PlazaBackgroundRenderer := preload"), "plaza scene should preload the background renderer")
	var draw_body := _function_body(source, "_draw")
	_expect(draw_body.contains("PlazaBackgroundRenderer.draw("), "scene draw should delegate background, ground, and exit drawing to the renderer")
	for legacy_constant in [
		"const FLOOR_REPEAT",
		"const GROUND_STRIP_REPEAT",
		"const GROUND_STRIP_HEIGHT",
		"const MIDGROUND_WALL_REPEAT",
		"const MIDGROUND_WALL_TOP",
		"const MIDGROUND_WALL_HEIGHT",
		"const MIDGROUND_WALL_ALPHA",
		"const MIDGROUND_WALL_TOP_FADE_HEIGHT",
		"const MIDGROUND_WALL_TOP_FADE_SLICE",
		"const FAR_SKY_WIDTH",
		"const FAR_SKY_HEIGHT",
		"const SIDEWALK_HEIGHT",
		"const UNDERGROUND_TOP",
	]:
		_expect(not source.contains(legacy_constant), "scene should not duplicate %s" % legacy_constant)
	for removed_method in [
		"_draw_parallax_background",
		"_draw_sky_gradient",
		"_draw_far_sky_asset",
		"_draw_moon",
		"_draw_cloud_band",
		"_draw_midground_wall",
		"_draw_midground_wall_asset_tile",
		"_draw_midground_wall_asset_region",
		"_draw_ground_strip",
		"_draw_vr_strata",
		"_draw_exit_zone",
		"_draw_texture_world",
		"_discrete_flicker",
		"_flicker_alpha",
		"_stable_hash_unit",
		"_smooth_unit",
	]:
		_expect(not source.contains("func %s(" % removed_method), "scene should not retain background method %s" % removed_method)
	var sample_body := _function_body(source, "get_flicker_samples_for_test")
	_expect(sample_body.contains("PlazaBackgroundProjection.discrete_flicker"), "flicker test facade should delegate to the background projection")

	if _failures.is_empty():
		print("plaza_background_renderer_owner_integration_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _function_body(source: String, method: String) -> String:
	var start := source.find("func %s(" % method)
	if start < 0:
		return ""
	var end := source.find("\nfunc ", start + method.length())
	return source.substr(start) if end < 0 else source.substr(start, end - start)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
