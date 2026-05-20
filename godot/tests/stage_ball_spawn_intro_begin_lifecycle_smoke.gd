extends SceneTree

const StageBallSpawnIntroBeginLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_begin_lifecycle.gd")
const StageBallSpawnIntroLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_lifecycle.gd")

var _failures: Array[String] = []


class FakeRoundState:
	extends RefCounted

	var paused := 0
	var player_serves := false

	func does_player_serve() -> bool:
		return player_serves

	func pause_serve_for_intro() -> void:
		paused += 1


class FakeRegistry:
	extends RefCounted

	var round_state := FakeRoundState.new()

	func get_instance(key: String) -> Object:
		if key == "round_flow_state":
			return round_state
		return null


class FakeOwner:
	extends RefCounted

	var current_stage := 2


class FakeIntro:
	extends RefCounted

	var active := false
	var overlay_active := false
	var serve_handoff_done := true
	var elapsed_sec := 9.0
	var current_stage := 1
	var player_serves := true
	var start_pos := Vector2.ZERO
	var target_pos := Vector2.ZERO
	var rng := RandomNumberGenerator.new()
	var prewarm_calls := 0
	var reset_calls := 0
	var spawn_calls := 0
	var begin_fx_calls := 0
	var synced_serve_input := 0
	var owner_snapshot: Dictionary = {}

	func _get_glow_texture() -> Variant:
		prewarm_calls += 1
		return null

	func _get_ball_texture() -> Variant:
		prewarm_calls += 1
		return null

	func _get_ball_body_texture() -> Variant:
		prewarm_calls += 1
		return null

	func _get_serve_target(_owner: Object) -> Vector2:
		return Vector2(321.0, 654.0)

	func _reset_state() -> void:
		reset_calls += 1

	func _spawn_initial_entities() -> void:
		spawn_calls += 1

	func _begin_fx_host(_owner: Object) -> void:
		begin_fx_calls += 1

	func _apply_owner_spawn_snapshot(_owner: Object, ball_pos: Vector2) -> void:
		owner_snapshot = {
			"ball_pos": ball_pos,
			"ball_vel": Vector2.ZERO,
			"ball_active": false,
		}

	func _sync_serve_input(_registry: Object) -> void:
		synced_serve_input += 1


class FakeBeginLifecycle:
	extends RefCounted

	var calls := 0
	var last_config: Dictionary = {}

	func begin_intro(_intro: Object, _owner: Object, _registry: Object, config: Dictionary) -> bool:
		calls += 1
		last_config = config
		return true


func _init() -> void:
	_verify_begin_lifecycle_starts_intro()
	_verify_begin_lifecycle_skips_tutorial_intro()
	_verify_lifecycle_delegates_begin_surface()

	if _failures.is_empty():
		print("stage_ball_spawn_intro_begin_lifecycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _begin_config() -> Dictionary:
	return {
		"tutorial_stage": 50,
		"game_width": 760.0,
		"game_height": 750.0,
	}


func _verify_begin_lifecycle_starts_intro() -> void:
	var lifecycle: Object = StageBallSpawnIntroBeginLifecycle.new()
	var intro := FakeIntro.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()

	_expect(lifecycle.begin_intro(intro, owner, registry, _begin_config()), "begin lifecycle should start a normal stage intro")
	_expect(intro.current_stage == 2, "begin lifecycle should store current stage")
	_expect(intro.active, "begin lifecycle should mark intro active")
	_expect(intro.overlay_active, "begin lifecycle should mark intro overlay active")
	_expect(not intro.serve_handoff_done, "begin lifecycle should clear prior serve handoff state")
	_expect(not intro.player_serves, "begin lifecycle should preserve round serve side")
	_expect(intro.start_pos == Vector2(380.0, 375.0), "begin lifecycle should set center start position")
	_expect(intro.target_pos == Vector2(321.0, 654.0), "begin lifecycle should resolve serve target")
	_expect(is_equal_approx(intro.elapsed_sec, 0.0), "begin lifecycle should reset elapsed time")
	_expect(intro.prewarm_calls == 3, "begin lifecycle should prewarm three texture paths")
	_expect(intro.reset_calls == 1, "begin lifecycle should reset intro state")
	_expect(intro.spawn_calls == 1, "begin lifecycle should spawn initial entities")
	_expect(intro.begin_fx_calls == 1, "begin lifecycle should attach FX host")
	_expect(intro.owner_snapshot.get("ball_pos", Vector2.ZERO) == Vector2(380.0, 375.0), "begin lifecycle should publish start ball snapshot")
	_expect(registry.round_state.paused == 1, "begin lifecycle should pause serve for intro")
	_expect(intro.synced_serve_input == 1, "begin lifecycle should sync serve input edges")


func _verify_begin_lifecycle_skips_tutorial_intro() -> void:
	var lifecycle: Object = StageBallSpawnIntroBeginLifecycle.new()
	var intro := FakeIntro.new()
	var owner := FakeOwner.new()
	owner.current_stage = 50

	_expect(not lifecycle.begin_intro(intro, owner, null, _begin_config()), "begin lifecycle should skip tutorial stage")
	_expect(not intro.active, "skipped tutorial begin should not activate intro")
	_expect(intro.prewarm_calls == 0, "skipped tutorial begin should not prewarm textures")


func _verify_lifecycle_delegates_begin_surface() -> void:
	var lifecycle: Object = StageBallSpawnIntroLifecycle.new()
	var fake := FakeBeginLifecycle.new()
	lifecycle.begin_lifecycle = fake

	_expect(lifecycle.begin_intro(RefCounted.new(), RefCounted.new(), null, _begin_config()), "intro lifecycle should return delegated begin result")
	_expect(fake.calls == 1, "intro lifecycle should delegate begin")
	_expect(fake.last_config.get("tutorial_stage", 0) == 50, "intro lifecycle should pass begin config through")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
