extends SceneTree

const StageBallSpawnIntroLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_lifecycle.gd")
const StageBallSpawnIntroUpdateLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_update_lifecycle.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted


class FakeIntro:
	extends RefCounted

	var active := true
	var overlay_active := true
	var serve_handoff_done := false
	var elapsed_sec := 0.0
	var start_pos := Vector2(380.0, 375.0)
	var next_ball_state := {
		"visible": true,
		"pos": Vector2(44.0, 55.0),
	}
	var finish_calls := 0
	var handoff_calls := 0
	var phase1_calls := 0
	var phase2_calls := 0
	var phase3_calls := 0
	var outro_calls := 0
	var state_sync_calls := 0
	var last_update_dt := 0.0
	var owner_snapshot: Dictionary = {}

	func _finish(_owner: Object, _registry: Object) -> void:
		finish_calls += 1
		active = false
		overlay_active = false

	func _complete_gameplay_handoff(_owner: Object, _registry: Object) -> void:
		handoff_calls += 1
		serve_handoff_done = true
		active = false
		overlay_active = true

	func _has_completed_serve_handoff() -> bool:
		return serve_handoff_done

	func is_overlay_active() -> bool:
		return active or overlay_active

	func _update_phase_1(dt: float) -> void:
		phase1_calls += 1
		last_update_dt = dt

	func _update_phase_2(dt: float) -> void:
		phase2_calls += 1
		last_update_dt = dt

	func _update_phase_3(dt: float) -> void:
		phase3_calls += 1
		last_update_dt = dt

	func _update_outro(dt: float) -> void:
		outro_calls += 1
		last_update_dt = dt

	func _get_ball_state() -> Dictionary:
		return next_ball_state

	func _sync_fx_host_state(_ball_state: Dictionary) -> void:
		state_sync_calls += 1

	func _apply_owner_spawn_snapshot(_owner: Object, ball_pos: Vector2) -> void:
		owner_snapshot = {
			"ball_pos": ball_pos,
			"ball_vel": Vector2.ZERO,
			"ball_active": false,
		}


class FakeUpdateLifecycle:
	extends RefCounted

	var calls := 0
	var last_delta := 0.0

	func update_intro(_intro: Object, delta: float, _owner: Object, _registry: Object, _config: Dictionary) -> void:
		calls += 1
		last_delta = delta


func _init() -> void:
	_verify_update_lifecycle_dispatches_phase_tick()
	_verify_update_lifecycle_hands_off_on_blocking_duration()
	_verify_update_lifecycle_finishes_on_total_duration()
	_verify_lifecycle_delegates_update_surface()

	if _failures.is_empty():
		print("stage_ball_spawn_intro_update_lifecycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _update_config() -> Dictionary:
	return {
		"phase_1_duration": 2.0,
		"phase_2_duration": 0.75,
		"phase_3_duration": 1.25,
		"blocking_duration": 4.0,
		"total_duration": 4.4,
	}


func _verify_update_lifecycle_dispatches_phase_tick() -> void:
	var lifecycle: Object = StageBallSpawnIntroUpdateLifecycle.new()
	var owner := FakeOwner.new()

	var phase1_intro := FakeIntro.new()
	lifecycle.update_intro(phase1_intro, 0.20, owner, null, _update_config())
	_expect(is_equal_approx(phase1_intro.elapsed_sec, 0.05), "update lifecycle should clamp delta before ticking elapsed time")
	_expect(phase1_intro.phase1_calls == 1, "update lifecycle should dispatch Phase 1")
	_expect(is_equal_approx(phase1_intro.last_update_dt, 0.05), "update lifecycle should pass clamped delta")
	_expect(phase1_intro.state_sync_calls == 1, "update lifecycle should sync FX host state after phase update")
	_expect(phase1_intro.owner_snapshot.get("ball_pos", Vector2.ZERO) == Vector2(44.0, 55.0), "update lifecycle should publish visible ball snapshot")

	var phase2_intro := FakeIntro.new()
	phase2_intro.elapsed_sec = 2.0
	lifecycle.update_intro(phase2_intro, 0.01, owner, null, _update_config())
	_expect(phase2_intro.phase2_calls == 1, "update lifecycle should dispatch Phase 2")

	var phase3_intro := FakeIntro.new()
	phase3_intro.elapsed_sec = 2.75
	lifecycle.update_intro(phase3_intro, 0.01, owner, null, _update_config())
	_expect(phase3_intro.phase3_calls == 1, "update lifecycle should dispatch Phase 3")

	var inactive_intro := FakeIntro.new()
	inactive_intro.active = false
	inactive_intro.overlay_active = false
	lifecycle.update_intro(inactive_intro, 0.01, owner, null, _update_config())
	_expect(is_equal_approx(inactive_intro.elapsed_sec, 0.0), "inactive update lifecycle should not tick elapsed time")


func _verify_update_lifecycle_hands_off_on_blocking_duration() -> void:
	var lifecycle: Object = StageBallSpawnIntroUpdateLifecycle.new()
	var intro := FakeIntro.new()
	intro.elapsed_sec = 3.99

	lifecycle.update_intro(intro, 0.20, null, null, _update_config())

	_expect(intro.handoff_calls == 1, "update lifecycle should hand off gameplay when blocking duration is reached")
	_expect(intro.finish_calls == 0, "blocking-duration handoff should keep residual overlay alive")
	_expect(not intro.active and intro.overlay_active, "handoff should unblock gameplay but keep overlay active")
	_expect(intro.outro_calls == 1, "handoff update should dispatch the outro tick")
	_expect(intro.state_sync_calls == 1, "handoff update should keep syncing FX state for the outro")


func _verify_update_lifecycle_finishes_on_total_duration() -> void:
	var lifecycle: Object = StageBallSpawnIntroUpdateLifecycle.new()
	var intro := FakeIntro.new()
	intro.active = false
	intro.overlay_active = true
	intro.serve_handoff_done = true
	intro.elapsed_sec = 4.39

	lifecycle.update_intro(intro, 0.20, null, null, _update_config())

	_expect(intro.finish_calls == 1, "update lifecycle should finish overlay when total duration is reached")
	_expect(intro.phase1_calls == 0 and intro.phase2_calls == 0 and intro.phase3_calls == 0, "finished update should skip phase dispatch")
	_expect(intro.state_sync_calls == 0, "finished update should skip FX state sync")


func _verify_lifecycle_delegates_update_surface() -> void:
	var lifecycle: Object = StageBallSpawnIntroLifecycle.new()
	var fake := FakeUpdateLifecycle.new()
	lifecycle.update_lifecycle = fake

	lifecycle.update_intro(RefCounted.new(), 0.12, null, null, _update_config())

	_expect(fake.calls == 1, "intro lifecycle should delegate per-frame update")
	_expect(is_equal_approx(fake.last_delta, 0.12), "intro lifecycle should pass update delta through")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
