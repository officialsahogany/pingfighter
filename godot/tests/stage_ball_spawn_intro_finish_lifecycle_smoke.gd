extends SceneTree

const StageBallSpawnIntroFinishLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_finish_lifecycle.gd")
const StageBallSpawnIntroLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_lifecycle.gd")

var _failures: Array[String] = []


class FakeRoundState:
	extends RefCounted

	var prepared := 0
	var reset_wait := 0

	func prepare_serve_after_intro() -> void:
		prepared += 1

	func reset_round_wait() -> void:
		reset_wait += 1


class FakeRuntimePerkState:
	extends RefCounted

	var intro_finished_calls := 0
	var last_owner: Object = null
	var last_registry: Object = null

	func on_ball_spawn_intro_finished(owner: Object, registry: Object) -> void:
		intro_finished_calls += 1
		last_owner = owner
		last_registry = registry


class FakeRegistry:
	extends RefCounted

	var round_state := FakeRoundState.new()
	var runtime_perk_state := FakeRuntimePerkState.new()

	func get_instance(key: String) -> Object:
		if key == "round_flow_state":
			return round_state
		if key == "runtime_perk_state":
			return runtime_perk_state
		return null


class FakeIntro:
	extends RefCounted

	var active := true
	var overlay_active := true
	var serve_handoff_done := false
	var elapsed_sec := 2.5
	var synced_serve_input := 0
	var owner_snapshot: Dictionary = {}

	func _apply_owner_spawn_snapshot(_owner: Object, ball_pos: Vector2) -> void:
		owner_snapshot = {
			"ball_pos": ball_pos,
			"ball_vel": Vector2.ZERO,
			"ball_active": false,
		}

	func _sync_serve_input(_registry: Object) -> void:
		synced_serve_input += 1

	func _has_completed_serve_handoff() -> bool:
		return serve_handoff_done

	func is_overlay_active() -> bool:
		return active or overlay_active


class FakeResetLifecycle:
	extends RefCounted

	var calls := 0

	func reset_state(_intro: Object) -> void:
		calls += 1


class FakeFinishLifecycle:
	extends RefCounted

	var calls := 0
	var last_target := Vector2.ZERO

	func finish_intro(_intro: Object, _owner: Object, _registry: Object, target_pos: Vector2, _reset_lifecycle: Object) -> void:
		calls += 1
		last_target = target_pos


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_finish_lifecycle_resets_and_resumes_serve()
	_verify_lifecycle_delegates_finish_surface()

	await process_frame
	if _failures.is_empty():
		print("stage_ball_spawn_intro_finish_lifecycle_smoke: ok")
		call_deferred("_quit_with_code", 0)
	else:
		for failure in _failures:
			push_error(failure)
		call_deferred("_quit_with_code", 1)


func _quit_with_code(exit_code: int) -> void:
	await process_frame
	quit(exit_code)


func _verify_finish_lifecycle_resets_and_resumes_serve() -> void:
	var lifecycle: Object = StageBallSpawnIntroFinishLifecycle.new()
	var intro := FakeIntro.new()
	var registry := FakeRegistry.new()
	var reset := FakeResetLifecycle.new()
	var target := Vector2(123.0, 456.0)

	lifecycle.finish_intro(intro, null, registry, target, reset)

	_expect(not intro.active, "finish lifecycle should mark intro inactive")
	_expect(not intro.overlay_active, "finish lifecycle should mark intro overlay inactive")
	_expect(is_equal_approx(intro.elapsed_sec, 0.0), "finish lifecycle should reset elapsed time")
	_expect(reset.calls == 1, "finish lifecycle should delegate reset state")
	_expect(intro.owner_snapshot.get("ball_pos", Vector2.ZERO) == target, "finish lifecycle should restore target ball position")
	_expect(registry.round_state.prepared == 1, "finish lifecycle should prepare serve after intro")
	_expect(registry.round_state.reset_wait == 0, "finish lifecycle should prefer prepare_serve_after_intro")
	_expect(intro.synced_serve_input == 1, "finish lifecycle should sync serve input edges")
	_expect(registry.runtime_perk_state.intro_finished_calls == 1, "finish lifecycle should flush runtime perk effects after the intro ends")

	var handed_off_intro := FakeIntro.new()
	handed_off_intro.active = false
	handed_off_intro.overlay_active = true
	handed_off_intro.serve_handoff_done = true
	var handed_off_registry := FakeRegistry.new()
	lifecycle.finish_intro(handed_off_intro, null, handed_off_registry, target, reset)
	_expect(handed_off_intro.owner_snapshot.is_empty(), "finish lifecycle should preserve live ball state after early handoff")
	_expect(handed_off_registry.round_state.prepared == 0, "finish lifecycle should not prepare serve twice after early handoff")
	_expect(handed_off_intro.synced_serve_input == 0, "finish lifecycle should not resync serve input after early handoff")
	_expect(handed_off_registry.runtime_perk_state.intro_finished_calls == 1, "finish lifecycle should still flush runtime perk effects after the residual overlay ends")
	registry.runtime_perk_state.last_owner = null
	registry.runtime_perk_state.last_registry = null
	handed_off_registry.runtime_perk_state.last_owner = null
	handed_off_registry.runtime_perk_state.last_registry = null


func _verify_lifecycle_delegates_finish_surface() -> void:
	var lifecycle: Object = StageBallSpawnIntroLifecycle.new()
	var fake := FakeFinishLifecycle.new()
	lifecycle.finish_lifecycle = fake
	var target := Vector2(10.0, 20.0)
	var intro := FakeIntro.new()

	lifecycle.finish(intro, null, null, target)

	_expect(fake.calls == 1, "intro lifecycle should delegate finish")
	_expect(fake.last_target == target, "intro lifecycle should pass finish target through")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
