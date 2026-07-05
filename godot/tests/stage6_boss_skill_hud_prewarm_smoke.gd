extends SceneTree

const Stage6TetriserBossSkillHudRenderer := preload("res://scripts/stages/stage6/stage6_tetriser_boss_skill_hud_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	var renderer := Stage6TetriserBossSkillHudRenderer.new()
	_expect(renderer.has_method("prewarm_assets_step"), "Stage 6 boss skill HUD should expose staged asset prewarm")
	_expect(not bool(renderer.prewarm_assets_step()), "first Stage 6 boss skill HUD prewarm step should not load every skillcard")
	_expect(_texture_cache_size(renderer) == 1, "first Stage 6 boss skill HUD prewarm step should touch exactly one skillcard path")
	_expect(not bool(renderer.prewarm_assets_step()), "second Stage 6 boss skill HUD prewarm step should still be staged")
	_expect(_texture_cache_size(renderer) == 2, "second Stage 6 boss skill HUD prewarm step should touch two skillcard paths")
	_expect(not bool(renderer.prewarm_assets_step()), "third Stage 6 boss skill HUD prewarm step should still be staged")
	_expect(_texture_cache_size(renderer) == 3, "third Stage 6 boss skill HUD prewarm step should touch three skillcard paths")
	_expect(bool(renderer.prewarm_assets_step()), "fourth Stage 6 boss skill HUD prewarm step should complete")
	_expect(_texture_cache_size(renderer) == 4, "completed Stage 6 boss skill HUD prewarm should touch all four skillcard paths")
	_expect(bool(renderer.prewarm_assets_step()), "completed Stage 6 boss skill HUD prewarm should remain idempotent")

	var asset_status: Dictionary = renderer.get_asset_status()
	for key in [
		"tetro_drop_card_texture",
		"guard_block_card_texture",
		"tetro_wall_card_texture",
		"super_tetriser_card_texture",
	]:
		_expect(bool(asset_status.get(key, false)), "Stage 6 boss skill HUD should load %s" % key)

	if _failures.is_empty():
		print("stage6_boss_skill_hud_prewarm_smoke: ok")
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
