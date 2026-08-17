extends SceneTree

const Stage6TetriserStarpointState := preload("res://scripts/stages/stage6/stage6_tetriser_starpoint_state.gd")
const StarpointPayloadFactory := preload("res://scripts/stages/common/starpoint_payload_factory.gd")

const HOST_PATH := "res://scripts/stages/stage6/stage6_tetriser_state.gd"
const CONTEXT_BUILDER_PATH := "res://scripts/stages/stage6/stage6_tetriser_context_builder.gd"
const EVENT_COORDINATOR_PATH := "res://scripts/stages/stage6/stage6_tetriser_event_coordinator.gd"

var _failures: Array[String] = []


class FakeRuntimePerkState:
	extends RefCounted
	var calls: Array[Dictionary] = []

	func collect_star_points(amount: int, character_type: String, catalog: Object, owner: Object, registry: Object) -> bool:
		calls.append({
			"amount": amount,
			"character_type": character_type,
			"catalog": catalog,
			"owner": owner,
			"registry": registry,
		})
		return true


class FakeOwner:
	extends RefCounted
	var redraws := 0

	func queue_redraw() -> void:
		redraws += 1


func _init() -> void:
	_verify_shared_rng_payload_and_golden_gate()
	_verify_motion_collection_and_stage_leave()
	_verify_copied_snapshots()
	_verify_host_delegates_starpoint_ownership()
	if _failures.is_empty():
		print("stage6_tetriser_starpoint_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_shared_rng_payload_and_golden_gate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 62061
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = 62061
	var state := Stage6TetriserStarpointState.new(rng)
	var spawn_pos := Vector2(240.0, 180.0)
	state.spawn(spawn_pos)
	var expected: Dictionary = StarpointPayloadFactory.build_drop(
		spawn_pos,
		expected_rng,
		false,
		Stage6TetriserStarpointState.DROP_SIZE,
		Stage6TetriserStarpointState.DROP_LIFETIME,
		0.05,
		0.1,
		"stage6_tetriser"
	)
	var snapshot: Array = state.get_snapshot()
	_expect(snapshot.size() == 1 and snapshot[0] == expected, "starpoint owner should consume the shared RNG exactly like the legacy payload path")

	var golden := {
		"golden": true,
		"origin": Vector2(100.0, 200.0),
		"cells": [Vector2(0.0, 0.0), Vector2(1.0, 0.0)],
		"cell_size": 20.0,
	}
	_expect(state.maybe_spawn_for_block(golden), "first golden-block event should spawn a starpoint")
	_expect(bool(golden.get("star_dropped", false)), "golden-block owner should mark the shared block dictionary synchronously")
	_expect(not state.maybe_spawn_for_block(golden), "the star_dropped gate should reject a duplicate spawn")
	_expect(state.get_count() == 2, "golden-block duplicate gate should keep exactly one additional drop")
	var golden_drop: Dictionary = state.get_snapshot()[1]
	_expect(golden_drop.get("pos", Vector2.ZERO) == Vector2(120.0, 210.0), "golden drop should use the exact average cell center")
	_expect(not state.maybe_spawn_for_block({"golden": false}), "ordinary blocks should not spawn starpoints")


func _verify_motion_collection_and_stage_leave() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 62062
	var state := Stage6TetriserStarpointState.new(rng)
	state.spawn(Vector2(380.0, 375.0))
	var before: Dictionary = state.get_snapshot()[0]
	state.update(1.0, {
		"current_stage": 6,
		"player_pos": Vector2(0.0, 690.0),
		"player_paddle_size": Vector2(80.0, 40.0),
	}, {})
	var after: Dictionary = state.get_snapshot()[0]
	_expect(after.get("pos", Vector2.ZERO) != before.get("pos", Vector2.ZERO), "active Stage 6 update should advance drop motion")
	_expect(state.get_count() == 1, "non-overlapping drop should remain alive after motion")

	var runtime_state := FakeRuntimePerkState.new()
	var owner := FakeOwner.new()
	var catalog := RefCounted.new()
	var registry := RefCounted.new()
	var drop_pos: Vector2 = after.get("pos", Vector2(380.0, 375.0))
	var overlap_context := {
		"current_stage": 6,
		"selected_character_type": "smasher",
		"player_pos": drop_pos - Vector2(50.0, 50.0),
		"player_paddle_size": Vector2(100.0, 100.0),
		"owner": owner,
		"registry": registry,
	}
	state.update(0.0, overlap_context, {})
	_expect(state.get_count() == 1, "missing runtime reward deps should preserve an overlapping drop")
	state.update(0.0, overlap_context, {
		"runtime_perk_state": runtime_state,
		"runtime_perk_catalog": catalog,
	})
	_expect(state.get_count() == 0, "successful reward collection should remove the overlapping drop")
	_expect(runtime_state.calls.size() == 1, "collection should call the runtime perk state exactly once")
	if runtime_state.calls.size() == 1:
		var call: Dictionary = runtime_state.calls[0]
		_expect(int(call.get("amount", 0)) == 1, "collection should grant exactly one star point")
		_expect(call.get("catalog", null) == catalog, "collection should forward the runtime perk catalog")
		_expect(call.get("owner", null) == owner, "collection should forward the live owner")
		_expect(call.get("registry", null) == registry, "collection should forward the live registry")
	_expect(owner.redraws == 1, "successful collection should request one owner redraw")

	state.spawn(Vector2(380.0, 375.0))
	state.update(0.0, {"current_stage": 5}, {})
	_expect(state.get_count() == 0, "leaving Stage 6 should clear transient starpoint drops")


func _verify_copied_snapshots() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 62063
	var state := Stage6TetriserStarpointState.new(rng)
	state.spawn(Vector2(300.0, 300.0))
	var draw_list: Array = state.get_draw_list()
	(draw_list[0] as Dictionary)["pos"] = Vector2.ZERO
	_expect((state.get_snapshot()[0] as Dictionary).get("pos", Vector2.ZERO) == Vector2(300.0, 300.0), "draw snapshots should not expose mutable owner state")
	state.clear()
	_expect(not state.has_drops() and state.get_count() == 0, "clear should empty the starpoint lifecycle owner")


func _verify_host_delegates_starpoint_ownership() -> void:
	var source := FileAccess.get_file_as_string(HOST_PATH)
	var context_source := FileAccess.get_file_as_string(CONTEXT_BUILDER_PATH)
	var event_source := FileAccess.get_file_as_string(EVENT_COORDINATOR_PATH)
	_expect(source.contains("const TetriserStarpointState := preload("), "Stage 6 host should preload the starpoint owner")
	_expect(source.contains("var _starpoint_state: Object = null"), "Stage 6 host should keep one starpoint-owner instance")
	_expect(source.contains("_starpoint_state.update(fps_scale, context, deps)"), "Stage 6 host should delegate starpoint motion and collection")
	_expect(source.contains("_event_coordinator = TetriserEventCoordinator.new("), "Stage 6 host should delegate cross-owner combat events")
	_expect(event_source.contains("_starpoint_state.maybe_spawn_for_block(block)"), "Stage 6 event coordinator should delegate the golden one-shot gate")
	_expect(source.contains("_context_builder.build_actor_draw_context("), "Stage 6 host should delegate actor-context assembly")
	_expect(context_source.contains("\"stage6_tetriser_starpoint_drops\": starpoint_state.get_draw_list()"), "Stage 6 context builder should consume the owner snapshot")
	_expect(not source.contains("var _starpoint_drops:"), "Stage 6 host should not restore a starpoint-array mirror")
	_expect(not source.contains("func _update_starpoint_drops("), "Stage 6 host should not restore starpoint lifecycle logic")
	_expect(not source.contains("const StarpointPayloadFactory := preload("), "Stage 6 host should not retain starpoint payload construction")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
