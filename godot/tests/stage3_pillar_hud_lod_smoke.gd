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
	var airborne_hud_context: Dictionary = drawer._with_stage3_hud_lod_context(
		{
			"selected_character_type": "viper",
			"viper_jetpack_airborne": true,
			"viper_jetpack_active": true,
		},
		ViperAirborneLod.AIRBORNE_EFFECT_SCALE
	)
	_expect(
		not bool(airborne_hud_context.get("pillar_hud_static_lod", false)),
		"Stage 3 normal airborne Viper HUD should keep ornamental pillar orb layers"
	)
	Engine.set("max_fps", 60)
	var capped_quality_scale := drawer._get_pillar_quality_scale({"selected_character_type": "smasher"})
	_expect(
		is_equal_approx(capped_quality_scale, BattleRenderQuality.FPS_CAP_EFFECT_SCALE),
		"Stage 3 pillar quality should follow the global 72 FPS-cap render LOD"
	)
	var capped_hud_context: Dictionary = drawer._with_stage3_hud_lod_context({"selected_character_type": "smasher"}, capped_quality_scale)
	_expect(
		bool(capped_hud_context.get("pillar_hud_static_lod", false)),
		"Stage 3 FPS-cap HUD should trim ornamental pillar orb layers even without Viper airborne flags"
	)
	var glide_hud_context: Dictionary = drawer._with_stage3_hud_lod_context(
		{
			"selected_character_type": "viper",
			"viper_jetpack_airborne": true,
			"viper_jetpack_active": false,
		},
		ViperAirborneLod.GLIDE_EFFECT_SCALE
	)
	_expect(
		bool(glide_hud_context.get("pillar_hud_static_lod", false)),
		"Stage 3 Viper glide / FPS-cap HUD should trim ornamental pillar orb layers"
	)

	Engine.set("max_fps", 144)
	var high_refresh_hud_context: Dictionary = drawer._with_stage3_hud_lod_context({"selected_character_type": "smasher"}, 1.0)
	_expect(
		bool(high_refresh_hud_context.get("pillar_hud_static_lod", false)),
		"Stage 3 high-refresh HUD should trim ornamental pillar orb layers"
	)
	Engine.set("max_fps", previous_max_fps)

	var source := FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_pillar_scene_drawer.gd")
	_expect(source.find("_with_stage3_hud_lod_context(context, quality_scale)") >= 0, "Stage 3 pillar draw should route HUD context through the LOD helper")
	_expect(source.find("stage3_pillar_hud_static_lod") >= 0, "Stage 3 pillar HUD should expose its static LOD marker")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
