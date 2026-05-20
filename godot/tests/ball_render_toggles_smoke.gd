extends SceneTree

const BallRenderToggles := preload("res://scripts/core/ball_render_toggles.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_default_off()
	_verify_intensity_force_disable()
	_verify_energy_force_disable()
	_verify_flag_path_constants()

	if _failures.is_empty():
		print("ball_render_toggles_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_default_off() -> void:
	BallRenderToggles.reset_cache_for_test()
	OS.set_environment(BallRenderToggles.INTENSITY_EFFECTS_ENV, "0")
	OS.set_environment(BallRenderToggles.ENERGY_PARTICLES_ENV, "0")
	_expect(not BallRenderToggles.is_intensity_effects_disabled(), "ball intensity effects toggle should force off when env var is '0'")
	_expect(not BallRenderToggles.is_energy_particles_disabled(), "ball energy particles toggle should force off when env var is '0'")


func _verify_intensity_force_disable() -> void:
	BallRenderToggles.reset_cache_for_test()
	OS.set_environment(BallRenderToggles.INTENSITY_EFFECTS_ENV, "1")
	OS.set_environment(BallRenderToggles.ENERGY_PARTICLES_ENV, "0")
	_expect(BallRenderToggles.is_intensity_effects_disabled(), "ball intensity effects toggle should switch on when its env var is '1'")
	_expect(not BallRenderToggles.is_energy_particles_disabled(), "ball intensity effects toggle should not affect energy particles")
	OS.set_environment(BallRenderToggles.INTENSITY_EFFECTS_ENV, "0")
	BallRenderToggles.reset_cache_for_test()


func _verify_energy_force_disable() -> void:
	BallRenderToggles.reset_cache_for_test()
	OS.set_environment(BallRenderToggles.INTENSITY_EFFECTS_ENV, "0")
	OS.set_environment(BallRenderToggles.ENERGY_PARTICLES_ENV, "1")
	_expect(BallRenderToggles.is_energy_particles_disabled(), "ball energy particles toggle should switch on when its env var is '1'")
	_expect(not BallRenderToggles.is_intensity_effects_disabled(), "ball energy particles toggle should not affect intensity effects")
	OS.set_environment(BallRenderToggles.ENERGY_PARTICLES_ENV, "0")
	BallRenderToggles.reset_cache_for_test()


func _verify_flag_path_constants() -> void:
	_expect(BallRenderToggles.INTENSITY_EFFECTS_FLAG == "res://disable_ball_intensity_effects.flag", "ball intensity effects flag path should stay stable so external tooling can drop the flag")
	_expect(BallRenderToggles.ENERGY_PARTICLES_FLAG == "res://disable_ball_energy_particles.flag", "ball energy particles flag path should stay stable so external tooling can drop the flag")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
