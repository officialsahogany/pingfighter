extends SceneTree

const StageBallSpawnIntro := preload("res://scripts/core/stage_ball_spawn_intro.gd")
const StageBallSpawnIntroLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_lifecycle.gd")

var _failures: Array[String] = []


class FakeRoundState:
	extends RefCounted

	var prepared := 0
	var reset_wait := 0
	var paused := 0
	var player_serves := false

	func does_player_serve() -> bool:
		return player_serves

	func pause_serve_for_intro() -> void:
		paused += 1

	func prepare_serve_after_intro() -> void:
		prepared += 1

	func reset_round_wait() -> void:
		reset_wait += 1


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
	var player_pos := Vector2(200.0, 700.0)
	var boss_pos := Vector2(300.0, 25.0)
	var player_paddle_width := 155.0


class FakeIntro:
	extends RefCounted

	var active := true
	var overlay_active := true
	var serve_handoff_done := false
	var elapsed_sec := 2.5
	var current_stage := 1
	var player_serves := true
	var start_pos := Vector2.ZERO
	var target_pos := Vector2.ZERO
	var rng := RandomNumberGenerator.new()
	var next_ball_state := {
		"visible": true,
		"pos": Vector2(44.0, 55.0),
	}
	var particles := [{"dirty": true}]
	var vortex_rings := [{"dirty": true}]
	var lightning_bolts := [{"dirty": true}]
	var chain_lightnings := [{"dirty": true}]
	var electric_arcs := [{"dirty": true}]
	var sparks := [{"dirty": true}]
	var hologram_rings := [{"dirty": true}]
	var energy_rings := [{"dirty": true}]
	var phase3_trail := [Vector2.ONE]
	var starfield := [{"dirty": true}]
	var haze_clouds := [{"dirty": true}]
	var lightning_spawn_timer := 1.0
	var arc_spawn_timer := 1.0
	var spark_spawn_timer := 1.0
	var hologram_spawn_timer := 1.0
	var energy_ring_timer := 1.0
	var particle_spawn_timer := 1.0
	var chain_spawn_timer := 1.0
	var fog_alpha := 100.0
	var core_glow_radius := 20.0
	var core_glow_alpha := 30.0
	var prewarm_calls := 0
	var tear_down_calls := 0
	var reset_calls := 0
	var spawn_calls := 0
	var begin_fx_calls := 0
	var finish_calls := 0
	var handoff_calls := 0
	var phase1_calls := 0
	var phase2_calls := 0
	var phase3_calls := 0
	var outro_calls := 0
	var state_sync_calls := 0
	var last_update_dt := 0.0
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

	func _tear_down_fx_host() -> void:
		tear_down_calls += 1

	func _apply_owner_spawn_snapshot(_owner: Object, ball_pos: Vector2) -> void:
		owner_snapshot = {
			"ball_pos": ball_pos,
			"ball_vel": Vector2.ZERO,
			"ball_active": false,
		}

	func _sync_serve_input(_registry: Object) -> void:
		synced_serve_input += 1


class FakeIntroLifecycle:
	extends RefCounted

	var begin_calls := 0
	var update_calls := 0
	var spawn_calls := 0
	var finish_calls := 0
	var reset_calls := 0

	func begin_intro(_intro: Object, _owner: Object, _registry: Object, _config: Dictionary) -> bool:
		begin_calls += 1
		return true

	func update_intro(_intro: Object, _delta: float, _owner: Object, _registry: Object, _config: Dictionary) -> void:
		update_calls += 1

	func spawn_initial_entities(_intro: Object, _config: Dictionary) -> void:
		spawn_calls += 1

	func finish(_intro: Object, _owner: Object, _registry: Object, _target_pos: Vector2) -> void:
		finish_calls += 1

	func reset_state(_intro: Object) -> void:
		reset_calls += 1


func _init() -> void:
	_verify_lifecycle_begins_intro()
	_verify_lifecycle_skips_tutorial_intro()
	_verify_lifecycle_updates_intro_phase_dispatch()
	_verify_lifecycle_finishes_intro_on_duration()
	_verify_lifecycle_spawns_initial_intro_entities()
	_verify_lifecycle_resets_intro_vfx_state()
	_verify_lifecycle_finishes_intro_and_resumes_serve()
	_verify_intro_delegates_finish_and_reset_surface()

	if _failures.is_empty():
		print("stage_ball_spawn_intro_lifecycle_smoke: ok")
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


