extends SceneTree

const GameplayStageModuleCatalog := preload("res://scripts/resources/gameplay_stage_module_catalog.gd")
const Stage1PillarPetalPayloadFactory := preload("res://scripts/stages/stage1/stage1_pillar_petal_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	seed(20260612)
	var floating: Dictionary = Stage1PillarPetalPayloadFactory.build_floating_petal(42.0)
	_expect(is_equal_approx(float(floating.get("x", 0.0)), 42.0), "floating petal should preserve x")
	_expect(float(floating.get("y", 1.0)) >= -20.0 and float(floating.get("y", 1.0)) <= 0.0, "floating petal y should start above view")
	_expect(float(floating.get("vx", 99.0)) >= -0.5 and float(floating.get("vx", 99.0)) <= 0.5, "floating petal vx should stay in range")
	_expect(float(floating.get("vy", 0.0)) >= 0.8 and float(floating.get("vy", 0.0)) <= 1.5, "floating petal vy should stay in range")
	_expect(float(floating.get("rotation", -1.0)) >= 0.0 and float(floating.get("rotation", -1.0)) <= 360.0, "floating petal rotation should stay in range")
	_expect(float(floating.get("rot_speed", 99.0)) >= -2.0 and float(floating.get("rot_speed", 99.0)) <= 2.0, "floating petal rot_speed should stay in range")
	_expect(float(floating.get("size", 0.0)) >= 6.0 and float(floating.get("size", 0.0)) <= 10.0, "floating petal size should stay in range")
	_expect(floating.get("color", null) is Color, "floating petal should include a color")

	seed(20260612)
	var burst := 1.35
	var tree_drop: Dictionary = Stage1PillarPetalPayloadFactory.build_tree_drop_petal(Vector2(100.0, 220.0), 1.0, burst)
	_expect(float(tree_drop.get("x", 0.0)) >= 84.0 and float(tree_drop.get("x", 0.0)) <= 116.0, "tree drop petal x should jitter around base")
	_expect(float(tree_drop.get("y", 0.0)) >= 192.0 and float(tree_drop.get("y", 0.0)) <= 244.0, "tree drop petal y should jitter around base")
	_expect(float(tree_drop.get("vx", 0.0)) >= -2.0 * burst and float(tree_drop.get("vx", 0.0)) <= 66.0 * burst, "tree drop petal vx should include side burst")
	_expect(float(tree_drop.get("vy", 0.0)) >= 24.0 * burst and float(tree_drop.get("vy", 0.0)) <= 76.0 * burst, "tree drop petal vy should scale by burst")
	_expect(float(tree_drop.get("gravity", 0.0)) >= 34.0 and float(tree_drop.get("gravity", 0.0)) <= 72.0, "tree drop petal gravity should stay in range")
	_expect(float(tree_drop.get("sway", -1.0)) >= 0.0 and float(tree_drop.get("sway", -1.0)) <= TAU, "tree drop petal sway should stay in range")
	_expect(float(tree_drop.get("sway_speed", 0.0)) >= 4.0 and float(tree_drop.get("sway_speed", 0.0)) <= 7.5, "tree drop petal sway speed should stay in range")
	_expect(float(tree_drop.get("rotation", -1.0)) >= 0.0 and float(tree_drop.get("rotation", -1.0)) <= 360.0, "tree drop petal rotation should stay in range")
	_expect(float(tree_drop.get("rot_speed", 999.0)) >= -165.0 and float(tree_drop.get("rot_speed", 999.0)) <= 165.0, "tree drop petal rot speed should stay in range")
	_expect(float(tree_drop.get("size", 0.0)) >= 5.0 and float(tree_drop.get("size", 0.0)) <= 9.0, "tree drop petal size should stay in range")
	_expect(tree_drop.get("color", null) is Color, "tree drop petal should include a color")
	_expect(float(tree_drop.get("life", 0.0)) >= 1.35 and float(tree_drop.get("life", 0.0)) <= 2.15, "tree drop petal life should stay in range")
	_expect(is_equal_approx(float(tree_drop.get("max_life", -1.0)), float(tree_drop.get("life", 0.0))), "tree drop petal max_life should match life")

	var floating_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_pillar_petal_state.gd")
	var tree_drop_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_pillar_tree_drop_petal_state.gd")
	_expect(floating_source.find("Stage1PillarPetalPayloadFactory.build_floating_petal") >= 0, "floating petal state should delegate payload construction")
	_expect(tree_drop_source.find("Stage1PillarPetalPayloadFactory.build_tree_drop_petal") >= 0, "tree drop state should delegate payload construction")

	var modules: Dictionary = GameplayStageModuleCatalog.MODULES
	_expect(modules.has("stage1_pillar_petal_payload_factory"), "stage module catalog should list the Stage 1 petal payload factory")

	if _failures.is_empty():
		print("stage1_pillar_petal_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
