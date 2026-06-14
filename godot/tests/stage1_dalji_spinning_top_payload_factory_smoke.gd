extends SceneTree

const GameplayStageModuleCatalog := preload("res://scripts/resources/gameplay_stage_module_catalog.gd")
const Stage1DaljiSpinningTopPayloadFactory := preload("res://scripts/stages/stage1/stage1_dalji_spinning_top_payload_factory.gd")
const Stage1DaljiSpinningTopSkillState := preload("res://scripts/stages/stage1/stage1_dalji_spinning_top_skill_state.gd")


var _failures: Array[String] = []

func _init() -> void:
	seed(20260612)
	var top: Dictionary = Stage1DaljiSpinningTopPayloadFactory.build_top(
		Vector2(380.0, 90.0),
		-30.0,
		1,
		0.4,
		0.15
	)
	_expect(is_equal_approx(float(top.get("x", 0.0)), 350.0), "spinning top should apply offset from boss center")
	_expect(is_equal_approx(float(top.get("y", 0.0)), 130.0), "spinning top should start below boss center")
	_expect(float(top.get("vx", 99.0)) >= -0.5 and float(top.get("vx", 99.0)) <= 0.5, "spinning top vx should stay in range")
	_expect(is_equal_approx(float(top.get("vy", 0.0)), 0.4), "spinning top should preserve initial down speed")
	_expect(float(top.get("rotation", -1.0)) >= 0.0 and float(top.get("rotation", -1.0)) <= 360.0, "spinning top rotation should stay in range")
	_expect(is_equal_approx(float(top.get("rotation_speed", 0.0)), 20.0), "spinning top rotation speed should stay tuned")
	_expect(is_equal_approx(float(top.get("tilt", -1.0)), 0.0), "spinning top should start untilted")
	_expect(is_equal_approx(float(top.get("alpha", 0.0)), 255.0), "spinning top should start opaque")
	_expect(str(top.get("whip_phase", "")) == "preparing", "spinning top should start in preparing whip phase")
	_expect(is_equal_approx(float(top.get("zigzag_timer", 0.0)), 10.0), "spinning top zigzag timer should offset by index")
	_expect(is_equal_approx(float(top.get("speed_boost", -1.0)), 0.0), "spinning top speed boost should start at zero")
	_expect(is_equal_approx(float(top.get("boost_timer", -1.0)), 0.0), "spinning top boost timer should start at zero")
	_expect(top.get("is_golden", null) is bool, "spinning top should include golden flag")
	_expect(not bool(top.get("star_spawned", true)), "spinning top should start without spawned star")

	seed(20260612)
	var state := Stage1DaljiSpinningTopSkillState.new()
	var base_context := {
		"current_stage": 1,
		"boss_pos": Vector2(330.0, 70.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_hitbox_height": 40.0,
	}
	_expect(state.activate(base_context), "spinning top state should activate on Stage 1")
	_expect(state.tops.size() == 2, "normal spinning top activation should spawn two tops")
	_expect(str((state.tops[0] as Dictionary).get("whip_phase", "")) == "preparing", "state-created tops should use factory defaults")
	state.reset_round()
	var enraged_context: Dictionary = base_context.duplicate(true)
	enraged_context["enraged_boss_active"] = true
	_expect(state.activate(enraged_context), "enraged spinning top state should activate on Stage 1")
	_expect(state.tops.size() == 4, "enraged spinning top activation should spawn four tops")

	var source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_dalji_spinning_top_skill_state.gd")
	_expect(source.find("Stage1DaljiSpinningTopPayloadFactory.build_top") >= 0, "spinning top state should delegate top payload construction")

	var modules: Dictionary = GameplayStageModuleCatalog.MODULES
	_expect(modules.has("stage1_dalji_spinning_top_payload_factory"), "stage module catalog should list the Stage 1 spinning top payload factory")

	if _failures.is_empty():
		print("stage1_dalji_spinning_top_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
