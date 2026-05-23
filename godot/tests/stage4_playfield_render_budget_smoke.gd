extends SceneTree

const Stage4PlayfieldRenderer := preload("res://scripts/stages/stage4/stage4_playfield_renderer.gd")
const ViperAirborneLod := preload("res://scripts/core/viper_airborne_lod.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_render_budgets()
	_verify_viper_airborne_lod_budget()
	_verify_shared_fps_cap_lod_budget()
	_verify_recent_start_helper()
	_verify_draw_paths_use_render_caps()

	if _failures.is_empty():
		print("stage4_playfield_render_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_render_budgets() -> void:
	_expect(Stage4PlayfieldRenderer.MAX_RENDERED_COLLAPSE_DEBRIS <= 56, "collapse debris should cap rendered texture pieces")
	_expect(Stage4PlayfieldRenderer.MAX_RENDERED_COLLAPSE_DEBRIS_LOD <= 32, "collapse debris should use a tighter airborne LOD cap")
	_expect(Stage4PlayfieldRenderer.MAX_RENDERED_ROOF_FRAGMENTS <= 24, "roof fragments should cap rendered texture pieces")
	_expect(Stage4PlayfieldRenderer.MAX_RENDERED_ROOF_FRAGMENTS_LOD <= 14, "roof fragments should use a tighter airborne LOD cap")
	_expect(Stage4PlayfieldRenderer.MAX_RENDERED_GROUND_FIRE_PARTICLES_PER_FIRE <= 8, "ground fire should cap rendered particles per fire")
	_expect(Stage4PlayfieldRenderer.MAX_RENDERED_GROUND_FIRE_PARTICLES_PER_FIRE_LOD <= 5, "ground fire should use a tighter airborne LOD cap")
	_expect(Stage4PlayfieldRenderer.MAX_RENDERED_DESTRUCTION_WAVE_ENERGY_RINGS <= 4, "destruction wave energy rings should cap rendered arcs")
	_expect(Stage4PlayfieldRenderer.MAX_RENDERED_DESTRUCTION_WAVE_ENERGY_RINGS_LOD <= 2, "destruction wave rings should use a tighter airborne LOD cap")
	_expect(Stage4PlayfieldRenderer.MAX_RENDERED_DESTRUCTION_WAVE_BEAMS <= 12, "destruction wave beams should cap rendered particles")
	_expect(Stage4PlayfieldRenderer.MAX_RENDERED_DESTRUCTION_WAVE_BEAMS_LOD <= 7, "destruction wave beams should use a tighter airborne LOD cap")
	_expect(Stage4PlayfieldRenderer.MAX_RENDERED_DESTRUCTION_WAVE_TRAIL <= 22, "destruction wave trail should cap rendered particles")
	_expect(Stage4PlayfieldRenderer.MAX_RENDERED_DESTRUCTION_WAVE_TRAIL_LOD <= 12, "destruction wave trail should use a tighter airborne LOD cap")
	_expect(Stage4PlayfieldRenderer.DESTRUCTION_WAVE_RING_ARC_POINTS <= 36, "destruction wave energy-ring arcs should use the reduced point budget")
	_expect(Stage4PlayfieldRenderer.DESTRUCTION_WAVE_RING_ARC_POINTS_LOD <= 24, "destruction wave energy-ring arcs should use a tighter airborne LOD budget")
	_expect(Stage4PlayfieldRenderer.DESTRUCTION_WAVE_CORE_ARC_POINTS <= 42, "destruction wave core arcs should use the reduced point budget")
	_expect(Stage4PlayfieldRenderer.DESTRUCTION_WAVE_CORE_ARC_POINTS_LOD <= 28, "destruction wave core arcs should use a tighter airborne LOD budget")
	_expect(Stage4PlayfieldRenderer.DESTRUCTION_WAVE_CORE_POINT_COUNT <= 16, "destruction wave core polygons should use the reduced point budget")
	_expect(Stage4PlayfieldRenderer.DESTRUCTION_WAVE_CORE_POINT_COUNT_LOD <= 12, "destruction wave core polygons should use a tighter airborne LOD budget")
	_expect(Stage4PlayfieldRenderer.DESTRUCTION_WAVE_CORE_LAYER_COUNT <= 4, "destruction wave core layers should stay within the reduced budget")
	_expect(Stage4PlayfieldRenderer.DESTRUCTION_WAVE_CORE_LAYER_COUNT_LOD <= 3, "destruction wave core layers should use a tighter airborne LOD budget")

	var renderer := Stage4PlayfieldRenderer.new()
	var status: Dictionary = renderer.get_imagegen_asset_status()
	_expect(bool(status.get("viper_airborne_lod_supported", false)), "asset status should expose Viper airborne LOD support")
	_expect(bool(status.get("shared_render_quality_lod_supported", false)), "asset status should expose shared render-quality LOD support")
	_expect(int(status.get("collapse_debris_render_limit", 0)) == Stage4PlayfieldRenderer.MAX_RENDERED_COLLAPSE_DEBRIS, "asset status should expose the collapse-debris render cap")
	_expect(int(status.get("collapse_debris_render_limit_lod", 0)) == Stage4PlayfieldRenderer.MAX_RENDERED_COLLAPSE_DEBRIS_LOD, "asset status should expose the collapse-debris LOD cap")
	_expect(int(status.get("destruction_wave_energy_ring_render_limit", 0)) == Stage4PlayfieldRenderer.MAX_RENDERED_DESTRUCTION_WAVE_ENERGY_RINGS, "asset status should expose the wave energy-ring render cap")
	_expect(int(status.get("destruction_wave_energy_ring_render_limit_lod", 0)) == Stage4PlayfieldRenderer.MAX_RENDERED_DESTRUCTION_WAVE_ENERGY_RINGS_LOD, "asset status should expose the wave energy-ring LOD cap")
	_expect(int(status.get("destruction_wave_trail_render_limit", 0)) == Stage4PlayfieldRenderer.MAX_RENDERED_DESTRUCTION_WAVE_TRAIL, "asset status should expose the wave-trail render cap")
	_expect(int(status.get("destruction_wave_trail_render_limit_lod", 0)) == Stage4PlayfieldRenderer.MAX_RENDERED_DESTRUCTION_WAVE_TRAIL_LOD, "asset status should expose the wave-trail LOD cap")
	_expect(is_equal_approx(float(status.get("red_moon_fragment_image_scale_min", 0.0)), Stage4PlayfieldRenderer.RED_MOON_FRAGMENT_IMAGE_SCALE_MIN), "asset status should expose the red moon fragment minimum image scale")
	_expect(is_equal_approx(float(status.get("red_moon_fragment_image_scale_max", 0.0)), Stage4PlayfieldRenderer.RED_MOON_FRAGMENT_IMAGE_SCALE_MAX), "asset status should expose the red moon fragment maximum image scale")
	_expect(Stage4PlayfieldRenderer.RED_MOON_FRAGMENT_IMAGE_SCALE_MIN <= 2.8, "red moon fragment images should still allow the original small visual scale")
	_expect(is_equal_approx(Stage4PlayfieldRenderer.RED_MOON_FRAGMENT_IMAGE_SCALE_MAX, 5.5), "red moon fragment images should use the tuned maximum visual scale")


func _verify_viper_airborne_lod_budget() -> void:
	var renderer := Stage4PlayfieldRenderer.new()
	var glide_context := {
		"selected_character_type": "viper",
		"viper_jetpack_airborne": true,
		"viper_jetpack_active": false,
		"current_msec": 5000,
	}
	ViperAirborneLod.reset_cache_for_test()
	ViperAirborneLod.effect_scale(glide_context)
	glide_context["current_msec"] = 5000 + ViperAirborneLod.GLIDE_SEVERE_ENTER_MSEC
	var glide_quality: float = renderer._get_playfield_quality_scale(glide_context)
	_expect(is_equal_approx(glide_quality, ViperAirborneLod.GLIDE_EFFECT_SCALE), "glide context should use the shared Viper airborne LOD scale")
	_expect(
		renderer._get_lod_count(
			Stage4PlayfieldRenderer.MAX_RENDERED_COLLAPSE_DEBRIS,
			Stage4PlayfieldRenderer.MAX_RENDERED_COLLAPSE_DEBRIS_LOD,
			glide_quality
		) == Stage4PlayfieldRenderer.MAX_RENDERED_COLLAPSE_DEBRIS_LOD,
		"glide context should use the Stage 4 playfield LOD cap"
	)
	_expect(
		renderer._get_lod_count(Stage4PlayfieldRenderer.FLOATING_LEAF_SPECS.size(), Stage4PlayfieldRenderer.FLOATING_LEAF_RENDER_LIMIT_LOD, glide_quality)
		== Stage4PlayfieldRenderer.FLOATING_LEAF_RENDER_LIMIT_LOD,
		"glide context should reduce floating leaf sprites"
	)
	_expect(
		renderer._get_lod_count(10, 5, 1.0) == 10,
		"normal quality should keep the full render cap"
	)


func _verify_shared_fps_cap_lod_budget() -> void:
	var old_max_fps: int = int(Engine.get("max_fps"))
	Engine.set("max_fps", BattleRenderQuality.FPS_CAP_LOD_MAX_FPS)
	BattleRenderQuality.reset_cache_for_test()

	var renderer := Stage4PlayfieldRenderer.new()
	var smasher_context := {
		"selected_character_type": "smasher",
	}
	var quality: float = renderer._get_playfield_quality_scale(smasher_context)
	_expect(
		is_equal_approx(quality, BattleRenderQuality.FPS_CAP_EFFECT_SCALE),
		"Smasher at the 72 FPS cap should use the shared render-quality LOD scale"
	)
	_expect(
		renderer._get_lod_count(
			Stage4PlayfieldRenderer.MAX_RENDERED_DESTRUCTION_WAVE_TRAIL,
			Stage4PlayfieldRenderer.MAX_RENDERED_DESTRUCTION_WAVE_TRAIL_LOD,
			quality
		) == Stage4PlayfieldRenderer.MAX_RENDERED_DESTRUCTION_WAVE_TRAIL_LOD,
		"shared FPS-cap quality should reduce Stage 4 decorative trail particles"
	)

	Engine.set("max_fps", old_max_fps)
	BattleRenderQuality.reset_cache_for_test()


func _verify_recent_start_helper() -> void:
	var renderer := Stage4PlayfieldRenderer.new()
	var values: Array = []
	for index in range(140):
		values.append(index)
	_expect(renderer._recent_start(values, 56) == 84, "recent-start helper should draw only the newest capped entries")
	_expect(renderer._recent_start(values, 180) == 0, "recent-start helper should draw from zero when under budget")
	_expect(renderer._recent_start(values, 0) == values.size(), "zero render budget should draw nothing")


func _verify_draw_paths_use_render_caps() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_playfield_renderer.gd")
	_expect(source != "", "Stage 4 playfield renderer source should be readable")
	_expect(
		_function_body(source, "func _draw_destruction_particles").find("MAX_RENDERED_COLLAPSE_DEBRIS") >= 0,
		"collapse debris draw should pass a render cap"
	)
	_expect(
		_function_body(source, "func _draw_destruction_particles").find("MAX_RENDERED_ROOF_FRAGMENTS") >= 0,
		"roof fragment draw should pass a render cap"
	)
	_expect(
		_function_body(source, "func _draw_debris_array").find("_recent_start(debris_values, render_limit)") >= 0,
		"debris array draw should cap decorative rendering"
	)
	_expect(
		_function_body(source, "func _draw_ground_fires").find("_recent_start(particles, particle_render_limit)") >= 0,
		"ground fire draw should cap per-fire particle rendering"
	)
	_expect(
		_function_body(source, "func _draw_destruction_wave_payload").find("_recent_start(beams, beam_render_limit)") >= 0,
		"destruction wave draw should cap beam particles"
	)
	_expect(
		_function_body(source, "func _draw_destruction_wave_payload").find("_recent_start(trail_particles, trail_render_limit)") >= 0,
		"destruction wave draw should cap trail particles"
	)
	_expect(
		_function_body(source, "func _draw_destruction_wave_payload").find("_recent_start(energy_rings, energy_ring_limit)") >= 0,
		"destruction wave draw should cap energy-ring arcs"
	)
	_expect(
		_function_body(source, "func _draw_destruction_wave_payload").find("ring_arc_points") >= 0,
		"destruction wave draw should use LOD-scaled arc point count"
	)
	_expect(
		_function_body(source, "func _draw_destruction_wave_core").find("core_point_count") >= 0,
		"destruction wave core should use reduced polygon point count"
	)
	_expect(
		_function_body(source, "func draw").find("_get_playfield_quality_scale(context)") >= 0,
		"Stage 4 playfield draw should calculate the shared render-quality LOD scale"
	)
	_expect(
		_function_body(source, "func _get_playfield_quality_scale").find("BattleRenderQuality.effect_scale(context)") >= 0,
		"Stage 4 playfield LOD should reuse the shared render-quality helper"
	)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
