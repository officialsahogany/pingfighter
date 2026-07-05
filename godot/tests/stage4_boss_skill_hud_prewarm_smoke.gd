extends SceneTree

const Stage4PonkBossSkillHudRenderer := preload("res://scripts/stages/stage4/stage4_ponk_boss_skill_hud_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	var renderer := Stage4PonkBossSkillHudRenderer.new()
	_expect(renderer.has_method("prewarm_assets_step"), "Stage 4 boss skill HUD should expose staged asset prewarm")
	_expect(not bool(renderer.prewarm_assets_step()), "first Stage 4 boss skill HUD prewarm step should not load every skillcard")
	_expect(_texture_cache_size(renderer) == 1, "first Stage 4 boss skill HUD prewarm step should load exactly one skillcard texture")
	_expect(not bool(renderer.prewarm_assets_step()), "second Stage 4 boss skill HUD prewarm step should wait for the illusion skillcard")
	_expect(_texture_cache_size(renderer) == 2, "second Stage 4 boss skill HUD prewarm step should load two skillcard textures")
	_expect(bool(renderer.prewarm_assets_step()), "third Stage 4 boss skill HUD prewarm step should complete")
	_expect(_texture_cache_size(renderer) == 3, "completed Stage 4 boss skill HUD prewarm should load all three skillcard textures")
	_expect(bool(renderer.prewarm_assets_step()), "completed Stage 4 boss skill HUD prewarm should remain idempotent")

	if _failures.is_empty():
		print("stage4_boss_skill_hud_prewarm_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _texture_cache_size(renderer: Object) -> int:
	var textures: Variant = renderer.get("_textures")
	if textures is Dictionary:
		return (textures as Dictionary).size()
	return -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
