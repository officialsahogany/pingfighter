extends SceneTree

const GameplayStageModuleCatalog := preload("res://scripts/resources/gameplay_stage_module_catalog.gd")
const Stage4PillarBackgroundPayloadFactory := preload("res://scripts/stages/stage4/stage4_pillar_background_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	var accent: Dictionary = Stage4PillarBackgroundPayloadFactory.build_wall_shake_accent(
		"left",
		0.42,
		1.25,
		0.24
	)
	_expect(str(accent.get("side", "")) == "left", "wall shake accent should preserve side")
	_expect(is_equal_approx(float(accent.get("y_ratio", 0.0)), 0.42), "wall shake accent should preserve y ratio")
	_expect(is_equal_approx(float(accent.get("speed_scale", 0.0)), 1.25), "wall shake accent should preserve speed scale")
	_expect(is_equal_approx(float(accent.get("timer", 0.0)), 0.24), "wall shake accent timer should start at duration")
	_expect(is_equal_approx(float(accent.get("duration", 0.0)), 0.24), "wall shake accent should preserve duration")

	var source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_pillar_background.gd")
	_expect(source.find("Stage4PillarBackgroundPayloadFactory.build_wall_shake_accent") >= 0, "Stage 4 pillar background should delegate wall-shake accent payloads")

	var modules: Dictionary = GameplayStageModuleCatalog.MODULES
	_expect(modules.has("stage4_pillar_background_payload_factory"), "stage module catalog should list the Stage 4 pillar background payload factory")

	if _failures.is_empty():
		print("stage4_pillar_background_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