func _verify_lifecycle_begins_intro() -> void:
	var lifecycle: Object = StageBallSpawnIntroLifecycle.new()
	var intro := FakeIntro.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()

	_expect(lifecycle.begin_intro(intro, owner, registry, {
		"tutorial_stage": 50,
		"game_width": 760.0,
		"game_height": 750.0,
	}), "lifecycle begin should start a normal stage intro")
	_expect(intro.current_stage == 2, "lifecycle begin should store current stage")
	_expect(intro.active, "lifecycle begin should mark intro active")
	_expect(intro.overlay_active, "lifecycle begin should mark intro overlay active")
	_expect(not intro.serve_handoff_done, "lifecycle begin should clear prior serve handoff state")
	_expect(not intro.player_serves, "lifecycle begin should preserve round serve side")
	_expect(intro.start_pos == Vector2(380.0, 375.0), "lifecycle begin should set center start position")
	_expect(intro.target_pos == Vector2(321.0, 654.0), "lifecycle begin should resolve serve target")
	_expect(is_equal_approx(intro.elapsed_sec, 0.0), "lifecycle begin should reset elapsed time")
	_expect(intro.prewarm_calls == 3, "lifecycle begin should prewarm three texture paths")
	_expect(intro.reset_calls == 1, "lifecycle begin should reset intro state")
	_expect(intro.spawn_calls == 1, "lifecycle begin should spawn initial entities")
	_expect(intro.begin_fx_calls == 1, "lifecycle begin should attach FX host")
	_expect(intro.owner_snapshot.get("ball_pos", Vector2.ZERO) == Vector2(380.0, 375.0), "lifecycle begin should publish start ball snapshot")
	_expect(registry.round_state.paused == 1, "lifecycle begin should pause serve for intro")
	_expect(intro.synced_serve_input == 1, "lifecycle begin should sync serve input edges")


func _verify_lifecycle_skips_tutorial_intro() -> void:
	var lifecycle: Object = StageBallSpawnIntroLifecycle.new()
	var intro := FakeIntro.new()
	var owner := FakeOwner.new()
	intro.active = false
	intro.overlay_active = false
	owner.current_stage = 50

	_expect(not lifecycle.begin_intro(intro, owner, null, {"tutorial_stage": 50}), "lifecycle begin should skip tutorial stage")
	_expect(not intro.active, "skipped tutorial begin should not activate intro")
	_expect(intro.prewarm_calls == 0, "skipped tutorial begin should not prewarm textures")


func _verify_lifecycle_updates_intro_phase_dispatch() -> void:
	var lifecycle: Object = StageBallSpawnIntroLifecycle.new()
	var owner := FakeOwner.new()

	var phase1_intro := FakeIntro.new()
	phase1_intro.elapsed_sec = 0.0
	lifecycle.update_intro(phase1_intro, 0.20, owner, null, _update_config())
	_expect(is_equal_approx(phase1_intro.elapsed_sec, 0.05), "update should clamp delta before ticking elapsed time")
	_expect(phase1_intro.phase1_calls == 1, "update should dispatch Phase 1 before phase boundary")
	_expect(phase1_intro.phase2_calls == 0 and phase1_intro.phase3_calls == 0, "Phase 1 update should not call later phases")
	_expect(is_equal_approx(phase1_intro.last_update_dt, 0.05), "update should pass clamped delta to phase method")
	_expect(phase1_intro.state_sync_calls == 1, "update should sync FX host state after phase update")
	_expect(phase1_intro.owner_snapshot.get("ball_pos", Vector2.ZERO) == Vector2(44.0, 55.0), "update should publish visible ball snapshot")

	var phase2_intro := FakeIntro.new()
	phase2_intro.elapsed_sec = 2.0
	lifecycle.update_intro(phase2_intro, 0.01, owner, null, _update_config())
	_expect(phase2_intro.phase2_calls == 1, "update should dispatch Phase 2 inside second phase window")

	var phase3_intro := FakeIntro.new()
	phase3_intro.elapsed_sec = 2.75
	lifecycle.update_intro(phase3_intro, 0.01, owner, null, _update_config())
	_expect(phase3_intro.phase3_calls == 1, "update should dispatch Phase 3 after phase 2 boundary")


func _verify_lifecycle_finishes_intro_on_duration() -> void:
	var lifecycle: Object = StageBallSpawnIntroLifecycle.new()
	var intro := FakeIntro.new()
	intro.elapsed_sec = 3.99

	lifecycle.update_intro(intro, 0.20, null, null, _update_config())

	_expect(intro.handoff_calls == 1, "update should hand off gameplay when blocking duration is reached")
	_expect(intro.finish_calls == 0, "blocking-duration handoff should not tear down residual overlay")
	_expect(not intro.active and intro.overlay_active, "handoff should unblock gameplay but keep overlay visible")
	_expect(intro.outro_calls == 1, "handoff update should dispatch the outro tick")
	_expect(intro.state_sync_calls == 1, "handoff update should keep syncing FX state")


func _verify_lifecycle_spawns_initial_intro_entities() -> void:
	var lifecycle: Object = StageBallSpawnIntroLifecycle.new()
	var intro: Object = StageBallSpawnIntro.new()
	intro.rng.seed = 12345
	intro.start_pos = Vector2(380.0, 375.0)

	lifecycle.spawn_initial_entities(intro, {
		"game_width": 760.0,
		"game_height": 750.0,
		"quantum_particle_base": 3,
		"vortex_ring_count": 2,
		"starfield_count": 4,
		"haze_cloud_count": 1,
	})

	_expect(intro.particles.size() == 3, "lifecycle spawn should create configured quantum particles")
	_expect(intro.vortex_rings.size() == 2, "lifecycle spawn should create configured vortex rings")
	_expect(intro.lightning_bolts.size() == 2, "lifecycle spawn should create initial lightning burst")
	_expect(intro.starfield.size() == 4, "lifecycle spawn should create configured starfield dots")
	_expect(intro.haze_clouds.size() == 1, "lifecycle spawn should create configured haze clouds")
	_expect(is_equal_approx(intro.fog_alpha, 100.0), "lifecycle spawn should initialize fog alpha")
	_expect(intro.fog_color == Color(0.78, 0.86, 1.0, 1.0), "lifecycle spawn should initialize fog color")


