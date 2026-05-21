extends SceneTree

const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const Stage2RockQuery := preload("res://scripts/stages/stage2/stage2_rock_query.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_rock_query()
	_verify_background_delegates_rock_query()

	if _failures.is_empty():
		print("stage2_rock_query_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_rock_query() -> void:
	var query := Stage2RockQuery.new()
	var rocks := [
		{"id": 10, "pos": Vector2(100.0, 200.0)},
		{"id": 20, "pos": Vector2(220.0, 300.0), "target_pos": Vector2(240.0, 320.0)},
	]
	_expect(int(query.get_by_id(rocks, 20).get("id", -1)) == 20, "rock query should find rocks by id")
	_expect(query.get_index_by_id(rocks, 10) == 0, "rock query should find rock indexes by id")
	_expect(query.get_index_by_id(rocks, 99) == -1, "rock query should return -1 for missing ids")
	_expect(query.select_random_id([], RandomNumberGenerator.new()) == -1, "rock query should ignore empty random selections")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var selected_id: int = query.select_random_id(rocks, rng)
	_expect([10, 20].has(selected_id), "rock query random selection should return an existing id")
	_expect(not query.needs_runtime_update({}, false), "rock query should ignore inert rocks")
	_expect(query.needs_runtime_update({"falling": true}, false), "rock query should update falling rocks")
	_expect(query.needs_runtime_update({"quake_offset": Vector2(0.2, 0.0)}, false), "rock query should update rocks with visible quake offset")
	_expect(query.needs_runtime_update({}, true), "rock query should update rocks while quake is active")
	var centered_rock := {
		"pos": Vector2.ZERO,
		"target_pos": Vector2(1.0, 2.0),
		"fall_y": -12.0,
		"falling": true,
		"drop_delay": 1.5,
		"quake_offset": Vector2(4.0, 5.0),
	}
	query.set_center(centered_rock, Vector2(44.0, 55.0))
	_expect(centered_rock.get("pos", Vector2.ZERO) == Vector2(44.0, 55.0), "rock query should set rock position to center")
	_expect(centered_rock.get("target_pos", Vector2.ZERO) == Vector2(44.0, 55.0), "rock query should set rock target to center")
	_expect(float(centered_rock.get("fall_y", 0.0)) == 55.0, "rock query should update fall_y when present")
	_expect(not bool(centered_rock.get("falling", true)), "rock query should clear falling state")
	_expect(float(centered_rock.get("drop_delay", 0.0)) == 0.0, "rock query should clear drop delay")
	_expect(centered_rock.get("quake_offset", Vector2.ONE) == Vector2.ZERO, "rock query should clear quake offset")


func _verify_background_delegates_rock_query() -> void:
	var background := Stage2PillarBackground.new()
	background.rocks = [
		{"id": 31, "pos": Vector2(100.0, 200.0)},
		{"id": 32, "pos": Vector2(200.0, 300.0)},
	]
	_expect(background._needs_rock_runtime_update({"falling": true}), "background runtime-update wrapper should delegate rock update predicates")
	var centered_rock := {
		"pos": Vector2.ZERO,
		"target_pos": Vector2(1.0, 2.0),
		"falling": true,
		"drop_delay": 1.0,
		"quake_offset": Vector2(4.0, 5.0),
	}
	background._set_rock_center(centered_rock, Vector2(12.0, 34.0))
	_expect(centered_rock.get("pos", Vector2.ZERO) == Vector2(12.0, 34.0), "background center wrapper should delegate rock center mutation")
	_expect(not bool(centered_rock.get("falling", true)), "background center wrapper should clear falling state")
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(
		source.find("rock_query.select_random_id") >= 0,
		"Stage 2 background source should call rock query directly for water-cannon target selection"
	)
	_expect(
		source.find("func _select_water_cannon_target_id") < 0,
		"Stage 2 background source should not keep the old water-cannon target wrapper"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
