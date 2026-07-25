extends SceneTree

const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")
const PlazaWorldGeometry := preload("res://scripts/plaza/plaza_world_geometry.gd")
const PlazaBuildingRenderer := preload("res://scripts/plaza/plaza_building_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_fit_and_camera_projection()
	_verify_coordinate_round_trip()
	_verify_building_hit_policies()
	_verify_building_render_projection()
	_verify_scene_facade()
	if _failures.is_empty():
		print("plaza_world_geometry_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_fit_and_camera_projection() -> void:
	var fitted := PlazaWorldGeometry.fit_game_rect(Vector2(1920.0, 1080.0), Vector2(760.0, 750.0))
	_expect_vec(fitted.size, Vector2(1094.4, 1080.0), "16:9 viewport should fit by height")
	_expect_vec(fitted.position, Vector2(412.8, 0.0), "fitted game rect should stay centered")
	_expect(PlazaWorldGeometry.fit_game_rect(Vector2.ZERO, Vector2(760.0, 750.0)) == Rect2(), "zero viewport should produce an empty fit")
	_expect_close(PlazaWorldGeometry.get_game_scale(Vector2(1520.0, 1500.0), Vector2(760.0, 750.0)), 2.0, "render scale")
	_expect_close(PlazaWorldGeometry.get_target_camera_x(120.0, 760.0, 1900.0, 100.0), 0.0, "camera left clamp")
	_expect_close(PlazaWorldGeometry.get_target_camera_x(1000.0, 760.0, 1900.0, 100.0), 720.0, "camera tracking")
	_expect_close(PlazaWorldGeometry.get_target_camera_x(1900.0, 760.0, 1900.0, 100.0), 1140.0, "camera right clamp")
	_expect_vec(
		PlazaWorldGeometry.normalize_player_position(Vector2(-50.0, 10.0), Vector2(1900.0, 750.0), 666.0, Vector2(38.0, 32.0)),
		Vector2(19.0, 666.0),
		"player position should clamp to the left edge and ground line"
	)
	_expect_vec(
		PlazaWorldGeometry.normalize_player_position(Vector2(2000.0, 900.0), Vector2(1900.0, 750.0), 666.0, Vector2(38.0, 32.0)),
		Vector2(1881.0, 666.0),
		"player position should clamp to the right edge and ground line"
	)


func _verify_coordinate_round_trip() -> void:
	var world_position := Vector2(500.0, 100.0)
	var local_position := PlazaWorldGeometry.world_to_local(world_position, 200.0, 2.0)
	_expect_vec(local_position, Vector2(600.0, 200.0), "world-to-local projection")
	var local_rect := PlazaWorldGeometry.world_rect_to_local(Rect2(world_position, Vector2(40.0, 20.0)), 200.0, 2.0)
	_expect_rect(local_rect, Rect2(Vector2(600.0, 200.0), Vector2(80.0, 40.0)), "world rect projection")
	var screen_position := local_position + Vector2(100.0, 50.0)
	_expect_vec(
		PlazaWorldGeometry.screen_to_world(screen_position, Vector2(100.0, 50.0), 200.0, 2.0),
		world_position,
		"screen-to-world should invert world-to-local projection"
	)
	_expect_vec(
		PlazaWorldGeometry.screen_to_local_game(screen_position, Vector2(100.0, 50.0), 2.0),
		Vector2(300.0, 100.0),
		"screen-to-game projection"
	)
	_expect(PlazaWorldGeometry.screen_to_world(screen_position, Vector2.ZERO, 0.0, 0.0) == Vector2.ZERO, "zero-scale world projection should be safe")
	_expect(PlazaWorldGeometry.screen_to_local_game(screen_position, Vector2.ZERO, 0.0) == Vector2.ZERO, "zero-scale game projection should be safe")


func _verify_building_hit_policies() -> void:
	var specs: Array = [
		{"type": "back", "visual_rect": Rect2(0.0, 0.0, 100.0, 100.0), "interaction_rect": Rect2(10.0, 90.0, 80.0, 20.0)},
		{"type": "front", "visual_rect": Rect2(30.0, 10.0, 100.0, 100.0), "interaction_rect": Rect2(40.0, 90.0, 80.0, 20.0)},
	]
	var overlap := Vector2(50.0, 95.0)
	_expect_eq(str(PlazaWorldGeometry.find_interactable_building(specs, overlap).get("type", "")), "back", "player interaction should preserve spec order")
	_expect_eq(str(PlazaWorldGeometry.find_building_at_world_position(specs, overlap).get("type", "")), "front", "mouse picking should prefer the last-drawn building")
	_expect_eq(str(PlazaWorldGeometry.find_building_at_world_position(specs, Vector2(120.0, 20.0)).get("type", "")), "front", "mouse picking should include the visible building body")
	_expect(PlazaWorldGeometry.find_building_at_world_position(specs, Vector2(500.0, 500.0)).is_empty(), "empty world position should not resolve a building")
	_expect(PlazaWorldGeometry.find_interactable_building([], overlap).is_empty(), "empty building list should be safe")


func _verify_building_render_projection() -> void:
	var explicit_rect := Rect2(20.0, 30.0, 400.0, 500.0)
	_expect_rect(
		PlazaBuildingRenderer.resolve_world_rect({"visual_rect": explicit_rect}),
		explicit_rect,
		"renderer should preserve an explicit building visual rect"
	)
	var fallback_spec := {
		"type": "shop",
		"source_size": Vector2(100.0, 200.0),
		"origin_pivot": Vector2(50.0, 180.0),
		"display_scale": 0.5,
		"pivot_pos": Vector2(300.0, 640.0),
	}
	_expect_rect(
		PlazaBuildingRenderer.resolve_world_rect(fallback_spec),
		Rect2(275.0, 550.0, 50.0, 100.0),
		"renderer should preserve source/pivot fallback projection"
	)
	_expect_eq(PlazaBuildingRenderer.get_flicker_seed(fallback_spec), "shop:300", "renderer should preserve stable type/pivot flicker identity")


func _verify_scene_facade() -> void:
	var scene: Object = PlazaScene.new()
	(scene as Control).size = Vector2(1520.0, 1500.0)
	scene.set("_camera_x", 200.0)
	_expect_close(float(scene.call("_get_game_scale")), 2.0, "scene scale facade")
	_expect_vec(scene.call("_world_to_local", Vector2(500.0, 100.0), 2.0), Vector2(600.0, 200.0), "scene world projection facade")
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