func _verify_lifecycle_resets_intro_vfx_state() -> void:
	var lifecycle: Object = StageBallSpawnIntroLifecycle.new()
	var intro := FakeIntro.new()

	lifecycle.reset_state(intro)

	_expect(intro.tear_down_calls == 1, "lifecycle reset should tear down the FX host")
	_expect(intro.particles.is_empty(), "lifecycle reset should clear particles")
	_expect(intro.vortex_rings.is_empty(), "lifecycle reset should clear vortex rings")
	_expect(intro.lightning_bolts.is_empty(), "lifecycle reset should clear lightning bolts")
	_expect(intro.chain_lightnings.is_empty(), "lifecycle reset should clear chain lightnings")
	_expect(intro.electric_arcs.is_empty(), "lifecycle reset should clear electric arcs")
	_expect(intro.sparks.is_empty(), "lifecycle reset should clear sparks")
	_expect(intro.hologram_rings.is_empty(), "lifecycle reset should clear hologram rings")
	_expect(intro.energy_rings.is_empty(), "lifecycle reset should clear energy rings")
	_expect(intro.phase3_trail.is_empty(), "lifecycle reset should clear phase 3 trail")
	_expect(intro.starfield.is_empty(), "lifecycle reset should clear starfield")
	_expect(intro.haze_clouds.is_empty(), "lifecycle reset should clear haze clouds")
	_expect(is_equal_approx(intro.lightning_spawn_timer, 0.0), "lifecycle reset should clear lightning timer")
	_expect(is_equal_approx(intro.arc_spawn_timer, 0.0), "lifecycle reset should clear arc timer")
	_expect(is_equal_approx(intro.spark_spawn_timer, 0.0), "lifecycle reset should clear spark timer")
	_expect(is_equal_approx(intro.hologram_spawn_timer, 0.0), "lifecycle reset should clear hologram timer")
	_expect(is_equal_approx(intro.energy_ring_timer, 0.0), "lifecycle reset should clear energy-ring timer")
	_expect(is_equal_approx(intro.particle_spawn_timer, 0.0), "lifecycle reset should clear particle timer")
	_expect(is_equal_approx(intro.chain_spawn_timer, 0.0), "lifecycle reset should clear chain timer")
	_expect(is_equal_approx(intro.fog_alpha, 0.0), "lifecycle reset should clear fog alpha")
	_expect(is_equal_approx(intro.core_glow_radius, 0.0), "lifecycle reset should clear core radius")
	_expect(is_equal_approx(intro.core_glow_alpha, 0.0), "lifecycle reset should clear core alpha")


func _verify_lifecycle_finishes_intro_and_resumes_serve() -> void:
	var lifecycle: Object = StageBallSpawnIntroLifecycle.new()
	var intro := FakeIntro.new()
	var registry := FakeRegistry.new()
	var target := Vector2(123.0, 456.0)

	lifecycle.finish(intro, null, registry, target)

	_expect(not intro.active, "finish should mark intro inactive")
	_expect(is_equal_approx(intro.elapsed_sec, 0.0), "finish should reset elapsed time")
	_expect(intro.tear_down_calls == 1, "finish should reset intro state")
	_expect(intro.owner_snapshot.get("ball_pos", Vector2.ZERO) == target, "finish should restore target ball position")
	_expect(registry.round_state.prepared == 1, "finish should prepare serve after intro")
	_expect(registry.round_state.reset_wait == 0, "finish should prefer prepare_serve_after_intro")
	_expect(intro.synced_serve_input == 1, "finish should sync serve input edges")


func _verify_intro_delegates_finish_and_reset_surface() -> void:
	var intro: Object = StageBallSpawnIntro.new()
	var lifecycle := FakeIntroLifecycle.new()
	intro.intro_lifecycle = lifecycle

	_expect(intro.begin(null, null), "intro begin should delegate to lifecycle helper")
	intro.update(0.016, null, null)
	intro._spawn_initial_entities()
	intro._reset_state()
	intro._finish(null, null)

	_expect(lifecycle.begin_calls == 1, "intro begin should delegate to lifecycle helper")
	_expect(lifecycle.update_calls == 1, "intro update should delegate to lifecycle helper")
	_expect(lifecycle.spawn_calls == 1, "intro initial spawn should delegate to lifecycle helper")
	_expect(lifecycle.reset_calls == 1, "intro reset should delegate to lifecycle helper")
	_expect(lifecycle.finish_calls == 1, "intro finish should delegate to lifecycle helper")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
