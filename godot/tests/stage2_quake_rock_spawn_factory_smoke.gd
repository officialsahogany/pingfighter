extends SceneTree

const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const Stage2QuakeRockPayloadFactory := preload("res://scripts/stages/stage2/stage2_quake_rock_payload_factory.gd")
const Stage2QuakeRockSpawnFactory := preload("res://scripts/stages/stage2/stage2_quake_rock_spawn_factory.gd")
const Stage2RockVisualFactory := preload("res://scripts/stages/stage2/stage2_rock_visual_factory.gd")

var _failures: Array[String] = []


class FakeAudio:
	var spawn_calls := 0

	func play_stage2_rock_spawn() -> void:
		spawn_calls += 1


func _init() -> void:
	_verify_spawn_batch_payloads()
	_verify_background_delegates_spawn_factory()

	if _failures.is_empty():
		print("stage2_quake_rock_spawn_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_spawn_batch_payloads() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260521
	var batch: Dictionary = Stage2QuakeRockSpawnFactory.new().build_spawn_batch(
		[{"target_pos": Vector2(200.0, 200.0)}],
		3,
		8,
		20,
		rng,
		Stage2RockVisualFactory.new(),
		Stage2QuakeRockPayloadFactory.new(),
		0.5,
		-1.0
	)
	var rocks: Array = batch.get("rocks", [])
	var targets: Array = batch.get("targets", [])
	_expect(rocks.size() == 3, "quake rock spawn factory should build requested rock count")
	_expect(targets.size() == 3, "quake rock spawn factory should preserve leaf target positions")
	_expect(int(batch.get("next_id", -1)) == 23, "quake rock spawn factory should advance next id")
	for index in range(rocks.size()):
		var rock: Dictionary = rocks[index]
		_expect(int(rock.get("id", -1)) == 20 + index, "quake rock spawn factory should assign sequential ids")
		_expect(bool(rock.get("falling", false)), "quake rock spawn factory should start rocks falling")
		_expect(rock.has("style_type"), "quake rock spawn factory should merge visual style data")
		_expect(rock.get("target_pos", Vector2.ZERO) == targets[index], "quake rock spawn factory target should match payload")


func _verify_background_delegates_spawn_factory() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(
		source.find("quake_rock_spawn_factory.build_spawn_batch") >= 0,
		"Stage 2 background source should delegate quake rock spawn batches"
	)
	var background := Stage2PillarBackground.new()
	background.rng.seed = 20260521
	var audio := FakeAudio.new()
	background._spawn_quake_rocks(2, {"audio": audio})
	_expect(background.rocks.size() == 2, "Stage 2 background should append delegated quake rocks")
	_expect(background.rock_next_id == 3, "Stage 2 background should advance delegated next id")
	_expect(audio.spawn_calls == 1, "Stage 2 background should keep quake rock spawn audio")
	_expect(background.leaf_particles.size() > 0, "Stage 2 background should keep quake rock leaf side effects")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
