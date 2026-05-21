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
		5,
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
	_expect(target.x >= 258.0 and target.x <= 295.0, "crisis wall rock should use indexed wall spacing")
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
	_expect(background.rocks.size() == 5, "Stage 2 background should spawn all crisis wall rocks")
	var first_rock: Dictionary = background.rocks[0]
	_expect(bool(first_rock.get("crisis_wall", false)), "spawned crisis wall rocks should be tagged")
	_expect(first_rock.has("style_type"), "spawned crisis wall rocks should include visual style data")
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(
		source.find("crisis_rock_wall_payload_factory.build_crisis_rock") >= 0,
		"Stage 2 background source should keep crisis wall payload construction delegated"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
