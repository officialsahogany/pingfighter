extends SceneTree

# expect-zero-object-leaks
const DefeatContinueSceneRenderer := preload("res://scripts/core/defeat_continue_scene_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_source_rect_contract()
	_verify_source_ownership()
	if _failures.is_empty():
		print("defeat_continue_scene_renderer_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_source_rect_contract() -> void:
	var standard := PlaceholderTexture2D.new()
	standard.size = Vector2(400.0, 200.0)
	var stage1 := DefeatContinueSceneRenderer.get_boss_victory_source_rect(standard, 1, 5)
	_expect(stage1 == Rect2(Vector2(100.0, 100.0), Vector2(100.0, 100.0)), "stage 1 portal sheet must preserve its 4x2 frame projection")
	var stage2 := DefeatContinueSceneRenderer.get_boss_victory_source_rect(standard, 2, 9)
	_expect(stage2 == Rect2(Vector2(100.0, 100.0), Vector2(100.0, 50.0)), "stage 2 portal sheet must use its 4x4 Cheongringwi frame projection")
	var wrapped := DefeatContinueSceneRenderer.get_boss_victory_source_rect(standard, 1, -1)
	_expect(wrapped == Rect2(Vector2(300.0, 100.0), Vector2(100.0, 100.0)), "negative frame indices must wrap within the portal sheet")

	var portrait := PlaceholderTexture2D.new()
	portrait.size = Vector2(100.0, 200.0)
	var stage4 := DefeatContinueSceneRenderer.get_boss_victory_source_rect(portrait, 4, 7)
	_expect(stage4 == Rect2(Vector2.ZERO, Vector2(100.0, 200.0)), "portrait stage 4+ victory art must remain a single frame")
	var missing := DefeatContinueSceneRenderer.get_boss_victory_source_rect(null, 1, 0)
	_expect(missing.size == Vector2.ZERO, "missing portal texture must return an empty source rectangle")


func _verify_source_ownership() -> void:
	var renderer_source := FileAccess.get_file_as_string("res://scripts/core/defeat_continue_scene_renderer.gd")
	var screen_source := FileAccess.get_file_as_string("res://scripts/core/defeat_chance_gems_continue_screen.gd")
	var texture_paths_source := FileAccess.get_file_as_string("res://scripts/resources/battle_core_texture_paths.gd")
	_expect(renderer_source.contains("func draw_scene_backdrop"), "scene renderer must own backdrop drawing")
	_expect(renderer_source.contains("func _draw_backdrop_vignette_bands"), "scene renderer must own vignette drawing")
	_expect(renderer_source.contains("func draw_entry_reveal_glow"), "scene renderer must own reveal glow drawing")
	_expect(renderer_source.contains("func draw_reveal_veil"), "scene renderer must own reveal veil drawing")
	_expect(renderer_source.contains("func draw_boss_portal_figure"), "scene renderer must own boss portal drawing")
	_expect(texture_paths_source.contains("defeat_continue_backdrop_hwangyeokjeon_imagegen_v1.png"), "defeat scene must route to the Hwangyeokjeon gwimun backdrop")
	_expect(not texture_paths_source.contains("\"res://assets/sprites/hud/defeat_continue_backdrop.png\""), "legacy Western portal backdrop must stay off the production route")
	_expect(not renderer_source.contains("func _process"), "scene renderer must remain caller-clocked")
	_expect(screen_source.contains("DefeatContinueSceneRenderer.draw_scene_backdrop"), "continue screen must delegate backdrop drawing")
	_expect(screen_source.contains("DefeatContinueSceneRenderer.draw_boss_portal_figure"), "continue screen must delegate boss portal drawing")
	_expect(not screen_source.contains("func _draw_scene_backdrop"), "continue screen must not retain backdrop drawing policy")
	_expect(not screen_source.contains("func _draw_backdrop_vignette_bands"), "continue screen must not retain vignette drawing policy")
	_expect(not screen_source.contains("func _draw_entry_reveal_glow"), "continue screen must not retain reveal glow drawing policy")
	_expect(not screen_source.contains("func _draw_reveal_veil"), "continue screen must not retain reveal veil drawing policy")
	_expect(not screen_source.contains("func _draw_boss_portal_figure"), "continue screen must not retain boss portal drawing policy")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
