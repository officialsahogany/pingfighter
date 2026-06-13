extends SceneTree

const StageClearResultRewardPlanBuilder := preload("res://scripts/core/stage_clear_result_reward_plan_builder.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_stage_clear_box_kind_odds()
	_verify_reward_box_counts()
	_verify_reward_plan_shape()
	_verify_screen_delegates_reward_plan_builder()

	if _failures.is_empty():
		print("stage_clear_result_reward_plan_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage_clear_box_kind_odds() -> void:
	var builder := StageClearResultRewardPlanBuilder.new()
	_expect(builder.roll_stage_clear_box_kind(0.0) == "guaranteed_mythic", "stage-clear box odds should map the low 3 percent to guaranteed mythic boxes")
	_expect(builder.roll_stage_clear_box_kind(0.029) == "guaranteed_mythic", "guaranteed mythic box range should end before 3 percent")
	_expect(builder.roll_stage_clear_box_kind(0.03) == "advanced", "stage-clear box odds should map rolls from 3 percent to advanced boxes")
	_expect(builder.roll_stage_clear_box_kind(0.229) == "advanced", "advanced box range should add exactly 20 percent")
	_expect(builder.roll_stage_clear_box_kind(0.23) == "normal", "normal boxes should occupy the remaining 77 percent")


func _verify_reward_box_counts() -> void:
	var builder := StageClearResultRewardPlanBuilder.new()
	_expect(builder.get_reward_box_count(5, 0) == 5, "5:0 stage clear should award five boxes")
	_expect(builder.get_reward_box_count(5, 1) == 4, "5:1 stage clear should award four boxes")
	_expect(builder.get_reward_box_count(5, 2) == 3, "5:2 stage clear should award three boxes")
	_expect(builder.get_reward_box_count(5, 3) == 2, "5:3 stage clear should award two boxes")
	_expect(builder.get_reward_box_count(5, 4) == 1, "5:4 stage clear should award one box")
	_expect(builder.get_reward_box_count(4, 0) == 1, "fallback score shapes should award one box")


func _verify_reward_plan_shape() -> void:
	var builder := StageClearResultRewardPlanBuilder.new()
	var plan: Dictionary = builder.build_reward_plan(5, 2)
	var boxes: Array = plan.get("boxes", [])
	_expect(int(plan.get("reward_count", 0)) == 3, "reward plan should expose the score-derived reward count")
	_expect(boxes.size() == 3, "reward plan should materialize one box per reward")
	for box_value in boxes:
		_expect(box_value is Dictionary and str((box_value as Dictionary).get("kind", "")) != "", "reward plan boxes should carry a kind")
	_expect(str(plan.get("summary", "")) != "", "reward plan should expose localized summary text")


func _verify_screen_delegates_reward_plan_builder() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var builder_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_reward_plan_builder.gd")
	_expect(source.find("StageClearResultRewardPlanBuilder.new()") >= 0, "result screen should own a reward plan builder instance")
	_expect(source.find(".build_reward_plan(player_score, boss_score)") >= 0, "result screen should delegate reward-plan construction")
	_expect(source.find("func _build_reward_plan") < 0, "result screen should not keep reward-plan assembly")
	_expect(source.find("func _roll_stage_clear_box_kind") < 0, "result screen should not keep box-kind odds")
	_expect(builder_source.find("func build_reward_plan") >= 0 and builder_source.find("func roll_stage_clear_box_kind") >= 0, "reward plan builder should own plan construction and odds")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
