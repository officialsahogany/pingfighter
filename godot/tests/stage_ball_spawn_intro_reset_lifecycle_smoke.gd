extends SceneTree

const StageBallSpawnIntroLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_lifecycle.gd")
const StageBallSpawnIntroResetLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_reset_lifecycle.gd")

var _failures: Array[String] = []


class FakeIntro:
	extends RefCounted

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
	var tear_down_calls := 0

	func _tear_down_fx_host() -> void:
		tear_down_calls += 1


class FakeResetLifecycle:
	extends RefCounted

	var calls := 0

	func reset_state(_intro: Object) -> void:
		calls += 1


func _init() -> void:
	_verify_reset_lifecycle_clears_intro_vfx_state()
	_verify_lifecycle_delegates_reset_surface()

	if _failures.is_empty():
		print("stage_ball_spawn_intro_reset_lifecycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_reset_lifecycle_clears_intro_vfx_state() -> void:
	var lifecycle: Object = StageBallSpawnIntroResetLifecycle.new()
	var intro := FakeIntro.new()

	lifecycle.reset_state(intro)

	_expect(intro.tear_down_calls == 1, "reset lifecycle should tear down the FX host")
	_expect(intro.particles.is_empty(), "reset lifecycle should clear particles")
	_expect(intro.vortex_rings.is_empty(), "reset lifecycle should clear vortex rings")
	_expect(intro.lightning_bolts.is_empty(), "reset lifecycle should clear lightning bolts")
	_expect(intro.chain_lightnings.is_empty(), "reset lifecycle should clear chain lightnings")
	_expect(intro.electric_arcs.is_empty(), "reset lifecycle should clear electric arcs")
	_expect(intro.sparks.is_empty(), "reset lifecycle should clear sparks")
	_expect(intro.hologram_rings.is_empty(), "reset lifecycle should clear hologram rings")
	_expect(intro.energy_rings.is_empty(), "reset lifecycle should clear energy rings")
	_expect(intro.phase3_trail.is_empty(), "reset lifecycle should clear phase 3 trail")
	_expect(intro.starfield.is_empty(), "reset lifecycle should clear starfield")
	_expect(intro.haze_clouds.is_empty(), "reset lifecycle should clear haze clouds")
	_expect(is_equal_approx(intro.lightning_spawn_timer, 0.0), "reset lifecycle should clear lightning timer")
	_expect(is_equal_approx(intro.arc_spawn_timer, 0.0), "reset lifecycle should clear arc timer")
	_expect(is_equal_approx(intro.spark_spawn_timer, 0.0), "reset lifecycle should clear spark timer")
	_expect(is_equal_approx(intro.hologram_spawn_timer, 0.0), "reset lifecycle should clear hologram timer")
	_expect(is_equal_approx(intro.energy_ring_timer, 0.0), "reset lifecycle should clear energy-ring timer")
	_expect(is_equal_approx(intro.particle_spawn_timer, 0.0), "reset lifecycle should clear particle timer")
	_expect(is_equal_approx(intro.chain_spawn_timer, 0.0), "reset lifecycle should clear chain timer")
	_expect(is_equal_approx(intro.fog_alpha, 0.0), "reset lifecycle should clear fog alpha")
	_expect(is_equal_approx(intro.core_glow_radius, 0.0), "reset lifecycle should clear core radius")
	_expect(is_equal_approx(intro.core_glow_alpha, 0.0), "reset lifecycle should clear core alpha")


func _verify_lifecycle_delegates_reset_surface() -> void:
	var lifecycle: Object = StageBallSpawnIntroLifecycle.new()
	var fake := FakeResetLifecycle.new()
	lifecycle.reset_lifecycle = fake

	lifecycle.reset_state(RefCounted.new())

	_expect(fake.calls == 1, "intro lifecycle should delegate reset state")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
