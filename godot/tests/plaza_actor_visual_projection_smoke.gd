extends SceneTree

const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")
const PlazaActorVisualProjection := preload("res://scripts/plaza/plaza_actor_visual_projection.gd")
const PlazaActorRenderer := preload("res://scripts/plaza/plaza_actor_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_player_motion_projection()
	_verify_sheet_projection()
	_verify_renderer_texture_priority()
	_verify_lingpet_follow_projection()
	_verify_scene_facade()
	if _failures.is_empty():
		print("plaza_actor_visual_projection_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_player_motion_projection() -> void:
	_expect(PlazaActorVisualProjection.is_player_walking(true, Vector2.RIGHT, Vector2.ZERO), "test input should drive walking when active")
	_expect(not PlazaActorVisualProjection.is_player_walking(true, Vector2(0.01, 0.0), Vector2.RIGHT), "walking threshold should remain strict and test input should override live input")
	_expect(PlazaActorVisualProjection.is_player_walking(false, Vector2.ZERO, Vector2.LEFT), "live input should drive walking outside test mode")
	_expect_eq(PlazaActorVisualProjection.get_facing_direction(Vector2.LEFT), -1, "left-facing projection")
	_expect_eq(PlazaActorVisualProjection.get_facing_direction(Vector2.ZERO), 1, "neutral facing should default right")
	_expect_eq(PlazaActorVisualProjection.get_player_sprite_frame(0, true, 8), 0, "walk frame start")
	_expect_eq(PlazaActorVisualProjection.get_player_sprite_frame(95, true, 8), 1, "walk frame advance")
	_expect_eq(PlazaActorVisualProjection.get_player_sprite_frame(759, true, 8), 7, "walk frame end")
	_expect_eq(PlazaActorVisualProjection.get_player_sprite_frame(760, true, 8), 0, "walk frame wrap")
	_expect_eq(PlazaActorVisualProjection.get_player_sprite_frame(130, false, 8), 1, "idle loop should use its slower duration")
	_expect_eq(PlazaActorVisualProjection.get_lingpet_sprite_frame(80), 1, "Lingpet frame advance")
	_expect_eq(PlazaActorVisualProjection.get_lingpet_sprite_frame(2000), 0, "Lingpet frame wrap")


func _verify_sheet_projection() -> void:
	_expect_rect(
		PlazaActorVisualProjection.get_sheet_frame_rect(Vector2(500.0, 500.0), 24, 5, 5),
		Rect2(400.0, 400.0, 100.0, 100.0),
		"last sheet cell"
	)
	_expect_rect(
		PlazaActorVisualProjection.get_sheet_frame_rect(Vector2(500.0, 500.0), 99, 5, 5),
		Rect2(400.0, 400.0, 100.0, 100.0),
		"sheet frame upper clamp"
	)
	_expect_rect(
		PlazaActorVisualProjection.get_sheet_frame_rect(Vector2(400.0, 200.0), -2, 4, 2),
		Rect2(0.0, 0.0, 100.0, 100.0),
		"sheet frame lower clamp"
	)
	_expect_rect(
		PlazaActorVisualProjection.get_player_draw_rect(Vector2(100.0, 200.0), 2.0),
		Rect2(Vector2(-48.0, -80.0), Vector2(296.0, 296.0)),
		"player foot-anchored draw rect"
	)
	_expect_rect(
		PlazaActorVisualProjection.get_lingpet_draw_rect(Vector2(100.0, 200.0), 92.0, 2.0),
		Rect2(Vector2(8.0, 32.0), Vector2(184.0, 184.0)),
		"Lingpet foot-anchored draw rect"
	)


func _verify_renderer_texture_priority() -> void:
	var all_textures := {"idle": true, "walk_left": true, "walk_right": true}
	_expect_eq(PlazaActorRenderer.get_player_texture_key(all_textures, true, -1), "walk_left", "moving left should prefer the left walk sheet")
	_expect_eq(PlazaActorRenderer.get_player_texture_key(all_textures, true, 1), "walk_right", "moving right should prefer the right walk sheet")
	_expect_eq(PlazaActorRenderer.get_player_texture_key({"idle": true, "walk_right": true}, true, -1), "idle", "missing directional walk sheet should fall back to idle")
	_expect_eq(PlazaActorRenderer.get_player_texture_key({"walk_right": true}, false, 1), "walk_right", "missing idle should fall back to the facing walk sheet")
	_expect_eq(PlazaActorRenderer.get_player_texture_key({}, false, 1), "", "missing player sheets should select the placeholder path")


func _verify_lingpet_follow_projection() -> void:
	var target := PlazaActorVisualProjection.get_lingpet_follow_target(Vector2(500.0, 666.0), 1, 1900.0, 38.0, 666.0)
	_expect_vec(target, Vector2(442.0, 646.0), "right-facing player follow target")
	_expect_vec(
		PlazaActorVisualProjection.project_lingpet_follower_position(Vector2.ZERO, false, target, 0.0),
		target,
		"uninitialized follower should snap to its target"
	)
	_expect_close(PlazaActorVisualProjection.get_lingpet_follow_blend(1.0 / 60.0), 0.12, "follower blend factor")
	_expect_vec(
		PlazaActorVisualProjection.project_lingpet_follower_position(Vector2(400.0, 646.0), true, target, 1.0 / 60.0),
		Vector2(405.04, 646.0),
		"follower should use the preserved 60-FPS blend"
	)
	_expect_vec(
		PlazaActorVisualProjection.get_lingpet_follow_target(Vector2(500.0, 666.0), -1, 1900.0, 38.0, 666.0),
		Vector2(558.0, 646.0),
		"follower should swap sides for a left-facing player"
	)
	_expect_vec(
		PlazaActorVisualProjection.get_lingpet_follow_target(Vector2(20.0, 666.0), 1, 1900.0, 38.0, 666.0),
		Vector2(19.0, 646.0),
		"follower should clamp at the left world edge"
	)
	_expect_vec(
		PlazaActorVisualProjection.get_lingpet_follow_target(Vector2(1880.0, 666.0), -1, 1900.0, 38.0, 666.0),
		Vector2(1881.0, 646.0),
		"follower should clamp at the right world edge"
	)


func _verify_scene_facade() -> void:
	var scene: Object = PlazaScene.new()
	scene.set("_test_input_active", true)
	scene.set("_test_input_dir", Vector2.LEFT)
	scene.set("_last_input_dir", Vector2.LEFT)
	_expect(bool(scene.call("_is_player_walking")), "scene walking facade")
	_expect_eq(int(scene.call("_get_player_facing_direction")), -1, "scene facing facade")
	_expect(scene.call("_get_sheet_frame_rect", null, 0, 4, 2) == Rect2(), "scene sheet facade should preserve null-texture safety")
	if scene is Node:
		(scene as Node).free()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _expect_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])


func _expect_close(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s: expected %.4f, got %.4f" % [label, expected, actual])


func _expect_vec(actual: Vector2, expected: Vector2, label: String) -> void:
	if not actual.is_equal_approx(expected):
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])


func _expect_rect(actual: Rect2, expected: Rect2, label: String) -> void:
	if not actual.position.is_equal_approx(expected.position) or not actual.size.is_equal_approx(expected.size):
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])
