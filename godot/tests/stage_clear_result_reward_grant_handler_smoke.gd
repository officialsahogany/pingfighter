extends SceneTree

const StageClearRewardResolver := preload("res://scripts/core/stage_clear_reward_resolver.gd")
const StageClearResultRewardGrantHandler := preload("res://scripts/core/stage_clear_result_reward_grant_handler.gd")

var _failures: Array[String] = []


class FakeRewardResolver:
	extends RefCounted

	var roll_calls := 0
	var grant_calls := 0
	var granted_rewards: Array = []

	func roll_reward(box_kind: String, _owner: Object = null, _registry: Object = null) -> Dictionary:
		roll_calls += 1
		return {
			"type": StageClearRewardResolver.REWARD_STARPOINT,
			"box_kind": box_kind,
			"amount": 1,
		}

	func grant_rewards(rewards: Array, _owner: Object, _registry: Object) -> Dictionary:
		grant_calls += 1
		granted_rewards = rewards.duplicate(true)
		var summary := {
			"attempted": rewards.size(),
			"granted": rewards.size(),
			"active_granted": 0,
			"passive_granted": 0,
			"mythic_granted": 0,
			"starpoint_granted": 0,
			"failed": [],
		}
		for reward_value in rewards:
			if not (reward_value is Dictionary):
				continue
			var reward: Dictionary = reward_value
			match str(reward.get("type", "")):
				StageClearRewardResolver.REWARD_STARPOINT:
					summary["starpoint_granted"] = int(summary["starpoint_granted"]) + int(reward.get("amount", 0))
				StageClearRewardResolver.REWARD_MYTHIC:
					summary["mythic_granted"] = int(summary["mythic_granted"]) + 1
		return summary


