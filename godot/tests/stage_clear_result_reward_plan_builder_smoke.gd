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
	# 2026-07-28 보상 하향 계약: 압승(5:0~5:1) 3개 / 일반 승리(5:2~5:4) 2개 /
	# 듀스 승리(6:x·7:x) 1개.
	var builder := StageClearResultRewardPlanBuilder.new()
	_expect(builder.get_reward_box_count(5, 0) == 3, "5:0 stage clear should award three boxes")
	_expect(builder.get_reward_box_count(5, 1) == 3, "5:1 stage clear should award three boxes")
	_expect(builder.get_reward_box_count(5, 2) == 2, "5:2 stage clear should award two boxes")
	_expect(builder.get_reward_box_count(5, 3) == 2, "5:3 stage clear should award two boxes")
	_expect(builder.get_reward_box_count(5, 4) == 2, "5:4 stage clear should award two boxes")
	_expect(builder.get_reward_box_count(6, 4) == 1, "6:4 deuce win should award one box")
	_expect(builder.get_reward_box_count(6, 5) == 1, "6:5 deuce win should award one box")
	_expect(builder.get_reward_box_count(7, 5) == 1, "7:5 deuce win should award one box")
	_expect(builder.get_reward_box_count(7, 6) == 1, "7:6 deuce win should award one box")


func _verify_reward_plan_shape() -> void:
	var builder := StageClearResultRewardPlanBuilder.new()
	var plan: Dictionary = builder.build_reward_plan(5, 2)
	var boxes: Array = plan.get("boxes", [])
	_expect(int(plan.get("reward_count", 0)) == 2, "reward plan should expose the score-derived reward count")
	_expect(boxes.size() == 2, "reward plan should materialize one box per reward")
	for box_value in boxes:
		_expect(box_value is Dictionary and str((box_value as Dictionary).get("kind", "")) != "", "reward plan boxes should carry a kind")
	_expect(str(plan.get("summary", "")) != "", "reward plan should expose localized summary text")


func _verify_screen_delegates_reward_plan_builder() -> void:
	# 상자 이벤트가 인게임 전리품 페이즈로 이관된 뒤의 소유권 계약:
	# 플랜 생성/등급 롤은 builder가 소유하고, 라이브 플랜 소비자는
	# victory_loot_phase_state 하나다. 결과화면은 빈 플랜만 돌려 이중 보상을 막는다.
	var source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var loot_source: String = FileAccess.get_file_as_string("res://scripts/core/victory_loot_phase_state.gd")
	var builder_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_reward_plan_builder.gd")
	_expect(loot_source.find("build_reward_plan(") >= 0, "victory loot phase should delegate reward-plan construction to the shared builder")
	_expect(source.find(".build_reward_plan(player_score, boss_score)") < 0, "result screen must not roll a second live reward plan (double-reward guard)")
	_expect(source.find("\"boxes\": []") >= 0, "result screen reward plan should stay empty after the loot-phase migration")
	_expect(source.find("func _build_reward_plan") < 0, "result screen should not keep reward-plan assembly")
	_expect(source.find("func _roll_stage_clear_box_kind") < 0, "result screen should not keep box-kind odds")
	_expect(builder_source.find("func build_reward_plan") >= 0 and builder_source.find("func roll_stage_clear_box_kind") >= 0, "reward plan builder should own plan construction and odds")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
