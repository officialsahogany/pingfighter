extends SceneTree

const Stage3EffectRenderer := preload("res://scripts/stages/stage3/stage3_menhera_skill_effect_renderer.gd")
const ViperAirborneLod := preload("res://scripts/core/viper_airborne_lod.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_render_budgets()
	_verify_recent_start_helper()
	_verify_draw_paths_use_render_caps()

	if _failures.is_empty():
		print("stage3_menhera_effect_render_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_render_budgets() -> void:
	_expect(Stage3EffectRenderer.MAX_RENDERED_TAIL_HIT_BURSTS_LOD <= 2, "tail-hit bursts should use a tighter airborne LOD cap")
	_expect(Stage3EffectRenderer.MAX_RENDERED_TAIL_HIT_BURSTS_SEVERE_LOD <= 1, "tail-hit bursts should use the severe Viper LOD cap")
	_expect(Stage3EffectRenderer.TAIL_DRAW_POINT_LIMIT <= 18, "tail whip should downsample runtime curve points before drawing")
	_expect(Stage3EffectRenderer.TAIL_DRAW_POINT_LIMIT_LOD <= 14, "tail whip should use a tighter airborne curve draw cap")
	_expect(Stage3EffectRenderer.TAIL_DRAW_POINT_LIMIT_SEVERE_LOD <= 10, "tail whip should use the severe Viper curve draw cap")
	_expect(Stage3EffectRenderer.TAIL_HIT_RING_SEGMENTS <= 24, "tail-hit rings should avoid high segment counts")
	_expect(Stage3EffectRenderer.TAIL_HIT_RAY_COUNT <= 6, "tail-hit rays should keep draw calls bounded")
	_expect(Stage3EffectRenderer.MAX_RENDERED_PRISM_PARTICLES <= 24, "tail-hit prism particles should cap decorative rendering")
	_expect(Stage3EffectRenderer.MAX_RENDERED_PRISM_PARTICLES_LOD <= 16, "tail-hit prism particles should use a tighter airborne LOD cap")
	_expect(Stage3EffectRenderer.MAX_RENDERED_PRISM_PARTICLES_SEVERE_LOD <= 10, "tail-hit prism particles should use the severe Viper LOD cap")
	_expect(Stage3EffectRenderer.MAX_RENDERED_PSYCHOBALL_NEUTRALIZE_PARTICLES <= 36, "psychoball neutralize particles should cap decorative rendering")
	_expect(Stage3EffectRenderer.MAX_RENDERED_PSYCHOBALL_NEUTRALIZE_PARTICLES_LOD <= 24, "psychoball neutralize particles should use a tighter airborne LOD cap")
	_expect(Stage3EffectRenderer.MAX_RENDERED_PSYCHOBALL_NEUTRALIZE_PARTICLES_SEVERE_LOD <= 16, "psychoball neutralize particles should use the severe Viper LOD cap")
	_expect(Stage3EffectRenderer.MAX_RENDERED_CURSE_SMOKE_PARTICLES <= 64, "curse smoke should cap texture-heavy decorative rendering")
	_expect(Stage3EffectRenderer.MAX_RENDERED_CURSE_SMOKE_PARTICLES_LOD <= 40, "curse smoke should use a tighter airborne LOD cap")
	_expect(Stage3EffectRenderer.MAX_RENDERED_CURSE_SMOKE_PARTICLES_SEVERE_LOD <= 28, "curse smoke should use the severe Viper LOD cap")
	_expect(Stage3EffectRenderer.MAX_RENDERED_CURSE_EXPLOSION_PARTICLES <= 48, "curse explosion particles should cap decorative rendering")
	_expect(Stage3EffectRenderer.MAX_RENDERED_CURSE_EXPLOSION_PARTICLES_LOD <= 32, "curse explosion particles should use a tighter airborne LOD cap")
	_expect(Stage3EffectRenderer.MAX_RENDERED_CURSE_EXPLOSION_PARTICLES_SEVERE_LOD <= 22, "curse explosion particles should use the severe Viper LOD cap")
	_expect(Stage3EffectRenderer.MAX_RENDERED_KUROMI_EATING_PARTICLES <= 40, "Kuromi eating particles should cap decorative rendering")
	_expect(Stage3EffectRenderer.MAX_RENDERED_KUROMI_EATING_PARTICLES_LOD <= 26, "Kuromi eating particles should use a tighter airborne LOD cap")
	_expect(Stage3EffectRenderer.MAX_RENDERED_KUROMI_EATING_PARTICLES_SEVERE_LOD <= 18, "Kuromi eating particles should use the severe Viper LOD cap")
	_expect(Stage3EffectRenderer.MAX_RENDERED_STARPOINT_PARTICLES <= 48, "Stage 3 starpoint particles should cap decorative rendering")
	_expect(Stage3EffectRenderer.MAX_RENDERED_STARPOINT_PARTICLES_LOD <= 30, "Stage 3 starpoint particles should use a tighter airborne LOD cap")
	_expect(Stage3EffectRenderer.MAX_RENDERED_STARPOINT_PARTICLES_SEVERE_LOD <= 20, "Stage 3 starpoint particles should use the severe Viper LOD cap")


func _verify_recent_start_helper() -> void:
	var renderer := Stage3EffectRenderer.new()
	var values: Array = []
	for index in range(100):
		values.append(index)
	_expect(renderer._recent_start(values, 36) == 64, "recent-start helper should draw only the newest capped entries")
	_expect(renderer._recent_start(values, 140) == 0, "recent-start helper should draw from zero when under budget")
	_expect(renderer._recent_start(values, 0) == values.size(), "zero render budget should draw nothing")
	var glide_context := {
		"selected_character_type": "viper",
		"viper_jetpack_airborne": true,
		"viper_jetpack_active": false,
		"current_msec": 5000,
	}
	ViperAirborneLod.reset_cache_for_test()
	renderer._active_quality_scale = ViperAirborneLod.effect_scale(glide_context)
	glide_context["current_msec"] = 5000 + ViperAirborneLod.GLIDE_SEVERE_ENTER_MSEC
	renderer._active_quality_scale = renderer._get_effect_quality_scale(glide_context)
	_expect(is_equal_approx(renderer._active_quality_scale, ViperAirborneLod.GLIDE_EFFECT_SCALE), "Stage 3 effect renderer should use shared Viper glide LOD")
	_expect(
		renderer._get_lod_count(
			Stage3EffectRenderer.MAX_RENDERED_CURSE_SMOKE_PARTICLES,
			Stage3EffectRenderer.MAX_RENDERED_CURSE_SMOKE_PARTICLES_LOD,
			Stage3EffectRenderer.MAX_RENDERED_CURSE_SMOKE_PARTICLES_SEVERE_LOD
		) == Stage3EffectRenderer.MAX_RENDERED_CURSE_SMOKE_PARTICLES_SEVERE_LOD,
		"Stage 3 effect renderer should use severe caps after glide hysteresis enters"
	)
	ViperAirborneLod.reset_cache_for_test()


func _verify_draw_paths_use_render_caps() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_menhera_skill_effect_renderer.gd")
	_expect(source != "", "Stage 3 Menhera effect renderer source should be readable")
	_expect(
		_function_body(source, "func _draw_psychoball_neutralize_particles").find("_recent_start(particles, render_limit)") >= 0,
		"psychoball neutralize draw should cap decorative particles"
	)
	_expect(
		_function_body(source, "func _draw_curse_smoke").find("_recent_start(smoke, render_limit)") >= 0,
		"curse-smoke draw should cap texture-heavy particles"
	)
	_expect(
		_function_body(source, "func _draw_curse_explosion").find("_recent_start(particles, render_limit)") >= 0,
		"curse-explosion draw should cap decorative particles"
	)
	_expect(
		_function_body(source, "func _draw_kuromi_eating_particles").find("_recent_start(particles, render_limit)") >= 0,
		"Kuromi eating draw should cap decorative particles"
	)
	_expect(
		_function_body(source, "func _draw_starpoint_particles").find("_recent_start(particles, render_limit)") >= 0,
		"Stage 3 starpoint draw should cap decorative particles"
	)
	_expect(
		_function_body(source, "func _draw_tail_whip").find("_copy_tail_draw_points") >= 0,
		"tail whip draw should downsample runtime points before drawing"
	)
	_expect(
		_function_body(source, "func _draw_prism_particles").find("MAX_RENDERED_PRISM_PARTICLES") >= 0,
		"tail-hit prism draw should use the render cap"
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
