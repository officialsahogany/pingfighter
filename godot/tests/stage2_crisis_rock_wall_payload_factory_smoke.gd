extends SceneTree

const Stage2CrisisRockWallPayloadFactory := preload("res://scripts/stages/stage2/stage2_crisis_rock_wall_payload_factory.gd")
const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")

var _failures: Array[String] = []


class FakeRockVisualFactory:
	extends RefCounted

	var calls: Array[Dictionary] = []

	func build_visual_data(size: float, is_golden: bool, seed_value: int, _rng: RandomNumberGenerator) -> Dictionary:
		calls.append({
			"size": size,
			"is_golden": is_golden,
			"seed": seed_value,
		})
		return {
			"style_type": "fake_crisis",
			"visual_radius": 999.0,
			"fixed_points": [Vector2.ONE],
		}


func _init() -> void:
	_verify_crisis_rock_payload()
	_verify_background_delegates_crisis_rock_payload()
	_verify_crisis_wall_randomizes_x_without_overlap()
	_verify_crisis_wall_preserves_existing_rocks()
	_verify_mythic_crisis_rock_wall_count()

	if _failures.is_empty():
		print("stage2_crisis_rock_wall_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_crisis_rock_payload() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260521
	var visual_factory := FakeRockVisualFactory.new()
	var factory := Stage2CrisisRockWallPayloadFactory.new()
	var rock: Dictionary = factory.build_crisis_rock(
		41,
		1,
		3,
		rng,
		visual_factory,
		12.0,
		29.0,
		46.0,
		185.0,
		0.5,
		0.07,
		0.42,
		-1.0
	)

	var target: Vector2 = rock.get("target_pos", Vector2.ZERO)
	var start: Vector2 = rock.get("pos", Vector2.ZERO)
	var radius := float(rock.get("radius", 0.0))
	_expect(int(rock.get("id", -1)) == 41, "crisis wall rock should preserve rock id")
	_expect(bool(rock.get("crisis_wall", false)), "crisis wall rock should be tagged")
	_expect(bool(rock.get("falling", false)), "crisis wall rock should start falling")
	_expect(target.x >= 70.0 + radius and target.x <= 690.0 - radius, "crisis wall rock should stay inside the randomized wall band")
	_expect(target.y >= 29.0 and target.y <= 46.0, "odd crisis wall rocks should target the lower band")
	_expect(is_equal_approx(start.y, target.y - 192.0), "crisis wall rock should include drop height and staggered start")
	_expect(radius >= 12.5 and radius <= 18.5, "crisis wall rock should scale collision radius")
	_expect(is_equal_approx(float(rock.get("drop_delay", 0.0)), 0.07), "crisis wall rock should stagger drop delay")
	_expect(is_equal_approx(float(rock.get("fall_timer", 0.0)), 0.42), "crisis wall rock should set fall timer")
	_expect(is_equal_approx(float(rock.get("fall_total", 0.0)), 0.42), "crisis wall rock should set fall total")
	_expect(is_equal_approx(float(rock.get("life", 0.0)), -1.0), "crisis wall rock should preserve life")
	_expect(str(rock.get("style_type", "")) == "fake_crisis", "crisis wall rock should merge visual data")
	_expect(is_equal_approx(float(rock.get("visual_radius", 0.0)), 999.0), "visual data should override visual radius")
	_expect(visual_factory.calls.size() == 1, "crisis wall rock should request visual data once")
	_expect(not bool(visual_factory.calls[0].get("is_golden", true)), "crisis wall rock visuals should not be golden")


func _verify_background_delegates_crisis_rock_payload() -> void:
	var background := Stage2PillarBackground.new()
	background.rng.seed = 20260521
	background._spawn_crisis_rock_wall({})
	_expect(background.rocks.size() == 3, "Stage 2 background should spawn all crisis wall rocks")
	var first_rock: Dictionary = background.rocks[0]
	_expect(bool(first_rock.get("crisis_wall", false)), "spawned crisis wall rocks should be tagged")
	_expect(first_rock.has("style_type"), "spawned crisis wall rocks should include visual style data")
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(
		source.find("crisis_rock_wall_payload_factory.build_crisis_rock") >= 0,
		"Stage 2 background source should keep crisis wall payload construction delegated"
	)


func _verify_crisis_wall_preserves_existing_rocks() -> void:
	var background := Stage2PillarBackground.new()
	background.rng.seed = 20260521
	var existing_rock: Dictionary = {
		"id": 77,
		"pos": Vector2(180.0, 230.0),
		"target_pos": Vector2(180.0, 230.0),
		"quake_offset": Vector2.ZERO,
		"falling": false,
		"drop_delay": 0.0,
		"radius": 18.0,
		"visual_radius": 36.0,
		"hp": 1,
		"life": -1.0,
		"flash": 0.0,
		"water_target_flash": 0.0,
		"phase": 0.0,
	}
	background.rocks.append(existing_rock)
	background.rock_next_id = 78

	background._spawn_crisis_rock_wall({})

	_expect(background.rocks.size() == 4, "crisis wall should append three rocks without clearing installed rocks")
	_expect(int(background.rocks[0].get("id", -1)) == 77, "existing installed rock should stay in the rock list")
	_expect(not bool(background.rocks[0].get("crisis_wall", false)), "existing installed rock should keep its original payload")
	_expect(int(background.rocks[1].get("id", -1)) == 78, "new crisis wall rocks should continue after the existing rock id")
	_expect(bool(background.rocks[1].get("crisis_wall", false)), "appended crisis wall rock should be tagged")
	_expect_crisis_wall_rocks_do_not_overlap(background.rocks, "crisis wall should avoid existing installed rocks when there is room")


func _verify_crisis_wall_randomizes_x_without_overlap() -> void:
	var first_positions: Array[float] = _spawn_crisis_wall_x_positions(20260521, "champion")
	var second_positions: Array[float] = _spawn_crisis_wall_x_positions(20260522, "champion")
	_expect(first_positions != second_positions, "crisis wall x positions should depend on the RNG seed")
	var mythic_background := Stage2PillarBackground.new()
	mythic_background.rng.seed = 20260523
	mythic_background.boss_rage_ai_mode = "mythic"
	mythic_background._spawn_crisis_rock_wall({})
	_expect(mythic_background.rocks.size() == 5, "mythic randomized crisis wall should keep five rocks")
	_expect_crisis_wall_rocks_do_not_overlap(mythic_background.rocks, "mythic randomized crisis wall rocks should not overlap")


func _verify_mythic_crisis_rock_wall_count() -> void:
	var background := Stage2PillarBackground.new()
	background.rng.seed = 20260521
	var context := {
		"current_stage": 2,
		"player_score": 4,
		"boss_score": 2,
		"ai_mode": "mythic",
	}
	background.update(0.0, context, {})
	_expect(background.start_boss_rage_animation({}), "mythic Stage 2 crisis should start boss rage")
	background.update(1.34, context, {})
	_expect(background.rocks.size() == 5, "mythic Stage 2 crisis wall should spawn five rocks")
	_expect_crisis_wall_rocks_do_not_overlap(background.rocks, "mythic Stage 2 crisis wall rocks should not overlap")


func _spawn_crisis_wall_x_positions(seed_value: int, ai_mode: String) -> Array[float]:
	var background := Stage2PillarBackground.new()
	background.rng.seed = seed_value
	background.boss_rage_ai_mode = ai_mode
	background._spawn_crisis_rock_wall({})
	_expect_crisis_wall_rocks_do_not_overlap(background.rocks, "randomized crisis wall rocks should not overlap")
	var positions: Array[float] = []
	for rock in background.rocks:
		var target: Vector2 = rock.get("target_pos", Vector2.ZERO)
		positions.append(target.x)
	return positions


func _expect_crisis_wall_rocks_do_not_overlap(rocks: Array, message: String) -> void:
	for left_index in range(rocks.size()):
		var left: Dictionary = rocks[left_index]
		var left_target: Vector2 = left.get("target_pos", left.get("pos", Vector2.ZERO))
		var left_radius := float(left.get("radius", 0.0))
		for right_index in range(left_index + 1, rocks.size()):
			var right: Dictionary = rocks[right_index]
			var right_target: Vector2 = right.get("target_pos", right.get("pos", Vector2.ZERO))
			var right_radius := float(right.get("radius", 0.0))
			_expect(left_target.distance_to(right_target) >= left_radius + right_radius, message)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
