extends SceneTree

const Stage3PillarSceneDrawer := preload("res://scripts/stages/stage3/stage3_pillar_scene_drawer.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const ViperAirborneLod := preload("res://scripts/core/viper_airborne_lod.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_stage3_pillar_hud_lod_context()

	if _failures.is_empty():
		print("stage3_pillar_hud_lod_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage3_pillar_hud_lod_context() -> void:
	var drawer := Stage3PillarSceneDrawer.new()
	_expect(
		float(Stage3PillarSceneDrawer.STAGE3_STATIC_HUD_LOD_SCALE) >= ViperAirborneLod.GLIDE_EFFECT_SCALE,
		"Stage 3 pillar HUD static LOD should cover Viper glide / 72 FPS-cap render windows"
	)

	var previous_max_fps: int = int(Engine.get("max_fps"))
	Engine.set("max_fps", 90)
	_expect(
		not bool(drawer._should_stage3_hud_static_lod(ViperAirborneLod.AIRBORNE_EFFECT_SCALE)),
		"Stage 3 normal airborne Viper HUD should keep ornamental pillar orb layers"
	)
	Engine.set("max_fps", 60)
	var capped_quality_scale := drawer._get_pillar_quality_scale({"selected_character_type": "smasher"})
	_expect(
		is_equal_approx(capped_quality_scale, BattleRenderQuality.FPS_CAP_EFFECT_SCALE),
		"Stage 3 pillar quality should follow the global 72 FPS-cap render LOD"
	)
	_expect(
		bool(drawer._should_stage3_hud_static_lod(capped_quality_scale)),
		"Stage 3 FPS-cap HUD should trim ornamental pillar orb layers even without Viper airborne flags"
	)
	_expect(
		bool(drawer._should_stage3_hud_static_lod(ViperAirborneLod.GLIDE_EFFECT_SCALE)),
		"Stage 3 Viper glide / FPS-cap HUD should trim ornamental pillar orb layers"
	)

	Engine.set("max_fps", 144)
	_expect(
		bool(drawer._should_stage3_hud_static_lod(1.0)),
		"Stage 3 high-refresh HUD should trim ornamental pillar orb layers"
	)
	Engine.set("max_fps", previous_max_fps)

	var source := FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_pillar_scene_drawer.gd")
	var boss_hud_source := FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd")
	_expect(source.find("_draw_stage3_shared_pillar_hud") >= 0, "Stage 3 pillar draw should route HUD through the shared LOD helper")
	_expect(source.find("stage3_pillar_hud_static_lod") >= 0, "Stage 3 pillar HUD should expose its static LOD marker")
	_expect(
		_function_body(source, "func _draw_stage3_shared_pillar_hud").find("context.duplicate()") < 0
			and _function_body(source, "func _draw_stage3_shared_pillar_hud").find("context.erase(\"pillar_hud_static_lod\")") >= 0,
		"Stage 3 pillar HUD LOD should avoid per-frame full context copies and restore temporary flags"
	)
	_expect(
		_function_body(source, "func _draw_stage3_boss_skill_hud").find("context.duplicate()") < 0
			and source.find("hud_context[\"current_stage\"] = 3") >= 0,
		"Stage 3 boss skill HUD should build a compact draw context instead of copying the full battle context"
	)
	_expect(
		boss_hud_source.find("_metrics_cache_pillar_width") >= 0
			and _function_body(boss_hud_source, "func draw(").find("var entries := skills") >= 0
			and boss_hud_source.find("func _skill_entries") < 0,
		"Stage 3 boss skill HUD should reuse metrics and avoid copying the skill array every draw"
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
