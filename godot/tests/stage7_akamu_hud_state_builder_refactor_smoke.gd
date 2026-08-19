extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")

const HUD_BUILDER_PATH := "res://scripts/stages/stage7/stage7_akamu_hud_state_builder.gd"

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_public_hud_projection()
	_verify_pause_and_writer_blocking()

	if _failures.is_empty():
		print("stage7_akamu_hud_state_builder_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(HUD_BUILDER_PATH), "Stage 7 skill-card state should have a focused projection builder")
	if not FileAccess.file_exists(HUD_BUILDER_PATH):
		return
	var host_source := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_state.gd")
	var helper_source := FileAccess.get_file_as_string(HUD_BUILDER_PATH)
	_expect(
		host_source.find("const Stage7AkamuHudStateBuilder := preload(\"%s\")" % HUD_BUILDER_PATH) >= 0,
		"Stage7AkamuState should preload the focused HUD projection builder"
	)
	_expect(
		host_source.find("var _hud_state_builder: Object = Stage7AkamuHudStateBuilder.new()") >= 0,
		"Stage7AkamuState should retain one HUD projection builder instance"
	)
	_expect(helper_source.find("func build_skills(") >= 0, "focused HUD projection builder should implement build_skills")
	for host_function in [
		"func _build_hud_skills(",
		"func _placeholder_hud_skill(",
		"func _build_shuriken_hud_skill(",
		"func _build_clone_hud_skill(",
		"func _build_cloud_hud_skill(",
		"func _build_superspeed_hud_skill(",
	]:
		_expect(host_source.find(host_function) < 0, "Stage7AkamuState should not retain HUD projection helper %s" % host_function)
	_expect(
		host_source.find("_hud_state_builder.build_skills(") >= 0,
		"public HUD context should route skill projection through the focused builder"
	)


func _verify_public_hud_projection() -> void:
	if not FileAccess.file_exists(HUD_BUILDER_PATH):
		return
	var state: Object = Stage7AkamuState.new()
	var context: Dictionary = state.get_hud_context()
	_expect(bool(context.get("stage7_boss_skill_hud_active", false)), "public Stage 7 HUD context should remain active")
	_expect(str(context.get("stage7_boss_skill_hud_boss_name", "")) != "", "public HUD context should retain the boss name")
	var skills: Array = context.get("stage7_boss_skill_hud_skills", []) as Array
	_expect(skills.size() == 4, "focused HUD projection should expose exactly four implemented skills")
	var ids: Array[String] = []
	for skill_value in skills:
		ids.append(str((skill_value as Dictionary).get("id", "")))
	_expect(
		ids == ["stage7_clone", "stage7_shuriken", "stage7_cloud", "stage7_superspeed"],
		"focused HUD projection should preserve clone/shuriken/cloud/superspeed order; got %s" % str(ids)
	)


func _verify_pause_and_writer_blocking() -> void:
	if not FileAccess.file_exists(HUD_BUILDER_PATH):
		return
	var paused_state: Object = Stage7AkamuState.new()
	paused_state.status = "paused"
	var clone_card := _find_skill(
		paused_state.get_hud_context().get("stage7_boss_skill_hud_skills", []) as Array,
		"stage7_clone"
	)
	_expect(str(clone_card.get("status", "")) == "paused", "facade paused status should propagate through the HUD builder")
	_expect(not bool(clone_card.get("ready", true)), "paused clone card should not publish ready")

	var state: Object = Stage7AkamuState.new()
	state.debug_set_gauge(500.0)
	_expect(state.debug_start_clone_cast(_base_context(), true, true), "clone writer-gate fixture should start")
	var skills: Array = state.get_hud_context().get("stage7_boss_skill_hud_skills", []) as Array
	var shuriken_card := _find_skill(skills, "stage7_shuriken")
	var cloud_card := _find_skill(skills, "stage7_cloud")
	_expect(not bool(shuriken_card.get("ready", true)), "active clone writer should block the shuriken card")
	_expect(not bool(cloud_card.get("ready", true)), "active clone writer should block the cloud card through motion ownership")


func _find_skill(skills: Array, skill_id: String) -> Dictionary:
	for skill_value in skills:
		var skill: Dictionary = skill_value as Dictionary
		if str(skill.get("id", "")) == skill_id:
			return skill
	return {}


func _base_context() -> Dictionary:
	return {
		"current_stage": 7,
		"ball_active": true,
		"waiting_for_serve": false,
		"gameplay_timing_frozen": false,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"ball_pos": Vector2(380.0, 700.0),
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
