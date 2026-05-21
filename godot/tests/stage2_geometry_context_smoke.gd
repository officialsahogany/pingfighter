extends SceneTree

const Stage2CollisionGeometry := preload("res://scripts/stages/stage2/stage2_collision_geometry.gd")
const Stage2WaterCannonGeometry := preload("res://scripts/stages/stage2/stage2_water_cannon_geometry.gd")

var _failures: Array[String] = []


class FakeWarpGateState:
	extends RefCounted

	func get_mirror_offset_x(_player_pos: Vector2, _player_width: float) -> float:
		return 42.0


func _init() -> void:
	_verify_player_rect_from_context()
	_verify_player_interaction_rects_from_context()
	_verify_boss_cannon_start_from_context()
	_verify_background_delegates_context_geometry()

	if _failures.is_empty():
		print("stage2_geometry_context_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_player_rect_from_context() -> void:
	var geometry := Stage2CollisionGeometry.new()
	var rect: Rect2 = geometry.get_player_rect_from_context({
		"player_pos": Vector2(30.0, 40.0),
		"player_paddle_size": Vector2(70.0, 20.0),
	}, Vector2(155.0, 50.0))
	_expect(rect.position == Vector2(30.0, 40.0), "collision geometry should read player position from context")
	_expect(rect.size == Vector2(70.0, 20.0), "collision geometry should read player size from context")
	var fallback_rect: Rect2 = geometry.get_player_rect_from_context({}, Vector2(155.0, 50.0))
	_expect(fallback_rect.size == Vector2(155.0, 50.0), "collision geometry should use fallback player size")


func _verify_player_interaction_rects_from_context() -> void:
	var geometry := Stage2CollisionGeometry.new()
	var rects: Array[Rect2] = geometry.get_player_interaction_rects_from_context({
		"player_pos": Vector2(30.0, 40.0),
		"player_paddle_size": Vector2(70.0, 20.0),
	}, {
		"smasher_warp_gate_state": FakeWarpGateState.new(),
	}, Vector2(155.0, 50.0))
	_expect(rects.size() == 2, "collision geometry should include warp-gate mirror interaction rects")
	_expect(rects[1].position == Vector2(72.0, 40.0), "collision geometry should offset mirrored player rects")

	var empty_rects: Array[Rect2] = geometry.get_player_interaction_rects_from_context({
		"player_pos": Vector2.ZERO,
		"player_paddle_size": Vector2.ZERO,
	}, {}, Vector2(155.0, 50.0))
	_expect(empty_rects.is_empty(), "collision geometry should reject empty player rects")


func _verify_boss_cannon_start_from_context() -> void:
	var geometry := Stage2WaterCannonGeometry.new()
	var start: Vector2 = geometry.get_boss_cannon_start_from_context({
		"boss_pos": Vector2(100.0, 50.0),
		"boss_paddle_width": 120.0,
		"boss_hitbox_height": 44.0,
	})
	_expect(start == Vector2(160.0, 124.0), "water cannon geometry should read boss cannon start from context")


func _verify_background_delegates_context_geometry() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(
		source.find("get_player_interaction_rects_from_context") >= 0,
		"Stage 2 background source should delegate player interaction rect context assembly"
	)
	_expect(
		source.find("get_boss_cannon_start_from_context") >= 0,
		"Stage 2 background source should delegate boss cannon start context assembly"
	)
	_expect(
		source.find("func _get_boss_cannon_start") < 0,
		"Stage 2 background source should not keep the old boss cannon wrapper"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
