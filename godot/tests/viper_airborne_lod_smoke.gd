extends SceneTree

const BattleDrawBallContext := preload("res://scripts/core/battle_draw_ball_context.gd")
const Stage1PlayfieldRenderer := preload("res://scripts/stages/stage1/stage1_playfield_renderer.gd")
const Stage1PillarSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_scene_drawer.gd")
const Stage1PillarUiRenderer := preload("res://scripts/hud/stage1_pillar_ui_renderer.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const ViperAirborneLod := preload("res://scripts/core/viper_airborne_lod.gd")
const ViperSkillParticleDrawer := preload("res://scripts/characters/viper_skill_particle_drawer.gd")

var _failures: Array[String] = []


func _init() -> void:
	var original_max_fps: int = int(Engine.get("max_fps"))
	_verify_lod_gate()
	_verify_ball_context_propagates_lod()
	_verify_stage1_pillar_context_uses_lod()
	_verify_viper_skill_context_uses_lod()
	Engine.set("max_fps", original_max_fps)

	if _failures.is_empty():
		print("viper_airborne_lod_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_lod_gate() -> void:
	ViperAirborneLod.reset_cache_for_test()
	_expect(not ViperAirborneLod.is_air_strike_lod_active({}), "empty context should not enable airborne LOD")
	_expect(
		not ViperAirborneLod.is_air_strike_lod_active({
			"selected_character_type": "viper",
			"viper_jetpack_airborne": true,
			"viper_air_strike_flash_timer": 0.0,
		}),
		"viper airborne without air strike flash should not enable LOD"
	)
	_expect(
		ViperAirborneLod.is_airborne_lod_active({
			"selected_character_type": "viper",
			"viper_jetpack_airborne": true,
			"viper_air_strike_flash_timer": 0.0,
		}),
		"viper airborne should enable the softer ball-FX LOD tier"
	)
	_expect(
		abs(float(ViperAirborneLod.effect_scale({
			"selected_character_type": "viper",
			"viper_jetpack_airborne": true,
			"viper_jetpack_active": true,
			"viper_air_strike_flash_timer": 0.0,
		})) - ViperAirborneLod.AIRBORNE_EFFECT_SCALE) < 0.001,
		"viper active thrust without air strike should use the softer airborne LOD scale"
	)
	_expect(
		ViperAirborneLod.is_glide_lod_active({
			"selected_character_type": "viper",
			"viper_jetpack_airborne": true,
			"viper_jetpack_active": false,
			"viper_air_strike_flash_timer": 0.0,
		}),
		"viper glide should enable the stronger sustained-airborne LOD tier"
	)
	var glide_context := {
		"selected_character_type": "viper",
		"viper_jetpack_airborne": true,
		"viper_jetpack_active": false,
		"viper_air_strike_flash_timer": 0.0,
		"current_msec": 1000,
	}
	_expect(
		abs(float(ViperAirborneLod.effect_scale(glide_context)) - ViperAirborneLod.AIRBORNE_EFFECT_SCALE) < 0.001,
		"viper glide should wait briefly before entering the severe sustained-airborne LOD scale"
	)
	glide_context["current_msec"] = 1000 + ViperAirborneLod.GLIDE_SEVERE_ENTER_MSEC - 1
	_expect(
		abs(float(ViperAirborneLod.effect_scale(glide_context)) - ViperAirborneLod.AIRBORNE_EFFECT_SCALE) < 0.001,
		"viper glide should not enter severe LOD before the hysteresis enter window"
	)
	glide_context["current_msec"] = 1000 + ViperAirborneLod.GLIDE_SEVERE_ENTER_MSEC
	_expect(
		abs(float(ViperAirborneLod.effect_scale(glide_context)) - ViperAirborneLod.GLIDE_EFFECT_SCALE) < 0.001,
		"viper stable glide should use the sustained-airborne LOD scale"
	)
	var thrust_context := {
		"selected_character_type": "viper",
		"viper_jetpack_airborne": true,
		"viper_jetpack_active": true,
		"viper_air_strike_flash_timer": 0.0,
		"current_msec": 1000 + ViperAirborneLod.GLIDE_SEVERE_ENTER_MSEC + 16,
	}
	_expect(
		abs(float(ViperAirborneLod.effect_scale(thrust_context)) - ViperAirborneLod.GLIDE_EFFECT_SCALE) < 0.001,
		"viper glide severe LOD should hold briefly through thrust flicker"
	)
	thrust_context["current_msec"] = 1000 + ViperAirborneLod.GLIDE_SEVERE_ENTER_MSEC + ViperAirborneLod.GLIDE_SEVERE_EXIT_HOLD_MSEC + 17
	_expect(
		abs(float(ViperAirborneLod.effect_scale(thrust_context)) - ViperAirborneLod.AIRBORNE_EFFECT_SCALE) < 0.001,
		"viper glide severe LOD should release after the thrust flicker hold window"
	)
	_expect(
		not ViperAirborneLod.is_air_strike_lod_active({
			"selected_character_type": "smasher",
			"viper_jetpack_airborne": true,
			"viper_air_strike_flash_timer": 4.0,
		}),
		"non-viper context should not enable viper LOD"
	)
	_expect(
		not ViperAirborneLod.is_fps_cap_lod_active({
			"selected_character_type": "smasher",
		}),
		"non-viper context should not enable capped-frame safety LOD"
	)
	Engine.set("max_fps", 72)
	ViperAirborneLod.reset_cache_for_test()
	var fps_cap_context := {
		"selected_character_type": "viper",
		"viper_jetpack_airborne": false,
		"viper_air_strike_flash_timer": 0.0,
	}
	_expect(ViperAirborneLod.is_fps_cap_lod_active(fps_cap_context), "viper should enable safety LOD under capped frame pacing")
	_expect(ViperAirborneLod.is_any_lod_active(fps_cap_context), "safety LOD should count as an active LOD tier")
	_expect(
		abs(float(ViperAirborneLod.effect_scale(fps_cap_context)) - ViperAirborneLod.FPS_CAP_EFFECT_SCALE) < 0.001,
		"viper ground state should use the capped-frame safety LOD scale when max_fps is capped"
	)
	Engine.set("max_fps", 144)
	ViperAirborneLod.reset_cache_for_test()
	_expect(
		not ViperAirborneLod.is_fps_cap_lod_active(fps_cap_context),
		"viper should not keep 72 FPS safety LOD when the runtime cap is raised"
	)
	_expect(
		ViperAirborneLod.is_air_strike_lod_active({
			"selected_character_type": "viper",
			"viper_jetpack_airborne": true,
			"viper_air_strike_flash_timer": 4.0,
		}),
		"viper airborne during air strike flash should enable LOD"
	)
	_expect(ViperAirborneLod.LOD_EFFECT_SCALE <= 0.50, "Air Strike LOD should stay severe enough to skip the heavy ball burst path")
	_expect(ViperAirborneLod.AIR_STRIKE_FLASH_VISIBLE_PROGRESS_CAP <= 0.55, "Air Strike flash should stop its texture pass before the long post-hit tail")


func _verify_ball_context_propagates_lod() -> void:
	var builder := BattleDrawBallContext.new()
	var draw_context := {
		"selected_character_type": "viper",
		"viper_jetpack_airborne": true,
		"viper_air_strike_flash_timer": 3.0,
		"ball_active": true,
	}
	var ball_draw: Dictionary = builder.build_draw(draw_context, {})
	var ball_context: Dictionary = ball_draw.get("context", {})
	_expect(bool(ball_context.get("viper_airborne_lod_active", false)), "ball draw context should carry active LOD flag")
	_expect(
		abs(float(ball_context.get("effect_lod_scale", 1.0)) - ViperAirborneLod.LOD_EFFECT_SCALE) < 0.001,
		"ball draw context should carry LOD effect scale"
	)


func _verify_stage1_pillar_context_uses_lod() -> void:
	var glide_context := {
		"selected_character_type": "viper",
		"viper_jetpack_airborne": true,
		"viper_jetpack_active": false,
		"viper_air_strike_flash_timer": 0.0,
		"current_msec": 4000,
	}
	var air_strike_context := {
		"selected_character_type": "viper",
		"viper_jetpack_airborne": true,
		"viper_jetpack_active": true,
		"viper_air_strike_flash_timer": 3.0,
	}
	var playfield_renderer := Stage1PlayfieldRenderer.new()
	var pillar_scene_drawer := Stage1PillarSceneDrawer.new()
	var pillar_ui_renderer := Stage1PillarUiRenderer.new()
	ViperAirborneLod.reset_cache_for_test()
	ViperAirborneLod.effect_scale(glide_context)
	glide_context["current_msec"] = 4000 + ViperAirborneLod.GLIDE_SEVERE_ENTER_MSEC
	_expect(
		abs(float(playfield_renderer._get_playfield_quality_scale(glide_context)) - ViperAirborneLod.GLIDE_EFFECT_SCALE) < 0.001,
		"Stage 1 playfield ambience should use Viper glide quality scale"
	)
	_expect(
		abs(float(playfield_renderer._get_playfield_quality_scale(air_strike_context)) - ViperAirborneLod.LOD_EFFECT_SCALE) < 0.001,
		"Stage 1 playfield ambience should use the strongest Viper air-strike quality scale"
	)
	_expect(
		playfield_renderer._get_lod_count(
			Stage1PlayfieldRenderer.STAGE1_CYBER_SCANLINE_COUNT,
			Stage1PlayfieldRenderer.STAGE1_CYBER_SCANLINE_COUNT_LOD,
			Stage1PlayfieldRenderer.STAGE1_CYBER_SCANLINE_COUNT_SEVERE_LOD,
			ViperAirborneLod.GLIDE_EFFECT_SCALE
		) < Stage1PlayfieldRenderer.STAGE1_CYBER_SCANLINE_COUNT,
		"Stage 1 playfield LOD should reduce ambient scanline work"
	)
	_expect(
		playfield_renderer._get_lod_count(
			Stage1PlayfieldRenderer.STAGE1_CYBER_GLITCH_BAND_COUNT,
			Stage1PlayfieldRenderer.STAGE1_CYBER_GLITCH_BAND_COUNT_LOD,
			Stage1PlayfieldRenderer.STAGE1_CYBER_GLITCH_BAND_COUNT_SEVERE_LOD,
			ViperAirborneLod.GLIDE_EFFECT_SCALE
		) == Stage1PlayfieldRenderer.STAGE1_CYBER_GLITCH_BAND_COUNT_SEVERE_LOD,
		"Stage 1 severe Viper glide LOD should use the tight ambient glitch budget"
	)
	_expect(
		abs(float(pillar_scene_drawer._get_pillar_quality_scale(glide_context)) - ViperAirborneLod.GLIDE_EFFECT_SCALE) < 0.001,
		"Stage 1 pillar background should use Viper glide quality scale"
	)
	_expect(
		abs(float(pillar_ui_renderer._get_hud_lod_scale(glide_context)) - ViperAirborneLod.GLIDE_EFFECT_SCALE) < 0.001,
		"Stage 1 pillar HUD should use Viper glide quality scale"
	)
	_expect(
		abs(float(pillar_ui_renderer._get_hud_lod_scale(air_strike_context)) - ViperAirborneLod.LOD_EFFECT_SCALE) < 0.001,
		"Stage 1 pillar HUD should use the strongest Viper air-strike quality scale"
	)
	var pillar_pass_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_pillar_draw_pass.gd")
	_expect(
		pillar_pass_source.find("_append_viper_lod_context(context, registry)") >= 0,
		"pillar draw pass should add Viper jetpack state before resolving pillar LOD"
	)
	_expect(
		abs(float(pillar_ui_renderer._get_hud_lod_scale({"selected_character_type": "soldier"})) - BattleRenderQuality.effect_scale({"selected_character_type": "soldier"})) < 0.001,
		"non-Viper Stage 1 pillar HUD should use the shared capped-frame render quality"
	)


func _verify_viper_skill_context_uses_lod() -> void:
	_expect(
		ViperSkillParticleDrawer.SEVERE_LOD_SCALE_THRESHOLD >= ViperAirborneLod.LOD_EFFECT_SCALE,
		"Viper skill renderer should classify Air Strike LOD as severe"
	)
	_expect(
		ViperSkillParticleDrawer.IGNITION_SEVERE_LOD_SCALE_THRESHOLD >= BattleRenderQuality.FPS_CAP_EFFECT_SCALE,
		"Ignition Aura should use severe draw budgets under the 72 FPS cap LOD"
	)
	_expect(
		ViperSkillParticleDrawer.SEVERE_LOD_DIVE_PARTICLE_DRAW_LIMIT <= 42,
		"Viper dive particles should keep a tight severe-LOD draw cap"
	)
	_expect(
		ViperSkillParticleDrawer.SEVERE_LOD_IGNITION_PARTICLE_DRAW_LIMIT <= 48,
		"Viper ignition particles should keep a tight severe-LOD draw cap"
	)
	var effects_source := FileAccess.get_file_as_string("res://scripts/core/battle_playfield_effects_drawer.gd")
	_expect(
		_function_body(effects_source, "func draw_viper_skill_effects").find("ViperAirborneLod.effect_scale(draw_context)") >= 0,
		"Viper skill draw pass should derive its LOD from the shared playfield context"
	)
	_expect(
		_function_body(effects_source, "func draw_viper_skill_effects").find("effect_lod_scale") >= 0,
		"Viper skill draw pass should forward the LOD scale into the runtime renderer"
	)
	var runtime_source := FileAccess.get_file_as_string("res://scripts/characters/viper_skill_runtime.gd")
	_expect(
		_function_body(runtime_source, "func draw").find("effect_lod_scale: float = 1.0") >= 0,
		"Viper skill runtime draw should accept an optional LOD scale"
	)
	var particle_source := FileAccess.get_file_as_string("res://scripts/characters/viper_skill_particle_drawer.gd")
	_expect(
		_function_body(particle_source, "func draw_dive_effects").find("effect_lod_scale") >= 0,
		"Viper dive effect draw should use the forwarded LOD scale"
	)
	_expect(
		_function_body(particle_source, "func draw_ignition_aura_effects").find("effect_lod_scale") >= 0,
		"Viper ignition effect draw should use the forwarded LOD scale"
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
