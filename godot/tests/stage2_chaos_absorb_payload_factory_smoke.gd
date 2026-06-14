extends SceneTree

const GameplayStageModuleCatalog := preload("res://scripts/resources/gameplay_stage_module_catalog.gd")
const Stage2ChaosAbsorbPayloadFactory := preload("res://scripts/stages/stage2/stage2_chaos_absorb_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	var splash: Dictionary = Stage2ChaosAbsorbPayloadFactory.build_absorbed_splash_payload(Vector2(110.0, 220.0))
	_expect(splash.get("position", Vector2.ZERO) == Vector2(110.0, 220.0), "absorbed splash payload should preserve position")
	_expect(is_equal_approx(float(splash.get("strength", 0.0)), 0.75), "absorbed splash strength should stay tuned")
	_expect(splash.get("color", null) == Color(0.42, 0.88, 1.0, 1.0), "absorbed splash color should stay tuned")

	var small_rock: Dictionary = Stage2ChaosAbsorbPayloadFactory.build_absorbed_rock_payload(Vector2(200.0, 300.0), 10.0)
	var normal_rock: Dictionary = Stage2ChaosAbsorbPayloadFactory.build_absorbed_rock_payload(Vector2(200.0, 300.0), 28.0)
	var large_rock: Dictionary = Stage2ChaosAbsorbPayloadFactory.build_absorbed_rock_payload(Vector2(200.0, 300.0), 80.0)
	_expect(normal_rock.get("position", Vector2.ZERO) == Vector2(200.0, 300.0), "absorbed rock payload should preserve position")
	_expect(is_equal_approx(float(small_rock.get("strength", 0.0)), 0.85), "absorbed rock strength should clamp low")
	_expect(is_equal_approx(float(normal_rock.get("strength", 0.0)), 1.0), "absorbed rock strength should scale from radius")
	_expect(is_equal_approx(float(large_rock.get("strength", 0.0)), 1.65), "absorbed rock strength should clamp high")
	_expect(normal_rock.get("color", null) == Color(0.48, 0.92, 0.78, 1.0), "absorbed rock color should stay tuned")

	var source := FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(source.find("Stage2ChaosAbsorbPayloadFactory.build_absorbed_splash_payload") >= 0, "Stage 2 background should delegate absorbed splash payloads")
	_expect(source.find("Stage2ChaosAbsorbPayloadFactory.build_absorbed_rock_payload") >= 0, "Stage 2 background should delegate absorbed rock payloads")

	var modules: Dictionary = GameplayStageModuleCatalog.MODULES
	_expect(modules.has("stage2_chaos_absorb_payload_factory"), "stage module catalog should list the Stage 2 chaos absorb payload factory")

	if _failures.is_empty():
		print("stage2_chaos_absorb_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
