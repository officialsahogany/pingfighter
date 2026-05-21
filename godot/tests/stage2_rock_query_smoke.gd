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


func _verify_background_delegates_rock_query() -> void:
	var background := Stage2PillarBackground.new()
	_expect(background._select_water_cannon_target_id() == -1, "background water-cannon target wrapper should ignore empty rocks")
	background.rocks = [
		{"id": 31, "pos": Vector2(100.0, 200.0)},
		{"id": 32, "pos": Vector2(200.0, 300.0)},
	]
	background.rng.seed = 99
	var selected_id: int = background._select_water_cannon_target_id()
	_expect([31, 32].has(selected_id), "background water-cannon target wrapper should delegate random id selection")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
