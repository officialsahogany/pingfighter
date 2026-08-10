extends SceneTree

const SCENE_PATH := "res://scripts/plaza/plaza_scene.gd"

var _failures: Array[String] = []


func _init() -> void:
	var source := FileAccess.get_file_as_string(SCENE_PATH)
	_expect(source.contains("const PlazaActorVisualProjection := preload"), "plaza scene should preload the actor projection")
	_expect(source.contains("const PlazaActorRenderer := preload"), "plaza scene should preload the actor renderer")
	_expect(source.contains("const PlazaBuildingRenderer := preload"), "plaza scene should preload the building renderer")
	for legacy_constant in [
		"const PLAYER_SPRITE_DRAW_SIZE",
		"const PLAYER_SPRITE_FOOT_OFFSET",
		"const LINGPET_FOLLOW_OFFSET_X",
		"const LINGPET_FOLLOW_OFFSET_Y",
		"const LINGPET_COMPANION_GRID_COLS",
		"const LINGPET_COMPANION_GRID_ROWS",
		"const LINGPET_COMPANION_FRAME_COUNT",
	]:
		_expect(not source.contains(legacy_constant), "scene should not duplicate %s" % legacy_constant)
	var building_body := _function_body(source, "_draw_building")
	_expect(building_body.contains("PlazaBuildingRenderer.draw("), "building draw should delegate to the renderer")
	var player_body := _function_body(source, "_draw_player")
	_expect(player_body.contains("PlazaActorRenderer.draw_player("), "player draw should delegate to the actor renderer")
	var lingpet_body := _function_body(source, "_draw_lingpet_follower")
	_expect(lingpet_body.contains("PlazaActorRenderer.draw_lingpet("), "Lingpet draw should delegate to the actor renderer")
	for removed_method in ["_draw_player_sheet", "_draw_player_placeholder", "_draw_ground_shadow"]:
		_expect(not source.contains("func %s(" % removed_method), "scene should not retain actor renderer method %s" % removed_method)
	_expect(_function_body(source, "_is_player_walking").contains("PlazaActorVisualProjection.is_player_walking"), "walking facade should delegate to the actor projection")
	_expect(_function_body(source, "_get_player_facing_direction").contains("PlazaActorVisualProjection.get_facing_direction"), "facing facade should delegate to the actor projection")
	_expect(_function_body(source, "_get_player_sprite_frame").contains("PlazaActorVisualProjection.get_player_sprite_frame"), "frame facade should delegate to the actor projection")
	_expect(_function_body(source, "_get_sheet_frame_rect").contains("PlazaActorVisualProjection.get_sheet_frame_rect"), "sheet facade should delegate to the actor projection")
	var follower_body := _function_body(source, "_update_lingpet_follower")
	_expect(follower_body.contains("PlazaActorVisualProjection.get_lingpet_follow_target"), "Lingpet follow target should use the actor projection")
	_expect(follower_body.contains("PlazaActorVisualProjection.project_lingpet_follower_position"), "Lingpet follow motion should use the actor projection")

	if _failures.is_empty():
		print("plaza_actor_building_renderer_owner_integration_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _function_body(source: String, method: String) -> String:
	var start := source.find("func %s(" % method)
	if start < 0:
		return ""
	var end := source.find("\nfunc ", start + method.length())
	return source.substr(start) if end < 0 else source.substr(start, end - start)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
