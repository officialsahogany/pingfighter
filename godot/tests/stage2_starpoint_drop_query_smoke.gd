extends SceneTree

const Stage2CollisionGeometry := preload("res://scripts/stages/stage2/stage2_collision_geometry.gd")
const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const Stage2StarpointDropQuery := preload("res://scripts/stages/stage2/stage2_starpoint_drop_query.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_collect_radius()
	_verify_overlap_query()
	_verify_background_delegates_drop_query()

	if _failures.is_empty():
		print("stage2_starpoint_drop_query_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_collect_radius() -> void:
	var radius := Stage2StarpointDropQuery.get_collect_radius({"size": 10.0}, 12.0)
	_expect(is_equal_approx(radius, 11.8), "starpoint query should scale explicit drop size")
	var fallback_radius := Stage2StarpointDropQuery.get_collect_radius({}, 12.0)
	_expect(is_equal_approx(fallback_radius, 14.16), "starpoint query should scale fallback drop size")


func _verify_overlap_query() -> void:
	var collision_geometry := Stage2CollisionGeometry.new()
	var player_rects: Array[Rect2] = [Rect2(Vector2(95.0, 95.0), Vector2(20.0, 20.0))]
	_expect(
		Stage2StarpointDropQuery.overlaps_any_player(
			{"pos": Vector2(100.0, 100.0), "size": 10.0},
			player_rects,
			collision_geometry,
			12.0
		),
		"starpoint query should detect overlapping player rects"
	)
	_expect(
		not Stage2StarpointDropQuery.overlaps_any_player(
			{"pos": Vector2(200.0, 200.0), "size": 10.0},
			player_rects,
			collision_geometry,
			12.0
		),
		"starpoint query should ignore distant player rects"
	)


func _verify_background_delegates_drop_query() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(
		source.find("Stage2StarpointDropQuery.overlaps_any_player") >= 0,
		"Stage 2 background source should delegate starpoint drop overlap checks"
	)
	var background := Stage2PillarBackground.new()
	background.starpoint_drops = [{
		"life": 10.0,
		"pos": Vector2(100.0, 100.0),
		"vel": Vector2.ZERO,
		"size": 12.0,
	}]
	background._update_starpoint_drops(0.0, {
		"current_stage": 2,
		"player_pos": Vector2(98.0, 98.0),
		"player_paddle_size": Vector2(20.0, 20.0),
		"play_left": 0.0,
		"play_right": 760.0,
		"height": 750.0,
	}, {})
	_expect(background.starpoint_drops.is_empty(), "Stage 2 background should collect overlapping starpoint drops")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
