extends SceneTree

const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const Stage2QuakeRockPayloadFactory := preload("res://scripts/stages/stage2/stage2_quake_rock_payload_factory.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_quake_rock_payload()
	_verify_background_delegates_quake_rock_payload()

	if _failures.is_empty():
		print("stage2_quake_rock_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_quake_rock_payload() -> void:
	var factory := Stage2QuakeRockPayloadFactory.new()
	var rock: Dictionary = factory.build_quake_rock(
		7,
		2,
		Vector2(120.0, 340.0),
		-80.0,
		42.0,
		0.72,
		2,
		629,
		true,
		-1.0,
		{
			"style_type": "golden_rock",
			"visual_radius": 45.0,
			"fixed_points": [Vector2.ONE],
		}
	)
	_expect(int(rock.get("id", -1)) == 7, "quake rock payload should preserve rock id")
	_expect(rock.get("pos", Vector2.ZERO) == Vector2(120.0, -80.0), "quake rock payload should start at fall height")
	_expect(rock.get("target_pos", Vector2.ZERO) == Vector2(120.0, 340.0), "quake rock payload should preserve target position")
	_expect(bool(rock.get("falling", false)), "quake rock payload should start falling")
	_expect(is_equal_approx(float(rock.get("spawn_delay_frames", 0.0)), 20.0), "quake rock payload should stagger by spawn index")
	_expect(is_equal_approx(float(rock.get("radius", 0.0)), 21.0), "quake rock payload should derive collision radius from size")
	_expect(is_equal_approx(float(rock.get("phase", 0.0)), 0.01), "quake rock payload should derive phase from seed")
	_expect(str(rock.get("style_type", "")) == "golden_rock", "quake rock payload should merge visual data")
	_expect(is_equal_approx(float(rock.get("visual_radius", 0.0)), 45.0), "quake rock visual data should be able to override visual radius")


func _verify_background_delegates_quake_rock_payload() -> void:
	var background := Stage2PillarBackground.new()
	background.rng.seed = 20260521
	background._spawn_quake_rocks(2)
	_expect(background.rocks.size() == 2, "Stage 2 background should spawn quake rocks through its payload path")
	var first_rock: Dictionary = background.rocks[0]
	_expect(first_rock.has("style_type"), "spawned quake rocks should include visual style data")
	_expect(bool(first_rock.get("falling", false)), "spawned quake rocks should begin falling")
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(
		source.find("quake_rock_spawn_factory.build_spawn_batch") >= 0,
		"Stage 2 background source should keep quake rock spawning delegated"
	)
	var spawn_factory_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_quake_rock_spawn_factory.gd")
	_expect(
		spawn_factory_source.find("quake_rock_payload_factory.build_quake_rock") >= 0,
		"Stage 2 quake rock spawn factory should keep payload construction delegated"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
