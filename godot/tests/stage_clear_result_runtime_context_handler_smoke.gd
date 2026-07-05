extends SceneTree

const StageClearResultRuntimeContextHandler := preload("res://scripts/core/stage_clear_result_runtime_context_handler.gd")
const StageClearResultScreen := preload("res://scripts/core/stage_clear_result_screen.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage: int = 1
	var selected_character_type: String = "smasher"


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var requested_keys: Array[String] = []

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		var instance: Variant = instances.get(key, null)
		return instance if instance is Object else null


class FakeMatchScoreState:
	extends RefCounted

	var snapshot: Variant = {}

	func get_snapshot() -> Variant:
		return snapshot


class FakeScoreboardState:
	extends RefCounted

	var player_points: int = 0
	var boss_points: int = 0

	func get_player_points() -> int:
		return player_points

	func get_boss_points() -> int:
		return boss_points


class FakeResetForResult:
	extends RefCounted

	var reset_for_result_calls: int = 0

	func reset_for_result() -> void:
		reset_for_result_calls += 1


class FakeActorRenderer:
	extends RefCounted

	var reset_round_fx_calls: int = 0
	var reset_calls: int = 0

	func reset_round_fx() -> void:
		reset_round_fx_calls += 1

	func reset() -> void:
		reset_calls += 1


class FakeFallbackActorRenderer:
	extends RefCounted

	var reset_calls: int = 0

	func reset() -> void:
		reset_calls += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_score_snapshot_priority_and_fallback()
	_verify_stage_and_character_context()
	_verify_stage_result_reset_routing()
	_verify_screen_source_boundary()

	if _failures.is_empty():
		print("stage_clear_result_runtime_context_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_score_snapshot_priority_and_fallback() -> void:
	var handler := StageClearResultRuntimeContextHandler.new()
	var registry := FakeRegistry.new()
	var match_score := FakeMatchScoreState.new()
	match_score.snapshot = {"player_score": 9, "boss_score": 2}
	var scoreboard := FakeScoreboardState.new()
	scoreboard.player_points = 3
	scoreboard.boss_points = 8
	registry.instances["match_score_state"] = match_score
	registry.instances["scoreboard_state"] = scoreboard
	_expect(handler.get_score_snapshot(registry) == {"player_score": 9, "boss_score": 2}, "match_score_state snapshot should win over scoreboard fallback")

	match_score.snapshot = ["invalid"]
	_expect(handler.get_score_snapshot(registry) == {"player_score": 3, "boss_score": 8}, "scoreboard_state should backfill result score when match snapshot is invalid")

	registry.instances.clear()
	_expect(handler.get_score_snapshot(registry).is_empty(), "missing score owners should produce an empty snapshot")


func _verify_stage_and_character_context() -> void:
	var handler := StageClearResultRuntimeContextHandler.new()
	var owner := FakeOwner.new()
	owner.current_stage = -4
	_expect(handler.get_current_stage(owner) == 1, "current stage should clamp to Stage 1 minimum")
	owner.current_stage = 6
	_expect(handler.get_current_stage(owner) == 6, "current stage should pass through Stage 6")
	_expect(handler.get_current_stage(null) == 1, "missing owner should default to Stage 1")

	owner.selected_character_type = " IO "
	_expect(handler.get_selected_character_type(owner) == "optimus", "handler should normalize Optimus aliases")
	_expect(handler.get_result_victory_character_type(owner) == "smasher", "Optimus should use the shared Smasher victory result")
	owner.selected_character_type = " Commando "
	_expect(handler.get_selected_character_type(owner) == "soldier", "handler should normalize Commando aliases")
	_expect(handler.get_result_victory_character_type(owner) == "soldier", "Commando should keep dedicated victory result assets")
	owner.selected_character_type = " Kohaku "
	_expect(handler.get_selected_character_type(owner) == "blacksmith", "handler should normalize Blacksmith aliases")
	_expect(handler.get_result_victory_character_type(owner) == "blacksmith", "Blacksmith should keep dedicated victory result assets")
	_expect(handler.get_selected_character_type(null) == "smasher", "missing owner should default to Smasher")


func _verify_stage_result_reset_routing() -> void:
	var handler := StageClearResultRuntimeContextHandler.new()
	var registry := FakeRegistry.new()
	var stage5_state := FakeResetForResult.new()
	var stage5_event := FakeResetForResult.new()
	var stage5_actor := FakeActorRenderer.new()
	var stage6_state := FakeResetForResult.new()
	var stage4_ponk_state := FakeResetForResult.new()
	registry.instances["stage4_ponk_skill_state"] = stage4_ponk_state
	registry.instances["stage5_hongryun_state"] = stage5_state
	registry.instances["stage5_hongryun_fire_machine_event"] = stage5_event
	registry.instances["stage5_hongryun_actor_renderer"] = stage5_actor
	registry.instances["stage6_tetriser_state"] = stage6_state

	handler.reset_stage_for_result(registry, 5)
	_expect(stage4_ponk_state.reset_for_result_calls == 0, "Stage 5 result reset should not touch Stage 4 Ponk state")
	_expect(stage5_state.reset_for_result_calls == 1, "Stage 5 result reset should clear Hongryun state")
	_expect(stage5_event.reset_for_result_calls == 1, "Stage 5 result reset should clear Hongryun fire-machine event")
	_expect(stage5_actor.reset_round_fx_calls == 1, "Stage 5 result reset should prefer actor reset_round_fx")
	_expect(stage5_actor.reset_calls == 0, "Stage 5 actor reset fallback should not run when reset_round_fx exists")
	_expect(stage6_state.reset_for_result_calls == 0, "Stage 5 result reset should not touch Stage 6 state")

	var fallback_registry := FakeRegistry.new()
	var fallback_actor := FakeFallbackActorRenderer.new()
	fallback_registry.instances["stage5_hongryun_actor_renderer"] = fallback_actor
	handler.reset_stage5_for_result(fallback_registry, 5)
	_expect(fallback_actor.reset_calls == 1, "Stage 5 result reset should use actor reset fallback when round FX reset is absent")

	handler.reset_stage_for_result(registry, 6)
	_expect(stage6_state.reset_for_result_calls == 1, "Stage 6 result reset should clear Tetriser state")
	_expect(stage4_ponk_state.reset_for_result_calls == 0, "Stage 6 result reset should not touch Stage 4 Ponk state")
	_expect(stage5_state.reset_for_result_calls == 1, "Stage 6 result reset should not touch Stage 5 state")

	handler.reset_stage_for_result(registry, 4)
	_expect(stage4_ponk_state.reset_for_result_calls == 1, "Stage 4 result reset should clear Ponk skill state")
	_expect(stage5_state.reset_for_result_calls == 1, "non Stage 5/6 result reset should not touch Stage 5 state")
	_expect(stage6_state.reset_for_result_calls == 1, "non Stage 5/6 result reset should not touch Stage 6 state")


func _verify_screen_source_boundary() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var registry_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_handler_registry.gd")
	var handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_runtime_context_handler.gd")
	var context_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_runtime_context_data.gd")
	_expect(registry_source.find("StageClearResultRuntimeContextHandler.new()") >= 0, "handler registry should own runtime context through the handler")
	_expect(screen_source.find("\"stage5_hongryun_state\"") < 0, "result screen should not perform Stage 5 registry lookups directly")
	_expect(screen_source.find("\"stage6_tetriser_state\"") < 0, "result screen should not perform Stage 6 registry lookups directly")
	_expect(screen_source.find("func _get_score_snapshot") < 0, "result screen should not keep score snapshot pass-through helpers")
	_expect(screen_source.find("func _get_selected_character_type") < 0, "result screen should not keep character context pass-through helpers")
	_expect(screen_source.find("_call_int") < 0, "result screen should not keep score primitive helpers inline")
	_expect(handler_source.find("StageClearResultRuntimeContextData.get_score_snapshot") >= 0, "runtime context handler should delegate score snapshots")
	_expect(handler_source.find("StageClearResultRuntimeContextData.get_selected_character_type") >= 0, "runtime context handler should delegate character context")
	_expect(handler_source.find("StageClearResultRuntimeContextData.reset_stage_for_result") >= 0, "runtime context handler should delegate result reset routing")
	_expect(handler_source.find("\"stage4_ponk_skill_state\"") < 0, "runtime context handler should not keep Stage 4 result reset lookup details")
	_expect(handler_source.find("\"stage5_hongryun_state\"") < 0, "runtime context handler should not keep Stage 5 result reset lookup details")
	_expect(handler_source.find("\"stage6_tetriser_state\"") < 0, "runtime context handler should not keep Stage 6 result reset lookup details")
	_expect(context_data_source.find("\"stage4_ponk_skill_state\"") >= 0, "runtime context data should own Stage 4 Ponk result reset lookup")
	_expect(context_data_source.find("\"stage5_hongryun_state\"") >= 0, "runtime context data should own Stage 5 result reset lookup")
	_expect(context_data_source.find("\"stage6_tetriser_state\"") >= 0, "runtime context data should own Stage 6 result reset lookup")
	_expect(context_data_source.find("get_score_snapshot") >= 0, "runtime context data should own result score snapshot reads")
	_expect(context_data_source.find("PlayerCharacterRuntime") >= 0, "runtime context data should own result character normalization")
	var registry := FakeRegistry.new()
	var stage6_state := FakeResetForResult.new()
	registry.instances["stage6_tetriser_state"] = stage6_state
	StageClearResultRuntimeContextHandler.new().reset_stage6_for_result(registry, 6)
	_expect(stage6_state.reset_for_result_calls == 1, "runtime context handler should expose Stage 6 result reset directly")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
