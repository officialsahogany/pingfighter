extends SceneTree

const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const Stage3PlayfieldRenderer := preload("res://scripts/stages/stage3/stage3_playfield_renderer.gd")
const Stage3EffectRenderer := preload("res://scripts/stages/stage3/stage3_menhera_skill_effect_renderer.gd")
const Stage3BossRenderer := preload("res://scripts/stages/stage3/stage3_menhera_boss_actor_renderer.gd")
const Stage3PillarBackground := preload("res://scripts/stages/stage3/stage3_pillar_background.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_stage3_shared_render_quality_lod()
	_verify_stage3_sources_use_shared_lod()

	if _failures.is_empty():
		print("stage3_shared_render_quality_lod_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage3_shared_render_quality_lod() -> void:
	var old_max_fps: int = int(Engine.get("max_fps"))
	Engine.set("max_fps", BattleRenderQuality.FPS_CAP_LOD_MAX_FPS)
	BattleRenderQuality.reset_cache_for_test()

	var context := {"selected_character_type": "soldier"}
	var playfield := Stage3PlayfieldRenderer.new()
	var effect_renderer := Stage3EffectRenderer.new()
	var boss_renderer := Stage3BossRenderer.new()
	var pillar_background := Stage3PillarBackground.new()
	var expected_quality := BattleRenderQuality.FPS_CAP_EFFECT_SCALE

	_expect(
		is_equal_approx(playfield._get_playfield_quality_scale(context), expected_quality),
		"Stage 3 playfield should honor shared 72 FPS-cap render LOD for Soldier"
	)
	_expect(
		is_equal_approx(effect_renderer._get_effect_quality_scale(context), expected_quality),
		"Stage 3 effect renderer should honor shared 72 FPS-cap render LOD for Soldier"
	)
	_expect(
		is_equal_approx(boss_renderer._get_actor_quality_scale(context), expected_quality),
		"Stage 3 Menhera boss renderer should honor shared 72 FPS-cap render LOD for Soldier"
	)
	_expect(
		is_equal_approx(pillar_background._get_pillar_quality_scale(context), expected_quality),
		"Stage 3 pillar background should honor shared 72 FPS-cap render LOD for Soldier"
	)

	Engine.set("max_fps", old_max_fps)
	BattleRenderQuality.reset_cache_for_test()


func _verify_stage3_sources_use_shared_lod() -> void:
	for path in [
		"res://scripts/stages/stage3/stage3_playfield_renderer.gd",
		"res://scripts/stages/stage3/stage3_menhera_skill_effect_renderer.gd",
		"res://scripts/stages/stage3/stage3_menhera_boss_actor_renderer.gd",
		"res://scripts/stages/stage3/stage3_pillar_background.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		_expect(source.find("BattleRenderQuality.effect_scale(context)") >= 0, "%s should use shared render-quality LOD" % path)
	var playfield_source := FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_playfield_renderer.gd")
	_expect(
		playfield_source.find("MAX_ELLIPSE_OUTLINE_POINTS_CACHE_ENTRIES") >= 0
			and playfield_source.find("ellipse_outline_points_cache") >= 0,
		"Stage 3 playfield should cache closed ellipse outline point arrays"
	)
	_expect(
		_function_body(playfield_source, "func _draw_ellipse_outline(").find("_ellipse_outline_points") >= 0
			and _function_body(playfield_source, "func _draw_ellipse_outline(").find("points.duplicate()") < 0,
		"Stage 3 ellipse outline draw should not duplicate PackedVector2Array data every frame"
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
