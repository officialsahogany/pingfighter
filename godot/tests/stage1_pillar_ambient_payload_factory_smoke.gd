extends SceneTree

const GameplayStageModuleCatalog := preload("res://scripts/resources/gameplay_stage_module_catalog.gd")
const Stage1PillarAmbientPayloadFactory := preload("res://scripts/stages/stage1/stage1_pillar_ambient_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	seed(20260612)
	var butterflies: Array[Dictionary] = Stage1PillarAmbientPayloadFactory.build_idle_butterflies()
	_expect(butterflies.size() == 4, "idle butterfly factory should create four pillar butterflies")
	var expected_sides := ["left", "left", "right", "right"]
	var expected_y := [1.0 / 3.0, 2.0 / 3.0, 1.0 / 3.0, 2.0 / 3.0]
	for i in range(butterflies.size()):
		var butterfly: Dictionary = butterflies[i]
		_expect(str(butterfly.get("side", "")) == expected_sides[i], "idle butterfly side should stay anchored")
		_expect(is_equal_approx(float(butterfly.get("y_ratio", 0.0)), expected_y[i]), "idle butterfly y ratio should stay anchored")
		_expect(float(butterfly.get("phase", -1.0)) >= 0.0 and float(butterfly.get("phase", -1.0)) <= TAU, "idle butterfly phase should be randomized in range")
		_expect(is_equal_approx(float(butterfly.get("wing_speed", 0.0)), 10.0), "idle butterfly wing speed should stay tuned")
		_expect(int(butterfly.get("color_index", -1)) == i, "idle butterfly color index should stay stable")
		_expect(is_equal_approx(float(butterfly.get("size", 0.0)), 1.0), "idle butterfly size should stay tuned")

	var trail_entry: Dictionary = Stage1PillarAmbientPayloadFactory.build_flying_trail_entry(Vector2(120.0, 240.0), 0.5)
	_expect(trail_entry.get("position", Vector2.ZERO) == Vector2(120.0, 240.0), "trail entry should preserve position")
	_expect(is_equal_approx(float(trail_entry.get("alpha", 0.0)), 0.5), "trail entry should preserve alpha")

	seed(20260612)
	var particle: Dictionary = Stage1PillarAmbientPayloadFactory.build_absorption_particle(Vector2(400.0, 300.0))
	_expect(particle.get("position", Vector2.ZERO) == Vector2(400.0, 300.0), "absorption particle should preserve center")
	var speed := (_as_vector2(particle.get("velocity", Vector2.ZERO))).length()
	_expect(speed >= 35.0 and speed <= 130.0, "absorption particle speed should stay in range")
	_expect(float(particle.get("life", 0.0)) >= 0.45 and float(particle.get("life", 0.0)) <= 1.0, "absorption particle life should stay in range")
	_expect(float(particle.get("size", 0.0)) >= 2.0 and float(particle.get("size", 0.0)) <= 5.5, "absorption particle size should stay in range")

	var source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_pillar_ambient_state.gd")
	_expect(source.find("Stage1PillarAmbientPayloadFactory.build_idle_butterflies") >= 0, "ambient state should delegate idle butterfly payloads")
	_expect(source.find("Stage1PillarAmbientPayloadFactory.build_flying_trail_entry") >= 0, "ambient state should delegate trail entries")
	_expect(source.find("Stage1PillarAmbientPayloadFactory.build_absorption_particle") >= 0, "ambient state should delegate absorption particles")

	var modules: Dictionary = GameplayStageModuleCatalog.MODULES
	_expect(modules.has("stage1_pillar_ambient_payload_factory"), "stage module catalog should list the Stage 1 ambient payload factory")

	if _failures.is_empty():
		print("stage1_pillar_ambient_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
