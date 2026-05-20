extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemMagnetFieldParticles := preload("res://scripts/items/active_item_magnet_field_particles.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(100.0, 600.0)
	var player_paddle_width := 120.0
	var player_paddle_height := 40.0


func _init() -> void:
	_verify_direct_particle_lifecycle()
	_verify_controller_delegates_particles()

	if _failures.is_empty():
		print("active_item_magnet_field_particles_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_particle_lifecycle() -> void:
	seed(77)
	var particles_helper: Object = ActiveItemMagnetFieldParticles.new()
	var particles: Array[Dictionary] = []
	var center := Vector2(160.0, 620.0)

	var accumulator: float = particles_helper.advance_particles(particles, center, 2.5, 1.0)
	_expect(is_equal_approx(accumulator, 0.5), "magnet particles should return remaining spawn accumulator")
	_expect(particles.size() == 1, "magnet particles should spawn after interval threshold")
	_expect(float(particles[0].get("alpha", 0.0)) < 200.0 / 255.0, "magnet particle should update alpha after spawning")

	for _i in range(120):
		particles_helper.spawn_particle(particles, center)
	_expect(particles.size() == 96, "magnet particle helper should enforce cap")

	var expired: Array[Dictionary] = [{
		"position": Vector2.ZERO,
		"velocity": Vector2.ZERO,
		"alpha": 0.01,
	}]
	particles_helper.update_particles(expired, 2.0)
	_expect(expired.is_empty(), "magnet particle helper should compact faded particles")


func _verify_controller_delegates_particles() -> void:
	seed(88)
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	controller.magnet_field_active = true
	controller.magnet_field_timer_frames = 30.0
	controller.magnet_field_initial_timer_frames = 30.0
	controller.magnet_field_particle_accumulator_frames = 2.5

	controller.update(owner, 1.0 / 60.0)
	_expect(controller.magnet_field_particles.size() == 1, "controller should delegate magnet particle spawning")
	_expect(is_equal_approx(controller.magnet_field_particle_accumulator_frames, 0.5), "controller should preserve delegated accumulator")
	_expect(controller.magnet_field_player_center == Vector2(160.0, 620.0), "controller should still update magnet player center")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
