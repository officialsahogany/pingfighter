extends SceneTree

const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const Stage5HongryunBossSkillHudRenderer := preload("res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd")
const Stage5HongryunPillarSceneDrawer := preload("res://scripts/stages/stage5/stage5_hongryun_pillar_scene_drawer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_stage5_pillar_hud_lod_context()
	_verify_stage5_boss_skill_hud_lod_contract()

	if _failures.is_empty():
		print("stage5_hud_lod_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage5_pillar_hud_lod_context() -> void:
	var drawer := Stage5HongryunPillarSceneDrawer.new()
	var normal_context := {"selected_character_type": "smasher"}
	var normal_hud_context: Dictionary = drawer._with_stage5_hud_lod_context(normal_context, 1.0)
	_expect(
		not bool(normal_hud_context.get("pillar_hud_static_lod", false)),
		"Stage 5 normal HUD should keep ornamental pillar layers"
	)

	var previous_max_fps: int = int(Engine.get("max_fps"))
	Engine.set("max_fps", 144)
	BattleRenderQuality.reset_cache_for_test()
	var quality_scale: float = drawer._get_pillar_quality_scale(normal_context)
	var high_refresh_hud_context: Dictionary = drawer._with_stage5_hud_lod_context(normal_context, quality_scale)
	Engine.set("max_fps", previous_max_fps)
	BattleRenderQuality.reset_cache_for_test()

	_expect(quality_scale < 0.85, "Stage 5 pillar chrome should honor high-refresh render LOD")
	_expect(
		bool(high_refresh_hud_context.get("stage5_pillar_hud_static_lod", false)),
		"Stage 5 high-refresh HUD should expose its Stage 5 static LOD marker"
	)
	_expect(
		bool(high_refresh_hud_context.get("pillar_hud_static_lod", false)),
		"Stage 5 high-refresh HUD should trim shared ornamental pillar layers"
	)
	_expect(
		Stage5HongryunPillarSceneDrawer.INFERNO_PILLAR_TRAIL_RENDER_LIMIT_SEVERE_LOD <= 6,
		"Stage 5 pillar flourish should cap inferno letterbox wisps under severe LOD"
	)


func _verify_stage5_boss_skill_hud_lod_contract() -> void:
	_expect(
		Stage5HongryunBossSkillHudRenderer.EMPTY_ORB_ARC_SEGMENTS_SEVERE_LOD <= 14,
		"Stage 5 boss skill HUD should reduce dragon orb arc segments under severe LOD"
	)
	_expect(
		Stage5HongryunBossSkillHudRenderer.INFERNO_WEDGE_SEGMENTS_BASE_SEVERE_LOD <= 8.0,
		"Stage 5 boss skill HUD should reduce inferno charge wedge segments under severe LOD"
	)

	var pillar_source := FileAccess.get_file_as_string("res://scripts/stages/stage5/stage5_hongryun_pillar_scene_drawer.gd")
	var boss_hud_source := FileAccess.get_file_as_string("res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd")
	_expect(
		pillar_source.find("_with_stage5_hud_lod_context(context, quality_scale)") >= 0,
		"Stage 5 pillar draw should route HUD context through the LOD helper"
	)
	_expect(
		pillar_source.find("stage5_hud_quality_scale") >= 0,
		"Stage 5 pillar drawer should pass the pillar quality scale to the boss skill HUD"
	)
	_expect(
		boss_hud_source.find("stage5_hud_quality_scale") >= 0,
		"Stage 5 boss skill HUD should read the pillar quality scale"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