class FakeResultScene:
	extends Control

	var _boxes: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_roll_and_pending_grants()
	_verify_scene_pending_grants()
	_verify_immediate_starpoint_grant()
	_verify_immediate_mythic_grant()
	_verify_reset_clears_cached_status()
	_verify_source_boundary()

	if _failures.is_empty():
		print("stage_clear_result_reward_grant_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_roll_and_pending_grants() -> void:
	var resolver := FakeRewardResolver.new()
	var handler := StageClearResultRewardGrantHandler.new()
	handler.set_reward_resolver_for_test(resolver)
	var reward: Dictionary = handler.roll_box_reward("normal", null, null)
	_expect(str(reward.get("box_kind", "")) == "normal", "reward grant handler should delegate reward rolls")
	var summary: Dictionary = handler.grant_pending_rewards([
		{"type": StageClearRewardResolver.REWARD_STARPOINT, "amount": 1},
		{"type": StageClearRewardResolver.REWARD_STARPOINT, "amount": 2, "immediate_granted": true},
	], null, null)
	_expect(resolver.grant_calls == 1, "reward grant handler should grant only pending rewards once")
	_expect(int(summary.get("attempted", 0)) == 1, "reward grant handler should skip immediate-granted rewards during final grant")
	summary = handler.grant_pending_rewards([{"type": StageClearRewardResolver.REWARD_STARPOINT, "amount": 5}], null, null)
	_expect(resolver.grant_calls == 1, "reward grant handler should not re-grant after finalization")
	_expect(int(summary.get("attempted", 0)) == 1, "reward grant handler should return the cached final summary")


func _verify_scene_pending_grants() -> void:
	var resolver := FakeRewardResolver.new()
	var handler := StageClearResultRewardGrantHandler.new()
	handler.set_reward_resolver_for_test(resolver)
	var scene := FakeResultScene.new()
	scene._boxes = [
		{"kind": "normal", "state": "opened", "reward": {"type": StageClearRewardResolver.REWARD_STARPOINT, "amount": 2}},
		{"kind": "advanced", "state": "opened", "reward": {"type": StageClearRewardResolver.REWARD_STARPOINT, "amount": 3, "immediate_granted": true}},
		{"kind": "normal", "state": "idle"},
	]
	var summary: Dictionary = handler.grant_pending_scene_rewards(scene, null, null)
	_expect(resolver.grant_calls == 1, "reward grant handler should read resolved scene rewards and grant pending rewards")
	_expect(int(summary.get("attempted", 0)) == 1, "scene pending grants should skip immediate-granted rewards")
	_expect((resolver.granted_rewards[0] as Dictionary).get("box_kind", "") == "normal", "scene pending grants should preserve resolved box metadata")
	scene.free()


func _verify_immediate_starpoint_grant() -> void:
	var resolver := FakeRewardResolver.new()
	var handler := StageClearResultRewardGrantHandler.new()
	handler.set_reward_resolver_for_test(resolver)
	var result: Dictionary = handler.grant_immediate_box_reward(
		{"type": StageClearRewardResolver.REWARD_STARPOINT, "amount": 3},
		null,
		null,
		true
	)
	_expect(bool(result.get("granted", false)), "reward grant handler should grant immediate starpoints")
	_expect(bool(result.get("defer_starpoint_choice", false)), "reward grant handler should report deferred starpoint choices")
	_expect(bool((resolver.granted_rewards[0] as Dictionary).get("defer_choice_open", false)), "reward grant handler should pass the defer flag into starpoint grants")
	var status: Dictionary = handler.get_status()
	_expect(int(status.get("immediate_reward_summaries", []).size()) == 1, "reward grant handler should cache immediate grant summaries")
	var grant_summary: Dictionary = status.get("last_grant_summary", {}) if status.get("last_grant_summary", {}) is Dictionary else {}
	_expect(int(grant_summary.get("starpoint_granted", 0)) == 3, "reward grant handler should merge starpoint grant counts")


func _verify_immediate_mythic_grant() -> void:
	var resolver := FakeRewardResolver.new()
	var handler := StageClearResultRewardGrantHandler.new()
	handler.set_reward_resolver_for_test(resolver)
	var result: Dictionary = handler.grant_immediate_box_reward(
		{"type": StageClearRewardResolver.REWARD_MYTHIC, "item_name": "meteor"},
		null,
		null,
		false
	)
	_expect(bool(result.get("granted", false)), "reward grant handler should grant immediate mythics")
	_expect(bool(result.get("raise_mythic_acquisition_cinematic", false)), "reward grant handler should ask the screen to raise mythic acquisition cinematics")
	_expect(bool((resolver.granted_rewards[0] as Dictionary).get("show_acquisition_cinematic", false)), "reward grant handler should request mythic acquisition cinematics in the grant payload")


func _verify_reset_clears_cached_status() -> void:
	var resolver := FakeRewardResolver.new()
	var handler := StageClearResultRewardGrantHandler.new()
	handler.set_reward_resolver_for_test(resolver)
	handler.grant_immediate_box_reward({"type": StageClearRewardResolver.REWARD_STARPOINT, "amount": 1}, null, null, false)
	handler.reset()
	var status: Dictionary = handler.get_status()
	_expect(not bool(status.get("rewards_granted", true)), "reward grant handler reset should clear final grant state")
	_expect((status.get("immediate_reward_summaries", []) as Array).is_empty(), "reward grant handler reset should clear immediate summaries")
	_expect((status.get("last_grant_summary", {}) as Dictionary).is_empty(), "reward grant handler reset should clear grant summary")


func _verify_source_boundary() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_reward_grant_handler.gd")
	var grant_state_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_reward_grant_state.gd")
	var immediate_grant_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_immediate_reward_grant_data.gd")
	var finish_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_finish_flow_handler.gd")
	var finish_screen_context_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_finish_screen_context_data.gd")
	var plaza_enter_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_plaza_enter_flow_handler.gd")
	var plaza_enter_screen_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_plaza_enter_screen_data.gd")
	_expect(screen_source.find("StageClearResultBoxSceneHandler") < 0, "result screen should not read result-box resolved rewards directly")
	_expect(screen_source.find("func _roll_box_reward") < 0, "result screen should not keep reward roll pass-through helpers")
	_expect(screen_source.find("func _grant_pending_rewards") < 0, "result screen should not keep pending reward grant pass-through helpers")
	_expect(screen_source.find("grant_pending_scene_rewards") < 0, "result screen should not wire pending scene reward grants directly")
	_expect(finish_source.find("grant_pending_scene_rewards") < 0, "finish flow handler should delegate pending scene reward grant wiring")
	_expect(finish_screen_context_source.find("grant_pending_scene_rewards") >= 0, "finish screen context data should wire pending scene reward grants")
	_expect(plaza_enter_source.find("grant_pending_scene_rewards") < 0, "plaza enter flow handler should delegate pending scene reward grant wiring")
	_expect(plaza_enter_screen_data_source.find("grant_pending_scene_rewards") >= 0, "plaza enter screen data should wire pending scene reward grants")
	_expect(handler_source.find("StageClearResultBoxSceneHandler") >= 0, "reward grant handler should own result-box resolved reward reads")
	_expect(handler_source.find("func grant_pending_scene_rewards") >= 0, "reward grant handler should expose a scene pending-grant entry point")
	_expect(handler_source.find("StageClearResultRewardGrantState") >= 0, "reward grant handler should delegate grant-state storage")
	_expect(handler_source.find("record_immediate_result") >= 0, "reward grant handler should delegate immediate summary recording")
	_expect(handler_source.find("func _merge_grant_summary") < 0, "reward grant handler should not keep grant-summary merge internals")
	_expect(handler_source.find("func _empty_grant_summary") < 0, "reward grant handler should not keep empty summary construction")
	_expect(handler_source.find("var _rewards_granted") < 0, "reward grant handler should not keep final-grant state flags directly")
	_expect(grant_state_source.find("func grant_pending_rewards") >= 0, "reward grant state should own pending reward idempotence")
	_expect(grant_state_source.find("func record_immediate_result") >= 0, "reward grant state should own immediate summary capture")
	_expect(grant_state_source.find("func merge_grant_summary") >= 0, "reward grant state should own summary merging")
	_expect(grant_state_source.find("immediate_granted") >= 0, "reward grant state should own pending reward filtering")
	_expect(handler_source.find("func _grant_immediate") < 0, "reward grant handler should not own immediate reward grant branches")
	_expect(handler_source.find("show_acquisition_cinematic") < 0, "reward grant handler should delegate mythic acquisition payload mutation")
	_expect(handler_source.find("defer_choice_open") < 0, "reward grant handler should delegate starpoint defer payload mutation")
	_expect(handler_source.find("StageClearResultImmediateRewardGrantData.grant_immediate_box_reward") >= 0, "reward grant handler should delegate immediate reward grants")
	_expect(immediate_grant_data_source.find("show_acquisition_cinematic") >= 0, "immediate grant data should own mythic cinematic payload mutation")
	_expect(immediate_grant_data_source.find("defer_choice_open") >= 0, "immediate grant data should own starpoint defer payload mutation")
	_expect(immediate_grant_data_source.find("static func grant_immediate_box_reward") >= 0, "immediate grant data should expose stateless immediate reward grants")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
