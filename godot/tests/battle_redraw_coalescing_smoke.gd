extends SceneTree

# Seals the physics-redraw coalescing contract:
# physics-tick dispatches must never call owner.queue_redraw() directly
# (each tick's MessageQueue flush would re-run the full immediate-mode
# _draw, multiplying draw cost during physics catch-up — the frame-drop
# spiral with the BattlePerf draw==proc+phys identity). Tick-side code
# sets a dirty flag via owner.request_battle_redraw(); the shell flushes
# at most ONE queue_redraw per rendered frame from _process.

const BattleSceneUpdateCallbacks := preload("res://scripts/core/battle_scene_update_callbacks.gd")
const BattleFrameFlowController := preload("res://scripts/core/battle_frame_flow_controller.gd")
const BattleSceneMatchEventDriver := preload("res://scripts/core/battle_scene_match_event_driver.gd")
const MatchScoreEventController := preload("res://scripts/core/match_score_event_controller.gd")
const BattleSceneShell := preload("res://scripts/core/battle_scene_shell.gd")

var _failures: Array[String] = []


class FakeRedrawOwner:
	extends RefCounted
	var request_count := 0
	var queue_count := 0

	func request_battle_redraw() -> void:
		request_count += 1

	func queue_redraw() -> void:
		queue_count += 1


class LegacyRedrawOwner:
	extends RefCounted
	var queue_count := 0

	func queue_redraw() -> void:
		queue_count += 1


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


func _init() -> void:
	_verify_callbacks_bind_request_flag_over_queue_redraw()
	_verify_physics_flow_updates_never_queue_redraw_directly()
	_verify_legacy_owner_falls_back_to_queue_redraw()
	_verify_shell_flushes_single_redraw_per_frame()
	_verify_match_event_driver_routes_redraw_requests()
	_verify_score_event_ball_hide_routes_redraw_request()

	if _failures.is_empty():
		print("battle_redraw_coalescing_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_callbacks_bind_request_flag_over_queue_redraw() -> void:
	var owner := FakeRedrawOwner.new()
	var callbacks: Dictionary = BattleSceneUpdateCallbacks.new().build_frame_callbacks(owner, FakeRegistry.new())
	var redraw_callback: Callable = callbacks.get("queue_redraw", Callable())
	_expect(redraw_callback.is_valid(), "frame callbacks should expose a valid queue_redraw callable")
	for _i in range(3):
		redraw_callback.call()
	_expect(owner.queue_count == 0, "physics redraw callback must not call queue_redraw directly (got %d)" % owner.queue_count)
	_expect(owner.request_count == 3, "physics redraw callback should route every call to request_battle_redraw (got %d)" % owner.request_count)


func _verify_physics_flow_updates_never_queue_redraw_directly() -> void:
	var owner := FakeRedrawOwner.new()
	var callbacks: Dictionary = BattleSceneUpdateCallbacks.new().build_frame_callbacks(owner, FakeRegistry.new())
	var flow: Object = BattleFrameFlowController.new()
	for _i in range(5):
		flow.update(1.0 / 72.0, {}, callbacks)
	_expect(owner.queue_count == 0, "repeated physics flow updates must keep owner queue_redraw at 0 before flush (got %d)" % owner.queue_count)
	_expect(owner.request_count == 5, "each physics flow update should leave exactly one redraw request (got %d)" % owner.request_count)


func _verify_legacy_owner_falls_back_to_queue_redraw() -> void:
	var owner := LegacyRedrawOwner.new()
	var callbacks: Dictionary = BattleSceneUpdateCallbacks.new().build_frame_callbacks(owner, FakeRegistry.new())
	var redraw_callback: Callable = callbacks.get("queue_redraw", Callable())
	_expect(redraw_callback.is_valid(), "legacy owner should still get a valid queue_redraw callable")
	for _i in range(2):
		redraw_callback.call()
	_expect(owner.queue_count == 2, "owner without request_battle_redraw should keep the direct queue_redraw path (got %d)" % owner.queue_count)


func _verify_shell_flushes_single_redraw_per_frame() -> void:
	var shell: Node2D = BattleSceneShell.new()
	_expect(not bool(shell._flush_battle_redraw_request()), "shell flush without a pending request should be a no-op")
	for _i in range(3):
		shell.request_battle_redraw()
	_expect(bool(shell._flush_battle_redraw_request()), "shell flush should consume pending requests as one redraw")
	_expect(not bool(shell._flush_battle_redraw_request()), "second flush in the same frame must not redraw again")
	shell.free()


func _verify_match_event_driver_routes_redraw_requests() -> void:
	var driver: Object = BattleSceneMatchEventDriver.new()
	var owner := FakeRedrawOwner.new()
	driver._queue_redraw(owner)
	_expect(owner.queue_count == 0 and owner.request_count == 1, "match event driver should route redraw through request_battle_redraw")
	var legacy_owner := LegacyRedrawOwner.new()
	driver._queue_redraw(legacy_owner)
	_expect(legacy_owner.queue_count == 1, "match event driver should fall back to queue_redraw for legacy owners")


func _verify_score_event_ball_hide_routes_redraw_request() -> void:
	var controller: Object = MatchScoreEventController.new()
	var owner := FakeRedrawOwner.new()
	controller._hide_ball_for_odins_eye_event({"owner": owner})
	_expect(owner.queue_count == 0 and owner.request_count == 1, "odins eye ball hide should route redraw through request_battle_redraw")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
